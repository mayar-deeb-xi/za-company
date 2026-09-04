# za-company

Godot 4.7 top-down 2D pixel-art game (GL Compatibility renderer, 640x360 base
viewport, 1x camera zoom, pixel snapping on).

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
for how much world there is and `spawn_position(name)` for where to stand.
Nothing in game.gd names a specific map beyond `START_LEVEL`.

The camera lives on game.tscn, not on the player, and game.gd decides per axis:
it follows the player where the level is bigger than the screen, and centres on
the level where it already fits, showing the room whole. Camera2D's own limits
are deliberately unused - they cannot express the second case, and asked to keep
a 544 px room inside a 640 px view they contradict themselves and jam the camera
against one edge. At zoom 1 the base viewport is 640x360, so a level up to that
size is seen entire, and the screen left over around a smaller room is void.
That void is deliberate - filling it with the level's own rock was tried and
looked worse than black.

**A level owns everything in it.** Its folder holds its own tileset, its own
column and doorway art, and its own `column.tscn` and `door.tscn` - no level
borrows another's. Levels are meant to diverge: different styles, different
props, different enemies, doors that lock.

```
game/levels/
  level.gd            base script every level scene runs
  door_base.gd        shared: how a door tells game.gd to swap levels
  hazard_base.gd      shared: presses take_damage() on the player it overlaps
  pickup_base.gd      shared: heal() on touch, consumed only if it healed
  <biome>/
    <biome>.tscn  door.tscn  column.tscn  torch.tscn  health_item.tscn
    tileset.tres  column_art.tres  torch_art.tres  health_art.tres
    doorway_out.tres  doorway_back.tres
```

The `_base.gd` scripts are shared because each is one side of a handshake the
other party owns: game.gd performs the swap doors report, and the player owns
the take_damage()/heal() API hazards and pickups press. Everything else about a
door, torch or heart is the level's: override `can_travel()` in a level's own
script for a lock, or restructure that level's scenes freely. A column has no
shared behaviour at all and carries no script.

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

## Characters

Play goes menu -> `ui/character_select/` -> game. Every character shares the
same body and animation set; the differences are cosmetic (hair, clothes, eyes)
plus at most a one-pixel build tweak, all palette-swapped from the CC0 sheet in
`game/player/src/` the way biome art is swapped from the dungeon sheet.

The cast sharing one sheet is deliberate and permanent - they all play the same
game with the same moves, so a new animation drawn once should land on all seven
at no cost. **Enemies deliberately do NOT work this way**: each owns its own
sheet, because each is heading somewhere different. See Enemies.

`game/player/characters/roster.gd` is the single source of truth: id, display
name, frames path, and the `recipe` tools/build_characters.gd bakes into that
character's `<id>_frames.tres` (textures embedded as
PortableCompressedTexture2D, so a rebuild works headless with no --import).
Mayar's frames double as the player scene's default look. Adding a character:
one roster entry, run build_characters.gd; the select screen builds its
portraits from the roster at runtime.

The choice is saved through `Settings` (section `player`, key `character`) only
when the player actually picks someone, and player.gd swaps its SpriteFrames to
match on `_ready`; an unknown saved id keeps the default look.

## Health

The player owns its health (player.gd): `MAX_HEALTH`, `take_damage()`,
`drain()`, `heal()`, `apply_slow()`, and a grace window after each hit during
which the sprite blinks and further damage is ignored. Hazards, pickups and
enemies reach the player by the `player` group + `has_method`, never by type.

**Three ways the world reaches the player, and the splits between them are the
thing to get right.** A *blow* (`take_damage()`) is metered by the grace window
and opens a fresh one.
That window is the only rate limiter for blows anywhere in the game, so hazards
and melee enemies press it every physics frame they overlap the player, carry
no timers of their own, and all retune together from `HURT_GRACE_SECONDS`. A
*drain* (`drain()`) is continuous harm that already knows its own rate - an
aura, a poison - and sits outside the grace window in both directions: never
blocked by one, never opens one. Routing a drain through `take_damage()` is the
obvious first move and is wrong twice over: an unrelated torch clip would
swallow a second of it, and the sprite would blink as though the player were
being struck once a second. Both funnel into `_lose_health()`, so death fires
identically whichever killed you.

