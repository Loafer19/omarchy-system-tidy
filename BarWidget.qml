import QtQuick
import qs.Ui

// Bar chrome here; Panel.qml owns the floating content (same split as clock).
// No IpcHandler here: the bar builds this widget once per monitor, and a
// target may have only one handler, so Service.qml owns `yoyo.system-tidy`.
BarWidget {
  id: root
  moduleName: "yoyo.system-tidy"

  // Untyped handle: the loaded Panel is only known at runtime (qmllint sees
  // it as plain QObject).
  readonly property var panelItem: panelLoader.item

  readonly property bool opened: root.panelItem ? root.panelItem.opened === true : false

  function open() {
    if (root.panelItem) root.panelItem.open()
  }

  function close() {
    if (root.panelItem) root.panelItem.close()
  }

  function toggle() {
    if (root.panelItem) root.panelItem.toggle()
  }

  readonly property bool popoutSwitchClosing: root.panelItem ? root.panelItem.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (root.panelItem) root.panelItem.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = root.panelItem
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰃢"
    tooltipText: "System Tidy"

    onPressed: function(b) { root.toggle() }
  }
}
