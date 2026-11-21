# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::GameOverPainter draws Game Over from the GameOverDrawing its
# screen hands it, as the game's result stands at the moment it is
# drawn, and from nothing else.
class GameOverPainterTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400]].freeze
  RECORD = DotPopper::Gameplay::Stats::Record.new(kind: :most_dots_in_a_row, value: 31)

  # The result is a timeline the painter reads at the moment it draws
  # (its entrance, its count, its prompt), and what the plan was laid out
  # from is handed on as rects and sizes.
  # Of the plan, the score is set by its middle and top, the row of facts
  # from its left, the buttons each by their own rect (not their row's),
  # and the score record's line at the size its words were laid out for.
  # Share my score's ui scale is drawn only as it drops in (tested below).
  UNUSED = [[:over], %i[plan backing], %i[plan placed scale], %i[plan placed fits], %i[plan placed rects score height],
            %i[plan placed rects summary width], %i[plan placed rects buttons], %i[plan sizes score_record], [:ui]].freeze

  # Game Over of a game played to its end at +width+ by +height+, its
  # result with +lines+, once everything has arrived; for a Free player
  # unless +pro+.
  def game_over(width: 1200, height: 800, pro: true, **lines)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, pro:)
    show = fixture.show
    show.screen.primary
    fixture.tick(31)
    flunk "the game is over" unless show.game_over?
    refute_nil show.screens.fetch(:game_over).drawing.play_note, "a Free player is told the games left" unless pro
    show.instance_variable_set(:@game_over, show.game_over.with(**lines)) unless lines.empty?
    fixture.tick(6)
    [show, show.screens.fetch(:game_over).drawing]
  end

  def draw(drawing, now) = Shell::GameOverPainter.new(context:, dots:).draw(drawing, now)

  def test_it_draws_every_field_of_its_drawing
    SIZES.each do |width, height|
      [{ pro: false }, { record: RECORD, goal_met: true, achievements: [:blink] }, { new_score_record: true }].each do |lines|
        show, given = game_over(width:, height:, **lines)
        # A chip that opens nothing is never lit.
        dark = given.chips.each_index.reject { given.chips[it].opens }.map { [:chip_hovers, it] }
        unused = [*UNUSED, *dark, *([[:record], %i[plan sizes summary]] unless given.record), *([%i[plan sizes chip]] if given.chips.empty?),
                  *([[:score_record_line]] unless given.score_record_line)]
        assert_draws_every_field(given, unused:) { draw(it, show.now) }
      end
    end
  end

  def test_nothing_is_drawn_before_a_game_has_finished
    fixture = Inputs::Fixture.new(os: "Linux", width: 1200, height: 800)
    assert_nil fixture.show.screens.fetch(:game_over).drawing
    assert_empty marks_of(nil) { draw(it, 0.0) }
  end

  def test_it_says_its_lines_and_buttons
    show, given = game_over(record: RECORD, goal_met: true, achievements: [:blink])
    marks = drawn_at(given, show.now)
    [given.time_up, given.record, given.home_word, given.share_word, given.play_word, *given.chips.map(&:text)].each { said(it, marks) }
    assert_equal %i[over_goal over_achievement], given.chips.map(&:name)
  end

  def test_each_button_and_line_is_lit_by_the_mouse_over_it
    show, given = game_over(achievements: [:blink])
    assert_in_delta 0.0, given.play_hover
    %i[play_again home share over_achievement].each do |name|
      reach = show.reach_of(name) or flunk "#{name} is offered"
      show.input = P::InputKind::MOUSE
      show.pointer_at(reach.center_x, reach.center_y)
      show.update(1.0)
      lit = show.screens.fetch(:game_over).drawing
      levels = { play_again: lit.play_hover, home: lit.home_hover, share: lit.share_hover, over_achievement: lit.chip_hovers[0] }
      assert_in_delta 1.0, levels.fetch(name), 1e-9, name.to_s
      assert(levels.except(name).values.all? { it < 0.5 }, "only #{name} is lit")
      show.pointer_gone
      show.update(1.0)
    end
  end

  def test_share_my_score_drops_in_at_the_ui_scale
    _, given = game_over
    over = given.over
    arriving = over.at + over.style.tally.duration + 0.05
    refute_equal marks_of(given) { draw(it, arriving) }, marks_of(given.with(ui: given.ui * 2)) { draw(it, arriving) }
  end

  private

  def drawn_at(drawing, now) = marks_of(drawing) { draw(it, now) }
end
