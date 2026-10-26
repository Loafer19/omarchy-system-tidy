import QtQuick
import "../vendor/yoyo-ui"

// A tab body (TabList) plus what every tab's rows need from the panel. Only
// the tab whose key is activeTab is visible and gets the cursor.
TabList {
  id: tab

  required property string tabKey
  property string activeTab: ""
  property string filter: ""
  property bool busy: false
  property ConfirmController controller: null
  // Cursor row / chip of the active tab, -1 when the cursor is elsewhere.
  property int activeCursorRow: -1
  property int activeChipCursor: -1

  readonly property bool active: tab.activeTab === tab.tabKey
  readonly property int cursorRow: tab.active ? tab.activeCursorRow : -1

  signal rowHovered(int index)
  signal rowActivated(int index, var item)

  visible: tab.active
  selectedKey: tab.filter
  chipCursorActive: tab.active && tab.activeChipCursor >= 0
  chipCursorIndex: tab.chipCursorActive ? tab.activeChipCursor : -1
}
