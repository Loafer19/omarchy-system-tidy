import QtQuick
import qs.Commons
import qs.Ui
import "../theme"

// Title + subtitle with a right-edge action; row highlight via hasCursor.
CursorSurface {
  id: root

  property string title: ""
  property string subtitle: ""
  property string actionLabel: ""
  property bool actionVisible: true
  property bool actionEnabled: true
  property bool danger: true
  // Armed = waiting for the second Enter/click; subtitle turns into the hint.
  property bool armed: false
  property string armedText: ""

  signal actionClicked()
  signal rowHovered()

  height: Theme.rowHeight
  foreground: Theme.fg
  fill: root.armed ? Theme.tint(Theme.urgent, 0.10) : Theme.hoverFill
  bordered: false
  current: root.armed
  currentFill: Theme.tint(Theme.urgent, 0.10)

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onContainsMouseChanged: if (containsMouse) root.rowHovered()
  }

  Column {
    id: infoCol
    anchors.left: parent.left
    anchors.leftMargin: Theme.edge
    anchors.right: actionBtn.left
    anchors.rightMargin: Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)
    z: 1

    Text {
      width: infoCol.width
      elide: Text.ElideRight
      textFormat: Text.PlainText
      visible: root.title !== ""
      text: root.title
      color: Theme.fg
      font.family: Theme.fontFamily
      font.pixelSize: Theme.body
      font.bold: true
    }
    Text {
      width: infoCol.width
      elide: Text.ElideRight
      textFormat: Text.PlainText
      visible: text !== ""
      text: root.armed && root.armedText !== "" ? root.armedText : root.subtitle
      color: root.armed ? Theme.urgent : Theme.dim
      font.family: Theme.fontFamily
      font.pixelSize: Theme.caption
    }
  }

  Rectangle {
    id: actionBtn
    anchors.right: parent.right
    anchors.rightMargin: Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    z: 2
    visible: root.actionVisible && root.actionLabel !== ""
    width: Style.space(72)
    height: Style.space(26)
    radius: Style.cornerRadius
    opacity: root.actionEnabled ? 1.0 : 0.45
    color: root.armed ? Theme.urgent
      : actionMouse.containsMouse && root.actionEnabled
      ? (root.danger ? Theme.tint(Theme.urgent, Style.hoverFillAlpha) : Theme.hoverFill)
      : Theme.normalFill

    Text {
      anchors.centerIn: parent
      text: root.armed ? "Confirm" : root.actionLabel
      color: root.armed ? Theme.background : Theme.fg
      font.bold: root.armed
      font.family: Theme.fontFamily
      font.pixelSize: Theme.caption
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      enabled: root.actionEnabled
      hoverEnabled: true
      cursorShape: root.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onContainsMouseChanged: if (containsMouse) root.rowHovered()
      onClicked: root.actionClicked()
    }
  }
}
