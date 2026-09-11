# Third-party assets

## Top-down character, dungeon tileset, jar
- Author: **profpatonildo**
- Source: https://opengameart.org/content/pixel-art-top-down-dungeon-tileset-and-rpg-character-with-animations
- License: **CC0 1.0 Universal** (public domain) - no attribution required, commercial use permitted
- Files: `game/player/src/character_cc0.png`, `game/enemies/src/body_cc0.png`
  (an identical frozen copy of it), `assets/tiles/dungeon.png`,
  `assets/props/jar/jar.png`
- Editable Aseprite sources kept alongside in `game/player/src/`, `assets/props/jar/src/` and `assets/tiles/src/`
- Every playable character (`game/player/characters/*_frames.tres`) is a
  **restyle** of that sheet, not the original: recoloured hair, skin, eyes and
  clothes per character. `tools/build_characters.gd` regenerates them from
  `game/player/src/character_cc0.png`, which is the cast's working sheet and
  will grow animations over time.
- Every enemy sheet (`game/enemies/<id>/src/<id>.png`) was **seeded** as a
  restyle of `game/enemies/src/body_cc0.png` - a byte-identical, deliberately
  frozen copy of the same CC0 sheet - and is hand-owned art from then on. The
  copy exists so that seeding stays reproducible while the cast's sheet changes
  underneath it. Both are CC0, so copying and restyling is unrestricted.
- The marble and hellfire tilesets are derived from `dungeon.png`: floor and
  wall tiles are palette-swapped copies of it (see `tools/build_biomes.gd`).
  CC0 permits this without restriction. The columns and door arches in those
  same files are original work, not derived from the sheet.
- Every office floor's tileset is derived the same way. Everything else in
  those rooms is original work with no third-party source: the glazed pillar,
  the cubicle divider, and the four office hazards - the sparking floor
  polisher, the arcing power strip, the fallen ring light and the jammed
  copier (`tools/props/fixtures/`) - plus the office furniture, the
  maintenance floor's hardware and junk, the call floor's phones and its lit
  wallboard, the media team's glass partitioning, edit bays, ring lights and
  paper backdrop, the gym's punch bags, weight racks and the boxing ring
  painted on its floor, the innovation lab's workstations, coffee machine,
  whiteboard diagram and build board, the executive floor's awards cabinets,
  boardroom table, drinks trolley, founder's portrait and rug, the penthouse's
  city window, its one bare desk and the note lying face down on it, the signs
  and the neon, and the 5x5 pixel font (`tools/props/`) - all drawn in code,
  since the dungeon sheet has no furniture or hardware in it to derive from.
- `game/enemies/office_boy/src/office_boy.png` was seeded as a restyle of the
  frozen CC0 body like every other enemy sheet, and is hand-owned from now on.
- `game/npcs/dominique/src/dominique.png` and `game/npcs/ivan/src/ivan.png`
  were seeded from the same CC0 cast sheet and then rebuilt at double height
  in a robe by `tools/npc_art.gd` - the robe, the hem, the waist cord and the
  doubled head are drawn in code, not sampled from anything. 64px cells, and
  hand-owned art from the moment they were written.

Credited voluntarily; CC0 imposes no obligation to do so.

## UI fonts
- Author: **Kenney** (https://kenney.nl)
- Source: https://kenney.nl/assets/kenney-fonts
- License: **CC0 1.0 Universal** - "free to use in personal, educational and
  commercial projects", crediting requested but explicitly not mandatory
- Files: `assets/fonts/KenneyBlocks.ttf` (titles), `assets/fonts/KenneyMiniSquare.ttf` (UI),
  plus `KenneyPixel.ttf` and `KenneyFutureNarrow.ttf` kept as alternatives

## Ahmed's and Mostafa's sound effects
- Author: **generated with ElevenLabs** (text-to-sound-effects), then trimmed,
  summed to mono, levelled and loop-sealed by hand
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0 like everything above, which is why they are listed separately
- Files: `game/bosses/mostafa/sfx/*.wav` - eleven: a telegraph and an impact
  for each of jab, hook and rush, the `rage` eruption, the `fire` loop he wears
  from half health on, and his hurt/stagger/concede. And
  `game/bosses/ahmed/sfx/*.wav` - the burning axe's idle loop, his hurt
  grunt, the stagger that says an interrupt landed, the axe hitting the floor
  as he concedes, and the breathing he is left with; plus the eight attack
  sounds, a `<attack>_windup` telegraph and a `<attack>_hit` impact for each of
  chop, sweep, slam and wave
- Mostafa's twenty-two voice lines are Eleven v3 text-to-speech (voice
  "Edward"), cut by `tools/voice/cut.py mostafa`; Ahmed's twenty-three are the
  same pipeline on voice "Jack". Both are delivery-tagged per cue rather than
  steered by a stability slider - the tags live in `tools/voice/<boss>.py`
  beside the rest of the recipe, and what each boss SAYS lives with him in
  `taunts.gd`
