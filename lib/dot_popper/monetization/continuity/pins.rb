# frozen_string_literal: true

module DotPopper
  module Monetization
    module Continuity
      # The keys a build trusts for setdef's answers, pinned in its code,
      # since a shipped copy can never learn new ones: the +roots+ that
      # certify the server's online key (GET /proof, and the answers about
      # license keys), the main one and a sealed backup, as 32-byte Ed25519
      # public keys. Nothing a server sends can add to them. The keys that
      # sign license keys are the license keys' own
      # (LicenseKeys::SIGNING_KEYS).
      class Pins < Data.define(:roots)
        def self.of(roots:) = new(roots: roots.map { [it].pack("H*").freeze }.freeze)
      end

      # setdef's own proof roots: the main one and a sealed backup (root ids
      # 8336ad85d326749b and ad88ca8070d052b7).
      SETDEF_PINS = Pins.of(
        roots: %w[79d5734924f1f17b86eec3d20cb05bcd88996cdac0ade9e76652e23890b0936b
                  acc38f5061fb9de2b57dff17f2f6c51ca585b96261805a5323b1022607c82253]
      )

      # What a build for sale trusts: setdef's real keys.
      PINNED = SETDEF_PINS

      # Whether +pins+ are setdef's real keys, so the server may be asked.
      def self.live?(pins = PINNED) = pins.equal?(SETDEF_PINS)
    end
  end
end
