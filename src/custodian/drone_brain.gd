extends RefCounted
## Scene-free patrol drone. One rule: break its spotlight's line of sight before its call completes, or it
## brings reinforcements. One tell: the cone, three roof bars filling in order, a rising chirp. It never
## attacks, it's slow, and a few rounds end it. data/custodian.json "drone".

enum State { DORMANT, PATROL, CALL, DEAD }

const EV_CALL_START := "call_start"
const EV_CALL_BROKEN := "call_broken"
const EV_CALLED := "called"
const EV_BAR := "bar"
const EV_DESTROYED := "destroyed"

var cfg: Dictionary
var route: Array
var state := State.DORMANT
var pos := Vector2.ZERO
var yaw := 0.0
var health := 0.0
var target_id := -1
var calling_for := 0.0

var _start := Vector2.ZERO
var _leg := 0
var _reacquire := 0.0
var _cooldown := 0.0
var _bars_shown := 0


func _init(config: Dictionary, at: Vector2, waypoints: Array) -> void:
	cfg = config
	_start = at
	route = waypoints
	reset()


func reset() -> void:
	state = State.DORMANT
	pos = _start
	yaw = 0.0
	health = float(cfg.health)
	target_id = -1
	calling_for = 0.0
	_leg = 0
	_reacquire = 0.0
	_cooldown = 0.0
	_bars_shown = 0


func wake() -> bool:
	if state != State.DORMANT:
		return false
	state = State.PATROL
	return true


func awake() -> bool:
	return state == State.PATROL or state == State.CALL


func alive() -> bool:
	return state != State.DEAD


func calling() -> bool:
	return state == State.CALL


func call_share() -> float:
	return clampf(calling_for / float(cfg.call_s), 0.0, 1.0)


## How many of the roof bars are lit: one, then two, then three, as the call fills.
func bars_lit() -> int:
	if state != State.CALL:
		return 0
	return mini(int(cfg.bars), floori(call_share() * float(cfg.bars)) + 1)


func eye() -> Vector3:
	return Vector3(pos.x, float(cfg.eye_height_m), pos.y)


## In its spotlight: in range, inside the cone it's pointing, and the guns' trace is clear to the torso.
func spot_sees(player: Dictionary, trace: Callable) -> bool:
	if not bool(player.alive):
		return false
	var to: Vector2 = (player.pos as Vector2) - pos
	if to.length() > float(cfg.spot_range_m):
		return false
	if absf(angle_difference(yaw, atan2(-to.x, -to.y))) > deg_to_rad(float(cfg.spot_half_deg)):
		return false
	return bool(trace.call(eye(), player.body).clear)


## Takes a round. Returns what it took.
func take_hit(damage: float) -> float:
	if state == State.DEAD:
		return 0.0
	var dealt := minf(damage, health)
	health -= dealt
	if health <= 0.0:
		state = State.DEAD
		calling_for = 0.0
		target_id = -1
	return dealt


## One step. `players`: [{id, pos: Vector2, body: Vector3, alive}]. `trace`: (from, to) -> {clear, point}.
func step(delta: float, players: Array, trace: Callable) -> Array:
	var events: Array = []
	_reacquire = maxf(_reacquire - delta, 0.0)
	_cooldown = maxf(_cooldown - delta, 0.0)
	match state:
		State.PATROL:
			_step_patrol(delta, players, trace, events)
		State.CALL:
			_step_call(delta, players, trace, events)
	return events


func _step_patrol(delta: float, players: Array, trace: Callable, events: Array) -> void:
	var goal: Vector2 = route[_leg]
	var to := goal - pos
	if to.length() <= float(cfg.arrive_m):
		_leg = (_leg + 1) % route.size()
	else:
		var want := atan2(-to.x, -to.y)
		yaw = rotate_toward(yaw, want, deg_to_rad(float(cfg.turn_deg_s)) * delta)
		if absf(angle_difference(yaw, want)) <= deg_to_rad(float(cfg.move_within_deg)):
			pos = pos.move_toward(goal, float(cfg.speed_m_s) * delta)
	if _reacquire > 0.0 or _cooldown > 0.0:
		return
	for p: Dictionary in players:
		if spot_sees(p, trace):
			state = State.CALL
			target_id = int(p.id)
			calling_for = 0.0
			_bars_shown = 0
			events.append({"type": EV_CALL_START, "player_id": target_id})
			_note_bars(events)
			return


## It stops and holds the light on you while the call goes through. Out of the light, the call's gone.
func _step_call(delta: float, players: Array, trace: Callable, events: Array) -> void:
	var p: Variant = null
	for candidate: Dictionary in players:
		if int(candidate.id) == target_id:
			p = candidate
	if p == null or not spot_sees(p, trace):
		events.append({"type": EV_CALL_BROKEN, "player_id": target_id})
		_end_call()
		_reacquire = float(cfg.reacquire_s)
		return
	var to: Vector2 = (p.pos as Vector2) - pos
	yaw = rotate_toward(yaw, atan2(-to.x, -to.y), deg_to_rad(float(cfg.track_deg_s)) * delta)
	calling_for += delta
	_note_bars(events)
	if calling_for >= float(cfg.call_s):
		events.append({"type": EV_CALLED, "player_id": target_id, "at": p.pos})
		_end_call()
		_cooldown = float(cfg.call_cooldown_s)


func _note_bars(events: Array) -> void:
	var lit := bars_lit()
	if lit > _bars_shown:
		_bars_shown = lit
		events.append({"type": EV_BAR, "bar": lit})


func _end_call() -> void:
	state = State.PATROL
	calling_for = 0.0
	target_id = -1
	_bars_shown = 0
