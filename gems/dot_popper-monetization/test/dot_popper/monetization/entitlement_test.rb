# frozen_string_literal: true

require "test_helper"

# What Monetization decides with nothing but itself: no store's receipt
# check, no license key and no test build's part, as a build for sale of
# a channel with no store starts. The tests of each store's receipts and
# of the test build's switches are the game's (test/monetization/), since
# that code is in the game's build parts.
class EntitlementAloneTest < Minitest::Test
  M = DotPopper::Monetization

  def test_a_free_entitlement_is_not_pro
    refute_predicate M::Entitlement.free, :pro?
  end

  def test_no_receipt_grants_pro_when_no_store_is_trusted
    entitlement = M::Entitlement.free
    refute M::Receipt.valid?("play:anything", M::Receipt::NONE)
    refute entitlement.verify_receipt("play:anything")
    refute_predicate entitlement, :pro?
  end

  def test_only_a_license_that_is_pro_grants_pro
    refute_predicate M::Entitlement.new(license: Data.define(:pro?).new(pro?: false)), :pro?
    assert_predicate M::Entitlement.new(license: Data.define(:pro?).new(pro?: true)), :pro?
  end

  def test_the_area_alone_holds_none_of_the_build_parts
    %i[TEST APPLE PLAY MICROSOFT_STORE Apple Play Microsoft TestKey].each { refute M::Receipt.const_defined?(it, false), it }
    %i[LicenseKeys WebsiteStore FakeStore FakeCheckout].each { refute M.const_defined?(it, false), it }
  end
end
