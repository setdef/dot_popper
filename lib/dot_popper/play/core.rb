# frozen_string_literal: true

# The play part (Build::PARTS names it in the Google Play build and in
# every build with no channel, whose fake store's receipts are in Play's
# form; no other build carries it): the code that checks Google Play's
# receipts, Play Billing's signed purchases, under Monetization's own names
# (Receipt::Play, Receipt::PLAY). It leans on Receipt, loaded before it.
require_relative "receipt"
