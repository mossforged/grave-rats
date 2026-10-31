extends "res://tools/t012_bots.gd"
## T015: T012's greedy and cautious bots through a whole shift, reading the cutter's tell: once the ring has
## been up REACT_S they make for the nearest place its line can't reach, dropping a heavy load if they
## wouldn't get there in time, and give it HIDE_S, there or on the way. Everything else is T012's bot, which reads no tell at all.
## Not a test: numbers for the handoff, beside tools/t012_bots.gd.
## usage: godot --headless --path . --fixed-fps 60 -s tools/t015_shift_bots.gd -- [seeds] [out.json]

const REACT_S := 0.3
const HIDE_S := 2.0
const ARRIVE_M := 0.5
const SPOT_RINGS := [1.0, 1.5, 2.2, 3.0, 4.0]
const SPOT_ANGLES := 16

var _ring_for := 0.0
var _hide_left := 0.0
var _hide_at := Vector2.INF


func _shift(bot: String, seed_value: int) -> Dictionary:
	_ring_for = 0.0
	_hide_left = 0.0
	return await super(bot, seed_value)


func _decide(bot: String) -> void:
	super(bot)
	_hide_left = maxf(_hide_left - DT, 0.0)
	if scene.suit.dead or op.control_held():
		return
	var pos: Vector2 = scene._eye()
	var cutter: Node3D = _cutter_on_me()
	_ring_for = _ring_for + DT if cutter != null else 0.0
	if cutter != null and _ring_for >= REACT_S and _hide_left <= 0.0:
		var spot: Variant = _hidden_spot(pos, cutter)
		if spot != null:
			_hide_at = spot
			_hide_left = HIDE_S
			var left: float = float(cutter.cfg.warmup_s) * (1.0 - cutter.brain.warm_share())
			if pos.distance_to(spot) > op.model.top_speed() * left:
				scene.drop_item()
	if _hide_left <= 0.0:
		return
	if pos.distance_to(_hide_at) <= ARRIVE_M:
		op.scripted["keys"] = Vector2.ZERO
		return
	var next := _hide_at
	for p: Vector2 in scene.pack.nav.path(pos, _hide_at):
		if pos.distance_to(p) > ARRIVE_M:
			next = p
			break
	op.scripted["keys"] = (next - pos).normalized().rotated(deg_to_rad(float(op.move_yaw_deg)))


func _cutter_on_me() -> Node3D:
	for c: Node3D in scene.custodian.cutters:
		if c.brain.aiming():
			return c
	return null


func _hidden_spot(pos: Vector2, cutter: Node3D) -> Variant:
	var trace: Callable = scene._custodian_trace.line
	var height := float(cutter.cfg.aim_floor_m)
	var best: Variant = null
	var best_d := INF
	for r: float in SPOT_RINGS:
		for i in SPOT_ANGLES:
			var p: Vector2 = pos + Vector2.from_angle(TAU * i / SPOT_ANGLES) * r
			if r >= best_d or not scene.pack.nav.is_free(p) or scene.pack.nav.path(pos, p).is_empty():
				continue
			if not bool(trace.call(cutter.brain.mount, Vector3(p.x, height, p.y)).clear):
				best = p
				best_d = r
	return best
