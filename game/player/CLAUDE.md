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

**Three ways the world reaches the player, and the splits between them are the
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
death. Freeze and push land here when they come - the shape is meant to take
them. A slow scales the walk animation as well as the speed, since a slowed walk
played at full rate reads as skating, but deliberately not the swing: it takes
your legs, not your sword.

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
`COMBO_GRACE_SECONDS` after, chains the thrust (`attack2` rows 9-11 of the cast
sheet, `THRUST_POWER` 7), which lunges a step forward (`LUNGE_SPEED`, decayed by
the same friction that roots attacks) and parks the Hitbox further out to match
its visibly longer blade. **A press mid-attack is buffered, never dropped** -
mashing alternates swing-thrust cleanly, and a dropped press reads as the game
eating the button. Getting hit deliberately does NOT break the combo: the game
has no hitstun, so a silently swallowed buffer would read as dropped input, and
melee happens inside enemy contact where hits are constant - the thrust's cost
is commitment (rooted through two animations, lunging toward danger), not a
hidden reset. Damage goes through a Hitbox Area2D that `_start_attack()` parks
one step ahead of the body in the facing direction; it stays live for the whole
animation but a ledger (`_swing_hits`) lands each attack once per enemy - so a
24 HP guard dies to one full mash cycle (5+7+5+7). The thrust's sparks are
tinted per character by `_spark_hex` in character_art.gd: the hair colour
raised to flash intensity (near-black hair would vanish on dark floors),
`SRC_SPARK` gold where a bald head has none. Per-character health and attack
stats are planned; they will join the roster recipe the way looks did.

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
