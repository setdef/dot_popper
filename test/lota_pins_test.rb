# frozen_string_literal: true

require_relative "test_helper"
require "bundler"
require "open3"
require "tmpdir"

# The Lota and Fledge the phone builds take by default
# (script/lota_pins.sh) are the ones Gemfile.lock pins, so an upgrade
# moves them with the lockfile.
class LotaPinsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "script/lota_pins.sh")

  def pins(lock = File.join(ROOT, "Gemfile.lock"))
    out, err, status = Open3.capture3("bash", SCRIPT, lock)
    [out.lines(chomp: true), err, status]
  end

  def test_the_pins_are_the_lockfiles_lota_and_fledge
    locked = Bundler::LockfileParser.new(File.binread(File.join(ROOT, "Gemfile.lock")))
    lota = locked.specs.select { it.name == "lota" }.map { it.version.to_s }.uniq
    fledge = locked.sources.find { it.is_a?(Bundler::Source::Git) && it.uri.end_with?("/Fledge") }
    lines, err, status = pins
    assert status.success?, err
    assert_equal ["LOTA_REF=v#{lota.fetch(0)}", "FLEDGE_TAG=#{fledge.options.fetch('tag')}"], lines
  end

  def test_a_lockfile_without_a_tagged_fledge_or_one_lota_is_refused
    Dir.mktmpdir do |dir|
      lock = File.join(dir, "Gemfile.lock")
      File.binwrite(lock, "GEM\n  remote: https://rubygems.org/\n  specs:\n    lota (0.3.1-x86_64-linux-gnu)\n")
      _, err, status = pins(lock)
      refute status.success?
      assert_match(/no single tagged Fledge/, err)

      File.binwrite(lock, "GEM\n  specs:\n    lota (0.3.1-arm64-darwin)\n    lota (0.5.2-x86_64-linux-gnu)\n")
      _, err, status = pins(lock)
      refute status.success?
      assert_match(/no single Lota version/, err)
    end
  end
end
