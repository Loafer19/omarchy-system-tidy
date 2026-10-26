// Preview stub for tools/render-previews.sh: the card of Omarchy's
// Ui/KeyboardPanel.qml drawn in a plain Item, since the real one is a
// layer-shell window that cannot map offscreen.
import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
  id: root
  property Item anchorItem: null
  property QtObject bar: null
  property var owner: null
  property int margin: Style.gapsOut
  property int padding: Style.spacing.popupPadding
  property int contentWidth: Style.space(280)
  property int contentHeight: Style.space(200)
  property var borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
  property bool centerOnBar: false
  property bool open: false
  property int gap: Style.gapsOut
  property bool popoutSwitching: false
  property bool popoutSwitchClosing: false
  property Item focusTarget: null
  readonly property Item card: card
  default property alias contentItem: contentHolder.children
  readonly property real verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)
  function close() { open = false }
  function fittedContentWidth(w, cap) { return Math.round(cap > 0 ? Math.min(w, cap) : w) }
  function fittedContentHeight(h, cap) { var d = Math.max(verticalContentInset, (Number(h) || 0) + verticalContentInset); return Math.round(cap > 0 ? Math.min(d, cap) : d) }
  function cappedContentHeight(h) { return Math.round(h) }
  width: contentWidth; height: contentHeight
  BorderSurface {
    id: card
    width: root.contentWidth; height: root.contentHeight
    color: Commons.Color.popups.background
    borderSpec: root.borderSpec
    padding: root.padding
    radius: Style.cornerRadius
    Item {
      id: contentHolder
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
    }
  }
}
