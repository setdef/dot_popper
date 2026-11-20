# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::PrivacyPainter draws the Privacy screen from the PrivacyDrawing
# its screen hands it, and from nothing else.
class PrivacyPainterTest < Minitest::Test
  include PaintersTest

  # Laid out, never drawn: what stays, said in the hold's own note.
  UNUSED = [%i[plan note_lines]].freeze

  def drawing(width: 1200, height: 800)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, member: true)
    show = fixture.show
    show.open_settings
    show.open_privacy
    fixture.tick(0.5)
    show.screen.drawing
  end

  def draw(drawing) = Shell::PrivacyPainter.new(context:).draw(drawing)

  def test_it_draws_every_field_of_its_drawing
    [drawing(width: 1200, height: 800), drawing(width: 400, height: 850)].each do |given|
      assert_draws_every_field(given.with(held: true, progress: 0.5), unused: UNUSED) { draw(it) }
      assert_draws_every_field(given, unused: [*UNUSED, [:held], [:progress]]) { draw(it) }
    end
  end

  def test_its_words_are_the_drawings_where_the_plan_puts_them
    given = drawing
    marks = drawn(given)
    assert_in_delta given.plan.policy.center_y, said(given.policy, marks).y, 1
    assert_in_delta given.plan.delete.center_y, said(given.delete, marks).y, 1
    refute_empty given.note_rows
    given.note_rows.each { assert_equal given.note_x, said(it, marks).x }
  end

  def test_the_mouse_lights_only_the_button_it_is_over
    given = drawing
    plain = drawn(given)
    lit = drawn(given.with(policy_hover: 1.0))
    refute_equal fill_at(given.plan.policy, plain), fill_at(given.plan.policy, lit)
    assert_equal fill_at(given.plan.delete, plain), fill_at(given.plan.delete, lit)
    assert_equal fill_at(given.header.back, plain), fill_at(given.header.back, lit)
  end

  def test_a_held_delete_fills_as_far_as_it_is_held
    given = drawing.with(held: true, progress: 0.5)
    half = drawn(given).select { it.kind == :polygon }
    refute_empty half
    refute_equal half, drawn(given.with(progress: 0.9)).select { it.kind == :polygon }
    assert_empty drawn(given.with(held: false)).select { it.kind == :polygon }
  end
end
