# Tools - furnishing rooms from data

Deep dive for `tools/`. WHAT each generator writes and the regenerate-don't-
hand-edit rules live in the root CLAUDE.md's "Generated resources" table; the
anatomy of the rooms these scripts produce is `game/levels/CLAUDE.md`. This
file is how furniture works and how floors are added.

Nothing here is ever run by the game, and nothing here is run BY the editor
either: `addons/za_build/` puts these scripts on the Project > Tools menu, but
each item spawns a headless child Godot to run them, exactly as the command
line does. So every script in this folder can go on assuming it owns the
process it is in - a fresh resource cache, `print` going somewhere, `quit()`
meaning quit - which is what makes the two entry points the same entry point.

## A room is furnished from data, not by hand

`tools/props/` holds one file per prop type, shelved by what a prop IS -
`furniture/` (reception counter, desk, chair, water cooler, sofa, coffee table,
pot plant alive and dead, call-centre station, media edit bay, engineer's
workstation, boardroom table, the executive's own bare desk, filter coffee
machine, drinks trolley, glass partition, awards cabinet), `hardware/` (server
rack, printer, stacked dead monitors, opened tower, toolbox, cable spool,
scrap pile, loose debris, a camera on its tripod, a ring light, a paper
backdrop, a punch bag, a rack of weights), `signs/` (the welcome banner, a
taped-up notice, two whiteboards - one lettered, one an architecture diagram
nobody may erase - two printed posters, two lit boards with a number on them,
the founder's portrait and one sticky note lying face down), `markings/` (what
is spread on the floor rather than stood on it: the gym's boxing ring, the
executive floor's rug and the studio's dolly track) and `openings/` (what is
cut through the building's shell rather than stood against it: the penthouse's
city window) - and a biome
says which ones it puts where in its own `props` list, exactly the way it
already says which enemies it gets. That list drives everything:
build_levels.gd writes a scene per type into the level's `props/`, paints its
picture in the biome's palette and bakes it in, then instances them.
`build_levels.gd -- lobby` therefore reproduces the dressed room rather than
resetting it to a bare box - which is what makes the generator's "re-running
overwrites hand-dressing" warning survivable for twelve floors.

**The folder is the catalogue, and the shelves are only organisation.**
`tools/props.gd` is the facade the generators call; it scans the shelves once
and resolves `{"type": "desk"}` to whichever shelf holds `desk.gd`, with no
registry in between and no shelf name in the data - so re-shelving a prop
touches no floor's file, and two shelves claiming one name fail loudly at
first lookup. Each prop file declares its `SIZE`, its `BLOCKS`, optionally its
`PIN`, and a `paint(spec)` - so adding a prop to the game is one new 30-90
line file on the right shelf plus a position in a floor's data, and a typo'd
type fails at generation time with "nothing in tools/props/ draws 'tabel'".
`_brush.gd` is the shared painting kit (the primitives, the multi-user fixed
colours, the pixel font), kept out of the catalogue by sitting at the root -
only the shelves are scanned. `fixtures/` is the shelf `known()` refuses:
levels place column, hazard, heart and the studio's dolly themselves, so
those can be painted but never listed as furniture. Every one of them is a
floor's to decline - an empty `columns` layout, `"hazard": "none"`, and
`"heart": true` or `"dolly"` left unsaid - and the generator then deletes that
level's column.tscn, torch.tscn, health_item.tscn or dolly.tscn rather than
leave a scene nothing points at. The gym and Khaled's office decline the lot,
and both have an empty `fixtures/` folder to show for it.

**And a shelf that does not exist yet is made by putting the first file on
it.** props.gd enumerates the directories under `tools/props/` rather than
holding a list of them, so a new shelf is a new folder and nothing else -
build_levels.gd shelves the level's scene to match on its own. Two shelves
have been opened this way and both for the same reason: `markings/` because
the boxing ring is neither furniture, hardware nor a sign but paint on the
floor, and `openings/` because the city window is none of those four either -
it is a hole cut through the building's shell. The test is whether shelving
the new prop somewhere existing would make the catalogue lie about what that
shelf holds. A window is not a sign just because signs also hang on walls.

