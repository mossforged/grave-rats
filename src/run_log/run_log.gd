extends RefCounted
## One life's record, written as user://runs/<timestamp>.json when the life ends. Scene-free.
## The lead reads these beside John's comments. See src/run_log/CONTRACT.md.

const DEFAULT_DIR := "user://runs"
const SOURCES := ["spit", "puddle", "lunge"]

var dir := DEFAULT_DIR
var enabled := true
var time_alive_s := 0.0
var shots_fired := 0
var shots_hit := 0
var damage_by_source := {}
var hits_in_cover := 0
var hits_in_open := 0
var times_protected := 0
var killed_by: Variant = null
var started_at := ""
var last_path := ""

var _written := false


func _init(directory := DEFAULT_DIR) -> void:
	dir = directory
	begin()


## A new life.
func begin() -> void:
	time_alive_s = 0.0
	shots_fired = 0
	shots_hit = 0
	damage_by_source = {}
	for s: String in SOURCES:
		damage_by_source[s] = 0.0
	hits_in_cover = 0
	hits_in_open = 0
	times_protected = 0
	killed_by = null
	started_at = Time.get_datetime_string_from_system()
	_written = false


func note_time(delta: float) -> void:
	time_alive_s += delta


func note_shot(hit: bool) -> void:
	shots_fired += 1
	if hit:
		shots_hit += 1


## `in_cover`: a piece of cover stood on the straight line from the source to you.
func note_damage(source: String, amount: float, in_cover: bool) -> void:
	damage_by_source[source] = float(damage_by_source.get(source, 0.0)) + amount
	if source == "puddle":
		return
	if in_cover:
		hits_in_cover += 1
	else:
		hits_in_open += 1


## Cover stopped something aimed at you.
func note_protected() -> void:
	times_protected += 1


func note_death(stalker_name: String, how: String) -> void:
	killed_by = {"stalker": stalker_name, "how": how}


func to_dict(ended: String) -> Dictionary:
	return {
		"started_at": started_at,
		"ended": ended,
		"time_alive_s": time_alive_s,
		"shots_fired": shots_fired,
		"shots_hit": shots_hit,
		"damage_by_source": damage_by_source,
		"hits_in_cover": hits_in_cover,
		"hits_in_open": hits_in_open,
		"times_protected": times_protected,
		"killed_by": killed_by,
	}


## Writes this life once ("death", "respawn" or "quit"). Returns the path, or "" when off or
## already written.
func write(ended: String) -> String:
	if not enabled or _written:
		return ""
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if err != OK:
		push_error("run_log: can't make %s: %s" % [dir, error_string(err)])
		return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := dir.path_join("%s.json" % stamp)
	var n := 1
	while FileAccess.file_exists(path):
		n += 1
		path = dir.path_join("%s_%d.json" % [stamp, n])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("run_log: can't write %s" % path)
		return ""
	f.store_string(JSON.stringify(to_dict(ended), "  ") + "\n")
	f.close()
	_written = true
	last_path = path
	return path
