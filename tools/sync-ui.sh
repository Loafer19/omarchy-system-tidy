#!/usr/bin/env bash
# sync-ui.sh — vendor omarchy-yoyo-ui into this plugin (vendor/yoyo-ui/).
#
# Copy this file to <plugin>/tools/sync-ui.sh. It always works on the plugin
# root (the parent of the directory it lives in).
#
#   tools/sync-ui.sh <ref>            vendor <ref> (tag such as v0.1.0, or a commit)
#   tools/sync-ui.sh --check          fail if vendor/yoyo-ui was edited by hand
#   tools/sync-ui.sh --check-upstream like --check, and also compare the files
#                                     with the pinned commit upstream (network)
#
# YOYO_UI_REPO overrides the source (URL or local path); default is
# https://github.com/Loafer19/omarchy-yoyo-ui.git
set -euo pipefail

repo=${YOYO_UI_REPO:-https://github.com/Loafer19/omarchy-yoyo-ui.git}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dest="$root/vendor/yoyo-ui"

die() { echo "sync-ui: $*" >&2; exit 1; }

# sha256 of every vendored file except VERSION / MANIFEST, sorted, relative paths.
manifest() {
  (cd "$1" && find . -type f ! -name VERSION ! -name MANIFEST -printf '%P\n' | LC_ALL=C sort |
    while IFS= read -r f; do sha256sum -- "$f"; done)
}

fetch() { # fetch REF DIR -> checks REF out in DIR (needs ui/)
  git clone --quiet --no-checkout -- "$repo" "$2" 2>/dev/null || die "cannot clone $repo"
  git -C "$2" -c advice.detachedHead=false checkout --quiet "$1" 2>/dev/null || die "no such ref: $1"
  [ -f "$2/ui/qmldir" ] || die "$1 has no ui/qmldir"
}

check() {
  if ! { [ -f "$dest/VERSION" ] && [ -f "$dest/MANIFEST" ]; }; then
    die "vendor/yoyo-ui is missing or was not created by sync-ui.sh"
  fi
  if ! diff -u "$dest/MANIFEST" <(manifest "$dest") >&2; then
    die "vendor/yoyo-ui differs from its MANIFEST: it was edited by hand. Change omarchy-yoyo-ui upstream and re-run tools/sync-ui.sh <ref>."
  fi
  echo "sync-ui: vendor/yoyo-ui OK ($(sed -n 's/^ref //p' "$dest/VERSION") $(sed -n 's/^commit //p' "$dest/VERSION" | cut -c1-12))"
}

case "${1:-}" in
  ""|-h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --check) check ;;
  --check-upstream)
    check
    commit=$(sed -n 's/^commit //p' "$dest/VERSION")
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    fetch "$commit" "$tmp/src"
    diff -u <(manifest "$tmp/src/ui") "$dest/MANIFEST" >&2 || die "vendor/yoyo-ui does not match upstream commit $commit"
    echo "sync-ui: matches upstream $commit" ;;
  -*) die "unknown option $1" ;;
  *)
    ref=$1
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    fetch "$ref" "$tmp/src"
    commit=$(git -C "$tmp/src" rev-parse HEAD)
    rm -rf "$dest"; mkdir -p "$dest"
    cp -R "$tmp/src/ui/." "$dest/"
    printf 'ref %s\ncommit %s\nrepo %s\n' "$ref" "$commit" "$repo" > "$dest/VERSION"
    manifest "$dest" > "$dest/MANIFEST"
    echo "sync-ui: vendored $ref ($commit) into vendor/yoyo-ui"
    check ;;
esac
