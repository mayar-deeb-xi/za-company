# za-company

Godot 4.7 top-down 2D pixel-art game (GL Compatibility renderer, 640x360 base
viewport, 1x camera zoom, pixel snapping on).

The game being built is THE NEW HIRE — see `DESIGN.md` for the content plan
(story, floors, enemy reskins, NPCs, bosses, ending) and its build-order
checklist. This file says HOW things work; DESIGN.md says WHAT to build.

## Structure: feature folders + shared pools

- `ui/<screen>/` - one folder per screen; scene + script together
- `game/` - gameplay; `game/<entity>/` owns its scene, script, art, frames
- `game/bosses/` - the bosses; each owns its scene, script, poses, sheet and
  effects and shares NOTHING with the others but the rules (`boss_base.gd`)
- `game/npcs/` - the friendly faces; each owns its scene and sheet, and they
  share one script (`npc_base.gd`) because none of them fights
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
cycle, the types, the enemy art pipeline), `game/bosses/CLAUDE.md` (multiple
attacks on that cycle, conceding, the poses-painter-fire contract, boss
floors), `game/player/CLAUDE.md` (characters,
health, the combo and the heavy), `game/npcs/CLAUDE.md` (why an NPC is twice
the player's height, the robe, the 64px cell and the ground line),
`game/dialogue/CLAUDE.md` (the beat format, why the runner holds no variables,
the escort, and where audio plugs in) and
`tools/CLAUDE.md` (furnishing rooms from
data, the prop catalogue, adding a floor). This file keeps what must be known
BEFORE touching anything: the maps, the invariants and the gotchas.

## Levels

`game/game.tscn` is a host, not a room: it owns the player, camera, HUD, fade
and pause menu, and swaps one `Level` child underneath them. A level owns only
its own tiles, props and spawn markers, and answers three questions -
`bounds()` for how much world there is, `spawn_position(name)` for where to
stand, and `title()` for what to call itself. Nothing in game.gd names a
specific map beyond `START_LEVEL`.

Its **CanvasLayer stack is now stated rather than defaulted**, because things
below the HUD have started arriving: -1 background, 0 the world, **1 a boss's
own screen effects**, 2 HUD, 5 transition fade, 6 level title. Anything
full-screen a fight draws goes in at 1 - above the room, under the bars, since
a flash that washes out the health bar hides the number the player is reading
while it lands. game.gd also owns **camera shake**, applied as an offset so
`_camera_target()` stays the only thing framing a room; a boss asks for it by
emitting `shook` (see game/bosses/CLAUDE.md).

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
them. A reskin (`office_boy`, `social_media`, `call_center`) is a new sheet,
name and folder with the archetype's numbers and no script - nothing else, or
the interrupt tuning breaks. All six enemies are now three archetypes twice
over, so each archetype's script lives at `game/enemies/` beside
`enemy_base.gd` - `wraith_base.gd` and `warden_base.gd`, plus the two effects
they draw with - and a type's own folder holds only its sheet, frames and
scene.

Bosses (`game/bosses/`) run the same cycle with several attacks and concede
instead of dying; a floor names its boss in `tools/biomes/<level>.gd` under
`boss`, which also shuts that floor's north door until he concedes
(game/levels/boss_door.gd) - except on the last floor, which has no north door
to shut, because build_levels.gd only cuts one where the chain continues. Every boss also gets a HUD bar
(`ui/hud/boss_bar.gd`) without asking for one: game.gd finds him by the
`bosses` group when it builds the room, so a new boss needs no HUD work - and
the same wiring hands him a **camera shake** if he emits `shook`, which is why
`boss_base` declares it and no boss has to implement it. It hands him his
**theme** on those same terms: a boss names a track in `music` on his scene
root and game.gd plays it where it raises his bar and fades it where it clears
it, so a boss floor is the only floor with music and every other floor is
silent without saying so. A boss floor is an
arena: his sight reaching the spawn is the one deliberate exception to the rule
below.

Bosses draw their own effects live from their poses rather than baking them
into a sheet - Ahmed's fire, Mostafa's **Bell** (his punches) and **Rage** (he
catches fire at half health, once, and never comes back down), Silverman's
**Smear**, **Glare**, **Chill** and the **copy** his split casts. Four things
generalize out of them:

- A boss effect that goes full-screen draws at TWO scales and confusing them is
  the trap: a piece of the FRAME (a vignette, a chevron) must be sized as a
  fraction of the viewport, or it is invisible at 640 px wide and changes size
  with the zoom; a thing in the ROOM is world pixels.
- An effect keyed to fixed seconds and an animation keyed to frames agree only
  while every beat is a **frame boundary**. Mostafa's rage has a test that says
  so, because nothing else would notice a retimed `dur` sliding the fire off
  the picture.
- **Fire is per boss on purpose.** The shapes are shared so the game has one
  fire; the RAMP is what says whose it is - Ahmed yellow and amber, Mostafa
  crimson and white. Nobody should have to check which boss they are fighting.
- **A boss's wind-up tint is the base's, until his palette says otherwise.**
  enemy_base fades a winding enemy towards amber, which is free legibility for
  anything with hue in it and wrong for anything without: Silverman is six exact
  greyscale values, so a multiply lands between two rungs of the only thing he
  is made of. He overrides `_windup_tint()` to white and draws his telegraph on
  the SHEET instead, in `dull` steps. His idle already rests at the brightest
  rung, so a wind-up can only ever dim him - worth knowing before designing an
  attack for a boss whose ramp runs one way.

**A boss makes noise the way he gets a health bar: by owning the files.**
`game/bosses/boss_audio.gd` is an `Audio` child holding id -> stream, and
boss_base fires `hurt`, `stagger` and `concede` on whichever of them exist -
Ahmed adds his burning axe and his beaten breath himself. Sound is the first
thing in this project that is NOT generated from data, so it brings back the
one thing everything else was built to avoid: **a `.wav` needs an import pass,
and an import pass needs the editor CLOSED.** Every miss is therefore legal by
design - a missing sound plays nothing and the fight is unaffected - so a
fresh checkout and the headless suites both work before anyone has imported
anything. Levels are baked into the files themselves; there is no bus layout
and no volume setting yet, so a file's own level IS the mix.

His sounds are positional and live in his scene because they are HIS; the
tracks are neither, and live on the `Music` autoload - see Music below for the
half of the audio that is not standing anywhere in particular.

game/bosses/CLAUDE.md has all of it, and the three fights are three different
SHAPES on the one cycle: Ahmed a menu (the attack suits the range), Mostafa a
rhythm (jab, jab, hook), Silverman a ladder (three phases, each adding a
mechanic, interrupts narrowing to none).

Which enemies a room gets is per-biome data (type + position), and positions
keep every sight radius clear of the door line, spawns and both stands - the
straight walk between the doors stays safe in every biome, and the flow and
combat tests depend on it. The lane is x 246-300 at every y, and clearing its
EDGE by the type's own radius is the rule, which gives a hard band per
archetype: a guard (80) needs x <= 166 or x >= 380, a wraith (120) x <= 126 or
x >= 420, a warden (130) x <= 116 or x >= 430.

**The reskins hold floors 1-9 and 12; the originals appear only from hellfire
up**, where the building stops pretending to be an office and the people in it
stop looking like colleagues. Types, seams, tuning and the art pipeline:
game/enemies/CLAUDE.md.

**Every floor but the lobby has a second beat** - `reinforcements` in its
biome, a finite authored group that walks in through a named door at a known
cue. Floor 1 is the exception for one reason and it is not squeamishness: a beat
is cued by kills, and a room deliberately empty of enemies can never reach one,
so an `after_kills` there would sit in the data forever without firing. The
lobby staying crossable without a fight and the lobby having no beat are the
same decision. It is
deliberately not waves: **a room is an ARRANGEMENT, not a population**, and
respawns flatten every floor's fight into the same one because a room's shape
only matters while its enemies are placed. A beat fires ONCE, and once the room
is clear it stays clear. **What happens once it is clear is the THIRD
beat** - `relief`, the only one that is not a fight: Ivan walks in with a heart
per head (see NPCs). It is a separate node beside the second because the two ask
opposite questions of the same room - is the fight far enough along, and is it
over - and "over" has to skip a conceded boss, who is in the `enemies` group and
is never freed.

Reinforcements are the only enemies in the game with no authored position -
they name a spawn marker instead - and three things follow that are worth
knowing before touching a beat:

- **It is the one place head count lives.** A beat's `enemies` is a base group
  that never scales; `per_head` is added once per head beyond the first. The
  split exists because multiplying one list gave every extra player a second
  `call_center`, and two slowers do not stack a slow, they refresh it - a
  permanently slowed player cannot sidestep a telegraph. `call_center` is in no
  floor's `per_head`. Nothing else in the game scales with players, and the rule
  is Difficulty's: more bodies, never a worse one.
- **A boss floor's cue is `at_boss_health`, not `after_kills`.** A boss is in
  the `enemies` group and is never freed, so he never counts as a kill and the
  count can only ever reach 0 there. His adds all live in his beat and his
  `enemies` list stays empty: an add arriving at a threshold is a PHASE of the
  one fight, where the same add placed in the arena is furniture standing in it
  from the first frame.
- **A beat is the only legal way to put a body on the door line.** Placements
  must keep every sight radius off it (see above); an arrival has no position to
  check. The executive floor's chokepoint is the case - the gap is on the line -
  which is what the biome `spawns` key is for.

game/levels/CLAUDE.md has the rest.

## NPCs

Three friendly faces - **Dominique** (guide, front desk), **Ivan** (healer,
cafeteria) and **HR** (unplaced), who is deliberately the only one without a
first name. An NPC is in the `npcs` group and in NEITHER `player` nor
`enemies`, which is the whole of what makes it friendly: nothing in this game
reaches anything by type, so an NPC is invisible to both sides by construction
rather than by a flag anyone has to remember to set. It is still a solid body,
so the furniture rule applies to a person too - never stand one on the line an
enemy walks from its post to the middle of the room.

**All of them are twice the player's height in a robe no wider than the
player**, and that one brief is why NPCs have an art pipeline instead of a row
in the cast's roster. Doubling a 14px cast body does not fit a 32px cell, so NPC sheets are
cut at **64px**, the size the bosses already slice at. The feet keep their
clearance from the bottom of the cell, so a 64px NPC stands on the same ground
line as a 32px enemy, and the only thing that knows the cell grew is the
scene's sprite offset (`-24` against an enemy's `-8`).

