# frozen_string_literal: true

require "test_helper"
require "prism"

# The domain is in three areas, each a folder and a module
# (doc/architecture.md, ADR-0019): Gameplay and Metagame
# (lib/dot_popper/gameplay, DotPopper::Gameplay), Monetization
# (lib/dot_popper/monetization) and Release Engineering
# (lib/dot_popper/release_engineering). What each may name is the
# context map's:
#
# - Gameplay and Metagame names nothing of Monetization or Release
#   Engineering, so the rules of play never know that Pro exists.
# - Monetization hears Gameplay's published events (Gameplay::Events).
# - Release Engineering names neither, and neither names it: it has no
#   interface at run time, and only selects and packages (the test
#   build's part, outside the areas, may name Build).
# - None names the use cases, the presentation, the shell, the
#   composition root or the privacy declarations, which are outside
#   them and name them instead. Each may name what serves every area:
#   the network client (Network), the system the game runs on
#   (Platform) and the guard on automated runs (Automation).
#
# Every constant an area's Ruby names is resolved as Ruby resolves it
# (the module nesting, then the superclasses defined here, then the top
# level), from the source, so this holds for code Steep does not type
# (Monetization's continuity/ and receipt/) as for the rest. Steep holds
# the same for the signatures, one target per area (Steepfile). A
# constant reached by a name spelled at run time (const_get) is not
# seen.
#
# Where the code breaks a rule today, the breach is listed in BREACHES
# with how many times it names it and the step that will remove it, so
# the list can only shrink: a new breach fails, and so does one that is
# gone but still listed.
class AreasTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  AREAS = { "Gameplay" => "gameplay", "Monetization" => "monetization", "ReleaseEngineering" => "release_engineering" }.freeze

  # What each area may name besides itself, as DotPopper::<name> and
  # everything inside it.
  ALLOWED = {
    "Gameplay" => %w[Network Platform Automation],
    "Monetization" => %w[Gameplay::Events Network Platform Automation],
    "ReleaseEngineering" => %w[]
  }.freeze

  # [file, the constant it names] => [times named, the step of the
  # refactoring list that removes it].
  BREACHES = {
    # The save file kept in memory is the score record's (step 2.3).
    ["lib/dot_popper/monetization/free_games.rb", "DotPopper::Gameplay::ScoreRecord::Memory"] => [1, "2.3"],
    ["lib/dot_popper/monetization/continuity/license.rb", "DotPopper::Gameplay::ScoreRecord::Memory"] => [1, "2.3"],
    # Monetization asks the build's channel at run time, which one
    # registry of channels and one store per build remove (steps 5.1 to
    # 5.4), and whether a channel keeps license keys, which goes to the
    # website's own part (6.2).
    ["lib/dot_popper/monetization/store.rb", "DotPopper::ReleaseEngineering::Build::CHANNEL"] => [1, "5.4"],
    ["lib/dot_popper/monetization/store.rb", "DotPopper::ReleaseEngineering::Build::MAC_APP_STORE"] => [1, "5.1"],
    ["lib/dot_popper/monetization/store.rb", "DotPopper::ReleaseEngineering::Build::MICROSOFT_STORE"] => [1, "5.1"],
    ["lib/dot_popper/monetization/store.rb", "DotPopper::ReleaseEngineering::Build::WEBSITE"] => [1, "5.1"],
    ["lib/dot_popper/monetization/receipt.rb", "DotPopper::ReleaseEngineering::Build::MICROSOFT_STORE"] => [1, "5.1"],
    ["lib/dot_popper/monetization/continuity/license.rb", "DotPopper::ReleaseEngineering::Build"] => [1, "6.2"]
  }.freeze

  def test_each_area_names_only_what_the_context_map_allows
    found = Hash.new(0)
    AREAS.each do |area, folder|
      Dir[File.join(ROOT, "lib/dot_popper/#{folder}/**/*.rb")].each do |path|
        file = path.delete_prefix("#{ROOT}/")
        named(path).each { found[[file, it]] += 1 unless allowed?(area, it) }
      end
    end

    assert_equal BREACHES.transform_values(&:first).sort, found.sort,
                 "an area names what the context map does not allow it (or a listed breach is gone: take it off BREACHES)"
  end

  def test_the_check_sees_a_name_written_in_any_way
    source = <<~RUBY
      module DotPopper
        module Gameplay
          class Example < Monetization::Store
            def a = Monetization::Entitlement
            def b = DotPopper::Presentation::Show
            def c = ::DotPopper::ReleaseEngineering::Build::CHANNEL
            def d = Rules
          end
        end
      end
    RUBY
    names = Resolver.new(definitions).names(Prism.parse(source).value)

    assert_equal %w[DotPopper::Monetization::Store DotPopper::Monetization::Entitlement DotPopper::Presentation::Show
                    DotPopper::ReleaseEngineering::Build::CHANNEL], names.reject { allowed?("Gameplay", it) }
    assert_includes names, "DotPopper::Gameplay::Rules"
  end

  private

  def allowed?(area, name)
    return true unless name.start_with?("DotPopper::")

    ([area] + ALLOWED.fetch(area)).any? { name == "DotPopper::#{it}" || name.start_with?("DotPopper::#{it}::") }
  end

  def named(path) = Resolver.new(definitions).names(Prism.parse_file(path).value)

  # Every module, class and constant the game's code defines, by its full
  # name.
  def definitions
    @definitions ||= Dir[File.join(ROOT, "lib/**/*.rb")].each_with_object({}) do |path, all|
      Resolver.new({}).definitions(Prism.parse_file(path).value).each { all[it] = true }
    end
  end

  # Ruby's constant lookup, read from the source.
  class Resolver
    def initialize(defined)
      @defined = defined
      @supers = {}
    end

    def definitions(node, nesting = [], out = [])
      each_node(node, nesting) do |child, scope|
        case child
        when Prism::ModuleNode, Prism::ClassNode then out << [scope.last, child.constant_path.slice].compact.join("::")
        when Prism::ConstantWriteNode then out << [scope.last, child.name].compact.join("::")
        end
      end
      out
    end

    def names(node)
      found = []
      each_node(node, []) do |child, scope|
        found << resolve(child.slice, scope) if chain?(child) && !child.is_a?(Prism::ConstantWriteNode)
      end
      found
    end

    private

    # Yields each node with its module nesting, and a constant path once,
    # whole (A::B::C, not also A::B).
    def each_node(node, nesting, &block)
      return unless node

      case node
      when Prism::ModuleNode, Prism::ClassNode
        yield node, nesting
        full = [nesting.last, node.constant_path.slice].compact.join("::")
        if node.is_a?(Prism::ClassNode) && node.superclass
          @supers[full] = resolve(node.superclass.slice, nesting) if chain?(node.superclass)
          each_node(node.superclass, nesting, &block)
        end
        each_node(node.body, nesting + [full], &block)
      when Prism::ConstantPathNode, Prism::ConstantReadNode
        chain?(node) ? yield(node, nesting) : node.compact_child_nodes.each { each_node(it, nesting, &block) }
      else
        yield node, nesting
        node.compact_child_nodes.each { each_node(it, nesting, &block) }
      end
    end

    def chain?(node)
      case node
      when Prism::ConstantReadNode then true
      when Prism::ConstantPathNode then node.parent.nil? || chain?(node.parent)
      else false
      end
    end

    def resolve(text, nesting)
      return text.delete_prefix("::") if text.start_with?("::")

      first, rest = text.split("::", 2)
      root = nesting.reverse_each.lazy.filter_map { lookup(it, first) }.first || first
      [root, rest].compact.join("::")
    end

    def lookup(scope, name)
      seen = {}
      while scope && !seen[scope]
        return "#{scope}::#{name}" if @defined["#{scope}::#{name}"]

        seen[scope] = true
        scope = @supers[scope]
      end
      nil
    end
  end
end
