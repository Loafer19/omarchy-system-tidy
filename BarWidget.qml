import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar entry point for System Tidy: a click opens the tabbed audit panel.
// Follows the same bar-widget/panel split as the built-in clock widget —
// this root owns the bar label, Panel.qml owns the floating content.
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

  IpcHandler {
    target: "yoyo.system-tidy"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  // Nerd Font "md-broom" glyph, rendered the same way every other first-party
  // bar icon is (BarIconButton -> OpticalGlyph text), instead of a rasterized
  // SVG + MultiEffect recolor — matches neighboring icons' weight/brightness
  // exactly since it's the same font-glyph rendering path they all use.
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰃢"
    tooltipText: "System Tidy"

    onPressed: function(b) { root.toggle() }
  }
}
