# frozen_string_literal: true

module DotPopper
  module Gameplay
    # What Gameplay hears of whether setdef is there: the port through
    # which "setdef is gone" reaches the themes (SavedThemes) and the server
    # friend groups use (ServerChoice). Monetization decides it; the
    # composition root tells Gameplay's listeners in these values, so
    # nothing of Gameplay names Monetization.

    # A check left setdef gone: gone +since+ the day it was first found
    # gone, as of +today+.
    class SetdefGone < Data.define(:since, :today)
      # Whole days it has been gone.
      def days = (today - since).to_i
    end

    # setdef's server proved itself in a check.
    class SetdefHere < Data.define; end
  end
end
