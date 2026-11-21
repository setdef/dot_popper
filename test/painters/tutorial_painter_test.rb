# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::TutorialPainter draws what goes over the Tutorial's HUD from the
# TutorialDrawing its screen hands it, with the scene it plays, and from
# nothing else.
class TutorialPainterTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400]].freeze

  # The Tutorial at +width+ by +height+, played by taps on the dots it
  # waits for, up to a moment with a number in flight and the guide
  # showing, so that every field of its drawing has something to draw.
  def tutorial(width, height)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, played: false)
    show = fixture.show
    show.screen.primary
    300.times do |i|
      scene = show.tutorial or flunk "the Tutorial ended before a number flew under the guide"
      return [show, scene] if scene.traveling_numbers.any? && scene.guide_pose&.alpha&.positive?

      id = P::TutorialScene::TURNS[scene.beat]
      dot = id && scene.dots.find { it.id == id && !it.popped? }
      show.tap(dot.x, dot.y, by: :mouse) if dot && i % 10 == 9
      fixture.tick(0.1)
    end
    flunk "no number flew under the guide"
  end

  # What over_hud draws of +drawing+ over +scene+, under the HUD the
  # scene shows at +show+'s layout.
  def over_hud(drawing, show, scene)
    hud = P::HudDrawings.new(type: P::Style::TYPE, measure: show.measure).call(scene.hud, show.layout, 1.0)
    painter = Shell::HudPainter.new(context:, dots:)
    pill = painter.bounds(hud)
    spots = painter.spots(hud)
    Shell::TutorialPainter.new(context:).over_hud(drawing, scene, pill, spots)
  end

  def test_it_draws_every_field_of_its_drawing
    SIZES.each do |width, height|
      show, scene = tutorial(width, height)
      given = show.screen.drawing
      refute_nil given.skip, "Skip shows while the Tutorial is on top"
      assert_draws_every_field(given) { over_hud(it, show, scene) }
    end
  end

  def test_skip_says_its_word_on_its_button_and_only_while_it_is_handed_one
    show, scene = tutorial(1200, 800)
    given = show.screen.drawing
    word = said(given.skip_word, marks_of(given) { over_hud(it, show, scene) })
    assert_operator word.x, :>=, given.skip.x
    assert_operator word.x, :<=, given.skip.x + given.skip.width
    assert_empty texts(marks_of(given.with(skip: nil)) { over_hud(it, show, scene) }).select { it.text == given.skip_word }
  end

  def test_the_guide_is_drawn_for_the_input_it_is_handed
    show, scene = tutorial(1200, 800)
    given = show.screen.drawing
    guides = [P::InputKind::TOUCH, P::InputKind::MOUSE, P::InputKind::GAMEPAD].map { |kind| marks_of(given.with(input: kind)) { over_hud(it, show, scene) } }
    assert_equal 3, guides.uniq.size, "a hand, a pointer and a gamepad's button each look their own"
  end

  def test_its_screen_hands_skip_where_a_press_reaches_it_lit_by_the_mouse_over_it
    show, = tutorial(1200, 800)
    skip = show.screen.drawing.skip
    assert_equal show.layout.skip_button, skip
    assert show.skip_reach.contains?(skip.center_x, skip.center_y)
    assert_in_delta 0.0, show.screen.drawing.skip_hover
    show.input = P::InputKind::MOUSE
    show.pointer_at(skip.center_x, skip.center_y)
    show.update(1.0)
    assert_in_delta 1.0, show.screen.drawing.skip_hover
  end
end
