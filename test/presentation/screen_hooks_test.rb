# frozen_string_literal: true

require_relative "presentation_helper"

# The Show tells every screen, open or not, what it needs to hear
# (Screens::Screen#update and the rest), so a screen with state of its
# own is told without the Show naming it.
class ScreenHooksTest < Minitest::Test
  include PresentationTest

  HOOKS = %i[update release cancel_hold page_changed game_started resized input_used].freeze

  def setup
    @game_flow = DotPopper::Gameplay::GameFlow.new(field, random: Random.new(2))
    @show = new_show(game_flow: @game_flow, layout: layout, sounds: FakeSounds.new, radius: R)
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
    @game_flow.update(30)
    @game_flow.update(DotPopper::Gameplay::Rules::GAME_OVER_GRACE)
    press_main

    missed = @heard.filter_map { |name, heard| "#{name} missed #{(HOOKS - heard).join(", ")}" unless (HOOKS - heard).empty? }
    assert_empty missed
  end

  def test_a_screen_over_home_opening_and_closing_is_told_twice
    @show.open_stats
    @show.back

    assert_equal [2], @heard.values.map { it.count(:page_changed) }.uniq
  end

  # The window losing focus stops a hold of Privacy's Delete my friend
  # group data, which is the friend groups' panel's.
  def test_losing_focus_stops_the_friend_groups_hold
    @show.open_settings
    @show.open_privacy
    @show.pad(:y)
    assert_predicate @show.group_panel.hold, :held?

    @show.let_go_of_everything
    refute_predicate @show.group_panel.hold, :held?
  end

  # A game started: the friend groups forget the last game's result, so
  # the next Game Over never shows it while its own is on the way.
  def test_a_game_started_forgets_the_last_games_result_for_the_friend_groups
    session = DotPopper::Gameplay::Groups::Session.off
    session.instance_variable_set(:@result_due, true) # as a game that counts finishes
    show = new_show(game_flow: DotPopper::Gameplay::GameFlow.new(field, random: Random.new(2)), layout:, sounds: FakeSounds.new, radius: R, groups: session)
    assert_equal " ", show.group_panel.game_line, "a result on its way holds the line's place"
    press_main(show)

    assert_nil show.group_panel.game_line
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
