# frozen_string_literal: true

require_relative "painters_helper"

# The painters draw only through the drawing context they are given, so
# a test can give them a RecordingContext and see what they drew. A
# painter that called Lota itself would draw past the recording, and
# would not load where Lota is not installed.
class NoLotaTest < Minitest::Test
  SHELL = File.expand_path("../../lib/dot_popper/shell", __dir__)

  include PaintersTest

  def test_no_painter_names_lota
    named = PAINTING.select { File.read(File.join(SHELL, "#{it}.rb")).match?(/\bLota\b|\bG\./) }
    assert_empty named, "these draw past their context"
  end

  def test_every_painter_of_the_shell_is_loaded_here
    painters = Dir[File.join(SHELL, "*_painter.rb")].map { File.basename(it, ".rb") }
    left_out = painters - PAINTING - %w[dot_painter effects_painter splash_painter cursor_painter]
    assert_empty left_out, "a painter of a screen is tested here, drawing through a RecordingContext"
  end
end
