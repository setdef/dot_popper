# frozen_string_literal: true

module DotPopper
  # This device's Stats, kept in a save file that answers +read+ and
  # +write(text)+, as ScoreRecord's is. +today+ gives the player's local
  # date. A save file that is missing or damaged starts from nothing, or from
  # what it could read. A save file written before records were kept by class
  # gives its records to +legacy+ and is saved again at once, as ScoreRecord
  # does.
  class SavedStats
    attr_reader :stats

    def initialize(file, today: -> { Date.today }, legacy: Gameplay::SizeClass::MEDIUM)
      @file = file
      @today = today
      @legacy = legacy
      text = file.read
      @stats = Stats.parse(text, legacy:)
      file.write(stats.to_text) if Stats.old?(text)
    end

    # Adds a finished game's GameStats, played on a screen of
    # +size_class+, saves, and says what the game did: the records it set
    # among that class's records, most impressive first, and whether it was
    # the first to meet today's goal.
    def record(game, size_class)
      day = today
      records = stats.records_set_by(game, size_class)
      goal_met = !stats.streak.done_on?(day) && DailyGoal.for(day).met?(game)
      @stats = stats.add(game, day: day.iso8601, size_class:)
      @stats = stats.with(streak: stats.streak.meet(day)) if goal_met
      @file.write(stats.to_text)
      Result.new(records:, goal_met:)
    end

    def today = @today.call

    # The save file's whole text, as saved, for #restore (StatsBackup).
    def saved = @file.read

    # Forgets every game, as on a new device: the totals, the chart, each
    # class's records, and the daily goal's streaks and today's goal met.
    def clear
      @stats = Stats.new
      @file.write("")
    end

    # Puts back +text+, the save file's whole text as #saved gave it.
    def restore(text)
      @file.write(text.to_s)
      @stats = Stats.parse(text, legacy: @legacy)
    end

    # Today's goal, and whether a game has met it yet today.
    def goal = DailyGoal.for(today)
    def goal_done? = stats.streak.done_on?(today)

    # The days in a row, up to today, that the goal was met.
    def streak = stats.streak.current_on(today)

    # What one game did to Stats: +records+ (Stats::Record,
    # most impressive first) and +goal_met+.
    class Result < Data.define(:records, :goal_met); end
  end
end
