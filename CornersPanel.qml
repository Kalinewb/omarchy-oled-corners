import QtQuick

// The settings panel, drawn inside the host's own surface. Every colour, the
// radius and the font come from `surfaceHost`; the panel paints no background
// and no motion of its own.
Item {
  id: panel

  // Set by the host, once.
  property var surfaceHost: null
  property string surfaceScreen: ""
  // Set where the Component is declared, in Surface.qml.
  property var integration: null
  // Bound by the host.
  property string route: "main"
  property real maxWidth: 400
  property real maxHeight: 400
  signal closeRequested()

  readonly property color foreground: surfaceHost ? surfaceHost.foreground : "#ffffff"
  readonly property color secondary: surfaceHost ? surfaceHost.secondary : "#9aa0ad"
  readonly property string fontFamily: surfaceHost ? surfaceHost.fontFamily : ""

  // One row for every monitor, plus the global default above them.
  readonly property var rows: {
    var out = [{ monitor: "", label: "All monitors" }]
    var names = integration ? integration.screenNames : []
    for (var i = 0; i < names.length; i++) out.push({ monitor: names[i], label: names[i] })
    return out
  }

  property int selected: 0

  function clampSelection() {
    if (selected >= rows.length) selected = rows.length - 1
    if (selected < 0) selected = 0
  }
  onRowsChanged: clampSelection()

  function valueText(monitor) {
    if (!integration) return ""
    var own = integration.radiusOf(monitor)
    if (own >= 0) return own + " px"
    return "Follow · " + integration.followRadius(monitor) + " px"
  }

  function open(next) { panel.selected = 0 }

  implicitWidth: Math.min(maxWidth, 380)
  implicitHeight: Math.min(maxHeight, header.height + list.height + hint.height + 8)

  focus: true
  Keys.onEscapePressed: panel.closeRequested()
  Keys.onUpPressed: { panel.selected = Math.max(0, panel.selected - 1) }
  Keys.onDownPressed: { panel.selected = Math.min(panel.rows.length - 1, panel.selected + 1) }
  Keys.onLeftPressed: if (integration) integration.nudge(panel.rows[panel.selected].monitor, -1)
  Keys.onRightPressed: if (integration) integration.nudge(panel.rows[panel.selected].monitor, 1)
  Keys.onPressed: function (event) {
    // Backspace or F hands the row back to the level above it.
    if (event.key === Qt.Key_Backspace || event.key === Qt.Key_F) {
      if (integration) integration.follow(panel.rows[panel.selected].monitor)
      event.accepted = true
    }
  }

  Text {
    id: header
    x: 14
    text: "OLED corners"
    color: panel.foreground
    font.family: panel.fontFamily
    font.pixelSize: 13
    height: 26
    verticalAlignment: Text.AlignVCenter
  }

  Column {
    id: list
    anchors.top: header.bottom
    width: parent.width

    Repeater {
      model: panel.rows

      Item {
        required property int index
        required property var modelData

        width: list.width
        height: 28

        Rectangle {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          radius: panel.surfaceHost ? panel.surfaceHost.radiusFor(height) : 6
          color: "transparent"
          border.width: 1
          border.color: index === panel.selected ? panel.secondary : "transparent"
        }

        Text {
          x: 14
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.label
          color: index === panel.selected ? panel.foreground : panel.secondary
          font.family: panel.fontFamily
          font.pixelSize: 12
        }

        Row {
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10

          Text {
            text: panel.valueText(modelData.monitor)
            color: index === panel.selected ? panel.foreground : panel.secondary
            font.family: panel.fontFamily
            font.pixelSize: 12
          }

          Text {
            text: "−"
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: 13
            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              onClicked: {
                panel.selected = index
                if (panel.integration) panel.integration.nudge(modelData.monitor, -1)
              }
            }
          }

          Text {
            text: "+"
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: 13
            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              onClicked: {
                panel.selected = index
                if (panel.integration) panel.integration.nudge(modelData.monitor, 1)
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          z: -1
          onClicked: panel.selected = index
        }
      }
    }
  }

  Text {
    id: hint
    anchors.top: list.bottom
    x: 14
    width: parent.width - 28
    elide: Text.ElideRight
    text: panel.integration && !panel.integration.writable && panel.integration.loaded
      ? "panel.json is not valid JSON · fix or delete it"
      : "← →  radius · F  follow · Esc  close"
    color: panel.secondary
    font.family: panel.fontFamily
    font.pixelSize: 11
    height: 30
    verticalAlignment: Text.AlignVCenter
  }
}
