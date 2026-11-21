# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::HomePainter draws Home from the HomeDrawing its screen hands it,
# as Home has come in by the moment it is drawn, and from nothing else.
class HomePainterTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400]].freeze

  # Home's entrance is a timeline the painter reads at the moment it
  # draws (tested below); the plan's buttons are handed on as tiles and
  # pills, with their words and light; and the safe area only narrows the
  # quit line where it would run past it (tested below).
  UNUSED = [[:entrance], %i[plan tiles], %i[plan pills], [:safe]].freeze

  def home(width: 1200, height: 800, played: true, input: nil, **given)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, played:, **given)
    show = fixture.show
    show.input = input if input
    fixture.tick(3.0)
    [show, fixture]
  end

  def draw(drawing, now) = Shell::HomePainter.new(context:, dots:).draw(drawing, now)

  def test_it_draws_every_field_of_its_drawing
    SIZES.each do |width, height|
      [[false, P::InputKind::MOUSE, {}], [true, P::InputKind::MOUSE, {}], [true, P::InputKind::GAMEPAD, { pro: true }]].each do |played, input, given|
        show, = home(width:, height:, played:, input:, **given)
        show.screen.ask_to_quit
        show.update(0.1)
        drawing = show.screen.drawing
        assert_operator drawing.quit, :>, 0.0
        assert_equal played, !drawing.tiles.empty?, "the large buttons once a game is played"
        assert_equal input == P::InputKind::GAMEPAD, drawing.tiles.any?(&:badge) if played
        unused = [*UNUSED.select { |path| paths(drawing).any? { under?(it, path) } }, *([[:goal]] unless drawing.goal), *drawing.tiles.each_index.map { [:tiles, it, :name] },
                  *drawing.pills.each_index.map { [:pills, it, :name] }]
        unused += [[:play_note]] unless drawing.play_note
        assert_draws_every_field(drawing, unused:) { draw(it, show.now) }
      end
    end
  end

  def test_the_quit_line_is_set_smaller_where_it_would_run_past_the_safe_area
    show, = home
    show.screen.ask_to_quit
    show.update(0.1)
    given = show.screen.drawing
    x, y = given.plan.quit_line
    narrow = given.with(safe: P::Rect.new(x: x - 60, y: y - 300, width: 120, height: 600))
    size = ->(drawing) { said(given.quit_text, marks_of(drawing) { draw(it, show.now) }).size }
    assert_operator size.call(narrow), :<, size.call(given)
  end

  def test_home_comes_in_as_its_entrance_says
    show, = home
    given = show.screen.drawing
    start = given.entrance.at
    refute_equal marks_of(given) { draw(it, start + 0.05) }, marks_of(given) { draw(it, show.now) }
  end

  def test_each_tile_and_pill_is_lit_by_the_mouse_over_it
    show, fixture = home(input: P::InputKind::MOUSE)
    given = show.screen.drawing
    [*given.tiles, *given.pills].each do |button|
      show.pointer_at(button.rect.center_x, button.rect.center_y)
      fixture.tick(1.0)
      lit = show.screen.drawing.then { [*it.tiles, *it.pills] }.to_h { [it.name, it.hover] }
      assert_in_delta 1.0, lit.fetch(button.name), 1e-9, button.name.to_s
      assert(lit.except(button.name).values.all? { it < 0.5 })
    end
  end

  def test_its_screen_hands_todays_goal_and_each_tiles_value
    show, = home
    given = show.screen.drawing
    refute_nil given.goal, "the card shows at 1200x800"
    assert_equal show.saved_stats.streak, given.goal.streak
    assert_equal show.saved_stats.goal_done?, given.goal.done
    assert_equal(given.tiles.map { show.screen.tile_note(it.name) }, given.tiles.map(&:note))
    assert_equal(given.tiles.map { show.words.tile(it.name) }, given.tiles.map(&:word))
    assert_equal [show.play_word, show.play_note], [given.play_word, given.play_note]
    assert(given.tiles.all? { it.badge.nil? }, "no badges without a controller")
  end
end
