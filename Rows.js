.pragma library
.import "Model.js" as Model

// What each tab shows and does, as pure functions: chips, row texts, the
// confirm key and hint of every row, and the backend command a row runs.
// Panel.qml and components/*Tab.qml only wire these to the UI.

var TABS = [
  { key: "packages", label: "Packages" },
  { key: "cleanup", label: "Cleanup" },
  { key: "startup", label: "Startup" },
  { key: "launchers", label: "Launchers" }
]

var CHIPS = {
  packages: [
    { key: "extra", label: "Extra" },
    { key: "orphans", label: "Orphans" },
    { key: "pacnew", label: "Pacnew" },
    { key: "agents", label: "Agent CLIs" }
  ],
  startup: [
    { key: "autostart", label: "Autostart" },
    { key: "services", label: "Services" }
  ],
  launchers: [
    { key: "webapps", label: "Web Apps" },
    { key: "tuis", label: "TUIs" }
  ]
}

var DEFAULT_FILTERS = { packages: "extra", startup: "autostart", launchers: "webapps" }

function chipsForTab(tab) { return CHIPS[tab] || [] }

// Fixed order (package caches, dev caches, apps, system logs, Trash) so a
// row never jumps under the cursor when sizes refresh.
var CLEANUP_ROWS = [
  { key: "pacman", label: "Pacman cache", action: "clean", note: "Packages no longer installed", warn: "Deletes cached packages of uninstalled software (needs password)" },
  { key: "aur", label: "AUR build cache", action: "clean", note: "yay/paru build artifacts, safe to delete", warn: "Deletes ~/.cache/yay and ~/.cache/paru" },
  { key: "dev", label: "Dev tool caches", action: "clean", note: "pip, npm, cargo, go — all rebuild on demand", warn: "Deletes pip/npm/cargo/go download caches" },
  { key: "agents", label: "Agent caches", action: "clean", note: "Temp, logs & caches — keeps sessions, memories, login", warn: "Permanently deletes agent temp/log/cache dirs", irreversible: true },
  { key: "mise", label: "Mise unused", action: "clean", note: "mise prune + download cache", warn: "Removes tool versions no mise config uses (reinstall to get back)" },
  { key: "docker", label: "Docker (prune)", action: "clean", note: "Stopped containers, dangling images, build cache", warn: "Runs docker system prune (volumes and tagged images are kept)" },
  { key: "browser", label: "Browser cache", action: "clean", note: "Chrome, Chromium, Brave, Vivaldi, Firefox page cache — keeps logins", warn: "Deletes page caches (running browsers are skipped)" },
  { key: "coredump", label: "Coredumps", action: "clean", note: "Crash dumps (coredumpctl), safe to delete", warn: "Deletes all crash dumps (needs password)" },
  { key: "journal", label: "Journal logs", action: "clean", note: "Above the latest 100 MiB", warn: "Vacuums the journal to 100 MiB (needs password)" },
  { key: "trash", label: "Trash", action: "clean", note: "Empties the Trash folder", warn: "Permanently empties the Trash", irreversible: true }
]

function cleanupMb(status, key) { return parseFloat(status ? status[key] : 0) || 0 }

// Summed in this order (not row order) so the total is bit-for-bit what it
// always was.
var CLEANUP_KEYS = ["pacman", "coredump", "trash", "docker", "browser", "aur", "dev", "agents", "mise", "journal"]

function cleanupTotalMb(status) {
  var t = 0
  for (var i = 0; i < CLEANUP_KEYS.length; i++) t += cleanupMb(status, CLEANUP_KEYS[i])
  return t
}

function cleanupLabel(key) {
  for (var i = 0; i < CLEANUP_ROWS.length; i++) {
    if (CLEANUP_ROWS[i].key === key) return CLEANUP_ROWS[i].label
  }
  return key
}

function keyHints(armed, hasFilters) {
  if (armed) return [["Enter", "confirm"], ["Esc", "cancel"]]
  var h = [["Tab", "tabs"]]
  if (hasFilters) h.push(["h l", "filters"])
  h.push(["j k", "rows"], ["Enter", "act"], ["Esc", "close"])
  return h
}

function confirmHint(text) { return text + " — again to confirm" }

// Stable confirm key per row (survives list reloads).
function rowKey(tab, packagesFilter, item) {
  if (!item) return ""
  if (tab === "packages") return "packages:" + packagesFilter + ":" + (item.path || item.id || item.name)
  if (tab === "cleanup") return "cleanup:" + item.key
  return tab + ":" + (item.kind || "") + ":" + item.name
}

// ---------------------------------------------------------------- lists

function startupItems(filter, systemdUnits, autostartItems) {
  if (filter === "services") {
    return systemdUnits.map(function(u) {
      return { name: u.name, status: u.status, kind: "systemd", detail: u.type, origin: "user", warning: "" }
    })
  }
  return autostartItems.map(function(a) {
    return { name: a.name, status: a.status, kind: "autostart", detail: a.source, origin: a.origin || "user", warning: Model.autostartWarning(a.name) }
  })
}

function launchersItems(filter, tuis, webapps) {
  if (filter === "tuis") return tuis.map(function(t) { return { name: t.name, kind: "tui" } })
  return webapps.map(function(w) { return { name: w.name, kind: "webapp" } })
}

// ---------------------------------------------------------------- texts

