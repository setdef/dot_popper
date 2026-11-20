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

  # adb as the driver asks it, answering from a device whose game raised:
  # Lota prints the error and shows its screen, and the app stays.
  RAISED_ADB = <<~'SH'
    #!/bin/sh
    case "$*" in
      "shell wm size") echo "Physical size: 320x640" ;;
      "shell pidof"*) echo 1234 ;;
      install*) echo Success ;;
      "logcat -v raw"*) printf 'ready\nError: lib/dot_popper/gameplay/game_flow.rb:186: a fault\nstack traceback:\n'; exec sleep 600 ;;
      "logcat -d -v raw"*) printf 'ready\nError: lib/dot_popper/gameplay/game_flow.rb:186: a fault\nstack traceback:\n' ;;
    esac
  SH

  # adb as the driver asks it, answering from a device where every
  # expected line was printed before Android logged the app's crash.
  CRASHED_ADB = <<~'SH'
    #!/bin/sh
    case "$*" in
      "shell wm size") echo "Physical size: 320x640" ;;
      "shell pidof"*) echo 1234 ;;
      install*) echo Success ;;
      "logcat -v raw"* | "logcat -d -v raw"*) echo ready; echo "kit probe: event HomeShown" ;;
      "logcat -d -b"*) echo "11-14 19:56:42.617  2728  5094 I am_crash: [1234,0,com.example.game,947404358,Native crash,Aborted,unknown,0]" ;;
    esac
  SH

  def setup
    skip "the Android checks run on Linux and macOS" if Gem.win_platform?
    @folder = Dir.mktmpdir("emulator-driver")
    @bin = File.join(@folder, "bin")
    FileUtils.mkdir_p(@bin)
    adb(FAKE_ADB)
  end

  def teardown
    FileUtils.rm_rf(@folder) if @folder
  end

  def test_a_device_that_prints_bytes_that_are_not_utf_8_still_passes_its_checks
    out = File.join(@folder, "out")
    said, status = drive(out, "--ready", "ready", "--timeout", "30", "--expect", "exited with status 0")

    assert_predicate status, :success?, said
    assert_includes File.read(File.join(out, "app.txt")), "Dot Popper exited with status 0"
    assert_includes File.read(File.join(out, "logcat.txt")), "libc"
  end

  def test_a_game_that_raises_fails_its_check_at_once
    adb(RAISED_ADB)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    said, status = drive(File.join(@folder, "out"), "--ready", "ready", "--timeout", "120", "--expect", "ready")

    refute_predicate status, :success?, said
    assert_includes said, "the game raised:\nError: lib/dot_popper/gameplay/game_flow.rb:186: a fault"
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 30, said
  end

  def test_a_crash_android_logs_fails_a_check_whose_lines_were_all_met
    adb(CRASHED_ADB)
    said, status = drive(File.join(@folder, "out"), "--ready", "ready", "--timeout", "30", "--until-met",
                         "--expect-order", "kit probe: event HomeShown")

    refute_predicate status, :success?, said
    assert_includes said, "every expectation met"
    assert_includes said, "the app crashed:"
  end

  private

  def adb(script)
    File.binwrite(File.join(@bin, "adb"), script)
    File.chmod(0o755, File.join(@bin, "adb"))
  end

  def drive(out, *options)
    # No Bundler, which the driver and adb have none of on the machine.
    env = ENV.keys.grep(/\A(BUNDLE_|RUBY)/).to_h { [it, nil] }
    env["PATH"] = [@bin, ENV.fetch("PATH")].join(File::PATH_SEPARATOR)
    Open3.capture2e(env, RbConfig.ruby, DRIVER, "app.apk", PACKAGE, out, *options)
  end
end
