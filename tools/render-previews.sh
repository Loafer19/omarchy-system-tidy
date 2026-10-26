#!/usr/bin/env bash
# Render the marketplace/README preview offscreen with made-up data:
#   tools/render-previews.sh [OUT_DIR]      (default: the repo root)
# Runs the real Panel.qml in Quickshell (QT_QPA_PLATFORM=offscreen) against
# tests/preview/backend.sh, a fake read-only backend, so nothing from this
# machine (packages, paths, sizes) ends up in the image. Needs qs and the
# Omarchy shell (Commons, Ui); skips cleanly without them. Colors follow the
# active Omarchy theme.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
out=$(mkdir -p "${1:-$root}" && cd "${1:-$root}" && pwd)
shell_dir=${OMARCHY_PATH:-/usr/share/omarchy}/shell
command -v qs >/dev/null 2>&1 || { echo "SKIP  render-previews (no qs)"; exit 0; }
[[ -d $shell_dir/Ui && -d $shell_dir/Commons ]] || { echo "SKIP  render-previews (no Omarchy shell at $shell_dir)"; exit 0; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/tidy-previews.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cfg=$tmp/cfg
mkdir -p "$cfg/plugin"
ln -s "$shell_dir/Commons" "$cfg/Commons"
# Ui is Omarchy's, except KeyboardPanel: a layer-shell window cannot map
# offscreen, so a stub draws the same card in a plain Item.
mkdir -p "$cfg/Ui"
for f in "$shell_dir"/Ui/*; do ln -s "$f" "$cfg/Ui/"; done
rm -f "$cfg/Ui/KeyboardPanel.qml"
cp "$root/tests/preview/KeyboardPanel.qml" "$cfg/Ui/KeyboardPanel.qml"
tar -C "$root" --exclude=.git --exclude='./preview*.png' -cf - . | tar -C "$cfg/plugin" -xf -
cp "$root/tests/preview/backend.sh" "$cfg/plugin/scripts/backend.sh"
cp "$root/tests/preview/shell.qml" "$cfg/shell.qml"

render() { # render FILE TAB
  local file=$out/$1 log=$tmp/$1.log
  PREVIEW_TAB=$2 PREVIEW_OUT=$file QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    QT_SCALE_FACTOR=${PREVIEW_SCALE:-2} timeout 40 qs -p "$cfg" > "$log" 2>&1 || true
  if grep -q '^.*saved ' "$log" && [[ -s $file ]]; then
    echo "saved $file"
  else
    echo "FAIL  render $1" >&2; tail -n 20 "$log" >&2; return 1
  fi
}
render preview.png cleanup
