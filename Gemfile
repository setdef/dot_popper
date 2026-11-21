# frozen_string_literal: true

source "https://rubygems.org"

# Lota 0.5 needs Ruby 4.1, which is not released yet. On Linux and macOS
# the Ruby is the preview .ruby-version names (4.1.0-preview1). On Windows,
# where RubyInstaller publishes no preview, it is RubyInstaller's head
# build of 2026-11-10, which calls itself 4.1.0dev and whose
# RbConfig::CONFIG["ruby_version"] is 4.1.0+6: the copy Fledge's release
# keeps, which mise.toml pins for Windows and Lota's Windows gems are built
# on. Fledge's runtimes, which run the packaged app, are the same Rubies,
# which fledge build compares with this file as RubyGems names them:
# 4.1.0.preview1, and 4.1.0.dev on Windows.
#
# So Bundler and Fledge are asked for Ruby 4.1.0 or a prerelease of it,
# and the Ruby that reads this file must be exactly the one pinned for its
# system.
ruby ">= 4.1.0.a", "<= 4.1.0"
windows_ruby_version = "4.1.0+6"
pinned_ruby = File.expand_path(".ruby-version", __dir__)
if Gem.win_platform?
  unless RbConfig::CONFIG["ruby_version"] == windows_ruby_version
    raise Gem::RubyVersionMismatch, "Dot Popper runs on Windows on RubyInstaller's head build whose ruby_version is " \
                                    "#{windows_ruby_version} (mise.toml), and this is #{RUBY_DESCRIPTION}"
  end
elsif File.file?(pinned_ruby)
  wanted = Gem::Version.new(File.read(pinned_ruby).strip.tr("-", "."))
  unless Gem.ruby_version == wanted
    raise Gem::RubyVersionMismatch, "Dot Popper runs on Ruby #{wanted} (.ruby-version), and this is #{RUBY_DESCRIPTION}"
  end
end

# Lota is not on RubyGems.org. Its precompiled gems for each platform we
# build on live in vendor/cache, downloaded from its GitHub release and
# checked against the release's SHA256SUMS.
gem "lota", "~> 0.5.5"

# The game's own gems, each an area of the game, or the code the areas
# share, in a folder of its own under gems/, taken by its path and
# published nowhere (PACKAGING.md, "The game's own gems"). Every app
# carries them, as it carries lib/.
gem "dot_popper-shared", path: "gems/dot_popper-shared"
gem "dot_popper-gameplay", path: "gems/dot_popper-gameplay"

# Fledge packages the game for people who don't have Ruby (PACKAGING.md).
# Pinned to a tag, which the phone builds take (script/lota_pins.sh)
# and every desktop build names to lota fuse, which would otherwise run
# its own pin, v0.14.0 in Lota 0.5.5 (PackagedApp.fledge_ref).
# In the development group, which lota fuse leaves out of a desktop app.
# The phone builds run it from a Gemfile of their own, outside the phone
# project, so no app carries it (Privacy::PHONE_GEMS).
group :development do
  gem "fledge", git: "https://github.com/setdef/Fledge", tag: "v0.16.0"

  # Steep checks the rules core against its RBS signatures in sig/
  # (bundle exec rake steep). Only the default rake task needs it;
  # rake test runs without it.
  gem "steep", "~> 2.1", require: false
end

group :development, :test do
  gem "minitest", "~> 6.1"
  # Minitest 6 keeps Minitest::Mock and #stub in a gem of their own.
  gem "minitest-mock", "~> 5.27"
  gem "rake", "~> 13.2"
end