HR's white dress is the one garment in the game that can lose its silhouette
to the floor - the lobby is blue-grey marble, the marble hall tops out at pure
white - so her 1px outline does the work the other two get from a saturated
robe. Worth a look at the floor before she is placed on one.

Each NPC owns its sheet on the enemies' exact terms - seeded once from
`game/npcs/roster.gd`'s recipe by way of `tools/npc_art.gd`, sliced from disk
forever after - so the doubled head's 2px outline, which is a known and
accepted debt, gets fixed by redrawing the head into that PNG rather than by
changing any code. `npc_base.gd`'s speed is 45, half the player's 90, written
as a plain number like every enemy's. All three stand still; `walk_to()` is
there for the day one doesn't. Dialogue and the thrown hearts are still to build.

**All three can talk, and none of them knows how.** An NPC carries a
`conversation` - a path to a .gd holding `const BEATS` - notices the player is
in range, puts a prompt over its head and emits `talk_requested`. game.gd wires
that to the director in game.tscn exactly as it wires a door's `travelled`, so
an NPC never learns that a subtitle box exists. HR stands in the lobby and her
induction is the first one built: a tour she walks and tows the player through,
ending in a contract that cannot be refused. Dialogue: game/dialogue/CLAUDE.md.

**Ivan heals, and he is the only healing in the game from floor 2 up.** He is
also the only person in it who ARRIVES: a floor with `relief` in its biome walks
him in through the door the player came by once the room is finally clear, and
he crosses to an authored spot and waits there (`game/levels/relief.gd`, the
third beat - see Enemies). At the end of his lines he throws **one heart per
head**, once per visit, and the count is `game/heads.gd` - the same function a
second beat's `per_head` reads, which is why that function is a file rather than
a line in either of them. Six floors have him: call_center, ahmed_office,
conflict_resolution, asset_recovery, executive_floor and khaled_office - the
floor before the first boss, and then after every big fight to the roof.
Everything else about him is npc_base, and `ivan.gd` is the only NPC script in
the folder. Dominique still has no lines and stands on no floor.

