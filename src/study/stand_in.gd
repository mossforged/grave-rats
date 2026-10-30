extends CharacterBody3D
## Walkable stand-in for the scale study: the legacy operator, WASD to move (screen-relative),
## faces `aim_point`. No shooting. Numbers from data/deck.json "stand_in"; size from character_scale.

const OPERATOR := preload("res://assets/game/legacy/operator.glb")

var move_yaw_deg := 0.0     # camera yaw, so W is always screen-up
var aim_point := Vector3.ZERO
var input_enabled := true
var character_scale := 1.0

var _cfg: Dictionary
var _model: Node3D
var _anim: AnimationPlayer
var _shape: CapsuleShape3D


func _ready() -> void:
	_cfg = Data.value("deck", "stand_in", {})
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_shape = CapsuleShape3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = _shape
	cs.name = "Collision"
	add_child(cs)
	_model = OPERATOR.instantiate()
	_model.name = "Model"
	add_child(_model)
	var gun := _model.find_child("Shotgun", true, false) as Node3D
	if gun:
		gun.visible = false
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	_anim.play("L_Idle")
	set_character_scale(float(Data.value("deck", "character_scale", 1.0)))


func radius() -> float:
	return float(_cfg.radius_m) * character_scale


func set_character_scale(s: float) -> void:
	character_scale = s
	_model.scale = Vector3.ONE * s
	_shape.radius = radius()
	_shape.height = maxf(float(_cfg.height_m) * s, radius() * 2.0)
	($Collision as Node3D).position.y = _shape.height * 0.5 + 0.02


## Horizontal unit vector the operator aims along (model faces -Z).
func aim_dir() -> Vector3:
	return -_model.global_basis.z


## Turns to face `aim_point` at once (captures and respawns).
func face_now(point: Vector3) -> void:
	aim_point = point
	var d := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if d.length() > 0.01:
		_model.rotation.y = atan2(-d.x, -d.z)


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if input_enabled:
		var v := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		if v.length() > 0.0:
			v = v.normalized().rotated(-deg_to_rad(move_yaw_deg))
			dir = Vector3(v.x, 0, v.y)
	velocity = dir * float(_cfg.speed_m_s)
	move_and_slide()
	global_position.y = 0.0
	var d := Vector3(aim_point.x - global_position.x, 0, aim_point.z - global_position.z)
	if d.length() > 0.2:
		var want := atan2(-d.x, -d.z)
		var step := deg_to_rad(float(_cfg.turn_deg_s)) * delta
		_model.rotation.y = rotate_toward(_model.rotation.y, want, step)
	var clip := "L_Run_F" if dir != Vector3.ZERO else "L_Idle"
	if _anim.current_animation != clip:
		_anim.play(clip, 0.15)
