"""Cuts a cast's sound effects: ElevenLabs -> 48 kHz mono 16-bit WAV.

    python tools/sfx/make.py enemies              # make anything not made yet
    python tools/sfx/make.py enemies --force      # re-roll everything but KEEP
    python tools/sfx/make.py enemies --only wraith social_media
    python tools/sfx/make.py enemies --relevel    # re-shape from src/, free
    python tools/sfx/make.py enemies --report     # what is on disk, and how loud

The second python in a repo of GDScript generators, and here for the same one
reason `tools/voice/cut.py` is: it talks to a web API, and Godot's headless
HTTP client is a poor place to do that. Everything it writes is an ordinary
WAV the game loads like any other file, so nothing in the game knows this
script exists.

Needs ELEVENLABS_API_KEY in `.env` at the repo root (gitignored).

## Sibling to cut.py, not a fork of it

The two pipelines are the same shape - a recipe module, a KEEP list, a free
`--relevel` off the untouched exports - and deliberately separate code, because
the endpoints differ in ways that go all the way down:

- `/v1/sound-generation` returns STEREO PCM where `/v1/text-to-speech` returns
  mono, so everything here is summed down first (`wav.mono`).
- there is no leading padding to trim, and no transcript to verify a result
  against. A sound effect cannot be checked by machine: `--report` prints what
  is on disk and how loud it is, and the ears do the rest.
- a voice is levelled against its speech, a sound effect against its whole
  self. See the header of wav.py.

## No ffmpeg, deliberately

It asks for `output_format=pcm_48000` and gets raw little-endian 16-bit PCM
back, then writes the WAV header itself. That lands on exactly the format the
bosses' sounds are already in, with nothing transcoded and no encoder to
install.
"""
import argparse
import importlib.util
import json
import os
import struct
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wav  # noqa: E402  (needs the path above)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
API = "https://api.elevenlabs.io/v1/sound-generation?output_format=pcm_48000"


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


def generate(r, prompt, seconds):
	"""One sound. Returns mono samples at 48 kHz.

	The endpoint hands back raw PCM with no header and no channel count, so
	the layout is worked out from the length against the duration asked for
	rather than assumed: it is stereo today, and a pipeline that would go
	silently half-speed the day that changes is not worth the two lines saved.
	"""
	body = {
		"text": "%s, %s" % (prompt, r.STYLE),
		"model_id": r.MODEL,
		"duration_seconds": seconds,
		"prompt_influence": r.PROMPT_INFLUENCE,
	}
	req = urllib.request.Request(
		API, data=json.dumps(body).encode("utf-8"),
		headers={"xi-api-key": key(), "Content-Type": "application/json"},
		method="POST")
	try:
		with urllib.request.urlopen(req, timeout=180) as resp:
			pcm = resp.read()
	except urllib.error.HTTPError as e:
		raise SystemExit("HTTP %s: %s" % (e.code, e.read().decode("utf-8", "replace")[:400]))
	n = len(pcm) // 2
	s = list(struct.unpack("<%dh" % n, pcm[:n * 2]))
	channels = max(1, min(2, round(len(s) / max(1.0, wav.RATE * seconds))))
	return wav.mono(s, channels)


def shape(r, s, cue, spec):
	"""Raw export -> what the game plays. The only place the order is decided.

	Trim, then cap, then seal a loop, then level - and the order is the whole
	of it. Levelling last is what makes the printed number true of the file
	that ships; sealing before levelling keeps the crossfade from being the
	one part of a loop that was mixed at a different gain.

	A loop takes the other road at the first fork: `steady` CHOOSES a stretch
	instead of trimming to one, because trimming asks where a sound starts and
	a bed is the thing with no answer to that. See wav.steadiest.
	"""
	if spec.get("steady"):
		s = wav.steadiest(s, spec["steady"])
	else:
		s = wav.trim(s)
	if spec.get("limit"):
		s = wav.limit_to(s, spec["limit"])
	if spec.get("loop"):
		s = wav.seal(s)
	return wav.level(s, r.LEVELS[cue], r.PEAK_CEILING_DB)


