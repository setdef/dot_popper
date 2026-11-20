# frozen_string_literal: true

require_relative "presentation_helper"
require "platforms_helper"

# Buying Pro: the URLs the hosts catch, the answers they
# write back, and the calm screen that offers it.
class StoreTest < Minitest::Test
  include PresentationTest

  Store = DotPopper::Monetization::Store
  NoStore = DotPopper::Monetization::NoStore
  NativeStore = DotPopper::Monetization::NativeStore
  FakeStore = DotPopper::Monetization::FakeStore
  WebsiteStore = DotPopper::Monetization::WebsiteStore
  FakeCheckout = DotPopper::Monetization::FakeCheckout

  class FakeOpener
    attr_reader :urls
    attr_writer :refuses

    def initialize = @urls = []

    def open(url)
      @urls << url
      !@refuses
    end
  end

  class FakeAnswers
    attr_accessor :text
    attr_reader :removed

    def read = @text
    def remove = (@removed = true) && (@text = nil)
    def path = "/save dir/answer.txt"
  end

  RECEIPT = DotPopper::Monetization::Receipt.issue

  def setup
    @opener = FakeOpener.new
    @answers = FakeAnswers.new
    @entitlement = DotPopper::Monetization::Entitlement.test
    @store = Store.new(port: port, entitlement: @entitlement)
  end

  def port = DotPopper::Monetization::NativeStore.new(opener: @opener, answers: @answers)

  # The native adapter a build for sale chooses, at the composition root.
  def stores
    @native ||= port
    { native: @native }
  end

  # The fake store's adapter, which only a test build chooses.
  def fake = @fake ||= DotPopper::Monetization::FakeStore.new(DotPopper::MemoryFile.new)

  def hear(text)
    @answers.text = text
    @store.update(Store::EVERY)
  end

  # Play takes only lowercase letters, digits, "_" and "." in a product
  # id, and one id serves every store.
  def test_pro_has_one_product_id_every_store_accepts
    assert_match(/\A[a-z][a-z0-9_.]*\z/, Store::PRODUCT_ID)
    assert_equal DotPopper::Monetization::Receipt::PRODUCT_ID, Store::PRODUCT_ID
  end

  def test_a_url_names_the_action_the_request_the_product_and_where_to_answer
    assert_equal "dotpopper-store://buy?n=3&product=com.setdef.dotpopper.pro&file=%2Fsave%20dir%2Fanswer.txt",
                 Store.url(:buy, 3, "/save dir/answer.txt")
  end

  def test_a_phone_test_build_is_metered_like_the_final_game
    %w[iOS Android].each do |os|
      store = Store.of_test_build(DotPopperTest.platform(os), fake:, entitlement: @entitlement)
      games = DotPopper::Monetization::FreeGames.new(DotPopper::MemoryFile.new, today: -> { Date.today }, entitlement: @entitlement,
                                                                         metered: store.offered?)

      assert_predicate games, :metered?, os
    end
  end

  # With no website store to give, as in a test of the store alone.
  def test_a_test_build_uses_the_fake_store_on_every_system
    ["iOS", "Android", "Linux", "Windows", "OS X"].each do |os|
      store = Store.of_test_build(DotPopperTest.platform(os), fake:, entitlement: @entitlement)

      assert_same fake, store.instance_variable_get(:@port), os
    end
  end

  def test_a_store_build_uses_the_native_store_on_phones
    %w[iOS Android].each do |os|
      store = Store.for(DotPopperTest.platform(os), **stores, entitlement: @entitlement, channel: "app-store")

      assert_same @native, store.instance_variable_get(:@port), os
    end
  end

  def test_a_computers_own_store_build_uses_the_native_port_on_that_computer_only
    { "mac-app-store" => "OS X", "microsoft-store" => "Windows" }.each do |channel, os|
      store = Store.for(DotPopperTest.platform(os), **stores, entitlement: @entitlement, channel:)

      assert_same @native, store.instance_variable_get(:@port), channel
      (["Linux", "OS X", "Windows"] - [os]).each do |other|
        refute_predicate Store.for(DotPopperTest.platform(other), **stores, entitlement: @entitlement, channel:), :offered?, "#{channel} on #{other}"
      end
    end
  end

  def test_connecting_asks_the_store_and_a_pro_player_needs_no_asking
    @store.connect

    assert @answers.removed
    assert_match %r{\Adotpopper-store://open\?n=1&}, @opener.urls.last
    assert_equal :loading, @store.status

    @entitlement.verify_receipt(RECEIPT)
    @store.connect

    assert_equal 1, @opener.urls.size
  end

  def test_an_answer_sets_the_price_and_status
    @store.connect
    hear("answer=1\nowned=0\nstate=ready\nprice=$1.99\n")

    assert_equal "$1.99", @store.price
    assert_equal :ready, @store.status
    refute_predicate @entitlement, :pro?
  end

  def test_a_receipt_proves_pro_whatever_request_the_answer_is_to
    @store.connect
    @store.connect
    hear("answer=1\nowned=1\nstate=ready\nprice=$1.99\nreceipt=#{RECEIPT}\n")
  
    assert_predicate @entitlement, :pro?
  end
  
  # The maintainer's rule: editing a text file must never grant Pro.
  def test_an_answer_that_only_says_owned_proves_nothing
    @store.connect
    hear("answer=1\nowned=1\nstate=ready\nprice=$1.99\n")
    hear("answer=1\nowned=1\nstate=ready\nprice=$1.99\nreceipt=pro\n")
    hear("answer=1\nowned=1\nstate=ready\nprice=$1.99\nreceipt=#{RECEIPT.sub("play:", "play:A")}\n")
  
    refute_predicate @entitlement, :pro?
  end
  
  def test_a_receipt_the_test_key_signed_proves_nothing_in_a_store_build
    store = Store.new(port:, entitlement: entitlement = DotPopper::Monetization::Entitlement.free)
    store.connect
    @answers.text = "answer=1\nowned=1\nstate=ready\nprice=$1.99\nreceipt=#{RECEIPT}\n"
    store.update(Store::EVERY)
  
    refute_predicate entitlement, :pro?
  end

  def test_an_older_answer_does_not_overturn_a_newer_request
    @store.connect
    hear("answer=1\nowned=0\nstate=ready\nprice=$1.99\n")
    @store.buy
    hear("answer=1\nowned=0\nstate=ready\nprice=$1.99\n")

    assert_equal :busy, @store.status
    hear("answer=2\nowned=0\nstate=canceled\nprice=$1.99\n")

    assert_equal :ready, @store.status
  end

  def test_buying_needs_a_price_and_is_not_asked_twice
    @store.buy

    assert_empty @opener.urls
    @store.connect
    hear("answer=1\nowned=0\nstate=ready\nprice=$1.99\n")
    @store.buy
    @store.buy

    assert_equal(1, @opener.urls.count { it.include?("://buy") })
    assert_includes @opener.urls.last, "n=2"
  end

  def test_restore_says_when_there_is_nothing_to_restore
    @store.restore
    hear("answer=1\nowned=0\nstate=none\n")

    assert_equal :none, @store.status
  end

  def test_a_refusal_or_an_unknown_state_is_said_plainly
    @opener.refuses = true
    @store.connect

    assert_equal :unavailable, @store.status
    @opener.refuses = false
    @store.connect
    hear("answer=2\nowned=0\nstate=gibberish\n")

    assert_equal :failed, @store.status
  end

  def test_a_store_that_later_says_not_owned_takes_nothing_back
    @entitlement.verify_receipt(RECEIPT)
    hear("answer=9\nowned=0\nstate=ready\n")

    assert_predicate @entitlement, :pro?
  end

  def test_the_answer_is_read_only_every_so_often
    @answers.text = "answer=0\nowned=1\nstate=ready\nreceipt=#{RECEIPT}\n"
    @store.update(Store::EVERY / 2)

    refute_predicate @entitlement, :pro?
    @store.update(Store::EVERY)

    assert_predicate @entitlement, :pro?
  end

  def test_a_computer_build_of_a_store_nobody_has_built_offers_nothing
    refute_predicate Store.for(DotPopperTest.platform("Linux"), **stores, entitlement: @entitlement, channel: "steam"), :offered?
    assert_instance_of Store, Store.for(DotPopperTest.platform("iOS"), **stores, entitlement: @entitlement, channel: "steam")
  end

  def test_no_word_of_the_offer_calls_it_a_trial_or_a_demo
    words = Style::WORDS.offer.values.flatten.join(" ")

    refute_match(/trial|demo/i, words)
  end

  def test_a_store_is_not_read_during_a_game
    show, = offer_show
    @answers.text = "answer=0\nowned=1\nstate=ready\nreceipt=#{RECEIPT}\n"
    show.primary
    show.update(Store::EVERY * 2)

    refute_predicate @entitlement, :pro?
  end

  def test_a_purchase_landing_while_the_offer_is_open_ticks
    show, = offer_show
    open_offer(show)
    answer("answer=1\nowned=1\nstate=ready\nreceipt=#{RECEIPT}\n", show)

    assert_predicate @entitlement, :pro?
    assert_equal [:tick, 1.3], show.sounds.played.last
  end

  def test_a_build_with_no_store_offers_nothing
    show = build_show(store: NoStore.new)
    show.open_stats

    refute_includes show.controls.map(&:name), :offer
  end

  private

  def overlap?(one, other)
    one.x < other.right && other.x < one.right && one.y < other.bottom && other.y < one.bottom
  end

  def build_show(**options)
    game_flow = DotPopper::Gameplay::GameFlow.new(field, random: Random.new(3))
    new_show(game_flow:, layout: layout, sounds: FakeSounds.new, radius: R, measure: RoughMeasure.new, **options)
  end

  def offer_show
    opener = FakeOpener.new
    store = Store.new(port: DotPopper::Monetization::NativeStore.new(opener:, answers: @answers), entitlement: @entitlement)
    show = build_show(store:, entitlement: @entitlement)
    [show, opener]
  end

  def answer(text, show)
    @answers.text = text
    show.update(Store::EVERY)
  end
end
