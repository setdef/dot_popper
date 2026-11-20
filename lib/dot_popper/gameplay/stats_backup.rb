# frozen_string_literal: true

module DotPopper
  module Gameplay
    # Clears the player's Stats, and brings them back: the ScoreRecord and
    # the SavedStats, the two save files that hold every record, total, chart bar,
    # and goal streak, and the Achievements, the achievements earned, which are
    # part of what the player did as much as a record is. Nothing else is
    # cleared, so the games log, the settings, what the game has taught,
    # and whether Pro was bought stay as they are.
    #
    # Clearing copies each save file's text, exactly, to a backup named for
    # when it happened (score_record-20261105-093000.txt), through +folder+,
    # which gives the save file of a name, as GamesLog's +archive+ does, and
    # save files there answer +remove+ too. NOTE lists the latest backups, and
    # the next clearing removes them, so the folder only ever keeps one.
    # Lota's save folder cannot rename a file, so nothing is moved: the
    # copies are written, then the save files are emptied.
    #
    # Each of the three is its own aggregate, so clearing is a sequence,
    # one save file after another, which finishes within a moment. The
    # game may be stopped between its steps (a crash, the system ending
    # it): then the next launch finishes it (#finish_stopped_clear), so the
    # player finds their Stats cleared as they asked, never half of them,
    # and the backup holds every file as it was. Undo lasts only as long as
    # the game runs, after a clear stopped or not.
    class StatsBackup
      NOTE = "cleared.txt"
      BACKUP = /\A(?:score_record|stats|achievements)-\d{8}-\d{6}\.txt\z/

      def initialize(score_record:, saved_stats:, achievements: nil, folder: Folder.new, now: -> { Time.now })
        @kept = { "score_record" => score_record, "stats" => saved_stats, "achievements" => achievements }.compact
        @folder = folder
        @now = now
        @cleared = !folder.call(NOTE).read.to_s.empty?
        finish_stopped_clear if @cleared
      end

      # Whether this device's Stats have ever been cleared, so the player
      # has played before, though their Stats say nothing yet.
      def cleared? = @cleared

      # Backs Stats up, then clears them, and returns them as Cleared,
      # for #restore.
      def clear
        texts = @kept.transform_values(&:saved)
        back_up(texts)
        @kept.each_value(&:clear)
        @cleared = true
        Cleared.new(texts:)
      end

      # Puts back Stats as they were before +cleared+ (Cleared). The
      # backup stays.
      def restore(cleared) = cleared.texts.each { |name, text| @kept.fetch(name).restore(text) }

      # The save files' texts as they were, by the name of each save file.
      class Cleared < Data.define(:texts); end

      # Stores in memory by name, for tests and for a game with no save
      # folder.
      class Folder
        def initialize = @files = {}
        def call(name) = @files[name] ||= MemoryFile.new
      end

      private

      # Finishes the last clear if the game was stopped before it emptied
      # every save file: when each save file the note names is either empty
      # or still exactly its backup, and some are each. A game played since
      # a clear finished changes Stats, so their file is neither, and Undo
      # leaves none empty.
      def finish_stopped_clear
        now = backups.to_h { |name, backup| [name, [@kept.fetch(name).saved.to_s, @folder.call(backup).read.to_s]] }
        emptied, left = now.partition { |_, (text, _)| text.empty? }
        return if emptied.empty? || left.empty? || left.any? { |_, (text, backup)| text != backup }

        left.each { |name, _| @kept.fetch(name).clear }
      end

      # The backups the note names, by the name of the save file each
      # copies, for the save files this keeps.
      def backups
        @folder.call(NOTE).read.to_s.lines.filter_map do |line|
          file, backup = line.strip.split("=", 2)
          name = file.to_s.delete_suffix(".txt")
          [name, backup] if @kept.key?(name) && BACKUP.match?(backup.to_s)
        end.to_h
      end

      def back_up(texts)
        note = @folder.call(NOTE)
        note.read.to_s.lines.filter_map { it.strip.split("=", 2).last }.grep(BACKUP).each { @folder.call(it).remove }
        time = @now.call
        stamp = time.strftime("%Y%m%d-%H%M%S")
        saved = texts.filter_map do |name, text|
          next unless text

          file = "#{name}-#{stamp}.txt"
          @folder.call(file).write(text)
          "#{name}.txt=#{file}\n"
        end
        note.write("cleared=#{time.iso8601}\n#{saved.join}")
      end
    end
  end
end
