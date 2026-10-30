extends Node
## Loads designer-tunable numbers from data/<name>.json. Autoloaded as `Data`.
## Missing files and bad JSON fail loudly: push_error, return null, and set last_error.

const DEFAULT_DIR := "res://data"

var base_dir := DEFAULT_DIR
var last_error := ""
var _cache := {}


## Returns the parsed JSON (usually a Dictionary) for data/<name>.json, or null on failure.
func load_data(name: String) -> Variant:
	if _cache.has(name):
		return _cache[name]
	last_error = ""
	var path := base_dir.path_join(name + ".json")
	if not FileAccess.file_exists(path):
		return _fail("data file missing: %s" % path)
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return _fail("bad JSON in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
	_cache[name] = json.data
	return json.data


## Reads one key from data/<name>.json; returns `fallback` (and fails loudly) if the file or key is missing.
func value(name: String, key: String, fallback: Variant = null) -> Variant:
	var d: Variant = load_data(name)
	if d is Dictionary and d.has(key):
		return d[key]
	if d != null:
		_fail("key '%s' missing in data/%s.json" % [key, name])
	return fallback


func clear_cache() -> void:
	_cache.clear()


func _fail(msg: String) -> Variant:
	last_error = msg
	push_error("Data: " + msg)
	return null
