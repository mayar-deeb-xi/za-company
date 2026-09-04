# za-company

Godot 4.7 top-down 2D pixel-art game (GL Compatibility renderer, 640x360 base
viewport, 1x camera zoom, pixel snapping on).

The game being built is THE NEW HIRE — see `DESIGN.md` for the content plan
(story, floors, enemy reskins, NPCs, bosses, ending) and its build-order
checklist. This file says HOW things work; DESIGN.md says WHAT to build.

## Structure: feature folders + shared pools

- `ui/<screen>/` - one folder per screen; scene + script together
- `game/` - gameplay; `game/<entity>/` owns its scene, script, art, frames
- `assets/` - ONLY files shared across features (fonts, tilesets, audio), plus
  source art no feature owns yet; it moves into the feature that claims it
- `autoload/` - global singletons registered in project.godot
- `tools/` - editor-side generator scripts run headless; never game code
- `addons/` - editor plugins, and there is one: `za_build`, which puts the
  `tools/` generators on the Project > Tools menu (see Workflow)

Placement rules:
1. A file lives with the feature that owns it. Scripts sit next to their
   scenes with the same basename (`player.tscn` + `player.gd`).
2. The moment a second feature needs a file, it bubbles up one level above
   the features that share it (enemy_base.gd at enemies/, theme at ui/theme/).
3. snake_case for every file and folder. `addons/` stays reserved for plugins.
4. Don't pre-create empty folders - create one when its first real file exists.

**Deep documentation lives with its subject**, in nested CLAUDE.md files that
load when files there are touched: `game/levels/CLAUDE.md` (the host, the
camera, room anatomy, doors and spawns), `game/enemies/CLAUDE.md` (the attack
cycle, the types, the enemy art pipeline), `game/player/CLAUDE.md` (characters,
health, the combo and the heavy) and `tools/CLAUDE.md` (furnishing rooms from
data, the prop catalogue, adding a floor). This file keeps what must be known
BEFORE touching anything: the maps, the invariants and the gotchas.

## Levels

`game/game.tscn` is a host, not a room: it owns the player, camera, HUD, fade
and pause menu, and swaps one `Level` child underneath them. A level owns only
its own tiles, props and spawn markers, and answers three questions -
`bounds()` for how much world there is, `spawn_position(name)` for where to
stand, and `title()` for what to call itself. Nothing in game.gd names a
specific map beyond `START_LEVEL`.

**A level owns everything in it**: its own tileset, doorway art, `door.tscn`
and its own copy of every prop it places, palette baked in - no level borrows
another's. Everything standing in a room lives in its `props/`, on the same
shelves as the painters in `tools/props/` (`fixtures/`, `furniture/`,
`hardware/`, `markings/`, `openings/`, `signs/`); the fixtures shelf is named
by ROLE, so hazard.gd paints `torch.tscn` and heart.gd paints
`health_item.tscn`.

**A room is furnished from data, not by hand**: a floor's palette, furniture
and enemies are one hand-edited file, `tools/biomes/<level>.gd`, so
`build_levels.gd -- lobby` reproduces the dressed room rather than resetting
it. What a re-run DOES overwrite is anything hand-nudged in the editor - prefer
moving positions into biomes data over nudging scenes.

Levels are re-instantiated per entry: a consumed pickup or a dead enemy is back
on the next visit - rooms keep no state yet. Doors are found through the `door`
group and levels are typed via `preload`, never `class_name`: global class
names live in an editor-written cache a fresh headless checkout does not have.

Adding a floor is a data file in `tools/biomes/` plus a `CHAIN` entry;
**inserting** one mid-chain also stales its NEIGHBOURS' baked door targets -
rebuild all three: `build_levels.gd -- <before> <new> <after>`. The full
recipe is in tools/CLAUDE.md; room anatomy in game/levels/CLAUDE.md.

## Characters and the player

Every playable character shares one body, one animation set and one sheet
(`game/player/src/character_cc0.png`) forever - a new animation drawn once
lands on all seven. `game/player/characters/roster.gd` is the single source of
truth; adding a character is one sheet row plus one roster entry, then
build_characters.gd. Enemies deliberately do NOT share a sheet - each owns its
own, seeded once from a frozen body copy (see game/enemies/CLAUDE.md).

The player owns its health and its lives (`MAX_LIVES` 3). **Three ways the
world reaches it, and the splits are the thing to get right**: a *blow*
(`take_damage()`) is metered by the grace window and opens one - that window is
per-difficulty and is secretly the CROWD dial; a *drain* (`drain()`) knows its
own rate and sits outside the window in both directions - never blocked by one,
never opens one; a *status* (`apply_slow()`) is something the player carries
that expires on its own, refreshing rather than compounding. Everything reaches
the player by the `player` group + `has_method`, never by type. Full rationale,
the HUD, the combo and the heavy: game/player/CLAUDE.md.

