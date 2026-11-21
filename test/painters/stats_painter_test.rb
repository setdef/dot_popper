# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::StatsPainter draws the Stats screen from the StatsDrawing its
# screen hands it, with the hold of "Clear my stats…" and Undo as they
# stand at the moment it draws, and from nothing else.
class StatsPainterTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400], [400, 320]].freeze
  HOLD = P::Style::STATS_CLEAR.hold

  # The plan keeps what it was laid out from; the hold and Undo are
  # timelines the painter reads at the moment it draws (tested below);
  # the Stats screen has no card of achievements; and of the goal's rows
  # only the number in each value is drawn (tested below).
  UNUSED = [%i[plan sheet], %i[plan layout], %i[plan style], [:clearing], [:undo], %i[sheet achievements],
            [:sheet, :goal, :rows, :*, :value]].freeze

  def stats(width: 1200, height: 800, played: true, input: nil)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, played:)
    show = fixture.show
    show.input = input if input
    show.open_stats
    fixture.tick(0.5)
    [show, fixture]
  end

  def draw(drawing, now) = Shell::StatsPainter.new(context:).draw(drawing, now)

  def test_it_draws_every_field_of_its_drawing
    SIZES.each do |width, height|
      show, = stats(width:, height:)
      given = show.screen.drawing
      refute given.sheet.empty
      unused = [*UNUSED.select { |path| paths(given).any? { under?(it, path) } }, [:keep_holding], [:hold_to_clear], [:prompt_y],
                [:prompt_width], [:undo_rect], [:undo_word], [:undo_hover], [:cleared], [:no_games], [:center_y]]
      unused += [[:note], [:center_x]] unless given.note
      assert_draws_every_field(given, unused:) { draw(it, show.now) }
    end
  end

  def test_the_goals_numbers_are_drawn
    show, = stats
    given = show.screen.drawing
    goal = given.sheet.goal
    rows = goal.rows.each_with_index.map { |row, i| i < 2 ? row.with(value: "#{71 + i} of them") : row }
    marks = drawn_now(given.with(sheet: given.sheet.with(goal: goal.with(rows:))), show)
    %w[71 72].each { said(it, marks) }
  end

  def test_holding_clear_says_what_will_go_and_fills_the_button
    show, fixture = stats(input: P::InputKind::GAMEPAD)
    show.pad(:y)
    fixture.tick(0.3)
    given = show.screen.drawing
    assert given.clearing.held?
    assert_includes given.keep_holding, "Y", "it names the button held"
    marks = marks_of(given) { draw(it, show.now) }
    said(given.keep_holding, marks)
    later = marks_of(given) { draw(it, show.now + 0.5) }
    refute_equal marks, later, "the fill grows as it is held"
    narrow = marks_of(given.with(prompt_width: 40)) { draw(it, show.now) }
    assert_operator texts(narrow).size, :>, texts(marks).size, "a prompt too wide for its room breaks into lines"
    assert_draws_every_field(given, unused: [*UNUSED.select { |path| paths(given).any? { under?(it, path) } }, [:hold_to_clear], [:prompt_width],
                                             [:undo_rect], [:undo_word], [:undo_hover], [:cleared], [:no_games], [:center_y],
                                             *([[:note]] unless given.note)]) { draw(it, show.now) }
  end

  def test_after_clearing_undo_shows_its_time_running_out
    show, fixture = stats
    show.pad(:y)
    fixture.tick(HOLD + 0.2)
    show.screen.release(:y)
    fixture.tick(0.2)
    given = show.screen.drawing
    refute_nil given.undo, "Undo is offered"
    assert_nil given.clear
    marks = marks_of(given) { draw(it, show.now) }
    said(given.undo_word, marks)
    said(given.cleared, marks)
    refute_equal marks, marks_of(given) { draw(it, show.now + 1.0) }, "its bar shortens"
  end

  def test_with_no_games_it_says_so
    show, = stats(played: false)
    given = show.screen.drawing or skip "Stats opens only once a game is played"
    skip "a sheet with games" unless given.sheet.empty
    said(given.no_games, marks_of(given) { draw(it, show.now) })
  end

  def test_its_screen_fits_the_list_and_a_scroll_moves_the_cards
    show, fixture = stats(width: 400, height: 320)
    before = show.screen.drawing.offset
    show.wheel_scroll(-3)
    fixture.tick(0.1)
    refute_equal before, show.screen.drawing.offset
    assert_equal show.screen.scroll.offset, show.screen.drawing.offset
  end

  def test_clear_is_lit_by_the_mouse_over_it
    show, fixture = stats(input: P::InputKind::MOUSE)
    rect = show.screen.drawing.clear
    show.pointer_at(rect.center_x, rect.center_y)
    fixture.tick(1.0)
    assert_in_delta 1.0, show.screen.drawing.clear_hover
  end

  private

  def drawn_now(drawing, show) = marks_of(drawing) { draw(it, show.now) }
end
