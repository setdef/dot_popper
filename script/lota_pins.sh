#!/usr/bin/env bash
# Prints the Lota and Fledge that Gemfile.lock pins, as the tags the phone
# builds clone and ask for, one per line:
#
#   LOTA_REF=v0.7.1
#   FLEDGE_TAG=v0.16.0
#
# script/android_build.sh and script/android_check.sh take their defaults
# from here, so a Lota or Fledge upgrade changes the Gemfile and its
# lockfile, and the phone builds follow. It fails, saying why, when the
# lockfile locks no Lota gem or no tagged Fledge.
set -euo pipefail

lock=${1:-$(cd "$(dirname "$0")/.." && pwd)/Gemfile.lock}
lota=$(sed -n 's/^    lota (\([0-9][0-9A-Za-z.]*\)\(-[^)]*\)\{0,1\})$/\1/p' "$lock" | sort -u)
fledge=$(awk '/^GIT$/ { git = 1; remote = ""; next } /^[^ ]/ { git = 0 }
  git && /^  remote: / { remote = $2 }
  git && remote ~ /\/Fledge$/ && /^  tag: / { print $2 }' "$lock" | sort -u)
[ "$(printf '%s\n' "$lota" | grep -c .)" = 1 ] || { echo "lota_pins.sh: $lock locks no single Lota version (${lota:-none})" >&2; exit 1; }
[ "$(printf '%s\n' "$fledge" | grep -c .)" = 1 ] || { echo "lota_pins.sh: $lock locks no single tagged Fledge (${fledge:-none})" >&2; exit 1; }
echo "LOTA_REF=v$lota"
echo "FLEDGE_TAG=$fledge"
