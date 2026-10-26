#!/usr/bin/env bash
# Lint the plugin's own code (vendor/ is checked by sync-ui.sh instead):
# ShellCheck with .shellcheckrc and Qt 6 qmllint, where any warning fails.
# Override the binaries with SHELLCHECK= / QMLLINT=. A missing tool is
# skipped with a note, so tests/run.sh also works without them.
set -euo pipefail
cd "$(dirname "$0")/.."

status=0
shellcheck_bin=${SHELLCHECK:-$(command -v shellcheck || true)}
if [[ -n "$shellcheck_bin" ]]; then
  # tools/sync-ui.sh is omarchy-yoyo-ui's own script, copied verbatim and
  # linted there; the rest is ours.
  mapfile -t own < <(printf '%s\n' scripts/*.sh tests/*.sh tests/preview/*.sh tools/*.sh | grep -vx tools/sync-ui.sh)
  "$shellcheck_bin" "${own[@]}" || status=1
else
  echo "lint: shellcheck not found, skipped" >&2
fi

qmllint_bin=${QMLLINT:-$(command -v qmllint || true)}
[[ -z "$qmllint_bin" && -x /usr/lib/qt6/bin/qmllint ]] && qmllint_bin=/usr/lib/qt6/bin/qmllint
shell_dir=${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}
if [[ -n "$qmllint_bin" && -d "$shell_dir/Commons" ]]; then
  # The shell resolves `qs.Commons` / `qs.Ui` from its config dir; mirror
  # that with a throwaway import root.
  imports=$(mktemp -d "${TMPDIR:-/tmp}/tidy-lint.XXXXXX")
  trap 'rm -rf "$imports"' EXIT
  mkdir -p "$imports/qs"
  ln -s "$shell_dir/Commons" "$imports/qs/Commons"
  ln -s "$shell_dir/Ui" "$imports/qs/Ui"
  files=(BarWidget.qml Panel.qml Service.qml components/*.qml ./*.js)
  if ! out=$("$qmllint_bin" -I "$imports" -I /usr/lib/qt6/qml "${files[@]}" 2>&1); then status=1; fi
  if grep -q '^Warning' <<<"$out"; then
    printf '%s\n' "$out" >&2
    status=1
  fi
else
  echo "lint: qmllint or $shell_dir not found, skipped" >&2
fi

if [[ "$status" -eq 0 ]]; then echo "lint: OK"; fi
exit "$status"
