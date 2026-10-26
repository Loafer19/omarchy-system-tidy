import QtQuick
import "../vendor/yoyo-ui"

// One list row: an ActionRow with a button on the right, armed through the
// panel's shared ConfirmController. Clicks and hovers are only reported
// (the panel runs the same code path as Enter).
ActionRow {
  id: row

  required property var modelData
  required property int index
  // Row index that has the keyboard cursor in this list, -1 for none.
  property int cursorIndex: -1
  property bool busy: false

  signal hoveredRow(int index)
  signal actionRequested(int index, var item)

  width: ListView.view ? ListView.view.width : implicitWidth
  actionStyle: "button"
  disarmOnLeave: false
  activateOnClick: false
  hasCursor: row.index === row.cursorIndex
  actionEnabled: !row.busy
  danger: true
  onRowHovered: row.hoveredRow(row.index)
  onActionClicked: row.actionRequested(row.index, row.modelData)
}
