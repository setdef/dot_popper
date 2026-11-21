# frozen_string_literal: true

require_relative "../composition/fake_engine"

# The rules of play, the Metagame's objects and the screens never know
# that Pro exists (ADR-0019). Three guards, the first the one that holds:
#
# 1. The structure. The presentation is never handed what decides Pro
#    (Entitlement, FreeGames, the store and its license keys): only the
#    use cases that ask them, and only the offer of Pro holds the one for
#    buying it. An object that holds none of them cannot ask them,
#    however it is written. The game is walked as the composition root
#    builds it, from the Show through everything it holds, the screens,
#    the panels, and what each block and method it keeps can reach.
# 2. The names. Only Monetization's own code, the use cases and the
#    composition root name Pro's objects or ask "pro?".
# 3. The answers. No public question of the presentation's objects
#    answers differently for a Free player and a Pro player.
#
# The first two do not see an object reached through a constant or a global
# (ObjectSpace, Object.const_get with a name built at run time): the
# scan finds a constant named outright, and nothing finds one spelled
# at run time.
class ProKnowledgeTest < Minitest::Test
  include PresentationTest

  # What decides Pro, which only the use cases may hold, and the
  # composition root, which holds all of it.
  DECIDING = [DotPopper::Monetization::Entitlement, DotPopper::Monetization::FreeGames, DotPopper::Monetization::LicenseKeys::License, DotPopper::Monetization::Store, DotPopper::Monetization::NoStore,
              DotPopper::Monetization::WebsiteStore, DotPopper::Monetization::FakeStore, DotPopper::Monetization::NativeStore, DotPopper::Composition::Root].freeze

  def test_the_presentation_holds_nothing_that_decides_pro_but_through_a_use_case
    show = game.show
    held = holdings(show)

    deciding = held.select { |object, _| DECIDING.any? { object.is_a?(it) } }
    assert_empty deciding.map { |object, owners| "#{object.class} in #{owners.map { |name, owner| "#{owner.class}'s #{name}" }}" },
                 "only a use case may hold what decides Pro"
    buy_pro = held.select { |object, _| object.is_a?(DotPopper::UseCases::BuyPro) }.values.flatten(1).map(&:last).uniq

    assert_equal [Screens::Offer], buy_pro.map(&:class), "only the offer of Pro holds BuyPro"
  end

  # The walk itself finds what it is meant to: a screen given the
  # Entitlement outright, or in a block it keeps.
  def test_the_walk_finds_an_entitlement_held_outright_or_in_a_block
    show = game.show
    entitlement = DotPopper::Monetization::Entitlement.free
    show.screens[:home].instance_variable_set(:@entitlement, entitlement)
    show.screens[:stats].instance_variable_set(:@ask, -> { entitlement.pro? })

    owners = holdings(show).fetch(entitlement).map(&:last)
    assert_equal [show.screens[:home], show.screens[:stats].instance_variable_get(:@ask)], owners
  end

  KNOWS = %w[
    gems/dot_popper-monetization/lib/dot_popper/monetization.rb
    gems/dot_popper-monetization/lib/dot_popper/monetization/entitlement.rb
    gems/dot_popper-monetization/lib/dot_popper/monetization/free_games.rb
    gems/dot_popper-monetization/lib/dot_popper/monetization/store.rb
    lib/dot_popper/composition/root.rb
    lib/dot_popper/composition/use_cases.rb
    lib/dot_popper/website/license_keys/license.rb
    lib/dot_popper/website/offer.rb
    lib/dot_popper/website/root.rb
    lib/dot_popper/test_build/fake_store.rb
    lib/dot_popper/test_build/root.rb
    lib/dot_popper/test_build/store.rb
    lib/dot_popper/test_build/switches.rb
    lib/dot_popper/use_cases/buy_pro.rb
    lib/dot_popper/use_cases/finish_game.rb
    lib/dot_popper/use_cases/join_or_create_friend_group.rb
    lib/dot_popper/use_cases/start_game.rb
    lib/dot_popper/use_cases/use_theme.rb
    lib/dot_popper/use_cases/view_achievements.rb
    lib/dot_popper/website/website_store.rb
  ].freeze

  # "pro?" with anything before it (has_pro?), or the Entitlement or the
  # free games by name in any case (@entitlement, free_games), in code or
  # in a comment; a line that only loads a file is not counted.
  NAMES = /pro\?|\bentitlement\b|\bfree_?games\b/i

  def test_only_monetization_the_use_cases_and_the_composition_root_name_pro
    root = File.expand_path("../..", __dir__)
    knowing = Dir["#{root}/{lib,gems/*/lib}/**/*.rb"].select { |path| File.foreach(path).any? { it.match?(NAMES) && !it.start_with?("require") } }
    knowing = knowing.map { it.delete_prefix("#{root}/") }

    assert_equal KNOWS.sort, knowing.sort
  end

  # Whether the player has Pro, under a use case's other names for it
  # (locked?, owned?), is asked nowhere in the presentation or the shell,
  # called or sent by name (send(:locked?)): a screen asks a use case for
  # the answer it carries out (UseTheme#choice, ViewAchievements#status,
  # BuyPro#status), so the decision stays there. A name spelled at run
  # time passes.
  ASKED = /\b(?:locked|owned)\?/

  def test_no_screen_asks_a_use_case_whether_the_player_has_pro
    root = File.expand_path("../..", __dir__)
    asking = Dir["#{root}/lib/dot_popper/{presentation,shell}/**/*.rb"].select { |path| File.foreach(path).any? { it.match?(ASKED) } }

    assert_empty asking.map { it.delete_prefix("#{root}/") }
  end

  # A third line, by behavior: the Show, its screens and the friend
  # groups' panel, built for a Free player and for a Pro player, answer
  # every question they ask in public (a method ending in "?" that needs
  # no argument) the same, on Home, at Game Over and on Home again, so no
  # screen offers another a Pro question under a name of its own. A use
  # case's answer carried out (a word, the offer opened) differs, as it
  # should; a decision made inside a command, or under a name that is not
  # a question, passes, and only review stops it.
  def test_no_screen_answers_a_question_that_tells_free_from_pro
    free = game("DOT_POPPER_FREE_GAMES" => "5", "DOT_POPPER_NO_TUTORIAL" => "1")
    pro = game("DOT_POPPER_PRO" => "1", "DOT_POPPER_NO_TUTORIAL" => "1")
    [free, pro].each { it.show.update(1 / 60.0) }
    3.times do |at|
      as_free = questions_answered(free.show)
      as_pro = questions_answered(pro.show)
      assert_empty as_free.reject { |question, answer| as_pro[question] == answer }.map { |question, answer| "#{question}: #{answer.inspect} for Free, #{as_pro[question].inspect} for Pro" },
                   "on #{%w[Home Game\ Over Home][at]}"
      [free, pro].each { at.zero? ? play_out(it) : it.show.screens[:game_over].continue_on }
    end
  end

  private

  def game(env = {})
    DotPopper::Composition::Root.new(engine: FakeEngine.new("Windows"),
                                     settings: DotPopper::Composition::DeveloperSettings.new({ "DOT_POPPER_QUIT_AFTER" => "600", **env }))
  end

  # Plays a game from Home to Game Over, ready for a press.
  def play_out(game)
    press_main(game.show)
    game.game_flow.update(30)
    game.game_flow.update(DotPopper::Gameplay::Rules::GAME_OVER_GRACE)
    game.show.update(1 / 60.0)
    assert_instance_of DotPopper::Gameplay::GameFlow::GameOver, game.game_flow.state
  end

  # What +object+ answers to +question+, or the error it raises, as some
  # do when asked out of turn (NewTheme#settled? with no card up); but a
  # question that asks its own object something it does not answer (a
  # forward to one that is gone, Show#offer_offered?) fails.
  def answer(object, question)
    object.public_send(question)
  rescue NoMethodError => e
    raise if e.receiver.equal?(object)

    e.class
  rescue StandardError => e
    e.class
  end

  # Each public question of the presentation's objects that a player's
  # screens are made of, by owner and name, with its answer.
  def questions_answered(show)
    objects = { "Show" => show, "group panel" => show.group_panel, **show.screens.transform_keys(&:to_s) }
    objects.flat_map do |name, object|
      object.public_methods.select { it.end_with?("?") }.filter_map do |question|
        method = object.method(question)
        next unless method.owner.name.to_s.start_with?("DotPopper::") && method.parameters.none? { |kind, _| %i[req keyreq].include?(kind) }

        ["#{name}##{question}", answer(object, question)]
      end
    end.to_h
  end

  # Everything +from+ holds, and what that holds in turn, each with the
  # owners that reach it ([name, owner]): the presentation's objects'
  # instance variables, the items of arrays and hashes, the members of
  # values, and what a block or a method it keeps can reach (its receiver
  # and the variables it closes over). An object outside the presentation
  # (the GameFlow, the friend groups' Session, a use case) is a boundary:
  # what it holds is its own, and the walk notes it but goes no further.
  def holdings(from)
    held = Hash.new { |hash, key| hash[key] = [] }.compare_by_identity
    seen = {}.compare_by_identity
    queue = [from]
    until queue.empty?
      owner = queue.shift
      next if seen[owner]

      seen[owner] = true
      parts(owner).each do |name, part|
        next if SCALARS.any? { part.is_a?(it) }

        held[part] << [name, owner]
        queue << part if walked?(part)
      end
    end
    held
  end

  # What holds nothing worth walking into.
  SCALARS = [NilClass, TrueClass, FalseClass, Numeric, String, Symbol, Module, Range, Regexp, Encoding, Random, Time, Date].freeze

  def walked?(object)
    [Array, Hash, Proc, Method, Data, Struct].any? { object.is_a?(it) } ||
      (object.class.name.to_s.start_with?("DotPopper::Presentation::") && DECIDING.none? { object.is_a?(it) })
  end

  def parts(object)
    case object
    when Array then object.each_with_index.map { |item, at| [at, item] }
    when Hash then object.flat_map { |key, value| [[:key, key], [key, value]] }
    when Proc then closed_over(object)
    when Method, UnboundMethod then [[:receiver, (object.receiver if object.is_a?(Method))]]
    when Data then Data.instance_method(:to_h).bind_call(object).to_a + ivars(object)
    when Struct then object.each_pair.to_a + ivars(object)
    else ivars(object)
    end
  end

  def ivars(object) = object.instance_variables.map { [it, object.instance_variable_get(it)] }

  def closed_over(block)
    binding = block.binding
    [[:self, binding.receiver], *binding.local_variables.map { [it, binding.local_variable_get(it)] }]
  rescue ArgumentError # a block made from a method: no binding of its own
    []
  end
end
