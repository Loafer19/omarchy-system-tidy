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

function parsePackages(text) {
  var rows = parseTsvRows(text, ["name", "sizeMb", "date", "lastUsed"])
  rows.sort(function(a, b) { return parseFloat(b.sizeMb) - parseFloat(a.sizeMb) })
  return rows
}

function parseWebapps(text) {
  return String(text || "").split("\n").filter(function(l) { return l.trim() !== "" }).map(function(name) {
    return { name: name }
  })
}

function parseAutostart(text) {
  return parseTsvRows(text, ["name", "status", "source"])
}

function parseSystemdUnits(text) {
  return parseTsvRows(text, ["name", "status", "type"])
}

function parsePacnewFiles(text) {
  var rows = parseTsvRows(text, ["name", "bytes", "path"])
  rows.sort(function(a, b) { return parseFloat(b.bytes) - parseFloat(a.bytes) })
  return rows
}

function parseCleanupStatus(text) {
  var rows = parseTsvRows(text, ["key", "mb"])
  var result = { pacman: 0, coredump: 0, trash: 0, docker: 0, browser: 0, aur: 0, dev: 0, journal: 0, orphans_count: 0, orphans_mb: 0 }
  for (var i = 0; i < rows.length; i++) {
    if (result.hasOwnProperty(rows[i].key)) result[rows[i].key] = parseFloat(rows[i].mb) || 0
  }
  return result
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
