# frozen_string_literal: true

module DotPopper
  module Gameplay
    # The Achievements this device has earned, and the day each was first earned
    # (an ISO date), kept in a save file that answers +read+ and +write(text)+,
    # as ScoreRecord's does, which it reads and writes as an AchievementsFile.
    # They are earned and kept whether or not the player has bought Pro; only
    # showing them waits for that.
    class Achievements
      def initialize(file)
        @file = file
        @days = AchievementsFile.parse(file.read).days
      end

      def earned?(id) = @days.key?(id)

      # The ids earned, in Achievement::IDS order.
      def earned = Achievement::IDS.select { earned?(it) }

      def count = @days.size

      # The day +id+ was earned, or nil.
      def day(id) = @days[id]

      # Keeps +ids+ as earned on +day+, saves, and returns those that were
      # not earned before, in Achievement::IDS order.
      def award(ids, day:)
        fresh = Achievement::IDS.select { ids.include?(it) && !earned?(it) }
        return fresh if fresh.empty?

        @days = @days.merge(fresh.to_h { [it, day.to_s] })
        @file.write(AchievementsFile.new(days: @days).to_s)
        fresh
      end

      # The save file's whole text, as saved, for #restore (StatsBackup).
      def saved = @file.read

      # Forgets every achievement, as on a new device.
      def clear
        @days = {}
        @file.write("")
      end

      # Puts back +text+, the save file's whole text as #saved gave it.
      def restore(text)
        @file.write(text.to_s)
        @days = AchievementsFile.parse(text).days
      end
    end
  end
end
