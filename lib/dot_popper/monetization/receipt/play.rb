# frozen_string_literal: true

module DotPopper
  module Monetization
    module Receipt
      # Google Play: the purchase's JSON, signed by the app's Play key, for
      # this package and product, and purchased. Play's JSON gives
      # purchaseState 0 for a purchase and 4 for a pending one (inference,
      # from Play Billing's Purchase#getPurchaseState, which treats any
      # other value as purchased; only 0 is taken here).
      module Play
        module_function

        # +text+ is "<JSON>:<signature>", each in standard Base64.
        def valid?(text, trust)
          Receipt.load_openssl
          json64, signature64 = text.split(":", 2)
          json = json64.to_s.unpack1("m").to_s
          signature = signature64.to_s.unpack1("m").to_s
          return false unless trust.play_keys.any? { OpenSSL::PKey.read(it).verify("SHA1", signature, json) } # steep:ignore ArgumentTypeMismatch

          purchase = JSON.parse(json)
          products = Array(purchase["productIds"]) + Array(purchase["productId"])
          purchase["packageName"] == trust.app_id && products.include?(trust.product_id) && purchase.fetch("purchaseState", 0).zero?
        rescue StandardError, ScriptError
          false
        end
      end

      # The app's public key from the Play Console (Monetize, Monetization
      # setup, Licensing), Base64 as the Console shows it. Empty until the
      # maintainer pins it, so until then no Google Play purchase verifies;
      # script/check_build.rb fails a Google Play build while it is.
      PLAY_KEYS = ([] #: Array[String]
                  ).freeze

      # What the Google Play build trusts: purchases signed by the app's
      # Play key once pinned, and nothing else.
      PLAY = Trust.new(apple_roots: NOTHING, play_keys: PLAY_KEYS.map { it.unpack1("m").to_s }.freeze, app_id: APP_ID,
                       product_id: PRODUCT_ID, windows_license: false)
    end
  end
end
