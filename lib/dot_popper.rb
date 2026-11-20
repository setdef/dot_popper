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
require_relative "dot_popper/memory_file"
require_relative "dot_popper/monetization"
require_relative "dot_popper/gameplay"
DotPopper::ReleaseEngineering::Build::PARTS.each { require_relative "dot_popper/#{it}/core" }
