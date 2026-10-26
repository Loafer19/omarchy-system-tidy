import QtQuick

// Drop into a row to make the mouse follow the keyboard cursor: it fills
// the parent, and hovering emits hovered(rowIndex) so the panel can move its
// cursor there (no containsMouse styling; the cursor index drives the look).
// clickable rows also take left clicks (onClicked) and show a pointing hand;
// pointer: false keeps the arrow on a clickable row.
//
//   RowHover { rowIndex: index; onHovered: (i) => panel.setRowCursor(i) }
//   RowHover { clickable: true; onHovered: root.rowHovered(); onClicked: root.rowClicked() }
MouseArea {
  id: root

  property int rowIndex: -1
  property bool clickable: false
  property bool pointer: clickable

  signal hovered(int rowIndex)

  anchors.fill: parent
  hoverEnabled: true
  acceptedButtons: root.clickable ? Qt.LeftButton : Qt.NoButton
  cursorShape: root.pointer ? Qt.PointingHandCursor : Qt.ArrowCursor
  onContainsMouseChanged: if (root.containsMouse) root.hovered(root.rowIndex)
}
