# frozen_string_literal: true

module DotPopper
  module Monetization
    # A store's signed record of a purchase of Pro, which the game checks by
    # itself, offline, each time the store hands it one (ADR-0010).
    # Nothing the game writes can stand in for
    # one: an edited file, a saved yes or a number never verifies.
    #
    # The app's host passes a receipt to the game as text, in one of three
    # forms, after the store's own name:
    #
    #   apple:<JWS>                 StoreKit 2's signed transaction
    #                               (VerificationResult#jwsRepresentation),
    #                               ES256, certified up to Apple Root CA - G3
    #   play:<JSON>:<signature>     Play Billing's purchase: its original JSON
    #                               and its RSA signature (PKCS #1 v1.5,
    #                               SHA-1) by the app's own Play key, both in
    #                               standard Base64
    #   microsoft:<token>:<SKU>     the Microsoft Store's license for the
    #                               add-on, which is Windows' word and no
    #                               signature (Microsoft), taken only by the
    #                               Microsoft Store build
    #
    # Anything that goes wrong is a receipt that does not verify, never an
    # error.
    module Receipt
      # What a build accepts a receipt from: the one +store+ whose receipts
      # it takes (Apple, Play or Microsoft, each the code that checks its
      # own store's receipts, or nil for none), the +keys+ that store's
      # receipts must be proven by (Apple's: DER root certificates a
      # StoreKit transaction must chain to; Play's: DER public keys a
      # purchase must be signed by; the Microsoft Store's: none, since its
      # word is Windows'), and the app's +app_id+ (its bundle ID and package
      # name) and the +product_id+. A receipt of any other store does not
      # verify.
      Trust = Data.define(:store, :keys, :app_id, :product_id)

      APP_ID = "com.setdef.DotPopper"
      PRODUCT_ID = "com.setdef.dotpopper.pro"

      # What a build sold through no store trusts: no receipt at all (the
      # website's, whose copies prove Pro by license key). Each store's own
      # is beside its check (APPLE, PLAY, MICROSOFT_STORE).
      NOTHING = ([] #: Array[String]
                ).freeze
      NONE = Trust.new(store: nil, keys: NOTHING, app_id: APP_ID, product_id: PRODUCT_ID)

      # Whether +text+ is a receipt for Pro that +trust+ accepts: one of its
      # own store's, after that store's name, which its store proves.
      def self.valid?(text, trust)
        store = trust.store or return false
        name, rest = text.to_s.strip.split(":", 2)
        name == store.name_in_receipts && store.valid?(rest.to_s, trust)
      end

      # OpenSSL and JSON, loaded on first use, as Continuity::Ed25519 does,
      # so a game that is never handed a receipt never loads them.
      def self.load_openssl
        require "openssl"
        require "json"
      end
    end
  end
end

# Apple's and Play's checks and the test key need OpenSSL and JSON, and
# are left out of the rules' type check (Steepfile).
%w[apple play microsoft].each { require_relative "receipt/#{it}" }
