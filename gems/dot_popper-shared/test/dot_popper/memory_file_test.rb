# frozen_string_literal: true

require "test_helper"

# A save file kept in memory answers as a save file on the device does.
class MemoryFileTest < Minitest::Test
  def test_it_keeps_what_was_written_until_it_is_removed
    file = DotPopper::MemoryFile.new
    assert_nil file.read
    file.write("kept")
    assert_equal "kept", file.read
    file.remove
    assert_nil file.read
    assert_equal "given", DotPopper::MemoryFile.new("given").read
  end
end
