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

## Levels

`game/game.tscn` is a host, not a room: it owns the player, camera, HUD, fade
and pause menu, and swaps one `Level` child underneath them. A level owns only
its own tiles, props and spawn markers, and answers two questions - `bounds()`
for the camera limits and `spawn_position(name)` for where to stand. Nothing in
game.gd names a specific map beyond `START_LEVEL`.

- `game/levels/level.gd` - base script every level scene runs
- `game/levels/<biome>/` - the scene plus that biome's tileset and column art
- `game/props/<name>/` - anything you place *in* a map, shared across biomes:
  - `door/` - walk-in Area2D; it only emits `travelled`, game.gd does the swap
  - `column/` - pillar prop, origin at its foot so Y-sorting works

`props/` is a peer of `levels/`, not a child of it, for the same reason enemies
will be: a prop is placed in a map, it is not part of the map system. Biome
skins for a shared prop (`door_marble.tres`) stay beside the prop rather than in
the level that uses them - which level consumes which skin flips whenever CHAIN
is reordered, and files should not move when that happens.

Doors are found through the `door` group and levels are typed via `preload`
rather than by `class_name`: global class names live in an editor-written cache
that a fresh checkout running headless does not have yet.

Adding a biome: add it to `BIOMES` in build_biomes.gd, then to `LEVELS` and
`CHAIN` in build_levels.gd. `CHAIN` order is what each door points at, wrapping
at the end.

## Generated resources - regenerate, don't hand-edit

- `ui/theme/menu_theme.tres`        <- tools/build_ui_theme.gd
- `game/player/character.png`       <- tools/build_character_sheet.gd
- `game/player/player_frames.tres`  <- tools/build_player_frames.gd
- `game/levels/*/[biome]_tileset.tres`, `*_column.tres`,
  `game/props/door/door_*.tres`     <- tools/build_biomes.gd
- project settings & input map      <- tools/setup_project.gd

Run: `<godot> --headless --path . --script res://tools/<script>.gd`

Biome art is palette-swapped from `assets/tiles/dungeon.png`. Only a handful of
tiles in that sheet are modular - the rest are pre-composed room motifs that do
not repeat - so build_biomes.gd copies the verified-seamless ones by coordinate
and draws columns and doors itself. Its textures are embedded in the `.tres` as
`PortableCompressedTexture2D` rather than written out as PNGs, so a regenerated
biome works headless immediately with no `--import` pass.

`tools/build_levels.gd` is the exception to "regenerate": the level scenes it
writes are a starting point meant to be dressed by hand in the editor, and
re-running it overwrites that work. Run it to reset a level or to add a new one.

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

## Testing

- `tests/` holds SceneTree-script tests: no framework, no dependencies.
  They drive the real game with synthesized input and exit 0/1.
- Run the smoke test after any change to scenes, input, or scene flow:
  `<godot> --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd`
- When synthesizing key events set BOTH `keycode` and `physical_keycode`
  (custom actions match physical, built-in ui_* match keycode).
- Level checks read the swapped-in child through `has_method("spawn_position")`
  rather than by class, for the same class-cache reason as game.gd. Leave slack
  around a door transition: two fades plus travel is ~40 frames.
- Split into `tests/test_<area>.gd` files when smoke_test.gd gets slow or
  crowded. Adopt gdUnit4 only once there is real unit-testable logic
  (damage math, inventory, save data) - not for scene wiring.
- `tests/` and `tools/` must be excluded from export presets when we set
  up exports.
