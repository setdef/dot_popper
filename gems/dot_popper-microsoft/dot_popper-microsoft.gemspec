# frozen_string_literal: true

# The Microsoft Store's part of Monetization, as a gem of its own: how the
# game takes that store's license. Only that store's build and a test
# build carry its code; the game's microsoft part (lib/dot_popper/microsoft)
# loads it. Another channel's build keeps this file alone, so that Bundler
# can read the Gemfile, and leaves out the gem's group.
Gem::Specification.new do |spec|
  spec.name = "dot_popper-microsoft"
  spec.version = "0.0.0"
  spec.summary = "Dot Popper's Microsoft Store license check"
  spec.authors = ["setdef"]
  spec.license = "LicenseRef-setdef-all-rights-reserved"
  spec.required_ruby_version = ">= 4.1.0.a"
  spec.files = Dir["lib/**/*.rb", base: __dir__]
  spec.require_paths = ["lib"]
  spec.add_dependency "dot_popper-monetization", "0.0.0"
end
