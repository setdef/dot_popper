# frozen_string_literal: true

module DotPopper
  module Composition
    class Root
      # What the apple part answers, in a build that carries it: the App
      # Store's and the Mac App Store's builds trust Apple's receipts alone
      # (Root.receipt_trust).
      module AppleChoices
        CHANNELS = [ReleaseEngineering::Build::APP_STORE, ReleaseEngineering::Build::MAC_APP_STORE].freeze

        def receipt_trust(settings) = CHANNELS.include?(settings.channel) ? Monetization::Receipt::APPLE : super
      end
      singleton_class.prepend(AppleChoices)
    end
  end
end
