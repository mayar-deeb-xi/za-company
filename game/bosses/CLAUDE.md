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
  never freed: he is still kneeling there when you walk out. A boss who should
  keep MOVING after that hands off to a looping row himself, off
  `animation_finished` in his own script (Ahmed does; see his `beaten`) - the
  base plays the concede once and stops there, because one animation cannot
  loop only its last two frames.

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

Rows are `Poses.ORDER` (idle, walk, chop, sweep, slam, wave, concede, beaten),
one row per animation, frames left to right, padded to the widest (nine). The slice
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

**The lock is currently OFF for development**: `boss_door.gd`'s `LOCKED` const
is false, so a boss floor can be walked straight through while the floors above
it are being built. Everything else is untouched - the door still asks the boss,
the fight is still placed - and the boss-floor check in tests/test_flow.gd reads
that same const, so flipping it back to true is the only edit. It has to go back
before shipping: a boss floor that is not a gate is just a room with a big man
standing in it.

The script is swapped BEFORE any door property is set: a node's exports reset
to the new script's defaults, so setting them first only loses them.

Ahmed's sight reaches the south spawn on purpose. Every other floor keeps the
door-to-door walk out of every sight radius; a boss floor is an arena and the
walk goes through him. test_flow.gd concedes him the short way
(`take_damage(96)`) to carry the chain on; the fight itself is
`tests/test_bosses.gd`'s, which places him in the empty lobby like
test_combat.gd does and records the order he attacks in rather than betting
on frames.

## The bar

Every boss puts his health on the HUD, and none of them knows it. `title()`
names him from his own SCENE path - `Props/Boss` is what build_levels.gd calls
the instance, so his node name would put BOSS on the bar - and `take_damage()`
emits `health_changed(health, max_health)`, the same signal in the same shape
the player already has. game.gd finds him through the `bosses` group when it
builds the room, feeds `Hud.set_boss()` once and wires the rest straight
through; the bar comes down on `conceded`, since he is never freed.

So a new boss gets a bar by existing. Nothing in `ui/hud/boss_bar.gd` names a
boss and nothing here names a bar.

The bar itself is ember, not the player's crimson - two red bars on one screen
is one bar the player has to identify first - and the pale block trailing the
fill is a hit's worth of ground, held and then drained. Both boss HP are
multiples of the heavy's 24, so a heavy is a visible chunk of a 240 px channel:
a quarter of Ahmed, a sixth of Mostafa.

## The noise

`boss_audio.gd` is to sound what `boss_base.gd` is to the fight: the mechanism
is shared, the files are not. A boss's scene gets an `Audio` child holding a
`sounds` dictionary of id -> stream, one `AudioStreamPlayer2D` is built per
entry at `_ready`, and **three ids are wired by the base for free** - `hurt`,
`stagger` and `concede`. A boss gets those by owning the files, the same deal
as the HUD bar; a boss who owns none stays silent with no branch anywhere but
`_sfx`.

Four things are load-bearing:

- **Every miss is legal.** An id the boss was never given, a boss with no
  `Audio` child, and a checkout whose WAVs have not been imported yet all
  land in the same null check and play nothing. That is not defensiveness for
  its own sake: the audio is the one part of the game that is NOT generated
  from data, so a fresh clone genuinely does have a scene pointing at five
  resources that do not exist until an `--import` pass has run, and the fight
  has to work anyway. test_bosses.gd passes with the sounds missing.
- **The stagger REPLACES the grunt.** A hit that interrupts a wind-up plays
  `stagger` and not `hurt`. The one thing the player needs off that hit is
  that the swing died, and two sounds on one frame is the fastest way to hear
  neither.
- **A loop's flag is set on the stream, not trusted to the .import.** Import
  settings are written by whoever first scanned the file, and a loop that
  quietly does not loop is very hard to notice inside a fight.
