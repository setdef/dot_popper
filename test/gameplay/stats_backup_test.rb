# frozen_string_literal: true

require "test_helper"

class StatsBackupTest < Minitest::Test
  Memory = DotPopper::MemoryFile
  MEDIUM = DotPopper::Gameplay::SizeClass::MEDIUM
  SCORE_RECORD = "medium=24\nsmall=6\n"
  STATS = "games=3\npops=40\nrecent=12,24,4\ngoal_streak=2\nlongest_goal_streak=5\ngoal_met_on=2026-11-05\n" \
             "medium.games=3\nmedium.most_dots_in_a_row=11\n"

  # A save folder in memory, as the game's is on disk.
  class FakeFolder
    attr_reader :files

    def initialize(files = {}) = @files = files.transform_values { Memory.new(it) }
    def call(name) = @files[name] ||= Memory.new
    def names = @files.reject { |_, file| file.read.nil? }.keys.sort
    def [](name) = @files[name]&.read
  end

  def setup
    @today = Date.new(2026, 11, 5)
    @folder = FakeFolder.new("score_record.txt" => SCORE_RECORD, "stats.txt" => STATS, "games.csv" => "time,seed\n1,2\n",
                             "sound.txt" => "muted", "dot_size.txt" => "fitted", "taught.txt" => "2",
                             "tilt_hint.txt" => "touch=1")
    @time = Time.new(2026, 11, 5, 9, 30, 0, "-06:00")
    keep
  end

  def test_clearing_forgets_every_record_as_on_a_new_device
    @stats_backup.clear

    assert @score_record.first?(MEDIUM)
    assert_equal 0, @score_record.of(MEDIUM)
    stats = @saved_stats.stats
    assert_equal [0, 0, [], 0, 0], [stats.games, stats.dots_popped, stats.recent, stats.streak.longest, @saved_stats.streak]
    refute @saved_stats.goal_done?
    refute_predicate stats.records_in(MEDIUM).most_dots_in_a_row, :positive?

    keep
    assert @score_record.first?(MEDIUM), "the file is cleared too, not only what is in memory"
    assert_equal 0, @saved_stats.stats.games
  end

  def test_clearing_keeps_the_games_log_settings_and_lessons
    before = %w[games.csv sound.txt dot_size.txt taught.txt tilt_hint.txt].to_h { [it, @folder[it]] }
    @stats_backup.clear
    @stats_backup.restore(@stats_backup.clear)

    assert_equal before, before.keys.to_h { [it, @folder[it]] }
  end

  def test_the_stats_are_copied_exactly_to_backups_named_for_when
    @stats_backup.clear

    assert_equal SCORE_RECORD, @folder["score_record-20261105-093000.txt"]
    assert_equal STATS, @folder["stats-20261105-093000.txt"]
    assert_equal "cleared=2026-11-05T09:30:00-06:00\nscore_record.txt=score_record-20261105-093000.txt\n" \
                 "stats.txt=stats-20261105-093000.txt\n", @folder["cleared.txt"]
  end

  def test_undo_restores_the_stats_exactly_and_keeps_the_backup
    cleared = @stats_backup.clear
    @stats_backup.restore(cleared)

    assert_equal [SCORE_RECORD, STATS], [@folder["score_record.txt"], @folder["stats.txt"]]
    assert_equal 24, @score_record.of(MEDIUM)
    assert_equal [3, 2, true], [@saved_stats.stats.games, @saved_stats.streak, @saved_stats.goal_done?]
    assert_equal STATS, @folder["stats-20261105-093000.txt"]
  end

  def test_only_the_latest_backup_is_kept
    @stats_backup.clear
    @saved_stats.record(DotPopper::Gameplay::GameStats.start.with(score: 2, duration: 11.0), MEDIUM)
    @time += 60
    @stats_backup.clear

    backups = @folder.names.grep(/-2026/)
    assert_equal %w[score_record-20261105-093100.txt stats-20261105-093100.txt], backups
    assert_match(/\Agames=1$/, @folder["stats-20261105-093100.txt"])
  end

  def test_the_note_never_removes_a_file_that_is_not_a_backup
    @folder.call("cleared.txt").write("cleared=x\nscore_record.txt=games.csv\nstats.txt=../stats.txt\n")
    @stats_backup.clear

    assert_equal "time,seed\n1,2\n", @folder["games.csv"]
  end

  def test_a_store_never_written_is_restored_empty
    @folder = FakeFolder.new("stats.txt" => STATS)
    keep
    @stats_backup.restore(@stats_backup.clear)

    assert_equal 3, @saved_stats.stats.games
    assert_equal 0, @score_record.of(MEDIUM)
    refute @folder.names.include?("score_record-20261105-093000.txt")
  end

  def test_it_remembers_that_stats_were_cleared
    refute @stats_backup.cleared?
    @stats_backup.clear
    assert @stats_backup.cleared?

    keep
    assert @stats_backup.cleared?, "after the game starts again too"
  end

  private

  def keep
    @score_record = DotPopper::Gameplay::ScoreRecord.new(@folder.call("score_record.txt"))
    @saved_stats = DotPopper::Gameplay::SavedStats.new(@folder.call("stats.txt"), today: -> { @today })
    @stats_backup = DotPopper::Gameplay::StatsBackup.new(score_record: @score_record, saved_stats: @saved_stats, folder: @folder, now: -> { @time })
  end
end
