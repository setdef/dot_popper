# frozen_string_literal: true

module DotPopper
  module Gameplay
    # What score_record.txt holds: the +scores+, each SizeClass's score
    # record, as a line of +class=score+ each, in the order they were
    # first kept. Read leniently: a line that is not +class=score+ for a
    # known class, with a whole number, is left out. A file written before
    # scores were kept by class holds one bare number (#old?), read as the
    # score of +legacy+, the class of the screen the game opens on.
    class ScoreRecordFile < Data.define(:scores)
      OLD = /\A\s*\d+\s*\z/

      def self.parse(text, legacy:)
        text = text.to_s
        return new(scores: { legacy => Integer(text.strip, 10) }) if old?(text)

        new(scores: text.lines.filter_map do |line|
          name, score = line.strip.split("=", 2)
          size_class = SizeClass.named(name.to_s)
          number = Integer(score.to_s, 10, exception: false)
          [size_class, number] if size_class && number && !number.negative?
        end.to_h)
      end

      # Whether +text+ is the single number written before classes.
      def self.old?(text) = OLD.match?(text)

      def to_s = scores.map { |size_class, score| "#{size_class.name}=#{score}\n" }.join
    end
  end
end
