#!/usr/bin/env bash
set -euo pipefail

# TIDY_ROOT only exists so tests/backend.sh can point the read-only system
# paths at a fixture tree; it is empty in normal use.
ROOT="${TIDY_ROOT:-}"
BASE_LIST="$ROOT/usr/share/omarchy/install/omarchy-base.packages"
OTHER_LIST="$ROOT/usr/share/omarchy/install/omarchy-other.packages"
PACMAN_LOG="$ROOT/var/log/pacman.log"

# Packages whose removal can leave the system unbootable, without sudo,
# without snapshots or without a desktop. Never offered for removal and
# refused by packages-remove even if asked directly.
PROTECTED_RE='^(omarchy|omarchy-.+|omasnap|base|base-devel|filesystem|glibc|bash|coreutils|systemd|systemd-.+|dbus|dbus-.+|pacman|pacman-contrib|archlinux-keyring|expac|sudo|polkit|linux|linux-(lts|zen|hardened|rt)|linux(-lts|-zen|-hardened|-rt)?-headers|linux-firmware(-.+)?|.+-ucode|.+-dkms|dkms|mkinitcpio|mkinitcpio-.+|dracut|limine|limine-.+|grub|efibootmgr|snapper|snap-pac|btrfs-progs|cryptsetup|lvm2|plymouth|nvidia|nvidia-.+|lib32-nvidia-utils|mesa|lib32-mesa|vulkan-.+|hyprland|uwsm|quickshell|networkmanager|iwd|wpa_supplicant|greetd|sddm|pipewire|wireplumber)$'

is_protected_pkg() {
  [[ "$1" =~ $PROTECTED_RE ]]
}

valid_pkg_name() {
  [[ "$1" =~ ^[a-zA-Z0-9@_+][a-zA-Z0-9@._+-]*$ ]]
}

defaults_set() {
  grep -hvE '^\s*#|^\s*$' "$BASE_LIST" "$OTHER_LIST" 2>/dev/null | sort -u || true
}

package_last_used() {
  local pkg="$1"
  local newest=0 atime f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    atime=$(stat -c %X "$f" 2>/dev/null || echo 0)
    [ "$atime" -gt "$newest" ] && newest=$atime
  done < <(pacman -Ql "$pkg" 2>/dev/null | awk '{print $2}' | grep -E '/s?bin/' || true)

  [ "$newest" -eq 0 ] && { echo "n/a"; return; }

  local days=$(( ($(date +%s) - newest) / 86400 ))
  [ "$days" -le 0 ] && echo "today" || echo "${days}d ago"
}

# last-used filled later via packages-last-used (pacman -Ql is slow).
describe_packages() {
  while read -r pkg; do
    [ -z "$pkg" ] && continue
    local size date
    size=$(expac -H M '%m' "$pkg" 2>/dev/null || echo "0")
    date=$(grep -a "installed $pkg " "$PACMAN_LOG" 2>/dev/null | tail -1 | cut -d']' -f1 | tr -d '[' | cut -dT -f1 || true)
    local prot=""
    is_protected_pkg "$pkg" && prot="protected"
    printf '%s\t%s\t%s\t%s\t%s\n' "$pkg" "${size:-0}" "${date:-unknown}" "" "$prot"
  done
  return 0
}

packages_list() {
  local defaults installed
  defaults=$(defaults_set)
  installed=$(pacman -Qeq 2>/dev/null | sort -u || true)
  comm -23 <(echo "$installed") <(echo "$defaults") | describe_packages
}

packages_orphans() {
  (pacman -Qtdq 2>/dev/null || true) | sort -u | describe_packages
}

packages_last_used() {
  local pkg
  for pkg in "$@"; do
    [ -z "$pkg" ] && continue
    printf '%s\t%s\n' "$pkg" "$(package_last_used "$pkg")"
  done
  return 0
}

