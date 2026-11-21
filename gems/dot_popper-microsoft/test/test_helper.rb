# frozen_string_literal: true

require "minitest/autorun"

# The gem's tests load the gem alone, with Monetization and the code the
# areas share, which it names, and nothing else of the game.
require "dot_popper/monetization"
require "dot_popper/monetization/receipt/microsoft"
require "dot_popper/automation"

ENV["DOT_POPPER_AUTOMATED"] = "1"
DotPopper::Automation.guard!
