# frozen_string_literal: true

require "minitest/autorun"

# The gem's tests load the gem alone, with nothing of the game and no
# other gem of the game's, so a file here that needs any of it fails to
# load. What a build obeys with the rest of the game loaded (the server,
# automated runs) is tested in the game's test/release_engineering/.
require "dot_popper/release_engineering"
