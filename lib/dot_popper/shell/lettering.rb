# frozen_string_literal: true

module DotPopper
  module Shell
    # Big display words set like candy: light letters on a deeper,
    # extruded copy of themselves, every layer on whole device pixels.
    class Lettering < Data.define(:context)
      def candy(text, font, x, y, alpha = 1.0, face: context.palette.bright_light, side: context.palette.bright_deep)
        depth = [(font.height * 0.06 * context.pixels.scale).round, 1].max
        depth.downto(1) { |step| context.text(text, font, x, y + (step / context.pixels.scale), side, alpha) }
        context.text(text, font, x, y, face, alpha)
      end
    end
  end
end