- **Levels are relative and baked into the files**, not left to the mixer:
  Ahmed's idle fire sits at -14 dBFS because it plays for the whole fight,
  his one-shots near -4 so a hit reads over it. There is no audio bus layout
  and no volume setting yet, so a file's own level IS the mix. Re-generating
  one sound means re-levelling it against the others.

Ahmed's own two are his, for the same reason his fire is: `axe` starts in his
`_ready` and never stops, because the blade burns for as long as he holds it,
and `breath` starts when the concede hands off to `beaten_side`. The axe fades
rather than cuts, over `Poses.glow_out_of("concede")` - the span the poses
actually draw fire for, derived beside `windup_of` and `recover_of` so a
retimed concede takes the sound with it rather than leaving the room silent
with the blade still lit.

His sounds sit in `ahmed/sfx/`, and their untouched exports in `ahmed/src/`
next to his sheet - the same split `src/` means everywhere else in this repo.
An ElevenLabs export is padded to a full second whether or not the sound fills
one, so what lands in `sfx/` is always trimmed, summed to mono and levelled,
never the file that came out of the generator: his grunt had 0.35 s of silence
in front of it, which is a hit landing a third of a second late.

Still to make: the eight attack sounds, a telegraph and an impact for each of
chop, sweep, slam and wave. They are split in two on purpose - a wind-up can
be interrupted, so a single clip covering the whole swing would play an impact
that never happened.

### The theme is not one of his sounds

A boss's MUSIC goes through `Music` (autoload/music.gd) and never touches
`boss_audio.gd`, and the split is the same one that decides everything else in
here: his grunts are positional, because a boss crossing the room should pan,
and a track is not standing anywhere. So a theme is a plain path on
`boss_base` - `@export_file("*.wav") var music` - which `game.gd._watch_boss()`
plays when it finds him by group and fades when he emits `conceded`, on
exactly the two moments it raises and clears his HUD bar. Three consequences
worth knowing before adding a second theme:

- **A new boss needs no music code**, the same way he needs no HUD code. He
  names a file on his scene root and that is the whole of it.
- **Silence is a floor with no live boss**, decided in one place. `_watch_boss`
  fades whatever is playing when it finds nobody - which is every ordinary
  floor, and also a boss floor walked back through after he has conceded,
  since a conceded boss is skipped. No room says anything about music.
- **The track is declared on the boss, not in `Music`'s catalogue.** That
  catalogue exists for `MENU`, the one track three front-end screens ask for
  by name and would otherwise spell out three times. A boss theme has exactly
  one asker, so it lives on him - and a boss who names none simply fights on
  in silence.

`Music.fade_out()` deliberately does NOT restart a fade already running,
because these exits stack: conceding starts one and the door off his floor
asks for another while it is still going. Ahmed's is
`assets/music/ahmed_theme_loop.wav`, 60 s at 48 kHz, and the one thing to
listen for is its seam - a generated track is rendered to a time, not to a
bar, so the loop point is where it will show.

## Mostafa

`mostafa/` is the second boss, and he breaks two of Ahmed's assumptions on
purpose. Both are load-bearing, so read them before touching his art.

- **He is drawn FRONT ON.** Every other boss is a profile. A boxer squares up
  to you, and that is the pose. It costs nothing against the side-only rule
  above: the figure is symmetric enough that the `flip_h` the base uses to turn
  him is invisible - only the lit forearm swaps sides, which is what Ahmed's
  does too. No override was needed anywhere; `_face()` and `_apply_animation`
  are untouched and his rows are still named `*_side`.
- **He is drawn at 2x DENSITY.** 70 source rows across 35 world px, where Ahmed
  spends 35 rows on the same 35 px. His cell is therefore `128` in roster.gd
  and his scene halves it back with `scale 0.5` and `offset -48`, so the two
  bosses stand the same height in the room and only Mostafa's pixels are finer.
  The cost is real: his pixels do not line up with the room's at odd window
  scales. It was chosen deliberately, because the style pass that shaped him
  had no range to work in at 1x - a 35px-tall body gives a head-width slider
  four usable steps.

His pieces:

