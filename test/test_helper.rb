# frozen_string_literal: true

require "minitest/autorun"
require "dot_popper"

# The suite is an automated run: it reaches no outside host (Automation).
ENV["DOT_POPPER_AUTOMATED"] = "1"
DotPopper::Automation.guard!

# Gameplay's test helpers are its gem's (gems/dot_popper-gameplay).
require_relative "../gems/dot_popper-gameplay/test/gameplay_helpers"

# A Ruby of its own for a copy of the game in +top+ (its lib/ and its own
# gems, gems/*/lib, PACKAGING.md): the environment and the arguments that
# load the game's code from that copy alone, with no Bundler, so a file
# the copy leaves out is not found in this repository instead. Every
# other gem (Lota, and what it needs) comes from this bundle by its folder.
module CopyRuby
  ROOT = File.expand_path("..", __dir__)
  ENV_WITHOUT_BUNDLER = { "RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLER_SETUP" => nil }.freeze

  def self.arguments(top)
    own = [File.join(ROOT, "lib"), File.join(ROOT, "test")]
    others = $LOAD_PATH.map(&:to_s).reject { own.include?(it) || it.start_with?(File.join(ROOT, "gems", "")) }
    [File.join(top, "lib"), *Dir[File.join(top, "gems", "*", "lib")].sort, *others].flat_map { ["-I", it] }
  end
end
