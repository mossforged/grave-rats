extends "res://src/shift/shift_deck.gd"
## Root of scenes/dev/t022_stand.tscn: T022's stills from the game camera on the real shift deck, with the AI
## stopped, and (env T022_MOVIE) a walk in a circle aiming at a fixed point, for tools/t022_capture.sh. Not a game scene.

const EIGHT := {"fwd": Vector2(0, -1), "fwd_right": Vector2(1, -1), "right": Vector2(1, 0), "back_right": Vector2(1, 1),
	"back": Vector2(0, 1), "back_left": Vector2(-1, 1), "left": Vector2(-1, 0), "fwd_left": Vector2(-1, -1)}
const WALK_SHARE := 0.5
const MOVIE_S := 16.0
const CIRCLE_M := 3.0
## Seen from the game camera the body is close to the floor plan: a lamp over it shows the pose, not the mood.
const LAMP_ENERGY := 3.0
const LAMP_RANGE_M := 10.0

var _lamp: OmniLight3D
var _at := {}
var _world_on := false   # the take only finishes with the world running


func _ready() -> void:
	super()
	if OS.has_environment("T022_MOVIE"):
		_movie.call_deferred()


func simulate_world(delta: float) -> void:
	if _world_on:
		super(delta)


func capture_shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: String in EIGHT:
		out.append({"name": "t022_walk_" + n, "do": "move", "keys": EIGHT[n], "mult": WALK_SHARE})
	for n: String in EIGHT:
		out.append({"name": "t022_run_" + n, "do": "move", "keys": EIGHT[n]})
	for n: String in ["fwd", "left", "right"]:
		out.append({"name": "t022_sprint_" + n, "do": "move", "keys": EIGHT[n], "sprint": true})
	for n: String in ["fwd", "back", "left", "right"]:
		out.append({"name": "t022_crouch_" + n, "do": "move", "keys": EIGHT[n], "crouch": true})
	out.append_array([
		{"name": "t022_crouch_idle", "do": "move", "keys": Vector2.ZERO, "crouch": true},
		{"name": "t022_fire_stand", "do": "fire", "keys": Vector2.ZERO},
		{"name": "t022_fire_walk", "do": "fire", "keys": EIGHT.fwd},
		{"name": "t022_fire_crouch", "do": "fire", "keys": Vector2.ZERO, "crouch": true},
		{"name": "t022_reload_stand", "do": "reload", "keys": Vector2.ZERO},
		{"name": "t022_reload_walk", "do": "reload", "keys": EIGHT.fwd},
		{"name": "t022_reload_crouch", "do": "reload", "keys": Vector2.ZERO, "crouch": true},
		{"name": "t022_hit_front", "do": "hit", "from": Vector2(0, -5)},
		{"name": "t022_hit_back", "do": "hit", "from": Vector2(0, 5)},
		{"name": "t022_pick_up", "do": "action", "state": "pick_up"},
		{"name": "t022_interact", "do": "action", "state": "interact"},
		{"name": "t022_turn", "do": "turn"},
		{"name": "t022_death_falling", "do": "death", "wait": 1.0},
		{"name": "t022_death_down", "do": "death", "wait": 5.0},
		{"name": "t022_carry_idle", "do": "carry", "keys": Vector2.ZERO},
		{"name": "t022_carry_walk", "do": "carry", "keys": EIGHT.fwd},
	])
	return out


func apply_shot(shot: Dictionary) -> void:
	Engine.time_scale = 1.0
	if panel:
		panel.visible = false
	sight_debug.visible = false
	_close_form()
	session_live = false
	_demo_t = -1.0
	respawn()
	ambush.fired = true
	rig.set_preset(int(Data.value("camera", "default_preset")))
	flashlight.set_on(true)
	set_kit_view("known")
	if _lamp == null:
		_lamp = OmniLight3D.new()
		_lamp.omni_range = LAMP_RANGE_M
		_lamp.light_energy = LAMP_ENERGY
		add_child(_lamp)
	var r: Rect2 = layout.space_rect("cargo")
	var spot: Vector2 = r.get_center()
	await _stand_at(spot, spot + Vector2(0, -8))
	operator.model.speed_mult = 1.0
	var op: Node3D = operator
	var hold := {"keys": shot.get("keys", Vector2.ZERO), "sprint": shot.get("sprint", false), "crouch": shot.get("crouch", false)}
	match String(shot.do):
		"move":
			op.model.speed_mult = float(shot.get("mult", 1.0))
			op.scripted = hold
			await _sim(0.7)
		"fire":
			op.scripted = hold
			await _sim(0.5)
			hold["fire"] = true
			op.scripted = hold
			await _sim(0.35)
		"reload":
			op.scripted = hold
			await _sim(0.5)
			op.rifle.state.mag = 3
			op.request_reload()
			await _sim(float(op.rifle.state.reload_total) * 0.35)
		"hit":
			await _sim(0.3)
			op.note_hit_from(Vector2(op.global_position.x, op.global_position.z) + shot.from)
			await _sim(0.22)
		"action":
			await _sim(0.3)
			op.play_action(String(shot.state))
			await _sim(float(Data.value("hauler_anim", "actions")[shot.state].seconds) * 0.5)
		"turn":
			await _sim(0.3)
			op.aim_point = op.global_position + Vector3(0, 1.2, 8)
			await _sim(0.5)
		"death":
			await _sim(0.3)
			op.note_hit_from(Vector2(op.global_position.x, op.global_position.z) + Vector2(0, 5))
			op.hold_control(INF)
			await _sim(float(shot.wait))
		"carry":
			_world_on = true
			await _carry_shot("heavy")
			_world_on = false
			op.scripted = hold
			await _sim(0.8)
	_lamp.global_position = op.global_position + Vector3(0, 3.5, 1.0)
	await _sim(0.05)
	var cam := get_viewport().get_camera_3d()
	var on_screen := cam.unproject_position(op.global_position + Vector3.UP)
	_at[String(shot.name)] = [on_screen.x, on_screen.y]
	Engine.time_scale = 0.0


func release_shot() -> void:
	Engine.time_scale = 1.0
	var out := String(Capture._out).path_join("t022_positions.json")
	if FileAccess.file_exists(out):
		var had: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out))
		had.merge(_at, true)
		_at = had
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_at))


## A walk in a circle, tangent to it, while aiming at its centre.
func _movie() -> void:
	_close_form()
	session_live = false
	ambush.fired = true
	operator.input_enabled = false
	aim_from_mouse = false
	set_kit_view("known")
	flashlight.set_on(true)
	var center: Vector2 = layout.space_rect("cargo").get_center()
	await _stand_at(center + Vector2(CIRCLE_M, 0), center)
	var aim := Vector3(center.x, 1.2, center.y)
	var left := MOVIE_S
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		var p := Vector2(operator.global_position.x, operator.global_position.z)
		var out_dir := (p - center).normalized()
		var tangent := out_dir.rotated(PI / 2.0)
		# Back onto the circle if the walk has drifted off it.
		var keys := tangent + out_dir * (CIRCLE_M - p.distance_to(center))
		operator.aim_point = aim
		operator.scripted = {"keys": keys}
	get_tree().quit()
