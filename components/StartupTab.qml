pragma ComponentBehavior: Bound
import QtQuick
import "../Rows.js" as Rows

// Startup: autostart entries and user systemd units. Disable asks first
// (with a specific warning for keyrings, input methods, …); Enable doesn't.
TidyTab {
  id: tab

  readonly property var empty: Rows.emptyText("startup", tab.filter)

  chips: Rows.chipsForTab("startup")
  emptyText: tab.empty.title
  emptySubtitle: tab.empty.subtitle

  delegate: TidyRow {
    readonly property bool isEnabled: modelData.status === "enabled"
    controller: tab.controller
    cursorIndex: tab.cursorRow
    busy: tab.busy
    title: modelData.name
    subtitle: Rows.startupSubtitle(modelData)
    actionLabel: isEnabled ? "Disable" : "Enable"
    danger: isEnabled
    badge: modelData.origin === "system" ? "system" : ""
    badgeVariant: isEnabled && modelData.warning !== "" ? "warn" : "normal"
    confirmKey: Rows.rowKey("startup", tab.filter, modelData)
    armedText: Rows.startupArmedText(modelData)
    onHoveredRow: function(index) { tab.rowHovered(index) }
    onActionRequested: function(index, item) { tab.rowActivated(index, item) }
  }
}
