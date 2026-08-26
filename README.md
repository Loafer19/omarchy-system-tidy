# System Tidy — system cleanup for Omarchy

A bar widget for [Omarchy](https://github.com/basecamp/omarchy) that audits
clutter and cleans it from one panel.

![Cleanup tab](preview.png)

Click the broom:

- **Packages** — **Added** (beyond Omarchy defaults), **Orphans**, **Pacnew**
  (`.pacnew`/`.pacsave`/`.pacorig`), and **Agent CLIs** (mise tools like Claude
  Code, Codex, Grok). Package remove uses `pacman -Rns` after
  `omarchy snapshot create`. Agent remove drops the tool; session history
  stays until Cleanup → Agent caches.
- **Cleanup** — pacman/AUR/dev caches, agent chat history & tmp (login stays),
  Mise unused (`mise prune` + download cache), Docker prune (no `-a`),
  Chrome/Chromium cache, coredumps, journal, trash. Clean is disabled at 0 MiB.
- **Startup** — **Autostart** `.desktop` entries and **Services** (only units
  under `~/.config/systemd/user/`).
- **Launchers** — **Web Apps** and **TUIs** from `omarchy webapp|tui install`.

Keyboard: **Tab** cycles tabs; **h/l** chips; **j/k** rows; **Enter** acts.
Status shows Done/Failed briefly after each action.

## Requirements

Stock Omarchy + `pacman-contrib`. Package remove, pacnew, paccache, coredump,
and journal ask for a password (`pkexec`).

## Install

```bash
omarchy plugin add https://github.com/Loafer19/omarchy-system-tidy --enable
```

## Uninstall

```bash
omarchy plugin remove yoyo.system-tidy
```
