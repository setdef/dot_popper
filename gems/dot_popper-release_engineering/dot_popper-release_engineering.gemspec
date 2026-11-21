# frozen_string_literal: true

# Release Engineering, Dot Popper's area of builds per channel, as a gem of
# its own (PACKAGING.md, "The game's own gems"). In the game it is only
# what a build is (DotPopper::ReleaseEngineering::Build), which
# script/set_build_channel.rb stamps in this gem's
# lib/dot_popper/release_engineering/build.rb before each build for sale,
# and which the release checks read in the app they built. It names no
# other area and depends on no other gem. The game takes it by its path
# in this repository (Gemfile); it is published to no gem server.
Gem::Specification.new do |spec|
  spec.name = "dot_popper-release_engineering"
  spec.version = "0.0.0"
  spec.summary = "Dot Popper's Release Engineering"
  spec.authors = ["setdef"]
  spec.license = "LicenseRef-setdef-all-rights-reserved"
  spec.required_ruby_version = ">= 4.1.0.a"
  spec.files = Dir["lib/**/*.rb", base: __dir__]
  spec.require_paths = ["lib"]
end
