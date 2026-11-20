# frozen_string_literal: true

module DotPopper
  module Shell
    # Change Server, as Presentation::ChangeServerLayout lays it out: the warning
    # and what to do, each after its sign, which server is in use, Paste
    # server address, Use setdef's server once another is chosen, and how
    # the last paste went.
    # It draws what the screen hands it (Presentation::ServerDrawing).
    class ServerPainter < Data.define(:context)
      def draw(drawing)
        plan = drawing.plan
        Header.new(context:).draw(drawing.header)
        lines(plan)
        line(plan.now, plan, plan.now_y, context.palette.soft)
        PillButton.new(context:).draw(plan.paste, drawing.paste, hover: drawing.paste_hover)
        PillButton.new(context:).draw(plan.reset, drawing.reset, hover: drawing.reset_hover) if plan.reset
        line(plan.status, plan, plan.status_y, context.palette.cream) if plan.status
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

      # One centered line, smaller until it fits across, as a long address may need.
      def line(text, plan, y, color)
        size = 17
        size -= 1 while size > 10 && context.fonts.semibold(size).width(text) > plan.width
        context.text(text, context.fonts.semibold(size), plan.left + (plan.width / 2.0), y, color)
      end
    end
  end
end
