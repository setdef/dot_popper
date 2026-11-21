# frozen_string_literal: true

require "minitest/autorun"

# The gem's tests load the gem alone, with nothing of the game, so a file
# here that needs the rest of the game fails to load. Of the game's code
# they have only the gem this one names, dot_popper-shared, and they run
# as the game's do, as an automated run, which reaches no outside host.
require "dot_popper/monetization"
require "dot_popper/automation"

ENV["DOT_POPPER_AUTOMATED"] = "1"
DotPopper::Automation.guard!
