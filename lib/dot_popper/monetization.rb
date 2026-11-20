# frozen_string_literal: true

require "date"
require_relative "network"
require_relative "memory_file"

module DotPopper
  # Monetization: Free and Pro, free games, the stores and their
  # receipts, license keys, and proof that setdef is there. It hears
  # Gameplay's published events and names nothing else of Gameplay, and
  # nothing of Release Engineering: the composition root reads the build's
  # channel and hands Monetization what it means. Of the code the areas
  # share it uses the network client and the save file kept in memory
  # (test/areas_test.rb). None of it touches Lota.
  module Monetization
  end
end

%w[receipt entitlement store website_store free_games continuity license_keys].each { require_relative "monetization/#{it}" }
