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
- `tools/` - editor-side generator scripts run headless; never game code.
  `tools/voice/` is the one corner of it that is python rather than GDScript,
  because it talks to a web API; what it writes is ordinary art the game loads
  like any other file
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
camera, room anatomy, doors and spawns, and the studio's clock),
`game/enemies/CLAUDE.md` (the attack cycle, the types, the enemy art
pipeline), `game/bosses/CLAUDE.md` (multiple
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
own screen effects**, 2 HUD, 3 the dialogue box, **4 what a boss is
shouting**, 5 transition fade, 6 level title. Anything
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

**One floor also keeps a CLOCK, and it is the first room that is not the same
room on every frame.** The content studio's biome carries a `studio` key, which
buys one node counting rest / cue / take, and three things read it: its five
ring lights go hot, its camera dolly runs a rail, and its neon sign says which
of the two the room is in. The reason is not damage but MEMORY - every other
threat in the game stands where it was placed, so a routing floor is solved
exactly once - and the three rules that generalize are one number (`heat()`)
driving every consumer, a cue phase that is visible and harmless because a
hazard which merely switches on is a hazard you cannot have avoided, and the
`studio` group being the only way anything finds the clock, so a floor without
one leaves every one of those props exactly the furniture it always was. The
dolly is also the first thing that could threaten the door lane without being
placed in it, and deliberately does not: its rail stops at x 228. All of it:
game/levels/CLAUDE.md's *The clock*.

**The call floor is WIRED, and it is that idea turned inside out.** Its `surge`
key buys four runs of cable trunking that flare end to end and then put
something very fast down their length, every 2.4s, staggered so the room fires
about every six tenths of a second. The dolly asks for patience, which is the
wrong question on the floor whose whole lesson is that your movement gets taken
away - so this one is small, fast and comes in fours. Three things generalize:
it **draws its own conduit** from the same two points it burns along, so the
lane the player reads and the lane that hurts cannot come apart (and it is the
one hazard in the game with no art file); the **whole run charges** rather than
one end of it, so a warning does not also have to teach a direction; and **one
pass is exactly one hit**, because the head crosses a player in a tenth of a
second against a far longer grace window - which is the entire reason four of
them is fair. The lane rule holds here too and pays for itself: cutting each
aisle in two at x 246-300 is what made four runs out of two.
game/levels/CLAUDE.md's *The wiring*.

**And the hub WANDERS.** Its `scrubbers` key buys two floor scrubbers, one per
half, and nothing about where they go is authored at all - they pick a heading,
run until the room stops them, and pick another, so the FURNITURE is what
decides the route. Two floors teaching "learn where the danger is, then time it"
is one lesson twice; this one cannot be learned and asks you to keep looking
instead. It is also the first hazard that is not fire or sparks: it takes your
POSITION, with a low damage and a real `shove()` - the fourth way the world
reaches the player - which is why its scanner is cold. Warm burns, cold moves
you. Being random, it keeps the door lane clear the only way a routeless thing
can: `within` pens each machine into its own half. And it is a solid BODY rather
than a trigger, because being in the way is half of what an obstacle is.
game/levels/CLAUDE.md's *The machines*.

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

The player owns its health and its lives (`MAX_LIVES` 3). **Four ways the
world reaches it, and the splits are the thing to get right**: a *blow*
(`take_damage()`) is metered by the grace window and opens one - that window is
per-difficulty and is secretly the CROWD dial; a *drain* (`drain()`) knows its
own rate and sits outside the window in both directions - never blocked by one,
never opens one; a *status* (`apply_slow()`) is something the player carries
that expires on its own, refreshing rather than compounding; and a *shove*
(`shove()`) is the fourth, shaped like a status rather than like a blow - the
hub's machines take your POSITION rather than your health, and the push is
carried, decays on its own, and refreshes rather than stacking. It is
deliberately never added to `velocity`, which is carried between frames and
would compound it into a launch. Everything reaches
the player by the `player` group + `has_method`, never by type. Full rationale,
the HUD, the combo and the heavy: game/player/CLAUDE.md.

**The player makes noise on the bestiary's exact terms: by owning the files.**
An `Audio` child holds id -> stream and player.gd fires eight names at it -
`swing`, `swing2`, `charge`, `heavy`, `wildfire`, `hit`, `hurt`, `die` - so a
cue arrives by having the WAV and nothing else, and a missing one is silent
with no branch anywhere. One set serves all seven characters, which is the
cast's SHEET rule applied to the other sense, and it decides the one thing
about the audio that could not be discovered later: `hurt` and `die` cannot
commit to a gender, because six of the seven are not whoever a grunt would
sound like. The node is `game/player/player_audio.gd` and is deliberately NOT
`game/enemies/enemy_audio.gd` bubbled up - it does a neighbouring job with a
different first line. An enemy is somewhere, and which corner a wind-up came
from is the whole of what panning is for; the player is never anywhere, since
the camera is on them, so their pan is 0 on every frame of every room and the
positional node buys an attenuation curve to produce silence's exact twin. It
is smaller than its counterpart rather than a copy of it, and drops
`play_detached` outright: that exists because an enemy plays `die` on the frame
it is freed, and the player is REVIVED, never freed.

Three splits are worth keeping straight, and two of them are the enemies' rules
arriving from the other side:

- **A swing is air; `hit` is a blow that LANDED.** The two lights announce
  themselves when they START, and `hit` fires from `_strike()` only on a frame
  something was actually reached - once for the frame, not once per enemy, so a
  heavy landing on four bodies is one impact rather than four copies of one clip
  started together, which is a click.
- **`drain()` is deliberately silent**, and it is the one absence anybody will
  call a bug. A drain runs every physics frame and already knows its own rate, so
  a gasp on each is sixty a second - and metering it through the grace window to
  thin them out is exactly the mistake `drain()` exists to not make. The thing
  draining you is already making the noise. A DEATH is not a drain tick, so
  `die` sits with `_lose_health()` and a drain kills as audibly as a blow does.
- **The charge is the one loop**, because the stance is held for as long as the
  button is and so has no length of its own to end at. It was specced as a
  one-shot capped at `CHARGE_SECONDS` so that running out would be the ready
  cue; that was wrong on its own terms, and the ready cue stays where it already
  was - on the eyes, where the animation doubles speed.

The sounds are `tools/sfx/make.py player` off `tools/sfx/player.py`, the
bestiary's pipeline unchanged.

## Enemies

`game/enemies/enemy_base.gd` runs every type: stand guard, close to
`stop_distance`, and hurt by FINISHING an attack (CHASE -> WINDUP -> STRIKE ->
RECOVER), never by mere contact. Damage interrupts a wind-up, bounded by
`commit_fraction` and `interrupt_cooldown`; the player is deliberately not
interruptible in return.

**`sight_radius` is how an enemy NOTICES the player and nothing more, and that
is load-bearing**: every authored position is placed to keep it off the door
lane, so widening it breaks all twelve floors and two suites at once. What
happens AFTER seeing you is the leash - `patience_seconds` (2.5) keeps it
coming that long after losing sight, `leash_factor` (2.0) stops it following
further than that multiple of its sight FROM ITS POST, and then it walks back
and stands on its mark. The second half is the one that matters: an enemy that
halted wherever it gave up let a player walk one body out of position and
leave, and a room is an ARRANGEMENT. A boss opts out of all of it
(`_leashes()` - an arena has no arrangement); a reinforcement opts out of the
POST only (`unleash()` - it is the one enemy with no authored position, so it
still gives up, it just has no mark to be held near or to return to). Full rationale:
game/enemies/CLAUDE.md's The leash.

**An enemy gets round the furniture, and there is still no pathfinding.**
Steering is *walk at the player*; what that cannot do is the thing it creates -
a body sliding along a desk turns to face the player ever more squarely until
the sideways part of the walk is gone, and it parks flat against the desk
forever. It presented as an enemy that would not attack, because the attack
cycle starts on contact. `_steer` commits to ONE side when it stops making
ground and holds it until a ray says the way is open, and after three fruitless
tries it gives up and walks home - only a body with a POST does that, which is
what keeps a boss and a reinforcement out of it without a list. The other half
is the collision layer: a prop whose box is 16 px or narrower is CLUTTER, solid
to the player and thin air to everything hunting them, because a box that small
was never cover and a snag costs the two sides very different amounts.
game/enemies/CLAUDE.md's *Getting round the furniture*.

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

**A boss can also TALK, and it is the same deal a third time.** He carries a
`Lines` child naming a file of them (`game/bosses/ahmed/taunts.gd`), boss_base
fires the cues off moments the fight already has - an attack beginning, a hit
landing, the end - plus two it does not: the frame he first sees the player,
and the player refusing to come near him, which is the taunt. He emits `said`
and game.gd puts it on `ui/subtitle/`, which is deliberately NOT the dialogue
box: that one types, waits for a keypress and takes the player's hands, and in
a fight a line that eats the attack key is a line that gets you hit. Ahmed is
the one who talks, and he is VOICED: twenty-three clips, cut by
`tools/voice/` with the read tagged per cue, and the subtitle holds for as long
as the recording runs. Nothing in the game changed to make that work - a line
always carried its clip path - see game/bosses/CLAUDE.md's The mouth.

**A boss makes noise the way he gets a health bar: by owning the files.**
`game/enemies/enemy_audio.gd` is an `Audio` child holding id -> stream, and
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

**And every enemy makes noise on the bosses' exact terms: by owning the
files.** The `Audio` child that gives a boss his grunts is the same node -
`game/enemies/enemy_audio.gd`, which moved here from `game/bosses/` the day a
second feature wanted it, the placement rule doing its job for the third time
in this folder. enemy_base fires five cues off moments the cycle already had -
`windup`, `hit`, `hurt`, `stagger`, `die` - so an enemy gets them by having the
WAVs and nothing else, and one that has none is silent with no branch anywhere.
Sound is per enemy, never per archetype: a reskin is no more a recolour here
than in its sheet, and the office boy's wrench must not ring like the guard's
sword.

Three things generalize out of it, and two are traps the bosses never hit:

- **A death cannot be played the ordinary way.** `die` fires on the frame the
  body is `queue_free`d and every player under it is freed too, so the normal
  path starts a sound and destroys it in the same frame. It is handed to the
  enemy's PARENT instead. No boss has this problem - he concedes rather than
  dying and is never freed.
- **`hit` fires only on a blow that landed.** A swing through empty air already
  said its piece on the wind-up, and an impact over nothing teaches the player
  that the sound does not mean they were hit.
- **The wraith's drain is the one sound that is a STATE**, and the one enemy
  that needs one: nothing is swung and nothing lands, so it is otherwise the
  only threat in the game you cannot hear. It is a sealed loop, with both of
  the two ways a loop ships broken guarded against - see Music below, and
  game/enemies/CLAUDE.md's The noise for the rest.

Enemies are levelled UNDER the bosses and that is arithmetic, not deference: a
boss floor holds one boss, hellfire holds seven bodies.

**And two of them TALK, on the third pass of the same deal.** `social_media`
and `call_center` carry a `Lines` child naming a file of mutters, and
`game/bosses/boss_lines.gd` moved to `game/enemies/enemy_lines.gd` to serve
them - unchanged, because the second user needed exactly the node the first
one had. `_lines` and `_say` are enemy_base's now; a boss's override adds only
the SUBTITLE, which is the one part of talking that was ever his. **A boss is
addressing you; an enemy is being overheard**, so a mutter deliberately never
reaches the subtitle box - four of them would fight over one box, and putting
a grumble on screen turns eavesdropping into being spoken to.

The cue is POLLED rather than fired, which no other line in the game is: it
answers to no moment, so enemy_base asks every 2 s and is refused most times,
and the `Lines` child's own `cue_seconds` does the real pacing. The first ask
is scattered across a whole cooldown or a room speaks in chorus. Both mutter
at -31 dBFS - under the warden's own telegraph at -29, because a wind-up is
information and this is decoration.

The joke is that the line and the mechanic are the same thing: she is a wraith
draining your health and every line is about having no time, and he is a
warden who takes your speed and every line is a call centre asking you to
hold. `tools/voice/cut.py <id>` cuts both, the bosses' pipeline unchanged.

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
ending in a contract that cannot be refused.

**She is also VOICED** - twenty-three clips out of the same `tools/voice/`
Ahmed's barks come from - and, as with him, nothing was rewritten to allow it:
a beat always carried its clip path, and the dialogue box always took one. What
the clip buys is the TYPING RATE, which is now the line's length over the
clip's, so the subtitle finishes as she stops rather than racing her. A beat
with no clip, or one not yet imported, is silent and types at the flat rate, so
every unwritten conversation in this game still reads. Dialogue:
game/dialogue/CLAUDE.md.

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
the folder.

**He says a different thing on every one of those six floors**, and that cost
six files and no code: `conversation` is placement, so each floor's biome names
its own (`game/npcs/ivan/after_<floor>.gd`). One shared set of lines was the
first version and it was wrong in a way only repetition shows - a man who walks
in after a fight and says something that fits no fight in particular reads as a
vending machine with a voice, and a player who has heard it three times has
stopped reading the box he cannot skip. What keeps six files one character is a
ROUTINE rather than a script: he talks about the room he has just walked into,
he knows everybody in it by what they order - Ahmed complains about his soup,
the office boys fix his ovens - and the last word is "Eat." every time, because
that is the word ivan.gd's gift lands on. The rest, including why the finale
names nobody, is `after_call_center.gd`'s header.

**He is VOICED too** - eighteen clips out of the same `tools/voice/`, three per
floor, in English with an Eastern-European accent, which is the only direction
his lines needed: he is the one man in the building who is glad to see you, and
he is heard over a room the player has just finished fighting in, so an accent
that ever costs a word would cost the moment it was written for. His clip names
are namespaced by floor (`call_eat`, `ahmed_axe`) because all six conversations
cut into one folder and nothing dedupes across them - and every floor really
does end on the same word.

**Dominique is the FOURTH beat, and the only one that hands over information.**
A floor with `briefing` in its biome walks them in once the room is clear to say
what is standing on the floor above - and it is the three floors that sit under
a boss, which is the rule rather than the list: `tests/test_dominique.gd` reads
the whole chain off disk and fails if a boss ever gets one without a warning
under it. They come down the NORTH door, the one the player is about to go up,
where Ivan comes up the south one - two of the three floors have both, and one
doorway cannot take two 64px bodies on one cue. It is the same
`game/levels/relief.gd` doing both, because that file has never named anybody:
the beats are told apart by node name and biome key, the way the prop shelves
are told apart by role. Their lines are one file per boss
(`game/npcs/dominique/before_<boss>.gd`) and they are voiced too - twelve clips,
bold and Slavic and impatient, deliberately not Ivan's warmth: he is glad to see
you, and they have given this speech before to people who did not come back.

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
- `game/enemies/*/sfx/*.wav`         <- tools/sfx/make.py enemies, the second
                                       thing here that talks to a web API and
                                       the second that costs something to run.
                                       Mechanism in `make.py` + `wav.py`, the
                                       prompts, lengths and levels in
                                       `enemies.py`, on cut.py's exact split.
                                       Re-shaping is FREE: `--relevel` re-trims
                                       and re-levels from the untouched exports
                                       in `game/enemies/<id>/src/sfx/`, so only
                                       a new PERFORMANCE costs credits
- `game/player/sfx/*.wav`           <- tools/sfx/make.py player, on the
                                       bestiary's pipeline unchanged: the
                                       recipe (prompts, lengths, levels) is
                                       `tools/sfx/player.py`, the engine is
                                       shared, and `--relevel` re-shapes from
                                       `game/player/src/sfx/` for free. ONE set
                                       for all seven characters, because they
                                       share one body
- `game/enemies/{social_media,call_center}/sfx/voice/*.wav`
                                    <- tools/voice/cut.py <id>, the bosses'
                                       pipeline unchanged. WHAT they mutter is
                                       game/enemies/<id>/mutters.gd and is read
                                       from there; how it is delivered is
                                       tools/voice/<id>.py
- `game/bosses/ahmed/sfx/voice/*.wav`
  `game/npcs/hr_lady/sfx/voice/*.wav`
  `game/npcs/ivan/sfx/voice/*.wav`
  `game/npcs/dominique/sfx/voice/*.wav`
                                    <- tools/voice/cut.py, the only generator
                                       here that COSTS something to run and the
                                       only one that is not deterministic: a
                                       re-cut line is a new performance, so
                                       takes that were listened to and approved
                                       are pinned in the recipe's KEEP and
                                       skipped. Its data is the delivery;
                                       WHAT is said stays with the mouth that
                                       says it and is read from there.
                                       **Two shapes of mouth, one driver**: a
                                       boss shouts on CUES and his clip is
                                       named after the cue and the pick
                                       (`taunt_1.wav`, derived); a conversation
                                       is a flat list of beats and its clip
                                       name is AUTHORED - read back out of the
                                       `voice` path the beat already carries
                                       for the game to load. That split is not
                                       tidiness: lines get written into the
                                       MIDDLE of an induction, and a numbered
                                       name would renumber every clip after the
                                       insert and re-cut, and re-bill, lines
                                       nobody touched
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

**Every floor plays something, and a boss is the only thing that interrupts
it.** `Music.DEFAULT` (`assets/music/level_loop.wav`) is the bed, and game.gd
asks for it in exactly the place it used to ask for silence: after the hunt for
a boss with a `music` on him, where a floor with no boss and a boss floor whose
boss has already conceded both land. A conceded boss hands it back on the same
signal that used to take his theme away - the fight ending is not the floor
ending, and Ivan walks in on half of those rooms.

The ask is `fade_to()` rather than `play()`, and it is the same idempotence
trick one level up: **a door between two ordinary floors must not restart the
bed**, so asking for the track already playing is a no-op and the music crosses
the building with the player. What `fade_to` adds is the handoff - there is ONE
player, so no crossfade is possible, and a track that is on its way out has to
finish leaving before the next one starts. That queue is why the first room
does not cut the menu off mid-fade: `_ready` asks the menu to leave, the lobby
asks for the bed, and the bed comes up when the fade lands. An explicit `play()`
or `stop()` always beats a queued handoff.

The loop flag is set on the stream in code, not trusted to the `.import`, for
the same reason `game/enemies/enemy_audio.gd` sets it - and unlike a boss's
sounds, which are HIS and live in his scene, the track paths are a short
catalogue of constants on Music, because a path spelled out in three screens is
the one that goes stale when a file moves.

**Audio lives in `assets/music/`** - the one folder, on the `assets/` rule that
names audio outright as a thing shared across features. A track that needed
work before it could loop keeps its untouched export beside it in
`assets/music/src/`, on the enemies' and bosses' exact terms: `src/` is the
hand-owned original, the file above it is what the game plays.

**The last two floors are the one exception to all of that, and it is a
FLOOR's track rather than a boss's.** A biome may carry a `music` key, which
the generator writes into the level scene beside its title and game.gd reads
where it used to say `Music.DEFAULT`; the executive floor and the penthouse
both name `finale_loop.wav`, so the finale comes up as the lift doors open on
floor 11 and is still playing through the last fight. It had to hang on the
floor and not on Silverman for the reason a theme is HIS: a boss's track starts
where his bar goes up and leaves where it clears, so it can never cover the
floor below him, and one on him here would interrupt this twice in the last
four minutes of the game. He therefore declares no `music` at all - the one
boss in the building who doesn't - and `tests/test_music.gd` checks that
absence, because nothing else would notice a line being added to his scene.
Crossing the door costs nothing because `fade_to` is idempotent on the path,
which is the same trick the bed already relied on, one level up.

**A generated loop does not loop**, and it fails in THREE different ways. The
first is the seam: an ElevenLabs export ends mid-waveform, so the last sample
steps straight to the first and clicks once per pass - on `menu_loop.wav` that
step was 22376 of 32768, and every 30 seconds. The fix is a 12 ms equal-power
crossfade of the tail over the head, which costs 12 ms of length (0.04% across
a 30 s loop, well under a 32nd note) and takes the step to 33.

The second is worse and is what `level_loop.wav` arrived with: **the export
ENDS**, fading out over its last 3.75 s, so the loop dies away to silence and
then restarts at full level - a hole once a minute rather than a click. A
crossfade cannot fix that, because there is nothing left at the end to fade.
The music has to be cut back to the last whole BAR before the fade begins, and
only then crossfaded. That is the one measurement worth taking on a new track
before anything else: the tempo, so the cut lands on the grid. The bed is
90 BPM, so a bar is 2.667 s and the loop is 20 of them. Two traps sit in that
sentence. The BPM is the one the generator was ASKED for and not the one it
delivered - this export runs at 90.019, which is 11 ms of drift by the
twentieth bar and therefore longer than the crossfade - and the thing being
matched at a loop point is waveform PHASE, which is sharp at the millisecond:
cutting at the nominal 53.333 s rather than the measured 53.322 took the
tail-against-head correlation from 0.875 to -0.12. So the bar count picks WHICH
peak to cut at and the measurement says where it is - correlate the tail's last
second against the head's first, swept at sample resolution.

The third is the one `finale_loop.wav` arrived with, and it hides from both of
the checks the first two taught. **The export ends by drying up rather than by
fading down**: the hits keep landing at full level to the last bar - the
on-beat quarter-seconds measure +2.0 dB against the track's own body at 59.5 s,
which is to say nothing whatever is fading - while the SPACE between them
empties out, the off-beats falling -3.0, -4.6, -6.1, -11.6, -20.9 dB across the
last four seconds as the reverb tail is pulled away. Peak level says the track
is fine. The waveform's outline says the track is fine. What loops is a room
that goes dry for two seconds once a minute and then snaps back wet, which
reads as a skip rather than as a fade. The measurement that finds it is an
envelope in quarter-second buckets with the ON-beat and OFF-beat buckets read
SEPARATELY; the fix is the second failure's fix - cut back to the last whole
bar before the off-beats start to move (56.0 s, bar 28, where they part
at 56.75).

And a measurement that works on a sparse track does not work on a dense one.
The tail-against-head correlation above is how `level_loop` was placed, and on
this track it is noise: a broadband sweep peaked at +0.20 on a cut 40 ms off
the grid - a third of a 16th note, an audible stumble - because hats and noise
are uncorrelated between two passes of the same music and drown the alignment
they are averaged into. Swept on the LOW BAND alone (one-pole at 300 Hz, the
kick and the sub, which is what carries the grid) the same track gives a single
sharp peak of +0.86, falling to +0.32 sixty samples either side. **Correlate
the band that keeps the beat, not the whole mix.**

Check all three on any new music before wiring it up: the click is obvious once
heard and invisible in a waveform view, the fade is invisible in the waveform's
shape until you look at where the last seconds of level went, and the dry-up is
invisible in both, because the hits never move.

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

- **WINDOW MODE** - windowed or fullscreen. The game launches windowed at
  1920x1080, which is an exact 3x of the base viewport.
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
  at all, and the only labelling that stays true. The default is 150%. Names for the result were
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
  They drive the real game with synthesized input and exit 0/1. Eighteen suites,
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
  - `test_combat.gd` - guard telegraph and interrupts, wraith, warden, heavy,
    and the leash: that losing sight of the player does not stop a chase, that
    it ends 2.5s later, that the body walks back to the spot it was placed on,
    and that kiting drags it exactly 160 px and no further.
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
  - `test_barks.gd` - what Ahmed shouts: the hello, the taunt when he is
    kited, an attack announcing itself on the wind-up, being interrupted and
    being merely hurt saying different things, the concede line jumping the
    queue, and the subtitle taking itself down. Its own suite because a taunt
    needs a boss who never reaches anybody, which is the exact opposite of the
    fight test_bosses.gd runs.
  - `test_reinforcements.gd` - a second beat's trigger, its single-file
    arrival, the door it uses, the hold while the player stands in that door,
    that a beat fires once, and the head count. Builds the beat by hand in the
    empty lobby rather than walking nine floors to the one biome that has one.
  - `test_ivan.gd` - the third beat: that he waits for a fight and not
    merely for a quiet room, that he comes in by the door and crosses to his
    spot, that a late arrival can still be talked to (game.gd wires NPCs as
    they arrive, which is the failure that would be silent on six floors),
    that the hearts land on the last word and heal, one per head, once. Builds
    the beat by hand in the empty lobby, then checks the six floors off disk -
    that each carries the beat, sends him to its own spot, and gives him its OWN
    conversation. It also sweeps all six of those: every line names a clip,
    every clip is on disk, no two floors share a clip (they cut into one folder,
    so a collision silently plays another floor's read) and no two floors say
    the same line, which is the whole reason there are six files.
  - `test_dominique.gd` - the fourth beat, the one that hands over information
    rather than a heart: that they wait for a fight and not merely for a quiet
    room, that they come down the NORTH door while Ivan comes up the south one,
    that they cross to the spot and can be talked to after arriving late, and
    that nothing is healed by any of it. Its own suite because test_ivan.gd
    ends by hurting the player and counting hearts, and this one has to prove
    no heart is ever thrown. It also checks the RULE the three floors are only
    an instance of - a briefing under every boss floor and under no other - by
    reading the whole chain off disk, so a fourth boss cannot ship unannounced.
  - `test_enemy_sfx.gd` - the bestiary's noise: that all six own the cues
    their archetype can actually reach and no cue it can never reach, that
    every declared stream resolves, that the wraith's drain is a sealed loop
    rather than a one-shot with a flag on it, and that a death sound outlives
    the body that made it. Its own suite because that last one is destructive
    - it kills an enemy and counts what the room is left holding. What it
    deliberately does NOT check is that a one-shot is audible: headless has no
    `playing` and `--fixed-fps` makes `get_playback_position()` a coin flip
    (see test_menu.gd's note), so the evidence is structure plus the two calls
    that leave a visible mark - the loop flag, and the detached player. It
    also keeps the two mutterers: that each names its OWN lines file, that
    every line has a clip that really resolves (a missing one is legal and
    silent, so a typo is an enemy who moves their lips), that the poll gets a
    line out, that six spawned together do not share one countdown, and that
    none of it reaches the subtitle.
  - `test_dialogue.gd` - HR's whole induction: the prompt, the typewriter, a
    dead stick while she talks, the choices and the branch one takes, the
    escorted tour, the contract, and the wheel coming back. Driven by what is
    on screen rather than by frame numbers - a line's LENGTH is its duration,
    so numbered frames would need re-timing every time one is reworded. It also
    keeps her VOICE, and the check that matters there is not that audio is
    playing (see the wall-clock note below) but that the line is typed at the
    CLIP's rate rather than the flat one: that is arithmetic the game did on
    the stream's own length, so it can only pass if the clip was really found,
    loaded and applied, and it does not depend on the wall clock at all. Plus
    the sweep a silent-by-design miss needs: every line she speaks names a
    clip, and every clip named is on disk.
  - `test_player_sfx.gd` - the player's own noise: that the body declares
    every cue player.gd can fire and no cue it never will, that each resolves,
    that the charge stance is a sealed LOOP rather than a one-shot with a flag
    on it, and - the part that is not test_enemy_sfx.gd over again - that a
    body with its `Audio` child torn off still swings, still charges and still
    takes a hit. That last one is the promise the whole design rests on and is
    destructive, which is why this is its own suite. It measures a loop seam
    against the clip's WORST internal step where the bestiary's suite uses the
    mean, because the charge bed is quiet in the export and takes a large
    make-up gain: its samples land on a coarse quantization grid with a median
    step of zero, and a mean no actual step is near fails a perfect join.
  - `test_studio.gd` - floor 2's clock and the two things that read it: that a
    lamp with no clock in the room is furniture (checked in the LOBBY, because
    a promise about absence has to be tested where the thing is absent), that
    the cue warms the pools and the sign without hurting anybody, that the
    take then burns and the rig runs, and that a rig being pushed back to its
    mark is harmless even parked on top of you. Its own suite because checking
    a rhythm means standing still in one room for eleven seconds, which is the
    opposite of every other file here; test_flow.gd keeps only that the
    dressing still carries the clock. It also guards the one invariant a
    moving hazard could break without ever being placed: the rail's span
    against the door lane.
  - `test_scrubber.gd` - floor 5's wandering machines, and the shove they
    arrived with. Every check is a PROPERTY rather than a position, because
    there is no authored route to compare against: neither machine left its pen
    in 420 sampled frames, neither was ever on the door lane, both covered
    ground rather than wedging in a corner, and a staged bump costs health and
    position together. Then the push on its own terms - it moves you, it wears
    off, and three at once move you no further than one. The bump is STAGED (a
    machine placed beside the player and aimed) rather than waited for: standing
    about hoping to be found is a check that passes on a seed, and starting the
    machine far away makes the contact frame depend on the travel, which is what
    made the first version flaky.
  - `test_music.gd` - the finale across a door: that an ordinary floor plays
    the bed, that floor 11 gets the track its biome names, that the stream
    really resolved and its loop is sealed to the stream's real length, that
    the door into the penthouse does not restart it, that the boss standing
    there names no theme of his own, and the RULE those two floors are only an
    instance of - read off disk, so a `music` line pasted onto a room in the
    middle of the building fails here. Its own suite because it is the first
    check in this project that spans a DOOR rather than sitting in one room.
    The no-restart check SEEKS the playhead to 30 s before travelling rather
    than reading the position twice: headless mixing crawls (0.09 s across 160
    frames), so "the position advanced" is a coin flip that would pass a
    restart on a quiet frame, while a playhead parked where no fresh `play()`
    could leave it either survives the door or does not.
  - `test_surge.gd` - floor 3's wiring: that a charging line warns without
    hurting, that the head then crosses whoever stood on it, that the drop is
    exactly the node's own scaled damage rather than merely non-zero (one pass
    is one hit, which is what makes four runs fair), that the head parks off
    the line between runs, and that the cycle comes round again. Its headline
    check is the lane swept across all four runs - a surge is the second thing
    that could threaten x 246-300 without being placed in it, and unlike the
    dolly there are four.
  - `test_steering.gd` - getting round the furniture: that a guard with two
    desks between it and the player arrives anyway and swings, that it got
    there by going AROUND rather than by some accident of the geometry, that a
    body with no way round stops trying and walks home instead of grinding,
    that an enemy with nothing in its way still walks a dead straight line, and
    that a chair is something it walks through. Its own suite because it needs
    a room arranged WRONG - every floor in the game is dressed so the fight
    works, so none of them can ask this - and it builds the bad case by hand in
    the empty lobby, the way test_reinforcements.gd builds its beat.
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
