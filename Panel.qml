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
  property var agents: []
  property var webapps: []
  property var tuis: []
  property var autostartItems: []
  property var systemdUnits: []
  property var cleanupStatus: ({ pacman: 0, coredump: 0, trash: 0, docker: 0, browser: 0, aur: 0, dev: 0, agents: 0, journal: 0, orphans_count: 0, orphans_mb: 0 })
  property bool busy: false
  property string statusText: ""
  property string statusKind: "progress" // "progress" | "done" | "error"

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dividerColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.12)

  // Single spacing value instead of scattered ad-hoc numbers.
  readonly property int edgeMargin: Style.space(6)
  readonly property int rowGap: 0
  readonly property int rowHeight: Style.space(44)

  readonly property color normalRowFill: Style.normalFillFor(contentForeground, Color.accent, Color.urgent)
  readonly property color hoverRowFill: Style.hoverFillFor(contentForeground, Color.accent, Color.urgent)
  readonly property color selectedRowFill: Style.selectedFillFor(contentForeground, Color.accent, Color.urgent)
  readonly property color dangerHoverFill: Util.alpha(Color.urgent, Style.hoverFillAlpha)

  readonly property var tabs: [
    { key: "packages", label: "Packages" },
    { key: "cleanup", label: "Cleanup" },
    { key: "startup", label: "Startup" },
    { key: "launchers", label: "Launchers" }
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

  function refreshAll() {
    if (root.packagesFilter === "pacnew") {
      pacnewProc.running = true
    } else if (root.packagesFilter === "agents") {
      agentsProc.running = true
    } else {
      root.packagesLoading = true
      packagesProc.running = true
    }
    webappsProc.running = true
    tuisProc.running = true
    autostartProc.running = true
    systemdProc.running = true
    cleanupProc.running = true
  }

  onOpenedChanged: if (opened) refreshAll()

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
    if (key === "pacnew") {
      pacnewProc.running = true
    } else if (key === "agents") {
      agentsProc.running = true
    } else {
      root.packagesLoading = true
      packagesProc.running = true
    }
  }

  function setStartupFilter(key) {
    root.startupFilter = key
  }

  function setLaunchersFilter(key) {
    root.launchersFilter = key
  }

  function removePackage(name) { runAction(["packages-remove", name], "Snapshotting + removing " + name + "…") }
  function removePacnewFile(path, name) { runAction(["packages-pacnew-remove", path], "Removing " + name + "…") }
  function removeAgent(id, name) { runAction(["agents-remove", id], "Removing " + name + "…") }
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
  function runCleanup(target) { runAction(["cleanup-run", target], "Cleaning " + target + "…") }

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
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(8)

        Row {
          spacing: Style.space(4)

          Repeater {
            model: root.tabs

            Rectangle {
              required property var modelData
              width: tabLabel.implicitWidth + Style.space(20)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: root.activeTab === modelData.key
                ? root.selectedRowFill
                : (tabMouse.containsMouse ? root.hoverRowFill : "transparent")
              border.width: root.activeTab === modelData.key ? 0 : Style.spacing.hairline
              border.color: root.dividerColor

              Text {
                id: tabLabel
                anchors.centerIn: parent
                text: modelData.label
                color: root.activeTab === modelData.key ? root.contentForeground : Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: root.activeTab === modelData.key
              }

              MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = modelData.key
              }
            }
          }
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

        Row {
          id: packagesFilterRow
          visible: root.activeTab === "packages"
          anchors.top: parent.top
          anchors.left: parent.left
          height: Style.space(24)
          spacing: root.edgeMargin

          Repeater {
            model: [
              { key: "extra", label: "Extra" },
              { key: "orphans", label: "Orphans" },
              { key: "pacnew", label: "Pacnew" },
              { key: "agents", label: "Agents" }
            ]

            Rectangle {
              required property var modelData
              readonly property bool selected: root.packagesFilter === modelData.key
              width: filterLabel.implicitWidth + Style.space(16)
              height: Style.space(24)
              radius: Style.cornerRadius
              color: selected
                ? root.selectedRowFill
                : (filterMouse.containsMouse ? root.hoverRowFill : "transparent")
              border.width: selected ? 0 : Style.spacing.hairline
              border.color: root.dividerColor

              Text {
                id: filterLabel
                anchors.centerIn: parent
                text: modelData.label
                color: selected ? root.contentForeground : Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: filterMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setPackagesFilter(modelData.key)
              }
            }
          }
        }

        ListView {
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
          delegate: Rectangle {
            required property var modelData
            readonly property bool isPacnew: root.packagesFilter === "pacnew"
            readonly property bool isAgent: root.packagesFilter === "agents"
            width: ListView.view.width
            height: root.rowHeight
            color: "transparent"

            Column {
              id: packageInfoCol
              anchors.left: parent.left
              anchors.leftMargin: root.edgeMargin
              anchors.right: removeBtn.left
              anchors.rightMargin: root.edgeMargin
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: packageInfoCol.width
                elide: Text.ElideRight
                text: modelData.name
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                width: packageInfoCol.width
                elide: Text.ElideRight
                text: isPacnew
                  ? Model.formatBytes(modelData.bytes) + " · " + modelData.path
                  : isAgent
                  ? Model.formatMib(modelData.sizeMb) + " · " + modelData.detail
                  : Model.formatMib(modelData.sizeMb) + " · installed " + modelData.date + " · used " + modelData.lastUsed
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              id: removeBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: root.edgeMargin
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              opacity: root.busy ? 0.45 : 1.0
              color: removeMouse.containsMouse ? root.dangerHoverFill : root.normalRowFill

              Text {
                anchors.centerIn: parent
                text: "Remove"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: removeMouse
                anchors.fill: parent
                enabled: !root.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (isPacnew) root.removePacnewFile(modelData.path, modelData.name)
                  else if (isAgent) root.removeAgent(modelData.id, modelData.name)
                  else root.removePackage(modelData.name)
                }
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "packages"
            && root.packagesFilter !== "pacnew" && root.packagesFilter !== "agents"
            && root.packagesLoading && root.packages.length === 0
          text: "Loading…"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "packages" && (
            root.packagesFilter === "pacnew" ? root.pacnewFiles.length === 0
              : root.packagesFilter === "agents" ? root.agents.length === 0
              : (!root.packagesLoading && root.packages.length === 0)
          )
          text: root.packagesFilter === "orphans"
            ? "No orphaned packages"
            : root.packagesFilter === "pacnew"
            ? "No .pacnew/.pacsave files found"
            : root.packagesFilter === "agents"
            ? "No coding agents installed"
            : "No packages beyond the Omarchy defaults"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        Row {
          id: launchersFilterRow
          visible: root.activeTab === "launchers"
          anchors.top: parent.top
          anchors.left: parent.left
          height: Style.space(24)
          spacing: root.edgeMargin

          Repeater {
            model: [
              { key: "webapps", label: "Webapps" },
              { key: "tuis", label: "TUIs" }
            ]

            Rectangle {
              required property var modelData
              readonly property bool selected: root.launchersFilter === modelData.key
              width: launchersFilterLabel.implicitWidth + Style.space(16)
              height: Style.space(24)
              radius: Style.cornerRadius
              color: selected
                ? root.selectedRowFill
                : (launchersFilterMouse.containsMouse ? root.hoverRowFill : "transparent")
              border.width: selected ? 0 : Style.spacing.hairline
              border.color: root.dividerColor

              Text {
                id: launchersFilterLabel
                anchors.centerIn: parent
                text: modelData.label
                color: selected ? root.contentForeground : Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: launchersFilterMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setLaunchersFilter(modelData.key)
              }
            }
          }
        }

        ListView {
          anchors.top: launchersFilterRow.bottom
          anchors.topMargin: root.edgeMargin
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          visible: root.activeTab === "launchers"
          clip: true
          spacing: root.rowGap
          model: root.launchersItems
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: root.rowHeight
            color: "transparent"

            Text {
              anchors.left: parent.left
              anchors.leftMargin: root.edgeMargin
              anchors.right: removeLauncherBtn.left
              anchors.rightMargin: root.edgeMargin
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              text: modelData.name
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Rectangle {
              id: removeLauncherBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: root.edgeMargin
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              opacity: root.busy ? 0.45 : 1.0
              color: removeLauncherMouse.containsMouse ? root.dangerHoverFill : root.normalRowFill

              Text {
                anchors.centerIn: parent
                text: "Remove"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: removeLauncherMouse
                anchors.fill: parent
                enabled: !root.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeLauncherItem(modelData)
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "launchers" && root.launchersItems.length === 0
          text: root.launchersFilter === "tuis"
            ? "No TUI launchers installed"
            : "No webapp launchers installed"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        Row {
          id: startupFilterRow
          visible: root.activeTab === "startup"
          anchors.top: parent.top
          anchors.left: parent.left
          height: Style.space(24)
          spacing: root.edgeMargin

          Repeater {
            model: [
              { key: "autostart", label: "Autostart" },
              { key: "services", label: "Services" }
            ]

            Rectangle {
              required property var modelData
              readonly property bool selected: root.startupFilter === modelData.key
              width: startupFilterLabel.implicitWidth + Style.space(16)
              height: Style.space(24)
              radius: Style.cornerRadius
              color: selected
                ? root.selectedRowFill
                : (startupFilterMouse.containsMouse ? root.hoverRowFill : "transparent")
              border.width: selected ? 0 : Style.spacing.hairline
              border.color: root.dividerColor

              Text {
                id: startupFilterLabel
                anchors.centerIn: parent
                text: modelData.label
                color: selected ? root.contentForeground : Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: startupFilterMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setStartupFilter(modelData.key)
              }
            }
          }
        }

        ListView {
          anchors.top: startupFilterRow.bottom
          anchors.topMargin: root.edgeMargin
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          visible: root.activeTab === "startup"
          clip: true
          spacing: root.rowGap
          model: root.startupItems
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: root.rowHeight
            color: "transparent"

            Column {
              id: startupInfoCol
              anchors.left: parent.left
              anchors.leftMargin: root.edgeMargin
              anchors.right: disableStartupBtn.left
              anchors.rightMargin: root.edgeMargin
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: startupInfoCol.width
                elide: Text.ElideRight
                text: modelData.name
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                width: startupInfoCol.width
                elide: Text.ElideRight
                text: modelData.status + " · " + modelData.detail
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              id: disableStartupBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: root.edgeMargin
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              visible: modelData.status === "enabled"
              opacity: root.busy ? 0.45 : 1.0
              color: disableStartupMouse.containsMouse ? root.dangerHoverFill : root.normalRowFill

              Text {
                anchors.centerIn: parent
                text: "Disable"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: disableStartupMouse
                anchors.fill: parent
                enabled: !root.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.disableStartupItem(modelData)
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "startup" && root.startupItems.length === 0
          text: root.startupFilter === "services"
            ? "No user-added systemd services found"
            : "No autostart entries found"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        ListView {
          anchors.fill: parent
          visible: root.activeTab === "cleanup"
          clip: true
          spacing: root.rowGap
          model: [
            { key: "pacman", label: "Pacman cache", action: "clean", note: "Skips packages you still have installed" },
            { key: "aur", label: "AUR build cache", action: "clean", note: "yay/paru build artifacts, safe to delete" },
            { key: "dev", label: "Dev tool caches", action: "clean", note: "pip, npm, cargo, go — all rebuild on demand" },
            { key: "agents", label: "Agent caches", action: "clean", note: "Sessions and tmp — keeps login and settings" },
            { key: "docker", label: "Docker (prune)", action: "clean", note: "Leaves images you still use alone" },
            { key: "browser", label: "Browser cache", action: "clean", note: "Just page cache — won't log you out" },
            { key: "coredump", label: "Coredumps", action: "clean", note: "Crash dumps (coredumpctl), safe to delete" },
            { key: "journal", label: "Journal logs", action: "clean", note: "Keeps the latest 100 MiB" },
            { key: "trash", label: "Trash", action: "clean", note: "" },
            { key: "orphans", label: "Orphan packages", action: "view", note: "Safe to remove — opens Packages → Orphans" }
          ]

          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: root.rowHeight
            color: "transparent"

            Column {
              id: contentCol
              anchors.left: parent.left
              anchors.leftMargin: root.edgeMargin
              anchors.right: actionBtn.left
              anchors.rightMargin: root.edgeMargin
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: contentCol.width
                text: modelData.key === "orphans"
                  ? modelData.label + " (" + (root.cleanupStatus.orphans_count || 0) + ")"
                  : modelData.label
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                width: contentCol.width
                elide: Text.ElideRight
                text: {
                  var size = modelData.key === "orphans"
                    ? Model.formatMib(root.cleanupStatus.orphans_mb || 0)
                    : Model.formatMib(root.cleanupStatus[modelData.key] || 0)
                  return modelData.note !== "" ? size + " · " + modelData.note : size
                }
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              id: actionBtn
              anchors.right: parent.right
              anchors.rightMargin: root.edgeMargin
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              opacity: root.busy ? 0.45 : 1.0
              color: cleanMouse.containsMouse
                ? (modelData.action === "view" ? root.hoverRowFill : root.dangerHoverFill)
                : root.normalRowFill

              Text {
                anchors.centerIn: parent
                text: modelData.action === "view" ? "View" : "Clean"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: cleanMouse
                anchors.fill: parent
                enabled: !root.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.action === "view") {
                    root.activeTab = "packages"
                    root.setPackagesFilter("orphans")
                  } else {
                    root.runCleanup(modelData.key)
                  }
                }
              }
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
      }
    }
  }

  Process {
    id: pacnewProc
    command: ["bash", root.backendPath, "packages-pacnew"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.pacnewFiles = Model.parsePacnewFiles(text)
    }
  }

  Process {
    id: agentsProc
    command: ["bash", root.backendPath, "agents-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.agents = Model.parseAgents(text)
    }
  }

  Process {
    id: webappsProc
    command: ["bash", root.backendPath, "webapps-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.webapps = Model.parseNameList(text)
    }
  }

  Process {
    id: tuisProc
    command: ["bash", root.backendPath, "tui-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.tuis = Model.parseNameList(text)
    }
  }

  Process {
    id: autostartProc
    command: ["bash", root.backendPath, "autostart-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.autostartItems = Model.parseAutostart(text)
    }
  }

  Process {
    id: systemdProc
    command: ["bash", root.backendPath, "systemd-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.systemdUnits = Model.parseSystemdUnits(text)
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
        if (exitCode === 0) { root.statusText = "Done"; root.statusKind = "done" }
        else if (root.statusText === "") { root.statusText = "Failed"; root.statusKind = "error" }
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
