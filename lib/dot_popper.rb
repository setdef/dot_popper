# frozen_string_literal: true

# The rules of Dot Popper: dots, scoring, the clock, and the flow from
# Home to Game Over. Nothing here draws, plays sounds, or reads input, so
# all of it runs, and is tested, without a window.
require "date"

module DotPopper
end

require_relative "dot_popper/release_engineering"
# The code the areas share is a gem of its own, dot_popper-shared
# (gems/dot_popper-shared, which the Gemfile names by its path).
%w[platform automation network memory_file].each { require "dot_popper/#{it}" }
# Monetization is the gem dot_popper-monetization.
require "dot_popper/monetization"
# Gameplay and Metagame is the gem dot_popper-gameplay.
require "dot_popper/gameplay"
DotPopper::ReleaseEngineering::Build::PARTS.each { require_relative "dot_popper/#{it}/core" }
