# frozen_string_literal: true

require_relative "../../test_helper"

# What a build is, read from the gem alone.
class GemBuildTest < Minitest::Test
  Build = DotPopper::ReleaseEngineering::Build

  def test_the_repository_s_build_is_a_test_build_with_every_part
    assert_nil Build::CHANNEL
    refute Build.store?
    assert_equal %w[apple play microsoft website test_build], Build::PARTS
  end

  def test_each_channel_carries_only_its_own_store_s_part
    assert_equal({ "app-store" => %w[apple], "mac-app-store" => %w[apple], "google-play" => %w[play],
                   "microsoft-store" => %w[microsoft], "website" => %w[website] },
                 Build::CHANNELS.transform_values(&:parts))
    assert_equal %w[app-store mac-app-store google-play microsoft-store], Build::STORES
  end

  def test_a_build_with_a_channel_keeps_only_the_harmless_developer_settings
    env = { "DOT_POPPER_PRO" => "1", "DOT_POPPER_SEED" => "7", "DOT_POPPER_NOT_YET_WRITTEN" => "1", "HOME" => "/home" }
    assert_equal({ "DOT_POPPER_SEED" => "7", "HOME" => "/home" }, Build.settings(env, channel: "website"))
    assert_same env, Build.settings(env, channel: nil)
  end
end
