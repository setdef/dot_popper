# frozen_string_literal: true

# The version a build carries, decided from the ref CI builds
# (GITHUB_REF_NAME), in the working tree it is run in (the repository's
# top). Every job a tag starts that builds an app or reads the version
# runs it first, and it prints the version:
#
#   ruby script/release_version.rb stamp v0.9.22   # => 0.9.22
#
# - A playtest tag (script/release_kind.rb; until 1.0.0, every v0.*)
#   names the version: its number, or a release candidate's base number
#   (v0.9.22-rc.1 builds 0.9.22; Playtest::BuildVersion says why). It is
#   stamped into fledge.yml's version line and doc/privacy.json's
#   game_version, in this working tree only, and never committed. A
#   playtest tag that names no X.Y.Z fails.
# - A website tag (v1.0.0 on) does not: from 1.0.0 the version is
#   committed in the tagged commit, and this fails, stamping nothing,
#   unless fledge.yml's version is the tag's number.
# - Any other ref (a push to trunk, a branch) keeps fledge.yml's version,
#   which before 1.0.0 is only what a build that is not a release carries.

require "yaml"
require_relative "release_kind"
require_relative "../playtest/kit"

module ReleaseVersion
  FLEDGE = "fledge.yml"
  PRIVACY = "doc/privacy.json"
  VERSION_LINE = /^version: .*$/
  GAME_VERSION_LINE = /^  "game_version": .*$/

  # The version +ref+ builds, after stamping it where a playtest tag
  # needs it. Raises with what to do when the tag and the files disagree.
  def self.stamp(ref)
    committed = YAML.safe_load_file(FLEDGE).fetch("version").to_s
    version = Playtest::BuildVersion.of(ref, fallback: committed)
    case release_kind(ref)
    when "playtest"
      raise ArgumentError, "#{ref} is a playtest tag, but names no version X.Y.Z (v0.9.22, or v0.9.22-rc.1)" unless version.tag?

      write(FLEDGE, VERSION_LINE, "version: #{version.app.inspect}")
      write(PRIVACY, GAME_VERSION_LINE, %(  "game_version": "#{version.app}",))
    when "website"
      unless version.app == committed
        raise ArgumentError, "#{ref} releases #{version.app}, but #{FLEDGE} says #{committed}: from 1.0.0 on, " \
                             "the tagged commit carries its version (#{FLEDGE} and #{PRIVACY})"
      end
    end
    version.app
  end

  def self.write(path, line, replacement)
    text = File.read(path)
    raise ArgumentError, "#{path} has no line #{line.source} to stamp" unless text.match?(line)

    File.write(path, text.sub(line, replacement))
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV
  in ["stamp", ref]
    begin
      puts ReleaseVersion.stamp(ref)
    rescue ArgumentError => e
      abort "release_version.rb: #{e.message}"
    end
  else
    abort "usage: ruby script/release_version.rb stamp REF"
  end
end