packages_remove() {
  [ "$#" -eq 0 ] && exit 0
  local pkg
  for pkg in "$@"; do
    if ! valid_pkg_name "$pkg"; then
      echo "refusing: invalid package name '$pkg'" >&2
      exit 2
    fi
    if is_protected_pkg "$pkg"; then
      echo "refusing: $pkg is a protected system package" >&2
      exit 2
    fi
  done
  # omarchy-snapshot (multi-config); snapper fallback. Failure must not block remove.
  pkexec env PATH="/usr/share/omarchy/bin:/usr/bin:/bin:$PATH" \
    OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}" \
    bash -c '
      if command -v omarchy-snapshot >/dev/null 2>&1; then
        omarchy-snapshot create >/dev/null 2>&1 || true
      elif command -v snapper >/dev/null 2>&1; then
        snapper create -c number -d "$1" >/dev/null 2>&1 || true
      fi
      shift
      exec pacman -Rns --noconfirm -- "$@"
    ' _ "system-tidy: before removing $*" "$@"
}

# Listing is unprivileged; remove needs root (/etc).
packages_pacnew() {
  (find "$ROOT/etc" -xdev \( -name "*.pacnew" -o -name "*.pacsave" -o -name "*.pacorig" \) 2>/dev/null || true) | sort | while read -r f; do
    [ -f "$f" ] || continue
    printf '%s\t%s\t%s\n' "$(basename "$f")" "$(stat -c%s "$f" 2>/dev/null || echo 0)" "$f"
  done
  return 0
}

packages_pacnew_remove() {
  [ "$#" -eq 0 ] && exit 0
  # realpath + /etc + .pacnew|.pacsave|.pacorig (including nested under /etc).
  local resolved
  resolved=$(realpath -e -- "$1" 2>/dev/null) || exit 1
  case "$resolved" in
    "$ROOT"/etc/*) ;;
    *) exit 1 ;;
  esac
  case "$resolved" in
    *.pacnew | *.pacsave | *.pacorig) ;;
    *) exit 1 ;;
  esac
  pkexec rm -f -- "$resolved"
}

webapps_list() {
  (grep -l "Exec=omarchy-launch-webapp\|Exec=omarchy-webapp-handler" "$HOME/.local/share/applications/"*.desktop 2>/dev/null || true) \
    | (while read -r f; do basename "$f" .desktop; done; true) | sort
}

webapps_remove() {
  [ "$#" -eq 0 ] && exit 0
  omarchy webapp remove "$1"
}

# Same match as omarchy-tui-remove-all.
tui_list() {
  local f
  for f in "$HOME/.local/share/applications/"*.desktop; do
    [ -f "$f" ] || continue
    grep -q 'Exec=xdg-terminal-exec --app-id=TUI\.' "$f" 2>/dev/null || continue
    basename "$f" .desktop
  done | sort
}

tui_remove() {
  [ "$#" -eq 0 ] && exit 0
  # Avoid `omarchy tui remove`: "all" is mass-delete.
  omarchy-tui-remove "$1"
}

valid_entry_name() {
  case "$1" in
    "" | .* | -* | *..* | */* | *$'\n'*) return 1 ;;
  esac
  return 0
}

desktop_hidden() {
  grep -qiE '^[[:space:]]*Hidden[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$1" 2>/dev/null
}

# name, enabled|disabled, dir it was read from, system|user (system = a
# vendor entry exists in /etc/xdg/autostart, whether or not overridden).
autostart_list() {
  local user_dir="$HOME/.config/autostart" sys_dir="$ROOT/etc/xdg/autostart"
  declare -A seen
  local d f name status origin
  for d in "$user_dir" "$sys_dir"; do
    [ -d "$d" ] || continue
    for f in "$d"/*.desktop; do
      [ -f "$f" ] || continue
      name=$(basename "$f" .desktop)
      [ -n "${seen[$name]:-}" ] && continue
      seen[$name]=1
      if desktop_hidden "$f"; then status="disabled"; else status="enabled"; fi
      origin="user"
      [ -f "$sys_dir/$name.desktop" ] && origin="system"
      printf '%s\t%s\t%s\t%s\n' "$name" "$status" "$d" "$origin"
    done
  done
  return 0
}

autostart_name_arg() {
  local name
  name=$(basename -- "$1")
  name=${name%.desktop}
  valid_entry_name "$name" || { echo "refusing: invalid autostart name" >&2; exit 2; }
  printf '%s' "$name"
}

autostart_disable() {
  [ "$#" -eq 0 ] && exit 0
  local name dir target tmp
  name=$(autostart_name_arg "$1") || exit 2
  dir="$HOME/.config/autostart"
  target="$dir/$name.desktop"
  if [ -L "$target" ]; then
    echo "refusing: $target is a symlink (managed elsewhere) — edit it there" >&2
    exit 3
  fi
  mkdir -p "$dir"
  # temp + rename so we never follow a symlink at $target.
  tmp=$(mktemp "$dir/.tidy-tmp.XXXXXX") || exit 1
  if [ -f "$target" ]; then
    if grep -qiE '^[[:space:]]*Hidden[[:space:]]*=' "$target"; then
      sed -E 's/^[[:space:]]*[Hh][Ii][Dd][Dd][Ee][Nn][[:space:]]*=.*/Hidden=true/' "$target" > "$tmp"
    else
      { cat "$target"; printf 'Hidden=true\n'; } > "$tmp"
    fi
  else
    # Override a vendor entry: a stub with only Hidden=true (no Exec=).
    printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\n' "$name" > "$tmp"
  fi
  mv -f "$tmp" "$target"
}

