# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Themes, over Home (ThemesLayout): a card for each theme, with a
      # controller the previous and next, and Back. A tap on a theme uses
      # it through +use_theme+ (UseCases::UseTheme), or for a Free player
      # opens the offer of Pro leading with themes. Every theme it shows is
      # open to use (+saved_themes+, Gameplay::SavedThemes#choices), so none
      # is drawn dimmed today, though a card that was not open would be.
      class Themes < Page
        def initialize(show, use_theme:, saved_themes:)
          super(show)
          @use_theme = use_theme
          @saved_themes = saved_themes
        end

        # Where its cards go (ThemesLayout).
        def plan = ThemesLayout.new(layout:, themes: show.themes, style: style::THEMES_LAYOUT)

        # Everything its painter draws (ThemesDrawing), made again only when
        # the window, the plan, the theme in use, a theme's opening, the
        # words, a button's light or the kind of input changes.
        def drawing
          plan = self.plan
          words = self.words
          hover = show.hover
          in_use = show.in_use
          open = plan.themes.to_h { [it.key, @saved_themes.open?(it.key)] }
          gamepad = show.input == InputKind::GAMEPAD
          drawn(plan, words, hover, in_use, open, gamepad) do
            names = words.themes
            cards = plan.cards.map do |card|
              theme = card.theme
              ThemeCardDrawing.new(theme:, rect: card.rect, name: names.fetch(theme.key), chosen: theme == in_use,
                                   open: open.fetch(theme.key), hover: hover.level(theme))
            end
            steps = gamepad ? plan.steps.map { |name, rect| ThemeStepDrawing.new(name:, rect:, hover: hover.level(name)) } : []
            ThemesDrawing.new(header: HeaderDrawing.for(names.fetch(:heading), layout:, measure:, words:, hover:), cards:, steps:)
          end
        end

        # Uses +theme+ from now on, and the whole screen takes its colors at
        # once, so the choice is seen before it is left.
        def use(theme)
          case @use_theme.call(theme.key)
          in :offer then show.offer.open_led_by(:themes)
          in :same then sounds.play(:tick, pitch: 0.8)
          in :used then sounds.play(:tick, pitch: 1.2)
          end
        end

        # Uses the previous (+by+ -1) or next (1) theme, round the ends.
        def step(by)
          list = show.themes
          use(list[(list.index(show.in_use).to_i + by) % list.size])
        end

        def controls
          plan = self.plan
          steps = show.input == InputKind::GAMEPAD ? plan.steps.map { |name, rect| button(name, rect) } : []
          plan.cards.map { button(it.theme, it.rect) } + steps << back_button
        end

        # LB and RB: use the previous or next theme.
        def pad(button)
          case button
          in :lb then step(-1)
          in :rb then step(1)
          else nil
          end
        end

        def answers = [*super, :theme, :theme_prev, :theme_next]

        def pressed(name, by)
          case name
          in Theme => theme then use(theme)
          in :theme_prev then step(-1)
          in :theme_next then step(1)
          else super
          end
        end
      end
    end
  end
end
