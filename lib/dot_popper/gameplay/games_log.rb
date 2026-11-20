# frozen_string_literal: true

module DotPopper
  module Gameplay
    # One line per finished game, as CSV, for comparing playtests: when it
    # ended, the seed its dots were drawn from, its score, how long it ran,
    # its GameStats, and the day's goal (DailyGoal, for the date +today+
    # gives) with whether the game met it. It listens to a GameFlow (GameFlow#subscribe) and appends
    # through a save file that answers +read+ and +write(text)+, as ScoreRecord
    # does, so it never touches a file system itself.
    #
    # A log whose first line names other columns, because it was written
    # by an older version, is kept whole in a save file of its own, named
    # games-<when>.csv and made by +archive+, and a new log starts under
    # the current header.
    class GamesLog
      COLUMNS = %w[time seed score duration pops mistakes softened mean_time_to_pop longest_time_to_pop goal goal_met].freeze

      HEADER = COLUMNS.join(",")

      def initialize(file, now: -> { Time.now }, today: -> { now.call.to_date },
                     archive: ->(_name) { ScoreRecord::Memory.new })
        @file = file
        @now = now
        @today = today
        @archive = archive
        @recorder = GameStats::Recorder.new
      end

      def call(event)
        @recorder.call(event)
        append(row(event, @recorder.stats)) if event.is_a?(Events::GameEnded)
      end

      private

      def row(ended, stats)
        goal = DailyGoal.for(@today.call)
        [@now.call.iso8601, ended.seed, ended.score, seconds(stats.duration), stats.dots_popped, stats.mistakes, stats.softened,
         seconds(stats.mean_time_to_pop), seconds(stats.longest_time_to_pop), goal, goal.met?(stats)].join(",")
      end

      def seconds(value) = format("%.2f", value)

      def append(line)
        before = current
        before += "\n" unless before.end_with?("\n")
        @file.write("#{before}#{line}\n")
      end

      # The log so far, under the current header: as it was, or new, after
      # setting aside an older log or starting the first.
      def current
        before = @file.read.to_s
        return before if before.lines.first&.chomp == HEADER

        set_aside(before) unless before.strip.empty?
        "#{HEADER}\n"
      end

      def set_aside(old)
        @archive.call("games-#{@now.call.strftime("%Y%m%d-%H%M%S")}.csv").write(old)
      end
    end
  end
end
