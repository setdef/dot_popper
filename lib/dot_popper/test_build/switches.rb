# frozen_string_literal: true

module DotPopper
  module Monetization
    # A test build's entitlement for tests and tools, which takes the fake
    # store's receipts (Receipt::TEST). Where a developer setting may change
    # what a player has (Pro without a purchase, the free-game limit), the
    # test build answers in the composition root's place (test_build/root.rb).
    class Entitlement
      def self.test = new(trust: Receipt::TEST)
    end
  end
end
