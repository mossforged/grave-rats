extends RefCounted
## Scene-free stalker: senses to state, state to where it wants to go and how it turns.
## Numbers from data/enemies.json "stalker". See src/enemies/CONTRACT.md.
## Yaw 0 faces -Z, as in OperatorModel; points are world XZ in Vector2.

enum State { DORMANT, PROWL, INVESTIGATE, STALK, SPIT, LUNGE, RECOVER, DEAD }

const NAMES := ["dormant", "prowl", "investigate", "stalk", "spit", "lunge", "recover", "dead"]
const EV_SPIT := "spit"
const EV_LUNGE_START := "lunge_start"
const EV_LUNGE_HIT := "lunge_hit"
const EV_DIED := "died"

var cfg: Dictionary
var state := State.PROWL
var health := 0.0
var yaw := 0.0
var patrol: Array = []
var knows := false
var last_known := Vector2.ZERO
var goal := Vector2.ZERO
var wants_move := false
var velocity := Vector2.ZERO
var charging := false
var windup := 0.0  # 0..1 through the current wind-up; the glow and the lean read it
var flinch_left := 0.0
var flash_left := 0.0

var _patrol_i := 0
var _pause_left := 0.0
var _noise_left := 0.0
var _linger_left := 0.0
var _memory_left := 0.0
var _phase_left := 0.0
var _spit_cd := 0.0
var _lunge_cd := 0.0
var _charge_left := 0.0
var _charge_dir := Vector2.ZERO
var _vulnerable := false
var _hit_landed := false


func _init(config: Dictionary, patrol_points: Array, dormant := false, start_yaw := 0.0) -> void:
	cfg = config
	patrol = patrol_points
	health = float(cfg.health)
	yaw = start_yaw
	state = State.DORMANT if dormant else State.PROWL


static func yaw_dir(y: float) -> Vector2:
	return Vector2(-sin(y), -cos(y))


static func yaw_to(a: Vector2, b: Vector2) -> float:
	return atan2(a.x - b.x, a.y - b.y)


func state_name() -> String:
	return NAMES[state]


func alive() -> bool:
	return state != State.DEAD


## Knows where you are and means it: these are the shooters the HUD's mark counts.
func hunting() -> bool:
	return state == State.STALK or state == State.SPIT or state == State.LUNGE or state == State.RECOVER


func vulnerable() -> bool:
	return state == State.RECOVER and _vulnerable


## Forward cone with nothing between, or close enough to feel you. `plan_blocked` is walls, doors
## and tall cover; `cover_blocked` the 3D line from its eye to your torso past low cover.
static func perceives(config: Dictionary, from: Vector2, facing: float, player: Vector2,
		plan_blocked: bool, cover_blocked: bool) -> bool:
	if plan_blocked:
		return false
	var s: Dictionary = config.senses
	var to := player - from
	var d := to.length()
	if d <= float(s.close_sense_m):
		return true
	if cover_blocked or d > float(s.sight_range_m):
		return false
	return rad_to_deg(absf(angle_difference(facing, yaw_to(from, player)))) <= float(s.sight_half_angle_deg)


## The burst: it comes out knowing where you are.
func wake(player: Vector2) -> void:
	if state != State.DORMANT:
		return
	last_known = player
	_start_stalk()


## Straight into a state, for captures and tests.
func force_hunt(from: Vector2, at: Vector2) -> void:
	yaw = yaw_to(from, at)
	last_known = at
	state = State.STALK
	knows = true
	_memory_left = float(cfg.senses.memory_s)


func force_spit() -> void:
	state = State.SPIT
	_phase_left = float(cfg.spit.windup_s)


func force_lunge() -> void:
	state = State.LUNGE
	_phase_left = float(cfg.lunge.windup_s)
	_charge_left = 0.0
	_hit_landed = false


## A noise of `kind` ("gunfire", "sprint") at `at`. True if it heard.
func hear(kind: String, at: Vector2, from: Vector2) -> bool:
	if state == State.DORMANT or state == State.DEAD:
		return false
	if from.distance_to(at) > float(cfg.senses[kind + "_m"]):
		return false
	if state == State.PROWL or state == State.INVESTIGATE:
		_investigate(at)
	elif hunting():
		# Firing from hiding gives you away.
		last_known = at
		_memory_left = float(cfg.senses.memory_s)
	return true


