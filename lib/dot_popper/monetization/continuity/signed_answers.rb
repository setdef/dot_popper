# frozen_string_literal: true

module DotPopper
  module Monetization
    module Continuity
      # The proof setdef's server signs with its online key, which a pinned
      # root certifies (Certificate::PROOF), and that key itself, which
      # LicenseKeys::Verdict also checks. An answer that fails any check is
      # no answer at all.
      module SignedAnswers
        PROOF = Certificate::PROOF

        module_function

        # 32 fresh bytes from a secure source: a nonce, or a device's secret.
        def fresh
          require "securerandom"
          SecureRandom.bytes(32)
        end

        # Whether +body+ (the parsed JSON of a 200 from GET /proof) proves
        # setdef's server answered +nonce+ (the server's docs/api.md,
        # "Verifying, in the game").
        def proof?(body, nonce, pins = PINNED)
          return false unless body.is_a?(Hash) && body["nonce"] == Continuity.hex(nonce)

          key = online_key(body, pins) or return false
          signature = Continuity.unhex(body["signature"], 64) or return false
          Ed25519.verify(key, signature, PROOF + nonce)
        end

        # The online key that +body+'s certificate carries, if a root of
        # +pins+ certified it for proof.
        def online_key(body, pins)
          bytes = Continuity.unhex(body["certificate"], Certificate::SIZE) or return nil
          Certificate.verified(bytes, roots: pins.roots, purpose: PROOF)&.public_key
        end
      end
    end
  end
end
