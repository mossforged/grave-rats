extends CharacterBody3D
## The operator: reads intent (keys, or `scripted` for captures and tests), steps OperatorModel,
## moves, fires the rifle, drives the animation and the floor drawings. See src/player/CONTRACT.md.
## Order inside a step matters: speed and direction come from the model BEFORE move_and_slide.

const OperatorModel := preload("res://src/player/operator_model.gd")
const OperatorAnim := preload("res://src/player/operator_anim.gd")
const AimVisuals := preload("res://src/player/aim_visuals.gd")
const Rifle := preload("res://src/weapons/rifle.gd")
const MODEL := preload("res://assets/game/legacy/operator.glb")

var model: OperatorModel
var rifle: Rifle
var anim: OperatorAnim
var visuals: AimVisuals
var aim_point := Vector3.ZERO
var move_yaw_deg := 0.0        # camera yaw, so W is always screen-up
var input_enabled := true
## When input is off: "keys" (Vector2 screen-relative), "crouch", "sprint", "fire".
var scripted := {}
var anim_speed := 0.0          # speed the animation got this step

var _cfg: Dictionary
var _rifle_cfg: Dictionary
var _visual: Node3D
var _shape: CapsuleShape3D
var _muzzle_offset := Vector3.ZERO
var _trigger_tap := false


func _ready() -> void:
	_cfg = Data.load_data("player")
	_rifle_cfg = Data.value("weapons", "rifle", {})
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	model = OperatorModel.new(_cfg)
	_shape = CapsuleShape3D.new()
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = _shape
	add_child(cs)
	_visual = MODEL.instantiate()
	_visual.name = "Model"
	add_child(_visual)
	var shotgun := _visual.find_child("Shotgun", true, false) as Node3D
	if shotgun:
		shotgun.visible = false
	anim = OperatorAnim.new()
	anim.name = "Anim"
	add_child(anim)
	anim.setup(_visual, _cfg.anim, String(_rifle_cfg.muzzle_bone))
	anim.start()
	var o: Array = _rifle_cfg.muzzle_bone_offset
	_muzzle_offset = Vector3(float(o[0]), float(o[1]), float(o[2]))
	rifle = Rifle.new()
	rifle.name = "Rifle"
	add_child(rifle)
	rifle.exclude = [get_rid()]
	visuals = AimVisuals.new()
	visuals.name = "AimVisuals"
	add_child(visuals)
	set_character_scale(float(Data.value("deck", "character_scale", 1.0)))


func set_character_scale(s: float) -> void:
	_visual.scale = Vector3.ONE * s
	var r := float(_cfg.radius_m) * s
	_shape.radius = r
	_shape.height = maxf(float(_cfg.height_m) * s, r * 2.0)
	($Collision as Node3D).position.y = _shape.height * 0.5


## Horizontal facing of the gun including recoil (rad).
func gun_yaw() -> float:
	return model.torso_yaw + deg_to_rad(rifle.state.recoil_deg)


## Unit vector the gun faces, for the camera's look-ahead.
func aim_dir() -> Vector3:
	return OperatorModel.yaw_dir(gun_yaw())


## Tip of the barrel in the world.
func muzzle_position() -> Vector3:
	return anim.skeleton.global_transform * anim.twist.weapon_pose * _muzzle_offset


## How far a shot along `yaw` would fly from here.
func shot_reach(yaw: float) -> float:
	var origin := global_position + Vector3.UP * float(_cfg.aim_height_m)
	var length := float(_rifle_cfg.range_m)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + OperatorModel.yaw_dir(yaw) * length)
	query.exclude = rifle.exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return length if hit.is_empty() else origin.distance_to(hit.position)


func face_now(point: Vector3) -> void:
	aim_point = point
	model.face_now(OperatorModel.yaw_to(global_position, point))
	_apply_facing()


## R pressed (or a script asking). Starts this step: the upper body changes the same frame.
func request_reload() -> bool:
	return rifle.request_reload(model.sprinting)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_trigger_tap = true
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_R:
		request_reload()


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	simulate(delta)


## One whole step; public so tests can drive it with exact deltas.
func simulate(delta: float) -> void:
	var keys: Vector2 = scripted.get("keys", Vector2.ZERO)
	var crouch: bool = scripted.get("crouch", false)
	var sprint: bool = scripted.get("sprint", false)
	if input_enabled:
		keys = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		crouch = Input.is_physical_key_pressed(KEY_C) or Input.is_physical_key_pressed(KEY_CTRL)
		sprint = Input.is_physical_key_pressed(KEY_SHIFT)
		# A click shorter than a physics step still fires.
		rifle.trigger_held = _trigger_tap or (rifle.trigger_held and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		_trigger_tap = false
	else:
		rifle.trigger_held = scripted.get("fire", false)
	var wish := OperatorModel.wish_from_keys(keys, move_yaw_deg)
	model.step(delta, wish, model.aim_yaw_for(global_position, aim_point), crouch, sprint)
	# Everything the animation reads is fixed here, before the body moves.
	anim_speed = model.speed
	var walk := float(_cfg.move.walk_speed_m_s)
	rifle.cone.step(delta, model.speed / walk, model.moving(), model.sprinting, model.turned_deg)
	var origin := global_position + Vector3.UP * float(_cfg.aim_height_m)
	if rifle.tick(delta, model.sprinting, origin, gun_yaw(), muzzle_position()):
		model.note_shot()
	var upper := "aim"
	if rifle.state.reloading():
		upper = "reload"
	elif model.sprinting:
		upper = "low"
	anim.update(model.leg_blend(), model.leg_time_scale(), model.crouch_time_scale(),
			model.crouch_amount, model.torso_lead(), upper, rifle.state.reload_total)
	velocity = model.velocity
	move_and_slide()
	global_position.y = 0.0
	_apply_facing()
	visuals.draw(global_position, gun_yaw(), rifle.cone.spread_deg, model.aim_yaw, aim_point, shot_reach)


func _apply_facing() -> void:
	_visual.rotation.y = model.hips_yaw
