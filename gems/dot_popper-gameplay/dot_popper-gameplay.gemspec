# frozen_string_literal: true

# Gameplay and Metagame, Dot Popper's core area, as a gem of its own
# (PACKAGING.md, "The game's own gems"). The game takes it by its path in
# this repository (Gemfile); it is published to no gem server. It holds
# only part of the area so far, the rules of a game, the game and its
# events, Stats with today's goal, and the achievements: the rest is in
# lib/dot_popper/gameplay/, whose loader requires what this gem holds by
# name.
Gem::Specification.new do |spec|
  spec.name = "dot_popper-gameplay"
  spec.version = "0.0.0"
  spec.summary = "Dot Popper's Gameplay and Metagame"
  spec.authors = ["setdef"]
  spec.license = "LicenseRef-setdef-all-rights-reserved"
  spec.required_ruby_version = ">= 4.1.0.a"
  spec.files = Dir["lib/**/*.rb", base: __dir__]
  spec.require_paths = ["lib"]
end
