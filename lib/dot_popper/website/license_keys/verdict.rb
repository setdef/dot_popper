# frozen_string_literal: true

module DotPopper
  module Monetization
    module LicenseKeys
      # What setdef's server signs, with the online key a pinned root
      # certifies (Continuity::SignedAnswers.online_key), in answer to
      # POST /licenses or /license_checks: whether a license key is still
      # this device's. An answer that fails any check is no answer at all.
      module Verdict
        LABEL = Continuity.label("dot-popper/license-check/v1")
        VERDICTS = { "current" => 1, "moved" => 0 }.freeze

        module_function

        # The verdict, :current or :moved, that +body+ (the parsed JSON of a
        # 200) signs for the license key +id+ in answer to +nonce+, or nil.
        def of(body, id, nonce, pins = Continuity::PINNED)
          return nil unless body.is_a?(Hash) && VERDICTS.key?(body["verdict"]) && body["nonce"] == Continuity.hex(nonce)
          return nil unless body["key_id"] == Continuity.hex(id)

          online = Continuity::SignedAnswers.online_key(body, pins) or return nil
          signature = Continuity.unhex(body["signature"], 64) or return nil
          Continuity::Ed25519.verify(online, signature, message(body["verdict"], id, nonce)) ? body["verdict"].to_sym : nil
        end

        def message(verdict, id, nonce) = LABEL + nonce + id + [VERDICTS.fetch(verdict)].pack("C")
      end
    end
  end
end
