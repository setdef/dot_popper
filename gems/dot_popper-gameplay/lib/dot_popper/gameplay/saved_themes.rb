# frozen_string_literal: true

module DotPopper
  module Gameplay
    # Which themes a player has, by key (Theme#key). A theme other than the
    # ordinary one exists to the player only once the server has released
    # it (#release), while online; from then on it is kept for good, on this
    # device, offline too. Once setdef has been gone GONE_DAYS, a theme also
    # opens on its date (Theme#opens_on), as the server would have released
    # it (ADR-0011). A newly released theme is told to the player once
    # (#new_theme, #told), and telling it never depends on buying anything.
    #
    # This keeps what the player chose (#chosen); which theme is current,
    # and that only Pro uses one other than the ordinary, is
    # UseCases::UseTheme's to say.
    #
    # It reads and writes its save file, themes.txt, as a ThemesFile, and
    # keeps of it only the themes this game knows.
    class SavedThemes
      # How long setdef must have been gone before a theme opens by its
      # date alone.
      GONE_DAYS = 180

      def initialize(file, themes: Theme::ALL)
        @file = file
        @themes = themes
        @released, @told, @chosen = read
      end

      # The ordinary theme's key.
      def ordinary = @themes.find(&:ordinary?)&.key || Theme::ORDINARY

      # The theme the player last chose and may still choose, or the
      # ordinary one.
      def chosen
        chosen = @chosen
        chosen && choices.include?(chosen) ? chosen : ordinary
      end

      # Every theme there is for this player, in the game's order: the
      # ordinary one and each released.
      def choices = @themes.select { it.ordinary? || @released.include?(it.key) }.map(&:key)

      # Whether the theme +key+ is open to this player; a Free player has it
      # open too, and only using it asks for Pro.
      def open?(key) = choices.include?(key)

      # Whether there is anything to choose among: not before a theme is
      # released.
      def offered? = choices.size > 1

      # The server's answer: every theme key released so far. Unknown keys
      # are ignored, for a game older than the server. A key once saved
      # stays, even if a later answer leaves it out. Says whether any was
      # new.
      def release(keys)
        fresh = keys.map(&:to_sym).select { |key| known?(key) } - @released
        return false if fresh.empty?

        @released += fresh
        save
        true
      end

      # Hears whether setdef is there (SetdefGone, SetdefHere): each check that leaves setdef gone opens the
      # themes whose dates have passed, once it has been gone long enough.
      def call(event)
        open_by_date(event.today, event.days) if event.is_a?(SetdefGone)
      end

      # Opens every theme whose date has come by +today+, once setdef has
      # been gone +gone_days+ of at least GONE_DAYS, as the server would
      # have released it. Says whether any was new.
      def open_by_date(today, gone_days)
        return false if gone_days < GONE_DAYS

        release(@themes.select { |theme| (day = theme.opens_on) && day <= today }.map(&:key))
      end

      # The first released theme not yet told, or nil.
      def new_theme = (@released - @told).first

      # The player has seen the theme +key+ announced, however they
      # answered.
      def told(key)
        @told |= [key]
        save
      end

      # Keeps the theme +key+ as the player's choice, if it is open to them.
      def use(key)
        return unless choices.include?(key)

        @chosen = key
        save
      end

      private

      def known?(key) = @themes.any? { it.key == key && !it.ordinary? }

      def read
        saved = ThemesFile.parse(@file.read)
        known = @themes.map(&:key)
        [saved.released & known, saved.told & known, saved.chosen]
      end

      def save = @file.write(ThemesFile.new(released: @released, told: @told, chosen: @chosen).to_s)
    end
  end
end
