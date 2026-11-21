# frozen_string_literal: true

# What a packaged app holds of the game, laid out as `lota fuse` lays it
# out (PACKAGING.md, What goes into the app), and a check that the game
# starts from only that, with no Bundler and no gem but Lota, short of
# opening a window (PackagedApp::START). test/packaged_app_test.rb runs
# the check in `rake test`, so a file the app would not hold, or a library
# it would not have, fails there rather than in a built app.
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "channel_contents"

module PackagedApp
  ROOT = File.expand_path("..", __dir__)

  # The repository's own files, which every app leaves out: the fuse
  # action (.github/actions/fuse/action.yml) passes each to
  # `lota fuse --exclude`, and test/packaged_app_test.rb holds its list to
  # this one.
  REPOSITORY_ONLY = %w[test doc sig script playtest android ios macos windows .github Rakefile Steepfile
                       mise.toml mise.lock mise.android.toml mise.ios.toml
                       AGENTS.md GLOSSARY.md INSIPIRATION.md PACKAGING.md README.md .gitignore .gitattributes
                       gems/dot_popper-gameplay/sig gems/dot_popper-gameplay/test gems/dot_popper-gameplay/Rakefile
                       gems/dot_popper-gameplay/Steepfile gems/dot_popper-monetization/sig gems/dot_popper-monetization/test
                       gems/dot_popper-monetization/Rakefile gems/dot_popper-monetization/Steepfile
                       gems/dot_popper-release_engineering/sig gems/dot_popper-release_engineering/test
                       gems/dot_popper-release_engineering/Rakefile gems/dot_popper-release_engineering/Steepfile
                       gems/dot_popper-microsoft/sig gems/dot_popper-microsoft/test gems/dot_popper-microsoft/Rakefile
                       gems/dot_popper-microsoft/Steepfile
                       gems/dot_popper-shared/sig gems/dot_popper-shared/test gems/dot_popper-shared/Rakefile gems/dot_popper-shared/Steepfile].freeze

  # Run in a Ruby of its own, with the game's folder in the app and then
  # the libraries to require: reads the game's settings as `lota fuse`
  # does (conf.rb), loads main.rb as Lota::Boot does once the window is
  # open, and requires each library the game's code names, which it may
  # require only when it first needs it. Prints what it found, and fails
  # with what it could not load.
  START = <<~RUBY
    game, *libraries = ARGV
    require "lota"
    settings = Lota::Boot.new(game, [], fused: true).read_settings
    puts "identity \#{settings.identity}"
    require File.join(game, "main.rb")
    callbacks = %i[load update draw].select { Lota.respond_to?(it) }
    abort "main.rb defines none of Lota.load, update or draw" if callbacks.empty?
    puts "callbacks \#{callbacks.join(" ")}"
    libraries.each { require it }
    puts "libraries \#{libraries.join(" ")}"
  RUBY

  module_function

  # The paths +channel+'s app leaves out of the game: the repository's
  # own, and what the channel's build leaves out (ChannelContents).
  def excludes(channel) = REPOSITORY_ONLY + ChannelContents.left_out(channel)

  # The Fledge tag +lock+ pins. lota fuse runs the Fledge Lota pins
  # (Lota::Fuse::FLEDGE_REF) unless LOTA_FLEDGE_REF names another, so
  # every desktop build names this one, which the phone builds take too
  # (script/lota_pins.sh): every app is built by one Fledge.
  def fledge_ref(lock = File.join(ROOT, "Gemfile.lock"))
    require "bundler"
    locked = Bundler::LockfileParser.new(File.binread(lock))
    fledge = locked.sources.find { it.is_a?(Bundler::Source::Git) && it.uri.end_with?("/Fledge") }
    fledge&.options&.fetch("tag", nil) or raise "#{lock} locks no tagged Fledge"
  end

  # Copies to +to+ the files git tracks in +root+, as they are in the
  # working copy: what a checkout of the commit holds, and so what CI
  # fuses. Other files in a working copy (a build's output in tmp/, say)
  # never reach an app CI builds, so they reach no copy here either.
  # Paths that start with one of +except+ are not copied.
  def copy_tracked(to, root: ROOT, except: [])
    listed, status = Open3.capture2("git", "-C", root, "ls-files", "-z")
    raise "git could not list the files of #{root}" unless status.success?

    listed.split("\0").each do |path|
      source = File.join(root, path)
      next if !File.file?(source) || except.any? { path.start_with?(it) }

      target = File.join(to, path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target, preserve: true)
    end
    to
  end

  # Lays out in +to+ the game's folder as `lota fuse` copies +game+ into
  # the app, leaving out +excludes+, by Lota's own copy (Lota::Fuse), so
  # that it leaves out exactly what the app does.
  def lay_out(game, to, excludes:)
    require "lota"
    require "lota/fuse"
    out = File.join(Dir.tmpdir, "dot_popper-no-fuse-output")
    Lota::Fuse.new(game, Lota::Fuse.options(exclude: excludes, out:)).send(:copy_game, File.expand_path(game), to)
  end

  # The folders the gems an app ships load from, for a Ruby that has no
  # gems: those of the Gemfile's default group, as `lota fuse` ships them
  # (Lota and the game's own gems, under gems/), or Lota's when Bundler
  # isn't loaded. Given the laid-out +game+, the game's own gems load from
  # its copy of them, as in the app, and not from this repository's.
  def shipped_load_path(game = nil)
    require "lota"
    specs = defined?(Bundler) ? Bundler.definition.specs_for([:default, *ChannelContents::GEM_PARTS.map(&:to_sym)]).to_a : [Gem.loaded_specs.fetch("lota")]
    paths = specs.reject { it.name == "bundler" }.flat_map(&:full_require_paths)
    return paths unless game

    own = File.join(ROOT, "gems", "")
    paths.map { it.start_with?(own) ? File.join(game, it.delete_prefix(File.join(ROOT, ""))) : it }
  end

  # The libraries the Ruby files in +game+ require by name.
  def libraries(game)
    ruby_files(game).flat_map { File.read(it).scan(/^\s*require\s+"([^"#]+)"/).flatten }.uniq.sort
  end

  # The Ruby in +game+: its .rb files, and the programs in bin/.
  def ruby_files(game)
    Dir.glob(File.join(game, "**", "*.rb")) + Dir.glob(File.join(game, "bin", "*")).select { File.file?(it) }
  end

  # Runs START on the laid-out +game+ as a player's computer would; returns
  # the output and whether it passed.
  def start(game) = bare_ruby("-e", START, game, *libraries(game), game:)

  # Runs this Ruby with +arguments+ as the app's Ruby runs: no Bundler, no
  # gem but those the app ships, none of this process's settings, and a
  # home of its own, with +env+ added. Ruby's own default libraries load;
  # its bundled gems, which the app's Ruby also carries, do not, since the
  # game must lock a gem it uses. The game's own gems load from +game+, when given.
  # Returns the output and whether it exited with 0.
  def bare_ruby(*arguments, env: {}, game: nil)
    Dir.mktmpdir("dot_popper-home") do |home|
      gems = File.join(home, "no-gems")
      Dir.mkdir(gems)
      kept = %w[PATH SystemRoot SYSTEMROOT windir TEMP TMP].to_h { [it, ENV.fetch(it, nil)] }.compact
      bare = kept.merge("HOME" => home, "USERPROFILE" => home, "APPDATA" => home, "LOCALAPPDATA" => home,
                        "GEM_HOME" => gems, "GEM_PATH" => gems, "DOT_POPPER_AUTOMATED" => "1")
      load_path = shipped_load_path(game).flat_map { ["-I", it] }
      out, status = Open3.capture2e(bare.merge(env), RbConfig.ruby, *load_path, *arguments,
                                    unsetenv_others: true, chdir: home)
      [out, status.success?]
    end
  end
end
