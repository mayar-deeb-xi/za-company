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
| `office_boy`  | regular (guard)  | 24 | polo + serving tray; wind-up = raising the tray |
| `social_media`| wraith           | 17 | phone glow, ring-light white while draining; faint floating "+1" tick |
| `call_center` | warden           | 36 | headset; charge ring reads as a spreading "on hold" circle |

HP stays on combo breakpoints (4 / 3 / 6 hits) — difficulty never scales HP.

## NPCs — two new small systems

- **Dominic** (guide, front desk): a talking signpost. New `npc_base.gd` +
  one-line dialogue box (`ui/dialogue/`): proximity trigger, one line per
  visit, advance with the attack key. No branching, no quest log. Placed on
  floors 1, 3, 6, 8.
- **Ivan** (healer, cafeteria): stands in a safe corner, lobs a heart in a
  short tween arc every ~10s. Spawns the existing `pickup_base.gd` heart;
  max ONE of his hearts on the floor at a time (lifeline, not fountain). Heart
  is live when it lands. Only line: "Eat." Present on floors 2, 3, 5, 6, 7, 8.

Both are friendly: no `player`-group targeting of them, enemies ignore them.

## Floors — 8 levels, one per CHAIN entry

Elevator is out of order. South door = down, north door = up. Boss floors lock
the north door until the boss falls (`can_travel()` override). Existing
placement rules apply everywhere: no enemy's sight reaches the door line, the
spawns, or the torch/heart stands; the straight door-to-door walk stays safe.

Each floor announces itself by name for three seconds on arrival, so every
biome entry needs a `title` - the floor name in caps, as listed below (e.g.
"THE BULLPEN"). Floor numbers are deliberately not in the card: the card names
the room, and the fiction carries which floor it is.

- [x] **F1 The Lobby** (tutorial): glass-and-steel reception, cool blue-grey
  marble, over-lit. Now `CHAIN[0]` and `game.gd`'s `START_LEVEL`: a run begins
  here. Built: biome palette, tileset, columns, torch, heart, north door to the
  marble hall, and the room deliberately empty of enemies - floor 1 is where a
  new player learns to walk, safely, and test_flow asserts it stays empty.
  Still to dress (needs art, not data): reception desk, dead plant, "WELCOME
  NEW HIRES" banner hanging by one corner, and the torch reskinned as the
  sparking floor polisher. Dominic + the 2 office boys land with steps 2-3.
- [ ] **F2 The Bullpen** (crowd): open-plan desks, dividers as columns.
  4 office boys, one per corner (pullable one at a time). Teaches the heavy.
  Ivan debuts (west wall). Hazard: arcing power strip.
- [ ] **F3 Ahmed's Corner Office** (BOSS): oversized office, golf putter,
  framed family photo. Small arena, no adds at rest. Ivan + Dominic.
- [ ] **F4 The Content Studio** (drain): dark room + neon, ring lights,
  "LIVE LAUGH ENGAGE" wall. 3 social_media with overlapping sight radii
  (routing level — standing central costs 6-9 HP/s), 1 office boy by the exit
  forcing one fight inside the field. Hazard: scalding ring light on a fallen
  tripod.
- [ ] **F5 The Call Center** (denial): cubicle maze, densest columns.
  2 call_center planted at chokepoints, 3 office boys between them. The
  lesson: a slow near guards is lethal. Ivan. Hazard: jammed photocopier.
- [ ] **F6 Conflict Resolution** (BOSS): company gym, boxing ring painted on
  the floor, poster: "TALK IT OUT" crossed out, "GLOVE IT OUT" under it.
  Tight arena, no columns. Mostafa. Ivan.
- [ ] **F7 The Executive Floor** (mix/exam): dark wood, glass walls, awards
  cabinet. 3 office boys + 2 social_media + 1 call_center (center chokepoint).
  Every prize requires stepping into a radius on purpose. Ivan.
- [ ] **F8 Khaled's Office** (FINAL): penthouse, city window, one desk, one
  face-down sticky note. Wide open arena. South door seals behind you.
  Dominic waits outside ("Whatever happens up there… CC me."). Ivan.

## Bosses — overrides on enemy_base.gd's cycle, built in this order

HP values are exact combo breakpoints (5/7 alternating) AND multiples of the
heavy's 24. Difficulty scales their damage only, never HP. All three concede
instead of dying (no queue_free): defeat -> concede animation -> north door
unlocks.

- [ ] **AHMED — 96 HP, F3.** The relative; teaching boss. Guard swing cycle,
  slightly faster recover, 14 damage. At 64 and 32 HP yells "SECURITY!" and
  summons 1 office boy through the door (cap 2 alive). Standard interrupt
  economy. Defeated: sits in his enormous chair — "I'm telling Mostafa."
- [ ] **MOSTAFA — 144 HP, F6.** Boxing rhythm fight; his attack is the cycle
  run 3x back-to-back:
  - Jab, jab: 0.25s wind-ups, 6 dmg each, commit_fraction ~1.0
    (effectively uninterruptible; they're swings — step out, they whiff).
  - Hook: 0.7s wind-up, 18 dmg, interruptible early. The one read.
  - Corner rush: dash gap-closer if the player kites to the ring edge.
  - Defeated: takes the gloves off, nods once, points at the ceiling.
- [ ] **KHALED — 192 HP, F8.** Smooth = never hurries; each phase announced by
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

- [ ] 1. Floors as biomes: 8 entries in `tools/biomes.gd` (office palettes),
        run build_biomes + build_levels, dress rooms by hand. Per-floor enemy
        placement is per-biome data as today. **F1 lobby done** (1/8); the
        chain is currently lobby -> marble_hall -> hellfire, with the two demo
        biomes still on the end until the office floors replace them.
        Regenerate one floor at a time: `build_levels.gd -- <level>`.
- [ ] 2. Reskin enemies: office_boy / social_media / call_center roster
        entries seeded from the frozen body; run build_enemies.
- [ ] 3. Dialogue + Dominic: npc_base.gd, ui/dialogue/, lines as instance data.
- [ ] 4. Ivan: heart-throwing NPC on cooldown.
- [ ] 5. Boss plumbing: locked north door, boss HP bar on HUD,
        defeat -> concede -> unlock sequence.
- [ ] 6. Bosses in order Ahmed -> Mostafa -> Khaled (each adds one idea:
        summons; multi-hit rhythm; phases).
- [ ] 7. Ending: sticky-note screen, discount code constant, credits.
- [ ] 8. Tests: new `tests/test_bosses.gd` suite (one suite = one world);
        extend test_flow with the locked-door case.
