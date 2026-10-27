import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "radius.js" as Radius

// What this plugin gives a surface host (today: kalinewb.notch). Contract 1.
//
// It exists once, however many monitors there are, so the settings live here
// rather than in the panel — the panel is created once per screen.
//
// Settings made in the panel are written to the plugin's own state folder
// (panel.json), never to ~/.config/omarchy/oled-corners.json: that file is the
// user's, is read here and never written, and the service lays the panel's
// values over it (Radius.resolve decides how).
//
// No windows, no IpcHandler: the service (Corners.qml) owns the IPC target.
Item {
  id: root

  // Set by the host. Until it does, there is no host.
  property var surfaceHost: null

  // The corners themselves need nothing from the host, so the settings panel
  // is always on offer.
  property bool available: true

  property Component panel: Component { CornersPanel { integration: root } }

  readonly property string panelDir:
    (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/kalinewb.oled-corners"
  readonly property string panelPath: panelDir + "/panel.json"
  readonly property string handPath: Quickshell.env("HOME") + "/.config/omarchy/oled-corners.json"

  // The panel's own file as parsed, so a key a later version adds survives a
  // write.
  property var stored: ({})
  // The user's file, read only to show what "Follow" will fall back to.
  property var hand: ({})

  // False until the first read has answered, and false for as long as panel.json
  // holds something that is not JSON: that is the user's to fix, and writing
  // over it would throw their edit away.
  property bool loaded: false
  property bool broken: false
  readonly property bool writable: loaded && !broken

  // What "Follow Hyprland" resolves to right now.
  readonly property int hyprRadius: Math.max(0, Style.cornerRadius)

  readonly property var screenNames: {
    var out = []
    for (var i = 0; i < Quickshell.screens.length; i++) out.push(String(Quickshell.screens[i].name))
    return out
  }

  // -1 means "not set here" — i.e. follow the level above (the file, or
  // Hyprland; for a named monitor, "All monitors" first).
  function radiusOf(monitor) {
    return monitor ? Radius.stored((stored.monitors || {})[monitor]) : Radius.stored(stored.radius)
  }

  // What that row actually paints with, once the fallbacks are applied.
  function effectiveRadius(monitor) {
    return Radius.resolve(stored, hand, monitor, hyprRadius)
  }

  // What the row would paint with if it were set to Follow.
  function followRadius(monitor) {
    return Radius.inherited(stored, hand, monitor, hyprRadius)
  }

  function setRadius(monitor, value) {
    if (!writable) return
    var next = JSON.parse(JSON.stringify(stored || {}))
    if (monitor) {
      var monitors = (next.monitors && typeof next.monitors === "object") ? next.monitors : {}
      if (value < 0) delete monitors[monitor]
      else monitors[monitor] = value
      if (Object.keys(monitors).length > 0) next.monitors = monitors
      else delete next.monitors
    } else {
      if (value < 0) delete next.radius
      else next.radius = value
    }
    stored = next
    write(JSON.stringify(next, null, 2) + "\n")
  }

  function nudge(monitor, delta) {
    var from = radiusOf(monitor)
    if (from < 0) from = effectiveRadius(monitor)
    setRadius(monitor, Math.max(0, Math.min(120, from + delta)))
  }

  function follow(monitor) {
    setRadius(monitor, -1)
  }

  // FileView will not create the folder, so make it first; the write then goes
  // through FileView's atomic rename.
  property string queued: ""
  // True when panel.json is not there yet: the folder may not have been either,
  // and a watch on a folder that did not exist never wakes up, so after the
  // first write the watch is set up again here and the service is told to look.
  property bool fresh: true
  property bool arm: false
  function write(text) {
    queued = text
    arm = fresh
    makeDir.running = true
  }

  Process {
    id: makeDir
    command: ["mkdir", "-p", root.panelDir]
    onExited: function (code) {
      if (code === 0 && root.queued !== "") panelFile.setText(root.queued)
      root.queued = ""
    }
  }

  function load(raw) {
    loaded = true
    try {
      var parsed = String(raw || "").trim() ? JSON.parse(raw) : {}
      var plain = !!parsed && typeof parsed === "object" && !Array.isArray(parsed)
      stored = plain ? parsed : ({})
      broken = !plain
    } catch (e) {
      stored = ({})
      broken = true
    }
  }

  function loadHand(raw) {
    try {
      var parsed = String(raw || "").trim() ? JSON.parse(raw) : {}
      hand = (parsed && typeof parsed === "object") ? parsed : ({})
    } catch (e) {
      // The service ignores a file it cannot parse and keeps what it had; this
      // can only show what that file would give, which is nothing.
      hand = ({})
    }
  }

  FileView {
    id: panelFile
    path: root.panelPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: { root.fresh = false; root.load(text()) }
    onFileChanged: reload()
    onSaved: {
      if (!root.arm) return
      root.arm = false
      var path = panelFile.path
      panelFile.path = ""
      panelFile.path = path
      Quickshell.execDetached(["omarchy-shell", "oled-corners", "reload"])
    }
    // No file yet is the normal case: nothing has been set from the panel.
    onLoadFailed: { root.fresh = true; root.load("") }
  }

  FileView {
    id: handFile
    path: root.handPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadHand(text())
    onFileChanged: reload()
    onLoadFailed: root.loadHand("")
  }
}
