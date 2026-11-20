# frozen_string_literal: true

module DotPopper
  module Monetization
    module LicenseKeys
      # setdef's own license-signing keys, pinned in the code: the main one
      # and a sealed backup, as 32-byte Ed25519 public keys. A license key
      # gives Pro only if one of the keys a build trusts signed it, and
      # nothing a server sends can add to them.
      SETDEF_SIGNING_KEYS = %w[779da5ce8b28fb9486667d610482a6abd416f94cc19721f3d1313475ea7b17c2
                               e40183ecb2bfcd2ff8f124d33a0ab32d8e96749a517a07d2237a88bacea908d0].map { [it].pack("H*").freeze }.freeze

      # What a build for sale trusts: setdef's real keys.
      SIGNING_KEYS = SETDEF_SIGNING_KEYS
    end
  end
end
