# frozen_string_literal: true

require "test_helper"
require "prism"

# The domain is in three areas, each a module in a gem of its own
# (doc/architecture.md, ADR-0019, ADR-0025): Gameplay and Metagame
# (the gem gems/dot_popper-gameplay, DotPopper::Gameplay), Monetization
# (the gem gems/dot_popper-monetization, with what the build parts under
# lib/dot_popper add to it) and Release Engineering
# (the gem gems/dot_popper-release_engineering); the code they share is
# the gem gems/dot_popper-shared. What each may name is the
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
#   (Platform), the guard on automated runs (Automation) and a save
#   file kept in memory (MemoryFile).
# - That shared code names nothing of the three areas, so it never
#   carries one area to another, and nothing outside it.
#
# An area's files are its gem's lib/ (gems/dot_popper-gameplay and the
# like), and Monetization's also the build parts' files that are its. Every constant an area's Ruby names is resolved as Ruby resolves it
# (the module nesting, then the superclasses defined here, then the top
# level), from the source, so this holds for code Steep does not type
# as for the rest. Steep holds
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

  SHARED = %w[Network Platform Automation MemoryFile].freeze

  # The files of each area, and of the code the areas share, under
  # lib/dot_popper, and in the game's own gems: Gameplay's
  # (gems/dot_popper-gameplay), all of which is Gameplay, Monetization's
  # (gems/dot_popper-monetization), which with the build parts' receipt
  # checks, license keys and website store is Monetization, Release
  # Engineering's (gems/dot_popper-release_engineering), all of which is
  # Release Engineering, and the shared code's (gems/dot_popper-shared),
  # all of which is the shared code.
  FILES = {
    "Gameplay" => %w[../../gems/dot_popper-gameplay/lib/**/*.rb],
    "Monetization" => %w[../../gems/dot_popper-monetization/lib/**/*.rb website/license_keys.rb website/license_keys/**/*.rb website/website_store.rb
                       apple/receipt.rb play/receipt.rb microsoft/receipt.rb],
    "ReleaseEngineering" => %w[../../gems/dot_popper-release_engineering/lib/**/*.rb],
    "Shared" => %w[../../gems/dot_popper-shared/lib/**/*.rb]
  }.freeze

  # What each may name besides itself, as DotPopper::<name> and
  # everything inside it.
  ALLOWED = {
    "Gameplay" => SHARED,
    "Monetization" => ["Gameplay::Events", *SHARED],
    "ReleaseEngineering" => %w[],
    "Shared" => SHARED
  }.freeze

  # [file, the constant it names] => [times named, the step of the
  # refactoring list that removes it].
  BREACHES = {
  }.freeze

  def test_each_area_names_only_what_the_context_map_allows
    found = Hash.new(0)
    FILES.each do |area, patterns|
      Dir[*patterns, base: File.join(ROOT, "lib/dot_popper")].map { File.expand_path(it, File.join(ROOT, "lib/dot_popper")) }.each do |path|
        file = path.delete_prefix("#{ROOT}/")
        named(path).each { found[[file, it]] += 1 unless allowed?(area, it) }
      end
    end

    assert_equal BREACHES.transform_values(&:first).sort, found.sort,
                 "an area names what the context map does not allow it (or a listed breach is gone: take it off BREACHES)"
  end

  def test_the_check_reads_each_area_s_loader_and_the_shared_code
    files = FILES.values.flatten.flat_map { Dir[it, base: File.join(ROOT, "lib/dot_popper")] }

    assert_includes files, "../../gems/dot_popper-gameplay/lib/dot_popper/gameplay.rb"
    assert_includes files, "../../gems/dot_popper-shared/lib/dot_popper/network/link.rb"
    assert_includes files, "../../gems/dot_popper-gameplay/lib/dot_popper/gameplay/visibility.rb"
    assert_includes files, "../../gems/dot_popper-monetization/lib/dot_popper/monetization.rb"
    assert_includes files, "../../gems/dot_popper-release_engineering/lib/dot_popper/release_engineering/build.rb"
    assert_equal Dir["*.rb", base: File.join(ROOT, "lib/dot_popper")].sort - %w[presentation.rb shell.rb use_cases.rb],
                 files.grep_v(%r{/}).sort, "every file at the top of lib/dot_popper but the outer layers' loaders"
  end

  # A file in one of the game's own gems that no area claims would be read
  # by nothing here.
  def test_every_file_of_the_game_s_own_gems_is_in_an_area
    claimed = FILES.values.flatten.flat_map { Dir[it, base: File.join(ROOT, "lib/dot_popper")] }
                   .map { File.expand_path(it, File.join(ROOT, "lib/dot_popper")) }

    assert_empty Dir[File.join(ROOT, "gems/*/lib/**/*.rb")] - claimed, "a gem's file is in no area of FILES"
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
            def e = ::Object::DotPopper::Monetization::Entitlement
            def f = Object::DotPopper::Shell
          end
        end
      end
    RUBY
    names = Resolver.new(definitions).names(Prism.parse(source).value)

    assert_equal %w[DotPopper::Monetization::Store DotPopper::Monetization::Entitlement DotPopper::Presentation::Show
                    DotPopper::ReleaseEngineering::Build::CHANNEL DotPopper::Monetization::Entitlement DotPopper::Shell], names.reject { allowed?("Gameplay", it) }
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
    @definitions ||= Dir[File.join(ROOT, "{lib,gems/*/lib}/**/*.rb")].each_with_object({}) do |path, all|
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

    # A name's full name. Object::X is the top level's X, so a leading
    # Object:: (::Object::DotPopper::…) is dropped.
    def resolve(text, nesting) = top_level(text.start_with?("::") ? text.delete_prefix("::") : nested(text, nesting))

    def nested(text, nesting)
      first, rest = text.split("::", 2)
      root = nesting.reverse_each.lazy.filter_map { lookup(it, first) }.first || first
      [root, rest].compact.join("::")
    end

    def top_level(name) = name.sub(/\A(?:Object::)+/, "")

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
