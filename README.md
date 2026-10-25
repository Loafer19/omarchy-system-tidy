# System Tidy — cleanup for Omarchy

Bar widget that audits clutter and cleans it from one panel.

![Cleanup tab](preview.png)

## Tabs

- **Packages**
  - **Extra** — packages beyond the Omarchy defaults, largest first, with
    install date and last use. Remove runs `pacman -Rns` after an
    `omarchy-snapshot create` (snapper fallback).
  - **Orphans** — dependencies nothing needs any more (`pacman -Qdtq`).
  - **Pacnew** — `.pacnew`/`.pacsave`/`.pacorig` files under `/etc`. Merge
    them with `pacdiff` first; Remove only deletes the leftover file.
  - **Agent CLIs** — agent tools installed through mise (Claude Code, Codex,
    Grok, …). Remove drops the tool; its history stays.
- **Cleanup** — see the table below. Sizes are what Clean would actually
  free; the footer shows the total.
- **Startup** — **Autostart** `.desktop` entries (user and system) and user
  **Services** (`~/.config/systemd/user/` only). Disable and Enable both work;
  systemd changes apply right away (`--now`).
- **Launchers** — Web Apps and TUIs added with `omarchy webapp|tui install`.

## What each cleanup removes

| Row | Removes | Keeps |
|---|---|---|
| Pacman cache | Cached packages that are no longer installed (`paccache -r -u -k0`) | Cache of every installed package, so downgrades still work |
| AUR build cache | `~/.cache/yay`, `~/.cache/paru` | — |
| Dev tool caches | `~/.cache/pip`, `~/.npm`, `~/.cargo/registry`, `~/go/pkg/mod` (all re-download on demand) | Installed tools, project files |
| Agent caches | Temp, log and cache dirs only: Claude `cache`, `paste-cache`, `shell-snapshots`, `session-env`, `telemetry`, `statsig`, `debug`, `plugins/cache`; Codex `.tmp`, `tmp`, `log`; omp/Copilot `logs`; opencode cache and log | Memories, goals, `projects/*/memory`, sessions, history, auth, config, settings, any `*.sqlite`. An agent that is running is skipped |
| Mise unused | `mise prune` (versions no config uses) + `mise cache clear` | Versions any config still uses |
| Docker | `docker system prune -f`: stopped containers, dangling images, unused networks, build cache | Tagged images, volumes (no `-a`, no `--volumes`) |
| Browser cache | Page caches of Chrome, Chromium, Brave, Vivaldi and Firefox (`cache2`). A running browser is skipped | Profiles, cookies, logins, history |
| Coredumps | `/var/lib/systemd/coredump/*` | — |
| Journal logs | Vacuums the journal down to 100 MiB (row shows only the part above that) | The newest 100 MiB of logs |
| Trash | `~/.local/share/Trash` | — |

## Safety

- Every destructive action asks twice: the first **Enter** (or click) arms
  the row and says what will happen, the second confirms. **Esc**, moving
  away, or 4 seconds of nothing cancels. Re-enabling a startup item runs
  straight away.
- Cleanup rows that cannot be undone (agent caches, trash) carry an
  **irreversible** badge. Package removal takes a snapshot first.
- Core system packages are marked **protected** and have no Remove button;
  `backend.sh packages-remove` refuses them too. The list covers Omarchy
  itself, base/glibc/bash/coreutils, systemd, dbus, pacman/expac, sudo/polkit,
  kernels, headers, firmware, microcode, DKMS modules, mkinitcpio/dracut,
  boot loaders, snapper/btrfs, cryptsetup/lvm2, GPU drivers (nvidia, mesa,
  vulkan), Hyprland/uwsm/Quickshell, networking, display managers and
  PipeWire. It lives in `PROTECTED_RE` in `scripts/backend.sh` (mirrored in
  `Model.js`; a test keeps them identical).
- Startup refuses to edit symlinked entries and never deletes vendor
  `.desktop` files — it writes a `Hidden=true` override in
  `~/.config/autostart` instead.

## Keys

**Tab** tabs · **h/l** filters · **j/k** rows · **Enter** act / confirm ·
**Esc** cancel / close. The footer always shows the keys that apply now.

## Requirements

- Omarchy (Quickshell bar)
- `pacman-contrib` (paccache, pacdiff) and `expac` (package sizes)
- Optional: `docker`, `mise`
- Package and pacnew removal, pacman cache, coredumps and journal go through
  `pkexec`.

## Open from a keybinding

```bash
omarchy shell shell toggle yoyo.system-tidy
```

On several monitors this opens the panel on the focused one. The legacy
`qs ipc call yoyo.system-tidy toggle` target still works.

## Tests

```bash
tests/run.sh   # node tests/model.test.js + bash tests/backend.sh
```

The backend tests run against stubbed `pacman`, `expac`, `pkexec`,
`paccache`, `systemctl`, `docker`, `mise` and `journalctl` in a temporary
`HOME`; they never touch the real system.

## Install

```bash
omarchy plugin add https://github.com/Loafer19/omarchy-system-tidy --enable
```

## Uninstall

```bash
omarchy plugin remove yoyo.system-tidy
```

## License

MIT — see [LICENSE](LICENSE).
