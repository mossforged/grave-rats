extends Node
## Loads designer-tunable numbers from data/<name>.json. Autoloaded as `Data`.
## Missing files and bad JSON fail loudly: push_error, return null, and set last_error.

const DEFAULT_DIR := "res://data"
const BASE_SHIP := "deck"
const SHIP_PREFIX := "deck_"
const OVERRIDES_KEY := "data_overrides"

var base_dir := DEFAULT_DIR
var last_error := ""
## The deck file in use: `load_data("deck")` reads it, and its "data_overrides" lie over the other files.
var ship := BASE_SHIP
## True when something chose this ship by hand (--ship, F1): the shift's `ship_pick` leaves it alone.
var ship_pinned := false
var _cache := {}


func _ready() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	var wanted := ship_arg(args)
	if wanted != "":
		pin_ship(ship_file(wanted))


## The value of `--ship name` or `--ship=name`, "" if there's none.
static func ship_arg(args: PackedStringArray) -> String:
	for i in args.size():
		if args[i].begins_with("--ship="):
			return args[i].trim_prefix("--ship=")
		if args[i] == "--ship" and i + 1 < args.size():
			return args[i + 1]
	return ""


## "survey" -> "deck_survey"; a deck file's own name stays as it is.
func ship_file(wanted: String) -> String:
	var prefixed := SHIP_PREFIX + wanted
	return prefixed if FileAccess.file_exists(base_dir.path_join(prefixed + ".json")) else wanted


## Every file read from here on sees this ship. A dictionary already handed out is refilled where it
## stands, so whoever holds one (Audio, Vfx) gets the new ship's top-level keys.
func use_ship(deck_file: String) -> void:
	if deck_file != BASE_SHIP and not FileAccess.file_exists(base_dir.path_join(deck_file + ".json")):
		_fail("no such ship: %s" % deck_file)
		return
	ship = deck_file
	var held := _cache
	_cache = {}
	for key: String in held:
		var fresh: Variant = load_data(key)
		if held[key] is Dictionary and fresh is Dictionary:
			(held[key] as Dictionary).clear()
			(held[key] as Dictionary).merge(fresh)
			_cache[key] = held[key]


func pin_ship(deck_file: String) -> void:
	use_ship(deck_file)
	ship_pinned = true


## The way back to the first ship, unpinned. Tests end on this.
func reset_ship() -> void:
	ship_pinned = false
	use_ship(BASE_SHIP)


## Returns the parsed JSON (usually a Dictionary) for data/<name>.json, or null on failure.
func load_data(name: String) -> Variant:
	if _cache.has(name):
		return _cache[name]
	last_error = ""
	var loaded: Variant = _read(ship if name == BASE_SHIP else name)
	if loaded == null:
		return null
	if ship != BASE_SHIP and name != BASE_SHIP and name != ship and loaded is Dictionary:
		var ship_data: Variant = _read(ship)
		if ship_data is Dictionary:
			merged_over(loaded, (ship_data as Dictionary).get(OVERRIDES_KEY, {}).get(name, {}))
	_cache[name] = loaded
	return loaded


## `over` laid on `base` in place: dictionaries merge key by key, anything else replaces.
static func merged_over(base: Dictionary, over: Dictionary) -> Dictionary:
	for key: Variant in over:
		if base.get(key) is Dictionary and over[key] is Dictionary:
			merged_over(base[key], over[key])
		else:
			base[key] = over[key]
	return base


func _read(file: String) -> Variant:
	var path := base_dir.path_join(file + ".json")
	if not FileAccess.file_exists(path):
		return _fail("data file missing: %s" % path)
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return _fail("bad JSON in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
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
