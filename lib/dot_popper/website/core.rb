# frozen_string_literal: true

# The website part (Build::PARTS names it in the website's build and in
# every build with no channel, and no app store's carries it): Monetization's code that
# only a copy sold on setdef's website needs, the website's store with
# its checkout in the browser, and license keys. Under Monetization's own
# names; it leans on the rest of Monetization, loaded before it.
require_relative "license_keys"
require_relative "website_store"