- **`poses.gd` is measurements, not a picture.** Where Ahmed's is body ASCII
  with an arm drawn over it, Mostafa's is thirteen numbers (head, shoulders,
  taper, torso, glove, shorts, legs, boots) plus a per-frame pose: body and
  head offsets, leg offsets, stance, and two arms each given as an elbow and a
  glove. That is what let him be shaped with sliders, and it is why a new frame
  here is six numbers rather than seventy rows. The **vertical stack those
  measurements add up to** lives there too, `BOOT_TOP` up to `HEAD_TOP`, and
  with it `SHOULDER` - the row every pose's `ey`/`gy` is measured down from.
  The painter reads them rather than deriving its own, because the moment a
  second thing draws a glove from pose data there must be one shoulder line
  and not two.
- **`tools/bosses/mostafa.gd` paints from those measurements.** Same seed-once
  contract as Ahmed's. The canvas lands at a FIXED offset in the cell, never
  centred per frame, or the body jitters between frames of a row.
- **Four attacks, but a RHYTHM rather than a menu** (`mostafa.gd`): jab, jab,
  hook, three times through, then `breath_seconds`. The corner rush breaks the
  pattern for a player who kites - and the dash IS its wind-up, with the blow
  on the last running frame, so he connects on arrival rather than swinging
  halfway there. There is no STRIKE phase to hang travel on: enemy_base fires
  the blow at the end of WINDUP and goes straight to RECOVER.
- **Commit is per attack.** `COMMIT` sets `commit_fraction` as each attack
  begins, which is the only way to have uninterruptible jabs and an
  interruptible hook off a base that has one dial.

One consequence worth knowing: the player's grace window is 0.65 s on MEDIUM
and his two jabs are closer together than that, so the second one is often
eaten. That is the crowd dial doing its job, not a bug - but it is why his
test asserts the ORDER he throws in rather than the health that comes off.

### The Bell - his punches, announced

`bell.gd`. Front on, a punch has no sideways travel to read: the jab's whole
animation is the glove growing `gs 5` to `gs 9` and back, four source pixels.
The Bell supplies what the camera angle takes away, and it does it at the scale
of the room rather than on his fist, because the fist is the one part that
cannot move on screen.

It is Ahmed's `axe_fire.gd` contract - a node that reads the sprite's
animation, frame and flip and draws from `poses.gd`, told nothing by anyone -
with one addition: it reads `frame_progress` too, so a chevron crossing the
screen has something smoother than ten frames a second to move on. Time into
the attack is summed from the same `dur` list the boss script derives
`windup_seconds` from, so **no timing moved to fit any of this** and none can
drift.

Three instances of the one script, and **the split is by SPACE**:

- **`BellGround`**, under the body: the floor ring tightening as he loads.
- **`BellBurst`**, over it: the ring and twelve spokes off the glove on impact,
  reaching ~54 px - three times his own height.
- **`BellScreen`**, on a CanvasLayer: the red vignette, the two chevrons that
  cross the screen through the wind-up, the flash, and the rush's speed lines.

That layer is `layer = 1`, which is why **game.tscn now states `layer = 2` on
the HUD**: a flash that washes out his own health bar hides the one number the
player is watching while it lands. The stack, explicit at last, is -1
background, 0 world, 1 his screen effects, 2 HUD, 5 transition, 6 title.

**The screen layer draws at TWO scales and getting this wrong is the whole
trap.** `chunk` is a piece of the frame (`view.x / CHUNK`, ~7 px at 640) and
builds the vignette, the chevrons and the jab's bar: furniture of the frame
sized in world pixels is a nine-pixel arrow on a 640-pixel screen, and it would
change size with the zoom, which is the one thing something pinned to the edge
of the screen must never do. `world` is a world pixel as seen, and places the
things that belong to the ROOM even when they span the frame - where the
chevrons MEET (his chest, 13 world px up) and where the rush's streaks sit.
The mockup this was ported from previewed at a zoom the game does not have, so
every number in it had to be read as one or the other.

