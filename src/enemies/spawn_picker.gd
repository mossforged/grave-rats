extends RefCounted
## Scene-free: where a new stalker may come in. Never where any player can see, never close to one.


## The index of a spawn point, or -1 when none will do yet. `points` are floor positions, `viewers` one
## (p: Vector2) -> bool per player, `players` where each is, `used` the indices already taken.
static func pick(points: Array, viewers: Array, players: Array, used: Array, min_player_m: float, rng: RandomNumberGenerator) -> int:
	var fit := allowed(points, viewers, players, used, min_player_m)
	return -1 if fit.is_empty() else int(fit[rng.randi_range(0, fit.size() - 1)])


static func allowed(points: Array, viewers: Array, players: Array, used: Array, min_player_m: float) -> Array:
	var fit: Array = []
	for i in points.size():
		var p: Vector2 = points[i]
		if not used.has(i) and not _near(p, players, min_player_m) and not _seen(p, viewers):
			fit.append(i)
	return fit


static func _near(p: Vector2, players: Array, min_m: float) -> bool:
	for at: Vector2 in players:
		if p.distance_to(at) < min_m:
			return true
	return false


static func _seen(p: Vector2, viewers: Array) -> bool:
	for sees: Callable in viewers:
		if sees.call(p):
			return true
	return false
