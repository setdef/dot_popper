# frozen_string_literal: true

module DotPopper
  module Composition
    class Root
      # What a test build puts together in place of a build for sale's
      # (Root#store_for and the rest): the fake store, its scenarios' themes,
      # the fake setdef server and the fake website checkout, each only when
      # the build has no channel: with one, each gives the shared answer, so
      # a part loaded into a build for sale by mistake changes nothing.
      module TestBuildParts
        private

        # The test build's store (Store.of_test_build): the fake store, or
        # on a computer the website's with the fake checkout.
        def store_for(clipboard)
          return super if settings.store_build?

          fake = Monetization::FakeStore.new(file("fake_store.txt"), fails: Monetization::FakeStore.failure(settings.env))
          Monetization::Store.of_test_build(platform, entitlement:, fake:, website: -> { website_store(clipboard, Monetization::FakeCheckout.new(clipboard:)) })
        end

        # A scenario's released themes and theme, in place of the server's.
        def use_fixture(saved_themes, use_theme)
          return super if settings.store_build?

          keys = settings["DOT_POPPER_THEME_UNLOCKS"]
          saved_themes.release(keys.split(",")) if keys
          key = settings["DOT_POPPER_THEME"]&.to_sym or return

          use_theme.call(key)
        end

        def test_watch(license, pins)
          return super if settings.store_build?

          fake = Monetization::Continuity::FakeSetdef.new(file("fake_setdef.txt"), mode: Monetization::Continuity::FakeSetdef.mode(settings.env))
          Monetization::Continuity::Watch.new(server: fake, connectivity: fake, gone: @gone, license:, today: settings.today, pins:)
        end
      end
      prepend TestBuildParts

      # What a test build trusts in place of a build for sale's (Root.pins,
      # Root.receipt_trust): the test keys, and only the fake store's
      # receipts; with a channel, the shared answer.
      module TestBuildTrust
        def pins(settings) = settings.store_build? ? super : Monetization::Continuity::TEST_PINS
        def receipt_trust(settings) = settings.store_build? ? super : Monetization::Receipt::TEST
      end
      singleton_class.prepend(TestBuildTrust)
    end
  end
end
