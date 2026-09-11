"""Cuts a voice: ElevenLabs -> 48 kHz mono 16-bit WAV.

    python tools/voice/cut.py ahmed            # cut anything not already cut
    python tools/voice/cut.py ahmed --force    # re-cut everything but KEEP
    python tools/voice/cut.py ahmed --verify   # transcribe what is on disk

The one python in a repo of GDScript generators, and it is here rather than in
a `.gd` for a reason the rest of `tools/` does not have: it talks to a web API
and Godot's headless HTTP client is a poor place to do that. Everything it
writes is ordinary art that the game loads like any other file, so nothing in
the game knows this script exists.

## Two kinds of mouth, one driver

A BOSS shouts on cues - `taunts.gd` holds `const LINES`, a cue mapped to the
several things he might say on it, and the clip is named after the cue and the
pick (`taunt_1.wav`). Nothing chooses those names, so they are derived.

An NPC has a CONVERSATION - `welcome.gd` holds `const BEATS`, a flat list said
once each in order, and every spoken beat already carries the `voice` path the
game will load. A recipe may name SEVERAL of them (Dominique briefs a different
boss on each of three floors), and they cut as one voice into one folder, which
is why the names in them have to be unique across the set. So the clip name there is AUTHORED, read back out of the beat,
and that is the important half: a conversation gets lines inserted into the
middle of it, and a derived name would renumber every clip after the insert and
re-cut the lot. Text-to-speech is not free and not repeatable, so a name that
moves is a bill and a re-performance of lines nobody asked to change.

`jobs()` flattens both into the same (name, text, tag, stability, key) list and
everything below it is shared.

Needs ELEVENLABS_API_KEY in `.env` at the repo root (gitignored).

## No ffmpeg, deliberately

It asks for `output_format=pcm_48000` and gets raw little-endian 16-bit mono
PCM back, then writes the WAV header itself. That lands on exactly the format
his grunts are already in, with nothing transcoded and no encoder to install.
MP3 would need one and would cost a generation loss for nothing.

## Trimming and levelling, and why both are windowed

An export arrives padded whether or not the sound fills it, and silence in
front of a bark is a shout landing late. The trim is measured in 20 ms WINDOWS
against the clip's own speech level - not sample-by-sample against its loudest
sample, which is fragile enough that one stray sample after the words keeps two
seconds of silence, and that silence then drags the level measurement down so
the clip ships both too long and too quiet.

The level is the 75th percentile of 50 ms window RMS: "how loud is he while
actually talking". Peak normalisation is the wrong measure for a voice - it
lines up the single loudest sample, which left a roar and a mutter 13 dB apart
in the only thing anybody hears.
"""
import argparse
import importlib.util
import json
import math
import os
import re
import struct
import subprocess
import sys
import urllib.error
import urllib.request
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RATE = 48000
TTS = "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=pcm_48000"
STT = "https://api.elevenlabs.io/v1/speech-to-text"


# ---- the boss's own recipe ------------------------------------------------

