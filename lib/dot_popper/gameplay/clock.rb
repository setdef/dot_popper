# frozen_string_literal: true

module DotPopper
  module Gameplay
    # The game's clock at one moment. It counts down in real time, takes
    # rewards and mistakes, and never reads less than zero.
    class Clock < Data.define(:remaining)
      def initialize(remaining:) = super(remaining: [remaining.to_f, 0.0].max)

      def tick(seconds) = adjust(-seconds)

      # The clock with +seconds+ added, or taken away when negative.
      def adjust(seconds) = with(remaining: remaining + seconds)

      def expired? = remaining <= 0
      def whole_seconds = remaining.floor
    end
  end
end
