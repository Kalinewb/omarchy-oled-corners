import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Black rounded corners in the four physical corners of every monitor, for
// OLED panels whose bezel is rounded (or for anyone who just likes it).
//
// One click-through overlay layer surface per screen, so the geometry is
// whatever Hyprland says a monitor is: resolution, scale, rotation, and
// position all come from the compositor, and Quickshell.screens adds and
// drops surfaces as monitors are plugged in, unplugged, or reconfigured.
//
// The radius follows Hyprland's `decoration:rounding` unless
// ~/.config/omarchy/oled-corners.json overrides it.
Item {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/oled-corners.json"

  // -1 means "follow Hyprland" — 0 is a real value (square corners).
  property int configRadius: -1
  property color cornerColor: "#000000"
  property var perMonitorRadius: ({})

  readonly property int fallbackRadius: configRadius >= 0 ? configRadius : Style.cornerRadius

  // Named monitors win over the global radius, so a square-cornered external
  // display can sit next to a rounded laptop panel.
  function radiusFor(screen) {
    var name = screen && screen.name ? String(screen.name) : ""
    if (name && perMonitorRadius.hasOwnProperty(name)) {
      var n = Number(perMonitorRadius[name])
      if (isFinite(n) && n >= 0) return Math.round(n)
    }
    return Math.max(0, fallbackRadius)
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
