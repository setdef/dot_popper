# frozen_string_literal: true

# Checks an app that was built, not this repository: loads the game's code
# from the unpacked app in FOLDER (its game/dot_popper folder, as
# `lota fuse` lays it out) and fails unless that code is a build for
# CHANNEL at VERSION, which trusts setdef's real keys and no test key
# (ADR-0010). The test build's proofs it is shown are made by this
# repository's code, in a Ruby of their own, so a build for sale need not
# carry the test keys to be shown that it refuses what they sign. It asks
# nothing of the internet. Only CHANNEL's own needs
# are checked: a website build needs no Play key or store identifier. It
# also runs script/channel_contents.rb's check on FOLDER, and fails if the
# app loads any of the test build's part, so it stands alone: a release
# that runs only this script still finds a file or a word the channel
# leaves out.
# The Package workflow runs it on every build for sale it makes, and
# Lota must be installed (the shell's code needs it to load).
#
#   ruby script/check_build.rb website 1.0.0 "unpacked/Dot Popper"
require "json"
require "open3"
require "rbconfig"
require "yaml"

channel, version, folder = ARGV
abort "usage: ruby script/check_build.rb CHANNEL VERSION FOLDER" unless channel && version && folder && File.directory?(folder)

games = Dir.glob(File.join(File.expand_path(folder), "**", "game", "dot_popper", "lib", "dot_popper", "release_engineering", "build.rb"))
           .map { File.expand_path("../../../..", it) }
abort "#{folder} holds #{games.size} copies of the game; expected one" unless games.size == 1
# Ruby records each file it loads by its real path, so the game's folder
# is compared by its real path too: a folder reached through a symbolic
# link (macOS's /var is /private/var) is still the app's own.
game = File.realpath(games.first)
puts "Checking the game in #{game}"

# The test build's proofs, made by this repository's code: the test
# build's own part and the website's, whose license keys its test keys
# sign, each loaded by name, since a checkout stamped for a channel
# (script/set_build_channel.rb) no longer loads the parts that channel
# leaves out. Each is checked there against the test build's own trust:
# the controls, so a Ruby that verifies nothing cannot pass the checks
# below.
MAKE_PROOFS = <<~RUBY
  require "json"
  require "dot_popper"
  require "dot_popper/website/core"
  require "dot_popper/test_build/core"
  c = DotPopper::Monetization::Continuity
  l = DotPopper::Monetization::LicenseKeys
  hex = ->(bytes) { bytes.unpack1("H*") }
  keys = %i[root license online].map { c::TestKeys.license_key(it).text }
  certificate = c::TestKeys.online_certificate
  receipt = DotPopper::Monetization::Receipt.issue
  controls = {
    "this Ruby verifies Ed25519" => c::Ed25519.available?,
    "a key signed by the test key unlocks a test build" => l::LicenseKey.parse(keys[1])&.valid?(l::TEST_SIGNING_KEYS) == true,
    "a test build takes a proof certified by the test root" =>
      !c::Certificate.verified(certificate, roots: c::TEST_PINS.roots, purpose: c::Certificate::PROOF).nil?,
    "the fake store's receipt proves Pro in a test build" => DotPopper::Monetization::Entitlement.new(trust: DotPopper::Monetization::Receipt::TEST).verify_receipt(receipt) == true
  }
  puts JSON.generate("roots" => c::TEST_PINS.roots.map(&hex), "license_keys" => l::TEST_SIGNING_KEYS.map(&hex),
                     "keys" => keys, "certificate" => hex.(certificate), "receipt" => receipt, "controls" => controls)
