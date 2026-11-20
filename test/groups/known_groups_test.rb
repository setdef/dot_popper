# frozen_string_literal: true

require "test_helper"

# What the game last heard from the server, and the rules for telling the
# player of a title change.
class KnownGroupsTest < Minitest::Test
  Groups = DotPopper::Groups

  def setup = @known = Groups::KnownGroups.new

  def group(id: 1, you: 2, champion: 1, top: 50)
    Groups::Group.parse({ "id" => id, "join_code" => "2345678", "you" => you, "champion_number" => champion, "top_score" => top,
                          "members" => [{ "number" => 1, "top_score" => 10 }, { "number" => 2, "top_score" => 20 }] })
  end

  def change(id, champion: 1, previous: 2, score: 50) = { "id" => id, "champion_number" => champion, "previous_champion_number" => previous, "score" => score }

  def announcements = [].tap { |all| while (one = @known.next_announcement) do all << one end }

  def test_the_last_known_answer_stands_until_groups_are_heard
    assert_predicate Groups::KnownGroups.new(last_known_member: true), :member?
    refute_predicate @known, :member?
    @known.upsert(group)

    assert_predicate @known, :member?
  end

  def test_what_the_server_answers_replaces_what_is_here
    @known.upsert(group)
    @known.upsert(group(top: 70))
    @known.upsert(group(id: 2))

    assert_equal [[1, 70], [2, 50]], @known.groups.map { [it.id, it.top_score] }
    @known.replace([group(id: 2)])

    assert_equal [2], @known.groups.map(&:id)
  end

  def test_a_group_listed_no_more_is_forgotten_with_what_was_seen_of_it
    @known.upsert(group)
    @known.read_history(1, [change(4)])
    @known.replace([])

    assert_empty @known.seen
  end

  def test_a_gone_group_takes_its_history_with_it
    @known.upsert(group)
    @known.read_history(1, [change(4)])
    @known.gone(1)

    assert_nil @known.group(1)
    assert_nil @known.title_changes(1)
    assert_nil @known.history(1)
    assert_empty @known.seen
  end

  def test_membership_is_remembered_and_its_change_told
    @known.upsert(group)

    assert @known.remember_membership
    refute @known.remember_membership
    @known.gone(1)

    assert @known.remember_membership
    refute @known.last_known_member
  end

  def test_the_history_is_worth_reading_only_once_the_title_has_moved
    @known.upsert(group)

    assert @known.title_moved?(group), "never read"
    @known.read_history(1, [])

    refute @known.title_moved?(group)
    assert @known.title_moved?(group(top: 60))
  end

  def test_a_history_is_taken_only_for_a_known_group_and_only_as_a_list
    refute @known.read_history(1, [change(4)])
    @known.upsert(group)

    refute @known.read_history(1, "garbage")
    assert @known.read_history(1, [change(2), change(9), { "kind" => "achievement", "id" => 5, "member_number" => 1, "key" => "steady" }])
    assert_equal [9, 2], @known.title_changes(1).map(&:id)
    assert_equal [9, 5, 2], @known.history(1).map(&:id)
  end

  def test_a_group_met_for_the_first_time_announces_nothing_of_its_past
    @known.upsert(group)
    @known.read_history(1, [change(9), change(4)])

    assert_empty announcements
  end

  def test_only_the_newest_change_not_yet_told_is_announced_once
    @known.upsert(group)
    @known.read_history(1, [change(4)])
    @known.read_history(1, [change(9, score: 90), change(8, score: 80), change(4)])

    assert_equal [90], announcements.map(&:score)
    @known.read_history(1, [change(9, score: 90), change(8, score: 80), change(4)])

    assert_empty announcements
  end

  def test_a_later_change_replaces_one_not_yet_told
    @known.upsert(group)
    @known.read_history(1, [change(4)])
    @known.read_history(1, [change(5, score: 60), change(4)])
    @known.read_history(1, [change(6, score: 70), change(5), change(4)])

    assert_equal [70], announcements.map(&:score)
  end

  def test_what_was_seen_is_kept_for_the_next_launch
    @known.upsert(group)
    @known.read_history(1, [change(4)])

    assert_equal({ 1 => Groups::Seen.new(last: 4, fingerprint: "1~50") }, @known.seen)
    later = Groups::KnownGroups.new(seen: @known.seen)
    later.upsert(group)
    later.read_history(1, [change(4)])

    assert_empty [later.next_announcement].compact
  end

  def test_the_newest_change_shown_never_goes_back
    @known.upsert(group)
    @known.read_history(1, [change(9)])
    @known.upsert(group(top: 60))
    @known.read_history(1, [change(4)])

    assert_equal 9, @known.seen.fetch(1).last
  end

  def test_an_arrival_is_taken_once
    @known.arrived(3)

    assert_equal 3, @known.take_arrival
    assert_nil @known.take_arrival
  end

  def test_a_forgotten_player_has_heard_nothing
    @known.upsert(group)
    @known.read_history(1, [change(4)])
    @known.read_history(1, [change(5), change(4)])
    @known.forget

    assert_empty @known.groups
    assert_empty @known.seen
    assert_nil @known.next_announcement
    refute_predicate @known, :member?
  end
end
