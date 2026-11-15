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
# receipts it trusts, with no developer setting and with every one.
class BuildForSaleTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  B = DotPopper::Build
  C = DotPopper::Continuity
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
    c = DotPopper::Continuity
    answers = { "channel" => DotPopper::Build::CHANNEL, "parts" => DotPopper::Build::PARTS,
                "part loaded" => $LOADED_FEATURES.grep(%r{/test_build/}),
                "pins are setdef's" => c.pins_for(DotPopper::Build::CHANNEL).equal?(c::PINNED) && c::PINNED == c::SETDEF_PINS,
                "builds" => [] }
    #{SYSTEMS.inspect}.product({ "no setting" => {}, "every setting" => JSON.parse(every) }.to_a).each do |system, (label, env)|
      engine = FakeEngine.new(system)
      root = DotPopper::Composition::Root.new(engine:, settings: DotPopper::Composition::DeveloperSettings.new(env))
      settings = root.settings
      built = { "system" => system, "settings" => label, "offered" => root.storefront.offered?,
                "games" => root.show.games_line, "pro" => root.entitlement.pro?,
                "themes.txt" => engine.file("themes.txt").read.to_s, "theme" => root.pen.theme&.key.to_s,
                "today" => settings.today.call.to_s, "date" => Date.today.to_s,
                "utc clock off by" => (settings.utc_clock.call - Time.now.utc).abs.round }
      root.entitlement.prove(receipt)
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
    @proofs ||= [DotPopper::Receipt.issue, C::LicenseKey.issue(C::TestKeys::LICENSE).text]
  end

  # What +channel+'s build answers, built from a copy of lib/ stamped as
  # the release stamps it and without what the channel leaves out.
  def self.answers(channel)
    Dir.mktmpdir("dot_popper_#{channel}") do |dir|
      FileUtils.cp_r(File.join(ROOT, "lib"), dir)
      build = File.join(dir, "lib/dot_popper/build.rb")
      File.binwrite(build, BuildChannel.stamp(File.binread(build), channel))
      ChannelContents.left_out(channel).each { FileUtils.rm_rf(File.join(dir, it)) }
      out, status = Open3.capture2e(RbConfig.ruby, "-I", File.join(dir, "lib"), "-I", File.join(ROOT, "test"), "-e", PROBE,
                                    "--", *proofs, JSON.generate(EVERY_SETTING))
      raise "#{channel}'s build did not answer:\n#{out}" unless status.success?

      JSON.parse(out.lines.last)
    end
  end

  # Every channel's answers, made once for all the tests below, each
  # channel's Ruby beside the others'.
  def self.all_answers
    @all_answers ||= B::CHANNEL_NAMES.map { |channel| Thread.new { [channel, answers(channel)] } }.to_h(&:value)
  end

  def all_answers = self.class.all_answers

  def each_build
    all_answers.each do |channel, answers|
      answers.fetch("builds").each { yield channel, it, "#{channel} on #{it["system"]}, #{it["settings"]}" }
    end
  end

  def test_each_build_for_sale_is_built_without_the_test_builds_part
    all_answers.each do |channel, answers|
      assert_equal channel, answers["channel"]
      assert_empty answers["parts"], channel
      assert_empty answers["part loaded"], channel
      assert answers["pins are setdef's"], channel
    end
  end

  def test_a_new_player_of_a_build_for_sale_has_the_first_free_games_and_no_more
    first = DotPopper::FreeGames::FIRST_GAMES + DotPopper::FreeGames::DAILY
    each_build do |_, built, where|
      next assert_nil built["games"], where unless built["offered"]

      assert_equal "#{first} games left", built["games"], where
    end
    B::CHANNEL_NAMES.each do |channel|
      assert all_answers[channel]["builds"].any? { it["offered"] }, "#{channel} sells Pro on no system"
    end
  end

  def test_a_build_for_sale_releases_no_theme_and_uses_the_ordinary_one
    each_build do |_, built, where|
      assert_equal "", built["themes.txt"], where
      assert_equal DotPopper::Theme::ORDINARY.to_s, built["theme"], where
    end
  end

  def test_a_build_for_sale_plays_on_todays_date
    each_build do |_, built, where|
      assert_equal built["date"], built["today"], where
      assert_operator built["utc clock off by"], :<=, 60, where
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
