# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::AchievementsPainter draws the Achievements grid from the
# AchievementsDrawing its screen hands it, and from nothing else.
class AchievementsPainterTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400], [400, 320]].freeze

  def achievements(width: 1200, height: 800, pro: true, input: nil)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, pro:)
    show = fixture.show
    show.input = input if input
    show.open_achievements
    fixture.tick(0.5)
    [show, fixture]
  end

  def draw(drawing) = Shell::AchievementsPainter.new(context:).draw(drawing)

  def test_it_draws_every_field_of_its_drawing
    SIZES.each do |width, height|
      [[true, P::InputKind::MOUSE], [false, P::InputKind::GAMEPAD]].each do |pro, input|
        show, = achievements(width:, height:, pro:, input:)
        given = show.screen.drawing
        assert_equal pro, !given.count.nil?, "a Pro player is told how many are earned"
        assert_equal input == P::InputKind::GAMEPAD, !given.how_to_earn.nil?
        unused = [*([[:count_x], [:count_y]] unless given.count), *([[:how_to_earn_word]] unless given.how_to_earn)]
        assert_draws_every_field(given, unused:) { draw(it) }
      end
    end
  end

  def test_every_cell_is_drawn_inside_the_window_it_scrolls_in
    show, = achievements(width: 400, height: 320)
    given = show.screen.drawing
    window = given.window
    marks = drawn(given)
    emblems = marks.select { it.kind == :circle && it.args[0] == :fill && !it.clip.nil? }
    refute_empty emblems
    assert(emblems.all? { it.clip == [window.x, window.y, window.width, window.height].map { context.pixels.snap(it) } })
    assert_equal given.cells.size, emblems.count { it.color[3] > 0.5 }, "each cell's icon, cut to the window"
  end

  def test_a_cell_is_lit_by_the_mouse_over_it_and_earned_or_not_as_its_player_has
    show, fixture = achievements(input: P::InputKind::MOUSE)
    cell = show.screen.drawing.cells.first.cell
    show.pointer_at(cell.x, cell.y)
    fixture.tick(1.0)
    lit = show.screen.drawing.cells.map(&:hover)
    assert_in_delta 1.0, lit.first
    assert(lit.drop(1).all?(&:zero?))
    given = show.screen.drawing
    assert_equal(given.cells.map { show.achievement_earned?(it.cell.id) }, given.cells.map(&:earned))
    assert_includes given.cells.map(&:earned), false, "some are not earned yet"
    earned = drawn(given.with(cells: given.cells.map { it.with(earned: true) }))
    not_yet = drawn(given.with(cells: given.cells.map { it.with(earned: false) }))
    refute_equal earned, not_yet
  end

  def test_a_scroll_moves_the_cells
    show, fixture = achievements(width: 400, height: 320)
    before = show.screen.drawing.cells.map { it.cell.y }
    show.wheel_scroll(-3)
    fixture.tick(0.1)
    refute_equal before, show.screen.drawing.cells.map { it.cell.y }
  end
end