RUBY
made, status = Open3.capture2e(RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-e", MAKE_PROOFS)
abort "The repository could not make the test build's proofs:\n#{made}" unless status.success?
proofs = JSON.parse(made.lines.last)

# What the package holds, checked by this repository's script before the
# app's code is loaded here.
contents, status = Open3.capture2e(RbConfig.ruby, File.expand_path("channel_contents.rb", __dir__), "check", channel, folder)
contents_held = status.success?

$LOAD_PATH.unshift(File.join(game, "lib"))
require "dot_popper"
require "lota"
require "dot_popper/shell"

failures = []
check = lambda do |what, &passes|
  ok = begin
    passes.call
  rescue StandardError => e
    warn "  (#{e.class}: #{e.message})"
    false
  end
  puts "#{ok ? "ok  " : "FAIL"} #{what}"
  failures << what unless ok
end

# The game's code is lib/dot_popper.rb and what is under lib/dot_popper/;
# another folder named dot_popper (one holding Ruby itself, say) is not.
ours = $LOADED_FEATURES.grep(%r{/lib/dot_popper(/|\.rb\z)})
check.call("every file of the game's code loaded is the app's own") { ours.any? && ours.all? { it.start_with?(game) } }

build = DotPopper::ReleaseEngineering::Build
c = DotPopper::Monetization::Continuity
# What the app's own composition root chooses for a build of its channel,
# with no developer setting.
root = DotPopper::Composition::Root
settings = DotPopper::Composition::DeveloperSettings.new({})
check.call("it holds nothing a #{channel} build leaves out, and is stamped for it (script/channel_contents.rb check)") do
  contents.lines.grep(/^FAIL /).each { warn "  #{it.chomp}" }
  contents_held
end
check.call("it loads none of the test build's part") do
  $LOADED_FEATURES.none? { it.include?("/dot_popper/test_build/") } && !defined?(c::TestKeys) && !defined?(c::TEST_PINS) &&
    !defined?(DotPopper::Monetization::LicenseKeys::TEST_SIGNING_KEYS) &&
    !defined?(DotPopper::Monetization::FakeStore) && !DotPopper::Monetization::Receipt.const_defined?(:TEST, false)
end
check.call("#{channel.inspect} is a channel the game names (#{build::CHANNEL_NAMES.join(", ")})") { build::CHANNEL_NAMES.include?(channel) }
check.call("the app was built for #{channel.inspect} (Build::CHANNEL is #{build::CHANNEL.inspect})") { build::CHANNEL == channel }

pins = root.pins(settings)
signing_keys = root.license_signing_keys(settings)
website = build::PARTS.include?("website")
hex = ->(bytes) { bytes.unpack1("H*") }
check.call("it carries its channel's parts alone (Build::CHANNELS)") { build::PARTS == build::CHANNELS[channel]&.parts }
# Each store's receipt code is in a part of its own, which only its
# store's channel carries (Build::CHANNELS).
receipts = { "apple" => :Apple, "play" => :Play, "microsoft" => :Microsoft }
own = receipts.keys & (build::CHANNELS[channel]&.parts || [])
check.call("it loads no other store's receipt code (#{own.empty? ? "none" : own.join(", ")} alone)") do
  (receipts.keys - own).all? do |part|
    !DotPopper::Monetization::Receipt.const_defined?(receipts.fetch(part), false) && $LOADED_FEATURES.none? { it.include?("/dot_popper/#{part}/") }
  end
end
# And trusts its own store's receipts, or none where it sells through no
# store: a part whose root never answers for its channel would leave Pro
# unbuyable in its build.
check.call("it trusts #{own.one? ? "its store's receipts alone (#{own.first})" : "no store's receipts"} (Root.receipt_trust)") do
  trust = root.receipt_trust(settings)
  receipt = DotPopper::Monetization::Receipt
  own.one? ? trust.store == receipt.const_get(receipts.fetch(own.first), false) : own.empty? && trust == receipt::NONE
end
check.call("it loads the website's store and license keys only if it carries the website part") do
  website || (!defined?(DotPopper::Monetization::LicenseKeys) && !defined?(DotPopper::Monetization::WebsiteStore) &&
              $LOADED_FEATURES.none? { it.include?("/dot_popper/website/") } && signing_keys.empty?)
end
check.call("it trusts setdef's own keys (Continuity::SETDEF_PINS, LicenseKeys::SETDEF_SIGNING_KEYS)") do
  license_keys = DotPopper::Monetization::LicenseKeys if website
  pins.equal?(c::PINNED) && c::PINNED == c::SETDEF_PINS && c.live?(pins) &&
    (!website || (signing_keys.equal?(license_keys::SIGNING_KEYS) && license_keys::SIGNING_KEYS == license_keys::SETDEF_SIGNING_KEYS))
end
check.call("it trusts no test key") do
  (pins.roots.map(&hex) & proofs.fetch("roots")).empty? && (signing_keys.map(&hex) & proofs.fetch("license_keys")).empty?
end

# Each "grants nothing" below is shown against its control, checked by
# the repository's code: the same proof does grant in a test build.
proofs.fetch("controls").each { |what, held| check.call(what) { held } }
check.call("no license key signed by a test key unlocks it") do
  !defined?(DotPopper::Monetization::LicenseKeys::LicenseKey) || proofs.fetch("keys").none? { DotPopper::Monetization::LicenseKeys::LicenseKey.parse(it)&.valid?(signing_keys) }
end
check.call("it takes no proof certified by the test root") do
  c::Certificate.verified([proofs.fetch("certificate")].pack("H*"), roots: pins.roots, purpose: c::Certificate::PROOF).nil?
end
check.call("the fake store's receipt proves nothing in it") do
  !DotPopper::Monetization::Entitlement.new(trust: root.receipt_trust(settings)).verify_receipt(proofs.fetch("receipt"))
end
check.call("no setting grants Pro or changes the server in it") do
  env = build.settings({ "DOT_POPPER_PRO" => "1", "DOT_POPPER_SERVER" => "http://localhost:1" })
  !root.forced_pro?(DotPopper::Composition::DeveloperSettings.new(env), nil) && DotPopper::Network::Server.url(env) == DotPopper::Network::Server::SERVER_URL
end

shipped = YAML.load_file(File.join(game, "fledge.yml")).fetch("version").to_s
check.call("its version is #{version} (the app's fledge.yml says #{shipped})") { shipped == version }

# What only some channels need.
if channel == build::GOOGLE_PLAY
  check.call("it pins the app's Play key (Receipt::PLAY_KEYS)") { DotPopper::Monetization::Receipt::PLAY_KEYS.any? }
end
if channel == build::WEBSITE
  check.call("it keeps and checks a license key") { root.license_keys?(settings) }
end

if failures.any?
  warn "#{failures.size} check#{"s" unless failures.size == 1} failed: this app is not a #{channel} build of #{version}."
  exit 1
end
puts "This app is a #{channel} build of #{version}."
