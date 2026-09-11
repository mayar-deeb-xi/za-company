"""Ivan's voice: the recipe. What he sounds like, line by line.

The mechanism is `cut.py`; this is the data, the same split every generated
thing in this project uses. The six conversations hold WHAT he says and are
read straight off disk by cut.py, so this file never repeats a line - it only
says how each one is delivered.

## Six conversations, one mouth

He used to say one set of three lines on all six floors he arrives on. He now
says a different three on each (`after_<floor>.gd`, and after_call_center.gd
carries the reasoning), so `BEATS` is a LIST, exactly as Dominique's is for the
three briefings.

They cut as one voice into one folder, which is the whole reason the clip names
are namespaced by floor: nothing dedupes across files, so two floors that both
called their last clip `eat` would cut once and the second floor would quietly
play the first floor's read. `call_`, `ahmed_`, `gym_`, `assets_`, `exec_`,
`khaled_` makes that impossible to do by accident - and every floor really does
end on the same word, so it is not a hypothetical here.

The names are worded rather than numbered for the reason every conversation's
are (see cut.py): a line written into the middle of a floor's three must not
renumber - or re-bill - the ones after it.

## Why this voice

He is the one man in the building who is glad to see you, and the brief was an
English read with a European accent. Four Eastern-European voices were cut on
his last line and listened to side by side; this one won on the thing that
actually matters for him, which is that the accent is present without ever
costing a word - he is heard once per floor, over a room the player has just
finished fighting in, and a line that has to be replayed to be understood is a
line that lands after the moment it was for.

## Five reads across eighteen lines

Shared the way HR's ten are shared across twenty-three: a tag per line would be
eighteen separate performances of one person. The arc inside a floor is the
same three steps every time - arrive gruff, be fond about a colleague, land the
food warm - which is what makes six floors sound like one man with a routine
rather than six visits from six different cooks.

The two exceptions are both the same floor being wrong: on the executive floor
he is quiet and then hurried, because it is the one room he is frightened of
being SEEN in, and the read has to carry that where the words are still about
lunch.

## Nothing is frozen

`KEEP` pinned the old `eat` - the audition take, and the only clip in the game
whose untouched export was never written to `src/`. The line it was a
performance of is gone with the file it was in, so the entry went with it. The
audition's real outcome was VOICE_ID above, which is what actually carries
forward; every clip here has a `src/` half and re-levels for free.
"""

VOICE_ID = "XaEUesE01wKIKaa0xI0h"
MODEL = "eleven_v3"

## Where the recordings land. `sfx/` is what the game loads, `src/` keeps the
## untouched export beside it - the same split HR, Dominique, the bosses and the
## music are on.
OUT = "game/npcs/ivan/sfx/voice"
RAW = "game/npcs/ivan/src/voice"

## The six floors he arrives on, in chain order, read for their `voice` paths
## and their text. Declaring BEATS rather than LINES is what tells cut.py which
## mouth this is; declaring a LIST of them is what tells it there is more than
## one floor.
BEATS = [
    "game/npcs/ivan/after_call_center.gd",
    "game/npcs/ivan/after_ahmed_office.gd",
    "game/npcs/ivan/after_conflict_resolution.gd",
    "game/npcs/ivan/after_asset_recovery.gd",
    "game/npcs/ivan/after_executive_floor.gd",
    "game/npcs/ivan/after_khaled_office.gd",
]

## Levelling. Every mouth in the game sits at -19: a file's own level IS the mix
## here, there is no bus layout, so one number across every mouth is what keeps
## a quiet floor and a boss floor at the same volume.
TARGET_RMS_DB = -19.0
PEAK_CEILING_DB = -3.0

_GRUFF = ("[gruff and weary, relieved but not showing it]", 0.4)
_DRY = ("[dry, fond, complaining about a colleague he likes]", 0.4)
_WARM = ("[warm and gruff, weary, a cook who has seen too much]", 0.4)
_LOW = ("[quiet and confiding, saying it only to you]", 0.45)
_HUSHED = ("[hushed and hurried, glancing over his shoulder]", 0.35)

## clip name -> (direction, stability). Six floors, the same three steps in
## each: arrive gruff, be fond, land the food warm - see the header for the one
## floor that breaks it and why.
TAGS = {
    "call_kitchen": _GRUFF,
    "call_hold": _DRY,
    "call_eat": _WARM,

    "ahmed_embarrassed": _DRY,
    "ahmed_salt": _DRY,
    "ahmed_axe": _WARM,

    "gym_ring": _DRY,
    "gym_two_plates": _DRY,
    "gym_hands": _WARM,

    "assets_counted": _GRUFF,
    "assets_boys": _LOW,
    "assets_crate": _WARM,

    "exec_not_staff": _LOW,
    "exec_kitchen": _LOW,
    "exec_quickly": _HUSHED,

    "khaled_heard": _GRUFF,
    "khaled_sixteen": _LOW,
    "khaled_nothing_above": _WARM,
}

## A beat written tomorrow that nobody has directed yet still cuts, in the read
## he ends every floor on. A missing tag is not worth a crash.
DEFAULT_TAG = _WARM

SIMILARITY = 0.75
SPEAKER_BOOST = True

## (clip name, text) -> the take that was approved for it. Text-to-speech is not
## deterministic, so a re-run must not re-cut a read somebody chose. Empty until
## somebody has actually listened - see the header.
KEEP = {}

## Transcript variants that are the transcriber, not the take. `--verify` reads
## a clip back and compares, and a check that always shows the same failures
## stops being read at all. His are three habits: the scribe contracts where the
## line does not, it writes a number as a digit, and it picks the American
## spelling of a word with one pronunciation and its own transliteration of a
## name - the same habits Dominique's table documents.
##
## Every one of these was listened to before it was written down. A spelling
## entry is how a take is FORGIVEN, so it must never be how a bad one is hidden:
## the three lines where the scribe had actually caught a wrong word - "I ran
## the kitchen" for "I run", "leave him way he is", "find the crate" for "a
## crate" - were re-cut rather than spelled away.
SPELLINGS = {
    "do not": "dont",
    "don't": "dont",
    "he is": "hes",
    "he's": "hes",
    "i have": "ive",
    "i've": "ive",
    "ax": "axe",             # one word, two spellings, one sound
    "16": "sixteen",         # a number said, a digit written
    "mustafa": "mostafa",    # scribe's transliteration against the game's
}
