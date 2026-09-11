"""HR's voice: the recipe. What she sounds like, line by line.

The mechanism is `cut.py`; this is the data, the same split every generated
thing in this project uses. `welcome.gd` holds WHAT she says and is read
straight off disk by cut.py, so this file never repeats a line - it only says
how each one is delivered.

## She is a conversation, not a boss, and the clip names come from her

Ahmed shouts on cues and his clips are named after them (`taunt_1.wav`). HR
has a list of beats said once each, and every spoken beat in `welcome.gd`
already carries the `voice` path the game loads - so the names below are read
back OUT of that file rather than derived here. That is deliberate: an
induction gets lines written into the middle of it, and a numbered name would
renumber every clip after the insert and re-cut lines nobody touched. See
cut.py's header.

Only HR is voiced. The contract-reading branch has the player answering back,
and the player is silent everywhere else in this game - putting HER voice in
their mouth would be the one line in the induction that is a mistake. Those
beats carry no `voice` and cut.py skips them.

## Tags, not sliders

Eleven v3 takes an inline delivery tag and acts on it, and the tag is stripped
from the audio rather than spoken - which is worth verifying rather than
trusting, and `cut.py --verify` transcribes every clip back and compares.

Her whole joke is that the menace is never in the words, so it has to be in the
read: the same bright HR voice says "you'll adore her" and "I'm told I have to
let you decide", and the second one has to land colder without ever raising.
Ten reads across twenty-three lines, shared the way Ahmed's swings share one -
a tag per line would be twenty-three separate performances of one person.

## Nothing is frozen yet

`KEEP` names takes that were listened to and approved; text-to-speech is not
deterministic, so a re-run must not re-cut them. It is empty until someone has
actually listened - add an entry the moment a read is worth protecting.
"""

VOICE_ID = "ogwqBH5bbF03DSbNiRNN"
MODEL = "eleven_v3"

## Where the recordings land. `sfx/` is what the game loads, `src/` keeps the
## untouched export beside it - the same split the bosses and the music are on.
OUT = "game/npcs/hr_lady/sfx/voice"
RAW = "game/npcs/hr_lady/src/voice"

## The conversation, read for its `voice` paths and its text. Declaring BEATS
## rather than LINES is what tells cut.py which mouth this is.
BEATS = "game/npcs/hr_lady/welcome.gd"

## Levelling. Ahmed's voice sits at -19 and so does hers: a file's own level IS
## the mix here, there is no bus layout, so one number across every mouth in the
## game is what keeps the lobby and the boss floor at the same volume.
TARGET_RMS_DB = -19.0
PEAK_CEILING_DB = -3.0

_BRIGHT = ("[warm, bright, welcoming]", 0.4)
_CRISP = ("[crisp, matter-of-fact]", 0.45)
_BREEZY = ("[breezy, cheerfully corporate]", 0.4)
_POINTED = ("[pleasant, but with a warning in it]", 0.4)
_CONFIDING = ("[confiding, amused, lowering her voice]", 0.5)
_SWEET = ("[sweetly insistent, coaxing]", 0.35)
_THIN = ("[patience thinning, the smile forced]", 0.3)
_COLD = ("[flat, cold, no warmth at all]", 0.5)
_PROUD = ("[proud, delighted with herself]", 0.3)
_BEAM = ("[beaming, delighted]", 0.2)

## clip name -> (direction, stability). The arc is the point: bright through
## the tour, sweet through the first refusals, and flat by the third - she only
## stops performing once the player has stopped cooperating.
TAGS = {
    "greet_1": _BRIGHT,
    "greet_2": _CRISP,
    "greet_3": _BREEZY,
    "just_hr": _BREEZY,
    "tour": _BREEZY,

    "desks": _POINTED,
    "reception_1": _BRIGHT,
    "reception_2": _CONFIDING,
    "cooler": _BREEZY,
    "tour_end_1": _BRIGHT,
    "tour_end_2": _SWEET,

    "offer_1": _SWEET,
    "refuse_1": _SWEET,
    "offer_2": _SWEET,
    "refuse_2": _THIN,
    "offer_3": _COLD,

    "read_1": _CRISP,
    "read_2": _PROUD,
    "read_3": _PROUD,

    "signed_1": _BEAM,
    "signed_2": _CRISP,
    "signed_3": _BREEZY,
    "signed_4": _BRIGHT,
}

## A beat written tomorrow that nobody has directed yet still cuts, in the voice
## she spends most of the induction in. A missing tag is not worth a crash.
DEFAULT_TAG = _BRIGHT

SIMILARITY = 0.75
SPEAKER_BOOST = True

## (clip name, text) -> the take that was approved for it. See the header.
KEEP = {}

## Transcript variants that are the transcriber, not the take. `--verify` reads
## a clip back and compares, and a check that always shows the same failures
## stops being read at all.
##
## Hers are all NUMBERS, which is the one thing she and Ahmed have in common:
## a time written as digits is read out as words and comes back as words, and a
## number written as a word comes back as digits. Neither is a bad take - both
## were listened to - so the table spells each pair the same way.
## The last two are not numbers and are worth knowing about: scribe is not
## deterministic either, so a clip can read back clean on one pass and show a
## homophone or an unpacked contraction on the next. Both of these were caught
## by transcribing the same take twice and getting two answers, which is the
## give-away that the difference is in the listener rather than in the voice.
SPELLINGS = {
    "eight fiftynine": "859",   # 8:59, said as a time
    "nine": "900",              # "not 9:00", said as the bare hour
    "sign in": "signin",        # "Sign-in.", heard as two words
    "eleven": "11",             # scribe's digits for a spoken number
    "council": "counsel",       # homophone; the legal one is what she says
    "i am": "i'm",              # contraction, unpacked on some passes
}
