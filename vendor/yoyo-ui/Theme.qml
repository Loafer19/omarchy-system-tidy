pragma Singleton

import QtQuick
import qs.Commons
import qs.Commons as Commons

// Colour roles, type sizes and row metrics for an Omarchy plugin panel.
// Everything is derived from qs.Commons (Color + Style): no custom colours.
// The plugin's Panel.qml binds foreground / fontFamily to the bar it opens
// from (see README). Each vendored copy is its own singleton instance.
QtObject {
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  // Text roles: primary, secondary (subtitles, idle chips), faint (hints, empty values).
  readonly property color fg: foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.8)
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: Commons.Color.urgent
  readonly property color background: Commons.Color.background
  readonly property color line: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  readonly property color hoverFill: Style.hoverFillFor(foreground, Commons.Color.accent, Commons.Color.urgent)
  readonly property color normalFill: Style.normalFillFor(foreground, Commons.Color.accent, Commons.Color.urgent)
  readonly property color selectedFill: Style.selectedFillFor(foreground, Commons.Color.accent, Commons.Color.urgent)

  function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  // Edges and gaps shared by Throttle / System Tidy / Notification Center.
  readonly property int edge: Style.spacing.md
  readonly property int gap: Style.spacing.lg
  // Rows: settings-like rows, compact data rows, small rows.
  readonly property int rowHeight: Style.space(44)
  readonly property int dataRowHeight: Style.space(36)
  readonly property int smallRowHeight: Style.space(28)

  readonly property int caption: Style.font.caption
  readonly property int body: Style.font.body
  readonly property int title: Style.font.title
  readonly property int heading: Style.font.heading
}
