"""The audio kit the sound-effects generator shapes its exports with.

Deliberately NOT shared with `tools/voice/cut.py`, which has its own copy of
the same four ideas. They measure different things and the split is the point:
a voice is trimmed and levelled against its SPEECH level - "how loud is he
while actually talking", the 75th percentile of window RMS - because peak
normalising a voice lines up one plosive and leaves a roar and a mutter 13 dB
apart. A sound effect has no speech in it. An impact IS a transient, so the
same percentile would read the decay tail and make a hit quieter the longer it
rings.

So here a clip's level is the plain RMS of everything left after trimming, and
the two files stay separate for the same reason `CC0_LAYOUT` and `CAST_LAYOUT`
are two constants: one number serving two jobs looks like tidiness right up to
the day one job moves.
"""
import math
import os
import struct
import wave

RATE = 48000


def load(path):
    with wave.open(path, "rb") as w:
        n, ch = w.getnframes(), w.getnchannels()
        s = list(struct.unpack("<%dh" % (n * ch), w.readframes(n)))
        return mono(s, ch)


def save(path, s):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack("<%dh" % len(s), *s))


def mono(s, channels):
    """Sum interleaved channels down to one. The sound-effects endpoint hands
    back STEREO PCM where the text-to-speech one hands back mono, which is the
    single difference between this pipeline and the voice's."""
    if channels < 2:
        return s
    return [sum(s[i:i + channels]) // channels
            for i in range(0, len(s) - channels + 1, channels)]


def rms_windows(s, size):
    out = []
    for i in range(0, max(1, len(s) - size + 1), size):
        c = s[i:i + size]
        out.append((i, math.sqrt(sum(float(v) * v for v in c) / len(c)) if c else 0.0))
    return out


def rms(s):
    if not s:
        return 1.0
    return math.sqrt(sum(float(v) * v for v in s) / len(s)) or 1.0


def db(x):
    return 20 * math.log10(max(x, 1e-9) / 32767.0)


def trim(s, pad_ms=8):
    """Cut the dead air at both ends, measured in 20 ms windows against the
    clip's own loud end rather than sample-by-sample - one stray sample should
    not keep half a second of silence in front of an impact.

    A generated effect has no LEADING padding to speak of (unlike a TTS export,
    which is padded to a full second), so in practice this takes the tail. The
    front is still measured, because a prompt that describes a build-up
    sometimes gets a beat of room tone before it.

    The floor is measured two ways and the TIGHTER wins, which a sparse clip is
    the reason for. Against the 90th percentile alone, a clip that is one click
    and then nothing has a percentile already down in the noise, so the floor
    lands under the noise too and a second of silence survives the trim: the
    office boy's wrench shipped as 0.05 s of hit and 0.95 s of room. Capping it
    48 dB under the loudest moment as well cannot mistake a sparse clip for a
    quiet one, and 48 dB under an impact is nothing anybody hears.
    """
    size = int(RATE * 0.02)
    prof = rms_windows(s, size)
    if not prof:
        return s
    loud = sorted(r for _, r in prof)
    floor = max((loud[int(len(loud) * 0.9)] or 1.0) * 0.03,   # 30 dB under the body
                (loud[-1] or 1.0) * 0.004)                    # 48 dB under the peak
    live = [i for i, r in prof if r >= floor]
    if not live:
        return s
    pad = int(RATE * pad_ms / 1000)
    return s[max(0, live[0] - pad):min(len(s), live[-1] + size + pad)]


def limit_to(s, seconds):
    """Hard-cap a clip's length, fading the last 10 ms so the cut cannot click.

    This is what keeps a telegraph shorter than the wind-up it plays under - a
    warning still sounding when the blow lands has stopped being a warning.
    Taking the FRONT is right for a telegraph specifically: it is a rising
    sound, so its first moments are the part that says something is coming.
    """
    n = int(RATE * seconds)
    if seconds <= 0.0 or len(s) <= n:
        return s
    s = s[:n]
    fade = min(int(RATE * 0.01), len(s))
    for i in range(fade):
        s[len(s) - fade + i] = int(s[len(s) - fade + i] * (1.0 - i / fade))
    return s


