"""What the player sounds like. The recipe, not the engine.

`make.py` is the mechanism; this is the data, on the same split as
`enemies.py` beside it - and it is deliberately a SECOND recipe rather than
another entry in that one, because the player is not a member of the bestiary
and its cues are not the bestiary's cues.

    python tools/sfx/make.py player
    python tools/sfx/make.py player --only player/hurt --force
    python tools/sfx/make.py player --report

## One body, one voice, forever

The seven characters share one sheet and one animation set and always will
(game/player/CLAUDE.md, Characters), so they share one set of sounds for
exactly the same reason: a swing drawn once lands on all seven, and a swing
CUT once has to as well. That is why this file has a single member where
`enemies.py` has six - the cast is one body wearing seven palettes.

It has one consequence that has to be designed for rather than discovered:
**the hurt cue cannot commit to a gender.** Six of the seven characters are
not whoever the clip sounds like, and a plainly male grunt coming out of a
character who is not male is the animation telling the truth while the audio
lies - the same failure the office boy's wrench exists to avoid, arriving from
the other direction. So `hurt` and `die` are asked for breathy and neutral in
pitch, carried by air rather than by tone.

## The cues are player.gd's, and they arrive by existing

Same bargain as every other body in the game: `game/player/player_audio.gd`
holds id -> stream and player.gd fires names at it, so a cue that has no file
is silence with no branch anywhere. Eight of them, and the split between the
first two is the one worth keeping straight:

- `swing` / `swing2`   the two light attacks, fired when the swing STARTS.
                       Air, not impact - nothing has been struck yet.
- `hit`                fired only from `_strike()`, and only when a blow
                       actually reached somebody. This is the enemies' rule
                       (game/enemies/CLAUDE.md, The noise) pointed the other
                       way: an impact over empty air teaches the player that
                       the sound does not mean they connected.
- `charge`             the stance, and the only LOOP here - it holds for as
                       long as the button does, so it has no length of its own
                       to end at. The ready cue stays where it already was,
                       on the eyes: the charge animation doubles speed. See
                       its entry below for the spec that was tried first and
                       why it was wrong.
- `heavy` / `wildfire` the spin and the ring of fire it erupts into.
- `hurt`               the player taking a blow. Metered by the grace window
                       for free, because `take_damage()` already is - a
                       crowded room cannot stack gasps.
- `die`                health reaching zero.

**`drain()` is deliberately silent**, and it is the one absence anybody is
likely to call a bug. A drain runs every physics frame and knows its own rate
(root CLAUDE.md, three ways the world reaches the player); a gasp on each of
those is sixty gasps a second, and routing it through the grace window to
thin them out is exactly the mistake `drain()` exists to not make. The thing
draining you is already making the noise - the wraith's `drain` loop - so the
information is on the bus already, coming from the right direction.

## Levels are relative, and the player sits at the top of the chain

No audio bus layout and no volume setting yet, so a file's own level IS the
mix (root CLAUDE.md, Music). The bosses were levelled first, the enemies under
them; the player goes ABOVE both, and it is the same arithmetic argument
upside down. A room holds up to seven enemies and one player, and the sound
that says YOU are losing is the one sound in the mix that must never be won by
a crowd.

    player hurt          -19 RMS      level with a boss's blow, and for the
    player die           -19          same reason: nothing may bury it
    heavy                -20          ~1.9 rooted seconds should land like it
    wildfire             -21
    player hit           -22          level with an enemy's hit - one blow
                                      landing is one blow landing
    boss ordinary blow   -19          (game/bosses/CLAUDE.md, The noise)
    enemy hit            -22          (enemies.py)
    swing2               -26          heard on every combo
    swing                -27          heard MORE than anything else in the
                                      game; 5 under the impact it precedes
    enemy telegraph      -29
    charge               -28          a build, on the telegraph's shelf

The 5 dB between `swing` and `hit` is the enemies' 7 narrowed, on purpose. A
wind-up warns about somebody else's blow and must stay out of its way; a swing
is the player's own hand and is heard hundreds of times a room, so it wants to
be quiet for fatigue rather than for legibility - and burying it under its own
impact by the full 7 makes the combo feel like it is not connected to the
button.

## The same two frozen-take rules as everywhere else

`KEEP` pins a sound that was listened to and approved, because generation is
no more deterministic than text-to-speech and a re-run must not re-roll
something already right. And re-shaping is FREE: `make.py player --relevel`
re-trims and re-levels from the untouched exports in `game/player/src/sfx/`,
so only a new PERFORMANCE costs credits.
"""

