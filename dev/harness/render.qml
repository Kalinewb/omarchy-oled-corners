import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "repo/ui"

// Renders the settings panel to a PNG, offscreen, on a stand-in surfaceHost
// (radius 10, black or white) or on none (standalone), with a stand-in for
// Surface.qml that has two screens. Run by dev/render.sh under Quickshell with
// the OpenGL RHI (as the kit's dev/gallery.sh and omarchy-notch dev/glow.sh);
// it opens no real window. `import "repo/ui"` is here only so the shell has
// scanned the kit's folder before the panel (loaded under Quickshell's own
// `qs:` scheme) asks for it, as the kit's own ui-walk.qml does.
//
//   UI_RENDER_ROOT      the panel file, relative to the repo (default CornersPanel.qml)
//   UI_RENDER_MODE      hosted | standalone
//   UI_RENDER_HOST      black | white        (the stand-in host's colour)
//   UI_RENDER_SELECTED  the row to select (0 is "All monitors")
//   UI_RENDER_BROKEN    1 for a panel.json that is not valid JSON
//   UI_RENDER_ZONE      1 draws the notch's back zone (180 x 32, top centre) as a dotted box
//   UI_RENDER_OUT       PNG path
//   UI_RENDER_THEME     current (default) or a theme name from the Omarchy themes
ShellRoot {
  id: shell

  readonly property string rootFile: Quickshell.env("UI_RENDER_ROOT") || "CornersPanel.qml"
  readonly property bool hostedMode: (Quickshell.env("UI_RENDER_MODE") || "hosted") !== "standalone"
  readonly property bool black: (Quickshell.env("UI_RENDER_HOST") || "black") !== "white"
  readonly property int selectRow: Number(Quickshell.env("UI_RENDER_SELECTED") || "0")
  readonly property bool broken: Quickshell.env("UI_RENDER_BROKEN") === "1"
  readonly property bool zone: Quickshell.env("UI_RENDER_ZONE") === "1"
  readonly property string out: Quickshell.env("UI_RENDER_OUT") || "/tmp/oled-corners-panel.png"
  readonly property string themeName: Quickshell.env("UI_RENDER_THEME") || "current"

  function say(key, value) { console.log("RENDER " + key + " " + value) }

  FileView {
    id: colors
    blockLoading: true
    path: shell.themeName === "current"
      ? Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
      : "/usr/share/omarchy/themes/" + shell.themeName + "/colors.toml"
  }
  Component.onCompleted: Commons.Color.loadColors(colors.text())

  // A contract-1 surfaceHost, as the notch hands it to a panel.
  QtObject {
    id: fakeHost
    readonly property var features: ["panel", "panelBack", "backZone"]
    readonly property color color: shell.black ? "#000000" : "#ffffff"
    readonly property color foreground: shell.black ? "#ffffff" : "#000000"
    readonly property color secondary: shell.black ? "#99EBEBF5" : "#993C3C43"
    readonly property color accent: foreground
    readonly property real radius: 10
    readonly property string fontFamily: Commons.Style.font.family
    readonly property real backZoneWidth: 180
    readonly property real backZoneHeight: 32
    readonly property real restHeight: 32
    function radiusFor(size) { return Math.max(0, Math.min(radius, size / 2)) }
  }

  // What Surface.qml gives the panel: three levels, two screens. "All monitors" is set, eDP-1 follows
  // it (so it shows what it would use), DP-2 has a value of its own.
  QtObject {
    id: integration
    property var screenNames: ["eDP-1", "DP-2"]
    property bool writable: !shell.broken
    property bool loaded: true
    property var own: ({ "": 22, "DP-2": 28 })
    function radiusOf(m) { return own[m] === undefined ? -1 : own[m] }
    function followRadius(m) { return m ? (own[""] === undefined ? 13 : own[""]) : 13 }
    function nudge(m, d) {}
    function follow(m) {}
  }

  Window {
    id: win
    visible: true
    width: Math.max(1, Math.ceil(loader.item ? loader.item.implicitWidth : 420))
    height: Math.max(1, Math.ceil(loader.item ? loader.item.implicitHeight : 200))
    color: shell.hostedMode ? fakeHost.color : Commons.Color.background

    Rectangle {
      id: scene
      anchors.fill: parent
      color: win.color
      Loader {
        id: loader
        Component.onCompleted: setSource("repo/" + shell.rootFile, {
          surfaceHost: shell.hostedMode ? fakeHost : null,
          integration: integration,
          maxWidth: 420,
          maxHeight: 400
        })
      }
      Rectangle {
        visible: shell.zone
        x: (scene.width - fakeHost.backZoneWidth) / 2
        y: 0
        width: fakeHost.backZoneWidth
        height: fakeHost.backZoneHeight
        color: "transparent"
        border.width: 1
        border.color: "#ff3b30"
      }
    }
  }

  Timer {
    interval: 400
    running: true
    onTriggered: {
      var panel = loader.item
      if (!panel) { shell.say("load", "FAIL " + shell.rootFile); Qt.exit(2); return }
      panel.forceActiveFocus()
      if (shell.selectRow > 0) panel.selected = shell.selectRow
      grabTimer.start()
    }
  }
  // Long enough for the tip to arm (250 ms after focus) and for the layout to settle.
  Timer {
    id: grabTimer
    interval: 700
    onTriggered: scene.grabToImage(function(result) {
      var ok = result.saveToFile(shell.out)
      shell.say("saved", shell.out + " " + win.width + "x" + win.height + (ok ? "" : " FAILED"))
      Qt.exit(ok ? 0 : 1)
    })
  }
  Timer { interval: 15000; running: true; onTriggered: { shell.say("timeout", "FAIL"); Qt.exit(3) } }
}
