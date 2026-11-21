# frozen_string_literal: true

require "test_helper"

# What score_record.txt holds, apart from the rules of a record: a line of
# class=score for each class of screen, as every build since scores were
# kept by class has written it.
class ScoreRecordFileTest < Minitest::Test
  ScoreRecordFile = DotPopper::Gameplay::ScoreRecordFile
  SizeClass = DotPopper::Gameplay::SizeClass

  def test_it_reads_and_writes_a_line_for_each_class_in_the_order_kept
    text = "fitted=44\nsmall=25\n"
    saved = ScoreRecordFile.parse(text, legacy: SizeClass::MEDIUM)

    assert_equal({ SizeClass::STANDARD => 44, SizeClass::SMALL => 25 }, saved.scores)
    assert_equal text, saved.to_s
    refute ScoreRecordFile.old?(text)
  end

  def test_a_line_it_cannot_read_is_left_out
    saved = ScoreRecordFile.parse("medium=-4\nhuge=9\nsmall\nlarge=x\nlarge=12\n", legacy: SizeClass::MEDIUM)
    assert_equal "large=12\n", saved.to_s
    assert_equal "", ScoreRecordFile.parse(nil, legacy: SizeClass::MEDIUM).to_s
  end

  def test_a_bare_number_from_before_classes_is_the_legacy_class_score
    saved = ScoreRecordFile.parse("12\n", legacy: SizeClass::LARGE)
    assert ScoreRecordFile.old?("12\n")
    assert_equal "large=12\n", saved.to_s
  end
end
