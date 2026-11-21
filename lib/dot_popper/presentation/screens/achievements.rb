# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Achievements, over Home (AchievementsLayout): a grid of cells that
      # scrolls, each opening its achievement's dialog, and Back.
      class Achievements < Page
        include Scrolling

        # How many are earned, and which (UseCases::ViewAchievements).
        def initialize(show, view_achievements:)
          super(show)
          @view_achievements = view_achievements
        end

        # Where the grid goes (AchievementsLayout).
        def grid = AchievementsLayout.new(layout:, ids: DotPopper::Gameplay::Achievement::IDS)

        # Each cell where it is on screen, with the list scrolled to fit its
        # window.
        def cells
          grid = self.grid
          fit(grid.height, grid.window.height)
          grid.cells(scroll.offset)
        end

        # Everything its painter draws (AchievementsDrawing), made again
        # only when the window, the scroll, what is earned, the words, a
        # cell's light or the kind of input changes.
        def drawing
          cells = self.cells
          words = self.words
          hover = show.hover
          count = @view_achievements.count
          earned = cells.map { @view_achievements.earned?(it.id) }
          drawn(cells, words, hover, count, earned) do
            gamepad = words.input == InputKind::GAMEPAD
            AchievementsDrawing.new(header: HeaderDrawing.for(words.button(:achievements_heading), layout:, measure:, words:, hover:),
                                    count: (AchievementWords.count(count) if count), count_x: layout.center_x,
                                    count_y: layout.heading_y + (layout.heading_size * 0.72), window: grid.window,
                                    cells: cells.each_with_index.map do |cell, i|
                                      AchievementCellDrawing.new(cell:, name: AchievementWords.name(cell.id), earned: earned[i],
                                                                 hover: hover.level([:achievement, cell.id]))
                                    end,
                                    how_to_earn: (layout.clear_stats_button if gamepad), how_to_earn_word: words.button(:how_to_earn))
          end
        end

        def controls
          window = grid.window
          cells = self.cells.select { it.rect.y < window.bottom && it.rect.bottom > window.y }.map do
            control = button([:achievement, it.id], it.rect.cut(top: window.y, bottom: window.bottom))
            control.with(reach: control.reach.cut(top: window.y, bottom: window.bottom))
          end
          cells << back_button
        end

        # X: the first achievement's dialog.
        def pad(button) = (show.screens.fetch(:achievement_dialog).open_at(DotPopper::Gameplay::Achievement::IDS.first) if button == :x)

        def answers = [*super, :achievement]

        def pressed(name, by)
          case name
          in [:achievement, id] then show.screens.fetch(:achievement_dialog).open_at(id)
          else super
          end
        end

        def list_row?(name) = name in [:achievement, _]
      end
    end
  end
end
