// Offscreen preview harness for tools/render-previews.sh: the real Panel.qml
// with tests/preview/backend.sh standing in for scripts/backend.sh. Opens the
// panel on PREVIEW_TAB, waits for the fake lists, saves the card to
// PREVIEW_OUT and quits.
import QtQuick
import Quickshell
import qs.Commons as Commons
import "plugin" as P

ShellRoot {
  id: shell
  property string tab: Quickshell.env("PREVIEW_TAB") || "cleanup"
  property string out: Quickshell.env("PREVIEW_OUT") || ""

  QtObject {
    id: fakeBar
    property color barForeground: Commons.Color.foreground
    property color foreground: Commons.Color.foreground
    property string fontFamily: Commons.Style.font.family
    property bool vertical: false
    property int barSize: 30
    property bool urgent: false
    property bool foregroundAnimationEnabled: false
    property QtObject shell: QtObject { function serviceFor(n) { return null } }
    function showTooltip() {}
    function hideTooltip() {}
  }

  FloatingWindow {
    implicitWidth: 900
    implicitHeight: 900
    color: "transparent"
    P.Panel { id: panel; bar: fakeBar; anchors.fill: parent }
  }

  Timer {
    interval: 1200; running: true
    onTriggered: { panel.open(); panel.activeTab = shell.tab; grab.start() }
  }
  Timer {
    id: grab; interval: 1500
    onTriggered: {
      var kp = panel.children.filter(function(c) { return c.card !== undefined })[0]
      kp.card.grabToImage(function(r) {
        r.saveToFile(shell.out)
        console.log("saved", shell.out, kp.card.width, kp.card.height)
        Qt.quit()
      })
    }
  }
}
