import qs.Commons as Commons
import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Nav.js" as Nav
import "Rows.js" as Rows
import "components" as Tidy
import "vendor/yoyo-ui"

// The floating panel: tab state, the keyboard cursor and the confirm step.
// Lists and the backend live in components/Backend.qml, each tab's rows in
// components/*Tab.qml, texts and rules in Rows.js, cursor moves in Nav.js.
Panel {
  id: root
  moduleName: "yoyo.system-tidy"
  ipcTarget: "yoyo.system-tidy"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property string activeTab: "packages"
  property string packagesFilter: Rows.DEFAULT_FILTERS.packages
  property string startupFilter: Rows.DEFAULT_FILTERS.startup
  property string launchersFilter: Rows.DEFAULT_FILTERS.launchers
  property bool busy: false

  // Two-step confirm: the first Enter/click arms a row (by stable key), the
  // second runs it. Esc, moving the cursor, or 4 s of nothing disarms.
  ConfirmController { id: confirmCtl; timeout: 4000 }
  property alias armedKey: confirmCtl.armedKey
  // Footer status lives in the shared StatusFooter (progress / done / error).
  property alias statusText: footer.statusText
  property alias statusKind: footer.statusKind

  // Cursor sections: "tabs" | "filters" | "rows"
  property bool cursorActive: false
  property string focusSection: "rows"
  property int selectedIndex: 0

  // Panel size before fitting to the screen (same scale as Style.space).
  readonly property int preferredWidth: Style.space(560)
  readonly property int preferredHeight: Style.space(440)

  readonly property var tabs: Rows.TABS
  readonly property var activeFilterChips: Rows.chipsForTab(root.activeTab)
  readonly property var keyHints: Rows.keyHints(root.armedKey !== "", root.activeFilterChips.length > 0)

  readonly property var startupItems: Rows.startupItems(root.startupFilter, backendLists.systemdUnits, backendLists.autostartItems)
  readonly property var launchersItems: Rows.launchersItems(root.launchersFilter, backendLists.tuis, backendLists.webapps)

  readonly property var activeListItems: {
    if (root.activeTab === "packages") return backendLists.packagesFor(root.packagesFilter)
    if (root.activeTab === "cleanup") return Rows.CLEANUP_ROWS
    if (root.activeTab === "startup") return root.startupItems
    if (root.activeTab === "launchers") return root.launchersItems
    return []
  }

  // The bar (and Style.font) are typed QtObject in the shell; read them untyped.
  readonly property var hostBar: root.bar
  readonly property var styleFont: Style.font
  readonly property color contentForeground: hostBar ? hostBar.foreground : Commons.Color.foreground
  readonly property string contentFontFamily: hostBar ? hostBar.fontFamily : root.styleFont.family
  Binding { target: Theme; property: "foreground"; value: root.contentForeground }
  Binding { target: Theme; property: "fontFamily"; value: root.contentFontFamily }

  Tidy.Backend {
    id: backendLists
    onActionFailedWith: function(text) { root.statusText = text; root.statusKind = "error" }
    onActionExited: function(exitCode) {
      root.busy = false
      Qt.callLater(function() {
        // flash() clears it after 2.5 s (done) / 6 s (error).
        if (exitCode === 0) footer.flash(backendLists.lastOut !== "" ? "Done · " + backendLists.lastOut : "Done", "done")
        else footer.flash(root.statusKind === "error" ? root.statusText : "Failed", "error")
      })
      root.refreshActiveTab()
    }
  }

  // ------------------------------------------------------------ cursor

  function navContext() {
    return {
      tabs: root.tabs,
      activeTab: root.activeTab,
      chips: root.activeFilterChips,
      filterKey: root.filterFor(root.activeTab),
      itemCount: root.activeListItems.length
    }
  }

  // Applies a Nav result: section and index first, then the tab or filter
  // switch, then scrolling (same order the handlers below expect).
  function applyCursor(next) {
    if (!next) return
    root.focusSection = next.section
    root.selectedIndex = next.index
    if (next.tab !== undefined) root.activeTab = next.tab
    if (next.filter !== undefined) root.applyFilterKey(next.filter)
    if (next.position) root.positionActiveList()
  }

  // false: the cursor was hidden and has just been shown (the key that
  // showed it does nothing else).
  function ensureCursor() {
    if (root.cursorActive) return true
    root.cursorActive = true
    root.applyCursor(Nav.initialCursor(root.navContext()))
    return false
  }

  function moveCursor(dx, dy) {
    root.disarm()
    if (!root.ensureCursor()) return
    root.applyCursor(Nav.move({ section: root.focusSection, index: root.selectedIndex }, dx, dy, root.navContext()))
  }

  function cycleTab(direction) {
    var i = Nav.cycleIndex(root.tabs, root.activeTab, direction)
    if (i < 0) return
    root.activeTab = root.tabs[i].key
    root.setChipCursor("tabs", i)
  }

  function positionActiveList() {
    if (root.focusSection !== "rows") return
    var view = tabBody.activeView
    if (view && root.selectedIndex >= 0 && root.selectedIndex < view.count)
      view.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function setRowCursor(index) {
    if (root.focusSection !== "rows" || root.selectedIndex !== index) root.disarm()
    root.cursorActive = true
    root.focusSection = "rows"
    root.selectedIndex = index
  }

  // Shows the cursor on a tab chip ("tabs") or filter chip ("filters").
  function setChipCursor(section, index) {
    root.cursorActive = true
    root.focusSection = section
    root.selectedIndex = index
  }

  // ------------------------------------------------------------ actions

  function disarm() { confirmCtl.disarm() }

  function activateCursor() {
    if (!root.ensureCursor()) return
    if (root.busy) return

    if (root.focusSection === "tabs") {
      root.activeTab = root.tabs[root.selectedIndex].key
      return
    }
    if (root.focusSection === "filters") {
      if (root.activeFilterChips.length === 0) return
      root.applyFilterKey(root.activeFilterChips[root.selectedIndex].key)
      return
    }

    var items = root.activeListItems
    if (root.selectedIndex < 0 || root.selectedIndex >= items.length) return
    root.requestRowAction(items[root.selectedIndex])
  }

  function actionContext() {
    return { tab: root.activeTab, packagesFilter: root.packagesFilter, cleanupLoaded: backendLists.cleanupLoaded, cleanupStatus: backendLists.cleanupStatus }
  }

  function requestRowAction(item) {
    var ctx = root.actionContext()
    if (!Rows.rowActionAvailable(ctx, item)) return
    if (Rows.runsWithoutConfirm(ctx, item)) {
      root.disarm()
      root.runCommand(Rows.startupEnableAction(item))
      return
    }
    var key = Rows.rowKey(root.activeTab, root.packagesFilter, item)
    if (root.busy || key === "") return
    // Returns true when the row was already armed: run it now.
    if (!confirmCtl.confirm(key)) return
    root.runCommand(Rows.rowAction(ctx, item))
  }

  function runCommand(action) {
    if (action) root.runAction(action.args, action.message)
  }

  function runAction(args, message) {
    if (root.busy) return
    root.busy = true
    footer.flash(message, "progress")
    backendLists.run(args)
  }

  // ------------------------------------------------------------ tabs & filters

  function filterFor(tab) {
    if (tab === "packages") return root.packagesFilter
    if (tab === "startup") return root.startupFilter
    if (tab === "launchers") return root.launchersFilter
    return ""
  }

  // Switches the active tab's filter (tabs without chips have none). Only
  // Packages loads per filter; the other tabs load both lists up front.
  function applyFilterKey(key) {
    var tab = root.activeTab
    if (Rows.chipsForTab(tab).length === 0) return
    root.disarm()
    if (root.filterFor(tab) === key) return
    if (tab === "packages") root.packagesFilter = key
    else if (tab === "startup") root.startupFilter = key
    else root.launchersFilter = key
    if (root.focusSection === "rows") root.selectedIndex = 0
    if (tab === "packages") backendLists.refreshPackages(key)
  }

  // A chip click: switch the filter and put the cursor on that chip.
  function selectFilter(key) {
    root.applyFilterKey(key)
    root.setChipCursor("filters", Nav.indexOfKey(root.activeFilterChips, key))
  }

  function refreshActiveTab() {
    if (root.activeTab === "packages") backendLists.refreshPackages(root.packagesFilter)
    else if (root.activeTab === "launchers") backendLists.refreshLaunchers()
    else if (root.activeTab === "startup") backendLists.refreshStartup()
    else if (root.activeTab === "cleanup") backendLists.refreshCleanup()
  }

  onActiveTabChanged: {
    root.disarm()
    root.selectedIndex = 0
    if (root.focusSection === "filters" && root.activeFilterChips.length === 0)
      root.focusSection = root.activeListItems.length > 0 ? "rows" : "tabs"
    if (root.focusSection === "rows")
      root.selectedIndex = Nav.clampIndex(0, root.activeListItems.length)
    if (root.opened) root.refreshActiveTab()
  }

  onOpenedChanged: {
    root.disarm()
    if (opened) {
      root.cursorActive = false
      root.focusSection = "rows"
      root.selectedIndex = 0
      root.refreshActiveTab()
    }
  }

  // ------------------------------------------------------------ layout

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.preferredWidth)
    contentHeight: panel.fittedContentHeight(root.preferredHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.armedKey !== "") root.disarm()
        else root.close()
      }
      onTabRequested: function(direction) { root.cycleTab(direction) }
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()

      Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.gap

        ChipRow {
          chips: root.tabs
          selectedKey: root.activeTab
          cursorActive: root.cursorActive && root.focusSection === "tabs"
          cursorIndex: root.cursorActive && root.focusSection === "tabs" ? root.selectedIndex : -1
          onSelected: function(key) {
            root.activeTab = key
            root.setChipCursor("tabs", Nav.indexOfKey(root.tabs, key))
          }
          onChipHovered: function(index) { root.setChipCursor("tabs", index) }
        }

        PanelSeparator { foreground: Theme.fg }
      }

      Tidy.TabBody {
        id: tabBody
        anchors.top: header.bottom
        anchors.topMargin: Theme.edge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.edge
        lists: backendLists
        controller: confirmCtl
        activeTab: root.activeTab
        packagesFilter: root.packagesFilter
        startupFilter: root.startupFilter
        launchersFilter: root.launchersFilter
        startupItems: root.startupItems
        launchersItems: root.launchersItems
        busy: root.busy
        cursorRow: root.cursorActive && root.focusSection === "rows" ? root.selectedIndex : -1
        chipCursorIndex: root.cursorActive && root.focusSection === "filters" ? root.selectedIndex : -1
        onRowHovered: function(index) { root.setRowCursor(index) }
        onRowActivated: function(index, item) {
          root.setRowCursor(index)
          root.requestRowAction(item)
        }
        onChipSelected: function(key) { root.selectFilter(key) }
        onChipHovered: function(index) { root.setChipCursor("filters", index) }
      }

      // Footer: status (progress / done / error) replaces the key hints while
      // it is showing, so nothing above it moves.
      StatusFooter {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        hints: root.keyHints
        rightText: root.activeTab === "cleanup" && backendLists.cleanupLoaded
          ? "≈ " + Model.formatMib(Rows.cleanupTotalMb(backendLists.cleanupStatus)) + " reclaimable" : ""
      }
    }
  }
}
