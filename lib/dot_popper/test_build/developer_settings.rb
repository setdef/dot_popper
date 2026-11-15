# frozen_string_literal: true

module DotPopper
  module Composition
    class DeveloperSettings
      # DOT_POPPER_TODAY=2026-11-07: a test build plays as if it were that
      # date, to try another day's goal or a streak. A build for sale plays
      # on today's, whatever its settings say.
      module PretendDay
        def today
          return super if store_build?

          pretend = Date.iso8601(fetch("DOT_POPPER_TODAY"))
          -> { pretend }
        rescue Date::Error
          super
        end

        # Midnight UTC of DOT_POPPER_TODAY's day.
        def utc_clock
          return super if store_build?

          pretend = Date.iso8601(fetch("DOT_POPPER_TODAY"))
          -> { Time.utc(pretend.year, pretend.month, pretend.day) }
        rescue Date::Error
          super
        end
      end
      prepend PretendDay
    end
  end
end
