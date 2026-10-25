import QtQuick
import qs.Commons
import "../theme"

// Footer: "Tab tabs · h l filters · j k rows · Enter act · Esc close".
Row {
  id: root

  property var hints: []

  spacing: Style.space(10)

  Repeater {
    model: root.hints
    Row {
      id: hint
      required property var modelData
      spacing: Style.space(4)
      Text {
        text: hint.modelData[0]
        color: Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.caption
        font.bold: true
      }
      Text {
        text: hint.modelData[1]
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.caption
      }
    }
  }
}
