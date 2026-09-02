// Matrix rain on the lock screen.
//
// Almost everything this plugin does happens in bin/omarchy-matrix-lock, which
// clones omarchy.lock and patches the clone. That is a one-shot operation the
// user runs, not something the shell should be doing, so this service exists
// for the one thing a script cannot do on its own: notice, while you are
// looking at the desktop, that an Omarchy update has moved the stock lock
// screen out from under your clone.
//
// A clone stops tracking upstream. Left alone it silently keeps an old lock
// screen, security fixes included, which is the one real hazard of the whole
// approach. `check` compares the stock LockView.qml this clone was generated
// from against the one installed now; the shell restarts on update, so a stale
// clone is reported at exactly the moment it becomes stale.
//
// Nothing here writes anything, and nothing runs unless the shell starts or an
// IPC call arrives.

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  // Qt hands out a file:// URL; Process needs a plain path.
  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    return u.indexOf("file://") === 0 ? u.substring(7) : u
  }
  readonly property string bin: pluginDir + "bin/omarchy-matrix-lock"

  // 0 current, 1 not installed, 3 installed but stale. -1 until first checked.
  property int state: -1
  readonly property bool stale: state === 3

  function check() {
    if (!checkProc.running) checkProc.running = true
  }

  Process {
    id: checkProc
    command: ["bash", "-c", 'exec "$0" check', root.bin]
    onExited: function (exitCode) {
      root.state = exitCode
      // Only ever on a transition into stale, so re-checking on demand does
      // not re-notify. A shell restart is a fresh process and does notify,
      // which is the point: that is the restart that followed the update.
      if (exitCode === 3) notifyProc.running = true
    }
  }

  Process {
    id: notifyProc
    command: ["notify-send", "--app-name=Matrix Lock", "--icon=system-lock-screen",
      "Lock screen is out of date",
      "Omarchy updated the lock screen since your matrix clone was made. Run: omarchy-matrix-lock sync"]
  }

  Process {
    id: statusProc
    command: ["bash", "-c", 'exec "$0" status', root.bin]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
  }

  IpcHandler {
    target: "matrix-lock"

    // Same text the script prints, so there is one description of the state.
    function status(): string {
      return String(statusOut.text || "").trim() || "not checked yet; try again"
    }

    function check(): string {
      root.check()
      return "checking"
    }
  }

  // Deferred so the notification daemon is up before anything is sent, and so
  // a stale clone never delays the rest of the shell coming up.
  Timer {
    interval: 4000
    running: true
    repeat: false
    onTriggered: {
      root.check()
      statusProc.running = true
    }
  }
}
