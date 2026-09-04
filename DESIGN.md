# THE NEW HIRE — design plan

Source of truth for the company-game content build. Mechanics live in CLAUDE.md;
this file says WHAT to build with them. The shareable pretty version of this
plan is a Claude artifact (ask Mayar for the link); when the two disagree,
this file wins.

Status legend: [ ] not started · [x] done. Update statuses as steps land.

## Premise

First day at the company. Your laptop connects to nothing: the WiFi password
changes weekly and only Khaled (top floor, calendar booked until 2031) knows
it. You climb the building floor by floor. Tone is affectionate workplace
comedy — these are real colleagues; jokes stay warm, never mean.

Story is delivered as one-line quips by Dominic at doors. No cutscenes until
the ending.

## Enemies — reskins of the three existing archetypes

The three company teams map 1:1 onto the existing enemy types. Mechanics,
numbers and scripts are UNCHANGED — new sheets, names and telegraph flavor
only. Each gets its own folder + sheet seeded from the frozen body via
`game/enemies/roster.gd`, per the existing rule.

| id            | built on         | HP | flavor |
|---------------|------------------|----|--------|
| `office_boy`  | regular (guard)  | 24 | the people who FIX things here: company-teal polo, dark work trousers; wind-up = raising a tool |
| `social_media`| wraith           | 17 | phone glow, ring-light white while draining; faint floating "+1" tick |
| `call_center` | warden           | 36 | headset; charge ring reads as a spreading "on hold" circle |

HP stays on combo breakpoints (4 / 3 / 6 hits) — difficulty never scales HP.

## NPCs — two new small systems

- **Dominic** (guide, front desk): a talking signpost. New `npc_base.gd` +
  one-line dialogue box (`ui/dialogue/`): proximity trigger, one line per
  visit, advance with the attack key. No branching, no quest log. Placed on
  floors 1, 4, 7, 10 - the tutorial, and then one before each boss.
- **Ivan** (healer, cafeteria): stands in a safe corner, lobs a heart in a
  short tween arc every ~10s. Spawns the existing `pickup_base.gd` heart;
  max ONE of his hearts on the floor at a time (lifeline, not fountain). Heart
  is live when it lands. Only line: "Eat." Present on floors 3, 4, 7, 8, 9, 10.
  From floor 2 up he is the ONLY healing in the game: the floors themselves no
  longer carry a heart, so the lobby's is the last one handed out for free.
  Until he is built, floors 2-9 have no heal at all - which is deliberate, and
  is the pressure his build step is meant to relieve.

Both are friendly: no `player`-group targeting of them, enemies ignore them.

## Floors — 10 levels

Elevator is out of order. South door = down, north door = up. Boss floors lock
the north door until the boss falls (`can_travel()` override). Existing
placement rules apply everywhere: no enemy's sight reaches the door line, the
spawns, or whichever of the hazard and heart stands that floor has; the
straight door-to-door walk stays safe.

**This list is in chain order.** `tools/biomes.gd`'s `CHAIN` is the floor plan
the game actually walks, and the numbers below match it: lobby ->
content_studio -> call_center -> ahmed_office -> shared_floor -> dev_floor ->
conflict_resolution -> bullpen, with the two demo biomes (marble_hall,
hellfire) still parked on the end until F9 and F10 replace them. They are
deliberately not in this list - they are placeholders, not floors of the
building. Reordering is one edit to `CHAIN` plus a full build_levels.gd run,
since every door target is baked into a level scene.

One consequence of this order worth knowing, because it is a choice rather
than an accident: Ahmed, the teaching boss, arrives fourth, and the bullpen's
four-on-one - which is where the heavy attack is taught - lands seventh,
after both bosses. If that reads wrong in play, the fix is the CHAIN edit
above, not a rewrite of any room.

