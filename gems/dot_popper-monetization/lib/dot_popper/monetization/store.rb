# frozen_string_literal: true

module DotPopper
  module Monetization
    # The store behind Pro, Monetization's port to it (doc/design/store-and-pro.md). Neither
    # Lota nor LÖVE knows a store, so this works as sharing does: the game
    # opens a URL in
    # its own SCHEME, and the store's answer comes back in a small file,
    # named in the URL, rewritten whole, which #update reads a few times a
    # second, outside a game. Each answer is the whole state, so one that
    # is missed costs nothing: whether the player owns the product, the
    # store's signed receipt for it if so, its price as the store writes
    # it, how the last request went, and that request's number.
    #
    # That URL and that file are the port: +port+ answers open(url) with
    # whether it was taken, and read, remove and path for the answer.
    # NativeStore is the adapter for the app's host, which catches the URL
    # before it leaves the app and asks StoreKit or Play Billing. Which one
    # is chosen once, by Store.for, at the composition root
    # (Composition::Root), from the build; nothing above the port differs
    # between them (the store contract, test/monetization/store_contract.rb).
    # +entitlement+ (Entitlement) is Pro the moment the store hands over a
    # receipt that verifies (Receipt); an answer's "owned" alone proves
    # nothing. Nothing is kept: each launch asks the store again, which
    # answers from its own cache, offline too. A store that later says
    # otherwise in the same run, as after a refund, locks nothing
    # (ADR-0010).
    class Store
      SCHEME = "dotpopper-store"
      # The one product, as App Store Connect and the Play Console must
      # name it (and ios/store_check's StoreKit configuration file).
      PRODUCT_ID = "com.setdef.dotpopper.pro"
      # How often, in seconds, the answer file is read.
      EVERY = 0.25
      # What a query value keeps as it is, as in a share sheet's URL.
      UNRESERVED = /[^A-Za-z0-9\-._~]/n
      # The hosts' states that a screen tells apart; any other is :failed.
      STATES = { "loading" => :loading, "working" => :busy, "ready" => :ready, "pending" => :pending,
                 "canceled" => :ready, "restored" => :ready, "none" => :none, "failed" => :failed,
                 "unavailable" => :unavailable }.freeze

      attr_reader :status, :price

      # The store for the build sold through +channel+ (a name the
      # composition root gives) on +platform+ (Platform), chosen once:
      # +website+, called, for a build sold through setdef's website, where
      # the platform allows website sales (never iOS, Apple 3.1.1); the
      # +native+ port where the host has a store, or where the channel is
      # that computer's own store's (Platform#own_store), whose host is a
      # small program shipped beside the game (Shell::StoreHelper), since
      # neither Lota nor LÖVE can call StoreKit or Windows.Services.Store;
      # and else none, which offers nothing, so no one is offered a purchase
      # that cannot complete. The composition root gives +website+ only to
      # the website's build.
      def self.for(platform, native:, entitlement:, channel:, website: nil)
        return website.call if website && platform.website_sales?
        return new(port: native, entitlement:) if platform.phone_host? || platform.own_store == channel

        NoStore.new
      end

      # The URL asking the host to do +action+ (:open, :buy, :restore) as
      # request number +number+, answering in the file at +path+.
      def self.url(action, number, path)
        query = { n: number, product: PRODUCT_ID, file: path }.map { |key, value| "#{key}=#{encode(value)}" }.join("&")
        "#{SCHEME}://#{action}?#{query}"
      end

      def self.encode(value) = value.to_s.b.gsub(UNRESERVED) { format("%%%02X", it.ord) }

      def initialize(port:, entitlement:)
        @port = port
        @entitlement = entitlement
        @status = :loading
        @price = nil
        @number = 0
        @since = 0.0
      end

      def offered? = true
      # A store's purchase is restored (Apple 3.1.1), and it sells for as
      # long as the store lists it.
      def sold? = true

      # Asks the store for the price and what this player owns: at launch,
      # so a purchase on another device or after a reinstall simply
      # appears, and each time the offer opens, which also clears a request
      # the store never answered. An old answer is thrown away first.
      def connect
        return if @entitlement.pro?

        @port.remove
        request(:open, :loading)
      end

      def buy
        request(:buy, :busy) if price && @status != :busy
      end

      def restore
        request(:restore, :busy) unless @status == :busy
      end

      # Reads the store's answer, EVERY so often, as the frames pass.
      def update(seconds)
        @since += seconds
        return if @since < EVERY

        @since = 0.0
        heard(@port.read)
      end

      private

      def request(action, status)
        @number += 1
        @status = @port.open(self.class.url(action, @number, @port.path)) ? status : :unavailable
      end

      def heard(text)
        return unless text

        answer = text.lines.to_h { (_ = it.chomp.split("=", 2)) }
        @entitlement.verify_receipt(answer["receipt"]) if answer["receipt"] && !@entitlement.pro?
        return unless answer["answer"].to_i >= @number

        @price = answer["price"] unless answer["price"].to_s.empty?
        @status = STATES.fetch(answer["state"], :failed)
      end
    end

    # The adapter for the app's host: its URLs go out by +opener+ and its
    # answers come back in +answers+, a file the host rewrites.
    class NativeStore < Data.define(:opener, :answers)
      def open(url) = opener.open(url)
      def read = answers.read
      def remove = answers.remove
      def path = answers.path
    end

    # Where there is no store, as on a computer whose build names a channel
    # nobody has built: nothing is offered.
    class NoStore
      def offered? = false
      def sold? = false
      def status = :unavailable
      def price = nil
      def connect = nil
      def buy = nil
      def restore = nil
      def update(_seconds) = nil
    end
  end
end
