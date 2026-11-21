# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib" << "test"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/gui/**/*")
  t.warning = true
end

# The game played in a real window, end to end (test/gui): each scenario
# boots the game through Lota, plays a scripted session through Lota's
# callbacks, and quits. It needs a display, so rake test leaves it out.
# test/gui/scenarios_test.rb refuses to open windows unless asked
# (DOT_POPPER_OPEN_WINDOWS=1); running this task is the ask.
namespace :test do
  task :open_windows do
    ENV["DOT_POPPER_OPEN_WINDOWS"] = "1"
  end

  Rake::TestTask.new(gui: :open_windows) do |t|
    t.description = "Play scripted sessions of the game in real windows"
    t.libs << "lib" << "test"
    t.test_files = FileList["test/gui/**/*_test.rb"]
    t.warning = true
  end
end

# Type-checks the rules core against sig/. Steep runs as its own command,
# so rake test never loads it.
desc "Type-check the rules core with Steep"
task :steep do
  sh "bundle exec steep check"
  # The areas, each kept to its own signatures (the Steepfile says why).
  sh({ "STEEP_PROJECT" => "areas" }, "bundle exec steep check")
end

# Writes doc/privacy.json from what the game declares (lib/dot_popper/privacy).
# test/privacy fails if the committed file is stale.
desc "Generate doc/privacy.json"
task :privacy do
  $LOAD_PATH.unshift File.expand_path("lib", __dir__)
  require "dot_popper/privacy/document"
  File.write(DotPopper::Privacy::Document::PATH, DotPopper::Privacy::Document.current_json)
end

# The game's own gems (gems/, PACKAGING.md) each have their own tests and
# Steep check, which rake test and rake steep run too, each in its gem's
# folder, so `bundle exec rake` stays the one check.
OWN_GEMS = FileList["gems/*/Rakefile"].map { File.dirname(it) }

namespace :gems do
  %i[test steep].each do |check|
    desc "Run #{check} in each of the game's own gems"
    task check do
      OWN_GEMS.each { |gem| Dir.chdir(gem) { sh RbConfig.ruby, Gem.bin_path("rake", "rake"), check.to_s } }
    end
  end
end

task test: "gems:test"
task steep: "gems:steep"

task default: %i[test steep]
