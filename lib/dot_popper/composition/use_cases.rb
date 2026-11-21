# frozen_string_literal: true

require_relative "../use_cases"
require_relative "../presentation"

module DotPopper
  module Composition
    # The use cases (ADR-0019; doc/architecture.md), made from the objects of the game's areas
    # that each joins, and subscribed to what each hears, here and nowhere
    # else: FinishGame hears the rules' events, before anything made after
    # it, and BuyPro hears Pro arrive (Entitlement::ProGranted). Answers
    # them by the names Presentation::Show takes, with the offer's second
    # action for the store (offer_second). UseTheme is not among
    # them: it hears nothing, and is made before the rest, since the drawing context
    # and the sound player take the current theme from it before anything
    # is drawn. +starter+ is the game flow's one Starter, which StartGame
    # holds.
    def self.use_cases(game_flow:, free_games:, entitlement:, store:, achievements:, saved_stats:, friend_groups:,
                       starter: game_flow.starter)
      buy_pro = UseCases::BuyPro.new(store:, entitlement:, game_flow:, achievements:, friend_groups:)
      entitlement.subscribe(buy_pro)
      finish_game = UseCases::FinishGame.new(saved_stats:, achievements:, entitlement:, friend_groups:)
      game_flow.subscribe(finish_game)
      {
        start_game: UseCases::StartGame.new(game_flow:, free_games:, starter:),
        finish_game:,
        buy_pro:,
        join_or_create_friend_group: UseCases::JoinOrCreateFriendGroup.new(groups: friend_groups, entitlement:),
        view_achievements: UseCases::ViewAchievements.new(achievements:, entitlement:, saved_stats:, score_record: game_flow.score_record),
        offer_second: offer_second(store:, entitlement:)
      }
    end

    # What the offer of Pro offers besides Buy, for +store+ (Screens::Offer's
    # +offer_second+): nil, the offer's own Restore Purchases, unless a part
    # (Build::PARTS) answers for its store.
    def self.offer_second(store:, entitlement:) = nil
  end
end

DotPopper::ReleaseEngineering::Build::PARTS.each { require_relative "../#{it}/offer" }
