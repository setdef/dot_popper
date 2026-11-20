# frozen_string_literal: true

require_relative "presentation_helper"

class SizingPreviewTest < Minitest::Test
  include PresentationTest

  BIGGER_OR_SMALLER = DotPopper::Gameplay::DotSizing::BIGGER_OR_SMALLER
  STANDARD = DotPopper::Gameplay::DotSizing::STANDARD

  def preview(standard, bigger_or_smaller: 50) = SizingPreview.new(bigger_or_smaller:, standard:, style: Style::SIZING)
  def named(sizing, standard) = Style::WORDS.sizing(sizing, preview(standard))

  # The default is "Standard" everywhere, and the other is named for
  # what a player sees it do here, next to it. The maintainer: "A player
  # sees only their own relative dot sizes: the smaller option, and the
  # bigger option." So on a phone the other reads "Bigger", and on a big
  # monitor "Smaller".
  def test_the_default_is_standard_and_the_other_is_named_for_what_it_does_here
    assert_equal ["Standard", "Bigger"], [named(STANDARD, 30), named(BIGGER_OR_SMALLER, 30)]
    assert_equal ["Standard", "Bigger"], [named(STANDARD, 44.9), named(BIGGER_OR_SMALLER, 44.9)]
    assert_equal ["Standard", "Smaller"], [named(STANDARD, 55.1), named(BIGGER_OR_SMALLER, 55.1)]
    assert_equal ["Standard", "Smaller"], [named(STANDARD, 97), named(BIGGER_OR_SMALLER, 97)]
  end

  # Within a tenth either way the two look alike, and Settings leaves
  # the choice out.
  def test_sizes_within_a_tenth_of_each_other_are_not_worth_a_choice
    [45.1, 50, 54.9].each do
      assert_equal :alike, preview(it).effect
      refute preview(it).offered?
    end
    assert preview(44.9).offered?
    assert preview(55.1).offered?
  end

  def test_it_reads_this_screens_sizes
    assert_equal :smaller, SizingPreview.of(DotPopper::Gameplay::Field.new(400, 850, 50), Style::SIZING).effect
    assert_equal :bigger, SizingPreview.of(DotPopper::Gameplay::Field.new(2400, 1500, 50), Style::SIZING).effect
    assert_equal :alike, SizingPreview.of(DotPopper::Gameplay::Field.new(1200, 800, 50), Style::SIZING).effect
  end

  # The icons stand in true proportion to the two sizes, as far as they
  # stay legible in a segment.
  def test_the_icons_are_in_proportion
    other = preview(30).icon(BIGGER_OR_SMALLER, 50)

    assert_in_delta 50 * Style::SIZING.icon, other
    assert_in_delta other * 0.6, preview(30).icon(STANDARD, 50)
    assert_in_delta other * 1.5, preview(75).icon(STANDARD, 50)
    assert_equal other, preview(97).icon(BIGGER_OR_SMALLER, 50), "the bigger or smaller size's icon never changes"
  end

  def test_the_icons_stay_legible_and_inside_their_segment
    smallest, largest = Style::SIZING.icons.minmax

    assert_in_delta 50 * Style::SIZING.icon * smallest, preview(5).icon(STANDARD, 50)
    assert_in_delta 50 * Style::SIZING.icon * largest, preview(500).icon(STANDARD, 50)
    assert_operator 2 * preview(500).icon(STANDARD, 50), :<, 50, "the biggest dot fits in the segment"
    assert_operator preview(5).icon(STANDARD, 44), :>=, 3, "the smallest is still a dot"
  end
end
