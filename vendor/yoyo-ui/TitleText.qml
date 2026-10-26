import QtQuick

// Row title: primary colour, body size, bold, one plain-text line that
// elides. The same look as ActionRow's title; override any font / colour.
Text {
  elide: Text.ElideRight
  textFormat: Text.PlainText
  color: Theme.fg
  font.family: Theme.fontFamily
  font.pixelSize: Theme.body
  font.bold: true
}
