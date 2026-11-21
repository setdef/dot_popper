# frozen_string_literal: true

module DotPopper
  module Monetization
    # setdef being there (ADR-0011): its signed proof, the keys a build
    # trusts, the watch, and the one test of whether setdef is gone. None of it
    # touches Lota, and none of it reaches the network but by a port.
    module Continuity
    end
  end
end

%w[ed25519 certificate pins signed_answers setdef_server watch].each { require_relative "continuity/#{it}" }