## A rifle round. Returns the damage taken. A hit tells it where the shot came from.
func take_hit(damage: float, from: Vector2) -> float:
	if state == State.DEAD or state == State.DORMANT:
		return 0.0
	var dealt := damage * (float(cfg.vulnerable_damage_mult) if vulnerable() else 1.0)
	health -= dealt
	flinch_left = float(cfg.flinch.s)
	flash_left = float(cfg.flinch.flash_s)
	if health <= 0.0:
		state = State.DEAD
		wants_move = false
		velocity = Vector2.ZERO
		return dealt
	if state == State.PROWL or state == State.INVESTIGATE:
		last_known = from
		_start_stalk()
	return dealt


## One step. `s` holds: pos, player, alive (player), sees, clear (nothing tall on the plan to
## last_known), ground_clear (nothing at all at knee height to the player), next_point (the path's
## next point), stalk_point (the planner's latest). Returns the events of this step.
func step(delta: float, s: Dictionary) -> Array:
	var events: Array = []
	flinch_left = maxf(flinch_left - delta, 0.0)
	flash_left = maxf(flash_left - delta, 0.0)
	_spit_cd = maxf(_spit_cd - delta, 0.0)
	_lunge_cd = maxf(_lunge_cd - delta, 0.0)
	windup = 0.0
	charging = false
	velocity = Vector2.ZERO
	if state == State.DEAD or state == State.DORMANT:
		wants_move = false
		return events
	_update_awareness(delta, s)
	match state:
		State.PROWL:
			_step_prowl(delta, s)
		State.INVESTIGATE:
			_step_investigate(delta, s)
		State.STALK:
			_step_stalk(delta, s, events)
		State.SPIT:
			_step_spit(delta, s, events)
		State.LUNGE:
			_step_lunge(delta, s, events)
		State.RECOVER:
			_phase_left -= delta
			wants_move = false
			if _phase_left <= 0.0:
				if knows:
					_start_stalk()
				else:
					_investigate(last_known)
	_step_body(delta, s)
	return events


func _update_awareness(delta: float, s: Dictionary) -> void:
	if not bool(s.alive):
		knows = false
		_memory_left = 0.0
		if state != State.PROWL:
			state = State.PROWL
		return
	if bool(s.sees):
		last_known = s.player
		_memory_left = float(cfg.senses.memory_s)
		knows = true
		if state == State.PROWL or state == State.INVESTIGATE:
			_start_stalk()
		return
	_memory_left = maxf(_memory_left - delta, 0.0)
	if _memory_left == 0.0 and knows and state == State.STALK:
		knows = false
		_investigate(last_known)


func _start_stalk() -> void:
	if state != State.STALK and state != State.RECOVER:
		_spit_cd = maxf(_spit_cd, float(cfg.spit.first_delay_s))
		_lunge_cd = maxf(_lunge_cd, float(cfg.lunge.first_delay_s))
	state = State.STALK
	knows = true
	_memory_left = maxf(_memory_left, float(cfg.senses.memory_s))


func _investigate(at: Vector2) -> void:
	state = State.INVESTIGATE
	goal = at
	last_known = at
	_noise_left = float(cfg.investigate.timeout_s)
	_linger_left = float(cfg.investigate.linger_s)


func _step_prowl(delta: float, s: Dictionary) -> void:
	goal = patrol[_patrol_i]
	if (s.pos as Vector2).distance_to(goal) <= float(cfg.prowl.arrive_m):
		wants_move = false
		_pause_left -= delta
		if _pause_left <= 0.0:
			_patrol_i = (_patrol_i + 1) % patrol.size()
			_pause_left = float(cfg.prowl.pause_s)
		return
	wants_move = true


func _step_investigate(delta: float, s: Dictionary) -> void:
	_noise_left -= delta
	var there := (s.pos as Vector2).distance_to(goal) <= float(cfg.investigate.arrive_m)
	wants_move = not there and _noise_left > 0.0
	if not wants_move:
		_linger_left -= delta
		if _linger_left <= 0.0:
			state = State.PROWL


