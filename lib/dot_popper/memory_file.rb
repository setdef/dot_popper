# frozen_string_literal: true

module DotPopper
  # A save file kept in memory: what every object that keeps something
  # saved reads and writes in tests, and in the game where nothing is to
  # be kept on the device (a store build's license key, friend groups
  # with no server). It answers as Shell::SaveFile does. It is technical
  # code that both areas use, and belongs to neither.
  class MemoryFile
    def initialize(text = nil) = @text = text
    def read = @text
    def write(text) = @text = text
    def remove = @text = nil
  end
end
