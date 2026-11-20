# frozen_string_literal: true

module DotPopper
  module Monetization
    module Receipt
      # The App Store: StoreKit 2's signed transaction, a JWS whose x5c chain
      # runs from a leaf Apple marks for signing receipts
      # (1.2.840.113635.100.6.11.1), through an intermediate it marks as its
      # WWDR CA (1.2.840.113635.100.6.2.1), to a pinned root; its ES256
      # signature by the leaf; and for this app and product, not revoked.
      # The chain is judged at the transaction's own signedDate, since a
      # device's clock proves nothing either way, and with no revocation
      # check, which would need the network. These are the checks Apple's
      # App Store Server Library makes, less the online ones.
      module Apple
        LEAF = "1.2.840.113635.100.6.11.1"
        INTERMEDIATE = "1.2.840.113635.100.6.2.1"

        module_function

        def valid?(jws, trust)
          return false if trust.apple_roots.empty?

          Receipt.load_openssl
          head64, body64, signature64 = jws.split(".")
          header = JSON.parse(decode(head64))
          return false unless header["alg"] == "ES256"

          leaf, intermediate, = Array(header["x5c"]).map { OpenSSL::X509::Certificate.new(it.to_s.unpack1("m").to_s) }
          return false unless leaf && intermediate && marked?(leaf, LEAF) && marked?(intermediate, INTERMEDIATE)

          transaction = JSON.parse(decode(body64))
          return false unless chained?(leaf, intermediate, trust, Time.at(Integer(transaction.fetch("signedDate")) / 1000r))
          return false unless leaf.public_key.verify("SHA256", der(decode(signature64)), "#{head64}.#{body64}")

          transaction["bundleId"] == trust.app_id && transaction["productId"] == trust.product_id && transaction["revocationDate"].nil?
        rescue StandardError, ScriptError
          false
        end

        def chained?(leaf, intermediate, trust, at)
          store = OpenSSL::X509::Store.new
          trust.apple_roots.each { store.add_cert(OpenSSL::X509::Certificate.new(it)) }
          store.time = at
          store.verify(leaf, [intermediate])
        end

        def marked?(certificate, oid) = certificate.extensions.any? { it.oid == oid }

        def decode(text) = text.to_s.tr("-_", "+/").then { it + ("=" * (-it.size % 4)) }.unpack1("m").to_s

        # A JWS's raw r and s, as the DER that OpenSSL verifies.
        def der(raw)
          return "" unless raw.bytesize == 64

          OpenSSL::ASN1::Sequence.new([raw[0, 32], raw[32, 32]].map { OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(it.to_s, 2)) }).to_der
        end
      end

      # Apple Root CA - G3, from https://www.apple.com/certificateauthority/
      # (SHA-256 63343ABF B89A6A03 EBB57E9B 3F5FA7BE 7C4F5C75 6F3017B3
      # A8C488C3 653E9179), which certifies StoreKit 2's signed transactions.
      APPLE_ROOT_G3 = <<~BASE64.unpack1("m").freeze
        MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9v
        dCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UE
        CgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2
        WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmlj
        YXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqG
        SM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxE
        tX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNC
        MEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0P
        AQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3m
        eoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkL
        F1vLUagM6BgD56KyKA==
      BASE64

      # What a build sold through Apple's stores trusts (the App Store's and
      # the Mac App Store's): StoreKit 2's transactions chained to Apple's
      # root, and nothing else.
      APPLE = Trust.new(apple_roots: [APPLE_ROOT_G3].freeze, play_keys: [].freeze, app_id: APP_ID, product_id: PRODUCT_ID,
                        windows_license: false)
    end
  end
end
