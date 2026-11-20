# frozen_string_literal: true

module DotPopper
  module Shell
    # The speaker in Home's corner: sound waves when sound is on, a
    # cross when it is off. A tap on it toggles sound (Show#tap). With the
    # mouse over it, +hover+ of the way (Presentation::Hover), its disc
    # brightens, an outline rings it, and the speaker lightens.
    class MuteButton < Data.define(:context)
      def draw(rect, muted, hover: 0.0)
        pixels = context.pixels
        lit = context.lit
        size = rect.width
        x = pixels.snap(rect.center_x)
        y = pixels.snap(rect.center_y)
        context.color(context.palette.pill.mix(lit.fill, hover))
        context.circle(:fill, x, y, size / 2.0, 48)
        ring(x, y, size, hover) if hover.positive?
        context.color(context.palette.soft.mix(lit.edge, hover * 0.6))
        speaker(x, y, size)
        muted ? cross(x, y, size) : waves(x, y, size)
      end

      private

      def ring(x, y, size, hover)
        context.color(context.lit.edge, 0.8 * hover)
        context.line_width = context.pixels.line_width(1)
        context.circle(:line, x, y, (size / 2.0) - (context.pixels.line_width(1) / 2.0), 48)
      end

      def speaker(x, y, size)
        u = size / 100.0
        context.rectangle(:fill, context.pixels.snap(x - (24 * u)), context.pixels.snap(y - (9 * u)), context.pixels.snap(11 * u),
                    context.pixels.snap(18 * u))
        context.polygon(:fill, x - (14 * u), y - (9 * u), x + (2 * u), y - (22 * u), x + (2 * u), y + (22 * u),
                  x - (14 * u), y + (9 * u))
      end

      def waves(x, y, size)
        u = size / 100.0
        context.line_width = context.pixels.whole(4.5 * u)
        [12, 22].each { context.arc(:line, :open, x + (4 * u), y, it * u, -0.85, 0.85, 16) }
      end

      def cross(x, y, size)
        u = size / 100.0
        context.line_width = context.pixels.whole(4.5 * u)
        left = x + (11 * u)
        right = x + (27 * u)
        context.line(left, y - (8 * u), right, y + (8 * u))
        context.line(left, y + (8 * u), right, y - (8 * u))
      end
    end
  end
end
