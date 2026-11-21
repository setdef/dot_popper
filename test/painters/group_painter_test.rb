# frozen_string_literal: true

require_relative "painters_helper"
require_relative "../presentation/inputs"

# Shell::GroupPainter draws the friend groups' pages from the
# GroupsDrawing their screen hands it, and from nothing else.
class GroupPainterTest < Minitest::Test
  include PaintersTest

  SIZES = [[1200, 800], [400, 850], [850, 400]].freeze

  # The plan's controls are handed on with their light (action_hovers,
  # row_hovers); what it was laid out from and how far its list scrolls
  # are not drawn; a group's member icons and crests are drawn from their
  # ids, which a change of kind cannot keep.
  UNUSED = [%i[plan heading_size], %i[plan content], [:plan, :actions, :*, :name], [:plan, :rows, :*, :group],
            [:plan, :rows, :*, :member], [:plan, :rows, :*, :change], [:plan, :rows, :*, :runs]].freeze

  def groups(width: 1200, height: 800, member: true, input: nil)
    fixture = Inputs::Fixture.new(os: "Linux", width:, height:, member:, pro: true)
    show = fixture.show
    show.input = input if input
    show.open_groups
    fixture.tick(1.0)
    [show, fixture]
  end

  def draw(drawing) = Shell::GroupPainter.new(context:).draw(drawing)

  # The paths of +drawing+ named +unused+, and whatever it leaves out:
  # an action with no word, or Back, which the header draws; a row's or
  # an action's light where none is drawn.
  def unused(drawing)
    plan = drawing.plan
    quiet = plan.actions.each_index.select { !plan.actions[it].text || plan.actions[it].name == :back }
    # Join looks shut, and never lit, until the code is whole.
    shut = drawing.code_complete ? [] : plan.actions.each_index.select { plan.actions[it].name == :code_submit }
    dark = plan.rows.each_index.reject { plan.rows[it].is_a?(P::GroupListRow) }
    [*UNUSED.select { |path| paths(drawing).any? { under?(it, path) } },
     *quiet.flat_map { [[:plan, :actions, it], [:action_hovers, it]] }, *dark.map { [:row_hovers, it] }, *shut.map { [:action_hovers, it] },
     *([%i[plan size]] if plan.lines.empty? && plan.rows.empty?),
     *([[:code], [:code_row]] unless plan.code_box), *([[:code_complete]] unless plan.actions.any? { it.name == :code_submit }),
     *([[:center_x]] if plan.lines.empty? && !plan.subheading && !(plan.crest_y && drawing.crest) && !drawing.holding), *([%i[plan crest_y], [:crest]] unless plan.crest_y && drawing.crest),
     *([[:holding_size], [:holding_bottom]] unless drawing.holding)]
  end

  def pages(show, fixture)
    panel = show.group_panel
    list = show.screen.drawing
    group = panel.groups.groups.first or flunk "the member's groups are listed"
    panel.press([:group_show, group.id], :touch, show.now)
    fixture.tick(1.0)
    standing = show.screen.drawing
    show.screen.start
    fixture.tick(0.3)
    holding = show.screen.drawing
    panel.let_go(:start, show.now)
    panel.back
    panel.press(:group_join_open, :touch, show.now)
    fixture.tick(0.5)
    panel.press(:notice_go, :touch, show.now) if panel.asking
    "123".each_char { panel.press([:code_digit, it], :touch, show.now) }
    fixture.tick(0.5)
    { list:, standing:, holding:, keypad: show.screen.drawing }
  end

  def test_it_draws_every_field_of_each_page
    SIZES.each do |width, height|
      show, fixture = groups(width:, height:)
      drawn = pages(show, fixture)
      assert_equal "123", drawn[:keypad].code, "the keypad's digits"
      refute_nil drawn[:holding].holding, "a hold on Leave"
      drawn.each do |name, given|
        refute_empty drawn(given), name.to_s
        assert_draws_every_field(given, unused: unused(given)) { draw(it) }
      end
    end
  end

  def test_the_next_place_of_the_code_is_outlined
    show, fixture = groups
    keypad = pages(show, fixture).fetch(:keypad)
    cream = context.palette.cream.then { [it.r, it.g, it.b] }
    lines = ->(drawing) { drawn(drawing).count { it.kind == :rectangle && it.args[0] == :line && it.color.first(3) == cream } }
    assert_equal lines.call(keypad.with(code: "1234567")) + 1, lines.call(keypad), "one place outlined while the code is short"
  end

  def test_the_notice_of_a_first_join_is_drawn_over_the_page
    show, fixture = groups
    show.group_panel.press(:group_join_open, :touch, show.now)
    fixture.tick(0.5)
    given = show.screen.drawing
    notice = given.notice
    refute_nil notice, "a first Join asks first"
    said(notice.later_word, drawn(given))
    assert_draws_every_field(notice, unused: [%i[plan lines], %i[plan size]]) { |it| Shell::GroupPainter.new(context:).send(:notice, it) }
  end

  def test_a_row_and_an_action_are_lit_by_the_mouse_over_them
    show, fixture = groups(input: P::InputKind::MOUSE)
    given = show.screen.drawing
    row = given.plan.rows.find { it.is_a?(P::GroupListRow) }
    show.pointer_at(row.rect.center_x, row.rect.center_y)
    fixture.tick(1.0)
    assert_in_delta 1.0, show.screen.drawing.row_hovers[given.plan.rows.index(row)]
    create = given.plan.actions.index { it.name == :group_create }
    rect = given.plan.actions[create].rect
    show.pointer_at(rect.center_x, rect.center_y)
    fixture.tick(1.0)
    lit = show.screen.drawing.action_hovers
    assert_in_delta 1.0, lit[create]
    assert(lit.each_with_index.all? { |level, i| i == create || level < 0.5 })
  end
end
