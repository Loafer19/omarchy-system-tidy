import QtQuick
import qs.Commons
import "../theme"

// One look for every "nothing here yet" (lists, ranges, measuring).
Column {
  id: root

  property string title: ""
  property string subtitle: ""

  topPadding: Style.space(24)
  bottomPadding: Style.space(16)
  spacing: Style.space(4)

  Text {
    width: root.width
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: root.title
    color: Theme.dim
    font.family: Theme.fontFamily
    font.pixelSize: Theme.body
  }
  Text {
    width: root.width
    visible: root.subtitle !== ""
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: root.subtitle
    color: Theme.faint
    font.family: Theme.fontFamily
    font.pixelSize: Theme.caption
  }
}
