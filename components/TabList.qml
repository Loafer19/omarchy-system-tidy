import QtQuick
import qs.Commons
import "../theme"

// One tab body: optional filter chips, the list, and its loading/empty text.
Item {
  id: root

  property var chips: []
  property string selectedKey: ""
  property bool chipCursorActive: false
  property int chipCursorIndex: -1
  property var model: []
  property bool loading: false
  property string emptyText: ""
  property string emptySubtitle: ""
  property alias delegate: list.delegate
  readonly property alias view: list
  readonly property int count: root.model ? root.model.length : 0

  signal chipSelected(string key)
  signal chipHovered(int index)

  ChipRow {
    id: chipRow
    visible: root.chips.length > 0
    anchors.top: parent.top
    anchors.left: parent.left
    compact: true
    chips: root.chips
    selectedKey: root.selectedKey
    cursorActive: root.chipCursorActive
    cursorIndex: root.chipCursorIndex
    onSelected: function(key) { root.chipSelected(key) }
    onChipHovered: function(index) { root.chipHovered(index) }
  }

  ListView {
    id: list
    anchors.top: chipRow.visible ? chipRow.bottom : parent.top
    anchors.topMargin: chipRow.visible ? Theme.edge : 0
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    clip: true
    model: root.model
  }

  EmptyState {
    anchors.top: list.top
    anchors.left: list.left
    anchors.right: list.right
    visible: root.count === 0
    title: root.loading ? "Loading…" : root.emptyText
    subtitle: root.loading ? "" : root.emptySubtitle
  }
}
