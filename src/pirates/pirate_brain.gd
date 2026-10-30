extends RefCounted
## Scene-free pirate: the same weight as the player. It only ever asks an OperatorModel to move and
## turn, and a RifleState and AimCone to fire, with numbers from data/pirates.json in the same shape
## as data/player.json and data/weapons.json. See src/pirates/CONTRACT.md.

const OperatorModel := preload("res://src/player/operator_model.gd")
const RifleState := preload("res://src/weapons/rifle_state.gd")
const AimCone := preload("res://src/weapons/aim_cone.gd")
const Suit := preload("res://src/health/suit.gd")
const HitTally := preload("res://src/pirates/hit_tally.gd")
const Tactics := preload("res://src/pirates/squad_tactics.gd")

enum State { LOOT, MOVE, DOWN, RISE, BURST, LOWER, RELOAD, DEAD }

const NAMES := ["loot", "move", "down", "rise", "burst", "lower", "reload", "dead"]
const EV_SHOT := "shot"
const EV_RELOAD := "reload"
const EV_DIED := "died"
const EV_HURT := "hurt"

var cfg: Dictionary
var state := State.LOOT
var role := Tactics.Role.NONE
var model: OperatorModel
var gun: RifleState
var cone: AimCone
var suit: Suit
var rng := RandomNumberGenerator.new()
var spot := {}                 # {hide, fire, kind, id}
var goal := Vector2.ZERO
var wants_move := false
var brace := 0.0               # 0 down behind cover, 1 up at braced height
var fell_back := false
var loot: Array = []

var _tally: HitTally
var _loot_i := 0
var _pause_left := 0.0
var _sweep_t := 0.0
var _wait_left := 0.0
var _rounds_left := 0
var _peek_left := 0.0
var _home_yaw := 0.0
var _hurt_said := false


func _init(config: Dictionary, loot_points: Array, start_yaw := 0.0) -> void:
	cfg = config
	loot = loot_points
	model = OperatorModel.new(cfg.weight)
	model.face_now(start_yaw)
	gun = RifleState.new(cfg.rifle)
	cone = AimCone.new(cfg.rifle.cone)
	suit = Suit.new({"suit": {"max": cfg.health}, "stagger": cfg.stagger})
	var big := float(cfg.stagger.threshold_fraction) * float(cfg.health)
	_tally = HitTally.new(float(cfg.big_hit.window_s), big)
	_home_yaw = start_yaw
	rng.randomize()


func state_name() -> String:
	return NAMES[state]


func alive() -> bool:
	return state != State.DEAD


## Up over the cover: a shot at it finds its braced torso.
func exposed() -> bool:
	return brace >= float(cfg.fight.exposed_at)


func gun_yaw() -> float:
	return model.torso_yaw + deg_to_rad(gun.recoil_deg)


func hurt() -> bool:
	return suit.fraction() <= float(cfg.fight.fall_back_below)


func wants_fall_back() -> bool:
	return alive() and hurt() and not fell_back


## At its spot and settled behind it.
func dug_in() -> bool:
	return state == State.DOWN or state == State.RISE or state == State.BURST or state == State.LOWER or state == State.RELOAD


## Go here, in this role. A new spot breaks off whatever it was doing.
func order(new_role: int, new_spot: Dictionary) -> void:
	role = new_role
	if new_spot.is_empty() or (not spot.is_empty() and new_spot.hide == spot.hide):
		return
	spot = new_spot
	if alive():
		state = State.MOVE


## Back to work.
func stand_down() -> void:
	if not alive():
		return
	role = Tactics.Role.NONE
	spot = {}
	state = State.LOOT
	_pause_left = 0.0


## A round landed. Returns what the suit lost.
func take_hit(amount: float) -> float:
	if not alive():
		return 0.0
	var result: Dictionary = suit.take(amount, "rifle")
	if _tally.add(amount):
		suit.stagger_left = float(cfg.stagger.control_loss_s)
		cone.spread_deg = maxf(cone.spread_deg, float(cfg.stagger.cone_deg))
	if bool(result.died):
		state = State.DEAD
		wants_move = false
		model.reset_motion()
	return float(result.amount)


