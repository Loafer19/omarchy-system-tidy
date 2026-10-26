pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../Model.js" as Model

// Every list the panel shows, read from scripts/backend.sh, plus the one
// action process. Each list has its own loading flag; a reply only ever
// lands in the list it was asked for.
Item {
  id: root

  readonly property string backendPath: String(Qt.resolvedUrl("../scripts/backend.sh")).replace(/^file:\/\//, "")

  property var packages: []
  property bool packagesLoading: false
  property var orphans: []
  property bool orphansLoading: false
  property var pacnewFiles: []
  property bool pacnewLoading: false
  property var agents: []
  property bool agentsLoading: false
  property var webapps: []
  property bool webappsLoading: false
  property var tuis: []
  property bool tuisLoading: false
  property var autostartItems: []
  property bool autostartLoading: false
  property var systemdUnits: []
  property bool systemdLoading: false
  property var cleanupStatus: ({ pacman: 0, coredump: 0, trash: 0, docker: 0, browser: 0, aur: 0, dev: 0, agents: 0, mise: 0, journal: 0 })
  property bool cleanupLoading: false
  property bool cleanupLoaded: false

  // Last "tidy: " line of the running/finished action (see Model.lastUserLine).
  readonly property string lastOut: actionProc.lastOut

  // stderr of the action (trimmed, non-empty), then its exit code. stdout may
  // still be arriving at exit: read lastOut later (Qt.callLater), not here.
  signal actionFailedWith(string text)
  signal actionExited(int exitCode)

  function packagesFor(filter) {
    if (filter === "pacnew") return root.pacnewFiles
    if (filter === "agents") return root.agents
    if (filter === "orphans") return root.orphans
    return root.packages
  }

  function packagesLoadingFor(filter) {
    if (filter === "pacnew") return root.pacnewLoading
    if (filter === "agents") return root.agentsLoading
    if (filter === "orphans") return root.orphansLoading
    return root.packagesLoading
  }

  function launchersLoadingFor(filter) { return filter === "tuis" ? root.tuisLoading : root.webappsLoading }
  function startupLoadingFor(filter) { return filter === "services" ? root.systemdLoading : root.autostartLoading }

  function refreshPackages(filter) {
    if (filter === "pacnew") {
      root.pacnewLoading = true
      pacnewProc.running = true
    } else if (filter === "agents") {
      root.agentsLoading = true
      agentsProc.running = true
    } else if (filter === "orphans") {
      root.orphansLoading = true
      orphansProc.running = true
    } else {
      root.packagesLoading = true
      packagesProc.running = true
    }
  }

  function refreshLaunchers() {
    root.webappsLoading = true
    root.tuisLoading = true
    webappsProc.running = true
    tuisProc.running = true
  }

  function refreshStartup() {
    root.autostartLoading = true
    root.systemdLoading = true
    autostartProc.running = true
    systemdProc.running = true
  }

  function refreshCleanup() {
    root.cleanupLoading = true
    cleanupProc.running = true
  }

  function run(args) {
    actionProc.lastOut = ""
    actionProc.command = ["bash", root.backendPath].concat(args)
    actionProc.running = true
  }

  // pacman -Ql per package is slow; if a run is in flight, queue the new
  // request and start it when the old one exits (no stale overwrite: the
  // result is merged by name into whichever list it was asked for).
  function requestPackagesLastUsed(rows, target) {
    if (!rows || rows.length === 0) return
    var names = []
    for (var i = 0; i < rows.length; i++) names.push(rows[i].name)
    var req = { target: target, command: ["bash", root.backendPath, "packages-last-used"].concat(names) }
    if (lastUsedProc.running) {
      lastUsedProc.pending = req
      return
    }
    lastUsedProc.target = req.target
    lastUsedProc.command = req.command
    lastUsedProc.running = true
  }

  ListProcess {
    id: packagesProc
    backendPath: root.backendPath
    verb: "packages-list"
    onFinished: function(text) {
      root.packages = Model.parsePackages(text)
      root.packagesLoading = false
      root.requestPackagesLastUsed(root.packages, "extra")
    }
  }

  ListProcess {
    id: orphansProc
    backendPath: root.backendPath
    verb: "packages-orphans"
    onFinished: function(text) {
      root.orphans = Model.parsePackages(text)
      root.orphansLoading = false
      root.requestPackagesLastUsed(root.orphans, "orphans")
    }
  }

  Process {
    id: lastUsedProc
    property string target: "extra"
    property var pending: null
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var map = Model.parseLastUsed(text)
        if (lastUsedProc.target === "orphans") root.orphans = Model.withLastUsed(root.orphans, map)
        else root.packages = Model.withLastUsed(root.packages, map)
      }
    }
    onExited: {
      var next = lastUsedProc.pending
      if (!next) return
      lastUsedProc.pending = null
      Qt.callLater(function() {
        lastUsedProc.target = next.target
        lastUsedProc.command = next.command
        lastUsedProc.running = true
      })
    }
  }

  ListProcess {
    id: pacnewProc
    backendPath: root.backendPath
    verb: "packages-pacnew"
    onFinished: function(text) {
      root.pacnewFiles = Model.parsePacnewFiles(text)
      root.pacnewLoading = false
    }
  }

  ListProcess {
    id: agentsProc
    backendPath: root.backendPath
    verb: "agents-list"
    onFinished: function(text) {
      root.agents = Model.parseAgents(text)
      root.agentsLoading = false
    }
  }

  ListProcess {
    id: webappsProc
    backendPath: root.backendPath
    verb: "webapps-list"
    onFinished: function(text) {
      root.webapps = Model.parseNameList(text)
      root.webappsLoading = false
    }
  }

  ListProcess {
    id: tuisProc
    backendPath: root.backendPath
    verb: "tui-list"
    onFinished: function(text) {
      root.tuis = Model.parseNameList(text)
      root.tuisLoading = false
    }
  }

  ListProcess {
    id: autostartProc
    backendPath: root.backendPath
    verb: "autostart-list"
    onFinished: function(text) {
      root.autostartItems = Model.parseAutostart(text)
      root.autostartLoading = false
    }
  }

  ListProcess {
    id: systemdProc
    backendPath: root.backendPath
    verb: "systemd-list"
    onFinished: function(text) {
      root.systemdUnits = Model.parseSystemdUnits(text)
      root.systemdLoading = false
    }
  }

  ListProcess {
    id: cleanupProc
    backendPath: root.backendPath
    verb: "cleanup-status"
    onFinished: function(text) {
      root.cleanupStatus = Model.parseCleanupStatus(text)
      root.cleanupLoading = false
      root.cleanupLoaded = true
    }
  }

  Process {
    id: actionProc
    property string lastOut: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: actionProc.lastOut = Model.lastUserLine(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err !== "") root.actionFailedWith(err)
      }
    }
    onExited: function(exitCode) { root.actionExited(exitCode) }
  }
}
