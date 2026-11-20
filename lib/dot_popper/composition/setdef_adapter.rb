# frozen_string_literal: true

module DotPopper
  module Composition
    # Connects Monetization's "setdef is gone" to Gameplay's port for it:
    # each event Continuity::Gone announces, it tells its +listeners+ as
    # Gameplay's own value (Gameplay::SetdefGone, Gameplay::SetdefHere), so
    # neither area names the other.
    class SetdefAdapter
      def initialize(*listeners)
        @listeners = listeners
      end

      def call(event)
        heard = case event
               when Monetization::Continuity::SetdefGone then Gameplay::SetdefGone.new(since: event.since, today: event.today)
               when Monetization::Continuity::SetdefHere then Gameplay::SetdefHere.new
               end
        @listeners.each { it.call(heard) } if heard
      end
    end
  end
end
