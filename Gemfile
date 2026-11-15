# frozen_string_literal: true

source "https://rubygems.org"

# Lota 0.5 needs Ruby 4.1, which is not released yet. On Linux and macOS
# the Ruby is the preview .ruby-version names (4.1.0-preview1). On Windows,
# where RubyInstaller publishes no preview, it is RubyInstaller's head
# build of 2026-11-10, which calls itself 4.1.0dev and whose
# RbConfig::CONFIG["ruby_version"] is 4.1.0+6: the copy Fledge's release
# keeps, which mise.toml pins for Windows and Lota's Windows gems are built
# on. Fledge's runtimes, which run the packaged app, call every one of
# these "4.1.0" when fledge build compares them with this file.
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
gem "lota", "~> 0.5.2"

# Fledge packages the game for people who don't have Ruby (PACKAGING.md).
# Pinned to v0.12.0, the Fledge that Lota 0.5.2's lota fuse pins for a
# fused app too.
# In the development group, so fledge build leaves it out of the app.
group :development do
  gem "fledge", git: "https://github.com/setdef/Fledge", tag: "v0.12.0"

  # Steep checks the rules core against its RBS signatures in sig/
  # (bundle exec rake steep). Only the default rake task needs it;
  # rake test runs without it.
  gem "steep", "~> 2.1", require: false
end

group :development, :test do
  gem "minitest", "~> 5.25"
  gem "rake", "~> 13.2"
end
