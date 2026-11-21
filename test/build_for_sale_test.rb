# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"
require_relative "../script/set_build_channel"
require_relative "../script/channel_contents"

# What each build for sale answers as it is built: the game put together
# (Composition::Root, with the fake engine) from a copy of lib/ stamped
# for the channel by script/set_build_channel.rb, with what that channel
# leaves out removed, in a Ruby of its own. Every other test loads the
# test build's part, whose answers stand in front of the shared code's,
# so this is where the shared code's own answers for a build for sale
# are tested: the free games, the themes, the date, the keys and the
# receipts it trusts, with no developer setting and with every one. And
# a build for sale that loads the test build's part by mistake still
# answers so: the part gives way to the shared answers for a channel.
class BuildForSaleTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  B = DotPopper::ReleaseEngineering::Build
  C = DotPopper::Monetization::Continuity
  SYSTEMS = ["iOS", "Android", "OS X", "Windows", "Linux"].freeze
  # Every developer setting that could change what a player has.
  EVERY_SETTING = {
    "DOT_POPPER_PRO" => "1", "DOT_POPPER_FREE_GAMES" => "5", "DOT_POPPER_TODAY" => "2031-01-01",
    "DOT_POPPER_THEME_UNLOCKS" => "ghost,turkey", "DOT_POPPER_THEME" => "ghost", "DOT_POPPER_SCENARIO" => "game",
    "DOT_POPPER_AUTOPLAY" => "1", "DOT_POPPER_FAKE_SETDEF" => "gone", "DOT_POPPER_FAKE_STORE_FAILS" => "refused"
  }.freeze

  # Builds the game on every system, with no setting and with every one,
  # and prints, as JSON, what each answers. A test-signed receipt and
  # license key, made by the repository's test build, come as arguments.
  PROBE = <<~RUBY
    require "json"
    require "composition/fake_engine"
    receipt, key, every = ARGV
    c = DotPopper::Monetization::Continuity
    l = (DotPopper::Monetization::LicenseKeys if defined?(DotPopper::Monetization::LicenseKeys))
    signing = DotPopper::Composition::Root.license_signing_keys(DotPopper::Composition::DeveloperSettings.new)
    answers = { "channel" => DotPopper::ReleaseEngineering::Build::CHANNEL, "parts" => DotPopper::ReleaseEngineering::Build::PARTS,
                "part loaded" => $LOADED_FEATURES.grep(%r{/test_build/}),
                "website part loaded" => $LOADED_FEATURES.grep(%r{/dot_popper/website/}).any? || !l.nil?,
                "pins are setdef's" => DotPopper::Composition::Root.pins(DotPopper::Composition::DeveloperSettings.new).equal?(c::PINNED) && c::PINNED == c::SETDEF_PINS &&
                  (l ? signing.equal?(l::SIGNING_KEYS) && l::SIGNING_KEYS == l::SETDEF_SIGNING_KEYS : signing.empty?),
                "builds" => [] }
    #{SYSTEMS.inspect}.product({ "no setting" => {}, "every setting" => JSON.parse(every) }.to_a).each do |system, (label, env)|
      engine = FakeEngine.new(system)
      root = DotPopper::Composition::Root.new(engine:, settings: DotPopper::Composition::DeveloperSettings.new(env))
      settings = root.settings
      built = { "system" => system, "settings" => label, "offered" => root.store.offered?,
                "games" => root.show.games_line, "pro" => root.entitlement.pro?,
                "themes.txt" => engine.file("themes.txt").read.to_s, "theme" => root.context.theme&.key.to_s,
                "today" => settings.today.call.to_s, "date" => Date.today.to_s,
                "utc now off by" => (settings.utc_now.call - Time.now.utc).abs.round,
                "takes license keys" => DotPopper::Composition::Root.license_keys?(settings) }
      root.entitlement.verify_receipt(receipt)
      built["pro after a test receipt"] = root.entitlement.pro?
      root.entitlement.enter(key)
      built["pro after a test key"] = root.entitlement.pro?
      answers["builds"] << built
    end
    puts JSON.generate(answers)
    $stdout.flush
    exit!(0)
  RUBY

  def self.proofs
    @proofs ||= [DotPopper::Monetization::Receipt.issue, C::TestKeys.license_key.text]
  end

  # How each build is made: as the release makes it, or with the test
  # build's part loaded by mistake (stamped, but the part named in
  # Build::PARTS, with the website's part it needs, and their folders
  # kept) and the filter on developer
  # settings letting every one through, so only the part's own deference
  # to the shared answers keeps it out.
  KINDS = {
    "as the release makes it" => :right,
    "with the test build's part loaded by mistake and every setting let through" => :mistaken
  }.freeze

  # What +channel+'s build of +kind+ answers, built from a copy of lib/
  # stamped as the release stamps it.
  def self.answers(channel, kind)
    Dir.mktmpdir("dot_popper_#{channel}") do |dir|
      FileUtils.cp_r(File.join(ROOT, "lib"), dir)
      build = File.join(dir, "lib/dot_popper/release_engineering/build.rb")
      source = BuildChannel.stamp(File.read(build), channel)
      if kind == :mistaken
        source = source.sub(/PARTS = %w\[[a-z_ ]*\]/, "PARTS = %w[website test_build]")
                       .sub("HARMLESS = %w[", "HARMLESS = %w[#{EVERY_SETTING.keys.map { it.delete_prefix(B::PREFIX) }.join(" ")} ")
      else
        ChannelContents.left_out(channel).each { FileUtils.rm_rf(File.join(dir, it)) }
      end
      File.write(build, source)
      out, status = Open3.capture2e(RbConfig.ruby, "-I", File.join(dir, "lib"), "-I", File.join(ROOT, "test"), "-e", PROBE,
                                    "--", *proofs, JSON.generate(EVERY_SETTING))
      raise "#{channel}'s build #{KINDS.key(kind)} did not answer:\n#{out}" unless status.success?

      JSON.parse(out.lines.last)
    end
  end

  # Every channel's answers, made once for all the tests below, each
  # build's Ruby beside the others'.
  def self.all_answers
    @all_answers ||= B::CHANNEL_NAMES.product(KINDS.values).map do |channel, kind|
      Thread.new { [[channel, kind], answers(channel, kind)] }
    end.to_h(&:value)
  end

  def all_answers = self.class.all_answers

  def each_build
    all_answers.each do |(channel, kind), answers|
      answers.fetch("builds").each { yield channel, it, "#{channel} #{KINDS.key(kind)}, on #{it["system"]}, #{it["settings"]}" }
    end
  end

  def test_each_build_for_sale_is_built_without_the_test_builds_part
    B::CHANNEL_NAMES.each do |channel|
      answers = all_answers[[channel, :right]]
      assert_equal channel, answers["channel"]
      assert_equal B::CHANNELS.fetch(channel).parts, answers["parts"], channel
      refute_includes answers["parts"], "test_build", channel
      assert_empty answers["part loaded"], channel
      assert answers["pins are setdef's"], channel
      mistaken = all_answers[[channel, :mistaken]]
      refute_empty mistaken["part loaded"], "#{channel}: the part was to be loaded by mistake"
      assert mistaken["pins are setdef's"], channel
    end
  end

  def test_a_new_player_of_a_build_for_sale_has_the_first_free_games_and_no_more
    first = DotPopper::Monetization::FreeGames::FIRST_GAMES + DotPopper::Monetization::FreeGames::DAILY
    each_build do |_, built, where|
      next assert_nil built["games"], where unless built["offered"]

      assert_equal "#{first} games left", built["games"], where
    end
    B::CHANNEL_NAMES.each do |channel|
      assert all_answers[[channel, :right]]["builds"].any? { it["offered"] }, "#{channel} sells Pro on no system"
    end
  end

  # Only the website's build keeps and checks a license key; an app
  # store's never reads license.txt.
  def test_only_the_website_build_takes_license_keys
    each_build { |channel, built, where| assert_equal channel == B::WEBSITE, built["takes license keys"], where }
  end

  # Only the website's build carries the website's part: an app store's
  # holds no license key and no website checkout, and loads neither.
  def test_only_the_website_build_carries_the_website_part
    B::CHANNEL_NAMES.each do |channel|
      assert_equal channel == B::WEBSITE, all_answers[[channel, :right]]["website part loaded"], channel
    end
  end

  def test_a_build_for_sale_releases_no_theme_and_uses_the_ordinary_one
    each_build do |_, built, where|
      assert_equal "", built["themes.txt"], where
      assert_equal DotPopper::Gameplay::Theme::ORDINARY.to_s, built["theme"], where
    end
  end

  def test_a_build_for_sale_plays_on_todays_date
    each_build do |_, built, where|
      assert_equal built["date"], built["today"], where
      assert_operator built["utc now off by"], :<=, 60, where
    end
  end

  def test_nothing_the_test_build_signs_or_sets_grants_pro_in_a_build_for_sale
    each_build do |_, built, where|
      refute built["pro"], where
      refute built["pro after a test receipt"], where
      refute built["pro after a test key"], where
    end
  end
end
