#!/usr/bin/env bash
# Fixture tests for scripts/backend.sh. Every command that could change the
# real system (pacman, pkexec, paccache, systemctl, docker, mise, journalctl,
# omarchy*) is a stub that only logs its argv, HOME is a temp dir and
# TIDY_ROOT points the read-only system paths at a fixture tree.
#   tests/backend.sh
# Stub bodies below are single-quoted scripts; their $vars are theirs.
# shellcheck disable=SC2016
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
backend=$here/../scripts/backend.sh
tmp=$(mktemp -d /tmp/tidy-test.XXXXXX)
trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok() { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; fail=$((fail + 1)); }
expect() { if [[ $2 == "$3" ]]; then ok "$1"; else no "$1" "got: $2 | want: $3"; fi; }
expect_has() { if [[ $2 == *"$3"* ]]; then ok "$1"; else no "$1" "missing: $3 in: $2"; fi; }
expect_lacks() { if [[ $2 != *"$3"* ]]; then ok "$1"; else no "$1" "unexpected: $3"; fi; }
exists() { if [[ -e "$2" ]]; then ok "$1"; else no "$1" "gone: $2"; fi; }
gone() { if [[ ! -e "$2" ]]; then ok "$1"; else no "$1" "still there: $2"; fi; }

bin=$tmp/bin; mkdir -p "$bin"
export CALLS=$tmp/calls.log FX=$tmp/fx
mkdir -p "$FX"
: > "$CALLS"
stub() { # stub NAME BODY — BODY runs after the argv is logged
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "%s" "$*" >> "$CALLS"\n%s\n' "$1" "${2:-exit 0}" > "$bin/$1"
  chmod +x "$bin/$1"
}
stub pacman '
case "$1" in
  -Qeq) cat "$FX/explicit" ;;
  -Qtdq) cat "$FX/orphans" 2>/dev/null; [ -s "$FX/orphans" ] || exit 1 ;;
  -Ql) exit 0 ;;
  -Qq) cat "$FX/explicit" ;;
esac'
stub expac 'shift 2; fmt=$1; shift; for p in "$@"; do s=$(grep -P "^$p\t" "$FX/sizes" | cut -f2); s=${s:-0.00 MiB}; if [ "$fmt" = "%n\t%m" ] || [ "$fmt" = "%n\\t%m" ]; then printf "%s\t%s\n" "$p" "$s"; else echo "$s"; fi; done'
stub pkexec
stub paccache 'cat "$FX/paccache" 2>/dev/null'
stub systemctl 'cat "$FX/systemctl.$1.$2" 2>/dev/null; exit 0'
stub docker '[ -f "$FX/docker-denied" ] && { echo "permission denied" >&2; exit 1; }
case "$1 $2" in
  "system df") cat "$FX/docker-df" 2>/dev/null ;;
  "images -f") cat "$FX/docker-dangling" 2>/dev/null ;;
esac'
stub mise
stub journalctl 'cat "$FX/journal" 2>/dev/null'
stub omarchy
stub omarchy-tui-remove
stub pgrep 'for n in $(cat "$FX/running" 2>/dev/null); do [ "${!#}" = "$n" ] && exit 0; done; exit 1'
stub sudo 'echo "sudo must never be called" >&2; exit 99'

export PATH="$bin:/usr/bin:/bin"
export HOME=$tmp/home TIDY_ROOT=$tmp/root XDG_DATA_HOME='' XDG_CACHE_HOME=
mkdir -p "$HOME" "$TIDY_ROOT/usr/share/omarchy/install" "$TIDY_ROOT/var/log" "$TIDY_ROOT/etc"
[[ "$(command -v pkexec)" = "$bin/pkexec" ]] || { echo "stubs not first on PATH, refusing to run" >&2; exit 2; }
B() { bash "$backend" "$@"; }
# rc_of CMD… — CMD's exit status (output dropped), without tripping set -e.
rc_of() { local rc=0; "$@" >/dev/null 2>&1 || rc=$?; echo "$rc"; }
calls() { cat "$CALLS"; }
reset_calls() { : > "$CALLS"; }

