import QtQuick
import qs.Commons

// Lightweight selection chips: fill-only hover/selected (no hover-border).
// Stock Button/ButtonGroup always paints hover fill + hover border together;
// that reads as a double effect on dense tab rows, so we keep this simpler.
Row {
  id: root

  property var chips: []
  property string selectedKey: ""
  property bool compact: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal selected(string key)

  spacing: compact ? Style.space(6) : Style.space(4)

  readonly property color selectedFill: Style.selectedFillFor(foreground, Color.accent, Color.urgent)
  readonly property color hoverFill: Style.hoverFillFor(foreground, Color.accent, Color.urgent)
  readonly property color idleBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  Repeater {
    model: root.chips

    Rectangle {
      required property var modelData
      readonly property bool isSelected: String(modelData.key) === root.selectedKey

      width: label.implicitWidth + (root.compact ? Style.space(16) : Style.space(20))
      height: root.compact ? Style.space(24) : Style.space(28)
      radius: Style.cornerRadius
      color: isSelected ? root.selectedFill
        : (chipMouse.containsMouse ? root.hoverFill : "transparent")
      // Idle outline only; selected/hover are fill-only (no second border effect).
      border.width: isSelected ? 0 : Style.spacing.hairline
      border.color: root.idleBorder

      Text {
        id: label
        anchors.centerIn: parent
        text: modelData.label
        color: isSelected ? root.foreground : Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: root.compact ? Style.font.caption : Style.font.body
        font.bold: !root.compact && isSelected
      }

      MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selected(String(modelData.key))
      }
    }
  }
}
