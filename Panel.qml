import qs.Commons as Commons
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "components" as Tidy
import "vendor/yoyo-ui"

Panel {
  id: root
  moduleName: "yoyo.system-tidy"
  ipcTarget: "yoyo.system-tidy"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string backendPath: String(Qt.resolvedUrl("scripts/backend.sh")).replace(/^file:\/\//, "")

  property string activeTab: "packages"
  property string packagesFilter: "extra"
  property string startupFilter: "autostart"
  property string launchersFilter: "webapps"
  property var packages: []
  property bool packagesLoading: false
  // Orphans have their own list so a late reply can never land in Extra.
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
  property bool busy: false
  // Two-step confirm: the first Enter/click arms a row (by stable key), the
  // second runs it. Esc, moving the cursor, or 4 s of nothing disarms.
  ConfirmController { id: confirmCtl; timeout: 4000 }
  property alias armedKey: confirmCtl.armedKey
  // Footer status lives in the shared StatusFooter (progress / done / error).
  property alias statusText: footer.statusText
  property alias statusKind: footer.statusKind
  property bool cleanupLoading: false
  property bool cleanupLoaded: false

  readonly property real cleanupTotalMb: {
    var s = root.cleanupStatus, keys = ["pacman", "coredump", "trash", "docker", "browser", "aur", "dev", "agents", "mise", "journal"], t = 0
    for (var i = 0; i < keys.length; i++) t += parseFloat(s[keys[i]]) || 0
    return t
  }

  readonly property var keyHints: {
    if (root.armedKey !== "") return [["Enter", "confirm"], ["Esc", "cancel"]]
    var h = [["Tab", "tabs"]]
    if (root.activeFilterChips.length > 0) h.push(["h l", "filters"])
    h.push(["j k", "rows"], ["Enter", "act"], ["Esc", "close"])
    return h
  }

  readonly property bool packagesViewLoading: {
    if (root.packagesFilter === "pacnew") return root.pacnewLoading
    if (root.packagesFilter === "agents") return root.agentsLoading
    if (root.packagesFilter === "orphans") return root.orphansLoading
    return root.packagesLoading
  }
  readonly property bool packagesViewEmpty: {
    if (root.packagesFilter === "pacnew") return root.pacnewFiles.length === 0
    if (root.packagesFilter === "agents") return root.agents.length === 0
    if (root.packagesFilter === "orphans") return root.orphans.length === 0
    return root.packages.length === 0
  }
  readonly property bool launchersViewLoading: root.launchersFilter === "tuis" ? root.tuisLoading : root.webappsLoading
  readonly property bool startupViewLoading: root.startupFilter === "services" ? root.systemdLoading : root.autostartLoading

  // Fixed order (package caches, dev caches, apps, system logs, Trash) so a
  // row never jumps under the cursor when sizes refresh.
  readonly property var cleanupRows: {
    var rows = [
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
    return rows
  }

  readonly property color contentForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  Binding { target: Theme; property: "foreground"; value: root.contentForeground }
  Binding { target: Theme; property: "fontFamily"; value: root.contentFontFamily }

  readonly property var tabs: [
    { key: "packages", label: "Packages" },
    { key: "cleanup", label: "Cleanup" },
    { key: "startup", label: "Startup" },
    { key: "launchers", label: "Launchers" }
  ]

  readonly property var packagesChips: [
    { key: "extra", label: "Extra" },
    { key: "orphans", label: "Orphans" },
    { key: "pacnew", label: "Pacnew" },
    { key: "agents", label: "Agent CLIs" }
  ]

  readonly property var launchersChips: [
    { key: "webapps", label: "Web Apps" },
    { key: "tuis", label: "TUIs" }
  ]

  readonly property var startupChips: [
    { key: "autostart", label: "Autostart" },
    { key: "services", label: "Services" }
  ]

  readonly property var startupItems: {
    if (root.startupFilter === "services") {
      return root.systemdUnits.map(function(u) {
        return { name: u.name, status: u.status, kind: "systemd", detail: u.type, origin: "user", warning: "" }
      })
    }
    return root.autostartItems.map(function(a) {
      return { name: a.name, status: a.status, kind: "autostart", detail: a.source, origin: a.origin || "user", warning: Model.autostartWarning(a.name) }
    })
  }

  readonly property var launchersItems: {
    if (root.launchersFilter === "tuis") {
      return root.tuis.map(function(t) {
        return { name: t.name, kind: "tui" }
      })
    }
    return root.webapps.map(function(w) {
      return { name: w.name, kind: "webapp" }
    })
  }

  // Cursor sections: "tabs" | "filters" | "rows"
  property bool cursorActive: false
  property string focusSection: "rows"
  property int selectedIndex: 0

  readonly property var activeFilterChips: {
    if (root.activeTab === "packages") return root.packagesChips
    if (root.activeTab === "startup") return root.startupChips
    if (root.activeTab === "launchers") return root.launchersChips
    return []
  }

  readonly property var activeListItems: {
    if (root.activeTab === "packages") {
      if (root.packagesFilter === "pacnew") return root.pacnewFiles
      if (root.packagesFilter === "agents") return root.agents
      if (root.packagesFilter === "orphans") return root.orphans
      return root.packages
    }
    if (root.activeTab === "cleanup") return root.cleanupRows
    if (root.activeTab === "startup") return root.startupItems
    if (root.activeTab === "launchers") return root.launchersItems
    return []
  }

  function chipIndexByKey(chips, key) {
    for (var i = 0; i < chips.length; i++) {
      if (String(chips[i].key) === String(key)) return i
    }
    return 0
  }

  function clampIndex(i, len) {
    if (len <= 0) return 0
    if (i < 0) return 0
    if (i >= len) return len - 1
    return i
  }

  function ensureCursor() {
    if (!root.cursorActive) {
      root.cursorActive = true
      if (root.activeListItems.length > 0) {
        root.focusSection = "rows"
        root.selectedIndex = 0
      } else if (root.activeFilterChips.length > 0) {
        root.focusSection = "filters"
        root.selectedIndex = root.chipIndexByKey(root.activeFilterChips, root.filterKeyForTab())
      } else {
        root.focusSection = "tabs"
        root.selectedIndex = root.chipIndexByKey(root.tabs, root.activeTab)
      }
      return false
    }
    return true
  }

  function filterKeyForTab() {
    if (root.activeTab === "packages") return root.packagesFilter
    if (root.activeTab === "startup") return root.startupFilter
    if (root.activeTab === "launchers") return root.launchersFilter
    return ""
  }

  function applyFilterKey(key) {
    if (root.activeTab === "packages") root.setPackagesFilter(key)
    else if (root.activeTab === "startup") root.setStartupFilter(key)
    else if (root.activeTab === "launchers") root.setLaunchersFilter(key)
  }

  function confirmHint(text) { return text + " — again to confirm" }

  function rowKey(tab, item) {
    if (!item) return ""
    if (tab === "packages") return "packages:" + root.packagesFilter + ":" + (item.path || item.id || item.name)
    if (tab === "cleanup") return "cleanup:" + item.key
    return tab + ":" + (item.kind || "") + ":" + item.name
  }

  function disarm() { confirmCtl.disarm() }

  // Returns true when the action should run now (row was already armed).
  function armOrConfirm(key) {
    if (root.busy || key === "") return false
    return confirmCtl.confirm(key)
  }

  function moveCursor(dx, dy) {
    root.disarm()
    if (!root.ensureCursor()) return

    if (dy !== 0) {
      if (root.focusSection === "tabs") {
        if (dy > 0) {
          if (root.activeFilterChips.length > 0) {
            root.focusSection = "filters"
            root.selectedIndex = root.chipIndexByKey(root.activeFilterChips, root.filterKeyForTab())
          } else if (root.activeListItems.length > 0) {
            root.focusSection = "rows"
            root.selectedIndex = 0
          }
        }
        return
      }
      if (root.focusSection === "filters") {
        if (dy > 0) {
          if (root.activeListItems.length > 0) {
            root.focusSection = "rows"
            root.selectedIndex = 0
          }
        } else {
          root.focusSection = "tabs"
          root.selectedIndex = root.chipIndexByKey(root.tabs, root.activeTab)
        }
        return
      }
      if (dy > 0) {
        root.selectedIndex = root.clampIndex(root.selectedIndex + 1, root.activeListItems.length)
      } else if (root.selectedIndex > 0) {
        root.selectedIndex = root.selectedIndex - 1
      } else if (root.activeFilterChips.length > 0) {
        root.focusSection = "filters"
        root.selectedIndex = root.chipIndexByKey(root.activeFilterChips, root.filterKeyForTab())
      } else {
        root.focusSection = "tabs"
        root.selectedIndex = root.chipIndexByKey(root.tabs, root.activeTab)
      }
      root.positionActiveList()
      return
    }

    if (dx === 0) return

    if (root.focusSection === "tabs") {
      root.selectedIndex = root.clampIndex(root.selectedIndex + dx, root.tabs.length)
      root.activeTab = root.tabs[root.selectedIndex].key
      return
    }
    if (root.focusSection === "filters" && root.activeFilterChips.length > 0) {
      root.selectedIndex = root.clampIndex(root.selectedIndex + dx, root.activeFilterChips.length)
      root.applyFilterKey(root.activeFilterChips[root.selectedIndex].key)
    }
  }

  function rowHasCursor(tab, index) {
    return root.cursorActive && root.focusSection === "rows" && root.activeTab === tab && root.selectedIndex === index
  }

  function positionActiveList() {
    if (root.focusSection !== "rows") return
    var view = null
    if (root.activeTab === "packages") view = packagesTab.view
    else if (root.activeTab === "launchers") view = launchersTab.view
    else if (root.activeTab === "startup") view = startupTab.view
    else if (root.activeTab === "cleanup") view = cleanupTab.view
    if (view && root.selectedIndex >= 0 && root.selectedIndex < view.count)
      view.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function activateCursor() {
    if (!root.ensureCursor()) return
    if (root.busy) return

    if (root.focusSection === "tabs") {
      root.activeTab = root.tabs[root.selectedIndex].key
      return
    }
    if (root.focusSection === "filters") {
      if (root.activeFilterChips.length === 0) return
      root.applyFilterKey(root.activeFilterChips[root.selectedIndex].key)
      return
    }

    var items = root.activeListItems
    if (root.selectedIndex < 0 || root.selectedIndex >= items.length) return
    var item = items[root.selectedIndex]
    root.requestRowAction(item)
  }

  function rowActionAvailable(item) {
    if (root.activeTab === "packages" && (root.packagesFilter === "extra" || root.packagesFilter === "orphans"))
      return !item.protected
    if (root.activeTab === "startup") return item.status === "enabled" || item.status === "disabled"
    if (root.activeTab === "cleanup") return root.cleanupLoaded && (parseFloat(root.cleanupStatus[item.key]) || 0) > 0
    return true
  }

  function requestRowAction(item) {
    if (!root.rowActionAvailable(item)) return
    // Re-enabling is harmless and undoable: no confirm step.
    if (root.activeTab === "startup" && item.status === "disabled") {
      root.disarm()
      root.enableStartupItem(item)
      return
    }
    if (!root.armOrConfirm(root.rowKey(root.activeTab, item))) return
    root.runRowAction(item)
  }

  function runRowAction(item) {
    if (root.activeTab === "packages") {
      if (root.packagesFilter === "pacnew") root.removePacnewFile(item.path, item.name)
      else if (root.packagesFilter === "agents") root.removeAgent(item.id, item.name)
      else root.removePackage(item.name)
      return
    }
    if (root.activeTab === "launchers") {
      root.removeLauncherItem(item)
      return
    }
    if (root.activeTab === "startup") {
      if (item.status === "enabled") root.disableStartupItem(item)
      else if (item.status === "disabled") root.enableStartupItem(item)
      return
    }
    if (root.activeTab === "cleanup")
      root.runCleanup(item.key)
  }

  function setRowCursor(index) {
    if (root.focusSection !== "rows" || root.selectedIndex !== index) root.disarm()
    root.cursorActive = true
    root.focusSection = "rows"
    root.selectedIndex = index
  }

  function setTabsCursor(index) {
    root.cursorActive = true
    root.focusSection = "tabs"
    root.selectedIndex = index
  }

  function setFiltersCursor(index) {
    root.cursorActive = true
    root.focusSection = "filters"
    root.selectedIndex = index
  }

  onActiveTabChanged: {
    root.disarm()
    root.selectedIndex = 0
    if (root.focusSection === "filters" && root.activeFilterChips.length === 0)
      root.focusSection = root.activeListItems.length > 0 ? "rows" : "tabs"
    if (root.focusSection === "rows")
      root.selectedIndex = root.clampIndex(0, root.activeListItems.length)
    if (root.opened) root.refreshActiveTab()
  }

  function refreshPackages() {
    if (root.packagesFilter === "pacnew") {
      root.pacnewLoading = true
      pacnewProc.running = true
    } else if (root.packagesFilter === "agents") {
      root.agentsLoading = true
      agentsProc.running = true
    } else if (root.packagesFilter === "orphans") {
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

  function refreshActiveTab() {
    if (root.activeTab === "packages") root.refreshPackages()
    else if (root.activeTab === "launchers") root.refreshLaunchers()
    else if (root.activeTab === "startup") root.refreshStartup()
    else if (root.activeTab === "cleanup") root.refreshCleanup()
  }

  onOpenedChanged: {
    root.disarm()
    if (opened) {
      root.cursorActive = false
      root.focusSection = "rows"
      root.selectedIndex = 0
      root.refreshActiveTab()
    }
  }

  function runAction(args, message) {
    if (root.busy) return
    root.busy = true
    footer.flash(message, "progress")
    actionProc.lastOut = ""
    actionProc.command = ["bash", root.backendPath].concat(args)
    actionProc.running = true
  }

  function setPackagesFilter(key) {
    root.disarm()
    if (root.packagesFilter === key) return
    root.packagesFilter = key
    if (root.focusSection === "rows") root.selectedIndex = 0
    if (key === "pacnew") {
      root.pacnewLoading = true
      pacnewProc.running = true
    } else if (key === "agents") {
      root.agentsLoading = true
      agentsProc.running = true
    } else if (root.packagesFilter === "orphans") {
      root.orphansLoading = true
      orphansProc.running = true
    } else {
      root.packagesLoading = true
      packagesProc.running = true
    }
  }

  function setStartupFilter(key) {
    root.disarm()
    if (root.startupFilter === key) return
    root.startupFilter = key
    if (root.focusSection === "rows") root.selectedIndex = 0
  }

  function setLaunchersFilter(key) {
    root.disarm()
    if (root.launchersFilter === key) return
    root.launchersFilter = key
    if (root.focusSection === "rows") root.selectedIndex = 0
  }

  function removePackage(name) { runAction(["packages-remove", name], "Snapshotting + removing " + name + "…") }
  function removePacnewFile(path, name) { runAction(["packages-pacnew-remove", path], "Removing " + name + "…") }
  function removeAgent(id, name) { runAction(["agents-remove", id], "Removing " + name + " (keeps sessions)…") }
  function removeWebapp(name) { runAction(["webapps-remove", name], "Removing " + name + "…") }
  function removeTui(name) { runAction(["tui-remove", name], "Removing " + name + "…") }
  function removeLauncherItem(item) {
    if (item.kind === "tui") root.removeTui(item.name)
    else root.removeWebapp(item.name)
  }
  function disableAutostart(name) { runAction(["autostart-disable", name], "Disabling " + name + "…") }
  function disableSystemdUnit(name) { runAction(["systemd-disable", name], "Disabling " + name + "…") }
  function enableStartupItem(item) {
    if (item.kind === "systemd") runAction(["systemd-enable", item.name], "Enabling " + item.name + "…")
    else runAction(["autostart-enable", item.name], "Enabling " + item.name + "…")
  }
  function disableStartupItem(item) {
    if (item.kind === "systemd") root.disableSystemdUnit(item.name)
    else root.disableAutostart(item.name)
  }
  function cleanupLabel(key) {
    for (var i = 0; i < root.cleanupRows.length; i++) {
      if (root.cleanupRows[i].key === key) return root.cleanupRows[i].label
    }
    return key
  }
  function runCleanup(target) {
    if ((parseFloat(root.cleanupStatus[target]) || 0) <= 0) return
    runAction(["cleanup-run", target], "Cleaning " + root.cleanupLabel(target) + "…")
  }

  function cycleTab(direction) {
    var n = root.tabs.length
    if (n === 0) return
    var i = root.chipIndexByKey(root.tabs, root.activeTab)
    i = (i + direction) % n
    if (i < 0) i += n
    root.activeTab = root.tabs[i].key
    root.setTabsCursor(i)
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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(Style.space(440))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.armedKey !== "") root.disarm()
        else root.close()
      }
      onTabRequested: function(direction) { root.cycleTab(direction) }
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()

      Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(8)

        ChipRow {
          chips: root.tabs
          selectedKey: root.activeTab
          cursorActive: root.cursorActive && root.focusSection === "tabs"
          cursorIndex: root.cursorActive && root.focusSection === "tabs" ? root.selectedIndex : -1
          onSelected: function(key) {
            root.activeTab = key
            root.setTabsCursor(root.chipIndexByKey(root.tabs, key))
          }
          onChipHovered: function(index) { root.setTabsCursor(index) }
        }

        Rectangle { width: parent.width; height: Style.spacing.hairline; color: Theme.line }
      }

      Item {
        id: body
        anchors.top: header.bottom
        anchors.topMargin: Theme.edge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.edge

        Tidy.TabList {
          id: packagesTab
          anchors.fill: parent
          visible: root.activeTab === "packages"
          chips: root.packagesChips
          selectedKey: root.packagesFilter
          chipCursorActive: root.cursorActive && root.focusSection === "filters" && root.activeTab === "packages"
          chipCursorIndex: chipCursorActive ? root.selectedIndex : -1
          model: root.packagesFilter === "pacnew" ? root.pacnewFiles
            : root.packagesFilter === "agents" ? root.agents
            : root.packagesFilter === "orphans" ? root.orphans
            : root.packages
          loading: root.packagesViewLoading
          emptyText: root.packagesFilter === "orphans" ? "No orphaned packages"
            : root.packagesFilter === "pacnew" ? "No .pacnew/.pacsave/.pacorig files found"
            : root.packagesFilter === "agents" ? "No agent CLIs installed"
            : "No packages beyond the Omarchy defaults"
          emptySubtitle: root.packagesFilter === "orphans" ? "Nothing is left over from removed software"
            : root.packagesFilter === "pacnew" ? "No config updates are waiting to be merged"
            : root.packagesFilter === "agents" ? "Agent CLIs installed through mise show up here"
            : "Everything explicitly installed is part of Omarchy"
          onChipSelected: function(key) {
            root.setPackagesFilter(key)
            root.setFiltersCursor(root.chipIndexByKey(root.packagesChips, key))
          }
          onChipHovered: function(index) { root.setFiltersCursor(index) }

          delegate: ActionRow {
            actionStyle: "button"
            controller: confirmCtl
            disarmOnLeave: false
            activateOnClick: false
            required property var modelData
            required property int index
            readonly property bool isPacnew: root.packagesFilter === "pacnew"
            readonly property bool isAgent: root.packagesFilter === "agents"
            width: ListView.view.width
            hasCursor: root.rowHasCursor("packages", index)
            title: modelData.name
            subtitle: {
              if (isPacnew) return Model.formatBytes(modelData.bytes) + " · " + modelData.path + " · review with pacdiff"
              if (isAgent) return Model.formatMib(modelData.sizeMb) + " · " + modelData.detail
              var line = (modelData.protected ? "needed by the system · " : "") + Model.formatMib(modelData.sizeMb) + " · installed " + modelData.date
              if (modelData.lastUsed && modelData.lastUsed !== "")
                line += " · used " + modelData.lastUsed
              return line
            }
            readonly property bool isProtected: !isPacnew && !isAgent && !!modelData.protected
            actionLabel: "Remove"
            actionVisible: !isProtected
            actionEnabled: !root.busy
            badge: isProtected ? "protected" : ""
            danger: true
            confirmKey: root.rowKey("packages", modelData)
            armedText: root.confirmHint(isPacnew ? "Deletes it — merge first with sudo pacdiff"
              : isAgent ? "Uninstalls " + modelData.name + " (mise + stub)"
              : "pacman -Rns " + modelData.name + " after a snapshot")
            onRowHovered: root.setRowCursor(index)
            onActionClicked: {
              root.setRowCursor(index)
              root.requestRowAction(modelData)
            }
          }
        }

        Tidy.TabList {
          id: launchersTab
          anchors.fill: parent
          visible: root.activeTab === "launchers"
          chips: root.launchersChips
          selectedKey: root.launchersFilter
          chipCursorActive: root.cursorActive && root.focusSection === "filters" && root.activeTab === "launchers"
          chipCursorIndex: chipCursorActive ? root.selectedIndex : -1
          model: root.launchersItems
          loading: root.launchersViewLoading
          emptyText: root.launchersFilter === "tuis" ? "No TUI launchers found" : "No Web App launchers found"
          emptySubtitle: root.launchersFilter === "tuis" ? "TUIs added with Install › TUI show up here" : "Web apps added with Install › Web App show up here"
          onChipSelected: function(key) {
            root.setLaunchersFilter(key)
            root.setFiltersCursor(root.chipIndexByKey(root.launchersChips, key))
          }
          onChipHovered: function(index) { root.setFiltersCursor(index) }

          delegate: ActionRow {
            actionStyle: "button"
            controller: confirmCtl
            disarmOnLeave: false
            activateOnClick: false
            required property var modelData
            required property int index
            width: ListView.view.width
            hasCursor: root.rowHasCursor("launchers", index)
            title: modelData.name
            actionLabel: "Remove"
            actionEnabled: !root.busy
            danger: true
            confirmKey: root.rowKey("launchers", modelData)
            armedText: root.confirmHint("Deletes the launcher and its icon")
            onRowHovered: root.setRowCursor(index)
            onActionClicked: {
              root.setRowCursor(index)
              root.requestRowAction(modelData)
            }
          }
        }

        Tidy.TabList {
          id: startupTab
          anchors.fill: parent
          visible: root.activeTab === "startup"
          chips: root.startupChips
          selectedKey: root.startupFilter
          chipCursorActive: root.cursorActive && root.focusSection === "filters" && root.activeTab === "startup"
          chipCursorIndex: chipCursorActive ? root.selectedIndex : -1
          model: root.startupItems
          loading: root.startupViewLoading
          emptyText: root.startupFilter === "services" ? "No user-added systemd services found" : "No autostart entries found"
          emptySubtitle: root.startupFilter === "services" ? "Only units in ~/.config/systemd/user are listed" : ""
          onChipSelected: function(key) {
            root.setStartupFilter(key)
            root.setFiltersCursor(root.chipIndexByKey(root.startupChips, key))
          }
          onChipHovered: function(index) { root.setFiltersCursor(index) }

          delegate: ActionRow {
            actionStyle: "button"
            controller: confirmCtl
            disarmOnLeave: false
            activateOnClick: false
            required property var modelData
            required property int index
            width: ListView.view.width
            hasCursor: root.rowHasCursor("startup", index)
            title: modelData.name
            subtitle: {
              var where = modelData.kind === "systemd" ? modelData.detail + " · ~/.config/systemd/user"
                : modelData.detail.replace(/^\/home\/[^\/]+/, "~")
              return modelData.status + " · " + where
            }
            readonly property bool isEnabled: modelData.status === "enabled"
            actionLabel: isEnabled ? "Disable" : "Enable"
            actionEnabled: !root.busy
            danger: isEnabled
            badge: modelData.origin === "system" ? "system" : ""
            badgeVariant: isEnabled && modelData.warning !== "" ? "warn" : "normal"
            confirmKey: root.rowKey("startup", modelData)
            armedText: root.confirmHint(modelData.warning !== ""
              ? "Disabling: " + modelData.warning
              : modelData.kind === "systemd" ? "Stops it now and at login" : "Stops it from starting at login")
            onRowHovered: root.setRowCursor(index)
            onActionClicked: {
              root.setRowCursor(index)
              root.requestRowAction(modelData)
            }
          }
        }

        Tidy.TabList {
          id: cleanupTab
          anchors.fill: parent
          visible: root.activeTab === "cleanup"
          model: root.cleanupRows

          delegate: ActionRow {
            actionStyle: "button"
            controller: confirmCtl
            disarmOnLeave: false
            activateOnClick: false
            required property var modelData
            required property int index
            width: ListView.view.width
            hasCursor: root.rowHasCursor("cleanup", index)
            title: modelData.label
            subtitle: {
              if (!root.cleanupLoaded) return "Measuring…"
              var size = Model.formatMib(root.cleanupStatus[modelData.key] || 0)
              var note = modelData.note
              if (modelData.key === "journal" && root.cleanupStatus.journalTotal > 0)
                note += " · " + Model.formatMib(root.cleanupStatus.journalTotal) + " in total"
              if (modelData.key === "pacman" && root.cleanupStatus.pacmanTotal > 0)
                note += " · cache is " + Model.formatMib(root.cleanupStatus.pacmanTotal) + " in total"
              if (modelData.key === "agents" && root.cleanupStatus.agentsRunning)
                note = "skips running " + root.cleanupStatus.agentsRunning.split(" ").join(", ") + " · " + note
              return note !== "" ? size + " · " + note : size
            }
            actionLabel: "Clean"
            badge: modelData.irreversible ? "irreversible" : ""
            badgeVariant: "warn"
            actionEnabled: !root.busy && root.cleanupLoaded && (parseFloat(root.cleanupStatus[modelData.key]) || 0) > 0
            danger: true
            confirmKey: root.rowKey("cleanup", modelData)
            armedText: root.confirmHint(modelData.warn || ("Deletes " + modelData.label.toLowerCase()))
            onRowHovered: root.setRowCursor(index)
            onActionClicked: {
              root.setRowCursor(index)
              root.requestRowAction(modelData)
            }
          }
        }
      }
    

      // Footer: status (progress / done / error) replaces the key hints while
      // it is showing, so nothing above it moves.
      StatusFooter {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        hints: root.keyHints
        rightText: root.activeTab === "cleanup" && root.cleanupLoaded
          ? "≈ " + Model.formatMib(root.cleanupTotalMb) + " reclaimable" : ""
      }
}
  }

  Process {
    id: packagesProc
    command: ["bash", root.backendPath, "packages-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.packages = Model.parsePackages(text)
        root.packagesLoading = false
        root.requestPackagesLastUsed(root.packages, "extra")
      }
    }
  }

  Process {
    id: orphansProc
    command: ["bash", root.backendPath, "packages-orphans"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.orphans = Model.parsePackages(text)
        root.orphansLoading = false
        root.requestPackagesLastUsed(root.orphans, "orphans")
      }
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

  Process {
    id: pacnewProc
    command: ["bash", root.backendPath, "packages-pacnew"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.pacnewFiles = Model.parsePacnewFiles(text)
        root.pacnewLoading = false
      }
    }
  }

  Process {
    id: agentsProc
    command: ["bash", root.backendPath, "agents-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.agents = Model.parseAgents(text)
        root.agentsLoading = false
      }
    }
  }

  Process {
    id: webappsProc
    command: ["bash", root.backendPath, "webapps-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.webapps = Model.parseNameList(text)
        root.webappsLoading = false
      }
    }
  }

  Process {
    id: tuisProc
    command: ["bash", root.backendPath, "tui-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.tuis = Model.parseNameList(text)
        root.tuisLoading = false
      }
    }
  }

  Process {
    id: autostartProc
    command: ["bash", root.backendPath, "autostart-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.autostartItems = Model.parseAutostart(text)
        root.autostartLoading = false
      }
    }
  }

  Process {
    id: systemdProc
    command: ["bash", root.backendPath, "systemd-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.systemdUnits = Model.parseSystemdUnits(text)
        root.systemdLoading = false
      }
    }
  }

  Process {
    id: cleanupProc
    command: ["bash", root.backendPath, "cleanup-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.cleanupStatus = Model.parseCleanupStatus(text)
        root.cleanupLoading = false
        root.cleanupLoaded = true
      }
    }
  }

  Process {
    id: actionProc
    property string lastOut: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Only lines the backend tags with "tidy: " are meant for the user.
        var lines = String(text || "").split("\n").filter(function(l) { return l.indexOf("tidy: ") === 0 })
        actionProc.lastOut = lines.length > 0 ? lines[lines.length - 1].slice(6) : ""
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err !== "") { root.statusText = err; root.statusKind = "error" }
      }
    }
    onExited: function(exitCode) {
      root.busy = false
      Qt.callLater(function() {
        // flash() clears it after 2.5 s (done) / 6 s (error).
        if (exitCode === 0) footer.flash(actionProc.lastOut !== "" ? "Done · " + actionProc.lastOut : "Done", "done")
        else footer.flash(root.statusKind === "error" ? root.statusText : "Failed", "error")
      })
      root.refreshActiveTab()
    }
  }

}
