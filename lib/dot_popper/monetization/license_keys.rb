# frozen_string_literal: true

module DotPopper
  module Monetization
    # License keys, the website's way to Pro (ADR-0011): the key's layout
    # and its offline check, and this device's place in "one key, one
    # device at a time". They lean on Continuity for setdef's signatures and
    # keys; Continuity names nothing of them. None of it touches Lota.
    module LicenseKeys
    end
  end
end

%w[license_key verdict license].each { require_relative "license_keys/#{it}" }
