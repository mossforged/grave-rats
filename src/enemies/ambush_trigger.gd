extends RefCounted
## Scene-free rule of the bulkhead ambush: fires once, only after the player has passed the panel
## and only with the panel behind their aim. Numbers from data/enemies.json "ambush".

var cfg: Dictionary
var panel := Vector2.ZERO
var pass_dir := Vector2.ZERO
var fired := false


func _init(config: Dictionary, panel_at: Vector2) -> void:
	cfg = config
	panel = panel_at
	pass_dir = Vector2(float(cfg.pass_dir[0]), float(cfg.pass_dir[1])).normalized()


func reset() -> void:
	fired = false


func would_fire(player: Vector2, aim_dir: Vector2) -> bool:
	if fired:
		return false
	var away := player - panel
	if away.dot(pass_dir) < float(cfg.past_m) or away.length() > float(cfg.max_range_m):
		return false
	return rad_to_deg(absf(aim_dir.angle_to(-away))) >= float(cfg.behind_deg)


## True the one step it fires.
func check(player: Vector2, aim_dir: Vector2) -> bool:
	if not would_fire(player, aim_dir):
		return false
	fired = true
	return true
