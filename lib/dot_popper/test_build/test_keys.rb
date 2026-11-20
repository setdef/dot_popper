# frozen_string_literal: true

module DotPopper
  module Monetization
    module Continuity
      # Throwaway keys, made for the test build's fakes, whose private seeds
      # ship in the test build (TestKeys), so they prove nothing outside it.
      TEST_PINS = Pins.of(
        roots: %w[e867ed3d37bcc7948f7c2ca7d57e7d2587dc93c53a9f6ece29f2d41bae20621b
                  a52b818651332dc6c25404e5abf90809d2c7b276e00a1f265fd3980e4aaa7dad],
        license_keys: %w[e6fe40875397014384ed6d74414bbd1f645476478311f8c6061bc2772cbaca1a
                         8aac532eb028225861e7e98055f98b5e06d7586fd07fbf5c4bca51cc7d4c8d90]
      )

      # The private seeds behind TEST_PINS, made for this purpose and public
      # on purpose: the test build's fakes sign with them, so a key the fake
      # seller issues and an answer the fake server gives verify by the very
      # code a real one does. Nothing signed by them is trusted by a build
      # for sale, which pins setdef's real keys.
      module TestKeys
        ROOT = ["67191f818614ee7f90d9da198e38e9476e5b56ef3be77cb62b18081c8c10e5b6"].pack("H*").freeze
        LICENSE = ["a32a9625168379d464511c036f8d3366c9535dead19aa8b80372034e07d7e6c2"].pack("H*").freeze
        ONLINE = ["b4452db4d792a54c54b4ba6ef820e608af96cd3572a5c1411efa16a592e7281f"].pack("H*").freeze

        # License keys signed by the test keys once, outside the game, and
        # kept as they were made, since no code in the game makes a license
        # key: four by LICENSE, which a test build trusts, and one each by
        # ROOT and ONLINE, which sign no license key any build trusts.
        LICENSE_KEYS = {
          license: %w[DP-04ZRB-V47SS-7X136-97APV-33XAJ-R6620-Y7DGH-H1X9S-4SN3C-7QC97-5S9K9-MRCCQ-25PX0-FBM61-R0Z49-1TK5N-SRFC4-THQMH-V17NN-8J99H-793ZY-QQ85A-7YRX0-BFZ9D-JD2N8-QVB0C
                       DP-062HT-M2CMS-SPQVF-9BC10-DJ4G8-CA72G-JEJ0M-4FQAP-JR07Z-5PV1K-XCDEA-QHS06-M78GY-Y7AKQ-NS6NE-1S1H3-DXZ60-QT92M-813VT-AJCB9-7RZ6P-NH9QR-114RZ-Y12FC-D4NDY-E540W
                       DP-04TZ5-K67J5-KBV7W-D0EYS-25PXR-5W3AX-V93J7-00ET2-041CY-JWMHB-ZX6TD-8D0WY-AC4XR-9PT9G-KP75X-3EPVZ-44XZY-9PC0C-EGF61-J1FYD-WYPJ5-3HTHQ-XQC76-R126J-7AVDH-2C004
                       DP-047DK-8ZBFE-Z4NKJ-NNRRS-VF2DJ-JJAYQ-M4CNN-JFPFA-9P91G-6DE6G-9X89M-34D2F-WVNM5-0JEBP-DAKQ0-HHGJP-66G42-YWJVF-2ZHMN-26SD9-98K0F-5F5ZA-VDNSP-XEBN6-R9Q2V-2Y21R].freeze,
          root: %w[DP-07R2R-548SY-V9YB2-4FKKC-JWX0Y-CEEFN-7FC59-0A71C-FEP87-8R0VS-VW457-X7FWY-R0BX6-6TRZ7-R2RHG-DKPQ4-8P6YB-P8R46-Y99HW-M88AE-44VAJ-7SPN0-P1BBW-TKG0V-NC05Q-8Q71R].freeze,
          online: %w[DP-07SQW-B1JSZ-0A8AA-JQY25-RCVHJ-6R1NP-6VYBV-VE22J-N8703-4A9VC-AC68W-9Y7NJ-R7G4W-PKTQG-GKMF2-SWDTP-YE2MR-Q17EM-6QKMA-P505T-XWS0Z-A74ZE-XY99H-5RTMC-7HGV0-V6C0C].freeze
        }.freeze

        # The +index+th key signed by +signer+ (:license, :root or :online).
        def self.license_key(signer = :license, index = 0) = LicenseKeys::LicenseKey.parse(LICENSE_KEYS.fetch(signer).fetch(index))

        # The online key's certificate, by the test root.
        def self.online_certificate
          @online_certificate ||= Certificate.issue(ROOT, Certificate::PROOF, Ed25519.public_key(ONLINE)).freeze
        end
      end
    end
  end
end