func _step_stalk(_delta: float, s: Dictionary, events: Array) -> void:
	goal = s.stalk_point
	wants_move = (s.pos as Vector2).distance_to(goal) > float(cfg.stalk.arrive_m)
	var pos: Vector2 = s.pos
	var d := pos.distance_to(s.player)
	if bool(s.sees) and bool(s.ground_clear) and d <= float(cfg.lunge.range_m) and _lunge_cd == 0.0:
		state = State.LUNGE
		_phase_left = float(cfg.lunge.windup_s)
		_hit_landed = false
		events.append(EV_LUNGE_START)
		return
	var to_known := pos.distance_to(last_known)
	if knows and bool(s.clear) and _spit_cd == 0.0 \
			and to_known >= float(cfg.spit.min_range_m) and to_known <= float(cfg.spit.max_range_m) \
			and rad_to_deg(absf(angle_difference(yaw, yaw_to(pos, last_known)))) <= float(cfg.spit.face_deg):
		state = State.SPIT
		_phase_left = float(cfg.spit.windup_s)


func _step_spit(delta: float, _s: Dictionary, events: Array) -> void:
	wants_move = false
	_phase_left -= delta
	windup = 1.0 - clampf(_phase_left / float(cfg.spit.windup_s), 0.0, 1.0)
	if _phase_left <= 0.0:
		events.append(EV_SPIT)
		_spit_cd = float(cfg.spit.cooldown_s)
		_recover(float(cfg.spit.recover_s), false)


func _step_lunge(delta: float, s: Dictionary, events: Array) -> void:
	wants_move = false
	if _charge_left <= 0.0 and _phase_left > 0.0:
		_phase_left -= delta
		windup = 1.0 - clampf(_phase_left / float(cfg.lunge.windup_s), 0.0, 1.0)
		if _phase_left <= 0.0:
			_charge_left = float(cfg.lunge.charge_m)
			_charge_dir = yaw_dir(yaw)
		return
	charging = true
	_charge_left -= float(cfg.lunge.speed_m_s) * delta
	velocity = _charge_dir * float(cfg.lunge.speed_m_s)
	if not _hit_landed and bool(s.ground_clear) and (s.pos as Vector2).distance_to(s.player) <= float(cfg.lunge.hit_reach_m):
		_hit_landed = true
		events.append(EV_LUNGE_HIT)
		_charge_left = 0.0
	if _charge_left <= 0.0:
		charging = false
		velocity = Vector2.ZERO
		_lunge_cd = float(cfg.lunge.cooldown_s)
		_recover(float(cfg.lunge.recover_s), true)


func _recover(seconds: float, vulnerable_now: bool) -> void:
	state = State.RECOVER
	_phase_left = seconds
	_vulnerable = vulnerable_now
	_charge_left = 0.0


## Turning and the forward walk. It walks where it faces, so a slow turn really is slow.
func _step_body(delta: float, s: Dictionary) -> void:
	var pos: Vector2 = s.pos
	match state:
		State.SPIT:
			_turn(delta, yaw_to(pos, last_known), float(cfg.turn.spit_deg_s))
		State.LUNGE:
			if not charging:
				_turn(delta, yaw_to(pos, s.player), float(cfg.turn.lunge_deg_s))
		State.RECOVER:
			pass
		State.STALK:
			var look: Vector2 = s.next_point if wants_move else last_known
			_turn(delta, yaw_to(pos, look), float(cfg.turn.stalk_deg_s))
			_walk(float(cfg.speed.stalk_m_s), s)
		State.INVESTIGATE:
			if wants_move:
				_turn(delta, yaw_to(pos, s.next_point), float(cfg.turn.investigate_deg_s))
			_walk(float(cfg.speed.investigate_m_s), s)
		State.PROWL:
			if wants_move:
				_turn(delta, yaw_to(pos, s.next_point), float(cfg.turn.prowl_deg_s))
			_walk(float(cfg.speed.prowl_m_s), s)


func _turn(delta: float, to_yaw: float, rate_deg_s: float) -> void:
	yaw = rotate_toward(yaw, to_yaw, deg_to_rad(rate_deg_s) * delta)


func _walk(speed: float, s: Dictionary) -> void:
	if not wants_move:
		return
	var pos: Vector2 = s.pos
	var along := maxf(yaw_dir(yaw).dot(((s.next_point as Vector2) - pos).normalized()), 0.0)
	var f := float(cfg.flinch.speed_factor) if flinch_left > 0.0 else 1.0
	velocity = yaw_dir(yaw) * speed * along * f