def recipe(name):
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), name + ".py")
    spec = importlib.util.spec_from_file_location("recipe_" + name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def key():
    for line in open(os.path.join(ROOT, ".env"), encoding="utf-8"):
        if line.startswith("ELEVENLABS_API_KEY="):
            return line.split("=", 1)[1].strip()
    raise SystemExit("no ELEVENLABS_API_KEY in .env")


def lines_of(rel):
    """cue -> [text], read out of the boss's own `const LINES`.

    Parsed entry-wise with DOTALL, because a long line is wrapped across two
    lines in that file and a line-at-a-time parse silently finds only some.

    A `\\n` in a line is a real break by the time it leaves here. Silverman says
    everything twice - Swedish, then the same thing in English - and the two
    halves are one string with a newline between them, which is what lets the
    subtitle draw two rows without `enemy_lines.gd` learning a second language.
    Passed through as the two characters a backslash and an `n` actually are,
    that break reaches the API inside the text and is read out.
    """
    src = open(os.path.join(ROOT, rel), encoding="utf-8").read()
    src = src[src.index("const LINES"):]
    cues, heads = {}, list(re.finditer(r'\n\t"(\w+)": \[', src))
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(src)
        cues[h.group(1)] = [t.replace("\\n", "\n") for t in
                            re.findall(r'\{"text": "(.*?)"[,}]', src[h.end():end], re.S)]
    return cues


def beats_of(rel):
    """[(clip name, text)] out of a conversation's `const BEATS`.

    Walked as balanced braces rather than by line, because a beat is a block
    and a long line is hand-wrapped across two of them with a `+`. Only beats
    that carry a `voice` are returned: the player's own lines in a conversation
    are not this voice, and a beat that is a walk or an overlay has no text at
    all. A clip named by two beats - the same words said twice on purpose - is
    cut once.
    """
    src = open(os.path.join(ROOT, rel), encoding="utf-8").read()
    src = src[src.index("const BEATS"):]
    out, seen, depth, start = [], set(), 0, 0
    for i, ch in enumerate(src):
        if ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth:
                continue
            block = src[start:i + 1]
            voice = re.search(r'"voice"\s*:\s*"([^"]+)"', block)
            if not voice:
                continue
            # An `options` list holds dicts with a "text" of their own, and it
            # always follows the line it answers - so the beat's own text is
            # whatever is in front of it.
            head = block.split('"options"')[0]
            parts = re.search(
                r'"text"\s*:\s*((?:"(?:[^"\\]|\\.)*"\s*\+?\s*)+)', head)
            name = os.path.basename(voice.group(1))[:-4]
            if not parts or name in seen:
                continue
            seen.add(name)
            out.append((name, "".join(
                re.findall(r'"((?:[^"\\]|\\.)*)"', parts.group(1)))))
    return out


def jobs(r):
    """Everything to cut, as (name, text, tag, stability, key).

    `key` is what KEEP and TAGS are looked up by - a cue for a boss, the clip's
    own name for a conversation - so both mouths share one driver below.

    A conversation recipe's `BEATS` may be one path or a list of them. Clip
    names are authored rather than derived, so nothing dedupes ACROSS files for
    you: two conversations that name the same clip cut once and the second one
    silently gets the first one's read.
    """
    if hasattr(r, "BEATS"):
        default = getattr(r, "DEFAULT_TAG", None)
        out = []
        # One conversation or several - a guide who says a different thing on
        # each of three floors is still one mouth with one folder of clips.
        files = r.BEATS if isinstance(r.BEATS, (list, tuple)) else [r.BEATS]
        for rel in files:
            for name, text in beats_of(rel):
                tag, stability = r.TAGS.get(name, default)
                out.append((name, text, tag, stability, name))
        return out
    out = []
    for cue, texts in lines_of(r.LINES).items():
        tag, stability = r.TAGS[cue]
        for i, text in enumerate(texts, 1):
            out.append(("%s_%d" % (cue, i), text, tag, stability, cue))
    return out


# ---- audio ----------------------------------------------------------------

def load(path):
    with wave.open(path, "rb") as w:
        return list(struct.unpack("<%dh" % w.getnframes(), w.readframes(w.getnframes())))


def save(path, s):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack("<%dh" % len(s), *s))


def rms_windows(s, size):
    out = []
    for i in range(0, max(1, len(s) - size + 1), size):
        c = s[i:i + size]
        out.append((i, math.sqrt(sum(float(v) * v for v in c) / len(c)) if c else 0.0))
    return out