Two dials beyond the drawing, both in `mostafa.gd`:

- **`HIT_STOP`** holds the sprite still for 0.08 s on the frame a blow lands
  (the hook gets half again), which is most of what tells a player the attack
  is OVER. It pauses the SPRITE only - `_phase_time` runs on, so the wind-up,
  the recover and the punish window are exactly what poses.gd says. The cost is
  the last 0.08 s of the recover animation being clipped, which is the right
  way round.
- **`SHAKE`** throws the camera, per attack, through `shook` on `boss_base` -
  a capability every boss now has and none has to implement. game.gd connects
  it in `_watch_boss()` beside the bar, and applies it as a camera OFFSET
  quantized to whole world pixels, so `_camera_target()` stays the only thing
  deciding framing and a shaken room does not crawl.

### The Rage - he goes up at 72

`rage.gd`, and `mostafa.gd` decides when. At half health he catches fire, once,
and never comes back down. **72 was already a moment**: his floor cues
`at_boss_health: 72`, so a `call_center` and a `social_media` come in through
the south door on the same frame the fire does.

**One flip, not a ladder**, because DESIGN.md gives the ladder to Khaled and
two bosses making the same argument is one boss too many.

The eruption is 0.95 s and **every beat of the fire is a frame boundary** in
poses.gd - pulses at 0.16 / 0.40 / 0.62, the blast at 0.51. That is not a
coincidence to preserve by hand: `tests/test_rage.gd` asserts it, because
rage.gd fires on fixed seconds while poses.gd decides when frames change, and
retiming a `dur` would slide the fire off the picture with nothing else to warn
you.

What happens, in order: he plants and sinks TWICE, the second deeper than the
first - which is what sells the third as the one that gives - blows a ring out
of the crouch behind a white flash on an already-dark room, and comes up
through his own column with his arms flung open. Then the fire settles: a skirt
at his boots, eight flames orbiting him split front and back about the
ellipse, **both gloves burning**, embers, heat, smoke, and a crimson rim along
his whole silhouette.

Three things worth knowing before touching it:

- **The rim is read off the sheet's own alpha**, cached per cell, so it follows
  any frame he is ever drawn in and costs the art nothing. It is 16k pixel
  reads for a 128px cell: fine once, a framerate every frame, which is why
  `_rims` keeps them.
- **`is_raging` is public and the effect reads it.** Everything else in this
  folder is told nothing and works it out from the sprite, but the fire he
  KEEPS has to outlive the animation that started it - by then the sprite is
  back on `idle_side` and has nothing left to say.
- **He does not get stronger.** Not one number moved: 24 / 17 / 36 and the
  heavy's 24 are exact combo breakpoints. If the rage should bite as well as
  burn, the cheapest honest lever is `breath_seconds` - the combination he
  taught you, arriving with less room to answer it.

While it runs he is rooted, throws nothing, and cannot be staggered -
`_can_advance`, `_advance_phase` and `_interruptible` all defer to
`_erupting()` - but damage still lands, so the 0.95 s is a free window and the
reward for being close. The blast holds his sprite for 0.12 s and emits
`shook` at 6 px, harder than any punch he throws.

### brush.gd, and the second fire in the game

`bell.gd` and `rage.gd` share `brush.gd`: the boss and sprite lookup, `part`,
the anim clock, and the pixel and flame kit.

Ahmed keeps his own copy of most of those shapes inside `axe_fire.gd`, and that
stays deliberate. Nothing about the ART is shared between bosses, and a flame is
art: the shapes here are the same as his, because one game should have one
fire, but **the ramp is the whole point of drawing it twice** - Ahmed is yellow
and amber, fuel burning on an axe; Mostafa is crimson and white, a body
overheating. Nobody should have to check which boss they are fighting. A third
consumer is the moment these bubble up to `game/bosses/` as a kit taking a
ramp, and not before.

### His sheet grew a row

