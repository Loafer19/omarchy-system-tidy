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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: Style.bar.iconSlot
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: "System Tidy"

    onPressed: function(b) { root.toggle() }

    // MDI "broom" glyph (broom.svg, Apache-2.0), pre-tinted to the bar's
    // foreground (#A9B1D6, sampled from the neighboring icons) rather than
    // recolored at runtime — one less moving part than a shader effect.
    Image {
      id: icon
      anchors.centerIn: parent
      width: Style.space(16)
      height: Style.space(16)
      source: Qt.resolvedUrl("broom.svg")
      sourceSize.width: width * 2
      sourceSize.height: height * 2
      fillMode: Image.PreserveAspectFit
      smooth: true
    }
  }
}
