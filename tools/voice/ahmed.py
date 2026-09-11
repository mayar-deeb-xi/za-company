"""Ahmed's voice: the recipe. What he sounds like, cue by cue.

The mechanism is `cut.py`; this is the data, the same split every generated
thing in this project uses. `taunts.gd` holds WHAT he says and is read straight
off disk by cut.py, so this file never repeats a line - it only says how each
cue is delivered.

## Tags, not sliders

Eleven v3 takes an inline delivery tag and acts on it; Multilingual v2 can only
be made less stable and hoped at. Both were cut and compared, and the tagged
reads won on both registers - so a cue's character lives in TAGS below as a
piece of direction ("[furious, roaring]") rather than as a number nobody can
read back later.

The tag is stripped from the audio by the model; it is not spoken. That is
worth verifying rather than trusting, which is what `cut.py --verify` does:
every clip is transcribed back and compared to the line it was cut from.

## Two clips are frozen

`KEEP` names the takes that were listened to and approved. Text-to-speech is
not deterministic - the same text, voice and settings give a different
performance every time - so re-running this script must not re-cut them, or it
ships a read nobody chose. Delete a KEEP entry to deliberately re-cut one.
"""

VOICE_ID = "EtsjFhqOd0YWASYxlmIg"
MODEL = "eleven_v3"

## Where the recordings land. `sfx/` is what the game loads, `src/` keeps the
## untouched export beside it - the same split his grunts and the music are on.
OUT = "game/bosses/ahmed/sfx/voice"
RAW = "game/bosses/ahmed/src/voice"
LINES = "game/bosses/ahmed/taunts.gd"

## Levelling. His grunts sit at -18.8 to -21.6 dBFS speech level, so the voice
## sits with them; a file's own level IS the mix here, there is no bus layout.
TARGET_RMS_DB = -19.0
PEAK_CEILING_DB = -3.0

_ROAR = ("[furious, roaring]", 0.0)
_SWING = ("[shouting, vicious]", 0.0)
_SNEER = ("[contemptuous, sneering]", 0.3)
_PAIN = ("[pained, furious]", 0.0)
_BEATEN = ("[defeated, bitter, muttering]", 0.5)

## cue -> (direction, stability). Five characters across nine cues, because a
## different tag per cue gives twenty-three lines that do not sound like one
## performance. The swings share a read; the two ways of being hit share a read.
TAGS = {
    "spot": _SNEER,
    "taunt": _ROAR,
    "slam": _ROAR,
    "chop": _SWING,
    "sweep": _SWING,
    "wave": _SWING,
    "hurt": _PAIN,
    "stagger": _PAIN,
    "concede": _BEATEN,
}

SIMILARITY = 0.75
SPEAKER_BOOST = True

## (cue, text) -> the take that was approved for it. See the header.
KEEP = {
    ("taunt", "Get over here!"): "approved: [furious, roaring], listened to",
    ("concede", "I'm telling Mostafa."): "approved: [defeated, bitter, muttering]",
}

## Transcript variants that are the transcriber, not the take. `--verify` reads
## a clip back and compares; these two would otherwise be flagged forever, and
## a check that always shows the same two failures stops being read at all.
##
## - scribe writes digits for spoken number words
## - "Mostafa" and "Mustafa" are one name; the take was approved by ear
SPELLINGS = {
    "twenty": "20",
    "mostafa": "mustafa",
}
