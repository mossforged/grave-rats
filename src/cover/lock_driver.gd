extends Node
## Lock-to-cover in a scene: while locked it takes the operator's controls, reads the player (or
## `scripted`) and feeds the operator crouched moves along the edge. Free, it touches nothing, so
## with the toggle off the crouch is the plain T006 one. The owner calls step() before the operator's.

const CoverLock := preload("res://src/cover/cover_lock.gd")
const OperatorModel := preload("res://src/player/operator_model.gd")

## When the operator's own input is off (tests, bots, captures): "keys", "aim", "fire".
var scripted := {}
var operator: Node3D
var lock: CoverLock
var field: RefCounted
var is_free := Callable()
var hide_prompt := false       # captures only

var _player_driving := false
var _tap := false
var _aim_hold := 0.0
var _face_left := 0.0
var _prompt: Label3D


func setup(op: Node3D, cover_field: RefCounted, config: Dictionary, free_check: Callable) -> void:
	operator = op
	field = cover_field
	lock = CoverLock.new(config)
	is_free = free_check
	_prompt = Label3D.new()
	_prompt.name = "LockPrompt"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.pixel_size = float(config.prompt_pixel_size)
	_prompt.font_size = int(config.prompt_font_size)
	_prompt.modulate = Color(String(config.prompt_color))
	_prompt.text = String(config.prompt)
	_prompt.visible = false
	add_child(_prompt)


func spot_here() -> Dictionary:
	return lock.spot_for(field, _flat(), operator.body_radius(), is_free)


## The key: locks if it can, lets go if locked. True when it did either.
func press() -> bool:
	if lock.locked():
		_let_go()
		return true
	if operator.control_held() or not lock.try_lock(field, _flat(), operator.body_radius(), is_free):
		return false
	_player_driving = operator.input_enabled
	operator.input_enabled = false
	scripted = {} if _player_driving else scripted
	_face_left = float(lock.cfg.face_hold_s)
	_tap = false
	_aim_hold = 0.0
	return true


## A click shorter than a physics step still counts, and raises you long enough to fire it.
func tap_fire() -> void:
	if lock.locked():
		_tap = true


func _let_go() -> void:
	lock.release()
	if _player_driving:
		operator.input_enabled = true
	operator.scripted = {}
	_player_driving = false


func release() -> void:
	if lock.locked():
		_let_go()


func step(delta: float) -> void:
	if not lock.locked():
		return
	var keys: Vector2 = scripted.get("keys", Vector2.ZERO)
	var aim: bool = scripted.get("aim", false)
	var fire: bool = scripted.get("fire", false)
	if _player_driving:
		keys = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		aim = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if fire or _tap:
		_aim_hold = float(lock.cfg.aim_hold_s)
	_aim_hold = maxf(_aim_hold - delta, 0.0)
	var yaw_deg: float = operator.move_yaw_deg
	var move := lock.step(delta, OperatorModel.wish_from_keys(keys, yaw_deg), aim or fire or _aim_hold > 0.0)
	if not lock.locked():
		_let_go()
		return
	var held := lock.hold_position(_flat())
	if not lock.locked():
		_let_go()
		return
	operator.global_position = Vector3(held.x, 0.0, held.y)
	var shoot: bool = (fire or _tap) and lock.can_fire()
	if shoot:
		_tap = false
	operator.scripted = {"keys": move.rotated(deg_to_rad(yaw_deg)), "crouch": true, "fire": shoot}
	if _face_left > 0.0:
		_face_left -= delta
		var across := lock.facing_point(float(lock.cfg.reach_m) * 2.0)
		operator.aim_point = Vector3(across.x, operator.aim_point.y, across.y)


## "", "locked" or "exposed": what the suit OS says about you.
func state_word() -> String:
	if not lock.locked():
		return ""
	return "exposed" if lock.exposed() else "locked"


## The prompt; call once a frame.
func show_state(alive: bool) -> void:
	var spot: Dictionary = spot_here() if alive and not lock.locked() else {}
	_prompt.visible = not spot.is_empty() and not operator.control_held() and not hide_prompt
	if _prompt.visible:
		var at: Vector2 = spot.cover_center
		_prompt.global_position = Vector3(at.x, float(lock.cfg.prompt_height_m), at.y)


func _flat() -> Vector2:
	return Vector2(operator.global_position.x, operator.global_position.z)
