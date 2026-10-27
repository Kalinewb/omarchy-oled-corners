import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "radius.js" as Radius

// Black rounded corners in the four physical corners of every monitor, for
// OLED panels whose bezel is rounded (or for anyone who just likes it).
//
// One click-through overlay layer surface per screen, so the geometry is
// whatever Hyprland says a monitor is: resolution, scale, rotation, and
// position all come from the compositor, and Quickshell.screens adds and
// drops surfaces as monitors are plugged in, unplugged, or reconfigured.
//
// The radius follows Hyprland's `decoration:rounding` unless
// ~/.config/omarchy/oled-corners.json overrides it. If a surface host is
// running (the notch), its settings panel can set radii too; those are kept in
// the plugin's own state folder and sit on top of the file, which is never
// written to.
Item {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/oled-corners.json"

  // What the settings panel wrote, in the plugin's own state folder. Empty
  // unless a host has ever drawn the panel, so without a host none of this
  // exists and the file above is the whole story.
  readonly property string panelPath:
    (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/kalinewb.oled-corners/panel.json"

  // -1 means "follow Hyprland" — 0 is a real value (square corners).
  property int configRadius: -1
  property color cornerColor: "#000000"
  property var perMonitorRadius: ({})

  property var panelLayer: ({})

  // Named monitors win over the global radius, so a square-cornered external
  // display can sit next to a rounded laptop panel. Radius.js is shared with
  // the settings panel, so what it shows is what is painted here.
  function radiusFor(screen) {
    var name = screen && screen.name ? String(screen.name) : ""
    return Radius.resolve(panelLayer, { radius: configRadius, monitors: perMonitorRadius }, name, Style.cornerRadius)
  }

  function applyConfig(raw) {
    var next = {}
    try {
      if (String(raw || "").trim()) next = JSON.parse(raw) || {}
    } catch (e) {
      console.warn("oled-corners: config is not valid JSON, ignoring:", e)
      return
    }

    var r = Number(next.radius)
    configRadius = (isFinite(r) && r >= 0) ? Math.round(r) : -1

    var c = String(next.color || "").trim()
    cornerColor = c ? c : "#000000"

    perMonitorRadius = (next.monitors && typeof next.monitors === "object") ? next.monitors : ({})
  }

  function applyPanel(raw) {
    var next = {}
    try {
      if (String(raw || "").trim()) next = JSON.parse(raw) || {}
    } catch (e) {
      console.warn("oled-corners: panel settings are not valid JSON, ignoring:", e)
      return
    }
    panelLayer = (next && typeof next === "object") ? next : ({})
  }

  // The plugin's own IPC target. `settings` is how a keybind, the Omarchy menu
  // or a surface host's card opens the panel that Surface.qml hands the host:
  // a service has no window of its own to open, so if no host is drawing for us
  // there is nothing to show and the answer says so.
  IpcHandler {
    target: "oled-corners"

    function settings(): string {
      if (!root.hostPresent()) return "no-host"
      if (root.hostHidden()) return "hidden"
      Quickshell.execDetached(["omarchy-shell", "notch", "panel", "kalinewb.oled-corners", "main"])
      return "opening"
    }

    // Surface.qml calls this the first time it creates panel.json: if that
    // folder did not exist when this started there is nothing watching it yet.
    function reload(): string {
      panelFile.reload()
      return "ok"
    }

    function status(): string {
      var out = []
      for (var i = 0; i < Quickshell.screens.length; i++) {
        var screen = Quickshell.screens[i]
        out.push({ monitor: String(screen.name), radius: root.radiusFor(screen) })
      }
      return JSON.stringify({
        radius: root.configRadius >= 0 ? root.configRadius : null,
        panel: root.panelLayer,
        hyprlandRounding: Style.cornerRadius,
        color: String(root.cornerColor),
        monitors: out
      })
    }
  }

  // The host keeps a heartbeat file; treat it as absent when it is missing,
  // says so, has gone quiet, or speaks an older contract than this plugin was
  // written for. Nothing here trusts it with anything but whether it is worth
  // asking: the settings panel is not a warning, so a forged answer costs
  // nothing.
  //
  // Read when asked, not watched: the host's folder may not exist yet when this
  // starts, and a watch on a folder that is not there never wakes up. Setting
  // the path again is what makes a blocking FileView read the file afresh.
  readonly property string hostPath:
    Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/kalinewb.notch/platform.json" : ""

  function hostSnapshot() {
    try {
      hostState.path = ""
      hostState.path = root.hostPath
      var state = JSON.parse(hostState.text() || "{}")
      if (state.present !== true) return null
      if (!(Number(state.contract) >= 1)) return null
      if (!state.accepted || state.accepted["kalinewb.oled-corners"] === undefined) return null
      var stale = Number(state.staleAfterMs || 6000)
      return (Date.now() - Number(state.beatAt || 0)) < stale ? state : null
    } catch (e) {
      return null
    }
  }

  function hostPresent() { return hostSnapshot() !== null }
  function hostHidden() { var state = hostSnapshot(); return state !== null && state.hidden === true }

  FileView {
    id: hostState
    blockLoading: true
    printErrors: false
  }

  FileView {
    id: panelFile
    path: root.panelPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyPanel(text())
    onFileChanged: reload()
    // Nothing has been set from the panel: the file above decides.
    onLoadFailed: root.applyPanel("")
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onFileChanged: reload()
    // No config file is the normal case: everything falls back to Hyprland.
    onLoadFailed: root.applyConfig("")
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.radiusFor(modelData) > 0
      color: "transparent"

      // Anchored to all four edges: the surface is exactly the monitor, so the
      // corners land on the panel's corners whatever the mode or scale is.
      anchors { top: true; bottom: true; left: true; right: true }

      WlrLayershell.namespace: "omarchy-oled-corners"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      // Empty input region — clicks, scrolls and hovers go straight through to
      // whatever is underneath, including fullscreen video and games.
      mask: Region {}

      readonly property int radius: root.radiusFor(modelData)

      Repeater {
        model: 4

        Item {
          required property int index

          width: panel.radius
          height: panel.radius
          // Same wedge rotated around its own centre, so it stays inside the
          // radius-sized box: 0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left.
          rotation: index * 90
          x: (index === 1 || index === 2) ? panel.width - width : 0
          y: (index === 2 || index === 3) ? panel.height - height : 0

          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
              fillColor: root.cornerColor
              strokeWidth: 0
              strokeColor: "transparent"

              startX: 0
              startY: 0
              PathLine { x: panel.radius; y: 0 }
              PathArc {
                x: 0
                y: panel.radius
                radiusX: panel.radius
                radiusY: panel.radius
                direction: PathArc.Counterclockwise
              }
              PathLine { x: 0; y: 0 }
            }
          }
        }
      }
    }
  }
}
