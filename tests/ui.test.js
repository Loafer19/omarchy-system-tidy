// Tests for the panel's pure logic (Nav.js: cursor moves, Rows.js: texts,
// keys and backend commands):  node tests/ui.test.js
const { load, eq, done } = require("./harness")
const Model = load("Model.js")
const N = load("Nav.js")
const R = load("Rows.js", { Model })

const tabs = R.TABS
const pk = R.chipsForTab("packages")
function ctx(over) {
  return Object.assign({ tabs, activeTab: "packages", chips: pk, filterKey: "extra", itemCount: 3 }, over || {})
}

// --- Nav: helpers ------------------------------------------------------------
eq("indexOfKey finds, else 0", [N.indexOfKey(tabs, "startup"), N.indexOfKey(tabs, "nope"), N.indexOfKey([], "x")], [2, 0, 0])
eq("indexOfKey compares as strings", N.indexOfKey([{ key: 1 }, { key: 2 }], "2"), 1)
eq("clampIndex", [N.clampIndex(-1, 3), N.clampIndex(1, 3), N.clampIndex(5, 3), N.clampIndex(2, 0)], [0, 1, 2, 0])

// --- Nav: first key press ------------------------------------------------------
eq("initialCursor: rows when the list has items", N.initialCursor(ctx()), { section: "rows", index: 0 })
eq("initialCursor: active filter chip when the list is empty", N.initialCursor(ctx({ itemCount: 0, filterKey: "pacnew" })), { section: "filters", index: 2 })
eq("initialCursor: active tab when there is nothing else", N.initialCursor(ctx({ activeTab: "cleanup", chips: [], itemCount: 0 })), { section: "tabs", index: 1 })

// --- Nav: vertical -------------------------------------------------------------
const tabsAt = { section: "tabs", index: 0 }, filtersAt = { section: "filters", index: 1 }
eq("tabs ↓ → active filter", N.move(tabsAt, 0, 1, ctx({ filterKey: "orphans" })), { section: "filters", index: 1 })
eq("tabs ↓ without filters → first row", N.move(tabsAt, 0, 1, ctx({ chips: [] })), { section: "rows", index: 0 })
eq("tabs ↓ with nothing below → stays", N.move(tabsAt, 0, 1, ctx({ chips: [], itemCount: 0 })), null)
eq("tabs ↑ → stays", N.move(tabsAt, 0, -1, ctx()), null)
eq("filters ↓ → first row", N.move(filtersAt, 0, 1, ctx()), { section: "rows", index: 0 })
eq("filters ↓ on an empty list → stays", N.move(filtersAt, 0, 1, ctx({ itemCount: 0 })), null)
eq("filters ↑ → active tab", N.move(filtersAt, 0, -1, ctx({ activeTab: "launchers" })), { section: "tabs", index: 3 })
eq("rows ↓ → next row, scrolled", N.move({ section: "rows", index: 0 }, 0, 1, ctx()), { section: "rows", index: 1, position: true })
eq("rows ↓ at the end → stays on the last row", N.move({ section: "rows", index: 2 }, 0, 1, ctx()), { section: "rows", index: 2, position: true })
eq("rows ↑ → previous row", N.move({ section: "rows", index: 2 }, 0, -1, ctx()), { section: "rows", index: 1, position: true })
eq("rows ↑ on the first row → active filter", N.move({ section: "rows", index: 0 }, 0, -1, ctx({ filterKey: "agents" })), { section: "filters", index: 3, position: true })
eq("rows ↑ on the first row without filters → active tab", N.move({ section: "rows", index: 0 }, 0, -1, ctx({ activeTab: "cleanup", chips: [] })), { section: "tabs", index: 1, position: true })

// --- Nav: horizontal -----------------------------------------------------------
eq("tabs → switches tab", N.move({ section: "tabs", index: 0 }, 1, 0, ctx()), { section: "tabs", index: 1, tab: "cleanup" })
eq("tabs ← at the start → clamps", N.move({ section: "tabs", index: 0 }, -1, 0, ctx()), { section: "tabs", index: 0, tab: "packages" })
eq("tabs → at the end → clamps", N.move({ section: "tabs", index: 3 }, 1, 0, ctx()), { section: "tabs", index: 3, tab: "launchers" })
eq("filters → applies the next filter", N.move({ section: "filters", index: 0 }, 1, 0, ctx()), { section: "filters", index: 1, filter: "orphans" })
eq("filters ← at the start → clamps", N.move({ section: "filters", index: 0 }, -1, 0, ctx()), { section: "filters", index: 0, filter: "extra" })
eq("filters on a tab without filters → nothing", N.move({ section: "filters", index: 0 }, 1, 0, ctx({ chips: [] })), null)
eq("rows ←/→ → nothing", N.move({ section: "rows", index: 1 }, 1, 0, ctx()), null)
eq("no movement → nothing", N.move({ section: "rows", index: 1 }, 0, 0, ctx()), null)

