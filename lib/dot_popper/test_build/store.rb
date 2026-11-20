# frozen_string_literal: true

module DotPopper
  module Monetization
    class Store
      # A test build's store on +platform+ (Platform), in place of Store.for's
      # choice by the channel: on a phone the +fake+ store port, and on a
      # computer the +website+ store with the test build's checkout, as
      # computers' copies will mostly be sold; the fake store port where no
      # +website+ is given.
      def self.of_test_build(platform, fake:, entitlement:, website: nil)
        return new(port: fake, entitlement:) if platform.phone_host? || website.nil?

        website.call
      end
    end
  end
end
