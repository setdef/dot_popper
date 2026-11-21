# frozen_string_literal: true

module DotPopper
  module Gameplay
    # Friend groups, from the game's side: a Session that knows who this
    # player is and what their group looks like, and talks to the server
    # through a Network::Link on a Network::Worker's thread. None of it touches Lota.
    module Groups
    end
  end
end

%w[requests join_code group group_file unsent known_groups jobs session].each { require_relative "groups/#{it}" }
