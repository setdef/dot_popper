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
          Monetization::Continuity::Watch.new(server: fake, connectivity: fake, gone: @gone, license:, license_server: fake, today: settings.today, pins:)
        end
      end
      prepend TestBuildParts

      # What a test build trusts and obeys in place of a build for sale's,
      # each giving the shared answer for a build with a channel:
      # - the test keys, and only the fake store's receipts (Root.pins,
      #   Root.receipt_trust), and license keys (Root.license_keys?);
      # - DOT_POPPER_PRO=1 stands in for a purchase, to try Pro out, and
      #   DOT_POPPER_PRO=0 is a free player; unset, as the shared code
      #   answers (Root.forced_pro?);
      # - who plays (Root.player?): not the autoplay bot, and not a GUI
      #   scenario unless it sets DOT_POPPER_FREE_GAMES to try the limit;
      # - DOT_POPPER_FREE_GAMES starts a new save with that many first
      #   games and that many a day (Root.starting_free_games).
      module TestBuildChoices
        STARTING = "DOT_POPPER_FREE_GAMES"

        def pins(settings) = settings.store_build? ? super : Monetization::Continuity::TEST_PINS
        def license_keys?(settings) = settings.store_build? ? super : true
        def receipt_trust(settings) = settings.store_build? ? super : Monetization::Receipt::TEST

        def forced_pro?(settings, platform)
          value = settings.fetch("DOT_POPPER_PRO")
          settings.store_build? || value.empty? ? super : value == "1"
        end

        def player?(settings)
          return super if settings.store_build?
          return false if settings.flag?("DOT_POPPER_AUTOPLAY")

          settings.fetch("DOT_POPPER_SCENARIO").empty? || !settings[STARTING].nil?
        end

        def starting_free_games(settings)
          return super if settings.store_build?

          Integer(settings.fetch(STARTING), exception: false)
        end
      end
      singleton_class.prepend(TestBuildChoices)
    end
  end
end