// --- Nav: Tab / Shift+Tab ------------------------------------------------------
eq("cycleIndex forward + wrap", [N.cycleIndex(tabs, "packages", 1), N.cycleIndex(tabs, "launchers", 1)], [1, 0])
eq("cycleIndex backward + wrap", [N.cycleIndex(tabs, "cleanup", -1), N.cycleIndex(tabs, "packages", -1)], [0, 3])
eq("cycleIndex with no tabs", N.cycleIndex([], "packages", 1), -1)

// --- Rows: constants -----------------------------------------------------------
eq("tabs in order", tabs.map(t => t.key), ["packages", "cleanup", "startup", "launchers"])
eq("chipsForTab", ["packages", "cleanup", "startup", "launchers", "nope"].map(t => R.chipsForTab(t).map(c => c.key)),
  [["extra", "orphans", "pacnew", "agents"], [], ["autostart", "services"], ["webapps", "tuis"], []])
eq("default filter is each tab's first chip", ["packages", "startup", "launchers"].map(t => R.DEFAULT_FILTERS[t] === R.chipsForTab(t)[0].key), [true, true, true])
eq("cleanup rows: fixed order", R.CLEANUP_ROWS.map(r => r.key), ["pacman", "aur", "dev", "agents", "mise", "docker", "browser", "coredump", "journal", "trash"])
eq("cleanup rows: total covers every row", R.CLEANUP_KEYS.slice().sort(), R.CLEANUP_ROWS.map(r => r.key).sort())
eq("cleanup rows: irreversible ones", R.CLEANUP_ROWS.filter(r => r.irreversible).map(r => r.key), ["agents", "trash"])

// The backend must accept every cleanup target the UI can send.
const backend = require("fs").readFileSync(require("path").join(__dirname, "..", "scripts/backend.sh"), "utf8")
eq("backend knows every cleanup target", R.CLEANUP_ROWS.filter(r => !new RegExp("^\\s*" + r.key + "\\)", "m").test(backend)).map(r => r.key), [])

// --- Rows: cleanup sizes -------------------------------------------------------
const status = Model.parseCleanupStatus("pacman\t289\npacman-total\t5498\njournal\t71.4\njournal-total\t171.4\nagents\t6\nagents-running\tcodex claude\n")
eq("cleanupMb", [R.cleanupMb(status, "pacman"), R.cleanupMb(status, "trash"), R.cleanupMb(null, "pacman"), R.cleanupMb({ x: "abc" }, "x")], [289, 0, 0, 0])
eq("cleanupTotalMb", R.cleanupTotalMb(status), 289 + 71.4 + 6)
eq("cleanupLabel", [R.cleanupLabel("aur"), R.cleanupLabel("nope")], ["AUR build cache", "nope"])
const row = k => R.CLEANUP_ROWS.filter(r => r.key === k)[0]
eq("cleanupSubtitle while measuring", R.cleanupSubtitle(row("pacman"), false, status), "Measuring…")
eq("cleanupSubtitle pacman total", R.cleanupSubtitle(row("pacman"), true, status), "289.0 MiB · Packages no longer installed · cache is 5.37 GiB in total")
eq("cleanupSubtitle journal total", R.cleanupSubtitle(row("journal"), true, status), "71.4 MiB · Above the latest 100 MiB · 171.4 MiB in total")
eq("cleanupSubtitle agents running", R.cleanupSubtitle(row("agents"), true, status), "6.0 MiB · skips running codex, claude · Temp, logs & caches — keeps sessions, memories, login")
eq("cleanupSubtitle zero size", R.cleanupSubtitle(row("trash"), true, status), "0.0 MiB · Empties the Trash folder")
eq("cleanupArmedText", R.cleanupArmedText(row("trash")), "Permanently empties the Trash — again to confirm")
eq("cleanupArmedText without warn", R.cleanupArmedText({ key: "x", label: "Foo Cache" }), "Deletes foo cache — again to confirm")