A *status* (`apply_slow()`) is the third thing: not harm that happens and is
over in the same frame, but something the player **carries** and that expires on
its own. Outside the grace window for the same reason a drain is. Statuses are
read off two public vars (`slow_factor`, `slow_seconds`) so a HUD icon can
render one later without new API; they refresh rather than compound - the
strongest in force wins and the timer extends, so two wardens keep you slow for
longer but never make you slower; `MIN_SLOW_FACTOR` floors how far any
combination can reach; and `revive()` clears them, because respawning into a
room still crippled by whatever killed you is a second punishment for one
death. Freeze and push land here when they come - the shape is meant to take
them. A slow scales the walk animation as well as the speed, since a slowed walk
played at full rate reads as skating, but deliberately not the swing: it takes
your legs, not your sword.

The player also owns its lives (`MAX_LIVES`, 3): each death spends one via
`lose_life()`, whose return value lets game.gd choose respawn or game over from
one call instead of racing a second signal. With lives left, death fades back
to the current level's `start` spawn at full health - losing a room. The last
death raises the pause overlay as a death screen (`show_game_over()`): heading
YOU DIED, CONTINUE disabled, Escape swallowed (nothing to resume back into),
the room frozen and visible behind the dim. MAIN MENU and QUIT are the only
exits, and a new run instantiates a fresh player, so lives reset by
construction.

The HUD (`ui/hud/`, instanced by game.tscn) is deliberately dumb: game.gd wires
`health_changed`/`lives_changed` to it and pushes starting values, and it
renders whatever it is fed - a bar with a percentage label, plus one heart icon
per possible life (spent ones dim rather than vanish, so max lives stays
readable). HUD heart icons are drawn at runtime in hud.gd from the same 9x8
mask as build_biomes.gd's heal pickup - kept in step by hand. Since game.tscn
never re-instantiates the player, health and lives carry across door
transitions for free; and since levels ARE re-instantiated, a consumed heal
pickup is back on the next visit - rooms keep no state yet.

Each level places one torch (on `hazard_base.gd`, hurts on touch) and one heart
(on `pickup_base.gd`, heals on touch, stays if you are full). Their art comes
from build_biomes.gd like everything else: the stand and plinth in the biome's
own ramp, the flame and the heart in fixed colours, because fire and health
have to read the same in every biome.

## Enemies

`game/enemies/enemy_base.gd` is the base every type builds on: an enemy stands
guard until the player comes within `sight_radius`, closes the ground to
`stop_distance` and holds there facing them, and presses its touch on the
player every physics frame of contact - no timers of its own, the player's
grace window meters the pressure, exactly like hazards. Stats (`max_health`,
`contact_damage`, `speed`, `sight_radius`, `stop_distance`) are @exports, so a
level can retune the instance it places. Enemies find the player by group +
`has_method`, doors ignore them (door_base.gd filters on the `player` group),
and each type lives in `game/enemies/<type>/`.

**An arrived enemy stops rather than keeps pressing.** Driving on into the
player buys no ground - two CharacterBody2Ds block at the sum of their radii,
10 px for everything so far - it only grinds the bodies together and slides the
enemy around the player in a circle. `stop_distance` (12) is bounded on both
sides and the second bound is the easy one to break when adding a type: it must
exceed those 10 px or the enemy never stops short of the grind, and stay under
the reach of that type's own Touch shape (its radius + the player's 5) or the
enemy parks just outside its own effect and nothing ever happens. The regular's
touch radius is 9 for exactly this reason - at the original 7 it reached 12 and
tied with the stop distance. `walk` also now plays only while actually
advancing, so a held enemy does not moonwalk on the spot.

