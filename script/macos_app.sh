#!/bin/bash
# Fuses the macOS app the commit at HEAD makes for one channel, and checks
# it as CI's Package workflow checks its own, on any Mac with Apple
# silicon, Xcode's command line tools and the game's Ruby:
#
#   script/macos_app.sh [test|mac-app-store|website] [--version VERSION] [--out DIR]
#
#   test           the playtest build (the Package workflow's macOS job, and
#                  the Kits workflow's): fuses it, unpacks the .tar.gz, and
#                  checks the app's Info.plist and program and the .dmg.
#   mac-app-store  the Mac App Store's build: stamps the channel, fuses,
#                  builds the store helper (macos/store) with swiftc and
#                  runs its --check, signs the helper and then the app ad hoc
#                  with the sandbox's entitlements, verifies the signature,
#                  runs script/check_build.rb and script/channel_contents.rb
#                  check on the app, and makes the unsigned store package.
#   website        the website's build: stamps the channel, fuses, and runs
#                  check_build.rb and channel_contents.rb check on the app in
#                  the .tar.gz and on the one in the .dmg (mounted read-only,
#                  out of sight).
#
# It does not play the app, which needs a screen: CI's jobs play each one
# after the push (PACKAGING.md, What CI checks). --version is the version
# the app must be (fledge.yml's by default); --out keeps what was built
# (the .dmg and .tar.gz, and the store package) in DIR.
#
# What is fused is the commit at HEAD (git archive), as a checkout in CI
# holds it, never other files in the working copy, in a folder of its own
# that is deleted at the end. Lota's gem comes from vendor/cache, checked
# against the checksum Gemfile.lock pins for it, and is installed in that
# folder too (CI checks the same gem against Lota's release). `lota fuse`
# leaves out what PackagedApp.excludes says, the list the fuse action's is
# held to (test/packaged_app_test.rb). Like any `lota fuse`, a first run
# needs the network. Written for macOS's own bash 3.2 and tools.
set -euo pipefail

channel=test version= out=
while [ $# -gt 0 ]; do
  case $1 in
    test | mac-app-store | website) channel=$1 ;;
    --version) version=${2:?--version needs a VERSION}; shift ;;
    --out) out=${2:?--out needs a DIR}; shift ;;
    *) echo "usage: script/macos_app.sh [test|mac-app-store|website] [--version VERSION] [--out DIR]" >&2; exit 2 ;;
  esac
  shift
done
[ "$(uname -s)-$(uname -m)" = Darwin-arm64 ] || { echo "script/macos_app.sh builds the arm64 macOS app, on a Mac with Apple silicon" >&2; exit 2; }
case $out in "" | /*) ;; *) out=$(pwd)/$out ;; esac

repo=$(cd "$(dirname "$0")/.." && pwd)
platform=arm64-darwin
identifier=com.setdef.DotPopper
work=$(mktemp -d "${TMPDIR:-/tmp}/dot_popper-macos-app.XXXXXX")
mount=
cleanup() {
  if [ -n "$mount" ]; then hdiutil detach "$mount" > /dev/null 2>&1 || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
started=$(date +%s)
say() { echo "[$(($(date +%s) - started)) s] $*"; }

src=$work/src fuse=$work/fuse
mkdir -p "$src"
git -C "$repo" archive HEAD | tar -x -C "$src"
cd "$src"
say "commit $(git -C "$repo" rev-parse --short HEAD), channel $channel, macOS $(sw_vers -productVersion), $(ruby -v | cut -d' ' -f1-2)"

# Lota's gem for this platform, as Gemfile.lock pins it.
lota_version=$(sed -n "s/^  lota (\([^)-]*\)-$platform) sha256=.*/\1/p" Gemfile.lock)
pinned=$(sed -n "s/^  lota ([^)]*-$platform) sha256=\([0-9a-f]*\)$/\1/p" Gemfile.lock)
[ -n "$pinned" ] || { echo "Gemfile.lock pins no checksum for lota on $platform" >&2; exit 1; }
gem_file=vendor/cache/lota-$lota_version-$platform.gem
[ -f "$gem_file" ] || { echo "$gem_file is missing: it is the gem Gemfile.lock pins" >&2; exit 1; }
have=$(shasum -a 256 "$gem_file" | cut -d' ' -f1)
[ "$have" = "$pinned" ] || { echo "$gem_file is not the gem Gemfile.lock pins (sha256 $have, pinned $pinned)" >&2; exit 1; }
export GEM_HOME=$work/gems
GEM_PATH=$GEM_HOME:$(ruby -e 'print Gem.path.join(":")')
export GEM_PATH
gem install --local --no-document "$gem_file" > /dev/null
say "Lota $lota_version's gem, as Gemfile.lock pins it"