The rest - the pipeline's three steps, why the robe goes down before the head,
and what a third NPC would need: game/npcs/CLAUDE.md.

## Generated resources - regenerate, don't hand-edit

- `ui/theme/menu_theme.tres`        <- tools/build_ui_theme.gd
- `game/player/characters/*_frames.tres`
                                    <- tools/build_characters.gd
- `game/enemies/*/*_frames.tres`    <- tools/build_enemies.gd, see below
- `game/npcs/*/*_frames.tres`      <- tools/build_npcs.gd: seeds
                                       game/npcs/<id>/src/<id>.png ONCE from
                                       the roster recipe by way of
                                       tools/npc_art.gd (double height, robe),
                                       then slices whatever is on disk, 64px
                                       cells
- `game/npcs/ivan/heart.tscn`       <- tools/build_npcs.gd, and it is the one
                                       thing that generator writes which is not
                                       an NPC: the heart Ivan throws, his and
                                       not a level's, because a room's heart
                                       takes the room's palette and his is the
                                       same red on every floor
- the NPCs' looks & robes           <- game/npcs/roster.gd (data, edited by
                                       hand)
- `game/bosses/*/*_frames.tres`     <- tools/build_bosses.gd: seeds
                                       game/bosses/<id>/src/<id>.png ONCE from
                                       the painter tools/bosses/<id>.gd (which
                                       draws game/bosses/<id>/poses.gd), then
                                       slices whatever is on disk, 64px cells
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

