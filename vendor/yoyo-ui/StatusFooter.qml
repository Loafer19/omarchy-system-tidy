import QtQuick
import qs.Commons

// Footer bar: key hints, replaced by a status line while one is showing
// (so nothing above it moves), plus optional right-aligned text.
// Either bind statusText / statusKind yourself, or call flash(text, kind):
// errors clear after errorMs, "done"/"" after doneMs, "progress" stays until
// the next flash() or clear().
Item {
  id: root

  property var hints: []
  property string statusText: ""
  // "" (plain), "progress", "done" (accent) or "error" (urgent)
  property string statusKind: ""
  property string rightText: ""
  property int doneMs: 2500
  property int errorMs: 6000

  function flash(text, kind) {
    root.statusText = text || ""
    root.statusKind = kind || ""
    if (root.statusText === "" || root.statusKind === "progress") clearTimer.stop()
    else { clearTimer.interval = root.statusKind === "error" ? root.errorMs : root.doneMs; clearTimer.restart() }
  }
  function clear() { clearTimer.stop(); root.statusText = ""; root.statusKind = "" }

  implicitHeight: Style.space(18)
  height: implicitHeight

  Timer { id: clearTimer; onTriggered: root.clear() }

  KeyHints {
    anchors.left: parent.left
    anchors.leftMargin: Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    visible: root.statusText === ""
    hints: root.hints
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: Theme.edge
    anchors.right: rightLabel.visible ? rightLabel.left : parent.right
    anchors.rightMargin: Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    visible: root.statusText !== ""
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: root.statusText
    color: root.statusKind === "error" ? Theme.urgent
      : root.statusKind === "done" ? Theme.accent
      : Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: Theme.caption
    font.bold: true
  }

  Text {
    id: rightLabel
    anchors.right: parent.right
    anchors.rightMargin: Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    visible: root.rightText !== ""
    textFormat: Text.PlainText
    text: root.rightText
    color: Theme.dim
    font.family: Theme.fontFamily
    font.pixelSize: Theme.caption
  }
}