**`_touch(player, delta)` is the seam between enemy types.** The base deals
`contact_damage`; a type that freezes, shoves or drains overrides `_touch()` in
its own script extending the base, and inherits chase, health and death
untouched. `delta` is that frame's worth of contact, which is what any effect
with a rate of its own needs. Two smaller seams travel with it, because an
effect is rarely only damage: `_contact_state()` is what contact looks like (the
base lunges, the others stand), `_resting_tint()` is how the enemy reads while
it works, and `_can_advance()` lets a type root itself while it winds up. The
base resolves `modulate` in one place after `_touch()` has run, with the hurt
flash outranking whatever a type wants, and sets `touching_player` first so an
override can read it.

Three types so far, and they deliberately threaten in three different ways -
damage, drain, and denial - so a room is built by mixing them rather than by
adding more of the same:

- **`regular/`** - 10 HP, 5 contact damage, speed 55, sight 80. Carries no
  script of its own: its scene runs enemy_base.gd directly, the way torches run
  hazard_base.gd.
- **`wraith/`** - 10 HP, no attack at all, speed 45, sight 120, and standing
  near it costs one health per second. It is the reason `drain()` exists (see
  Health). Its `_contact_state()` is `idle`: having arrived it has no attack to
  play and nowhere left to walk, so it just stands over you facing your way
  while your health goes, which reads worse than a lunge would. The aura is
  just the Touch area tuned wide, because "near you" and "touching you" are the
  same question and the base already answers it; the
  fractional remainder (`_owed`) is deliberately kept when contact breaks, so
  dancing on the edge of the aura cannot reset the tick. It glows cold while
  feeding so the health ticking down has a visible cause. Being one of the cast
  drained of colour - straight hair, normal build, white on dark blue - is the
  point of the look: it reads as a person, not a monster.
- **`warden/`** - 10 HP, no damage of any kind, speed 50, sight 130, a 48 px
  area, and a 2-second wind-up that slows everyone still inside to half speed
  for 4. It is pure area denial: harmless alone, and the reason the guards and
  the wraith in hellfire are dangerous. Its `_touch()` is deliberately empty -
  what its area costs you is settled by the wind-up, not by the frame-by-frame
  contact the base meters.

  Three things about it are load-bearing. It **plants at the rim** of its area
  rather than in your face, and that falls out of `_can_advance()` returning
  `not touching_player` rather than being a second rule: contact is what roots
  it, so it stops the moment it has you. That keeps it clear of your sword and
  makes killing it a decision to walk into the thing about to slow you.
  Leaving **resets** the wind-up rather than pausing it, so the counterplay is
  to move and a warden you step in and out of never lands an effect it did not
  hold you for the full two seconds. And it **tints toward violet in proportion
  to the charge**, because the counter is only a choice if you can see it
  coming.

  The wind-up is counted in its own `_physics_process` after `super()`, NOT in
  `_touch()`: the base calls `_touch()` once per body in range, so a wind-up
  counted there would fill twice as fast with two players in the area. After
  `super()` the base has settled `touching_player` for the frame, and one read
  covers however many are standing in it.

The player's side of the fight is `ATTACK_POWER` (5, player.gd) pressed through
a Hitbox Area2D that `_start_attack()` parks one step ahead of the body in the
facing direction. The hitbox stays live for the whole swing animation but a
ledger (`_swing_hits`) lands it once per enemy per swing - so a 10 HP regular
dies to exactly two swings. Per-character health and attack stats are planned;
they will join the roster recipe the way looks did.

**Every enemy owns its sprite sheet**, and this is the one place enemies and the
cast are deliberately organised differently. The seven characters share
`game/player/src/character_cc0.png` forever: they play the same game with the
same moves, so a new animation drawn once should land on all seven. Enemies are
the opposite - each is heading somewhere different, and a shared sheet would
pile every enemy's future moves into one file. So each has
`game/enemies/<id>/src/<id>.png` of its own.

`tools/build_enemies.gd` is **seed once, slice always**:

- *Seeding* writes that PNG, and only ever when it is missing - a recipe
  recolours the CC0 body so a new enemy has something to walk around as on day
  one. It is a starting point, exactly like the level scenes build_levels.gd
  writes.
- *Slicing* runs every time, on whatever sheet is actually on disk.

