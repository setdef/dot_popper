# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws a frame of the Show, straight to the window at its own
    # resolution: the night behind, the edge glow, the dots (tumbling
    # into the Pile after time's up) over the Bloom's glow, the rings and
    # outlines that follow them, which after time's up are the pile's and
    # dim with it, under Game Over's card and buttons, the numbers that
    # float up, the screen's words and HUD on top, the screens open over
    # the game's state (Show#stack), each by its painter, and over
    # everything, the gamepad's cursor when it shows. Only the HUD shakes.
    # The Tutorial is drawn as a game is, from its own dots and HUD, with
    # its spotlight, hand and skip button over them.
    class Renderer
      G = ::Lota::Graphics
      Screens = Presentation::Screens

      # With +diagnostic+ (DOT_POPPER_DIAGNOSTIC_COLORS), each frame clears
      # to pure blue and draws no night, so any pixel the game's drawing
      # reaches but nothing paints shows blue (doc/ios.md).
      def initialize(show, context, pile:, particle_systems:, bloom:, diagnostic: false)
        @show = show
        @diagnostic = diagnostic
        @context = context
        @pile = pile
        @bloom = bloom
        @dots = DotPainter.new(context:, now: -> { @show.now })
        @effects = EffectsPainter.new(context:, particle_systems:)
        @hud = HudPainter.new(context:, dots: @dots)
        @huds = Presentation::HudDrawings.new(type: context.style::TYPE, measure: show.measure)
        @home = HomePainter.new(context:, dots: @dots)
        @stats = StatsPainter.new(context:)
        @settings = SettingsPainter.new(context:, dots: @dots)
        @achievements = AchievementsPainter.new(context:)
        @privacy = PrivacyPainter.new(context:)
        @server = ServerPainter.new(context:)
        @credits = CreditsPainter.new(context:)
        @themes = ThemesPainter.new(context:, dots: @dots)
        @offer = OfferPainter.new(context:, dots: @dots)
        @game_over = GameOverPainter.new(context:, dots: @dots)
        @group = GroupPainter.new(context:)
        @share = SharePreviewPainter.new(context:, dots: @dots)
        @cursor = CursorPainter.new(context:)
        @splash = SplashPainter.new(context:)
        @scene = Scene.new(context)
        @new_theme_card = NewThemeCardPainter.new(context:, dots: @dots)
        @tutorial = TutorialPainter.new(context:)
        @at_rest = Presentation::DotAnimations.new(context.style::MOTION)
      end

      # The frame, with the setdef +splash+ over it while there is one:
      # what the Show says is showing (Show#screen). Under everything is
      # the game's state: Home's dots, the Tutorial over its game, or a
      # game and after it Game Over. Over that, the screens open over it,
      # from the last that covers the rest up to the top one.
      def draw(cursor, splash = nil)
        width, height = cover
        layout = @show.layout
        backdrop(width, height)
        state = @show.state_screen
        case state
        when Screens::Tutorial then tutorial(state, width, height, layout)
        when Screens::Home, Screens::NewTheme then @dots.draw(@show.attract.dots, @at_rest, @show.now, radius)
        else game(width, height, layout)
        end
        screens(state, width, height, layout)
        announcement(layout) if @show.screen.announces?
        splash ? @splash.draw(splash) : @cursor.draw(cursor)
      end

      private

      # The screens over the game's state, from the last one that covers
      # the rest (or the screen for the state itself) up to the top one.
      def screens(state, width, height, layout)
        stack = @show.stack
        from = stack.rindex { it.covers? }
        draw_screen(state, width, height, layout) unless from
        (from || 0).upto(stack.size - 1) { draw_screen(stack[it], width, height, layout) }
      end

      # One screen, over the veil it draws over what is under it, by its
      # class (PAINTS).
      def draw_screen(screen, width, height, layout) = send(PAINTS.fetch(screen.class), screen, width, height, layout)

      # How each screen is drawn, by its class: the veil it lays over what
      # is under it, and its painter. The Tutorial, a game and Game Over
      # are drawn with the game under every screen (#draw), so they add
      # nothing here. test/shell/renderer_screens_test.rb fails for a
      # screen in Screens::ALL that is missing.
      PAINTS = { Screens::Home => :home_screen, Screens::NewTheme => :new_theme_screen, Screens::Tutorial => :nothing,
                 Screens::Game => :nothing, Screens::GameOver => :nothing, Screens::SharePreview => :share_preview_screen,
                 Screens::Offer => :offer_screen, Screens::Stats => :stats_screen, Screens::Achievements => :achievements_screen,
                 Screens::AchievementDialog => :achievement_dialog_screen, Screens::Themes => :themes_screen,
                 Screens::Settings => :settings_screen, Screens::Credits => :credits_screen, Screens::Privacy => :privacy_screen,
                 Screens::ChangeServer => :change_server_screen, Screens::FriendGroups => :friend_groups_screen }.freeze

      def nothing(_screen, _width, _height, _layout) = nil

      def home_screen(_screen, width, height, _layout)
        veil(width, height, @context.style::HOME.dim)
        @home.draw(@show.screens.fetch(:home).drawing, @show.now)
      end

      def new_theme_screen(screen, width, height, layout)
        home_screen(screen, width, height, layout)
        @new_theme_card.draw(screen.drawing)
      end

      def settings_screen(screen, width, height, _layout)
        page_veil(width, height)
        @settings.draw(screen.drawing)
      end

      def credits_screen(screen, width, height, _layout)
        page_veil(width, height)
        @credits.draw(screen.drawing)
      end

      def change_server_screen(screen, width, height, _layout)
        page_veil(width, height)
        @server.draw(screen.drawing)
      end

      def privacy_screen(screen, width, height, _layout)
        page_veil(width, height)
        @privacy.draw(screen.drawing)
      end

      def stats_screen(_screen, width, height, layout)
        page_veil(width, height)
        @stats.draw(@show, layout)
      end

      def themes_screen(screen, width, height, _layout)
        page_veil(width, height)
        @themes.draw(screen.drawing)
      end

      def achievements_screen(screen, width, height, _layout)
        page_veil(width, height)
        @achievements.draw(screen.drawing)
      end

      def achievement_dialog_screen(screen, _width, _height, _layout) = @achievements.dialog(screen.drawing)

      def friend_groups_screen(screen, width, height, _layout)
        veil(width, height, @context.style::GROUPS.veil)
        @group.draw(screen.drawing)
      end

      def offer_screen(screen, width, height, _layout)
        page_veil(width, height)
        @offer.draw(screen.drawing)
      end

      def share_preview_screen(screen, width, height, _layout) = @share.draw(screen.drawing, width, height)

      # The veil over Home's dots under a screen over Home.
      def page_veil(width, height) = veil(width, height, @context.style::STATS.veil)

      # A game, and after it, Game Over over its pile: the dots over their
      # glow, the effects, the veil and words of Game Over, the clock highlight
      # after the Tutorial, and the HUD until Game Over has arrived.
      def game(width, height, layout)
        @effects.flash(@show.effects, width, height)
        glow
        field
        @effects.scene(@show.effects, dots)
        veil(width, height, @show.game_over&.dim(@show.now).to_f) unless @show.playing?
        @effects.words(@show.effects, layout)
        @game_over.draw(@show.screens.fetch(:game_over).drawing, @show.now) unless @show.playing?
        highlight = @show.clock_highlight
        shown = !@show.game_over&.then { it.entrance(@show.now) >= 1.0 }
        hud = hud_drawing(@show.hud, layout) if highlight || shown
        if highlight
          pill = @hud.bounds(hud)
          @tutorial.clock_highlight_under(highlight, @show.now, pill, @hud.spots(hud), @show.game_flow.game.field.radius)
        end
        hud(hud) if shown
        @tutorial.clock_highlight_over(highlight, @show.now, pill) if highlight
      end

      # A title change's announcement, for the few seconds it shows.
      def announcement(layout) = @group.announcement(@show.group_panel.announcement, @show.now, layout, @show.announcement_y)

      def radius = @show.game_flow.field.radius

      # The Tutorial, drawn as the game it opens is: its dots over their
      # glow and the effects of its taps, its HUD, never shaken, and its
      # spotlight, guide and skip button over them all.
      def tutorial(screen, width, height, layout)
        scene = screen.scene
        @effects.flash(@show.effects, width, height)
        @bloom.glow do
          @dots.glow(scene.dots, scene.animations, scene.now, scene.radius)
          @effects.droplets
        end
        @dots.draw(scene.dots, scene.animations, scene.now, scene.radius)
        @effects.scene(@show.effects, scene.dots)
        @effects.words(@show.effects, layout)
        hud = hud_drawing(scene.hud, layout)
        pill = @hud.bounds(hud)
        spots = @hud.spots(hud)
        @tutorial.under_hud(scene, pill, spots)
        @hud.draw(hud)
        @tutorial.over_hud(screen.drawing, scene, pill, spots)
      end

      # How far the night and the veils must reach to cover every pixel:
      # a unit past Lota's dimensions. Those are whole units, rounded
      # down, while the drawable may be a fraction of a unit wider: on an
      # iPhone 13 mini turned landscape it is 2338 pixels at a scale of
      # 2.88, 811.8 units, which Lota calls 811, and a night that stopped
      # there left the last two columns of pixels undrawn.
      def cover
        width, height = G.dimensions
        [width + 1, height + 1]
      end

      def field
        game = @show.game_flow.game or return
        @dots.draw(dots, @show.animations, @show.now, game.field.radius)
      end

      # The bright dots' and droplets' light, on the night under every dot,
      # so it never washes out a dot or hints at a bright dot that is
      # covered.
      def glow
        game = @show.game_flow.game or return
        @bloom.glow do
          @dots.glow(dots, @show.animations, @show.now, game.field.radius)
          @effects.droplets
        end
      end

      # The game's dots where they are drawn: where the rules put them, or
      # after time's up, wherever they have tumbled to in the Pile.
      def dots = @pile.stack || @show.game_flow.game&.dots

      # The score and clock, on top of everything, until Game Over has
      # arrived, so a game ended by a mistake is seen to reach 0; Game
      # Over then shows the score itself. After a mistake
      # the HUD shakes, by whole device pixels; the dots never do, since a
      # tap is judged where a dot really is.
      def hud(drawing)
        pixels = @context.pixels
        G.push do
          G.translate(pixels.snap(@show.effects.shake_x), pixels.snap(@show.effects.shake_y))
          @hud.draw(drawing)
        end
      end

      # What the HUD painter draws for +hud+ (Presentation::HudDrawing), laid
      # out for +layout+ at the screen's density.
      def hud_drawing(hud, layout) = @huds.call(hud, layout, @context.pixels.scale)

      public

      # Makes the fonts a frame may need, so the first pop or tick of a
      # game does not stall on making one, and clears each frame to the
      # night's darkest ink, so a pixel nothing draws is never black or
      # another color.
      def prepare
        G.background_color = @context.palette.ink_edge.to_a
        @scene.bake(@context.art)
        @splash.refresh
        @hud.prepare(@show.layout)
      end

      def backdrop(width, height)
        return G.clear(0, 0, 1, 1) if @diagnostic
        return @scene.draw if @scene.on?
        return flat_backdrop(width, height) unless @context.shader?(:backdrop)

        @context.shading(:backdrop) do |shader|
          @context.uniform(shader, "size", [width.to_f, height.to_f])
          G.color = [1, 1, 1, 1]
          @context.square(width / 2.0, height / 2.0, width / 2.0, height / 2.0)
        end
      end

      # Without its shader, the night is bands from top to bottom.
      def flat_backdrop(width, height)
        palette = @context.palette
        bands = 16
        bands.times do |i|
          @context.color(palette.ink_top.mix(palette.ink_bottom, i / (bands - 1.0)))
          G.rectangle(:fill, 0, height * i / bands, width, (height / bands.to_f) + 1)
        end
      end

      # The ink drawn over dots that are only scenery.
      def veil(width, height, alpha)
        return if alpha <= 0.0

        @context.color(@context.palette.ink_bottom, alpha)
        G.rectangle(:fill, 0, 0, width, height)
      end
    end
  end
end
