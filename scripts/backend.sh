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
  pkexec bash -c '
    command -v snapper >/dev/null 2>&1 && snapper create -c number -d "$1" >/dev/null 2>&1
    shift
    exec pacman -Rns --noconfirm "$@"
  ' _ "system-tidy: before removing $*" "$@"
}

# Leftover config files pacman drops on upgrade/removal. Listing needs no
# privilege; removing does, since /etc is root-owned.
packages_pacnew() {
  (find /etc -xdev \( -name "*.pacnew" -o -name "*.pacsave" -o -name "*.pacorig" \) 2>/dev/null || true) | sort | while read -r f; do
    [ -f "$f" ] || continue
    printf '%s\t%s\t%s\n' "$(basename "$f")" "$(stat -c%s "$f" 2>/dev/null || echo 0)" "$f"
  done
  return 0
}

packages_pacnew_remove() {
  [ "$#" -eq 0 ] && exit 0
  # Defense in depth: a privileged delete shouldn't trust its argument
  # just because the only real caller is our own listing.
  case "$1" in
    /etc/*.pacnew | /etc/*.pacsave | /etc/*.pacorig) ;;
    *) exit 1 ;;
  esac
  pkexec rm -f "$1"
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
  local dir="$HOME/.config/autostart"
  local target="$dir/$name.desktop"
  mkdir -p "$dir"

  # Write to a temp file and rename it into place — rename(2) replaces
  # whatever's at $target without following it, so there's no race window.
  local tmp
  tmp=$(mktemp "$dir/.tidy-tmp.XXXXXX") || exit 1

  if [ -f "$target" ] && [ ! -L "$target" ]; then
    if grep -q '^Hidden=' "$target" 2>/dev/null; then
      sed 's/^Hidden=.*/Hidden=true/' "$target" > "$tmp"
    else
      cat "$target" > "$tmp"
      printf 'Hidden=true\n' >> "$tmp"
    fi
  else
    printf '[Desktop Entry]\nHidden=true\n' > "$tmp"
  fi

  mv -f "$tmp" "$target"
}

# Scoped to units under ~/.config/systemd/user/ only, so vendor-shipped
# units (audio, keyring, etc.) never show up here to be disabled.
systemd_user_list() {
  command -v systemctl >/dev/null 2>&1 || return 0
  local unit path
  while read -r unit _; do
    [ -z "$unit" ] && continue
    path=$(systemctl --user show "$unit" -p FragmentPath --value 2>/dev/null)
    case "$path" in
      "$HOME"/.config/systemd/user/*) ;;
      *) continue ;;
    esac
    printf '%s\tenabled\t%s\n' "$unit" "${unit##*.}"
  done < <(systemctl --user list-unit-files --state=enabled --no-legend --no-pager 2>/dev/null)
}

systemd_user_disable() {
  [ "$#" -eq 0 ] && exit 0
  systemctl --user disable "$1"
}

dir_size_mb() {
  du -sm "$1" 2>/dev/null | cut -f1 || true
}

# Refuses a symlinked path — a plain `rm -rf "$d"/*` would otherwise
# follow it and delete whatever it actually points to.
safe_clear_dir() {
  local d="$1"
  [ -L "$d" ] && return 0
  [ -d "$d" ] || return 0
  rm -rf "${d:?}"/*
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

aur_cache_mb() {
  local total=0 d size
  for d in "$HOME/.cache/yay" "$HOME/.cache/paru"; do
    size=$(dir_size_mb "$d")
    total=$((total + ${size:-0}))
  done
  echo "$total"
}

dev_cache_mb() {
  local total=0 d size
  for d in "$HOME/.cache/pip" "$HOME/.npm" "$HOME/.cargo/registry" "$HOME/go/pkg/mod"; do
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
  printf 'aur\t%s\n' "$(aur_cache_mb)"
  printf 'dev\t%s\n' "$(dev_cache_mb)"
  printf 'journal\t%s\n' "$(journal_size_mb)"
  printf 'orphans_count\t%s\n' "$(orphans_count)"
  printf 'orphans_mb\t%s\n' "$(orphans_size_mb)"
}

dev_cache_clean() {
  # Clear directly rather than each tool's own "clean" command — those
  # no-op silently when the tool isn't on this process's PATH.
  safe_clear_dir "$HOME/.cache/pip"
  safe_clear_dir "$HOME/.npm"
  safe_clear_dir "$HOME/.cargo/registry"
  # Go marks module cache entries read-only; strip that first or rm stops
  # partway through.
  if [ -d "$HOME/go/pkg/mod" ] && [ ! -L "$HOME/go/pkg/mod" ]; then
    chmod -R u+w "$HOME/go/pkg/mod" 2>/dev/null || true
  fi
  safe_clear_dir "$HOME/go/pkg/mod"
  return 0
}

cleanup_run() {
  case "$1" in
    pacman) pkexec paccache -r -u -k0 ;;
    coredump) pkexec rm -rf /var/lib/systemd/coredump/* ;;
    trash)
      safe_clear_dir "$HOME/.local/share/Trash/files"
      safe_clear_dir "$HOME/.local/share/Trash/info"
      ;;
    docker) docker system prune -f ;;
    browser)
      safe_clear_dir "$HOME/.cache/google-chrome"
      safe_clear_dir "$HOME/.cache/chromium"
      ;;
    aur)
      safe_clear_dir "$HOME/.cache/yay"
      safe_clear_dir "$HOME/.cache/paru"
      ;;
    dev) dev_cache_clean ;;
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
  packages-pacnew) packages_pacnew ;;
  packages-pacnew-remove) packages_pacnew_remove "$@" ;;
  webapps-list) webapps_list ;;
  webapps-remove) webapps_remove "$@" ;;
  autostart-list) autostart_list ;;
  autostart-disable) autostart_disable "$@" ;;
  systemd-list) systemd_user_list ;;
  systemd-disable) systemd_user_disable "$@" ;;
  cleanup-status) cleanup_status ;;
  cleanup-run) cleanup_run "$@" ;;
  *) echo "unknown command: $cmd" >&2; exit 1 ;;
esac
