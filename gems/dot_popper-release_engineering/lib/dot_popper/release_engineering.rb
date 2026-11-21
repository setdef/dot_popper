# frozen_string_literal: true

module DotPopper
  # Release Engineering: builds per channel, signing, attestation,
  # downloads, updates and installers. In the game it is only what a
  # build is, stamped when the app is built (Build); it has no interface
  # at run time, and names neither of the other areas
  # (test/areas_test.rb). None of it touches Lota.
  module ReleaseEngineering
  end
end

require_relative "release_engineering/build"