// --- Rows: hints and keys ------------------------------------------------------
eq("keyHints armed", R.keyHints(true, true), [["Enter", "confirm"], ["Esc", "cancel"]])
eq("keyHints with filters", R.keyHints(false, true).map(h => h[0]), ["Tab", "h l", "j k", "Enter", "Esc"])
eq("keyHints without filters", R.keyHints(false, false).map(h => h[0]), ["Tab", "j k", "Enter", "Esc"])
eq("rowKey", [
  R.rowKey("packages", "extra", { name: "steam" }),
  R.rowKey("packages", "pacnew", { name: "a.pacnew", path: "/etc/a.pacnew" }),
  R.rowKey("packages", "agents", { name: "Codex", id: "codex" }),
  R.rowKey("cleanup", "", { key: "aur", label: "AUR" }),
  R.rowKey("startup", "services", { name: "x.service", kind: "systemd" }),
  R.rowKey("launchers", "webapps", { name: "Chat" }),
  R.rowKey("packages", "extra", null)
], ["packages:extra:steam", "packages:pacnew:/etc/a.pacnew", "packages:agents:codex", "cleanup:aur", "startup:systemd:x.service", "launchers::Chat", ""])
eq("rowKey: same name in another filter is another row", R.rowKey("packages", "orphans", { name: "steam" }) !== R.rowKey("packages", "extra", { name: "steam" }), true)

// --- Rows: lists ---------------------------------------------------------------
const units = Model.parseSystemdUnits("fluxd.service\tenabled\tservice\n")
const autos = Model.parseAutostart("gnome-keyring-secrets\tenabled\t/etc/xdg/autostart\tsystem\nnextcloud\tdisabled\t/home/yoyo/.config/autostart\t\n")
eq("startupItems services", R.startupItems("services", units, autos), [{ name: "fluxd.service", status: "enabled", kind: "systemd", detail: "service", origin: "user", warning: "" }])
const st = R.startupItems("autostart", units, autos)
eq("startupItems autostart: kind, origin default, warning", st.map(i => [i.name, i.kind, i.origin, i.warning !== ""]),
  [["gnome-keyring-secrets", "autostart", "system", true], ["nextcloud", "autostart", "user", false]])
eq("launchersItems", [R.launchersItems("tuis", [{ name: "btop" }], [{ name: "Chat" }]), R.launchersItems("webapps", [{ name: "btop" }], [{ name: "Chat" }])],
  [[{ name: "btop", kind: "tui" }], [{ name: "Chat", kind: "webapp" }]])

// --- Rows: texts ---------------------------------------------------------------
eq("emptyText per tab/filter", [["packages", "extra"], ["packages", "orphans"], ["packages", "pacnew"], ["packages", "agents"], ["startup", "autostart"], ["startup", "services"], ["launchers", "webapps"], ["launchers", "tuis"], ["cleanup", ""]]
  .map(a => R.emptyText(a[0], a[1]).title), ["No packages beyond the Omarchy defaults", "No orphaned packages", "No .pacnew/.pacsave/.pacorig files found", "No agent CLIs installed",
  "No autostart entries found", "No user-added systemd services found", "No Web App launchers found", "No TUI launchers found", ""])
eq("packageIsProtected only in Extra/Orphans", [R.packageIsProtected("extra", { protected: true }), R.packageIsProtected("orphans", { protected: true }), R.packageIsProtected("pacnew", { protected: true }), R.packageIsProtected("extra", {})], [true, true, false, false])
eq("packageSubtitle extra", R.packageSubtitle("extra", { protected: true, sizeMb: 7.8, date: "2026-09-29", lastUsed: "today" }), "needed by the system · 7.8 MiB · installed 2026-09-29 · used today")
eq("packageSubtitle extra, never used", R.packageSubtitle("extra", { sizeMb: 19.5, date: "2026-09-29", lastUsed: "" }), "19.5 MiB · installed 2026-09-29")
eq("packageSubtitle pacnew", R.packageSubtitle("pacnew", { bytes: 5203, path: "/etc/a.pacnew" }), "5.1 KiB · /etc/a.pacnew · review with pacdiff")
eq("packageSubtitle agents", R.packageSubtitle("agents", { sizeMb: 50, detail: "~/.local/bin/codex" }), "50.0 MiB · ~/.local/bin/codex")
eq("packageArmedText", ["extra", "pacnew", "agents"].map(f => R.packageArmedText(f, { name: "codex" })),
  ["pacman -Rns codex after a snapshot — again to confirm", "Deletes it — merge first with sudo pacdiff — again to confirm", "Uninstalls codex (mise + stub) — again to confirm"])
