# za-company

Godot 4.7 top-down 2D pixel-art game (GL Compatibility renderer, 640x360 base
viewport, 2x player camera zoom, pixel snapping on).

## Structure: feature folders + shared pools

- `ui/<screen>/` - one folder per screen; scene + script together
- `game/` - gameplay; `game/<entity>/` owns its scene, script, art, frames
- `assets/` - ONLY files shared across features (fonts, tilesets, audio)
- `autoload/` - global singletons registered in project.godot
- `tools/` - editor-side generator scripts run headless; never game code

Placement rules:
1. A file lives with the feature that owns it. Scripts sit next to their
   scenes with the same basename (`player.tscn` + `player.gd`).
2. The moment a second feature needs a file, it bubbles up one level above
   the features that share it (enemy_base.gd at enemies/, theme at ui/theme/).
3. snake_case for every file and folder. `addons/` stays reserved for plugins.
4. Don't pre-create empty folders - create one when its first real file exists.

## Generated resources - regenerate, don't hand-edit

- `ui/theme/menu_theme.tres`        <- tools/build_ui_theme.gd
- `game/player/player_frames.tres`  <- tools/build_player_frames.gd
- project settings & input map      <- tools/setup_project.gd

Run: `<godot> --headless --path . --script res://tools/<script>.gd`

## Workflow

- Godot binary (not on PATH):
  `~/OneDrive/Desktop/Godot_v4.7.2-stable_win64_console.exe`
- Quick check: `--headless --path . --quit-after 3`
- Full import pass: `--headless --import --path .` - ONLY while the editor
  is closed; two editor instances on one project corrupt each other's state.
- The Godot editor is usually open while Claude edits files as text.
  After renames/moves: Project > Reload Current Project. For migrations:
  close the editor first.
- All third-party assets are CC0; sources and licenses live in CREDITS.md -
  update it whenever an asset is added.