- The eight were generated through the Sound Effects API rather than the web
  app (`POST /v1/sound-generation`, `output_format=pcm_48000`), which is worth
  knowing for the next batch: it returns raw STEREO 16-bit PCM with no WAV
  header and no leading padding, so the header is written by hand, the two
  channels are summed to mono, and only the dead TAIL needs trimming. The
  prompts, durations and levelling are `tools/`-free on purpose - they live in
  the scratchpad script that made them, and the files below are the artefact
- The untouched ElevenLabs exports are kept in `game/bosses/ahmed/src/`
  beside his sheet, on the same terms as `assets/music/src/` and every other
  `src/` here: the original is hand-owned and never played, the file above it
  is what the game loads. Re-trimming one therefore costs no credits.
- What the game plays is 48 kHz mono 16-bit WAV, levelled against each other
  rather than all normalised to full scale: the idle fire sits at -14 dBFS because it
  plays for the whole fight, and the one-shots sit near -4 so a hit reads over
  it. Re-generating one means re-levelling it to match, not just dropping the
  new file in.
- The attack sounds keep that rule and add one of their own: impacts join the
  one-shots at -4 dBFS, and **telegraphs sit at -9**. A wind-up as loud as the
  blow it warns about has stopped being a warning. Each telegraph is also
  shorter than the wind-up it plays under - the tightest is `sweep_windup` at
  0.48 s against a 0.52 s wind-up - so a swing never lands while its own
  warning is still going.

## The enemies' sound effects
- Author: **generated with ElevenLabs** (text-to-sound-effects), then trimmed,
  summed to mono, levelled and loop-sealed by `tools/sfx/make.py`
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0 like the art above, on the same footing as the bosses' sounds
- Files: `game/enemies/<id>/sfx/*.wav` - twenty-six across six enemies. The
  four that run the attack cycle (`regular`, `office_boy`, `warden`,
  `call_center`) get five each - `windup`, `hit`, `hurt`, `stagger`, `die`;
  the two drainers (`wraith`, `social_media`) get three - `drain`, `hurt`,
  `die` - because they opt out of the cycle and so have no wind-up to
  telegraph, no blow to land and nothing to stagger
- **Every enemy has its own**, including each reskin, on the same terms as its
  sheet: `office_boy` is mechanically the regular to the frame and sounds
  nothing like it, because he thrusts a wrench where the guard swings a sword
- **The recipe is in the repo**, which the bosses' sound effects above are the
  one exception to: `tools/sfx/` holds the mechanism (`make.py`, plus the
  audio kit in `wav.py`) and the prompts, durations and levels
  (`enemies.py`). Re-generating one is one command; re-SHAPING one is
  `--relevel` and costs nothing
- The untouched exports are kept in `game/enemies/<id>/src/sfx/`, on the same
  terms as `assets/music/src/` and every other `src/` here: the original is
  hand-owned and never played, the file above it is what the game loads.
  Re-trimming therefore costs no credits
- What the game plays is 48 kHz mono 16-bit WAV, levelled against each other
  AND against the bosses rather than normalised to full scale. A boss floor
  holds one boss; hellfire holds four guards, two wraiths and a warden, so the
  enemies sit under him: impacts at -22 dBFS RMS against his -19, telegraphs
  at -29 (7 dB under their own impact, his ratio), grunts at -24, deaths at
  -22, and the wraith's continuous drain loop at -30. Re-generating one means
  re-levelling it to match, not just dropping the new file in
- Peaks are held under -3 dBFS by a soft limiter (tanh at the ceiling) rather
  than a gain cut, which is the lesson Ahmed's slam paid for: pulling a whole
  sound down so its tallest transient fits is what holds an impact under
  target in the first place
