# frozen_string_literal: true

# The apple part (Build::PARTS names it in the App Store's and the Mac App
# Store's builds and in every build with no channel; no other build
# carries it): the code that checks Apple's receipts, StoreKit's signed
# transactions, under Monetization's own names (Receipt::Apple,
# Receipt::APPLE). It leans on Receipt, loaded before it.
require_relative "receipt"
