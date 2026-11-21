# frozen_string_literal: true

module DotPopper
  module Shell
    # The offer of Pro, over the screen where it was asked for: the
    # heading and Back, then what was tapped, shown (every theme Pro gives,
    # the achievement and how to earn it, or the feature's sign), its name,
    # the rest of what Pro adds, each after its sign, the price from the
    # store on Buy, and Restore Purchases; or, once it is the player's,
    # thanks. Calm: no motion, no clock, and Back always there.
    # Presentation::OfferLayout decides where each goes; this only draws,
    # on whole device pixels.
    class OfferPainter < Data.define(:context, :dots)
      SIGNS = { "Unlimited games" => :infinity, "Achievements" => :ribbon, "Friend groups" => :crown }.freeze

      # The offer as its +drawing+ (Presentation::OfferDrawing) says.
      def draw(drawing)
        plan = drawing.plan
        palette = context.palette
        Header.new(context:).draw(drawing.header)
        note(plan) if plan.key?(:note)
        art(drawing, plan[:art]) if plan.key?(:art)
        centered(plan, :focus, :bold, :focus, drawing.focus_word, palette.cream)
        items(plan, drawing.others)
        status(plan, drawing.status)
        buttons(drawing)
      end

      private

      def centered(plan, name, face, size, text, color)
        rect = plan[name] or return
        context.text(text, context.fonts.public_send(face, plan.size(size)), rect.center_x, rect.center_y, color)
      end

      def note(plan)
        font = context.fonts.semibold(plan.size(:note))
        plan.note_lines.each_with_index do |line, i|
          context.text(line, font, plan[:note].center_x, plan[:note].y + (font.height * (i + 0.5)), context.palette.alarm)
        end
      end

      # What was tapped, shown in the room the plan gives it.
      def art(drawing, rect)
        case drawing.focus
        when :themes then themes(drawing.themes, rect)
        when :achievements then achievement(drawing.achievement, rect)
        else Glyphs.new(context:).draw(drawing.focus == :groups ? :crown : :infinity, rect.center_x, rect.center_y, rect.height,
                                       color: context.palette.bright_body, weight: 2.0)
        end
      end

      # A small card for each theme Pro would give, each its own night and
      # dots, in a row.
      def themes(named, rect)
        list = named.map(&:first)
        return if list.empty?

        gap = 10.0
        width = [(rect.width - (gap * (list.size - 1))) / list.size, rect.height * 1.3].min
        left = rect.center_x - (((list.size * width) + ((list.size - 1) * gap)) / 2.0)
        list.each_with_index do |theme, i|
          box = Presentation::Rect.new(x: left + (i * (width + gap)), y: rect.y, width:, height: rect.height)
          context.color(theme.palette.ink_top)
          context.rectangle(:fill, box.x, box.y, box.width, box.height, 12, 12, 24)
          radius = [box.height * 0.24, box.width * 0.17].min
          context.using(theme) do
            dots.icon(box.center_x - (radius * 0.6), box.y + (box.height * 0.4), radius, bright: true)
            dots.icon(box.center_x + (radius * 0.6), box.y + (box.height * 0.4), radius, bright: false)
          end
          name = named[i].last
          art = theme.art
          name = name.upcase if art&.wordmark && art.dotted_name
          size = [(box.height * 0.16).round, 18].min
          size -= 1 while size > 9 && context.fonts.face(art&.wordmark || context.style::TYPE.bold, size).width(name) > box.width * 0.9
          context.text(name, context.fonts.face(art&.wordmark || context.style::TYPE.bold, size), box.center_x, box.bottom - (box.height * 0.18),
                   theme.palette.bright_body)
        end
      end

      # The achievement tapped, on a card: its sign in the grid's dashed
      # ring, its name, and how to earn it. No progress: that is what Pro
      # adds (doc/design/store-and-pro.md).
      def achievement(shown, rect)
        return unless shown

        id = shown.id
        Card.new(context:).draw(rect)
        radius = rect.height * 0.32
        x = rect.x + 16 + radius
        AchievementsPainter.new(context:).emblem(id, x, rect.center_y, radius, shown.earned)
        left = x + radius + 16
        room = rect.right - left - 16
        bold = context.fonts.bold(18)
        small = context.fonts.semibold(14)
        lines = Presentation::Words.wrap(shown.how, room) { small.width(it) }.first(3)
        top = rect.center_y - (((lines.size * small.height) + bold.height) / 2.0)
        name = shown.name
        context.text(name, bold, left + (bold.width(name) / 2.0), top + (bold.height / 2.0), context.palette.cream)
        lines.each_with_index do |line, i|
          context.text(line, small, left + (small.width(line) / 2.0), top + bold.height + (small.height * (i + 0.5)), context.palette.cream)
        end
      end

      def items(plan, list)
        rect = plan[:items] or return
        font = context.fonts.semibold(plan.size(:item))
        line = font.height * Presentation::OfferLayout::LINE
        list.each_with_index do |item, i|
          y = context.pixels.snap(rect.y + (font.height / 2.0) + (i * line))
          sign = font.height * 1.1
          if SIGNS.key?(item)
            Glyphs.new(context:).draw(SIGNS[item], rect.x + (sign / 2.0), y, sign, color: context.palette.bright_body)
          else
            dots.icon(rect.x + (sign / 2.0), y, sign * 0.45, bright: true)
          end
          context.text(item, font, rect.x + (font.height * 1.6) + (font.width(item) / 2.0), y, context.palette.cream)
        end
      end

      # How the store or the key is getting on, smaller until it fits across.
      def status(plan, text)
        rect = plan[:status] or return
        size = plan.size(:note)
        size -= 1 while size > 10 && context.fonts.semibold(size).width(text) > rect.width
        context.text(text, context.fonts.semibold(size), rect.center_x, rect.center_y, context.palette.cream)
      end

      # Buy, while Pro is sold, and the second button.
      def buttons(drawing)
        plan = drawing.plan
        PrimaryButton.new(context:).draw(plan[:buy], drawing.buy, hover: drawing.lit.fetch(:buy)) if plan.key?(:buy)
        second = drawing.second
        PillButton.new(context:).draw(plan[second], drawing.second_words, hover: drawing.lit.fetch(second)) if plan.key?(second)
      end
    end
  end
end
