# frozen_string_literal: true

require "test_helper"

# What the game owes the server, and the rules for sending it.
class UnsentTest < Minitest::Test
  Unsent = DotPopper::Groups::Unsent

  def setup = @unsent = Unsent.new

  def owe(score, member: true, counts: true) = @unsent.owe_game(score:, counts:, member:)

  def test_only_a_game_that_counts_is_owed
    assert_nil owe(40, member: false)
    assert_nil owe(40, counts: false)
    assert_nil owe(0)
    assert_nil @unsent.score
    assert_equal 40, owe(40)
  end

  def test_a_score_is_clamped_to_what_the_server_takes
    assert_equal 100_000, owe(999_999)
    assert_equal 100_000, @unsent.score
  end

  def test_only_the_highest_unsent_score_is_kept
    owe(30)

    assert_equal 20, owe(20), "the game's own score, for its result"
    assert_equal 30, @unsent.score
    owe(50)

    assert_equal 50, @unsent.score
  end

  def test_nothing_is_sent_to_a_player_in_no_group
    owe(30)
    @unsent.owe_achievements(["steady"])

    assert_nil @unsent.take_score(member: false)
    assert_empty @unsent.take_achievements(member: false)
    assert_equal 30, @unsent.take_score(member: true)
    assert_equal ["steady"], @unsent.take_achievements(member: true)
  end

  def test_a_score_is_in_flight_once_at_a_time
    owe(30)

    assert_equal 30, @unsent.take_score(member: true)
    owe(40)

    assert_nil @unsent.take_score(member: true)
    @unsent.score_settled

    assert_equal 40, @unsent.take_score(member: true)
  end

  def test_a_score_is_taken_only_by_its_own_answer
    owe(30)
    @unsent.take_score(member: true)
    owe(40)
    @unsent.score_taken(30)

    assert_equal 40, @unsent.score
    @unsent.score_taken(40)

    assert_nil @unsent.score
  end

  def test_a_dropped_score_is_owed_no_longer
    owe(30)
    @unsent.drop_score

    assert_nil @unsent.take_score(member: true)
  end

  def test_each_achievement_is_owed_once_and_in_flight_once
    assert @unsent.owe_achievements([:steady, "blink"])
    refute @unsent.owe_achievements(["steady"])
    assert_equal %w[steady blink], @unsent.take_achievements(member: true)
    @unsent.owe_achievements(["tap"])

    assert_equal ["tap"], @unsent.take_achievements(member: true)
    @unsent.achievement_settled("steady")

    assert_equal ["steady"], @unsent.take_achievements(member: true), "answered but not taken: it is owed still"
    @unsent.drop_achievement("steady")

    assert_equal %w[blink tap], @unsent.achievements
  end

  def test_a_forgotten_player_owes_nothing
    owe(30)
    @unsent.owe_achievements(["steady"])
    @unsent.take_achievements(member: true)
    @unsent.forget

    assert_nil @unsent.score
    assert_empty @unsent.achievements
    @unsent.owe_achievements(["steady"])

    assert_equal ["steady"], @unsent.take_achievements(member: true)
  end
end