## Where they land. `sfx/` is what the game loads, `src/sfx/` keeps the
## untouched export beside it - the enemies', bosses' and music's split
## exactly. It is `src/sfx/` rather than `src/` for the enemies' own reason:
## `game/player/src/` already means one documented thing, the cast's hand-owned
## sheet (`character_cc0.png`), and eight WAVs dropped in beside that PNG would
## blur a rule someone has to trust.
##
## The id slot is the owning FOLDER, which is what it has always been - the
## bestiary spells it `game/enemies/%s/sfx` because an enemy owns its sounds,
## and the player owns its own one level up.
OUT = "game/%s/sfx"
RAW = "game/%s/src/sfx"

MODEL = "eleven_text_to_sound_v2"

## Ahmed's ceiling. Three subsystems now, one headroom.
PEAK_CEILING_DB = -3.0

## How literally the model takes the prompt. The bestiary's number, unchanged:
## high enough that "dry, close, no music" is obeyed.
PROMPT_INFLUENCE = 0.55

## cue -> RMS target. See the header for why these numbers and not others.
LEVELS = {
	"swing": -27.0,
	"swing2": -26.0,
	"charge": -28.0,
	"heavy": -20.0,
	"wildfire": -21.0,
	"hit": -22.0,
	"hurt": -19.0,
	"die": -19.0,
}

## The tail of every prompt, and the bestiary's verbatim - a game sound is dry
## and close, because the room it plays in is 640 px wide and any reverb in the
## file is reverb the game cannot take back out.
STYLE = "dry, close, mono, no music, no reverb tail, game sound effect"

