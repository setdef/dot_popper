# frozen_string_literal: true

module DotPopper
  module Gameplay
    # What themes.txt holds, three lines of keys: the themes +released+ to
    # this device ("unlocked: ghost eclipse", the word saved before themes
    # were said to be released, kept so every saved file reads), those
    # +told+ ("told: ghost"), and the one +chosen+ ("chosen: ghost"). Read
    # leniently: a line without a colon is left out, and a line missing
    # reads as none.
    class ThemesFile < Data.define(:released, :told, :chosen)
      RELEASED = "unlocked"
      TOLD = "told"
      CHOSEN = "chosen"

      def self.parse(text)
        lines = text.to_s.lines.filter_map { it.split(":", 2).map(&:strip) if it.include?(":") }.to_h
        new(released: keys(lines.fetch(RELEASED, "")), told: keys(lines.fetch(TOLD, "")), chosen: lines[CHOSEN]&.to_sym)
      end

      def self.keys(line) = line.split.map(&:to_sym)

      private_class_method :keys

      def to_s = "#{RELEASED}: #{released.join(" ")}\n#{TOLD}: #{told.join(" ")}\n#{CHOSEN}: #{chosen}\n"
    end
  end
end
