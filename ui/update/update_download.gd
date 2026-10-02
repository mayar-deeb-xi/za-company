extends Node
## Fetches one release file and proves it is the file the release published.
##
## Two requests, in this order: `SHA256SUMS.txt` (a few hundred bytes, into
## memory), then the file itself, streamed to disk so a 45 MB installer never
## sits in RAM. The file is only reported finished once its SHA-256 matches
## the published line for it; a mismatch deletes it. A file we cannot vouch
## for is never handed to an installer - the caller falls back to the link.
##
## The static half (picking, parsing, hashing) needs no network and is what
## tests/test_updater.gd exercises.

signal progressed(done: int, total: int)
signal finished(path: String, error: String)

const SUMS := "SHA256SUMS.txt"
## Bigger than HTTPRequest's 64 KB default: fewer round trips through the
## main loop for a file this size, still small next to the 45 MB it carries.
const CHUNK := 1 << 20
const TIMEOUT := 30.0

var _http: HTTPRequest
var _path := ""
var _expected := ""


## The first asset whose name ends with `suffix`, or {} - the platform
## scripts' ASSET_SUFFIX is what is passed in.
static func pick(assets: Array, suffix: String) -> Dictionary:
	for asset in assets:
		if asset is Dictionary and String(asset.get("name", "")).ends_with(suffix):
			return asset
	return {}


static func named(assets: Array, file_name: String) -> Dictionary:
	for asset in assets:
		if asset is Dictionary and String(asset.get("name", "")) == file_name:
			return asset
	return {}


## `sha256sum` output -> {file name: lowercase hex}. Takes both of its modes
## ("<hash>  <name>" and "<hash> *<name>") and skips anything else.
static func parse_sums(text: String) -> Dictionary:
	var sums := {}
	for line in text.split("\n", false):
		var clean := line.strip_edges()
		var gap := clean.find(" ")
		if gap != 64:
			continue
		var digest := clean.left(64).to_lower()
		var file_name := clean.substr(gap).strip_edges().trim_prefix("*")
		if file_name != "" and digest.is_valid_hex_number():
			sums[file_name] = digest
	return sums


## The file's SHA-256 as lowercase hex, read in chunks; "" if unreadable.
static func sha256_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		ctx.update(file.get_buffer(CHUNK))
	return ctx.finish().hex_encode()


static func matches(path: String, expected: String) -> bool:
	return expected != "" and sha256_file(path) == expected.to_lower()


## Starts both requests. `asset` and `sums` are entries from the release's
## `assets`; the file lands in `folder` under its own name.
func fetch(asset: Dictionary, sums: Dictionary, folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	_path = folder.path_join(String(asset["name"]))
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_sums.bind(String(asset["name"]),
		String(asset["browser_download_url"])), CONNECT_ONE_SHOT)
	if _http.request(String(sums["browser_download_url"])) != OK:
		finished.emit("", "could not ask for the checksums")


func cancel() -> void:
	if _http != null:
		_http.cancel_request()
	_discard()


func _process(_delta: float) -> void:
	if _http != null and _http.download_file != "":
		progressed.emit(_http.get_downloaded_bytes(), _http.get_body_size())


func _on_sums(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray,
		file_name: String, url: String) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		finished.emit("", "could not download the checksums")
		return
	_expected = String(parse_sums(body.get_string_from_utf8()).get(file_name, ""))
	if _expected == "":
		finished.emit("", "the release lists no checksum for " + file_name)
		return
	_http.timeout = 0.0  # a slow line on a big file is not a failure
	_http.download_chunk_size = CHUNK
	_http.download_file = _path
	_http.request_completed.connect(_on_file, CONNECT_ONE_SHOT)
	if _http.request(url) != OK:
		finished.emit("", "could not start the download")


func _on_file(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_discard()
		finished.emit("", "the download failed")
		return
	if not matches(_path, _expected):
		_discard()
		finished.emit("", "the download did not match its checksum")
		return
	finished.emit(_path, "")


func _discard() -> void:
	if _path != "" and FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
