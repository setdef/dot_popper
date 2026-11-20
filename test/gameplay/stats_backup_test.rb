# frozen_string_literal: true

require "test_helper"

class StatsBackupTest < Minitest::Test
  Memory = DotPopper::MemoryFile
  MEDIUM = DotPopper::Gameplay::SizeClass::MEDIUM
  SCORE_RECORD = "medium=24\nsmall=6\n"
  STATS = "games=3\npops=40\nrecent=12,24,4\ngoal_streak=2\nlongest_goal_streak=5\ngoal_met_on=2026-11-05\n" \
             "medium.games=3\nmedium.most_dots_in_a_row=11\n"
  ACHIEVEMENTS = "sharpshooter=2026-11-01\npatience=2026-11-03\n"
  KEPT = %w[score_record.txt stats.txt achievements.txt].freeze

  # The game stopped (a crash, the system ending it) as a save file is
  # written: the write raises, once, when +stop+ says so; with +lose+, it
  # is lost without a word, as Shell::SaveFile loses a write that fails.
  class Stopped < StandardError; end

  class StoppingFile < Memory
    def initialize(text = nil, lose: false, &stop)
      super(text)
      @stop = stop
      @lose = lose
    end

    def write(text)
      return super unless @stop&.call(text)

      @stop = nil
      raise Stopped unless @lose

      text
    end
  end

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
    assert_equal %w[achievements-20261105-093100.txt score_record-20261105-093100.txt stats-20261105-093100.txt], backups
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

  # A clear stopped between its steps is finished at the next launch, and
  # the backup still holds every file as it was. The steps: the backups,
  # the note, each save file emptied in turn, the note again.
  def test_a_clear_stopped_after_each_of_its_steps_is_finished_at_the_next_launch
    { "score_record.txt" => "", "stats.txt" => "", "achievements.txt" => "" }.each do |name, emptied|
      stop_a_clear(name) { it == emptied }
      relaunched = KEPT.map { @folder[it] }

      assert_equal ["", "", ""], relaunched, "stopped before #{name} was emptied"
      assert_equal [0, 0, 0], [@score_record.of(MEDIUM), @saved_stats.stats.games, @achievements.count], "what the game holds, too"
      assert_backup_whole
    end
  end

  def test_a_clear_stopped_before_the_note_lost_its_mark_is_finished_too
    stop_a_clear("cleared.txt") { !it.include?("clearing=") }

    assert_equal ["", "", ""], KEPT.map { @folder[it] }
    assert_backup_whole
    refute_includes @folder["cleared.txt"], "clearing=", "finished, the note says so"
  end

  def test_a_clear_stopped_before_its_note_was_written_leaves_everything
    stop_a_clear("cleared.txt") { true }

    assert_equal [SCORE_RECORD, STATS, ACHIEVEMENTS], KEPT.map { @folder[it] }
  end

  def test_a_finished_clear_leaves_the_note_as_v0_9_21_writes_it
    @folder.call("achievements.txt").write(ACHIEVEMENTS)
    keep
    @stats_backup.clear

    assert_equal "cleared=2026-11-05T09:30:00-06:00\nscore_record.txt=score_record-20261105-093000.txt\n" \
                 "stats.txt=stats-20261105-093000.txt\nachievements.txt=achievements-20261105-093000.txt\n", @folder["cleared.txt"]
  end

  def test_a_launch_after_a_finished_clear_changes_nothing_with_or_without_a_game_since
    @folder.call("achievements.txt").write(ACHIEVEMENTS)
    keep
    @stats_backup.clear
    keep
    assert_equal ["", "", ""], KEPT.map { @folder[it] }

    @saved_stats.record(DotPopper::Gameplay::GameStats.start.with(score: 2, duration: 11.0), MEDIUM)
    played = KEPT.map { @folder[it] }
    keep
    assert_equal played, KEPT.map { @folder[it] }
  end

  # The review's first case: a file empty before the clear (achievements.txt
  # after an earlier clear, with none earned since) is put back empty by
  # Undo, and the next launch must change nothing.
  def test_after_undo_with_a_file_empty_before_the_clear_the_next_launch_changes_nothing
    @folder.call("achievements.txt").write(ACHIEVEMENTS)
    keep
    @stats_backup.clear
    @saved_stats.record(DotPopper::Gameplay::GameStats.start, MEDIUM)
    @score_record.record(5, MEDIUM)
    keep
    @time += 3600
    before = KEPT.map { @folder[it] }
    @stats_backup.restore(@stats_backup.clear)
    keep

    assert_equal before, KEPT.map { @folder[it] }
  end

  # The review's second case: long after a clear and its Undo, stats.txt
  # alone reads empty once (a write cut short); the next launch empties
  # nothing else.
  def test_a_stats_file_alone_read_empty_long_after_a_clear_empties_nothing_else
    @folder.call("achievements.txt").write(ACHIEVEMENTS)
    keep
    @stats_backup.restore(@stats_backup.clear)
    @saved_stats.record(DotPopper::Gameplay::GameStats.start, MEDIUM)
    keep
    @folder.files["stats.txt"] = Memory.new("")
    keep

    assert_equal [SCORE_RECORD, "", ACHIEVEMENTS], KEPT.map { @folder[it] }
  end

  # A note as v0.9.21 writes it has no mark, so whatever the files hold,
  # a launch finishes nothing: one emptied and the rest their backups here.
  def test_a_note_written_by_v0_9_21_never_makes_a_launch_finish_anything
    write_v0_9_21_clear(score_record: "", stats: STATS, achievements: ACHIEVEMENTS)
    keep

    assert_equal ["", STATS, ACHIEVEMENTS], KEPT.map { @folder[it] }
  end

  def test_a_file_that_cannot_be_read_is_never_taken_for_one_a_clear_emptied
    write_v0_9_21_clear(score_record: SCORE_RECORD, stats: nil, achievements: ACHIEVEMENTS)
    keep
    assert_equal [SCORE_RECORD, nil, ACHIEVEMENTS], KEPT.map { @folder[it] }, "with a v0.9.21 note"

    unreadable = lambda do
      @folder.files["stats.txt"] = Memory.new(nil)
      @folder.files["stats-20261105-093000.txt"] = Memory.new(nil) # and its backup, so the two agree
    end
    stop_a_clear("score_record.txt", before_launch: unreadable) { it == "" }
    assert_equal ["", nil, ""], KEPT.map { @folder[it] }, "with a clear under way, it is left as it is"
  end

  # The note's last write can fail without a word, so its mark outlives a
  # finished clear: Undo drops the mark, and a game since is kept.
  def test_a_mark_left_by_a_lost_write_never_empties_what_undo_restored_or_a_game_since
    @folder.files["cleared.txt"] = StoppingFile.new(lose: true) { !it.include?("clearing=") }
    @folder.call("achievements.txt").write(ACHIEVEMENTS)
    keep
    @stats_backup.restore(@stats_backup.clear)
    keep
    assert_equal [SCORE_RECORD, STATS, ACHIEVEMENTS], KEPT.map { @folder[it] }, "after Undo"

    @folder.files["cleared.txt"] = StoppingFile.new(@folder["cleared.txt"], lose: true) { !it.include?("clearing=") }
    keep
    @stats_backup.clear
    @saved_stats.record(DotPopper::Gameplay::GameStats.start.with(score: 2, duration: 11.0), MEDIUM)
    played = KEPT.map { @folder[it] }
    keep
    assert_equal played, KEPT.map { @folder[it] }, "after a game"
  end

  private

  def keep
    @score_record = DotPopper::Gameplay::ScoreRecord.new(@folder.call("score_record.txt"))
    @saved_stats = DotPopper::Gameplay::SavedStats.new(@folder.call("stats.txt"), today: -> { @today })
    @achievements = DotPopper::Gameplay::Achievements.new(@folder.call("achievements.txt"))
    @stats_backup = DotPopper::Gameplay::StatsBackup.new(score_record: @score_record, saved_stats: @saved_stats, achievements: @achievements,
                                                         folder: @folder, now: -> { @time })
  end

  # Starts from the three save files as setup has them, with achievements,
  # stops a clear as +name+ is written with what +stop+ matches, and
  # launches again, after +before_launch+.
  def stop_a_clear(name, before_launch: nil, &stop)
    setup
    @folder.call("achievements.txt").write(ACHIEVEMENTS)
    @folder.files[name] = StoppingFile.new(@folder[name], &stop)
    keep
    assert_raises(Stopped) { @stats_backup.clear }
    before_launch&.call
    keep
  end

  def assert_backup_whole
    assert_equal [SCORE_RECORD, STATS, ACHIEVEMENTS], %w[score_record stats achievements].map { @folder["#{it}-20261105-093000.txt"] }
    assert_equal 3, @folder["cleared.txt"].scan("-20261105-093000.txt").size, "the note still names the backup"
  end

  # The folder as v0.9.21 leaves it after a clear, with each save file as
  # given (nil: it cannot be read).
  def write_v0_9_21_clear(**texts)
    note = +"cleared=2026-11-05T09:30:00-06:00\n"
    texts.each do |name, text|
      @folder.call("#{name}-20261105-093000.txt").write({ score_record: SCORE_RECORD, stats: STATS, achievements: ACHIEVEMENTS }.fetch(name))
      note << "#{name}.txt=#{name}-20261105-093000.txt\n"
      @folder.files["#{name}.txt"] = Memory.new(text)
    end
    @folder.call("cleared.txt").write(note)
  end
end
