# frozen_string_literal: true

# The rules of Dot Popper: dots, scoring, the clock, and the flow from
# Home to Game Over. Nothing here draws, plays sounds, or reads input, so
# all of it runs, and is tested, without a window.
require "date"

module DotPopper
end

require_relative "dot_popper/build"
require_relative "dot_popper/platform"
require_relative "dot_popper/automation"
require_relative "dot_popper/gameplay/rules"
require_relative "dot_popper/receipt"
require_relative "dot_popper/monetization/entitlement"
require_relative "dot_popper/store"
require_relative "dot_popper/website_store"
require_relative "dot_popper/gameplay/visibility"
require_relative "dot_popper/gameplay/events"
require_relative "dot_popper/gameplay/field"
require_relative "dot_popper/gameplay/size_class"
require_relative "dot_popper/gameplay/dot_size"
require_relative "dot_popper/gameplay/dot_sizing"
require_relative "dot_popper/gameplay/dot"
require_relative "dot_popper/gameplay/touch_target"
require_relative "dot_popper/gameplay/spawn_check"
require_relative "dot_popper/gameplay/spawn"
require_relative "dot_popper/gameplay/spawner"
require_relative "dot_popper/gameplay/clock"
require_relative "dot_popper/gameplay/stack"
require_relative "dot_popper/gameplay/game"
require_relative "dot_popper/gameplay/score_record"
require_relative "dot_popper/monetization/free_games"
require_relative "dot_popper/gameplay/game_stats"
require_relative "dot_popper/gameplay/daily_goal"
require_relative "dot_popper/gameplay/goal_streak"
require_relative "dot_popper/gameplay/stats"
require_relative "dot_popper/gameplay/saved_stats"
require_relative "dot_popper/gameplay/achievement"
require_relative "dot_popper/gameplay/achievement_recorder"
require_relative "dot_popper/gameplay/achievements"
require_relative "dot_popper/gameplay/stats_backup"
require_relative "dot_popper/gameplay/theme"
require_relative "dot_popper/gameplay/saved_themes"
require_relative "dot_popper/gameplay/games_log"
require_relative "dot_popper/gameplay/game_flow"
require_relative "dot_popper/gameplay/refresh"
require_relative "dot_popper/network"
require_relative "dot_popper/gameplay/groups"
require_relative "dot_popper/continuity"
DotPopper::Build::PARTS.each { require_relative "dot_popper/#{it}/core" }
require_relative "dot_popper/gameplay/theme_releases"
require_relative "dot_popper/gameplay/server_choice"
