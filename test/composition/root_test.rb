# frozen_string_literal: true

require_relative "fake_engine"

# What the game is built from on every system and in every kind of build
# (Composition::Root), with memory saves and a fake engine, and no Lota:
# the window, the store, sharing and buzzing, the keys and receipts it
# trusts, the free games, the date and the server, and which developer
# settings a store build ignores. A test build (no channel) is the control.
class RootTest < Minitest::Test
  include PresentationTest

  Store = DotPopper::Monetization::Store
  NoStore = DotPopper::Monetization::NoStore
  NativeStore = DotPopper::Monetization::NativeStore
  FakeStore = DotPopper::Monetization::FakeStore
  WebsiteStore = DotPopper::Monetization::WebsiteStore
  FakeCheckout = DotPopper::Monetization::FakeCheckout

  C = DotPopper::Monetization::Continuity
  B = DotPopper::ReleaseEngineering::Build
  Root = DotPopper::Composition::Root
  SYSTEMS = ["iOS", "Android", "OS X", "Windows", "Linux"].freeze
  BUILDS = [nil, *B::CHANNEL_NAMES].freeze
  PHONES = %w[iOS Android].freeze
  # Every developer setting a player could set that matters to a store.
  SETTINGS = {
    "DOT_POPPER_AUTOMATED" => "1", "DOT_POPPER_PRO" => "1", "DOT_POPPER_AUTOPLAY" => "1", "DOT_POPPER_SCENARIO" => "game",
    "DOT_POPPER_FREE_GAMES" => "999", "DOT_POPPER_TODAY" => "2031-01-01", "DOT_POPPER_SERVER" => "http://localhost:1"
  }.freeze

  # Quitting after a while makes a run automated in any build, as
  # DOT_POPPER_AUTOMATED does only in a test build (Automation).
  AUTOMATED = { "DOT_POPPER_QUIT_AFTER" => "600" }.freeze

  def root(system = "Linux", channel: nil, env: AUTOMATED, engine: FakeEngine.new(system))
    Root.new(engine:, settings: DotPopper::Composition::DeveloperSettings.new(env, channel:))
  end

  def port(store) = store.instance_variable_get(:@port)

  def test_every_system_and_every_build_builds_a_game_at_home
    SYSTEMS.product(BUILDS).each do |system, channel|
      game = root(system, channel:)

      assert_instance_of DotPopper::Gameplay::GameFlow::Home, game.game_flow.state, "#{system}, #{channel.inspect}"
      assert_predicate game.show, :home?, "#{system}, #{channel.inspect}"
      assert_equal DotPopperTest.platform(system), game.platform
    end
  end

  def test_a_phone_fills_its_screen_and_a_computer_opens_a_window_with_its_controls
    SYSTEMS.each do |system|
      engine = FakeEngine.new(system)
      game = root(system, engine:)

      if PHONES.include?(system)
        assert_equal :filled, engine.opened, system
        assert_instance_of NoWindowControl, game.window, system
      else
        assert_equal({ radius: 50, wanted: nil, smallest: [400, 320] }, engine.opened, system)
        assert_instance_of FakeEngine::DesktopWindow, game.window, system
        refute game.window.exclusive, system
      end
    end
  end

  def test_a_computers_window_takes_the_size_and_the_fullscreen_asked_for_in_a_store_build_too
    BUILDS.each do |channel|
      engine = FakeEngine.new("Windows")
      game = root("Windows", channel:, engine:, env: { "DOT_POPPER_WINDOW" => "300x850", "DOT_POPPER_FULLSCREEN" => "exclusive" })

      assert_equal [400, 850], engine.opened[:wanted], "no smaller than the smallest window"
      assert game.window.exclusive, channel.inspect
    end
  end

  def test_the_lines_a_run_prints_name_the_dots_size_and_where_games_are_logged
    {
      "iOS" => "a dot's radius is 50 points, about 8 mm", "Android" => "a dot's radius is 50 dp, about 8 mm",
      "OS X" => "a dot's radius is 50 logical pixels", "Windows" => "a dot's radius is 50 logical pixels",
      "Linux" => "a dot's radius is 50 logical pixels"
    }.each do |system, line|
      engine = FakeEngine.new(system)
      root(system, engine:)

      assert_equal [line, "dots are standard, worked out from the screen as each game starts", "each game is logged in /save/games.csv"], engine.said, system
    end
    engine = FakeEngine.new("Linux")
    engine.file("dot_size.txt").write(DotPopper::Gameplay::DotSizing::BIGGER_OR_SMALLER.name)
    root(engine:, env: { "DOT_POPPER_PERF" => "1" })

    refute_includes engine.said, "dots are standard, worked out from the screen as each game starts"
    assert_match(/\AEd25519 (verifies|does not verify) the server's test vector\z/, engine.said[1])
  end

  def test_only_android_buzzes_and_only_a_phone_shares_through_its_sheet
    SYSTEMS.each do |system|
      engine = FakeEngine.new(system)
      game = root(system, engine:)

      if system == "Android"
        assert_same engine.buzzer, game.haptics
      else
        assert_instance_of NoHaptics, game.haptics, system
      end
      if PHONES.include?(system)
        assert_instance_of SheetSharing, game.sharing, system
      else
        assert_instance_of InGameSharing, game.sharing, system
      end
    end
  end

  def test_a_phone_starts_with_touch_a_computer_with_the_mouse_and_a_fake_gamepad_with_the_gamepad
    assert_equal InputKind::TOUCH, root("iOS").show.input
    assert_equal InputKind::MOUSE, root("OS X").show.input
    game = root("Linux", env: { "DOT_POPPER_FAKE_GAMEPAD" => "1" })

    assert_equal InputKind::GAMEPAD, game.show.input
    assert game.cursor.visible
    refute root("Linux").cursor.visible
  end

  # Store.for's table (doc/design/store-and-pro.md), as the root
  # builds it on each system for each channel.
  def test_each_build_sells_through_its_own_store_on_each_system
    expected = {
      nil => { phone: :fake, computer: :fake_website },
      B::WEBSITE => { "iOS" => :native, "Android" => :website, computer: :website },
      B::MAC_APP_STORE => { phone: :native, "OS X" => :helper, computer: :none },
      B::MICROSOFT_STORE => { phone: :native, "Windows" => :helper, computer: :none },
      B::APP_STORE => { phone: :native, computer: :none },
      B::GOOGLE_PLAY => { phone: :native, computer: :none }
    }
    SYSTEMS.product(BUILDS).each do |system, channel|
      row = expected.fetch(channel)
      want = row.fetch(system) { row.fetch(PHONES.include?(system) ? :phone : :computer) }

      assert_equal want, store_kind(root(system, channel:).store), "#{system}, #{channel.inspect}"
    end
  end

  def store_kind(store)
    case store
    when NoStore then :none
    when WebsiteStore then store.instance_variable_get(:@checkout).is_a?(FakeCheckout) ? :fake_website : :website
    else
      case port(store)
      when FakeStore then :fake
      when NativeStore then :native
      when FakeEngine::StoreHelper then :helper
      end
    end
  end

  def test_a_computers_own_store_starts_no_helper_in_an_automated_run
    [B::MAC_APP_STORE, "OS X", B::MICROSOFT_STORE, "Windows"].each_slice(2) do |channel, system|
      helper = port(root(system, channel:).store)

      assert helper.automated, system
      refute port(root(system, channel:, env: {}).store).automated, system
    end
  end

  # The keys and receipts a build trusts, by its channel alone and never
  # by anything set at run time (ADR-0010): in a test build the test keys
  # and the fake store's receipts; in a build for sale setdef's own keys,
  # and only its own store's receipts: Apple's in the App Store's and the
  # Mac App Store's, Google's in Google Play's, Windows' word in the
  # Microsoft Store's, and none in the website's.
  def test_a_build_trusts_keys_and_receipts_by_its_channel_alone
    trust = ->(channel) { DotPopper::Composition::DeveloperSettings.new(SETTINGS, channel:) }

    assert_same C::TEST_PINS, Root.pins(trust.(nil))
    assert_same DotPopper::Monetization::LicenseKeys::TEST_SIGNING_KEYS, Root.license_signing_keys(trust.(nil))
    assert_same DotPopper::Monetization::Receipt::TEST, Root.receipt_trust(trust.(nil))
    B::CHANNEL_NAMES.each do |channel|
      assert_same C::PINNED, Root.pins(trust.(channel)), channel
      assert_same DotPopper::Monetization::LicenseKeys::SIGNING_KEYS, Root.license_signing_keys(trust.(channel)), channel
      wanted = { B::APP_STORE => :APPLE, B::MAC_APP_STORE => :APPLE, B::GOOGLE_PLAY => :PLAY, B::MICROSOFT_STORE => :MICROSOFT_STORE,
                 B::WEBSITE => :NONE }.fetch(channel)
      assert_same DotPopper::Monetization::Receipt.const_get(wanted), Root.receipt_trust(trust.(channel)), channel
    end
  end

  # The root gives what it trusts to the license and the Entitlement,
  # whatever the environment says.
  def test_a_test_signed_license_key_unlocks_only_a_test_build
    key = C::TestKeys.license_key.text

    assert_equal :invalid, root(channel: B::WEBSITE, env: SETTINGS).entitlement.enter(key)
    assert_equal :entered, root(env: SETTINGS).entitlement.enter(key)
  end

  def test_only_a_test_build_takes_the_fake_stores_receipts
    receipt = DotPopper::Monetization::Receipt.issue

    refute root("iOS", channel: B::APP_STORE, env: SETTINGS).entitlement.verify_receipt(receipt)
    assert root(env: SETTINGS).entitlement.verify_receipt(receipt)
  end

  # Windows' word for a license is taken in the Microsoft Store's build
  # only, whose answers come down the helper's pipe and from no file.
  def test_only_the_microsoft_store_build_takes_windows_word
    word = "microsoft:#{DotPopper::Monetization::Receipt::PRODUCT_ID}:9NBLGGH4R315/000N"

    assert root("Windows", channel: B::MICROSOFT_STORE, env: SETTINGS).entitlement.verify_receipt(word)
    [nil, B::APP_STORE, B::MAC_APP_STORE, B::WEBSITE].each do |channel|
      refute root("Windows", channel:, env: SETTINGS).entitlement.verify_receipt(word), channel.inspect
    end
  end

  def test_pro_is_set_by_the_environment_only_in_a_test_build
    BUILDS.each do |channel|
      game = root("Linux", channel:, env: SETTINGS)

      assert_equal channel.nil?, game.entitlement.pro?, channel.inspect
    end
  end

  # Pro without a purchase (Root.forced_pro?): never on a computer or a
  # phone by default; in a test build DOT_POPPER_PRO stands in for a
  # purchase, and in a build for sale no setting does.
  def test_a_computer_is_free_by_default_and_the_setting_still_stands_in
    forced = ->(env, system) { Root.forced_pro?(DotPopper::Composition::DeveloperSettings.new(env, channel: nil), system && DotPopperTest.platform(system)) }

    ["Linux", "Windows", "OS X", "iOS", "Android"].each { refute forced.({}, it), it }
    refute forced.({ "DOT_POPPER_PRO" => "0" }, "Windows")
    B::CHANNEL_NAMES.each { refute Root.forced_pro?(DotPopper::Composition::DeveloperSettings.new({ "DOT_POPPER_PRO" => "1" }, channel: it), nil), it }
    ["Linux", "iOS", nil].each { assert forced.({ "DOT_POPPER_PRO" => "1" }, it), it.inspect }
  end

  # A new save starts with the games a developer asks for in a test build
  # (Root.starting_free_games), and with no setting's in a build for sale.
  def test_a_new_save_starts_with_the_games_a_developer_asks_for_only_in_a_test_build
    games = ->(channel, env) { Root.starting_free_games(DotPopper::Composition::DeveloperSettings.new(env, channel:)) }

    assert_equal 2, games.(nil, { "DOT_POPPER_FREE_GAMES" => "2" })
    assert_nil games.(nil, { "DOT_POPPER_FREE_GAMES" => "lots" })
    assert_nil games.(nil, {})
    B::CHANNEL_NAMES.each { assert_nil games.(it, { "DOT_POPPER_FREE_GAMES" => "2" }), it }
  end

  # Who plays is the root's to decide (Root.player?), and that free games
  # are counted for a player where Pro is offered Monetization's
  # (FreeGames.metered?): in a test build not the autoplay bot nor a GUI
  # scenario unless it sets DOT_POPPER_FREE_GAMES to try the limit, and in
  # a store build everyone. Home says how many games are left wherever
  # they are counted.
  def test_the_free_game_limit_counts_in_a_store_build_even_for_a_bot_or_a_scenario
    bot = { "DOT_POPPER_AUTOPLAY" => "1", "DOT_POPPER_SCENARIO" => "game" }
    counted = ->(channel, env) { !root(channel:, env:).show.screens[:home].games_line.nil? }

    assert counted.call(B::WEBSITE, bot)
    refute counted.call(nil, bot)
    refute counted.call(nil, { "DOT_POPPER_AUTOPLAY" => "1" })
    refute counted.call(nil, { "DOT_POPPER_SCENARIO" => "game" })
    assert counted.call(nil, { "DOT_POPPER_SCENARIO" => "game", "DOT_POPPER_FREE_GAMES" => "2" })
    assert counted.call(nil, {})
  end

  def test_a_store_build_starts_with_the_usual_free_games
    games = root(channel: B::WEBSITE, env: SETTINGS).free_games(DotPopper::Monetization::Entitlement.free, metered: true, file: DotPopper::MemoryFile.new)

    assert_equal DotPopper::Monetization::FreeGames::FIRST_GAMES + DotPopper::Monetization::FreeGames::DAILY, games.left
    test_build = root(env: SETTINGS).free_games(DotPopper::Monetization::Entitlement.free, metered: true, file: DotPopper::MemoryFile.new)

    assert_equal 999 * 2, test_build.left
  end

  def test_a_store_build_keeps_the_real_date_and_server
    store = root(channel: B::WEBSITE, env: SETTINGS)

    assert_equal Date.today, store.settings.today.call
    assert_nil store.server_url, "the bot's run is offline, not on DOT_POPPER_SERVER"
    assert_nil store.theme_releases
    plain = root(channel: B::WEBSITE, env: { "DOT_POPPER_SERVER" => "http://localhost:1" })

    assert_equal DotPopper::Network::Server::SERVER_URL, plain.server_url
    test_build = root(env: SETTINGS)

    assert_equal Date.new(2031, 1, 1), test_build.settings.today.call
    assert_equal "http://localhost:1", test_build.server_url
    refute_nil test_build.theme_releases
  end

  # A license file on disk is never read in an app store's build, so it
  # grants nothing and the watch owes the server no request about it
  # (Root.license_keys?, LicenseKeys::License.kept_in): an app store's copy
  # never accepts, keeps, verifies or sends a website license key (Apple
  # 3.1.1; Google's billing rules).
  def test_an_app_stores_build_never_reads_a_license_key
    B::STORES.each do |channel|
      engine = FakeEngine.new("Linux")
      root(channel:, engine:, env: SETTINGS)

      refute engine.opened?("license.txt"), channel
    end
    [B::WEBSITE, nil].each do |channel|
      engine = FakeEngine.new("Linux")
      root(channel:, engine:, env: SETTINGS)

      assert engine.opened?("license.txt"), channel.inspect
    end
  end

  # The setdef watch checks setdef's answers with the same pins the
  # license key is checked with: the test keys in a test build, setdef's
  # in a build for sale that asks the real server.
  def test_the_setdef_watch_trusts_the_same_pins_as_the_license
    l = DotPopper::Monetization::LicenseKeys
    { nil => [C::TEST_PINS, l::TEST_SIGNING_KEYS], B::WEBSITE => [C::PINNED, l::SIGNING_KEYS] }.each do |channel, (pins, signing_keys)|
      watch = root(channel:, env: {}).watch

      assert_instance_of C::Watch, watch, channel.inspect
      assert_same pins, watch.instance_variable_get(:@pins), channel.inspect
      assert_same pins, watch.license.instance_variable_get(:@pins), channel.inspect
      assert_same signing_keys, watch.license.instance_variable_get(:@signing_keys), channel.inspect
    end
  end

  def test_a_test_build_watches_for_setdef_through_its_fake_and_a_store_build_through_nothing_yet
    assert_instance_of C::Watch, root(env: SETTINGS).watch
    BUILDS.compact.each { assert_instance_of C::NoWatch, root(channel: it, env: SETTINGS).watch, it }
  end

  # The root subscribes the themes and the chosen server to what the
  # watch hears of setdef (Continuity::Gone): gone long enough, themes open
  # by their dates; back again, a server chosen meanwhile is forgotten.
  def test_what_the_watch_hears_of_setdef_reaches_the_themes_and_the_chosen_server
    engine = FakeEngine.new("Linux")
    game = root(engine:, env: SETTINGS)
    gone = game.watch.gone

    refute_includes game.show.themes.map(&:key), :ghost
    gone.heard(:gone, Date.new(2030, 1, 1))
    gone.heard(:unknown, Date.new(2030, 12, 1))

    assert_includes game.show.themes.map(&:key), :ghost, "opened by its date"
    engine.file("server.txt").write("https://groups.example.org\n")

    assert_equal "https://groups.example.org", game.server_url
    gone.heard(:here, Date.new(2030, 12, 2))

    assert_equal "http://localhost:1", game.server_url, "setdef's own again"
    assert_empty engine.file("server.txt").read.to_s
  end

  # A device that has found setdef gone long enough opens the themes whose
  # dates have come as the game starts, before the watch's first check.
  def test_a_game_started_with_setdef_gone_long_enough_opens_the_themes_by_their_dates
    engine = FakeEngine.new("Linux")
    engine.file("setdef.txt").write("2030-01-01\n")
    game = root(engine:, env: SETTINGS.merge("DOT_POPPER_TODAY" => "2030-12-01"))

    assert_includes game.show.themes.map(&:key), :ghost, "opened at launch, with no check yet"
    assert game.show.change_server_offered?, "Change Server offered at launch, with no check yet"
    refute root.show.change_server_offered?, "nor where setdef was never found gone"
  end

  # The game flow's Starter is UseCases::StartGame's, which the root makes,
  # so nothing else in the game can start one.
  def test_only_the_use_case_can_start_a_game
    SYSTEMS.each { |system| assert_raises(DotPopper::Gameplay::GameFlow::StarterTaken, system) { root(system).game_flow.starter } }
  end

  # The root makes the use cases and subscribes them, and the offer, to
  # what they hear: Pro arriving reaches BuyPro first, which tells friend
  # groups what was earned while Free, and then ticks on the open offer.
  def test_pro_arriving_is_heard_by_buy_pro_and_then_by_the_offer
    game = root
    listeners = game.entitlement.instance_variable_get(:@listeners)

    assert_equal [DotPopper::UseCases::BuyPro, Screens::Offer], listeners.map(&:class)
    game.show.offer.open_led_by(:themes)
    game.entitlement.verify_receipt(DotPopper::Monetization::Receipt.issue)

    assert_equal [:tick, 1.3], game.sound_player.played.last
  end

  # The root subscribes the Show it builds to the rules' events: a game
  # played there is followed by the Show, which lays out its Game Over.
  def test_the_show_the_root_builds_shows_the_game_it_hears
    game = root
    game.show.play
    game.show.back # Escape skips the Tutorial, if it opened

    assert_predicate game.game_flow, :playing?
    game.game_flow.update(30)

    assert_instance_of DotPopper::Gameplay::GameFlow::GameOver, game.game_flow.state
    assert_equal game.game_flow.state.score, game.show.game_over&.score
  end

  # The Show hears the rules' events from the game flow the root builds, so
  # a dot popped there sounds its pop: Game Over alone would not show it,
  # since the Show lays that out from what FinishGame tells it.
  def test_a_dot_popped_in_the_game_the_root_builds_sounds_its_pop
    game = root
    game.show.play
    game.show.back # Escape skips the Tutorial, if it opened
    dot = game.game_flow.game.dots.find(&:bright?)
    game.sound_player.played.clear
    game.show.tap(dot.x, dot.y)

    assert_includes game.sound_player.names, :pop
  end

  # The root subscribes every listener to the rules' events itself, in the
  # order they hear them, and the Show to each game FinishGame finishes.
  # Making a Show subscribes nothing.
  def test_the_root_subscribes_the_rules_listeners_and_a_show_subscribes_none
    game = root
    listeners = game.game_flow.instance_variable_get(:@listeners).map(&:class)

    assert_equal [DotPopper::UseCases::FinishGame, Show, DotPopper::Gameplay::Refresh, DotPopper::Gameplay::GamesLog], listeners
    game_flow = DotPopper::Gameplay::GameFlow.new(field)
    entitlement = DotPopper::Monetization::Entitlement.free
    saved_stats = DotPopper::Gameplay::SavedStats.new(DotPopper::MemoryFile.new)
    achievements = DotPopper::Gameplay::Achievements.new(DotPopper::MemoryFile.new)
    groups = DotPopper::Gameplay::Groups::Session.off
    saved_themes = DotPopper::Gameplay::SavedThemes.new(DotPopper::MemoryFile.new)
    use_cases = DotPopper::Composition.use_cases(game_flow:, free_games: DotPopper::Monetization::FreeGames.unlimited, entitlement:, store: NoStore.new,
                                                 achievements:, saved_stats:, friend_groups: groups)
    heard = -> { [game_flow, entitlement, use_cases[:finish_game]].map { it.instance_variable_get(:@listeners).size } }
    before = heard.call
    Show.new(game_flow:, layout:, sounds: FakeSounds.new, radius: R, saved_stats:, achievements:, saved_themes:, groups:,
             use_theme: DotPopper::UseCases::UseTheme.new(saved_themes:, entitlement:), **use_cases)

    assert_equal before, heard.call
  end

  def test_a_scenarios_theme_is_used_in_a_test_build_and_ignored_in_a_store_build
    env = { "DOT_POPPER_PRO" => "1", "DOT_POPPER_THEME" => "ghost", "DOT_POPPER_THEME_UNLOCKS" => "ghost" }

    assert_equal :ghost, root(env:).context.theme.key
    assert_equal :ghost, root(env:).sound_player.theme.key
    refute_equal :ghost, root(channel: B::WEBSITE, env:).context.theme.key
  end

  # A device that saved Jingle bell, a theme since removed, as its choice
  # or among its released themes starts with the ordinary theme in its place and
  # keeps every other theme it saved.
  def test_a_device_that_saved_a_removed_theme_starts_and_keeps_the_rest
    pro = AUTOMATED.merge("DOT_POPPER_PRO" => "1")
    {
      "unlocked: ghost jingle_bell\ntold: ghost jingle_bell\nchosen: jingle_bell\n" => :classic,
      "unlocked: jingle_bell ghost\ntold: jingle_bell ghost\nchosen: ghost\n" => :ghost
    }.each do |saved, in_use|
      engine = FakeEngine.new("Linux")
      engine.file("themes.txt").write(saved)
      game = root(engine:, env: pro)

      assert_instance_of DotPopper::Gameplay::GameFlow::Home, game.game_flow.state, saved
      assert_equal in_use, game.context.theme.key, saved
      assert_equal in_use, game.sound_player.theme.key, saved
      assert_equal %i[classic ghost], DotPopper::Gameplay::SavedThemes.new(engine.file("themes.txt")).choices, saved
    end
  end

  def test_the_context_draws_without_shaders_when_asked_in_any_build
    BUILDS.each do |channel|
      assert root(channel:).context.shaders
      refute root(channel:, env: { "DOT_POPPER_NO_SHADERS" => "1" }).context.shaders, channel.inspect
    end
  end

  def test_the_splash_plays_unless_it_is_left_out_and_sounds_unless_muted
    assert root(env: {}).splash.sounding
    engine = FakeEngine.new("Linux")
    engine.file("sound.txt").write("muted")

    refute root(engine:, env: {}).splash.sounding
    assert_nil root(env: { "DOT_POPPER_NO_SPLASH" => "1" }).splash
  end

  def test_a_calm_run_has_a_calm_pile_in_any_build
    BUILDS.each do |channel|
      calm = root(channel:, env: { "DOT_POPPER_CALM" => "1" })

      assert_equal [Style::CALM_PILE, Style::CALM_GRAB, Style::CALM_TILT], [calm.pile_style, calm.grab_style, calm.tilt_style]
      plain = root(channel:)

      assert_equal [Style::PILE, Style::GRAB, Style::TILT], [plain.pile_style, plain.grab_style, plain.tilt_style]
    end
  end

  def test_the_bot_plays_when_asked_in_any_build
    BUILDS.each do |channel|
      refute_nil root(channel:, env: { "DOT_POPPER_AUTOPLAY" => "1" }).bot, channel.inspect
      assert_nil root(channel:).bot
    end
  end

  def test_starting_asks_the_phone_hosts_store_and_nothing_else_reaches_past_the_process
    engine = FakeEngine.new("iOS")
    game = root("iOS", channel: B::APP_STORE, engine:)

    assert_empty engine.opener.urls, "nothing asked before #start"
    game.start

    assert_equal ["dotpopper-store://open"], engine.opener.urls.map { it[/\A[^?]*/] }
  end

  # Coming back asks for the themes and the friend groups again, as at
  # launch, and nothing that is asked once each time the game starts: not
  # the store, nor the watch for setdef.
  def test_coming_back_asks_again_for_themes_and_groups_and_nothing_asked_once_a_start
    now = 0.0
    engine = FakeEngine.new("iOS")
    game = Root.new(engine:, settings: DotPopper::Composition::DeveloperSettings.new(SETTINGS, channel: nil), now: -> { now })
    asked = []
    game.theme_releases.define_singleton_method(:ask) { asked << :themes }
    game.show.group_panel.groups.define_singleton_method(:refresh) { asked << :groups }
    game.watch.define_singleton_method(:start) { asked << :watch }
    game.store.define_singleton_method(:connect) { asked << :store }
    game.start

    assert_equal %i[themes store watch], asked, "each asked once as the game starts"
    asked.clear
    now += DotPopper::Gameplay::Refresh::FLOOR
    game.refresh.came_back

    assert_equal %i[themes groups], asked
    now += DotPopper::Gameplay::Refresh::FLOOR
    game.game_flow.send(:announce, DotPopper::Gameplay::Events::HomeShown.new(score_record: 0)) # as the game_flow does, back on Home

    assert_equal %i[themes groups themes groups], asked
  end

  # FakeEngine#file declares each name, as Shell::SaveFile does, so a
  # file the privacy document doesn't list fails every test here.
  def test_the_game_keeps_its_files_in_declared_save_files
    engine = FakeEngine.new("Linux")
    root(engine:)

    assert_includes engine.files.keys, "score_record.txt"
    assert_includes engine.files.keys, "games.csv"
  end

  # The root decides without Lota, and names nothing in the shell, which
  # hands it what it needs.
  def test_the_composition_root_names_neither_lota_nor_the_shell
    root = File.expand_path("../..", __dir__)
    named = Dir["#{root}/lib/dot_popper/composition/*.rb"].select do |path|
      File.readlines(path).any? { !it.lstrip.start_with?("#") && it.match?(/\bLota\b|\bShell::/) }
    end

    assert_empty named.map { it.delete_prefix("#{root}/") }
  end
end
