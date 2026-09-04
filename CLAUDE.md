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
its own tiles, props and spawn markers, and answers three questions -
`bounds()` for how much world there is, `spawn_position(name)` for where to
stand, and `title()` for what to call itself. Nothing in game.gd names a
specific map beyond `START_LEVEL`.

**Arriving somewhere announces it.** `ui/level_title/` is a card game.tscn
instances on its own CanvasLayer, fed one string by game.gd at the end of
`_enter_level` and dumb about everything else, exactly like the HUD: three
seconds at full opacity, then it fades itself out over 0.4s, and a second call
cuts the first off rather than queueing behind it, so stepping straight back
through a door reads the room you are now in. It sits at layer 6 - above the
transition fade so the name is already legible on the black with the room
appearing behind it, below the pause menu's 10 so a death screen still covers
it. The name is authored per biome as `title` in tools/biomes.gd and written
into the level scene as the `display_name` export, with `title()` falling back
to the node name; it is authored rather than derived because "THE MARBLE HALL"
is not a transformation of "MarbleHall" that any rule gets right everywhere
("HELLFIRE" takes no article). Being called from `_enter_level` is what makes
the start of a run announce the lobby too, and what keeps a respawn silent -
dying and getting up in the same room is not arriving somewhere.

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

**A door re-arms when the player steps off it**, and the case that needs it is
not the obvious one. `_used` is latched so a nudge back onto a threshold cannot
queue a second travel mid-fade, and physics is frozen on the player for that
whole fade, so nothing legitimately leaves a threshold while the latch matters.
But a level is swapped in while the arriving player still carries the position
they had when the LAST door fired - and since every level puts its doors in the
same place, that position is right on top of the new room's matching door. It
fires during the transition, where game.gd is still `_travelling` and drops it.
Without re-arming on `body_exited`, the door ahead of you is spent before you
ever walk to it and the chain dead-ends at the second room, which is invisible
in a two-level chain where nobody ever arrives and then walks on.

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
at no cost. Adding one is two edits: draw the row into
`game/player/src/character_cc0.png`, then add it to `CAST_LAYOUT` in
tools/build_characters.gd. Nothing outside the cast can see either change.

**Enemies deliberately do NOT work this way**: each owns its own sheet and is
seeded from a frozen copy of the body, because each is heading somewhere
different and the cast's sheet is going to keep moving. See Enemies.

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
and opens a fresh one. That window is the only rate limiter for blows anywhere
in the game, and it is per-difficulty (`Difficulty.grace_seconds()`, read once
at spawn) because it is secretly the CROWD dial: a guard's full attack cycle is
0.8s, so a grace of 0.8 (EASY) swallows every extra guard's strikes and N
enemies hit like one, 0.65 (MEDIUM) lets a pair partly interleave, and 0.5
(HARD) makes a crowd a real threat. Retuning it retunes every hazard and enemy
at once. A
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

**An enemy hurts you by finishing an attack, not by touching you.** The cycle is
CHASE -> WINDUP -> STRIKE -> RECOVER, with STAGGER hanging off WINDUP for an
attack that got interrupted; the enemy only moves in CHASE, so a swing is
something you can see coming and step out of. Contact alone costs nothing - that
is what makes the telegraph mean anything, and it is how the wraith and the
warden already worked, so this brought the plain melee enemy in line with them
rather than inventing a new idea.

**Damage interrupts a wind-up, and two rules keep that from being a spam
button.** Unbounded, "any hit cancels" is a stun-lock: a fresh wind-up can
always be hit at its start, so mashing would beat every enemy in the game.
`commit_fraction` (0.6) is the point past which the enemy is committed - a late
hit still damages it but the blow lands anyway, which makes interrupting a
timing decision rather than a check on button speed. `interrupt_cooldown` (1.2s)
is the load-bearing one: having been interrupted once, an enemy cannot be
interrupted again for a while, so an interrupt is a resource spent on the attack
that most needs stopping. The player is deliberately NOT interruptible in
return - being staggered out of a combo by chip damage feels dreadful, and
asymmetry in the player's favour is the right kind of unfair.

The numbers come off the player's combo, which is the clock everything else is
measured against. Damage lands on an attack's first frame and the chain has no
gaps, so cumulative damage is 5 / 12 / 17 / 24 / 29 / 36 at 0.29s intervals -
which is why enemy health is 24, 17 and 36 rather than round numbers. Each is
"dies in exactly N hits". At the old 10 health every enemy died in 0.29s and no
telegraph could exist inside that.

**`_touch_strike(player)` is the seam between melee types**, called on the frame
the wind-up completes for each player still in range. `_touch(player, delta)` is
still there for per-frame contact and still hands over `delta`, because a
continuous effect with a rate of its own - the wraith's drain - is exactly what
it is for. `_attacks()` says whether a type uses the cycle at all, and
`_windup_needs_contact()` whether stepping out of range unwinds it (false for a
swing, which lands on air; true for something that has to hold you).

