# frozen_string_literal: true

module DotPopper
  module Gameplay
    # The highest score on this device, kept for each SizeClass, since a
    # phone's score record and a big monitor's are different contests. It reads and
    # writes through a save file that answers +read+ and +write(text)+, so the
    # rules never touch a file system themselves (Lota's save folder in the
    # game, memory in tests). What the file holds, and how it reads and
    # writes, is ScoreRecordFile's.
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
        @values = ScoreRecordFile.parse(text, legacy:).scores
        save if ScoreRecordFile.old?(text)
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
        @values = ScoreRecordFile.parse(text, legacy: @legacy).scores
      end

      private

      def save = @file.write(ScoreRecordFile.new(scores: @values).to_s)
    end
  end
end
