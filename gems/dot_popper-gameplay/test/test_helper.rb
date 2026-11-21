# frozen_string_literal: true

require "minitest/autorun"

# The gem's tests load the gem alone, with nothing of the game, so a file
# here that needs the rest of the game fails to load. Of the game's code
# they have only the gem this one names, dot_popper-shared.
require "dot_popper/gameplay"

module DotPopperTest
  R = DotPopper::Gameplay::Rules::RADIUS

  def field(width = 800, height = 600) = DotPopper::Gameplay::Field.new(width, height, R)

  def dot(x, y, velocity_x: 0, velocity_y: 0, popped: false, bonus: false, id: (@ids = (@ids || 100) + 1))
    DotPopper::Gameplay::Dot.new(id:, x:, y:, velocity_x:, velocity_y:, radius: R, popped:, bonus:)
  end
end
