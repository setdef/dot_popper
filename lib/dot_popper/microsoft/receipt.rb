# frozen_string_literal: true

module DotPopper
  module Monetization
    module Receipt
      # The Microsoft Store: not a signature but Windows' own word. Its
      # purchase API, Windows.Services.Store, gives an app no receipt for an
      # add-on, only the licenses the user holds (StoreAppLicense's
      # AddOnLicenses), which Windows keeps and answers from. So the game
      # cannot check this one itself: it can only take Windows' answer, and
      # only by a road no text file is on (ADR-0010). The text is
      # "<in-app offer token>:<SKU Store ID>", as the Microsoft Store build's
      # helper (windows/store) writes it down its pipe.
      #
      # It proves Pro only under a Trust whose store is the Microsoft Store's
      # (Receipt.valid?), which only the Microsoft Store build holds, and
      # whose store's answers come only through that pipe
      # (Shell::StoreHelper). Every other build refuses it, so writing it
      # into a store answer file does nothing.
      module Microsoft
        # A SKU's Store ID: the product's twelve characters, a slash, and
        # the SKU's four.
        SKU = %r{\A[0-9A-Z]{12}/[0-9A-Z]{4}\z}

        module_function

        def name_in_receipts = "microsoft"

        def valid?(text, trust)
          token, sku = text.split(":", 2)
          token == trust.product_id && SKU.match?(sku.to_s)
        end
      end

      # What the Microsoft Store build trusts: Windows' word for its license,
      # and nothing that is signed, since no other store sells that build.
      MICROSOFT_STORE = Trust.new(store: Microsoft, keys: NOTHING, app_id: APP_ID, product_id: PRODUCT_ID)
    end
  end
end