# ---------------------------------------------------------------- packages
printf 'base\nhyprland\n' > "$TIDY_ROOT/usr/share/omarchy/install/omarchy-base.packages"
: > "$TIDY_ROOT/usr/share/omarchy/install/omarchy-other.packages"
printf '%s\n' base hyprland steam amd-ucode omarchy-settings v4l2loopback-dkms sudo linux-wifi-hotspot cmake > "$FX/explicit"
printf 'steam\t512.00 MiB\ncmake\t40.10 MiB\nsudo\t7.00 MiB\n' > "$FX/sizes"
printf '[2026-01-02T10:00:00+0200] [ALPM] installed steam (1.0-1)\n[2026-03-04T10:00:00+0200] [ALPM] installed steam-native (1)\n' > "$TIDY_ROOT/var/log/pacman.log"

echo "== protected packages"
list=$(B packages-list)
expect "defaults are not listed" "$(cut -f1 <<<"$list" | tr '\n' ' ')" "amd-ucode cmake linux-wifi-hotspot omarchy-settings steam sudo v4l2loopback-dkms "
expect "protected column" "$(awk -F'\t' '$5=="protected"{printf "%s ", $1}' <<<"$list")" "amd-ucode omarchy-settings sudo v4l2loopback-dkms "
expect "sizes from one expac call" "$(awk -F'\t' '$1=="steam"||$1=="cmake"{printf "%s=%s ", $1, $2}' <<<"$list")" "cmake=40.10 MiB steam=512.00 MiB "
expect "install date: exact name, last install" "$(awk -F'\t' '$1=="steam"{print $3}' <<<"$list")" "2026-01-02"
expect "unknown date" "$(awk -F'\t' '$1=="cmake"{print $3}' <<<"$list")" "unknown"
expect "user apps not protected" "$(awk -F'\t' '$5==""{printf "%s ", $1}' <<<"$list")" "cmake linux-wifi-hotspot steam "
for p in sudo omarchy amd-ucode linux mkinitcpio limine nvidia-dkms base; do
  reset_calls
  rc=0; err=$(B packages-remove cmake "$p" 2>&1) || rc=$?
  expect "remove refuses $p (rc 2, no pkexec)" "$rc:$(calls)" "2:"
done
expect_has "refusal says why" "$err" "protected system package"
reset_calls; expect "option-like names refused" "$(rc_of B packages-remove --):$(calls)" "2:"
reset_calls; expect "flag injection refused" "$(rc_of B packages-remove '-Rdd'):$(calls)" "2:"
reset_calls; B packages-remove steam cmake; expect_has "allowed remove goes through pkexec" "$(calls)" "pkexec env PATH="
expect_has "pacman args end with -- names" "$(calls)" "pacman -Rns --noconfirm -- \"\$@\""


# ---------------------------------------------------------------- agents
echo "== agent caches"
mk() { mkdir -p "$(dirname "$1")"; head -c 2000000 /dev/zero > "$1"; }
for f in .claude/cache/a .claude/paste-cache/b .claude/debug/c .claude/projects/-home-x/memory/MEMORY.md \
  .claude/projects/-home-x/s1.jsonl .claude/history.jsonl .claude/settings.json .claude/.credentials.json \
  .claude/plans/p.md .claude/file-history/f .claude/backups/b \
  .codex/tmp/t .codex/log/l .codex/memories_1.sqlite .codex/goals_1.sqlite .codex/state_5.sqlite-wal \
  .codex/sessions/2026/s.jsonl .codex/auth.json .codex/config.toml .codex/tmp/memories/keep \
  .cache/opencode/x .local/share/opencode/log/y .local/share/opencode/storage/z .local/share/opencode/auth.json; do
  mk "$HOME/$f"
