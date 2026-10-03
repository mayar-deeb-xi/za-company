# Ahmed

Deep dive for `game/bosses/ahmed/`: the MENU of the three fights, the attack
suiting the range. The rules every boss shares are `game/bosses/CLAUDE.md`,
and its *The noise* and *The mouth* are written around him because he was
first - his grunts, his barks and his twenty-three voiced lines are the
examples there.

`ahmed/` is the template. His pieces, and what agrees with what:

- **`poses.gd` is the single source of truth for his shape.** Body as ASCII
  (35 rows, the feet on row 34), leg variants, and every frame of every
  animation as data: arm targets, the axe's hand/angle/length, body nudges,
  phase, and fire descriptors. Two consumers read it and must agree pixel for
  pixel: the painter that seeds the sheet and the fire that is drawn live.
  Change a pose here and both move.
- **A leg variant's ROW COUNT is the body drop it pairs with**, and getting
  this wrong is what split him at the hips for two commits. The painter
  anchors a leg block's last row to row 34 - the floor - whatever the frame's
  `dy` is, so the torso and the legs meet only when `dy = 7 - rows`: brace is
  7 rows at dy 0, `crouch` 6 at dy 1, `knee_one` 5 at dy 2, `kneel` 3 at dy 4,
  `kneel_low` 2 at dy 5. The old painter added `dy` to the legs as well, which
  meant a 3-row kneel at dy 4 drew its legs four rows BELOW the torso and four
  pixels under the floor. There is a separate key for the other thing a frame
  might mean: **`lift` takes both feet off the ground** and moves body and legs
  together, which is what the walk's bob and the slam's rear-back use.