## One step. Senses: pos, next_point (towards `goal`), aim (where the gun should point),
## can_engage (it's worth coming up to fire). Returns events.
func step(delta: float, s: Dictionary) -> Array:
	var events: Array = []
	if not alive():
		return events
	suit.step(delta)
	_tally.step(delta)
	var pos: Vector2 = s.pos
	var aim: Vector2 = s.aim
	var wish := Vector2.ZERO
	var crouch := false
	var sprint := false
	var trigger := false
	wants_move = false
	match state:
		State.LOOT:
			var r := _step_loot(delta, pos, s)
			wish = r.wish
			crouch = r.crouch
			aim = r.aim
		State.MOVE:
			goal = spot.hide
			wants_move = true
			var d := pos.distance_to(goal)
			wish = pos.direction_to(s.next_point)
			sprint = d > float(cfg.fight.sprint_over_m)
			if sprint:
				aim = s.next_point
			if d <= float(cfg.fight.arrive_m):
				state = State.DOWN
				_wait_left = float(cfg.fight.first_gap_s)
		State.DOWN:
			crouch = true
			wish = _towards(pos, spot.hide)
			_wait_left -= delta
			if gun.mag <= int(cfg.fight.reload_below) and gun.start_reload(false):
				state = State.RELOAD
				events.append(EV_RELOAD)
			elif _wait_left <= 0.0 and bool(s.can_engage) and gun.mag > 0:
				state = State.RISE
				_peek_left = float(cfg.fight.peek_hold_s)
		State.RELOAD:
			crouch = true
			wish = _towards(pos, spot.hide)
			if not gun.reloading():
				state = State.DOWN
				_wait_left = 0.0
		State.RISE:
			crouch = true
			wish = _towards(pos, spot.fire)
			brace = move_toward(brace, 1.0, delta / maxf(float(cfg.fight.rise_s), delta))
			_peek_left -= delta
			if brace >= 1.0 and wish == Vector2.ZERO and _ready_to_fire(aim, pos):
				state = State.BURST
				_rounds_left = rng.randi_range(int(cfg.fight.burst_min), maxi(int(cfg.fight.burst_min), int(cfg.fight.burst_max)))
			elif _peek_left <= 0.0:
				_lower()
		State.BURST:
			crouch = true
			trigger = true
			if not bool(s.can_engage) and _rounds_left <= 0:
				_lower()
		State.LOWER:
			crouch = true
			wish = _towards(pos, spot.hide)
			brace = move_toward(brace, 0.0, delta / maxf(float(cfg.fight.lower_s), delta))
			if brace <= 0.0 and wish == Vector2.ZERO:
				state = State.DOWN
	if state != State.RISE and state != State.BURST and state != State.LOWER:
		brace = move_toward(brace, 0.0, delta / maxf(float(cfg.fight.lower_s), delta))
	# A stagger takes control away, exactly as Operator.hold_control does for you.
	if suit.staggered():
		wish = Vector2.ZERO
		sprint = false
		trigger = false
		aim = pos + _yaw_flat(model.aim_yaw)
	var from3 := Vector3(pos.x, 0.0, pos.y)
	var to_yaw := model.aim_yaw_for(from3, Vector3(aim.x, 0.0, aim.y))
	model.step(delta, wish, to_yaw, crouch, sprint)
	cone.step(delta, model.speed / float(cfg.weight.move.walk_speed_m_s), model.moving(), model.sprinting, model.turned_deg)
	gun.step(delta, model.sprinting)
	if trigger and gun.try_fire(model.sprinting) == RifleState.FIRED:
		model.note_shot()
		_rounds_left -= 1
		events.append(EV_SHOT)
	if state == State.BURST and (_rounds_left <= 0 or gun.mag <= 0):
		_lower()
	if not _hurt_said and hurt():
		_hurt_said = true
		events.append(EV_HURT)
	return events


func _lower() -> void:
	state = State.LOWER
	var f: Dictionary = cfg.fight
	var gap := float(f.support_gap_s)
	if role == Tactics.Role.SUPPRESS:
		gap = float(f.suppress_gap_s)
	elif role == Tactics.Role.FLANK:
		gap = float(f.flank_gap_s)
	_wait_left = gap * rng.randf_range(1.0 - float(f.gap_jitter), 1.0 + float(f.gap_jitter))


func _ready_to_fire(aim: Vector2, pos: Vector2) -> bool:
	var to := OperatorModel.yaw_to(Vector3(pos.x, 0.0, pos.y), Vector3(aim.x, 0.0, aim.y))
	var off := rad_to_deg(absf(angle_difference(model.torso_yaw, to)))
	return off <= float(cfg.fight.fire_within_deg) and cone.spread_deg <= float(cfg.fight.fire_spread_deg)


## A small walk to a point right here; nothing when it's near enough.
func _towards(pos: Vector2, point: Variant) -> Vector2:
	if pos.distance_to(point) <= float(cfg.fight.fire_point_m):
		return Vector2.ZERO
	return pos.direction_to(point)


func _yaw_flat(yaw: float) -> Vector2:
	var d := OperatorModel.yaw_dir(yaw)
	return Vector2(d.x, d.z)


## Walks between crates with its light sweeping, then squats over one for a while.
func _step_loot(delta: float, pos: Vector2, s: Dictionary) -> Dictionary:
	var l: Dictionary = cfg.loot
	_sweep_t += delta
	var sweep := deg_to_rad(float(l.sweep_deg)) * sin(TAU * float(l.sweep_hz) * _sweep_t)
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_loot_i = (_loot_i + 1) % loot.size()
		return {"wish": Vector2.ZERO, "crouch": true, "aim": pos + _yaw_flat(_home_yaw + sweep) * float(cfg.weight.turn.aim_deadzone_m) * 8.0}
	goal = loot[_loot_i]
	wants_move = true
	if pos.distance_to(goal) <= float(l.arrive_m):
		_pause_left = float(l.pause_s)
		_home_yaw = model.torso_yaw
		wants_move = false
		return {"wish": Vector2.ZERO, "crouch": false, "aim": pos + _yaw_flat(_home_yaw) * float(cfg.weight.turn.aim_deadzone_m) * 8.0}
	var next: Vector2 = s.next_point
	return {"wish": pos.direction_to(next) * float(l.walk_share), "crouch": false, "aim": next}
