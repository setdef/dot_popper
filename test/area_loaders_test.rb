# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

# Each area of the domain loads by itself, in a Ruby of its own with
# nothing else of the game loaded, and brings nothing with it but its
# own folder and the shared code it names, so what an area needs is in
# its own loader. The shared code comes from its gem
# (gems/dot_popper-shared), and Gameplay and Metagame and Monetization
# wholly from their own (gems/dot_popper-gameplay,
# gems/dot_popper-monetization), not from the game's lib/.
class AreaLoadersTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  ALONE = { "gameplay" => %w[gameplay network memory_file], "monetization" => %w[monetization network memory_file],
            "release_engineering" => %w[release_engineering] }.freeze

  def test_each_area_loads_by_itself
    ALONE.each do |area, own|
      script = %(require "dot_popper/#{area}"; puts $LOADED_FEATURES.grep(%r{/lib/dot_popper[/.]}))
      # No Bundler: the game's lib and its own gems' (gems/, PACKAGING.md)
      # by their folders, as where the game is fused, so the area loads from
      # this copy's files and not from whatever a bundle points at.
      code = [File.join(ROOT, "lib"), *Dir[File.join(ROOT, "gems/*/lib")].sort].flat_map { ["-I", it] }
      out, status = Open3.capture2e({ "RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil }, RbConfig.ruby, *code, "-e", script)
      assert status.success?, "#{area} does not load by itself:\n#{out}"
      loaded = out.lines.map { it.chomp.sub(%r{\A.*/lib/dot_popper/}, "") }
      assert_empty loaded.reject { |file| own.any? { file == "#{it}.rb" || file.start_with?("#{it}/") } }, "#{area} loads more than itself"
      shared = out.lines.map(&:chomp).select { it.match?(%r{/lib/dot_popper/(?:network|memory_file)[/.]}) }
      assert_empty shared.reject { it.start_with?(File.join(ROOT, "gems/dot_popper-shared/lib/")) }, "#{area} loads the shared code from outside its gem"
      next if area == "release_engineering"

      assert_empty out.lines.map(&:chomp).reject { it.start_with?(*[area, "shared"].map { File.join(ROOT, "gems/dot_popper-#{it}/lib/") }) },
                   "#{area} loads something from outside its gem and the shared code's"
    end
  end
end
