extends RefCounted
## Scene-free: which way the hits you couldn't see came from. Each is an arc around you that fades,
## coloured by what hit you. Directions are kept in the world, so the arc still points the right way if
## you've moved or the camera has. Numbers from data/hud.json "hit_direction".

var cfg: Dictionary
var arcs: Array = []  # {from: Vector2, source: String, left: float}


func _init(config: Dictionary) -> void:
	cfg = config


## A hit from world XZ point `from`. A second from the same source nearby refreshes the arc.
func add(from: Vector2, source: String) -> void:
	for a: Dictionary in arcs:
		if a.source == source and (a.from as Vector2).distance_to(from) <= float(cfg.merge_m):
			a.from = from
			a.left = float(cfg.life_s)
			return
	arcs.append({"from": from, "source": source, "left": float(cfg.life_s)})
	if arcs.size() > int(cfg.max_arcs):
		arcs.pop_front()


func step(delta: float) -> void:
	for a: Dictionary in arcs:
		a.left -= delta
	arcs = arcs.filter(func(a: Dictionary) -> bool: return float(a.left) > 0.0)


func reset() -> void:
	arcs.clear()


func color_for(source: String) -> Color:
	return Color(String((cfg.colors as Dictionary).get(source, cfg.colors.default)))


func alpha_of(arc: Dictionary) -> float:
	return clampf(float(arc.left) / float(cfg.fade_s), 0.0, 1.0)
