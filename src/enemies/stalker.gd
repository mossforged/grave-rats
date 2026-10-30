extends CharacterBody3D
## One stalker in the world: StalkerBrain plus body, collision, path following. The pack feeds it
## its senses and turns its events into spits and hits. It moves before the player's next step.

const StalkerBrain := preload("res://src/enemies/stalker_brain.gd")
const StalkerBody := preload("res://src/enemies/stalker_body.gd")
const SightTarget := preload("res://src/sight/sight_target.gd")

signal was_shot(stalker: Node3D, damage: float, from: Vector2)

var brain: StalkerBrain
var cfg: Dictionary
var spec: Dictionary
var body: StalkerBody
var label := ""
var home := Vector2.ZERO
var patrol: Array = []
var stalk_point := Vector2.ZERO
var path := PackedVector2Array()
var side := 1.0

var _repath_left := 0.0
var _replan_left := 0.0
var _cs: CollisionShape3D


func setup(config: Dictionary, entry: Dictionary, at: Vector2, patrol_points: Array, side_sign: float) -> void:
	cfg = config
	spec = entry
	label = String(entry.name)
	home = at
	patrol = patrol_points
	side = side_sign
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CapsuleShape3D.new()
	shape.radius = float(cfg.radius_m)
	shape.height = maxf(float(cfg.height_m), shape.radius * 2.0)
	_cs = CollisionShape3D.new()
	_cs.shape = shape
	_cs.position.y = shape.height * 0.5
	add_child(_cs)
	body = StalkerBody.new()
	body.name = "Body"
	add_child(body)
	body.setup(cfg)
	var st := SightTarget.new()
	st.name = "SightTarget"
	add_child(st)
	reset()


func reset() -> void:
	brain = StalkerBrain.new(cfg, patrol, bool(spec.get("dormant", false)), deg_to_rad(float(spec.get("yaw_deg", 0.0))))
	global_position = Vector3(home.x, 0.0, home.y)
	velocity = Vector3.ZERO
	stalk_point = home
	path = PackedVector2Array()
	_repath_left = 0.0
	_replan_left = 0.0
	_cs.disabled = false
	body.show_state(1.0, brain)
	body.rotation.y = brain.yaw


func floor_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func mouth() -> Vector3:
	return Vector3(global_position.x, float(cfg.mouth_m), global_position.z)


## ShotTracer contract: where a round can find it.
func shot_disc() -> Dictionary:
	if not brain.alive() or brain.state == StalkerBrain.State.DORMANT:
		return {}
	return {"center": floor_position(), "radius": float(cfg.hit_radius_m), "height": float(cfg.torso_m)}


## Rifle contract. `hit` has damage, and origin when it came from the rifle.
func take_hit(hit: Dictionary) -> void:
	var from := floor_position()
	if hit.has("origin"):
		var o: Vector3 = hit.origin
		from = Vector2(o.x, o.z)
	var dealt := brain.take_hit(float(hit.damage), from)
	if dealt > 0.0:
		was_shot.emit(self, dealt, from)
	if not brain.alive():
		_cs.disabled = true


## Puts it at `from`, facing `at` and hunting it (captures, tests).
func place_hunting(from: Vector2, at: Vector2) -> void:
	global_position = Vector3(from.x, 0.0, from.y)
	brain.force_hunt(from, at)
	stalk_point = from
	_replan_left = float(cfg.stalk.replan_s)


## One step, given the pack's senses builder. Returns the brain's events.
func simulate(delta: float, pack: Node) -> Array:
	if brain.state == StalkerBrain.State.DORMANT or not brain.alive():
		body.show_state(delta, brain)
		return []
	var pos := floor_position()
	_replan_left -= delta
	if brain.state == StalkerBrain.State.STALK and _replan_left <= 0.0:
		_replan_left = float(cfg.stalk.replan_s)
		stalk_point = pack.next_stalk_point(self)
		_repath_left = 0.0
	if brain.wants_move:
		_repath_left -= delta
		if _repath_left <= 0.0 or path.is_empty():
			_repath_left = float(cfg.nav.repath_s)
			path = pack.nav.path(pos, brain.goal)
	var s: Dictionary = pack.senses_for(self)
	s.next_point = _next_point(pos)
	s.stalk_point = stalk_point
	var events: Array = brain.step(delta, s)
	velocity = Vector3(brain.velocity.x, 0.0, brain.velocity.y)
	move_and_slide()
	global_position.y = 0.0
	body.rotation.y = brain.yaw
	body.show_state(delta, brain)
	return events


## A few cells ahead on the path, dropping points already passed.
func _next_point(pos: Vector2) -> Vector2:
	var cell := float(cfg.nav.cell_m)
	var k := 0
	while k < path.size() and path[k].distance_to(pos) < cell:
		k += 1
	if k >= path.size():
		return brain.goal
	return path[mini(k + int(cfg.nav.lookahead_cells) - 1, path.size() - 1)]
