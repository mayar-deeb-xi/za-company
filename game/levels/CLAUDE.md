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
                        where the biome asks for it, and the gym asks for none
      furniture/        desk.tscn  chair.tscn ...      whatever it
      hardware/         server_rack.tscn  printer.tscn ...  places,
      markings/         boxing_ring.tscn  rug.tscn          by kind
      signs/            notice.tscn ...
```

**A level folder is split by what a file IS, not by its type,** and the split is
between two groups that behave completely differently. The room is a handful of
files that never grow. `props/` holds one scene per prop the biome uses and
grows every time a floor wants new furniture - the bullpen wanted sixteen, which
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
Removing them halved a level folder (bullpen 37 files to 21, lobby 28 to 16).

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
not have one, and Ahmed's office, because the only thing in there meant to hurt
is Ahmed). Every style keeps the same canvas size and foot, so the scenes and
collision boxes are untouched by the choice - only the art differs. The split
exists because the classical column is most of what makes the marble hall read
as a hall, and it was also most of what made the office lobby read as a temple.
What a room uses to break up its floor is exactly what changes between a lobby
and a bullpen. A biome can also override the colonnade's `columns` layout (a
furnished room needs the floor a full colonnade takes up), hand in an EMPTY one
for no colonnade at all (the gym: a tight arena with nothing in it to hide
behind, and no column scene in its folder either), and ask for a `runner`,
which tints the central floor band toward the accent so it reads as carpet
rather than as more of the same stone.

A room can also be divided by FURNITURE rather than by its column style, and
the shared floor is the case: its media half is walled into two glass-fronted
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
Ahmed's office and the marble hall say it), and NO heart unless the floor says
`"heart": true` - which only the lobby does. Floor 1 is where a player finds out
what a heal is; from floor 2 up the supply is meant to be Ivan carrying one to
you, not a room leaving one lying about. A declined fixture gets neither the
instance nor the scene: the generator deletes the stale `torch.tscn` or
`health_item.tscn` rather than leave a level folder holding a fixture nothing
points at. Their art comes from build_biomes.gd like everything else: the stand
and plinth in the biome's own ramp, the flame and the heart in fixed colours,
because fire and health have to read the same in every biome.
