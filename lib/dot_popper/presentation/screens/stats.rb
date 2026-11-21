# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Stats, over Home (StatsLayout): the sheet of every game's numbers
      # from +saved_stats+ and the +achievements+, Back, and "Clear my
      # stats…", held to clear them through +stats_backup+ (StatsBackup), or
      # Undo for a while after.
      class Stats < Page
        include Scrolling

        def initialize(show, stats_backup:, saved_stats:, achievements:, haptics:)
          super(show)
          @stats_backup = stats_backup
          @saved_stats = saved_stats
          @achievements = achievements
          @haptics = haptics
          @sheet = nil
          @clearing = HoldToConfirm.idle(show.style::STATS_CLEAR.hold)
          @undo = nil
        end

        # What it shows (StatsSheet), from when it was last opened.
        attr_reader :sheet

        # The hold of "Clear my stats…" (HoldToConfirm).
        attr_reader :clearing

        # Opens over Home, from the Stats as they are now.
        def open
          refresh
          show.push_page(:stats)
        end

        # The sheet as the Stats are now.
        def refresh = @sheet = build_sheet

        # As a screen over Home opens or closes: its list starts from the
        # top, and nothing holds "Clear my stats…".
        def page_changed
          super
          cancel_hold
        end

        # Where its parts go (StatsLayout).
        def plan = StatsLayout.measured(layout:, sheet:, style: style::STATS, measure:)

        # Everything its painter draws (StatsDrawing), or nil before it has
        # been opened, made again only when the window, the sheet, the
        # list's scroll, the hold, Undo, the words or a button's light
        # changes. Its list is fitted to its window here, as it is drawn.
        def drawing
          sheet = self.sheet or return
          plan = self.plan
          words = self.words
          hover = show.hover
          note = show.stats_note
          undo = undoable_clear
          offered = clear_offered?
          offset = (fit(plan.cards.last, plan.window.height).offset unless sheet.empty)
          drawn(sheet, plan, words, hover, note, clearing, undo, offered, offset) do
            StatsDrawing.new(header: HeaderDrawing.for(words.stats, layout:, measure:, words:, hover:), sheet:, plan:, note:,
                             center_x: layout.center_x, center_y: layout.center_y, offset:, clearing:,
                             keep_holding: words.keep_holding(clearing.by == :y ? "Y" : "A"), hold_to_clear: words.hold_to_clear,
                             prompt_y: (layout.short? ? layout.safe.bottom : layout.back_button.y) - 14, prompt_width: layout.safe.width - 32,
                             clear: (layout.clear_stats_button if offered), clear_word: words.clear, clear_hover: hover.level(:clear), undo:,
                             undo_rect: layout.undo_button, undo_word: words.undo, undo_hover: hover.level(:undo), cleared: words.cleared,
                             no_games: words.no_games)
          end
        end

        # Undo, while it is offered here (UndoableClear), or nil.
        def undoable_clear = (@undo if show.stats?)

        # Whether it offers "Clear my stats…": while it has Stats to clear,
        # and no Undo is offered.
        def clear_offered? = show.stats? && !sheet.empty && !undoable_clear

        # A gamepad's Y, held by +by+: Undo while it is offered, or else the
        # start of holding "Clear my stats…".
        def clear_or_undo(by)
          return undo if undoable_clear

          hold_clear(by) if clear_offered?
        end

        def hold_clear(by)
          @clearing = clearing.press(by, show.now)
          sounds.play(:tick, pitch: 0.7)
        end

        # +by+ let go: a hold it made ends, with nothing cleared, if it was
        # let go too soon.
        def release(by) = @clearing = clearing.release(by, show.now)

        # Whatever holds "Clear my stats…" stops, with nothing cleared.
        def cancel_hold = @clearing = clearing.cancel

        # A game started: its records would be lost to an undo.
        def game_started = @undo = nil

        def undo
          @stats_backup.restore(@undo.cleared)
          @undo = nil
          changed
          sounds.play(:tick, pitch: 1.2)
        end

        # The moving parts of each frame: a hold done clears the Stats, and
        # Undo goes once its time is over.
        def update(_seconds)
          clear if clearing.done?(show.now)
          @undo = nil unless @undo&.open?(show.now)
        end

        # "Clear my stats…" was held long enough: Stats go, and Undo is
        # offered.
        def clear
          @clearing = clearing.cancel
          @undo = UndoableClear.new(cleared: @stats_backup.clear, at: show.now, seconds: style::STATS_CLEAR.undo)
          changed
          sounds.play(:bonk, pitch: 0.7)
          @haptics.buzz(style::HAPTICS.mistake)
        end

        def controls
          [(button(:undo, layout.undo_button) if undoable_clear),
           (button(:clear, layout.clear_stats_button) if clear_offered?),
           back_button].compact
        end

        # Y: Undo while it is offered, or else hold to clear the stats.
        def pad(button) = (clear_or_undo(:y) if button == :y)

        def answers = [*super, :undo, :clear]

        def pressed(name, by)
          case name
          in :undo then undo
          in :clear then hold_clear(by)
          else super
          end
        end

        private

        # The Stats changed under it: it, and Home's score record, show them
        # as they are now.
        def changed
          refresh if show.stats?
          show.score_record_changed
        end

        def build_sheet
          game_flow = show.game_flow
          size_class = game_flow.size_class
          StatsSheet.build(@saved_stats.stats, score_record: game_flow.score_record.of(size_class), words:, streak: @saved_stats.streak,
                                              size_class:, achievements: @achievements)
        end
      end
    end
  end
end
