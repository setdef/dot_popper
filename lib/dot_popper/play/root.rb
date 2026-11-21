# frozen_string_literal: true

module DotPopper
  module Composition
    class Root
      # What the play part answers, in a build that carries it: the Google
      # Play build trusts Google's receipts alone (Root.receipt_trust).
      module PlayChoices
        def receipt_trust(settings) = settings.channel == ReleaseEngineering::Build::GOOGLE_PLAY ? Monetization::Receipt::PLAY : super
      end
      singleton_class.prepend(PlayChoices)
    end
  end
end
