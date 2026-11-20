# frozen_string_literal: true

module DotPopper
  module Shell
    # The box a code being tapped shows in, a bit darker than a button.
    class CodeBox < Data.define(:context)
      G = ::Lota::Graphics

      def draw(rect, text, font, empty:)
        pixels = context.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        corner = height / 3.0
        context.color(context.palette.ink_bottom, 0.85)
        G.rectangle(:fill, x, y, width, height, corner, corner, 24)
        context.color(context.palette.soft, 0.6)
        G.line_width = pixels.line_width(1)
        G.rectangle(:line, x, y, width, height, corner, corner, 24)
        context.text(text, font, rect.center_x, rect.center_y, empty ? context.palette.soft : context.palette.cream)
      end
    end
  end
end
