# frozen_string_literal: true

# The code Dot Popper's areas share, as a gem of its own (PACKAGING.md,
# "The game's own gems"): the HTTP client every request goes through
# (Network), what the system means for the game (Platform), the guard on
# automated runs (Automation) and a save file kept in memory
# (MemoryFile). It names nothing of the areas, and each area's gem names
# it. The game takes it by its path in this repository (Gemfile); it is
# published to no gem server.
Gem::Specification.new do |spec|
  spec.name = "dot_popper-shared"
  spec.version = "0.0.0"
  spec.summary = "The code Dot Popper's areas share"
  spec.authors = ["setdef"]
  spec.license = "LicenseRef-setdef-all-rights-reserved"
  spec.required_ruby_version = ">= 4.1.0.a"
  spec.files = Dir["lib/**/*.rb", base: __dir__]
  spec.require_paths = ["lib"]
end
