extends RefCounted
## Scene-free cutter turret. One rule: it needs a clear line to you, and tall cover breaks it. One tell:
## a line that sweeps, swings onto you and stays there, and a ring that fills, before the burn. It only
## ever asks `trace`, the guns' 3D trace, and it asks on the very step it fires. data/custodian.json "cutter".

const Visibility := preload("res://src/sight/visibility.gd")

enum State { DORMANT, SWEEP, AIM, BURN, COOL }

const EV_AIM := "aim"
const EV_CANCEL := "cancel"
const EV_BURN := "burn"
const EV_HIT := "hit"

var cfg: Dictionary
var mount: Vector3
var home_yaw := 0.0
var arc_half := 0.0
var state := State.DORMANT
var yaw := 0.0
var warm := 0.0
var target_id := -1
## How long it's been burning. Damage lands once a burn, per player.
var burn_left := 0.0

var _offset := 0.0
var _sweep_dir := 1.0
var _hold := 0.0
var _cool := 0.0
var _hit: Array = []


func _init(config: Dictionary, at: Vector2, home_yaw_deg: float, arc_half_deg: float) -> void:
	cfg = config
	mount = Vector3(at.x, float(cfg.mount_height_m), at.y)
	home_yaw = deg_to_rad(home_yaw_deg)
	arc_half = deg_to_rad(arc_half_deg)
	reset()


func reset() -> void:
	state = State.DORMANT
	yaw = home_yaw
	warm = 0.0
	target_id = -1
	burn_left = 0.0
	_offset = 0.0
	_sweep_dir = 1.0
	_hold = 0.0
	_cool = 0.0
	_hit = []


func wake() -> bool:
	if state != State.DORMANT:
		return false
	state = State.SWEEP
	return true


func awake() -> bool:
	return state != State.DORMANT


## Its line shows now. Whenever it's aiming at someone, this holds.
func line_on() -> bool:
	return state == State.SWEEP or state == State.AIM or state == State.BURN


func aiming() -> bool:
	return state == State.AIM


func burning() -> bool:
	return state == State.BURN


func warm_share() -> float:
	return clampf(warm / float(cfg.warmup_s), 0.0, 1.0)


## Where its aim point on a body is. Above low cover and from above it, so low cover never gets in the
## way: that's geometry, not an exception. Tall cover has no top.
func aim_point(player: Dictionary) -> Vector3:
	var body: Vector3 = player.body
	return Vector3(body.x, maxf(body.y, float(cfg.aim_floor_m)), body.z)


## Can it reach this player right now? In range, in its arc, with a clear line.
func can_see(player: Dictionary, trace: Callable) -> bool:
	if not bool(player.alive):
		return false
	var to: Vector2 = (player.pos as Vector2) - _plan()
	if to.length() > float(cfg.range_m):
		return false
	if absf(angle_difference(home_yaw, atan2(-to.x, -to.y))) > arc_half:
		return false
	return bool(trace.call(mount, aim_point(player)).clear)


## The end of its line before anything stops it: toward its yaw, `reach` away, at aim height.
func far_point(reach: float) -> Vector3:
	var p := _plan() + Visibility.yaw_dir2(yaw) * reach
	return Vector3(p.x, float(cfg.aim_floor_m), p.y)


## How far its line reaches now: to the target while aiming, otherwise its full range.
func line_reach(players: Array) -> float:
	if state == State.AIM:
		var p: Variant = _player(players, target_id)
		if p != null:
			return ((p.pos as Vector2) - _plan()).length()
	return float(cfg.range_m)


## One step. `players`: [{id, pos: Vector2, body: Vector3, alive}]. `trace`: (from, to) -> {clear, point}.
func step(delta: float, players: Array, trace: Callable) -> Array:
	var events: Array = []
	match state:
		State.SWEEP:
			_step_sweep(delta, players, trace, events)
		State.AIM:
			_step_aim(delta, players, trace, events)
		State.BURN:
			_step_burn(delta, players, trace, events)
		State.COOL:
			_cool -= delta
			if _cool <= 0.0:
				_back_to_sweep()
	return events


func _step_sweep(delta: float, players: Array, trace: Callable, events: Array) -> void:
	_offset += _sweep_dir * deg_to_rad(float(cfg.sweep_deg_s)) * delta
	if absf(_offset) >= arc_half:
		_offset = clampf(_offset, -arc_half, arc_half)
		_sweep_dir = -_sweep_dir
	yaw = home_yaw + _offset
	_hold -= delta
	if _hold > 0.0:
		return
	var best: Variant = null
	var best_d := INF
	for p: Dictionary in players:
		var d := ((p.pos as Vector2) - _plan()).length()
		if d < best_d and can_see(p, trace):
			best = p
			best_d = d
	if best != null:
		state = State.AIM
		target_id = int(best.id)
		warm = 0.0
		events.append({"type": EV_AIM, "player_id": target_id})


## The ring only fills with the line on you. Lose the line and it's over, right there.
func _step_aim(delta: float, players: Array, trace: Callable, events: Array) -> void:
	var p: Variant = _player(players, target_id)
	if p == null or not can_see(p, trace):
		events.append({"type": EV_CANCEL, "player_id": target_id})
		_hold = float(cfg.cancel_hold_s)
		_back_to_sweep()
		return
	var to: Vector2 = (p.pos as Vector2) - _plan()
	var want := atan2(-to.x, -to.y)
	var rate: float = cfg.track_deg_s if warm > 0.0 else cfg.slew_deg_s
	yaw = rotate_toward(yaw, want, deg_to_rad(rate) * delta)
	if absf(angle_difference(yaw, want)) > deg_to_rad(float(cfg.aligned_deg)):
		return
	warm += delta
	if warm < float(cfg.warmup_s):
		return
	state = State.BURN
	burn_left = float(cfg.burn_s)
	_hit = []
	events.append({"type": EV_BURN, "player_id": target_id})
	_burn_contact(players, trace, events)


func _step_burn(delta: float, players: Array, trace: Callable, events: Array) -> void:
	_burn_contact(players, trace, events)
	burn_left -= delta
	if burn_left <= 0.0:
		state = State.COOL
		_cool = float(cfg.cool_s)
		warm = 0.0
		target_id = -1


## The beam doesn't follow you. Anyone on its line, with nothing in the way, is burned once.
func _burn_contact(players: Array, trace: Callable, events: Array) -> void:
	var from := _plan()
	var to := from + Visibility.yaw_dir2(yaw) * float(cfg.range_m)
	for p: Dictionary in players:
		if _hit.has(p.id) or not bool(p.alive):
			continue
		var at: Vector2 = p.pos
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, from, to)) > float(cfg.hit_radius_m):
			continue
		if not can_see(p, trace):
			continue
		_hit.append(p.id)
		events.append({"type": EV_HIT, "player_id": int(p.id), "amount": float(cfg.damage)})


func _back_to_sweep() -> void:
	state = State.SWEEP
	warm = 0.0
	target_id = -1
	_offset = clampf(angle_difference(home_yaw, yaw), -arc_half, arc_half)


func _plan() -> Vector2:
	return Vector2(mount.x, mount.z)


func _player(players: Array, id: int) -> Variant:
	for p: Dictionary in players:
		if int(p.id) == id:
			return p
	return null
