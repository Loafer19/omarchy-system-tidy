import QtQuick
import qs.Commons

// Fill-only tab / filter chips. Keyboard cursor via cursorIndex (not
// containsMouse); chips: [{ key, label }].
Row {
  id: root

  property var chips: []
  property string selectedKey: ""
  property bool compact: false
  property color foreground: Theme.fg
  property string fontFamily: Theme.fontFamily
  property int cursorIndex: -1
  property bool cursorActive: false

  signal selected(string key)
  signal chipHovered(int index)

  spacing: compact ? Style.space(6) : Style.space(4)

  readonly property color selectedFill: Style.selectedFillFor(foreground, Theme.accent, Theme.urgent)
  readonly property color hoverFill: Style.hoverFillFor(foreground, Theme.accent, Theme.urgent)
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
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) root.chipHovered(index)
        onClicked: root.selected(String(modelData.key))
      }
    }
  }
}