done
st=$(B cleanup-status)
expect "agents size counts only caches" "$(awk -F'\t' '$1=="agents"' <<<"$st")" "$(printf 'agents\t16')"
expect "nothing running" "$(awk -F'\t' '$1=="agents-running"' <<<"$st")" "$(printf 'agents-running\t')"
echo codex > "$FX/running"
expect "running agent reported" "$(B cleanup-status | awk -F'\t' '$1=="agents-running"{print $2}')" "codex"
out=$(B cleanup-run agents)
expect "skip message" "$out" "tidy: skipped running codex"
exists "running codex tmp untouched" "$HOME/.codex/tmp/t"
gone "claude cache cleared" "$HOME/.claude/cache/a"
gone "claude debug cleared" "$HOME/.claude/debug/c"
gone "opencode cache cleared" "$HOME/.cache/opencode/x"
gone "opencode log cleared" "$HOME/.local/share/opencode/log/y"
for f in .claude/projects/-home-x/memory/MEMORY.md .claude/projects/-home-x/s1.jsonl .claude/history.jsonl \
  .claude/settings.json .claude/.credentials.json .claude/plans/p.md .claude/file-history/f .claude/backups/b \
  .codex/memories_1.sqlite .codex/goals_1.sqlite .codex/state_5.sqlite-wal .codex/sessions/2026/s.jsonl \
  .codex/auth.json .codex/config.toml .local/share/opencode/storage/z .local/share/opencode/auth.json; do
  exists "kept $f" "$HOME/$f"
done
: > "$FX/running"
out=$(B cleanup-run agents)
expect "no skip message when idle" "$out" ""
gone "codex tmp cleared when idle" "$HOME/.codex/tmp/t"
exists "memories dir inside a cache dir kept" "$HOME/.codex/tmp/memories/keep"
exists "codex memories still kept" "$HOME/.codex/memories_1.sqlite"


# ---------------------------------------------------------------- sizes
echo "== reclaimable sizes"
mkdir -p "$TIDY_ROOT/var/cache/pacman/pkg"; head -c 3000000 /dev/zero > "$TIDY_ROOT/var/cache/pacman/pkg/x.pkg.tar.zst"
printf '\n==> finished dry run: 49 candidates (disk space saved: 289.42 MiB)\n' > "$FX/paccache"
st=$(B cleanup-status)
v() { awk -F'\t' -v k="$1" '$1==k{print $2}' <<<"$st"; }
expect "pacman = paccache dry-run saving" "$(v pacman)" "289"
expect "pacman-total = whole cache" "$(v pacman-total)" "3"
expect_has "paccache dry run only" "$(calls)" "paccache -d -u -k0"
expect_lacks "paccache never -r in status" "$(calls)" "paccache -r"
printf '\n==> finished dry run: 3 candidates (disk space saved: 1.50 GiB)\n' > "$FX/paccache"
st=$(B cleanup-status); expect "GiB converted" "$(v pacman)" "1536"
printf '==> no candidate packages found for pruning\n' > "$FX/paccache"
st=$(B cleanup-status); expect "nothing to prune" "$(v pacman)" "0"
printf 'Images|1.2GB (50%%)\nContainers|512MB (100%%)\nLocal Volumes|9GB (90%%)\nBuild Cache|980.5kB\n' > "$FX/docker-df"
printf '100MB\n20MB\n' > "$FX/docker-dangling"
st=$(B cleanup-status); expect "docker = containers + build cache + dangling, no volumes" "$(v docker)" "633"
touch "$FX/docker-denied"
st=$(B cleanup-status); expect "docker socket denied -> 0 (was '00')" "$(v docker)" "0"
rm -f "$FX/docker-denied"

