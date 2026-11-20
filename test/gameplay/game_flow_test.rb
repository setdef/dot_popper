# frozen_string_literal: true

require "test_helper"

class GameFlowTest < Minitest::Test
  include DotPopperTest
  GameFlow = DotPopper::Gameplay::GameFlow
  Events = DotPopper::Gameplay::Events

  def setup
    @file = DotPopper::ScoreRecord::Memory.new
    @game_flow = GameFlow.new(field, score_record: DotPopper::ScoreRecord.new(@file), random: Random.new(9))
    @heard = []
    @game_flow.subscribe { @heard << it }
  end

  def test_the_game_starts_on_home
    assert_instance_of GameFlow::Home, @game_flow.state
    assert_nil @game_flow.game
  end

  def test_a_press_on_home_starts_nothing
    @game_flow.press(400, 300)

    assert_instance_of GameFlow::Home, @game_flow.state
    assert_empty @heard.grep(Events::GameStarted)
  end

  def test_starting_a_game_from_home_starts_a_fresh_one_in_play
    start!(@game_flow)

    assert_instance_of GameFlow::Playing, @game_flow.state
    assert_predicate @game_flow, :playing?
    assert_equal 0, @game_flow.game.score
    assert_equal 10.0, @game_flow.game.clock.remaining
    assert_equal 1, @game_flow.game.dots.size
    assert_instance_of Events::GameStarted, @heard.last
  end

  def test_presses_in_play_reach_the_game_and_are_announced
    start!(@game_flow)
    target = @game_flow.game.dots.first

    @game_flow.press(target.x, target.y)

    assert_equal 1, @game_flow.game.score
    assert_instance_of Events::Popped, @heard.last
  end

  # Each event carries the game as it stood when the event was told, so
  # a listener needs nothing but the event.
  def test_every_event_carries_the_game_as_it_stood_when_it_was_told
    start!(@game_flow)
    game = @game_flow.game
    assert_stood game, @heard.last, :field, :dots, :score, :dots_in_a_row
    @game_flow.update(1.25)
    bright = game.dots.first
    @game_flow.press(bright.x, bright.y)
    assert_stood game, @heard.last, :dots, :score, :clock, :elapsed
    popped = game.dots.first
    @game_flow.press(popped.x, popped.y)
    assert_stood game, @heard.last, :dots, :score, :clock, :elapsed
    @game_flow.update(20)
    assert_stood game, @heard.last, :field, :dots, :score, :elapsed

    assert_equal [Events::GameStarted, Events::Popped, Events::MistakeMade, Events::GameEnded], @heard.map(&:class)
    # 10 seconds, +1 for the pop and -2 for the mistake, all played
    assert_equal [1.25, 1.25, 9.0], @heard.drop(1).map(&:elapsed)
  end

  def test_when_time_runs_out_the_game_is_over_and_shows_the_final_score
    play_to_score(1)
    @game_flow.update(20)

    assert_instance_of GameFlow::GameOver, @game_flow.state
    assert_equal 1, @game_flow.state.score
    assert_instance_of Events::GameEnded, @heard.last
  end

  def test_a_mistake_that_empties_the_clock_ends_the_game_at_once
    start!(@game_flow)
    target = @game_flow.game.dots.first
    @game_flow.press(target.x, target.y)
    @game_flow.update(10.5) # 0.5 s left, and the popped dot is still on top where it went
    popped = @game_flow.game.dots.first

    @game_flow.press(popped.x, popped.y)

    assert_instance_of GameFlow::GameOver, @game_flow.state
  end

  def test_game_over_ignores_presses_for_a_moment_then_returns_to_home
    start!(@game_flow)
    @game_flow.update(11)

    @game_flow.press(400, 300)
    assert_instance_of GameFlow::GameOver, @game_flow.state

    @game_flow.update(DotPopper::Gameplay::Rules::GAME_OVER_GRACE)
    @game_flow.press(400, 300)
    assert_instance_of GameFlow::Home, @game_flow.state
  end

  def test_presses_outside_play_do_not_change_the_finished_game
    play_to_score(1)
    @game_flow.update(11)
    game = @game_flow.game

    @game_flow.update(5)
    @game_flow.press(400, 300)
    @game_flow.press(400, 300)

    assert_equal 1, game.score
    assert_equal 0.0, game.clock.remaining
  end

  def test_a_new_game_starts_fresh
    play_to_score(2)
    @game_flow.update(20)
    @game_flow.update(1)
    @game_flow.press(0, 0) # to Home
    start!(@game_flow) # and a new game

    assert_equal 0, @game_flow.game.score
    assert_equal 1, @game_flow.game.dots.size
    assert_equal 10.0, @game_flow.game.clock.remaining
  end

  # 800 by 600 is 16 by 12 radii, a phone-sized field, and 1200 by 800 a
  # tablet-sized one.
  def test_a_game_counts_among_the_records_of_the_screen_it_started_on
    assert_equal DotPopper::Gameplay::SizeClass::SMALL, @game_flow.size_class
    play_to_score(2)
    @game_flow.screen = field(1200, 800)
    @game_flow.update(20)

    assert_equal DotPopper::Gameplay::SizeClass::SMALL, @heard.last.size_class
    assert_equal 2, @game_flow.score_record.of(DotPopper::Gameplay::SizeClass::SMALL)
    assert_equal 0, @game_flow.score_record.of(DotPopper::Gameplay::SizeClass::MEDIUM)
    assert_equal DotPopper::Gameplay::SizeClass::MEDIUM, @game_flow.size_class, "the next game counts with the new size"
  end

  # A class's first game sets its record, but beat nothing, so it is not
  # announced as a new one.
  def test_the_score_record_is_kept_and_only_a_beaten_one_is_a_new_score_record
    play_to_score(2)
    @game_flow.update(20)

    assert_equal 2, @game_flow.score_record.of(DotPopper::Gameplay::SizeClass::SMALL)
    assert_equal "small=2\n", @file.read
    assert @heard.last.first
    refute @heard.last.new_score_record

    @game_flow.update(1)
    @game_flow.press(0, 0)
    start!(@game_flow)
    @game_flow.update(20)
    refute @heard.last.first
    refute @heard.last.new_score_record
    assert_equal 2, @heard.last.score_record

    @game_flow.update(1)
    @game_flow.press(0, 0)
    play_to_score(3)
    @game_flow.update(20)
    assert @heard.last.new_score_record
    assert_equal 3, @heard.last.score_record
  end

  def test_a_new_game_uses_the_field_as_it_is_when_the_game_starts
    @game_flow.screen = field(300, 200)
    start!(@game_flow)

    assert_equal 300, @game_flow.game.field.width
  end

  # 1200 by 800 is the reference window, where a standard dot is the usual
  # 50; 600 by 400 fits a radius of 25, which the rules raise to 30.
  def test_standard_dots_set_each_games_radius_when_it_starts_and_keep_it
    @game_flow.screen = field(600, 400)
    @game_flow.sizing = DotPopper::Gameplay::DotSizing::STANDARD
    start!(@game_flow)
    assert_in_delta 30.0, @game_flow.game.field.radius
    assert_equal DotPopper::Gameplay::SizeClass::STANDARD, @game_flow.state.size_class

    @game_flow.screen = field(1200, 800)
    @game_flow.sizing = DotPopper::Gameplay::DotSizing::BIGGER_OR_SMALLER
    assert_in_delta 30.0, @game_flow.game.field.radius, 0.001, "a game keeps its radius through a resize"
    assert_equal 1200, @game_flow.game.field.width
    assert_equal DotPopper::Gameplay::DotSizing::STANDARD, @game_flow.sizing, "only the title changes the choice"
    assert_in_delta 50.0, @game_flow.field.radius, 0.001, "the next game fits the new screen"
  end

  def test_a_subscriber_must_be_a_listener_or_a_block
    assert_raises(ArgumentError) { @game_flow.subscribe }
  end

  def test_each_game_has_a_seed_of_its_own_that_replays_its_dots
    start!(@game_flow)
    first = @heard.last.seed
    seeded = DotPopper::Gameplay::Game.new(field, random: Random.new(first))

    assert_equal seeded.dots.to_a, @game_flow.game.dots.to_a
    finish_and_restart
    refute_equal first, @heard.last.seed
  end

  def test_a_paused_game_is_made_on_home_and_announced_only_when_unpaused
    first = DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, id: 0)])
    start_paused!(@game_flow, first)

    assert_instance_of GameFlow::Paused, @game_flow.state
    assert_predicate @game_flow, :paused?
    assert_equal first, @game_flow.game.dots
    assert_equal [0, 10.0], [@game_flow.game.score, @game_flow.game.clock.remaining]
    assert_empty @heard.grep(Events::GameStarted)
  end

  def test_a_paused_games_clock_does_not_run_and_no_press_reaches_it
    start_paused!(@game_flow, DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, velocity_x: 50, id: 0)]))
    @game_flow.update(3.0)
    @game_flow.press(300, 300)

    assert_equal [300.0, 10.0, 0.0], [@game_flow.game.dots.first.x, @game_flow.game.clock.remaining, @game_flow.game.elapsed]
    assert_equal [false], @game_flow.game.dots.map(&:popped?)
    @game_flow.move_paused(1.0)
    assert_in_delta 350.0, @game_flow.game.dots.first.x, 1e-9, "its dots move only as the tutorial moves them"
    assert_in_delta 10.0, @game_flow.game.clock.remaining
  end

  def test_the_tutorials_presses_reach_a_paused_game_by_the_usual_rules_and_tell_no_one
    start_paused!(@game_flow, DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, id: 0)]))
    popped = @game_flow.press_paused(300, 300)
    bright = @game_flow.game.dots.find(&:bright?)
    clear_around!(live(@game_flow), @game_flow.game.dots.first)
    mistake = @game_flow.press_paused(300, 300)

    assert_instance_of Events::Popped, popped
    assert_equal 1, popped.spawned.id
    assert_equal bright.id, popped.spawned.id
    assert_instance_of Events::MistakeMade, mistake
    assert_equal [0, 9.0, 0], [@game_flow.game.score, @game_flow.game.clock.remaining, @game_flow.game.dots_in_a_row]
    assert_empty @heard.grep(Events::Popped)
    assert_empty @heard.grep(Events::MistakeMade)
  end

  def test_the_tutorial_arranges_a_paused_games_dots
    start_paused!(@game_flow, DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, id: 0)]))
    @game_flow.arrange(@game_flow.game.dots.first.with(velocity_y: -60.0))

    assert_equal(-60.0, @game_flow.game.dots.first.velocity_y)
  end

  def test_unpausing_begins_play_on_the_same_game_as_it_is
    start_paused!(@game_flow, DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, id: 0)]))
    @game_flow.press_paused(300, 300)
    game = @game_flow.game
    @game_flow.unpause

    assert_instance_of GameFlow::Playing, @game_flow.state
    assert_same game, @game_flow.game
    started = @heard.last
    assert_instance_of Events::GameStarted, started
    assert_equal [game.dots, 1], [started.dots, started.score]
    assert_equal [1, 11.0], [game.score, game.clock.remaining]
    @game_flow.update(0.5)
    assert_in_delta 10.5, game.clock.remaining, 1e-9, "its clock runs from there"
  end

  def test_a_paused_games_seed_replays_the_dots_it_spawns
    first = DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, id: 0)])
    start_paused!(@game_flow, first)
    @game_flow.press_paused(300, 300)
    @game_flow.unpause
    seeded = DotPopper::Gameplay::Game.new(field, random: Random.new(@heard.last.seed), dots: first)
    seeded.tap_at(300, 300)

    assert_equal seeded.dots.to_a, @game_flow.game.dots.to_a
  end

  def test_a_paused_game_counts_among_the_records_of_the_screen_it_was_made_on
    start_paused!(@game_flow, DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, id: 0)]))
    made_on = @game_flow.size_class
    @game_flow.screen = DotPopper::Gameplay::Field.new(2000, 1500, R)
    @game_flow.unpause

    refute_equal made_on, @game_flow.size_class
    assert_equal made_on, @game_flow.state.size_class
  end

  def test_a_resized_window_keeps_a_paused_games_dots_on_it
    start_paused!(@game_flow, DotPopper::Gameplay::Stack.new(dots: [dot(700, 300, id: 0)]))
    @game_flow.screen = DotPopper::Gameplay::Field.new(400, 850, R)

    assert_equal 400, @game_flow.game.field.width
    assert @game_flow.game.dots.first.x.between?(R, 400 - R)
  end

  def test_only_home_starts_a_game
    start!(@game_flow)
    game = @game_flow.game
    start!(@game_flow)
    @game_flow.update(11)
    start!(@game_flow)

    assert_same game, @game_flow.game
    assert_instance_of GameFlow::GameOver, @game_flow.state
    assert_equal 1, @heard.grep(Events::GameStarted).size
  end

  # A game starts only through the game flow's Starter, which it hands out
  # once: the game flow has no method of its own that starts one, so what
  # holds only the game flow cannot, even by sending a private method's name.
  def test_only_the_game_flows_starter_starts_a_game_and_it_is_handed_out_once
    assert_raises(NoMethodError) { @game_flow.start_game(1) }
    assert_raises(NoMethodError) { @game_flow.send(:start_game, 1) }
    assert_raises(NoMethodError) { @game_flow.send(:start_paused, DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, id: 0)]), 1) }
    starter = @game_flow.starter
    assert_raises(GameFlow::StarterTaken) { @game_flow.starter }

    assert_instance_of GameFlow::Home, @game_flow.state
    assert_empty @heard.grep(Events::GameStarted)
    starter.game(1)
    assert_instance_of GameFlow::Playing, @game_flow.state
  end

  # A game is finished only by the game flow's own states, as its clock
  # reaches zero: what holds the game flow can neither finish a game that
  # was never played, so that Stats and friend groups count it, nor
  # announce an event of its own, nor send it Home.
  def test_only_the_game_flows_states_finish_a_game_announce_or_go_home
    unplayed = DotPopper::Gameplay::Game.new(field, random: Random.new(1))
    assert_raises(NoMethodError) { @game_flow.finish(unplayed, 1, @game_flow.size_class, false) }
    assert_raises(NoMethodError) { @game_flow.announce(Events::HomeShown.new(score_record: 0)) }
    assert_raises(NoMethodError) { @game_flow.show_home }

    assert_empty @heard
    start!(@game_flow)
    @game_flow.update(11)
    assert_equal 1, @heard.grep(Events::GameEnded).size, "its own clock still finishes it"
  end

  def test_only_home_makes_a_paused_game_and_only_a_paused_game_unpauses
    @game_flow.unpause
    assert_instance_of GameFlow::Home, @game_flow.state
    start!(@game_flow)
    game = @game_flow.game
    start_paused!(@game_flow, DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, id: 0)]))
    @game_flow.unpause

    assert_same game, @game_flow.game
    assert_nil @game_flow.press_paused(game.dots.first.x, game.dots.first.y)
    assert_equal 1, @heard.grep(Events::GameStarted).size
  end

  # What changes a game: a press, time, the tutorial's moves, and a resize.
  CHANGES = %i[tap_at update move_dots arrange field=].freeze

  # What the game flow answers without an argument, but what moves it on
  # (from a pause, or taking its Starter): every reader there is,
  # or will be.
  def readers = GameFlow.public_instance_methods(false).select { GameFlow.instance_method(it).arity.zero? } - %i[unpause starter]

  # Only the game flow holds its game. Nothing it answers, in any state,
  # and nothing its state holds, is the game or can change it: what the
  # screens, the renderer, the bot and the tutorial read is the game's
  # read-only Game::View, the same one each frame.
  def test_nothing_the_game_flow_answers_can_change_its_game
    answers = lambda do
      state = @game_flow.state
      [state, *Data.instance_method(:to_h).bind_call(state).values, *readers.map { @game_flow.public_send(it) }]
    end
    seen = [answers.call]
    start_paused!(@game_flow, DotPopper::Gameplay::Stack.new(dots: [dot(300, 300, id: 0)]))
    seen << answers.call
    @game_flow.unpause
    seen << answers.call
    assert_same @game_flow.game, @game_flow.game, "made once, not each time it is asked"
    @game_flow.update(30)
    seen << answers.call

    assert_equal %w[Home Paused Playing GameOver], seen.map { it[0].class.name.split("::").last }
    held = seen.flatten.compact
    view = DotPopper::Gameplay::Game::View
    read = held.grep(view).flat_map { |game| view.public_instance_methods(false).map { game.public_send(it) } }
    held += read
    assert_empty held.grep(DotPopper::Gameplay::Game)
    # What a view answers is a value, frozen all the way down, so nothing
    # reached through it can change the game it reads.
    assert_empty read.reject { Ractor.shareable?(it) }.map(&:class)
    # A state's own #update takes the game as the game flow hands it over.
    values = held.reject { it.class.name.start_with?("DotPopper::Gameplay::GameFlow::") }
    assert_empty values.select { |answer| CHANGES.any? { answer.respond_to?(it) } }.map(&:class)
    assert_empty DotPopper::Gameplay::Game::View.public_instance_methods & CHANGES
  end

  private

  def finish_and_restart
    @game_flow.update(20)
    @game_flow.update(1)
    @game_flow.press(0, 0)
    start!(@game_flow)
  end

  def play_to_score(points)
    start!(@game_flow)
    points.times do
      bright = @game_flow.game.dots.find(&:bright?)
      clear_around!(live(@game_flow), bright)
      @game_flow.press(bright.x, bright.y)
    end
  end

  def assert_stood(game, event, *values)
    values.each { assert_equal game.public_send(it), event.public_send(it), "#{event.class}##{it}" }
  end
end
