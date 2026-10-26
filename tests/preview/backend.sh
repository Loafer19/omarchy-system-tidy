#!/usr/bin/env bash
# Fake backend for tools/render-previews.sh: fixed, made-up lists so the
# preview shows no real package names, paths or sizes. Read-only: every
# action verb is refused.
case "${1:-}" in
  packages-list) printf '%s\n' \
    'blender	412.6	2026-09-12		' 'libreoffice-fresh	388.1	2026-08-30		' \
    'obs-studio	96.4	2026-10-02		' 'inkscape	88.9	2026-09-18		' \
    'gimp	71.2	2026-09-18		' 'kdenlive	54.0	2026-10-05		' \
    'vlc	12.7	2026-07-21		' 'htop	0.4	2026-06-03		' ;;
  packages-orphans) printf 'python-example\t3.10\t2026-10-02\t\t\n' ;;
  packages-last-used) shift; for p in "$@"; do printf '%s\t%s\n' "$p" "3d ago"; done ;;
  packages-pacnew) printf 'mirrorlist.pacnew\t5203\t/etc/pacman.d/mirrorlist.pacnew\n' ;;
  agents-list) printf 'example\tExample CLI\t120\tnpm\n' ;;
  webapps-list|tui-list) ;;
  autostart-list) printf 'example-applet\tenabled\t/etc/xdg/autostart\tsystem\n' ;;
  systemd-list) printf 'example.service\tenabled\tservice\n' ;;
  cleanup-status) printf '%s\n' 'pacman	312' 'pacman-total	4210' 'coredump	1480' 'trash	240' \
    'docker	0' 'browser	1630' 'aur	520' 'dev	760' 'agents	14' 'agents-running	' \
    'mise	410' 'journal	64.0' 'journal-total	164.0' ;;
  *) echo "preview backend: refused ${1:-}" >&2; exit 1 ;;
esac
