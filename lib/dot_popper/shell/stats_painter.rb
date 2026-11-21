# frozen_string_literal: true

module DotPopper
  module Shell
    # The Stats screen, in cards in a list that scrolls: Highest score and
    # the chart of the last games, the records, the daily goal, and the
    # totals. Back is in one corner; "Clear my stats…" (or, once they are
    # cleared, Undo) is in the other, and while it is held the prompt says
    # what will go.
    class StatsPainter < Data.define(:context)
      DIM = 0.3 # how much of a bar shows when its game counts elsewhere

      # The screen as its +drawing+ (Presentation::StatsDrawing) says, the
      # hold and Undo as they stand at +now+; nothing before it has opened.
      def draw(drawing, now)
        return unless drawing

        plan = drawing.plan
        Header.new(context:).draw(drawing.header)
        context.text(drawing.note, context.fonts.semibold(15), drawing.center_x, plan.note_y, context.palette.soft) if drawing.note
        prompt(drawing, now)
        corner(drawing, now)
        return nothing_yet(drawing) if drawing.sheet.empty

        cards(drawing)
      end

      private

      def cards(drawing)
        sheet = drawing.sheet
        plan = drawing.plan
        window = plan.window
        placed, = plan.cards
        pixels = context.pixels
        context.scissor = pixels.snap(window.x), pixels.snap(window.y), pixels.snap(window.width), pixels.snap(window.height)
        placed.each do |card|
          rect = card.rect.with(y: window.y + card.rect.y - drawing.offset)
          Card.new(context:).draw(rect)
          send(card.kind, sheet, rect)
        end
        context.scissor = nil
      end

      def chart(sheet, rect)
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
          context.rectangle(:fill, bar.x, bar.y, bar.width, bar.height, corner, corner, 8)
        end
      end

      def records(sheet, rect) = rows("Records", sheet.records.rows.drop(1), rect, Presentation::StatsLayout::RECORD_ROW, 18)
      def totals(sheet, rect) = rows(sheet.totals.heading, sheet.totals.rows, rect, Presentation::StatsLayout::TOTAL_ROW, 16)

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
          context.rectangle(:fill, rect.x + pad, context.pixels.snap(y - (height / 2.0)), rect.width - (2 * pad), context.pixels.line_width(1))
        end
      end

      def goal(sheet, rect)
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
      def prompt(drawing, now)
        clearing = drawing.clearing
        hint = context.style::STATS_CLEAR.hint
        ago = clearing.let_go_ago(now)
        if clearing.held? then say(drawing.keep_holding, drawing, 1.0)
        elsif ago && ago < hint then say(drawing.hold_to_clear, drawing, ((hint - ago) / 0.5).clamp(0.0, 1.0))
        end
      end

      def say(text, drawing, alpha)
        font = context.fonts.semibold(15)
        y = drawing.prompt_y
        Presentation::Words.balance(text, drawing.prompt_width) { font.width(it) }.reverse.each_with_index do |line, i|
          context.text(line, font, drawing.center_x, y - (i * font.height), context.palette.cream, alpha)
        end
      end

      def corner(drawing, now)
        if drawing.undo then undo(drawing, now)
        elsif drawing.clear then clear(drawing, now)
        end
      end

      def clear(drawing, now)
        rect = drawing.clear
        held = drawing.clearing.held?
        PillButton.new(context:).draw(rect, drawing.clear_word, hover: drawing.clear_hover)
        return unless held

        outline = Presentation::PillFill.new(rect:, amount: drawing.clearing.progress(now)).outline
        if outline.size >= 6
          context.color(context.palette.alarm, 0.55)
          context.polygon(:fill, *outline)
        end
        PillButton.new(context:).label(rect, drawing.clear_word)
      end

      def undo(drawing, now)
        rect = drawing.undo_rect
        PillButton.new(context:).draw(rect, drawing.undo_word, hover: drawing.undo_hover)
        font = context.fonts.semibold(15)
        text = drawing.cleared
        context.text(text, font, rect.x - 12 - (font.width(text) / 2.0), rect.center_y, context.palette.soft)
        amount = drawing.undo.left(now)
        return unless amount.positive?

        context.color(context.palette.soft, 0.5)
        context.rectangle(:fill, rect.x + (rect.height / 2.0), rect.bottom + 4, [(rect.width - rect.height) * amount, 1.0].max, context.pixels.line_width(3))
      end

      def nothing_yet(drawing)
        context.text(drawing.no_games, context.fonts.semibold(18), drawing.center_x, drawing.center_y, context.palette.soft)
      end

      def left(text, font, x, y, color) = context.text(text, font, x + (font.width(text) / 2.0), y, color)
      def right(text, font, x, y, color) = context.text(text, font, x - (font.width(text) / 2.0), y, color)
    end
  end
end
