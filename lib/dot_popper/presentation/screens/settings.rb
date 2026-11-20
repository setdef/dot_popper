# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Settings, over Home (SettingsLayout): its rows of choices, Credits
      # and licenses, Privacy, Change Server while setdef is gone, and
      # Back. Only the buttons in view take presses.
      class Settings < Page
        include Scrolling

        # The dot-size choices in the order its row draws them: the
        # default, Standard, first.
        SIZINGS = [DotSizing::STANDARD, DotSizing::BIGGER_OR_SMALLER].freeze

        # +sizing_store+ keeps the player's DotSizing.
        def initialize(show, sizing_store:)
          super(show)
          @sizing_store = sizing_store
        end

        # Where its rows and buttons go (SettingsPlan), with its list fitted
        # to the page while it is open.
        def plan
          sounds = self.sounds
          rows = [[:sound, words.button(:sound), :speaker, [[words.button(:on), !sounds.muted?, [:sound, true]], [words.button(:off), sounds.muted?, [:sound, false]]]]]
          if show.sizing_offered?
            game_flow = show.game_flow
            rows << [:dot_size, words.button(:dot_size), :dot, SIZINGS.map { [words.sizing(it, show.sizing_preview), it == game_flow.sizing, it] }]
          end
          rows << [:display, words.button(:display), :corners, display_choices] if show.window.offered?
          plan = SettingsLayout.new(layout:, rows:, offset: scroll ? scroll.offset : 0.0, change_server: show.change_server_offered?).plan
          fit(plan.height, layout.page.height)
          plan
        end

        # Everything its painter draws (SettingsDrawing), made again only
        # when the window, the plan, the words or a button's light changes.
        def drawing
          plan = self.plan
          words = self.words
          hover = show.hover
          preview = show.sizing_preview
          drawn(plan, words, hover, preview) do
            page = layout.page
            safe = layout.safe
            SettingsDrawing.new(header: HeaderDrawing.for(words.button(:settings_heading), layout:, measure:, words:, hover:), plan:,
                                clip: Rect.new(x: safe.x, y: page.y, width: safe.width, height: page.height),
                                choices: plan.rows.map { |row| row.choices.map { |text, chosen, name| [text, chosen, hover.level(name), name] } },
                                sizing_preview: preview, credits: words.button(:credits_licenses), privacy: words.button(:privacy),
                                change_server: words.button(:server), lit: %i[credits privacy change_server].to_h { [it, hover.level(it)] })
          end
        end

        # Sizes dots as +sizing+ (DotSizing) says, while it offers the
        # choice, and remembers it. Home's dots and score record change
        # with it, so the choice shows at once.
        def choose_sizing(sizing)
          game_flow = show.game_flow
          return sounds.play(:tick, pitch: 0.8) if sizing == game_flow.sizing

          game_flow.sizing = sizing
          @sizing_store.write(game_flow.sizing.to_text)
          show.sizing_changed
          sounds.play(:tick, pitch: game_flow.sizing.standard? ? 1.2 : 0.9)
        end

        # Sound on or off, as +on+ says.
        def set_sound(on)
          sounds.toggle_mute if sounds.muted? == on
          sounds.play(:tick)
        end

        # The next of the window's displays, round the end, on a computer.
        def next_display
          window = show.window
          order = %i[window borderless exclusive]
          window.display = order[(order.index(window.display).to_i + 1) % order.size]
        end

        def controls
          plan = self.plan
          rows = plan.rows.flat_map { |row| row.choices.zip(row.rects).map { |(_, _, name), rect| button(name, rect) } }
          page = layout.page
          seen = (rows + [button(:credits, plan.credits), button(:privacy, plan.privacy), *(button(:change_server, plan.change_server) if plan.change_server)])
                 .select { it.frame.center_y.between?(page.y, page.bottom) }
          seen.map { it.with(frame: it.frame.cut(top: page.y, bottom: page.bottom), reach: it.reach.cut(top: page.y, bottom: page.bottom)) } <<
            back_button
        end

        # C opens Credits and licenses.
        def key_bindings = KEY_BINDINGS
        KEY_BINDINGS = [KeyBinding.new(keys: :c, does: :type)].freeze

        def type(key)
          return false unless key == :c

          show.open_credits
          true
        end

        # View/Select Sound, LB Dot size where it is offered, RB Display,
        # X Credits and licenses, Y Privacy.
        def pad(button)
          case button
          in :lb then choose_sizing(show.game_flow.sizing.toggled) if show.sizing_offered?
          in :rb then next_display
          in :x then show.open_credits
          in :y then show.open_privacy
          in :select then set_sound(sounds.muted?)
          else nil
          end
        end

        def answers = [*super, :sound, :dot_size, :display, :credits, :privacy, :change_server]

        def pressed(name, by)
          case name
          in [:sound, on] then set_sound(on)
          in DotSizing => sizing then choose_sizing(sizing)
          in [:display, mode] then show.window.display = mode
          in :credits then show.open_credits
          in :privacy then show.open_privacy
          in :change_server then show.screens.fetch(:change_server).open
          else super
          end
        end

        private

        def display_choices
          window = show.window
          { window: :windowed, borderless: :full_screen_borderless, exclusive: :full_screen }.map { |mode, word| [words.button(word), window.display == mode, [:display, mode]] }
        end
      end
    end
  end
end
