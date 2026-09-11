# Levels - how a room works

Deep dive for `game/levels/` and game.gd's hosting of it. The cross-cutting
rules (regeneration semantics, the no-room-state rule, preload-not-class_name)
live in the root CLAUDE.md; the generators and biome data that write these
folders are documented in `tools/CLAUDE.md`.

## The host and the room

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

## A level owns everything in it

Its folder holds its own tileset, its own doorway art, its own `door.tscn` and
its own copy of every prop it places, each with that biome's palette baked in -
no level borrows another's. Levels are meant to diverge: different styles,
different props, different enemies, doors that lock.

```
game/levels/
  level.gd            base script every level scene runs
  door_base.gd        shared: how a door tells game.gd to swap levels
  hazard_base.gd      shared: presses take_damage() on the player it overlaps
  pickup_base.gd      shared: heal() on touch, consumed only if it healed
  <biome>/            THE ROOM - five files, and it never grows
    <biome>.tscn        the level
    tileset.tres        its floors and walls
    doorway_out.tres    its passage up, lit by the room beyond
    doorway_back.tres   its passage down
    door.tscn           how it connects
    props/            EVERYTHING STANDING IN IT - one scene each, on the
                      same shelves as tools/props/
      fixtures/         column.tscn, torch.tscn, health_item.tscn - each only
                        where the biome asks for it - the gym and the
                        penthouse ask for none
      furniture/        desk.tscn  chair.tscn ...      whatever it
      hardware/         server_rack.tscn  printer.tscn ...  places,
      markings/         boxing_ring.tscn  rug.tscn          by kind
      openings/         city_window.tscn                    of thing
      signs/            notice.tscn ...
```

**A level folder is split by what a file IS, not by its type,** and the split is
between two groups that behave completely differently. The room is a handful of
files that never grow. `props/` holds one scene per prop the biome uses and
grows every time a floor wants new furniture - asset recovery wanted sixteen, which
buried the five files that say what the level actually is. Inside `props/` the
scenes sit on the same shelves as their painters in `tools/props/` (the
generator asks `Props.shelf_of()` where to put each one), so finding a prop's
scene in a level is the same walk as finding its brush - with one renaming to
know: the fixtures shelf is named for the ROLE in the room, not the painter, so
hazard.gd paints `torch.tscn` and heart.gd paints `health_item.tscn`.

**Each prop scene carries its own picture, embedded** as a `[sub_resource]`
right beside its collision shape. There used to be a matching `<prop>_art.tres`
next to every prop scene, and every one of those had exactly one consumer: its
own sibling. That is precisely what a sub-resource is for, and the collision box
was already stored that way - the texture was the odd one out, for no reason.
Removing them halved a level folder (asset recovery 37 files to 21, lobby 28 to 16).

The two doorway textures are the exception and stay as files, because they are
the one texture assigned **per instance**: the level scene hands `doorway_out`
to its north door and `doorway_back` to its south one, so their consumer is the
level, not a prop scene.

Architecture and the hazard are per-biome **styles**, not one look for the whole
game: `column` picks the fluted classical stone, a glazed steel pillar or a
cubicle divider, and `hazard` picks the standing torch, a sparking floor
polisher, an arcing power strip, a ring light knocked over and left at full
output, a photocopier jammed with the fuser still going - or `"none"`, which is
a floor with nothing on it that hurts (the lobby, because a tutorial room must
not have one, and Ahmed's office, the gym and the penthouse, because a room
built around one fight is a room where a burn is the floor's fault). Every
style keeps the same canvas size and foot, so the scenes and collision boxes
are untouched by the choice - only the art differs. The split
exists because the classical column is most of what makes the marble hall read
as a hall, and it was also most of what made the office lobby read as a temple.
What a room uses to break up its floor is exactly what changes between a lobby
and a recovery floor. A biome can also override the colonnade's `columns` layout (a
furnished room needs the floor a full colonnade takes up), hand in an EMPTY one
for no colonnade at all (the gym: a tight arena with nothing in it to hide
behind, and no column scene in its folder either), and ask for a `runner`,
which tints the central floor band toward the accent so it reads as carpet
rather than as more of the same stone.

A room can also be divided by FURNITURE rather than by its column style, and
the hub is the case: its media half is walled into two glass-fronted
offices by a run of `partition` props, because a `columns` layout is rows
times columns and so cannot leave a gap where a door goes. The glass is
translucent on purpose - a wall is drawn upwards from its foot, so an opaque
one would hide anybody standing in the office. The executive floor takes the
same prop the other way: one run of it crosses the WHOLE room with a single
gap left on the door line, so a partition wall stops being furniture that
divides a half and becomes the chokepoint the room is fought at. See
tools/CLAUDE.md.

