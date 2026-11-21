# frozen_string_literal: true

module DotPopper
  module ReleaseEngineering
    # What kind of build this is, fixed when the app is built and never by
    # anything a player can set at run time: not an environment variable, a
    # file, or an argument. A build with a channel trusts only setdef's
    # keys, sells through its channel's store, and ignores each developer
    # setting that could grant Pro, change the server, or skip the free-game
    # limit (ADR-0010).
    module Build
      # The channel this build is sold through, one of CHANNEL_NAMES:
      # script/set_build_channel.rb sets it in each build for sale, and the
      # release checks that the app it built has it (script/check_build.rb).
      CHANNEL = nil

      # The folders of code only some builds carry (lib/dot_popper/PART), each
      # loaded by lib/dot_popper.rb: in the repository every one; in a build
      # for sale only its own channel's, set with CHANNEL
      # by script/set_build_channel.rb, so it holds none of another's.
      PARTS = %w[website test_build].freeze

      # The names of the channels a build can be sold through (CHANNELS).
      APP_STORE = "app-store"
      MAC_APP_STORE = "mac-app-store"
      GOOGLE_PLAY = "google-play"
      MICROSOFT_STORE = "microsoft-store"
      WEBSITE = "website"

      PREFIX = "DOT_POPPER_"

      # The developer settings a store build still obeys, since none of them
      # touches a purchase, Pro, the server, the date or the free games: how
      # the window and graphics start, calm and diagnostic aids, a repeatable
      # seed, the tutorial, and the bot and screenshots (an automated run of
      # a store build still meters its free games and sells through its
      # channel). Every other DOT_POPPER_* setting, known or not yet written,
      # is inert in a store build.
      HARMLESS = %w[
        AUTOPLAY CALM DIAGNOSTIC_COLORS FAKE_DRAG FAKE_GAMEPAD FAKE_TILT FULLSCREEN
        NO_SHADERS NO_SPLASH NO_TUTORIAL NO_VULKAN PERF QUIT_AFTER RENDERERS SEED
        SHOTS TUTORIAL WINDOW
      ].map { "#{PREFIX}#{it}" }.freeze

      def self.store?(channel = CHANNEL) = !channel.nil?

      # A channel a build can be sold through: its +name+, whether it is an
      # app store's (+store+) or setdef's website, for copies no store
      # controls, and the +parts+ its build carries, which
      # script/set_build_channel.rb stamps into PARTS.
      class Channel < Data.define(:name, :store, :parts); end

      # Every channel, by name: the one list of them, which the scripts and
      # the composition root take from here.
      NO_PARTS = ([] #: Array[String]
                 ).freeze
      CHANNELS = [
        Channel.new(name: APP_STORE, store: true, parts: NO_PARTS),
        Channel.new(name: MAC_APP_STORE, store: true, parts: NO_PARTS),
        Channel.new(name: GOOGLE_PLAY, store: true, parts: NO_PARTS),
        Channel.new(name: MICROSOFT_STORE, store: true, parts: NO_PARTS),
        Channel.new(name: WEBSITE, store: false, parts: %w[website].freeze)
      ].to_h { [it.name, it] }.freeze

      # The channels of the app stores, and every channel's name.
      STORES = CHANNELS.values.select(&:store).map(&:name).freeze
      CHANNEL_NAMES = CHANNELS.keys.freeze

      # +env+ as this build lets it be read: with a channel, without the
      # developer settings that affect purchases,
      # Pro or the server.
      def self.settings(env = ENV, channel: CHANNEL)
        return env unless store?(channel)

        env.to_h.reject { |name, _| name.start_with?(PREFIX) && !HARMLESS.include?(name) }
      end
    end
  end
end
