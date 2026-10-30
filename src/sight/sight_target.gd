extends Node
## Carried by anything that must be hidden unless currently seen: add it as a child of the
## entity (a Node3D). The sight system sets `seen`; the entity's `visible` follows.

const GROUP := &"sight_target"

signal seen_changed(now_seen: bool)

var seen := false
var _applied := false


func _ready() -> void:
	add_to_group(GROUP)
	_apply()


func set_seen(value: bool) -> void:
	if value == seen and _applied:
		return
	seen = value
	_apply()
	seen_changed.emit(seen)


func floor_position() -> Vector2:
	var p := (get_parent() as Node3D).global_position
	return Vector2(p.x, p.z)


func _apply() -> void:
	_applied = true
	(get_parent() as Node3D).visible = seen
