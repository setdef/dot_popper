# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The friend groups' screens, over Home: the list, a group, its
      # history and the keypad that joins one, each GroupPanel's page, and
      # the notice a first Join or Create shows over them (GroupLayout,
      # GroupNoticeDialog).
      class FriendGroups < Screen
        include Scrolling

        # Where the open page's parts go (GroupLayout), its list fitted to
        # its window, and scrolled back to its top when the page or the
        # group changes.
        def plan
          panel = show.group_panel
          where = [panel.page, panel.group_id]
          scroll_from_top unless @scrolled_at == where
          @scrolled_at = where
          offset = scroll&.offset || 0.0
          plan = GroupLayout.new(layout:, style: style::GROUPS, measure:, panel:,
                                 back_text: words.go_back, offset:, input: show.input).plan
          fit(plan.content, plan.window.height) if plan.window
          plan
        end

        # Where the notice of a first Join or Create puts its parts, while it
        # is open over the page (GroupNoticePlan), or nil.
        def notice_plan
          panel = show.group_panel
          return unless panel.open? && panel.asking

          GroupNoticeDialog.new(layout:, measure:, policy_text: word(GroupWords.notice_policy),
                                later_text: word(GroupWords.notice_later), go_text: word(GroupWords.notice_go(panel.asking))).plan
        end

        # Everything its painter draws (GroupsDrawing), made again only when
        # the page's plan, the panel's code or hold, the notice, the words or
        # a button's light changes.
        def drawing
          plan = self.plan
          notice = notice_plan
          panel = show.group_panel
          words = self.words
          hover = show.hover
          page = panel.page
          code = page == :group ? (panel.code_shown? ? CodeText.hyphenated(panel.group.join_code) : GroupWords.hidden_code) : panel.code
          holding = panel.holding_words if panel.hold.held?
          asking = panel.asking
          drawn(plan, notice, words, hover, panel.group_id, page, code, panel.code_complete?, holding, asking) do
            GroupsDrawing.new(plan:, heading_size: layout.heading_place(plan.heading, measure).first, back: layout.back_button,
                              back_word: words.go_back, back_hover: hover.level(:back), center_x: layout.center_x, crest: panel.group_id,
                              code:, code_row: page == :group, code_complete: panel.code_complete?,
                              action_hovers: plan.actions.map { hover.level(it.name) },
                              row_hovers: plan.rows.map { it.is_a?(GroupListRow) ? hover.level([:group_show, it.group.id]) : 0.0 },
                              holding:, holding_size: layout.scaled(style::GROUPS.text), holding_bottom: layout.page.bottom - layout.control_height,
                              notice: notice&.then { notice_drawing(it, asking, hover) })
          end
        end

        # Each frame, the panel hears the friend groups' server, and shows
        # a title change's announcement where the screen on top shows one.
        def update(_seconds) = show.group_panel.update(now, quiet: !show.playing?, showing: show.screen.announces?)

        # A hold on Leave, or on Privacy's Delete my friend group data,
        # ends when it is let go.
        def release(by) = show.group_panel.let_go(by, now)

        def cancel_hold = show.group_panel.cancel_hold

        # A game started: the panel waits for its result.
        def game_started = show.group_panel.game_started

        # A friend groups' word (a ByInput), said as the player's input would
        # press it.
        def word(byinput) = byinput.for(show.input)

        def controls = (notice_plan || plan).controls.map { |name, frame| button(name, frame) }

        # The notice of a first Join or Create (GroupNoticeDrawing), asked
        # by +asking+.
        def notice_drawing(plan, asking, hover)
          safe = layout.safe
          GroupNoticeDrawing.new(plan:, veil: Rect.new(x: safe.x - 400, y: safe.y - 400, width: safe.width + 800, height: safe.height + 800),
                                 later_word: word(GroupWords.notice_later), go_word: word(GroupWords.notice_go(asking)),
                                 later_hover: hover.level(:notice_later), go_hover: hover.level(:notice_go), policy_hover: hover.level(:policy))
        end

        def primary = show.group_panel.primary

        # Back up a level (GroupPanel#back).
        def back
          show.group_panel.back
          true
        end

        # Holding Start on a group leaves it; elsewhere it is the main
        # button (GroupPanel#start).
        def start = show.group_panel.start(:start, show.now)

        # The keypad's digits, and Backspace or Delete (GroupPanel#type).
        def key_bindings = KEY_BINDINGS
        KEY_BINDINGS = [KeyBinding.new(keys: [*(0..9).map { it.to_s.to_sym }, :backspace, :delete], does: :type)].freeze

        def type(key) = show.group_panel.type(key)

        # Each page's own (GroupPanel#pad); over the notice, X opens the
        # privacy policy, as it does on Privacy.
        def pad(button)
          return (show.open_policy if button == :x) if show.group_panel.asking

          show.group_panel.pad(button)
        end

        def answers = [:back, :policy, *GroupPanel::ANSWERS]

        # Back, the notice's privacy policy, and every other button the
        # panel's (GroupPanel#press).
        def pressed(name, by)
          case name
          in :back then show.group_panel.back
          in :policy then show.open_policy
          else show.group_panel.press(name, by, show.now)
          end
        end

        # A row of the list of groups.
        def list_row?(name) = show.group_panel.page == :list && (name in [:group_show, _])

        def covers? = true
      end
    end
  end
end
