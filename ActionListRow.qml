import QtQuick
import qs.Commons
import qs.Ui

// Title + optional subtitle with a right-edge text action (Remove/Clean/…).
// Row chrome comes from CursorSurface (hasCursor), never from containsMouse.
CursorSurface {
  id: root

  property string title: ""
  property string subtitle: ""
  property string actionLabel: ""
  property bool actionVisible: true
  property bool actionEnabled: true
  // Urgent tint for Remove/Clean; normal hover for View/Disable.
  property bool danger: true
  property color contentForeground: Color.foreground
  property string contentFontFamily: Style.font.family
  property int edgeMargin: Style.space(6)
  property int rowHeight: Style.space(44)

  signal actionClicked()
  signal rowHovered()

  height: rowHeight
  foreground: contentForeground
  fill: Style.hoverFillFor(contentForeground, Color.accent, Color.urgent)
  // Outline-free cursor so we don't double up with the light chip language.
  bordered: false

  readonly property color actionNormalFill: Style.normalFillFor(contentForeground, Color.accent, Color.urgent)
  readonly property color actionHoverFill: danger
    ? Util.alpha(Color.urgent, Style.hoverFillAlpha)
    : Style.hoverFillFor(contentForeground, Color.accent, Color.urgent)

  // Hover only — clicks stay on the action button (and keyboard Enter).
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onContainsMouseChanged: if (containsMouse) root.rowHovered()
  }

  Column {
    id: infoCol
    anchors.left: parent.left
    anchors.leftMargin: root.edgeMargin
    anchors.right: actionBtn.left
    anchors.rightMargin: root.edgeMargin
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)
    z: 1

    Text {
      width: infoCol.width
      elide: Text.ElideRight
      visible: root.title !== ""
      text: root.title
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
    Text {
      width: infoCol.width
      elide: Text.ElideRight
      visible: root.subtitle !== ""
      text: root.subtitle
      color: Qt.darker(root.contentForeground, 1.5)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Rectangle {
    id: actionBtn
    anchors.right: parent.right
    anchors.rightMargin: root.edgeMargin
    anchors.verticalCenter: parent.verticalCenter
    z: 2
    visible: root.actionVisible && root.actionLabel !== ""
    width: Style.space(72)
    height: Style.space(26)
    radius: Style.cornerRadius
    opacity: root.actionEnabled ? 1.0 : 0.45
    color: actionMouse.containsMouse && root.actionEnabled ? root.actionHoverFill : root.actionNormalFill

    Text {
      anchors.centerIn: parent
      text: root.actionLabel
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.caption
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
