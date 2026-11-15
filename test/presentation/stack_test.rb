# frozen_string_literal: true

require_relative "inputs"

# The stack of screens (Show#layers, ADR-0018), as a table: each row goes
# somewhere as a finger would, or pushes and pops the stack itself, and
# says what is then on the stack, bottom first, which screen is on top
# (Show#screen), and what the Show's questions answer. Some questions ask
# whether a screen is on top (Show#on_top?: #stats?, #settings?, #themes?,
# #credits?, #server?, #privacy?, #achievements_open?), and some whether
# it is anywhere on the stack (#offer?, #sharing?, #dialog,
# #friend_groups_open?); the rows say which.
class StackTest < Minitest::Test
  include Inputs

  SMALL = { width: 400, height: 320 }.freeze
  DIALOG = DotPopper::Achievement::IDS.first

  # name, the Fixture's options, the steps there, and what is then so.
  # A step is a control a finger presses (Input#press), :play_game
  # (Input#play), or a lambda given the Show.
  ROWS = [
    ["Home has nothing over it", {}, [], { stack: [], top: :home, on_home?: true, stats?: false }],
    ["a screen over Home is pushed over it", {}, [:stats], { stack: %i[stats], top: :stats, on_home?: false, stats?: true }],
    ["a screen over Settings is pushed over it", {}, %i[settings credits],
     { stack: %i[settings credits], top: :credits, settings?: false, credits?: true, on_home?: false }],
    ["Back closes the top one only", {}, %i[settings credits back], { stack: %i[settings], top: :settings, settings?: true, credits?: false }],
    ["Back from the last one is Home", {}, %i[settings back], { stack: [], top: :home, on_home?: true }],
    ["a dialog over its screen: the screen is no longer on top", { pro: true, **SMALL }, [:achievements, [:achievement, DIALOG]],
     { stack: %i[achievements achievement_dialog], top: :achievement_dialog, achievements_open?: false, dialog: DIALOG }],
    ["Close on the dialog is its screen again", { pro: true, **SMALL }, [:achievements, [:achievement, DIALOG], :achievement_close],
     { stack: %i[achievements], top: :achievements, achievements_open?: true, dialog: nil }],
    ["Get Pro closes the dialog before the offer opens", SMALL, [:achievements, [:achievement, DIALOG], :achievement_pro],
     { stack: %i[achievements offer], top: :offer, dialog: nil, offer?: true, achievements_open?: false }],
    ["the offer over the friend groups: they are still open under it", { member: true }, %i[groups group_join_open],
     { stack: %i[friend_groups offer], top: :offer, friend_groups_open?: true, group_open?: true, offer?: true }],
    ["Back from the offer is the friend groups as they were", { member: true }, %i[groups group_join_open back],
     { stack: %i[friend_groups], top: :friend_groups, friend_groups_open?: true, offer?: false }],
    ["the share preview over Game Over", {}, %i[play play_game share], { stack: %i[share_preview], top: :share_preview, sharing?: true }],
    ["the offer over Game Over", { games_left: 1 }, %i[play play_game play_again], { stack: %i[offer], top: :offer, offer?: true }],
    ["a screen open already is not pushed again", {}, [->(show) { 2.times { show.open_layer(:offer) } }],
     { stack: %i[offer], top: :offer }],
    ["a screen under another is not closed", { pro: true, **SMALL }, [:achievements, [:achievement, DIALOG], ->(show) { show.close_layer(:achievements) }],
     { stack: %i[achievements achievement_dialog], top: :achievement_dialog }],
    ["the offer is open while a screen is over it", {}, [:stats, ->(show) { show.open_layer(:offer) && show.open_layer(:credits) }],
     { stack: %i[stats offer credits], top: :credits, offer?: true, stats?: false, credits?: true }],
    ["the share preview is open while a screen is over it", {}, [:play, :play_game, :share, ->(show) { show.open_layer(:offer) }],
     { stack: %i[share_preview offer], top: :offer, sharing?: true }],
    ["the dialog is open while a screen is over it", { pro: true, **SMALL }, [:achievements, [:achievement, DIALOG], ->(show) { show.open_layer(:offer) }],
     { stack: %i[achievements achievement_dialog offer], top: :offer, dialog: DIALOG }],
    ["Home shown empties the stack", {}, [:play, :play_game, :share, ->(show) { show.cabinet.press(show.layout.center_x, show.layout.center_y) }],
     { stack: [], top: :home, on_home?: true, sharing?: false }],
    ["a game started closes the share preview", {}, [->(show) { show.open_layer(:share_preview) }, ->(show) { DotPopperTest.starter_of(show.cabinet).game }],
     { stack: [], top: :game, sharing?: false }]
  ].freeze

  ROWS.each_with_index do |(name, options, steps, expected), i|
    define_method(:"test_#{i}_#{name.tr(" ,:", "_").downcase}") do
      fixture = Fixture.new(os: "Linux", width: 1200, height: 800, **options)
      finger = Finger.new(fixture)
      steps.each do |step|
        case step
        when Proc then step.call(fixture.show)
        when :play_game then assert_equal :pressed, finger.play, "on the way: #{step}"
        else assert_equal :pressed, finger.press(step), "on the way: #{step.inspect}"
        end
      end
      fixture.tick(0.1)
      assert_equal expected, observe(fixture.show, expected.keys)
    end
  end

  # As a screen over Home opens or closes, the lists start again from
  # their top: Back from Credits is Settings at its top.
  def test_a_list_starts_from_its_top_again_as_a_screen_over_it_closes
    fixture = Fixture.new(os: "Linux", **SMALL)
    finger = Finger.new(fixture)
    assert_equal :pressed, finger.press(:settings)
    fixture.show.controls # as a frame lays it out
    assert finger.scroll(1), "Settings scrolls on a small window"
    assert_equal :pressed, finger.press(:credits)
    assert_equal :pressed, finger.press(:back)
    fixture.show.controls

    assert_equal 0.0, fixture.show.scroll.offset
  end

  # A frame passes on every screen: the new theme's card, under no other,
  # takes a press once it has been up a moment.
  def test_the_new_theme_card_hears_the_frames_pass
    fixture = Fixture.new(os: "Linux", width: 1200, height: 800, arrival: true)

    assert_equal :new_theme, fixture.show.screens.key(fixture.show.screen)
    assert_includes fixture.show.controls.map(&:name), :arrival_use
  end

  private

  def observe(show, keys)
    keys.to_h do |key|
      case key
      when :stack then [key, show.layers.map { show.screens.key(it) }]
      when :top then [key, show.screens.key(show.screen)]
      else [key, show.public_send(key)]
      end
    end
  end
end
