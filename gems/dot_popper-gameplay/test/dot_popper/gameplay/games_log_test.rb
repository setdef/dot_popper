# frozen_string_literal: true

require "test_helper"

class GamesLogTest < Minitest::Test
  include DotPopperTest

  def setup
    @file = DotPopper::MemoryFile.new
    @game_flow = DotPopper::Gameplay::GameFlow.new(field, random: Random.new(9))
    @game_flow.subscribe(DotPopper::Gameplay::GamesLog.new(@file, now: -> { Time.utc(2026, 11, 5, 9, 30) },
                                               today: -> { Date.new(2026, 11, 5) }))
  end

  def test_each_finished_game_appends_a_line_under_one_header
    play_game(dots_popped: 2)
    play_game(dots_popped: 0)

    lines = @file.read.lines(chomp: true)
    assert_equal "time,seed,score,duration,pops,mistakes,softened,mean_time_to_pop,longest_time_to_pop,goal,goal_met", lines.first
    assert_equal 3, lines.size
    time, seed, score, duration, dots_popped, mistakes, softened, mean_time_to_pop, longest_time_to_pop, goal, met = lines[1].split(",")
    assert_equal "2026-11-05T09:30:00Z", time
    assert_match(/\A\d+\z/, seed)
    assert_equal %w[2 12.00 2 0 0], [score, duration, dots_popped, mistakes, softened]
    assert_equal %w[0.50 1.00], [mean_time_to_pop, longest_time_to_pop]
    assert_equal [DotPopper::Gameplay::DailyGoal.for(Date.new(2026, 11, 5)).to_s, "false"], [goal, met]
  end

  def test_a_log_with_other_columns_is_set_aside_and_a_new_one_begins
    old = "time,mode,seed,score\n2026-11-04T20:00:00Z,daily,7,12\n"
    file = DotPopper::MemoryFile.new(old)
    archives = {}
    game_flow = DotPopper::Gameplay::GameFlow.new(field, random: Random.new(9))
    game_flow.subscribe(DotPopper::Gameplay::GamesLog.new(file, now: -> { Time.utc(2026, 11, 5, 9, 30, 15) },
                                              archive: ->(name) { archives[name] = DotPopper::MemoryFile.new }))
    @game_flow = game_flow
    play_game(dots_popped: 1)
    play_game(dots_popped: 1)

    assert_equal ["games-20261105-093015.csv"], archives.keys
    assert_equal old, archives.values.first.read
    lines = file.read.lines(chomp: true)
    assert_equal DotPopper::Gameplay::GamesLog::HEADER, lines.first
    assert_equal 3, lines.size, "the new log keeps its own games"
  end

  def test_a_log_under_the_current_header_is_only_added_to
    @file.write("#{DotPopper::Gameplay::GamesLog::HEADER}\nan,earlier,game\n")
    play_game(dots_popped: 0)

    assert_equal "an,earlier,game", @file.read.lines(chomp: true)[1]
    assert_equal 3, @file.read.lines.size
  end

  def test_a_game_still_in_play_is_not_logged
    start!(@game_flow)

    assert_nil @file.read
  end

  private

  def play_game(dots_popped:)
    start!(@game_flow)
    dots_popped.times do |i|
      @game_flow.update(1.0) if i.zero?
      bright = @game_flow.game.dots.find(&:bright?)
      clear_around!(live(@game_flow), bright)
      @game_flow.press(bright.x, bright.y)
    end
    @game_flow.update(20)
    @game_flow.update(1)
    @game_flow.press(0, 0)
  end
end
