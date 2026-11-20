# frozen_string_literal: true

module DotPopper
  module Monetization
    module Continuity
      # The port to setdef's own server for what only it can prove: that it
      # is itself (GET /proof), answering a Network::Reply. SetdefServer is
      # the adapter for the real one, by Network::Link. A replacement server
      # is never asked: it is setdef's, whatever server friend groups use.
      class SetdefServer
        # What setdef's server is asked for its proof; #proof makes requests
        # only from these.
        REQUESTS = [
          Network::Request.new(kind: :proof, verb: :get, path: "/proof", feature: "checking that setdef's server is setdef's",
                               query: { nonce: Network::Field.new(what: "32 random bytes, new for each check, which the server signs", label: :other_usage) },
                               happens: "Once each time the game starts, on copies that can check, to tell setdef's server from anyone else at its address. Always to setdef's own server, never a replacement.")
        ].to_h { [it.kind, it] }.freeze

        def initialize(link) = @link = link

        def proof(nonce) = @link.call(Network::Job.of(REQUESTS.fetch(:proof), query: { nonce: Continuity.hex(nonce) }), nil)
      end

      # The port to the connectivity checks: three addresses run by Apple,
      # Google and Microsoft for exactly this, each answering a fixed reply,
      # so that one answering as expected shows the internet works. #online?
      # asks them in turn and stops at the first that does. Connectivity is
      # the real adapter, by Network::Link.
      class Connectivity
        # The three checks, each to its own host (+to+), as plain HTTP.
        REQUESTS = [
          Network::Request.new(kind: :connectivity_apple, verb: :get, path: "/hotspot-detect.html", to: "captive.apple.com", feature: "connectivity checks",
                               happens: "Only when setdef's server gave no valid proof at a start: to tell setdef being gone from the internet being down. Apple's connectivity check, which answers the same page to everyone."),
          Network::Request.new(kind: :connectivity_google, verb: :get, path: "/generate_204", to: "connectivitycheck.gstatic.com", feature: "connectivity checks",
                               happens: "As the one before, only if Apple's check did not answer as expected. Google's connectivity check, which answers an empty page to everyone."),
          Network::Request.new(kind: :connectivity_microsoft, verb: :get, path: "/connecttest.txt", to: "www.msftconnecttest.com", feature: "connectivity checks",
                               happens: "As the one before, only if neither Apple's nor Google's check answered as expected. Microsoft's connectivity check, which answers the same line to everyone.")
        ].to_h { [it.kind, it] }.freeze

        # A check: its declaration, and the answer that shows the internet
        # works.
        Check = Data.define(:request, :status, :body) do
          def url = "http://#{request.to}"
        end

        CHECKS = [
          Check.new(request: REQUESTS.fetch(:connectivity_apple), status: 200, body: /Success/),
          Check.new(request: REQUESTS.fetch(:connectivity_google), status: 204, body: /\A\z/),
          Check.new(request: REQUESTS.fetch(:connectivity_microsoft), status: 200, body: /\AMicrosoft Connect Test\z/)
        ].freeze

        # +link+ makes a raw Network::Link for a check's host.
        def initialize(checks: CHECKS, link: ->(url) { Network::Link.new(url, raw: true) })
          @checks = checks
          @link = link
        end

        def online?
          @checks.any? do |check|
            reply = @link.call(check.url).call(Network::Job.of(check.request), nil)
            reply.status == check.status && reply.body.is_a?(String) && reply.body.strip.match?(check.body)
          end
        end
      end
    end
  end
end
