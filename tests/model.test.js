// Sanity tests for Model.js outside QML:  node tests/model.test.js
const fs = require("fs"), path = require("path"), cp = require("child_process")
const { dir, load, eq, done } = require("./harness")
const M = load("Model.js")

// --- protected packages: UI list must equal the backend list -------------
const backend = fs.readFileSync(path.join(dir, "scripts/backend.sh"), "utf8")
const m = backend.match(/^PROTECTED_RE='([^']+)'/m)
eq("backend defines PROTECTED_RE", !!m, true)
eq("Model.js PROTECTED_RE == backend PROTECTED_RE", M.PROTECTED_RE.source, m ? m[1] : null)
const names = ["omarchy", "omarchy-keyring", "omasnap", "sudo", "linux", "linux-zen-headers", "linux-firmware-intel",
  "amd-ucode", "v4l2loopback-dkms", "nvidia-open-dkms", "mesa", "vulkan-radeon", "hyprland", "pipewire", "expac",
  "google-chrome", "steam", "linux-wifi-hotspot", "omarchyish", "sudo-rs", "mesa-demos", "pacman-mirrorlist", ""]
const want = [true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
  false, false, false, false, false, false, false, false]
eq("isProtectedPackage", names.map(n => M.isProtectedPackage(n)), want)
try {
  const out = cp.execFileSync("bash", ["-c", 're="$1"; shift; for n; do [[ $n =~ $re ]] && echo 1 || echo 0; done', "_", m[1], ...names.slice(0, -1)]).toString().trim().split("\n")
  eq("bash [[ =~ ]] agrees with JS on every sample", out.map(x => x === "1"), want.slice(0, -1))
} catch (e) { eq("bash regex check ran", String(e), "") }

// --- packages -------------------------------------------------------------
const pk = M.parsePackages("steam\t19.5\t2026-09-29\t\t\nsudo\t7.8\t2026-09-29\t\tprotected\ngoogle-chrome\t444.2\t2026-09-29\t3d ago\t\nlinux\t140\t2026-09-01\t\t\n")
eq("parsePackages: removable first, largest first, protected last", pk.map(p => p.name), ["google-chrome", "steam", "linux", "sudo"])
eq("parsePackages: protected column", pk.map(p => p.protected), [false, false, true, true])
eq("parsePackages: lastUsed kept", pk[0].lastUsed, "3d ago")
eq("parsePackages: old 4-column backend falls back to the regex", M.parsePackages("sudo\t7.8\t2026-09-29\t\n").map(p => p.protected), [true])
eq("parsePackages: empty", M.parsePackages("").length, 0)
const lu = M.withLastUsed(pk, M.parseLastUsed("steam\t12d ago\nsudo\ttoday\n"))
eq("withLastUsed merges + keeps protected", lu.map(p => [p.name, p.lastUsed, p.protected]),
  [["google-chrome", "3d ago", false], ["steam", "12d ago", false], ["linux", "", true], ["sudo", "today", true]])
eq("parsePacnewFiles largest first", M.parsePacnewFiles("a.pacnew\t10\t/etc/a.pacnew\nb.pacnew\t900\t/etc/b.pacnew\n").map(r => r.name), ["b.pacnew", "a.pacnew"])
eq("parseNameList sorted", M.parseNameList("zeta\nalpha\n\n").map(r => r.name), ["alpha", "zeta"])

// --- startup ---------------------------------------------------------------
const as = M.parseAutostart("steam\tenabled\t~/.config/autostart\tuser\ngnome-keyring-secrets\tenabled\t/etc/xdg/autostart\tsystem\n")
eq("parseAutostart sorted + origin", as.map(r => [r.name, r.origin]), [["gnome-keyring-secrets", "system"], ["steam", "user"]])
eq("autostartWarning", ["gnome-keyring-secrets", "at-spi-dbus-bus", "xdg-desktop-portal-hyprland", "polkit-gnome-agent", "org.fcitx.Fcitx5", "steam"].map(M.autostartWarning).map(w => w !== ""),
  [true, true, true, true, true, false])
eq("parseSystemdUnits", M.parseSystemdUnits("fluxd.service\tenabled\tservice\nbackup.timer\tdisabled\ttimer\n").map(r => r.name), ["backup.timer", "fluxd.service"])

// --- cleanup ---------------------------------------------------------------
const cs = M.parseCleanupStatus("pacman\t289\npacman-total\t5498\ncoredump\t2773\ndocker\t00\nagents\t6\nagents-running\tcodex claude\njournal\t71.4\njournal-total\t171.4\nbogus\t5\n")
eq("parseCleanupStatus values", [cs.pacman, cs.pacmanTotal, cs.coredump, cs.docker, cs.agents, cs.journal, cs.journalTotal, cs.trash],
  [289, 5498, 2773, 0, 6, 71.4, 171.4, 0])
eq("parseCleanupStatus agents-running", cs.agentsRunning, "codex claude")
eq("parseCleanupStatus ignores unknown keys", cs.bogus, undefined)
eq("parseCleanupStatus empty", M.parseCleanupStatus("").agentsRunning, "")
eq("parseAgents largest first", M.parseAgents("claude\tClaude Code\t10\tx\ncodex\tCodex\t50\ty\n").map(r => r.id), ["codex", "claude"])

// --- formatting ------------------------------------------------------------
eq("formatMib", [M.formatMib(0), M.formatMib("289"), M.formatMib(1951), M.formatMib("x")], ["0.0 MiB", "289.0 MiB", "1.91 GiB", "0 MiB"])
eq("lastUserLine: last tagged line, tag stripped", M.lastUserLine("noise\ntidy: one\nmore\ntidy: two\n"), "two")
eq("lastUserLine: nothing tagged", [M.lastUserLine("plain\n"), M.lastUserLine(""), M.lastUserLine(null)], ["", "", ""])
eq("formatBytes", [M.formatBytes(5), M.formatBytes(5203), M.formatBytes(3 * 1048576), M.formatBytes("")], ["5 B", "5.1 KiB", "3.00 MiB", "0 B"])

done()
