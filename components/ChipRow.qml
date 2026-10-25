import QtQuick
import qs.Commons
import "../theme"

// Fill-only chips; cursor via cursorIndex (not containsMouse).
Row {
  id: root

  property var chips: []
  property string selectedKey: ""
  property bool compact: false
  property int cursorIndex: -1
  property bool cursorActive: false

  signal selected(string key)
  signal chipHovered(int index)

  spacing: compact ? Style.space(6) : Style.space(4)

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
      color: hasCursor ? Theme.hoverFill : (isSelected ? Theme.selectedFill : "transparent")
      border.width: isSelected || hasCursor ? 0 : Style.spacing.hairline
      border.color: Theme.line

      Text {
        id: label
        anchors.centerIn: parent
        text: modelData.label
        color: isSelected || hasCursor ? Theme.fg : Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: root.compact ? Theme.caption : Theme.body
        font.bold: !root.compact && isSelected
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) root.chipHovered(index)
        onClicked: root.selected(String(modelData.key))
      }
    }
  }
}
