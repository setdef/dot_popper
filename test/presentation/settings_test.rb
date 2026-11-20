# frozen_string_literal: true

require_relative "presentation_helper"

# Settings: Sound, the dot size where the two sizes look different, and
# on a computer the window's Display; a short window scrolls to the rest.
class SettingsTest < Minitest::Test
  include PresentationTest

  def setup
    @sizing_file = DotPopper::ScoreRecord::Memory.new
    @game_flow = DotPopper::Gameplay::GameFlow.new(field, random: Random.new(2))
    @show = new_show(game_flow: @game_flow, layout: layout, sounds: FakeSounds.new, radius: R, sizing_file: @sizing_file)
    @show.open_settings
  end

  # 800 by 600 fits a radius of about 35 with standard dots.
  def test_a_tap_on_a_dot_size_chooses_it_and_it_is_remembered
    refute @game_flow.sizing.standard?
    @show.tap(*middle(@show.reach_of(DotPopper::Gameplay::DotSizing::BIGGER_OR_SMALLER)))
    assert_nil @sizing_file.read, "the chosen one again changes nothing, so nothing is saved"

    @show.tap(*middle(@show.reach_of(DotPopper::Gameplay::DotSizing::STANDARD)))
    assert @game_flow.sizing.standard?
    assert_equal "fitted", @sizing_file.read, "dot_size.txt's word for the default, as every build wrote it"
    assert @show.settings?, "the tap never leaves Settings"
    assert_in_delta 35.4, @show.attract.dots.first.radius, 0.1, "Home's dots follow the choice"
    @show.back
    press_main
    assert_in_delta 35.4, @game_flow.game.field.radius, 0.1
  end

  def test_the_size_that_is_the_same_everywhere_saves_as_standard
    @game_flow.sizing = DotPopper::Gameplay::DotSizing::DEFAULT
    @show.tap(*middle(@show.reach_of(DotPopper::Gameplay::DotSizing::DEFAULT.toggled)))

    assert_equal "standard", @sizing_file.read, "dot_size.txt's word for it, as every build wrote it"
  end

  # On the 24 × 16 R window, the two sizes are the same, so
  # Settings leaves the choice out, and a shoulder button changes nothing.
  def test_where_the_sizes_look_alike_the_choice_is_not_offered
    game_flow = DotPopper::Gameplay::GameFlow.new(field(1200, 800), random: Random.new(2), sizing: DotPopper::Gameplay::DotSizing::STANDARD)
    show = new_show(game_flow:, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R, sizing_file: @sizing_file)
    show.open_settings

    refute show.sizing_offered?
    assert_nil show.reach_of(DotPopper::Gameplay::DotSizing::BIGGER_OR_SMALLER)
    show.pad(:lb)
    assert game_flow.sizing.standard?, "the saved choice stays"
    assert_nil @sizing_file.read
  end

  # Whatever size is saved: with the bigger or smaller size saved there,
  # the choice is left out too, and the saved size stands.
  def test_where_the_sizes_look_alike_the_choice_is_left_out_whatever_size_is_saved
    game_flow = DotPopper::Gameplay::GameFlow.new(field(1200, 800), random: Random.new(2), sizing: DotPopper::Gameplay::DotSizing::BIGGER_OR_SMALLER)
    show = new_show(game_flow:, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R, sizing_file: @sizing_file)
    show.open_settings

    refute show.sizing_offered?
    assert_nil show.reach_of(DotPopper::Gameplay::DotSizing::STANDARD)
    assert_nil show.reach_of(DotPopper::Gameplay::DotSizing::BIGGER_OR_SMALLER)
    show.pad(:lb)
    refute game_flow.sizing.standard?, "the saved choice stays"
    assert_nil @sizing_file.read
  end

  # Standard, the default, is the first segment, as the default was before
  # it was called Standard, so the filled segment does not move for anyone.
  def test_standard_is_the_first_segment
    standard = @show.reach_of(DotPopper::Gameplay::DotSizing::STANDARD)
    other = @show.reach_of(DotPopper::Gameplay::DotSizing::BIGGER_OR_SMALLER)

    assert_operator standard.x, :<, other.x
  end

  def test_a_short_window_scrolls_to_what_does_not_fit
    show = new_show(game_flow: @game_flow, layout: layout(400, 320), sounds: FakeSounds.new, radius: R, window: FakeWindow.new)
    show.open_settings
    assert_nil show.reach_of(:privacy), "Privacy is below the window"

    show.scroll_key(:end)
    assert show.reach_of(:privacy)
    assert_nil show.reach_of([:sound, true]), "Sound has scrolled away above"
  end

  private

  def middle(rect) = [rect.center_x, rect.center_y]
end
