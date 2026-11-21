#!/bin/bash
# Builds the iPhone and iPad app the commit at HEAD makes, unsigned, as the
# Kits workflow builds it, on a Mac with Xcode, the game's Ruby and the
# iOS build's tools (mise.ios.toml):
#
#   MISE_ENV=ios mise install                       # once: XcodeGen, CMake and Ninja
#   MISE_ENV=ios mise exec -- script/ios_app.sh [--out DIR]
#
# It takes Lota's phone route (Lota's doc/guide/phones.md) as the Kits
# workflow's iPad job does: Lota's source at the tag of the Lota that
# Gemfile.lock pins (script/lota_pins.sh), SDL3 built for iOS with its
# rake ios:sdl3, the phone project laid out with the game's files less
# what only the repository needs, Lota's notices, and `fledge build ios`
# with the Fledge that Gemfile.lock pins; then it makes that job's checks that the project
# stands on its own. Then it builds the project as the Simulator job does,
# with Xcode and no signing: Debug for the Simulator, and Debug and Release
# for devices, each checked for its privacy manifest and Lota's notices.
# --out DIR keeps the unsigned Debug app for devices, zipped with ditto,
# and BUILD.txt, which says what it was built from.
#
# It signs nothing and runs nothing: CI's Simulator job plays the app.
# Lota's clone with SDL3 built is kept in
# ${XDG_CACHE_HOME:-~/.cache}/dot_popper/ios-lota, one for each Lota
# version, so only the first build takes long; everything else is built
# in a temporary folder that is deleted at the end. Like the workflow, it
# needs the network: GitHub for Lota and Fledge, RubyGems.org for their
# gems. Written for macOS's own bash 3.2 and tools.
set -euo pipefail

out=
while [ $# -gt 0 ]; do
  case $1 in
    --out) out=${2:?--out needs a DIR}; shift ;;
    *) echo "usage: script/ios_app.sh [--out DIR]" >&2; exit 2 ;;
  esac
  shift
done
[ "$(uname -s)" = Darwin ] || { echo "script/ios_app.sh builds the iOS app on a Mac" >&2; exit 2; }
for tool in xcodebuild xcodegen cmake ninja; do
  command -v "$tool" > /dev/null || { echo "no $tool here: MISE_ENV=ios mise install (mise.ios.toml), and Xcode" >&2; exit 2; }
