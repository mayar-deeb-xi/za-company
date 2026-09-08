# Bosses - the rules they share, and the art they don't

Deep dive for `game/bosses/`. The root CLAUDE.md has the one-paragraph
version; `game/enemies/CLAUDE.md` has the cycle every boss runs on.

## What a boss is

A boss is an enemy with more than one attack that concedes instead of dying.
`boss_base.gd` extends `enemy_base.gd` and changes exactly three things:

- **Contact picks an attack.** Where the base enters WINDUP on touch, the boss
  asks `_pick_attack()` for an id and `_begin_attack()` loads that attack's
  wind-up, recover and damage into the base's own dials. The cycle itself is
  untouched, so `commit_fraction` and `interrupt_cooldown` mean what they
  always meant: a boss can be staggered out of a wind-up once, then not for
  1.2 s.
- **The attack's animation is the whole cycle.** `<attack>_side` runs from the
  first wind-up frame to the last recover frame, and its per-frame durations
  come from the same pose list the boss script derives `windup_seconds` and
  `recover_seconds` from (`Poses.windup_of()` - everything before the frame
  marked `impact`). The picture and the timer cannot drift. Because of that,
  `_apply_animation` holds a finished attack animation on its last frame
  instead of restarting it the way the base does, and `_contact_state()` is
  `idle` - a boss sheet has no plain `attack` row.
- **Zero health is a concede.** `has_conceded` goes true, the boss leaves the
  `enemies` group (so "is the room clear" checks stay honest) but stays in
  `bosses` and in the tree, plays `concede_side`, and emits `conceded`. It is
  never freed: he is still kneeling there when you walk out.

Bosses face **side only**. `_face()` never picks up or down, so a boss sheet
draws one profile and the game flips it. Four attacks in three directions was
twelve rows of art for a fight that reads perfectly well sideways.

## Nothing is shared between bosses but the rules

Each boss folder holds everything that is his: scene, script, `poses.gd`,
`src/<id>.png`, `<id>_frames.tres`, and any effect script. `roster.gd` lists
them, and each entry names its own painter and cell size. There is no shared
body, no shared sheet, no shared layout - the three bosses are heading three
different places.

## Ahmed

`ahmed/` is the template. His pieces, and what agrees with what:

- **`poses.gd` is the single source of truth for his shape.** Body as ASCII
  (35 rows, the feet on row 34), leg variants, and every frame of every
  animation as data: arm targets, the axe's hand/angle/length, body nudges,
  phase, and fire descriptors. Two consumers read it and must agree pixel for
  pixel: the painter that seeds the sheet and the fire that is drawn live.
  Change a pose here and both move.
- **`tools/bosses/ahmed.gd` paints the sheet** from the poses: body, arm, axe,
  outline. It runs only when `src/ahmed.png` is missing (see Sheets below).
  Cells are 64 px; body column 0 / row 0 sits at cell (25, 22), which centres
  him so a flipped frame stays put and stands his feet on row 56 - the scene's
  sprite offset of -24 is what puts row 56 on the boss's origin.
- **`axe_fire.gd` draws the fire live**, pixel by pixel, from the same poses,
  in two instances: `FloorFire` (first child, under the body: the slam's ring
  and cracks) and `AirFire` (over the body: everything else, the glow on the
  blade included). It reads the sprite's animation, frame and flip, so nothing
  tells it anything. A left-facing frame is drawn mirrored about the origin:
  local x lands at -1 - x. The sheet stays a clean body to draw into because
  the fire is not on it.
- **Four attacks, chosen by range and behaviour** (`ahmed.gd`): chop and sweep
  alternate in reach; every third swing, or sooner if he is hit twice inside
  2 s, is the slam; a player in the lane and out of reach gets the wave, then
  a cooldown. Damage is MEDIUM data in `DAMAGE`, scaled once when chosen.
- **Three reaches, three Area2Ds.** `Touch` (r 24) is the axe and what the
  base uses to decide he has arrived - so his wind-up starts at ~29 px from the
  player, before `stop_distance` (20) ever applies. `Ring` (r 40) is the slam:
  everyone in it with a `take_damage()`, office boys included. `Lane` (64x16,
  swung to his facing every frame) is the wave, which hits as it travels: the
  strike frame reaches 20 px, then each recover frame that draws the front
  further down the lane hits whoever it has reached and not yet burned.

## Sheets: seed once, slice always

`tools/build_bosses.gd` is build_enemies.gd's contract with a different seed:
an enemy is recoloured from the frozen CC0 body, a boss is painted by its own
`tools/bosses/<id>.gd`. Only when the PNG is missing. From then on
`src/<id>.png` is hand-owned art - draw into it, rebuild, only the frames
change. Delete it to start over from the painter.

Rows are `Poses.ORDER` (idle, walk, chop, sweep, slam, wave, concede), one row
per animation, frames left to right, padded to the widest (nine). The slice
runs at `Poses.FPS` (10) with each frame's `dur` as a duration multiplier, so
the sheet carries the attack's own timing; `character_art.slice()` grew a
cell-size argument and `durations` for exactly this, defaulting to the 32 px
CC0 behaviour everything else relies on.

If you hand-draw a frame, keep the body where the painter put it: the fire is
drawn from the poses, not from the pixels, so a hand-moved axe leaves its
flame behind.

## Boss floors

A floor gets its boss from `tools/biomes/<level>.gd` under `boss`
(`{type, at}`), the same shape as one `enemies` entry. build_levels.gd
instances it as `Props/Boss` and swaps the north door's script for
`game/levels/boss_door.gd`, which asks that sibling `has_conceded` on every
attempt to walk through. No signal wiring; a room built without a boss simply
opens. The door's `Seal` body is what makes "shut" solid.

The script is swapped BEFORE any door property is set: a node's exports reset
to the new script's defaults, so setting them first only loses them.

Ahmed's sight reaches the south spawn on purpose. Every other floor keeps the
door-to-door walk out of every sight radius; a boss floor is an arena and the
walk goes through him. test_flow.gd concedes him the short way
(`take_damage(96)`) to carry the chain on; the fight itself is
`tests/test_bosses.gd`'s, which places him in the empty lobby like
test_combat.gd does and records the order he attacks in rather than betting
on frames.

## Adding a boss

1. `game/bosses/<id>/poses.gd` - body ASCII, legs, `ORDER`, `ANIMS`, `LOOPS`.
2. `tools/bosses/<id>.gd` - a painter with `static func paint() -> Image`.
   Copy Ahmed's; only the poses it reads and its cell geometry change.
3. A roster entry in `game/bosses/roster.gd`.
4. `game/bosses/<id>/<id>.gd` over `boss_base.gd`: `_pick_attack()`,
   `_attack_spec()`, `_strike()` for anything that is not the axe on `Touch`.
5. `game/bosses/<id>/<id>.tscn` with the reaches it needs.
6. `"boss": {type, at}` in the floor's biome file, then
   `build_bosses.gd` and `build_levels.gd -- <level>`.
7. A section in `tests/test_bosses.gd` (one suite, one world: place him in the
   lobby and fight there).

## Still to build

DESIGN.md's Ahmed also yells "SECURITY!" at 64 and 32 HP and summons an office
boy through the door (cap 2). The slam already knows what to do with them. The
HUD has no boss bar yet, and the concede is a kneel rather than the enormous
chair.
