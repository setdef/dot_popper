# frozen_string_literal: true

require_relative "presentation_helper"

# The Show tells every screen, open or not, what it needs to hear
# (Screens::Screen#update and the rest), so a screen with state of its
# own is told without the Show naming it.
class ScreenHooksTest < Minitest::Test
  include PresentationTest

  HOOKS = %i[update release cancel_hold page_changed home_shown game_started resized input_used].freeze

  def setup
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2))
    @show = new_show(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R)
    @heard = @show.screens.transform_values { hear(it) }
  end

  def test_every_screen_hears_each_thing_the_show_tells
    @show.update(0.1)
    @show.let_go(:mouse)
    @show.let_go_of_everything
    @show.open_stats
    @show.back
    @show.input = InputKind::GAMEPAD
    @show.resize(layout(640, 480), field(640, 480))
    press_main
    @cabinet.update(30)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main

    missed = @heard.filter_map { |name, heard| "#{name} missed #{(HOOKS - heard).join(", ")}" unless (HOOKS - heard).empty? }
    assert_empty missed
  end

  def test_a_screen_over_home_opening_and_closing_is_told_twice
    @show.open_stats
    @show.back

    assert_equal [2], @heard.values.map { it.count(:page_changed) }.uniq
  end

  private

  # What +screen+ hears, as it hears it, still doing what it does.
  def hear(screen)
    heard = []
    HOOKS.each do |hook|
      screen.singleton_class.define_method(hook) do |*args|
        heard << hook
        super(*args)
      end
    end
    heard
  end
end
