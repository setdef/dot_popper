# frozen_string_literal: true

require "test_helper"

# What achievements.txt holds, apart from the rules of earning: a line of
# id=day for each achievement earned, in the order the game lists them.
class AchievementsFileTest < Minitest::Test
  AchievementsFile = DotPopper::Gameplay::AchievementsFile

  def test_it_reads_each_earned_achievement_and_writes_them_in_the_games_order
    saved = AchievementsFile.parse("patience=2026-11-02\nsharpshooter=2026-11-01\n")

    assert_equal({ patience: "2026-11-02", sharpshooter: "2026-11-01" }, saved.days)
    assert_equal "sharpshooter=2026-11-01\npatience=2026-11-02\n", saved.to_s
  end

  def test_what_it_cannot_read_or_does_not_know_is_left_out
    saved = AchievementsFile.parse("from_a_newer_version=2030-01-01\n\nnonsense\nblink=2026-11-03\n")
    assert_equal "blink=2026-11-03\n", saved.to_s
    assert_equal "", AchievementsFile.parse(nil).to_s
  end
end
