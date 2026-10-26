pragma ComponentBehavior: Bound
import QtQuick
import "../Rows.js" as Rows

// Launchers: Web App and TUI .desktop launchers (remove deletes the
// launcher and its icon).
TidyTab {
  id: tab

  readonly property var empty: Rows.emptyText("launchers", tab.filter)

  chips: Rows.chipsForTab("launchers")
  emptyText: tab.empty.title
  emptySubtitle: tab.empty.subtitle

  delegate: TidyRow {
    controller: tab.controller
    cursorIndex: tab.cursorRow
    busy: tab.busy
    title: modelData.name
    actionLabel: "Remove"
    confirmKey: Rows.rowKey("launchers", tab.filter, modelData)
    armedText: Rows.confirmHint("Deletes the launcher and its icon")
    onHoveredRow: function(index) { tab.rowHovered(index) }
    onActionRequested: function(index, item) { tab.rowActivated(index, item) }
  }
}
