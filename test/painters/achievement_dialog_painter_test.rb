# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::AchievementsPainter#dialog draws an achievement's dialog from the
# AchievementDialogDrawing its screen hands it, and from nothing else.
class AchievementDialogPainterTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400]].freeze

  # The plan's buttons are handed on as DialogButtonDrawings, with their
  # words and light; its how-to-earn text was laid out into its lines.
  UNUSED = [%i[plan buttons], %i[plan how]].freeze

  def dialog(id, width: 1200, height: 800, pro: true, input: nil)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, pro:)
    show = fixture.show
    show.input = input if input
    show.open_achievements
    show.open_achievement(id)
    fixture.tick(0.5)
    [show, fixture]
  end

  def draw(drawing) = Shell::AchievementsPainter.new(context:).dialog(drawing)

  def test_it_draws_every_field_of_its_drawing
    SIZES.each do |width, height|
      [[:steady, true, P::InputKind::MOUSE], [:steady, false, P::InputKind::GAMEPAD], [:blink, true, P::InputKind::MOUSE]].each do |id, pro, input|
        show, = dialog(id, width:, height:, pro:, input:)
        given = show.screen.drawing
        unused = [*UNUSED.select { |path| present?(given, path) }, *([[:progress_label]] unless given.progress), *([%i[plan status_y]] unless given.status)]
        assert_draws_every_field(given, unused:) { draw(it) }
      end
    end
  end

  def test_a_pro_player_sees_how_far_along_and_a_free_player_is_offered_pro
    show, = dialog(:steady)
    given = show.screen.drawing
    refute_nil given.status
    refute_nil given.progress
    marks = drawn(given)
    said(given.status, marks)
    said("#{given.progress[0]} of #{given.progress[1]}", marks)
    show, = dialog(:steady, pro: false)
    given = show.screen.drawing
    assert_nil given.status
    assert_equal %i[achievement_pro achievement_close], given.buttons.map(&:name)
    given.buttons.each { said(it.word, drawn(given)) }
  end

  def test_each_button_is_lit_by_the_mouse_over_it
    show, fixture = dialog(:steady, pro: false, input: P::InputKind::MOUSE)
    show.screen.drawing.buttons.each do |button|
      show.pointer_at(button.rect.center_x, button.rect.center_y)
      fixture.tick(1.0)
      lit = show.screen.drawing.buttons.to_h { [it.name, it.hover] }
      assert_in_delta 1.0, lit.fetch(button.name), 1e-9, button.name.to_s
      assert(lit.except(button.name).values.all? { it < 0.5 })
    end
  end

  def test_its_screen_hands_the_achievement_as_the_player_has_it
    show, = dialog(:steady)
    given = show.screen.drawing
    assert_equal :steady, given.id
    assert_equal show.achievement_earned?(:steady), given.earned
    assert_equal show.dialog_status(:steady), given.status
    assert_equal show.achievement_progress(:steady), given.progress
    refute_equal drawn(given), drawn(given.with(earned: !given.earned))
  end

  def test_an_earned_achievement_says_its_day_in_the_gains_color_after_a_check
    show, fixture = dialog(:blink)
    # The Show's achievements, as ViewAchievements reads them.
    achievements = show.screens.fetch(:achievement_dialog).instance_variable_get(:@view).instance_variable_get(:@achievements)
    achievements.award([:blink], day: Date.new(2026, 11, 3))
    fixture.tick(0.1)
    given = show.screen.drawing
    assert given.earned
    assert_equal show.dialog_status(:blink), given.status
    marks = drawn(given)
    assert_equal context.palette.gain.then { [it.r, it.g, it.b] }, said(given.status, marks).color.first(3)
    refute_equal marks.count { it.kind == :line }, drawn(given.with(earned: false)).count { it.kind == :line }, "a check before it"
  end

  private

  def present?(drawing, path) = paths(drawing).any? { under?(it, path) }
end
