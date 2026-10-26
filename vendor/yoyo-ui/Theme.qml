pragma Singleton

import QtQuick
import qs.Commons
import qs.Commons as Commons

// Colour roles, type sizes and row metrics for an Omarchy plugin panel.
// Everything is derived from qs.Commons (Color + Style): no custom colours.
// The plugin's Panel.qml binds foreground / fontFamily to the bar it opens
// from (see README). Each vendored copy is its own singleton instance.
//
// Every token is a typed property, so qmllint can check `Theme.x` in plugin
// code. Style.spacing / Style.font are plain QtObjects to qmllint, which is
// why the reads below carry `qmllint disable missing-property`: this file is
// the one place that needs it.
QtObject {
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family // qmllint disable missing-property

  function tint(c: color, a: real): color { return Qt.rgba(c.r, c.g, c.b, a) }

  // Text roles: primary, secondary (subtitles, idle chips), faint (hints, empty values).
  readonly property color fg: foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.8)
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: Commons.Color.urgent
  readonly property color background: Commons.Color.background
  readonly property color line: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  // Fainter rule between a list and its footer (StatusFooter.separator).
  readonly property color separator: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  // Idle fill of small icon / text buttons (hover uses hoverFill).
  readonly property color buttonFill: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.06)
  readonly property color hoverFill: Style.hoverFillFor(foreground, Commons.Color.accent, Commons.Color.urgent)
  readonly property color normalFill: Style.normalFillFor(foreground, Commons.Color.accent, Commons.Color.urgent)
  readonly property color selectedFill: Style.selectedFillFor(foreground, Commons.Color.accent, Commons.Color.urgent)

  // Edges and gaps shared by Throttle / System Tidy / Notification Center.
  readonly property int edge: Style.spacing.md // qmllint disable missing-property
  readonly property int gap: Style.spacing.lg // qmllint disable missing-property
  // Divider / border thickness (Style.spacing.hairline, 1 px at default scale).
  readonly property int hairline: Style.spacing.hairline // qmllint disable missing-property
  // Rows: settings-like rows, compact data rows, small rows.
  readonly property int rowHeight: Style.space(44)
  readonly property int dataRowHeight: Style.space(36)
  readonly property int smallRowHeight: Style.space(28)
  // Panel content widths (pass to panel.fittedContentWidth(...)).
  readonly property int panelNarrow: Style.space(480)
  readonly property int panelWidth: Style.space(520)
  readonly property int panelWide: Style.space(560)

  // Type sizes.
  readonly property int caption: Style.font.caption // qmllint disable missing-property
  readonly property int body: Style.font.body // qmllint disable missing-property
  readonly property int title: Style.font.title // qmllint disable missing-property
  readonly property int heading: Style.font.heading // qmllint disable missing-property
  // Icon glyphs (Style.font.icon, title size unless the user overrides it).
  readonly property int icon: Style.font.icon // qmllint disable missing-property
  readonly property int iconSmall: Style.font.iconSmall // qmllint disable missing-property
}