`ORDER` is now idle, walk, jab, hook, rush, **rage**, concede - seven rows, and
`src/mostafa.png` was re-seeded to get it. That was free, and the reason is
worth keeping: his PNG was still **exactly what the painter paints**, verified
by repainting and diffing all 896x768 before deleting it. Every old row came
back byte-identical and the concede moved down a row intact.

That is the seed-once contract working as intended rather than being bent: the
moment anyone hand-draws into that PNG, adding a row costs a redraw instead of
a rebuild.

## Silverman

`silverman/` is the third boss and the last man in the building. He breaks the
other two the same way they broke each other, and the break is the whole
character: **his body never changes shape.**

- **One picture, moved around.** Ahmed's poses are an arm and an axe swung
  about a torso; Mostafa's are thirteen measurements restruck per frame.
  Silverman's are one block of ASCII and two numbers per frame - `dy`, how
  high he is floating, and `dull`, how many steps down the ramp he is painted.
  There is no scale, no lean, no clip and no leg variant anywhere in his
  `poses.gd`. A deforming version was drawn, looked at and dropped: a liquid
  that stretches while it travels reads as a cartoon, and this one is the
  final boss.
- **He does not walk, and he has no melee.** `walk_side` is the hover taken
  faster, because gliding is all the travel he has. He owns four things and not
  one of them is thrown with a hand: he crosses through you, blinds you,
  divides, and freezes the air near him. A player standing on him is answered
  by the glare, whose band starts inside its own reach.
- **His telegraph is DRAWN, and it can only ever dim him.** His idle already
  rests at `dull 0`, the brightest rung he has, so there is nowhere to go but
  darker on the way to a blow: an attack row takes two rungs out of him and
  spends the lot on the impact frame, where he snaps back to full. That is also
  why `silverman.gd` overrides `_windup_tint()` to plain white - the base fades
  a winding enemy towards amber, and a multiply on a body of six exact
  greyscale values lands between two rungs of the only thing he is made of.
- **1x, like Ahmed.** Cell 64, sprite unscaled, offset -24. He was drawn,
  shown and picked at 35 rows, and the approved picture is the spec -
  redrawing him at Mostafa's density to gain ramp headroom would be shipping a
  different character. He needs it least of the three anyway: every frame of
  every row is the same pixels at a different height.
- **His toes end on row 32.** The two empty rows under them are the hover, and
  they are why he never looks like he has landed. The concede spends them: he
  settles the two pixels onto the floor he has never touched, and the shine
  goes out of him on the way down. Losing flight IS the defeat. Then `beaten`
  loops two dull levels slowly, so what is left in the room is a statue still
  cooling rather than a statue.

### The dash, and why it is one frame

His one piece of real locomotion. `DASH` in `silverman.gd` is a **position
curve** - six beats over half a second, out to 72 px - and that is all it is.
The sprite holds `dash_side`'s single frame for the whole crossing.

That single frame is the consequence of the rule above, and it is worth
stating because it looks like a mistake otherwise: if the body never changes,
the sheet has nothing to hold but one pose, so the travel is the boss moving
under an unchanging sprite and the speed is drawn by `smear.gd`. The trail can
be retuned later without repainting anything.

**The smear is seven copies six pixels apart**, each a step down the ramp and
fading back, so they overlap into one continuous length of metal with the real
Silverman at the bright end. Six apart rather than fourteen is what makes it a
smear instead of three afterimages: at that spacing the eye gets a band rather
than a count.

`ghost` is a sheet row the boss **never plays**. It holds the dash pose painted
one step down the ramp, and `smear.gd` pulls its texture straight out of the
SpriteFrames. The alternative was dulling a live copy with a modulate, which is
a multiply and lands between two rungs; a boss whose whole look is six exact
values does not get to approximate one of them. A picture the effect needs is a
picture, so it lives on the sheet.

Three beats of the six are travel - `moving` - and the first and last two are
the coil and the arrival: three pixels back before he goes, two past the mark
on the way in. That is the only anticipation he has, and it is position, so his
shape is still never touched. The trail draws on the travel beats only.

