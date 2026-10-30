extends RefCounted
## Scene-free rifle: magazine and reserve, fire interval, recoil, camera kick, reload commitment.
## Numbers from data/weapons.json "rifle".
##
## Reload: starting one drops the magazine (its rounds go back to the reserve) and pulls the new
## one out of the reserve. It takes its full time. Pressing fire does nothing to it; sprinting
## cancels it and the new magazine is lost, leaving the gun empty.

const FIRED := "fired"
const BLOCKED_SPRINT := "sprinting"
const BLOCKED_RELOAD := "reloading"
const BLOCKED_EMPTY := "empty"
const BLOCKED_COOLDOWN := "cooldown"

var cfg: Dictionary
var rng := RandomNumberGenerator.new()

var mag := 0
var reserve := 0
var reload_left := 0.0
var reload_total := 0.0
var recoil_deg := 0.0          # signed yaw offset of the gun
var camera_kick_m := 0.0

var _incoming := 0
var _cooldown := 0.0
var _recoil_wait := 0.0
var _side := 1.0


func _init(config: Dictionary) -> void:
	cfg = config
	mag = int(cfg.magazine)
	reserve = int(cfg.reserve)
	rng.randomize()


## Full magazine and reserve, nothing in progress (respawns).
func refill() -> void:
	cancel_reload()
	mag = int(cfg.magazine)
	reserve = int(cfg.reserve)
	recoil_deg = 0.0
	camera_kick_m = 0.0


func reloading() -> bool:
	return reload_left > 0.0


func reload_progress() -> float:
	return 1.0 - reload_left / reload_total if reloading() else 0.0


## Time passes. Sprinting during a reload cancels it. Returns "finished", "cancelled" or "".
func step(delta: float, sprinting: bool) -> String:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_step_recoil(delta)
	if not reloading():
		return ""
	if sprinting:
		cancel_reload()
		return "cancelled"
	reload_left = maxf(reload_left - delta, 0.0)
	if not reloading():
		mag = _incoming
		_incoming = 0
		return "finished"
	return ""


## Tries to fire one round; returns FIRED or why not. Never touches a reload in progress.
func try_fire(sprinting: bool) -> String:
	if sprinting:
		return BLOCKED_SPRINT
	if reloading():
		return BLOCKED_RELOAD
	if _cooldown > 0.0:
		return BLOCKED_COOLDOWN
	if mag <= 0:
		return BLOCKED_EMPTY
	mag -= 1
	_cooldown = float(cfg.fire_interval_s)
	_kick()
	return FIRED


## Starts a reload if there is one to do (not sprinting, magazine not full, rounds left).
func start_reload(sprinting: bool) -> bool:
	if sprinting or reloading() or mag >= int(cfg.magazine) or reserve + mag <= 0:
		return false
	reserve += mag
	mag = 0
	_incoming = mini(int(cfg.magazine), reserve)
	reserve -= _incoming
	reload_total = float(cfg.reload_s)
	reload_left = reload_total
	return true


func cancel_reload() -> void:
	reload_left = 0.0
	_incoming = 0


## Yaw of one shot: uniform inside a cone of full angle `spread_deg` around `center_yaw`.
func shot_yaw(center_yaw: float, spread_deg: float) -> float:
	var half := deg_to_rad(spread_deg) * 0.5
	return center_yaw + rng.randf_range(-half, half)


func _kick() -> void:
	var r: Dictionary = cfg.recoil
	if rng.randf() > float(r.same_side_chance):
		_side = -_side
	var limit := float(r.max_deg)
	recoil_deg = clampf(recoil_deg + _side * float(r.kick_deg), -limit, limit)
	_recoil_wait = float(r.recover_delay_s)
	camera_kick_m = float(cfg.camera_kick.kick_m)


func _step_recoil(delta: float) -> void:
	var r: Dictionary = cfg.recoil
	_recoil_wait = maxf(_recoil_wait - delta, 0.0)
	if _recoil_wait == 0.0:
		recoil_deg = move_toward(recoil_deg, 0.0, float(r.recover_deg_s) * delta)
	var k: Dictionary = cfg.camera_kick
	var rate := float(k.kick_m) / maxf(float(k.recover_s), delta)
	camera_kick_m = move_toward(camera_kick_m, 0.0, rate * delta)
