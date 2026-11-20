# frozen_string_literal: true

module DotPopper
  module Gameplay
    # What achievements.txt holds: the +days+ each achievement was first
    # earned (an ISO date), as a line of +id=day+ for each, in
    # Achievement::IDS order. Read leniently: text it cannot read is left
    # out, and an achievement a newer version knows and this one does not
    # is dropped.
    class AchievementsFile < Data.define(:days)
      def self.parse(text)
        new(days: text.to_s.lines.filter_map do |line|
          name, day = line.strip.split("=", 2)
          id = name&.to_sym
          [id, day.to_s] if id && Achievement.known?(id)
        end.to_h)
      end

      def to_s = Achievement::IDS.filter_map { |id| "#{id}=#{days[id]}\n" if days.key?(id) }.join
    end
  end
end
