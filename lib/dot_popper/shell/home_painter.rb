# frozen_string_literal: true

module DotPopper
  module Shell
    # Home, as Presentation::HomeLayout lays it out: the name, the first
    # launch's legend, Play with what it leaves to say under it, today's
    # goal and the days in a row on their card, the four large buttons,
    # and the bottom row. Each large button shows one value.
    class HomePainter < Data.define(:context, :dots)
      # Home as its +drawing+ (Presentation::HomeDrawing) says, as it has
      # come in by +now+.
      def draw(drawing, now)
        intro = drawing.entrance.intro(now)
        plan = drawing.plan
        name(drawing.name, plan, intro)
        legend(plan, intro) if plan.legend
        PrimaryButton.new(context:).draw(plan.play, drawing.play_word, note: drawing.play_note, alpha: intro, hover: drawing.play_hover)
        goal(drawing.goal, plan.goal, intro) if plan.goal
        drawing.tiles.each { tile(it, intro) }
        drawing.pills.each { pill(it, intro) }
        quit_prompt(drawing)
      end

      private

      def name(text, plan, alpha)
        rect = plan.name
        if context.art then ThemedName.new(context:, dots:).draw(text, rect.center_x, rect.center_y, plan.name_size, alpha, room: rect.width)
        else Lettering.new(context:).candy(text, context.fonts.bold(plan.name_size), rect.center_x, rect.center_y, alpha)
        end
      end

      # A bright dot, then "+1" and "+1" with a stopwatch; under it a
      # popped dot, then "−2" and "−2" with a stopwatch.
      def legend(plan, alpha)
        font = context.fonts.bold(plan.legend_size)
        legend = Presentation::Legend.measure(font.height) { font.width(it) }
        radius = legend.radius
        x = plan.legend.center_x - (legend.width / 2.0)
        y = plan.legend.center_y
        tallies = TallyPainter.new(context:)
        Presentation::Legend.rows.each_with_index do |(bright, points, seconds), i|
          row = y + ((i - 0.5) * radius * Presentation::Legend::ROW)
          dots.icon(x + radius, row, radius, bright:, opacity: alpha)
          tallies.left(points, font, x + legend.points, row, bright ? context.palette.cream : context.palette.alarm, alpha)
          tallies.left(seconds, font, x + legend.seconds, row, bright ? context.palette.gain : context.palette.alarm, alpha)
        end
      end

      def goal(goal, rect, alpha)
        palette = context.palette
        Card.new(context:).draw(rect, alpha:)
        card = Presentation::GoalCard.fit(rect, goal.sentence, FontMeasure.new(context.fonts))
        pad = card.pad
        divider = card.divider
        label = context.fonts.semibold(card.label_size)
        text = context.fonts.bold(card.text_size)
        done = goal.done
        tone = done ? palette.gain : palette.soft
        heading = goal.label
        context.text(heading, label, rect.x + pad + (label.width(heading) / 2.0), rect.y + pad + (label.height / 2.0), tone, alpha)
        Glyphs.new(context:).draw(:check, rect.x + pad + label.width(heading) + (label.height * 0.9), rect.y + pad + (label.height / 2.0), label.height * 0.9, color: palette.gain, alpha:) if done
        card.lines.each_with_index do |line, i|
          context.text(line, text, rect.x + pad + (text.width(line) / 2.0), card.top + (text.height * (i + 0.5)), done ? palette.gain : palette.cream, alpha)
        end
        context.color(palette.soft, 0.25 * alpha)
        context.line_width = context.pixels.line_width(1)
        context.line(context.pixels.snap(divider), rect.y + pad, context.pixels.snap(divider), rect.bottom - pad)
        streak(goal, rect, divider, label, alpha)
      end

      def streak(goal, rect, divider, label, alpha)
        palette = context.palette
        x = (divider + rect.right) / 2.0
        digits = context.fonts.bold([(rect.height * 0.32).round, 16].max)
        days = goal.streak
        top = rect.y + (rect.height * 0.3)
        Lettering.new(context:).candy(days.to_s, digits, x, top, alpha, face: palette.bright_body, side: palette.bright_deep)
        context.text(goal.streak_days, label, x, top + (digits.height * 0.72), palette.soft, alpha)
        context.text(goal.in_a_row, label, x, top + (digits.height * 0.72) + label.height, palette.soft, alpha)
      end

      # A large button: its icon, its name, one value, and on a controller
      # its button in the corner.
      def tile(drawn, alpha)
        palette = context.palette
        rect = drawn.rect
        Card.new(context:).draw(rect, alpha:, lit: drawn.hover)
        size = [rect.height * 0.46, 20.0].max
        icon_x = rect.x + (rect.height * 0.32) + (size * 0.3)
        text_x = icon_x + (size * 0.72) + 8
        icon(drawn.name, icon_x, rect.center_y, size, alpha)
        room = rect.right - text_x - 8
        heading = fit_bold(drawn.word, [(rect.height * 0.23).round, 18].min, room)
        note = fit(drawn.note, [(rect.height * 0.18).round, 16].min, room)
        context.text(drawn.word, heading, text_x + (heading.width(drawn.word) / 2.0), rect.center_y - (note.height * 0.5), palette.cream, alpha)
        context.text(drawn.note, note, text_x + (note.width(drawn.note) / 2.0), rect.center_y + (heading.height * 0.55), palette.soft, alpha)
        badge(drawn.badge, rect, alpha) if drawn.badge
      end

      def icon(tile, x, y, size, alpha)
        case tile
        when :themes then dots.icon(x, y, size * 0.6, bright: true, opacity: alpha)
        else Glyphs.new(context:).draw({ stats: :bars, achievements: :ribbon, groups: :crown }.fetch(tile), x, y, size, color: context.palette.bright_body, alpha:, weight: 1.8)
        end
      end

      def badge(text, rect, alpha)
        font = context.fonts.semibold(13)
        width = font.width(text) + 14
        height = font.height + 4
        x = rect.right - width - 8
        y = rect.y - (height / 2.0)
        context.color(context.palette.ink_top, alpha)
        context.rectangle(:fill, x, y, width, height, height / 2.0, height / 2.0, 12)
        context.color(context.palette.soft, 0.5 * alpha)
        context.rectangle(:line, x, y, width, height, height / 2.0, height / 2.0, 12)
        context.text(text, font, x + (width / 2.0), y + (height / 2.0), context.palette.soft, alpha)
      end

      def pill(drawn, alpha)
        glyph = { how_to_play: :question, settings: :gear, quit: :power }.fetch(drawn.name)
        PillButton.new(context:).draw(drawn.rect, drawn.word, alpha:, hover: drawn.hover,
                                      icon: ->(x, y, size) { Glyphs.new(context:).draw(glyph, x, y, size * 0.42, alpha:) })
      end

      def fit(text, size, room)
        size -= 1 while size > 11 && context.fonts.semibold(size).width(text) > room
        context.fonts.semibold(size)
      end

      def fit_bold(text, size, room)
        size -= 1 while size > 11 && context.fonts.bold(size).width(text) > room
        context.fonts.bold(size)
      end

      # "Press B again to quit" (or Escape, after Escape), above the
      # bottom row, while a second press would quit: smaller where it
      # would run past the safe area's edge, as in a small window.
      def quit_prompt(drawing)
        alpha = drawing.quit
        return unless alpha.positive?

        x, y = drawing.plan.quit_line
        safe = drawing.safe
        text = drawing.quit_text
        font = fit(text, 18, 2 * ([x - safe.x, safe.right - x].min - 4))
        context.text(text, font, x, y, context.palette.cream, alpha)
      end
    end
  end
end
