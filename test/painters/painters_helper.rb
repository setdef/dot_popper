# frozen_string_literal: true

require "test_helper"
require "dot_popper/presentation"
require_relative "recording_context"

# The painters, loaded without Lota: each draws only through the context
# it is given (Shell::DrawingContext in the game), so a test hands it a
# RecordingContext and reads what it drew.
module PaintersTest
  P = DotPopper::Presentation

  # The files the painters draw with: every painter of a screen, and the
  # parts they share.
  PAINTING = %w[glyphs hud_painter mute_button tally_painter pill_button primary_button scrim_painter check_mark lettering
                code_box member_icon_painter group_painter settings_painter achievements_painter privacy_painter
                server_painter home_painter stats_painter offer_painter themes_painter credits_painter share_button
                share_preview_painter game_over_painter guide_painter tutorial_painter new_theme_card_painter
                themed_name].freeze
  PAINTING.each { require "dot_popper/shell/#{it}" }

  Shell = DotPopper::Shell

  # Shell::DotPainter's dots, kept as marks of the kind :dot in the
  # context: where, how big, how drawn, and in which theme's colors.
  class FakeDots < Data.define(:context)
    def icon(x, y, radius, bright:, opacity: 1.0, bonus: false) = context.record(:dot, x, y, radius, { bright:, opacity:, bonus:, palette: context.palette })
  end

  def context = @context ||= RecordingContext.new
  def dots = FakeDots.new(context:)

  # What +draw+ draws of +drawing+, in a context of its own.
  def marks_of(drawing)
    @context = RecordingContext.new
    yield drawing
    @context.marks
  rescue StandardError => e
    [e.class]
  end

  # Each field of +drawing+, and of the values in it, changed in turn:
  # what +draw+ draws from it must change too, or the painter ignores
  # what its screen handed it (a hover never lit, a line never drawn).
  # +unused+ names, by path, the fields a painter is not meant to draw,
  # such as where a press reaches a button, and everything inside them
  # (:* for any one key or index).
  def assert_draws_every_field(drawing, unused: [], &draw)
    before = marks_of(drawing, &draw)
    refute_empty before, "it draws something"
    ignored = paths(drawing).reject { |path| unused.any? { under?(path, it) } }.select do |path|
      changed = changed(drawing, path)
      changed && marks_of(changed, &draw) == before
    end
    assert_empty ignored, "drawn the same whatever these say"
    assert_empty unused.reject { |name| paths(drawing).any? { under?(it, name) } }, "named unused, and not in it"
  end

  # Whether +path+ is +name+ or inside it; :* in +name+ stands for any
  # one key or index.
  def under?(path, name) = name.size <= path.size && name.each_with_index.all? { |key, i| key == :* || key == path[i] }

  def paths(value, at = [])
    inner = case value
            when P::Color then return [at]
            when Data then value.to_h
            when Hash then value
            when Array then value.each_with_index.to_h { |v, i| [i, v] }
            else return [at]
            end
    inner.flat_map { |key, v| paths(v, [*at, key]) }
  end

  # +value+ with what is at +path+ changed, or nil where nothing there
  # can be changed and still be a value of its kind.
  def changed(value, path)
    return change(value) if path.empty?

    key, *rest = path
    inner = changed(value.is_a?(Data) ? value.public_send(key) : value[key], rest)
    return nil if inner.nil?

    case value
    when Data then value.with(key => inner)
    when Hash then value.merge(key => inner)
    else value.dup.tap { it[key] = inner }
    end
  end

  def change(value)
    case value
    when Integer then value + 5
    when Float then value.between?(0.0, 1.0) ? (value + 0.63) % 1.0 : value + 5.37
    when String then "#{value}Z"
    when true, false then !value
    when P::Color then value.mix(P::Color.new(r: 0.5, g: 0.1, b: 0.9, a: 1.0), 0.5)
    end
  end

  # What #draw (the test's own) draws of +drawing+.
  def drawn(drawing) = marks_of(drawing) { draw(it) }

  # The texts among +marks+, and the one that says +text+.
  def texts(marks) = marks.select { %i[text outlined].include?(it.kind) }

  def said(text, marks)
    found = texts(marks).select { it.text == text }
    assert_equal 1, found.size, "#{text.inspect} is drawn once, among #{texts(marks).map(&:text).inspect}"
    found.first
  end

  # The color the pill or card at +rect+ was filled with.
  def fill_at(rect, marks)
    x, y = [rect.x, rect.y].map { context.pixels.snap(it) }
    marks.find { it.kind == :rectangle && it.args[0] == :fill && it.args[1] == x && it.args[2] == y }&.color
  end
end
