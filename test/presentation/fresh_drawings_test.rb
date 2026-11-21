# frozen_string_literal: true

require_relative "presentation_helper"
require_relative "inputs"

# A screen keeps the drawing it hands its painter (Memo) until what the
# drawing is made from changes. Whatever changes, the window's size above
# all, the drawing it hands over must be the one it would make afresh, or
# the painter draws a screen that is no longer there: Back drawn where a
# press no longer reaches it, or a list cut short.
class FreshDrawingsTest < Minitest::Test
  include PresentationTest

  P = DotPopper::Presentation

  # How to open each screen that has a drawing: the fixture it needs,
  # what opens it, and the changes of its own a player can make there
  # (each a name and what makes it). A screen given a drawing is named
  # here, and is then checked like the rest.
  OPENED = {
    settings: [{}, ->(show) { show.open_settings }, { "sound off" => ->(show) { show.screen.set_sound(false) } }],
    credits: [{}, lambda { |show|
      show.open_settings
      show.open_credits
    }, { "a scroll" => ->(show) { show.wheel_scroll(-3) } }],
    privacy: [{ member: true }, lambda { |show|
      show.open_settings
      show.open_privacy
    }, { "holding Delete" => ->(show) { show.pad(:y) }, "letting go" => ->(show) { show.group_panel.let_go(:y, show.now) } }],
    change_server: [{ gone: true }, lambda { |show|
      show.open_settings
      show.open_change_server
    }, {}],
    new_theme: [{ new_theme: true, pro: true }, ->(_show) {}, {}],
    home: [{}, ->(_show) {}, { "asked to quit" => ->(show) { show.screen.ask_to_quit } }],
    tutorial: [{ played: false }, ->(show) { show.screen.primary }, {}],
    themes: [{ pro: true }, ->(show) { show.open_themes }, { "using the next theme" => ->(show) { show.screen.step(1) } }],
    achievements: [{ pro: true }, ->(show) { show.open_achievements }, { "a scroll" => ->(show) { show.wheel_scroll(-3) } }],
    achievement_dialog: [{ pro: true }, lambda { |show|
      show.open_achievements
      show.open_achievement(:steady)
    }, { "the next" => ->(show) { show.screen.step(1) } }],
    game_over: [{ pro: true }, lambda { |show|
      show.screen.primary
      show.game_flow.update(31)
    }, { "its grace over" => ->(show) { show.game_flow.update(DotPopper::Gameplay::Rules::GAME_OVER_GRACE) } }],
    share_preview: [{}, ->(show) { show.screens.fetch(:share_preview).open_with(P::ShareText.open("🟡 27 dots\n⏱ 30s", show.now)) }, {}]
  }.freeze

  # Sizes a desktop window is dragged to, one after another: some change
  # only the height, which moves Back and the page but may leave a plan
  # equal to the last.
  SIZES = [[1200, 900], [500, 700], [500, 900], [500, 700], [400, 850], [850, 400], [850, 450], [400, 320], [400, 360],
           [1200, 800]].freeze

  def test_every_screen_with_a_drawing_is_checked
    show = Inputs::Fixture.new(os: "Linux", width: 1200, height: 800).show
    drawn = show.screens.select { |_, screen| screen.respond_to?(:drawing) }.keys
    assert_equal drawn.sort, OPENED.keys.sort, "a screen with a drawing needs a line in OPENED"
  end

  OPENED.each do |name, (given, open, changes)|
    define_method("test_#{name}_draws_what_a_fresh_drawing_would") do
      fixture = Inputs::Fixture.new(os: "Linux", width: 1200, height: 800, **given)
      show = fixture.show
      open.call(show)
      fixture.tick(1.0)
      screen = show.screens.fetch(name)
      assert_same screen, show.screen, "#{name} opens"
      stale = []
      check = ->(what) { stale << what unless screen.drawing == fresh(screen) }
      check.call("opening")
      SIZES.each do |width, height|
        fixture.game_flow.screen = field(width, height)
        show.resize(layout(width, height), field(width, height))
        fixture.tick(0.05)
        check.call("a resize to #{width}x#{height}")
      end
      [P::InputKind::GAMEPAD, P::InputKind::TOUCH, P::InputKind::MOUSE].each do |kind|
        show.input = kind
        fixture.tick(0.05)
        check.call("input by #{kind}")
      end
      screen.controls.each do |control|
        show.pointer_at(control.frame.center_x, control.frame.center_y)
        fixture.tick(0.1)
        check.call("the mouse over #{control.name}")
      end
      show.pointer_gone
      fixture.tick(1.0)
      check.call("the mouse gone")
      changes.each do |what, change|
        change.call(show)
        fixture.tick(0.3)
        check.call(what)
      end
      assert_empty stale, "#{name} drew a stale drawing after #{stale.join(", ")}"
      kept = screen.drawing
      fixture.tick(0.05)
      assert_same kept, screen.drawing, "a frame that changes nothing makes nothing"
    end
  end

  private

  # The drawing +screen+ would make with nothing kept: each of its Memos
  # emptied for the call, and put back after.
  def fresh(screen)
    kept = screen.instance_variables.to_h { [it, screen.instance_variable_get(it)] }.select { |_, value| value.is_a?(P::Memo) }
    kept.each_key { screen.instance_variable_set(it, P::Memo.new) }
    screen.drawing
  ensure
    kept&.each { |name, memo| screen.instance_variable_set(name, memo) }
  end
end
