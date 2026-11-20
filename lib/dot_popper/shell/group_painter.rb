# frozen_string_literal: true

module DotPopper
  module Shell
    # The friend groups' screens, over Home's dimmed dots, as
    # Presentation::GroupLayout lays them out, each under its heading with
    # Back, and the short announcement a title change shows on Home or at
    # Game Over.
    class GroupPainter < Data.define(:context, :icons)
      def initialize(context:, icons: MemberIconPainter.new(context:)) = super

      def draw(show, layout)
        plan = show.group_plan
        palette = context.palette
        heading = context.fonts.bold(show.heading_place(plan.heading).first)
        context.text(plan.heading, heading, plan.heading_x, plan.heading_y, palette.cream)
        PillButton.new(context:).draw(layout.back_button, show.words.go_back, hover: show.hover.level(:back),
                                  icon: ->(x, y, size) { Glyphs.new(context:).draw(:chevron_left, x, y, size * 0.38) })
        context.text(plan.subheading, context.fonts.semibold(15), layout.center_x, plan.heading_y + (heading.height * 0.62), palette.soft) if plan.subheading
        icons.crest(layout.center_x, plan.crest_y, 22.0, show.group_panel.group_id) if plan.crest_y && show.group_panel.group_id
        lines(plan, layout)
        show.group_panel.page == :group ? code_row(show, plan) : code_box(show, plan)
        buttons(show, plan)
        rows(show, plan)
        hold(show, layout) if show.group_panel.hold.held?
        notice(show, layout)
      end

      # The notice of a first Join or Create, over the screen it was asked
      # from, dimmed: who keeps the scores, the link to the policy with the
      # external-link sign, Not now, and the button that goes on.
      def notice(show, layout)
        plan = show.group_notice_plan or return
        palette = context.palette
        safe = layout.safe
        context.color(palette.ink_edge, 0.72)
        context.rectangle(:fill, safe.x - 400, safe.y - 400, safe.width + 800, safe.height + 800)
        card = plan.card
        context.color(palette.ink_top)
        context.rectangle(:fill, card.x, card.y, card.width, card.height, 22, 22, 32)
        context.color(palette.pill_edge)
        context.line_width = context.pixels.line_width(1.5)
        context.rectangle(:line, card.x, card.y, card.width, card.height, 22, 22, 32)
        font = context.fonts.bold(plan.size)
        plan.lines.each_with_index { |line, i| context.text(line, font, plan.card.center_x, plan.text_y + (plan.line_height * i), palette.cream) }
        link(show, plan)
        words = Presentation::GroupWords
        PillButton.new(context:).draw(plan.later, show.group_word(words.notice_later), hover: show.hover.level(:notice_later))
        PrimaryButton.new(context:).draw(plan.go, show.group_word(words.notice_go(show.group_panel.asking)), hover: show.hover.level(:notice_go))
      end

      # The rows, clipped to the window they scroll in.
      def rows(show, plan)
        window = plan.window
        pixels = context.pixels
        context.scissor = pixels.snap(window.x - 4), pixels.snap(window.y), pixels.snap(window.width + 8), pixels.snap(window.height) if window
        plan.rows.each { row(show, plan, it) }
        context.scissor = nil
      end

      # The announcement at +y+, on a dark pill so it reads over anything,
      # for the moment it shows, with the group's crest and the champion's
      # icon. +announcement+ is nil most of the time.
      def announcement(announcement, now, layout, y)
        return unless announcement

        alpha = announcement.alpha(now)
        font = context.fonts.semibold(Presentation::Pixels.font_size(layout.scaled(context.style::GROUPS.text)))
        height = font.height * 1.9
        width = font.width(announcement.text) + (height * 2.7)
        pixels = context.pixels
        x = pixels.snap(layout.center_x - (width / 2.0))
        top = pixels.snap(y)
        middle = top + (height / 2.0)
        context.color(context.palette.ink_bottom, 0.94 * alpha)
        context.rectangle(:fill, x, top, width, height, height / 2.0, height / 2.0, 32)
        icons.crest(x + (height * 0.55), middle, height * 0.34, announcement.group_id, alpha)
        icons.draw(x + (height * 1.2), middle, height * 0.34, announcement.group_id, announcement.number, alpha)
        context.text(announcement.text, font, x + (height * 1.7) + (font.width(announcement.text) / 2.0), middle, context.palette.cream, alpha)
      end

      private

      def lines(plan, layout)
        palette = context.palette
        font = context.fonts.semibold(plan.size)
        colors = { text: palette.cream, note: palette.soft, alert: palette.alarm }
        plan.lines.each { context.text(it.text, font, layout.center_x, it.y, colors.fetch(it.kind)) }
      end

      # The code tapped so far, one box for each of its seven places, a
      # hyphen after the third, as a code is shared: 482-1073. The next
      # place to fill is outlined, and a place still to come shows a dash.
      def code_box(show, plan)
        rect = plan.code_box or return
        panel = show.group_panel
        places = Presentation::CodeText.places(panel.code, Gameplay::Groups::JoinCode::LENGTH)
        gap = 6.0
        hyphen = rect.height * 0.35
        width = [(rect.width - hyphen - (gap * places.size)) / places.size, rect.height * 0.85].min
        x = rect.center_x - (((width * places.size) + hyphen + (gap * places.size)) / 2.0)
        font = context.fonts.bold((rect.height * 0.5).round)
        places.each_with_index do |digit, i|
          if i == Presentation::CodeText::FIRST
            context.text("-", font, x + (hyphen / 2.0), rect.center_y, context.palette.soft)
            x += hyphen + gap
          end
          box = Presentation::Rect.new(x:, y: rect.y, width:, height: rect.height)
          Card.new(context:).draw(box, corner: 10.0, edge: (context.palette.cream if i == panel.code.size))
          context.text(digit || "–", font, box.center_x, box.center_y, digit ? context.palette.cream : context.palette.soft)
          x += width + gap
        end
      end

      # Every button but a row's: a row is drawn as a row, the keypad's
      # keys as keys, and the code's Show or Copy in its row.
      SIGNS = { group_join_open: :keypad, group_create: :plus, group_history: :history, group_leave: :leave, group_code: nil }.freeze

      def buttons(show, plan)
        plan.actions.each do |action|
          next if !action.text || action.name == :back
          next key(show, action) if key?(action.name)
          next step(show, action) if %i[group_prev group_next].include?(action.name)

          sign = SIGNS[action.name]
          leave = action.name == :group_leave
          color = leave ? context.palette.alarm : context.palette.cream
          icon = (->(x, y, size) { Glyphs.new(context:).draw(sign, x, y, size * 0.4, color:) } if sign)
          PillButton.new(context:).draw(action.rect, action.text, hover: show.hover.level(action.name), color:, icon:, edge: (context.palette.alarm if leave))
        end
      end

      # The group's code, hidden until Show is pressed: "Code", the code or
      # its dots, and Show or Copy at the row's end.
      def code_row(show, plan)
        rect = plan.code_box or return
        panel = show.group_panel
        Card.new(context:).draw(rect)
        small = context.fonts.semibold(15)
        context.text("Code", small, rect.x + 18 + (small.width("Code") / 2.0), rect.center_y, context.palette.soft)
        code = panel.code_shown? ? Presentation::CodeText.hyphenated(panel.group.join_code) : Presentation::GroupWords.hidden_code
        font = context.fonts.bold(24)
        context.text(code, font, rect.center_x, rect.center_y, context.palette.cream)
      end

      def key?(name) = (name in [:code_digit, String] | :code_erase | :code_submit)

      # A key of the keypad: a digit, Delete with its sign, or Join, which
      # looks disabled until all seven digits are in.
      def key(show, action)
        rect = action.rect
        open = action.name != :code_submit || show.group_panel.code_complete?
        hover = open ? show.hover.level(action.name) : 0.0
        Card.new(context:).draw(rect, corner: [rect.height * 0.22, 14.0].min, alpha: open ? 1.0 : 0.5, lit: hover)
        digit = action.name.is_a?(Array)
        font = digit ? context.fonts.bold((rect.height * 0.42).round) : context.fonts.semibold((rect.height * 0.3).round)
        color = open ? context.palette.cream : context.palette.soft
        return context.text(action.text, font, rect.center_x, rect.center_y, color, open ? 1.0 : 0.6) unless action.name == :code_erase

        mark = rect.height * 0.36
        left = rect.center_x - ((mark + 8 + font.width(action.text)) / 2.0)
        Glyphs.new(context:).draw(:backspace, left + (mark / 2.0), rect.center_y, mark)
        context.text(action.text, font, left + mark + 8 + (font.width(action.text) / 2.0), rect.center_y, color)
      end

      # LB or RB, the previous or the next group, with its chevron.
      def step(show, action)
        back = action.name == :group_prev
        PillButton.new(context:).draw(action.rect, action.text, hover: show.hover.level(action.name),
                                  icon: ->(x, y, size) { Glyphs.new(context:).draw(back ? :chevron_left : :chevron_right, x, y, size * 0.36) })
      end

      # "Read the privacy policy", underlined in the bright dot's gold, with
      # the external-link sign after it, brighter under the mouse.
      def link(show, plan)
        rect = plan.policy
        font = context.fonts.semibold(plan.link_size)
        text = plan.policy_text
        color = context.palette.bright_body.mix(context.palette.bright_light, 0.6 * show.hover.level(:policy))
        left = rect.center_x - ((font.width(text) + 26) / 2.0)
        context.text(text, font, left + (font.width(text) / 2.0), rect.center_y, color)
        Glyphs.new(context:).draw(:external, left + font.width(text) + 14, rect.center_y - 1, font.height * 0.8, color:)
        under = context.pixels.snap(rect.center_y + (font.height * 0.5))
        context.line_width = context.pixels.line_width(1.5)
        context.line(left, under, left + font.width(text) + 26, under)
      end

      def quiet?(name) = name == :group_leave

      def row(show, plan, row)
        case row
        in Presentation::GroupListRow then list_row(show, plan, row)
        in Presentation::GroupStandingRow then standing_row(plan, row)
        in Presentation::GroupHistoryRow then history_row(plan, row)
        end
      end

      # A group's crest and name, the crown glyph where the player holds its
      # title, its top score, and the arrow that opens it.
      def list_row(show, plan, row)
        rect = row.rect
        group = row.group
        Card.new(context:).draw(rect, lit: show.hover.level([:group_show, group.id]))
        radius = rect.height * 0.32
        icons.crest(rect.x + 14 + radius, rect.center_y, radius, group.id)
        font = context.fonts.bold(plan.size)
        name = Presentation::Names.group(group.id)
        context.text(name, font, rect.x + 28 + (radius * 2) + (font.width(name) / 2.0), rect.center_y, context.palette.cream)
        score = group.top_score.to_s
        big = context.fonts.bold(plan.size + 8)
        right = rect.right - 46
        context.text(score, big, right - (big.width(score) / 2.0), rect.center_y, context.palette.bright_body)
        Glyphs.new(context:).draw(:chevron_right, rect.right - 22, rect.center_y, 16, color: context.palette.soft)
        return unless group.champion?

        Glyphs.new(context:).draw(:crown, right - big.width(score) - 26, rect.center_y, 24, color: context.palette.bright_body)
      end

      # A member's rank, icon and name, Champion or You under it, and their
      # score; the player's own row outlined.
      def standing_row(plan, row)
        rect = row.rect
        Card.new(context:).draw(rect, edge: (context.palette.bright_body if row.me))
        small = context.fonts.semibold(13)
        font = context.fonts.bold(plan.size)
        rank = row.rank.to_s
        context.text(rank, small, rect.x + 20, rect.center_y, context.palette.soft)
        radius = rect.height * 0.32
        icons.draw(rect.x + 40 + radius, rect.center_y, radius, row.group_id, row.number)
        x = rect.x + 52 + (radius * 2)
        name = Presentation::Names.member(row.group_id, row.number)
        tag = (Presentation::GroupWords.champion if row.champion) || (Presentation::GroupWords.you if row.me)
        y = tag ? rect.center_y - (font.height * 0.38) : rect.center_y
        context.text(name, font, x + (font.width(name) / 2.0), y, context.palette.cream)
        if tag
          tag_x = x
          if row.champion
            Glyphs.new(context:).draw(:crown, x + 8, rect.center_y + (font.height * 0.45), 14, color: context.palette.bright_body)
            tag_x += 20
          end
          context.text(tag, small, tag_x + (small.width(tag) / 2.0), rect.center_y + (font.height * 0.45), context.palette.bright_body)
        end
        score = row.score.to_s
        big = context.fonts.bold(plan.size + 6)
        context.text(score, big, rect.right - 18 - (big.width(score) / 2.0), rect.center_y, context.palette.cream)
      end

      # Who took the title from whom, or who earned which achievement, the
      # names in bold, and when, in the player's own time.
      def history_row(plan, row)
        rect = row.rect
        Card.new(context:).draw(rect)
        change = row.change
        number = change.is_a?(Gameplay::Groups::MemberAchievement) ? change.member_number : change.champion_number
        radius = rect.height * 0.3
        icons.draw(rect.x + 14 + radius, rect.center_y, radius, row.group_id, number)
        left = rect.x + 28 + (radius * 2)
        room = rect.right - 14 - left
        bold = context.fonts.bold(plan.size - 1)
        plain = context.fonts.semibold(plan.size - 1)
        lines = runs_in_lines(Presentation::GroupWords.entry(row.group_id, change), room, bold, plain).first(2)
        small = context.fonts.semibold(13)
        top = rect.center_y - (((lines.size * bold.height) + small.height) / 2.0)
        lines.each_with_index do |line, i|
          x = left
          line.each do |text, strong|
            face = strong ? bold : plain
            context.text(text, face, x + (face.width(text) / 2.0), top + (bold.height * (i + 0.5)), strong ? context.palette.cream : context.palette.soft)
            x += face.width(text)
          end
        end
        stamp = Presentation::GroupWords.when(change.at)
        context.text(stamp, small, left + (small.width(stamp) / 2.0), top + (lines.size * bold.height) + (small.height / 2.0), context.palette.soft)
      end

      # Runs of [text, bold] broken into lines no wider than +room+, at
      # word boundaries.
      def runs_in_lines(runs, room, bold, plain)
        lines = [[]]
        width = 0.0
        runs.each do |text, strong|
          face = strong ? bold : plain
          text.split(/(?<= )/).each do |word|
            wide = face.width(word)
            if width + wide > room && !lines.last.empty?
              lines << []
              width = 0.0
              word = word.lstrip
              wide = face.width(word)
            end
            last = lines.last.last
            last && last[1] == strong ? last[0] += word : lines.last << [+word, strong]
            width += wide
          end
        end
        lines
      end

      def backing(rect, lit)
        pixels = context.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        context.color(context.palette.ink_bottom, 0.5 + (0.3 * lit))
        context.rectangle(:fill, x, y, width, height, height / 2.0, height / 2.0, 32)
      end

      # While a long press is held, what it will do.
      def hold(show, layout)
        font = context.fonts.semibold(layout.scaled(context.style::GROUPS.text))
        y = layout.page.bottom - layout.control_height - (font.height * 1.2)
        context.text(show.group_panel.holding_words, font, layout.center_x, y, context.palette.cream)
      end
    end
  end
end
