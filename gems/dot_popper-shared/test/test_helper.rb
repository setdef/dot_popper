# frozen_string_literal: true

require "minitest/autorun"

# The gem's tests load the gem alone, with nothing of the game, so a file
# here that needs the rest of the game fails to load. They run as the
# game's do, as an automated run, which reaches no outside host.
%w[platform automation network memory_file].each { require "dot_popper/#{it}" }

ENV["DOT_POPPER_AUTOMATED"] = "1"
DotPopper::Automation.guard!
