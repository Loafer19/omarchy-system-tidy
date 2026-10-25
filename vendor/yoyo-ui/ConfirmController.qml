import QtQuick

// Two-step confirm state for rows and chips: the first confirm(key) arms,
// a second confirm(key) with the same key returns true (run it now).
// Keys are stable strings (e.g. "packages:" + name), not indices, so the
// armed row survives ListView reloads. Call disarm() on Esc, cursor moves and
// tab changes; it also disarms itself after `timeout` ms.
// One controller per panel means at most one armed thing at a time.
QtObject {
  id: root

  property string armedKey: ""
  property int timeout: 4000
  readonly property bool armed: armedKey !== ""

  function isArmed(key) { return key !== undefined && key !== null && String(key) !== "" && root.armedKey === String(key) }

  function arm(key) {
    if (key === undefined || key === null || String(key) === "") return
    root.armedKey = String(key)
    root._timer.restart()
  }

  function disarm() {
    root._timer.stop()
    root.armedKey = ""
  }

  // true = already armed with this key: disarm and run the action now.
  function confirm(key) {
    if (key === undefined || key === null || String(key) === "") return false
    if (root.isArmed(key)) { root.disarm(); return true }
    root.arm(key)
    return false
  }

  property Timer _timer: Timer {
    interval: root.timeout
    onTriggered: root.armedKey = ""
  }
}
