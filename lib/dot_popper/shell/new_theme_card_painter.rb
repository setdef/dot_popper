# frozen_string_literal: true

module DotPopper
  module Shell
    # The new theme card, once, at a calm moment on
    # Home: the theme's own two dots for a preview, its name, and an
    # immediate switch beside "Not now". Calm, and always answerable.
    # Presentation::NewThemeCardPlan decides where each part goes, and the
    # screen hands it all (Presentation::NewThemeCardDrawing).
    class NewThemeCardPainter < Data.define(:context, :dots)
      G = ::Lota::Graphics

      def draw(drawing)
        plan = drawing.plan
        veil(drawing.veil)
        card(plan)
        preview(plan, drawing.theme)
        cream = context.palette.cream
        context.text(drawing.heading, context.fonts.semibold(plan.heading_size), plan.card.center_x, plan.heading_y, context.palette.soft)
        context.text(drawing.name, context.fonts.bold(plan.name_size), plan.card.center_x, plan.name_y, cream)
        PrimaryButton.new(context:).draw(plan.use_button, drawing.use, hover: drawing.use_hover)
        PillButton.new(context:).draw(plan.later_button, drawing.later, hover: drawing.later_hover)
      end

      private

      def veil(rect)
        context.color(context.palette.ink_edge, 0.72)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height)
      end

      def card(plan)
        rect = plan.card
        corner = context.pixels.snap(rect.height * 0.06)
        context.color(context.palette.ink_top)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
        context.color(context.palette.pill_edge)
        G.line_width = context.pixels.line_width(1.5)
        G.rectangle(:line, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
      end

      def preview(plan, theme)
        r = plan.preview_radius
        x = plan.card.center_x
        y = plan.preview_y
        context.using(theme) do
          dots.icon(x - (r * 1.15), y, r, bright: true)
          dots.icon(x + (r * 1.15), y, r, bright: false)
        end
      end
    end
  end
end
