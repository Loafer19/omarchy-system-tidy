import QtQuick
import qs.Commons
import qs.Ui

// Title + caption and one chip. confirm rows ask once: the first activate()
// arms the chip ("Confirm", urgent) for armMs, the second one triggers.
// After triggering, the chip shows doneText (if set) for doneMs.
CursorSurface {
  id: root

  property string title: ""
  property string subtitle: ""
  property string chip: ""
  property bool confirm: false
  property bool armed: false
  property bool done: false
  property string confirmText: "Confirm"
  property string confirmTooltip: "Click again to confirm"
  property string doneText: ""
  property int armMs: 3000
  property int doneMs: 1500

  signal rowHovered()
  signal triggered()

  implicitHeight: Theme.rowHeight
  height: implicitHeight
  foreground: Theme.fg
  fill: Theme.hoverFill
  bordered: false

  function activate() {
    if (root.confirm && !root.armed) { root.armed = true; disarm.restart(); return }
    root.armed = false
    disarm.stop()
    root.triggered()
    root.done = true
    doneTimer.restart()
  }
  Timer { id: disarm; interval: root.armMs; onTriggered: root.armed = false }
  Timer { id: doneTimer; interval: root.doneMs; onTriggered: root.done = false }
  onHasCursorChanged: if (!hasCursor) armed = false

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onContainsMouseChanged: if (containsMouse) root.rowHovered()
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Theme.edge
    anchors.right: chipItem.left
    anchors.rightMargin: Theme.gap
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: root.title
      color: Theme.fg
      font.family: Theme.fontFamily
      font.pixelSize: Theme.body
      font.bold: true
    }
    Text {
      width: parent.width
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: root.subtitle
      color: Theme.dim
      font.family: Theme.fontFamily
      font.pixelSize: Theme.caption
    }
  }

  HeaderChip {
    id: chipItem
    anchors.right: parent.right
    anchors.rightMargin: Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    text: root.armed ? root.confirmText : (root.done && root.doneText !== "" ? root.doneText : root.chip)
    on: root.armed || root.hasCursor
    danger: root.confirm && root.armed
    tooltipText: root.armed ? root.confirmTooltip : ""
    onClicked: root.activate()
  }
}
