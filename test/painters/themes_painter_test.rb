# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::ThemesPainter draws the Themes screen from the ThemesDrawing its
# screen hands it, and from nothing else.
class ThemesPainterTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400]].freeze

  # The theme's art is the dot painter's to draw (FakeDots keeps only its
  # colors), and its key only names it.
  UNUSED = [%i[cards * theme art]].freeze

  # The card of the theme in use is outlined in cream, however lit.
  def unused(drawing) = [*UNUSED, *drawing.cards.each_index.select { drawing.cards[it].chosen }.map { [:cards, it, :hover] }]

  def themes(width: 1200, height: 800, pro: true, input: nil)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, pro:)
    show = fixture.show
    show.input = input if input
    show.open_themes
    fixture.tick(0.5)
    [show, fixture]
  end

  def draw(drawing) = Shell::ThemesPainter.new(context:, dots:).draw(drawing)

  def test_it_draws_every_field_of_its_drawing
    SIZES.each do |width, height|
      [P::InputKind::MOUSE, P::InputKind::GAMEPAD].each do |input|
        show, = themes(width:, height:, input:)
        given = show.screen.drawing
        assert_operator given.cards.size, :>, 1, "more than one theme to choose"
        assert_equal(input == P::InputKind::GAMEPAD ? 2 : 0, given.steps.size)
        assert_draws_every_field(given, unused: unused(given)) { draw(it) }
      end
    end
  end

  def test_each_card_says_its_name_and_only_the_theme_in_use_is_chosen
    show, = themes
    given = show.screen.drawing
    marks = drawn(given)
    # A theme with a dotted wordmark says its name in capitals, as Home does.
    given.cards.each { |card| said(card.theme.art&.then { it.wordmark && it.dotted_name } ? card.name.upcase : card.name, marks) }
    assert_equal [show.in_use], given.cards.select(&:chosen).map(&:theme)
    chosen = given.cards.index(&:chosen)
    plain = drawn(given.with(cards: given.cards.each_with_index.map { |card, i| i == chosen ? card.with(chosen: false) : card }))
    check = ->(marks) { marks.count { %i[circle line].include?(it.kind) } }
    assert_equal check.call(plain) + 2, check.call(marks), "the theme in use has a check: a disc and its tick"
  end

  def test_using_another_theme_chooses_its_card
    show, fixture = themes
    other = show.screen.drawing.cards.find { !it.chosen }.theme
    show.screen.use(other)
    fixture.tick(0.1)
    assert_equal [other], show.screen.drawing.cards.select(&:chosen).map(&:theme)
  end

  def test_a_card_is_lit_by_the_mouse_over_it_and_lb_and_rb_by_their_own
    show, fixture = themes(input: P::InputKind::MOUSE)
    card = show.screen.drawing.cards.last
    show.pointer_at(card.rect.center_x, card.rect.center_y)
    fixture.tick(1.0)
    lit = show.screen.drawing.cards.map(&:hover)
    assert_in_delta 1.0, lit.last
    assert(lit[0...-1].all?(&:zero?))
  end

  def test_a_theme_not_open_is_dimmed
    show, = themes
    given = show.screen.drawing
    card = given.cards.first
    shut = given.with(cards: [card.with(open: false), *given.cards.drop(1)])
    rect = card.rect
    dim = ->(marks) { marks.count { it.kind == :rectangle && it.args[0] == :fill && it.args[1] == context.pixels.snap(rect.x) } }
    assert_equal dim.call(drawn(given)) + 1, dim.call(drawn(shut))
  end
end
