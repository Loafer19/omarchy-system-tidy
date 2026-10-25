import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar chrome here; Panel.qml owns the floating content (same split as clock).
BarWidget {
  id: root
  moduleName: "yoyo.system-tidy"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
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
    var w = button.QsWindow.window
    return w && w.screen ? String(w.screen.name || "") : ""
  }
  readonly property bool isPrimaryInstance: {
    var screens = Quickshell.screens
    if (root.hostScreenName === "" || !screens || screens.length === 0) return true
    return String(screens[0].name || "") === root.hostScreenName
  }

  function shellBar() {
    var s = root.bar ? root.bar.shell : null
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