- **`tools/bosses/ahmed.gd` paints the sheet** from the poses: body, arm, axe,
  outline. It runs only when `src/ahmed.png` is missing (see
  game/bosses/CLAUDE.md's Sheets). Cells are 64 px; body column 0 / row 0 sits
  at cell (25, 22), which centres him so a flipped frame stays put and stands
  his feet on row 56 - the scene's sprite offset of -24 is what puts row 56 on
  the boss's origin.
- **`axe_fire.gd` draws the fire live**, pixel by pixel, from the same poses,
  in two instances: `FloorFire` (first child, under the body: the slam's ring
  and cracks) and `AirFire` (over the body: everything else, the glow on the
  blade included). It reads the sprite's animation, frame and flip, so nothing
  tells it anything. A left-facing frame is drawn mirrored about the origin:
  local x lands at -1 - x. The sheet stays a clean body to draw into because
  the fire is not on it.
- **Five attacks, chosen by range and behaviour** (`ahmed.gd`), picked from
  an animated preview and built to it: each asks for a different move.
  - In reach, chop and sweep alternate. The chop is a **fissure** - a crack
    runs 73 px on ahead of the blade and seven pillars burst out of it, 8 more
    to anyone on the line, so backing straight off is the wrong answer. The
    sweep **shoves** (`shove()` at the player's own cap of 70, ~18 px of
    skid): far enough to put you out of reach and in front of him, which is
    where the wave goes - a combo you can see coming.
  - The slam is a **leap**: two crouch frames, then the frame marked `air` is
    the jump (0.6 s), carrying him to where the player stood as he left the
    ground, up to 100 px. In reach it is every third swing or two hits inside
    2 s, as before, and is a hop; out of reach it is how he follows you. The
    sprite and AirFire rise (`_set_height`); his body, shadow and Ring stay on
    the floor.
  - In front of him and out of reach, the **fan**: three waves 0.42 rad apart,
    14 each. Between two of them is safe - sidestep a little, not a lot.
  - Kept out of his reach for 3 s, **the enormous chair**: he sits in it (the
    `chair` row, painted last onto the sheet by build_bosses' `_extend`),
    spins it up for a second - the sprite flipping fourteen times a second -
    and rolls at 255 px/s until he hits something, 18 to whoever the Touch
    area meets on the way, then sits dizzy for 1.55 s. The charge frame's
    `dur` is the longest the run may last; the recover the base counts is the
    dizzy spell alone, and the clock is held while he rolls.
  - The three ranged answers share a 1.5 s `ranged_gap`, so keeping away is a
    fight and not a barrage. Damage is MEDIUM data in `DAMAGE`, scaled once
    when chosen.
- **Every impact lands with weight** (`_jolt`): a 0.08 s hit-stop, a shake and
  a white star. The stop is the `froze` signal on boss_base, wired by game.gd
  like `shook`; game.gd drops `Engine.time_scale` to 0.05 (never 0 - a zero
  delta is a division waiting to happen) and lets it go on an unscaled timer,
  extending rather than stacking, and on every room change and exit.
- **Two reaches, two Area2Ds, and the rest is geometry.** `Touch` (r 24) is the
  axe, the chair's bumper, and what the base uses to decide he has arrived -
  so his wind-up starts at ~29 px from the player, before `stop_distance` (20)
  ever applies. `Ring` (r 40) is the slam: everyone in it with a
  `take_damage()`, office boys included. The old 64x16 `Lane` is gone: the
  fan and the fissure carry their own lanes, measured in their own nodes, so
  the line you see is the line that burns.
- **What an attack throws off is a child of his pinned to the floor**
  (`fx_node.gd`): fissure, fan, leap mark, landing, shove dust, chair run,
  impact star. A child, so it draws in his slot in the room's y-sort like the
  axe fire; re-pinned to its `anchor` every frame, so it stays where it fell
  while he walks away; on its own clock, because most of them outlast the
  frames that made them. They draw with `fx_kit.gd`, the preview's own pixel
  functions ported line for line (JavaScript's half-up rounding included), so
  a number tuned on the preview means the same thing here. The landing and
  the leap mark are CIRCLES where the old slam drew an ellipse: the Ring is a
  circle, and the drawing that says get out must be the shape that hits.

## The concede

Ahmed's concede is done: he lets go of the axe. He straightens up one last
time, his fingers open, the axe drops and lands flat, and the fire goes out the
moment it leaves his hand - the painter draws the axe wherever its descriptor
says regardless of where the arm is, so a dropped axe costs nothing but a hand
that stopped following it. With nothing left to hold, the far arm comes into
view and both hands end on his thighs. Then `beaten` loops for the rest of the
run, which is the point of the whole thing: every other option on the table
left a statue in the room. It is a kneel rather than the enormous chair. The
panting that goes with it does NOT loop for ever - see What he sounds like.

## What he sounds like

The mechanism - an `Audio` child, and `hurt`, `stagger` and `concede` wired by
the base for free - is game/bosses/CLAUDE.md's *The noise*, and so is where
his files sit and how his attack sounds are split. What is here is his alone.

Ahmed's own two are his, for the same reason his fire is: `axe` starts in his
`_ready` and never stops, because the blade burns for as long as he holds it,
and `breath` starts when the concede hands off to `beaten_side`. The axe fades
rather than cuts, over `Poses.glow_out_of("concede")` - the span the poses
actually draw fire for, derived beside `windup_of` and `recover_of` so a
retimed concede takes the sound with it rather than leaving the room silent
with the blade still lit.

**And the breath ENDS, which it did not used to.** The `beaten` row loops for
good and must - he is still there and still alive when you walk back out - but
the panting is an event with an end, and left running it was the only sound on
the floor for as long as the player stayed: his theme fades on the concede and
Ivan walks in to talk over the top of it. `_settle()` winds both halves down
together, the sound fading after `BREATH_HARD` and the row slowing to
`BREATH_CALM` across the whole span, so the picture and the sound tell the same
story at every moment - the thing the axe fade above already had to get right.
Fading the sound alone would have read as the audio breaking while his chest
still heaved. What is left is a man kneeling and breathing slowly, which is
what the row was drawn for.

His eight attack sounds, a telegraph and an impact for each of chop, sweep,
slam and wave, are the shared file's example of that split. The chair has no
`chair_windup` or `chair_hit` yet: both are legal misses, and it is silent
until they are cut.

They are levelled by RMS against the sounds he already had, not by peak.
Peak-normalising all eight to a flat -4 dBFS left 13 dB of spread in how loud
they actually sound and inverted the fight: `chop`, the basic alternating
swing, came out louder than `slam`, which is the blow the camera shakes for. A
short transient and a dense fire whoosh are not the same loudness at the same
peak. So the ordinary blows sit with his own one-shots (-19 RMS, beside hurt at
-18.8 and stagger at -19.8), the wave a shade forward because it travels, and
the slam alone above the pack at -16. Telegraphs run 7 dB under their own
impact - clearly over the -34 dB idle fire, never mistakable for the blow they
are warning about - and each is shorter than the wind-up it plays under, the
tightest being `sweep_windup` at 0.48 s against a 0.52 s wind-up.

The slam needed a soft limiter (tanh at the ceiling) rather than a gain cut to
get there: pulling the whole sound down to fit its tallest transient under the
ceiling is what held it 2 dB under target in the first place, and on an impact
the harmonics a soft knee adds read as punch.

## His theme

A boss's theme is one path on his scene root, played and faded with his bar
(game/bosses/CLAUDE.md's *The theme is not one of his sounds*). Ahmed's is
`assets/music/ahmed_theme_loop.wav`, 60 s at 48 kHz, and the one thing to
listen for is its seam - a generated track is rendered to a time, not to a
bar, so the loop point is where it will show.

## Still to build

DESIGN.md's Ahmed also yells "SECURITY!" at 64 and 32 HP and summons an office
boy through the door (cap 2). The slam already knows what to do with them.