The cue is **distance alone**, and `dash_range` is the number that matters.
`_can_advance()` is false while crossing, or the base's own walking fights the
curve, and the dash drives `velocity` rather than assigning position so the
arena's walls still stop him.

It is now **locomotion that hurts** - the pass-through - and converting it cost
exactly what this file promised: `hit` on the three travel beats, a flag to keep
it to one blow, and nothing else moved. Two things had to be fixed to make it
true, and both are the kind that only surface once a gap-closer starts dealing
damage:

- **`dash_range` came down from 96 to 40.** He triggered at 96 and travels 72,
  so he always stopped 24 px short and could never once pass through anybody. A
  gap-closer may stop short; a blow may not. At 40 the bands are: inside 40 he
  glares, 40 to ~86 he crosses THROUGH you, and past that he crosses and lands
  short - which is the old locomotion, still doing its old job.
- **He needs a collision exception to pass through at all.** Two solid bodies do
  not interpenetrate, so his own `move_and_slide()` hit the player and halted
  him 11 px out: the pass-through was a boss walking into you and stopping.
  `add_collision_exception_with()` on the one body he is crossing, dropped on
  arrival and on a concede mid-flight - an exception rather than a collision
  mask precisely because the walls must still stop him.

The sprite is switched to `dash` in `_consider_dash` rather than waiting for the
next `_dash_step`, or he spends one frame crossing the room in his idle pose.

### The fight: a ladder, not a menu and not a rhythm

Ahmed is a menu (the attack suits the range) and Mostafa is a rhythm (jab, jab,
hook). Silverman had to be a third thing or the last fight in the building is
one you have already had twice, so he is **cumulative**: three phases, each
ADDING a mechanic and removing nothing, the interrupt window narrowing on every
step. The fight gets more crowded rather than faster, which is the only
escalation available to a man who never hurries.

`tier()` is the phase, taken off fractions of his own max health rather than the
literal 128 and 64, so retuning his HP in the scene moves the phases with it:

| phase | HP | adds | interrupts |
|---|---|---|---|
| The Handshake | 192-128 | the crossing, the glare | standard (`commit` 0.65) |
| The Meeting | 128-64 | the split | one, then 3 s (`commit` 0.40) |
| The Performance Review | 64-0 | the cold room | none (`commit` 0.0) |

`COMMIT` and `LOCKOUT` are set per phase as each attack begins, because the base
has one dial for each and that is the only place they can narrow over a fight -
Mostafa's per-attack trick, applied per phase instead. **`commit_fraction` 0.0
is never interruptible, not always**: `_interruptible()` asks whether the
wind-up's progress is still BELOW it, so a lower number is a more committed
boss, and 0.0 is DESIGN.md's "fully uninterruptible" with no special case
anywhere to make it so.

A phase is announced by `herald`, a countdown glare.gd draws as two pulses of
the room. He has no cuffs to adjust, so what he spends on the announcement is a
rung of his own shine. Crossing a threshold also clears both attack cooldowns,
so an escalation ARRIVES rather than being something you notice a few seconds
later.

**The four attacks, and what each is made of:**

- **the glare** (16, 0.80/0.70) - the room whites out and a 20 px lane of it
  crosses the floor, travelling through his recover on Ahmed's wave contract.
  You step out of its line; you cannot outrun it. `glare.gd`, two parts split by
  SPACE like the Bell: `band` under the body in world pixels, `screen` on a
  CanvasLayer at layer 1 in viewport pixels. **The band draws exactly the
  hitbox** - its front is the boss's own `glare_front()`, the same function
  `_glare_reach()` moves the Area2D to, because a sweep you are asked to step
  out of has to be a sweep whose edges you can see.
- **the split** (12, 0.60 wind-up) - he divides, and the copy walks at you while
  he stands still. `copy.gd` draws the `ghost` row - the dulled body already on
  the sheet for the smear - so a copy of him is a copy of him by construction
  and costs **no art at all**. It is deliberately not an add: no group, no
  health, no bar, no collision, gone in 1.8 s. A boss floor's real adds arrive
  on `at_boss_health`, and two systems that put fighters in a room is one too
  many, so this one puts a THREAT in the room instead.