## Music

`autoload/music.gd` (`Music`) is an autoload for one reason: the front end is
THREE scenes - main menu, character select, and back out of a finished run -
and `change_scene_to_file` frees the old one. A player living in main_menu.tscn
would restart the track the moment PLAY is pressed, which is the one seam a
menu loop exists to hide. Above the tree, it simply keeps playing.

`play(path)` is **idempotent on the track**, and that is the whole trick: every
front-end screen asks for the same track in its `_ready` without knowing which
screen ran before it, and only the first ask starts anything. No screen has to
know whether music is already playing. The no-op is decided on the path Music
itself holds and **never on `AudioStreamPlayer.playing`** - under a dummy audio
driver, which is every headless run and every test, `playing` is false even
while a stream is assigned and looping, so a guard that trusted it would
restart the track on every scene change in exactly the situation nobody can
hear. `track()` is the readout, for callers and tests alike. game.gd calls
`fade_out()` in `_ready`, so the menu carries over the load and goes out under
the first room's fade-in.

The loop flag is set on the stream in code, not trusted to the `.import`, for
the same reason `game/bosses/boss_audio.gd` sets it - and unlike a boss's
sounds, which are HIS and live in his scene, the track paths are a short
catalogue of constants on Music, because a path spelled out in three screens is
the one that goes stale when a file moves.

**Audio lives in `assets/music/`** - the one folder, on the `assets/` rule that
names audio outright as a thing shared across features. A track that needed
work before it could loop keeps its untouched export beside it in
`assets/music/src/`, on the enemies' and bosses' exact terms: `src/` is the
hand-owned original, the file above it is what the game plays.

**A generated loop does not loop.** An ElevenLabs export ends mid-waveform, so
the last sample steps straight to the first and clicks once per pass - on
`menu_loop.wav` that step was 22376 of 32768, and every 30 seconds. The fix is
a 12 ms equal-power crossfade of the tail over the head, which costs 12 ms of
length (0.04% across a 30 s loop, well under a 32nd note) and takes the step to
33. Check the seam on any new music before wiring it up; the click is obvious
once heard and invisible in a waveform view.

## Settings

Three autoloads, split by responsibility - `Music` above is a fourth, and is
here rather than there because it owns no setting:

- `autoload/settings.gd` (`Settings`) owns `user://settings.cfg` and nothing
  else - sections, keys, write-through on change. A future audio or controls
  page adds a section without this script learning about it.
- `autoload/display.gd` (`Display`) applies window mode and windowed size, and
  persists through Settings. Every window change goes through it, F11 included,
  so a hotkey press is remembered exactly like a menu choice.
