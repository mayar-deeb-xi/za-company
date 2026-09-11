"""Mostafa's voice: the recipe. What he sounds like, cue by cue.

The mechanism is `cut.py`; this is the data, the same split every generated
thing in this project uses. `game/bosses/mostafa/taunts.gd` holds WHAT he says
and is read straight off disk by cut.py, so this file never repeats a line - it
only says how each cue is delivered.

## A different voice, and a different register, because he is not his brother

Ahmed is Jack, British, and he ROARS: seven of his nine cues are tagged
furious or shouting. Mostafa is Edward - British too, because they are
brothers, but dark and low - and the tags below run the other way. He is
CONFLICT RESOLUTION, and he talks like it: calm, measured, procedural, booking
the room. Seven of his nine cues are quiet.

That inversion is the point. Two brothers tagged the same way would be one
boss fought twice, and the fights are already different shapes - Ahmed is a
menu of attacks chosen by range, Mostafa is a rhythm.

## The rage is the one explosion, and it has to be

`rage` fires once, on the frame he catches fire at half health, and never
again. It is the only cue here tagged like one of Ahmed's, and it is the only
line in his file with no procedure left in it. If every cue were shouted that
moment would be worth nothing - so the quiet everywhere else is what buys it.

## Two clips can be frozen

`KEEP` names takes that were listened to and approved. Text-to-speech is not
deterministic, so re-running this must not re-cut them or it ships a read
nobody chose. Nothing is frozen yet: these have not been auditioned.
"""

## Edward - British, Dark, Low. Ahmed is Jack (EtsjFhqOd0YWASYxlmIg); these two
## must not share a voice, and changing this line is the whole of recasting him.
VOICE_ID = "goT3UYdM9bhm0n2lmKQx"
MODEL = "eleven_v3"

## Where the recordings land. `sfx/` is what the game loads, `src/` keeps the
## untouched export beside it - the same split his grunts and the music are on.
OUT = "game/bosses/mostafa/sfx/voice"
RAW = "game/bosses/mostafa/src/voice"
LINES = "game/bosses/mostafa/taunts.gd"

## Ahmed's exact numbers. The two bosses are never heard together, but they are
## heard four floors apart by the same person at the same system volume, and a
## brother who is 4 dB louder is a mixing error rather than a character.
TARGET_RMS_DB = -19.0
PEAK_CEILING_DB = -3.0

_CALM  = ("[calm, measured, quietly menacing]", 0.55)
_FIRM  = ("[firm, impatient, professional]", 0.40)
_CLIP  = ("[clipped, businesslike]", 0.40)
_FORCE = ("[shouting, forceful]", 0.0)
_DRIVE = ("[urgent, driving]", 0.10)
_TAKE  = ("[winded, still controlled]", 0.30)
_SHARP = ("[indignant, sharp]", 0.20)
## The mask coming off, and the only tag here that would fit in Ahmed's file.
_BREAK = ("[furious, roaring, losing control]", 0.0)
_COLD  = ("[cold, seething, quiet]", 0.60)

## cue -> (direction, stability). Nine characters across nine cues: his lines
## carry the joke, so a single read across all twenty-two would flatten the one
## thing they are for.
TAGS = {
    "spot": _CALM,
    "taunt": _FIRM,
    "jab": _CLIP,
    "hook": _FORCE,
    "rush": _DRIVE,
    "hurt": _TAKE,
    "stagger": _SHARP,
    "rage": _BREAK,
    "concede": _COLD,
}

SIMILARITY = 0.75
SPEAKER_BOOST = True

## (cue, text) -> the take that was approved for it. See the header.
KEEP = {}

## Transcript variants that are the transcriber, not the take. `--verify` reads
## a clip back and compares; without these the same rows would be flagged
## forever, and a check that always fails the same way stops being read.
##
## - "Khaled" has no settled English spelling and scribe picks its own
## - scribe writes digits for spoken number words
SPELLINGS = {
    "khaled": "khalid",
}
