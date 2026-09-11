"""Ivan's voice: the recipe. What he sounds like, line by line.

The mechanism is `cut.py`; this is the data, the same split every generated
thing in this project uses. `after_the_fight.gd` holds WHAT he says and is read
straight off disk by cut.py, so this file never repeats a line - it only says
how each one is delivered.

## The second conversation, and the names come from him

He is a BEATS recipe like HR rather than a LINES one like the bosses: three
beats said once each in order, and each one carries the `voice` path the game
loads, so the clip names below are read back OUT of that file. His are worded
rather than numbered - `still_standing`, `chair`, `eat` - because a numbered
name renumbers the moment a line is written into the middle of him, and a
renumbered name is a re-performance of lines nobody touched. See cut.py.

## Why this voice

He is the one man in the building who is glad to see you, and the brief was an
English read with a European accent. Four Eastern-European voices were cut on
his last line and listened to side by side; this one won on the thing that
actually matters for him, which is that the accent is present without ever
costing a word - he is heard once per floor, over a room the player has just
finished fighting in, and a line that has to be replayed to be understood is a
line that lands after the moment it was for.

## Three reads, because he only has three lines

HR shares ten reads across twenty-three lines; there is nothing to share here.
Each line gets its own direction, and the arc is one man relaxing: he opens
braced for the count, corrects himself mid-sentence about the chair, and only
by the last line is he warm - which is the line the hearts land on.

## `eat` is frozen, and it has no export beside it

It is the audition take - the one performance that was actually listened to and
picked - so KEEP pins it and no re-run may replace it. It is also the one clip
in the game whose untouched export was not kept, because it was cut before
there was an `ivan` recipe to write a `src/` for. `cut.py --relevel` says so
and skips it rather than failing; the other two re-level normally. Nothing else
here is affected, and the alternative - re-cutting it to tidy the folder - would
throw away the only take anybody chose.
"""

VOICE_ID = "XaEUesE01wKIKaa0xI0h"
MODEL = "eleven_v3"

## Where the recordings land. `sfx/` is what the game loads, `src/` keeps the
## untouched export beside it - the same split HR, the bosses and the music are
## on. See the header for the one clip that has no `src/` half.
OUT = "game/npcs/ivan/sfx/voice"
RAW = "game/npcs/ivan/src/voice"

## The conversation, read for its `voice` paths and its text. Declaring BEATS
## rather than LINES is what tells cut.py which mouth this is.
BEATS = "game/npcs/ivan/after_the_fight.gd"

## Levelling. Ahmed's voice sits at -19 and so do HR's: a file's own level IS
## the mix here, there is no bus layout, so one number across every mouth in the
## game is what keeps a quiet floor and a boss floor at the same volume.
TARGET_RMS_DB = -19.0
PEAK_CEILING_DB = -3.0

_BRACED = ("[gruff and weary, relieved but not showing it]", 0.4)
_FUSSING = ("[brisk, catching himself mid-sentence, fussing]", 0.35)
_WARM = ("[warm and gruff, weary, a cook who has seen too much]", 0.4)

## clip name -> (direction, stability). Three lines, three reads - see header.
TAGS = {
    "still_standing": _BRACED,
    "chair": _FUSSING,
    "eat": _WARM,
}

## A beat written tomorrow that nobody has directed yet still cuts, in the read
## he ends on. A missing tag is not worth a crash.
DEFAULT_TAG = _WARM

SIMILARITY = 0.75
SPEAKER_BOOST = True

## (clip name, text) -> the take that was approved for it. Text-to-speech is not
## deterministic, so a re-run must not re-cut a read somebody chose.
KEEP = {
    ("eat", "I made too much again. I always make too much. Eat."):
        "the audition take, picked over three other voices",
}

## Transcript variants that are the transcriber, not the take. Empty: he says
## no numbers and no names, which is what fills this table for everyone else.
SPELLINGS = {}
