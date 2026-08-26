import QtQuick
import qs.Commons

// Title + optional subtitle with a right-edge text action (Remove/Clean/…).
// Fill-only hover like ChipRow — stock Button would also paint a hover border.
Item {
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

  height: rowHeight

  readonly property color normalFill: Style.normalFillFor(contentForeground, Color.accent, Color.urgent)
  readonly property color hoverFill: danger
    ? Util.alpha(Color.urgent, Style.hoverFillAlpha)
    : Style.hoverFillFor(contentForeground, Color.accent, Color.urgent)

  Column {
    id: infoCol
    anchors.left: parent.left
    anchors.leftMargin: root.edgeMargin
    anchors.right: actionBtn.left
    anchors.rightMargin: root.edgeMargin
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

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
    visible: root.actionVisible && root.actionLabel !== ""
    width: Style.space(72)
    height: Style.space(26)
    radius: Style.cornerRadius
    opacity: root.actionEnabled ? 1.0 : 0.45
    color: actionMouse.containsMouse && root.actionEnabled ? root.hoverFill : root.normalFill

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
      onClicked: root.actionClicked()
    }
  }
}
