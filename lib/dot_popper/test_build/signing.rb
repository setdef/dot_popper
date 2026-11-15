# frozen_string_literal: true

module DotPopper
  module Continuity
    # Signing, which only the test build's fakes do, with its test keys: a
    # build for sale verifies what setdef signed and signs nothing.
    module Ed25519
      # The DER prefix of a raw 32-byte private seed (PKCS #8), as OpenSSL
      # reads one.
      PRIVATE_DER = ["302e020100300506032b657004220420"].pack("H*").freeze

      module_function

      # +seed+'s (32 bytes) signature over +message+.
      def sign(seed, message)
        require "openssl"
        OpenSSL::PKey.read(PRIVATE_DER + seed.b).sign(nil, message.b)
      end

      # The public key of +seed+.
      def public_key(seed)
        require "openssl"
        OpenSSL::PKey.read(PRIVATE_DER + seed.b).public_to_der[-32..].to_s
      end
    end

    class Certificate
      # A certificate for +public_key+ signed by +root_seed+, as the test
      # build's fake setdef server shows one.
      def self.issue(root_seed, purpose, public_key)
        body = MAGIC + [VERSION].pack("C") + id_of(Ed25519.public_key(root_seed)) + purpose + public_key
        body + Ed25519.sign(root_seed, SIGNING_LABEL + body)
      end
    end

    class LicenseKey
      # A key for a fresh random id, signed by +seed+, as the test build's
      # fake checkout issues one.
      def self.issue(seed, id: Random.bytes(16))
        new(id:, signature: Ed25519.sign(seed, LABEL + [VERSION].pack("C") + id))
      end
    end
  end
end