## Enemies

`game/enemies/enemy_base.gd` runs every type: stand guard, close to
`stop_distance`, and hurt by FINISHING an attack (CHASE -> WINDUP -> STRIKE ->
RECOVER), never by mere contact. Damage interrupts a wind-up, bounded by
`commit_fraction` and `interrupt_cooldown`; the player is deliberately not
interruptible in return.

**Enemy HP (24 / 17 / 36) are exact breakpoints on the player's combo** -
"dies in exactly N hits" - and `HEAVY_POWER` equals a guard's health by design.
Never retune one side without the other, and difficulty must never scale any of
them. A reskin (`office_boy`) is a new sheet, name and folder with the base's
numbers and no script - nothing else, or the interrupt tuning breaks.

Which enemies a room gets is per-biome data (type + position), and positions
keep every sight radius clear of the door line, spawns and both stands - the
straight walk between the doors stays safe in every biome, and the flow and
combat tests depend on it. Types, seams, tuning and the art pipeline:
game/enemies/CLAUDE.md.

## Generated resources - regenerate, don't hand-edit

- `ui/theme/menu_theme.tres`        <- tools/build_ui_theme.gd
- `game/player/characters/*_frames.tres`
                                    <- tools/build_characters.gd
- `game/enemies/*/*_frames.tres`    <- tools/build_enemies.gd, see below
- sheet shaping & slicing engine    <- tools/character_art.gd (shared by both)
- playable cast & recipes           <- game/player/characters/roster.gd
                                       (data, edited by hand)
- bestiary, sheet paths & seed recipes
                                    <- game/enemies/roster.gd
                                       (data, edited by hand)
- `game/levels/*/tileset.tres`, `doorway_out.tres`, `doorway_back.tres`
                                    <- tools/build_biomes.gd (the ROOM's art,
                                       and the only art that is a file)
- `game/levels/*/<biome>.tscn`, `door.tscn`, `props/<shelf>/*.tscn` (art
  embedded in each; enemy and prop instances placed in the level scene)
                                    <- tools/build_levels.gd, see below
- every picture of a thing standing in a room
                                    <- tools/props/<shelf>/<type>.gd, one file
                                       per prop shelved by kind (furniture/,
                                       hardware/, signs/, markings/,
                                       openings/, fixtures/);
                                       tools/props.gd is the facade that finds
                                       them BY FILENAME across the shelves,
                                       and _brush.gd is the shared painting
                                       kit + pixel font
- chain order + per-floor helpers   <- tools/biomes.gd
- each floor's palette, furniture and enemies
                                    <- tools/biomes/<level>.gd, one data file
                                       per floor (edited by hand)
- project settings & input map      <- tools/setup_project.gd
- stable ids in regenerated files   <- tools/stable_ids.gd (both level
                                       generators call it around every save,
                                       so a re-run with unchanged data is a
                                       byte-identical file; run it alone to
                                       normalize scenes without regenerating)

Run: `<godot> --headless --path . --script res://tools/<script>.gd` - or, from
inside the editor, **Project > Tools > za-build**, which is the same commands
behind menu items (`addons/za_build/`, see Workflow).

Biome art is palette-swapped from `assets/tiles/dungeon.png`. Only a handful of
tiles in that sheet are modular - the rest are pre-composed room motifs that do
not repeat - so build_biomes.gd copies the verified-seamless ones by coordinate
and draws columns and doorways itself. Its textures are embedded in the `.tres`
as `PortableCompressedTexture2D` rather than written out as PNGs, so a
regenerated biome works headless immediately with no `--import` pass.

`tools/build_enemies.gd` is a partial exception: the `_frames.tres` it writes
are regenerate-freely, but `game/enemies/<id>/src/<id>.png` is hand-owned art it
only ever creates when missing. It will not overwrite a sheet you have drawn
into.

`tools/build_levels.gd` is the exception to "regenerate": what it writes - the
level scene and that level's own door, plus - where its biome asks for them -
its column, hazard and heart scenes - is a starting point meant to be dressed by
hand in the editor, and re-running it overwrites that work. Run it to reset a
level or to add a new one, and pass level names after `--` to build only those,
because a chain of twelve means adding a floor must not re-roll the eleven already
dressed:

```
<godot> --headless --path . --script res://tools/build_levels.gd -- lobby
```

The door trigger's hand-tuned y=13, snug against the seal, is now what the
generator writes, so regenerating a door no longer silently undoes it.

