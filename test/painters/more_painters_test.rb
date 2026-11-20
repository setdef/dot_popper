# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Credits, the new theme card, the share preview and the HUD, each drawn
# from the drawing its screen (or the HUD) hands it, and from nothing else.
class MorePaintersTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400]].freeze

  # What the share preview's plan was laid out from, which its drawing
  # hands on as runs and rects: the column's scale and fit, the lines, and
  # where the buttons' row goes (each button has its own rect).
  SHARE_PLAN = [%i[plan placed scale], %i[plan placed fits], %i[plan lines], %i[plan placed rects buttons]].freeze

  # What the HUD's sizes were made from (HudDrawing#sizes).
  HUD_SIZES = [%i[plan number_height], %i[plan label_height], [:readouts, :*, :scale]].freeze

  def fixture(width, height, **given)
    Inputs::Fixture.new(os: "Linux", width:, height:, **given)
  end

  def test_credits_draws_every_field
    SIZES.each do |width, height|
      made = fixture(width, height)
      made.show.open_settings
      made.show.open_credits
      headed = false
      8.times do
        made.tick(1.0)
        given = made.show.screen.drawing
        heading = given.rows.any? { it.kind == :heading }
        headed ||= heading
        # The bar stands at bar_x, or at bar_limit where bar_x would pass
        # it, and only where the page is longer than its window.
        bar = if given.thumb.nil? then [[:bar_x], [:bar_limit]]
              elsif given.bar_x.round >= given.bar_limit - 3 then [[:bar_x]]
              else [[:bar_limit]]
              end
        assert_draws_every_field(given, unused: [*bar, *([[:heading_size]] unless heading)]) do
          Shell::CreditsPainter.new(context:).draw(it)
        end
        made.show.wheel_scroll(-12)
      end
      assert headed, "a heading is drawn somewhere on the page"
    end
  end

  def test_the_new_theme_card_draws_every_field
    SIZES.each do |width, height|
      made = fixture(width, height, new_theme: true, pro: true)
      made.tick(1.0)
      given = made.show.screen.drawing
      # The theme's art is the dot painter's to draw (FakeDots keeps only
      # its colors); the plan's layout and word are what it was laid out from.
      assert_draws_every_field(given, unused: [%i[theme art], %i[plan layout], %i[plan word]]) { Shell::NewThemeCardPainter.new(context:, dots:).draw(it) }
    end
  end

  def test_the_share_preview_draws_every_field
    SIZES.each do |width, height|
      made = fixture(width, height)
      made.show.screens.fetch(:share_preview).open_with(P::ShareText.open("🟡 27 dots · ⚫ 1 mistake\n⏱ 30s", made.show.now))
      made.tick(0.1)
      coming = made.show.screen.drawing
      made.show.screen.copy
      made.tick(1.0)
      copied = made.show.screen.drawing
      draw = ->(given) { Shell::SharePreviewPainter.new(context:, dots:).draw(given, width, height) }
      assert_draws_every_field(coming, unused: [*SHARE_PLAN, %i[plan sizes note], [:copied_word], %i[plan placed rects note]], &draw)
      assert_draws_every_field(copied, unused: SHARE_PLAN, &draw)
    end
  end

  def test_the_hud_draws_every_field
    SIZES.each do |width, height|
      made = fixture(width, height)
      show = made.show
      huds = P::HudDrawings.new(type: P::Style::TYPE, measure: show.measure)
      given = huds.call(show.hud, show.layout, 1.0)
      assert_draws_every_field(given, unused: HUD_SIZES) { Shell::HudPainter.new(context:, dots:).draw(it) }
    end
  end
end