def line(name, s, note=""):
	print("  %-22s %5.2fs  rms %6.1f  peak %5.1f  %s"
		% (name, len(s) / wav.RATE, wav.db(wav.rms(s)), wav.peak_db(s), note))


def each(r, only):
	"""The work, filtered by `--only`, which takes an enemy or a single cue.

	Per-cue selection is not a convenience: a sound is judged one at a time
	and re-rolled one at a time, so `--only warden/hit --force` has to mean
	that hit and not the four sounds beside it that were already right.
	"""
	for who in r.ENEMIES:
		for cue, spec in r.ENEMIES[who].items():
			if only and who not in only and "%s/%s" % (who, cue) not in only:
				continue
			yield who, cue, spec


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("cast", help="a recipe module in this folder, e.g. enemies")
	ap.add_argument("--only", nargs="*", default=[], help="just these ids")
	ap.add_argument("--force", action="store_true", help="re-roll even what exists")
	ap.add_argument("--relevel", action="store_true",
					help="re-shape from src/, spending nothing")
	ap.add_argument("--report", action="store_true", help="what is on disk")
	args = ap.parse_args()

	r = recipe(args.cast)
	work = list(each(r, args.only))

	if args.report:
		missing = 0
		for who, cue, spec in work:
			path = os.path.join(ROOT, r.OUT % who, cue + ".wav")
			if not os.path.exists(path):
				print("  %-22s MISSING" % ("%s/%s" % (who, cue)))
				missing += 1
				continue
			s = wav.load(path)
			line("%s/%s" % (who, cue), s,
				"target %.0f%s" % (r.LEVELS[cue], "  loop" if spec.get("loop") else ""))
			# The SHAPE, which is the half of a review that does not need ears -
			# and the half that caught every sound this batch had to re-roll.
			bar, mid, spread = wav.envelope(s)
			print("  %-22s |%s| mid %.2f  hi/lo %6.1fx" % ("", bar, mid, spread))
		print("\n%s" % ("all present" if not missing else "%d missing" % missing))
		print("An impact wants mid low, a build-up high, a loop near 0.50 with"
			" hi/lo in single figures.")
		return

	# Re-shape the PLAYED files from the untouched exports. Free, and safe on
	# an approved sound: the performance lives in the export, so trimming and
	# levelling it again is not a new roll of the dice. This is what `src/` is
	# kept for, and it is how a sound cut under an older leveller is carried
	# onto a better one without paying for it twice.
	if args.relevel:
		for who, cue, spec in work:
			raw = os.path.join(ROOT, r.RAW % who, cue + ".wav")
			if not os.path.exists(raw):
				print("  %-22s no export kept" % ("%s/%s" % (who, cue)))
				continue
			out = shape(r, wav.load(raw), cue, spec)
			wav.save(os.path.join(ROOT, r.OUT % who, cue + ".wav"), out)
			line("%s/%s" % (who, cue), out, "re-levelled")
		print("\nRe-shaped from src/. No credits spent, no sound changed.")
		return

	for who, cue, spec in work:
		name = "%s/%s" % (who, cue)
		out_path = os.path.join(ROOT, r.OUT % who, cue + ".wav")
		raw_path = os.path.join(ROOT, r.RAW % who, cue + ".wav")
		if (who, cue) in r.KEEP and os.path.exists(out_path):
			print("  %-22s kept  (%s)" % (name, r.KEEP[(who, cue)]))
			continue
		if os.path.exists(out_path) and not args.force:
			print("  %-22s have" % name)
			continue
		s = generate(r, spec["prompt"], spec["seconds"])
		wav.save(raw_path, s)
		out = shape(r, s, cue, spec)
		wav.save(out_path, out)
		line(name, out, "from %.2fs" % (len(s) / wav.RATE))

	print("\nRun an --import pass with the editor CLOSED before these play.")


if __name__ == "__main__":
	main()