The division of labour between the two generators is by **subject**, not by
file type: build_biomes.gd paints the ROOM (its tileset and doorways, the only
art a level scene points at as files) and tools/props/ paints everything
standing in the room. One consequence to know: re-palettizing a prop needs
build_levels.gd, not just build_biomes.gd, because that is where its picture
gets baked in.

**A re-run with unchanged data writes a byte-identical file**, and
`stable_ids.gd` is why that holds. Two identifiers used to churn: the engine
mints a random per-node `unique_id` every time a scene is packed, and a
headless save drops the `uid="uid://..."` the editor stamps into a bare
header - so the editor and the generators took turns rewriting every file.
Both generators now route every save through stable_ids.gd, which re-derives
node ids from (file, parent, name) - the engine preserves ids it finds on
load, so the editor never re-rolls them - and splices the captured uid back.
The payoff is that `git diff` after a regen shows real changes only, and an
EMPTY diff is the proof a re-run reproduced the dressed room. Run the file
standalone to normalize scenes already on disk without regenerating them.

## Drawing a prop

Props are drawn, not sampled, like the columns and torches and for the same
reason: the shared dungeon sheet has no furniture in it. Bodies come out of the
biome's own ramp through `Biomes.shade()`, so a desk in hellfire is a hellfire
desk for free. Only what has to read the same everywhere is fixed - water,
foliage, a monitor's dark screen - the argument that already fixes fire and
hearts. Two numbers are load-bearing in every prop file. `BLOCKS` is the
collision box, and a prop blocks only its base (the column's trick) so the
player passes behind its upper half and Y-sorting draws the two in the right
order; a `BLOCKS` of zero is decor, and gets a bare Node2D rather than a body
with no shape. And heights are measured against the 24 px standing torch, which
is about as tall as a character: the first draft ignored that reference and drew
a 30 px desk, which looks like nothing on its own and makes the whole cast read
as children the moment one of them stands next to it.

**A prop that blocks nothing is a tool, not an oversight.** `debris` - litter on
the floor - has a `blocks` of zero and is the answer to a brief that pulls two
ways: asset recovery has to look full of junk AND leave floor for a four-on-one
fight and an AoE. Solid props cannot do both, so the junk is a thick perimeter
and the middle gets litter. It is also the one prop drawn without an outline,
since an outline is what gives a prop volume and this is meant to read as marks
on the floor; and nothing in it is red or gold, because the heart pickup is red
and the hazard's sparks are gold, and litter that borrows either colour is
litter the player crosses the room to try to pick up.

**Putting something ON a surface is a canvas trick, not a Y-sort one.** Every
prop is drawn upwards from its foot and Y-sorting reads the node's y, so an
object lying on a desk cannot simply be placed where it lies: pinned there it
sorts BEFORE the desk and the desk is drawn over it. `sticky_note` is the
worked case. Its canvas is 30 px tall with the note in the top ten and the
rest transparent; it is placed two pixels SOUTH of the desk's foot, so it
sorts after the desk, and its art - twenty pixels up from that foot - lands on
the desktop. The alternative, painting the note into the desk, was rejected
for a reason that has nothing to do with drawing: the ending turns the note
over, so it needs a node of its own in the level scene for a script to find.

**A prop can also grow BEHAVIOUR, and it declares it the same way it declares
its size.** Two more optional constants, and most props will never carry
either - a desk is a picture with a box under it:

```gdscript
const SCRIPT      := "res://game/levels/on_air.gd"     # on the prop itself
const BURNS       := Vector2(30, 18)                   # a Burn area at its foot
const BURN_SCRIPT := "res://game/levels/hot_light.gd"  # what drives that area
```

`SCRIPT` is for a thing that changes what it LOOKS like - the studio's neon sign
reading the floor's clock. `BURNS` is for a thing that HURTS, and it is a
separate node rather than a flag on the collision box because they are different
sizes on the one prop that has both: a ring light blocks with its tripod and
burns across a patch of floor several times wider, and one node cannot be a
solid body and a trigger at two sizes. `BURN_SCRIPT` defaults to the shared
`hazard_base.gd`, which is the honest default - a thing that burns and says
nothing else about itself burns the way the torch does.

Both keep the rule every optional thing in this project keeps: **a prop that
declares neither is written exactly as it always was, and a script that finds
nothing to read does nothing.** That is what lets `ring_light` be a hazard on
the content studio and ordinary furniture on any floor that stands one without
running a clock - see game/levels/CLAUDE.md's *The clock*. build_levels.gd was
always going to need this (its own comment promised the power strip and the
photocopier would arrive as hazards); the studio's lighting got there first.

**A prop can also be architecture.** The colonnade is a fixture the level
places itself and its layout is a cross product of rows and columns, which
describes a grid of pillars and nothing else - so the hub's glass
offices are furniture instead. `partition` is 32 px of wall, art and collision
box both, and a run of positions with one left out of the list is a wall with
a doorway in it, which no `columns` layout can express. Two things follow from
walling a room this way. Its glazing is genuinely translucent, because a wall
is drawn upwards from its foot and an opaque one hides whoever is standing
behind it - which is asset recovery's lesson about an enemy parked on a divider's
x, met head on. And a bay is a pocket, so an enemy placed on a floor like this
one belongs deliberately inside a bay or deliberately outside it, never on the
doorway.

**And a wall with one gap in it is a chokepoint**, which the executive floor
is built on: fourteen bays run the full width of the room at one y with a
64 px opening left on the door line, so the whole northern half - boardroom
and trophy wall - is reached through one place. That is the difference between
partitioning a room and dividing it, and it is worth being deliberate about
which one a floor is doing, because the second changes how it fights. The gap
sits on the door line for the reason every floor keeps that line clear, and
the enemies a floor like this gets belong on ONE side of the glass or standing
in the mouth of the gap - an enemy on the far side of a full-width wall grinds
along it rather than coming round, since enemies slide off what they hit and
have no pathfinding.

Solid props matter to the enemies too, not just the player: enemies walk
straight at the player and slide off whatever they hit, with no pathfinding to
recover from a pocket. So a furnished room must not be a maze, and nothing solid
should sit on the line an enemy walks from its post to the middle of the room.

_brush.gd also carries a 5x5 pixel font - uppercase and, since the call floor's
wallboard needed to write a number, digits - because half of what makes a
company office funny is what is written on the walls. A sign's words are a
`TEXT` constant in its own file, not baked into a painter, so a floor can put up
its own words without new drawing code - the banner says WELCOME / NEW HIRES,
the notice says OUT OF ORDER, the counter says RECEPTION, the hub's
whiteboard says SMILE / THEY CAN / HEAR IT and its poster says FIX IT / IN
POST, the call floor's wallboard says CALLS / WAITING / 142 with the figure in
red, the innovation lab's whiteboard says DO NOT ERASE under a diagram it does not
explain, its build board says BUILD / FAILED, and the executive floor's
portrait says only FOUNDER on a brass plaque - one word, because a portrait
that has to explain who it is of is not a portrait of anybody important.
The last sign in the building has no `TEXT` at all: the penthouse's
`sticky_note` is face down, so what it says is four grey smudges of ink coming
through the back of it, and the ending is where it gets turned over.

## Adding and inserting a biome

Adding a biome: one new data file in `tools/biomes/` plus its name in
`tools/biomes.gd`'s `CHAIN`, then run build_biomes.gd and build_levels.gd.
Appending to `CHAIN` gives the previous last level a north door automatically.

**Inserting** one in the middle - which is how the office floors were built
in front of the two demo biomes - changes its NEIGHBOURS as well, and this
is the step to get wrong: a door's `target_level` is baked into the level
scene by the generator, so the level before the new one still points past it
and the level after it still points back past it until both are rebuilt.
Pass all three names: `build_levels.gd -- <before> <new> <after>`.

**Reordering** is the same problem with a longer blast radius. Moving the
marble hall and hellfire into the middle of the building changed seven levels'
neighbours at once, and every one of them had to be named; when in doubt, name
them all. It cost hellfire a placement too - it gained a north door, and its
enemies had been lined along the north wall on the assumption that nobody ever
walked past them. A room that gains a door has to re-earn the rule every other
room keeps: every sight radius clear of the lane the two doors line up on.

build_biomes.gd always does every biome, so the doorway textures (each lit by
the colour of the place on the other side) come out right on their own.

## Bosses

`build_bosses.gd` is build_enemies.gd with a different seed: a boss is not
recoloured from the CC0 body but painted by its own `tools/bosses/<id>.gd`
from `game/bosses/<id>/poses.gd`, into a 64 px sheet, once - then sliced
from disk every run. A boss floor places him through the biome's `boss` key,
which build_levels.gd instances as `Props/Boss` and answers by giving the
north door the lock script. The rest is game/bosses/CLAUDE.md.

## Voice and sound effects - the python, and the generators that cost money

`tools/voice/` and `tools/sfx/` break two rules this folder otherwise keeps,
and both breaks are deliberate. What follows describes the voice; `tools/sfx/`
is the same shape and the differences are at the end.

It is **python rather than GDScript**, because it talks to a web API and
Godot's headless HTTP client is a poor place to do that. Everything it writes
is ordinary art the game loads like any other file, so no game code knows it
exists - which is the test that keeps it honest as a tool rather than a
dependency. The usual split still holds inside it: `cut.py` is the mechanism
and `<who>.py` is that one mouth's recipe, the way props.gd is the facade and
each prop file is a prop.

**Two shapes of mouth, one driver.** A boss shouts on CUES - `taunts.gd` maps a
cue to the several things he might say on it, and his clip is named after the
cue and the pick (`taunt_1.wav`), derived, because nothing chose those names.
An NPC has a CONVERSATION - `welcome.gd`, a flat list said once each in order -
and its clip name is AUTHORED: read back out of the `voice` path the beat
already carries for the game to load. The recipe says which by declaring
`BEATS` instead of `LINES`, and `jobs()` flattens both into one list so
everything below it is shared.

That split is worth the branch. Lines get written into the MIDDLE of an
induction, and a derived number would renumber every clip after the insert -
which on a generator that costs money and never repeats a performance means
re-billing and re-recording lines nobody touched.

And **it is not free and not deterministic**, which every other generator here
is. Re-running build_levels.gd costs nothing and reproduces the file; re-running
this costs credits and produces a DIFFERENT performance of the same line. Two
consequences:

- A take somebody listened to and approved is pinned in the recipe's `KEEP`
  and skipped. Without that, a routine re-run quietly replaces a chosen read.
- Existing files are skipped by default; `--force` is what re-cuts them.

`--verify` transcribes every clip back and compares it to the line it was cut
from. That is not belt-and-braces: the delivery is given to the model as an
inline tag (`[furious, roaring]`), and the failure mode is the model READING
the tag aloud instead of acting on it - which is silent in a waveform, obvious
in a fight, and invisible to anyone who does not listen to all twenty-three.
Its `SPELLINGS` map exists so the check means something: a transcriber that
writes "20" for a spoken "twenty" would otherwise flag the same two lines
forever, and a check that always fails the same way stops being read.

A spelling is a **phrase on both sides**, not a word for a word, because the
habits that turn up do not line up one-for-one - a clock written `8:59` comes
back as three words, and no word-for-word map can put those together. Both
texts are normalized and then rewritten by the same table, longest rule first
so `nine` cannot claim the tail of `fifty nine`. And the transcriber is not
deterministic either: the same take can read clean on one pass and show a
homophone or an unpacked contraction on the next, which is the give-away that
the difference is in the listener rather than in the voice - transcribe it a
second time before adding a rule for it.

The audio rules themselves - 48 kHz mono, no ffmpeg, levelled on speech rather
than on peaks - are in cut.py's own header and in CREDITS.md.

### It is not just bosses any more

`cut.py social_media` and `cut.py call_center` cut the two enemies who mutter
to themselves, and **not one line of cut.py changed to make that work**. A
recipe names a voice, an output folder and a `.gd` holding `const LINES`; none
of those ever cared whether the mouth had a health bar. That is the test the
split was built to pass, and it passed the first time it was asked.

Two things about those recipes are worth copying rather than re-deriving:

- **Stability runs the opposite way to a boss's.** Ahmed's roars are at 0.0,
  which lets the model off its leash and gives nine cues nine characters. A
  mutterer has ONE cue and eight lines that must sound like the same person on
  the same bad afternoon, so stability is 0.65-0.70. At a boss's setting one
  line came back screamed and one shrugged.
- **They are levelled at -31, not -19.** A boss is the loudest thing in his
  room; a mutter must sit under the telegraph of the wind-up it is muttering
  through. See game/enemies/CLAUDE.md's The mutters.

### tools/sfx - the same shape, for things that are not a voice

`make.py enemies` cuts the bestiary's sounds: the mechanism in `make.py`, the
audio kit in `wav.py`, and every prompt, length and level in `enemies.py`. The
recipe/mechanism split, the `KEEP` pins and the skip-what-exists default are
cut.py's, deliberately - a second pipeline that behaved differently would be a
second set of habits to remember.

Four things differ, and each is the endpoint rather than a preference:

- `/v1/sound-generation` returns STEREO PCM where text-to-speech returns mono,
  so everything is summed down first. The channel count is DERIVED from the
  length against the duration asked for rather than assumed, because a
  pipeline that would silently go half-speed the day that changes is not worth
  two saved lines.
- There is no transcript, so nothing can be verified by machine the way
  `--verify` verifies a line. `--report` prints what is on disk and how loud it
  is, and the ears do the rest. What CAN be checked without ears is SHAPE, and
  it is worth doing: a telegraph whose energy sits at the end, an impact that
  arrives half a second in, a "loop" that decays to nothing. All three shipped
  in the first batch and all three are visible in a coarse RMS envelope.
- A voice is levelled against its SPEECH level; a sound effect has no speech in
  it and is levelled against its whole self. That is why `wav.py` is its own
  audio kit rather than an import from `tools/voice/` - the same reason
  `CC0_LAYOUT` and `CAST_LAYOUT` are two constants.
- **A loop is CHOSEN, not trimmed.** Asked for an unchanging bed the model
  still writes a sound with a beginning and an end, and a decay crossfaded into
  its own head pulses once per pass. So a loop is generated long and
  `wav.steadiest` keeps the stretch whose windows vary least. Trimming asks
  where a sound starts, which is the wrong question about something meant not
  to.

`--relevel` is the one to know: it re-trims, re-caps, re-seals and re-levels
every played file from the untouched exports in `game/enemies/<id>/src/sfx/`,
spends nothing and changes no performance. It is how a sound cut under an
older leveller is carried onto a better one without paying for it twice, and
it is why `src/` is kept at all.

## NPCs

A floor's `npcs` key places the friendly faces the same way `enemies` places
the hostile ones - `{id, at}`, the id a folder under `game/npcs/` - and carries
three things that are placement rather than identity: which way she faces, WHICH
CONVERSATION she is holding (a .gd of beats), and whether she starts it herself
or waits to be spoken to.

That the conversation is placement is the useful part: the same person can
greet you on floor 1 and warn you on floor 7 without a second scene, and
rewriting what she says never touches a scene at all. The format is documented
in game/dialogue/dialogue_director.gd and the reasoning in
game/dialogue/CLAUDE.md.

An NPC is a solid body, so it obeys the furniture rule twice: off the door line,
and off the line an enemy walks from its post to the middle of the room - an
enemy has no pathfinding and will grind along her forever. Her tour's `walk`
points are positions in the same biome file, so moving a prop and leaving the
route alone is how a line stops landing on the thing it is about.

`relief` is the other way an NPC gets into a room, and the only one that is not
a placement: `{npc, from, at, say}` - who walks in once the floor is CLEAR,
through which spawn marker, to which spot, carrying which lines. It is Ivan, on
the six floors that have earned him, and from floor 2 up he is the only healing
in the game. Because he arrives rather than stands, the furniture rule applies
to `at` alone - the room is empty by the time he reaches it, so that spot only
has to clear the scenery and the door line. Why it is an arrival, what counts as
"clear" on a boss floor, and why he does not greet: game/levels/CLAUDE.md.

`briefing` is the same four keys and the same script, and it is Dominique:
who walks in once the floor is CLEAR to say what is on the floor ABOVE. It
is on the three floors that sit under a boss and on no others, and it names
`from: "returned"` - the north door - where `relief` names the south one,
because two of those three floors have both and one doorway cannot take two
bodies at once. The two keys are separate rather than a list for the reason
the prop shelves are named by role: a room's scene should say which arrival
is which.

`build_npcs.gd` also writes ONE thing that is not an NPC -
`game/npcs/ivan/heart.tscn`, the pickup he throws - and that is the single place
this generator crosses into build_levels.gd's territory. The reason is the rule
the hearts follow: a room's own heart is dressing and takes the room's palette
with it, while his is the same red on every floor he walks onto. One file, not
six identical ones in six level folders.
