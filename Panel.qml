import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

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
  property var cleanupStatus: ({ pacman: 0, coredump: 0, trash: 0, docker: 0, browser: 0, aur: 0, dev: 0, agents: 0, mise: 0, journal: 0, orphans_count: 0, orphans_mb: 0 })
  property bool busy: false
  property string statusText: ""
  property string statusKind: "progress" // "progress" | "done" | "error"

  readonly property bool packagesViewLoading: {
    if (root.packagesFilter === "pacnew") return root.pacnewLoading
    if (root.packagesFilter === "agents") return root.agentsLoading
    return root.packagesLoading
  }
  readonly property bool packagesViewEmpty: {
    if (root.packagesFilter === "pacnew") return root.pacnewFiles.length === 0
    if (root.packagesFilter === "agents") return root.agents.length === 0
    return root.packages.length === 0
  }
  readonly property bool launchersViewLoading: root.launchersFilter === "tuis" ? root.tuisLoading : root.webappsLoading
  readonly property bool startupViewLoading: root.startupFilter === "services" ? root.systemdLoading : root.autostartLoading

  // Cleanable rows largest-first. Orphans live under Packages → Orphans only.
  readonly property var cleanupRows: {
    var rows = [
      { key: "pacman", label: "Pacman cache", action: "clean", note: "Only cached packages you've already removed" },
      { key: "aur", label: "AUR build cache", action: "clean", note: "yay/paru build artifacts, safe to delete" },
      { key: "dev", label: "Dev tool caches", action: "clean", note: "pip, npm, cargo, go — all rebuild on demand" },
      { key: "agents", label: "Agent caches", action: "clean", note: "Chat history & tmp — keeps login and settings" },
      { key: "mise", label: "Mise unused", action: "clean", note: "mise prune + download cache" },
      { key: "docker", label: "Docker (prune)", action: "clean", note: "Stopped containers & dangling images only" },
      { key: "browser", label: "Browser cache", action: "clean", note: "Chrome/Chromium page cache — won't log you out" },
      { key: "coredump", label: "Coredumps", action: "clean", note: "Crash dumps (coredumpctl), safe to delete" },
      { key: "journal", label: "Journal logs", action: "clean", note: "Keeps the latest 100 MiB" },
      { key: "trash", label: "Trash", action: "clean", note: "Empties the Trash folder" }
    ]
    var status = root.cleanupStatus
    rows.sort(function(a, b) {
      return (parseFloat(status[b.key]) || 0) - (parseFloat(status[a.key]) || 0)
    })
    return rows
  }

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dividerColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.12)

  // Single spacing value instead of scattered ad-hoc numbers.
  readonly property int edgeMargin: Style.space(6)
  readonly property int rowGap: 0
  readonly property int rowHeight: Style.space(44)

  readonly property var tabs: [
    { key: "packages", label: "Packages" },
    { key: "cleanup", label: "Cleanup" },
    { key: "startup", label: "Startup" },
    { key: "launchers", label: "Launchers" }
  ]

  readonly property var packagesChips: [
    { key: "extra", label: "Added" },
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
        return { name: u.name, status: u.status, kind: "systemd", detail: u.type }
      })
    }
    return root.autostartItems.map(function(a) {
      return { name: a.name, status: a.status, kind: "autostart", detail: a.source }
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

  // Keyboard / mouse cursor — one highlight via CursorSurface / ChipRow.
  // Sections: "tabs" | "filters" | "rows"
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

  function moveCursor(dx, dy) {
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
      // rows
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

  function positionActiveList() {
    if (root.focusSection !== "rows") return
    var view = null
    if (root.activeTab === "packages") view = packagesList
    else if (root.activeTab === "launchers") view = launchersList
    else if (root.activeTab === "startup") view = startupList
    else if (root.activeTab === "cleanup") view = cleanupList
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
      return
    }
    if (root.activeTab === "cleanup")
      root.runCleanup(item.key)
  }

  function setRowCursor(index) {
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
    root.selectedIndex = 0
    if (root.focusSection === "filters" && root.activeFilterChips.length === 0)
      root.focusSection = root.activeListItems.length > 0 ? "rows" : "tabs"
    if (root.focusSection === "rows")
      root.selectedIndex = root.clampIndex(0, root.activeListItems.length)
  }

  function refreshAll() {
    if (root.packagesFilter === "pacnew") {
      root.pacnewLoading = true
      pacnewProc.running = true
    } else if (root.packagesFilter === "agents") {
      root.agentsLoading = true
      agentsProc.running = true
    } else {
      root.packagesLoading = true
      packagesProc.running = true
    }
    root.webappsLoading = true
    root.tuisLoading = true
    root.autostartLoading = true
    root.systemdLoading = true
    webappsProc.running = true
    tuisProc.running = true
    autostartProc.running = true
    systemdProc.running = true
    cleanupProc.running = true
  }

  onOpenedChanged: {
    if (opened) {
      root.cursorActive = false
      root.focusSection = "rows"
      root.selectedIndex = 0
      refreshAll()
    }
  }

  function runAction(args, message) {
    if (root.busy) return
    root.busy = true
    root.statusText = message
    root.statusKind = "progress"
    actionProc.command = ["bash", root.backendPath].concat(args)
    actionProc.running = true
  }

  function setPackagesFilter(key) {
    if (root.packagesFilter === key) return
    root.packagesFilter = key
    if (root.focusSection === "rows") root.selectedIndex = 0
    if (key === "pacnew") {
      root.pacnewLoading = true
      pacnewProc.running = true
    } else if (key === "agents") {
      root.agentsLoading = true
      agentsProc.running = true
    } else {
      root.packagesLoading = true
      packagesProc.running = true
    }
  }

  function setStartupFilter(key) {
    if (root.startupFilter === key) return
    root.startupFilter = key
    if (root.focusSection === "rows") root.selectedIndex = 0
  }

  function setLaunchersFilter(key) {
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

  function requestPackagesLastUsed(rows) {
    if (!rows || rows.length === 0) return
    var names = []
    for (var i = 0; i < rows.length; i++) names.push(rows[i].name)
    lastUsedProc.command = ["bash", root.backendPath, "packages-last-used"].concat(names)
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
      onCloseRequested: root.close()
      // Tab cycles our own tabs — not other bar plugins.
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
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          cursorActive: root.cursorActive && root.focusSection === "tabs"
          cursorIndex: root.cursorActive && root.focusSection === "tabs" ? root.selectedIndex : -1
          onSelected: function(key) {
            root.activeTab = key
            root.setTabsCursor(root.chipIndexByKey(root.tabs, key))
          }
          onChipHovered: function(index) { root.setTabsCursor(index) }
        }

        Rectangle { width: parent.width; height: Style.spacing.hairline; color: root.dividerColor }

        Text {
          id: statusLabel
          visible: opacity > 0
          leftPadding: root.edgeMargin
          width: parent.width - root.edgeMargin
          elide: Text.ElideRight
          color: root.statusKind === "error" ? Color.urgent
            : root.statusKind === "done" ? Color.accent
            : root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          opacity: root.statusText !== "" ? 1 : 0

          Behavior on opacity { NumberAnimation { duration: 150 } }

          // Keeps the last message visible while it fades out.
          Connections {
            target: root
            function onStatusTextChanged() {
              if (root.statusText !== "") statusLabel.text = root.statusText
            }
          }
        }
      }

      Item {
        id: body
        anchors.top: header.bottom
        anchors.topMargin: root.edgeMargin
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        ChipRow {
          id: packagesFilterRow
          visible: root.activeTab === "packages"
          anchors.top: parent.top
          anchors.left: parent.left
          compact: true
          chips: root.packagesChips
          selectedKey: root.packagesFilter
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          cursorActive: root.cursorActive && root.focusSection === "filters" && root.activeTab === "packages"
          cursorIndex: root.cursorActive && root.focusSection === "filters" && root.activeTab === "packages" ? root.selectedIndex : -1
          onSelected: function(key) {
            root.setPackagesFilter(key)
            root.setFiltersCursor(root.chipIndexByKey(root.packagesChips, key))
          }
          onChipHovered: function(index) { root.setFiltersCursor(index) }
        }

        ListView {
          id: packagesList
          anchors.top: packagesFilterRow.bottom
          anchors.topMargin: root.edgeMargin
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          visible: root.activeTab === "packages"
          clip: true
          spacing: root.rowGap
          model: root.packagesFilter === "pacnew" ? root.pacnewFiles
            : root.packagesFilter === "agents" ? root.agents
            : root.packages
          delegate: ActionListRow {
            required property var modelData
            required property int index
            readonly property bool isPacnew: root.packagesFilter === "pacnew"
            readonly property bool isAgent: root.packagesFilter === "agents"
            width: ListView.view.width
            rowHeight: root.rowHeight
            edgeMargin: root.edgeMargin
            contentForeground: root.contentForeground
            contentFontFamily: root.contentFontFamily
            hasCursor: root.cursorActive && root.focusSection === "rows" && root.activeTab === "packages" && root.selectedIndex === index
            title: modelData.name
            subtitle: {
              if (isPacnew) return Model.formatBytes(modelData.bytes) + " · " + modelData.path
              if (isAgent) return Model.formatMib(modelData.sizeMb) + " · " + modelData.detail
              var line = Model.formatMib(modelData.sizeMb) + " · installed " + modelData.date
              if (modelData.lastUsed && modelData.lastUsed !== "")
                line += " · used " + modelData.lastUsed
              return line
            }
            actionLabel: "Remove"
            actionEnabled: !root.busy
            danger: true
            onRowHovered: root.setRowCursor(index)
            onActionClicked: {
              root.setRowCursor(index)
              if (isPacnew) root.removePacnewFile(modelData.path, modelData.name)
              else if (isAgent) root.removeAgent(modelData.id, modelData.name)
              else root.removePackage(modelData.name)
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "packages" && root.packagesViewLoading && root.packagesViewEmpty
          text: "Loading…"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "packages" && !root.packagesViewLoading && root.packagesViewEmpty
          text: root.packagesFilter === "orphans"
            ? "No orphaned packages"
            : root.packagesFilter === "pacnew"
            ? "No .pacnew/.pacsave/.pacorig files found"
            : root.packagesFilter === "agents"
            ? "No agent CLIs installed"
            : "No packages beyond the Omarchy defaults"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        ChipRow {
          id: launchersFilterRow
          visible: root.activeTab === "launchers"
          anchors.top: parent.top
          anchors.left: parent.left
          compact: true
          chips: root.launchersChips
          selectedKey: root.launchersFilter
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          cursorActive: root.cursorActive && root.focusSection === "filters" && root.activeTab === "launchers"
          cursorIndex: root.cursorActive && root.focusSection === "filters" && root.activeTab === "launchers" ? root.selectedIndex : -1
          onSelected: function(key) {
            root.setLaunchersFilter(key)
            root.setFiltersCursor(root.chipIndexByKey(root.launchersChips, key))
          }
          onChipHovered: function(index) { root.setFiltersCursor(index) }
        }

        ListView {
          id: launchersList
          anchors.top: launchersFilterRow.bottom
          anchors.topMargin: root.edgeMargin
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          visible: root.activeTab === "launchers"
          clip: true
          spacing: root.rowGap
          model: root.launchersItems
          delegate: ActionListRow {
            required property var modelData
            required property int index
            width: ListView.view.width
            rowHeight: root.rowHeight
            edgeMargin: root.edgeMargin
            contentForeground: root.contentForeground
            contentFontFamily: root.contentFontFamily
            hasCursor: root.cursorActive && root.focusSection === "rows" && root.activeTab === "launchers" && root.selectedIndex === index
            title: modelData.name
            actionLabel: "Remove"
            actionEnabled: !root.busy
            danger: true
            onRowHovered: root.setRowCursor(index)
            onActionClicked: {
              root.setRowCursor(index)
              root.removeLauncherItem(modelData)
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "launchers" && root.launchersViewLoading && root.launchersItems.length === 0
          text: "Loading…"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "launchers" && !root.launchersViewLoading && root.launchersItems.length === 0
          text: root.launchersFilter === "tuis"
            ? "No TUI launchers found"
            : "No Web App launchers found"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        ChipRow {
          id: startupFilterRow
          visible: root.activeTab === "startup"
          anchors.top: parent.top
          anchors.left: parent.left
          compact: true
          chips: root.startupChips
          selectedKey: root.startupFilter
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          cursorActive: root.cursorActive && root.focusSection === "filters" && root.activeTab === "startup"
          cursorIndex: root.cursorActive && root.focusSection === "filters" && root.activeTab === "startup" ? root.selectedIndex : -1
          onSelected: function(key) {
            root.setStartupFilter(key)
            root.setFiltersCursor(root.chipIndexByKey(root.startupChips, key))
          }
          onChipHovered: function(index) { root.setFiltersCursor(index) }
        }

        ListView {
          id: startupList
          anchors.top: startupFilterRow.bottom
          anchors.topMargin: root.edgeMargin
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          visible: root.activeTab === "startup"
          clip: true
          spacing: root.rowGap
          model: root.startupItems
          delegate: ActionListRow {
            required property var modelData
            required property int index
            width: ListView.view.width
            rowHeight: root.rowHeight
            edgeMargin: root.edgeMargin
            contentForeground: root.contentForeground
            contentFontFamily: root.contentFontFamily
            hasCursor: root.cursorActive && root.focusSection === "rows" && root.activeTab === "startup" && root.selectedIndex === index
            title: modelData.name
            subtitle: modelData.status + " · " + modelData.detail
            actionLabel: "Disable"
            actionVisible: modelData.status === "enabled"
            actionEnabled: !root.busy
            danger: false
            onRowHovered: root.setRowCursor(index)
            onActionClicked: {
              root.setRowCursor(index)
              root.disableStartupItem(modelData)
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "startup" && root.startupViewLoading && root.startupItems.length === 0
          text: "Loading…"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "startup" && !root.startupViewLoading && root.startupItems.length === 0
          text: root.startupFilter === "services"
            ? "No user-added systemd services found"
            : "No autostart entries found"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        ListView {
          id: cleanupList
          anchors.fill: parent
          visible: root.activeTab === "cleanup"
          clip: true
          spacing: root.rowGap
          model: root.cleanupRows

          delegate: ActionListRow {
            required property var modelData
            required property int index
            width: ListView.view.width
            rowHeight: root.rowHeight
            edgeMargin: root.edgeMargin
            contentForeground: root.contentForeground
            contentFontFamily: root.contentFontFamily
            hasCursor: root.cursorActive && root.focusSection === "rows" && root.activeTab === "cleanup" && root.selectedIndex === index
            title: modelData.label
            subtitle: {
              var size = Model.formatMib(root.cleanupStatus[modelData.key] || 0)
              return modelData.note !== "" ? size + " · " + modelData.note : size
            }
            actionLabel: "Clean"
            actionEnabled: !root.busy && (parseFloat(root.cleanupStatus[modelData.key]) || 0) > 0
            danger: true
            onRowHovered: root.setRowCursor(index)
            onActionClicked: {
              root.setRowCursor(index)
              root.runCleanup(modelData.key)
            }
          }
        }
      }
    }
  }

  Process {
    id: packagesProc
    command: ["bash", root.backendPath, root.packagesFilter === "orphans" ? "packages-orphans" : "packages-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.packages = Model.parsePackages(text)
        root.packagesLoading = false
        root.requestPackagesLastUsed(root.packages)
      }
    }
  }

  Process {
    id: lastUsedProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.packages = Model.withLastUsed(root.packages, Model.parseLastUsed(text))
      }
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
      onStreamFinished: root.cleanupStatus = Model.parseCleanupStatus(text)
    }
  }

  Process {
    id: actionProc
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
        if (exitCode === 0) {
          root.statusText = "Done"
          root.statusKind = "done"
        } else if (root.statusKind !== "error") {
          // Progress text is still set; don't require statusText === "".
          root.statusText = "Failed"
          root.statusKind = "error"
        }
        statusClearTimer.restart()
      })
      root.refreshAll()
    }
  }

  Timer {
    id: statusClearTimer
    interval: 2000
    onTriggered: root.statusText = ""
  }
}
