# Music - the tracks, and what a generated one needs before it can loop

What plays them, and when, is autoload/CLAUDE.md's *Music*. This is about the
files, and every rule here was learned on one of them.

**Audio lives in `assets/music/`** - the one folder, on the `assets/` rule that
names audio outright as a thing shared across features. A track that needed
work before it could loop keeps its untouched export beside it in
`assets/music/src/`, on the enemies' and bosses' exact terms: `src/` is the
hand-owned original, the file above it is what the game plays.

**Every track and every voice clip imports at 24 kHz**, not the 48 they are
exported at: `force/max_rate` on in each `.wav.import`, which halves 23 MB of
audio to 11.5 in every build. It is Godot's own resampler AS-IS, and that
resampler has no low-pass - at 48 -> 24 it keeps every other sample, so
treble above 12 kHz folds down rather than being cut. That was measured
(about -21 dB on Domimi and the social media mutter, under -40 on most) and
then judged by ear on an A/B page, and as-is won; a pre-filter is the fix if a
future line ever sounds gritty. Godot gives a NEW clip a fresh `.import` at its
48 kHz default, so a line cut tomorrow ships at twice the size and plays fine -
`tests/test_music.gd` sweeps every `sfx/voice/` and `assets/music/` import off
disk and fails on it. SFX and the menu's `ui/sfx/` stay at 48 kHz.

**A generated loop does not loop**, and it fails in THREE different ways. The
first is the seam: an ElevenLabs export ends mid-waveform, so the last sample
steps straight to the first and clicks once per pass - on `menu_loop.wav` that
step was 22376 of 32768, and every 30 seconds. The fix is a 12 ms equal-power
crossfade of the tail over the head, which costs 12 ms of length (0.04% across
a 30 s loop, well under a 32nd note) and takes the step to 33.

The second is worse and is what `lobby_loop.wav` arrived with - floor 1's
track, which was the building's bed when this was written: **the export
ENDS**, fading out over its last 3.75 s, so the loop dies away to silence and
then restarts at full level - a hole once a minute rather than a click. A
crossfade cannot fix that, because there is nothing left at the end to fade.
The music has to be cut back to the last whole BAR before the fade begins, and
only then crossfaded. That is the one measurement worth taking on a new track
before anything else: the tempo, so the cut lands on the grid. That track is
90 BPM, so a bar is 2.667 s and the loop is 20 of them. Two traps sit in that
sentence. The BPM is the one the generator was ASKED for and not the one it
delivered - this export runs at 90.019, which is 11 ms of drift by the
twentieth bar and therefore longer than the crossfade - and the thing being
matched at a loop point is waveform PHASE, which is sharp at the millisecond:
cutting at the nominal 53.333 s rather than the measured 53.322 took the
tail-against-head correlation from 0.875 to -0.12. So the bar count picks WHICH
peak to cut at and the measurement says where it is - correlate the tail's last
second against the head's first, swept at sample resolution.

The third is the one `finale_loop.wav` arrived with, and it hides from both of
the checks the first two taught. **The export ends by drying up rather than by
fading down**: the hits keep landing at full level to the last bar - the
on-beat quarter-seconds measure +2.0 dB against the track's own body at 59.5 s,
which is to say nothing whatever is fading - while the SPACE between them
empties out, the off-beats falling -3.0, -4.6, -6.1, -11.6, -20.9 dB across the
last four seconds as the reverb tail is pulled away. Peak level says the track
is fine. The waveform's outline says the track is fine. What loops is a room
that goes dry for two seconds once a minute and then snaps back wet, which
reads as a skip rather than as a fade. The measurement that finds it is an
envelope in quarter-second buckets with the ON-beat and OFF-beat buckets read
SEPARATELY; the fix is the second failure's fix - cut back to the last whole
bar before the off-beats start to move (56.0 s, bar 28, where they part
at 56.75).

And a measurement that works on a sparse track does not work on a dense one.
The tail-against-head correlation above is how `lobby_loop` was placed, and on
this track it is noise: a broadband sweep peaked at +0.20 on a cut 40 ms off
the grid - a third of a 16th note, an audible stumble - because hats and noise
are uncorrelated between two passes of the same music and drown the alignment
they are averaged into. Swept on the LOW BAND alone (one-pole at 300 Hz, the
kick and the sub, which is what carries the grid) the same track gives a single
sharp peak of +0.86, falling to +0.32 sixty samples either side. **Correlate
the band that keeps the beat, not the whole mix.**

Check all three on any new music before wiring it up: the click is obvious once
heard and invisible in a waveform view, the fade is invisible in the waveform's
shape until you look at where the last seconds of level went, and the dry-up is
invisible in both, because the hits never move.

**Two of the three are avoidable in the ASK, and the current bed is the proof.**
It was asked for at 128 BPM as "a single continuous 32-bar groove at constant
intensity - no intro, no build, no drop, no fade, and the last bar as loud and
as busy as the first". 32 bars at 128 BPM is 60.000 s, which is exactly the
length ElevenLabs exports, so the generator had nowhere to put an ending: it
came back with no fade and no dry-up (its last 8 s alternate +2.0 / -2.3 dB
about the body, on-beat against off-beat, right up to 59.75 s) and measured
128.00 BPM to within a millisecond over 30 bars. Nothing had to be cut back to
a bar line - the whole file WAS the loop - and only the seam needed the 12 ms
crossfade, which took the step from 39526 of 32768 to 706, the same size as
this track's own mean sample-to-sample step. **Pick a tempo whose bar count
lands on the export length and say the last bar must be as loud as the first,
and the only failure left is the one that is always there.**

**A track a MOUTH plays over is levelled in the speech band, not broadband,
and Ahmed's theme is why that sentence exists.** Every voice in the game is cut
to -19 dBFS and every track is trimmed by the one number on Music
(`VOLUME_DB` -8), so a floor's balance is decided entirely by the level baked
into its track - and his arrived at -12.5 dBFS, 6 dB hotter than the bed and
the hottest file in `assets/music/`, peaking -0.2. That put his voice 1.1 dB
over his own theme, which is to say under it. The broadband number is only half
of what was wrong: measured at 300 Hz - 4 kHz, where intelligibility lives,
every other track in the building sits 13-15 dB below its own broadband level
and his sat 7 dB below it - a midrange-heavy fight theme standing exactly where
he was talking, 9.7 dB hotter in that band than Big Mo's. **The check is the
75th-percentile window RMS of the track and of a voice clip, both band-limited
to 300-4000, with the music's -8 applied; the voice wants to clear it by
something like 8-13 dB, which is where all three bosses now are.** A track that
measures fine full-band can still bury a boss, so measure the band he speaks in.

He is also the track that proves the seam check is not optional: his was the
one file in `assets/music/` with no `src/` half, because it had never been
through any of this. It needed no bar-line cut and had no dry-up - its last 8 s
alternate about the body right to 59.75 s, the good-ask case above - but it
stepped 10413 of 32768 across the loop point against a mean step of 554, and
clicked once a minute for as long as it had been in the game. The 12 ms
crossfade took that to 184.
