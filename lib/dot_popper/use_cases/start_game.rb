# frozen_string_literal: true

module DotPopper
  module UseCases
    # Starting a game: Play, and the opening of the tutorial, whose game
    # begins as it opens (ADR-0016). It is the one way into a game, and it
    # spends exactly one free game on each (ADR-0012): with none left, no
    # game starts, and it answers the offer of Pro, which the screen
    # carries out. Games run out only where they are counted, which is
    # only for a Free player where Pro is offered (FreeGames.metered?), so
    # no game left means Pro is offered. A game is
    # Gameplay's (+cabinet+, a Cabinet) and the count of free games
    # Monetization's (+free_games+, FreeGames), so neither knows of the
    # other. It holds the cabinet's +starter+ (Cabinet::Starter), which the
    # cabinet hands out once, so it alone can start a game there.
    class StartGame
      def initialize(cabinet:, free_games:, starter: cabinet.starter)
        @cabinet = cabinet
        @starter = starter
        @free_games = free_games
      end

      # Whether Play would find no game left to start, and lead to the
      # offer of Pro instead, for Play's word.
      def none_left? = !@free_games.can_play?

      # How many games the player has left, or nil where none are counted
      # (FreeGames#metered?), for Play's word; and how many each day gives.
      def left = (@free_games.left if @free_games.metered?)
      def daily = @free_games.daily

      # Starts a game from Home and spends a free game on it: in play at
      # once, or with +opening+ (a Stack), paused before its clock first
      # runs, with those dots first, for the tutorial to play over.
      # Answers :started; :offer when the player has no game left, from
      # Home or anywhere else, and nothing starts; or :not_home away from
      # Home with a game left, where nothing is spent, and a game starts
      # once Home is shown.
      def call(opening = nil)
        return :offer if none_left?
        return :not_home unless @cabinet.state.is_a?(Cabinet::Home)
        return :offer unless @free_games.spend!

        opening ? @starter.paused(opening) : @starter.game
        :started
      end
    end
  end
end
