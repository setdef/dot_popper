# frozen_string_literal: true

# A drawing context (Shell::DrawingContext) that draws nothing and keeps,
# in order, everything a painter asked it to draw: each text with its
# face, size, place and color, and each shape with its corners, the color
# and line width it was drawn in, the clip, and how far the drawing had
# been moved. A painter draws only through its context, so a test can
# hand it one of these and say what it drew, with no window and no Lota.
#
# Fonts are measured as RoughMeasure measures, so a painter given a
# plan laid out with RoughMeasure draws text where the plan placed it.
# No shader is offered, so a painter takes the paths it draws without
# them, and no theme has art.
class RecordingContext
  P = DotPopper::Presentation

  # One thing drawn: +kind+ (:text, :outlined, :rectangle, :circle,
  # :line, :polygon, :arc, :image or :square), what it was asked with,
  # and the state it was drawn in.
  Mark = Data.define(:kind, :args, :color, :line_width, :offset, :clip) do
    # For a text: what it says, its face and size, and its center.
    def text = args[0]
    def face = args[1].face
    def size = args[1].size
    def x = args[2]
    def y = args[3]
    def alpha = color[3]
  end

  # A font of +face+ at +size+, measured as RoughMeasure measures.
  Font = Data.define(:face, :size) do
    def width(text) = P::RoughMeasure.new.width(P::RoughMeasure::LETTER.key?(face) ? face : :mono, size, text)
    def height = P::RoughMeasure.new.height(face, size)
  end

  # The game's fonts by face, as Shell::FontCache answers.
  class Fonts
    def bold(size) = Font.new(:bold, size)
    def semibold(size) = Font.new(:semibold, size)
    def mono(size) = Font.new(:mono, size)
    def wordmark(size) = Font.new(:wordmark, size)
    def face(path, size) = Font.new(path, size)
  end

  attr_reader :marks, :style, :palette, :fonts, :pixels, :dimensions, :theme

  def initialize(style: P::Style, scale: 1.0, dimensions: [1200, 800])
    @style = style
    @palette = style::PALETTE
    @fonts = Fonts.new
    @pixels = P::Pixels.new(scale:)
    @dimensions = dimensions
    @marks = []
    @color = [1, 1, 1, 1]
    @line_width = 1
    @offset = [0, 0]
    @clip = nil
  end

  def art = nil
  def shader?(_name) = false
  def dot_shader = nil
  def using(_theme) = yield
  def adding = yield
  def themed(color) = (job = style::PALETTE.to_h.key(color)) ? palette.public_send(job) : color
  def lit = style::HOVER.with(fill: palette.ink_glow.with_alpha(style::HOVER.fill.a), edge: palette.cream)
  def rgb(color) = [color.r, color.g, color.b]

  def color(color, alpha = color.a) = @color = [color.r, color.g, color.b, alpha]
  def white(alpha) = @color = [1, 1, 1, alpha]

  def text(text, font, x, y, color, alpha = color.a) = mark(:text, [text, font, x, y], [color.r, color.g, color.b, alpha])

  def outlined(text, font, x, y, color, alpha = color.a) = mark(:outlined, [text, font, x, y], [color.r, color.g, color.b, alpha])

  %i[rectangle circle line polygon arc image square].each do |kind|
    define_method(kind) { |*args| mark(kind, args) }
  end

  def line_width=(width)
    @line_width = width
  end

  def line_join=(_join); end

  def scissor=(rect)
    @clip = rect
  end

  def translate(x, y) = @offset = [@offset[0] + x, @offset[1] + y]

  def push
    was = @offset
    yield
  ensure
    @offset = was
  end

  # Keeps a mark of +kind+ that a stand-in for another painter drew.
  def record(kind, *args) = mark(kind, args)

  private

  def mark(kind, args, color = @color) = (@marks << Mark.new(kind:, args:, color:, line_width: @line_width, offset: @offset, clip: @clip)).last
end
