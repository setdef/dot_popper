# frozen_string_literal: true

require "test_helper"

# Which server friend groups and themes use: setdef's, or while setdef is
# gone, one the player pasted.
class ServerChoiceTest < Minitest::Test
  Memory = DotPopper::Gameplay::ScoreRecord::Memory
  OWN = "https://server.dot-popper.setdef.com"
  Gone = DotPopper::Gameplay::SetdefGone
  JAN1 = Date.new(2027, 1, 1)

  class Clipboard
    attr_accessor :text

    def paste = text
  end

  def setup
    @file = Memory.new
    @clipboard = Clipboard.new
    @choice = DotPopper::Gameplay::ServerChoice.new(@file, gone: false, clipboard: @clipboard)
  end

  def test_while_setdef_answers_nothing_is_offered_and_setdefs_server_is_used
    @file.write("https://groups.example.org\n")

    refute_predicate @choice, :offered?
    assert_equal OWN, @choice.server_url(OWN)
  end

  # setdef found gone before this launch: offered from the start, until
  # setdef answers.
  def test_setdef_gone_as_the_game_starts_offers_change_server_until_setdef_answers
    choice = DotPopper::Gameplay::ServerChoice.new(@file, gone: true, clipboard: @clipboard)
    assert_predicate choice, :offered?

    choice.call(DotPopper::Gameplay::SetdefHere.new)
    refute_predicate choice, :offered?
  end

  def test_while_setdef_is_gone_a_pasted_https_address_is_kept_and_used
    @choice.call(Gone.new(since: JAN1, today: JAN1))
    assert_predicate @choice, :offered?
    assert_equal OWN, @choice.server_url(OWN)

    @clipboard.text = "  "
    assert_equal :empty, @choice.paste
    @clipboard.text = "http://groups.example.org"
    assert_equal :not_https, @choice.paste
    assert_nil @choice.address
    @clipboard.text = " https://groups.example.org \n"
    assert_equal :chosen, @choice.paste
    assert_equal :chosen, @choice.status
    assert_equal "https://groups.example.org\n", @file.read
    assert_equal "https://groups.example.org", @choice.server_url(OWN)
  end

  def test_when_setdef_answers_again_a_chosen_server_is_forgotten
    @choice.call(Gone.new(since: JAN1, today: JAN1))
    @clipboard.text = "https://groups.example.org"
    @choice.paste

    @choice.call(Gone.new(since: JAN1, today: JAN1 + 1))
    assert_equal "https://groups.example.org", @choice.address, "kept while setdef is still gone"
    @choice.call(DotPopper::Gameplay::SetdefHere.new)
    assert_nil @choice.address
    assert_equal "", @file.read
    assert_equal OWN, @choice.server_url(OWN)
  end

  def test_a_chosen_server_is_forgotten_only_once_setdef_is_back
    @choice.call(Gone.new(since: JAN1, today: JAN1))
    @clipboard.text = "https://groups.example.org"
    @choice.paste

    @choice.forget
    assert_equal "https://groups.example.org", @choice.address
  end

  def test_reset_goes_back_to_setdefs_server
    @choice.call(Gone.new(since: JAN1, today: JAN1))
    @clipboard.text = "https://groups.example.org"
    @choice.paste
    @choice.reset

    assert_nil @choice.status
    assert_equal OWN, @choice.server_url(OWN)
  end

  def test_a_server_address_must_be_one_https_address
    ["https://a.example", "https://a.example:8443/api"].each { assert DotPopper::Gameplay::ServerChoice.https?(it), it }
    ["http://a.example", "https://", "https://u:p@a.example", "https://a.example b", "ftp://a.example", "a.example", "https://[bad"].each do
      refute DotPopper::Gameplay::ServerChoice.https?(it), it
    end
  end
end
