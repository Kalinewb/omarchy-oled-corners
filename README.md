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

```bash
omarchy plugin add https://github.com/Kalinewb/omarchy-oled-corners.git
omarchy plugin enable graveklar.oled-corners
```

Plugins land disabled so you can read the code first — it's one QML file.

To remove:

```bash
omarchy plugin remove graveklar.oled-corners
```

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

## License

MIT
