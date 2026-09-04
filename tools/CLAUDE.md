# Tools - furnishing rooms from data

Deep dive for `tools/`. WHAT each generator writes and the regenerate-don't-
hand-edit rules live in the root CLAUDE.md's "Generated resources" table; the
anatomy of the rooms these scripts produce is `game/levels/CLAUDE.md`. This
file is how furniture works and how floors are added.

## A room is furnished from data, not by hand

`tools/props/` holds one file per prop type, shelved by what a prop IS -
`furniture/` (reception counter, desk, chair, water cooler, sofa, coffee
table, pot plant alive and dead), `hardware/` (server rack, printer, stacked
dead monitors, opened tower, toolbox, cable spool, scrap pile, loose debris)
and `signs/` (the welcome banner, a taped-up notice) - and a biome says which
ones it puts where in its own `props` list, exactly the way it already says
which enemies it gets. That list drives everything: build_levels.gd writes a
scene per type into the level's `props/`, paints its picture in the biome's
palette and bakes it in, then instances them. `build_levels.gd -- lobby`
therefore reproduces the dressed room rather than resetting it to a bare box -
which is what makes the generator's "re-running overwrites hand-dressing"
warning survivable for eight floors.

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
levels place column, hazard and heart themselves, so those can be painted but
never listed as furniture.

The division of labour between the two generators is by **subject**, not by
file type: build_biomes.gd paints the ROOM (its tileset and doorways, the only
art a level scene points at as files) and tools/props/ paints everything
standing in the room. One consequence to know: re-palettizing a prop needs
build_levels.gd, not just build_biomes.gd, because that is where its picture
gets baked in.

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
ways: the bullpen has to look full of junk AND leave floor for a four-on-one
fight and an AoE. Solid props cannot do both, so the junk is a thick perimeter
and the middle gets litter. It is also the one prop drawn without an outline,
since an outline is what gives a prop volume and this is meant to read as marks
on the floor; and nothing in it is red or gold, because the heart pickup is red
and the hazard's sparks are gold, and litter that borrows either colour is
litter the player crosses the room to try to pick up.

Solid props matter to the enemies too, not just the player: enemies walk
straight at the player and slide off whatever they hit, with no pathfinding to
recover from a pocket. So a furnished room must not be a maze, and nothing solid
should sit on the line an enemy walks from its post to the middle of the room.

_brush.gd also carries a 5x5 uppercase pixel font, because half of what makes a
company office funny is what is written on the walls. A sign's words are a
`TEXT` constant in its own file, not baked into a painter, so a floor can put up
its own words without new drawing code - the banner says WELCOME / NEW HIRES,
the notice says OUT OF ORDER, the counter says RECEPTION, and DESIGN.md has wall
text waiting on four more floors.

## Adding and inserting a biome

Adding a biome: one new data file in `tools/biomes/` plus its name in
`tools/biomes.gd`'s `CHAIN`, then run build_biomes.gd and build_levels.gd.
Appending to `CHAIN` gives the previous last level a north door automatically.

**Inserting** one in the middle - which is how the office floors are being built
in front of the two demo biomes - changes its NEIGHBOURS as well, and this is
the step to get wrong: a door's `target_level` is baked into the level scene by
the generator, so the level before the new one still points past it and the
level after it still points back past it until both are rebuilt. Pass all three
names: `build_levels.gd -- lobby bullpen marble_hall`. build_biomes.gd always
does every biome, so the doorway textures (each lit by the colour of the place
on the other side) come out right on their own.
