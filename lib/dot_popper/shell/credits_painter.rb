# frozen_string_literal: true

module DotPopper
  module Shell
    # The Credits screen, over Home's dimmed dots: the heading as
    # the Stats screen has it, Back in the bottom left corner, and between
    # them the license texts, scrolled, in the same type and palette, each
    # line on whole device pixels and clipped to its window. A faint bar
    # beside the window shows where in the page it is.
    # Presentation::CreditsLayout decides where each goes, and the screen
    # hands it all (Presentation::CreditsDrawing).
    class CreditsPainter < Data.define(:context)
      G = ::Lota::Graphics

      def draw(drawing)
        Header.new(context:).draw(drawing.header)
        text(drawing)
        bar(drawing)
      end

      private

      def text(drawing)
        window = drawing.window
        offset = drawing.offset
        pixels = context.pixels
        G.scissor = pixels.snap(window.x), pixels.snap(window.y), pixels.snap(window.width), pixels.snap(window.height)
        fonts = { heading: context.fonts.bold(drawing.heading_size),
                  subheading: context.fonts.bold(drawing.size),
                  note: context.fonts.semibold(drawing.size), legal: context.fonts.mono(drawing.size) }
        colors = { heading: context.palette.cream, subheading: context.palette.gain, note: context.palette.cream, legal: context.palette.cream }
        drawing.rows.each do |row|
          font = fonts.fetch(row.kind)
          context.text(row.text, font, window.x + (font.width(row.text) / 2.0), window.y + row.y - offset, colors.fetch(row.kind))
        end
        G.scissor = nil
      end

      # The page's place in the window, a thin bar at the window's right
      # edge, when there is more page than window.
      def bar(drawing)
        thumb = drawing.thumb or return
        window = drawing.window
        start, length = thumb
        pixels = context.pixels
        width = pixels.line_width(3)
        x = [pixels.snap(drawing.bar_x), drawing.bar_limit - width].min
        context.color(context.palette.soft, 0.5)
        G.rectangle(:fill, x, pixels.snap(window.y + (window.height * start)), width,
                    [pixels.snap(window.height * length), width].max, width / 2.0, width / 2.0, 8)
      end
    end
  end
end