[ -n "$version" ] || version=$(ruby -ryaml -e 'print YAML.load_file("fledge.yml").fetch("version")')
[ "$channel" = test ] || ruby script/set_build_channel.rb "$channel"
excludes=()
for path in $(ruby -r./script/packaged_app -e 'puts PackagedApp.excludes(ARGV[0])' "$channel"); do
  excludes+=(--exclude "$path")
done
app_version=$(ruby -ryaml -e 'print YAML.load_file("fledge.yml").fetch("version")')
# The Fledge Gemfile.lock pins, as the fuse action names it.
LOTA_FLEDGE_REF=$(ruby -r./script/packaged_app -e 'print PackagedApp.fledge_ref')
export LOTA_FLEDGE_REF
say "Fledge $LOTA_FLEDGE_REF"
ruby "$GEM_HOME/bin/lota" fuse . "${excludes[@]}" --identifier "$identifier" --app-version "$app_version" \
  --icon icons/icon --out "$fuse"
ls -l "$fuse"
say "fused"

unpacked=$work/unpacked
mkdir -p "$unpacked"
tar -xzf "$fuse"/*.tar.gz -C "$unpacked"
app=$(find "$unpacked" -maxdepth 3 -name 'Dot Popper.app' -type d | head -1)
[ -n "$app" ] || { echo "the .tar.gz holds no Dot Popper.app" >&2; exit 1; }
check_plist() {
  local got
  got=$(plutil -extract "$1" raw "$app/Contents/Info.plist")
  [ "$got" = "$2" ] || { echo "the app's $1 is $got, not $2" >&2; exit 1; }
}
check_plist CFBundleIdentifier "$identifier"
check_plist CFBundleShortVersionString "$version"
[ -x "$app/Contents/MacOS/Dot Popper" ] || { echo "the app has no program" >&2; exit 1; }
ls "$fuse"/*.dmg > /dev/null
say "the app is $identifier $version"

check() { ruby script/check_build.rb "$channel" "$version" "$1" && ruby script/channel_contents.rb check "$channel" "$1"; }
case $channel in
  mac-app-store)
    mkdir -p "$app/Contents/Helpers"
    helper="$app/Contents/Helpers/dot-popper-store"
    xcrun swiftc -O -target arm64-apple-macos13 \
      -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker macos/store/Info.plist \
      -o "$helper" macos/store/main.swift
    "$helper" --check
    # Inside out, and never --deep: the helper, then the app.
    codesign --force --sign - --identifier com.setdef.DotPopper.store-helper \
      --entitlements macos/store/helper.entitlements "$helper"
    codesign --force --sign - --entitlements macos/store/app.entitlements "$app"
    codesign --verify --strict --verbose=2 "$app"
    say "the store helper is built and checked, and it and the app are signed for the sandbox"
    check "$unpacked"
    mkdir -p "$work/pkg"
    productbuild --component "$app" /Applications "$work/pkg/Dot-Popper-$version-mac-app-store-unsigned.pkg"
    ls -l "$work/pkg"
    ;;
  website)
    check "$unpacked"
    mount=$work/dmg
    hdiutil attach -nobrowse -readonly -mountpoint "$mount" "$fuse"/*.dmg > /dev/null
    check "$mount"
    hdiutil detach "$mount" > /dev/null
    mount=
    ;;
esac
say "checked"

if [ -n "$out" ]; then
  mkdir -p "$out"
  cp "$fuse"/*.dmg "$fuse"/*.tar.gz "$out/"
  if [ -d "$work/pkg" ]; then cp "$work/pkg"/*.pkg "$out/"; fi
  ls -l "$out"
fi
say "script/macos_app.sh: the $channel build passed (not played: CI plays it)"
