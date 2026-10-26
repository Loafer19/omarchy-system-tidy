pragma ComponentBehavior: Bound
import QtQuick
import "../Rows.js" as Rows

// Packages: Extra / Orphans (pacman -Rns after a snapshot), Pacnew files
// and agent CLIs. Protected system packages show a badge and no button.
TidyTab {
  id: tab

  readonly property var empty: Rows.emptyText("packages", tab.filter)

  chips: Rows.chipsForTab("packages")
  emptyText: tab.empty.title
  emptySubtitle: tab.empty.subtitle

  delegate: TidyRow {
    readonly property bool isProtected: Rows.packageIsProtected(tab.filter, modelData)
    controller: tab.controller
    cursorIndex: tab.cursorRow
    busy: tab.busy
    title: modelData.name
    subtitle: Rows.packageSubtitle(tab.filter, modelData)
    actionLabel: "Remove"
    actionVisible: !isProtected
    badge: isProtected ? "protected" : ""
    confirmKey: Rows.rowKey("packages", tab.filter, modelData)
    armedText: Rows.packageArmedText(tab.filter, modelData)
    onHoveredRow: function(index) { tab.rowHovered(index) }
    onActionRequested: function(index, item) { tab.rowActivated(index, item) }
  }
}
