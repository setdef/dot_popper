# frozen_string_literal: true

module DotPopper
  module Shell
    # A check mark, drawn as two strokes in the gain color, before a line
    # of text: "✓ Today's goal is done." The font has no check of its own.
    class CheckMark < Data.define(:context)
      # The check and +text+ together, centered on +x+ and +y+.
      def labeled(text, font, x, y, alpha)
        size = font.height
        mark = size * 0.5
        gap = size * 0.25
        left = x - ((mark + gap + font.width(text)) / 2.0)
        draw(left, y, mark, alpha)
        context.text(text, font, left + mark + gap + (font.width(text) / 2.0), y, context.palette.gain, alpha)
      end

      private

      # A check +width+ across, from +x+, centered on +y+.
      def draw(x, y, width, alpha)
        context.color(context.palette.gain, alpha)
        context.line_width = context.pixels.whole(width * 0.22)
        context.line(x, y, x + (width * 0.38), y + (width * 0.38), x + width, y - (width * 0.42))
      end
    end
  end
end
