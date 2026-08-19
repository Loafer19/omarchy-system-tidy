#!/usr/bin/env bash
set -euo pipefail

BASE_LIST="/usr/share/omarchy/install/omarchy-base.packages"
OTHER_LIST="/usr/share/omarchy/install/omarchy-other.packages"

defaults_set() {
  grep -hvE '^\s*#|^\s*$' "$BASE_LIST" "$OTHER_LIST" 2>/dev/null | sort -u
}

package_last_used() {
  local pkg="$1"
  local newest=0 atime f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    atime=$(stat -c %X "$f" 2>/dev/null || echo 0)
    [ "$atime" -gt "$newest" ] && newest=$atime
  done < <(pacman -Ql "$pkg" 2>/dev/null | awk '{print $2}' | grep -E '/s?bin/')

  [ "$newest" -eq 0 ] && { echo "n/a"; return; }

  local days=$(( ($(date +%s) - newest) / 86400 ))
  [ "$days" -le 0 ] && echo "today" || echo "${days}d ago"
}

describe_packages() {
  while read -r pkg; do
    [ -z "$pkg" ] && continue
    local size date used
    size=$(expac -H M '%m' "$pkg" 2>/dev/null || echo "0")
    date=$(grep -a "installed $pkg " /var/log/pacman.log 2>/dev/null | tail -1 | cut -d']' -f1 | tr -d '[' | cut -dT -f1)
    used=$(package_last_used "$pkg")
    printf '%s\t%s\t%s\t%s\n' "$pkg" "${size:-0}" "${date:-unknown}" "$used"
  done
  return 0
}

packages_list() {
  local defaults installed
  defaults=$(defaults_set)
  installed=$(pacman -Qeq | sort -u)
  comm -23 <(echo "$installed") <(echo "$defaults") | describe_packages
}

packages_orphans() {
  (pacman -Qtdq 2>/dev/null || true) | sort -u | describe_packages
}

packages_remove() {
  [ "$#" -eq 0 ] && exit 0
  pkexec pacman -Rns --noconfirm "$@"
}

webapps_list() {
  (grep -l "Exec=omarchy-launch-webapp\|Exec=omarchy-webapp-handler" "$HOME/.local/share/applications/"*.desktop 2>/dev/null || true) \
    | (while read -r f; do basename "$f" .desktop; done; true) | sort
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

docker_size_mb() {
  command -v docker >/dev/null 2>&1 || { echo 0; return; }
  docker system df --format '{{.Size}}' 2>/dev/null | awk '
    {
      v = $0
      unit = substr(v, length(v) - 1, 2)
      if (unit == "GB") { total += substr(v, 1, length(v) - 2) * 1024 }
      else if (unit == "MB") { total += substr(v, 1, length(v) - 2) }
      else if (unit == "kB" || unit == "KB") { total += substr(v, 1, length(v) - 2) / 1024 }
      else if (substr(v, length(v), 1) == "B") { total += substr(v, 1, length(v) - 1) / 1024 / 1024 }
    }
    END { printf "%.0f", total + 0 }
  ' || echo 0
}

browser_cache_mb() {
  local total=0 d size
  for d in "$HOME/.cache/google-chrome" "$HOME/.cache/chromium"; do
    size=$(dir_size_mb "$d")
    total=$((total + ${size:-0}))
  done
  echo "$total"
}

journal_size_mb() {
  journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMG]' | head -1 | awk '
    {
      unit = substr($0, length($0), 1)
      num = substr($0, 1, length($0) - 1)
      if (unit == "G") print num * 1024
      else if (unit == "M") print num
      else if (unit == "K") print num / 1024
      else print 0
    }
  '
}

orphans_count() {
  (pacman -Qtdq 2>/dev/null || true) | wc -l
}

orphans_size_mb() {
  local pkgs
  pkgs=$(pacman -Qtdq 2>/dev/null || true)
  [ -z "$pkgs" ] && { echo 0; return; }
  expac -H M '%m' $pkgs 2>/dev/null | awk '{t += $1} END { printf "%.0f", t + 0 }'
}

cleanup_status() {
  printf 'pacman\t%s\n' "$(dir_size_mb /var/cache/pacman/pkg/)"
  printf 'coredump\t%s\n' "$(dir_size_mb /var/lib/systemd/coredump/)"
  printf 'trash\t%s\n' "$(dir_size_mb "$HOME/.local/share/Trash/")"
  printf 'docker\t%s\n' "$(docker_size_mb)"
  printf 'browser\t%s\n' "$(browser_cache_mb)"
  printf 'journal\t%s\n' "$(journal_size_mb)"
  printf 'orphans_count\t%s\n' "$(orphans_count)"
  printf 'orphans_mb\t%s\n' "$(orphans_size_mb)"
}

cleanup_run() {
  case "$1" in
    pacman) pkexec paccache -r -u -k0 ;;
    coredump) pkexec rm -rf /var/lib/systemd/coredump/* ;;
    trash) rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* ;;
    docker) docker system prune -f ;;
    browser) rm -rf "$HOME/.cache/google-chrome/"* "$HOME/.cache/chromium/"* ;;
    journal) pkexec journalctl --vacuum-size=100M ;;
    *) exit 1 ;;
  esac
}

cmd="${1:-}"
shift || true
case "$cmd" in
  packages-list) packages_list ;;
  packages-orphans) packages_orphans ;;
  packages-remove) packages_remove "$@" ;;
  webapps-list) webapps_list ;;
  webapps-remove) webapps_remove "$@" ;;
  autostart-list) autostart_list ;;
  autostart-disable) autostart_disable "$@" ;;
  cleanup-status) cleanup_status ;;
  cleanup-run) cleanup_run "$@" ;;
  *) echo "unknown command: $cmd" >&2; exit 1 ;;
esac
