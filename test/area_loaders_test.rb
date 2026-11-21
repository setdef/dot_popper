# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

# Each area of the domain loads by itself, in a Ruby of its own with
# nothing else of the game loaded, and brings nothing with it but its
# own folder and the shared code it names, so what an area needs is in
# its own loader. The shared code comes from its gem
# (gems/dot_popper-shared), not from the game's lib/.
class AreaLoadersTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  ALONE = { "gameplay" => %w[gameplay network memory_file], "monetization" => %w[monetization network memory_file],
            "release_engineering" => %w[release_engineering] }.freeze

  def test_each_area_loads_by_itself
    ALONE.each do |area, own|
      script = %(require "dot_popper/#{area}"; puts $LOADED_FEATURES.grep(%r{/lib/dot_popper[/.]}))
      out, status = Open3.capture2e(RbConfig.ruby, "-I", File.join(ROOT, "lib"), "-e", script)
      assert status.success?, "#{area} does not load by itself:\n#{out}"
      loaded = out.lines.map { it.chomp.sub(%r{\A.*/lib/dot_popper/}, "") }
      assert_empty loaded.reject { |file| own.any? { file == "#{it}.rb" || file.start_with?("#{it}/") } }, "#{area} loads more than itself"
      shared = out.lines.map(&:chomp).select { it.match?(%r{/lib/dot_popper/(?:network|memory_file)[/.]}) }
      assert_empty shared.reject { it.start_with?(File.join(ROOT, "gems/dot_popper-shared/lib/")) }, "#{area} loads the shared code from outside its gem"
    end
  end
end