def steadiest(s, seconds):
    """The most EVEN stretch of `seconds`, which is what a loop is made from.

    Asked for an unchanging bed the model still writes a sound: it opens, it
    swells, it decays and stops. Both drains came back that shape, and a decay
    crossfaded into its own head is a pulse once per pass - the loop working
    perfectly and sounding like a loop, which is the one thing a bed must not
    do.

    So a loop is not trimmed, it is CHOSEN: generate long, slide a window over
    the clip and keep the one whose 100 ms windows vary least. Trimming asks
    "where does the sound start", which is the wrong question about something
    that is meant not to.
    """
    n = int(RATE * seconds)
    if len(s) <= n:
        return s
    size = int(RATE * 0.1)
    step = int(RATE * 0.05)
    best, best_cost = 0, None
    for start in range(0, len(s) - n + 1, step):
        w = [r for _, r in rms_windows(s[start:start + n], size)]
        mean = sum(w) / len(w) if w else 0.0
        if mean <= 0.0:
            continue
        # Spread relative to level: a quiet even stretch beats a loud ragged
        # one, and dividing by the mean is what stops it simply picking silence.
        cost = math.sqrt(sum((v - mean) ** 2 for v in w) / len(w)) / mean
        if best_cost is None or cost < best_cost:
            best, best_cost = start, cost
    return s[best:best + n]


def seal(s, ms=12):
    """Crossfade the tail over the head so a loop can actually loop.

    A generated export ends mid-waveform: the last sample steps straight to the
    first and clicks once per pass. The same 12 ms equal-power crossfade the
    menu track needed (see autoload/music.gd and the root CLAUDE.md's Music) -
    it costs 12 ms of length and takes a step of thousands down to tens. Only
    a clip the game LOOPS needs it; a one-shot is left alone.
    """
    n = int(RATE * ms / 1000)
    if len(s) < n * 3:
        return s
    head, body = s[:n], s[n:]
    for i in range(n):
        t = (i + 0.5) / n
        a, b = math.cos(t * math.pi / 2), math.sin(t * math.pi / 2)
        body[len(body) - n + i] = max(-32768, min(32767, int(
            body[len(body) - n + i] * a + head[i] * b)))
    return body


def level(s, target_db, ceiling_db):
    """Bring the clip's RMS to target, then round off whatever pokes through.

    tanh rather than a gain cut, which is the lesson Ahmed's slam paid for:
    pulling a whole sound down so its tallest transient fits under the ceiling
    is what holds an impact 2 dB under target in the first place, and on an
    impact the harmonics a soft knee adds read as punch. It cannot exceed the
    ceiling by construction.
    """
    gain = 10 ** ((target_db - db(rms(s))) / 20.0)
    ceil = 10 ** (ceiling_db / 20.0) * 32767.0
    return [max(-32768, min(32767, int(ceil * math.tanh(v * gain / ceil))))
            for v in s]


def peak_db(s):
    return db(max((abs(v) for v in s), default=1))


BARS = " .:-=+*#%@"


def envelope(s, cells=28):
    """A coarse picture of where a clip's energy sits, and the centre of mass.

    The only review a machine can give a sound effect. It will not say whether
    a wrench sounds like a wrench, but it catches the three failures that shipped
    in the first batch of these and that all sound like a bug rather than a
    choice: a telegraph whose energy is at the END, an impact that arrives half
    a second in, and a "loop" that decays to nothing.

    `mid` is 0.0 for everything at the front and 1.0 for everything at the end -
    an impact wants it low, a build-up high, a loop near 0.5. `hi/lo` is the
    loudest window over the quietest: a bed should be single digits, and a loop
    in the hundreds has a hole in it.
    """
    n = max(1, len(s) // cells)
    vals = [rms(s[i:i + n]) for i in range(0, len(s) - n + 1, n)]
    if not vals:
        return "", 0.0, 0.0
    peak = max(vals) or 1.0
    bar = "".join(BARS[min(9, int(v / peak * 9.99))] for v in vals)
    total = sum(vals) or 1.0
    mid = sum(v * i for i, v in enumerate(vals)) / total / max(1, len(vals) - 1)
    return bar, mid, peak / (min(vals) or 1.0)
