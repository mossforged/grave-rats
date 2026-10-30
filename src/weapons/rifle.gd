extends Node3D
## The rifle in the world: hitscan inside the cone, muzzle flash, tracer, impact. Holds the
## scene-free RifleState and AimCone; the owner calls tick() once per physics step.
## See src/weapons/CONTRACT.md.

signal fired(from: Vector3, to: Vector3, direction: Vector3, hit: Object)
signal blocked(reason: String)
signal reload_started
signal reload_finished
signal reload_cancelled

const RifleState := preload("res://src/weapons/rifle_state.gd")
const AimCone := preload("res://src/weapons/aim_cone.gd")
const RifleFx := preload("res://src/weapons/rifle_fx.gd")

var state: RifleState
var cone: AimCone
var fx: RifleFx
var trigger_held := false
var exclude: Array[RID] = []
## Optional: replaces the flat physics ray. (origin, dir, length) -> {} or {position, collider}.
var shot_tracer := Callable()

var _cfg: Dictionary


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
	match state.step(delta, sprinting):
		"finished":
			reload_finished.emit()
		"cancelled":
			reload_cancelled.emit()
	if not trigger_held:
		return false
	var result := state.try_fire(sprinting)
	if result != RifleState.FIRED:
		if result != RifleState.BLOCKED_COOLDOWN:
			blocked.emit(result)
		return false
	_shoot(origin, state.shot_yaw(center_yaw, cone.spread_deg), muzzle)
	return true


func request_reload(sprinting: bool) -> bool:
	var ok := state.start_reload(sprinting)
	if ok:
		reload_started.emit()
	return ok


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
		fx.impact(to)
	fx.shot(muzzle, to)
	fired.emit(muzzle, to, dir, target)
