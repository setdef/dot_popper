# frozen_string_literal: true

require "test_helper"
require "dot_popper/composition/use_cases"

# A license key entered on the offer of Pro, on a website copy
# (lib/dot_popper/website/offer.rb): pasted or typed into the website's
# store, and once the player has Pro a typed key reaches nothing.
class EnterLicenseKeyTest < Minitest::Test
  # The website store's answers for a key, as a local fake: what it was
  # asked.
  class Store
    attr_reader :asked

    def initialize = @asked = []
    def paste = (@asked << :paste) && :invalid
    def type(key) = (@asked << [:type, key]) && true
    def typed = "AB"
  end

  def setup
    @store = Store.new
    @entitlement = DotPopper::Monetization::Entitlement.test
    @keys = DotPopper::UseCases::EnterLicenseKey.new(store: @store, entitlement: @entitlement)
  end

  def test_a_key_is_pasted_or_typed_into_the_store
    assert_equal :invalid, @keys.paste
    assert @keys.type(:a)
    assert_equal "AB", @keys.typed
    assert_equal [:paste, [:type, :a]], @store.asked
  end

  def test_a_typed_key_does_nothing_once_the_player_has_pro
    @entitlement.verify_receipt(DotPopper::Monetization::Receipt.issue)

    refute @keys.type(:a)
    assert_empty @store.asked
  end
end
