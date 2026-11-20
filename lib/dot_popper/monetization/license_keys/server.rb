# frozen_string_literal: true

module DotPopper
  module Monetization
    module LicenseKeys
      # The port to setdef's own server for where a license key is
      # (POST /licenses, POST /license_checks), answering a Network::Reply.
      # Server is the adapter for the real one, by Network::Link. A
      # replacement server is never asked: it is setdef's, whatever server
      # friend groups use.
      class Server
        # What setdef's server is asked of license keys; #ask makes requests
        # only from these.
        REQUESTS = [
          Network::Request.new(kind: :license_entry, verb: :post, path: "/licenses", feature: "license keys",
                               body: { key: Network::Field.new(what: "the license key the player pasted", label: :license_key),
                                       secret: Network::Field.new(what: "32 random bytes this device chose, which the server keeps only as a SHA-256", label: :license_key),
                                       nonce: Network::Field.new(what: "32 random bytes, new for each request, which the server signs", label: :license_key) },
                               happens: "When a player enters a license key, and at each start until setdef's server has answered, so the key moves to this device. Never on a copy sold by a store."),
          Network::Request.new(kind: :license_check, verb: :post, path: "/license_checks", feature: "license keys",
                               body: { key_id: Network::Field.new(what: "the license key's id, its first part", label: :license_key),
                                       secret: Network::Field.new(what: "this device's current secret for the key", label: :license_key),
                                       next: Network::Field.new(what: "32 random bytes this device chose as its next secret", label: :license_key),
                                       nonce: Network::Field.new(what: "32 random bytes, new for each request, which the server signs", label: :license_key) },
                               happens: "Once each time the game starts, on a device holding a license key, to learn whether the key has moved to another device.")
        ].to_h { [it.kind, it] }.freeze

        def initialize(link) = @link = link

        # +due+ is License::Due.
        def ask(due) = @link.call(Network::Job.of(REQUESTS.fetch(due.kind), body: due.body), nil)
      end
    end
  end
end
