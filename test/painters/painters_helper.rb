# frozen_string_literal: true

require "test_helper"
require "dot_popper/presentation"
require_relative "recording_context"

# The painters, loaded without Lota: each draws only through the context
# it is given (Shell::DrawingContext in the game), so a test hands it a
# RecordingContext and reads what it drew.
module PaintersTest
  P = DotPopper::Presentation

  # The files the painters draw with: every painter of a screen, and the
  # parts they share.
  PAINTING = %w[glyphs hud_painter mute_button tally_painter pill_button primary_button scrim_painter check_mark lettering
                code_box member_icon_painter group_painter settings_painter achievements_painter privacy_painter
                server_painter home_painter stats_painter offer_painter themes_painter credits_painter share_button
                share_preview_painter game_over_painter guide_painter tutorial_painter new_theme_card_painter
                themed_name].freeze
  PAINTING.each { require "dot_popper/shell/#{it}" }

  Shell = DotPopper::Shell

  # Shell::DotPainter's dots, kept as marks of the kind :dot in the
  # context: where, how big, and how drawn.
  class FakeDots < Data.define(:context)
    def icon(x, y, radius, bright:, opacity: 1.0, bonus: false) = context.record(:dot, x, y, radius, { bright:, opacity:, bonus: })
  end

  def context = @context ||= RecordingContext.new
  def dots = FakeDots.new(context:)
end
