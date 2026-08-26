import QtQuick
import qs.Commons

// Lightweight selection chips: fill-only selected/cursor (no hover-border).
// Cursor highlight comes from cursorIndex (panel j/k/h/l + mouse), not raw
// containsMouse alone — same single-highlight contract as CursorSurface rows.
Row {
  id: root

  property var chips: []
  property string selectedKey: ""
  property bool compact: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  // -1 = no keyboard/mouse cursor on this row
  property int cursorIndex: -1
  property bool cursorActive: false

  signal selected(string key)
  signal chipHovered(int index)

  spacing: compact ? Style.space(6) : Style.space(4)

  readonly property color selectedFill: Style.selectedFillFor(foreground, Color.accent, Color.urgent)
  readonly property color hoverFill: Style.hoverFillFor(foreground, Color.accent, Color.urgent)
  readonly property color idleBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  Repeater {
    model: root.chips

    Rectangle {
      required property var modelData
      required property int index
      readonly property bool isSelected: String(modelData.key) === root.selectedKey
      readonly property bool hasCursor: root.cursorActive && root.cursorIndex === index

      width: label.implicitWidth + (root.compact ? Style.space(16) : Style.space(20))
      height: root.compact ? Style.space(24) : Style.space(28)
      radius: Style.cornerRadius
      // Cursor wins over selected fill while navigating, matching CursorSurface.
      color: hasCursor ? root.hoverFill
        : (isSelected ? root.selectedFill : "transparent")
      border.width: isSelected || hasCursor ? 0 : Style.spacing.hairline
      border.color: root.idleBorder

      Text {
        id: label
        anchors.centerIn: parent
        text: modelData.label
        color: isSelected || hasCursor ? root.foreground : Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: root.compact ? Style.font.caption : Style.font.body
        font.bold: !root.compact && isSelected
      }

      MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) root.chipHovered(index)
        onClicked: root.selected(String(modelData.key))
      }
    }
  }
}