- The two `drain` loops are the only looping files here, and each was
  generated at 8 s so the steadiest 2.5 s could be CHOSEN out of it, then
  crossfaded 12 ms tail-over-head. Both fixes are needed and neither is
  visible without the other: the model writes a beginning and an end even when
  asked not to, and a raw export ends mid-waveform and clicks once per pass

## Ahmed's voice
- Author: **generated with ElevenLabs** (text-to-speech, Eleven v3), then
  trimmed and levelled by `tools/voice/cut.py`
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0, on the same footing as the sound effects above. A synthetic
  voice also carries the terms of the VOICE used, which is a separate question
  from the audio: this one is `EtsjFhqOd0YWASYxlmIg`, and it is not a voice on
  the account's own list, so check its licence before the game ships.
- Files: `game/bosses/ahmed/sfx/voice/*.wav` - twenty-three lines, one per
  thing he says in `game/bosses/ahmed/taunts.gd`, named `<cue>_<n>.wav`
- **The recipe is in the repo**, unlike the sound effects above: `tools/voice/`
  holds the mechanism (`cut.py`) and Ahmed's own direction (`ahmed.py`, a
  delivery tag per cue). Re-cutting a reworded line is one command. Two clips
  are pinned in that file as approved takes and are never re-cut, because
  text-to-speech is not deterministic and re-running would quietly ship a
  performance nobody chose.
- Same format as his grunts - 48 kHz mono 16-bit - fetched as
  `output_format=pcm_48000` and given a WAV header directly, so there is no MP3
  stage and no encoder to install. Levelled on the **75th percentile of speech**
  rather than on peaks, to -19 dBFS, which is where his grunts already sit; peak
  matching had left a roar and a mutter 13 dB apart in the only thing anybody
  hears.
- `cut.py --verify` transcribes every clip back and compares it to the line it
  was cut from, which is the one check that catches a delivery tag being read
  ALOUD instead of acted on - inaudible in a waveform, obvious in a fight.

## HR's voice
- Author: **generated with ElevenLabs** (text-to-speech, Eleven v3), then
  trimmed and levelled by `tools/voice/cut.py`, exactly as Ahmed's are
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0, on the same footing as every other generated sound here. The
  VOICE carries its own terms separately from the audio: this one is
  `ogwqBH5bbF03DSbNiRNN`, and its licence wants checking before the game ships.
- Files: `game/npcs/hr_lady/sfx/voice/*.wav` - twenty-three clips for the
  twenty-four lines she speaks in `game/npcs/hr_lady/welcome.gd`. The
  twenty-fourth is not missing: her first and third refusals are the same five
  words, and they deliberately share one recording, because a woman repeating
  herself in the *identical* take is the joke that two performances of it would
  soften.
- **Named by the beat, not by a number.** Ahmed's clips are `<cue>_<n>.wav`,
  derived from the fight. Hers are read back out of the `voice` path each beat
  already carries for the game to load, so writing a new line into the middle
  of the induction does not renumber - or re-bill - the twenty after it.
- Only HR is voiced. The contract branch has the player answering her, and
  those beats carry no clip on purpose: the player is silent everywhere else in
  this game.
- Ten delivery tags across the twenty-three, shared the way Ahmed's swings
  share one read, and the arc is the content: bright through the tour, sweetly
  insistent through the first refusals, and flat by the third. Her whole joke is
  that the menace is never in the words, so it has to be in the read.
- Levelled to -19 dBFS on the 75th percentile of speech, the same number Ahmed
  sits at - one figure across every mouth in the game, since a file's own level
  IS the mix here and there is no bus layout.
- `cut.py --verify` is green on all twenty-three. Four `SPELLINGS` entries are
  needed to keep it that way and none of them is a bad take: scribe writes
  "8:59" back as three words and "Eleven" as digits, and it is not deterministic
  either - the same clip read back clean on one pass and showed a homophone
  ("council" for "counsel") on the next. Transcribing a take twice and getting
  two answers is the give-away that the difference is in the listener.

