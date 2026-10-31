extends Node3D
## The rifle in the world: hitscan inside the cone, and the shot's flash, tracer, sound and effects (RifleFx,
## ShotTimeline). Holds the scene-free RifleState and AimCone; the owner calls tick() once per physics step.
## See src/weapons/CONTRACT.md.

signal fired(from: Vector3, to: Vector3, direction: Vector3, hit: Object)
signal blocked(reason: String)
signal reload_started
signal reload_finished
signal reload_cancelled

const RifleState := preload("res://src/weapons/rifle_state.gd")
const AimCone := preload("res://src/weapons/aim_cone.gd")
const RifleFx := preload("res://src/weapons/rifle_fx.gd")
const ShotTimeline := preload("res://src/weapons/shot_timeline.gd")
const SoundRules := preload("res://src/audio/sound_rules.gd")

var state: RifleState
var cone: AimCone
var fx: RifleFx
var timeline := ShotTimeline.new()
var trigger_held := false
var exclude: Array[RID] = []
## Optional: replaces the flat physics ray. (origin, dir, length) -> {} or {position, collider}.
var shot_tracer := Callable()

var _cfg: Dictionary
var _empty_reload := false
var _muzzle := Vector3.ZERO
var _facing := Vector3.FORWARD


func _ready() -> void:
	var w: Dictionary = Data.load_data("weapons")
	_cfg = w.rifle
	state = RifleState.new(_cfg)
	cone = AimCone.new(_cfg.cone)
	fx = RifleFx.new()
	fx.name = "Fx"
	add_child(fx)


## One physics step. `origin` is the ray start (centre of the body at gun height), `center_yaw`
## the gun's facing with recoil, `muzzle` where the tracer starts. Returns true if a shot went off.
func tick(delta: float, sprinting: bool, origin: Vector3, center_yaw: float, muzzle: Vector3) -> bool:
	_muzzle = muzzle
	_facing = Vector3(-sin(center_yaw), 0.0, -cos(center_yaw))
	timeline.step(delta, muzzle, _facing)
	var reload_was := state.reload_progress()
	match state.step(delta, sprinting):
		"finished":
			_reload_sounds(reload_was, 1.0)
			reload_finished.emit()
		"cancelled":
			reload_cancelled.emit()
		_:
			_reload_sounds(reload_was, state.reload_progress())
	if not trigger_held:
		return false
	var result := state.try_fire(sprinting)
	if result != RifleState.FIRED:
		if result == RifleState.BLOCKED_EMPTY:
			timeline.dry(global_position)
		if result != RifleState.BLOCKED_COOLDOWN:
			blocked.emit(result)
		return false
	_shoot(origin, state.shot_yaw(center_yaw, cone.spread_deg), muzzle)
	return true


func request_reload(sprinting: bool) -> bool:
	var was_empty := state.mag == 0
	var ok := state.start_reload(sprinting)
	if ok:
		_empty_reload = was_empty
		Audio.play("rifle_mag_out", global_position)
		timeline.drop_magazine(_muzzle, _facing)
		reload_started.emit()
	return ok


## One round with no trigger and no rules: the debug gallery's shot sequence.
func play_round(origin: Vector3, yaw: float, muzzle: Vector3) -> void:
	_shoot(origin, yaw, muzzle)


## The mag going in and, from empty, the charge, where data says they fall in the reload.
func _reload_sounds(before: float, after: float) -> void:
	for s: Dictionary in SoundRules.stages_crossed(Data.value("audio", "reload_stages"), before, after):
		if _empty_reload or not bool(s.get("only_empty", false)):
			Audio.play(String(s.cue), global_position)


func _space() -> String:
	var owner_node := get_parent()
	if owner_node == null or not ("space_at" in owner_node) or not owner_node.space_at.is_valid():
		return ""
	return String(owner_node.space_at.call(Vector2(global_position.x, global_position.z)))


func _shoot(origin: Vector3, yaw: float, muzzle: Vector3) -> void:
	var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var to := origin + dir * float(_cfg.range_m)
	var hit: Dictionary
	if shot_tracer.is_valid():
		hit = shot_tracer.call(origin, dir, float(_cfg.range_m))
	else:
		var query := PhysicsRayQueryParameters3D.create(origin, to)
		query.exclude = exclude
		hit = get_world_3d().direct_space_state.intersect_ray(query)
	var target: Object = null
	if not hit.is_empty():
		to = hit.position
		target = hit.collider
		if target != null and target.has_method("take_hit"):
			target.take_hit({"point": to, "direction": dir, "damage": float(_cfg.damage), "origin": origin})
		timeline.land(target, to, hit.get("normal", -dir), dir, float(_cfg.damage))
	fx.shot(muzzle, to)
	timeline.shot(muzzle, dir, state.mag, _space(), Audio.following() == get_parent())
	fired.emit(muzzle, to, dir, target)
