import QtQuick
import qs.Commons

// One look for every "nothing here yet" (lists, ranges, measuring).
Column {
  id: root

  property string title: ""
  property string subtitle: ""
  property string fontFamily: Theme.fontFamily

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
    font.family: root.fontFamily
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
    font.family: root.fontFamily
    font.pixelSize: Theme.caption
  }
}
