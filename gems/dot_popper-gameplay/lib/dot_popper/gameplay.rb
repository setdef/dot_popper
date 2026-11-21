# frozen_string_literal: true

require "date"
require "dot_popper/network"
require "dot_popper/memory_file"

module DotPopper
  # Gameplay and Metagame, the core of the domain: playing and learning
  # to play (the rules, a game and the flow from Home to Game Over, with
  # the events it announces), Stats and records, achievements and
  # today's goal, friend groups and the title with the server that keeps
  # them, themes and their release, and what is saved on the device. It
  # names nothing of Monetization or Release Engineering, so the rules of
  # play never know that Pro exists, and nothing of the use cases, the
  # screens or the shell; of the code the areas share (the gem
  # dot_popper-shared, which this gem's gemspec names) it uses the network
  # client (test/areas_test.rb). None of it touches Lota.
  module Gameplay
  end
end

# The area's files, in this gem (gems/dot_popper-gameplay, which the
# game's Gemfile names by its path): the rules of a game, the game and
# its events, a game's numbers, the score record and Stats with today's
# goal and its streak, and the achievements, each with its save file's
# format, the themes a player has with what Gameplay hears of setdef,
# clearing Stats, the games log, the flow from Home to Game Over and when
# to ask the server again, friend groups' client and the server it uses,
# and the server's releases of themes.
%w[rules visibility field size_class dot_size dot_sizing dot touch_target spawn_check spawn spawner clock
   stack events game score_record_file score_record game_stats daily_goal goal_streak stats stats_file saved_stats
   achievement achievement_recorder achievements_file achievements theme setdef themes_file
   saved_themes stats_backup games_log game_flow refresh groups theme_releases
   server_choice].each { require_relative "gameplay/#{it}" }
