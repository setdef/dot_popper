# frozen_string_literal: true

module DotPopper
  module UseCases
    # Buying Pro, from the offer: asking the store (+store+, the
    # Store port) for the price as the offer opens, Buy, and Restore
    # Purchases; once the player has Pro (+entitlement+, Entitlement), Buy
    # does nothing. The store is heard only while no game
    # is in play (+game_flow+, GameFlow), so a purchase never lands mid-game.
    # When Pro arrives (Entitlement::ProGranted, which the composition
    # root subscribes it to), the player's friend groups (+friend_groups+)
    # hear of every achievement already earned (+achievements+,
    # Achievements), which a Free player's games kept but never reported.
    # It is the offer's one way to the store and to whether the player
    # has Pro, so no screen holds either.
    class BuyPro
      def initialize(store:, entitlement:, game_flow:, achievements:, friend_groups:)
        @store = store
        @entitlement = entitlement
        @game_flow = game_flow
        @achievements = achievements
        @friend_groups = friend_groups
      end

      # Whether Pro can be offered: where there is a store, to a player
      # who has not bought it.
      def offered? = @store.offered? && !owned?

      # Whether the store sells Pro here.
      def sold? = @store.sold?

      # The price the store gave, or nil before it has.
      def price = @store.price

      # What the offer says of buying: :thanks once the player has Pro,
      # which the offer thanks them for in place of selling it; until
      # then, how the store is getting on (:ready, :waiting and the like).
      def status = owned? ? :thanks : @store.status

      # The offer opened: asks the store for the price and what this
      # player owns, or asks again if an earlier request went unanswered.
      def open = @store.connect

      # Buy, where Pro is sold and not yet bought: with the store's price,
      # a purchase, and before one has come, Buy's "Try again", which asks
      # again. Says whether it was taken.
      def buy
        return false if owned? || !@store.sold?

        @store.price ? @store.buy : @store.connect
        true
      end

      def restore = @store.restore

      # Hears the store, +seconds+ on, unless a game is in play.
      def update(seconds)
        @store.update(seconds) unless @game_flow.playing?
      end

      # Pro arrived: what was earned while Free counts now.
      def call(_granted)
        @friend_groups.report_achievements(@achievements.earned)
      end

      private

      # Whether the player has Pro, which the offer thanks them for.
      def owned? = @entitlement.pro?
    end
  end
end
