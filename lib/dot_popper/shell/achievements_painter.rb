# frozen_string_literal: true

module DotPopper
  module Shell
    # The Achievements screen, a grid of icons a tap explains, and the
    # dialog over it: name, how it is earned, and for Pro the day or the
    # progress.
    class AchievementsPainter < Data.define(:context)
      # The grid as its +drawing+ (Presentation::AchievementsDrawing) says.
      def draw(drawing)
        Header.new(context:).draw(drawing.header)
        context.text(drawing.count, context.fonts.semibold(16), drawing.count_x, drawing.count_y, context.palette.soft) if drawing.count
        window = drawing.window
        pixels = context.pixels
        context.scissor = pixels.snap(window.x), pixels.snap(window.y), pixels.snap(window.width), pixels.snap(window.height)
        drawing.cells.each { cell(it) }
        context.scissor = nil
        PillButton.new(context:).draw(drawing.how_to_earn, drawing.how_to_earn_word) if drawing.how_to_earn
      end

      # An achievement's dialog as its +drawing+ (Presentation::
      # AchievementDialogDrawing) says.
      def dialog(drawing)
        plan = drawing.plan
        shade(drawing.shade)
        card(plan.card)
        emblem(drawing.id, plan.card.center_x, plan.icon_y, plan.radius, drawing.earned)
        context.text(drawing.name, context.fonts.bold(32), plan.card.center_x, plan.name_y, context.palette.cream)
        status(drawing) if drawing.status
        font = context.fonts.semibold(plan.line_size)
        plan.lines.each_with_index { |line, i| context.text(line, font, plan.card.center_x, plan.lines_y + (font.height * (i + 0.5)), context.palette.cream) }
        progress(drawing) if drawing.progress
        buttons(drawing.buttons)
      end

      # An achievement's sign at +x+, +y+, +radius+ across: on gold where
      # +earned+, and in a dashed ring where not yet, as the grid shows it
      # and the offer of Pro shows the one tapped.
      def emblem(id, x, y, radius, earned, lit: 0.0)
        palette = context.palette
        if earned
          context.color(palette.bright_body.mix(palette.bright_light, 0.2))
          context.circle(:fill, x, y, radius, 64)
          context.color(palette.cream)
          context.line_width = context.pixels.line_width(1)
          context.circle(:line, x, y, radius, 64)
        else
          context.color(palette.ink_bottom, 0.7)
          context.circle(:fill, x, y, radius, 64)
          context.color(palette.soft, 0.45)
          context.line_width = context.pixels.line_width(1.2)
          dashes(x, y, radius)
        end
        context.color(palette.cream, 0.2 * lit)
        context.circle(:fill, x, y, radius, 64) if lit.positive?
        glyph = Presentation::AchievementWords.glyph(id)
        Glyphs.new(context:).draw(glyph, x, y, radius * 1.15, color: earned ? palette.ink_bottom : palette.soft, weight: 2.0)
      end

      private

      def cell(drawn)
        cell = drawn.cell
        earned = drawn.earned
        emblem(cell.id, cell.x, cell.y, cell.radius, earned, lit: drawn.hover)
        name = drawn.name
        lines = Presentation::Words.wrap(name, cell.radius * 2.8) { context.fonts.semibold(15).width(it) }
        font = context.fonts.semibold(15)
        lines.each_with_index { |line, i| context.text(line, font, cell.x, cell.name_y + (font.height * i), earned ? context.palette.cream : context.palette.soft) }
      end

      def dashes(x, y, radius)
        segments = 36
        segments.times do |i|
          next if i.odd?

          a = i * 2 * Math::PI / segments
          b = (i + 1) * 2 * Math::PI / segments
          context.line(x + (radius * Math.cos(a)), y + (radius * Math.sin(a)), x + (radius * Math.cos(b)), y + (radius * Math.sin(b)))
        end
      end

      def status(drawing)
        plan = drawing.plan
        text = drawing.status
        font = context.fonts.semibold(17)
        if drawing.earned
          x = plan.card.center_x - (font.width(text) / 2.0) - 14
          Glyphs.new(context:).draw(:check, x, plan.status_y, 15, color: context.palette.gain)
          context.text(text, font, plan.card.center_x + 8, plan.status_y, context.palette.gain)
        else
          context.text(text, font, plan.card.center_x, plan.status_y, context.palette.soft)
        end
      end

      def progress(drawing)
        have, goal = drawing.progress
        rect = drawing.plan.bar
        small = context.fonts.semibold(15)
        label = drawing.progress_label
        context.text(label, small, rect.x + (small.width(label) / 2.0), rect.y - 16, context.palette.soft)
        count = "#{have} of #{goal}"
        context.text(count, small, rect.right - (small.width(count) / 2.0), rect.y - 16, context.palette.cream)
        context.color(context.palette.ink_bottom, 0.8)
        context.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, rect.height / 2.0, rect.height / 2.0, 12)
        share = [have.to_f / goal, 1.0].min
        context.color(context.palette.bright_body)
        context.rectangle(:fill, rect.x, rect.y, [rect.width * share, rect.height].max, rect.height, rect.height / 2.0, rect.height / 2.0, 12) if share.positive?
      end

      def buttons(buttons)
        buttons.each do |button|
          rect = button.rect
          case button.name
          when :achievement_pro
            PrimaryButton.new(context:).draw(rect, button.word, hover: button.hover, ratio: PillButton::LABEL)
          when :achievement_close
            PillButton.new(context:).draw(rect, button.word, hover: button.hover)
          when :achievement_prev
            step(button, :chevron_left, "LB")
          when :achievement_next
            step(button, :chevron_right, "RB")
          end
        end
      end

      def step(button, glyph, word)
        PillButton.new(context:).draw(button.rect, word, hover: button.hover,
                                      icon: ->(x, y, size) { Glyphs.new(context:).draw(glyph, x, y, size * 0.34) })
      end

      def shade(rect)
        context.color(context.palette.ink_edge, 0.85)
        context.rectangle(:fill, rect.x, rect.y, rect.width, rect.height)
      end

      def card(rect)
        corner = 24.0
        context.color(context.palette.ink_top)
        context.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
        context.color(context.palette.soft, 0.3)
        context.line_width = context.pixels.line_width(1)
        context.rectangle(:line, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
      end
    end
  end
end
