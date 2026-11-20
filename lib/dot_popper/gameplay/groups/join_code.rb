# frozen_string_literal: true

module DotPopper
  module Gameplay
    module Groups
      # A friend group's join code as a player taps it in: digits only, no
      # more than LENGTH of them, which the server makes every code
      # (doc/design/friend-groups.md, "Joining by a seven-digit code").
      # Join can be pressed once it is complete.
      class JoinCode < Data.define(:digits)
        LENGTH = 7

        def self.empty = new(digits: "")

        def complete? = digits.size == LENGTH

        # The code with +digit+ after it, if it is one digit from 0 to 9
        # and the code has room for it; otherwise the same code.
        def add(digit)
          return self unless digit.match?(/\A[0-9]\z/) && digits.size < LENGTH

          with(digits: digits + digit)
        end

        # The code without its last digit.
        def erase = with(digits: digits[0...-1].to_s)
      end
    end
  end
end
