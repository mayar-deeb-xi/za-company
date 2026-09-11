"""The Content Studio's voice: the recipe. What she sounds like muttering.

The mechanism is `cut.py`; this is the data, the same split every generated
thing in this project uses. `game/enemies/social_media/mutters.gd` holds WHAT
she says and is read straight off disk by cut.py, so this file never repeats a
line - it only says how each cue is delivered.

## The first voice in the game that is not a boss, and the first that is female

Everything cut before this was one man shouting at the player: Ahmed roaring,
Mostafa booking the room, HR reading a contract. This is the other thing a
voice can do in a game - not address the player at all. She is talking to
herself, and the player is overhearing an office.

That is why there is ONE cue here where a boss has nine. A boss's lines are
pinned to moments the fight makes (he swung, he was interrupted, he lost);
hers are pinned to nothing, polled slowly while she is alive, and the delivery
has to work with no context on either side of it. A read with a big arc would
sound like an answer to something.

## Whispered, and levelled like a whisper

`TARGET_RMS_DB` is -31, twelve under the bosses' -19, and that is not a
mistake to be corrected later. A mutter is flavour playing underneath
gameplay: it must sit below the warden's telegraph (-29), because a wind-up is
information the player needs and this is not. Anything louder and eight lines
on a slow poll become the loudest thing in a room with six enemies in it.

Voice cuts through a mix at a lower RMS than a noise effect does - it lands in
a band nothing else in this game occupies - so -31 is audible rather than
buried. It was checked against the drain loop she is standing in, which is the
only thing she is ever heard over.

## Nothing is frozen yet

`KEEP` names takes that were listened to and approved. Text-to-speech is not
deterministic, so re-running this must not re-cut them or it ships a read
nobody chose. These have not been auditioned.
"""

## Laura - female, young, "Enthusiast, Quirky Attitude". Picked for what it
## does when it is TIRED: a bright young-creator voice muttering about a
## deadline is somebody whose whole personality is running on fumes, which is
## the character. A naturally flat or breathy voice would have read as sad,
## and she is not sad, she is late.
##
## No other voice in the game may take this id. Ahmed is Jack, Mostafa is
## Edward, the call centre is Eric; the whole point of a bestiary that talks
## is that nobody has to check which enemy they are listening to.
VOICE_ID = "FGY2WhTYpPnrIDTdsKH5"
MODEL = "eleven_v3"

## Where the recordings land. `sfx/voice/` is what the game loads, `src/voice/`
## keeps the untouched export beside it - the same split the bosses' voices,
## her own sound effects and the music are on. Note `src/voice/` and not
## `src/sfx/`: her effects are already in the latter, and a re-cut of one must
## never be able to overwrite the other.
OUT = "game/enemies/social_media/sfx/voice"
RAW = "game/enemies/social_media/src/voice"
LINES = "game/enemies/social_media/mutters.gd"

## See the header. -19 is a boss; this is not a boss.
TARGET_RMS_DB = -31.0
PEAK_CEILING_DB = -3.0

## One cue, one read. Stability is high where a boss's is 0.0: a roar wants the
## model off its leash, and eight mutters that have to sound like the same
## person on the same bad afternoon want it on. Low stability gave one line
## read as a scream and one as a shrug.
_TIRED = ("[muttering to herself, stressed, exhausted, quiet]", 0.65)

TAGS = {
	"mutter": _TIRED,
}

SIMILARITY = 0.75
SPEAKER_BOOST = True

## (cue, text) -> the take that was approved for it. See the header.
KEEP = {}

## Transcript variants that are the transcriber, not the take - `--verify`
## reads a clip back and compares. Scribe writes digits for spoken number
## words, and these lines are full of times and counts.
##
## "500" is the one that is not obvious: she says "It's due at five", scribe
## hears a time and writes "5:00", and `same()` strips the punctuation before
## comparing, so it arrives here as five hundred. Both sides are mapped to the
## same token rather than the got-side being special-cased, because the same
## line read back a second time may well come out as plain "5".
SPELLINGS = {
	"five": "5",
	"500": "5",
	"three": "3",
}
