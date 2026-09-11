# Dialogue - subtitles, choices, and being shown around

Deep dive for `game/dialogue/` and `ui/dialogue/`. The root CLAUDE.md says
where these files sit; this is what the pieces are and why the seams fall where
they do.

Three files and nothing else:

- `ui/dialogue/dialogue_box.gd` - the **view**. A name, a line, a caret and a
  list of answers. It is handed strings and renders them.
- `game/dialogue/dialogue_director.gd` - the **runner**. Reads a conversation,
  drives the box, walks the NPC, tows the player, raises overlays.
- `game/npcs/<id>/<name>.gd` - the **content**. `const BEATS`, no code.

The box never learns what an NPC is. The NPC never learns what a box is. They
meet in game.gd, which connects `talk_requested` the same way it connects a
door's `travelled` and a boss's `health_changed` - by group, at the moment the
room is built, naming nothing.

## The beat format is in one place and it is the director

Every key a beat can carry is documented at the top of `dialogue_director.gd`,
next to the `_play()` that applies them, so the list cannot drift from the code
that reads it. Do not copy it here; read it there.

The shape of it, though, is worth stating: **a conversation is a flat list with
labels, not a tree**. `id` marks a beat and `goto` jumps to it, which is what
lets a question fan out and come back without any nesting. It is a smaller
language than a tree and it does the same work, and it stays readable as a file
you scroll.

## The runner holds no variables, and that is deliberate

There is no `set_flag` and no condition on a beat. A conversation cannot
remember that you already refused once.

Refusing HR twice gets two different lines anyway, and the way that is done is
the argument for the rule: each refusal is its own labelled beat, and the offer
it returns to is a different offer. Three labels bought what a counter and an
`if` would have bought, and the file still reads top to bottom as a thing
somebody said. The moment beats grow conditions, a conversation stops being
content and becomes a little program with no debugger.

When persistent story state does arrive - "she has already inducted you" - it
belongs in a save file and in the biome that decides which conversation she is
carrying, not in a variable here. Rooms are re-instantiated on every entry (see
the root CLAUDE.md), so there is nothing to hang it on yet.

## Audio, and the seams it was built against

**HR and Ivan are voiced** - twenty-three clips and eighteen, cut by
`tools/voice/`, the same pipeline Ahmed's barks come out of. Nothing about the runner changed to make that work,
because the two seams it needed were put in before there was any sound at all:

- **every beat can carry `voice`**, a clip path, and `say()` hands it to
  `_play_voice()`, which loads it and plays it.
- **the reveal rate is one function**, `_reveal_rate()`, and with a clip it is
  the line's length over the clip's length - so the last character lands as the
  speaker stops instead of a second before or four seconds after. That is the
  one piece of timing a subtitle can never guess for itself.

Subtitles are not a fallback for the voice here - they are the primary channel,
and the voice rides along with them. Nothing waits on audio: a press still
completes the line and a second still advances past it, clip or no clip,
because a player who reads faster than she talks must never be held at a box.

**Every miss is legal**, on `enemy_lines.gd`'s exact terms: a beat with no clip,
a clip not recorded yet, and a fresh checkout whose WAVs have not been imported
all land in the same `ResourceLoader.exists()` check, play nothing, and type at
CHARS_PER_SECOND. So a conversation is readable before a line of it has been
recorded, which is what this whole file described until HR was given a voice.

That freedom has a cost worth knowing: a mistyped clip path is SILENT, not an
error, so nothing at runtime would ever report one. `tests/test_dialogue.gd`
is the only thing that would - it reads the induction off disk and checks that
every line she speaks names a clip and every clip named is really there.
`tests/test_ivan.gd` carries the same pair over all six of his conversations,
plus two that only a speaker with six of them needs: that no two floors name the
same clip, since they all cut into one folder and a collision plays the wrong
floor's read, and that no two floors say the same LINE, which is the whole
reason there are six files instead of one.

**What stays unvoiced is the PLAYER.** The contract branch has them answering
back, and those beats carry no `voice` on purpose: the player is silent
everywhere else in this game, and HR's voice in their mouth would be the one
line of the induction that is a mistake. Ivan asks nothing and branches
nowhere on any of his six floors, so every line in them is his own and every one
of them is recorded.

## Taking the wheel

A conversation calls `player.take_control()`, which is NOT
`set_physics_process(false)` - the door transition uses that, and a frozen body
cannot be walked anywhere. Scripted control keeps physics running and ignores
the stick, so the escort can move the player under their own legs, at their own
speed, in their own walk animation. Being led looks exactly like walking
because it is the same code with the direction coming from somewhere else.

The escort re-aims every physics frame at a point `TRAIL` px from the guide
**along the line the player is already on**, so they trail from whichever side
they happen to be standing, and the player's own `LEAD_STOP` ring keeps them
from jittering when she slows. `TRAIL` is deliberately smaller than an NPC's
talk radius: a tour that ends where it started must leave the player close
enough to start another one.

**The tree is never paused.** It cannot be - the guide has to walk while she
talks. So the world runs through a conversation and the protection against
being hit mid-sentence is WHERE an NPC stands, not a flag in here. Two things
do cut a conversation short, both through `stop()`: a door and a death, wired
in game.gd, because both move the player somewhere and neither may leave them
under someone else's control.

A `walk` beat has a timeout (`WALK_TIMEOUT`). NPCs have no pathfinding - they
slide off whatever they touch, exactly as the enemies do - so a route that
clips a plant pot after somebody nudges a prop would otherwise hang the
conversation forever with the player still in it. It gives up and says the line
from wherever she got to.

## The box is as tall as the line in it

A fixed-height box has to reserve room for the longest thing anyone might ever
say. Almost nothing in the game says more than one line, so that reserve shows
up as empty space under the text on nearly every beat, and it reads as a menu
that has lost something rather than as somebody talking.

`dialogue_box._fit_panel()` measures instead, and it measures off **the Label's
own wrapped line count** rather than re-measuring the string through the font.
That is the whole reason it is safe: the box cannot disagree with the text it
is drawing, so no line can be clipped out of view. `get_line_count()` is
correct the instant `text` is assigned - no frame in between - so there is no
pop to hide.

It resizes in `say()` only, between beats, and only the TOP edge moves: the
bottom is pinned 10 px off the screen. So the box never changes height under a
line somebody is reading, and the choices ride on the top edge rather than
being placed against it.

One line is 34 px, each line after is 15 more. `tests/test_dialogue.gd` asserts
both halves of this - that the box stayed short, and that no line was ever
taller than the rect drawing it - so rewording a line or changing the font
size cannot quietly reintroduce either failure.

## Overlays are scenes, by path

A beat's `show` takes a scene path and `hide` takes it away. The director never
learns what any particular overlay is, which is why `ui/contract/` needed no
code here. The next conversation that wants to hold something up adds a scene
and a key, and this file does not change.

## Where a conversation lives

With the NPC who has it: `game/npcs/hr_lady/welcome.gd`. Not in a shared
`dialogue/` pile - the placement rule is the same as everywhere else in this
project, and a line is owned by the mouth it comes out of. WHICH conversation
an NPC is carrying is placement, though, and lives in the biome
(`tools/biomes/<level>.gd`, the `npcs` key), so the same person can greet you on
one floor and warn you on another without a second scene.
