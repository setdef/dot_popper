# frozen_string_literal: true

require "test_helper"
require "dot_popper/use_cases"

# Using a theme: only Pro uses one other than the ordinary, and a Free
# player's choice leads to the offer instead.
class UseThemeTest < Minitest::Test
  # The themes the game keeps, as a local fake: :plain is the ordinary
  # one, and only the open ones may be chosen.
  class SavedThemes
    attr_reader :chosen

    def initialize(open:) = (@open = open) && (@chosen = :plain)
    def ordinary = :plain
    def open?(theme) = @open.include?(theme)
    def use(theme) = @chosen = theme
  end

  def setup
    @saved_themes = SavedThemes.new(open: %i[plain ghost])
  end

  def use_theme(pro:) = DotPopper::UseCases::UseTheme.new(saved_themes: @saved_themes, entitlement: DotPopper::Entitlement.new(forced: pro))

  def test_pro_uses_an_open_theme_at_once
    pro = use_theme(pro: true)

    assert_equal :used, pro.call(:ghost)
    assert_equal :ghost, pro.current
    assert_equal :ghost, @saved_themes.chosen
  end

  def test_the_current_theme_or_one_not_open_changes_nothing
    pro = use_theme(pro: true)

    assert_equal :same, pro.call(:plain)
    assert_equal :same, pro.call(:eclipse)
    assert_equal :plain, @saved_themes.chosen
  end

  # What the new theme card's switch leads to, as choosing the theme
  # would (#call), before it is pressed: using it for Pro, nothing where
  # it is current or not open, and the offer of Pro for a Free player.
  # Whether the player has Pro is not asked of the use case by anyone
  # else.
  def test_the_switch_leads_a_pro_player_to_the_theme_and_a_free_one_to_the_offer
    assert_equal :use, use_theme(pro: true).choice(:ghost)
    assert_equal :same, use_theme(pro: true).choice(:plain)
    assert_equal :same, use_theme(pro: true).choice(:eclipse)
    assert_equal :offer, use_theme(pro: false).choice(:ghost)
    refute_respond_to use_theme(pro: false), :locked?
  end

  def test_a_free_player_is_offered_pro_and_keeps_the_ordinary_theme
    free = use_theme(pro: false)

    assert_equal :offer, free.choice(:ghost)
    assert_equal :offer, free.call(:ghost)
    assert_equal :plain, free.current
    assert_equal :plain, @saved_themes.chosen
  end

  def test_a_choice_made_with_pro_is_current_only_while_pro_lasts
    use_theme(pro: true).call(:ghost)

    assert_equal :plain, use_theme(pro: false).current
    assert_equal :ghost, use_theme(pro: true).current
  end

  def test_pro_arriving_changes_the_current_theme_only_once_it_is_taken_up
    entitlement = DotPopper::Entitlement.test
    @saved_themes.use(:ghost)
    theme = DotPopper::UseCases::UseTheme.new(saved_themes: @saved_themes, entitlement:)
    entitlement.verify_receipt(DotPopper::Receipt.issue)

    assert_equal :plain, theme.current, "never mid-game"
    theme.refresh
    assert_equal :ghost, theme.current
  end

  # With the game's own Themes: a theme a Pro player chose is current
  # after a restart, and a saved choice of a theme since removed gives way
  # to the ordinary one.
  def test_with_the_games_themes_a_choice_lasts_and_a_removed_one_gives_way
    file = DotPopper::Gameplay::ScoreRecord::Memory.new("unlocked: ghost jingle_bell\ntold: ghost\nchosen: jingle_bell\n")
    pro = DotPopper::Entitlement.new(forced: true)
    theme = DotPopper::UseCases::UseTheme.new(saved_themes: DotPopper::Gameplay::SavedThemes.new(file), entitlement: pro)

    assert_equal :classic, theme.current
    assert_equal :used, theme.call(:ghost)
    assert_equal :ghost, DotPopper::UseCases::UseTheme.new(saved_themes: DotPopper::Gameplay::SavedThemes.new(file), entitlement: pro).current
  end
end
