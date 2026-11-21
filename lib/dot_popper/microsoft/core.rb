# frozen_string_literal: true

# The microsoft part (Build::PARTS names it in the Microsoft Store's build
# and in every build with no channel; no other build carries it): the code
# that takes the Microsoft Store's license, Windows' word, under
# Monetization's own names (Receipt::Microsoft, Receipt::MICROSOFT_STORE).
# It leans on Receipt, loaded before it.
require "dot_popper/monetization/receipt/microsoft"
