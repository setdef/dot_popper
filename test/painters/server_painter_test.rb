# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::ServerPainter draws Change Server from the ServerDrawing its
# screen hands it, and from nothing else.
class ServerPainterTest < Minitest::Test
  include PaintersTest

  def drawing(width: 1200, height: 800, paste: nil)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, gone: true)
    show = fixture.show
    show.open_settings
    show.open_change_server
    if paste
      fixture.clipboard.copy(paste)
      show.paste_server
    end
    fixture.tick(0.5)
    show.screen.drawing
  end

  def draw(drawing) = Shell::ServerPainter.new(context:).draw(drawing)

  def test_it_draws_every_field_of_its_drawing
    assert_draws_every_field(drawing, unused: [%i[plan status_y], [:reset], [:reset_hover]]) { draw(it) }
    assert_draws_every_field(drawing(paste: "not an address"), unused: [[:reset], [:reset_hover]]) { draw(it) }
    [[1200, 800], [400, 850]].each do |width, height|
      assert_draws_every_field(drawing(paste: "https://groups.example.org", width:, height:)) { draw(it) }
    end
  end

  def test_the_last_paste_is_said_under_the_buttons
    given = drawing(paste: "not an address")
    refute_nil given.plan.status
    assert_in_delta given.plan.status_y, said(given.plan.status, drawn(given)).y, 1
  end

  def test_the_mouse_lights_only_the_button_it_is_over
    given = drawing(paste: "https://groups.example.org")
    refute_nil given.plan.reset
    plain = drawn(given)
    lit = drawn(given.with(reset_hover: 1.0))
    refute_equal fill_at(given.plan.reset, plain), fill_at(given.plan.reset, lit)
    assert_equal fill_at(given.plan.paste, plain), fill_at(given.plan.paste, lit)
  end
end
