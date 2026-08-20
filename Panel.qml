import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Tabbed audit panel: packages added on top of the Omarchy defaults, webapp
// launchers, autostart entries, and disk cleanup targets. Each tab shells
// out to scripts/backend.sh and lists results with a one-click action.
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
  property var packages: []
  property var webapps: []
  property var autostartItems: []
  property var systemdUnits: []
  property var cleanupStatus: ({ pacman: 0, coredump: 0, trash: 0, docker: 0, browser: 0, aur: 0, dev: 0, journal: 0, orphans_count: 0, orphans_mb: 0 })
  property bool busy: false
  property string statusText: ""
  property string statusKind: "progress" // "progress" | "done" | "error"

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dividerColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.12)

  // Single edge-margin/padding value for every row and section gap in this
  // panel, so spacing stays consistent in one place instead of scattered
  // ad-hoc numbers.
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
    { key: "autostart", label: "Autostart" },
    { key: "services", label: "Services" },
    { key: "webapps", label: "Webapps" }
  ]

  function refreshAll() {
    packagesProc.running = true
    webappsProc.running = true
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
    packagesProc.running = true
  }

  function removePackage(name) { runAction(["packages-remove", name], "Snapshotting + removing " + name + "…") }
  function removeWebapp(name) { runAction(["webapps-remove", name], "Removing " + name + "…") }
  function disableAutostart(name) { runAction(["autostart-disable", name], "Disabling " + name + "…") }
  function disableSystemdUnit(name) { runAction(["systemd-disable", name], "Disabling " + name + "…") }
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

          // Keeps showing the last message while it fades out, instead of
          // snapping to blank the instant statusClearTimer clears the text.
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
              { key: "orphans", label: "Orphans" }
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
          model: root.packages
          delegate: Rectangle {
            required property var modelData
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
                text: Model.formatMib(modelData.sizeMb) + " · installed " + modelData.date + " · used " + modelData.lastUsed
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
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removePackage(modelData.name)
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "packages" && root.packages.length === 0
          text: root.packagesFilter === "orphans"
            ? "No orphaned packages"
            : "No packages beyond the Omarchy defaults"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        ListView {
          anchors.fill: parent
          visible: root.activeTab === "webapps"
          clip: true
          spacing: root.rowGap
          model: root.webapps
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: root.rowHeight
            color: "transparent"

            Text {
              anchors.left: parent.left
              anchors.leftMargin: root.edgeMargin
              anchors.right: removeWebappBtn.left
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
              id: removeWebappBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: root.edgeMargin
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: removeWebappMouse.containsMouse ? root.dangerHoverFill : root.normalRowFill

              Text {
                anchors.centerIn: parent
                text: "Remove"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: removeWebappMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeWebapp(modelData.name)
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "webapps" && root.webapps.length === 0
          text: "No webapp launchers installed"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        ListView {
          anchors.fill: parent
          visible: root.activeTab === "autostart"
          clip: true
          spacing: root.rowGap
          model: root.autostartItems
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: root.rowHeight
            color: "transparent"

            Column {
              id: autostartInfoCol
              anchors.left: parent.left
              anchors.leftMargin: root.edgeMargin
              anchors.right: disableBtn.left
              anchors.rightMargin: root.edgeMargin
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: autostartInfoCol.width
                elide: Text.ElideRight
                text: modelData.name
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                width: autostartInfoCol.width
                elide: Text.ElideRight
                text: modelData.status + " · " + modelData.source
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              id: disableBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: root.edgeMargin
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              visible: modelData.status === "enabled"
              color: disableMouse.containsMouse ? root.dangerHoverFill : root.normalRowFill

              Text {
                anchors.centerIn: parent
                text: "Disable"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: disableMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.disableAutostart(modelData.name)
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "autostart" && root.autostartItems.length === 0
          text: "No autostart entries found"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        ListView {
          anchors.fill: parent
          visible: root.activeTab === "services"
          clip: true
          spacing: root.rowGap
          model: root.systemdUnits
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: root.rowHeight
            color: "transparent"

            Column {
              id: serviceInfoCol
              anchors.left: parent.left
              anchors.leftMargin: root.edgeMargin
              anchors.right: disableServiceBtn.left
              anchors.rightMargin: root.edgeMargin
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: serviceInfoCol.width
                elide: Text.ElideRight
                text: modelData.name
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                width: serviceInfoCol.width
                elide: Text.ElideRight
                text: modelData.status + " · " + modelData.type
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              id: disableServiceBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: root.edgeMargin
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              visible: modelData.status === "enabled"
              color: disableServiceMouse.containsMouse ? root.dangerHoverFill : root.normalRowFill

              Text {
                anchors.centerIn: parent
                text: "Disable"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: disableServiceMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.disableSystemdUnit(modelData.name)
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.activeTab === "services" && root.systemdUnits.length === 0
          text: "No user-added systemd services found"
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
      onStreamFinished: root.packages = Model.parsePackages(text)
    }
  }

  Process {
    id: webappsProc
    command: ["bash", root.backendPath, "webapps-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.webapps = Model.parseWebapps(text)
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
