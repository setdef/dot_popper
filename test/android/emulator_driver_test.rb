# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"

# .github/android_emulator.rb, the driver of each Android emulator check,
# against a stand-in for adb. What the device prints is bytes, and its
# log is not always UTF-8: a check once failed with "invalid byte
# sequence in UTF-8" as the driver read back the log it had kept, though
# the game had done everything asked of it.
class EmulatorDriverTest < Minitest::Test
  DRIVER = File.expand_path("../../.github/android_emulator.rb", __dir__)
  PACKAGE = "com.example.game"

  # adb as the driver asks it, answering from a device whose app and log
  # print a byte that is not UTF-8 among their lines.
  FAKE_ADB = <<~'SH'
    #!/bin/sh
    broken() { printf 'caf\351 \377\n'; }
    case "$*" in
      "shell wm size") echo "Physical size: 320x640" ;;
      install*) echo Success ;;
      "logcat -v raw"* | "logcat -d -v raw"*) broken; echo ready; echo "Dot Popper exited with status 0" ;;
      "logcat -d -b"*) printf '11-14 19:56:42.617  2728  5094 W libc    : '; broken ;;
    esac
  SH

  def setup
    skip "the Android checks run on Linux and macOS" if Gem.win_platform?
    @folder = Dir.mktmpdir("emulator-driver")
    @bin = File.join(@folder, "bin")
    FileUtils.mkdir_p(@bin)
    File.binwrite(File.join(@bin, "adb"), FAKE_ADB)
    File.chmod(0o755, File.join(@bin, "adb"))
  end

  def teardown
    FileUtils.rm_rf(@folder) if @folder
  end

  def test_a_device_that_prints_bytes_that_are_not_utf_8_still_passes_its_checks
    out = File.join(@folder, "out")
    # No Bundler, which the driver and adb have none of on the machine.
    env = ENV.keys.grep(/\A(BUNDLE_|RUBY)/).to_h { [it, nil] }
    env["PATH"] = [@bin, ENV.fetch("PATH")].join(File::PATH_SEPARATOR)
    said, status = Open3.capture2e(env, RbConfig.ruby, DRIVER, "app.apk", PACKAGE, out, "--ready", "ready",
                                   "--timeout", "30", "--expect", "exited with status 0")

    assert_predicate status, :success?, said
    assert_includes File.read(File.join(out, "app.txt")), "Dot Popper exited with status 0"
    assert_includes File.read(File.join(out, "logcat.txt")), "libc"
  end
end
