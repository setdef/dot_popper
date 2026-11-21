# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The offer of Pro, over the screen it was opened from (OfferLayout):
      # Buy, a second action, and Back. It asks everything of +buy_pro+
      # (UseCases::BuyPro): it sells through it, shows what it says of the
      # store, and thanks the player once it says they have Pro. The second
      # action is the one the build's store comes with (+offer_second+, which
      # the composition root chooses for the store), or Restore Purchases
      # (RestorePurchases): the button, its words, its controller button
      # and keys, and what the status line says of it.
      class Offer < Screen
        # The second action of a store's copy: Restore Purchases, with no
        # keys of its own and nothing of its own to say.
        class RestorePurchases
          def name = :restore
          def label(words) = words.offer[:restore]
          def press(offer, _sounds) = offer.restore
          def key_bindings = []
          def status(_status) = nil
          def paste(_sounds) = false
          def type(_key) = false
          def typing? = false
        end

        def initialize(show, buy_pro:, view_achievements:, offer_second:)
          super(show)
          @buy_pro = buy_pro
          @view_achievements = view_achievements
          @second = offer_second || RestorePurchases.new
          @focus = nil
          @for_play = false
          @key_hint = nil
        end

        # What it leads with (:themes, :achievements, :groups, :games), or
        # nil when it was not opened by a tap on something Pro has; the
        # achievement a Free player tapped; and whether it was opened by
        # Play with no game left, which it says.
        attr_reader :focus, :achievement, :for_play

        # A Free player tapped something that comes with Pro (+feature+ is
        # :achievements, :themes or :groups): it opens over the screen they
        # are on, leading with it, and Back closes it to that same screen,
        # open as it was, so no one loses their place.
        def open_led_by(feature)
          show.push(self)
          @focus = feature
          @buy_pro.open
          sounds.play(:tick)
        end

        # The achievement a Free player's Get Pro came from, which it leads
        # with.
        def led_by_achievement(id) = @achievement = id

        # Hears the store, +seconds+ on, while no game is in play
        # (UseCases::BuyPro#update).
        def update(seconds) = @buy_pro.update(seconds)

        # Pro arrived (a ProGranted, which the composition root subscribes
        # it to hear): a tick marks a store's purchase landing while
        # it is open. A license key entered has had its own tick as it was
        # pressed.
        def call(granted)
          sounds.play(:tick, pitch: 1.3) if opened? && granted.by == :receipt
        end

        # Opened by Play or Play again with no game left, where Pro is
        # offered: over the screen in view, leading with games, and saying
        # why. It asks the store for the price, or asks again if an earlier
        # request was never answered.
        def open_for_play
          return unless offered?

          @for_play = true
          show.push(self)
          @focus = :games
          @buy_pro.open
          sounds.play(:tick)
        end

        # Back to the screen it was opened over, with a tick unless +quiet+.
        def close(quiet: false)
          @for_play = false
          show.pop(self)
          @focus = nil
          sounds.play(:tick, pitch: 0.8) unless quiet
        end

        # A pointer or a controller took over from the keyboard, or the
        # keyboard was used again: Buy names no key until #key_hint says.
        def input_used(_kind) = @key_hint = nil

        # The words and parts to lay out (OfferLayout), and where they go.
        def screen_layout
          OfferLayout.new(layout:, type: style::TYPE, words:, measure:, offering: !thanking?,
                          note: (words.offer[:no_games] if for_play), focus:, art:,
                          sold: @buy_pro.sold?, second: @second.name)
        end

        def plan = screen_layout.plan

        # Everything its painter draws (OfferDrawing), made again only when
        # what it lays out, its status, Buy's words, a button's light, the
        # themes or the achievement it leads with changes.
        def drawing
          screen = screen_layout
          words = self.words
          hover = show.hover
          status = self.status
          buy = buy_label
          themes = show.themes.reject(&:ordinary?) # every theme but the ordinary, as Pro would give them now
          id = achievement
          earned = id && @view_achievements.earned?(id)
          drawn(screen, words, hover, status, buy, themes, id, earned) do
            offer = words.offer
            OfferDrawing.new(header: HeaderDrawing.for(offer[:heading], layout:, measure:, words:, hover:), plan: screen.plan, focus:,
                             focus_word: screen.focus_word, others: screen.others, status:, buy:, second: @second.name,
                             second_words: @second.label(words), lit: [:buy, @second.name].to_h { [it, hover.level(it)] },
                             themes: themes.map { [it, words.themes.fetch(it.key)] },
                             achievement: id && OfferAchievement.new(id:, name: AchievementWords.name(id), how: AchievementWords.how(id), earned:))
          end
        end

        # How tall its picture of what was tapped is: the themes' cards,
        # the achievement's card, or a feature's sign.
        def art
          case focus
          when :themes then layout.short? ? 64.0 : 100.0
          when :achievements then layout.short? ? 84.0 : 110.0
          else layout.short? ? 40.0 : 56.0
          end
        end

        # The price the store gave, or nil before it has.
        def price = @buy_pro.price

        # What it says of buying, as BuyPro#status answers: thanks once the
        # player has Pro, and otherwise a word only when there is something
        # to say of the store, the second action's own first.
        def status
          status = @buy_pro.status
          @second.status(status) || words.offer.fetch(status, "")
        end

        # Buy's words, with the controller's button that presses it (Y) while
        # a controller is in use, or until a pointer or a controller is
        # used, the keyboard's (#key_hint). Buy's other ways are its own
        # button and Ctrl+B or Cmd+B; none is a press that means continue or
        # back elsewhere.
        def buy_label
          label = price ? format(words.offer[:buy], price) : words.offer[:retry]
          return "#{label} (#{GamepadButtons::LABELS.fetch(BUTTONS.key(:buy))})" if show.input == InputKind::GAMEPAD

          @key_hint ? "#{label} (#{@key_hint})" : label
        end

        # The key that buys, from the offer's own keys (KEY_BINDINGS):
        # "Ctrl+B", or "⌘B" where the system's command key is Cmd
        # (+command_key+).
        def buy_key(command_key:) = KEY_BINDINGS.find { it.does == :buy }.hint(command_key:)

        # Buy's key on a computer's keyboard ("Ctrl+B", or "⌘B" on a Mac),
        # since a key was pressed, or nil since a pointer or a controller was.
        attr_writer :key_hint

        # Buy where the store gave a price, and otherwise the same button's
        # "Try again" (UseCases::BuyPro). Says whether it took the press.
        def buy = @buy_pro.buy

        def restore = @buy_pro.restore

        # The second action, pressed: Restore Purchases, or the store's own.
        def second = @second.press(self, sounds)

        def controls
          plan = self.plan
          name = @second.name
          [(button(:buy, plan[:buy]) if plan.key?(:buy)),
           (button(name, plan[name]) if plan.key?(name)),
           back_button].compact
        end

        # Back: Buy has only its own controls, so no one buys by reflex.
        def primary = close

        def back
          close
          true
        end

        # A controller's buttons here, by what each presses: Y Buy, and X
        # the second action.
        BUTTONS = { y: :buy, x: :second }.freeze

        def pad(button)
          case BUTTONS[button]
          in :second then second
          in :buy then buy
          else nil
          end
        end

        # Ctrl+B or Cmd+B buys: a chord, so no press that means continue or
        # back, and no letter typed into the second action, buys. Then the
        # second action's own keys (none for Restore Purchases), each
        # pressing what it names here (#paste, #type, #typing?).
        def key_bindings = [*KEY_BINDINGS, *@second.key_bindings]
        KEY_BINDINGS = [KeyBinding.new(keys: :b, with: KeyBinding::COMMAND, does: :buy)].freeze

        # The system's paste shortcut, a key typed, and whether something
        # is being typed, as the second action takes them; each says whether
        # it took the key.
        def paste = @second.paste(sounds)
        def type(key) = @second.type(key)
        def typing? = @second.typing?

        def answers = [:buy, @second.name, :back]

        def pressed(name, by)
          case name
          in :buy then buy
          in :back then close
          else second if name == @second.name
          end
        end

        def covers? = true

        private

        # Whether Pro can be offered at all: where there is a store, to a
        # player who has not bought it. The offer's own, so no other screen
        # asks it.
        def offered? = @buy_pro.offered?

        # Whether it thanks the player (BuyPro#status), in place of selling:
        # no buttons but Back, and not opened over what was tapped.
        def thanking? = @buy_pro.status == :thanks
      end
    end
  end
end
