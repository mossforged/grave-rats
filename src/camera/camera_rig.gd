extends Node3D
## Follow camera for the top-down view. Reads data/camera.json: presets (perspective or
## orthographic), follow smoothing and look-ahead, and the wall cut-away.
## Set `target` (a Node3D) and, each frame, `aim_dir` (horizontal unit vector or zero).
## Cut-away walls are any nodes in the group CUTAWAY_GROUP; see src/camera/CONTRACT.md.

signal preset_changed(index: int, preset: Dictionary)
signal cutaway_mode_changed(mode: String)

const CameraMath := preload("res://src/camera/camera_math.gd")
const CUTAWAY_GROUP := &"camera_cutaway"

var target: Node3D
var aim_dir := Vector3.ZERO
var presets: Array = []
var preset_index := 0
var cutaway: Dictionary = {}
var cutaway_mode := "drop"
var camera: Camera3D

var _follow: Dictionary = {}
var _focus := Vector3.ZERO


func _ready() -> void:
	var d: Dictionary = Data.load_data("camera")
	presets = d.presets
	_follow = d.follow
	cutaway = d.cutaway
	cutaway_mode = String(cutaway.mode)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.near = float(d.near_m)
	camera.far = float(d.far_m)
	add_child(camera)
	camera.make_current()
	set_preset(int(d.default_preset))


func preset() -> Dictionary:
	return presets[preset_index]


func set_preset(i: int) -> void:
	preset_index = clampi(i, 0, presets.size() - 1)
	var p := preset()
	if CameraMath.is_ortho(p):
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(p.ortho_size_m)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = float(p.fov_deg)
	_place()
	preset_changed.emit(preset_index, p)


func set_cutaway_mode(mode: String) -> void:
	cutaway_mode = mode
	cutaway_mode_changed.emit(mode)


func cycle_cutaway_mode() -> void:
	var modes: Array = cutaway.modes
	set_cutaway_mode(String(modes[(modes.find(cutaway_mode) + 1) % modes.size()]))


## The point the camera wants to look at: target plus look-ahead toward the aim, at focus height.
func desired_focus() -> Vector3:
	if target == null:
		return _focus
	var aim := Vector3(aim_dir.x, 0, aim_dir.z)
	if aim.length() > 0.001:
		aim = aim.normalized() * float(_follow.look_ahead_m)
	return target.global_position + aim + Vector3.UP * float(_follow.focus_height_m)


## Jumps to the desired framing and settles the cut-away at once (captures, respawns).
func snap() -> void:
	_focus = desired_focus()
	_place()
	_update_cutaway(INF)


func _process(delta: float) -> void:
	_focus = CameraMath.follow_step(_focus, desired_focus(), delta, float(_follow.smoothing_hz))
	_place()
	_update_cutaway(delta)


func _place() -> void:
	if camera:
		camera.global_transform = CameraMath.camera_transform(_focus, preset())


## Walls in the zone between the player and the camera drop to a low height or fade.
## Each cut-away node is a Node3D whose origin sits on the floor; meta "cutaway_rect" (Rect2,
## world XZ footprint) and "cutaway_height" (full height, m). "Drop" scales it in Y about the
## floor, "fade" sets the transparency of its GeometryInstance3D children.
func _update_cutaway(delta: float) -> void:
	if target == null:
		return
	var p := Vector2(target.global_position.x, target.global_position.z)
	var to_cam := CameraMath.to_camera_2d(preset())
	var step := float(cutaway.speed_per_s) * delta
	for n in get_tree().get_nodes_in_group(CUTAWAY_GROUP):
		var wall := n as Node3D
		var hit := cutaway_mode != "off" and CameraMath.in_cut_zone(wall.get_meta("cutaway_rect"), p, to_cam,
				float(cutaway.half_width_m), float(cutaway.depth_m), float(cutaway.behind_m))
		var amount := move_toward(float(wall.get_meta("cutaway_amount", 0.0)), 1.0 if hit else 0.0, step)
		wall.set_meta("cutaway_amount", amount)
		var full := float(wall.get_meta("cutaway_height"))
		var low := minf(float(cutaway.low_height_m) / full, 1.0)
		wall.scale.y = lerpf(1.0, low, amount) if cutaway_mode == "drop" else 1.0
		var fade := amount * float(cutaway.fade_transparency) if cutaway_mode == "fade" else 0.0
		for g in wall.get_children():
			if g is GeometryInstance3D:
				g.transparency = fade
