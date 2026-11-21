# frozen_string_literal: true

require_relative "../../../test_helper"

# The Microsoft Store's word, read with the gem and Monetization alone.
class MicrosoftReceiptTest < Minitest::Test
  Receipt = DotPopper::Monetization::Receipt

  def test_windows_word_proves_pro_only_in_the_microsoft_store_build
    word = "microsoft:#{Receipt::PRODUCT_ID}:9NBLGGH4R315/000N"

    assert Receipt.valid?(word, Receipt::MICROSOFT_STORE)
    refute Receipt.valid?(word, Receipt::NONE)
  end

  def test_windows_word_for_another_add_on_or_no_sku_proves_nothing
    refute Receipt.valid?("microsoft:com.setdef.DotPopper.other:9NBLGGH4R315/000N", Receipt::MICROSOFT_STORE)
    refute Receipt.valid?("microsoft:#{Receipt::PRODUCT_ID}", Receipt::MICROSOFT_STORE)
    refute Receipt.valid?("microsoft:#{Receipt::PRODUCT_ID}:owned", Receipt::MICROSOFT_STORE)
  end
end
