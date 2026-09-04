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

Credited voluntarily; CC0 imposes no obligation to do so.

## UI fonts
- Author: **Kenney** (https://kenney.nl)
- Source: https://kenney.nl/assets/kenney-fonts
- License: **CC0 1.0 Universal** - "free to use in personal, educational and
  commercial projects", crediting requested but explicitly not mandatory
- Files: `assets/fonts/KenneyBlocks.ttf` (titles), `assets/fonts/KenneyMiniSquare.ttf` (UI),
  plus `KenneyPixel.ttf` and `KenneyFutureNarrow.ttf` kept as alternatives
