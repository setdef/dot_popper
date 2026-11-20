# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws what follows a tap: rings (each around its dot, if it follows
    # one), the droplets that ParticleSystems flies, and floating numbers, outlined
    # so they read over any dot.
    class EffectsPainter < Data.define(:context, :particle_systems)
      G = ::Lota::Graphics
      EDGE_BANDS = 8 # strips of the edge glow, without its shader

      # The rings, the outlines of a hidden bright dot, and the droplets.
      def scene(effects, dots)
        rings(effects.rings, effects.now, dots)
        mistake_outlines(effects.mistake_outlines, effects.now, dots)
        droplets
      end

      # The floating numbers, over everything, glow included.
      def words(effects, layout) = floating_texts(effects.floating_texts, effects.now, layout)

      # Additive, so droplets only ever brighten.
      def droplets = context.adding { particle_systems.draw }

      # The glow at the screen's edges, over everything in the field.
      def flash(effects, width, height)
        alpha = effects.flash_alpha
        return if alpha <= 0.0

        band = [width, height].min * effects.flash.band
        return flat_flash(context.themed(effects.flash.color), alpha, width, height, band) unless context.shader?(:edge)

        context.shading(:edge) do |shader|
          context.uniform(shader, "size", [width.to_f, height.to_f])
          context.uniform(shader, "band", band)
          context.color(context.themed(effects.flash.color), alpha)
          context.square(width / 2.0, height / 2.0, width / 2.0, height / 2.0)
        end
      end

      private

      def rings(rings, now, dots)
        rings.each do |ring|
          width = ring.width(now)
          next if width <= 0.0

          x, y = ring.center(dots)
          context.color(context.themed(ring.style.color), ring.alpha(now))
          G.line_width = width
          G.circle(:line, x, y, ring.radius(now), 64)
        end
      end

      # Each hidden dot's outline, in dashes, over a darker one so it reads
      # over a light dot as well as a dark one.
      def mistake_outlines(outlines, now, dots)
        outlines.each do |outline|
          x, y = outline.center(dots)
          radius = outline.radius(now)
          alpha = outline.alpha(now)
          [[context.palette.shadow, outline.width * 2.2, alpha * 0.5], [context.themed(outline.style.color), outline.width, alpha]]
            .each do |color, width, strength|
            context.color(color, strength)
            G.line_width = width
            outline.dashes(now).each { |from, to| G.arc(:line, :open, x, y, radius, from, to, 10) }
          end
        end
      end

      def floating_texts(texts, now, layout)
        return if texts.empty?

        font = context.fonts.bold(layout.scaled(context.style::TYPE.floating_text))
        texts.each { context.outlined(it.text, font, it.x, it.y_at(now), it.color, it.alpha(now)) }
      end

      # Strips along each edge, fainter toward the middle.
      def flat_flash(color, alpha, width, height, band)
        step = band / EDGE_BANDS
        EDGE_BANDS.times do |i|
          context.color(color, alpha * ((1 - (i.to_f / EDGE_BANDS))**2) * 0.5)
          inset = i * step
          G.rectangle(:fill, inset, inset, width - (2 * inset), step)
          G.rectangle(:fill, inset, height - inset - step, width - (2 * inset), step)
          G.rectangle(:fill, inset, inset + step, step, height - (2 * (inset + step)))
          G.rectangle(:fill, width - inset - step, inset + step, step, height - (2 * (inset + step)))
        end
      end
    end
  end
end
