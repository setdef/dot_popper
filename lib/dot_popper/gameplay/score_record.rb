# frozen_string_literal: true

module DotPopper
  module Gameplay
    # The highest score on this device, kept for each SizeClass, since a
    # phone's score record and a big monitor's are different contests. It reads and
    # writes through a save file that answers +read+ and +write(text)+, so the
    # rules never touch a file system themselves (Lota's save folder in the
    # game, memory in tests). It saves as lines of +class=score+.
    #
    # A save file written before scores were kept by class holds one bare
    # number. That record belongs to +legacy+, the class of the screen the
    # game opens on, and is saved again in the new form at once, so it
    # stays there whichever screen the game opens on next.
    class ScoreRecord
      def initialize(file, legacy: SizeClass::MEDIUM)
        @file = file
        @legacy = legacy
        text = file.read.to_s
        @values = Table.parse(text, legacy:)
        save if Table.old?(text)
      end

      # The score record on screens of +size_class+, or 0 before there is one.
      def of(size_class) = @values.fetch(size_class, 0)

      # Whether no game has been recorded on screens of +size_class+ yet.
      def first?(size_class) = !@values.key?(size_class)

      # Keeps +score+ as one played on +size_class+, and says whether it
      # beat that class's record. A class's first game sets its record but
      # beats nothing, so it is never a new record: there was nothing to beat.
      def record(score, size_class)
        first = first?(size_class)
        return false unless first || score > of(size_class)

        @values = @values.merge(size_class => score)
        save
        !first
      end

      # The save file's whole text, as saved, for #restore (StatsBackup).
      def saved = @file.read

      # Forgets every class's score record, as on a new device.
      def clear
        @values = {}
        @file.write("")
      end

      # Puts back +text+, the save file's whole text as #saved gave it.
      def restore(text)
        @file.write(text.to_s)
        @values = Table.parse(text.to_s, legacy: @legacy)
      end

      private

      def save = @file.write(Table.to_text(@values))

      # How a save file's text reads and writes.
      module Table
        OLD = /\A\s*\d+\s*\z/

        # Each class's score, read leniently: a line that is not
        # +class=score+ for a known class, with a whole number, is skipped.
        def self.parse(text, legacy:)
          return { legacy => Integer(text.strip, 10) } if old?(text)

          text.lines.filter_map do |line|
            name, score = line.strip.split("=", 2)
            size_class = SizeClass.named(name.to_s)
            number = Integer(score.to_s, 10, exception: false)
            [size_class, number] if size_class && number && !number.negative?
          end.to_h
        end

        # Whether +text+ is the single number written before classes.
        def self.old?(text) = OLD.match?(text)

        def self.to_text(values) = values.map { |size_class, score| "#{size_class.name}=#{score}\n" }.join
      end
    end
  end
end
