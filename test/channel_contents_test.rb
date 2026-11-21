# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

# What a package holds that its channel does not need
# (script/channel_contents.rb), read from an app laid out here as
# `lota fuse` lays one out: the game's copy in game/dot_popper, beside
# files of Ruby's own.
class ChannelContentsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "script", "channel_contents.rb")
  require SCRIPT
  require_relative "../script/set_build_channel"
  require_relative "../script/packaged_app"

  def setup
    @app = Dir.mktmpdir("dot_popper_app")
    @game = File.join(@app, "Dot Popper", "app", "game", "dot_popper")
    lay_out_game
    # Ruby's own files may say anything; only the game's are read for Ruby's pieces.
    ruby = File.join(@app, "Dot Popper", "app", "ruby", "lib")
    FileUtils.mkdir_p(ruby)
    File.write(File.join(ruby, "openssl_doc.rb"), "# -----BEGIN PRIVATE KEY----- LicenseKey\n")
  end

  def teardown = FileUtils.rm_rf(@app)

  # The game's copy in the app: lib/ and the game's own gems, less what
  # every app leaves out of them (PackagedApp::REPOSITORY_ONLY).
  def lay_out_game
    FileUtils.rm_rf(@game)
    FileUtils.mkdir_p(@game)
    FileUtils.cp_r(%w[lib gems].map { File.join(ROOT, it) }, @game)
    PackagedApp::REPOSITORY_ONLY.grep(%r{\Agems/}).each { FileUtils.rm_rf(File.join(@game, it)) }
  end

  # Stamps the app's copy for +channel+ as script/set_build_channel.rb
  # stamps a build, and leaves out what that channel's build leaves out.
  def stamp(channel)
    build = File.join(@game, "lib/dot_popper/release_engineering/build.rb")
    File.write(build, BuildChannel.stamp(File.read(build), channel))
    ChannelContents.left_out(channel).each { FileUtils.rm_rf(File.join(@game, it)) }
  end

  def edit_build(from, to)
    build = File.join(@game, "lib/dot_popper/release_engineering/build.rb")
    source = File.binread(build)
    assert_includes source, from
    File.binwrite(build, source.sub(from, to))
  end

  def run_script(*args)
    out, status = Open3.capture2e(RbConfig.ruby, SCRIPT, *args)
    [status.success?, out]
  end

  def test_a_store_build_today_holds_the_fakes_test_keys_and_website_checkout
    ok, out = run_script("list", "mac-app-store", @app)

    assert ok, out
    assert_match %r{^the test build's part .*\n  file lib/dot_popper/test_build$}, out
    assert_match %r{  text lib/dot_popper/test_build/receipt_test_key\.rb: BEGIN PRIVATE KEY x1}, out
    assert_match %r{^the website checkout .*\n  file lib/dot_popper/website$}, out
    assert_match(/^the Microsoft Store's license /, out)
    refute_match(/^Apple's receipts/, out)
    refute_match(/openssl_doc/, out)
  end

  def test_a_test_build_needs_its_fakes_and_the_website_checkout
    ok, out = run_script("list", "test", @app)

    assert ok, out
    refute_match(/^the test build's part|^the fake store|^the test keys|^the website checkout|^license keys/, out)
    refute_match(/^Apple's receipts|^Google Play's receipts|^the Microsoft Store's license/, out)
    assert_match(/^StoreKit \(needed by app-store, mac-app-store\)/, out)
  end

  def test_a_build_for_sale_leaves_out_the_privacy_declarations_the_game_never_loads
    expected = %w[lib/dot_popper/privacy/declared.rb lib/dot_popper/privacy/document.rb lib/dot_popper/privacy/requests.rb]

    DotPopper::ReleaseEngineering::Build::CHANNEL_NAMES.each { assert_empty expected - ChannelContents.left_out(it), it }
    assert_empty ChannelContents.left_out("test")
    assert_includes run_script("excludes", "microsoft-store").last, "#{expected.join("\n")}\n"
    assert_equal "", run_script("excludes", "test").last
  end

  # The working copy's own channel, which the fuse action asks for, is a
  # test build's in the repository.
  def test_the_working_copy_leaves_nothing_out
    ok, out = run_script("excludes")

    assert ok, out
    assert_equal "", out
  end

  # The fuse action asks a checkout already stamped for the channel, as
  # CI's Package jobs stamp it, and leaves out what it answers.
  def test_a_checkout_stamped_for_a_channel_leaves_out_what_that_channel_does
    DotPopper::ReleaseEngineering::Build::CHANNEL_NAMES.each do |channel|
      Dir.mktmpdir("dot_popper_checkout") do |checkout|
        FileUtils.cp_r(%w[lib script].map { File.join(ROOT, it) }, checkout)
        build = File.join(checkout, "lib/dot_popper/release_engineering/build.rb")
        File.write(build, BuildChannel.stamp(File.read(build), channel))
        out, status = Open3.capture2e(RbConfig.ruby, File.join(checkout, "script", "channel_contents.rb"), "excludes")

        assert status.success?, out
        assert_equal ChannelContents.left_out(channel), out.lines(chomp: true), channel
      end
    end
  end

  # Each channel's build, stamped as script/set_build_channel.rb stamps it
  # and loaded as the app loads it (main.rb loads the shell), loads none
  # of what that channel leaves out.
  def test_no_build_for_sale_loads_what_it_leaves_out
    DotPopper::ReleaseEngineering::Build::CHANNEL_NAMES.each do |channel|
      lay_out_game
      build = File.join(@game, "lib/dot_popper/release_engineering/build.rb")
      File.write(build, BuildChannel.stamp(File.read(build), channel))
      ChannelContents.left_out(channel).each { FileUtils.rm_rf(File.join(@game, it)) }
      load = 'require "lota"; require "dot_popper"; require "dot_popper/shell"; puts DotPopper::ReleaseEngineering::Build::CHANNEL'
      out, status = Open3.capture2e(CopyRuby::ENV_WITHOUT_BUNDLER, RbConfig.ruby, *CopyRuby.arguments(@game), "-e", load)
      skip "Lota isn't installed here (#{out.lines.first})" if !status.success? && out.include?("lota (LoadError)")

      assert status.success?, "#{channel}: #{out}"
      assert_equal channel, out.lines.last.chomp
    end
  end

  def test_every_left_out_file_is_in_the_repository
    ChannelContents::PIECES.select(&:apart).flat_map(&:files).each { assert_path_exists File.join(ROOT, it) }
  end

  def test_check_fails_when_a_left_out_file_comes_back
    ok, out = run_script("check", "mac-app-store", @app)

    refute ok, out
    assert_match %r{FAIL .* holds lib/dot_popper/privacy/declared\.rb \(privacy declarations the game never loads\), which a mac-app-store build leaves out}, out

    stamp("mac-app-store")
    ok, out = run_script("check", "mac-app-store", @app)

    assert ok, out
  end

  # The check stands alone: a package of the right files whose build.rb
  # is not its channel's fails it too, as check_build.rb would fail it.
  def test_check_fails_when_the_package_is_not_stamped_for_its_channel
    ChannelContents.left_out("website").each { FileUtils.rm_rf(File.join(@game, it)) }
    ok, out = run_script("check", "website", @app)

    refute ok, out
    assert_match(/FAIL .* is not stamped for website: its Build::CHANNEL is nil, where a website build's is "website"/, out)
    assert_match(/FAIL .* is not stamped for website: its Build::PARTS names apple, play, microsoft, test_build, which a website build does not carry/, out)

    stamp("microsoft-store")
    ok, out = run_script("check", "website", @app)

    refute ok, out
    assert_match(/its Build::CHANNEL is "microsoft-store", where a website build's is "website"/, out)
  end

  # An app store's build holds no license key and no website checkout:
  # the website's part is left out of it, and its check fails if the
  # part's files are there.
  def test_check_fails_when_an_app_store_build_holds_the_website_part
    stamp("app-store")
    ok, out = run_script("check", "app-store", @app)

    assert ok, out
    refute_path_exists File.join(@game, "lib/dot_popper/website")

    FileUtils.cp_r(File.join(ROOT, "lib/dot_popper/website"), File.join(@game, "lib/dot_popper/website"))
    ok, out = run_script("check", "app-store", @app)

    refute ok, out
    assert_match(%r{FAIL .* holds lib/dot_popper/website \(the website checkout\)}, out)
    assert_match(%r{FAIL .* holds lib/dot_popper/website/license_keys}, out)
  end

  # A copy of one of the part's files at another path fails the check
  # too, loaded or not: only the part's own files define its classes.
  def test_check_fails_when_an_app_store_build_holds_a_copy_of_a_website_file_elsewhere
    stamp("app-store")
    stray = File.join(@game, "lib/dot_popper/monetization/stray.rb")
    Dir.glob("lib/dot_popper/website/{website_store.rb,offer.rb,license_keys.rb,license_keys/*.rb}", base: ROOT).each do |file|
      FileUtils.cp(File.join(ROOT, file), stray)
      ok, out = run_script("check", "app-store", @app)

      refute ok, "#{file}:\n#{out}"
      assert_match(%r{FAIL .* holds lib/dot_popper/monetization/stray\.rb, which names (the website checkout|license keys)}, out)
    end
  end

  # The offer asks the second action the build's store comes with, so no
  # shared file names the website's store or says the website's words: an
  # app store's package whose shared code names the store, or says "Paste
  # license key" or that a key comes by email, anywhere, fails.
  def test_check_fails_when_an_app_store_builds_shared_code_names_the_website_store_or_its_words
    stamp("app-store")
    show = File.join(@game, "lib/dot_popper/presentation/show.rb")
    original = File.read(show)
    { "# the WebsiteStore" => "the website checkout", 'X = "Paste license key"' => "license keys",
      'X = "Your key comes by email."' => "license keys" }.each do |line, piece|
      File.write(show, "#{original}#{line}\n")
      ok, out = run_script("check", "app-store", @app)

      refute ok, "#{line}:\n#{out}"
      assert_match(%r{FAIL .* holds lib/dot_popper/presentation/show\.rb, which names #{piece}}, out)
    end
  end

  # Each store's receipt code is a part only its own store's build
  # carries: an app store's package holding another store's, at its own
  # place or copied anywhere, fails.
  def test_check_fails_when_an_app_store_build_holds_another_stores_receipts
    stamp("app-store")
    { "play" => "Google Play's receipts", "microsoft" => "the Microsoft Store's license" }.each do |part, piece|
      FileUtils.cp_r(File.join(ROOT, "lib/dot_popper", part), File.join(@game, "lib/dot_popper", part))
      ok, out = run_script("check", "app-store", @app)

      refute ok, out
      assert_match(%r{FAIL .* holds lib/dot_popper/#{part} \(#{piece}\)}, out)

      FileUtils.rm_rf(File.join(@game, "lib/dot_popper", part))
      FileUtils.cp(File.join(ROOT, "lib/dot_popper", part, "receipt.rb"), File.join(@game, "lib/dot_popper/monetization/stray.rb"))
      ok, out = run_script("check", "app-store", @app)

      refute ok, out
      assert_match(%r{FAIL .* holds lib/dot_popper/monetization/stray\.rb, which names #{piece}}, out)
      FileUtils.rm_f(File.join(@game, "lib/dot_popper/monetization/stray.rb"))
    end
  end

  def test_check_fails_when_a_build_for_sale_names_the_test_builds_part
    stamp("app-store")
    edit_build("PARTS = %w[apple].freeze", "PARTS = %w[apple test_build].freeze")
    ok, out = run_script("check", "app-store", @app)

    refute ok, out
    assert_match(/its Build::PARTS names test_build, which a app-store build does not carry/, out)
  end

  # A test build is the repository's own build.rb, part and all.
  def test_a_test_build_passes_the_check_as_it_is
    ok, out = run_script("check", "test", @app)

    assert ok, out
  end

  # A build for sale holds no word of what it leaves out whole: a test
  # key's name in a file it carries fails the check.
  def test_check_fails_when_a_build_for_sale_names_a_test_key
    stamp("website")
    ok, out = run_script("check", "website", @app)

    assert ok, out
    File.write(File.join(@game, "lib/dot_popper/stray.rb"), "# Continuity::TestKeys::LICENSE\n")
    ok, out = run_script("check", "website", @app)

    refute ok, out
    assert_match %r{FAIL .* holds lib/dot_popper/stray\.rb, which names the test keys \(TestKeys\?\)}, out
  end

  # A build for sale verifies and signs nothing: the code that issues
  # license keys and certificates and signs is the test build's part's.
  def test_a_build_for_sale_holds_no_signing_code
    ChannelContents.left_out("website").each { FileUtils.rm_rf(File.join(@game, it)) }
    _, out = run_script("list", "website", @app)

    refute_match(/^signing/, out)
    File.write(File.join(@game, "lib/dot_popper/website/license_keys/license_key.rb"), "def self.issue(seed) = Ed25519.sign(seed, LABEL)\n", mode: "a")
    _, out = run_script("check", "website", @app)

    assert_match(%r{FAIL .* holds lib/dot_popper/website/license_keys/license_key\.rb, which names signing}, out)
  end

  # Nor any prose about the test build, which has other ways to Pro.
  def test_a_build_for_sale_says_nothing_of_the_test_build
    ChannelContents.left_out("app-store").each { FileUtils.rm_rf(File.join(@game, it)) }
    _, out = run_script("list", "app-store", @app)

    refute_match(/^words about the test build/, out)
    File.write(File.join(@game, "lib/dot_popper/monetization/entitlement.rb"), "# A test build has a setting of its own.\n", mode: "a")
    _, out = run_script("check", "app-store", @app)

    assert_match(%r{FAIL .* holds lib/dot_popper/monetization/entitlement\.rb, which names words about the test build}, out)
  end

  def test_an_unknown_channel_or_a_missing_folder_is_refused
    refute run_script("list", "steam", @app).first
    refute run_script("list", "website", File.join(@app, "nowhere")).first
    refute run_script("excludes", "steam").first
  end
end
