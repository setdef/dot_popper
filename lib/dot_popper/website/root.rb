# frozen_string_literal: true

module DotPopper
  module Composition
    class Root
      # What the website part puts together, in a build that carries it (the
      # website's, and every build with no channel): the license key, kept where the build
      # takes license keys (Root.license_keys?) and checked against the
      # keys it trusts; the server that is asked where a key is; and, for
      # the website's channel, the website's store with its checkout in the
      # browser. A build without the part keeps no license key and sells
      # through no website.
      module WebsiteParts
        private

        def license_for(pins)
          kept = Monetization::LicenseKeys::License.kept_in(self.class.license_keys?(settings)) { file("license.txt") }
          Monetization::LicenseKeys::License.new(kept, pins:, signing_keys: self.class.license_signing_keys(settings))
        end

        def license_server_for(link) = Monetization::LicenseKeys::Server.new(link)

        def website_for(clipboard)
          return super unless settings.channel == ReleaseEngineering::Build::WEBSITE

          -> { website_store(clipboard, Monetization::BrowserCheckout.new(opener: @engine.opener)) }
        end

        # The website's store, with +checkout+: in the browser, in a build
        # for sale.
        def website_store(clipboard, checkout)
          Monetization::WebsiteStore.new(checkout:, entitlement:, gone: @gone, clipboard:, entered: -> { @watch.start })
        end
      end
      prepend WebsiteParts

      # The keys whose signature on a license key a build with the part
      # trusts: setdef's own.
      module WebsiteChoices
        def license_signing_keys(_settings) = Monetization::LicenseKeys::SIGNING_KEYS
      end
      singleton_class.prepend(WebsiteChoices)
    end
  end
end