# ---------------------------------------------------------------- startup
echo "== startup"
ua=$HOME/.config/autostart sa=$TIDY_ROOT/etc/xdg/autostart
mkdir -p "$ua" "$sa"
printf '[Desktop Entry]\nExec=/usr/bin/gnome-keyring-daemon\n' > "$sa/gnome-keyring-secrets.desktop"
printf '[Desktop Entry]\nExec=fcitx5\n' > "$sa/org.fcitx.Fcitx5.desktop"
printf '[Desktop Entry]\nExec=steam -silent\nhidden = TRUE\n' > "$ua/steam.desktop"
printf '[Desktop Entry]\nExec=mine\n' > "$HOME/real-mine.desktop"; ln -s "$HOME/real-mine.desktop" "$ua/mine.desktop"
list=$(B autostart-list)
expect "case/space-insensitive Hidden" "$(grep '^steam' <<<"$list" | cut -f2)" "disabled"
expect "vendor entry is system" "$(grep '^gnome-keyring-secrets' <<<"$list" | cut -f2,4)" "$(printf 'enabled\tsystem')"
B autostart-disable gnome-keyring-secrets
expect "disable vendor = stub override" "$(grep -c '^Exec' "$ua/gnome-keyring-secrets.desktop"):$(grep -c '^Hidden=true' "$ua/gnome-keyring-secrets.desktop")" "0:1"
expect "vendor file untouched" "$(cat "$sa/gnome-keyring-secrets.desktop")" "$(printf '[Desktop Entry]\nExec=/usr/bin/gnome-keyring-daemon')"
expect "listed disabled" "$(B autostart-list | grep '^gnome-keyring-secrets' | cut -f2)" "disabled"
B autostart-enable gnome-keyring-secrets
gone "enable drops our stub" "$ua/gnome-keyring-secrets.desktop"
expect "listed enabled again" "$(B autostart-list | grep '^gnome-keyring-secrets' | cut -f2)" "enabled"
B autostart-enable steam
expect "enable user entry keeps Exec, drops Hidden" "$(cat "$ua/steam.desktop")" "$(printf '[Desktop Entry]\nExec=steam -silent')"
B autostart-disable steam
expect "disable user entry appends Hidden" "$(tail -1 "$ua/steam.desktop")" "Hidden=true"
rc=0; err=$(B autostart-disable mine 2>&1) || rc=$?
expect "symlinked entry refused" "$rc" "3"
expect_has "symlink message" "$err" "symlink"
expect "symlink target untouched" "$(cat "$HOME/real-mine.desktop")" "$(printf '[Desktop Entry]\nExec=mine')"
B autostart-disable ../escape; gone "path in name is stripped to basename" "$HOME/.config/escape.desktop"
rm -f "$ua/escape.desktop"
for bad in .. .hidden -x; do expect "bad autostart name '$bad' refused" "$(rc_of B autostart-disable "$bad")" "2"; done

printf 'fluxd.service enabled enabled\nold.timer disabled enabled\nvendor.service enabled enabled\n' > "$FX/systemctl.--user.list-unit-files"
cat > "$bin/systemctl" <<'S'
#!/usr/bin/env bash
printf "systemctl %s\n" "$*" >> "$CALLS"
case "$*" in
  *list-unit-files*) cat "$FX/systemctl.--user.list-unit-files" ;;
  *"show vendor.service"*) echo /usr/lib/systemd/user/vendor.service ;;
  *"show "*) set -- $*; echo "$HOME/.config/systemd/user/$3" ;;
esac
exit 0
S
chmod +x "$bin/systemctl"
expect "systemd list: user units incl. disabled, no vendor" "$(B systemd-list | cut -f1,2 | tr '\t\n' ': ')" "fluxd.service:enabled old.timer:disabled "
reset_calls; B systemd-disable fluxd.service; expect_has "disable --now --" "$(calls)" "systemctl --user disable --now -- fluxd.service"
reset_calls; B systemd-enable old.timer; expect_has "enable --now --" "$(calls)" "systemctl --user enable --now -- old.timer"
reset_calls; expect "vendor unit refused" "$(rc_of B systemd-disable vendor.service):$(calls | grep -c disable || true)" "2:0"
reset_calls; expect "option-like unit refused" "$(rc_of B systemd-disable --global):$(calls)" "2:"


