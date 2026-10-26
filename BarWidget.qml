import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Bar chrome here; Panel.qml owns the floating content (same split as clock).
BarWidget {
  id: root
  moduleName: "yoyo.system-tidy"

  // Untyped handles: the loaded Panel, this button's window and the host bar
  // are only known at runtime (qmllint sees them as plain QObject).
  readonly property var panelItem: panelLoader.item
  readonly property var hostWindow: button.QsWindow.window
  readonly property var hostBar: root.bar

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

  // Legacy `omarchy shell yoyo.system-tidy toggle`. The bar is created once
  // per monitor, and only one IpcHandler per target may exist, so only the
  // instance on the first screen registers it ("Handler was registered but
  // will not be used" otherwise), and it routes through the shell's bar so
  // the panel opens on the focused monitor, like
  // `omarchy shell shell toggle yoyo.system-tidy` does.
  readonly property string hostScreenName: {
    var w = root.hostWindow
    return w && w.screen ? String(w.screen.name || "") : ""
  }
  readonly property bool isPrimaryInstance: {
    var screens = Quickshell.screens
    if (root.hostScreenName === "" || !screens || screens.length === 0) return true
    return String(screens[0].name || "") === root.hostScreenName
  }

  function shellBar() {
    var s = root.hostBar ? root.hostBar.shell : null
    var b = s ? s.bar : null
    return b && typeof b.summonBarWidget === "function" && typeof b.hideBarWidget === "function"
      && typeof b.isBarWidgetOpen === "function" ? b : null
  }

  IpcHandler {
    target: "yoyo.system-tidy"
    enabled: root.isPrimaryInstance

    function open(): void {
      var b = root.shellBar()
      if (!b || !b.summonBarWidget(root.moduleName)) root.open()
    }
    function close(): void {
      var b = root.shellBar()
      if (!b || !b.hideBarWidget(root.moduleName)) root.close()
    }
    function toggle(): void {
      var b = root.shellBar()
      if (!b) { root.toggle(); return }
      var ok = b.isBarWidgetOpen(root.moduleName) ? b.hideBarWidget(root.moduleName) : b.summonBarWidget(root.moduleName)
      if (!ok) root.toggle()
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
