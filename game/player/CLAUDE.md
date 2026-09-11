# Player - characters, health, combat

Deep dive for `game/player/` and the HUD it feeds. The contract the world
presses on the player (blow / drain / status, group + has_method) is restated
in the root CLAUDE.md; the enemies these numbers are tuned against are
`game/enemies/CLAUDE.md`.

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
different and the cast's sheet is going to keep moving. See
game/enemies/CLAUDE.md.

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

**Four ways the world reaches the player, and the splits between them are the
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
death. Freeze lands here when it comes - the shape is meant to take it. A slow
scales the walk animation as well as the speed, since a slowed walk played at
full rate reads as skating, but deliberately not the swing: it takes your legs,
not your sword.

A *shove* (`shove(direction, force)`) is the fourth, and it arrived on exactly
the terms this section promised push would: it is shaped like a status, not like
a blow. Something the player carries for half a second and which decays on its
own, outside the grace window in both directions - a torch clip must not swallow
it, and being pushed must not buy immunity from the guard winding up behind you.
Overlapping shoves refresh rather than compound, the same rule a slow keeps: the
strongest push wins and the clock resets, so two machines catching somebody
between them cannot add up to a launch. The hub's floor scrubbers are what asked
for it (game/levels/CLAUDE.md's *The machines*); where one also wants to hurt it
calls `take_damage()` too, and the two meter themselves independently, which is
correct - the damage is a blow and the push is not.

Three things about it are load-bearing:

- **It is never added to `velocity`.** Velocity is carried between frames and
  only bled off at `FRICTION`, so adding a push to it every frame COMPOUNDS: a
  70 px/s shove held for half a second reaches several hundred and then coasts
  the player across the room long after the shove is over. It goes through its
  own `move_and_collide()` after the ordinary move instead, which leaves the
  state the stick owns alone.
- **The room stops it.** Because it is a real move rather than a teleport, walls
  and furniture bound it; and `MAX_SHOVE` (70) is under the walking speed of 90,
  so one physics frame is about 1.2 px and nothing can be posted through a
  16 px tile.
- **It rides on top of whatever the player was doing.** Walking, sliding through
  a light attack, rooted in the heavy - all pushed the same amount, because
  being rooted is not being bolted down, and a push you cannot walk against is a
  cutscene rather than a stumble. `MAX_SHOVE` and `SHOVE_SECONDS` together are
  the whole feel: half a second off a 70 ceiling is about 17 px, which is a tile.

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

## Combat - three moves, one button

The player's side of the fight is three attacks on the one attack button. A
press starts the swing (`ATTACK_POWER` 5); pressing again during it, or within
`COMBO_GRACE_SECONDS` after, chains the second hit (`attack2` rows 9-11 of the
cast sheet, `THRUST_POWER` 7 - the name is historical, the move is now a rising
slash). It shares the swing's hitbox: its arc covers the same reach, and the jump in
its art is its own movement. **A press mid-attack is buffered, never dropped** -
mashing alternates swing-thrust cleanly, and a dropped press reads as the game
eating the button. Getting hit deliberately does NOT break the combo: the game
has no hitstun, so a silently swallowed buffer would read as dropped input, and
melee happens inside enemy contact where hits are constant - the second hit's
cost is commitment (two animations facing one way), not a hidden reset.

**Light attacks steer and slide, the heavy roots.** While the swing or the
second hit plays, a held direction moves the body at `ATTACK_SLIDE` (0.35) of
walking speed AND turns it: `_turn_attack()` re-faces, re-parks the hitbox and
swaps the sprite to the new facing's row of the same attack at the same frame
and progress, so the swing keeps its timing while it follows the stick. The hit
ledger is untouched, so one swing still lands once per enemy however far it
turns. The
fraction is a step-in, not an escape: a guard's finish still lands on a player
who tries to walk out of it, which is what the grace window and the interrupt
tuning assume. The charge stance, the heavy and the wildfire brake to a stop as
before - the heavy's rooted seconds are part of its damage maths. Damage goes through a Hitbox Area2D that `_start_attack()` parks
one step ahead of the body in the facing direction; it stays live for the whole
animation but a ledger (`_swing_hits`) lands each attack once per enemy - so a
24 HP guard dies to one full mash cycle (5+7+5+7). The spark colour every
character carries comes from `_spark_hex` in character_art.gd: the hair colour
raised to flash intensity (near-black hair would vanish on dark floors),
`SRC_SPARK` gold where a bald head has none; it tints the swing, the charge
sparks and the wildfire. Per-character health and attack
stats are planned; they will join the roster recipe the way looks did.

The swing's art is **Lightning Edge** (rows 6-8 of the sheet): the old outlined
crescent is gone, and the blade is a one-pixel white line trailing a jagged
arc that cools and breaks into dashes, with a bloom at the hitbox centre on the
third frame. It is drawn blue in the sheet (the `SRC_VOLT_*` constants in
character_art.gd) and **recoloured per character the way the old sparks were**:
the white core stays, the arc becomes the spark colour, the tail and fade the
spark darkened - so Mayar swings violet, Anas gold. Everything stays inside the
32px frame; on the down row the bloom sits 3px above the hitbox centre because
the centre itself is on the frame's last row.

The second hit's art is **Rising Dragon** (rows 9-11): a launcher. Crouch in a
wide stance with the blade low, an uppercut slash that lifts the body three then
five pixels with a shadow painted on the floor beneath, blade straight overhead
at the apex, then a landing squat with dust. The bodies are NEW poses, not
reused frames: a pose kit takes the idle body's head, torso and legs, draws the
arms fresh for each frame and regenerates the outline. Its blues (`SRC_THRUST_*`)
are deliberately fixed for every character - the swing reads as the character's
own colour, the launcher as the weapon's - and sit one step off the volt values
so the recolour, which goes by exact hex, can tell them apart. The floor shadow
(`SRC_SHADOW`) is translucent: restyle() keeps each pixel's alpha when it
recolours, where it used to rebuild the pixel opaque.

Both were baked by a script from the pristine CC0 rows rather than drawn by
hand, so `character.aseprite` no longer matches the PNG; the PNG is the truth.

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

## Scripted control - when the world has the wheel

`take_control()` / `release_control()` / `lead_to()` are how a cutscene moves
the player, and the split from the door transition's
`set_physics_process(false)` is the whole point of them. A frozen body cannot
be walked anywhere, and the first thing a conversation wanted was to walk the
player across a room behind somebody.

So scripted control keeps physics running and cuts the INPUT instead: the stick
is not read, the attack button is not read, and any swing, thrust, charge or
heavy in flight is dropped on the way in - a conversation that opens on frame
two of a combo must not play out over the top of it, hitbox and all. What
remains is `_scripted_step()`, which is the ordinary walk with its direction
coming from `_lead` instead of the keyboard: same SPEED, same ACCELERATION,
same animation, so being led looks exactly like walking because it is.

`_lead` is a point, not a target node, re-set every frame by whoever is leading.
That is what lets one mechanism serve both "walk to this mark" and "follow her",
and `LEAD_STOP` is a ring rather than a pixel because an escort's destination
MOVES - a tighter test makes the walk stutter every time the guide slows down.

Health, grace and slows are all untouched by it. **Being talked at is not a
safe room**: the tree is not paused during a conversation (the guide has to
walk while she talks), so the protection is where an NPC is placed. See
game/dialogue/CLAUDE.md.

## The noise

The player's sounds work exactly the way an enemy's do and for the same
reason: `player.tscn` carries an `Audio` child (`player_audio.gd`) holding
id -> stream, player.gd fires names at it through `_sfx` / `_sfx_loop` /
`_sfx_fade` / `_sfx_stop`, and a name with no file behind it is silence with
no branch anywhere. Eight cues - `swing`, `swing2`, `charge`, `heavy`,
`wildfire`, `hit`, `hurt`, `die` - and a cue arrives by having the WAV.

**One set for all seven characters.** That is the sheet rule from Characters
above applied to the other sense, and it is permanent for the identical
reason: they play the same game with the same moves, so a swing cut once
should land on all seven at no cost. It has one consequence that had to be
designed for rather than discovered - **the hurt cue cannot commit to a
gender.** Six of the seven are not whoever the clip sounds like, and a plainly
male grunt out of a character who is not male is the animation telling the
truth while the audio lies. So `hurt` and `die` are carried by air rather than
by tone: breathy, one syllable, neutral in pitch.

### Why this is not `enemy_audio.gd`

The placement rule would bubble a file shared by two features up to `game/`,
and this one is not shared - it does a neighbouring job with a different first
line. An enemy is SOMEWHERE. A room holds up to seven of them and which corner
a wind-up came from is the whole of what panning is for, so `enemy_audio.gd`
is an `AudioStreamPlayer2D` with a flattened attenuation curve. The player is
never anywhere: the camera is on them, so their pan is 0 on every frame of
every room, and a positional node here buys a distance calculation to produce
silence's exact twin.

So `player_audio.gd` is a plain `Node` of plain `AudioStreamPlayer`s, and it
is SMALLER than its counterpart rather than a copy of it. It drops
`play_detached` outright - that exists because an enemy plays `die` on the
frame it is `queue_free`d and takes its own speakers down with it, and the
player is revived rather than freed, so a death here outlives itself for free.
What it keeps is the `loop_end` fix, which is the third copy of that one in
the project (`enemy_audio.loop`, `music._seal`) and is worth having three
times: a forward loop sealed to frame 0 plays exact silence with its flag set.

The four wrapper names on player.gd are `enemy_base`'s verbatim on purpose.
They are not the same code, but nobody reading both should have to learn two
vocabularies for one idea.

### Three splits, and two are the enemies' rules from the other side

**A swing is air; `hit` is a blow that landed.** The two lights announce
themselves in `_start_attack` - the frame the swing STARTS, when nothing has
been struck - and `hit` fires from `_strike()` only on a frame something was
actually reached. That is game/enemies/CLAUDE.md's rule pointed back at the
player: an impact over empty air teaches you that the sound does not mean you
connected. It fires once for the FRAME rather than once per enemy, because a
heavy landing on four bodies is one impact, and four copies of one clip
started on one frame is a click rather than four hits.

**`drain()` is deliberately silent**, and it is the one absence somebody will
file as a bug. A drain runs every physics frame and already knows its own rate
(see Health above); a gasp on each of those is sixty a second, and routing it
through the grace window to thin them out is precisely the mistake `drain()`
exists to not make. The thing draining you is already making the noise - the
wraith's own `drain` loop - so the information is on the bus already, coming
from the right direction. A DEATH is a different matter and is not a drain
tick, so `die` lives in `_lose_health()` rather than in `take_damage()`: a
drain that kills you has to kill you as audibly as a blow does.

`hurt` is metered for free, because `take_damage()` already is - the grace
window stops a crowd stacking gasps without a line of audio code. It fires
only on a blow that was SURVIVED, since `_lose_health` plays `die` at zero and
a gasp laid over the death breath in one frame is one muddy sound rather than
two clear ones.

**The charge is the one loop here.** The stance is held for as long as the
button is, so it has no length of its own to end at. It was first specced as a
one-shot capped at `CHARGE_SECONDS` so that the clip running out would be the
ready cue, and that was wrong on its own terms - a sound that stops 0.35s
before the heavy is available actively misinforms. The ready cue stays where it
already was, on the eyes: the charge animation doubles speed. The hum is faded
on release (an early release loses nothing, so it must not sound like something
broke) and CUT by `take_control()` and `revive()`, where the move itself was
cancelled and a hum trailing into the first line of a conversation would be the
cutscene starting on top of the combat it just dropped.

### Making them

`python tools/sfx/make.py player`, off `tools/sfx/player.py` - the bestiary's
pipeline with a second recipe, which is why the engine's dict is `CAST` rather
than `ENEMIES`. The levels sit ABOVE the bosses and the enemies rather than
under them, on the same arithmetic upside down: a room holds seven enemies and
one player, so the sound that says YOU are losing must never be won by a crowd.
`--relevel` re-shapes from `game/player/src/sfx/` and costs nothing; only a new
performance costs credits, and all eight are pinned in `KEEP` so a stray
`--force` cannot re-bill them. The prompts, the levels and the reasoning behind
both are in that file.