eq("startupSubtitle", [R.startupSubtitle({ kind: "systemd", detail: "timer", status: "disabled" }), R.startupSubtitle({ kind: "autostart", detail: "/home/yoyo/.config/autostart", status: "enabled" })],
  ["disabled · timer · ~/.config/systemd/user", "enabled · ~/.config/autostart"])
eq("startupArmedText", [R.startupArmedText({ kind: "systemd", warning: "" }), R.startupArmedText({ kind: "autostart", warning: "" }), R.startupArmedText({ kind: "autostart", warning: "breaks X" })],
  ["Stops it now and at login — again to confirm", "Stops it from starting at login — again to confirm", "Disabling: breaks X — again to confirm"])

// --- Rows: actions -------------------------------------------------------------
const loaded = { cleanupLoaded: true, cleanupStatus: status }
const c = (tab, packagesFilter) => Object.assign({ tab, packagesFilter: packagesFilter || "extra" }, loaded)
eq("rowActionAvailable: protected package has none", [R.rowActionAvailable(c("packages"), { protected: true }), R.rowActionAvailable(c("packages", "orphans"), { protected: true }), R.rowActionAvailable(c("packages"), {})], [false, false, true])
eq("rowActionAvailable: pacnew/agents ignore the protected flag", [R.rowActionAvailable(c("packages", "pacnew"), { protected: true }), R.rowActionAvailable(c("packages", "agents"), { protected: true })], [true, true])
eq("rowActionAvailable: startup only for enabled/disabled", ["enabled", "disabled", "masked", "static"].map(s => R.rowActionAvailable(c("startup"), { status: s })), [true, true, false, false])
eq("rowActionAvailable: cleanup needs a measured size > 0", [R.rowActionAvailable(c("cleanup"), { key: "pacman" }), R.rowActionAvailable(c("cleanup"), { key: "trash" }),
  R.rowActionAvailable({ tab: "cleanup", cleanupLoaded: false, cleanupStatus: status }, { key: "pacman" })], [true, false, false])
eq("runsWithoutConfirm: only re-enabling startup items", [R.runsWithoutConfirm(c("startup"), { status: "disabled" }), R.runsWithoutConfirm(c("startup"), { status: "enabled" }), R.runsWithoutConfirm(c("packages"), { status: "disabled" })], [true, false, false])
eq("rowAction packages", ["extra", "orphans", "pacnew", "agents"].map(f => R.rowAction(c("packages", f), { name: "codex", id: "codex-id", path: "/etc/x.pacnew" }).args),
  [["packages-remove", "codex"], ["packages-remove", "codex"], ["packages-pacnew-remove", "/etc/x.pacnew"], ["agents-remove", "codex-id"]])
eq("rowAction package message", R.rowAction(c("packages"), { name: "steam" }).message, "Snapshotting + removing steam…")
eq("rowAction agent message", R.rowAction(c("packages", "agents"), { name: "Codex", id: "codex" }).message, "Removing Codex (keeps sessions)…")
eq("rowAction launchers", [R.rowAction(c("launchers"), { name: "btop", kind: "tui" }).args, R.rowAction(c("launchers"), { name: "Chat", kind: "webapp" }).args], [["tui-remove", "btop"], ["webapps-remove", "Chat"]])
eq("rowAction startup", [
  R.rowAction(c("startup"), { name: "a", kind: "autostart", status: "enabled" }).args,
  R.rowAction(c("startup"), { name: "a", kind: "autostart", status: "disabled" }).args,
  R.rowAction(c("startup"), { name: "u", kind: "systemd", status: "enabled" }).args,
  R.rowAction(c("startup"), { name: "u", kind: "systemd", status: "disabled" }).args,
  R.rowAction(c("startup"), { name: "u", kind: "systemd", status: "static" })
], [["autostart-disable", "a"], ["autostart-enable", "a"], ["systemd-disable", "u"], ["systemd-enable", "u"], null])
eq("startupEnableAction message", R.startupEnableAction({ name: "nextcloud", kind: "autostart" }), { args: ["autostart-enable", "nextcloud"], message: "Enabling nextcloud…" })
eq("rowAction cleanup", R.rowAction(c("cleanup"), { key: "pacman" }), { args: ["cleanup-run", "pacman"], message: "Cleaning Pacman cache…" })
eq("rowAction cleanup with nothing to free", R.rowAction(c("cleanup"), { key: "trash" }), null)
eq("rowAction unknown tab", R.rowAction(c("nope"), { name: "x" }), null)

done()
