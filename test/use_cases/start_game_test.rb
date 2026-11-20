# frozen_string_literal: true

require "test_helper"
require "dot_popper/use_cases"

# Starting a game, the one way into one: it spends exactly one free game
# on each game it starts, and starts none without one
# (doc/design/store-and-pro.md).
class StartGameTest < Minitest::Test
  include DotPopperTest
  GameFlow = DotPopper::GameFlow

  def setup
    @day = Date.new(2026, 11, 8)
    @games = DotPopper::FreeGames.new(DotPopper::ScoreRecord::Memory.new, today: -> { @day }, entitlement: DotPopper::Entitlement.free,
                                                                         first_games: 0, daily: 2)
    @game_flow = GameFlow.new(field, random: Random.new(3))
    @started = []
    @game_flow.subscribe { @started << it if it.is_a?(DotPopper::Events::GameStarted) }
    @start = DotPopper::UseCases::StartGame.new(game_flow: @game_flow, free_games: @games)
  end

  def test_it_starts_a_game_in_play_and_spends_one
    refute_predicate @start, :none_left?
    assert_equal :started, @start.call

    assert_predicate @game_flow, :playing?
    assert_equal 1, @games.left
    assert_equal 1, @started.size
  end

  def test_with_an_opening_it_starts_the_game_paused_with_those_dots_and_spends_one_then
    opening = DotPopper::Stack.new(dots: [dot(300, 300, id: 0)])

    assert_equal :started, @start.call(opening)
    assert_predicate @game_flow, :paused?
    assert_equal [0], @game_flow.game.dots.map(&:id)
    assert_equal 1, @games.left, "spent as it opens"
    assert_empty @started, "announced only as play begins"

    @game_flow.unpause
    assert_equal 1, @games.left, "play beginning spends no more"
  end

  # With none left, which only a Free player where Pro is offered can
  # be (FreeGames.metered?), it answers the offer of Pro, which Play and
  # Play again carry out; nothing starts.
  def test_with_none_left_nothing_starts_and_it_answers_the_offer
    2.times { @start.call.then { finish_game } }

    assert_predicate @start, :none_left?
    assert_equal :offer, @start.call
    assert_equal :offer, @start.call(DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    assert_instance_of GameFlow::Home, @game_flow.state
    assert_equal 2, @started.size
  end

  # Away from Home it starts nothing and spends nothing, and says which:
  # Game Over's Play again goes Home to start one, or opens the offer
  # over Game Over when none is left.
  def test_away_from_home_it_starts_nothing_and_spends_nothing
    @start.call

    assert_equal :not_home, @start.call
    assert_equal 1, @games.left
    finish_game
    @start.call
    @game_flow.update(20)

    assert_equal 0, @games.left
    assert_equal :offer, @start.call, "at Game Over, with none left"
    assert_instance_of GameFlow::GameOver, @game_flow.state
  end

  def test_a_game_unmetered_costs_nothing
    games = DotPopper::FreeGames.unlimited
    game_flow = GameFlow.new(field, random: Random.new(3)) # one StartGame for each game_flow
    start = DotPopper::UseCases::StartGame.new(game_flow:, free_games: games)

    assert_equal :started, start.call
    assert_predicate game_flow, :playing?
  end

  # A game flow hands out its one Starter once, and the use case takes it as
  # it is made, so nothing else can start a game on that game flow.
  def test_a_game_flow_hands_out_its_starter_once_and_the_use_case_holds_it
    assert_raises(GameFlow::StarterTaken) { @game_flow.starter }
    assert_raises(GameFlow::StarterTaken) { DotPopper::UseCases::StartGame.new(game_flow: @game_flow, free_games: @games) }
  end

  # A GameFlow's Starter taken (".starter"), or StartGame's read by
  # reflection (instance_variable_get(:@starter)): the second line behind
  # the Starter handed out once.
  STARTERS = /\.starter\b|@starter\b/

  # Nothing but this use case, and the composition root that hands it
  # the game flow's Starter, takes it or reads it: no screen, no shell,
  # no script, and no file outside lib/ that the phones load. It reads
  # the source, so it cannot see a name built at run time.
  def test_nothing_else_starts_a_game
    root = File.expand_path("../..", __dir__)
    files = Dir["#{root}/{lib,script}/**/*.rb"] + Dir["#{root}/bin/*"] + ["#{root}/main.rb", "#{root}/conf.rb", "#{root}/android/android_kit"]
    callers = files.select { File.file?(it) }.flat_map do |path|
      File.readlines(path).filter_map { |line| path.delete_prefix("#{root}/") if line.match?(STARTERS) && !line.strip.start_with?("#") }
    end

    assert_equal ["lib/dot_popper/composition/use_cases.rb", "lib/dot_popper/use_cases/start_game.rb"], callers.uniq.sort
  end

  private

  def finish_game
    @game_flow.update(20)
    @game_flow.update(DotPopper::Rules::GAME_OVER_GRACE)
    @game_flow.press(0, 0)
  end
end
