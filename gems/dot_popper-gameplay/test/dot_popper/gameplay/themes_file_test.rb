# frozen_string_literal: true

require "test_helper"

# What themes.txt holds, apart from the rules of which themes a player
# has: three lines, the themes released to this device under the word
# every build has saved them as ("unlocked"), those told, and the one
# chosen.
class ThemesFileTest < Minitest::Test
  ThemesFile = DotPopper::Gameplay::ThemesFile

  def test_it_reads_and_writes_the_three_lines_as_every_build_has
    text = "unlocked: ghost eclipse\ntold: ghost\nchosen: eclipse\n"
    saved = ThemesFile.parse(text)

    assert_equal [%i[ghost eclipse], %i[ghost], :eclipse], [saved.released, saved.told, saved.chosen]
    assert_equal text, saved.to_s
  end

  def test_an_empty_or_damaged_file_reads_as_nothing_released
    saved = ThemesFile.parse("garbage\ntold ghost\n")
    assert_equal [[], [], nil], [saved.released, saved.told, saved.chosen]
    assert_equal "unlocked: \ntold: \nchosen: \n", ThemesFile.parse(nil).to_s
  end
end
