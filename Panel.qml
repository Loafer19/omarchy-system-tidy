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
  property var cleanupStatus: ({ pacman: 0, coredump: 0, trash: 0, docker: 0, browser: 0, journal: 0 })
  property bool busy: false
  property string statusText: ""

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dividerColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.12)

  readonly property var tabs: [
    { key: "packages", label: "Packages" },
    { key: "webapps", label: "Webapps" },
    { key: "autostart", label: "Autostart" },
    { key: "cleanup", label: "Cleanup" }
  ]

  function refreshAll() {
    packagesProc.running = true
    webappsProc.running = true
    autostartProc.running = true
    cleanupProc.running = true
  }

  onOpenedChanged: if (opened) refreshAll()

  function runAction(args, message) {
    if (root.busy) return
    root.busy = true
    root.statusText = message
    actionProc.command = ["bash", root.backendPath].concat(args)
    actionProc.running = true
  }

  function setPackagesFilter(key) {
    if (root.packagesFilter === key) return
    root.packagesFilter = key
    packagesProc.running = true
  }

  function removePackage(name) { runAction(["packages-remove", name], "Removing " + name + "…") }
  function removeWebapp(name) { runAction(["webapps-remove", name], "Removing " + name + "…") }
  function disableAutostart(name) { runAction(["autostart-disable", name], "Disabling " + name + "…") }
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
                ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                : (tabMouse.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06) : "transparent")

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
          visible: root.statusText !== ""
          text: root.statusText
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      Item {
        id: body
        anchors.top: header.bottom
        anchors.topMargin: Style.space(8)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Row {
          id: packagesFilterRow
          visible: root.activeTab === "packages"
          anchors.top: parent.top
          anchors.left: parent.left
          height: Style.space(24)
          spacing: Style.space(6)

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
                ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                : (filterMouse.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06) : "transparent")
              border.width: selected ? 0 : Style.spacing.hairline
              border.color: root.dividerColor

              Text {
                id: filterLabel
                anchors.centerIn: parent
                text: modelData.label
                color: selected ? root.contentForeground : Qt.darker(root.contentForeground, 1.4)
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
          anchors.topMargin: Style.space(6)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          visible: root.activeTab === "packages"
          clip: true
          model: root.packages
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: Style.space(44)
            color: "transparent"

            Column {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(6)
              spacing: Style.space(2)

              Text {
                text: modelData.name
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                text: Model.formatMib(modelData.sizeMb) + " · installed " + modelData.date
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: Style.space(6)
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: removeMouse.containsMouse ? Qt.rgba(0.8, 0.2, 0.2, 0.25) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

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
            ? "No orphaned packages."
            : "No packages beyond the Omarchy defaults."
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        ListView {
          anchors.fill: parent
          visible: root.activeTab === "webapps"
          clip: true
          model: root.webapps
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: Style.space(40)
            color: "transparent"

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(6)
              text: modelData.name
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: Style.space(6)
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: removeWebappMouse.containsMouse ? Qt.rgba(0.8, 0.2, 0.2, 0.25) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

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
          text: "No webapp launchers installed."
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        ListView {
          anchors.fill: parent
          visible: root.activeTab === "autostart"
          clip: true
          model: root.autostartItems
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: Style.space(44)
            color: "transparent"

            Column {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(6)
              spacing: Style.space(2)

              Text {
                text: modelData.name
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                text: modelData.status + " · " + modelData.source
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: Style.space(6)
              width: Style.space(72)
              height: Style.space(26)
              radius: Style.cornerRadius
              visible: modelData.status === "enabled"
              color: disableMouse.containsMouse ? Qt.rgba(0.8, 0.2, 0.2, 0.25) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

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

        Column {
          anchors.fill: parent
          visible: root.activeTab === "cleanup"
          spacing: Style.space(10)

          Repeater {
            model: [
              { key: "pacman", label: "Pacman cache" },
              { key: "coredump", label: "Coredumps" },
              { key: "trash", label: "Trash" },
              { key: "docker", label: "Docker (prune)" },
              { key: "browser", label: "Browser cache" },
              { key: "journal", label: "Journal logs" }
            ]

            Rectangle {
              required property var modelData
              width: parent.width
              height: Style.space(44)
              color: "transparent"

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label + " — " + Model.formatMib(root.cleanupStatus[modelData.key] || 0)
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }

              Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(72)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: cleanMouse.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

                Text {
                  anchors.centerIn: parent
                  text: "Clean"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: cleanMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.runCleanup(modelData.key)
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
        if (err !== "") root.statusText = err
      }
    }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode === 0) root.statusText = ""
      root.refreshAll()
    }
  }
}
