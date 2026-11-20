# frozen_string_literal: true

# The rules of Dot Popper: dots, scoring, the clock, and the flow from
# Home to Game Over. Nothing here draws, plays sounds, or reads input, so
# all of it runs, and is tested, without a window.
require "date"

module DotPopper
end

require_relative "dot_popper/release_engineering"
require_relative "dot_popper/platform"
require_relative "dot_popper/automation"
require_relative "dot_popper/network"
# Monetization has no loader of its own yet: its store names Release
# Engineering's Build as it loads (test/area_loaders_test.rb).
require_relative "dot_popper/monetization/receipt"
require_relative "dot_popper/monetization/entitlement"
require_relative "dot_popper/monetization/store"
require_relative "dot_popper/monetization/website_store"
require_relative "dot_popper/monetization/free_games"
require_relative "dot_popper/monetization/continuity"
require_relative "dot_popper/gameplay"
DotPopper::ReleaseEngineering::Build::PARTS.each { require_relative "dot_popper/#{it}/core" }
