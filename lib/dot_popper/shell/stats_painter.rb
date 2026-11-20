# frozen_string_literal: true

module DotPopper
  module Shell
    # The Stats screen, in cards in a list that scrolls: Highest score and
    # the chart of the last games, the records, the daily goal, and the
    # totals. Back is in one corner; "Clear my stats…" (or, once they are
    # cleared, Undo) is in the other, and while it is held the prompt says
    # what will go.
    class StatsPainter < Data.define(:context)
      G = ::Lota::Graphics
      DIM = 0.3 # how much of a bar shows when its game counts elsewhere

      def draw(show, layout)
        sheet = show.stats or return
        words = show.words
        plan = show.stats_layout
        Header.new(context:).draw(show, layout, words.stats)
        note = show.stats_note
        context.text(note, context.fonts.semibold(15), layout.center_x, plan.note_y, context.palette.soft) if note
        prompt(show, layout)
        corner(show, layout)
        return nothing_yet(words, layout) if sheet.empty

        cards(show, sheet, plan)
      end

      private

      def cards(show, sheet, plan)
        window = plan.window
        placed, height = plan.cards
        scroll = show.list_fit(height, window.height)
        pixels = context.pixels
        G.scissor = pixels.snap(window.x), pixels.snap(window.y), pixels.snap(window.width), pixels.snap(window.height)
        placed.each do |card|
          rect = card.rect.with(y: window.y + card.rect.y - scroll.offset)
          Card.new(context:).draw(rect)
          send(card.kind, show, sheet, rect)
        end
        G.scissor = nil
      end

      def chart(show, sheet, rect)
        palette = context.palette
        pad = 14.0
        label = context.fonts.semibold(14)
        left(sheet.records.rows.first.label, label, rect.x + pad, rect.y + 22, palette.soft)
        big = context.fonts.bold(rect.height > 200 ? 56 : 44)
        Lettering.new(context:).candy(sheet.records.rows.first.value, big, rect.x + pad + (big.width(sheet.records.rows.first.value) / 2.0), rect.y + 22 + (big.height * 0.72), 1.0, face: palette.bright_body, side: palette.bright_deep)
        caption = Presentation::Words.last_games(sheet.scores.size)
        right(caption, label, rect.right - pad, rect.y + 22 + (big.height * 1.05), palette.soft)
        top = rect.y + 22 + (big.height * 1.35)
        note = sheet.chart_note ? 22.0 : 0.0
        bars(sheet, Presentation::Rect.new(x: rect.x + pad, y: top, width: rect.width - (2 * pad), height: rect.bottom - top - 12 - note))
        left(sheet.chart_note, context.fonts.semibold(13), rect.x + pad, rect.bottom - 16, palette.soft) if sheet.chart_note
      end

      def bars(sheet, box)
        palette = context.palette
        Presentation::ScoreBars.new(scores: sheet.scores, mine: sheet.mine).bars(box, context.pixels).each do |bar|
          context.color(bar.score_record ? palette.bright_light : palette.bright_body.mix(palette.bright_deep, 0.45), bar.dim ? DIM : 1.0)
          corner = [bar.width / 3.0, 2.0].min
          G.rectangle(:fill, bar.x, bar.y, bar.width, bar.height, corner, corner, 8)
        end
      end

      def records(_show, sheet, rect) = rows("Records", sheet.records.rows.drop(1), rect, Presentation::StatsLayout::RECORD_ROW, 18)
      def totals(_show, sheet, rect) = rows(sheet.totals.heading, sheet.totals.rows, rect, Presentation::StatsLayout::TOTAL_ROW, 16)

      def rows(heading, rows, rect, height, size)
        palette = context.palette
        pad = 16.0
        left(heading, context.fonts.semibold(14), rect.x + pad, rect.y + 16, palette.soft)
        # One size for every row of the card: the largest at which each
        # row's label fits beside its value.
        # a label that still does not fit breaks onto two lines.
        room = rect.width - (2 * pad) - 14
        least = (size * 0.8).round
        size -= 1 while size > least && rows.any? { context.fonts.semibold(size).width(it.label) + context.fonts.bold(size).width(it.value) > room }
        font = context.fonts.semibold(size)
        rows.each_with_index do |row, i|
          y = rect.y + 30 + (i * height) + (height / 2.0)
          lines = Presentation::Words.wrap(row.label, room - context.fonts.bold(size).width(row.value)) { font.width(it) }
          lines = [row.label] if lines.size > 2
          step = [font.height * 0.95, height / 2.0].min
          lines.each_with_index { |line, n| left(line, font, rect.x + pad, y + ((n - ((lines.size - 1) / 2.0)) * step), palette.cream) }
          right(row.value, context.fonts.bold(size), rect.right - pad, y, palette.cream)
          next if i.zero?

          context.color(palette.soft, 0.18)
          G.rectangle(:fill, rect.x + pad, context.pixels.snap(y - (height / 2.0)), rect.width - (2 * pad), context.pixels.line_width(1))
        end
      end

      def goal(show, sheet, rect)
        palette = context.palette
        left(sheet.goal.heading, context.fonts.semibold(14), rect.x + 14, rect.y + 16, palette.soft)
        rows = sheet.goal.rows
        [rows[0], rows[1]].each_with_index do |row, i|
          x = rect.x + (rect.width * (i.zero? ? 0.27 : 0.73))
          context.text(row.value[/\d+/].to_s, context.fonts.bold(26), x, rect.y + 40, palette.cream)
          context.text(row.label, fit_label(row.label, 14, rect.width * 0.46), x, rect.y + 64, palette.soft)
        end
      end

      def fit_label(text, size, room)
        size -= 1 while size > 11 && context.fonts.semibold(size).width(text) > room
        context.fonts.semibold(size)
      end

      # While "Clear my stats…" is held, what holding it will clear; and
      # for a moment after a press let go too soon, that it must be held.
      def prompt(show, layout)
        words = show.words
        clearing = show.clearing
        hint = context.style::STATS_CLEAR.hint
        ago = clearing.let_go_ago(show.now)
        if clearing.held? then say(words.keep_holding(show.holding_button), layout, 1.0)
        elsif ago && ago < hint then say(words.hold_to_clear, layout, ((hint - ago) / 0.5).clamp(0.0, 1.0))
        end
      end

      def say(text, layout, alpha)
        font = context.fonts.semibold(15)
        y = layout.short? ? layout.safe.bottom - 14 : layout.back_button.y - 14
        Presentation::Words.balance(text, layout.safe.width - 32) { font.width(it) }.reverse.each_with_index do |line, i|
          context.text(line, font, layout.center_x, y - (i * font.height), context.palette.cream, alpha)
        end
      end

      def corner(show, layout)
        if (offer = show.undo_offer) then undo(show, offer, layout)
        elsif show.clear_offered? then clear(show, layout)
        end
      end

      def clear(show, layout)
        rect = layout.clear_stats_button
        held = show.clearing.held?
        hover = show.hover.level(:clear)
        PillButton.new(context:).draw(rect, show.words.clear, hover:)
        return unless held

        outline = Presentation::PillFill.new(rect:, amount: show.clearing.progress(show.now)).outline
        if outline.size >= 6
          context.color(context.palette.alarm, 0.55)
          G.polygon(:fill, *outline)
        end
        PillButton.new(context:).label(rect, show.words.clear)
      end

      def undo(show, offer, layout)
        rect = layout.undo_button
        PillButton.new(context:).draw(rect, show.words.undo, hover: show.hover.level(:undo))
        font = context.fonts.semibold(15)
        text = show.words.cleared
        context.text(text, font, rect.x - 12 - (font.width(text) / 2.0), rect.center_y, context.palette.soft)
        amount = offer.left(show.now)
        return unless amount.positive?

        context.color(context.palette.soft, 0.5)
        G.rectangle(:fill, rect.x + (rect.height / 2.0), rect.bottom + 4, [(rect.width - rect.height) * amount, 1.0].max, context.pixels.line_width(3))
      end

      def nothing_yet(words, layout)
        context.text(words.no_games, context.fonts.semibold(18), layout.center_x, layout.center_y, context.palette.soft)
      end

      def left(text, font, x, y, color) = context.text(text, font, x + (font.width(text) / 2.0), y, color)
      def right(text, font, x, y, color) = context.text(text, font, x - (font.width(text) / 2.0), y, color)
    end
  end
end
