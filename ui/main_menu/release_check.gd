extends Node
## Which version this is, and whether a newer one is out.
##
## The version is the repository's `VERSION` file, read at runtime rather than
## copied anywhere: every export preset lists it in `include_filter`, so the
## number on the menu and the number a release was published under are the same
## file and cannot drift. RELEASING.md is how that file becomes a release.
##
## The check asks GitHub for the latest release once per run, and only from a
## build carrying the `packaged` feature - the installed Windows and macOS
## games. Never the editor or a test suite (no network in a headless run), and
## never the web build, which is always the newest by being served.
## `/releases/latest` already skips drafts and pre-releases, so a beta never
## nags anyone. Every failure - offline, rate-limited, a malformed answer - is
## silence: an update notice is a courtesy, never something to wait on.

signal newer_found(version: String, url: String)

const LATEST := "https://api.github.com/repos/mayar4ki/za-company/releases/latest"
const VERSION_PATH := "res://VERSION"
const TIMEOUT := 6.0

## One ask per run: the menu is rebuilt after every game over, and asking again
## each time would spend GitHub's sixty-an-hour allowance for nothing.
static var _asked := false
static var _found := {}


static func current() -> String:
	var text := FileAccess.get_file_as_string(VERSION_PATH).strip_edges()
	return text if not text.is_empty() else "dev"


## True when `remote` is a later MAJOR.MINOR.PATCH than `local`. On an equal
## core a release beats its own pre-release (1.0.0 > 1.0.0-rc.1); anything that
## does not parse is never newer, so a junk answer cannot raise a notice.
static func is_newer(remote: String, local: String) -> bool:
	var a := _parse(remote)
	var b := _parse(local)
	if a.is_empty() or b.is_empty():
		return false
	for i in 3:
		if a[i] != b[i]:
			return a[i] > b[i]
	return a[3] == "" and b[3] != ""


static func _parse(version: String) -> Array:
	var text := version.strip_edges().trim_prefix("v")
	var cut := text.find("-")
	var suffix := "" if cut < 0 else text.substr(cut + 1)
	var parts := (text if cut < 0 else text.left(cut)).split(".")
	if parts.size() != 3:
		return []
	for part in parts:
		if not part.is_valid_int():
			return []
	return [int(parts[0]), int(parts[1]), int(parts[2]), suffix]


func _ready() -> void:
	if not _found.is_empty():
		newer_found.emit.call_deferred(_found["version"], _found["url"])
		return
	if _asked or not OS.has_feature("packaged"):
		return
	_asked = true
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_answer)
	http.request(LATEST, ["Accept: application/vnd.github+json"])


func _on_answer(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	take(body.get_string_from_utf8())


## The answer, separated from the asking so a test can hand it one.
func take(json: String) -> void:
	# An instance parse, not JSON.parse_string: that one logs an engine error
	# for every bad answer, and a bad answer is nothing worth a line in a log.
	var parser := JSON.new()
	if parser.parse(json) != OK or not parser.data is Dictionary:
		return
	var release: Dictionary = parser.data
	var tag := String(release.get("tag_name", ""))
	var url := String(release.get("html_url", ""))
	if url.begins_with("https://github.com/") and is_newer(tag, current()):
		_found = {"version": tag.trim_prefix("v"), "url": url}
		newer_found.emit(_found["version"], url)