## Music
- Author: **generated with ElevenLabs** (text-to-music)
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0 like the art above, on the same footing as the sound effects
- Files: `assets/music/menu_loop.wav` (the front end),
  `assets/music/level_loop.wav` (the bed under every floor without a boss on
  it - see below), `assets/music/ahmed_theme_loop.wav` (Ahmed's fight, floor 4)
  and `assets/music/mostafa_theme_loop.wav` (Mostafa's, the gym on floor 7 -
  industrial cyberpunk techno at 120 BPM, which is a beat every 30 frames and
  therefore his 0.25 s jab on the grid rather than drifting against it)
- These live in `assets/` rather than in the feature that plays them, which is
  the one place that rule bends: `menu_loop` is asked for by three front-end
  screens and belongs to none of them, and keeping the tracks in one folder
  is what makes them levellable against each other at a glance. Who plays a
  track is said on the boss instead - see game/bosses/CLAUDE.md.
- 48 kHz 16-bit stereo, and deliberately stereo where the sound effects are
  mono: an effect is positional and pans with the room, a track is not standing
  anywhere. All three are trimmed by `Music.VOLUME_DB` (-8) rather than
  normalised, and Ahmed's sits ~1.5 dB hotter than the menu's at source, which
  is the right direction - a fight should be more present than a menu bed.
  **A boss theme is levelled against his own sounds, not against the other
  theme**, and Mostafa is where that was learned. Matching Ahmed's RMS came
  first (-1.7 dB, since his export landed that much hotter) and it was the
  wrong target: broadband loudness says nothing about MASKING, which is per
  band. Measured in octave bands at playing level, his eruption `rage.wav`
  cleared the bed by 3.9 dB at best and his `fire` loop by 0.1, because both
  live under 250 Hz and that is exactly where a techno track keeps its kick
  (60-125 Hz sits 17 dB above its own mids). Ahmed's quietest sound clears his
  theme by 2.3 dB, so that is the floor this was levelled to: a further -3 dB,
  i.e. **-4.67 dB flat from the export**, which puts every one of Mostafa's
  eleven sounds at least 3.1 dB over the bed in some band, with the hook - the
  one read in the fight - at 20.5. He therefore sits 3 dB under Ahmed at
  -16.1 dBFS RMS, peak -5.2, and that is the number doing a job rather than a
  mismatch.
- **`level_loop.wav` is the bed, and it is levelled as one.** Cyberpunk
  sequencer ambience at 120 BPM - the same grid as Mostafa's, so it is a beat
  every 30 frames here too. At source it is the quietest of the four by some
  way: -19.37 dBFS RMS, which is 4.7 dB under the menu, 6.1 under Ahmed and
  3.1 under Mostafa. That gap is the point rather than an accident, and it is
  doing two jobs. It is the escalation - walking onto a boss floor has to read
  as the music getting bigger - and it is the headroom, because this is the
  track that will still be playing when ordinary floors finally get sound
  effects of their own. There is now one thing to measure it against, and it is
  the loudest thing an ordinary floor is ever likely to carry: **HR's voice**,
  in the lobby, at -19 dBFS speech level. That is 0.4 dB over this track's own
  RMS, so a line of hers and this bed are within half a decibel of each other -
  which is exactly the case the masking arithmetic above was written for, and
  the first place to listen if her induction ever sounds like it is competing
  with the room rather than being said in it.
- Untouched exports go in `assets/music/src/` on the same terms as every other
  `src/` here. `menu_loop`, `mostafa_theme_loop` and `level_loop` have one;
  `ahmed_theme_loop` is currently played as it came out of the generator, so
  re-trimming its loop seam means keeping a copy there first.
- **`level_loop` needed the cut before it could take the crossfade at all.**
  Its export ends: the last 3.75 s fades away to -83 dBFS while the head starts
  cold at full level, so as a loop it died once a minute rather than clicking.
  The music is intact to 56.25 s, so it is cut to **56.000 s - 28 bars at
  120 BPM**, the last whole bar that fits, and 12 ms of what is left over is
  crossfaded back over the head. The seam step goes from 2547/1722 to 36/92
  against a median body step of 33, i.e. from audible to indistinguishable from
  the music's own motion. 2,688,000 frames, and 3360 at 60 fps.
- **Mostafa's loop is sealed, Ahmed's is not**, and the numbers say why it
  matters: the step across the loop point was 9139 against a median
  sample-to-sample step of 591 in the body, i.e. a tick once a minute, and a
  12 ms equal-power crossfade of the tail over the head takes it to 19 for
  0.012 s of length. Ahmed's seam is 10413 against a body step of 125 and is
  the louder of the two - a known debt, and the same fix when it is paid.
