# frozen_string_literal: true

# Monetization, Dot Popper's area of Free and Pro, as a gem of its own
# (PACKAGING.md, "The game's own gems"): free games, the stores and their
# receipts, and proof that setdef is there. Each store's receipt check
# and the website's license keys and store are in the game's build parts
# (lib/dot_popper/apple, play, microsoft, website and the rest), which
# only their channels' builds carry. The game takes it
# by its path in this repository (Gemfile); it is published to no gem
# server. It holds the whole area, which the game loads by requiring
# dot_popper/monetization.
Gem::Specification.new do |spec|
  spec.name = "dot_popper-monetization"
  spec.version = "0.0.0"
  spec.summary = "Dot Popper's Monetization"
  spec.authors = ["setdef"]
  spec.license = "LicenseRef-setdef-all-rights-reserved"
  spec.required_ruby_version = ">= 4.1.0.a"
  spec.files = Dir["lib/**/*.rb", base: __dir__]
  spec.require_paths = ["lib"]
  # The code the game's areas share, the game's own gem too.
  spec.add_dependency "dot_popper-shared", "0.0.0"
end