Smaller seams travel with those, because an effect is rarely only damage:
`_contact_state()` is what contact looks like between attacks,
`_windup_state()` and `_windup_tint()` are what the telegraph looks and reads
like, `_resting_tint()` is how the enemy reads the rest of the time, and
`_can_advance()` lets a type root itself. The base resolves `modulate` in one
place, with the hurt flash outranking a wind-up and a wind-up outranking
`_resting_tint()`, and settles `touching_player` and the phase before any
override is asked.

**A charge and a swing are the same shape**, which is worth knowing before
writing a fourth type: wind up, land it if it completes, recover, interruptible
early and committed late. The warden looked like it needed a clock of its own
and did not - it is four overrides on the same cycle, and taking them
individually is what earns it the interrupt rules for free. `_attacks()` is for
a type with no attack at all, not for a type whose attack is unusual.

Three types so far, and they deliberately threaten in three different ways -
damage, drain, and denial - so a room is built by mixing them rather than by
adding more of the same:

- **`regular/`** - 24 HP, 10 damage on a completed strike, speed 55, sight 80,
  0.45s wind-up. Carries no script of its own: its scene runs enemy_base.gd
  directly, the way torches run hazard_base.gd, so the base's defaults ARE the
  regular's numbers. It is the only type that uses the swing cycle, and the one
  the interrupt rules exist for. `max_health` is the number most likely to want
  retuning - four guards in the marble hall is sixteen hits between them, and
  17 is the next stop down if that reads as a slog.
