#!/usr/bin/env bash
# Publishes doc/privacy.json to the server for the tag in $TAG (v0.9.9 etc.).
# Needs PRIVACY_DOCUMENT_TOKEN. PRIVACY_DOCUMENT_URL is for a local stub.
set -euo pipefail

tag="${TAG:?TAG is the tag being published}"
url="${PRIVACY_DOCUMENT_URL:-https://server.dot-popper.setdef.com/privacy_document}"
: "${PRIVACY_DOCUMENT_TOKEN:?PRIVACY_DOCUMENT_TOKEN is not set}"
doc=doc/privacy.json

# Before 1.0.0 the tag names the version, which this stamps into
# fledge.yml and the document, here only, as every build of the tag does
# (script/release_version.rb); from 1.0.0 on it fails unless the tagged
# commit carries the tag's version.
ruby script/release_version.rb stamp "$tag" > /dev/null

# Regenerate, so a stale document cannot be published.
before="$(mktemp)"
cp "$doc" "$before"
bundle exec rake privacy
if ! cmp -s "$before" "$doc"; then
  echo "::error::$doc is stale: regenerating it changed it. Run bundle exec rake privacy, commit it, and tag again."
  diff -u "$before" "$doc" || true
  exit 1
fi

version="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).fetch("game_version")' "$doc")"
if [ "$version" != "${tag#v}" ]; then
  echo "::error::game_version is $version but the tag is $tag"
  exit 1
fi

body="$(mktemp)"
status="$(curl --silent --show-error --output "$body" --write-out '%{http_code}' \
  --request PUT "$url" \
  --header "Authorization: Bearer $PRIVACY_DOCUMENT_TOKEN" \
  --header 'Content-Type: application/json' \
  --data-binary "@$doc")"

case "$status" in
  201) echo "Published the privacy document for $tag (new)." ;;
  200) echo "The server already has this privacy document for $tag." ;;
  *)
    echo "::error::The server answered $status"
    cat "$body"
    echo
    exit 1
    ;;
esac