- **the cold room** (3.0/s inside r 34, third phase only) - an aura, not an
  attack, on the wraith's `drain()` path: it knows its own rate, and the grace
  window neither blocks it nor is opened by it. `chill.gd` draws the EDGE
  brightest, at exactly the radius the drain uses, because an aura with no
  telegraph is only fair if you can see how far it reaches.
- **the crossing** (18) - above.

**Every reach he owns points along x, so he had to be given one that does
not.** The band is a 20 px lane through his chest, the crossing only travels
along x, and the split will not fire closer than 34 - so a player standing
directly north or south of him at arm's length was missed by the lane on BOTH
axes, slid past by the crossing, and not worth a split. Phases one and two
landed nothing at all on them, and the last fight in the game was free to
anyone who hugged him. `_flash_at_source()` is the answer: the glare bursts off
HIM before it sets out and catches anyone inside `Touch` whatever line they
stand on, sharing `_glare_hit` with the band so one glare cannot hit twice. It
needed no new number and no new shape, and standing in the source of the glare
being the worst place to be is the obvious reading of it. `tests/test_silverman.gd`
opens with that case, because it is the one a placement can never reveal.

Nothing about the ladder lives in the effects. `chill.gd` asks him `tier()`,
`glare.gd` reads `herald`, and both walk up to the `bosses` group to find him
the way `brush.gd` does - so an effect on a CanvasLayer is as able to reach him
as one under the body, and neither is told anything.

**Placed: floor 12, the penthouse**, at (272, 140) - the centre line, 100 px
north of where you walk in and inside his 130 sight, so he has seen you before
you have taken a step. x is `DOOR_CENTRE_X` and that is the load-bearing half:
his glare sweeps 140 px along x and his crossing travels 72 along x, so he is
the one boss whose attacks need the room's WIDTH, and centred is the only
placement that gives him all of it both ways.

**He is the one boss floor with no door to lock.** Every other shuts its north
door until the boss concedes; the penthouse is the end of the chain, so
build_levels.gd cuts nothing through that wall and the boss-door swap has
nothing to swap. Beating him opens no floor - what follows is the ending.

His floor's beat was authored before he existed, against an assumed 192 HP, and
192 is what he opens at - so its thresholds (144 / 96 / 48) are confirmed rather
than guessed. They also sit deliberately OFF his phase boundaries (128 and 64):
one thing to read at a time was the whole argument for the arena being empty,
and it applies just as much to two clocks running on the same health bar.

The open question is no longer where he stands but who he is: DESIGN.md's final boss is KHALED on F10, and whether Silverman
is a rename of him, a second boss above him or what he turns into is an open
decision that changes a biome entry and the ending, not the art.

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

There is deliberately no step for the HUD bar: he is in the `bosses` group and
over `boss_base.gd`, which is all game.gd looks for. See The bar.

## Still to build

Mostafa's concede is a single placeholder frame - the animation DESIGN.md
describes (gloves off, a nod, a point at the ceiling) was drawn and rejected in
review. `boss_base.gd` plays `concede_side` at zero health so the row has to
exist; replacing it is adding frames to his poses.gd and nothing else.

Ahmed's concede is done: he lets go of the axe. He straightens up one last
time, his fingers open, the axe drops and lands flat, and the fire goes out the
moment it leaves his hand - the painter draws the axe wherever its descriptor
says regardless of where the arm is, so a dropped axe costs nothing but a hand
that stopped following it. With nothing left to hold, the far arm comes into
view and both hands end on his thighs. Then `beaten` loops the breath for the
rest of the run, which is the point of the whole thing: every other option on
the table left a statue in the room. It is a kneel rather than the enormous
chair.

DESIGN.md's Ahmed also yells "SECURITY!" at 64 and 32 HP and summons an office
boy through the door (cap 2). The slam already knows what to do with them.
