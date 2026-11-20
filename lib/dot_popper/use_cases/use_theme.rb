# frozen_string_literal: true

module DotPopper
  module UseCases
    # Using a theme: which themes a player has is Gameplay and Metagame's
    # (+saved_themes+, SavedThemes, which keeps which are released and which the
    # player chose), and using one other than the ordinary is Pro's
    # (+entitlement+, Entitlement). A Free player sees every theme, and is
    # told of a new one, but uses the ordinary theme, and choosing another
    # leads to the offer of Pro instead. Themes are named by their keys
    # (Theme#key); what each draws is the presentation's.
    class UseTheme
      def initialize(saved_themes:, entitlement:)
        @saved_themes = saved_themes
        @entitlement = entitlement
        refresh
      end

      # The current theme's key, which changes only when the player uses
      # one or #refresh takes it up, between games.
      attr_reader :current

      # What choosing the theme +key+ would lead to (#call), as the
      # new theme card's switch says before it is pressed: :offer for a
      # Free player, the offer of Pro instead; :same when it is already
      # current or not open to use; or :use.
      def choice(key)
        return :offer if locked?

        key && !same?(key) ? :use : :same
      end

      # The player chose the theme +key+: :offer for a Free player, who is
      # offered Pro instead; :same when it is already current or not open
      # to use; or :used, and it is current from now on.
      def call(key)
        return :offer if locked?
        return :same if same?(key)

        @saved_themes.use(key)
        refresh
        :used
      end

      # Takes up which theme is current: the one a Pro player chose, and
      # for a Free player the ordinary one.
      def refresh
        @current = locked? ? @saved_themes.ordinary : @saved_themes.chosen
      end

      private

      def same?(key) = key == current || !@saved_themes.open?(key)

      # Whether choosing a theme leads to Pro, as for a Free player.
      def locked? = !@entitlement.pro?
    end
  end
end