The `_base.gd` scripts are shared because each is one side of a handshake the
other party owns: game.gd performs the swap doors report, and the player owns
the take_damage()/heal() API hazards and pickups press. Everything else about a
door, torch or heart is the level's: override `can_travel()` in a level's own
script for a lock, or restructure that level's scenes freely. A column has no
shared behaviour at all and carries no script.

## Doors and spawns

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

## Dressing

Both of a level's health fixtures are per-biome now, and both default the way
the game wants: a hazard unless the floor says `"hazard": "none"` (the lobby,
Ahmed's office, the gym, the penthouse and the marble hall say it), and NO
heart unless the floor says `"heart": true` - which only the lobby does. Floor
1 is where a player finds out what a heal is; from floor 2 up the supply is
meant to be Ivan carrying one to you, not a room leaving one lying about. A
declined fixture gets neither the instance nor the scene: the generator
deletes the stale `torch.tscn` or `health_item.tscn` rather than leave a level
folder holding a fixture nothing points at. Their art comes from
build_biomes.gd like everything else: the stand and plinth in the biome's own
ramp, the flame and the heart in fixed colours, because fire and health have
to read the same in every biome.

## Reinforcements - a room's second beat

A floor with `reinforcements` in its biome gets one extra node,
`Reinforcements`, holding the list as an export; a floor without the key gets no
node at all, which today is the lobby alone. **Every other floor has one**, and
the shape of a floor's beat is the shape of its lesson restated:

| floor | cue | base group | `per_head` | in by |
|-------|-----|------------|-----------|-------|
| F1 lobby | — | *none: see below* | — | — |
| F2 content_studio | 2 kills | 2 `social_media` | +1 `social_media` | south |
| F3 call_center | 3 kills | 2 `office_boy` | +1 `office_boy` | south |
| F4 ahmed_office | HP 72 / 48 / 24 | drain+boy / **slow** / 2 drains | +drain / +boy / +drain | south |
| F5 the_hub | 2 kills | 2 `office_boy` | +1 `office_boy` | south |
| F6 marble_hall | 2 kills | 2 `office_boy` | +1 `office_boy` | **north** |
| F7 innovation_lab | 2 kills | one of each | +1 `office_boy` | south |
| F8 conflict_resolution | HP 108 / 72 / 36 | 2 drains / **slow**+drain / 2 drains+**slow** | +drain / +boy / +drain | south |
| F9 asset_recovery | 3 kills | 3 `office_boy` | +2 `office_boy` | south |
| F10 hellfire | 4 kills | 2 `regular` + 1 `wraith` | +1 `regular` | **north** |
| F11 executive_floor | 4 kills | 1 `warden` + 2 `regular` | +1 `regular` | chokepoint |
| F12 khaled_office | HP 144 / 96 / 48 | 2 drains / **slow**+boy / 2 drains+boy | +drain / +boy / +drain | south |

Four of those rows carry something worth knowing:

- **F1 has no beat, and could not have one.** The lobby is deliberately the one
  room with nobody in it - the first thing a new player does is walk, and floor
  1 is where they learn that safely - so it has no kills to count and an
  `after_kills` there would never fire. The emptiness and the missing beat are
  one decision, not two.
- **F6 and F10 come in by the NORTH door** - the way out. Half the room is dead,
  the stairs are in sight, and the beat arrives from the direction the player
  has stopped watching. On hellfire it also says what the floor above is.
- **F12 is authored and inert.** Khaled is build step 6; `_due()` returns false
  while `Props/Boss` is null, so the list costs nothing standing there. Its
  thresholds ASSUME 192 HP and nothing will complain if he lands elsewhere -
  set them from his real `max_health` when the scene exists.
- **F9 has the heaviest `per_head` in the game** (+2 rather than +1), because
  the crowd floor is the one whose lesson IS the head count.

## `per_head` - what a crowd brings, and what it never brings

`enemies` is a beat's base group and never scales. `per_head` is added once per
head BEYOND the first, so `bodies = len(enemies) + (heads - 1) * len(per_head)`.

The split is not a convenience. Multiplying one list gave every extra player a
copy of every type in the beat - which on a boss floor means a second
`call_center`, and **two slowers do not stack a slow, they refresh it.** A
permanently slowed player cannot sidestep a telegraph, and being unable to
dodge is the one thing here that reads as unfair rather than hard. So
**`call_center` appears in no floor's `per_head`**, a rule
`tests/test_reinforcements.gd` checks against both boss floors' baked data.

It also makes head count matter MORE: a beat can hand a solo player the
arrangement it was tuned for and still answer a party of four, instead of every
number being a multiple of the solo one.

## Relief - a room's third beat

A floor with `relief` in its biome gets one more node, `Relief`
(`game/levels/relief.gd`), and it is the only beat that is not a fight: when the
room is finally clear, **Ivan walks in through the door the player came by**,
crosses to an authored spot, and waits there with a heart per head. Six floors
have one:

| floor | he stands at | why that floor |
|-------|--------------|----------------|
| F3 call_center | (208, 168) | first floor where a slow near two guards kills; last before Ahmed |
| F4 ahmed_office | (180, 160) | after Ahmed concedes |
| F8 conflict_resolution | (412, 144) | ringside, after Mostafa |
| F9 asset_recovery | (80, 180) | the heaviest `per_head` in the game deserves the matching heal |
| F11 executive_floor | (324, 196) | the exam floor, last stop before the roof |
| F12 khaled_office | (400, 176) | the finale |

**He is an arrival, not a placement, and that is the whole design.** Standing him
in the room from the first frame would put a solid 64px body inside an
arrangement whose positions were picked against sight radii and clear lanes, and
put a heart on offer while the fight the floor is FOR is still standing. His
healing reads as a lifeline because it arrives after the cost has been paid. So
he has an authored DESTINATION and no authored position, exactly as a
reinforcement has neither - you cannot walk in at a spot. The furniture rule
applies to that destination alone: by the time he reaches it the room is empty,
so all it has to clear is the scenery and the door line.

He lives beside reinforcements.gd rather than inside it because the two ask
opposite questions of the same room - is the fight far enough along, and is it
over - and threading a friendly body through a script that spawns enemies would
cost both of them their one sentence.

"Over" has to mean over on both kinds of floor, and each of these was a way of
getting it wrong:

- **A conceded boss is not a hostile.** `_hostiles()` counts the `enemies` group
  and skips anybody who has given up, which is the one line that lets a boss
  floor reach this cue at all: a boss is in that group and is never freed, so
  counting the group alone can never reach zero on the four floors that have
  one.
- **He waits until he has seen a fight.** A room is clear on its first frame
  too, and an Ivan who walks in before anything has happened is a vending
  machine in a doorway. The cue is a room that has been EMPTIED.
- **He waits for the second beat to be spent.** A floor with reinforcements is
  quiet between the last kill of the opening arrangement and the group it cues,
  and quiet is not clear. He asks the sibling node (`spent()`), the same
  ask-don't-listen shape the boss door and the beats themselves use.

Two more things follow from him arriving late:

- **He does not greet.** `greets` fires on the talk radius being ENTERED, and a
  man walking across a room drags that radius over the player on the way, so a
  greeting would land mid-stride. The deeper reason is the lobby's: a
  conversation that starts itself takes the wheel off a player who has pressed
  nothing, and this one has just finished a fight.
- **game.gd wires NPCs as they arrive, not as a room is built.** Doors can be
  swept once, because a room has all the doors it will ever have; people it does
  not. `_on_node_added` is what keeps a late Ivan's prompt from being a key that
  does nothing - a failure that would be silent on all six floors.

The gift itself is `game/npcs/ivan/ivan.gd`: one heart per head from
`game/heads.gd`, thrown on the falling edge of the conversation, once per visit.
See game/npcs/CLAUDE.md.

## The pair that makes a boss fight annoying

Boss floors field `social_media` and `call_center` rather than boys, and the
choice is pointed at the thing a boss fight actually is - reading one telegraph:

- **`social_media` has no wind-up to interrupt.** Its harm is proximity, so it
  cannot be answered with the timing the boss is teaching. It just bleeds you
  while you watch him.
- **`call_center` takes the dodge away.** Ahmed's fire wave is a sidestep and
  nothing else; Mostafa's rush needs you to move. Slowed, neither is dodgeable.

So every boss floor runs drain, then the slow at the halfway point, then drain
again - the slower arriving as one distinct event rather than a state the player
lives in. ONE of him per threshold. Mostafa's final quarter is the single place
in the game where two can be alive at once, as the deliberate peak, and it is
the first thing to check in play: if it reads as a room you cannot move in
rather than a crescendo, that is the beat to thin.

**This is deliberately not waves, and the reason is the whole design.** A room
here is an ARRANGEMENT, not a population - the content studio is three
overlapping drain fields you route around, asset recovery is four boys behind a
colonnade you pull one at a time, the executive floor is one 64px gap you
choose to step through. Every one of those fights is made of WHERE the enemies
are, and a stream of respawns flattens all three into the same fight, because a
room's shape only matters while its enemies are placed. So a beat is finite,
authored and fires once; the room clears and stays clear.

**Every floor having one is not a walking back of that.** What "not waves"
forbids is a floor answering a kill with a respawn forever; what each floor has
is one authored group, of known types, at a known cue, once. The test of a beat
is still whether it restates the floor's own lesson rather than adding bodies to
it - which is why the studio's beat is drains and not boys, why the call floor's
adds no slower to the two already standing there, why the executive floor's
arrives at the chokepoint and nowhere else, and why the lobby has none at all.

Three things follow from that and are worth knowing before touching it:

- **A reinforcement has no position, and that is the point.** Everything in
  `enemies` is an authored `at`, picked against sight radii, the door line and
  the clear lanes - and you cannot multiply a spot. A beat names a spawn marker
  instead (`from`, default `start`) and asks the level for it through
  `has_method`, so the whole list fits on one node. A floor can name markers of
  its own under `spawns`, and the executive floor is why that key exists: its
  chokepoint is ON the door line, where nothing may be *placed*, so a beat is
  the only legal way to put a body at the floor's own idea. That marker sits
  SOUTH of the glass deliberately - enemies slide off what they hit and have no
  pathfinding, so a warden arriving on the far side of the partitioning would
  grind along it instead of coming through the gap.
- **Which makes it the one place head count can live.** `_head_count()` returns
  1 today and multiplies the group when a second player exists. It obeys the
  rule `Difficulty` already obeys - scale what the world sends, never what it is
  made of - so more players means more BODIES, never a tougher one, for the same
  reason no difficulty mode touches the 24/17/36 breakpoints.
- **Nothing signals it.** Enemies die by `queue_free()` in enemy_base.gd and
  there is no death signal; the node counts the `enemies` group instead, exactly
  as boss_door.gd asks its boss whether it has conceded. Ask-don't-listen is the
  shape the whole level layer uses, and this is not a workaround for a missing
  signal. The health cue is the same shape one step on - it ASKS `Props/Boss`
  what he has left - which is why it is ten lines in `_due()` rather than a
  summon hook on boss_base.gd: a summon would need its own release interval,
  doorway hold and head count, all of which already live here.

**A boss floor's beat is cued by `at_boss_health`, not `after_kills`,** and the
reason is not preference. A boss is in the `enemies` group and is never freed -
he is still standing in the room when you leave - so he inflates the population
by one and never subtracts, and `_killed()` reports only the adds. On a floor
whose whole population is him the only number it can reach is **0**, and a beat
cued at 0 is a placement that walks in through a door.

Which is also why a boss floor's adds belong in its beat rather than its
`enemies` list. An add *placed* in an arena stands in it from the first frame,
which is exactly what "one fight is enough to read at a time" was protecting; an
add arriving at a threshold is a PHASE of the one fight. The concede guard in
`_due()` is load-bearing to that: he concedes AT zero, which satisfies every
threshold at once, so without it the last beat of a fight lands on the frame the
fight ends.

One consequence worth seeing in play before trusting it: all of a boss floor's
add budget sits in its beat, so those floors are the most head-count-scalable in
the game. Two players fighting Ahmed get two boys per threshold; four get four.

Two rules keep an arrival from being unfair, and both are load-bearing.
Arrivals are single file, `RELEASE_INTERVAL` apart, because a doorway is single
file and two bodies in the same 16px of threshold is a stack rather than an
entrance. And an arrival HOLDS while a player is within `SAFE_RADIUS` of the
threshold - dropping an enemy on somebody is the one thing a spawn must never
do, and standing in the doorway is exactly where a player who has just cleared
three quarters of a room tends to be. The hold is indefinite and costs nothing.

The interval spaces arrivals within a beat and must never delay the start of
one: `_cooldown` is zeroed when a beat is queued, or a beat would silently
inherit the previous beat's wait before its own first body.

Still to come, and it is the next thing this wants: a beat has no TELEGRAPH.
The staggered walk-in through a known door carries it for now, and the door
that opens is the honest place to put one.
