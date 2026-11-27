# OLED Corners

An [Omarchy](https://omarchy.org) shell plugin that paints black rounded
corners in the four **physical corners of every monitor** — the screen's own
corners, not any window's.

Handy on OLED panels (a true-black corner costs no light and hides a rounded
bezel), and on laptops whose display glass is rounded but whose framebuffer
isn't.

## What it does

- One click-through overlay per screen. Clicks, scrolls and hovers pass
  straight through, including over fullscreen video and games.
- Geometry comes from Hyprland: resolution, scale, rotation and position are
  whatever the compositor reports, and surfaces appear and disappear as
  monitors are plugged in, unplugged, or reconfigured — no restart.
- Radius is 1.25 times Hyprland's `decoration:rounding` by default, so the
  screen corners track your window corners (a little larger) and change when
  your theme or config does.

## Install

No setup, no dependencies beyond the Omarchy shell itself, no install script,
and nothing outside the plugin's own directory is touched. Two commands:

```bash
omarchy plugin add https://github.com/Kalinewb/omarchy-oled-corners.git
omarchy plugin enable kalinewb.oled-corners
```

Plugins land disabled so you can read the code first — `Corners.qml` is the
whole service; the rest is the optional settings panel below. The corners
appear the moment it's enabled; no restart, no configuration.

To turn it off without uninstalling:

```bash
omarchy plugin disable kalinewb.oled-corners
```

To remove it completely:

```bash
omarchy plugin remove kalinewb.oled-corners
```

That deletes the checkout. Two small files can outlive it, and only if you
made them: `~/.config/omarchy/oled-corners.json` (your own config) and
`~/.local/state/kalinewb.oled-corners/` (what the settings panel saved).
Delete them too if you want nothing left behind.

## Configuration

Entirely optional. Without a config file the radius is 1.25 times Hyprland's
`decoration:rounding` and the corners are pure black.

Create `~/.config/omarchy/oled-corners.json`:

```json
{
  "radius": 22,
  "color": "#000000",
  "monitors": {
    "eDP-1": 28,
    "DP-2": 0
  }
}
```

| Key        | Meaning                                                                 |
|------------|-------------------------------------------------------------------------|
| `radius`   | Corner radius in logical pixels, used as written. Omit it to get 1.25 times Hyprland's `decoration:rounding`. |
| `power`    | Shape of the curve: a number >= 1, default 2 (a circle); higher is squarer. |
| `color`    | Any Qt color string. Defaults to `#000000`.                              |
| `monitors` | Per-output radius overrides, keyed by Hyprland output name (`hyprctl monitors`). A `0` turns corners off for that display. |

The file is watched — edits apply immediately, no restart.

## Settings panel (optional, needs the notch)

If you run the [Notch](https://github.com/Kalinewb/omarchy-notch) as your bar,
OLED Corners offers it a settings panel that opens **inside the notch**, in the
notch's own colours and corner radius. It lists "All monitors" and one row per
screen, each with a radius stepper (`−` / `+`) and a **Follow** button:

| Key        | What it does                                                        |
|------------|---------------------------------------------------------------------|
| `←` / `→`  | Radius down / up by one pixel (also the `−` and `+` buttons)        |
| `F` or `⌫` | **Follow**: hand the row back to the level above it (also the Follow button) |
| `↑` / `↓`  | Pick a row                                                          |
| `Tab`      | Move between the controls                                           |
| `Esc`      | Put a tip away if one is showing, otherwise close (also the `✕`)    |

The keys are named in a tip on the foot line, not printed on the panel. A row
set to **Follow** says "Following" and shows the radius it will use in the
stepper, for example `22 px`.

Open it from a keybind, the Omarchy menu or a script:

```bash
omarchy-shell oled-corners settings
```

The answer is `opening`, `hidden` (the bar is hidden) or `no-host` (see
*Without the notch*). `omarchy-shell oled-corners status` prints the radii in
use, as JSON.

**Where it saves.** The panel never writes your
`~/.config/omarchy/oled-corners.json`. Its settings go in
`~/.local/state/kalinewb.oled-corners/panel.json` (`$XDG_STATE_HOME` is
respected) and are laid on top of your file:

1. a monitor's own value set in the panel,
2. "All monitors" set in the panel,
3. your `oled-corners.json` (its per-monitor value, then its `radius`),
4. 1.25 times Hyprland's `decoration:rounding`.

So **Follow** on a row falls back to your file and Hyprland, and deleting
`panel.json` puts everything back the way your file says. If `panel.json` is
not valid JSON the panel says so and refuses to write rather than overwrite
what you typed.

## The UI kit

The panel is built on the shared UI kit of the kalinewb plugins,
`omarchy-ui` (Kalinewb/omarchy-ui): rows, a stepper, buttons,
tips and one Esc handler, in the notch's own colours (every one an opaque solid,
as the surface contract asks), the one spacing scale and three text levels.
**There are no external dependencies at run time**: `ui/` is vendored from
omarchy-ui, copied in whole by `dev/sync-ui.sh`, hashed in `ui/KIT` and never
edited here (a fix goes to omarchy-ui and comes back through a re-sync).
`Corners.qml`, the service that draws the corners, does not use it.

**Reduced motion.** `OMARCHY_REDUCED_MOTION=1` in the environment turns reduced
motion on; `NOTCH_REDUCED_MOTION=1` is an alias that the notch and the kit both
read; a host may provide `reducedMotion` instead. (`OMARCHY_` is only a prefix:
it is not an Omarchy variable, and omarchy-ui's README is its one definition.)
When on, springs are off, `press` and `stagger` are off, fades stay and loops
stop on their final frame. The panel has no loops of its own.

## Without the notch

The notch is optional and nothing depends on it. Under another bar, or with the
notch removed or its integration switched off in Settings → Integrations, the
plugin is only the overlays and `oled-corners.json`: no extra files, and no
panel. `omarchy-shell oled-corners settings` answers `no-host` and does
nothing. The notch is detected from the
small heartbeat file it keeps in `$XDG_RUNTIME_DIR/kalinewb.notch/` (read only);
the plugin asks the host for its panel and never installs, enables or changes
anything on the host.

The integration follows the notch's
[surface contract](https://github.com/Kalinewb/omarchy-notch/blob/master/SURFACE-HOSTING.md),
version 1: `Surface.qml` is declared in the manifest and draws no window of its
own.

## Development

Nothing here is needed to run the plugin. Everything is offscreen; nothing is
installed or reloaded.

```bash
./dev/test.sh                       # lint, radius.js, the panel's zone and keys, the UI gate and its walk
./dev/check-ui.sh --score --walk CornersPanel.qml
./dev/render.sh --all /tmp/corners-screens  # the panel on a stand-in host, black and white, and standalone
../omarchy-ui/dev/sync-ui.sh --from ../omarchy-ui --to . --tools --only UClose,UButton,UNotice,URow,USection,UStepper,UKeys
```

## Compatibility

Omarchy Quattro (`omarchy-shell`, Quickshell) on Hyprland. Nothing else is required.

## License

MIT
