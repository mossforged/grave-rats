extends RefCounted
## Scene-free weight of the operator: move speed and ramps, capped turning, the torso/hips split
## and the crouch. Numbers from data/player.json. The rule (docs/studies/2026-10-29-weight-without-lag.md):
## the intent responds the same step, the completion takes time.
##
## Yaw 0 faces -Z (screen-up) and grows counter-clockwise, as in Node3D.rotation.y.
## step() computes velocity and speed BEFORE anything moves. Animation reads those, never the
## distance actually travelled: the old prototype measured after the move and the walk never animated.

var cfg: Dictionary

var velocity := Vector3.ZERO   # commanded this step, before collision
var speed := 0.0               # velocity.length(), what the animation reads
var torso_yaw := 0.0           # where the gun faces (before recoil)
var hips_yaw := 0.0            # where the legs face
var aim_yaw := 0.0             # where the cursor is
var crouch_amount := 0.0       # 0 standing, 1 fully down
var sprinting := false
var turned_deg := 0.0          # how far the torso turned this step
var hip_turn_deg_s := 0.0      # how fast the hips turned this step (signed)
var speed_mult := 1.0          # what you're carrying: share of every top speed (src/salvage)
var can_sprint := true         # what you're carrying: no sprint with your hands full

var _firing_left := 0.0


func _init(config: Dictionary) -> void:
	cfg = config


## Screen-relative keys (x right, y down) to a world XZ direction.
static func wish_from_keys(keys: Vector2, camera_yaw_deg: float) -> Vector2:
	if keys.length() == 0.0:
		return Vector2.ZERO
	return keys.normalized().rotated(-deg_to_rad(camera_yaw_deg))


## Yaw of the horizontal direction from `from` to `to`.
static func yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(from.x - to.x, from.z - to.z)


