# frozen_string_literal: true

module DotPopper
  module Gameplay
    # Every game this device has played, added up: the totals (games,
    # dots popped, mistakes, seconds, and the distinct days played, counted by
    # +last_day+), the last RECENT scores, oldest first, with the SizeClass
    # each was played in (+recent_classes+, nil where a file written before
    # they were kept does not say), and the daily goal's GoalStreak, across
    # every screen; and for each SizeClass, its
    # RecordSet, the records a game on such a screen can set. Days are ISO 8601 dates
    # ("2026-11-05"), local to the player. The score record stays with
    # ScoreRecord. How stats.txt reads and writes it is StatsFile's.
    class Stats < Data.define(:games, :dots_popped, :mistakes, :seconds, :days, :last_day, :recent, :recent_classes,
                                      :streak, :records)
      RECENT = 20

      # +recent_classes+ line up with +recent+ from the newest back; a score
      # with none is of an unknown class.
      def initialize(games: 0, dots_popped: 0, mistakes: 0, seconds: 0.0, days: 0, last_day: nil, recent: [], recent_classes: [],
                     streak: GoalStreak.new, records: {})
        classes = ([nil] * recent.size) + recent_classes
        super(games:, dots_popped:, mistakes:, seconds: seconds.to_f, days:, last_day:, recent: recent.dup.freeze,
              recent_classes: classes.last(recent.size).freeze, streak:, records: records.dup.freeze)
      end

      # The records on screens of +size_class+, or none yet.
      def records_in(size_class) = records.fetch(size_class) { RecordSet.new }

      # The stats after one more game, played on +day+ on a screen of
      # +size_class+.
      def add(stats, day:, size_class:)
        with(games: games + 1, dots_popped: dots_popped + stats.dots_popped, mistakes: mistakes + stats.mistakes, seconds: seconds + stats.duration,
             days: day == last_day ? days : days + 1, last_day: day, recent: (recent + [stats.score]).last(RECENT),
             recent_classes: (recent_classes + [size_class]).last(RECENT),
             records: records.merge(size_class => records_in(size_class).add(stats)))
      end

      # The records a game with +stats+ on a screen of +size_class+ would
      # set, most impressive first (Record::ORDER); see RecordSet#records_set_by.
      def records_set_by(stats, size_class) = records_in(size_class).records_set_by(stats)

      # The records a game can set on one class of screen: its length, the
      # most dots in a row without a mistake, the fastest pop, and the
      # Longest Time to Pop, with how many +games+ have
      # been played on such screens.
      class RecordSet < Data.define(:games, :longest_game, :most_dots_in_a_row, :shortest_time_to_pop, :longest_time_to_pop)
        def initialize(games: 0, longest_game: 0.0, most_dots_in_a_row: 0, shortest_time_to_pop: nil, longest_time_to_pop: 0.0)
          super(games:, longest_game: longest_game.to_f, most_dots_in_a_row:, shortest_time_to_pop: shortest_time_to_pop&.to_f,
                longest_time_to_pop: longest_time_to_pop.to_f)
        end

        def add(stats)
          with(games: games + 1, longest_game: [longest_game, stats.duration].max,
               most_dots_in_a_row: [most_dots_in_a_row, stats.most_dots_in_a_row].max,
               shortest_time_to_pop: [shortest_time_to_pop, stats.shortest_time_to_pop].compact.min,
               longest_time_to_pop: [longest_time_to_pop, stats.longest_time_to_pop].max)
        end

        # The records a game with +stats+ would set. A first game sets
        # none, since it has nothing to beat, and neither does a game that
        # only equals a record as the game shows it: whole seconds for a
        # game, tenths for a pop's wait.
        def records_set_by(stats)
          return [] if games.zero?

          [
            (Record.new(kind: :most_dots_in_a_row, value: stats.most_dots_in_a_row) if beats?(stats.most_dots_in_a_row, most_dots_in_a_row, 0)),
            (Record.new(kind: :longest_game, value: stats.duration) if beats?(stats.duration, longest_game, 0)),
            (Record.new(kind: :longest_time_to_pop, value: stats.longest_time_to_pop) if beats?(stats.longest_time_to_pop, longest_time_to_pop, 1)),
            faster(stats.shortest_time_to_pop)
          ].compact
        end

        private

        # Whether +value+ beats a +record+ that is more than nothing, once both
        # are rounded to +digits+ after the point.
        def beats?(value, record, digits) = record.positive? && value.round(digits) > record.round(digits)

        def faster(pop)
          record = shortest_time_to_pop
          Record.new(kind: :shortest_time_to_pop, value: pop) if pop && record && pop.round(1) < record.round(1)
        end
      end

      # A record a game beat: +kind+ names the stat, +value+ is the game's.
      class Record < Data.define(:kind, :value)
        # The records from most impressive to least. Many dots in a row without a mistake
        # are the game's whole skill, and a long game follows from it; a long
        # wait shows patience, and the fastest pop owes the most to luck.
        ORDER = %i[most_dots_in_a_row longest_game longest_time_to_pop shortest_time_to_pop].freeze
      end
    end
  end
end
