extends Node
## Lock-to-cover in a scene: while locked it takes the operator's controls, turns the player (or
## `scripted`) into LOCK_CONTROLS commands and feeds the operator crouched moves along the edge. A remote
## operator's come from its client instead. Free, it touches nothing, so with the toggle off the
## crouch is the plain T006 one. The owner calls step() before the operator's.

const CoverLock := preload("res://src/cover/cover_lock.gd")
const OperatorModel := preload("res://src/player/operator_model.gd")
const Commands := preload("res://src/session/commands.gd")

## When the operator's own input is off (tests, bots, captures): "keys", "aim", "fire".
var scripted := {}
var operator: Node3D
var lock: CoverLock
var field: RefCounted
var is_free := Callable()
var hide_prompt := false       # captures only

var _player_driving := false
var _tap := false
var _click := false
var _keys := Vector2.ZERO
var _aim := false
var _fire := false
var _yaw_deg := 0.0
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
	_click = false
	_keys = Vector2.ZERO
	_aim = false
	_fire = false
	_yaw_deg = operator.move_yaw_deg
	_aim_hold = 0.0
	return true


## A click shorter than a physics step still counts, and raises you long enough to fire it.
func tap_fire() -> void:
	if lock.locked():
		_click = true


## LOCK_CONTROLS arrives. The step below only ever reads what these left.
func apply_command(cmd: Dictionary) -> void:
	if not lock.locked():
		return
	_keys = cmd.keys
	_aim = cmd.aim
	_fire = cmd.fire
	_yaw_deg = cmd.yaw_deg
	if cmd.tap:
		_tap = true


func _let_go() -> void:
	lock.release()
	if _player_driving:
		operator.input_enabled = true
	operator.scripted = {}
	if operator.remote:
		_drive_remote(Vector2.ZERO, false, false)
	_player_driving = false


func release() -> void:
	if lock.locked():
		_let_go()


## Keys and the mouse (or `scripted`) become this step's LOCK_CONTROLS. A remote operator's client sends its own.
func _send_local_controls() -> void:
	if operator.remote:
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
	_send(Commands.lock_controls(operator.player_id, keys, aim, fire, _click, operator.move_yaw_deg))
	_click = false


func _send(cmd: Dictionary) -> void:
	if operator.send_command.is_valid():
		operator.send_command.call(cmd)


func _drive_remote(keys: Vector2, crouch: bool, fire: bool) -> void:
	_send(Commands.move(operator.player_id, keys, false, _yaw_deg))
	_send(Commands.crouch(operator.player_id, crouch))
	_send(Commands.fire(operator.player_id, fire))


func step(delta: float) -> void:
	if not lock.locked():
		return
	_send_local_controls()
	if _fire or _tap:
		_aim_hold = float(lock.cfg.aim_hold_s)
	_aim_hold = maxf(_aim_hold - delta, 0.0)
	var move := lock.step(delta, OperatorModel.wish_from_keys(_keys, _yaw_deg), _aim or _fire or _aim_hold > 0.0)
	if not lock.locked():
		_let_go()
		return
	var held := lock.hold_position(_flat())
	if not lock.locked():
		_let_go()
		return
	operator.global_position = Vector3(held.x, 0.0, held.y)
	var shoot: bool = (_fire or _tap) and lock.can_fire()
	if shoot:
		_tap = false
	var body_keys := move.rotated(deg_to_rad(_yaw_deg))
	if operator.remote:
		_drive_remote(body_keys, true, shoot)
	else:
		operator.scripted = {"keys": body_keys, "crouch": true, "fire": shoot}
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
