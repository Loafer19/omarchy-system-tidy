import QtQuick
import qs.Commons

// One look for every "nothing here yet" (lists, ranges, measuring).
//
// Default: both lines fill the width and centre with AlignHCenter.
// fitContent: each line is only as wide as its text (capped at the width, so
// it still wraps) and centred with an anchor, which rounds to whole pixels
// exactly like `Text { anchors.centerIn: parent }` does.
// Spacing around it: topPadding / bottomPadding / spacing (regular Column
// properties; 0/0 for a message centred in a list with anchors.centerIn).
Column {
  id: root

  property string title: ""
  property string subtitle: ""
  property string fontFamily: Theme.fontFamily
  property bool fitContent: false

  topPadding: Style.space(24)
  bottomPadding: Style.space(16)
  spacing: Style.space(4)

  Text {
    width: root.fitContent ? Math.min(implicitWidth, root.width) : root.width
    anchors.horizontalCenter: root.fitContent ? parent.horizontalCenter : undefined
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: root.title
    color: Theme.dim
    font.family: root.fontFamily
    font.pixelSize: Theme.body
  }
  Text {
    width: root.fitContent ? Math.min(implicitWidth, root.width) : root.width
    anchors.horizontalCenter: root.fitContent ? parent.horizontalCenter : undefined
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