- **`wraith/`** - 17 HP, no attack at all, speed 45, sight 120, and standing
  near it costs three health per second (1 was flavour, not threat: 100 seconds
  to matter; at 3, two of them cost about half a guard's output from the one
  source that cannot be staggered). It is the reason `drain()` exists (see
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

  It opts out of the attack cycle (`_attacks()` false), so **it is the one thing
  in the game that hitting does not stagger** - deliberately, since it has no
  attack to stagger, only proximity. That leaves exactly two answers to it,
  leave or kill it, and being the softest of the three at three hits is the
  other half of that bargain.
- **`warden/`** - 36 HP, no damage of any kind, speed 50, sight 130, a 48 px
  area, and a 2-second wind-up that slows everyone still inside to half speed
  for 4. It is pure area denial: harmless alone, and the reason the guards and
  the wraiths in hellfire are dangerous. What its area costs you is settled by
  the wind-up, never by contact.

  **It runs the base's cycle**, with its charge as the wind-up and its slow as
  the strike, so its numbers are the ordinary `windup_seconds` (2.0),
  `commit_fraction` (0.75), `recover_seconds` (0.6) and `interrupt_cooldown`
  (1.5). Three counters, each deliberately just barely sufficient: walk out and
  `_windup_needs_contact()` unwinds it; hit it early and stagger it, once,
  because its interrupt cooldown outlasts the charge it interrupts; or kill it,
  which at 36 health is 1.43s of unbroken combo against a 2s charge - a race you
  can just win with enough left to cover closing the distance. Leave it too late
  and none of them work.

  Its telegraph is three readings of `_windup_progress()`: the drawn ring
  (`charge_ring.gd`), the violet `_windup_tint()`, and the sprite's four attack
  frames held to the charge's pace rather than looping six times through it.
  The ring exists because 48 px of floor is six times the width of the body and
  no animation on a 32 px sprite can say where an area ends; it copies its
  radius off the Touch shape on `_ready`, so the drawing cannot lie about the
  reach. Because all three read the one number, an interrupt wipes the sweep,
  drops the tint and resets the sprite in the frame it lands - legible without a
  line of code of its own.

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

The player's side of the fight is three attacks on the one attack button. A
press starts the swing (`ATTACK_POWER` 5); pressing again during it, or within
`COMBO_GRACE_SECONDS` after, chains the thrust (`attack2` rows 9-11 of the cast
sheet, `THRUST_POWER` 7), which lunges a step forward (`LUNGE_SPEED`, decayed by
the same friction that roots attacks) and parks the Hitbox further out to match
its visibly longer blade. **A press mid-attack is buffered, never dropped** -
mashing alternates swing-thrust cleanly, and a dropped press reads as the game
eating the button. Getting hit deliberately does NOT break the combo: the game
has no hitstun, so a silently swallowed buffer would read as dropped input, and
melee happens inside enemy contact where hits are constant - the thrust's cost
is commitment (rooted through two animations, lunging toward danger), not a
hidden reset. Damage goes through a Hitbox Area2D that `_start_attack()` parks
one step ahead of the body in the facing direction; it stays live for the whole
animation but a ledger (`_swing_hits`) lands each attack once per enemy - so a
24 HP guard dies to one full mash cycle (5+7+5+7). The thrust's sparks are
tinted per character by `_spark_hex` in character_art.gd: the hair colour
raised to flash intensity (near-black hair would vanish on dark floors),
`SRC_SPARK` gold where a bald head has none. Per-character health and attack
stats are planned; they will join the roster recipe the way looks did.

**The heavy is the hold.** A press always swings first - waiting to see whether
the press is a hold would lag every basic attack - and a button still held when
an attack ends (with nothing buffered) flows into the `charge` stance: rooted,
looping the wind-up while sparks spiral inward. `CHARGE_SECONDS` (1.0) later
the loop doubles speed as the ready cue; releasing then fires `heavy` - the
spin - which always erupts into `wildfire`, and the pair deals `HEAVY_POWER`
(15) through the Spinbox, a 17 px circle on player.tscn, to EVERY enemy inside
it, once per enemy across both animations (the ledger is not cleared between
them). Releasing early just returns to idle - the press's swing already
happened, so a tap stays a tap, mashing stays the combo, and holding is the
heavy: three moves, one button. `HEAVY_POWER` is **exactly a guard's health, and
the equality is the design**: an AoE that does not kill the basic enemy thins no
crowd and never repays its ~1.9 rooted seconds - at its original 15 it was
strictly the wrong button, 10.8 damage/s single-target against the combo's 21
with nothing dead at the end. At 24 it one-shots a guard and a wraith while its
single-target rate (~15.6/s with the entry swing) stays below the combo's, so
the combo remains correct against one enemy and the heavy against a crowd.
Difficulty must never scale either side of that equality. The wildfire's ember
tone is `SRC_FIRE`, recoloured to the spark colour darkened, so each
character's fire matches their sparks - violet for the black-haired, gold for
the bald. One test-side consequence: a synthesized Space left held is no longer
inert - a test's mash window must end on a release, or the player stands in
the charge stance for every later movement check.

**Every enemy owns its sprite sheet**, and this is the one place enemies and the
cast are deliberately organised differently. The seven characters share
`game/player/src/character_cc0.png` forever: they play the same game with the
same moves, so a new animation drawn once should land on all seven. Enemies are
the opposite - each is heading somewhere different, and a shared sheet would
pile every enemy's future moves into one file. So each has
`game/enemies/<id>/src/<id>.png` of its own.

`tools/build_enemies.gd` is **seed once, slice always**:

- *Seeding* writes that PNG, and only ever when it is missing - a recipe
  recolours the body from `game/enemies/src/body_cc0.png` so a new enemy has
  something to walk around as on day one. It is a starting point, exactly like
  the level scenes build_levels.gd writes.
- *Slicing* runs every time, on whatever sheet is actually on disk.

**`game/enemies/src/body_cc0.png` is a frozen copy of the pristine CC0 sheet,
and the copy is the whole point.** The cast's `game/player/src/character_cc0.png`
is living art that will grow animations; seeding from it would mean an enemy
created after a player animation was drawn silently started from a different
body than the enemies before it. Seeding has to be reproducible, so enemies read
their own frozen copy and it is never edited.

The same split applies to the animation layout, and this one bites harder: the
cast's layout is `CAST_LAYOUT` in build_characters.gd, while enemies fall back to
`CC0_LAYOUT` in character_art.gd. They are deliberately NOT one constant, and
the thrust is now the proof: `attack2` lives in rows 9-11 of the cast's sheet
only, and sharing the constant would have told every enemy to slice rows its
own 9-row sheet does not have, with the frames coming back empty and nothing to
say why.

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
what makes one room feel unlike the next: the marble hall is four guards, one to
a corner rather than a line across the top so they can be taken on one at a
time, and hellfire is four of those plus two wraiths and a warden - where things
start following you and taking your legs. Positions are chosen so
no enemy's sight reaches the door line, the spawns or the torch and heart stands
- the straight walk between the two doors stays safe in every biome, and the
flow and combat tests depend on nothing aggroing until a check deliberately
walks into range. The warden's 130 px is the longest look in the
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
it overwrites that work. Run it to reset a level or to add a new one, and pass
level names after `--` to build only those, because a chain of eight means
adding a floor must not re-roll the seven already dressed:

```
<godot> --headless --path . --script res://tools/build_levels.gd -- lobby
```

The door trigger's hand-tuned y=13, snug against the seal, is now what the
generator writes, so regenerating a door no longer silently undoes it.

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
  crowd dial - see Health.

Consumers read their numbers ONCE, where they spawn, never live - the mode is
only choosable at the main menu, a new run builds a fresh player and fresh
rooms, so there is no mid-fight rescaling and deliberately no `changed` signal.
MEDIUM is the tuned baseline; every number in enemy scenes and in this file is
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
- All third-party assets are CC0; sources and licenses live in CREDITS.md -
  update it whenever an asset is added.

## Testing

- `tests/` holds SceneTree-script tests: no framework, no dependencies.
  They drive the real game with synthesized input and exit 0/1. Three suites,
  each extending `tests/helpers.gd` (the shared harness: checks, key synthesis,
  settings backup, node getters) and overriding `_tick(frame)`:
  - `test_menu.gd` - main menu, MODE button + difficulty scaling, character
    select, the settings panel from the main menu. Never enters the game.
  - `test_flow.gd` - select -> game -> movement -> pause -> zoom -> torch ->
    heart -> death -> wall -> doors -> lives -> game over.
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
- `tests/` and `tools/` must be excluded from export presets when we set
  up exports.
