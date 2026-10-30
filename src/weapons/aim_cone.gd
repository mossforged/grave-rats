extends RefCounted
## Scene-free aim-settle cone. `spread_deg` is the full angle of the cone; shots land uniformly
## inside it. Moving opens it toward wide (more with speed, never under the moving minimum),
## sprinting opens it further, turning adds to it per degree turned, and it closes from wide to
## tight over settle_s. Numbers from data/weapons.json "rifle.cone".

var cfg: Dictionary
var spread_deg := 0.0


func _init(config: Dictionary) -> void:
	cfg = config
	spread_deg = float(cfg.tight_deg)


## The spread this movement is heading for.
func target_deg(speed_fraction: float, moving: bool, sprinting: bool) -> float:
	if sprinting:
		return float(cfg.sprint_deg)
	if moving:
		return lerpf(float(cfg.moving_min_deg), float(cfg.wide_deg), clampf(speed_fraction, 0.0, 1.0))
	return float(cfg.tight_deg)


## `speed_fraction` is speed over walk speed; `turned_deg` is how far the body turned this step.
func step(delta: float, speed_fraction: float, moving: bool, sprinting: bool, turned_deg: float) -> void:
	var target := target_deg(speed_fraction, moving, sprinting)
	var wide := float(cfg.wide_deg)
	var close_rate := (wide - float(cfg.tight_deg)) / float(cfg.settle_s)
	spread_deg = minf(spread_deg + turned_deg * float(cfg.turn_open_per_deg), maxf(wide, spread_deg))
	if spread_deg < target:
		spread_deg = minf(spread_deg + float(cfg.open_deg_s) * delta, target)
	else:
		spread_deg = maxf(spread_deg - close_rate * delta, target)
	if moving:
		spread_deg = maxf(spread_deg, float(cfg.moving_min_deg))
