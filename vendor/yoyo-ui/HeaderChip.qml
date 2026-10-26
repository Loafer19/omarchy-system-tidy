import QtQuick
import qs.Commons
import qs.Ui

// Small action chip. on = filled with accent (urgent when danger).
// Disable it with the regular Item `enabled` (opacity 0.4, no clicks).
//
// confirm: true makes it two-step: the first click arms it ("Confirm?",
// urgent fill), the second emits triggered(). It disarms after armMs, when
// disabled, or when you call disarm() (do that on Esc / tab change).
// Pass a shared ConfirmController + confirmKey to coordinate with rows.
Rectangle {
  id: root

  property string text: ""
  property string tooltipText: ""
  property bool on: false
  // When on+danger, fill with urgent (destructive confirms like Remove).
  property bool danger: false
  property color foreground: Theme.fg
  property string fontFamily: Theme.fontFamily

  property bool confirm: false
  property string confirmText: "Confirm?"
  // Tooltip while armed; falls back to tooltipText when empty.
  property string confirmTooltip: ""
  property int armMs: 4000
  property ConfirmController controller: ownConfirm
  property string confirmKey: ""
  readonly property string effectiveKey: root.confirmKey !== "" ? root.confirmKey : "chip"
  readonly property bool armed: root.confirm && root.controller !== null && root.controller.isArmed(root.effectiveKey)

  readonly property bool lit: root.on || root.armed
  readonly property color activeFill: root.danger || root.armed ? Theme.urgent : Theme.accent
  readonly property color idleFill: Style.normalFillFor(root.foreground, Theme.accent, Theme.urgent)
  readonly property color hoverFill: Style.hoverFillFor(root.foreground, Theme.accent, Theme.urgent)
  readonly property bool hovered: chipMouse.containsMouse

  // Every click; with confirm, triggered() only on the confirming one.
  signal clicked()
  signal triggered()

  function activate() {
    if (!root.enabled) return
    root.clicked()
    if (!root.confirm) { root.triggered(); return }
    if (root.controller && root.controller.confirm(root.effectiveKey)) root.triggered()
  }
  function disarm() { if (root.armed) root.controller.disarm() }

  onEnabledChanged: if (!enabled) root.disarm()

  ConfirmController { id: ownConfirm; timeout: root.armMs }

  width: label.implicitWidth + Style.space(16)
  height: Style.space(24)
  radius: Style.cornerRadius
  opacity: root.enabled ? 1 : 0.4
  color: {
    if (!root.enabled) return root.idleFill
    if (root.lit) return chipMouse.containsMouse ? Qt.darker(root.activeFill, 1.08) : root.activeFill
    return chipMouse.containsMouse ? root.hoverFill : root.idleFill
  }
  border.width: Theme.hairline
  border.color: root.lit && root.enabled ? root.activeFill : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

  Text {
    id: label
    anchors.centerIn: parent
    text: root.armed ? root.confirmText : root.text
    color: root.lit && root.enabled ? Theme.background : root.foreground
    font.family: root.fontFamily
    font.pixelSize: Theme.caption
    font.bold: true
  }

  MouseArea {
    id: chipMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.activate()
  }

  PanelToolTip {
    readonly property string tip: root.armed && root.confirmTooltip !== "" ? root.confirmTooltip : root.tooltipText
    visible: tip !== "" && chipMouse.containsMouse
    text: tip
    fontFamily: root.fontFamily
  }
}
