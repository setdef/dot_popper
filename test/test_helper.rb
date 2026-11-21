# frozen_string_literal: true

require "minitest/autorun"
require "dot_popper"

# The suite is an automated run: it reaches no outside host (Automation).
ENV["DOT_POPPER_AUTOMATED"] = "1"
DotPopper::Automation.guard!

# Gameplay's test helpers are its gem's (gems/dot_popper-gameplay).
require_relative "../gems/dot_popper-gameplay/test/gameplay_helpers"
