# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"
require "yaml"
require_relative "../script/set_build_channel"
require_relative "../script/channel_contents"
require_relative "../script/packaged_app"

# A release checks the app it built (script/check_build.rb), laid out here
# as `lota fuse` lays one out: the game's copy in game/dot_popper.
class CheckBuildTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "script", "check_build.rb")

  def setup
    require "lota"
    @app = Dir.mktmpdir("dot_popper_app")
    @game = File.join(@app, "Dot Popper", "app", "game", "dot_popper")
    lay_out_app
    @version = YAML.load_file(File.join(ROOT, "fledge.yml")).fetch("version").to_s
  rescue LoadError => e
    skip "Lota isn't installed here (#{e.message})"
  end

  def teardown = @app && FileUtils.rm_rf(@app)

  # An app store's build carries no website part and is checked without
  # it; one that carries the part fails.
  def test_an_app_store_build_is_checked_without_the_website_part
    stamp("mac-app-store")
    _, out = check("mac-app-store")

    assert_match(/^ok   it carries its channel's parts alone/, out)
    assert_match(/^ok   it loads the website's store and license keys only if it carries the website part$/, out)
    assert_match(/^ok   it trusts setdef's own keys/, out)

    FileUtils.rm_rf(File.join(@game, "lib/dot_popper/website"))
    FileUtils.cp_r(File.join(ROOT, "lib/dot_popper/website"), File.join(@game, "lib/dot_popper/website"))
    edit("lib/dot_popper/release_engineering/build.rb", "PARTS = %w[apple].freeze", "PARTS = %w[apple website].freeze")
    ok, out = check("mac-app-store")

    refute ok, out
    assert_match(/^FAIL it carries its channel's parts alone/, out)
  end

  # Each store's build carries its own store's receipt code alone: the Mac
  # App Store's, Apple's; one that carries Google Play's fails.
  def test_an_app_store_build_carries_its_own_stores_receipts_alone
    stamp("mac-app-store")
    ok, out = check("mac-app-store")

    assert ok, out
    assert_match(/^ok   it loads no other store's receipt code \(apple alone\)$/, out)

    FileUtils.cp_r(File.join(ROOT, "lib/dot_popper/play"), File.join(@game, "lib/dot_popper/play"))
    edit("lib/dot_popper/release_engineering/build.rb", "PARTS = %w[apple].freeze", "PARTS = %w[apple play].freeze")
    ok, out = check("mac-app-store")

    refute ok, out
    assert_match(/^FAIL it loads no other store's receipt code \(apple alone\)$/, out)
    assert_match(%r{FAIL .* holds lib/dot_popper/play \(Google Play's receipts\)}, out)
  end

  # Stamps the copy as script/set_build_channel.rb stamps a build, and
  # leaves out what the channel's build leaves out.
  def stamp(channel)
    build = File.join(@game, "lib/dot_popper/release_engineering/build.rb")
    File.write(build, BuildChannel.stamp(File.read(build), channel))
    ChannelContents.left_out(channel).each { FileUtils.rm_rf(File.join(@game, it)) }
  end

  def edit(path, from, to)
    file = File.join(@game, path)
    source = File.read(file)
    assert_includes source, from
    File.write(file, source.sub(from, to))
  end

  def check(channel, version = @version)
    out, status = Open3.capture2e(RbConfig.ruby, SCRIPT, channel, version, @app)
    [status.success?, out]
  end

  def test_a_website_build_passes_as_a_website_build
    stamp("website")
    ok, out = check("website")

    assert ok, out
    refute_match(/FAIL/, out)
  end

  # The repository's own code is a test build, and a build for another
  # channel is not this one.
  def test_a_test_build_or_another_channels_build_fails
    ok, out = check("website")

    refute ok, out
    assert_match(/FAIL the app was built for "website"/, out)

    stamp("microsoft-store")
    ok, out = check("website")

    refute ok, out
    assert_match(/FAIL the app was built for "website" \(Build::CHANNEL is "microsoft-store"\)/, out)
  end

  def test_a_build_that_trusts_the_test_keys_or_has_another_version_fails
    stamp("website")
    test_pins = DotPopper::Monetization::Continuity::TEST_PINS
    hexes = ->(keys) { "%w[#{keys.map { it.unpack1("H*") }.join(" ")}]" }
    edit("gems/dot_popper-monetization/lib/dot_popper/monetization/continuity/pins.rb", "PINNED = SETDEF_PINS", "PINNED = Pins.of(roots: #{hexes.(test_pins.roots)})")
    edit("lib/dot_popper/website/license_keys/signing_keys.rb", "SIGNING_KEYS = SETDEF_SIGNING_KEYS",
         "SIGNING_KEYS = #{hexes.(DotPopper::Monetization::LicenseKeys::TEST_SIGNING_KEYS)}.map { [it].pack(\"H*\") }")
    ok, out = check("website", "0.0.1")

    refute ok, out
    assert_match(/FAIL it trusts setdef's own keys/, out)
    assert_match(/FAIL it trusts no test key/, out)
    assert_match(/FAIL no license key signed by a test key unlocks it/, out)
    assert_match(/FAIL its version is 0\.0\.1/, out)
  end

  # Only the channel's own needs: Google Play's build needs the Play key,
  # which a website build does not.
  # The test build's proofs come from this repository, so an app that
  # carries no test keys is still shown refusing what they sign.
  def test_an_app_without_the_test_keys_is_checked_with_the_repositorys
    stamp("website")
    ok, out = check("website")

    refute_path_exists File.join(@game, "lib/dot_popper/test_build")

    assert ok, out
    assert_match(/^ok   a key signed by the test key unlocks a test build$/, out)
    assert_match(/^ok   no license key signed by a test key unlocks it$/, out)
  end

  # CI's Package jobs stamp the checkout itself for the channel before
  # they check, and a checkout stamped for a channel loads none of the
  # parts that channel leaves out. The check still makes the test build's
  # proofs there, for every channel a build is sold through.
  def test_the_check_runs_from_a_checkout_stamped_for_each_channel
    DotPopper::ReleaseEngineering::Build::CHANNEL_NAMES.each do |channel|
      lay_out_app
      stamp(channel)
      ok, out = check_from_stamped_checkout(channel)

      refute_match(/could not make the test build's proofs/, out, channel)
      expected = channel != DotPopper::ReleaseEngineering::Build::GOOGLE_PLAY || DotPopper::Monetization::Receipt::PLAY_KEYS.any?
      assert_equal expected, ok, "#{channel}:\n#{out}"
    end
  end

  # A build for sale trusts its own store's receipts, and the website's
  # trusts none. A store's part whose root never answers for it would
  # leave Pro unbuyable there with every other check passed.
  def test_each_build_for_sale_trusts_its_own_stores_receipts
    { "app-store" => "apple", "mac-app-store" => "apple", "google-play" => "play", "microsoft-store" => "microsoft", "website" => nil }
      .each do |channel, part|
        lay_out_app
        stamp(channel)
        _, out = check_from_stamped_checkout(channel)
        trusted = part ? "its store's receipts alone (#{part})" : "no store's receipts"
        assert_match(/^ok   it trusts #{Regexp.escape(trusted)}/, out, channel)

        if part
          edit("lib/dot_popper/#{part}/root.rb", "singleton_class.prepend(#{part.capitalize}Choices)", "")
        else
          edit("lib/dot_popper/composition/root.rb", "def self.receipt_trust(_settings) = Monetization::Receipt::NONE",
               "def self.receipt_trust(_settings) = Monetization::Receipt::NONE.with(product_id: 'another')")
        end
        ok, out = check_from_stamped_checkout(channel)

        refute ok, out
        assert_match(/^FAIL it trusts #{Regexp.escape(trusted)}/, out, channel)
      end
  end

  def lay_out_app
    FileUtils.rm_rf(@game)
    FileUtils.mkdir_p(@game)
    FileUtils.cp_r(%w[lib gems fledge.yml].map { File.join(ROOT, it) }, @game)
    # Every app leaves out the game's own gems' tests, signatures and
    # checks, as it leaves out the repository's (PackagedApp).
    PackagedApp::REPOSITORY_ONLY.grep(%r{\Agems/}).each { FileUtils.rm_rf(File.join(@game, it)) }
  end

  def check_from_stamped_checkout(channel)
    Dir.mktmpdir("dot_popper_checkout") do |checkout|
      FileUtils.cp_r(%w[lib gems script].map { File.join(ROOT, it) }, checkout)
      build = File.join(checkout, "lib/dot_popper/release_engineering/build.rb")
      File.write(build, BuildChannel.stamp(File.read(build), channel))
      out, status = Open3.capture2e(RbConfig.ruby, File.join(checkout, "script", "check_build.rb"), channel, @version, @app)
      [status.success?, out]
    end
  end

  # The check stands alone: what script/channel_contents.rb check finds
  # in a package fails it too, as does the test build's part loaded by a
  # build stamped for sale.
  def test_a_build_holding_what_its_channel_leaves_out_fails
    stamp("website")
    FileUtils.cp_r(File.join(ROOT, "lib/dot_popper/test_build"), File.join(@game, "lib/dot_popper/test_build"))
    FileUtils.cp_r(File.join(ROOT, "lib/dot_popper/play"), File.join(@game, "lib/dot_popper/play"))
    ok, out = check("website")

    refute ok, out
    assert_match(/FAIL it holds nothing a website build leaves out/, out)
    assert_match(%r{FAIL .* holds lib/dot_popper/test_build \(the test build's part\)}, out)
    assert_match(/^ok   it loads none of the test build's part$/, out)

    edit("lib/dot_popper/release_engineering/build.rb", "PARTS = %w[website].freeze", "PARTS = %w[play website test_build].freeze")
    ok, out = check("website")

    refute ok, out
    assert_match(/FAIL it loads none of the test build's part/, out)
    assert_match(/its Build::PARTS names play, test_build, which a website build does not carry/, out)
  end

  def test_a_build_naming_a_test_key_fails
    stamp("mac-app-store")
    File.write(File.join(@game, "gems/dot_popper-monetization/lib/dot_popper/monetization/store.rb"), "# Continuity::TestKeys\n", mode: "a")
    ok, out = check("mac-app-store")

    refute ok, out
    assert_match(%r{FAIL .* holds gems/dot_popper-monetization/lib/dot_popper/monetization/store\.rb, which names the test keys}, out)
  end

  def test_a_google_play_build_needs_the_play_key
    stamp("google-play")
    ok, out = check("google-play")

    assert_equal DotPopper::Monetization::Receipt::PLAY_KEYS.any?, ok, out
    assert_match(/it pins the app's Play key/, out)
  end
end
