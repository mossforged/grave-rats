extends RefCounted
## Scene-free acid puddles: where, how big, how long, and the damage per second of standing in
## one. Overlaps don't stack. `dps` comes from data/health.json, size and life from whoever adds.

var dps := 0.0
var puddles: Array = []  # {id: int, at: Vector2, radius: float, life: float, left: float, owner: String}

var _next_id := 0


func _init(damage_per_s: float) -> void:
	dps = damage_per_s


func add(at: Vector2, radius: float, life: float, owner_name: String, max_count: int) -> Dictionary:
	_next_id += 1
	var p := {"id": _next_id, "at": at, "radius": radius, "life": life, "left": life, "owner": owner_name}
	puddles.append(p)
	while puddles.size() > max_count:
		puddles.pop_front()
	return p


func step(delta: float) -> void:
	for p: Dictionary in puddles:
		p.left = float(p.left) - delta
	puddles = puddles.filter(func(p: Dictionary) -> bool: return float(p.left) > 0.0)


func clear() -> void:
	puddles.clear()


## The puddle under `p`, or {}.
func puddle_at(p: Vector2) -> Dictionary:
	for q: Dictionary in puddles:
		if (q.at as Vector2).distance_to(p) <= float(q.radius):
			return q
	return {}


## Damage for standing at `p` for `delta` seconds.
func damage_at(p: Vector2, delta: float) -> float:
	return dps * delta if not puddle_at(p).is_empty() else 0.0