def trim(s, pad_ms=40):
    size = int(RATE * 0.02)
    prof = rms_windows(s, size)
    if not prof:
        return s
    loud = sorted(r for _, r in prof)
    floor = (loud[int(len(loud) * 0.9)] or 1.0) * 0.05   # 26 dB under his speech
    live = [i for i, r in prof if r >= floor]
    if not live:
        return s
    pad = int(RATE * pad_ms / 1000)
    return s[max(0, live[0] - pad):min(len(s), live[-1] + size + pad)]


def speech_level(s):
    wins = sorted(r for _, r in rms_windows(s, int(RATE * 0.05)))
    return (wins[int(len(wins) * 0.75)] if wins else 1.0) or 1.0


def db(x):
    return 20 * math.log10(max(x, 1e-9) / 32767.0)


def level(s, target_db, ceiling_db):
    """Bring the SPEECH to target, then round off whatever pokes through.

    Capping the gain instead - which this did - lets one plosive decide how
    loud a whole line is. It barely showed on Ahmed, who shouts seven of his
    nine cues, and cost Mostafa 6.5 dB on the two lines that matter most: the
    first thing he says and the last. Both are tagged quiet, so they have the
    widest gap between their loudest consonant and their speaking level, and
    both ended up pinned at the ceiling with the words 6 dB under everything
    else he says.

    tanh leaves anything well below the ceiling untouched and compresses only
    what approaches it, so the words arrive at target and the transient stops
    short of clipping. It cannot exceed the ceiling by construction.
    """
    gain = 10 ** ((target_db - db(speech_level(s))) / 20.0)
    ceil = 10 ** (ceiling_db / 20.0) * 32767.0
    return [max(-32768, min(32767, int(ceil * math.tanh(v * gain / ceil))))
            for v in s]


# ---- the api --------------------------------------------------------------

