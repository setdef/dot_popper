# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::SettingsPainter draws Settings from the SettingsDrawing its
# screen hands it, and from nothing else.
class SettingsPainterTest < Minitest::Test
  include PaintersTest

  # The choices as the plan lists them, which the screen hands on with
  # their light (SettingsDrawing#choices); a choice's name, which only
  # Dot size's preview asks; and how tall the list is, for its scroll.
  UNUSED = [[:plan, :rows, :*, :choices], [:choices, :*, :*, 3], %i[plan height], %i[sizing_preview style alike]].freeze

  def drawing(width: 1200, height: 800, gone: false)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, gone:)
    show = fixture.show
    show.open_settings
    fixture.tick(0.5)
    show.screen.drawing
  end

  def draw(drawing) = Shell::SettingsPainter.new(context:, dots:).draw(drawing)

  def test_it_draws_every_field_of_its_drawing
    [drawing, drawing(gone: true), drawing(width: 400, height: 850), drawing(width: 400, height: 320)].each do |given|
      sized = given.plan.rows.any? { it.key == :dot_size }
      assert_draws_every_field(given, unused: [*UNUSED, *([[:sizing_preview]] unless sized),
                                               *([[:change_server], %i[lit change_server]] unless given.plan.change_server)]) { draw(it) }
    end
  end

  def test_everything_is_drawn_inside_the_clip_and_nothing_after_it
    given = drawing(width: 400, height: 320)
    marks = drawn(given)
    clip = given.clip
    rows = marks.reject { it.kind == :text && it.text == given.header.text }.drop_while { it.clip.nil? }
    assert_equal [clip.x, clip.y, clip.width, clip.height], rows.first.clip
    assert(marks.reverse.take_while { it.clip.nil? }.empty?, "the clip ends with the last of the list")
  end

  def test_each_pill_is_lit_by_its_own_hover
    given = drawing(gone: true)
    plain = drawn(given)
    %i[credits privacy change_server].each do |name|
      lit = drawn(given.with(lit: given.lit.merge(name => 1.0)))
      rect = given.plan.public_send(name)
      refute_equal fill_at(rect, plain), fill_at(rect, lit), name
      (%i[credits privacy change_server] - [name]).each { assert_equal fill_at(given.plan.public_send(it), plain), fill_at(given.plan.public_send(it), lit) }
    end
  end

  def test_each_dot_size_shows_a_dot_as_big_as_it_makes_them
    given = drawing(width: 400, height: 850)
    row = given.plan.rows.find { it.key == :dot_size } or skip "no dot size row at 400x850"
    first, second = drawn(given).select { it.kind == :dot }.map { it.args[2] }.last(2)
    names = given.choices[given.plan.rows.index(row)].map(&:last)
    assert_in_delta given.sizing_preview.icon(names[0], 100) / given.sizing_preview.icon(names[1], 100), first / second, 1e-9
  end
end