echo "== journal / browser"
printf 'Archived and active journals take up 171.4M in the file system.\n' > "$FX/journal"
st=$(B cleanup-status)
expect "journal reclaimable = size - 100 MiB" "$(v journal)" "71.4"
expect "journal total kept" "$(v journal-total)" "171.4"
printf 'Archived and active journals take up 80.0M in the file system.\n' > "$FX/journal"
st=$(B cleanup-status); expect "journal under 100 MiB -> 0" "$(v journal)" "0.0"
mk "$HOME/.cache/google-chrome/Default/Cache/x"; mk "$HOME/.cache/BraveSoftware/Brave-Browser/Default/Cache/y"
mk "$HOME/.cache/mozilla/firefox/abc.default/cache2/entries/z"; mk "$HOME/.config/google-chrome/Default/Cookies"
st=$(B cleanup-status); expect "browser counts chrome+brave+firefox" "$(v browser)" "6"
echo chrome > "$FX/running"
out=$(B cleanup-run browser)
expect "running chrome skipped" "$out" "tidy: skipped running chrome"
exists "chrome cache kept while running" "$HOME/.cache/google-chrome/Default/Cache/x"
gone "brave cache cleared" "$HOME/.cache/BraveSoftware/Brave-Browser"
gone "firefox cache2 cleared" "$HOME/.cache/mozilla/firefox/abc.default/cache2/entries"
exists "firefox profile dir kept" "$HOME/.cache/mozilla/firefox/abc.default/cache2"
exists "chrome profile (cookies) never touched" "$HOME/.config/google-chrome/Default/Cookies"
: > "$FX/running"

# ---------------------------------------------------------------- error paths
echo "== error paths"
reset_calls; rc=0; err=$(B bogus-command 2>&1) || rc=$?
expect "unknown command: rc 1, nothing run" "$rc:$(calls)" "1:"
expect "unknown command named" "$err" "unknown command: bogus-command"
reset_calls; expect "no command: rc 1" "$(rc_of B):$(calls)" "1:"
for verb in packages-remove packages-pacnew-remove agents-remove webapps-remove tui-remove \
  autostart-disable autostart-enable systemd-disable systemd-enable; do
  reset_calls; expect "$verb without a target is a no-op" "$(rc_of B "$verb"):$(calls)" "0:"
done
reset_calls; expect "cleanup-run without a target fails, nothing run" "$(rc_of B cleanup-run | sed 's/[1-9][0-9]*/fail/'):$(calls)" "fail:"
reset_calls; expect "unknown cleanup target refused" "$(rc_of B cleanup-run everything):$(calls)" "1:"
reset_calls; expect "invalid package name refused" "$(rc_of B packages-remove 'a b'):$(calls)" "2:"
reset_calls; expect "unknown agent id refused, mise untouched" "$(rc_of B agents-remove no-such-agent):$(calls)" "1:"

mkdir -p "$TIDY_ROOT/etc/pacman.d" "$TIDY_ROOT/srv"
: > "$TIDY_ROOT/etc/pacman.d/mirrorlist.pacnew"; : > "$TIDY_ROOT/etc/pacman.conf"; : > "$TIDY_ROOT/srv/x.pacnew"
ln -s "$TIDY_ROOT/srv/x.pacnew" "$TIDY_ROOT/etc/link.pacnew"
reset_calls; expect "pacnew outside /etc refused" "$(rc_of B packages-pacnew-remove "$TIDY_ROOT/srv/x.pacnew"):$(calls)" "1:"
reset_calls; expect "pacnew symlink out of /etc refused" "$(rc_of B packages-pacnew-remove "$TIDY_ROOT/etc/link.pacnew"):$(calls)" "1:"
reset_calls; expect "non-.pacnew file in /etc refused" "$(rc_of B packages-pacnew-remove "$TIDY_ROOT/etc/pacman.conf"):$(calls)" "1:"
reset_calls; expect "missing pacnew refused" "$(rc_of B packages-pacnew-remove "$TIDY_ROOT/etc/nope.pacnew"):$(calls)" "1:"
reset_calls; expect "dot-dot escape refused" "$(rc_of B packages-pacnew-remove "$TIDY_ROOT/etc/../srv/x.pacnew"):$(calls)" "1:"
reset_calls; B packages-pacnew-remove "$TIDY_ROOT/etc/pacman.d/mirrorlist.pacnew"
expect "nested /etc pacnew removed via pkexec rm" "$(calls)" "pkexec rm -f -- $TIDY_ROOT/etc/pacman.d/mirrorlist.pacnew"

printf '\nRESULT  %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