def speak(r, text, tag, stability):
    body = {
        "text": "%s %s" % (tag, text),
        "model_id": r.MODEL,
        "voice_settings": {
            "stability": stability,
            "similarity_boost": r.SIMILARITY,
            "use_speaker_boost": r.SPEAKER_BOOST,
        },
    }
    req = urllib.request.Request(
        TTS % r.VOICE_ID, data=json.dumps(body).encode("utf-8"),
        headers={"xi-api-key": key(), "Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            pcm = resp.read()
    except urllib.error.HTTPError as e:
        raise SystemExit("HTTP %s: %s" % (e.code, e.read().decode("utf-8", "replace")[:400]))
    n = len(pcm) // 2
    return list(struct.unpack("<%dh" % n, pcm[:n * 2]))


def transcribe(path):
    """What the clip actually says. Used to prove the delivery tag was acted on
    rather than read out - which is the one failure that is inaudible in a
    waveform and obvious in a fight."""
    # utf-8 explicitly: `text=True` decodes with the machine's locale, which on
    # Windows is cp1252, and a Swedish transcript comes back as mojibake. It
    # compares the same either way - `same()` strips both sides down to ascii -
    # but the printout is the half of --verify a person actually reads.
    p = subprocess.run(
        ["curl", "-s", "--max-time", "120", "-X", "POST", STT,
         "-H", "xi-api-key: " + key(), "-F", "model_id=scribe_v1",
         "-F", "file=@%s;type=audio/wav" % path],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    try:
        return json.loads(p.stdout).get("text", "")
    except Exception:
        return "<no response>"


def same(a, b, spellings=None):
    """Whether a clip said its line.

    Bracketed text is dropped before comparing: the transcriber annotates audio
    EVENTS that way - `[growls]`, `[sighs]` - and a growl in front of a taunt is
    the delivery tag working, not a fault. `spellings` carries the rest, which
    is the transcriber's habits rather than the take's: digits for spoken number
    words, and one transliteration of a name against another.

    A spelling is a PHRASE on both sides, not a word, because the habits that
    actually show up do not line up one-for-one: a clock written `8:59` comes
    back as three words, and no word-for-word map can put those together. Both
    texts are normalized and then rewritten by the same table, so a rule reads
    as "these two spell the same sound" rather than as a direction.

    Longest first, so a rule cannot be eaten by a shorter one that matches
    inside it - `nine` would otherwise claim the tail of `fifty nine`.
    """
    def norm(s):
        s = re.sub(r"\[.*?\]", " ", s).lower()
        # Whitespace to spaces BEFORE the strip, or a newline is deleted rather
        # than collapsed and the words either side of it are welded into one.
        # Silverman's lines carry one - Swedish, break, English - so every clip
        # he has read back as a DIFF on a word that was never wrong.
        s = " ".join(re.sub(r"[^a-z0-9' ]", "", re.sub(r"\s+", " ", s)).split())
        for k in sorted(spellings or {}, key=len, reverse=True):
            s = re.sub(r"\b%s\b" % re.escape(k), spellings[k], s)
        return " ".join(s.split())
    return norm(a) == norm(b)


# ---- driver ---------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("who", help="a recipe in tools/voice/ - ahmed, hr, ...")
    ap.add_argument("--force", action="store_true", help="re-cut even what exists")
    ap.add_argument("--verify", action="store_true", help="transcribe what is on disk")
    ap.add_argument("--relevel", action="store_true",
                    help="re-trim and re-level from src/, spending nothing")
    args = ap.parse_args()

    r = recipe(args.who)
    work = jobs(r)

    # Re-cut the PLAYED files from the untouched exports. Free, and safe on an
    # approved take: the performance lives in the export, so trimming and
    # levelling it again is not a new read. This is what `src/` is kept for,
    # and it is the way to carry a boss who was cut under an older leveller
    # onto a better one without paying for him twice.
    if args.relevel:
        for name, _text, _tag, _stability, _key in work:
            raw = os.path.join(ROOT, r.RAW, name + ".wav")
            if not os.path.exists(raw):
                print("  %-14s no export kept" % name)
                continue
            s = load(raw)
            cut = level(trim(s), r.TARGET_RMS_DB, r.PEAK_CEILING_DB)
            save(os.path.join(ROOT, r.OUT, name + ".wav"), cut)
            print("  %-14s %.2fs  speech %.1f dBFS  peak %.1f"
                  % (name, len(cut) / RATE, db(speech_level(cut)),
                     db(max((abs(v) for v in cut), default=1))))
        print("\nRe-levelled from src/. No credits spent, no take changed.")
        return

    if args.verify:
        bad = 0
        for name, text, _tag, _stability, _key in work:
            path = os.path.join(ROOT, r.OUT, name + ".wav")
            if not os.path.exists(path):
                print("  %-14s MISSING" % name)
                bad += 1
                continue
            got = transcribe(path)
            ok = same(got, text, getattr(r, "SPELLINGS", {}))
            bad += 0 if ok else 1
            print("  %-14s %s  %s"
                  % (name, "ok  " if ok else "DIFF", got.strip()[:52]))
        print("\n%s" % ("every clip says its line" if not bad else "%d to look at" % bad))
        return

    for name, text, tag, stability, key in work:
        out = os.path.join(ROOT, r.OUT, name + ".wav")
        raw = os.path.join(ROOT, r.RAW, name + ".wav")
        if (key, text) in r.KEEP and os.path.exists(out):
            print("  %-14s kept  (%s)" % (name, r.KEEP[(key, text)]))
            continue
        if os.path.exists(out) and not args.force:
            print("  %-14s have" % name)
            continue
        s = speak(r, text, tag, stability)
        save(raw, s)
        cut = level(trim(s), r.TARGET_RMS_DB, r.PEAK_CEILING_DB)
        save(out, cut)
        print("  %-14s cut   %.2fs -> %.2fs  speech %.1f dBFS  %s"
              % (name, len(s) / RATE, len(cut) / RATE,
                 db(speech_level(cut)), text[:34]))

    print("\nRun an --import pass with the editor CLOSED before these play.")


if __name__ == "__main__":
    main()
