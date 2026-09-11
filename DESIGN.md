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

Story is delivered as one-line quips by Dominique at doors. No cutscenes until
the ending.

## Enemies — three reskins, and one new archetype

The three company teams map 1:1 onto the existing enemy types. Mechanics,
numbers and scripts are UNCHANGED — new sheets, names and telegraph flavor
only. Each gets its own folder + sheet seeded from the frozen body via
`game/enemies/roster.gd`, per the existing rule.

| id            | built on         | HP | flavor |
|---------------|------------------|----|--------|
| `office_boy`  | regular (guard)  | 24 | the people who FIX things here: company-teal polo under a dark apron, dark work trousers; wind-up = a wrench thrust along the facing, carried in hand while idle and walking |
| `social_media`| wraith           | 17 | phone glow, ring-light white while draining; faint floating "+1" tick |
| `call_center` | warden           | 36 | headset; charge ring reads as a spreading "on hold" circle |

HP stays on combo breakpoints (4 / 3 / 6 hits) — difficulty never scales HP.

### The fourth archetype — `security`

The one enemy in the bestiary that is NOT a reskin of something, and the
exception is earned rather than allowed: three archetypes threaten with damage,
drain and denial, and a floor is built by mixing kinds of threat. Adding more of
any of those three makes rooms longer, not different.

| id         | built on           | HP | flavor |
|------------|--------------------|----|--------|
| `security` | *new* — the brute  | 48 | the building's night shift: the company uniform gone dark, charcoal over black, twice everyone else's height. Winds up for the better part of a second and slams the floor — a ring around his own feet that costs 20 and THROWS you out of it |

**He takes your POSITION**, which no enemy did before: the push is `shove()`, the
fourth way the world reaches the player, built for the hub's floor scrubbers and
until now used by nothing that fights back. The two now bracket the same
mechanic from either end — a scrubber is 6 damage and all push with no
telegraph, and this is a full blow, the same push, and nearly a second of
warning.

Two numbers carry the design and neither is round:

- **48 HP** is the eighth rung of the combo and *exactly two heavies*. He is the
  one body in the game the charged spin was built for and still cannot one-shot,
  which is what makes the heavy the right answer to him rather than the only
  one. `tests/test_slam.gd` reads both off `player.gd` so retuning either side
  fails there.
- **90 px sight**, which buys him his own placement band around the door lane
  (x ≤ 156 or x ≥ 390) and, more to the point, keeps him slow AND short-sighted.
  At speed 35 against the player's 90 he is always outrunnable: the threat is
  that he is standing in the way, not that he catches you.

He is the first enemy drawn at **64px**, the cell the bosses and the NPCs
already use. That cost one `frame` key in the roster and one seeder
(`tools/enemy_art.gd`); 1.5× was considered and dropped, because
nearest-neighbour 1.5 wrecks the 1px outline that is the whole silhouette.

