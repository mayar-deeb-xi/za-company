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
  painted on its floor, the dev floor's workstations, coffee machine,
  whiteboard diagram and build board, the signs and the neon, and the 5x5
  pixel font (`tools/props/`) - all drawn in code, since the dungeon sheet has
  no furniture or hardware in it to derive from.
  derive from.
- `game/enemies/office_boy/src/office_boy.png` was seeded as a restyle of the
  frozen CC0 body like every other enemy sheet, and is hand-owned from now on.

Credited voluntarily; CC0 imposes no obligation to do so.

## UI fonts
- Author: **Kenney** (https://kenney.nl)
- Source: https://kenney.nl/assets/kenney-fonts
- License: **CC0 1.0 Universal** - "free to use in personal, educational and
  commercial projects", crediting requested but explicitly not mandatory
- Files: `assets/fonts/KenneyBlocks.ttf` (titles), `assets/fonts/KenneyMiniSquare.ttf` (UI),
  plus `KenneyPixel.ttf` and `KenneyFutureNarrow.ttf` kept as alternatives
