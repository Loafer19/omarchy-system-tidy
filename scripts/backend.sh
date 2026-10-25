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

autostart_list() {
  local dirs=("$HOME/.config/autostart" "$ROOT/etc/xdg/autostart")
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
  name=$(basename -- "$name")
  name=${name%.desktop}
  case "$name" in
    "" | .* | *..* | */*) exit 1 ;;
  esac
  [[ "$name" != *$'\n'* && "$name" != *'/'* ]] || exit 1

  local dir="$HOME/.config/autostart"
  local target="$dir/$name.desktop"
  mkdir -p "$dir"

  # temp + rename so we never follow a symlink at $target.
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

# Only ~/.config/systemd/user/ — never vendor session units.
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

# Session/cache paths only — leave auth, settings, skills alone.
agents_cache_paths() {
  local share="${XDG_DATA_HOME:-$HOME/.local/share}"
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}"
  cat <<EOF
$HOME/.claude/projects
$HOME/.claude/cache
$HOME/.claude/file-history
$HOME/.claude/shell-snapshots
$HOME/.claude/session-env
$HOME/.claude/paste-cache
$HOME/.claude/sessions
$HOME/.claude/telemetry
$HOME/.claude/backups
$HOME/.claude/plans
$HOME/.claude/jobs
$HOME/.claude/plugins/cache
$HOME/.claude/history.jsonl
$HOME/.codex/.tmp
$HOME/.codex/tmp
$HOME/.pi/agent/sessions
$HOME/.omp/agent/sessions
$HOME/.omp/logs
$HOME/.copilot/logs
$share/opencode
$cache/opencode
EOF
}

agents_cache_mb() {
  local total=0 size path
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ -d "$path" ]; then
      size=$(dir_size_mb "$path")
    elif [ -f "$path" ]; then
      size=$(du -sm "$path" 2>/dev/null | cut -f1 || true)
    else
      size=0
    fi
    total=$((total + ${size:-0}))
  done < <(agents_cache_paths)
  size=$(du -sm "$HOME"/.codex/*.sqlite "$HOME"/.codex/*.sqlite-wal "$HOME"/.codex/*.sqlite-shm 2>/dev/null \
    | awk '{t += $1} END { printf "%.0f", t + 0 }' || echo 0)
  total=$((total + ${size:-0}))
  echo "$total"
}

agents_cache_clean() {
  local path opencode_share="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    [ -L "$path" ] && continue
    if [ -d "$path" ]; then
      if [ "$path" = "$opencode_share" ]; then
        find "$path" -mindepth 1 -maxdepth 1 ! -name 'auth.json' -exec rm -rf {} + 2>/dev/null || true
      else
        safe_clear_dir "$path"
      fi
    elif [ -f "$path" ]; then
      rm -f "$path"
    fi
  done < <(agents_cache_paths)
  rm -f "$HOME/.claude/mcp-needs-auth-cache.json" "$HOME/.claude/daemon.log"
  rm -f "$HOME"/.codex/*.sqlite "$HOME"/.codex/*.sqlite-wal "$HOME"/.codex/*.sqlite-shm
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
  printf 'pacman\t%s\n' "$(dir_size_mb "$ROOT/var/cache/pacman/pkg/")"
  printf 'coredump\t%s\n' "$(dir_size_mb "$ROOT/var/lib/systemd/coredump/")"
  printf 'trash\t%s\n' "$(dir_size_mb "$HOME/.local/share/Trash/")"
  printf 'docker\t%s\n' "$(docker_size_mb)"
  printf 'browser\t%s\n' "$(browser_cache_mb)"
  printf 'aur\t%s\n' "$(aur_cache_mb)"
  printf 'dev\t%s\n' "$(dev_cache_mb)"
  printf 'agents\t%s\n' "$(agents_cache_mb)"
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
  systemd-list) systemd_user_list ;;
  systemd-disable) systemd_user_disable "$@" ;;
  cleanup-status) cleanup_status ;;
  cleanup-run) cleanup_run "$@" ;;
  *) echo "unknown command: $cmd" >&2; exit 1 ;;
esac
