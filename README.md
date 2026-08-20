# System Tidy — package/webapp/autostart/cleanup audit for Omarchy

A bar widget for [Omarchy](https://github.com/basecamp/omarchy) that shows
what's cluttering your system and lets you clean it in one panel.

![Packages tab](preview.png)

Click the broom in the bar:

- **Packages** — everything installed beyond Omarchy's defaults, with size,
  install date, and last-used time (from binary atime). Toggle **Orphans**
  for packages nothing depends on anymore. One-click remove either way,
  snapshotted first via `snapper` if it's set up.
- **Webapps** — launchers from `omarchy webapp install`, one-click remove.
- **Autostart** — user + system autostart entries, one-click disable.
- **Cleanup** — pacman cache, coredumps, trash, Docker, browser cache,
  journal logs, plus an orphan-packages summary linking back to Packages.
  Each row says what it does and doesn't touch.

![Cleanup tab](preview-cleanup.png)

Status line shows Done/Failed for a couple seconds after every action.

## Requirements

Stock Omarchy plus `pacman-contrib`. Package removal, pacman cache trim,
coredump/journal cleanup go through `pkexec`. Docker prune and
browser-cache/trash clearing run as your own user.

## Install

```bash
omarchy plugin add https://github.com/Loafer19/omarchy-system-tidy --enable
```

## Uninstall

```bash
omarchy plugin remove yoyo.system-tidy
```

This removes the plugin only — packages, webapps, and autostart entries you
cleaned up with it are unaffected either way.

## Safety

Package removal is `pacman -Rns` — only that package's own dependencies go
with it — and takes a `snapper` checkpoint first when snapper is present,
so a bad removal has an actual way back. Docker cleanup is
`docker system prune -f`, no `-a`, so images you're using stay. Nothing
runs without a click.
