pragma ComponentBehavior: Bound
import QtQuick
import "../Rows.js" as Rows

// Cleanup: one row per cache with what Clean would free; nothing to free
// (or still measuring) disables the button.
TidyTab {
  id: tab

  property bool loaded: false
  property var status: ({})

  model: Rows.CLEANUP_ROWS

  delegate: TidyRow {
    controller: tab.controller
    cursorIndex: tab.cursorRow
    busy: tab.busy
    title: modelData.label
    subtitle: Rows.cleanupSubtitle(modelData, tab.loaded, tab.status)
    actionLabel: "Clean"
    badge: modelData.irreversible ? "irreversible" : ""
    badgeVariant: "warn"
    actionEnabled: !tab.busy && tab.loaded && Rows.cleanupMb(tab.status, modelData.key) > 0
    confirmKey: Rows.rowKey("cleanup", tab.filter, modelData)
    armedText: Rows.cleanupArmedText(modelData)
    onHoveredRow: function(index) { tab.rowHovered(index) }
    onActionRequested: function(index, item) { tab.rowActivated(index, item) }
  }
}
