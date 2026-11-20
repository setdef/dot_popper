# frozen_string_literal: true

module DotPopper
  module Monetization
    # The test build's checkout: no browser and no payment, and at once a
    # real license key, one of those the test key the test build trusts
    # signed once (Continuity::TestKeys::LICENSE_KEYS), on the clipboard,
    # where an email's copy would put it. Paste license key then takes the
    # same road a bought key does.
    class FakeCheckout < Data.define(:clipboard)
      def buy
        clipboard.copy(Continuity::TestKeys::LICENSE_KEYS.fetch(:license).sample)
        :copied
      end
    end
  end
end
