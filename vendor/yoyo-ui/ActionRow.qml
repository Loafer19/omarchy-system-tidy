import QtQuick
import qs.Commons
import qs.Ui

// Title + subtitle, an optional badge and one action on the right.
//
// actionStyle "chip": a HeaderChip (lit while the row has the cursor).
// actionStyle "button": a fixed-width button (actionWidth, default 72),
//   urgent hover when danger, row tinted urgent while armed.
//
// confirm: true makes the action two-step. activate() (click, or call it on
// Enter) arms the row, a second activate() emits triggered(). Arming lives in
// a ConfirmController: the row's own one (armMs, default 3 s) or a shared
// one you pass as `controller` with a stable `confirmKey` per row (one armed
// row per panel, survives ListView reloads; disarm it on Esc / cursor moves).
// While armed the subtitle shows armedText (urgent) and the action confirmText.
// `armed` can also be bound from outside if you run the confirm yourself.
CursorSurface {
  id: root

  property string title: ""
  property string subtitle: ""
  property string actionLabel: ""
  property string actionStyle: "chip"
  property int actionWidth: Style.space(72)
  property bool actionVisible: true
  property bool actionEnabled: true
  // Button style: urgent hover tint instead of the neutral one.
  property bool danger: false

  // Small pill before the action ("system", "irreversible").
  property string badge: ""
  // "normal" (neutral), "warn" (urgent tint) or "danger" (solid urgent)
  property string badgeVariant: "normal"

  property bool confirm: false
  property int armMs: 3000
  property ConfirmController controller: ownConfirm
  property string confirmKey: ""
  readonly property string effectiveKey: root.confirmKey !== "" ? root.confirmKey : "row"
  property bool armed: root.controller !== null && root.controller.isArmed(root.effectiveKey)
  property string armedText: ""
  property bool armedTint: root.actionStyle === "button"
  property string confirmText: "Confirm"
  property string confirmTooltip: root.actionStyle === "chip" ? "Click again to confirm" : ""
  // Leaving the row (hasCursor false) disarms it.
  property bool disarmOnLeave: true
  // false: a click only emits actionClicked(); route it yourself (e.g. the
  // same panel function Enter uses) and arm via the shared controller.
  property bool activateOnClick: true

  // After triggering, the action shows doneText (if set) for doneMs.
  property string doneText: ""
  property int doneMs: 1500
  property bool done: false

  readonly property bool actionShown: root.actionVisible && root.actionLabel !== ""
  readonly property Item actionItem: root.actionStyle === "button" ? buttonAction : chipAction
  readonly property string actionText: root.armed ? root.confirmText
    : (root.done && root.doneText !== "" ? root.doneText : root.actionLabel)

  signal rowHovered()
  // Every click on the action (before the confirm logic runs).
  signal actionClicked()
  signal triggered()

  implicitHeight: Theme.rowHeight
  height: implicitHeight
  foreground: Theme.fg
  fill: root.armed && root.armedTint ? Theme.tint(Theme.urgent, 0.10) : Theme.hoverFill
  bordered: false
  current: root.armed && root.armedTint
  currentFill: Theme.tint(Theme.urgent, 0.10)

  function activate() {
    if (!root.actionShown || !root.actionEnabled) return
    if (root.confirm) {
      if (!root.controller || !root.controller.confirm(root.effectiveKey)) return
    } else if (root.controller) {
      root.controller.disarm()
    }
    root.triggered()
    root.done = true
    doneTimer.restart()
  }
  function disarm() { if (root.controller && root.controller.isArmed(root.effectiveKey)) root.controller.disarm() }

  ConfirmController { id: ownConfirm; timeout: root.armMs }
  Timer { id: doneTimer; interval: root.doneMs; onTriggered: root.done = false }
  onHasCursorChanged: if (!hasCursor && root.disarmOnLeave) root.disarm()

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onContainsMouseChanged: if (containsMouse) root.rowHovered()
  }

  Column {
    id: infoCol
    anchors.left: parent.left
    anchors.leftMargin: Theme.edge
    anchors.right: badgePill.visible ? badgePill.left : (root.actionShown ? root.actionItem.left : parent.right)
    anchors.rightMargin: root.actionStyle === "chip" ? Theme.gap : Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)
    z: 1

    Text {
      width: infoCol.width
      elide: Text.ElideRight
      textFormat: Text.PlainText
      visible: text !== ""
      text: root.title
      color: Theme.fg
      font.family: Theme.fontFamily
      font.pixelSize: Theme.body
      font.bold: true
    }
    Text {
      readonly property bool showArmed: root.armed && root.armedText !== ""
      width: infoCol.width
      elide: Text.ElideRight
      textFormat: Text.PlainText
      visible: text !== ""
      text: showArmed ? root.armedText : root.subtitle
      color: showArmed || (root.armed && root.armedTint) ? Theme.urgent : Theme.dim
      font.family: Theme.fontFamily
      font.pixelSize: Theme.caption
    }
  }

  Rectangle {
    id: badgePill
    anchors.right: root.actionShown ? root.actionItem.left : parent.right
    anchors.rightMargin: Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    z: 2
    visible: root.badge !== ""
    width: badgeText.implicitWidth + Style.space(12)
    height: Style.space(18)
    radius: height / 2
    color: root.badgeVariant === "warn" ? Theme.tint(Theme.urgent, 0.14)
      : root.badgeVariant === "danger" ? Theme.urgent
      : Theme.normalFill

    Text {
      id: badgeText
      anchors.centerIn: parent
      text: root.badge
      textFormat: Text.PlainText
      color: root.badgeVariant === "warn" ? Theme.urgent
        : root.badgeVariant === "danger" ? Theme.background
        : Theme.dim
      font.family: Theme.fontFamily
      font.pixelSize: Theme.caption
    }
  }

  HeaderChip {
    id: chipAction
    anchors.right: parent.right
    anchors.rightMargin: Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    z: 2
    visible: root.actionStyle !== "button" && root.actionShown
    enabled: root.actionEnabled
    text: root.actionText
    on: root.armed || root.hasCursor
    danger: root.armed
    tooltipText: root.armed ? root.confirmTooltip : ""
    onClicked: { root.actionClicked(); if (root.activateOnClick) root.activate() }
  }

  Rectangle {
    id: buttonAction
    anchors.right: parent.right
    anchors.rightMargin: Theme.edge
    anchors.verticalCenter: parent.verticalCenter
    z: 2
    visible: root.actionStyle === "button" && root.actionShown
    width: root.actionWidth
    height: Style.space(26)
    radius: Style.cornerRadius
    opacity: root.actionEnabled ? 1.0 : 0.45
    color: root.armed ? Theme.urgent
      : buttonMouse.containsMouse && root.actionEnabled
      ? (root.danger ? Theme.tint(Theme.urgent, Style.hoverFillAlpha) : Theme.hoverFill)
      : Theme.normalFill

    Text {
      anchors.centerIn: parent
      text: root.actionText
      color: root.armed ? Theme.background : Theme.fg
      font.bold: root.armed
      font.family: Theme.fontFamily
      font.pixelSize: Theme.caption
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      enabled: root.actionEnabled
      hoverEnabled: true
      cursorShape: root.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onContainsMouseChanged: if (containsMouse) root.rowHovered()
      onClicked: { root.actionClicked(); if (root.activateOnClick) root.activate() }
    }
  }
}
