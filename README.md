# System Tidy — cleanup for Omarchy

Bar widget that audits clutter and cleans it from one panel.

![Cleanup tab](preview.png)

- **Packages** — **Extra** (beyond Omarchy defaults), **Orphans**, **Pacnew**,
  **Agent CLIs** (mise: Claude Code, Codex, Grok, …). Package remove is
  `pacman -Rns` after `omarchy snapshot create`. Agent remove drops the tool;
  history stays until Cleanup → Agent caches.
- **Cleanup** — pacman/AUR/dev caches, agent history & tmp, Mise unused
  (`mise prune` + download cache), Docker prune (no `-a`), Chrome/Chromium
  cache, coredumps, journal, trash. Clean disabled at 0 MiB.
- **Startup** — Autostart `.desktop` + Services (`~/.config/systemd/user/` only).
- **Launchers** — Web Apps and TUIs from `omarchy webapp|tui install`.

**Tab** cycles tabs · **h/l** chips · **j/k** rows · **Enter** acts.

## Requirements

Omarchy + `pacman-contrib`. Package remove, pacnew, paccache, coredump, and
journal use `pkexec`.

## Install

```bash
omarchy plugin add https://github.com/Loafer19/omarchy-system-tidy --enable
```

## Uninstall

```bash
omarchy plugin remove yoyo.system-tidy
```