## id -> cue -> spec.
##   prompt   what to generate, minus STYLE
##   seconds  what to ask the API for; it is padded and then trimmed
##   limit    hard cap on the finished clip, where one is load-bearing
CAST = {
	"player": {
		# Light attack one. The most-heard sound in the game by a wide margin,
		# so it is asked for SHORT and dry: anything with a tail on it becomes
		# a smear the third time it fires inside a combo.
		"swing": {
			"prompt": "a light sword swung fast through the air, one clean "
				"short whoosh with a faint bright steel shimmer on it, "
				"nothing struck, no impact",
			"seconds": 0.7, "limit": 0.35,
		},
		# Light attack two - a rising slash, a launcher rather than a thrust
		# (game/player/CLAUDE.md). So it goes UP, which is the whole of how a
		# player tells the two halves of the combo apart with their ears.
		"swing2": {
			"prompt": "a sword slashing upward in a fast rising arc, a whoosh "
				"that pitches upward as it travels, brighter and a little "
				"longer than a flat swing, nothing struck, no impact",
			"seconds": 0.8, "limit": 0.45,
		},
		# The stance, and the one cue here that is a LOOP. It was specced as a
		# one-shot capped at CHARGE_SECONDS so that running out would be the
		# ready cue, and that was wrong on its own terms: the stance is held
		# for as long as the button is, so there is no fixed length for a clip
		# to run out AT, and a sound that stops 0.35 s before the heavy is
		# available actively misinforms. The eyes already have the ready cue
		# (the charge animation doubles speed); the ears get a hum that holds
		# for as long as you do, and the heavy's own swing is the payoff.
		#
		# So it takes the wraith drain's road at the first fork: `steady`
		# CHOOSES a stretch rather than trimming to one, because trimming asks
		# where a sound starts and a held note is the thing with no answer to
		# that. Two rolls came back a plateau that decays - the model will not
		# build on request - and `steadiest` is exactly the tool for turning a
		# plateau into a bed.
		"charge": {
			"prompt": "a sword blade gathering energy, starting from near "
				"silence and growing continuously louder and higher the "
				"entire time, quietest at the very beginning and loudest at "
				"the very end, one unbroken rise with no gaps, no impact and "
				"no release at the end",
			"seconds": 2.0, "steady": 0.5, "loop": True,
		},
		# The spin. 24 damage and ~1.9 rooted seconds, so it is the one swing
		# in the game allowed to be broad and heavy.
		"heavy": {
			"prompt": "a heavy sword spun in one full circle, a single broad "
				"unbroken sweeping whoosh of steel with a deep whump of "
				"displaced air under it, one continuous movement from start "
				"to finish with no gaps and no separate events in it",
			"seconds": 1.0,
		},
		# What the heavy erupts into. Ignition on the first instant, because
		# the ring is already out at full radius on the animation's frame one.
		"wildfire": {
			"prompt": "a ring of fire erupting outward across the ground, at "
				"full force on the very first sample with no silence and no "
				"build-up before it, a deep whoosh of ignition then flame "
				"roaring outward and falling away continuously to nothing "
				"with no gaps",
			"seconds": 1.2,
		},
		# A blow that LANDED. Fired from _strike() and nowhere else.
		"hit": {
			"prompt": "a sword blade striking home into a body, one crisp "
				"bright impact of steel with a solid thud under it, landing "
				"on the very first instant, single hit",
			"seconds": 0.8,
		},
		# The player taking a blow. Breath-forward and neutral in pitch - see
		# the header for why this one cannot sound like a particular person.
		# Light on the thud on purpose too: whatever struck you is playing its
		# own `hit` in the same frame, and two impacts stacked read as one
		# muddy one.
		"hurt": {
			"prompt": "one short sharp gasp of pain, breathy and androgynous "
				"with almost no pitch to it, a soft cloth-and-body thud under "
				"it, a single voice, one syllable",
			"seconds": 0.7,
		},
		# Health at zero. Same neutrality rule, plus the sword leaving the
		# hand - the one thing on screen that is true of all seven characters.
		"die": {
			"prompt": "a body hitting a hard floor together with a sword, a "
				"breathy exhale of air knocked out with almost no pitch to "
				"it and steel ringing off tile, everything arriving in the "
				"same instant and ringing down smoothly to nothing, one "
				"single unbroken event with no pauses and no second hit",
			"seconds": 0.9,
		},
	},
}

## (id, cue) -> why it was kept. See the header.
##
## All eight are pinned, and on SHAPE rather than on ears - `--report` is the
## half of a review a machine can do (make.py's note under it), and it is the
## half that caught every sound in this batch that had to be re-rolled. They
## still want listening to. Pinned anyway because the alternative is a stray
## `--force` re-billing eight rolls that are already right, and because a
## re-shape is free either way: `--relevel` works THROUGH a pin, since it
## spends nothing and changes no performance. Delete an entry to deliberately
## buy a new one.
KEEP = {
	("player", "swing"): "short, dry, front-loaded - no smear on a mashed combo",
	("player", "swing2"): "rises, and reads longer and brighter than swing",
	("player", "charge"): "mid 0.49, hi/lo 2.0x - a bed, not a plateau (2 rolls)",
	("player", "heavy"): "one unbroken sweep; the first roll went quiet mid-spin",
	("player", "wildfire"): "full force on sample one, as the ring already is",
	("player", "hit"): "maximum on the first instant, clean decay - an impact",
	("player", "hurt"): "breathy, neutral, one syllable, no competing thud",
	("player", "die"): "one event; two earlier rolls had a hole in the middle",
}
