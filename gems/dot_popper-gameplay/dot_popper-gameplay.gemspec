# frozen_string_literal: true

# Gameplay and Metagame, Dot Popper's core area, as a gem of its own
# (PACKAGING.md, "The game's own gems"). The game takes it by its path in
# this repository (Gemfile); it is published to no gem server. It holds
# the whole area, which the game loads by requiring dot_popper/gameplay.
Gem::Specification.new do |spec|
  spec.name = "dot_popper-gameplay"
  spec.version = "0.0.0"
  spec.summary = "Dot Popper's Gameplay and Metagame"
  spec.authors = ["setdef"]
  spec.license = "LicenseRef-setdef-all-rights-reserved"
  spec.required_ruby_version = ">= 4.1.0.a"
  spec.files = Dir["lib/**/*.rb", base: __dir__]
  spec.require_paths = ["lib"]
  # The code the game's areas share, the game's own gem too.
  spec.add_dependency "dot_popper-shared", "0.0.0"
end
