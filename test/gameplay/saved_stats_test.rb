# frozen_string_literal: true

require "test_helper"

class SavedStatsTest < Minitest::Test
  SavedStats = DotPopper::Gameplay::SavedStats
  GameStats = DotPopper::Gameplay::GameStats
  MEDIUM = DotPopper::Gameplay::SizeClass::MEDIUM

  def setup
    @file = DotPopper::Gameplay::ScoreRecord::Memory.new
    @saved_stats = SavedStats.new(@file, today: -> { Date.new(2026, 11, 5) })
  end

  def test_a_game_is_added_and_saved_on_todays_date
    @saved_stats.record(GameStats.start.with(score: 4, dots_popped: 4, duration: 14.0), MEDIUM)

    saved = SavedStats.new(@file).stats
    assert_equal 1, saved.games
    assert_equal "2026-11-05", saved.last_day
    assert_equal [4], saved.recent
  end

  def test_it_returns_the_stats_a_game_set
    @saved_stats.record(GameStats.start.with(most_dots_in_a_row: 3, duration: 10.0), MEDIUM)

    assert_equal %i[most_dots_in_a_row longest_game],
                 @saved_stats.record(GameStats.start.with(most_dots_in_a_row: 5, duration: 20.0), MEDIUM).records.map(&:kind)
  end

  # 2026-11-03's goal is to score 30 points in one game.
  def test_the_first_game_to_meet_todays_goal_says_so_and_adds_a_day_to_the_streak
    day = Date.new(2026, 11, 3)
    saved_stats = SavedStats.new(@file, today: -> { day })
    assert_equal :score, saved_stats.goal.kind

    refute saved_stats.record(GameStats.start.with(score: 29), MEDIUM).goal_met
    refute saved_stats.goal_done?
    assert saved_stats.record(GameStats.start.with(score: 30), MEDIUM).goal_met
    assert saved_stats.goal_done?
    refute saved_stats.record(GameStats.start.with(score: 35), MEDIUM).goal_met, "it is met only once a day"
    assert_equal 1, saved_stats.streak
    assert_equal 1, SavedStats.new(@file, today: -> { day }).streak, "the streak is saved"
  end

  def test_the_streak_counts_days_in_a_row_and_a_missed_day_starts_it_again
    days = { Date.new(2026, 11, 3) => :score, Date.new(2026, 11, 8) => :score, Date.new(2026, 11, 12) => :score }
    days.each_key do |day|
      SavedStats.new(@file, today: -> { day }).record(GameStats.start.with(score: 30), MEDIUM)
    end
    later = SavedStats.new(@file, today: -> { Date.new(2026, 11, 13) })

    assert_equal 1, later.streak
    assert_equal 1, later.stats.streak.longest
  end

  def test_an_older_file_is_given_to_this_screens_class_and_saved_again_at_once
    file = DotPopper::Gameplay::ScoreRecord::Memory.new("games=3\nlongest_game=20.0\nmost_dots_in_a_row=5\n")
    small = DotPopper::Gameplay::SizeClass::SMALL
    saved_stats = SavedStats.new(file, legacy: small)

    assert_equal 5, saved_stats.stats.records_in(small).most_dots_in_a_row
    assert_includes file.read, "small.most_dots_in_a_row=5\n"
    assert_equal 5, SavedStats.new(file, legacy: MEDIUM).stats.records_in(small).most_dots_in_a_row
  end

  def test_a_store_holding_nonsense_starts_from_nothing
    assert_equal DotPopper::Gameplay::Stats.new, SavedStats.new(DotPopper::Gameplay::ScoreRecord::Memory.new("\xFF\xFE".b)).stats
  end
end