Still to build: his own sheet drawn past the seed (the slam wants an overhead
raise, not the seed's sword swing), his sounds, and the ORIGINAL he is a reskin
of — `bailiff`, for hellfire and up, by the rule below.

### Who stands on which floor

Two rules decide it, and together they tell the building's story: **the reskins
are the company's staff and hold floors 2–9; the originals appear only from
hellfire up**, where the building stops pretending to be an office and the
people in it stop looking like colleagues. A floor's `enemies` list is its
opening ARRANGEMENT, in chain order (`CHAIN` positions, so the two demo biomes
are counted in):

| # | level | count | composition |
|---|-------|-------|-------------|
| 1 | lobby | 0 | the tutorial, and it stays empty |
| 2 | content_studio | 7 | 4 `social_media` + 3 `office_boy` |
| 3 | call_center | 9 | 2 `call_center` + 7 `office_boy` |
| 4 | ahmed_office | 0 | boss arena - his adds are a beat, see below |
| 5 | the_hub | 8 | 1 `call_center` + 4 `office_boy` + 3 `social_media` |
| 6 | marble_hall | 9 | 8 `office_boy`, two gangs of four + 1 `security` at the heart of the east gang |
| 7 | innovation_lab | 9 | 5 `office_boy` + 3 `social_media` + 1 `call_center` |
| 8 | conflict_resolution | 0 | boss arena - his adds are a beat, see below |
| 9 | asset_recovery | 10 | 10 `office_boy`, four knots |
| 10 | hellfire | 10 | 6 `regular` + 3 `wraith` + 1 `warden` (placed) |
| 11 | executive_floor | 11 | 7 `regular` + 2 `wraith` + 2 `warden` (placed) |
| 12 | khaled_office | 0 | final boss arena - SILVERMAN placed, beat live |

Three of those are decisions rather than transcriptions of the floor list above.
**The innovation lab, which had no mechanic assigned, becomes the first
one-of-each mix** — which earns the executive floor for free: the exam is the
same fight one rank bigger with the masks off. And **the executive floor's
eleven are the originals**, not the reskins its entry names, by the rule above.

The third is the SHAPE of every row, and it is worth more than any count here.
These bodies stand in overlapping GROUPS, not spread across a floor: every
ordinary room now has a spot where four or five of them can see the player at
once, where the old arrangements topped out at one or two. Four enemies one to
a corner is not a crowd, it is four duels with a walk between them - and a room
of duels has no use for the heavy, no use for positioning, and no reason for a
player to ever retreat. The count going up is what makes a floor last; the
grouping is what makes it a fight.

One known wrinkle, ordering rather than composition: floor 3 still out-weighs
the floors just above it (trim one office boy if it bites, never a
`call_center` — the pair IS the lesson). Hellfire no longer out-weighs the exam
it precedes: the executive floor is now the heaviest room in the building,
which is what an exam should be.

**Floor 1 stays crossable without a fight.** Two office boys and a beat were
tried here and reverted: the lobby is where a new player finds out what walking
and healing are, and a tutorial that has to be fought through is not one. It is
the only floor with no `reinforcements` key either, and that follows rather than
being a second choice — a beat is cued by kills, so a room with nobody in it can
never reach one.

### Reinforcements — the second beat

Not waves. A room here is an ARRANGEMENT, not a population: the studio is three
overlapping drain fields, asset recovery is four boys behind a colonnade, the
executive floor is one 64px gap — fights made of WHERE the enemies are, and a
stream of respawns flattens all three into the same fight. So a floor may have
one finite authored beat: a named group walking in through a named door at a
known cue — kills, or a boss's remaining health — once, after which the room
clears and stays clear.

- [x] **F8 asset recovery** — 2 `office_boy` at 3 kills, in by the south door.
      Built: `reinforcements` in the biome, `game/levels/reinforcements.gd`,
      `tests/test_reinforcements.gd`. This floor first because it is the crowd
      floor and the one that teaches the heavy: a floor whose whole job is to
      say "two of them are following you and the sword is the wrong answer" can
      afford to say it twice.
- [x] **F11 executive floor** — 1 `warden` at 4 kills, through the glass gap.
      Built: a `spawns` key in biome data and a `chokepoint` marker south of
      the glass, because an arrival on the far side of the partitioning would
      grind along it rather than come through the gap. This is the beat that
      shows why the mechanism earns its keep — **the gap is on the door line,
      where nothing may be placed, so a beat is the only legal way to put a
      body at the floor's own idea at all.**
- [x] **Boss floors get adds, and they get them as beats.** Reversed from "never
      on a boss floor": the arena rule that mattered was *one fight is enough to
      read at a time*, and a body arriving at a health threshold is a PHASE of
      the one fight, where the same body placed in the arena is furniture
      standing in it from the first frame. So a boss floor's `enemies` list
      stays empty and its adds are cued by `at_boss_health` — which needed a
      second cue in `reinforcements.gd`, because `after_kills` cannot reach any
      number but zero on a floor whose whole population is a boss who never
      dies.
      - **F4 Ahmed** — 1 `office_boy` at 64 HP and again at 32, in by the south
        door. This is DESIGN.md's own "SECURITY!" summon, arrived at without a
        summon hook.
      - **F8 Mostafa** — 1 `office_boy` at 96 HP and again at 48. It lands on
        the floor's own idea: the corner rush already makes the edges dangerous,
        and a body arriving mid-rhythm is a body you have to fit into a rhythm.
      - **F12 Khaled** — held until he exists. His three phases already fold in
        a `call_center` slow pulse and `social_media` drain, so whether real
        bodies would say the same thing twice is a question for the built fight.
- [x] **Every floor but the lobby has a beat.** Reversed from "nowhere else
      without a reason", and the reason it is not a walking back of "not
      waves": what
      that forbids is a floor answering a kill with a respawn forever, and what
      each floor has is one authored group, of known types, at a known cue,
      once. The test is unchanged — a beat must restate the floor's own lesson
      rather than add bodies to it — which is why the studio's is drains and
      not boys, why the call floor's adds no slower to the two already there,
      and why F6 and F10 come in by the NORTH door, from the direction the
      player has stopped watching. The full grid is in
      `game/levels/CLAUDE.md`.
- [x] **`per_head`: what a crowd brings, and what it never brings.** A beat's
      `enemies` is a base group that never scales and `per_head` is added once
      per head beyond the first, so `bodies = len(enemies) + (heads-1) *
      len(per_head)`. The split exists because multiplying one list gave every
      extra player a second `call_center`, and two slowers do not stack a slow,
      they REFRESH it — a permanently slowed player cannot sidestep a telegraph,
      which is the one thing here that reads unfair rather than hard. So
      `call_center` is in no floor's `per_head`, and head count now matters
      MORE, not less: a beat can hand a solo player the arrangement it was
      tuned for and still answer a party of four.
- [x] **The boss pair is `social_media` + `call_center`, and the annoyance is
      the point.** What makes a boss fight hard is reading one telegraph, and
      these two attack the reading rather than the health bar: the drain has NO
      wind-up to interrupt, so it cannot be answered with the timing the boss
      is teaching, and the slow takes the dodge away — Ahmed's fire wave is a
      sidestep and nothing else. Every boss floor runs drain, then the slow at
      the halfway point, then drain again, one slower per threshold. Mostafa's
      final quarter is the one place two can be alive at once, the deliberate
      peak, and the first thing to check in play.
- [ ] **A boss's health does not scale with head count, and should not.** 96 is
      exactly four heavies and 144 exactly six, so a fractional multiplier
      lands him on a last swing that does nothing visible — the same arithmetic
      that keeps 24/17/36 off every difficulty dial. His adds are the honest
      dial instead, which is why boss floors put every body they have in a
      beat. Open question for playtest: two players kill a boss in half the
      wall-clock, and whether the extra adds cover that is not yet known.

**Still missing, and it is the next thing this wants: a beat has no telegraph.**
The staggered single-file walk-in through a known door carries it for now.

## NPCs — two new small systems

- **Dominique** (guide, front desk): a talking signpost. New `npc_base.gd` +
  one-line dialogue box (`ui/dialogue/`): proximity trigger, one line per
  visit, advance with the attack key. No branching, no quest log. Placed on
  floors 1, 4, 7, 10 - the tutorial, and then one before each boss.
  **The box was built with branching after all**, because HR's induction needed
  it and a box that can ask a question can also just not ask one. Dominique's
  signpost lines cost a data file and nothing else now.
- **Ivan** (healer, cafeteria): **built, and the cooldown became a cue.** The
  plan was a heart lobbed every ~10s from a safe corner; what shipped is a heart
  per HEAD thrown once, when the room is clear, by a man who walks in to do it.
  A timer would have had him standing in the fight with healing on offer, which
  is the one thing that stops a heal reading as relief - so he is a beat
  (`relief` in biome data, `game/levels/relief.gd`) rather than furniture, and
  the "max one on the floor" rule became "once per visit". The arc, the
  `pickup_base.gd` heart and "Eat." as his last word all survived intact.
  Present on floors 3, 4, 7, 8, 9, 10. From floor 2 up he is the ONLY healing in
  the game: the floors themselves carry no heart, so the lobby's is the last one
  handed out for free.
  **And he says a different thing on every one of them.** He shipped with one
  set of three lines for all six floors, which was wrong the moment anybody
  played more than one of them: the whole point of a man who walks in after a
  fight is that he saw THAT fight, and a line that fits none of them in
  particular reads as a vending machine with a voice. Six conversations now
  (`game/npcs/ivan/after_<floor>.gd`), one per floor, and it cost no code -
  `conversation` was always placement. He introduces himself on the call floor,
  complains that Ahmed says the soup needs salt, knows that Mostafa eats two
  plates standing up, tells you the office boys fix his ovens and that somebody
  upstairs pointed them at you, notices on the executive floor that those ones
  have never stood in his lunch queue, and on the top floor says there is
  nothing above you now. Every one of them still ends on "Eat." - the refrain
  the hearts land on. Voiced, eighteen clips, same pipeline.

Both are friendly: no `player`-group targeting of them, enemies ignore them.
They are in the `npcs` group and in neither `player` nor `enemies`, which is
all it takes — nothing in this game reaches anything by type.

**Both are twice the player's height, in a robe no wider than the player.**
Settled after a preview round; the picks were Dominique's long blonde hair over
a teal robe and Ivan's cropped black curls over a red one, both with a hemp
waist cord and a floor-length hem. It is the one deliberately uncanny thing
about the only two people in the building who are kind to you: a colleague you
have to look up at. It also does a job the writing cannot — from floor 2 up
Ivan is the only healing in the game, and at double height he is the tallest
thing in any room he is in, which finds him in a crowd without a marker.

Mechanically it costs a 64 px cell (the bosses' size, already supported) and
buys nothing else: same ground line, same collision footprint, same everything.
They walk at **45**, half the player's 90 — though both stand still, so that
number only matters the day one of them is asked to go somewhere.

**Built so far**: `game/npcs/` with all three NPCs' art, scenes, roster and
`npc_base.gd`, plus the whole dialogue system (`game/dialogue/`,
`ui/dialogue/`), HR standing in the lobby with an induction to deliver, and Ivan
arriving on six floors with a heart per head.

**Built since: Dominique, and the signpost became a BEAT.** The plan was one
line per visit on floors 1/4/7/10; what shipped is four beats on each of the
three floors that sit under a boss, arriving the way Ivan does once the room is
clear - because a warning is only information while the fight is still ahead,
and a signpost standing in the room during the fight is furniture. Each briefing
names the boss and ends on that fight's actual tell: sidestep Ahmed's wave,
break Mostafa's third punch, spend everything before Silverman's last phase.
They come down the north door while Ivan comes up the south one. Voiced, twelve
clips, in the same pipeline as the other three mouths. `tests/test_dominique.gd`
holds the rule that put them on exactly those three floors.

## HR's induction — the first conversation in the game

She is in the lobby, off the door line and out of the fight lanes, with a
prompt over her head rather than a cutscene that starts itself. Press E and she
welcomes you, then walks the room — sign-in, the front desk, the water cooler —
towing you along behind her, one stop per thing she has an opinion about, and
returns to her post.

Then the contract. **It cannot be refused**, and that is the joke rather than a
limitation: REFUSE does not end the conversation, it gets "Oh, it's so simple.
Just sign it." and a fresh offer, and the third offer loops to itself forever.
Asking to READ it raises the agreement — an English header, an English
signature line, and five clauses of randomly generated consonants. She is not
hiding the terms. There are no terms. Signing is the only way out of the room,
which is the first thing the building teaches you about itself.

## Floors — 10 levels

Elevator is out of order. South door = down, north door = up. Boss floors lock
the north door until the boss falls (`can_travel()` override). Existing
placement rules apply everywhere: no enemy's sight reaches the door line, the
spawns, or whichever of the hazard and heart stands that floor has; the
straight door-to-door walk stays safe.

**This list is in chain order.** `tools/biomes.gd`'s `CHAIN` is the floor plan
the game actually walks, and the numbers below match it: lobby ->
content_studio -> call_center -> ahmed_office -> the_hub -> innovation_lab ->
conflict_resolution -> asset_recovery -> executive_floor -> khaled_office.
The two demo biomes are dealt into that order rather than parked on the end
of it - `marble_hall` sits between F5 and F6, `hellfire` between F8 and F9 -
and they are deliberately not in this list, because they are placeholders
rather than floors of the building. Reordering is one edit to `CHAIN` plus a
build_levels.gd run naming every level whose neighbours moved, since each
door target is baked into a level scene.

One consequence of this order worth knowing, because it is a choice rather
than an accident: Ahmed, the teaching boss, arrives fourth, and the
four-on-one on asset recovery - which is where the heavy attack is taught -
lands seventh, after both bosses. If that reads wrong in play, the fix is
the CHAIN edit above, not a rewrite of any room.

Each floor announces itself by name for three seconds on arrival, so every
biome entry needs a `title` - the floor name in caps, as listed below (e.g.
"ASSET RECOVERY"). Floor numbers are deliberately not in the card: the card
names the room, and the fiction carries which floor it is.

- [x] **F1 The Lobby** (tutorial): glass-and-steel reception, cool blue-grey
  marble, over-lit. Now `CHAIN[0]` and `game.gd`'s `START_LEVEL`: a run begins
  here. Built: biome palette, tileset, north door to the content studio, the
  heart, and
  the room deliberately empty of enemies - floor 1 is where a new player learns
  to walk, safely, and test_flow asserts it stays empty. **Dressed**: reception
  counter (Dominique's spot, and Y-sorting already puts them behind it), the dead
  plant at the end of it, water cooler and a living plant on the far wall, a
  waiting area of sofa and coffee table, two sign-in workstations with chairs,
  the "WELCOME NEW HIRES" banner hanging crooked off one corner, a carpet
  runner down the middle, and the classical colonnade replaced by four glazed
  steel pillars. Floor 1 has no hazard at all - the sparking floor polisher was
  cut, because the one thing a room where a new player learns to walk must not
  have is a way to lose health by walking into the scenery. All of it is
  per-biome data in `tools/biomes.gd` drawn by `tools/props.gd`, so it survives
  a regeneration and floors 2-9 can reuse the catalogue. Dominique + the 2 office
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
  it - the hub further up says the same colour more quietly. Dressed
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
  **And it now runs on a CLOCK**, which is the first room in the game that is
  not the same room on every frame. A take rolls for 4.5s, the room rests for
  5, and a 1.5s cue sits between them; three things read it and nothing else in
  the building does yet. The reason was not that the floor was too easy - it was
  that every threat on it stood where it was placed, so a routing floor is a
  puzzle solved exactly once and walked from memory afterwards. A clock adds a
  reason to be somewhere at a MOMENT, which a fixed arrangement cannot have.
  - The five standing ring lights **go hot** during a take, opening a visible
    pool of light at each foot through the cue and burning in exactly that
    footprint once it rolls. Nothing new was drawn: this floor's hazard was
    already a ring light knocked over at full output, and the room said "these
    things burn" five times while meaning it once.
  - A **camera dolly** runs a painted rail across the set - the first thing in
    the game that hurts you and moves. It tracks the WEST HALF only, which
    keeps the door lane (x 246-300) walkable the way every floor keeps it, and
    charges exactly the ground the floor already makes expensive: the two
    overlapping drain fields with the fallen light between them. It is slower
    than a walk on purpose, so being hit is always a consequence of standing
    still. Between takes it slides back to its mark, harmlessly, which is the
    earliest warning the room gives.
  - The LIVE / LAUGH / ENGAGE neon is the **tally light**: the tubes drop to a
    third between takes and come back over the cue, so the brightest object on
    a near-black wall says what the floor is about to do.
  Two new props (`rail` on the markings shelf, `dolly` on fixtures) and a small
  extension to the prop catalogue - a painter can now declare a `SCRIPT` and a
  `BURNS` box, which is how furniture grows behaviour without every other floor
  learning about it. `tests/test_studio.gd` owns the rhythm.
- [x] **F3 The Call Center** (denial): cubicle maze, densest columns.
  2 call_center planted at chokepoints, 3 office boys between them. The
  lesson: a slow near guards is lethal. Ivan. Hazard: jammed photocopier.
  **Built**: the room, and it is the densest one in the game - eighteen
  dividers in three rows, half again asset recovery's full colonnade, which is
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
  **And the floor is now WIRED.** Four runs of cable trunking down the aisles at
  y 128 and y 224, each one dull until it flares end to end for half a second
  and then puts something very fast and very bright down its length. On a 2.4s
  cycle with the four staggered, so a spark goes off roughly every six tenths of
  a second and two are usually in flight at once - the room never stops moving.
  It is deliberately the opposite of the studio's dolly one floor down. That rig
  is slow and heavy and what it asks for is patience, which is exactly the wrong
  question on the floor whose whole lesson is that your movement gets taken
  away: a threat you beat by standing still is a threat a slow makes easier. So
  this one is small, fast, and comes in fours.
  - It **draws its own conduit** - the trunking and the spark come off the same
    two authored points, so the lane the player reads and the lane that hurts
    cannot come apart. It is the only thing in the game that hurts you and has
    no art file at all.
  - The **whole run charges**, not one end of it, so the warning does not also
    have to teach a direction.
  - **One pass is one hit**: the head crosses a standing player in about a tenth
    of a second against a grace window six times that, so a surge is a tax on
    crossing at the wrong moment and never a lane you are trapped inside. That
    is the whole argument for four of them, and why the damage (8) sits under
    the copier's 10 - the copier is a place you chose to stand in.
  - Every run stops clear of the door lane (x 246-300), which is not a
    compromise: cutting each aisle in two at the lane is what made four runs out
    of two, and it is also what keeps the arrival at (272, 240) safe while the
    first line is already charging.
  `tests/test_surge.gd` owns it.
- [ ] **F4 Ahmed's Corner Office** (BOSS): oversized office, golf putter,
  framed family photo. Small arena, no adds at rest. Ivan + Dominique.
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
  **Built since**: Ahmed, standing north of centre with the north door shut
  behind him until he concedes (see Bosses).
  **Still to add**: the dressing named above - the oversized desk,
  the putter and the framed photo are props nobody has drawn yet.
- [x] **F5 The Hub** (breather): one room, two teams, neither of whom
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
  IN POST. Grey-violet against the brown of asset recovery, magenta accent:
  the media team's colour, which the call floor inherited when the two were
  moved in together. Built: biome, six new props (`call_desk`, `edit_desk`,
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
  somewhere you can be SEEN standing - the same lesson the dividers on asset
  recovery taught the hard way.
  **Still to add**: its people. `call_center` and `social_media` are both
  build step 2, so the room is deliberately empty of enemies and test_flow
  asserts that it stays that way until they exist. When they land they should
  stay light: this floor lands just past Ahmed and before the innovation
  lab, and its job is to be a breather rather than a test of anything.
  **And it WANDERS.** Two floor scrubbers left running, one penned into each
  half, trundling about at 60 px/s and turning whenever they hit something.
  It is the third moving hazard in the building and deliberately the third
  SHAPE: the studio's dolly runs a rail and the call floor's surges run four
  fixed lines, so both are learned as geometry - find the danger, then time it -
  and a third fixed path would have been that lesson a third time. **Nothing
  about where these go is authored.** What decides the route is the furniture,
  which is exactly why they belong here and nowhere else: this is the room with
  two completely different interiors, so the west machine ricochets down cubicle
  rows while the east one crosses open carpet and now and then finds a 32 px
  office door. Same machine, two behaviours, neither written down.
  - It takes your **position**, not your health - a low 6 and a real `shove()`,
    which is a fourth way for the world to reach the player and lands on exactly
    the terms game/player/CLAUDE.md had already reserved for one: shaped like a
    status, carried, decaying, refreshing rather than stacking. On a floor whose
    drains sit inside the glass offices, being moved a tile is worth more than
    the six points.
  - It is the first hazard in the game that is **not fire or sparks**, and its
    scanner is cold for that reason. The player gets a rule rather than a list:
    warm burns, cold moves you.
  - It is a solid **body** rather than a trigger, because being in the way is the
    other half of being an obstacle - the only hazard here that is not an Area2D.
  - Random, but **penned**: `within` is what keeps the door lane walkable when a
    hazard has no route to inspect, and what stops the two halves bleeding into
    one.
  `tests/test_scrubber.gd` owns it, and one new fixture painter (`scrubber`).
- [x] **F6 The Innovation Lab** (light relief): where the software gets
  written, and the brightest room in the building after the lobby. Warm
  off-white and pale wood, the floor the company spent the refurbishment
  budget on - the exact opposite of the content studio four floors down, and
  that contrast is doing work rather than just being pretty: nothing else in
  the building is this bright, so the screens on these desks are the DARKEST
  things in the room instead of the lightest, which is how a floor full of
  monitors reads as a floor full of monitors. Editor blue for an accent, the
  one colour no other floor has.
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
  it. Every other floor has a cast - the lobby blue, asset recovery brown, the
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
  **Still to add**: Mostafa stands in the middle of the ring at
  (272, 138), and naming him in the biome is also what swapped the north
  door for boss_door.gd. His adds are a beat rather than placements - one
  office boy at 96 HP and again at 48 - which is also what keeps the ring
  clear: an arrival carries no `at`, so it cannot be parked inside it.
- [x] **F8 Asset Recovery** (crowd): the office boys' OWN floor - the back of
  house where the company's broken hardware goes and mostly stays, under a
  sign about recovering value from it. Dim warm brown against every other
  floor in the building, amber accent, dividers as columns (the full
  colonnade of twelve, which is what breaks the sight lines that let four
  boys be pulled one at a time). Built: biome, `office_boy` (step 2's first
  reskin), and the room - a server bank along the top wall with one red light,
  e-waste heaped down both side walls, a photocopier with an OUT OF ORDER
  notice taped up beside it, toolboxes and half-stripped towers on the way in,
  three open-plan desks along the bottom, and loose litter over the middle.
  Hazard: the arcing power strip, as planned.
  10 office boys in four KNOTS - three to each western corner, two to each
  eastern one. Teaches the heavy, and the grouping is HOW: one boy per quadrant
  left no point in the room inside two sight radii, so the sword was always the
  right answer and the heavy never repaid its ~1.9 rooted seconds.
  The junk is a thick PERIMETER around a clear arena (about x 200-350,
  y 110-200): a four-on-one fight and an AoE both need floor, so the only thing
  that goes in the middle is `debris`, which blocks nothing. Two placement
  rules bite here and are commented in `tools/biomes.gd` - nothing solid on the
  straight line an office boy walks to the middle (they slide off obstacles and
  have no pathfinding), and no enemy parked on a divider's x, or the divider's
  48px art hides it completely.
  Ivan arrives at the west wall (80, 180) once the room is clear - the
  heaviest `per_head` in the game is the one that most deserves the heal to
  scale too.
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
  **Built since**: its six, and they are the ORIGINALS - two `wraith` behind
  the glass, one per north half, so every awards cabinet sits inside a drain
  field and "every prize requires stepping into a radius" is drawn rather than
  described; a `warden` and three `regular` in the gallery you arrive into.
  Both drains are IN the north half because an enemy on the far side of the
  partitioning grinds along it instead of coming round through the gap. Plus
  the floor's late beat - one more `warden` at 4 kills, arriving at the
  chokepoint, which is the only legal way to put a body there.
  Ivan arrives at (324, 196) once the room is clear.
- [x] **F10 Khaled's Office** (FINAL): penthouse, city window, one desk, one
  face-down sticky note. Wide open arena. South door seals behind you.
  Dominique waits outside ("Whatever happens up there… CC me."). Ivan.
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
  Ivan arrives at (400, 176) once the room is clear - though on this floor
  "clear" waits on a boss who does not exist yet.
  **Still to add**: Khaled, and the south door sealing behind you, which is a
  `can_travel()` override on this level's own script.

## Bosses — overrides on enemy_base.gd's cycle, built in this order

HP values are exact combo breakpoints (5/7 alternating) AND multiples of the
heavy's 24. Difficulty scales their damage only, never HP. All three concede
instead of dying (no queue_free): defeat -> concede animation -> north door
unlocks.

- [x] **AHMED — 96 HP, F4.** The relative; teaching boss, and the one who
  brought an axe to a performance review. 2.5x the player and thin as a coat
  rack: black curls going grey, black beard, white shirt with the sleeves
  shoved up, black trousers. The axe burns. Four attacks on the guard's cycle,
  chosen by range and by how the player is behaving (game/bosses/ahmed/):
  CHOP 16 and SWEEP 12 alternate in reach; every third swing - or sooner, if
  he is hit twice inside 2 s - is the SLAM, 20 to EVERYONE in a 40 px ring,
  office boys included; a player who kites gets the FIRE WAVE, 14 down a
  64 px lane, dodged by a sidestep. Standard interrupt economy. Every attack
  has fire on it, drawn live over a clean sheet.
  **Built**: the boss, his fire, the locked north door, tests/test_bosses.gd.
  **Built since**: the "SECURITY!" summon, and it needed no summon hook on him
  at all - it is a `reinforcements` beat cued by `at_boss_health`, one office
  boy at 64 and again at 32, in by the south door. One at a time rather than a
  cap of two alive: a duel with a crowd in it is neither, and the slam still
  knows what to do with whoever is standing in the ring.
  **Built since**: his mouth. He shouts through the fight - a hello, a taunt
  when you keep out of his reach ("Get over here!", "Come here, coward!"), a
  line on the wind-up of a swing, one for being hit and a different one for
  being interrupted, and "I'm telling Mostafa." as he kneels. Subtitles AND voice:
  all twenty-three lines are cut with ElevenLabs v3, the read tagged per cue
  rather than tuned on a slider, and the subtitle holds for as long as the
  recording runs. `ahmed/taunts.gd` is the
  whole of what he says; `game/enemies/enemy_lines.gd` decides when, and no
  other boss has lines yet.
  **Still to add**: the enormous chair.
- [x] **MOSTAFA — 144 HP, F7.** Boxing rhythm fight; his attack is the cycle
  run 3x back-to-back:
  - Jab, jab: 0.25s wind-ups, 6 dmg each, commit_fraction ~1.0
    (effectively uninterruptible; they're swings — step out, they whiff).
  - Hook: 0.7s wind-up, 18 dmg, interruptible early. The one read.
  - Corner rush: dash gap-closer if the player kites to the ring edge.
  - Defeated: takes the gloves off, nods once, points at the ceiling.
  **Built**: all of the above except the concede, plus two things that are
  his alone and are documented in game/bosses/CLAUDE.md. He is the one boss
  drawn FRONT ON — a boxer squares up to you — which costs nothing against
  boss_base's side-only facing because the figure is symmetric enough that
  `flip_h` is invisible on it. And he is drawn at 2x DENSITY: 70 source rows
  across the same 35 world px Ahmed spends 35 on, cell 128, halved back by
  `scale 0.5` in the scene. The style pass that shaped him needed the range.
  Commit is per attack (`COMMIT` in mostafa.gd), which is what makes the jabs
  uninterruptible and the hook not — the base has one dial, so he sets it as
  each attack begins.
  He also **goes up at 72** — half health, once, and never back down. A 0.95 s
  eruption (two sinks, a blast out of the crouch, a column he stands up
  through) and then he burns for the rest of the fight: skirt, orbiting flame,
  both gloves alight, a rim on his silhouette. Crimson and white, deliberately
  not Ahmed's amber. It lands on the floor's existing `at_boss_health: 72`
  beat, so the fire and the south door open together. **No number changed** —
  the rage burns without biting; `breath_seconds` is the lever if it should do
  both. `rage.gd` + `bell.gd` over the shared `brush.gd`.
  **Still to add**: the concede. The animation described above was drawn and
  rejected in review, so the row is a single placeholder frame — he stops and
  his hands come down. boss_base plays `concede_side` at zero health and the
  row has to exist; replacing it is adding frames to poses.gd and nothing
  else.
- [ ] **KHALED — 192 HP, F10.** Smooth = never hurries; each phase announced by
  adjusting his cuffs:
  - P1 "The Handshake" (192→128): single strikes, 0.8s telegraph, 20 dmg,
    gliding movement. Standard interrupts. The fair phase.
  - P2 "The Meeting" (128→64): adds a call_center slow pulse on a cycle
    ("Sit. Stay a while."). Interrupt cooldown stretches — you get one.
  - P3 "The Performance Review" (64→0): adds social_media drain while near,
    becomes fully uninterruptible. Ivan's hearts + the heavy are the answer.
  - Defeated: never falls. Straightens his cuffs and concedes.
  **Built, on SILVERMAN, and unplaced.** The three phases above are implemented
  verbatim on `game/bosses/silverman/` - 192 HP, a cumulative ladder at 128 and
  64, a slow pulse in phase two and a drain in phase three, uninterruptible in
  phase three - with the mechanics chosen from a preview rather than from this
  list: the glare (the penthouse window turned on you), the split (he divides;
  the copy walks at you), the cold room (proximity drains, outside the grace
  window) and the crossing (his dash, which now passes through you). His
  announcement is not cuffs - he has none - but a rung of his own shine spent on
  the room. `tests/test_silverman.gd` fights him.
  **Placed on F12, the penthouse**, at (272, 140) - centred, because his glare
  and his crossing both run along x and centred is the only spot that gives him
  the room's full width both ways. His floor's beat (144 / 96 / 48) was authored
  against an assumed 192 and is now confirmed against the scene, and those
  thresholds sit off his phase boundaries on purpose so an arrival and a phase
  change never land together. It is the one boss floor with no door to lock: the
  penthouse ends the chain, so there is no north wall to cut and beating him
  opens nothing.
  **Settled: Silverman IS Khaled, and the bar still says SILVERMAN.** There is
  no boss above him and no rename coming. The floor announces itself as
  KHALED'S OFFICE, his bar says SILVERMAN, and the two never meet on screen -
  `title()` reads the scene's filename and the floor card reads the biome, so
  neither had to learn about the other. Nothing in the game says he is Khaled;
  it is the rule the other two already follow, that a name passed up the stairs
  is the whole threat and the blood is never spelled out. Mostafa escalates
  "to Khaled", the player walks into KHALED'S OFFICE, and the man waiting there
  does not introduce himself.
  **He talks, and he says everything twice** - Swedish, then the same thing in
  English. Twenty lines across nine cues in `silverman/taunts.gd`, voiced by a
  Swedish voice reading both halves in one take. He is the gracious one: he
  compliments you for arriving, thanks you for hitting him, and there is not
  one insult in the file. Two cues are his own, `meeting` and `review`, said as
  he crosses into phases two and three - the phase names above, spoken. His
  concede is "Du har jobbet. Det har du haft hela tiden. / You have the job.
  You always did.", which is the handoff into the ending below: the job was
  never the thing being fought over. See game/bosses/CLAUDE.md's
  *He says everything twice*.

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
Khaled". Dominique: "Password changes Monday. The discount doesn't." Credits.

## Multiplayer — a known future, not a current one

The game may grow a second player. Writing it down so it is a recorded decision
rather than something rediscovered later, along with what was and was NOT built
for it.

**Already safe, by accident of a good rule.** Everything the world does to the
player goes through the `player` group plus `has_method` — `take_damage()`,
`drain()`, `apply_slow()`. None of it knows a type or a singleton, so a torch, a
drain field and a guard's strike would already hit two players correctly with no
line changed. That was the expensive seam and it is already open.

**Genuinely single-player, and both are honest to fix later.** `game.gd` owns
`$Player` as one child — camera follow, HUD, lives, death and respawn all hang
off that node — and `enemy_base.gd` targets `get_first_node_in_group("player")`.
Neither gets cheaper by preparing now, and both need decisions that cannot be
guessed well yet: does the camera frame both or split, are lives shared or per
player, what happens at a door with one player standing in it, does an enemy
take the nearest or hold aggro.

**The one thing built for it now is `reinforcements.gd`'s `_head_count()`**, and
it is there because reinforcements are the ONLY enemies in the game with no
authored position. An `at` in a biome is a spot picked against sight radii and
clear lanes; you cannot multiply a spot. So two players do not get a second copy
of a room's arrangement — they get more of its second beat, which is the only
part of a fight that can scale without being re-authored. It returns 1 today,
costs one line, and obeys the rule `Difficulty` already obeys: **more bodies,
never tougher ones**, because 24/17/36 are exact combo breakpoints.

## Build order — each step ships playable

- [ ] 1. Floors as biomes: 10 entries in `tools/biomes.gd` (office palettes),
        run build_biomes + build_levels. Per-floor enemy placement AND
        furniture are per-biome data, so a floor is data plus whatever new
        props it needs in `tools/props.gd` - a regenerate rebuilds the dressed
        room rather than resetting it. **ALL TEN ROOMS EXIST**, in chain
        order: F1 the lobby, F2 the content studio, F3 the call center, F5 the
        hub, F6 the innovation lab, F7 the gym, F8 asset recovery, F9 the
        executive floor and F10 Khaled's office are dressed, and F4 Ahmed's
        office is a room waiting for its boss. Every one of them is empty of
        enemies except F8, which has its four office boys - the cast goes in
        by hand, floor by floor.
        The two demo biomes are not on the end of the chain any more - they
        are dealt INTO the building, `marble_hall` between F5 and F6 and
        `hellfire` between F8 and F9, so a run walks all ten floors in
        DESIGN.md's own order and ends where the story ends, in Khaled's
        office. Both are still demo rooms and both still hold the only fights
        above asset recovery, which is what keeps the flow suite's enemy checks
        somewhere real while the reskins are unbuilt.
        Moving hellfire mid-chain cost it a placement: it gained a north door,
        and its enemies had been lined along the north wall on the assumption
        that nobody ever walked past them. They now clear the door lane at
        x 246-300 by each type's own sight radius, like every office floor's
        do.
        Regenerate one floor at a time: `build_levels.gd -- <level>`, and note
        that inserting a floor changes its NEIGHBOURS' door targets, so
        rebuild those too.
- [x] 2. Reskin enemies: office_boy / social_media / call_center roster
        entries seeded from the frozen body; run build_enemies.
        All three exist, each a roster entry, a seeded sheet and a scene with
        no script of its own: `office_boy` on enemy_base.gd, `social_media` on
        wraith_base.gd (violet-haired, wearing the studio's own neon),
        `call_center` on warden_base.gd (grey shirt, because a pale neutral
        takes the violet charge tint hardest). Reskinning the wraith and the
        warden bubbled their scripts and effects up to `game/enemies/`, per the
        placement rule; the six sheets are 9 rows for the three that swing and
        6 for the three that never do.
        **Still to place**: nobody stands in a room yet - the floors' `enemies`
        lists are the next step, and "Who stands on which floor" above is the
        agreed roster to place from, floor by floor.
- [ ] 2b. Reinforcements: a floor's second beat, `reinforcements` in its biome.
        Built and covered by `tests/test_reinforcements.gd`: the machinery in
        `game/levels/reinforcements.gd`, asset recovery's pair, the executive
        floor's late warden (with the `spawns` key its chokepoint needed) and
        both boss floors' health-cued adds. **Every beat's telegraph is still to
        come, and it is the only thing this is missing** - the staggered
        single-file walk-in through a known door carries it for now. See
        "Reinforcements - the second beat" above for why this is not waves, and
        why almost no floor gets one.
- [x] 3. Dialogue. **Built**, and built past what this step asked for: the
        subtitle box (`ui/dialogue/`), the proximity trigger and prompt on
        npc_base, and a conversation runner that also branches, walks the NPC
        and tows the player along behind her (`game/dialogue/`). Conversations
        are data - a .gd of beats, named per NPC in biome data - and every beat
        already carries a `voice` path for the day there is audio. Covered by
        `tests/test_dialogue.gd`. **Dominique and Ivan still have no lines and
        are still not on a floor**; HR is, and hers is the first induction.
- [x] 4. Ivan. **Built**, and the cooldown turned into a cue: he is a floor's
        THIRD beat (`relief`, game/levels/relief.gd), walking in through the
        door the player came by once the room is clear, crossing to an authored
        spot, and throwing one heart per head at the end of his three lines -
        once per visit. The head count is game/heads.gd, shared with a second
        beat's `per_head`. His heart is his own scene (tools/build_npcs.gd), so
        no floor but the lobby carries one. Covered by `tests/test_ivan.gd`.
        **Built since**: a conversation per floor rather than one for all six,
        voiced - see his entry under NPCs for why one set of lines could not
        survive being heard six times.
- [x] 5. Boss plumbing: locked north door (done: game/levels/boss_door.gd),
        defeat -> concede -> unlock (done: boss_base.gd), boss HP bar on HUD
        (done: ui/hud/boss_bar.gd, found by group so every boss gets one).
- [ ] 6. Bosses in order Ahmed -> Mostafa -> Khaled (each adds one idea:
        summons; multi-hit rhythm; phases). Ahmed is built, less his summon.
- [ ] 7. Ending: sticky-note screen, discount code constant, credits.
- [x] 8. Tests: new `tests/test_bosses.gd` suite (one suite = one world);
        test_flow checks the locked door and concedes Ahmed to walk on.
