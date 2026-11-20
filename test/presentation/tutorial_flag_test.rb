# frozen_string_literal: true

require_relative "presentation_helper"

class TutorialFlagTest < Minitest::Test
  include PresentationTest

  def setup
    @file = DotPopper::MemoryFile.new
  end

  def test_it_is_due_once_on_a_bright_install_and_remembered_across_sessions
    flag = TutorialFlag.new(@file)
    assert flag.due?(played: false)

    flag.seen!
    refute flag.due?(played: false)
    refute TutorialFlag.new(@file).due?(played: false)
    assert_equal "seen", @file.read
  end

  def test_a_player_who_has_played_before_never_sees_it
    refute TutorialFlag.new(@file).due?(played: true)
  end

  def test_a_damaged_flag_counts_as_unseen
    @file.write("maybe")

    assert TutorialFlag.new(@file).due?(played: false)
  end

  def test_forced_it_shows_on_every_play_and_skipped_never
    @file.write("seen")

    assert TutorialFlag.new(@file, mode: :forced).due?(played: true)
    refute TutorialFlag.new(DotPopper::MemoryFile.new, mode: :skipped).due?(played: false)
  end

  def test_the_environment_chooses_the_mode
    assert_equal :usual, TutorialFlag.mode({})
    assert_equal :forced, TutorialFlag.mode("DOT_POPPER_TUTORIAL" => "1")
    assert_equal :forced, TutorialFlag.mode("DOT_POPPER_TUTORIAL" => "1", "DOT_POPPER_SCENARIO" => "tutorial")
    %w[DOT_POPPER_AUTOPLAY DOT_POPPER_SCENARIO DOT_POPPER_NO_TUTORIAL].each do |name|
      assert_equal :skipped, TutorialFlag.mode(name => "1"), name
    end
  end
end