- `autoload/difficulty.gd` (`Difficulty`) owns the game modes - see Difficulty.

`Settings` must stay registered **before** `Display` and `Difficulty` - both
read their saved values during `_ready`. `Music` is appended after all three;
it reads nothing saved today, and a future volume row is one more reader of
Settings, not a new rule. tools/setup_project.gd clears their entries
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
  They drive the real game with synthesized input and exit 0/1. Nine suites,
  each extending `tests/helpers.gd` (the shared harness: checks, key synthesis,
  settings backup, node getters) and overriding `_tick(frame)`:
  - `test_menu.gd` - main menu, MODE button + difficulty scaling, character
    select, the settings panel from the main menu, and the menu music holding
    ONE player across all three front-end scenes (checked by object id, since
    a headless run has no audio device to ask). Never enters the game.
  - `test_flow.gd` - select -> game -> movement -> pause -> zoom -> blow ->
    heart -> death -> wall -> doors (a hazard en route) -> lives -> game over.
    It walks the whole chain on foot, so inserting a floor means renumbering
    the frames after the new leg (~80 frames per door) and it asserts each
    room's own composition and dressing as it passes through.
  - `test_combat.gd` - guard telegraph and interrupts, wraith, warden, heavy.
  - `test_bosses.gd` - Ahmed's attacks, the order he picks them in, the
    interrupt and the concede.
  - `test_rage.gd` - Mostafa going up at 72 and staying up: that it fires at
    half health and not before, fires once, roots and silences him without
    letting him be staggered, never comes back down, and that every beat of
    the fire still lands on a frame boundary. Its own suite because it needs
    him FIGHTING and then taken across the line on a chosen frame, which
    threaded through the three-boss file made one boss's timing decide
    another's.
  - `test_silverman.gd` - his whole ladder: the glare opening at range with no
    contact, the crossing that passes THROUGH the player for one blow, the
    split's copy walking you down, the cold room draining outside the grace
    window, and the third phase refusing to be staggered. Its own suite because
    the fight walks him down three phases, so every check after the first
    depends on how much health he has left - a file that does that cannot also
    hand the room to a next section unchanged. test_bosses.gd keeps the art
    invariants that hold at any health. It isolates by GEOMETRY rather than by
    frame number: his band is a 20 px lane and his crossing only moves along x,
    so a player parked 30 px off his line is untouchable by both while the copy,
    which homes in two dimensions, still reaches them.
  - `test_reinforcements.gd` - a second beat's trigger, its single-file
    arrival, the door it uses, the hold while the player stands in that door,
    that a beat fires once, and the head count. Builds the beat by hand in the
    empty lobby rather than walking nine floors to the one biome that has one.
  - `test_ivan.gd` - the third beat: that he waits for a fight and not
    merely for a quiet room, that he comes in by the door and crosses to his
    spot, that a late arrival can still be talked to (game.gd wires NPCs as
    they arrive, which is the failure that would be silent on six floors),
    that the hearts land on the last word and heal, one per head, once. Builds
    the beat by hand in the empty lobby, then checks the six floors off disk.
  - `test_dialogue.gd` - HR's whole induction: the prompt, the typewriter, a
    dead stick while she talks, the choices and the branch one takes, the
    escorted tour, the contract, and the wheel coming back. Driven by what is
    on screen rather than by frame numbers - a line's LENGTH is its duration,
    so numbered frames would need re-timing every time one is reworded.
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
- **A looping sound proves nothing by having `loop_mode` set.** `AudioStreamWAV`
  seals a loop with `loop_begin`/`loop_end` in FRAMES, and `loop_end` 0 does
  NOT mean "to the end" - a forward loop ending on frame 0 wraps before it has
  played anything, so the playback position stays pinned at 0.000s and the bus
  receives exact silence. Every track and every looping effect in the game
  shipped mute that way while a green check watched `loop_mode`, which was set
  the whole time. The real end is `get_length() * mix_rate` (not `data.size()`
  - these import as QOA, so `data` is compressed bytes rather than frames), and
  the check with teeth is that `get_playback_position()` has MOVED between two
  frames. That works headless: the dummy driver still mixes, so audio is
  testable here rather than something only ears can confirm.
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
