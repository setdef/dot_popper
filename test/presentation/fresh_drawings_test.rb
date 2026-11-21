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
    offer: [{}, ->(show) { show.open_offer_for(:themes) }, {}],
    stats: [{}, ->(show) { show.open_stats }, { "a scroll" => ->(show) { show.wheel_scroll(-3) }, "holding Clear" => ->(show) { show.pad(:y) },
                                                "letting go" => ->(show) { show.screen.release(:y) } }],
    themes: [{ pro: true }, ->(show) { show.open_themes }, { "using the next theme" => ->(show) { show.screen.step(1) } }],
    achievements: [{ pro: true }, ->(show) { show.open_achievements }, { "a scroll" => ->(show) { show.wheel_scroll(-3) } }],
    friend_groups: [{ member: true, pro: true }, ->(show) { show.open_groups }, {
      "a group open" => ->(show) { show.group_panel.press([:group_show, show.group_panel.groups.groups.first.id], :touch, show.now) },
      "holding Leave" => ->(show) { show.group_panel.start(:start, show.now) },
      "letting Leave go" => ->(show) { show.group_panel.let_go(:start, show.now) }, "the next group" => ->(show) { show.group_panel.pad(:rb) },
      "back to the list" => ->(show) { show.group_panel.back }, "the keypad" => ->(show) { show.group_panel.press(:group_join_open, :touch, show.now) },
      "a digit" => ->(show) { show.group_panel.press([:code_digit, "4"], :touch, show.now) }
    }],
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

  # A game that meets every day's goal (DailyGoal::LIST).
  GOAL_MET = DotPopper::Gameplay::GameStats.start.with(most_dots_in_a_row: 15, times_to_pop: [3.0] + ([0.5] * 9), duration: 50.0, mistakes: 0,
                                                      score: 30)

  # A small window, where the list scrolls, and a scroll there.
  SCROLLED = { "a small window" => ->(fixture) { FreshDrawingsTest.resize(fixture, 400, 360) },
               "a scroll" => ->(fixture) { fixture.show.wheel_scroll(-3) } }.freeze

  # What changes under an open screen from outside it, in order: for each
  # screen, the fixtures to open it on (as OPENED opens it), each with the
  # changes to make, each a name and what makes it, given the fixture. A
  # purchase, the day, a game recorded elsewhere, an achievement earned,
  # Pro arriving. After each, every frame for two seconds is checked, as
  # what it sets off goes on by itself.
  OUTSIDE = {
    offer: [[{}, { "a theme released" => ->(fixture) { fixture.saved_themes.release(%w[ornament]) },
                   "a key pressed, which Buy then names" => ->(fixture) { fixture.key(nil) },
                   "buying" => ->(fixture) { fixture.show.screen.pressed(:buy, :mouse) },
                   "pasting the key" => ->(fixture) { fixture.show.screen.pressed(:paste, :mouse) } }],
            # From an achievement's dialog, by a Free player who has earned it,
            # whose thank-you hands it earned (OfferPainterTest).
            [{}, { "it earned" => ->(fixture) { fixture.achievements.award([:steady], day: fixture.day) },
                   "buying" => ->(fixture) { fixture.show.screen.pressed(:buy, :mouse) },
                   "pasting the key" => ->(fixture) { fixture.show.screen.pressed(:paste, :mouse) } }, lambda { |show|
                     show.open_achievements
                     show.open_achievement(:steady)
                     show.achievement_pro
                   }],
            # Closed, and opened again from another achievement's dialog.
            [{}, { "opened again for another" => lambda { |fixture|
              fixture.show.back
              fixture.show.open_achievement(:unshaken)
              fixture.show.achievement_pro
            } }, lambda { |show|
              show.open_achievements
              show.open_achievement(:steady)
              show.achievement_pro
            }]],
    home: [[{}, { "the next day" => ->(fixture) { fixture.day += 1 },
                  "the day's goal met" => ->(fixture) { fixture.saved_stats.record(GOAL_MET, fixture.game_flow.size_class) },
                  "a game spent elsewhere" => ->(fixture) { fixture.games.spend! },
                  "Pro arriving" => ->(fixture) { FreshDrawingsTest.pro(fixture) },
                  "an achievement earned" => ->(fixture) { fixture.achievements.award([:steady], day: fixture.day) } }],
           [{ pro: true }, { "a game played, and Home again" => lambda { |fixture|
             show = fixture.show
             show.screen.primary
             show.game_flow.update(31)
             show.game_flow.update(DotPopper::Gameplay::Rules::GAME_OVER_GRACE)
             fixture.tick(0.5)
             show.back
           } }]],
    themes: [[{ pro: true }, { "a new season" => ->(fixture) { fixture.day = Date.new(2026, 12, 20) },
                               "a theme released" => ->(fixture) { fixture.saved_themes.release(%w[ornament]) } }]],
    achievements: [[{}, { "Pro arriving" => ->(fixture) { FreshDrawingsTest.pro(fixture) } }],
                   [{ pro: true }, SCROLLED],
                   [{ pro: true }, { "an achievement earned" => ->(fixture) { fixture.achievements.award([:steady], day: fixture.day) } }]],
    achievement_dialog: [[{ pro: true }, {
      "a record nearer it" => ->(fixture) { fixture.saved_stats.record(GOAL_MET, fixture.game_flow.size_class) },
      "it earned" => ->(fixture) { fixture.achievements.award([:steady], day: fixture.day) }
    }]],
    change_server: [[{ gone: true }, { "an address pasted" => lambda { |fixture|
      fixture.clipboard.copy("https://dots.example.org")
      fixture.show.screen.pressed(:server_paste, :mouse)
    }, "set back" => ->(fixture) { fixture.show.screen.pressed(:server_reset, :mouse) } }]],
    share_preview: [[{}, { "copied" => ->(fixture) { fixture.show.screen.pressed(:copy, :mouse) } }]],
    credits: [[{}, SCROLLED]],
    stats: [[{}, SCROLLED.merge("the other dot size" => lambda { |fixture|
      fixture.game_flow.sizing = (P::Screens::Settings::SIZINGS - [fixture.game_flow.sizing]).first
    })], [{}, { "a game recorded" => ->(fixture) { fixture.saved_stats.record(GOAL_MET, fixture.game_flow.size_class) } }]],
    # No press of a player's opens a screen over the Tutorial today, but its
    # drawing says Skip is drawn only while it is on top.
    tutorial: [[{ played: false }, { "the offer opened over it" => ->(fixture) { fixture.show.open_offer_for(:themes) } }]]
  }.freeze

  # Pro, bought on the website and its key entered, as from another screen.
  def self.pro(fixture)
    fixture.store.buy
    fixture.entitlement.enter(fixture.clipboard.paste)
    raise "Pro did not arrive" unless fixture.entitlement.pro?
  end

  def self.resize(fixture, width, height)
    sizes = new("sizes")
    fixture.game_flow.screen = sizes.field(width, height)
    fixture.show.resize(sizes.layout(width, height), sizes.field(width, height))
  end

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
        6.times do |frame|
          fixture.tick(0.05)
          check.call("#{what} (frame #{frame})")
        end
      end
      assert_empty stale, "#{name} drew a stale drawing after #{stale.join(", ")}"
      kept = screen.drawing
      fixture.tick(0.05)
      assert_same kept, screen.drawing, "a frame that changes nothing makes nothing"
    end
  end

  OUTSIDE.each do |name, cases|
    cases.each_with_index do |(given, changes, open), n|
      define_method("test_#{name}_draws_what_a_fresh_drawing_would_as_things_change_outside_it_#{n}") do
        fixture = Inputs::Fixture.new(os: "Linux", width: 1200, height: 800, **given)
        show = fixture.show
        show.pointer_gone # so that no change of hover hides one of what changes
        (open || OPENED.fetch(name)[1]).call(show)
        screen = show.screens.fetch(name)
        stale = []
        20.times do |frame| # as it comes in, each frame kept as a frame keeps it
          fixture.tick(0.05)
          stale << "opening (frame #{frame})" unless screen.drawing == fresh(screen)
        end
        assert_same screen, show.screen, "#{name} opens"
        changes.each do |what, change|
          change.call(fixture)
          40.times do |frame|
            fixture.tick(0.05)
            stale << "#{what} (frame #{frame})" unless screen.drawing == fresh(screen)
          end
        end
        assert_empty stale, "#{name} drew a stale drawing after #{stale.first(5).join(", ")}"
      end
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
