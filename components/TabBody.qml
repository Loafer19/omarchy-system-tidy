import QtQuick
import "../vendor/yoyo-ui"

// The four tab bodies, stacked; only the active one is visible. Row and chip
// events are forwarded to the panel, which owns the cursor.
Item {
  id: body

  required property Backend lists
  property ConfirmController controller: null
  property string activeTab: "packages"
  property string packagesFilter: ""
  property string startupFilter: ""
  property string launchersFilter: ""
  property var startupItems: []
  property var launchersItems: []
  property bool busy: false
  // Cursor row / chip in the active tab, -1 when the cursor is elsewhere.
  property int cursorRow: -1
  property int chipCursorIndex: -1

  readonly property var tabItems: [packagesTab, cleanupTab, startupTab, launchersTab]
  readonly property ListView activeView: {
    for (var i = 0; i < body.tabItems.length; i++) {
      if (body.tabItems[i].active) return body.tabItems[i].view
    }
    return null
  }

  signal rowHovered(int index)
  signal rowActivated(int index, var item)
  signal chipSelected(string key)
  signal chipHovered(int index)

  Component.onCompleted: {
    for (var i = 0; i < body.tabItems.length; i++) {
      var tab = body.tabItems[i]
      tab.rowHovered.connect(body.rowHovered)
      tab.rowActivated.connect(body.rowActivated)
      tab.chipSelected.connect(body.chipSelected)
      tab.chipHovered.connect(body.chipHovered)
    }
  }

  PackagesTab {
    id: packagesTab
    anchors.fill: parent
    tabKey: "packages"
    activeTab: body.activeTab
    activeCursorRow: body.cursorRow
    activeChipCursor: body.chipCursorIndex
    controller: body.controller
    busy: body.busy
    filter: body.packagesFilter
    model: body.lists.packagesFor(body.packagesFilter)
    loading: body.lists.packagesLoadingFor(body.packagesFilter)
  }

  LaunchersTab {
    id: launchersTab
    anchors.fill: parent
    tabKey: "launchers"
    activeTab: body.activeTab
    activeCursorRow: body.cursorRow
    activeChipCursor: body.chipCursorIndex
    controller: body.controller
    busy: body.busy
    filter: body.launchersFilter
    model: body.launchersItems
    loading: body.lists.launchersLoadingFor(body.launchersFilter)
  }

  StartupTab {
    id: startupTab
    anchors.fill: parent
    tabKey: "startup"
    activeTab: body.activeTab
    activeCursorRow: body.cursorRow
    activeChipCursor: body.chipCursorIndex
    controller: body.controller
    busy: body.busy
    filter: body.startupFilter
    model: body.startupItems
    loading: body.lists.startupLoadingFor(body.startupFilter)
  }

  CleanupTab {
    id: cleanupTab
    anchors.fill: parent
    tabKey: "cleanup"
    activeTab: body.activeTab
    activeCursorRow: body.cursorRow
    controller: body.controller
    busy: body.busy
    loaded: body.lists.cleanupLoaded
    status: body.lists.cleanupStatus
  }
}
