# frozen_string_literal: true

module DotPopper
  module UseCases
    # A license key entered on the offer of Pro, on a copy the website's
    # store sells (+store+, WebsiteStore): pasted from the clipboard, or
    # typed on a computer's keyboard, which does nothing once the player
    # has Pro (+entitlement+, Entitlement). The offer's one way to the
    # website store's keys, so no screen holds the store.
    class EnterLicenseKey
      def initialize(store:, entitlement:)
        @store = store
        @entitlement = entitlement
      end

      # Paste license key: what is on the clipboard, entered as a key.
      def paste = @store.paste

      # A key typed as a license key; says whether it was taken.
      def type(key) = !@entitlement.pro? && @store.type(key)

      # The license key typed so far, or "".
      def typed = @store.typed
    end
  end

  module Presentation
    # The offer of Pro's second action on a website copy
    # (Screens::Offer#second), in place of Restore Purchases: Paste license
    # key, which enters what is on the clipboard, and a key typed on a
    # computer's keyboard, through +keys+ (UseCases::EnterLicenseKey); its
    # words, and the status line's while a key is being typed and as the
    # website store answers.
    class LicenseKeyEntry
      WORDS = {
        paste: "Paste license key", browser: "Finish in your browser. Your key comes by email.",
        copied: "Your license key is copied. Paste it here.", invalid: "That isn't a license key.",
        typing: "Key:", empty: "Copy your license key first.", same: "That key is already here.", not_sold: "Pro is no longer sold."
      }.freeze

      # Ctrl+V or Cmd+V pastes a license key. Then a letter, digit or
      # hyphen, alone or with Alt (Option types characters on a Mac), is
      # typed into one, whatever the key does on other screens, so a key's
      # letters are never shortcuts; with Ctrl or Cmd it is the system's
      # shortcut (select all, copy, quit), and types nothing. Backspace,
      # Delete or Enter edits or enters it, with any modifier keys held or
      # none. While a key is being typed, Space does nothing: a key's text
      # ignores spaces, so one typed as it is printed, in groups, never
      # closes the offer.
      CHARACTERS = [*("a".."z"), *("0".."9"), "minus"].map(&:to_sym).freeze
      KEY_BINDINGS = [
        KeyBinding.new(keys: :v, with: KeyBinding::COMMAND, does: :paste),
        KeyBinding.new(keys: CHARACTERS, does: :type),
        KeyBinding.new(keys: CHARACTERS, with: %i[alt], does: :type),
        KeyBinding.new(keys: %i[backspace delete enter], held_or_not: true, does: :type),
        KeyBinding.new(keys: :space, does: :typing?)
      ].freeze

      # The most of a key being typed that the status line shows.
      TAIL = 24

      def initialize(keys) = @keys = keys

      # The button's name, in the offer's plan and its controls.
      def name = :paste

      def label(_words) = WORDS.fetch(:paste)

      def key_bindings = KEY_BINDINGS

      # Paste license key: a key that is good is Pro at once, which is
      # announced as Pro arriving (Screens::Offer#call), with a tick of its
      # own as it is pressed (+sounds+).
      def press(_offer, sounds)
        @keys.paste
        sounds.play(:tick)
      end

      # Ctrl+V or Cmd+V: Paste license key; it takes the key.
      def paste(sounds)
        press(nil, sounds)
        true
      end

      # A key typed on a computer's keyboard (WebsiteStore#type).
      def type(key) = @keys.type(key)

      # Whether a license key is being typed.
      def typing? = !@keys.typed.empty?

      # The status line's words for the website store's +status+, or nil
      # where the offer's own words say it: "Key:" and the last of the key
      # while one is being typed.
      def status(status)
        return "#{WORDS.fetch(:typing)} #{tail}" if status == :ready && typing?

        WORDS[status]
      end

      private

      def tail
        typed = @keys.typed
        typed.length > TAIL ? "…#{typed[-TAIL..]}" : typed
      end
    end
  end

  module Composition
    # On a copy whose store is the website's, the offer's second action
    # is a license key's (Presentation::LicenseKeyEntry); any other store's
    # is the offer's own, Restore Purchases.
    module WebsiteOffer
      def offer_second(store:, entitlement:)
        return super unless store.is_a?(Monetization::WebsiteStore)

        Presentation::LicenseKeyEntry.new(UseCases::EnterLicenseKey.new(store:, entitlement:))
      end
    end
    singleton_class.prepend(WebsiteOffer)
  end
end
