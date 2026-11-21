# frozen_string_literal: true

require "test_helper"

# A friend group's join code as a player taps it in: seven digits, which
# the server makes.
class JoinCodeTest < Minitest::Test
  JoinCode = DotPopper::Gameplay::Groups::JoinCode

  def typed(digits) = digits.chars.reduce(JoinCode.empty) { |code, digit| code.add(digit) }

  def test_a_code_takes_digits_until_it_has_seven
    assert_equal "1234567", typed("123456789").digits
    refute_predicate typed("123456"), :complete?
    assert_predicate typed("1234567"), :complete?
  end

  def test_a_code_takes_nothing_but_one_digit_at_a_time
    assert_equal "12", typed("1a2").digits
    assert_equal "", JoinCode.empty.add("12").digits
    assert_equal "", JoinCode.empty.add("").digits
    assert_equal "", JoinCode.empty.add("٣").digits, "only 0 to 9"
  end

  def test_erasing_takes_the_last_digit_away
    assert_equal "12", typed("123").erase.digits
    assert_equal "", JoinCode.empty.erase.digits
  end

  def test_the_code_is_a_value
    assert_equal typed("12"), typed("12")
    assert_predicate typed("12"), :frozen?
  end
end
