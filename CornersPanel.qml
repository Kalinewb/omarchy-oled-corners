import QtQuick
import "ui"

// The settings panel, drawn inside the host's own surface, on the shared UI kit
// (ui/, vendored from omarchy-ui). Under the notch every colour, the radius and
// the font come from `surfaceHost` through the kit's theme, as an opaque solid;
// the panel paints no background and no motion of its own.
//
// One row per monitor, and one for all of them: a stepper for the radius and a
// Follow button that hands the row back to the level above. The keys are the
// ones it always had (Up/Down pick a row, Left/Right step it, F or Backspace
// follow, Esc closes); the tip on the foot line names them.
FocusScope {
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

  // The kit's theme, once, from the host (null: standalone). A harness may hand in its own.
  property var theme: UTheme { host: panel.surfaceHost }

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

  // The keyboard rests on the stepper of the selected row: the rows answer this.
  signal focusAsked()
  function focusSelected() { focusAsked() }
  onSelectedChanged: focusSelected()

  // -1 when the row follows the level above it.
  function ownRadius(monitor) { return integration ? integration.radiusOf(monitor) : -1 }
  // What the row paints with: its own value, or what Follow falls back to.
  function shownRadius(monitor) {
    if (!integration) return 0
    var own = integration.radiusOf(monitor)
    return own >= 0 ? own : integration.followRadius(monitor)
  }

  function open(next) {
    panel.selected = 0
    focusSelected()
  }

  // The notch's back strip is a zone at the top CENTRE of the panel (`backZoneWidth` by `backZoneHeight`)
  // and a press anywhere in it goes back, so no control and no text of ours may sit in it. Nothing is
  // pushed down for it: the heading is at the left, as it always was, and is held to the room between
  // the panel's edge and the zone (elided if it ever had to be longer); the close is at the right, and
  // the rows have their name at the left and their controls at the right. With no strip there is no
  // zone and the heading has its full width. This is a single page, so there is no back of our own
  // (the strip, or nothing): Esc is the strip's invisible alias.
  readonly property bool hostHasBack: !!surfaceHost && !!surfaceHost.features && surfaceHost.features.indexOf("panelBack") !== -1
  readonly property real zoneWidth: !surfaceHost ? 0
    : surfaceHost.backZoneWidth > 0 ? surfaceHost.backZoneWidth
    : (hostHasBack && surfaceHost.restWidth > 0) ? surfaceHost.restWidth : 0
  // The keys are named on one reserved line at the foot of the page. This page only ever lives in the notch
  // (no host, no panel), so it takes the kit's notch placement everywhere and never floats a box over the rows.
  readonly property string keysTip: "← → change the radius · F or ⌫ follow the level above"

  // A single page: the strip's first ask has nothing to step back inside, so it answers no and the host
  // goes back to where this was opened from, or closes.
  function goBackInside() { return false }

  readonly property int pad: theme.sp.md
  implicitWidth: Math.min(maxWidth, 420)
  implicitHeight: Math.min(maxHeight, page.height + theme.sp.sm)

  // Left and Right reach the stepper when it has the keyboard; this is for when a button has it.
  Keys.onLeftPressed: if (integration) integration.nudge(panel.rows[panel.selected].monitor, -1)
  Keys.onRightPressed: if (integration) integration.nudge(panel.rows[panel.selected].monitor, 1)
  Keys.onUpPressed: { panel.selected = Math.max(0, panel.selected - 1) }
  Keys.onDownPressed: { panel.selected = Math.min(panel.rows.length - 1, panel.selected + 1) }
  Keys.onPressed: function (event) {
    // Backspace or F hands the row back to the level above it.
    if (event.key === Qt.Key_Backspace || event.key === Qt.Key_F) {
      if (integration) integration.follow(panel.rows[panel.selected].monitor)
      event.accepted = true
    }
  }

  // The one place Esc is handled: it dismisses the tip first, then closes.
  UKeys {
    anchors.fill: parent
    focus: true
    level: "back"
    open: false
    onCloseRequested: panel.closeRequested()

    Column {
      id: page
      x: panel.pad
      width: panel.width - 2 * panel.pad
      spacing: panel.theme.sp.sm

      Item {
        id: header
        width: page.width
        // As tall as the zone, so the first row (a press target across the panel) starts below it.
        height: Math.max(panel.theme.rowHeight, panel.hostHasBack && panel.surfaceHost ? panel.surfaceHost.backZoneHeight : 0)

        Text {
          width: panel.zoneWidth > 0 ? Math.max(40, (panel.width - panel.zoneWidth) / 2 - panel.pad - panel.theme.sp.xs)
            : header.width - close.width - panel.theme.sp.sm
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          text: "OLED corners"
          color: panel.theme.label
          font.family: panel.theme.fontFamily
          font.pixelSize: panel.theme.titleSize
          font.weight: panel.theme.titleWeight
          Accessible.role: Accessible.Heading
          Accessible.name: text
        }
        UClose {
          id: close
          theme: panel.theme
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          onActivated: panel.closeRequested()
        }
      }

      USection {
        theme: panel.theme
        title: "Corner radius"
        first: true

        Repeater {
          id: rowList
          model: panel.rows

          Item {
            id: line
            required property int index
            required property var modelData
            readonly property bool follows: panel.ownRadius(modelData.monitor) < 0

            width: parent.width
            height: row.height

            Connections {
              target: panel
              function onFocusAsked() { if (line.index === panel.selected) step.forceActiveFocus() }
            }
            Component.onCompleted: if (line.index === panel.selected) step.forceActiveFocus()

            // A press anywhere on the row picks it.
            MouseArea {
              anchors.fill: parent
              z: -1
              onClicked: panel.selected = line.index
            }

            URow {
              id: row
              theme: panel.theme
              label: line.modelData.label
              value: line.follows ? "Following" : ""
              valueQuiet: true

              UStepper {
                id: step
                theme: panel.theme
                label: line.modelData.label + " radius"
                from: 0
                to: 120
                value: panel.shownRadius(line.modelData.monitor)
                unit: " px"
                onModified: function (next) {
                  panel.selected = line.index
                  if (panel.integration) panel.integration.nudge(line.modelData.monitor, next - step.value)
                }
                onActiveFocusChanged: if (activeFocus) panel.selected = line.index

                UTip {
                  theme: panel.theme
                  text: panel.keysTip
                  placement: "foot"
                  hovering: step.hotMinus || step.hotPlus
                }
              }

              trailing: UButton {
                theme: panel.theme
                text: "Follow"
                enabled: !line.follows
                height: panel.theme.controlHeight
                onClicked: {
                  panel.selected = line.index
                  if (panel.integration) panel.integration.follow(line.modelData.monitor)
                }
                onActiveFocusChanged: if (activeFocus) panel.selected = line.index
              }
            }
          }
        }
      }

      UNotice {
        theme: panel.theme
        width: page.width
        visible: !!panel.integration && !panel.integration.writable && panel.integration.loaded
        tone: "warning"
        text: "panel.json is not valid JSON. Fix or delete it."
      }

      UTip {
        theme: panel.theme
        width: page.width
        line: true
      }
    }
  }
}
