import QtQuick
import qs.Commons

// Footer hints: [["Tab", "tabs"], ["j k", "rows"], ["Enter", "open"]].
Row {
  id: root

  property var hints: []
  property string fontFamily: Theme.fontFamily

  spacing: Style.space(10)

  Repeater {
    model: root.hints
    Row {
      required property var modelData
      spacing: Style.space(4)
      Text {
        text: modelData[0]
        color: Theme.dim
        font.family: root.fontFamily
        font.pixelSize: Theme.caption
        font.bold: true
      }
      Text {
        text: modelData[1]
        color: Theme.faint
        font.family: root.fontFamily
        font.pixelSize: Theme.caption
      }
    }
  }
}
