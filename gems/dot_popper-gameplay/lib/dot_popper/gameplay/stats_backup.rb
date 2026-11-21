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
    # one save file after another. The note carries a mark (UNDER_WAY) from
    # before the first file is emptied until the last one is, and a launch
    # that finds it finishes that clear (#finish_stopped_clear), so a game
    # stopped between the steps (a crash, the system ending it) leaves the
    # player's Stats cleared as they asked, never half of them, and the
    # backup still holds every file as it was. Without the mark a launch
    # changes nothing, whatever the files hold: a file Undo put back, or
    # one that reads empty or cannot be read, is never taken for a clear.
    class StatsBackup
      NOTE = "cleared.txt"
      BACKUP = /\A(?:score_record|stats|achievements)-\d{8}-\d{6}\.txt\z/
      # The note's last line while a clear is under way. v0.9.21 reads a
      # line's value only if it is shaped like a backup's name, so it
      # passes over this one.
      UNDER_WAY = "clearing=1\n"

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
        note = back_up(texts)
        @kept.each_value(&:clear)
        @folder.call(NOTE).write(note)
        @cleared = true
        Cleared.new(texts:)
      end

      # Puts back Stats as they were before +cleared+ (Cleared). The
      # backup stays, and so does the note, without its mark, in case the
      # note's last write was lost.
      def restore(cleared)
        drop_mark
        cleared.texts.each { |name, text| @kept.fetch(name).restore(text) }
      end

      # The save files' texts as they were, by the name of each save file.
      class Cleared < Data.define(:texts); end

      # Stores in memory by name, for tests and for a game with no save
      # folder.
      class Folder
        def initialize = @files = {}
        def call(name) = @files[name] ||= MemoryFile.new
      end

      private

      # Finishes the clear the note says is under way: empties each save
      # file it names that is still exactly its backup, which the clear
      # had not reached. One already empty the clear reached; one that
      # cannot be read, or holds anything else, was written since (an
      # older version on the same folder, or a game after a note's last
      # write was lost), and is left as it is.
      def finish_stopped_clear
        note = @folder.call(NOTE).read.to_s
        return unless note.lines.include?(UNDER_WAY)

        backups.each do |name, backup|
          kept = @kept.fetch(name)
          text = kept.saved
          kept.clear if text && text == @folder.call(backup).read
        end
        drop_mark
      end

      def drop_mark
        note = @folder.call(NOTE)
        lines = note.read.to_s.lines
        note.write((lines - [UNDER_WAY]).join) if lines.include?(UNDER_WAY)
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

      # Writes the backups, and the note naming them with the mark, and
      # answers the note without it, to write once every file is emptied.
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
        finished = "cleared=#{time.iso8601}\n#{saved.join}"
        note.write(finished + UNDER_WAY)
        finished
      end
    end
  end
end
