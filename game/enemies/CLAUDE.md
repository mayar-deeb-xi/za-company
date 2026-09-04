# Enemies - the base, the types, the art pipeline

Deep dive for `game/enemies/`. The cross-cutting invariants (HP numbers are
combo breakpoints, difficulty never scales them, reskins keep the base's
numbers, composition is per-biome data) are restated in the root CLAUDE.md;
the player's side of the fight - the combo and the heavy these numbers are
tuned against - is `game/player/CLAUDE.md`.

## The base

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

**A reskin is a roster entry and a scene, and nothing else.** `office_boy` is
the company's maintenance staff and mechanically it IS the regular: its scene
runs enemy_base.gd with no exported overrides, so the base's defaults are its
numbers, exactly as `regular.tscn` does. That is the whole pattern for
DESIGN.md's three reskins - new sheet, new name, new folder, same script and
same numbers - and it is what keeps the interrupt rules meaningful: they were
tuned against 24 HP and a 0.45s wind-up, and a reskin that quietly retuned
either would need them re-tuned too. Two types share the base's defaults now,
so a change to those defaults moves both.

## The types

They deliberately threaten in different ways - damage, drain, and denial - so a
room is built by mixing them rather than by adding more of the same:

- **`regular/`** - 24 HP, 10 damage on a completed strike, speed 55, sight 80,
  0.45s wind-up. Carries no script of its own: its scene runs enemy_base.gd
  directly, the way torches run hazard_base.gd, so the base's defaults ARE the
  regular's numbers. It uses the swing cycle, and it is the one the interrupt
  rules exist for. `max_health` is the number most likely to want
  retuning - four guards in the marble hall is sixteen hits between them, and
  17 is the next stop down if that reads as a slog.
- **`office_boy/`** - the regular, reskinned as the company's maintenance staff
  for floor 2 (see above). Identical numbers, its own sheet, no script.
  Placement in asset recovery has one extra rule that is easy to miss and produced
  an invisible enemy first time: a divider's art is 48 px tall, so an enemy
  parked at a divider's x with a smaller y than the divider's foot is drawn
  BEHIND it and cannot be seen until it walks out.
- **`wraith/`** - 17 HP, no attack at all, speed 45, sight 120, and standing
  near it costs three health per second (1 was flavour, not threat: 100 seconds
  to matter; at 3, two of them cost about half a guard's output from the one
  source that cannot be staggered). It is the reason `drain()` exists (see
  game/player/CLAUDE.md's Health). Its `_contact_state()` is `idle`: having
  arrived it has no attack to
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

## Sheets: every enemy owns its own

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

## Placement

A dead enemy is `queue_free`d, and since levels are re-instantiated per entry,
it is back on the next visit - the same no-room-state rule as pickups.

Enemies are the one prop a level does NOT own a copy of - types are shared, and
**which ones a room gets is per-biome data in `tools/biomes.gd`** (`enemies`:
type + position), not one constant in the generator. Composition is most of
what makes one room feel unlike the next: the lobby is empty, asset recovery is
four office boys one to a quadrant, the marble hall is four guards one to a
corner rather than a line across the top so they can be taken on one at a
time, and hellfire is four of those plus two wraiths and a warden - where things
start following you and taking your legs. Positions are chosen so
no enemy's sight reaches the door line, the spawns or the torch and heart stands
- the straight walk between the two doors stays safe in every biome, and the
flow and combat tests depend on nothing aggroing until a check deliberately
walks into range. The warden's 130 px is the longest look in the
game and every walkable line in the marble hall falls inside it, which is the
reason that room has none.
