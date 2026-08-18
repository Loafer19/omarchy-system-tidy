#!/usr/bin/env bash
set -euo pipefail

BASE_LIST="/usr/share/omarchy/install/omarchy-base.packages"
OTHER_LIST="/usr/share/omarchy/install/omarchy-other.packages"

defaults_set() {
  grep -hvE '^\s*#|^\s*$' "$BASE_LIST" "$OTHER_LIST" 2>/dev/null | sort -u
}

packages_list() {
  local defaults installed
  defaults=$(defaults_set)
  installed=$(pacman -Qeq | sort -u)
  comm -23 <(echo "$installed") <(echo "$defaults") | while read -r pkg; do
    [ -z "$pkg" ] && continue
    local size date
    size=$(expac -H M '%m' "$pkg" 2>/dev/null || echo "0")
    date=$(grep -a "installed $pkg " /var/log/pacman.log 2>/dev/null | tail -1 | cut -d']' -f1 | tr -d '[' | cut -dT -f1)
    printf '%s\t%s\t%s\n' "$pkg" "${size:-0}" "${date:-unknown}"
  done
}

packages_remove() {
  [ "$#" -eq 0 ] && exit 0
  pkexec pacman -Rns --noconfirm "$@"
}

webapps_list() {
  grep -l "Exec=omarchy-launch-webapp\|Exec=omarchy-webapp-handler" "$HOME/.local/share/applications/"*.desktop 2>/dev/null \
    | while read -r f; do basename "$f" .desktop; done | sort
}

webapps_remove() {
  [ "$#" -eq 0 ] && exit 0
  omarchy webapp remove "$1"
}

autostart_list() {
  local dirs=("$HOME/.config/autostart" "/etc/xdg/autostart")
  declare -A seen
  for d in "${dirs[@]}"; do
    [ -d "$d" ] || continue
    for f in "$d"/*.desktop; do
      [ -f "$f" ] || continue
      local name status
      name=$(basename "$f" .desktop)
      [ -n "${seen[$name]:-}" ] && continue
      seen[$name]=1
      if grep -q '^Hidden=true' "$f" 2>/dev/null; then
        status="disabled"
      else
        status="enabled"
      fi
      printf '%s\t%s\t%s\n' "$name" "$status" "$d"
    done
  done
}

autostart_disable() {
  [ "$#" -eq 0 ] && exit 0
  local name="$1"
  local target="$HOME/.config/autostart/$name.desktop"
  mkdir -p "$HOME/.config/autostart"
  if [ -f "$target" ]; then
    if ! grep -q '^Hidden=' "$target"; then
      printf 'Hidden=true\n' >> "$target"
    else
      sed -i 's/^Hidden=.*/Hidden=true/' "$target"
    fi
  else
    printf '[Desktop Entry]\nHidden=true\n' > "$target"
  fi
}

dir_size_mb() {
  du -sm "$1" 2>/dev/null | cut -f1 || true
}

cleanup_status() {
  local pacman_cache coredump trash
  pacman_cache=$(dir_size_mb /var/cache/pacman/pkg/)
  coredump=$(dir_size_mb /var/lib/systemd/coredump/)
  trash=$(dir_size_mb "$HOME/.local/share/Trash/")
  printf 'pacman\t%s\n' "${pacman_cache:-0}"
  printf 'coredump\t%s\n' "${coredump:-0}"
  printf 'trash\t%s\n' "${trash:-0}"
}

cleanup_run() {
  case "$1" in
    pacman) pkexec paccache -r -u -k0 ;;
    coredump) pkexec rm -rf /var/lib/systemd/coredump/* ;;
    trash) rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* ;;
    *) exit 1 ;;
  esac
}

cmd="${1:-}"
shift || true
case "$cmd" in
  packages-list) packages_list ;;
  packages-remove) packages_remove "$@" ;;
  webapps-list) webapps_list ;;
  webapps-remove) webapps_remove "$@" ;;
  autostart-list) autostart_list ;;
  autostart-disable) autostart_disable "$@" ;;
  cleanup-status) cleanup_status ;;
  cleanup-run) cleanup_run "$@" ;;
  *) echo "unknown command: $cmd" >&2; exit 1 ;;
esac
