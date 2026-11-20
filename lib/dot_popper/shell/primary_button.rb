# frozen_string_literal: true

module DotPopper
  module Shell
    # A screen's main button, on whole device pixels: Home's Play and
    # Game Over's Play again. It is the one warm, filled pill on its screen,
    # a bright dot's gold with its word in the night's ink, so it reads at
    # once as the thing to press (Tidwell's prominent "done" button). The
    # mouse over it (+hover+, from 0 to 1) lightens it toward the bright
    # dot's light, and outlines it in cream.
    class PrimaryButton < Data.define(:context)
      LABEL = 0.36 # the word's size, in the button's height

      def draw(rect, text, alpha: 1.0, hover: 0.0, ratio: LABEL, note: nil)
        return if alpha <= 0.0

        palette = context.palette
        pixels = context.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        corner = height / 2.0
        context.color(palette.shadow, 0.35 * alpha)
        context.rectangle(:fill, x, y + pixels.snap(height * 0.06), width, height, corner, corner, 48)
        context.color(palette.bright_body.mix(palette.bright_light, 0.15 + (0.45 * hover)), alpha)
        context.rectangle(:fill, x, y, width, height, corner, corner, 48)
        edge(x, y, width, height, corner, alpha, hover)
        font = fit(text, width - height, height, ratio)
        return context.text(text, font, x + (width / 2.0), y + (height / 2.0), palette.ink_bottom, alpha) unless note

        small = fit(note, width - (height * 0.6), height, 0.16)
        top = y + (height / 2.0) - ((font.height + small.height) / 2.0)
        context.text(text, font, x + (width / 2.0), top + (font.height / 2.0), palette.ink_bottom, alpha)
        context.text(note, small, x + (width / 2.0), top + font.height + (small.height / 2.0), palette.ink_bottom, 0.8 * alpha)
      end

      private

      # A thin rim, cream as a bright dot's, brighter under the mouse.
      def edge(x, y, width, height, corner, alpha, hover)
        pixels = context.pixels
        context.color(context.palette.bright_rim, (0.5 + (0.5 * hover)) * alpha)
        context.line_width = pixels.line_width(hover.positive? ? 2 : 1)
        inset = pixels.line_at(x) - x
        context.rectangle(:line, x + inset, y + inset, width - (2 * inset), height - (2 * inset), corner, corner, 48)
      end

      # The word in bold, as big as a third of the button's height allows,
      # shrunk by whole sizes until it fits.
      def fit(text, room, height, ratio)
        size = [(height * ratio).round, 40].min
        size -= 1 while size > 12 && context.fonts.bold(size).width(text) > room
        context.fonts.bold(size)
      end
    end
  end
end
