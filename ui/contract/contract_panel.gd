extends Control
## The employment agreement, held up for the player to read. The header is
## English, the signature line is English, and every word of the agreement
## itself is nonsense - which is the joke, and also the point: HR is not hiding
## the terms, there are no terms.
##
## Raised by a conversation beat's `show` key and taken down by its `hide` (see
## game/dialogue/dialogue_director.gd), so it is a scene with no callers and no
## API. Anything else a conversation wants to hold up is another scene exactly
## like this one, and the director needs no edit to raise it.
##
## The body is generated at load rather than typed into the scene, for two
## reasons: a fixed page of gibberish is a page players can learn to recognise,
## and nonsense typed by hand is never quite nonsense enough - it drifts towards
## pronounceable.

## Letters the clauses are drawn from. Consonant-heavy and mixed-case on
## purpose: vowels in the usual proportion produce syllables, syllables produce
## words, and a page that almost reads is a page the player tries to read.
const GLYPHS := "qwrtypsdfghjklzxcvbnmQWRTYPSDFGHJKLZXCVBNM"
## Punctuation salted through the clauses. A page of pure letters reads as a
## corrupted file; commas and semicolons make it read as LEGAL, which is worse.
const MARKS := ",;.:()-/"
## Clauses down the page, and how wide each is allowed to get. The last line of
## a clause is cut short so the block has a ragged bottom edge, like prose.
## Five clauses of two lines is what fits the page at 16 px without the
## signature line sliding off the bottom of it.
const CLAUSES := 5
const CLAUSE_LINES := 2
const LINE_CHARS := 46

@onready var _body: Label = %Body

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Unseeded: a second look at the contract is a second page of nonsense,
	# which is funnier than the same one and costs nothing.
	_rng.randomize()
	_body.text = _page()


func _page() -> String:
	var lines: Array[String] = []
	for clause in CLAUSES:
		for line in CLAUSE_LINES:
			var width := LINE_CHARS
			if line == CLAUSE_LINES - 1:
				width = _rng.randi_range(LINE_CHARS / 3, LINE_CHARS - 6)
			# Sub-clause numbers are random rather than sequential. A real
			# agreement's numbering is a tree with most of it cut away, and
			# 4.1 under 3.1 under 2.1 reads as a generator, which it is.
			var prefix := "%d.%d  " % [clause + 1, _rng.randi_range(1, 9)] 				if line == 0 else "     "
			lines.append(prefix + _garble(width))
	return "\n".join(lines)


## One line of it. Words of two to nine glyphs, occasionally punctuated, cut at
## `width` so the right edge stays a column rather than a fringe.
func _garble(width: int) -> String:
	var out := ""
	while out.length() < width:
		var word := ""
		for i in _rng.randi_range(2, 9):
			word += GLYPHS[_rng.randi() % GLYPHS.length()]
		if _rng.randf() < 0.18:
			word += MARKS[_rng.randi() % MARKS.length()]
		out += word + " "
	return out.substr(0, width)
