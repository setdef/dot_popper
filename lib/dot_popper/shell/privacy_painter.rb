# frozen_string_literal: true

module DotPopper
  module Shell
    # The Privacy screen: what stays and what is kept online, a link to
    # the policy, and a held button that deletes the online data, as the
    # screen hands it (Presentation::PrivacyDrawing).
    class PrivacyPainter < Data.define(:context)
      def draw(drawing)
        plan = drawing.plan
        Header.new(context:).draw(drawing.header)
        lines(plan)
        policy(drawing, plan)
        delete(drawing, plan) if plan.delete
        note(drawing, plan) unless drawing.note_rows.empty?
      end

      private

      def lines(plan)
        font = context.fonts.semibold(plan.line_size)
        plan.lines.each do |glyph, rows, top|
          Glyphs.new(context:).draw(glyph, plan.left + 13, top + (font.height / 2.0), 24, color: context.palette.bright_body)
          rows.each_with_index do |row, i|
            context.text(row, font, plan.left + 42 + (font.width(row) / 2.0), top + (font.height * (i + 0.5)) + (i * plan.line_size * 0.15), context.palette.cream)
          end
        end
      end

      def policy(drawing, plan)
        rect = plan.policy
        PillButton.new(context:).draw(rect, nil, hover: drawing.policy_hover,
                                  icon: lambda do |x, y, size|
                                    font = context.fonts.semibold((size * 0.33).round)
                                    text = drawing.policy
                                    total = font.width(text) + 40
                                    left = rect.center_x - (total / 2.0)
                                    context.text(text, font, left + (font.width(text) / 2.0), rect.center_y, context.palette.cream)
                                    Glyphs.new(context:).draw(:external, left + total - 10, rect.center_y, size * 0.34, color: context.palette.cream)
                                    [x, y]
                                  end)
      end

      def delete(drawing, plan)
        rect = plan.delete
        PillButton.new(context:).draw(rect, nil, hover: drawing.delete_hover, edge: context.palette.urgent,
                                  icon: lambda do |_x, y, size|
                                    fill(rect, drawing.progress) if drawing.held
                                    font = context.fonts.semibold((size * 0.33).round)
                                    text = drawing.delete
                                    total = font.width(text) + 40
                                    left = rect.center_x - (total / 2.0)
                                    Glyphs.new(context:).draw(:trash, left + 10, y, size * 0.34, color: context.palette.urgent)
                                    context.text(text, font, left + 40 + (font.width(text) / 2.0), y, context.palette.urgent)
                                  end)
      end

      def fill(rect, amount)
        outline = Presentation::PillFill.new(rect:, amount:).outline
        return if outline.size < 6

        context.color(context.palette.alarm, 0.45)
        context.polygon(:fill, *outline)
      end

      def note(drawing, plan)
        font = context.fonts.semibold(15)
        y = plan.note_y + 6
        drawing.note_rows.each_with_index { |line, i| context.text(line, font, drawing.note_x, y + (i * font.height), context.palette.soft) }
      end
    end
  end
end