From the moment the PNG exists it is hand-owned art. Draw a new animation into
one enemy's sheet, re-run the tool, and only that enemy's frames change - the
recipe never touches it again. Deleting an enemy's PNG and rebuilding is how you
start its art over from the plain body. An enemy whose sheet grows rows the CC0
grid does not have adds a `layout` (and `specs`) to its roster entry; the
default lives in tools/character_art.gd, which is the shaping and slicing engine
both generators share.

A dead enemy is `queue_free`d, and since levels are re-instantiated per entry,
it is back on the next visit - the same no-room-state rule as pickups.

Enemies are the one prop a level does NOT own a copy of - types are shared, and
**which ones a room gets is per-biome data in `tools/biomes.gd`** (`enemies`:
type + position), not one constant in the generator. Composition is most of
what makes one room feel unlike the next: the marble hall is two guards you can
walk past, and hellfire is the same two plus the wraith and the warden, which is
where things start following you and taking your legs. Positions are chosen so
no enemy's sight reaches the door line, the spawns or the torch and heart stands
- the straight walk between the two doors stays safe in every biome, and the
smoke test's early sections depend on nothing aggroing until the combat run
deliberately walks into range. The warden's 130 px is the longest look in the
game and every walkable line in the marble hall falls inside it, which is the
reason that room has none.

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
- `game/levels/*/tileset.tres`, `column_art.tres`, `torch_art.tres`,
  `health_art.tres`, `doorway_out.tres`, `doorway_back.tres`
                                    <- tools/build_biomes.gd
- `game/levels/*/*.tscn` (level, door, column, torch, health item;
  enemy instances placed in the level scene)
                                    <- tools/build_levels.gd, see below
- biome list, chain order, per-room enemies
                                    <- tools/biomes.gd (data, edited by hand)
- project settings & input map      <- tools/setup_project.gd

Run: `<godot> --headless --path . --script res://tools/<script>.gd`

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
level scene and that level's own door, column, torch and health item scenes -
is a starting point meant to be dressed by hand in the editor, and re-running
it overwrites that work. Run it to reset a level or to add a new one. The door
scenes are already dressed: their trigger sits at y=13, snug against the seal,
where the generator still writes 38 - regenerate a door and that tuning is
gone.

## Settings

Two autoloads, split by responsibility:

- `autoload/settings.gd` (`Settings`) owns `user://settings.cfg` and nothing
  else - sections, keys, write-through on change. A future audio or controls
  page adds a section without this script learning about it.
- `autoload/display.gd` (`Display`) applies window mode and windowed size, and
  persists through Settings. Every window change goes through it, F11 included,
  so a hotkey press is remembered exactly like a menu choice.

`Settings` must stay registered **before** `Display` - display.gd reads its
saved values during `_ready`. tools/setup_project.gd clears the Display entry
before re-adding it, which is what enforces that order.

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
and the smoke test measures it so a fourth row cannot quietly overflow.

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
- Autoloads are NOT identifiers in the script passed to `--script` - that file
  is compiled before the autoload list reaches the compiler. Reach them with
  `root.get_node("/root/Settings")` and `call()`. Ordinary game scripts, loaded
  later as part of a scene, use the names normally.
- Anything touching `user://` must put it back. The smoke test backs up
  `settings.cfg` before it starts, clears it so the run is a clean install, and
  restores it at the end - so running tests never changes how the developer's
  own game opens, and their own saved zoom never decides whether a check about
  framing passes.
- Setting `current_scene` is NOT enough to make `/root/<Autoload>` resolvable;
  it works from `_process`, not from `_initialize`, and the null that comes
  back there fails quietly enough to look like a logic bug.
- `OptionButton.select()` does not emit `item_selected`; simulate a click by
  emitting it too, or the handler never runs.
- Split into `tests/test_<area>.gd` files when smoke_test.gd gets slow or
  crowded. Adopt gdUnit4 only once there is real unit-testable logic
  (damage math, inventory, save data) - not for scene wiring.
- `tests/` and `tools/` must be excluded from export presets when we set
  up exports.
