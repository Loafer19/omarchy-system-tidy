import QtQuick

// Subtitle / caption: secondary colour, caption size, one plain-text line
// that elides. The same look as ActionRow's subtitle.
Text {
  elide: Text.ElideRight
  textFormat: Text.PlainText
  color: Theme.dim
  font.family: Theme.fontFamily
  font.pixelSize: Theme.caption
}
