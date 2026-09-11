# Enemies - the base, the types, the art pipeline

Deep dive for `game/enemies/`. The cross-cutting invariants (HP numbers are
combo breakpoints, difficulty never scales them, reskins keep the base's
numbers, composition is per-biome data) are restated in the root CLAUDE.md;
the player's side of the fight - the combo and the heavy these numbers are
tuned against - is `game/player/CLAUDE.md`. Bosses extend this base with
several attacks and a concede; they live in `game/bosses/`, with their own
CLAUDE.md.

## The base

`game/enemies/enemy_base.gd` is the base every type builds on: an enemy stands
guard until the player comes within `sight_radius`, closes the ground to
`stop_distance` and holds there facing them, follows them for a while once it
has seen them and goes back to its post when it loses them (The leash, below), and presses its touch on the
player every physics frame of contact - no timers of its own, the player's
grace window meters the pressure, exactly like hazards. Stats (`max_health`,
`contact_damage`, `speed`, `sight_radius`, `stop_distance`, `patience_seconds`,
`leash_factor`) are @exports, so a level can retune the instance it places. Enemies find the player by group +
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

**Reskinning the wraith and the warden moved their scripts up here**, and that
is the placement rule in CLAUDE.md doing its job rather than a special case: the
moment a second feature needs a file it bubbles up one level above the features
that share it. So `wraith_base.gd`, `warden_base.gd` and the two effects they
draw with (`drain_aura.gd`, `charge_ring.gd`, each with its shader) sit at
`game/enemies/`, beside `enemy_base.gd`, and four folders now hold nothing but a
sheet, a `_frames.tres` and a scene. Read it the way the regular and the office
boy already read: the archetype's behaviour is shared, the look is not.

What is NOT shared is the tuning. Each scene repeats the archetype's exports -
17 HP and 45 speed on both drainers, 36 and the 2-second charge on both chargers
- so a floor can retune the copy it places, which is the same bargain
`office_boy.tscn` makes. The cost is real and worth naming: retune the wraith's
scene and its reskin keeps the old numbers. `tests/test_combat.gd` spawns both
reskins and asserts their health against the archetype's, which is what catches
that drift.

## The leash: what an enemy does about a player who walks away

`sight_radius` is how an enemy NOTICES the player and that is now all it is.
Every authored position in `tools/biomes/` is placed so no sight radius reaches
the door lane, so **entering the circle has to stay the only way to be seen** -
widen it and every floor in the game breaks at once, along with the flow and
combat tests. That half does not move.

What was wrong was everything after it. The chase was gated on the player
being inside that circle THIS FRAME, so an enemy stopped mid-stride the moment
they stepped one pixel back over the edge - and at 90 against 45-55 the player
owns that pixel whenever they want it. Two things followed, and the second is
the worse one. A guard that halted on an invisible line read as a guard that
did not care. And it halted *where it happened to be standing*, so a player who
walked one body out of position and left never had to face that arrangement
again: the room was permanently a little flatter, on a floor whose shape is
most of what makes it unlike the last one.

Two numbers, neither of them touching detection:

- **`patience_seconds`** (2.5) - having seen the player, it keeps coming for
  that long after losing sight. Escape becomes a distance you have to make -
  137 px for a guard - rather than a line you step over. It walks at the
  player's CURRENT position through that window rather than their last known
  one, which is the small lie a game of this kind tells; the honest version is
  an enemy striding confidently at where you used to be.
- **`leash_factor`** (2.0) - it will not follow further than that multiple of
  its sight from its POST, the spot it was placed on. So a guard owns 160 px
  around its mark, a wraith 240 and a warden 260. **Measured from the post and
  never from the enemy's own feet**, which is the one thing to get right here:
  a bound on the distance to the PLAYER travels along with the enemy and so
  permits a chase across the whole building, which is not a leash at all.

Then it walks home and stands on its mark again, which is the half that
protects the arrangement. `HOME_SLACK` (2 px) is what keeps it from jittering
forever on the last half pixel - the same reason `npc_base.gd` has one.

