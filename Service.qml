import QtQuick
import Quickshell.Io

// Headless, loaded once per shell (not per monitor like the bar widget), so it
// owns the plugin's one IpcHandler. The bar builds BarWidget.qml on every
// monitor, and a handler there registers the target once per bar ("Handler was
// registered but will not be used ..."). Calls go through the shell, which
// opens the panel of the bar on the focused monitor, as
// `omarchy-shell shell toggle yoyo.system-tidy` does. keepLoaded keeps this
// instance (and its registration) across plugin hot-reloads.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  // Injected by the shell; `shell` is the plugin's scoped facade.
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property string omarchyPath: ""

  readonly property string pluginId: "yoyo.system-tidy"

  function host() {
    var s = root.shell
    return s && typeof s.summon === "function" && typeof s.hide === "function"
      && typeof s.toggle === "function" ? s : null
  }

  // `qs ipc call yoyo.system-tidy toggle` (and open / close).
  IpcHandler {
    target: "yoyo.system-tidy"

    function open(): void {
      var s = root.host()
      if (s) s.summon(root.pluginId, "")
    }
    function close(): void {
      var s = root.host()
      if (s) s.hide(root.pluginId)
    }
    function toggle(): void {
      var s = root.host()
      if (s) s.toggle(root.pluginId, "")
    }
  }
}
