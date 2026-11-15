# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Shell::App's input callbacks, as main.rb hands Lota's to them: each
# reaches the Presentation::InputHandler as the game's own event, with
# what Lota says of the keyboard. The GUI scenarios push presses onto
# Lota's event queue, but a modifier held, a trigger and the window's
# focus come from the system, not that queue, so no scenario reaches
# these; here the App's own methods are called, with a stand-in for the
# handler that remembers what it was handed.
class AppInputsTest < Minitest::Test
  P = DotPopper::Presentation

  # The InputHandler, remembering each event.
  class Heard
    attr_reader :events

    def initialize = @events = []
    def call(event) = @events << event
  end

  def setup
    require "lota"
    require "dot_popper/shell"
    @app = DotPopper::Shell::App.new({})
    @heard = Heard.new
    @app.instance_variable_set(:@input, DotPopper::Shell::LotaInput.new)
    @app.instance_variable_set(:@inputs, @heard)
  rescue LoadError => e
    skip "Lota isn't installed here (#{e.message})"
  end

  def test_a_key_comes_with_the_modifier_keys_lota_says_are_held
    ::Lota::Keyboard.stub(:down?, ->(*keys) { keys.include?(:rctrl) }) { @app.key_pressed("v") }

    assert_equal [P::KeyPress.new(key: :v, held: %i[ctrl])], @heard.events
  end

  def test_a_trigger_is_pulled
    @app.gamepad_axis("triggerright", 0.75)

    assert_equal [P::TriggerPull.new(trigger: :right, value: 0.75)], @heard.events
  end

  def test_the_window_losing_focus_and_the_mouse_leaving_it
    @app.focus(false)
    @app.mouse_focus(false)
    @app.mouse_focus(true)

    assert_equal [P::FocusLost.new, P::MouseLeft.new], @heard.events
  end
end
