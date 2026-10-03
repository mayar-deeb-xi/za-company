# Sync - one run on several machines

The party is put together by `Net` (autoload/CLAUDE.md's *Net*) and the lobby
(ui/lobby/CLAUDE.md); this is what keeps it one game once the host presses
START. The plan it builds is DESIGN.md's *Multiplayer*.

**In the run, `game/sync/` keeps the machines in step (M3)**, built by game.gd
as `Sync` on every machine so both ends sit at one path, and inert offline.
The host is the truth for everything but where a body is:

- **A body is its owner's**: a member whose `peer` is not this machine's is
  REMOTE (player.gd's `remote`) - it runs none of the player, and stands where
  its owner says, thirty times a second (`net_state()` / `apply_net_state()`,
  `game/sync/bodies.gd`), relayed by the host. Its PICTURE is drawn a beat
  behind that (below).
- **The world reaches nobody on a guest** - player.gd's `_world_reaches()`,
  which makes `take_damage`, `drain`, `apply_slow`, `shove` and `heal` no-ops
  anywhere but the host. It is the one rule that lets a guest run a room's
  effects for the look of them without any landing twice. On the host a blow
  on a remote body is decided there and its health sent to everybody; a slow
  or a shove is sent to the owner, who carries it (`reached` ->
  `net_reached()`).
- **The run is the host's**: deaths, the pool, getting up, the doors (a
  guest's count but never go) and the end of the run, told to the guests and
  run there by game.gd's `net_*` functions. Every arrival is a ROOM the host
  counts, carried on everything only true in one, so a step from the last
  floor is never drawn on the next.
- **When to speak**: two machines load at their own speed, so a guest's game
  tells the host it is up through `Net.arrived()` - Net being the one node both
  ends always have - and the host opens with a welcome holding the floor, the
  room, the pool, every body's health and who is down.
- **Nothing pauses online**: the pause menu and the death screen open over a
  running game, and game.gd hands this machine's player still hands while one
  is up. The true hit-stop (`Engine.time_scale`) is solo-only: online the stop
  holds the PICTURE instead (below).
- **A guest leaving takes their body with them** (`net_left`), and their row.
- **The room is ONE snapshot** (`game/sync/world.gd`): twenty times a second,
  compressed, every `synced` thing in it by its path - an enemy, a boss - and
  what it looks like. A guest draws each one where the host says
  (game/enemies/CLAUDE.md's *Online*), and the same message is the only word
  on what EXISTS: an entry the guest lacks was spawned on the host and carries
  its scene, so the guest makes one at that path; a thing the guest has and
  the snapshot lacks is gone, and goes. No spawn or despawn message to lose,
  arrive out of order or be missed by a guest still fading in. A guest's
  swing is reported by the attacker (a player's moment, below) and dealt on
  the host; a beat (`reinforcements.gd`) is the host's alone.
- **A room's own moving parts ride the same snapshot** (game/levels/CLAUDE.md's
  *Online*): a CLOCK - the studio, the dolly, the wiring - runs everywhere and
  is put right only when it drifts, DICE - the scrubbers - are the host's and
  drawn, and the host alone walks Ivan and Dominique in, throws the hearts and
  spends a pickup.
- **A MOMENT is told, not pictured**: what a snapshot cannot carry because it
  is over by the next one - a boss's line, his every sound and shake, a fire he
  throws, Silverman's copy and his prism's fan - the host `_tell()`s, and the
  same thing on each guest hears it in `net_event()` (game/bosses/CLAUDE.md's
  *Online*). The host picks a line and tells WHICH, so every machine reads the
  same words and plays the same clip.
- **Whoever presses the key talks** (game/sync/talk.gd): their machine runs the
  conversation and leads the NPC - lent to them for its length, so HR's tour
  works with a guest at its front - it is busy for everybody else, and they
  read the lines along on the subtitle.

**And it FEELS like one game (M4)**, which is three things on top of M3:

- **One clock, the host's, a tenth of a second ago.** Every message about the
  run carries the host's time; a guest reads that clock off the fastest trip it
  has seen (`game/sync/clock.gd`), and the host turns each guest's stamps into
  its own. What is DRAWN is drawn `Sync.DELAY` (0.1 s) behind it, gliding
  between the states either side (`game/sync/timeline.gd`) instead of stepping
  twenty or thirty times a second: the room's bodies answer `net_between()`,
  everybody else's player `net_draw()`. **A remote player is in two places on
  purpose**: its BODY stands at the newest step - that is what the host decides
  blows, doors and pickups with, so a guest who stepped out of a swing is out
  of it as soon as the wire allows - and its PICTURE (the sprite's offset) is a
  beat behind. What the host says ABOUT the room - a blow on you, health,
  down, up, lives, the end, every boss moment - waits for the same moment of
  the same clock (`Sync.later()`), so a number comes up as the drawn sword
  lands; only the welcome and the order to travel are acted on when heard, and
  travelling plays out everything still waiting first. **A CLOCK is not drawn
  behind**: the studio, the dolly and the wiring answer no `net_between()` and
  take their state when heard, or every correction would set a hazard late.
  Anything faster than 600 px/s between two states JUMPED and is held, not
  slid.
- **The stop holds the picture** (`game/picture_hold.gd`): online a blow that
  lands disables every `AnimatedSprite2D` and every hit-feel effect on THAT
  machine for the stop and leaves the world running, then catches each
  animation up by the time it was held - a boss's sprite is his telegraph, and
  a swing must still end itself (`animation_finished`). Asked by this
  machine's own blows and by a boss's, whose `froze` is told like his shake;
  somebody else's blow holds nothing here.
- **Every blow is seen everywhere.** A blow and a bolt are a player's MOMENTS,
  told by whoever moves that player and passed through the host
  (`World.from_player`, player.gd's `_tell` / `net_event`): the host deals a
  guest's reported blow FIRST, then every other machine draws it with the
  attacker's body - number, flash, jolt, juggle, static charge, the pieces on a
  kill, the bolt and its crackle, the impact sound - and the attacker hears
  back only whether it killed. A blow or a drain on a player is seen on every
  machine with its grunt (`net_seen()`), and `die` plays wherever health
  reaches 0. A remote body's own moves are read off its picture: the swing's
  air, the charge's hum and ring, the heavy's supernova - never the stop, the
  shake or the flash, which are the attacker's to feel. A remote body's sounds
  are POSITIONAL (player_audio.gd), because a teammate is somewhere. And static
  charge is PER PLAYER (the owner's call): your swings set up only your own
  arc, a body two players have tagged carries one charge of each, in each
  one's colour, and an arc prefers and sets off only its thrower's.

The game's own `WIRE` is 3 from here: a build from before the run was stamped
with the host's time is refused rather than let into one.