Only a player retreating *while staying in sight* can pull an enemy any real
distance, because patience alone gives out at 137 px, so the leash is a bound
on kiting specifically. At the edge of it the body holds station and keeps
watching a player it can plainly see, which is a legible thing to look at: it
has not lost you, it is not coming.

**Two bodies opt out, and they opt out of different amounts of it.** A boss
overrides `_leashes()` to false and loses the lot - no patience, no bound, no
walk home, which is exactly how every enemy behaved before this: his floor is
an arena holding one body, so there is no arrangement for a leash to protect,
and his own scripts read `sight_radius` directly for the dash, the taunt and
every attack gate, so a base that walked him back to his spawn the moment the
player stepped out of it would be fighting all three.

A reinforcement gets `unleash()` from `game/levels/reinforcements.gd` on
arrival, and that takes only the POST - it still hunts, still runs out of
patience and still gives up, it simply has no mark to be held near and none to
go back to. That is the right half to remove: they are the only enemies in the
game with no authored position, the leash is anchored to authored positions,
and the only thing an arrival could be tied to is the doorway it walked in
through. A body that came to find you is not defending anything.

`tests/test_combat.gd` ends on it - the pursuit past the circle, the giving up,
the walk home, and a guard dragged 160 px and not one pixel more.

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

  **His sheet is drawn past the seed and is the one place the reskin is more
  than a recolour.** The seed's sword is gone: he carries a wrench, and his
  `attack` rows are a THRUST along the facing rather than a swing across it.
  Three things about those twelve frames are deliberate, and all three are easy
  to undo by redrawing carelessly:

  - **The impact is on frame 3.** All four frames play inside the 0.45s wind-up
    at 14fps, so the animation ends 164ms before the blow does and the last
    frame is what is on screen when `_touch_strike()` fires. Frame 3 carries the
    spark and the smear for that reason; the seed's sword peaked on frame 2 and
    was trailing away by the time it cost anything.
  - **The read is silhouette LENGTH, not direction** - ready, coiled, driving,
    extended. The coil pulls the wrench back along the axis it strikes on; an
    earlier pass flipped it to point the other way and at 14fps that read as a
    bug rather than as loading a thrust.
  - **The wrench is in the idle and walk rows too**, so it does not appear out
    of thin air the moment he attacks. Nothing else in the bestiary does this
    yet - the wraith and the warden carry nothing - and it is the reason his
    sheet still fits the plain 9-row `CC0_LAYOUT` with no `layout` entry.

  **The apron is a dark bib INSIDE the polo, and the teal border round it is the
  whole look**: every shirt pixel below the collar row, inset two columns off
  the shirt mass's bounding box, plus a belt line on the first row of trousers.
  It shipped wrong once, and the failure is worth knowing because it looks like
  a reasonable simplification: darkening the bottom shirt row full-width instead
  puts the dark straight against the trousers, which are also dark, so there is
  no bib left to see and he reads as a teal shirt that stops early. The apron
  has to have polo on BOTH sides of it.

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
  feeding so the health ticking down has a visible cause, and the aura itself
  is drawn (`drain_aura.gd` + `drain_aura.gdshader`, the wraith's first child
  at z 0 like the warden's field): a dashed rim at the Touch shape's exact
  reach, brighter and turning while it feeds, and one mote streaming from the
  player's chest to the wraith's for every point taken. The mote is spawned in
  `_touch()` on the same line that calls `drain()`, so the drawing beats at
  the real 3/s and can never show health that was not lost. The motes are
  drawn with draw_rect on the aura node, which has NO material - the shader
  lives on its `Rim` child, because a material on the parent would run every
  mote through the rim shader and paint it transparent. Being one of the cast
  drained of colour - straight hair, normal build, white on dark blue - is the
  point of the look: it reads as a person, not a monster.

  It opts out of the attack cycle (`_attacks()` false), so **it is the one thing
  in the game that hitting does not stagger** - deliberately, since it has no
  attack to stagger, only proximity. That leaves exactly two answers to it,
  leave or kill it, and being the softest of the three at three hits is the
  other half of that bargain.
- **`social_media/`** - the wraith, reskinned as the Content Studio's people.
  Identical numbers, its own sheet, no script: its scene runs `wraith_base.gd`.
  The look wears the floor's own neon - `a64dff` is the Content Studio's accent,
  and she carries it in dyed violet hair over a black tee, so on the darkest
  floor in the game the hair is the silhouette. **The known cost of that pick**:
  violet moves less than a warm colour would under the cold feed tint, so the
  drain is told by the aura and the motes more than by the body. If it ever
  reads as ambiguous in the room, the fix is on `drain_aura.gd`, not the sheet.
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

  Its telegraph is two readings of `_windup_progress()`: the drawn field
  (`charge_ring.gd` and its `charge_ring.gdshader`) and the violet
  `_windup_tint()`. The field exists because 48 px of floor is six times the
  width of the body and no animation on a 32 px sprite can say where an area
  ends. A dashed rim marks the reach at all times; as the charge fills, frost
  creeps out from the warden's feet and reaches the rim exactly as the slow
  lands, so how far and how soon are one shape - and past `commit_fraction`
  the frost's edge blinks white and the body shivers a pixel, the same "too
  late" said twice. On landing the whole area ices over and thaws in step with
  the four seconds of slow. It copies its radius off the Touch shape on
  `_ready`, so the drawing cannot lie about the reach, and because both
  readings take the one number, an interrupt wipes the frost and drops the
  tint in the frame it lands - legible without a line of code of its own.

  Two gotchas, both paid for once. **The warden does not play `attack`**:
  `_windup_state()` is overridden to `idle`, because on this sheet `attack`
  is a sword swing and a harmless enemy raising a sword for two seconds read
  as the one thing it is not. And **the field must sit above the floor**: it
  is the warden's first child at z 0, over the tiles and under the body. The
  level's Floor tilemap is itself at z 0, so the `z_index = -1` it used to
  carry drew it under the floor, and the ring was never once on screen.

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
- **`call_center/`** - the warden, reskinned as the phone team's supervisors.
  Identical numbers, its own sheet, no script: its scene runs `warden_base.gd`.
  Deliberately the most ORDINARY-looking person in the building - grey
  button-up, navy slacks, no beard - because everything frightening about him is
  the field on the floor, not him. The pale shirt is the working part rather
  than a neutral choice: `_windup_tint()` pushes the body toward violet in
  proportion to the charge, and a light neutral takes that tint harder than any
  other colour tried, so the two-second warning reads on the body as clearly as
  it does on the ring.

## The noise: every enemy owns its sounds, exactly as it owns its sheet

The sheet rule below applied to the other sense. `enemy_audio.gd` is the
mechanism and it is shared; the files are not, and a reskin is no more a
recolour here than it is in the PNG. `office_boy` is the regular down to the
last frame of its wind-up and must not sound like it: the regular swings a
sword, the office boy THRUSTS a wrench, and a thrust that rings like a blade
is the animation telling the truth while the audio lies. Six characters, not
three.

**The node moved up here, and that is the placement rule rather than a
favour.** `enemy_audio.gd` was `game/bosses/boss_audio.gd` until the plain
enemies wanted the identical node for the identical job. A boss IS an enemy -
`boss_base.gd` extends `enemy_base.gd` - so it now sits beside the base it
serves, and `_sfx`, `_sfx_loop` and `_sfx_fade` moved with it and are
inherited. `wraith_base.gd` made the same journey for the same reason when it
got a reskin. What stays in boss_base is only WHERE a boss fires them.

**Five cues, fired off moments the cycle already had**: `windup` as the
telegraph starts, `hit` when a blow actually lands, `hurt` and `stagger` off
the two ways a hit reads, `die`. An enemy gets them by owning an `Audio` child
with the files in it and nothing else - the HUD-bar deal. No `Audio` child, an
id it was never given, and a fresh checkout whose WAVs are not imported all
land in the same null check and play nothing, so the fight works before anyone
has imported anything. `tests/test_enemy_sfx.gd` passes with the sounds
missing.

Four things are load-bearing, and three of them are the bosses' rules
inherited rather than re-decided (game/bosses/CLAUDE.md, The noise):

- **The stagger REPLACES the grunt.** The one thing the player needs off that
  hit is that the swing died, and two sounds on one frame is the fastest way
  to hear neither.
- **`hit` fires only on a blow that found somebody.** A swing through empty
  air said everything it had to say on the wind-up, and an impact with nothing
  under it teaches the player that the sound does not mean they were hit. It
  lives in `_strike()` for that reason and not in `_touch_strike()`, which the
  warden overrides and which cannot see whether anyone was there.
- **A telegraph is levelled and LENGTH-capped under the wind-up it plays
  beneath**, 7 dB below its own impact. A warning still sounding when the blow
  lands has stopped being a warning.
- **`die` cannot be played the ordinary way, and this one is new.** It fires
  on the frame the body is `queue_free`d, and every player under the node is
  freed with it - the ordinary path starts a sound and destroys it in the same
  frame. `_sfx_detached()` hands a copy to the enemy's PARENT, which buries
  itself when it finishes. No boss ever hit this, because a boss concedes
  instead of dying and is still standing in the room when you leave.

**The wraith's drain is the only sound in the game that is a STATE**, and it
is the one enemy that needs one: nothing is swung and nothing lands, so
without it the one enemy that hurts you by standing there is also the one you
cannot hear. `wraith_base` asks for it every frame it is feeding and fades it
over 0.08 s when contact breaks - both calls are idempotent, so that is a
dictionary lookup and no branch. The fade is not politeness: the clip ends
mid-waveform because it is a seamless loop, and cutting it dead clicks.

**A generated loop does not loop**, which the menu track paid for first (root
CLAUDE.md, Music). Two separate failures live in one clip and each is
invisible on its own: the seam, fixed by a 12 ms equal-power crossfade in
`tools/sfx/wav.py`; and `loop_end` 0, which is NOT "to the end" - a forward
loop ending on frame 0 wraps before it has played anything and the bus
receives exact silence with every flag reading correct. `enemy_audio.loop()`
seals it on the stream rather than trusting the `.import`, and
test_enemy_sfx.gd checks both.

Levels are relative and baked into the files, because there is no bus layout
and no volume setting - a file's own level IS the mix. The enemies sit UNDER
the bosses and that is arithmetic rather than deference: a boss floor holds
one boss, hellfire holds four guards, two wraiths and a warden, and seven
bodies at a boss's level is a wall rather than a fight.

    boss ordinary blow   -19 RMS      the number everything else is set from
    enemy hit            -22 RMS      3 under it, and there are six of them
    enemy telegraph      -29 RMS      7 under its own impact, the boss's ratio
    the drain loop       -30 RMS      continuous, so it lives near the floor

The sounds are generated: `tools/sfx/make.py enemies`, with the prompts,
durations and levels in `tools/sfx/enemies.py` - mechanism and recipe, the
same split as `cut.py` to `ahmed.py`. Unlike the bosses' sounds, whose prompts
went with the scratchpad script that made them, this one is in the repo.
`--relevel` re-shapes from the untouched exports in `src/sfx/` and costs
nothing, which is the way to carry a sound onto a better leveller without
paying for it twice.

## The mutters: two of them talk, and neither is talking to you

`social_media` and `call_center` say things while they are alive. Nothing else
in the bestiary does, and what makes these two worth voicing is that the line
and the mechanic are the same joke:

- **She is a wraith.** No attack, no telegraph, and standing near her costs
  three health a second. Every one of her eight lines is about not having
  enough time, said by the thing that is taking yours - "I just need five more
  minutes" is her aura, described. Laura, female, and the first voice in the
  game that is not a man shouting.
- **He is a warden.** He deals no damage at all and instead takes four seconds
  of your speed, and he is drawn as the most ordinary person in the building
  because everything frightening about him is the field on the floor. So he is
  Eric - the smooth, trustworthy hold-music voice - and **none of his lines is
  a threat**. They are the things a call centre actually says, said kindly, by
  somebody whose whole mechanical purpose is to make you wait. "Relax, you're
  not going anywhere" is a reassurance and a description of the slow at once,
  and it only lands because the seven around it are sincere. A line that
  dropped the mask would turn him into a small boss, which is the one thing
  this character is built not to be.

**`enemy_lines.gd` moved here from `game/bosses/` on the same day and the same
rule as `enemy_audio.gd`**, and for once the second user needed the node
completely unchanged: one line at a time, a cooldown per cue, never the same
line twice running, the clip loaded by path and played positionally. `_lines`
and `_say` live on `enemy_base` now; what a boss still owns is the SUBTITLE,
as an override of `_say` that emits `said`.

That split is the whole design and it is worth stating outright: **a boss is
addressing you, an enemy is being overheard.** A mutter therefore has no
subtitle - four of them would fight each other for one box, and putting an
office worker's grumble on screen turns eavesdropping into being spoken to.

Three smaller things:

- **The cue is polled, not fired.** Every other line in this game hangs off a
  moment the fight makes - he swung, he was interrupted, he lost. This one
  answers to nothing, so `enemy_base._mutter()` asks every `MUTTER_POLL`
  (2 s) and is refused most times. The real pacing is the `Lines` child's own
  `cue_seconds` (11 for her, 14 for him - she is heard at point blank, he
  plants at the rim of a 48 px field), which is where every other line timing
  already lives rather than a second set of dials here.
- **The FIRST ask is scattered across a whole cooldown.** Four spawn on one
  frame with their cooldowns at zero, so a fixed first poll makes the whole
  room speak at once and then settle into a rhythm. That sounds like a bug and
  cannot be heard as an office.
- **It keeps going while they are being hit.** The mutter is not a reaction,
  and an office worker who stops complaining the moment a fight starts is an
  office worker who was only ever scenery.

The lines live with the mouth that says them - `game/enemies/<id>/mutters.gd`,
the placement rule a boss's `taunts.gd` and an NPC's conversation already
follow - and are cut by `tools/voice/cut.py <id>`, the bosses' pipeline
entirely unchanged. They are levelled at **-31 dBFS RMS**, twelve under a
boss, and the number is load-bearing rather than timid: a mutter must sit
under the warden's own telegraph at -29, because a wind-up is information the
player needs and this is decoration. Voice carries at a lower RMS than a noise
effect does - it lands in a band nothing else here occupies - so -31 is
audible rather than buried, checked against the drain loop she stands in.

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
start its art over from the plain body. An enemy whose sheet does not hold the
CC0 grid's rows adds a `layout` (and `specs`) to its roster entry; the default
lives in tools/character_art.gd, which is the shaping and slicing engine both
generators share.

**That goes for rows dropped as much as rows grown.** The wraith and the warden
never play `attack` - the wraith has none at all and the warden's charge is
animated as `idle` on purpose - so the swing the seed gave them was three rows
nothing could ever reach. Both sheets are cut to 6 rows and both entries name
`NO_ATTACK_LAYOUT` in roster.gd. It matters because these are hand-owned art:
what is in the PNG is what someone draws into next, and rows that cannot play
are three rows of a lie about what the enemy does. Give one of them a swing
later and it takes its own `layout` back, at whatever rows its sheet then has.

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
walks into range. The leash does not loosen that rule and it does not tighten
it either: **the lane is a promise about being NOTICED, not about being safe**.
Nothing sees a player who walks it, so nothing follows them into it - but a
player who has stepped into a sight radius and then retreated into the lane is
being followed there, which is the point of the thing. The warden's 130 px is the longest look in the
game and every walkable line in the marble hall falls inside it, which is the
reason that room has none.
