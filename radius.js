.pragma library

// Which radius a monitor is painted with. Corners.qml (the service) and
// Surface.qml (the settings panel) both call this, so the panel can never show
// a number the corners are not using.
//
// Three layers, nearest first:
//   panel  -- what the settings panel wrote:  { radius, monitors }
//   hand   -- ~/.config/omarchy/oled-corners.json, as the user wrote it
//   hypr   -- Hyprland's decoration:rounding
// Within the panel layer a named monitor beats "All monitors"; "All monitors"
// beats everything in the hand-written file, including its per-monitor radii.

// A radius from the panel's own file: a whole number >= 0, or -1 for "not set".
function stored(value) {
  if (value === undefined || value === null || value === "" || typeof value === "boolean") return -1
  var n = Number(value)
  return (isFinite(n) && n >= 0) ? Math.round(n) : -1
}

// The same, for the hand-written file, kept exactly as 1.0.1 read it.
function written(value) {
  var n = Number(value)
  return (isFinite(n) && n >= 0) ? Math.round(n) : -1
}

function own(layer, name) {
  var monitors = (layer && layer.monitors && typeof layer.monitors === "object") ? layer.monitors : {}
  return name ? stored(monitors[name]) : stored(layer ? layer.radius : undefined)
}

function fromHand(hand, name, hypr) {
  var monitors = (hand && hand.monitors && typeof hand.monitors === "object") ? hand.monitors : {}
  if (name && Object.prototype.hasOwnProperty.call(monitors, name)) {
    var n = written(monitors[name])
    if (n >= 0) return n
  }
  var r = written(hand ? hand.radius : undefined)
  return Math.max(0, r >= 0 ? r : hypr)
}

// `name` is "" for the "All monitors" row.
function resolve(panel, hand, name, hypr) {
  var mine = own(panel, name)
  if (mine >= 0) return mine
  var all = own(panel, "")
  if (all >= 0) return all
  return fromHand(hand, name, hypr)
}

// What a row falls back to when its own panel value is cleared.
function inherited(panel, hand, name, hypr) {
  if (name) {
    var all = own(panel, "")
    if (all >= 0) return all
  }
  return fromHand(hand, name, hypr)
}
