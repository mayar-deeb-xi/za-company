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

## Ahmed's sound effects
- Author: **generated with ElevenLabs** (text-to-sound-effects), then trimmed,
  summed to mono, levelled and loop-sealed by hand
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0 like everything above, which is why they are listed separately
- Files: `game/bosses/ahmed/sfx/*.wav` - the burning axe's idle loop, his hurt
  grunt, the stagger that says an interrupt landed, the axe hitting the floor
  as he concedes, and the breathing he is left with
- The untouched ElevenLabs exports are kept in `game/bosses/ahmed/src/`
  beside his sheet, on the same terms as `assets/music/src/` and every other
  `src/` here: the original is hand-owned and never played, the file above it
  is what the game loads. Re-trimming one therefore costs no credits.
- What the game plays is 48 kHz mono 16-bit WAV, levelled against each other
  rather than all normalised to full scale: the idle fire sits at -14 dBFS because it
  plays for the whole fight, and the one-shots sit near -4 so a hit reads over
  it. Re-generating one means re-levelling it to match, not just dropping the
  new file in.

## Music
- Author: **generated with ElevenLabs** (text-to-music)
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0 like the art above, on the same footing as the sound effects
- Files: `assets/music/menu_loop.wav` (the front end) and
  `assets/music/ahmed_theme_loop.wav` (Ahmed's fight, floor 4)
- These live in `assets/` rather than in the feature that plays them, which is
  the one place that rule bends: `menu_loop` is asked for by three front-end
  screens and belongs to none of them, and keeping the two tracks in one folder
  is what makes them levellable against each other at a glance. Who plays a
  track is said on the boss instead - see game/bosses/CLAUDE.md.
- 48 kHz 16-bit stereo, and deliberately stereo where the sound effects are
  mono: an effect is positional and pans with the room, a track is not standing
  anywhere. Both are trimmed by `Music.VOLUME_DB` (-8) rather than normalised,
  and Ahmed's sits ~1.5 dB hotter than the menu's at source, which is the right
  direction - a fight should be more present than a menu bed.
- Untouched exports go in `assets/music/src/` on the same terms as every other
  `src/` here. `menu_loop` has one; `ahmed_theme_loop` is currently played as
  it came out of the generator, so re-trimming its loop seam means keeping a
  copy there first.
