import QtQuick

// The root `dev/check-ui.sh --walk` can use when the bare CornersPanel.qml shows too little: the panel
// with three screens (one following, one with a value of its own), a panel.json that is not valid JSON,
// and the theme's host as the panel's surfaceHost, so the walk sees every row, button and the notice.
//   ./dev/check-ui.sh --walk dev/walk-root.qml
Item {
  id: root
  property var theme: null
  implicitWidth: panel.item ? panel.item.implicitWidth : 420
  implicitHeight: panel.item ? panel.item.implicitHeight : 200

  QtObject {
    id: integration
    property var screenNames: ["eDP-1", "DP-2"]
    property bool writable: false
    property bool loaded: true
    function radiusOf(m) { return m === "DP-2" ? 28 : (m === "" ? 22 : -1) }
    function followRadius(m) { return 22 }
    function nudge(m, d) {}
    function follow(m) {}
  }

  // A Loader, not the CornersPanel type: the walk runs under Quickshell's `qs:` scheme, where a folder
  // is importable only from the harness root, so this file names the panel by path instead.
  Loader {
    id: panel
    Component.onCompleted: setSource("../CornersPanel.qml", {
      theme: root.theme,
      surfaceHost: root.theme ? root.theme.host : null,
      integration: integration,
      maxWidth: 420,
      maxHeight: 400
    })
  }
}
