# frozen_string_literal: true

require "uri"
require_relative "../presentation"
require_relative "developer_settings"
require_relative "use_cases"

module DotPopper
  module Composition
    # The composition root: builds the whole game for one platform and one
    # kind of build, and decides what it is built from, with no Lota. What
    # only the engine can make or do, it asks of +engine+ (Shell::Engine in
    # the game, a fake in the tests):
    #
    # [platform] the Platform the game runs on
    # [unit] what a graphics unit is called there, to print
    # [file(name)] a save file (read, write, remove)
    # [dimensions] the window's width and height in graphics units
    # [layout] the window's Presentation::Layout, with its safe area
    # [fill_screen] fills a phone's or tablet's screen
    # [open_window(radius:, wanted:, smallest:)] sizes a computer's window
    # [desktop_window(exclusive:)] a computer's window control
    # [context(shaders:)], [measure(context)] what draws, and how wide text is in
    #   its fonts
    # [sound_player(file:)] what plays the sounds
    # [clipboard], [opener], [buzzer] the system's clipboard, its URL
    #   opener, and its vibration motor
    # [notices] the notices Credits shows
    # [store_helper(automated:)] a computer's store helper
    # [store_answers] the file the phone host writes the store's answers to
    # [say(line)] prints a line about the run
    # [path(name)] where the save file +name+ is, to print
    #
    # +settings+ (DeveloperSettings) are the developer settings this build obeys,
    # and +now+ the time on the wall, in seconds, which Refresh keeps its floor
    # by. Nothing here starts a thread or asks anything of the network
    # until #start.
    class Root
      Style = Presentation::Style
      GAMES_LOG = "games.csv"
      SMALLEST_WINDOW = [400, 320].freeze

      attr_reader :settings, :platform, :dot_size, :window, :game_flow, :show, :context, :sound_player, :splash, :store,
                  :entitlement, :theme_releases, :watch, :cursor, :bot, :haptics, :sharing, :refresh

      def initialize(engine:, settings: DeveloperSettings.new, now: -> { Time.now.to_f })
        @engine = engine
        @settings = settings
        @now = now
        @platform = engine.platform
        @dot_size = Gameplay::DotSize.for(platform, unit: engine.unit)
        engine.say("a dot's radius is #{dot_size.reason}")
        # With DOT_POPPER_PERF=1: whether this build's Ruby verifies
        # Ed25519, which the packaged-app playthroughs check. Where it
        # does not, setdef is never found gone (Continuity::Watch).
        engine.say("Ed25519 #{Monetization::Continuity::Ed25519.available? ? "verifies" : "does not verify"} the server's test vector") if flag?("DOT_POPPER_PERF")
        open_window
        build
      end

      # Starts what reaches past this process: the first request for theme
      # releases, the store's first question, and the watch for setdef.
      # Only the first and the friend groups' are asked again (Refresh);
      # the rest are once each time the game starts.
      def start
        theme_releases&.ask
        store.connect
        watch.start
      end

      # The window as a field of dots at the usual size; the game sizes a
      # game's dots on it as the player chose (DotSizing).
      def screen = dot_size.field(*@engine.dimensions)

      # How the Game Over pile falls, is dragged, and tilts: softly, with
      # DOT_POPPER_CALM.
      def pile_style = settings.calm? ? Style::CALM_PILE : Style::PILE
      def grab_style = settings.calm? ? Style::CALM_GRAB : Style::GRAB
      def tilt_style = settings.calm? ? Style::CALM_TILT : Style::TILT

      # DOT_POPPER_FAKE_TILT's steady reading, in place of an accelerometer,
      # or nil.
      def fake_tilt = Presentation::Reading.parse(settings["DOT_POPPER_FAKE_TILT"])

      # The games a free player has left, counted as +metered+ says
      # (FreeGames.metered?), starting as a developer may ask
      # (FreeGames.starting).
      def free_games(entitlement, metered:, file: file("games.txt"))
        start = Monetization::FreeGames.starting(settings.env, channel: settings.channel)
        Monetization::FreeGames.new(file, today: settings.today, entitlement:, metered:,
                             **(start ? { first_games: start, daily: start } : {}))
      end

      # The native port: on a phone the app's host, by URL and answer file;
      # on a computer sold through its own store, the store helper shipped
      # in the app, by its pipe (Shell::StoreHelper). Which one a build uses
      # is Store.for's choice, by the channel.
      def native_store
        return @engine.store_helper(automated: settings.automated?) if platform.own_store

        Monetization::NativeStore.new(opener: @engine.opener, answers: @engine.store_answers)
      end

      # The server friend groups and themes use: setdef's, or while setdef
      # is gone, a replacement the player chose (ServerChoice),
      # or none in an automated run.
      def server_url
        own = Network::Server.url(settings.env) or return
        @server_choice.server_url(own)
      end

      private

      def flag?(name) = settings.flag?(name)
      def file(name) = @engine.file(name)

      # A phone's or tablet's game fills its screen; a computer's window is
      # sized to the play area, or to DOT_POPPER_WINDOW's size. A desktop's
      # Home offers "Full screen" and Quit; a phone's or tablet's game
      # leaves by the system.
      def open_window
        if platform.touch?
          @engine.fill_screen
          @window = Presentation::NoWindowControl.new
        else
          @engine.open_window(radius: dot_size.radius, wanted: settings.window_size(SMALLEST_WINDOW), smallest: SMALLEST_WINDOW)
          @window = @engine.desktop_window(exclusive: settings["DOT_POPPER_FULLSCREEN"] == "exclusive")
        end
      end

      def build
        today = settings.today
        random = settings.seed ? Random.new(settings.seed) : Random.new
        # A record saved before records were kept by size of screen goes to
        # this screen's class.
        legacy = Gameplay::SizeClass.of(screen)
        sizing_file = file("dot_size.txt")
        @game_flow = Gameplay::GameFlow.new(screen, score_record: Gameplay::ScoreRecord.new(file("score_record.txt"), legacy:), random:,
                                       sizing: Gameplay::DotSizing.parse(sizing_file.read))
        @engine.say("dots are standard, worked out from the screen as each game starts") if @game_flow.sizing.standard?
        saved_stats = Gameplay::SavedStats.new(file("stats.txt"), today:, legacy:)
        achievements = Gameplay::Achievements.new(file("achievements.txt"))
        stats_backup = Gameplay::StatsBackup.new(score_record: @game_flow.score_record, saved_stats:, achievements:, folder: ->(name) { file(name) })
        @gone = Monetization::Continuity::Gone.new(file("setdef.txt"))
        # What this build trusts, and where it keeps a license key, as
        # Monetization decides by the channel alone (ADR-0010).
        channel = settings.channel
        pins = Monetization::Continuity.pins_for(channel)
        license = Monetization::Continuity::License.new(Monetization::Continuity::License.kept_in(channel) { file("license.txt") }, pins:)
        @watch = watch_for(license, pins)
        @entitlement = Monetization::Entitlement.new(forced: Monetization::Entitlement.forced?(settings.env, platform:), license:, trust: Monetization::Receipt.trusted(channel))
        clipboard = @engine.clipboard
        @server_choice = Gameplay::ServerChoice.new(file("server.txt"), gone: @gone, clipboard:)
        saved_themes = Gameplay::SavedThemes.new(file("themes.txt"))
        use_theme = UseCases::UseTheme.new(saved_themes:, entitlement:)
        use_fixture(saved_themes, use_theme)
        saved_themes.open_by_date(today.call, @gone.days(today.call))
        @gone.subscribe(@server_choice).subscribe(saved_themes)
        @theme_releases = theme_releases_for(saved_themes)
        @context = @engine.context(shaders: !flag?("DOT_POPPER_NO_SHADERS"))
        current = Style::THEMES.find { it.key == use_theme.current }
        @context.use(current)
        @sound_player = @engine.sound_player(file: file("sound.txt"))
        @sound_player.use(current)
        unless Presentation::Splash.skipped?(settings.env)
          @splash = Presentation::Splash.start(calm: settings.calm?, sounding: !@sound_player.muted?)
        end
        @store = store_for(clipboard)
        games = free_games(entitlement, metered: Monetization::FreeGames.metered?(settings.env, channel:, offered: store.offered?))
        @haptics = platform.buzzes? ? @engine.buzzer : Presentation::NoHaptics.new
        @sharing = Presentation::SheetSharing.for(platform, opener: @engine.opener)
        groups = groups_session
        use_cases = Composition.use_cases(game_flow: @game_flow, free_games: games, entitlement:, store:, achievements:,
                                          saved_stats:, friend_groups: groups)
        @show = Presentation::Show.new(
          groups:, game_flow: @game_flow, layout: @engine.layout, sounds: @sound_player, radius: dot_size.radius,
          random:, calm: settings.calm?, tutor: Presentation::Tutor.new(file("taught.txt"), times: Style::LESSON.times),
          haptics:, clipboard:, notices: @engine.notices, sharing:,
          saved_stats:, achievements:, stats_backup:, sizing_file:, input: starting_input, measure: @engine.measure(@context),
          window: @window,
          tutorial_flag: Presentation::TutorialFlag.new(file("tutorial.txt"), mode: Presentation::TutorialFlag.mode(settings.env)),
          group_notice: Presentation::GroupNotice.new(file("group_notice.txt")),
          saved_themes:, links: @engine.opener, server_choice: @server_choice, use_theme:, **use_cases
        )
        # The Show hears the rules' events, and each game as FinishGame
        # finishes it, for Game Over; a store's purchase landing ticks on
        # the offer, after BuyPro has told friend groups of what was earned
        # while Free.
        @game_flow.subscribe(@show)
        use_cases[:finish_game].subscribe(@show)
        entitlement.subscribe(@show.offer)
        @refresh = Gameplay::Refresh.new([-> { @theme_releases&.ask }, -> { groups.refresh }], game_flow: @game_flow, now: @now)
        @game_flow.subscribe(@refresh)
        @game_flow.subscribe(Gameplay::GamesLog.new(file(GAMES_LOG), today:, archive: ->(name) { file(name) }))
        @engine.say("each game is logged in #{@engine.path(GAMES_LOG)}")
        @show.group_panel.open if flag?("DOT_POPPER_GROUP_SCREEN")
        @cursor = Presentation::GamepadCursor.centered(@show.layout.whole, style: Style::GAMEPAD, radius: dot_size.radius)
        @cursor = @cursor.show if settings.fake_gamepad?
        @bot = Presentation::Bot.new(Style::BOT) if flag?("DOT_POPPER_AUTOPLAY")
      end

      # The store for this build, as Store.for chooses it by the channel.
      def store_for(clipboard)
        Monetization::Store.for(platform, entitlement:, channel: settings.channel, native: native_store,
                            website: -> { website_store(clipboard, Monetization::BrowserCheckout.new(opener: @engine.opener)) })
      end

      # A build for sale releases no theme here and has no stand-in for
      # setdef; a part (Build::PARTS) may answer these, and #store_for,
      # for a build with no channel.
      def use_fixture(_saved_themes, _use_theme) = nil
      def test_watch(_license, _pins) = nil

      # What the player is assumed to hold before they press anything.
      def starting_input
        return Presentation::InputKind::GAMEPAD if settings.fake_gamepad?

        Presentation::InputKind.starting(touch: platform.touch?)
      end

      # Friend groups on the server in use, each server's token kept apart,
      # so setdef's is never sent to a replacement.
      def groups_session
        url = server_url
        own = url.nil? || url == Network::Server.url(settings.env)
        Gameplay::Groups::Session.at(url, file: own ? file("group.txt") : file("group-#{URI(url).host.to_s.downcase}.txt"))
      end

      # What asks whether setdef is gone, and where a license key is: a test
      # build's own, in this process, sending nothing anywhere (#test_watch);
      # the real server and connectivity checks once setdef's real keys are
      # pinned (Continuity.live?), never in an automated run; and else
      # nothing.
      def watch_for(license, pins)
        watch = test_watch(license, pins) and return watch
        if Monetization::Continuity.live? && !settings.automated?
          return Monetization::Continuity::Watch.new(server: Monetization::Continuity::SetdefServer.new(Network::Link.new(Network::Server::SERVER_URL)),
                                       connectivity: Monetization::Continuity::Connectivity.new, gone: @gone, license:, today: settings.today, pins:)
        end

        Monetization::Continuity::NoWatch.new(gone: @gone, license:)
      end

      # The website's store, with +checkout+: in the browser, in a build
      # for sale.
      def website_store(clipboard, checkout)
        Monetization::WebsiteStore.new(checkout:, entitlement:, gone: @gone, clipboard:, entered: -> { @watch.start })
      end

      # What asks the server which themes are released, if the game has a
      # server.
      def theme_releases_for(saved_themes)
        url = server_url or return
        Gameplay::ThemeReleases.new(worker: Network::Worker.new(Network::Link.new(url)), saved_themes:,
                          file: file("started_on.txt"), now: settings.utc_now)
      end
    end
  end
end

DotPopper::ReleaseEngineering::Build::PARTS.each { require_relative "../#{it}/root" }
