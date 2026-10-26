import QtQuick
import Quickshell.Io

// One read-only backend call (`bash backend.sh <verb>`); finished(text)
// gets its whole stdout.
Process {
  id: root

  property string backendPath: ""
  property string verb: ""

  signal finished(string text)

  command: ["bash", root.backendPath, root.verb]
  stdout: StdioCollector {
    waitForEnd: true
    onStreamFinished: root.finished(text)
  }
}