Each floor announces itself by name for three seconds on arrival, so every
biome entry needs a `title` - the floor name in caps, as listed below (e.g.
"THE BULLPEN"). Floor numbers are deliberately not in the card: the card names
the room, and the fiction carries which floor it is.

- [x] **F1 The Lobby** (tutorial): glass-and-steel reception, cool blue-grey
  marble, over-lit. Now `CHAIN[0]` and `game.gd`'s `START_LEVEL`: a run begins
  here. Built: biome palette, tileset, north door to the content studio, the
  heart, and
  the room deliberately empty of enemies - floor 1 is where a new player learns
  to walk, safely, and test_flow asserts it stays empty. **Dressed**: reception
  counter (Dominic's spot, and Y-sorting already puts him behind it), the dead
  plant at the end of it, water cooler and a living plant on the far wall, a
  waiting area of sofa and coffee table, two sign-in workstations with chairs,
  the "WELCOME NEW HIRES" banner hanging crooked off one corner, a carpet
  runner down the middle, and the classical colonnade replaced by four glazed
  steel pillars. Floor 1 has no hazard at all - the sparking floor polisher was
  cut, because the one thing a room where a new player learns to walk must not
  have is a way to lose health by walking into the scenery. All of it is
  per-biome data in `tools/biomes.gd` drawn by `tools/props.gd`, so it survives
  a regeneration and floors 2-9 can reuse the catalogue. Dominic + the 2 office
  boys land with steps 2-3.
  Two lanes are kept deliberately clear of furniture and must stay that way:
  the door line (x 246-300) and the central band (y 122-200, x 86-352).
  tests/test_combat.gd fights in this room, because floor 1 is the empty one.
- [x] **F2 The Content Studio** (drain): dark room + neon, ring lights,
  "LIVE LAUGH ENGAGE" wall. 3 social_media with overlapping sight radii
  (routing level — standing central costs 6-9 HP/s), 1 office boy by the exit
  forcing one fight inside the field. Hazard: scalding ring light on a fallen
  tripod.
  **Built**: the room, and it is the first genuinely DARK floor in the game -
  the ramp never reaches white, so the brightest things in it are the lights
  standing on the floor and the sign on the wall. Neon violet accent: the media
  team's magenta pushed to the end of the tube, and the first floor to carry
  it - the shared floor further up says the same colour more quietly. Dressed
  as a working studio: a paper sweep with the interview couch and the plant
  that is in every shot in front of it, a light either side, a camera looking
  at the lot of it, the stream station in the far corner, a green room of couch
  and table in the dark one, and cable and litter everywhere. The wall sign is
  real neon - tubing and bloom, no board - reading LIVE / LAUGH / ENGAGE. Four
  glazed pillars rather than a colonnade, for the reason below. Three new props
  (`ring_light`, `backdrop`, `neon`) and a fourth hazard style, `fallen_light`:
  DESIGN's ring light knocked over and still at full output, which is the same
  object as the `ring_light` standing next to it - once as the furniture that
  makes this a studio and once as the thing on the floor that hurts.
  The middle of this room is the emptiest floor in the game, and deliberately:
  three drain fields that OVERLAP need floor to overlap on, and a column is a
  sight-line breaker, which is the one thing that would undo the lesson. All the
  kit is in the four quadrants and against the walls.
  The floor band starts high on a low ramp (0.32-0.68) rather than going as dark
  as the room wants - checked with three of the cast standing on it, because a
  dark-haired cast on a near-black floor is a floor you cannot see anybody on.
  The room reads dark because the WALLS are near-black, not the floor.
  **Still to add**: its people, being placed by hand - 3 social_media across the
  middle plus 1 office boy by the north door.
- [x] **F3 The Call Center** (denial): cubicle maze, densest columns.
  2 call_center planted at chokepoints, 3 office boys between them. The
  lesson: a slow near guards is lethal. Ivan. Hazard: jammed photocopier.
  **Built**: the room, and it is the densest one in the game - eighteen
  dividers in three rows, half again the bullpen's full colonnade, which is
  what makes it a maze rather than an open plan. Ten identical stations in the
  pockets the dividers leave, in three ranks, with the middle rank thinned to
  two against the side walls: this floor's lesson only lands in a room you were
  trying to cross, so the band at y 128-176 keeps the floor a routing fight
  needs. Fluorescent green-grey - the only green floor in the game, landing
  between the studio's near-black and Ahmed's dark marble, so walking in here
  is walking into the lights being ON - with a cold cyan accent, the colour of
  being asked to hold. The wallboard on the north wall reads CALLS / WAITING /
  142 with the number in red, and it is the prop that made the 5x5 pixel font
  learn digits. An OUT OF ORDER notice next to it, and both a `printer` (a
  machine nobody can use) and the new `copier` hazard (a machine nobody should
  touch), which is DESIGN's jammed photocopier: lid up, paper crumpled out of
  the slot, fuser still going.
  The divider xs are 72 / 152 / 232 / 312 / 392 / 472 and every enemy must stay
  off them - an enemy on a divider's x and above its foot is invisible, and
  this floor has eighteen chances to make that mistake instead of six.
  **Still to add**: its people, being placed by hand - 2 call_center at the
  chokepoints, 3 office boys between them.
- [ ] **F4 Ahmed's Corner Office** (BOSS): oversized office, golf putter,
  framed family photo. Small arena, no adds at rest. Ivan + Dominic.
  **Built**: the room, and it is the marble hall's room - the same stone and
  the same classical colonnade, because this is the floor where the building
  stops pretending to be an office - taken down out of the white. Every stop
  on the ramp is pulled darker, the hall's gold is brassier, gamma goes above
  1.0 so mid-tones sit down instead of lifting, and the floor band stops at
  0.70 rather than the hall's 1.00, which is the number that actually makes a
  room darker. Two things it deliberately has NOT got: a hazard
  (`"hazard": "none"` - the only thing in here meant to hurt is Ahmed, and one
  fight is enough to read at a time) and any enemies, since Ahmed is step 6
  and the design gives this floor no adds at rest.
  **Still to add**: Ahmed, and the dressing named above - the oversized desk,
  the putter and the framed photo are props nobody has drawn yet.
- [x] **F5 The Shared Floor** (breather): one room, two teams, neither of whom
  asked to share it - and the floor where the two teams whose own floors you
  have just walked through are crammed into one room. The WEST half is the call
  floor: two
  rows of identical stations, cubicle dividers between them, a desk phone and
  a queue of calls on every screen, a printer, a cooler and a break corner
  nobody sits in, under a wallboard reading SMILE / THEY CAN / HEAR IT. The
  EAST half is the media team's, walled into two glass-fronted offices you
  walk into through a gap in the glass, each with a lit edit bay in it - a
  timeline on one screen and the shot on the other - plus cable, a render
  tower, a camera still up on its tripod, and a poster reading FIX IT /
  IN POST. Grey-violet against the bullpen's brown, magenta accent: the media
  team's colour, which the call floor inherited when the two were moved in
  together. Built: biome, six new props (`call_desk`, `edit_desk`,
  `partition`, `whiteboard`, `poster`, `camera_rig`) and the room.
  The generator's two clear lanes ARE the floor plan here: the door line
  (x 246-300) runs down between the two halves and the runner band
  (y 128-176) crosses it, so the dressing goes in the four quadrants and the
  cross is a pair of office corridors for free. Both stay clear - the power
  strip stands at (120, 152) on the call side and the heart at (424, 152) on
  the media side, and that band is the lane a fight will use.
  The glass is a PROP, not a column style, and that is the one decision to
  know here: a run of `partition` segments 32 px apart with one left out of
  the list is a wall with a door in it, which the colonnade's rows-by-columns
  layout cannot describe. Its glazing is translucent so that an office is
  somewhere you can be SEEN standing - the same lesson the bullpen's dividers
  taught the hard way.
  **Still to add**: its people. `call_center` and `social_media` are both
  build step 2, so the room is deliberately empty of enemies and test_flow
  asserts that it stays that way until they exist. When they land they should
  stay light: this floor lands just past Ahmed and before the dev floor, and
  its job is to be a breather rather than a test of anything.
- [x] **F6 The Dev Floor** (light relief): where the software gets written, and
  the brightest room in the building after the lobby. Warm off-white and pale
  wood, the floor the company spent the refurbishment budget on - the exact
  opposite of the content studio four floors down, and that contrast is doing
  work rather than just being pretty: nothing else in the building is this
  bright, so the screens on these desks are the DARKEST things in the room
  instead of the lightest, which is how a floor full of monitors reads as a
  floor full of monitors. Editor blue for an accent, the one colour no other
  floor has.
  **Built**: seven workstations - two along the north wall, three across the
  south, one either side of the east - the whiteboard, the build screen, the
  service wall (racks, tower, coffee, water) and a breakout of sofa, table and
  plants. Four new props:
  - `dev_desk`, the fourth desk in the catalogue and the only one with a
    monitor turned on its SIDE. That is the whole silhouette - nobody else in
    the building rotates a screen - and next to it a mechanical keyboard, a
    mug, and a rubber duck to explain the bug to, in fixed yellow for the same
    reason the cooler's water is fixed blue.
  - `diagram`, the whiteboard, whose joke is DRAWN rather than written: four
    boxes, arrows between them, one arrow that goes back where it came from,
    and DO NOT ERASE along the bottom in red pen.
  - `build_board`, the screen telling the whole floor the build is failing,
    with the run history under it - green, green, green, then nine reds nobody
    has fixed.
  - `coffee`, the filter machine, stewed since the morning, and the second
    prop in the catalogue whose colour is not the room's.
  Hazard: the power strip again, and it needs no excuse on this floor - seven
  workstations, each with two monitors and a machine under the desk, all fed
  from whatever was already plugged in.
  One placement note worth keeping: the pillars sit on rows 6 and 12 rather
  than the usual 5 and 13. A pillar's art is 48 px above its foot, so the
  default rows put one across y 48-96, which is exactly where north-wall
  furniture stands; two tiles down, the whole north wall is free for the
  whiteboard and the first pod.
  **Still to add**: its people, and the lesson that comes with them - this
  floor has no mechanic assigned to it yet.
- [x] **F7 Conflict Resolution** (BOSS): company gym, boxing ring painted on
  the floor, poster: "TALK IT OUT" crossed out, "GLOVE IT OUT" under it.
  Tight arena, no columns. Mostafa. Ivan.
  **Built**: the room, and it is the only room in the game with no colour in
  it. Every other floor has a cast - the lobby blue, the bullpen brown, the
  call floor green - and this one is plain concrete and rubber, so the single
  warm thing in it is the paint on the floor: grey room, red ring. The ring
  is DESIGN's, painted rather than built, and it is the first prop in the
  catalogue that is a MARKING rather than a thing - a new `markings/` shelf,
  because paint is neither furniture, hardware nor a sign. It blocks nothing
  (you fight on it) and it pins its top-left corner rather than its foot,
  which is what puts it under everybody standing on it; pinned at its foot it
  would paint over the fighters. A wash of the accent across the inside is
  what makes it read as a surface rather than a rectangle drawn on the ground.
  Also new: `motto`, the poster with the correction on it - the strike-through
  is drawing code, one stroke through the first line of TEXT - plus
  `heavy_bag` and `weight_rack` for the walls.
  This is the first floor with NO colonnade, which the design asks for
  outright, and a biome says so by handing in an empty `columns` layout. It
  gets no column scene in its folder either, the same rule the hazard and the
  heart already follow. Nothing solid stands inside the ring: a rhythm fight
  that steps in and out of range - and the corner rush, which needs corners to
  rush into - has the whole 232x148 of it. The kit is all against the walls.
  No hazard, for the same reason Ahmed's office has none: one fight is enough
  to read at a time, and a boss room that also burns you is a boss room where
  the death was the floor's fault.
  **Still to add**: Mostafa, and Ivan.
- [x] **F8 The Bullpen** (crowd): the office boys' OWN floor - the back of house
  where the company's broken hardware goes and mostly stays. Dim warm brown
  against every other floor in the building, amber accent, dividers as columns
  (the
  full colonnade of twelve, which is what breaks the sight lines that let four
  boys be pulled one at a time). Built: biome, `office_boy` (step 2's first
  reskin), and the room - a server bank along the top wall with one red light,
  e-waste heaped down both side walls, a photocopier with an OUT OF ORDER
  notice taped up beside it, toolboxes and half-stripped towers on the way in,
  three open-plan desks along the bottom, and loose litter over the middle.
  Hazard: the arcing power strip, as planned.
  4 office boys, one per quadrant. Teaches the heavy.
  The junk is a thick PERIMETER around a clear arena (about x 200-350,
  y 110-200): a four-on-one fight and an AoE both need floor, so the only thing
  that goes in the middle is `debris`, which blocks nothing. Two placement
  rules bite here and are commented in `tools/biomes.gd` - nothing solid on the
  straight line an office boy walks to the middle (they slide off obstacles and
  have no pathfinding), and no enemy parked on a divider's x, or the divider's
  48px art hides it completely.
  **Still to add**: Ivan (west wall) - he needs the NPC system, build step 4.
- [x] **F9 The Executive Floor** (mix/exam): dark wood, glass walls, awards
  cabinet. 3 office boys + 2 social_media + 1 call_center (center chokepoint).
  Every prize requires stepping into a radius on purpose. Ivan.
  **Built**: mahogany walls and a brass accent - the darkest warm room in the
  building, and deliberately the lobby's opposite number: floor 1 is over-lit
  and cheap, floor 9 is under-lit and expensive. It is also the only OFFICE
  floor with the fluted classical colonnade, which is the joke rather than an
  oversight - the columns are what made the lobby read as a temple, and this is
  the one floor entitled to the pretence.
  The chokepoint is DRAWN. A run of fourteen glass bays crosses the whole
  floor with a single 64 px gap on the door line, so the boardroom and the
  trophy wall behind it are reached through one opening in the middle of the
  room - which is what makes "every prize requires stepping into a radius"
  mean anything. North of the glass: the boardroom (the table, six chairs, the
  drinks trolley) west of the gap, four awards cabinets and a bench east of it.
  South of it: the gallery you arrive into, a carpet corridor along the glass
  and a rug under two couches. Five new props:
  - `awards_cabinet`, the tallest piece of furniture in the catalogue, with
    three lit shelves of cups and stars behind a glass door. The trophies are
    a fixed gold for the same reason fire and hearts are fixed - take them off
    the biome's ramp and hellfire hands out iron cups.
  - `boardroom_table`, the widest prop in the catalogue at 96 px: a polished
    top with a brass inlay, six places set with pads nobody has written on,
    and one speakerphone.
  - `bar_cart`, the drinks trolley, whose decanter is the catalogue's fourth
    fixed colour after water, coffee and gold.
  - `portrait`, the founder in oils under a brass FOUNDER plaque - the only
    sign in the game that is a picture with a caption rather than a caption.
    Painted in varnish rather than in skin, which is both what a hundred-year
    -old commissioned portrait looks like and a way of making no claim about
    whose face it is.
  - `rug`, the second thing on the markings shelf after the boxing ring, and
    the same two tricks: it blocks nothing and it pins its top-left corner so
    everybody walks on top of it.
  Hazard: the floor polisher, back from the lobby that dropped it, and this is
  the floor it was always for - the only one in the building whose wood is
  actually polished.
  No debris anywhere on this floor, and the absence is deliberate: every floor
  below it has litter because every floor below it is used.
  **Still to add**: its six, and Ivan.
- [x] **F10 Khaled's Office** (FINAL): penthouse, city window, one desk, one
  face-down sticky note. Wide open arena. South door seals behind you.
  Dominic waits outside ("Whatever happens up there… CC me."). Ivan.
  **Built**: the only ramp in the game with no warmth anywhere in it -
  charcoal and glass up to a blue-white - and a platinum accent, which is not
  a colour so much as the absence of one. That is the gym's argument made the
  other way round: the gym is grey so its red paint is the only warm thing in
  it, and this room is grey so the CITY is. Everything with a colour in here
  is on the far side of the glass.
  The second floor to hand in an empty `columns` layout, after the gym, and
  the third to take no hazard, after Ahmed's office and the gym. Nothing solid
  stands anywhere in the middle: the arena is x 150-400 by y 150-280 and the
  only thing in it is the rug, which blocks nothing. Three new props:
  - `city_window`, which opens a shelf. `openings/` exists because a window is
    none of the other four things a prop can be - not furniture, hardware, a
    sign or paint on the floor, but a hole cut through the building's shell -
    and the boxing ring opened `markings/` on exactly that argument. It runs
    480 px unbroken, wall to wall, and it can only do that because the
    penthouse is the END of the chain: a level with a floor above it has a
    doorway cut through its north wall, and a panoramic window drawn across
    that doorway would glaze the way out. It carried a 96 px hole for exactly
    that reason until Khaled's office became the last room. The sky and the
    city are fixed colours; only the frame and the sill take the room's.
  - `exec_desk`, and the point of it is what is NOT on it: every other desk in
    the building is buried, and this one is a mirror-polished slab with a pen
    laid square to the edge. A man who does no work in the room where the work
    is decided.
  - `sticky_note`, face down, shelved with the signs because it IS one - the
    only one in the game turned over. It is a prop of its own rather than a
    detail painted into the desk because the ending turns it over and needs a
    node to find, and `StickyNote1` is that node. Its canvas is 30 px tall
    with the note in the top ten, which is how anything lying ON a desk is
    placed at all: given a foot two pixels south of the desk's it sorts after
    it, and its art, twenty pixels up, lands on the desktop.
  The rug and the drinks trolley are the executive floor's, one storey down,
  which is the catalogue working as intended - in a room with no hue in it the
  rug comes out platinum on slate.
  **Still to add**: Khaled, Ivan, and the south door sealing behind you, which
  is a `can_travel()` override on this level's own script.

## Bosses — overrides on enemy_base.gd's cycle, built in this order

HP values are exact combo breakpoints (5/7 alternating) AND multiples of the
heavy's 24. Difficulty scales their damage only, never HP. All three concede
instead of dying (no queue_free): defeat -> concede animation -> north door
unlocks.

- [ ] **AHMED — 96 HP, F4.** The relative; teaching boss. Guard swing cycle,
  slightly faster recover, 14 damage. At 64 and 32 HP yells "SECURITY!" and
  summons 1 office boy through the door (cap 2 alive). Standard interrupt
  economy. Defeated: sits in his enormous chair — "I'm telling Mostafa."
- [ ] **MOSTAFA — 144 HP, F7.** Boxing rhythm fight; his attack is the cycle
  run 3x back-to-back:
  - Jab, jab: 0.25s wind-ups, 6 dmg each, commit_fraction ~1.0
    (effectively uninterruptible; they're swings — step out, they whiff).
  - Hook: 0.7s wind-up, 18 dmg, interruptible early. The one read.
  - Corner rush: dash gap-closer if the player kites to the ring edge.
  - Defeated: takes the gloves off, nods once, points at the ceiling.
- [ ] **KHALED — 192 HP, F10.** Smooth = never hurries; each phase announced by
  adjusting his cuffs:
  - P1 "The Handshake" (192→128): single strikes, 0.8s telegraph, 20 dmg,
    gliding movement. Standard interrupts. The fair phase.
  - P2 "The Meeting" (128→64): adds a call_center slow pulse on a cycle
    ("Sit. Stay a while."). Interrupt cooldown stretches — you get one.
  - P3 "The Performance Review" (64→0): adds social_media drain while near,
    becomes fully uninterruptible. Ivan's hearts + the heavy are the answer.
  - Defeated: never falls. Straightens his cuffs and concedes.

## Ending — two codes, two jobs

Khaled's concession speech, then:

1. **WiFi password** (closes the story; the sticky note):
   `ZA-C0MPANY-Wi-Fi!2026` — fictional, part of the joke.
2. **Discount code** (the real reward): "The WiFi gets you connected. This —
   this is because you impressed me." A REAL redeemable discount code for the
   company's product, shown only on beating the game. Placeholder
   `KHALED-APPROVED`; keep it as ONE constant in the ending scene so marketing
   can rotate it without touching anything else.

Smash cut: desk, laptop connected, notification "Welcome to the team 🎉 —
Khaled". Dominic: "Password changes Monday. The discount doesn't." Credits.

## Build order — each step ships playable

- [ ] 1. Floors as biomes: 10 entries in `tools/biomes.gd` (office palettes),
        run build_biomes + build_levels. Per-floor enemy placement AND
        furniture are per-biome data, so a floor is data plus whatever new
        props it needs in `tools/props.gd` - a regenerate rebuilds the dressed
        room rather than resetting it. **ALL TEN ROOMS EXIST**, in chain
        order: F1 the lobby, F2 the content studio, F3 the call center, F5 the
        shared floor, F6 the dev floor, F7 the gym, F8 the bullpen, F9 the
        executive floor and F10 Khaled's office are dressed, and F4 Ahmed's
        office is a room waiting for its boss. Every one of them is empty of
        enemies except F8, which has its four office boys - the cast goes in
        by hand, floor by floor.
        The two demo biomes are not on the end of the chain any more - they
        are dealt INTO the building, `marble_hall` between F5 and F6 and
        `hellfire` between F8 and F9, so a run walks all ten floors in
        DESIGN.md's own order and ends where the story ends, in Khaled's
        office. Both are still demo rooms and both still hold the only fights
        above the bullpen, which is what keeps the flow suite's enemy checks
        somewhere real while the reskins are unbuilt.
        Moving hellfire mid-chain cost it a placement: it gained a north door,
        and its enemies had been lined along the north wall on the assumption
        that nobody ever walked past them. They now clear the door lane at
        x 246-300 by each type's own sight radius, like every office floor's
        do.
        Regenerate one floor at a time: `build_levels.gd -- <level>`, and note
        that inserting a floor changes its NEIGHBOURS' door targets, so
        rebuild those too.
- [ ] 2. Reskin enemies: office_boy / social_media / call_center roster
        entries seeded from the frozen body; run build_enemies.
        **office_boy done**: roster entry + `office_boy.tscn` running
        enemy_base.gd with no overrides, so it is the guard's numbers exactly.
        social_media and call_center still to do.
- [ ] 3. Dialogue + Dominic: npc_base.gd, ui/dialogue/, lines as instance data.
- [ ] 4. Ivan: heart-throwing NPC on cooldown.
- [ ] 5. Boss plumbing: locked north door, boss HP bar on HUD,
        defeat -> concede -> unlock sequence.
- [ ] 6. Bosses in order Ahmed -> Mostafa -> Khaled (each adds one idea:
        summons; multi-hit rhythm; phases).
- [ ] 7. Ending: sticky-note screen, discount code constant, credits.
- [ ] 8. Tests: new `tests/test_bosses.gd` suite (one suite = one world);
        extend test_flow with the locked-door case.
