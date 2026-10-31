extends RefCounted
## Scene-free noise ring: how far you can be heard right now, for the ring on the floor. Radii are
## read straight from the enemies' `senses`, the same dictionary their ears use, never copied.
## Timings and looks: data/hud.json "ring".

var cfg: Dictionary
var senses: Dictionary
var kind := ""            # what your feet are doing: "", "walk", "crouch", "sprint"
var radius := 0.0         # metres: where the ring is
var ripple := -1.0        # metres: a pulse running out from a shot; below zero when there's none

var _hold_left := 0.0
var _blooming := false
var _bloom_kind := "gunfire"


func _init(ring_cfg: Dictionary, enemy_senses: Dictionary) -> void:
	cfg = ring_cfg
	senses = enemy_senses


## The hearing radius for a noise: 0 for no noise at all.
func heard_at(noise_kind: String) -> float:
	return 0.0 if noise_kind == "" else float(senses[noise_kind + "_m"])


func reset() -> void:
	kind = ""
	radius = 0.0
	ripple = -1.0
	_hold_left = 0.0
	_blooming = false


## A shot: out to the gunfire radius, and a new pulse if the last has run far enough. Anything else
## that loud (a dropped pod) names its own radius.
func fire(loud_kind := "gunfire") -> void:
	_bloom_kind = loud_kind
	_blooming = true
	_hold_left = float(cfg.bloom_s) + float(cfg.hold_s)
	if ripple < 0.0 or ripple >= float(cfg.ripple_restart_m):
		ripple = 0.0


func step(delta: float, feet_kind: String) -> void:
	kind = feet_kind
	var gun := heard_at("gunfire")
	if ripple >= 0.0:
		ripple += gun / float(cfg.bloom_s) * delta
		if ripple >= gun:
			ripple = -1.0
	_hold_left = maxf(_hold_left - delta, 0.0)
	if _blooming:
		var loud := heard_at(_bloom_kind)
		radius = move_toward(radius, loud, loud / float(cfg.bloom_s) * delta)
		if _hold_left == 0.0:
			_blooming = false
		return
	var want := heard_at(kind)
	var rate := float(cfg.swell_m_s) if want > radius else gun / float(cfg.shrink_s)
	radius = move_toward(radius, want, rate * delta)


## How strongly a ring at `at_radius` shows: faint for a walk, stronger up to a gunshot.
func alpha_at(at_radius: float) -> float:
	var a: Dictionary = cfg.alpha
	var quiet := heard_at("walk")
	var loud := heard_at("sprint")
	if at_radius <= quiet:
		return float(a.walk)
	if at_radius <= loud:
		return lerpf(float(a.walk), float(a.sprint), inverse_lerp(quiet, loud, at_radius))
	return lerpf(float(a.sprint), float(a.gunfire), inverse_lerp(loud, heard_at("gunfire"), at_radius))


## Cold when quiet, warm when loud: 0 at a walk, 1 at the gunfire radius.
func heat_at(at_radius: float) -> float:
	return clampf(inverse_lerp(heard_at("walk"), heard_at("gunfire"), at_radius), 0.0, 1.0)
