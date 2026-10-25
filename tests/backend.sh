#!/usr/bin/env bash
# Fixture tests for scripts/backend.sh. Every command that could change the
# real system (pacman, pkexec, paccache, systemctl, docker, mise, journalctl,
# omarchy*) is a stub that only logs its argv, HOME is a temp dir and
# TIDY_ROOT points the read-only system paths at a fixture tree.
#   tests/backend.sh
set -uo pipefail
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
exists() { if [ -e "$2" ]; then ok "$1"; else no "$1" "gone: $2"; fi; }
gone() { if [ ! -e "$2" ]; then ok "$1"; else no "$1" "still there: $2"; fi; }

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
stub expac 'shift 2; fmt=$1; shift; for p in "$@"; do grep -P "^$p\t" "$FX/sizes" | cut -f2 || echo "0.00 MiB"; done; [ $# -gt 0 ] || while read -r p; do printf "%s\t%s\n" "$p" "$(grep -P "^$p\t" "$FX/sizes" | cut -f2)"; done'
stub pkexec
stub paccache 'cat "$FX/paccache" 2>/dev/null'
stub systemctl 'cat "$FX/systemctl.$1.$2" 2>/dev/null; exit 0'
stub docker 'cat "$FX/docker" 2>/dev/null'
stub mise
stub journalctl 'cat "$FX/journal" 2>/dev/null'
stub omarchy
stub omarchy-tui-remove
stub pgrep 'for n in $(cat "$FX/running" 2>/dev/null); do [ "${!#}" = "$n" ] && exit 0; done; exit 1'
stub sudo 'echo "sudo must never be called" >&2; exit 99'

export PATH="$bin:/usr/bin:/bin"
export HOME=$tmp/home TIDY_ROOT=$tmp/root XDG_DATA_HOME= XDG_CACHE_HOME=
mkdir -p "$HOME" "$TIDY_ROOT/usr/share/omarchy/install" "$TIDY_ROOT/var/log" "$TIDY_ROOT/etc"
[ "$(command -v pkexec)" = "$bin/pkexec" ] || { echo "stubs not first on PATH, refusing to run" >&2; exit 2; }
B() { bash "$backend" "$@"; }
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
expect "user apps not protected" "$(awk -F'\t' '$5==""{printf "%s ", $1}' <<<"$list")" "cmake linux-wifi-hotspot steam "
for p in sudo omarchy amd-ucode linux mkinitcpio limine nvidia-dkms base; do
  reset_calls
  err=$(B packages-remove cmake "$p" 2>&1); rc=$?
  expect "remove refuses $p (rc 2, no pkexec)" "$rc:$(calls)" "2:"
done
expect_has "refusal says why" "$err" "protected system package"
reset_calls; B packages-remove -- >/dev/null 2>&1; expect "option-like names refused" "$?:$(calls)" "2:"
reset_calls; B packages-remove '-Rdd' >/dev/null 2>&1; expect "flag injection refused" "$?:$(calls)" "2:"
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

printf '\nRESULT  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