Anything a level is dressed with that CAN be expressed as data should be, for
the same reason: enemies and furniture both live in tools/biomes.gd, so
re-running the generator rebuilds a dressed room instead of resetting it. The
warning above is about what is left - tiles moved by hand, a prop nudged in the
inspector - and every position that moves out of the editor and into biomes.gd
is one less thing a regeneration can cost you.

## Difficulty

Three modes - EASY / MEDIUM / HARD - picked by one cycling MODE button on the
main menu (a separate screen was not worth a three-way choice; the label always
says where you are). The choice persists through Settings (section `game`, key
`difficulty`), default MEDIUM, applied-but-never-saved like every default.

`autoload/difficulty.gd` (`Difficulty`) owns the modes and their numbers.
**Difficulty scales what the world deals, never enemy health**: the HP numbers
(24 / 17 / 36) are exact breakpoints on the player's combo - four hits, three,
six, heavy one-shot - and a multiplier would shred them on two of three modes.
So a guard dies identically on every mode; the modes change what being slow
costs you. Two dials per mode:

- `damage_scale` (0.6 / 1.0 / 1.5) multiplies every blow and drain - guard
  strikes, torches, wraith drain.
- `grace_seconds` (0.8 / 0.65 / 0.5) is the player's grace window, i.e. the
  crowd dial - see game/player/CLAUDE.md's Health.

Consumers read their numbers ONCE, where they spawn, never live - the mode is
only choosable at the main menu, a new run builds a fresh player and fresh
rooms, so there is no mid-fight rescaling and deliberately no `changed` signal.
MEDIUM is the tuned baseline; every number in enemy scenes and in these docs is
a MEDIUM number.

## Settings

Three autoloads, split by responsibility:

- `autoload/settings.gd` (`Settings`) owns `user://settings.cfg` and nothing
  else - sections, keys, write-through on change. A future audio or controls
  page adds a section without this script learning about it.
- `autoload/display.gd` (`Display`) applies window mode and windowed size, and
  persists through Settings. Every window change goes through it, F11 included,
  so a hotkey press is remembered exactly like a menu choice.
- `autoload/difficulty.gd` (`Difficulty`) owns the game modes - see Difficulty.

`Settings` must stay registered **before** the other two - both read their
saved values during `_ready`. tools/setup_project.gd clears their entries
before re-adding them, which is what enforces that order.

**A default is applied but never saved.** Nothing is written until the player
actually picks something, so an untouched install keeps launching the way
project.godot says - and no headless run can quietly change that.

`ui/settings/settings_panel.tscn` is one overlay instanced by both the main menu
and the pause menu, rather than a screen of its own: the pause menu cannot leave
the scene, since the paused game is still sitting behind it. It runs
`PROCESS_MODE_ALWAYS` for the same reason. Escape backs out one step - both
menus skip their own Escape handling while the panel is open, and the panel
marks the event handled so the press cannot also unpause.

The page has three rows, and the split between the last two is the thing to get
right - it is the one players get wrong:

- **WINDOW MODE** - windowed or fullscreen.
- **WINDOW SIZE** - deliberately not called a resolution. The game always
  renders at the 640x360 base viewport, so the window only decides how many
  screen pixels one game pixel becomes. Choices are whole multiples of the base
  (`Display.SCALES`), each labelled with its factor; at a fractional scale like
  2.5x some pixels land on three screen pixels and their neighbours on two, and
  the image crawls as the camera moves. Greys out in fullscreen rather than
  pretending to have an effect, while still remembering the choice.
- **ZOOM** - the one that changes *how much of the level is on screen*
  (`Display.ZOOMS`). At 1 a whole room fits and the camera sits still; above
  that the camera follows the player. Shown as a **percentage** - 100% / 125% /
  150% / 200% / 300% / 400% - which is the convention where a game exposes zoom
  at all, and the only labelling that stays true. Names for the result were
  tried and dropped: "WHOLE ROOM" describes the zoom against the size of the
  room the player is standing in, so it becomes a lie the first time a level is
  bigger than the screen, and word ladders like ALMOST WHOLE / MOST OF ROOM do
  not tell a player which way is further. Percent describes the one thing the
  setting controls. The labels are derived from `ZOOMS` by
  `settings_panel._zoom_label()`, so adding a level is one edit.

  1.25 and 1.5 are the deliberate exception to whole numbers, since 1 to 2 is
  otherwise a jump straight from the whole room to a quarter of it. A fractional
  zoom does draw neighbouring source pixels at different sizes; both are
  quarters, so a 16px tile still lands on a whole 20 or 24px and the tile grid
  itself stays even. `Display.zoom()` returns a float and casts on read - a
  settings.cfg written before these existed holds a plain int.

