# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::OfferPainter draws the offer of Pro from the OfferDrawing its
# screen hands it, and from nothing else.
class OfferPainterTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400]].freeze

  # How the plan was laid out to fit is not drawn, and the list of what Pro adds
  # is set from its top left; a theme's art is the dot painter's to draw
  # (FakeDots keeps only its colors).
  UNUSED = [%i[plan placed scale], %i[plan placed fits], %i[plan placed rects items width], %i[plan placed rects items height],
            [:themes, :*, 0, :art]].freeze

  def offer(feature, width: 1200, height: 800, achievement: nil)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:)
    show = fixture.show
    if achievement
      show.open_achievements
      show.open_achievement(achievement)
      show.screen.get_pro
    else
      show.open_offer_for(feature)
    end
    fixture.tick(0.5)
    [show, fixture]
  end

  def draw(drawing) = Shell::OfferPainter.new(context:, dots:).draw(drawing)

  # What +drawing+ leaves undrawn: the themes or the achievement where it
  # leads with something else, and a button's light or word where the
  # plan has no such button.
  def unused(drawing)
    plan = drawing.plan
    [*UNUSED.select { |path| paths(drawing).any? { under?(it, path) } },
     *([[:themes]] unless drawing.focus == :themes), *([[:achievement]] unless drawing.focus == :achievements),
     *%i[buy restore paste].reject { plan.key?(it) }.flat_map { [[it], [:lit, it]] },
     *([[:status]] unless plan.key?(:status))]
  end

  def test_it_draws_every_field_of_its_drawing
    SIZES.each do |width, height|
      [offer(:themes, width:, height:), offer(:groups, width:, height:), offer(:games, width:, height:),
       offer(nil, width:, height:, achievement: :steady)].each do |show, _|
        given = show.screen.drawing
        assert_draws_every_field(given, unused: unused(given)) { draw(it) }
      end
    end
  end

  def test_it_leads_with_the_achievement_tapped_and_says_how_to_earn_it
    show, = offer(nil, achievement: :steady)
    given = show.screen.drawing
    assert_equal :achievements, given.focus
    assert_equal :steady, given.achievement.id
    assert_equal show.achievement_earned?(:steady), given.achievement.earned
    said(given.achievement.name, drawn(given))
  end

  def test_buy_and_its_neighbour_are_lit_by_the_mouse_over_them
    show, fixture = offer(:games)
    show.input = P::InputKind::MOUSE
    given = show.screen.drawing
    (%i[buy restore paste] & given.lit.keys).select { given.plan.key?(it) }.each do |name|
      rect = given.plan[name]
      show.pointer_at(rect.center_x, rect.center_y)
      fixture.tick(1.0)
      lit = show.screen.drawing.lit
      assert_in_delta 1.0, lit.fetch(name), 1e-9, name.to_s
      assert(lit.except(name).values.all? { it < 0.5 })
    end
  end

  def test_its_screen_hands_the_themes_pro_would_give_by_name
    show, = offer(:themes)
    given = show.screen.drawing
    refute_empty given.themes
    assert(given.themes.none? { it.first.ordinary? })
    assert_equal(given.themes.map { show.words.themes.fetch(it.first.key) }, given.themes.map(&:last))
  end
end
