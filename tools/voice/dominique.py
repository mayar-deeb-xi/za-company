"""Dominique's voice: the recipe. What they sound like, line by line.

The mechanism is `cut.py`; this is the data, the same split every generated
thing in this project uses. The three briefings hold WHAT is said and are read
straight off disk by cut.py, so this file never repeats a line - it only says
how each one is delivered.

## Three conversations, one mouth

HR has one induction and Ivan has one thank-you; Dominique briefs a different
boss on each of the three floors below one, so `BEATS` is a LIST. They cut as
one voice into one folder, which is the whole reason the clip names below are
namespaced by the boss they are about: nothing dedupes across files, so two
briefings that both called a line `opening` would cut once and the second floor
would quietly play the first floor's read. `ahmed_`, `mostafa_`, `silverman_`
makes that impossible to do by accident.

The names are worded rather than numbered for the reason every conversation's
are (see cut.py): a line written into the middle of a briefing must not
renumber - or re-bill - the ones after it.

## Why this voice

Bold, Slavic and impatient, picked off the same four-voice audition Ivan's read
came out of. The two of them are deliberately not the same warmth: Ivan is glad
to see you and shows it, and Dominique has given this speech before to people
who did not come back. An impatient read is what makes a briefing feel like
information rather than sympathy - they are a road sign, not a send-off.

## Four reads across twelve lines

Shared the way HR's ten are shared across twenty-three: a tag per line would be
twelve separate performances of one person. The arc inside each briefing is the
same three steps - open brisk, state the fight flat, land the tell hard - which
is what makes three floors sound like one character with a routine rather than
three different warnings.

## Nothing is frozen yet

`KEEP` names takes that were listened to and approved; text-to-speech is not
deterministic, so a re-run must not re-cut them. It is empty until someone has
actually listened - add an entry the moment a read is worth protecting.
"""

VOICE_ID = "Xh5OictnmgRO4dff7pLm"
MODEL = "eleven_v3"

## Where the recordings land. `sfx/` is what the game loads, `src/` keeps the
## untouched export beside it - the same split HR, Ivan, the bosses and the
## music are on.
OUT = "game/npcs/dominique/sfx/voice"
RAW = "game/npcs/dominique/src/voice"

## The three briefings, read for their `voice` paths and their text. Declaring
## BEATS rather than LINES is what tells cut.py which mouth this is; declaring
## a LIST of them is what tells it there is more than one floor.
BEATS = [
    "game/npcs/dominique/before_ahmed.gd",
    "game/npcs/dominique/before_mostafa.gd",
    "game/npcs/dominique/before_silverman.gd",
]

## Levelling. Every mouth in the game sits at -19: a file's own level IS the mix
## here, there is no bus layout, so one number is what keeps a quiet floor and a
## boss floor at the same volume.
TARGET_RMS_DB = -19.0
PEAK_CEILING_DB = -3.0

_BRISK = ("[brisk, impatient, already walking away]", 0.4)
_DRY = ("[dry, unimpressed, stating company policy]", 0.45)
_FLAT = ("[flat and factual, reciting a known danger]", 0.45)
_HARD = ("[hard and direct - the one thing that matters]", 0.35)

## clip name -> (direction, stability). Three briefings, the same three steps in
## each: open brisk, state the fight flat, land the tell hard.
TAGS = {
    "ahmed_listen": _BRISK,
    "ahmed_family": _DRY,
    "ahmed_slam": _FLAT,
    "ahmed_fire": _HARD,

    "mostafa_gym": _DRY,
    "mostafa_rhythm": _FLAT,
    "mostafa_break": _HARD,
    "mostafa_fire": _HARD,

    "silverman_last_door": _BRISK,
    "silverman_slow": _DRY,
    "silverman_phases": _FLAT,
    "silverman_early": _HARD,
}

## A briefing written tomorrow that nobody has directed yet still cuts, in the
## read they spend most of a floor in. A missing tag is not worth a crash.
DEFAULT_TAG = _FLAT

SIMILARITY = 0.75
SPEAKER_BOOST = True

## (clip name, text) -> the take that was approved for it. See the header.
KEEP = {}

## Transcript variants that are the transcriber, not the take. `--verify` reads
## a clip back and compares, and a check that always shows the same three
## failures stops being read at all.
##
## All three are orthography rather than performance, and each is a different
## flavour of it: scribe contracts where the line does not, writes the American
## spelling of a word with only one pronunciation, and picks its own
## transliteration of a name - the same habit HR's table documents. Every one of
## these was listened to before it was written down here; a spelling entry is
## how a take is forgiven, so it must never be how a bad one is hidden.
SPELLINGS = {
    "you're": "you are",     # contracted in the read, not in the line
    "ax": "axe",             # one word, two spellings, one sound
    "mustafa": "mostafa",    # scribe's transliteration against the game's
}
