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
- Radius follows Hyprland's `decoration:rounding` by default, so the screen
  corners match your window corners and change when your theme or config does.

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

Entirely optional. Without a config file the radius tracks
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
| `radius`   | Corner radius in logical pixels. Omit it to follow `decoration:rounding`. |
| `color`    | Any Qt color string. Defaults to `#000000`.                              |
| `monitors` | Per-output radius overrides, keyed by Hyprland output name (`hyprctl monitors`). A `0` turns corners off for that display. |

The file is watched — edits apply immediately, no restart.

## Settings panel (optional, needs the notch)

If you run the [Notch](https://github.com/Kalinewb/omarchy-notch) as your bar,
OLED Corners offers it a settings panel that opens **inside the notch**, in the
notch's own colours and corner radius. It lists "All monitors" and one row per
screen:

| Key        | What it does                                                        |
|------------|---------------------------------------------------------------------|
| `←` / `→`  | Radius down / up by one pixel (also the `−` and `+` buttons)        |
| `F` or `⌫` | **Follow**: hand the row back to the level above it                 |
| `↑` / `↓`  | Pick a row                                                          |
| `Esc`      | Close                                                               |

A row set to **Follow** shows what it will use, for example `Follow · 22 px`.

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
4. Hyprland's `decoration:rounding`.

So **Follow** on a row falls back to your file and Hyprland, and deleting
`panel.json` puts everything back the way your file says. If `panel.json` is
not valid JSON the panel says so and refuses to write rather than overwrite
what you typed.

## Without the notch

The notch is optional and nothing depends on it. Under another bar, or with the
notch removed or its integration switched off in Settings → Integrations, the
plugin is exactly OLED Corners 1.0.1: the same overlays, the same
`oled-corners.json`, no extra files, and no panel. `omarchy-shell oled-corners
settings` answers `no-host` and does nothing. The notch is detected from the
small heartbeat file it keeps in `$XDG_RUNTIME_DIR/kalinewb.notch/` (read only);
the plugin asks the host for its panel and never installs, enables or changes
anything on the host.

The integration follows the notch's
[surface contract](https://github.com/Kalinewb/omarchy-notch/blob/master/SURFACE-HOSTING.md),
version 1: `Surface.qml` is declared in the manifest and draws no window of its
own.

## Compatibility

Omarchy Quattro (`omarchy-shell`, Quickshell) on Hyprland. Nothing else is required.

## License

MIT