Zoom is stored with the window settings but applied by game.gd, which is what
owns a camera; it re-applies on `Display.changed` and repositions immediately
rather than waiting for `_process`, because the tree is paused while the panel
is open. Two footer lines on the panel state the split outright.

The panel must fit the 640x360 design viewport - it is at 325px with three rows,
and test_menu.gd measures it so a fourth row cannot quietly overflow.

## Workflow

- Godot binary (not on PATH):
  `~/OneDrive/Desktop/Godot_v4.7.2-stable_win64_console.exe`
- Quick check: `--headless --path . --quit-after 3`
- Full import pass: `--headless --import --path .` - ONLY while the editor
  is closed; two editor instances on one project corrupt each other's state.
- The Godot editor is usually open while Claude edits files as text.
  After renames/moves: Project > Reload Current Project. For migrations:
  close the editor first.
- **Project > Tools > za-build** runs the generators without a terminal.
  `addons/za_build/` is the project's one plugin, and every item in it spawns
  a headless child Godot running the same `tools/` script the command line
  would - it does NOT call the generator in the editor's process. That is the
  whole design: build_levels.gd rewrites `.tscn` files the editor may have
  open, and an editor holding a stale copy writes it back over the fresh one,
  which is how a deleted `health_item.tscn` keeps coming back. A child has its
  own resource cache and cannot do it; `scan()` afterwards is what makes the
  editor see the new files. **Close any level scene you have open before
  rebuilding it** - the plugin warns, but it cannot close a tab for you, and
  saving that tab is the failure it is warning about. "Rebuild levels..."
  opens a picker over `CHAIN` with **include neighbours** on by default,
  because a door's `target_level` is baked into the level scene.
- All third-party assets are CC0; sources and licenses live in CREDITS.md -
  update it whenever an asset is added.

## Testing

- `tests/` holds SceneTree-script tests: no framework, no dependencies.
  They drive the real game with synthesized input and exit 0/1. Three suites,
  each extending `tests/helpers.gd` (the shared harness: checks, key synthesis,
  settings backup, node getters) and overriding `_tick(frame)`:
  - `test_menu.gd` - main menu, MODE button + difficulty scaling, character
    select, the settings panel from the main menu. Never enters the game.
  - `test_flow.gd` - select -> game -> movement -> pause -> zoom -> blow ->
    heart -> death -> wall -> doors (a hazard en route) -> lives -> game over.
    It walks the whole chain on foot, so inserting a floor means renumbering
    the frames after the new leg (~80 frames per door) and it asserts each
    room's own composition and dressing as it passes through.
  - `test_combat.gd` - guard telegraph and interrupts, wraith, warden, heavy.
- Run all after any change to scenes, input, or scene flow:
  `<godot> --headless --path . --script res://tests/run_all.gd`
  (or one suite with `--fixed-fps 60 --script res://tests/test_<area>.gd`).
- **One suite = one Godot process = one clean world.** That is the design, not
  a convenience: when everything was one smoke test, each section had to leave
  the game exactly as the next expected, and the failures that produced were in
  the test - a combo's lunge drifting the player out of a later section's
  geometry, an enemy spawned into a still-resolving swing. Keep new checks in
  the suite whose world they need; start a new suite rather than making one
  file's sections depend on each other.
- When synthesizing key events set BOTH `keycode` and `physical_keycode`
  (custom actions match physical, built-in ui_* match keycode).
- Level checks read the swapped-in child through `has_method("spawn_position")`
  rather than by class, for the same class-cache reason as game.gd. Leave slack
  around a door transition: two fades plus travel is ~40 frames.
- Autoloads are NOT identifiers in the script passed to `--script` - that file
  is compiled before the autoload list reaches the compiler. Reach them with
  `root.get_node("/root/Settings")` and `call()`. Ordinary game scripts, loaded
  later as part of a scene, use the names normally.
- Anything touching `user://` must put it back. helpers.gd backs up
  `settings.cfg` before each suite, clears it so the run is a clean install,
  and restores it at the end - so running tests never changes how the
  developer's own game opens, and their own saved zoom never decides whether a
  check about framing passes.
- Setting `current_scene` is NOT enough to make `/root/<Autoload>` resolvable;
  it works from `_process`, not from `_initialize`, and the null that comes
  back there fails quietly enough to look like a logic bug.
- `OptionButton.select()` does not emit `item_selected`; simulate a click by
  emitting it too, or the handler never runs.
- Adopt gdUnit4 only once there is real unit-testable logic beyond what the
  suites cover in passing (inventory, save data) - not for scene wiring, which
  is the hard part here and which no framework drives.
- `tests/`, `tools/` and `addons/` must be excluded from export presets when
  we set up exports. All three are editor-side only; the plugin in `addons/`
  preloads `tools/`, so exporting one without the other breaks the build.