done
case $out in "" | /*) ;; *) out=$(pwd)/$out ;; esac

repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"
app_name=DotPopper
pins=$(script/lota_pins.sh)
lota_ref=$(echo "$pins" | sed -n 's/^LOTA_REF=//p')
fledge_tag=$(echo "$pins" | sed -n 's/^FLEDGE_TAG=//p')
unset GEM_HOME GEM_PATH BUNDLE_GEMFILE BUNDLE_PATH RUBYOPT BUNDLE_FROZEN
export ALSOFT_DRIVERS=null

work=$(mktemp -d "${TMPDIR:-/tmp}/dot_popper-ios-app.XXXXXX")
lock=
cleanup() {
  if [ -n "$lock" ]; then rmdir "$lock" 2> /dev/null || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
started=$(date +%s)
say() { echo "[$(($(date +%s) - started)) s] $*"; }
say "commit $(git rev-parse --short HEAD), Lota $lota_ref, Fledge $fledge_tag, $(xcodebuild -version | head -1)," \
  "XcodeGen $(xcodegen --version 2>&1 | tail -1 | sed 's/^Version: //'), $(cmake --version | head -1), Ninja $(ninja --version)"

# Lota at its tag, with SDL3 built for iOS and a folder of only what its
# gem packages (a gem named by its path carries its whole folder into the
# app): made once for each version, one build at a time.
lota=${XDG_CACHE_HOME:-$HOME/.cache}/dot_popper/ios-lota/$lota_ref
mkdir -p "$(dirname "$lota")"
until mkdir "$lota.lock" 2> /dev/null; do
  # A lock older than two hours is a build that died.
  if [ -n "$(find "$lota.lock" -maxdepth 0 -mmin +120 2> /dev/null)" ]; then rmdir "$lota.lock" 2> /dev/null || true; fi
  sleep 10
done
lock=$lota.lock
if [ ! -f "$lota/.ready" ]; then
  say "building Lota $lota_ref for iOS into $lota (once)"
  rm -rf "$lota"
  git clone --quiet --depth 1 --branch "$lota_ref" https://github.com/setdef/Lota.git "$lota"
  git -C "$lota" submodule update --init --depth 1 vendor/love vendor/love-apple-dependencies
  (
    cd "$lota"
    export BUNDLE_PATH=$lota/.bundle-gems
    bundle install --quiet
    bundle exec rake ios:sdl3 > "$work/sdl3.log" 2>&1 || { tail -40 "$work/sdl3.log"; exit 1; }
    mkdir -p tmp/phone
    gem build lota.gemspec --output tmp/phone/lota.gem > /dev/null
    gem unpack tmp/phone/lota.gem --target tmp/phone > /dev/null
    gem specification tmp/phone/lota.gem --ruby > tmp/phone/lota/lota.gemspec
  )
  touch "$lota/.ready"
fi
rmdir "$lock"
lock=
lota_bundle() { (cd "$lota" && BUNDLE_PATH=$lota/.bundle-gems bundle "$@"); }
rice=$(lota_bundle info rice --path)
say "Lota $lota_ref is $(git -C "$lota" rev-parse --short HEAD)"

# The phone project of Lota's guide, as the Kits workflow lays it out:
# everything in it but the hosts goes into the app, so the game's copy
# leaves out what only the repository needs, and Dot Popper's ios/host
# goes over Lota's iOS host from the gem.
phone=$work/phone
game=$phone/game/dot_popper
mkdir -p "$game"
git archive HEAD | tar -x -C "$game"
(cd "$game" && rm -rf .github vendor android ios macos windows test doc playtest script sig server Steepfile Rakefile \
  Gemfile Gemfile.lock mise.toml mise.lock mise.android.toml mise.ios.toml .ruby-version AGENTS.md GLOSSARY.md INSIPIRATION.md PACKAGING.md README.md .gitignore .gitattributes \
  gems/dot_popper-gameplay/sig gems/dot_popper-gameplay/test gems/dot_popper-gameplay/Rakefile gems/dot_popper-gameplay/Steepfile \
  gems/dot_popper-shared/sig gems/dot_popper-shared/test gems/dot_popper-shared/Rakefile gems/dot_popper-shared/Steepfile)
cp -R "$lota/tmp/phone/lota/ext/lota/phone/host" "$phone/host"
rm -rf "$phone/host/android"
cp -R ios/host/. "$phone/host/ios/"
cat > "$phone/main.rb" << 'EOF'
# frozen_string_literal: true

# Written by script/ios_app.sh: starts the game's copy as its own program does.
load File.join(__dir__, "game", "dot_popper", "bin", "dot_popper")
EOF
lota_bundle exec rake "ios:notices[$phone]" > /dev/null
grep -q . "$phone/NOTICES.txt"
cat > "$phone/Gemfile" << EOF
# frozen_string_literal: true

# Written by script/ios_app.sh for fledge build ios.
source "https://rubygems.org"

gem "lota", path: "$lota/tmp/phone/lota"
# The game's own gems, in the game's copy (PACKAGING.md).
gem "dot_popper-shared", path: "game/dot_popper/gems/dot_popper-shared"
gem "dot_popper-gameplay", path: "game/dot_popper/gems/dot_popper-gameplay"
EOF
# Fledge runs from a Gemfile of its own, outside the phone project, and
# builds the project by its path (Fledge's README, "Installation"), so
# the app carries no Fledge.
tools=$work/fledge
mkdir -p "$tools"
cat > "$tools/Gemfile" << EOF
# frozen_string_literal: true

# Written by script/ios_app.sh: Fledge alone, to build the phone project.
source "https://rubygems.org"

gem "fledge", git: "https://github.com/setdef/Fledge", tag: "$fledge_tag"
EOF
APP_NAME=$app_name ruby -ryaml -e '
  source = YAML.load_file("fledge.yml")
  program = source.fetch("programs").first
  config = {
    "name" => ENV.fetch("APP_NAME"),
    "identifier" => program.fetch("identifier"),
    "version" => source.fetch("version"),
    "icon" => File.join("game/dot_popper", program.fetch("icon")),
    "ios" => { "host" => "host/ios" }
  }
  File.write(ARGV[0], "# Written by script/ios_app.sh for fledge build ios, from fledge.yml.\n" + YAML.dump(config))
' "$phone/fledge.yml"
say "laid out the phone project"

(
  cd "$phone"
  export BUNDLE_GEMFILE=$phone/Gemfile BUNDLE_PATH=$work/app-bundle XDG_CACHE_HOME=$work/cache
  bundle config set --local build.lota "--with-lota-source=$lota --with-lota-sdl3=$lota/tmp/ios/sdl3 --with-rice-dir=$rice" > /dev/null
  bundle lock --add-platform ruby > /dev/null
  bundle install --quiet
  BUNDLE_GEMFILE=$tools/Gemfile bundle install --quiet
  BUNDLE_GEMFILE=$tools/Gemfile bundle exec fledge build ios --out "$phone/dist" "$phone" > "$work/fledge.log" 2>&1 ||
    { tail -60 "$work/fledge.log"; exit 1; }
)
project=$phone/dist/$app_name-ios
say "fledge build ios wrote $project"

# The Kits workflow's checks that the project stands on its own.
if grep -rIl -e "$work" -e "$repo" -e "$HOME" "$project/project.yml" "$project/$app_name.xcodeproj" "$project/Host" \
  "$project/fledge/fledge.cfg"; then
  echo "the project names a path on this computer" >&2
  exit 1
fi
expect() { "$@" || { echo "the project fails: $*" >&2; exit 1; }; }
expect [ "$(plutil -extract LotaAudioSessionCategory raw "$project/Host/Info.plist")" = ambient ]
expect [ "$(plutil -extract CFBundleDisplayName raw "$project/Host/Info.plist")" = "Dot Popper" ]
expect grep -q SDL_ACCELEROMETER_AS_JOYSTICK "$project/Host/main.m"
expect grep -q "0x0c / 255.0 green:0x0b / 255.0 blue:0x22" "$project/Host/main.m"
expect grep -q "AppStore.sync" "$project/Host/Store.swift"
expect grep -q 'TARGETED_DEVICE_FAMILY: "1,2"' "$project/project.yml"
say "the project stands on its own"

# As the Simulator job builds it, with no signing.
derived=$work/derived
for build in Debug:iphonesimulator Debug:iphoneos Release:iphoneos; do
  configuration=${build%%:*} sdk=${build#*:}
  log=$work/xcodebuild-$configuration-$sdk.log
  (cd "$project" && xcodebuild -project "$app_name.xcodeproj" -scheme "$app_name" -configuration "$configuration" -sdk "$sdk" \
    -derivedDataPath "$derived" build CODE_SIGNING_ALLOWED=NO > "$log" 2>&1) || { tail -80 "$log"; exit 1; }
  app=$derived/Build/Products/$configuration-$sdk/$app_name.app
  plutil -lint "$app/PrivacyInfo.xcprivacy" > /dev/null
  notices=$(find "$app" -name NOTICES.txt | head -1)
  expect [ -n "$notices" ]
  expect grep -q "^FreeType " "$notices"
  expect grep -q "^==== AGPL-3.0-or-later ====" "$notices"
  if grep -q "OpenAL Soft" "$notices"; then echo "the notices name OpenAL Soft, which the iOS app does not carry" >&2; exit 1; fi
  say "built $configuration for $sdk"
done

if [ -n "$out" ]; then
  mkdir -p "$out"
  ditto -c -k --keepParent "$derived/Build/Products/Debug-iphoneos/$app_name.app" "$out/$app_name-Debug-iphoneos.zip"
  {
    echo "Dot Popper, commit $(git rev-parse HEAD), unsigned"
    echo "Lota $lota_ref ($(git -C "$lota" rev-parse HEAD)), Fledge $fledge_tag"
    echo "Built $(date -u +%Y-%m-%d) with $(xcodebuild -version | tr '\n' ' ')on macOS $(sw_vers -productVersion)"
  } > "$out/BUILD.txt"
  ls -l "$out"
fi
say "script/ios_app.sh: built and checked, unsigned (not played: CI's Simulator job plays it)"