autostart_enable() {
  [ "$#" -eq 0 ] && exit 0
  local name dir target tmp
  name=$(autostart_name_arg "$1") || exit 2
  dir="$HOME/.config/autostart"
  target="$dir/$name.desktop"
  if [ -L "$target" ]; then
    echo "refusing: $target is a symlink (managed elsewhere) — edit it there" >&2
    exit 3
  fi
  [ -f "$target" ] || exit 0   # vendor entry with no override is already enabled
  # Our own override stub (no Exec=) over a vendor entry: just drop it.
  if ! grep -qE '^[[:space:]]*Exec[[:space:]]*=' "$target" && [ -f "$ROOT/etc/xdg/autostart/$name.desktop" ]; then
    rm -f -- "$target"
    return 0
  fi
  tmp=$(mktemp "$dir/.tidy-tmp.XXXXXX") || exit 1
  grep -viE '^[[:space:]]*Hidden[[:space:]]*=' "$target" > "$tmp" || true
  mv -f "$tmp" "$target"
}

valid_unit_name() {
  [[ "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9:_.@-]*\.(service|timer|socket|path)$ ]]
}

user_unit_path() {
  systemctl --user show "$1" -p FragmentPath --value 2>/dev/null || true
}

# Only units in ~/.config/systemd/user/ — never vendor session units.
systemd_user_list() {
  command -v systemctl >/dev/null 2>&1 || return 0
  local unit state path
  while read -r unit state _; do
    [ -z "$unit" ] && continue
    valid_unit_name "$unit" || continue
    path=$(user_unit_path "$unit")
    case "$path" in
      "$HOME"/.config/systemd/user/*) ;;
      *) continue ;;
    esac
    printf '%s\t%s\t%s\n' "$unit" "$state" "${unit##*.}"
  done < <(systemctl --user list-unit-files --state=enabled,disabled --no-legend --no-pager 2>/dev/null)
  return 0
}

systemd_user_guard() {
  valid_unit_name "$1" || { echo "refusing: invalid unit name" >&2; exit 2; }
  case "$(user_unit_path "$1")" in
    "$HOME"/.config/systemd/user/*) ;;
    *) echo "refusing: $1 is not a unit in ~/.config/systemd/user" >&2; exit 2 ;;
  esac
}

systemd_user_disable() {
  [ "$#" -eq 0 ] && exit 0
  systemd_user_guard "$1"
  systemctl --user disable --now -- "$1"
}

systemd_user_enable() {
  [ "$#" -eq 0 ] && exit 0
  systemd_user_guard "$1"
  systemctl --user enable --now -- "$1"
}

dir_size_mb() {
  du -sm "$1" 2>/dev/null | cut -f1 || true
}

# Refuse symlinked dirs; find clears children including dotfiles.
safe_clear_dir() {
  local d="$1"
  [ -L "$d" ] && return 0
  [ -d "$d" ] || return 0
  find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
  return 0
}

# safe_clear_dir as root (expand inside pkexec, not the user shell).
pkexec_safe_clear_dir() {
  local d="$1"
  pkexec bash -c '
    d=$1
    [ -L "$d" ] && exit 0
    [ -d "$d" ] || exit 0
    find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  ' _ "$d"
}

# "1.2GB", "512MB (40%)", "980.5kB", "0B" -> MiB on stdout (sums all lines).
docker_sizes_to_mb() {
  awk '
    {
      v = $1
      if (v == "") next
      n = v + 0
      u = v; sub(/^[0-9.]+/, "", u)
      if (u == "TB") total += n * 1024 * 1024
      else if (u == "GB") total += n * 1024
      else if (u == "MB") total += n
      else if (u == "kB" || u == "KB") total += n / 1024
      else if (u == "B") total += n / 1024 / 1024
    }
    END { printf "%.0f\n", total + 0 }
  '
}

# What `docker system prune -f` frees: stopped containers, build cache and
# dangling images (not every unused image — that needs -a, which we don't
# run). Prints 0 when docker is missing or the socket isn't reachable.
docker_size_mb() {
  command -v docker >/dev/null 2>&1 || { echo 0; return; }
  local df dangling
  df=$(docker system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null) || { echo 0; return; }
  dangling=$(docker images -f dangling=true --format '{{.Size}}' 2>/dev/null || true)
  {
    awk -F'|' '$1 != "Images" && $1 != "Local Volumes" { print $2 }' <<<"$df"
    printf '%s\n' "$dangling"
  } | docker_sizes_to_mb
}

# What `paccache -r -u -k0` would delete: cached packages that are no longer
# installed. paccache's own dry run is unprivileged.
pacman_reclaimable_mb() {
  command -v paccache >/dev/null 2>&1 || { echo 0; return; }
  local out
  out=$(paccache -d -u -k0 -c "$ROOT/var/cache/pacman/pkg" 2>/dev/null || true)
  awk '
    match($0, /disk space saved: [0-9.]+ [KMGT]?i?B/) {
      s = substr($0, RSTART + 18, RLENGTH - 18); split(s, p, " ")
      n = p[1] + 0; u = p[2]
      if (u == "TiB") n *= 1024 * 1024; else if (u == "GiB") n *= 1024
      else if (u == "KiB") n /= 1024; else if (u == "B") n /= 1024 * 1024
      found = n
    }
    END { printf "%.0f\n", found + 0 }
  ' <<<"$out"
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
  local out
  out=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMG]' | head -1 | awk '
    {
      unit = substr($0, length($0), 1)
      num = substr($0, 1, length($0) - 1)
      if (unit == "G") print num * 1024
      else if (unit == "M") print num
      else if (unit == "K") print num / 1024
      else print 0
    }
  ' || true)
  echo "${out:-0}"
}

# id|display|mise_pkg|stub|install_dirname — same set as omarchy-default-agent.
agent_catalog() {
  cat <<'EOF'
pi|Pi|pi|pi|pi
omp|Oh My Pi|github:can1357/oh-my-pi|omp|github-can1357-oh-my-pi
opencode|OpenCode|opencode|opencode|opencode
ori|Ori|github:OpenRouterLabs/ori-releases|ori|github-OpenRouterLabs-ori-releases
claude|Claude Code|claude|claude|claude
codex|Codex|codex|codex|codex
grok|Grok|npm:@xai-official/grok|grok|npm-xai-official-grok
agy|Antigravity|antigravity-cli|agy|antigravity-cli
copilot|GitHub Copilot|copilot|copilot|copilot
crush|Crush|crush|crush|crush
EOF
}

agent_install_path() {
  local hint="$1" pkg="$2"
  local installs="$HOME/.local/share/mise/installs"
  local candidates=("$hint") c
  case "$pkg" in
    npm:*)
      candidates+=("npm-${pkg#npm:}" "npm-${pkg#npm:@}")
      ;;
    github:*)
      candidates+=("github-${pkg#github:}" "${pkg#github:}")
      ;;
    *)
      candidates+=("$pkg")
      ;;
  esac
  for c in "${candidates[@]}"; do
    c=${c//\//-}
    c=${c//@/}
    c=${c//:/-}
    [ -n "$c" ] || continue
    [ -d "$installs/$c" ] && { echo "$installs/$c"; return 0; }
  done
  return 1
}

agents_list() {
  local id name pkg stub install_dir size detail has_stub path
  while IFS='|' read -r id name pkg stub install_dir; do
    [ -z "$id" ] && continue
    has_stub=0
    path=""
    [ -e "$HOME/.local/bin/$stub" ] && has_stub=1
    path=$(agent_install_path "$install_dir" "$pkg" || true)
    [ "$has_stub" -eq 0 ] && [ -z "$path" ] && continue

    size=0
    if [ -n "$path" ]; then
      size=$(dir_size_mb "$path")
      detail="mise"
    else
      detail="stub only"
    fi
    printf '%s\t%s\t%s\t%s\n' "$id" "$name" "${size:-0}" "$detail"
  done < <(agent_catalog)
  return 0
}

agents_remove() {
  [ "$#" -eq 0 ] && exit 0
  local id="$1" pkg stub matched=0
  local aid aname apkg astub ainstall
  while IFS='|' read -r aid aname apkg astub ainstall; do
    if [ "$aid" = "$id" ]; then
      pkg=$apkg; stub=$astub; matched=1
      break
    fi
  done < <(agent_catalog)
  [ "$matched" -eq 1 ] || exit 1

  if command -v mise >/dev/null 2>&1; then
    mise unuse -g -y "$pkg" >/dev/null 2>&1 || true
    mise uninstall --all -y "$pkg" >/dev/null 2>&1 || true
  fi
  rm -f "$HOME/.local/bin/$stub"

  local def="$HOME/.config/omarchy/defaults/agent"
  if [ -f "$def" ] && [ "$(tr -d '[:space:]' < "$def")" = "$id" ]; then
    rm -f "$def"
  fi
}

# Agent caches: only temp files, logs and re-downloadable caches.
# Never touched: sessions/transcripts (resume), memories*, goals*, any
# *.sqlite state, projects/*/memory, history, plans, auth and config.
# Format: agent|process-name|path (process-name is what pgrep looks for).
agents_cache_paths() {
  local share="${XDG_DATA_HOME:-$HOME/.local/share}"
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}"
  cat <<EOF
claude|claude|$HOME/.claude/cache
claude|claude|$HOME/.claude/paste-cache
claude|claude|$HOME/.claude/shell-snapshots
claude|claude|$HOME/.claude/session-env
claude|claude|$HOME/.claude/telemetry
claude|claude|$HOME/.claude/statsig
claude|claude|$HOME/.claude/debug
claude|claude|$HOME/.claude/plugins/cache
codex|codex|$HOME/.codex/.tmp
codex|codex|$HOME/.codex/tmp
codex|codex|$HOME/.codex/log
omp|omp|$HOME/.omp/logs
copilot|copilot|$HOME/.copilot/logs
opencode|opencode|$cache/opencode
opencode|opencode|$share/opencode/log
EOF
}

# A path whose last component looks like memory/goals/state is never cleared,
# whatever the list above says.
agent_path_is_precious() {
  case "${1##*/}" in
    memor* | goal* | *.sqlite* | auth* | config* | settings* | credentials* | projects | sessions | history*) return 0 ;;
  esac
  return 1
}

agent_running() {
  pgrep -x "$1" >/dev/null 2>&1 && return 0
  pgrep -f -- "(^|/)$1( |\$)" >/dev/null 2>&1
}

agents_running_list() {
  local seen="" agent proc _path
  while IFS='|' read -r agent proc _path; do
    [[ " $seen " == *" $agent "* ]] && continue
    agent_running "$proc" && seen="$seen $agent"
  done < <(agents_cache_paths)
  echo "${seen# }"
}

agents_cache_mb() {
  local total=0 size agent proc path
  while IFS='|' read -r agent proc path; do
    [ -n "$path" ] && [ -d "$path" ] && [ ! -L "$path" ] || continue
    agent_path_is_precious "$path" && continue
    size=$(dir_size_mb "$path")
    total=$((total + ${size:-0}))
  done < <(agents_cache_paths)
  echo "$total"
}

agents_cache_clean() {
  local agent proc path skipped=""
  while IFS='|' read -r agent proc path; do
    [ -n "$path" ] || continue
    [[ " $skipped " == *" $agent "* ]] && continue
    if agent_running "$proc"; then
      skipped="$skipped $agent"
      continue
    fi
    [ -L "$path" ] && continue
    agent_path_is_precious "$path" && continue
    [ -d "$path" ] || continue
    find "$path" -mindepth 1 -maxdepth 1 ! -name 'memor*' ! -name 'goal*' ! -name '*.sqlite*' \
      ! -name 'auth*' ! -name 'config*' -exec rm -rf -- {} + 2>/dev/null || true
  done < <(agents_cache_paths)
  skipped="${skipped# }"
  [ -n "$skipped" ] && echo "tidy: skipped running ${skipped// /, }"
  return 0
}

# ~/.cache/mise + versions `mise prune` would delete.
mise_unused_mb() {
  command -v mise >/dev/null 2>&1 || { echo 0; return; }
  local total=0 size path tool ver
  size=$(dir_size_mb "${XDG_CACHE_HOME:-$HOME/.cache}/mise")
  total=$((total + ${size:-0}))

  while read -r tool ver _; do
    [ -z "${tool:-}" ] || [ -z "${ver:-}" ] && continue
    [[ "$tool" == "#"* ]] && continue
    path=$(mise where "${tool}@${ver}" 2>/dev/null || true)
    [ -n "$path" ] || continue
    size=$(dir_size_mb "$path")
    total=$((total + ${size:-0}))
  done < <(mise ls --prunable --installed --no-header 2>/dev/null || true)

  echo "$total"
}

mise_unused_clean() {
  command -v mise >/dev/null 2>&1 || return 0
  mise prune -y >/dev/null 2>&1 || true
  mise cache clear >/dev/null 2>&1 || true
  return 0
}

cleanup_status() {
  printf 'pacman\t%s\n' "$(pacman_reclaimable_mb)"
  printf 'pacman-total\t%s\n' "$(dir_size_mb "$ROOT/var/cache/pacman/pkg/")"
  printf 'coredump\t%s\n' "$(dir_size_mb "$ROOT/var/lib/systemd/coredump/")"
  printf 'trash\t%s\n' "$(dir_size_mb "$HOME/.local/share/Trash/")"
  printf 'docker\t%s\n' "$(docker_size_mb)"
  printf 'browser\t%s\n' "$(browser_cache_mb)"
  printf 'aur\t%s\n' "$(aur_cache_mb)"
  printf 'dev\t%s\n' "$(dev_cache_mb)"
  printf 'agents\t%s\n' "$(agents_cache_mb)"
  printf 'agents-running\t%s\n' "$(agents_running_list)"
  printf 'mise\t%s\n' "$(mise_unused_mb)"
  printf 'journal\t%s\n' "$(journal_size_mb)"
}

dev_cache_clean() {
  safe_clear_dir "$HOME/.cache/pip"
  safe_clear_dir "$HOME/.npm"
  safe_clear_dir "$HOME/.cargo/registry"
  # Go module cache is often read-only.
  if [ -d "$HOME/go/pkg/mod" ] && [ ! -L "$HOME/go/pkg/mod" ]; then
    chmod -R u+w "$HOME/go/pkg/mod" 2>/dev/null || true
  fi
  safe_clear_dir "$HOME/go/pkg/mod"
  return 0
}

cleanup_run() {
  case "$1" in
    pacman) pkexec paccache -r -u -k0 ;;
    coredump) pkexec_safe_clear_dir /var/lib/systemd/coredump ;;
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
    agents) agents_cache_clean ;;
    mise) mise_unused_clean ;;
    journal) pkexec journalctl --vacuum-size=100M ;;
    *) exit 1 ;;
  esac
}

cmd="${1:-}"
shift || true
case "$cmd" in
  packages-list) packages_list ;;
  packages-orphans) packages_orphans ;;
  packages-last-used) packages_last_used "$@" ;;
  packages-remove) packages_remove "$@" ;;
  packages-pacnew) packages_pacnew ;;
  packages-pacnew-remove) packages_pacnew_remove "$@" ;;
  agents-list) agents_list ;;
  agents-remove) agents_remove "$@" ;;
  webapps-list) webapps_list ;;
  webapps-remove) webapps_remove "$@" ;;
  tui-list) tui_list ;;
  tui-remove) tui_remove "$@" ;;
  autostart-list) autostart_list ;;
  autostart-disable) autostart_disable "$@" ;;
  autostart-enable) autostart_enable "$@" ;;
  systemd-list) systemd_user_list ;;
  systemd-disable) systemd_user_disable "$@" ;;
  systemd-enable) systemd_user_enable "$@" ;;
  cleanup-status) cleanup_status ;;
  cleanup-run) cleanup_run "$@" ;;
  *) echo "unknown command: $cmd" >&2; exit 1 ;;
esac
