# frozen_string_literal: true

module DotPopper
  module Gameplay
    # What stats.txt holds: the device's +stats+ (Stats) as lines of
    # +key=value+, a class's records under its name
    # ("medium.most_dots_in_a_row=18"), the total of dots popped as "pops",
    # the key every build before it was renamed reads and writes. Read
    # leniently: a missing, unknown, or unreadable value keeps its starting
    # value, so a damaged file gives back whatever can be read of it. A file
    # written before records were kept by class has them unnamed (.old?);
    # they go to +legacy+, the class of the screen the game opens on.
    class StatsFile < Data.define(:stats)
      DAY = /\A\d{4}-\d{2}-\d{2}\z/
      UNKNOWN = "?" # a recent score's class, in a file written before they were kept

      def self.parse(text, legacy: SizeClass::MEDIUM)
        pairs = Pairs.parse(text)
        records = SizeClass::ALL.to_h { [it, record_set(pairs.within(it.name))] }
        records[legacy] = record_set(pairs) if old?(text)
        recent = Stats::RECENT
        new(stats: Stats.new(games: pairs.count(:games), dots_popped: pairs.count(:pops), mistakes: pairs.count(:mistakes),
                             seconds: pairs.time(:seconds) || 0.0, days: pairs.count(:days), last_day: pairs.day(:last_day),
                             recent: pairs.counts(:recent).last(recent), recent_classes: pairs.classes(:recent_classes).last(recent),
                             streak: GoalStreak.new(current: pairs.count(:goal_streak), longest: pairs.count(:longest_goal_streak),
                                                    last_met: pairs.day(:goal_met_on)),
                             records: records.reject { |_, each| each.games.zero? }))
      end

      # Whether +text+ keeps its records unnamed, as files did before they
      # were kept by class.
      def self.old?(text) = Pairs.parse(text).values.key?("longest_game")

      # One class's records, from the pairs under its name.
      def self.record_set(pairs)
        Stats::RecordSet.new(games: pairs.count(:games), longest_game: pairs.time(:longest_game) || 0.0,
                             most_dots_in_a_row: pairs.count(:most_dots_in_a_row), shortest_time_to_pop: pairs.time(:shortest_time_to_pop),
                             longest_time_to_pop: pairs.time(:longest_time_to_pop) || 0.0)
      end

      private_class_method :record_set

      def to_s
        totals = [["games", stats.games], ["pops", stats.dots_popped], ["mistakes", stats.mistakes], ["seconds", stats.seconds],
                  ["days", stats.days], ["last_day", stats.last_day], ["recent", stats.recent.join(",")],
                  ["recent_classes", stats.recent_classes.map { it&.name || UNKNOWN }.join(",")],
                  ["goal_streak", stats.streak.current],
                  ["longest_goal_streak", stats.streak.longest], ["goal_met_on", stats.streak.last_met]]
        named = stats.records.flat_map { |size_class, each| pairs_of(each).map { |key, value| ["#{size_class.name}.#{key}", value] } }
        (totals + named).reject { |_, value| value.nil? }.map { |key, value| "#{key}=#{value}\n" }.join
      end

      # The +key=value+ lines of a saved file, read leniently: a value that
      # is missing, negative, or not a number reads as nil (or zero, for a
      # count).
      class Pairs < Data.define(:values)
        def self.parse(text)
          values = text.to_s.lines.filter_map do |line|
            key, value = line.strip.split("=", 2)
            [key.to_s, value.to_s] if value
          end
          new(values: values.to_h)
        end

        def count(key) = natural(values[key.to_s]) || 0

        def time(key)
          number = Float(values[key.to_s].to_s, exception: false)
          number if number&.finite? && !number.negative?
        end

        def counts(key) = values[key.to_s].to_s.split(",").filter_map { natural(it) }

        # The SizeClasses a list names, nil for each it does not know.
        def classes(key) = values[key.to_s].to_s.split(",").map { SizeClass.named(it) }

        def day(key)
          value = values[key.to_s].to_s
          value if DAY.match?(value)
        end

        # The pairs under +prefix+ ("medium.games"), named without it.
        def within(prefix)
          named = "#{prefix}."
          Pairs.new(values: values.filter_map { |key, value| [key.delete_prefix(named), value] if key.start_with?(named) }
                                  .to_h)
        end

        private

        def natural(text)
          number = Integer(text.to_s, 10, exception: false)
          number if number && !number.negative?
        end
      end

      private

      # One class's records as +key=value+ pairs.
      def pairs_of(set)
        [["games", set.games], ["longest_game", set.longest_game], ["most_dots_in_a_row", set.most_dots_in_a_row],
         ["shortest_time_to_pop", set.shortest_time_to_pop], ["longest_time_to_pop", set.longest_time_to_pop]]
      end
    end
  end
end
