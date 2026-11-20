# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# The version a release's builds carry (script/release_version.rb): before
# 1.0.0 a playtest tag names it and every build of the tag stamps it into
# its working tree; from 1.0.0 on it is committed, and a tag that
# disagrees with it fails.
class ReleaseVersionTest < Minitest::Test
  SCRIPT = File.expand_path("../script/release_version.rb", __dir__)
  ROOT = File.expand_path("..", __dir__)

  # Runs the script's stamp in a copy of the repository's fledge.yml and
  # doc/privacy.json whose version is +committed+, and answers its output,
  # whether it passed, and the two files after it.
  def stamp(ref, committed: "0.9.21")
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "doc"))
      File.write(File.join(dir, "fledge.yml"), with_version(fledge, committed))
      File.write(File.join(dir, "doc/privacy.json"), with_game_version(privacy, committed))
      out, err, status = Open3.capture3(RbConfig.ruby, SCRIPT, "stamp", ref, chdir: dir)
      [out.strip, err, status.success?, File.read(File.join(dir, "fledge.yml")), File.read(File.join(dir, "doc/privacy.json"))]
    end
  end

  def fledge = File.read(File.join(ROOT, "fledge.yml"))
  def privacy = File.read(File.join(ROOT, "doc/privacy.json"))
  def with_version(text, version) = text.sub(/^version: .*$/, "version: #{version.inspect}")
  def with_game_version(text, version) = text.sub(/^  "game_version": .*$/, %(  "game_version": "#{version}",))

  def test_a_playtest_tag_names_the_version_of_the_files_every_build_reads
    out, _, passed, yml, json = stamp("v0.9.22")
    assert passed
    assert_equal "0.9.22", out
    assert_equal with_version(fledge, "0.9.22"), yml, "only fledge.yml's version line changes"
    assert_equal with_game_version(privacy, "0.9.22"), json, "only the privacy document's version changes"
  end

  # What the privacy document is generated from must read the stamped
  # version as the document has it, so the tag's document is not stale.
  def test_the_stamped_files_agree_as_the_privacy_document_reads_them
    _, _, _, yml, json = stamp("v0.10.3")
    assert_equal "0.10.3", yml[/^version:\s*"([^"]+)"/, 1]
    assert_equal "0.10.3", JSON.parse(json).fetch("game_version")
  end

  # macOS's and Windows' version strings take only numbers.
  def test_a_release_candidate_builds_its_base_version
    out, _, passed, yml, = stamp("v0.9.22-rc.1")
    assert passed
    assert_equal "0.9.22", out
    assert_includes yml, %(version: "0.9.22")
  end

  def test_a_build_that_is_no_release_keeps_the_committed_version
    ["trunk", "", "v2", "vx.1.0"].each do |ref|
      out, _, passed, yml, json = stamp(ref)
      assert passed, ref.inspect
      assert_equal "0.9.21", out, ref.inspect
      assert_equal with_version(fledge, "0.9.21"), yml, ref.inspect
      assert_equal with_game_version(privacy, "0.9.21"), json, ref.inspect
    end
  end

  def test_a_playtest_tag_that_names_no_version_fails
    %w[v0.9 v0.9.x].each do |tag|
      _, err, passed, yml, = stamp(tag)
      refute passed, tag
      assert_includes err, tag
      assert_includes yml, %(version: "0.9.21"), "nothing is stamped for #{tag}"
    end
  end

  def test_from_1_0_0_on_the_committed_version_is_the_release
    %w[v1.0.0 v1.0.0-rc.1].each do |tag|
      out, _, passed, yml, = stamp(tag, committed: "1.0.0")
      assert passed, tag
      assert_equal "1.0.0", out, tag
      assert_equal with_version(fledge, "1.0.0"), yml, "#{tag} stamps nothing"
    end
  end

  def test_from_1_0_0_on_a_tag_that_disagrees_with_the_committed_version_fails
    _, err, passed, yml, = stamp("v1.0.0")
    refute passed
    assert_includes err, "v1.0.0"
    assert_includes err, "0.9.21"
    assert_includes yml, %(version: "0.9.21"), "and stamps nothing"
    refute stamp("v1.2.0", committed: "1.1.0")[2]
  end

  def test_a_file_with_no_version_line_to_stamp_fails
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "doc"))
      File.write(File.join(dir, "fledge.yml"), fledge)
      File.write(File.join(dir, "doc/privacy.json"), "{}\n")
      _, err, status = Open3.capture3(RbConfig.ruby, SCRIPT, "stamp", "v0.9.22", chdir: dir)
      refute status.success?
      assert_includes err, "game_version"
    end
  end
end
