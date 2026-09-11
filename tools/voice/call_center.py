"""The phone team's voice: the recipe. What he sounds like while you wait.

The mechanism is `cut.py`; this is the data, the same split every generated
thing in this project uses. `game/enemies/call_center/mutters.gd` holds WHAT
he says and is read straight off disk by cut.py, so this file never repeats a
line - it only says how each cue is delivered.

## The direction is the whole character, and it runs opposite to the words

He is a warden: he deals no damage at all and instead takes four seconds of
your speed. He is also drawn as the most ordinary person in the building
because everything frightening about him is the field on the floor.

So the tag below is `[warm, pleasant, patient, customer service voice]` and it
is applied to "I can keep you waiting all day." That mismatch is the joke and
it is the only thing here that needs protecting. Read menacingly, these lines
are a small boss taunting the player, and the character stops working - the
fight already has three bosses, and this one is supposed to be somebody's
colleague. The unbroken pleasantness is what makes the two lines that describe
the slow land at all.

His brief is therefore the inverse of Mostafa's, who is calm because he is
dangerous. This one is calm because he genuinely thinks he is helping.

## Whispered, and levelled like a whisper

-31 RMS, twelve under the bosses, for the reason set out in social_media.py:
a mutter must sit below the telegraph of the very wind-up he is charging
(-29), because a wind-up is information and this is decoration. The two
mutterers are levelled identically so that a floor with both on it has no
accidental foreground.

## Nothing is frozen yet

`KEEP` names takes that were listened to and approved; text-to-speech is not
deterministic, so re-running must not re-cut them. These have not been
auditioned.
"""

## Eric - male, middle-aged, "Smooth, Trustworthy". The hold-music voice, and
## picked for exactly the register the lines need to be delivered in: the one
## that reads a script it does not have the authority to depart from.
##
## Deliberately not Brian ("Deep, Resonant and Comforting"), which was the
## closer match on the word "comforting" and the worse match on the character:
## deep and resonant is where Mostafa already lives, and a warden who sounds
## like a boss is the one thing this enemy must not be.
VOICE_ID = "cjVigY5qzO86Huf0OWal"
MODEL = "eleven_v3"

## `sfx/voice/` is what the game loads, `src/voice/` keeps the untouched
## export. Note `src/voice/` and not `src/sfx/`, which already holds his
## effects: a re-cut of one must never be able to overwrite the other.
OUT = "game/enemies/call_center/sfx/voice"
RAW = "game/enemies/call_center/src/voice"
LINES = "game/enemies/call_center/mutters.gd"

## Her numbers exactly. The two mutterers are never heard together - they are
## eight floors apart - but they are heard by the same person at the same
## system volume, and a difference between them would be a mixing error rather
## than a character. See social_media.py's header.
TARGET_RMS_DB = -31.0
PEAK_CEILING_DB = -3.0

## One cue, one read, and the read is the character - see the header. Stability
## is high because the ONLY thing that must not vary is his pleasantness: eight
## lines where one comes out cold is eight lines where the joke is explained.
_HELPFUL = ("[warm, pleasant, patient, customer service voice]", 0.70)

TAGS = {
	"mutter": _HELPFUL,
}

SIMILARITY = 0.75
SPEAKER_BOOST = True

## (cue, text) -> the take that was approved for it. See the header.
KEEP = {}

## Transcript variants that are the transcriber, not the take: scribe writes
## digits for spoken number words, and he counts a queue.
SPELLINGS = {
	"four": "4",
}