function emptyText(tab, filter) {
  if (tab === "packages") {
    if (filter === "orphans") return { title: "No orphaned packages", subtitle: "Nothing is left over from removed software" }
    if (filter === "pacnew") return { title: "No .pacnew/.pacsave/.pacorig files found", subtitle: "No config updates are waiting to be merged" }
    if (filter === "agents") return { title: "No agent CLIs installed", subtitle: "Agent CLIs installed through mise show up here" }
    return { title: "No packages beyond the Omarchy defaults", subtitle: "Everything explicitly installed is part of Omarchy" }
  }
  if (tab === "startup") {
    if (filter === "services") return { title: "No user-added systemd services found", subtitle: "Only units in ~/.config/systemd/user are listed" }
    return { title: "No autostart entries found", subtitle: "" }
  }
  if (tab === "launchers") {
    if (filter === "tuis") return { title: "No TUI launchers found", subtitle: "TUIs added with Install › TUI show up here" }
    return { title: "No Web App launchers found", subtitle: "Web apps added with Install › Web App show up here" }
  }
  return { title: "", subtitle: "" }
}

function packageIsProtected(filter, item) {
  return filter !== "pacnew" && filter !== "agents" && !!item.protected
}

function packageSubtitle(filter, item) {
  if (filter === "pacnew") return Model.formatBytes(item.bytes) + " · " + item.path + " · review with pacdiff"
  if (filter === "agents") return Model.formatMib(item.sizeMb) + " · " + item.detail
  var line = (item.protected ? "needed by the system · " : "") + Model.formatMib(item.sizeMb) + " · installed " + item.date
  if (item.lastUsed && item.lastUsed !== "") line += " · used " + item.lastUsed
  return line
}

function packageArmedText(filter, item) {
  return confirmHint(filter === "pacnew" ? "Deletes it — merge first with sudo pacdiff"
    : filter === "agents" ? "Uninstalls " + item.name + " (mise + stub)"
    : "pacman -Rns " + item.name + " after a snapshot")
}

function startupSubtitle(item) {
  var where = item.kind === "systemd" ? item.detail + " · ~/.config/systemd/user"
    : item.detail.replace(/^\/home\/[^\/]+/, "~")
  return item.status + " · " + where
}

function startupArmedText(item) {
  return confirmHint(item.warning !== ""
    ? "Disabling: " + item.warning
    : item.kind === "systemd" ? "Stops it now and at login" : "Stops it from starting at login")
}

function cleanupSubtitle(row, loaded, status) {
  if (!loaded) return "Measuring…"
  var size = Model.formatMib(status[row.key] || 0)
  var note = row.note
  if (row.key === "journal" && status.journalTotal > 0)
    note += " · " + Model.formatMib(status.journalTotal) + " in total"
  if (row.key === "pacman" && status.pacmanTotal > 0)
    note += " · cache is " + Model.formatMib(status.pacmanTotal) + " in total"
  if (row.key === "agents" && status.agentsRunning)
    note = "skips running " + status.agentsRunning.split(" ").join(", ") + " · " + note
  return note !== "" ? size + " · " + note : size
}

function cleanupArmedText(row) {
  return confirmHint(row.warn || ("Deletes " + row.label.toLowerCase()))
}

// ---------------------------------------------------------------- actions

// ctx: { tab, packagesFilter, cleanupLoaded, cleanupStatus }
function rowActionAvailable(ctx, item) {
  if (ctx.tab === "packages" && (ctx.packagesFilter === "extra" || ctx.packagesFilter === "orphans"))
    return !item.protected
  if (ctx.tab === "startup") return item.status === "enabled" || item.status === "disabled"
  if (ctx.tab === "cleanup") return ctx.cleanupLoaded && cleanupMb(ctx.cleanupStatus, item.key) > 0
  return true
}

// Re-enabling a startup item is harmless and undoable: it skips the confirm.
function runsWithoutConfirm(ctx, item) {
  return ctx.tab === "startup" && item.status === "disabled"
}

function startupEnableAction(item) {
  if (item.kind === "systemd") return { args: ["systemd-enable", item.name], message: "Enabling " + item.name + "…" }
  return { args: ["autostart-enable", item.name], message: "Enabling " + item.name + "…" }
}

// The backend command for a confirmed row: { args, message }, or null.
function rowAction(ctx, item) {
  if (ctx.tab === "packages") {
    if (ctx.packagesFilter === "pacnew") return { args: ["packages-pacnew-remove", item.path], message: "Removing " + item.name + "…" }
    if (ctx.packagesFilter === "agents") return { args: ["agents-remove", item.id], message: "Removing " + item.name + " (keeps sessions)…" }
    return { args: ["packages-remove", item.name], message: "Snapshotting + removing " + item.name + "…" }
  }
  if (ctx.tab === "launchers") {
    if (item.kind === "tui") return { args: ["tui-remove", item.name], message: "Removing " + item.name + "…" }
    return { args: ["webapps-remove", item.name], message: "Removing " + item.name + "…" }
  }
  if (ctx.tab === "startup") {
    if (item.status === "enabled") {
      if (item.kind === "systemd") return { args: ["systemd-disable", item.name], message: "Disabling " + item.name + "…" }
      return { args: ["autostart-disable", item.name], message: "Disabling " + item.name + "…" }
    }
    if (item.status === "disabled") return startupEnableAction(item)
    return null
  }
  if (ctx.tab === "cleanup") {
    if (cleanupMb(ctx.cleanupStatus, item.key) <= 0) return null
    return { args: ["cleanup-run", item.key], message: "Cleaning " + cleanupLabel(item.key) + "…" }
  }
  return null
}
