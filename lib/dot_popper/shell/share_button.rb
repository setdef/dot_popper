# frozen_string_literal: true

module DotPopper
  module Shell
    # Game Over's "Share my score", on whole device pixels: a dark pill
    # like the other quiet buttons, but outlined in a bright dot's gold and
    # led by a share glyph, three dots joined by two lines, so it is seen
    # without competing with Play again's filled gold. It comes in as its
    # +entrance+ (Presentation::ShareButtonEntrance) says, rising into place
    # with a ring spreading from its edge. +hover+, from 0 to 1, is how lit the mouse
    # over it has made it (Presentation::Hover).
    class ShareButton < Data.define(:context)
      G = ::Lota::Graphics
      Plan = Presentation::GameOverLayout

      def draw(rect, text, entrance:, ui:, alpha: 1.0, hover: 0.0)
        shown = entrance.alpha * alpha
        return if shown <= 0.0

        pixels = context.pixels
        rect = rect.with(y: rect.y + pixels.snap(entrance.drop * ui))
        ring(rect, entrance.ring * ui, entrance.ring_alpha * alpha) if entrance.ring_alpha.positive?
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        pill(x, y, width, height, shown, hover)
        label(text, x, y, width, height, shown)
      end

      private

      def pill(x, y, width, height, alpha, hover)
        palette = context.palette
        lit = context.style::HOVER
        pixels = context.pixels
        corner = height / 2.0
        fill = palette.pill.mix(lit.fill, hover)
        context.color(fill, fill.a * alpha)
        G.rectangle(:fill, x, y, width, height, corner, corner, 48)
        context.color(palette.bright_body.mix(lit.edge, hover), (0.8 + (0.2 * hover)) * alpha)
        G.line_width = pixels.line_width(2)
        inset = pixels.line_at(x, 2) - x
        G.rectangle(:line, x + inset, y + inset, width - (2 * inset), height - (2 * inset), corner, corner, 48)
      end

      # The glyph and the words after it, centered together.
      def label(text, x, y, width, height, alpha)
        glyph = height * Plan::SHARE_GLYPH
        font = fit(text, width - (height * (Plan::SHARE_GLYPH + Plan::SHARE_SIDES)), height)
        left = x + ((width - glyph - font.width(text)) / 2.0)
        middle = y + (height / 2.0)
        share_glyph(left, middle, glyph * 0.68, alpha)
        context.text(text, font, left + glyph + (font.width(text) / 2.0), middle, context.palette.cream, alpha)
      end

      # Three dots joined by two lines, +size+ across from +x+, centered on
      # +y+: the bright dot on the left, sharing with the two on the right.
      def share_glyph(x, y, size, alpha)
        palette = context.palette
        pixels = context.pixels
        dot = size * 0.2
        left = [x + dot, y]
        ends = [[x + size - dot, y - (size * 0.38)], [x + size - dot, y + (size * 0.38)]]
        context.color(palette.soft, alpha)
        G.line_width = pixels.whole(size * 0.1)
        ends.each { G.line(*left, *it) }
        context.color(palette.cream, alpha)
        ends.each { G.circle(:fill, *it, dot, 24) }
        context.color(palette.bright_body, alpha)
        G.circle(:fill, *left, dot * 1.15, 24)
      end

      # A ring +reach+ units out from the pill, fading as it spreads.
      def ring(rect, reach, alpha)
        pixels = context.pixels
        box = rect.inset(-reach)
        x, y, width, height = [box.x, box.y, box.width, box.height].map { pixels.snap(it) }
        corner = height / 2.0
        context.color(context.palette.bright_body, alpha)
        G.line_width = pixels.line_width(2)
        G.rectangle(:line, x, y, width, height, corner, corner, 48)
      end

      # The words in semibold, as big as the plan measured them, shrunk by
      # whole sizes if the real font needs it.
      def fit(text, room, height)
        size = Plan.share_size(height)
        size -= 1 while size > 10 && context.fonts.semibold(size).width(text) > room
        context.fonts.semibold(size)
      end
    end
  end
end