## Horizontal unit vector of a yaw.
static func yaw_dir(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Aim yaw for a cursor at `point`, or the current aim while the cursor is on top of the body.
func aim_yaw_for(from: Vector3, point: Vector3) -> float:
	var flat := Vector2(point.x - from.x, point.z - from.z)
	if flat.length() < float(cfg.turn.aim_deadzone_m):
		return aim_yaw
	return yaw_to(from, point)


func face_now(yaw: float) -> void:
	aim_yaw = yaw
	torso_yaw = yaw
	hips_yaw = yaw


## Standing still and upright at once (respawns).
func reset_motion() -> void:
	velocity = Vector3.ZERO
	speed = 0.0
	crouch_amount = 0.0
	sprinting = false
	_firing_left = 0.0


## A shot went off: the slower firing turn rate holds for a moment.
func note_shot() -> void:
	_firing_left = float(cfg.turn.firing_hold_s)


func firing() -> bool:
	return _firing_left > 0.0


## 1 the moment a shot goes off, down to 0 as the firing hold runs out.
func firing_share() -> float:
	var hold := float(cfg.turn.firing_hold_s)
	return _firing_left / hold if hold > 0.0 else 0.0


func moving() -> bool:
	return speed > float(cfg.move.moving_threshold_m_s)


## The noise your feet make right now: a key into the enemies' `senses` ("sprint_m" and so on), or
## "" standing still. The AI hears this and the HUD's ring draws it.
func noise_kind() -> String:
	if not moving():
		return ""
	if sprinting:
		return "sprint"
	return "crouch" if crouch_amount >= 0.5 else "walk"


func current_turn_rate_deg() -> float:
	var t: Dictionary = cfg.turn
	var rate := lerpf(float(t.standing_deg_s), float(t.crouched_deg_s), crouch_amount)
	return minf(rate, float(t.firing_deg_s)) if firing() else rate


## Signed angle (rad) from the torso to the cursor.
func aim_error() -> float:
	return wrapf(aim_yaw - torso_yaw, -PI, PI)


## Top speed right now: a crouch or a stand-up in progress still holds you to the crouch speed.
func top_speed() -> float:
	var m: Dictionary = cfg.move
	if sprinting:
		return float(m.sprint_speed_m_s) * speed_mult
	return lerpf(float(m.walk_speed_m_s), float(m.crouch_speed_m_s), crouch_amount) * speed_mult


## One step. `wish` is a world XZ direction (length <= 1), `to_yaw` the cursor's yaw.
func step(delta: float, wish: Vector2, to_yaw: float, wants_crouch: bool, wants_sprint: bool) -> void:
	_firing_left = maxf(_firing_left - delta, 0.0)
	_step_crouch(delta, wants_crouch)
	sprinting = wants_sprint and can_sprint and wish.length() > 0.0 and not wants_crouch and crouch_amount == 0.0
	_step_velocity(delta, wish)
	_step_turn(delta, to_yaw)


func _step_crouch(delta: float, wants_crouch: bool) -> void:
	var c: Dictionary = cfg.crouch
	if wants_crouch:
		crouch_amount = move_toward(crouch_amount, 1.0, delta / maxf(float(c.down_s), delta))
	else:
		crouch_amount = move_toward(crouch_amount, 0.0, delta / maxf(float(c.stand_up_s), delta))


func _step_velocity(delta: float, wish: Vector2) -> void:
	var m: Dictionary = cfg.move
	var want := Vector3(wish.x, 0.0, wish.y) * top_speed()
	var rate: float
	if want.length() >= speed:
		rate = want.length() / maxf(float(m.accel_s), delta)
	else:
		rate = float(m.walk_speed_m_s) / maxf(float(m.decel_s), delta)
	velocity = velocity.move_toward(want, rate * delta)
	speed = velocity.length()


func _step_turn(delta: float, to_yaw: float) -> void:
	var t: Dictionary = cfg.turn
	aim_yaw = to_yaw
	var err := aim_error()
	var turn := minf(absf(err), deg_to_rad(current_turn_rate_deg()) * delta)
	torso_yaw = wrapf(torso_yaw + signf(err) * turn, -PI, PI)
	turned_deg = rad_to_deg(turn)
	var hips_before := hips_yaw
	# Planted feet stay until the torso runs out of lead; walking brings the hips back under it.
	if moving():
		hips_yaw = rotate_toward(hips_yaw, torso_yaw, deg_to_rad(float(t.hip_settle_deg_s)) * delta)
	var limit := deg_to_rad(float(t.torso_lead_deg))
	var lead := wrapf(torso_yaw - hips_yaw, -PI, PI)
	if absf(lead) > limit:
		hips_yaw = wrapf(torso_yaw - signf(lead) * limit, -PI, PI)
	hip_turn_deg_s = rad_to_deg(wrapf(hips_yaw - hips_before, -PI, PI)) / delta if delta > 0.0 else 0.0


## Signed torso lead over the hips (rad).
func torso_lead() -> float:
	return wrapf(torso_yaw - hips_yaw, -PI, PI)


## Move direction relative to the torso for the leg blend: x = right, y = forward, length = speed
## as a fraction of the walk speed, capped at 1.
func leg_blend() -> Vector2:
	var fwd := yaw_dir(torso_yaw)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var fraction := minf(speed / float(cfg.move.walk_speed_m_s), 1.0)
	if speed == 0.0:
		return Vector2.ZERO
	var d := velocity / speed
	return Vector2(d.dot(right), d.dot(fwd)) * fraction


## Clip play rate that matches the feet to the ground speed in the current direction, capped.
func leg_time_scale() -> float:
	var a: Dictionary = cfg.anim
	var b := leg_blend()
	var length := b.length()
	if length == 0.0:
		return 1.0
	var along := absf(b.y) / length
	var forward := float(a.clip_speed_forward_m_s) if b.y >= 0.0 else float(a.clip_speed_back_m_s)
	var clip_speed := lerpf(float(a.clip_speed_strafe_m_s), forward, along)
	var matched := minf(speed / clip_speed, float(a.max_time_scale))
	return lerpf(1.0, matched, length)


func crouch_time_scale() -> float:
	var a: Dictionary = cfg.anim
	var length := leg_blend().length()
	var matched := minf(speed / float(a.clip_speed_crouch_m_s), float(a.max_time_scale))
	return lerpf(1.0, matched, length)
