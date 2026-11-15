# frozen_string_literal: true

require "test_helper"

# The renderer draws each screen by its class (Shell::Renderer::PAINTS).
# A screen with no painting there would pass every presentation test and
# then raise, or draw nothing, in front of a player on the frame it
# opens; this test loads the shell without a window and fails first.
class RendererScreensTest < Minitest::Test
  def setup
    require "lota"
    require "dot_popper/shell"
  rescue LoadError => e
    skip "Lota isn't installed here (#{e.message})"
  end

  def screens = DotPopper::Presentation::Screens::ALL.values.map { DotPopper::Presentation::Screens.const_get(it) }

  def test_every_screen_has_a_painting
    assert_empty screens - DotPopper::Shell::Renderer::PAINTS.keys
  end

  def test_every_painting_is_a_method_of_the_renderer
    renderer = DotPopper::Shell::Renderer
    assert_empty renderer::PAINTS.values.reject { renderer.private_method_defined?(it) || renderer.method_defined?(it) }
  end

  def test_the_renderer_paints_no_screen_that_is_gone
    assert_empty DotPopper::Shell::Renderer::PAINTS.keys - screens
  end
end
