"""The menu's blips, synthesised from data: no API, no credits, no recording.

    python tools/sfx/ui.py            # write ui/sfx/{move,press,back}.wav
    python tools/sfx/ui.py --report   # what is on disk, and how loud

The third python file in tools/sfx/ and the one that is NOT make.py's shape.
`make.py` and `tools/voice/cut.py` are both there for the same single reason -
they talk to a web API, because a performance cannot be computed - and
everything that follows from it (a KEEP list, a free `--relevel` off untouched
exports, ears as the only verification) exists to manage a generator that costs
money and never returns the same thing twice.

None of that applies here, because a menu tick has no performance in it. It is
three tones and an envelope, which is DATA - so this is the one sound in the
game that is generated the way the tilesets and the sprite sheets are: run it
twice, get the same bytes, and the recipe below is the whole truth about what
comes out. There is no `src/` beside the output and no KEEP, because there is
no take to approve and nothing to preserve: the numbers ARE the take.

That also makes it the only sound a fresh checkout can produce for itself.

## The synth is written twice, on purpose

This ships with a sibling: the audition page these were picked on runs the
identical per-sample loop in JavaScript. That is why the engine below is an
explicit sample loop rather than a chain of scipy filters or an oscillator
graph - the two implementations have to be the same ARITHMETIC, or the thing
that was picked and the thing that shipped are only approximately each other.
Anything added here (a new wave, a new envelope stage) is worth nothing until
the page can make the same noise.

## Levels

Peaks are stated per sound in the recipe, and they are quiet on purpose: these
sit over `menu_loop.wav` at its -8 dB trim (autoload/music.gd), and a menu tick
that competes with the music is a tick the player turns the game down to
escape. `move` is the quietest of the three because it fires the most - a
player scrolling a four-item menu hears it four times a second.

Nothing is normalised across the set: `press` is 4 dB over `move` because
choosing is a bigger event than passing over, and that difference is the whole
of what tells the two apart when they are otherwise the same two triangles.
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wav  # noqa: E402  (needs the path above)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "ui", "sfx")

# --------------------------------------------------------------------------
# The recipe. CHIME: a warm triangle with its octave laid over the top - the
# set picked out of four auditioned in the game's own menu.
#
# The three are one sound said three ways, which is the point: the same two
# triangles an octave apart, moving nowhere for `move`, up a fifth for `press`
# and down one for `back`. A player never has to learn three sounds, only a
# direction - and "up means forward, down means back" is the one piece of
# audio vocabulary every menu in the world already agreed on.
# --------------------------------------------------------------------------
SOUNDS = {
	"move": {
		"dur": 0.140, "peak_db": -22.0,
		"layers": [
			{"wave": "tri", "f0": 523.0, "dur": 0.140, "atk": 0.002, "dec": 34.0, "lp": 7000.0, "gain": 1.00},
			{"wave": "tri", "f0": 1046.0, "dur": 0.140, "atk": 0.002, "dec": 46.0, "lp": 9000.0, "gain": 0.34},
		],
	},
	"press": {
		"dur": 0.200, "peak_db": -18.0,
		"layers": [
			{"wave": "tri", "f0": 523.0, "f1": 784.0, "dur": 0.200, "atk": 0.002, "dec": 20.0, "lp": 7000.0, "gain": 1.00},
			{"wave": "tri", "f0": 1046.0, "f1": 1568.0, "dur": 0.200, "atk": 0.002, "dec": 28.0, "lp": 9000.0, "gain": 0.30},
		],
	},
	"back": {
		"dur": 0.200, "peak_db": -20.0,
		"layers": [
			{"wave": "tri", "f0": 523.0, "f1": 392.0, "dur": 0.200, "atk": 0.002, "dec": 22.0, "lp": 6000.0, "gain": 1.00},
			{"wave": "tri", "f0": 1046.0, "f1": 784.0, "dur": 0.200, "atk": 0.002, "dec": 30.0, "lp": 8000.0, "gain": 0.28},
		],
	},
}

RATE = wav.RATE


def frames(seconds):
	"""Seconds to a whole frame count, rounding half UP - which is what
	JavaScript's Math.round does and what Python's round() does not (it rounds
	half to even). One frame either way is inaudible; a length that disagrees
	with the audition page by one is a diff nobody can explain later."""
	return int(seconds * RATE + 0.5)


def noise(seed):
	"""Deterministic white noise: a plain 32-bit LCG, so the audition page
	reproduces it sample for sample. `random` would make every run a different
	click, which is exactly the non-reproducibility this file exists without.

	Unused by CHIME, which has no noise in it - kept because the engine is the
	part that is shared with the page, and a wave the page can make and this
	cannot is the drift the header warns about."""
	s = seed & 0xFFFFFFFF

	def nxt():
		nonlocal s
		s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
		return s / 2147483648.0 - 1.0

	return nxt


def render(spec):
	"""One sound to 16-bit samples.

	Per layer: an oscillator whose frequency glides exponentially from `f0` to
	`f1`, through a one-pole lowpass, under an envelope of linear attack ->
	exponential decay -> a 4 ms fade to a hard zero at the end.

	That last 4 ms is not cosmetic. A clip that stops mid-waveform steps
	straight to silence and clicks, which is the same seam `autoload/music.gd`
	crossfades its loops out of - and on a sound this short, a click at the end
	is a large fraction of what the player hears.
	"""
	n = frames(spec["dur"])
	out = [0.0] * n

	for L in spec["layers"]:
		start = frames(L.get("t0", 0.0))
		length = frames(L["dur"])
		rnd = noise(L.get("seed", 12345))
		# One-pole coefficient for the layer's corner frequency; no `lp` is a
		# coefficient of 1, i.e. the filter passes the signal through unchanged.
		a = 1.0 - math.exp(-2.0 * math.pi * L["lp"] / RATE) if L.get("lp") else 1.0
		duty = L.get("duty", 0.5)
		gain = L.get("gain", 1.0)
		decay = L.get("dec", 30.0)
		glide = L.get("f1")
		phase = 0.0
		filtered = 0.0

		for i in range(length):
			t = i / RATE
			f = L["f0"] * (glide / L["f0"]) ** (t / L["dur"]) if glide else L["f0"]
			phase += f / RATE
			if phase >= 1.0:
				phase -= math.floor(phase)

			shape = L["wave"]
			if shape == "sine":
				v = math.sin(2.0 * math.pi * phase)
			elif shape == "square":
				v = 1.0 if phase < duty else -1.0
			elif shape == "tri":
				v = 4.0 * abs(phase - 0.5) - 1.0
			elif shape == "noise":
				v = rnd()
			else:
				raise SystemExit("tools/sfx/ui.py: no wave called %r" % shape)

			filtered += a * (v - filtered)

			attack = min(1.0, t / L["atk"]) if L.get("atk") else 1.0
			tail = max(0.0, min(1.0, (L["dur"] - t) / 0.004))
			j = start + i
			if j < n:
				out[j] += filtered * attack * math.exp(-decay * t) * tail * gain

	# Normalise to the stated peak, so "how loud is this one" is one number in
	# the recipe above rather than an accident of how many layers were summed.
	peak = max((abs(v) for v in out), default=0.0)
	if peak > 0.0:
		g = (10.0 ** (spec["peak_db"] / 20.0)) / peak
		out = [v * g for v in out]

	return [max(-32768, min(32767, int(round(v * 32767.0)))) for v in out]


def report():
	for cue in SOUNDS:
		path = os.path.join(OUT, cue + ".wav")
		if not os.path.exists(path):
			print("%-6s  -- not built" % cue)
			continue
		s = wav.load(path)
		peak = max((abs(v) for v in s), default=0)
		print("%-6s  %6.1f ms  peak %6.1f dBFS  rms %6.1f dBFS" % (
			cue, len(s) / RATE * 1000.0,
			20.0 * math.log10(peak / 32767.0) if peak else -99.0,
			20.0 * math.log10(wav.rms(s) / 32767.0) if wav.rms(s) else -99.0))


def main():
	ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	ap.add_argument("--report", action="store_true",
		help="print what is on disk and how loud, and write nothing")
	args = ap.parse_args()

	if args.report:
		report()
		return

	for cue, spec in SOUNDS.items():
		path = os.path.join(OUT, cue + ".wav")
		wav.save(path, render(spec))
		print("wrote %s  (%.0f ms, peak %.1f dBFS)" % (
			os.path.relpath(path, ROOT).replace("\\", "/"),
			spec["dur"] * 1000.0, spec["peak_db"]))
	print("\nNow import them: close the editor, then")
	print("  <godot> --headless --import --path .")


if __name__ == "__main__":
	main()
