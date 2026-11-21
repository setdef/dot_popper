# frozen_string_literal: true

require_relative "../test_helper"
require "dot_popper/presentation"

# A store build is decided by the build alone. Nothing a player can set, in
# the environment, a file or an argument, selects the test keys, grants Pro,
# changes the server, or skips the free-game limit in one
# (ADR-0010).
class BuildTest < Minitest::Test
  STORE = "website"
  SETTINGS = {
    "DOT_POPPER_AUTOMATED" => "1", "DOT_POPPER_PRO" => "1", "DOT_POPPER_SERVER" => "http://localhost:9292",
    "DOT_POPPER_FREE_GAMES" => "999", "DOT_POPPER_TODAY" => "2031-01-01", "DOT_POPPER_THEME_UNLOCKS" => "ghost",
    "DOT_POPPER_THEME" => "ghost", "DOT_POPPER_FAKE_SETDEF" => "here", "DOT_POPPER_FAKE_STORE_FAILS" => "buy",
    "DOT_POPPER_SCENARIO" => "game", "DOT_POPPER_SAVE_AS" => "elsewhere", "DOT_POPPER_GROUP_SCREEN" => "1",
    "DOT_POPPER_SOMETHING_NEW" => "1"
  }.freeze

  def test_a_store_build_ignores_every_setting_that_touches_purchases_pro_or_the_server
    settings = DotPopper::ReleaseEngineering::Build.settings(SETTINGS.merge("PATH" => "/bin"), channel: STORE)

    assert_equal({ "PATH" => "/bin" }, settings)
  end

  def test_a_store_build_keeps_the_settings_that_touch_nothing_of_the_kind
    kept = { "DOT_POPPER_CALM" => "1", "DOT_POPPER_AUTOPLAY" => "1", "DOT_POPPER_QUIT_AFTER" => "20", "DOT_POPPER_WINDOW" => "400x850" }

    assert_equal kept, DotPopper::ReleaseEngineering::Build.settings(kept, channel: STORE)
  end

  def test_a_test_build_obeys_every_setting
    assert_equal SETTINGS, DotPopper::ReleaseEngineering::Build.settings(SETTINGS, channel: nil)
  end

  def test_pro_and_the_server_stay_as_they_were_in_a_store_build
    env = DotPopper::ReleaseEngineering::Build.settings(SETTINGS, channel: STORE)

    assert_equal DotPopper::Network::Server::SERVER_URL, DotPopper::Network::Server.url(env)
    refute DotPopper::Automation.on?(env), "a store build is not made automated by the environment"
  end

  def test_the_settings_do_work_in_a_test_build
    env = DotPopper::ReleaseEngineering::Build.settings(SETTINGS, channel: nil)

    assert_equal "http://localhost:9292", DotPopper::Network::Server.url(env)
  end

  # One list names every channel, whether it is an app store's, and the
  # parts its build carries, none of them the test build's.
  def test_one_list_names_every_channel_and_what_its_build_carries
    build = DotPopper::ReleaseEngineering::Build

    assert_equal build::CHANNEL_NAMES, build::CHANNELS.values.map(&:name)
    assert_equal [build::WEBSITE], build::CHANNEL_NAMES - build::STORES
    assert_predicate build::CHANNELS, :frozen?
    build::CHANNELS.each_value { refute_includes it.parts, "test_build", it.name }
  end
end
