# za-company

Godot 4.7 top-down 2D pixel-art game (GL Compatibility renderer, 640x360 base
viewport, 2x player camera zoom, pixel snapping on).

## Structure: feature folders + shared pools

- `ui/<screen>/` - one folder per screen; scene + script together
- `game/` - gameplay; `game/<entity>/` owns its scene, script, art, frames
- `assets/` - ONLY files shared across features (fonts, tilesets, audio), plus
  source art no feature owns yet; it moves into the feature that claims it
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

**A level owns everything in it.** Its folder holds its own tileset, its own
column and doorway art, and its own `column.tscn` and `door.tscn` - no level
borrows another's. Levels are meant to diverge: different styles, different
props, different enemies, doors that lock.

```
game/levels/
  level.gd            base script every level scene runs
  door_base.gd        the ONE shared thing: how a door tells game.gd
  <biome>/
    <biome>.tscn  door.tscn  column.tscn
    tileset.tres  column_art.tres  doorway_out.tres  doorway_back.tres
```

`door_base.gd` is shared because game.gd is what performs the swap, so every
door has to report it the same way. Everything else about a door is the level's:
override `can_travel()` in a level's own script for a lock, or restructure that
level's `door.tscn` freely. A column has no shared behaviour at all and carries
no script.

Doors are found through the `door` group and levels are typed via `preload`
rather than by `class_name`: global class names live in an editor-written cache
that a fresh checkout running headless does not have yet.

Each level has a door north to the next in `CHAIN` and a door south to the one
before, so the two ends of the chain have one door instead of two. Doorways sit
in a gap cut through the wall ring; the door scene carries its own `Seal` body
across that gap, so the map stays closed whether or not the transition fires -
and that is the body a locked door will keep. A south door is the same scene
rotated half a turn, which is why the doorway art is directional rather than
mirrored.

Spawns are named for how you arrived: `start` (in from the previous level, by
the south door) and `returned` (back from the next one, by the north door).
Both sit clear of a threshold so arriving never re-triggers the door.

Adding a biome: one edit to `tools/biomes.gd`, then run build_biomes.gd and
build_levels.gd. Appending to `CHAIN` gives the previous last level a north door
automatically.

## Generated resources - regenerate, don't hand-edit

- `ui/theme/menu_theme.tres`        <- tools/build_ui_theme.gd
- `game/player/character.png`       <- tools/build_character_sheet.gd
- `game/player/player_frames.tres`  <- tools/build_player_frames.gd
- `game/levels/*/tileset.tres`, `column_art.tres`,
  `doorway_out.tres`, `doorway_back.tres`
                                    <- tools/build_biomes.gd
- `game/levels/*/*.tscn` (level, door, column)
                                    <- tools/build_levels.gd, see below
- biome list & chain order          <- tools/biomes.gd (data, edited by hand)
- project settings & input map      <- tools/setup_project.gd

Run: `<godot> --headless --path . --script res://tools/<script>.gd`

Biome art is palette-swapped from `assets/tiles/dungeon.png`. Only a handful of
tiles in that sheet are modular - the rest are pre-composed room motifs that do
not repeat - so build_biomes.gd copies the verified-seamless ones by coordinate
and draws columns and doorways itself. Its textures are embedded in the `.tres`
as `PortableCompressedTexture2D` rather than written out as PNGs, so a
regenerated biome works headless immediately with no `--import` pass.

`tools/build_levels.gd` is the exception to "regenerate": what it writes - the
level scene and that level's own door and column scenes - is a starting point
meant to be dressed by hand in the editor, and re-running it overwrites that
work. Run it to reset a level or to add a new one.

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
