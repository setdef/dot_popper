# frozen_string_literal: true

require "date"
require_relative "network"
require_relative "memory_file"

module DotPopper
  # Gameplay and Metagame, the core of the domain: playing and learning
  # to play (the rules, a game and the flow from Home to Game Over, with
  # the events it announces), Stats and records, achievements and
  # today's goal, friend groups and the title with the server that keeps
  # them, themes and their release, and what is saved on the device. It
  # names nothing of Monetization or Release Engineering, so the rules of
  # play never know that Pro exists, and nothing of the use cases, the
  # screens or the shell; of the code the areas share it uses the network
  # client (test/areas_test.rb). None of it touches Lota.
  module Gameplay
  end
end

# The part of the area that is a gem already, dot_popper-gameplay
# (gems/dot_popper-gameplay, which the Gemfile names by its path).
require "dot_popper/gameplay/visibility"

%w[rules events field size_class dot_size dot_sizing dot
   touch_target spawn_check spawn spawner clock stack game score_record_file score_record
   game_stats daily_goal goal_streak stats stats_file saved_stats achievement achievement_recorder achievements_file achievements
   stats_backup theme setdef themes_file saved_themes games_log game_flow refresh groups theme_releases
   server_choice].each { require_relative "gameplay/#{it}" }
