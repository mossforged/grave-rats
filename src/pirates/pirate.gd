extends CharacterBody3D
## One rival pirate in the world: PirateBrain plus the legacy operator recoloured, its rifle, its
## flashlight and its path. The squad feeds it senses and acts on its events.

const PirateBrain := preload("res://src/pirates/pirate_brain.gd")
const PirateLight := preload("res://src/pirates/pirate_light.gd")
const PirateRecolour := preload("res://src/pirates/pirate_recolour.gd")
const OperatorAnim := preload("res://src/player/operator_anim.gd")
const RifleFx := preload("res://src/weapons/rifle_fx.gd")
const SightTarget := preload("res://src/sight/sight_target.gd")
const MODEL := preload("res://assets/game/legacy/operator.glb")

signal was_shot(pirate: Node3D, damage: float, from: Vector2)

var brain: PirateBrain
var torso_height := 0.0
var cfg: Dictionary
var spec: Dictionary
var label := ""
var home := Vector2.ZERO
var loot: Array = []
var anim: OperatorAnim
var fx: RifleFx
var light: PirateLight
var path := PackedVector2Array()

var _visual: Node3D
var _cs: CollisionShape3D
var _muzzle_offset := Vector3.ZERO
var _repath_left := 0.0
var _lean := 0.0
var _tilt := 0.0


func setup(config: Dictionary, entry: Dictionary, at: Vector2, loot_points: Array, character_scale: float) -> void:
	cfg = config
	spec = entry
	label = String(entry.name)
	home = at
	loot = loot_points
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var r := float(cfg.radius_m) * character_scale
	var shape := CapsuleShape3D.new()
	shape.radius = r
	shape.height = maxf(float(cfg.height_m) * character_scale, r * 2.0)
	_cs = CollisionShape3D.new()
	_cs.shape = shape
	_cs.position.y = shape.height * 0.5
	add_child(_cs)
	_visual = MODEL.instantiate()
	_visual.name = "Model"
	add_child(_visual)
	_visual.scale = Vector3.ONE * character_scale
	var shotgun := _visual.find_child("Shotgun", true, false) as Node3D
	if shotgun:
		shotgun.visible = false
	PirateRecolour.apply(_visual, cfg.body.materials)
	anim = OperatorAnim.new()
	anim.name = "Anim"
	add_child(anim)
	anim.setup(_visual, cfg.weight.anim, String(cfg.rifle.muzzle_bone))
	anim.start()
	var o: Array = cfg.rifle.muzzle_bone_offset
	_muzzle_offset = Vector3(float(o[0]), float(o[1]), float(o[2]))
	fx = RifleFx.new()
	fx.name = "Fx"
	add_child(fx)
	light = PirateLight.new()
	light.name = "Light"
	add_child(light)
	light.setup(cfg.flashlight)
	var st := SightTarget.new()
	st.name = "SightTarget"
	add_child(st)
	reset()


func reset() -> void:
	brain = PirateBrain.new(cfg, loot, deg_to_rad(float(spec.get("yaw_deg", 0.0))))
	global_position = Vector3(home.x, 0.0, home.y)
	velocity = Vector3.ZERO
	path = PackedVector2Array()
	_repath_left = 0.0
	_cs.disabled = false
	_lean = 0.0
	_tilt = 0.0
	_visual.rotation = Vector3(0.0, brain.model.hips_yaw, 0.0)
	light.set_on(bool(cfg.flashlight.start_on))


func floor_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func muzzle_position() -> Vector3:
	return anim.skeleton.global_transform * anim.twist.weapon_pose * _muzzle_offset


## Where its rounds start: the centre of the body at gun height, as for the player.
func shot_origin() -> Vector3:
	return global_position + Vector3.UP * float(cfg.aim_height_m)


## ShotTracer contract. The squad knows the cover rules, so it fills in the torso height.
func shot_disc() -> Dictionary:
	if not brain.alive():
		return {}
	return {"center": floor_position(), "radius": float(cfg.hit_radius_m), "height": torso_height}


## Rifle contract.
func take_hit(hit: Dictionary) -> void:
	var dealt := brain.take_hit(float(hit.damage))
	if dealt <= 0.0:
		return
	_lean = float(cfg.body.hit_lean_deg)
	var from := floor_position()
	if hit.has("origin"):
		var o: Vector3 = hit.origin
		from = Vector2(o.x, o.z)
	was_shot.emit(self, dealt, from)
	if not brain.alive():
		_cs.disabled = true
		light.set_on(false)


## One step, given the squad's senses builder. Returns the brain's events.
func simulate(delta: float, squad: Node) -> Array:
	if not brain.alive():
		_show(delta)
		return []
	var pos := floor_position()
	if brain.wants_move or brain.state == brain.State.MOVE or brain.state == brain.State.LOOT:
		_repath_left -= delta
		if _repath_left <= 0.0 or path.is_empty():
			_repath_left = float(cfg.nav.repath_s)
			var to: Vector2 = brain.spot.hide if brain.state == brain.State.MOVE else brain.goal
			path = squad.nav.path(pos, to)
	var s: Dictionary = squad.senses_for(self)
	s.next_point = _next_point(pos)
	var events: Array = brain.step(delta, s)
	velocity = brain.model.velocity
	move_and_slide()
	global_position.y = 0.0
	_show(delta)
	return events


func _show(delta: float) -> void:
	var m = brain.model
	var shown := lerpf(1.0, float(cfg.fight.brace_crouch_shown), brain.brace)
	var upper := "aim"
	if brain.gun.reloading():
		upper = "reload"
	elif m.sprinting or brain.state == brain.State.LOOT:
		upper = "low"
	anim.update(m.leg_blend(), m.leg_time_scale(), m.crouch_time_scale(), m.crouch_amount * shown,
			m.torso_lead(), upper, brain.gun.reload_total)
	_visual.rotation.y = m.hips_yaw
	_lean = move_toward(_lean, 0.0, float(cfg.body.hit_lean_recover_deg_s) * delta)
	if not brain.alive():
		_tilt = move_toward(_tilt, float(cfg.body.dead_tilt_deg), float(cfg.body.dead_tilt_deg_s) * delta)
	_visual.rotation.x = deg_to_rad(_lean + _tilt)


func _next_point(pos: Vector2) -> Vector2:
	if path.is_empty():
		return pos
	var nearest := 0
	var best := INF
	for k in path.size():
		var d := path[k].distance_squared_to(pos)
		if d < best:
			best = d
			nearest = k
	var ahead := nearest + int(cfg.nav.lookahead_cells)
	return path[ahead] if ahead < path.size() else path[-1]
