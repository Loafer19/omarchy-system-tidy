.pragma library

function parseTsvRows(text, fieldNames) {
  var lines = String(text || "").split("\n")
  var rows = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.trim() === "") continue
    var parts = line.split("\t")
    var row = {}
    for (var f = 0; f < fieldNames.length; f++) row[fieldNames[f]] = parts[f] !== undefined ? parts[f] : ""
    rows.push(row)
  }
  return rows
}

// Must match PROTECTED_RE in scripts/backend.sh (the backend is the
// authority; this only keeps the UI honest if an old backend omits column 5).
var PROTECTED_RE = /^(omarchy|omarchy-.+|omasnap|base|base-devel|filesystem|glibc|bash|coreutils|systemd|systemd-.+|dbus|dbus-.+|pacman|pacman-contrib|archlinux-keyring|expac|sudo|polkit|linux|linux-(lts|zen|hardened|rt)|linux(-lts|-zen|-hardened|-rt)?-headers|linux-firmware(-.+)?|.+-ucode|.+-dkms|dkms|mkinitcpio|mkinitcpio-.+|dracut|limine|limine-.+|grub|efibootmgr|snapper|snap-pac|btrfs-progs|cryptsetup|lvm2|plymouth|nvidia|nvidia-.+|lib32-nvidia-utils|mesa|lib32-mesa|vulkan-.+|hyprland|uwsm|quickshell|networkmanager|iwd|wpa_supplicant|greetd|sddm|pipewire|wireplumber)$/

function isProtectedPackage(name) {
  return PROTECTED_RE.test(String(name || ""))
}

function parsePackages(text) {
  var rows = parseTsvRows(text, ["name", "sizeMb", "date", "lastUsed", "protected"])
  for (var i = 0; i < rows.length; i++) rows[i].protected = rows[i].protected === "protected" || isProtectedPackage(rows[i].name)
  // Removable first (largest first), protected system packages at the bottom.
  rows.sort(function(a, b) {
    if (a.protected !== b.protected) return a.protected ? 1 : -1
    return parseFloat(b.sizeMb) - parseFloat(a.sizeMb)
  })
  return rows
}

function sortByName(rows) {
  rows.sort(function(a, b) { return String(a.name).localeCompare(String(b.name)) })
  return rows
}

function parseNameList(text) {
  return sortByName(String(text || "").split("\n").filter(function(l) { return l.trim() !== "" }).map(function(name) {
    return { name: name }
  }))
}

function parseAutostart(text) {
  return sortByName(parseTsvRows(text, ["name", "status", "source", "origin"]))
}

// Extra warning for autostart entries other things quietly depend on.
function autostartWarning(name) {
  var n = String(name || "")
  if (/gnome-keyring|kwallet|keepassxc/.test(n)) return "apps may stop finding saved passwords"
  if (/at-spi/.test(n)) return "screen readers and some apps' accessibility break"
  if (/polkit|xdg-desktop-portal/.test(n)) return "password prompts or file pickers may stop working"
  if (/fcitx|ibus/.test(n)) return "your input method won't start"
  return ""
}

function parseSystemdUnits(text) {
  return sortByName(parseTsvRows(text, ["name", "status", "type"]))
}

function parsePacnewFiles(text) {
  var rows = parseTsvRows(text, ["name", "bytes", "path"])
  rows.sort(function(a, b) { return parseFloat(b.bytes) - parseFloat(a.bytes) })
  return rows
}

function parseAgents(text) {
  var rows = parseTsvRows(text, ["id", "name", "sizeMb", "detail"])
  rows.sort(function(a, b) { return parseFloat(b.sizeMb) - parseFloat(a.sizeMb) })
  return rows
}

function parseCleanupStatus(text) {
  var rows = parseTsvRows(text, ["key", "mb"])
  var result = { pacman: 0, coredump: 0, trash: 0, docker: 0, browser: 0, aur: 0, dev: 0, agents: 0, mise: 0, journal: 0, agentsRunning: "", pacmanTotal: 0 }
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].key === "pacman-total") result.pacmanTotal = parseFloat(rows[i].mb) || 0
    else if (rows[i].key === "agents-running") result.agentsRunning = String(rows[i].mb || "").trim()
    else if (result.hasOwnProperty(rows[i].key)) result[rows[i].key] = parseFloat(rows[i].mb) || 0
  }
  return result
}

function parseLastUsed(text) {
  var rows = parseTsvRows(text, ["name", "lastUsed"])
  var map = {}
  for (var i = 0; i < rows.length; i++) map[rows[i].name] = rows[i].lastUsed
  return map
}

function withLastUsed(packages, lastUsedMap) {
  var out = []
  for (var i = 0; i < packages.length; i++) {
    var p = packages[i]
    out.push({
      name: p.name,
      sizeMb: p.sizeMb,
      date: p.date,
      lastUsed: lastUsedMap[p.name] !== undefined ? lastUsedMap[p.name] : (p.lastUsed || ""),
      protected: !!p.protected
    })
  }
  return out
}

function formatMib(mb) {
  var n = parseFloat(mb)
  if (isNaN(n)) return "0 MiB"
  if (n >= 1024) return (n / 1024).toFixed(2) + " GiB"
  return n.toFixed(1) + " MiB"
}

function formatBytes(bytes) {
  var n = parseFloat(bytes)
  if (isNaN(n)) return "0 B"
  if (n >= 1024 * 1024) return (n / (1024 * 1024)).toFixed(2) + " MiB"
  if (n >= 1024) return (n / 1024).toFixed(1) + " KiB"
  return n.toFixed(0) + " B"
}
