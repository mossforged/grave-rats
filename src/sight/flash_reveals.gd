extends RefCounted
## Scene-free: moments when something lit itself up for the player, a muzzle flash above all. Each is a
## wall-clipped shape around a point that holds, then fades. It changes what's drawn and who's shown, not
## what the player knows: nothing here goes into memory. Refreshing by key keeps a burst one flash.

var flashes := {}


## `points` is the shape in world XZ, the first being its centre.
func add(key: Variant, at: Vector2, radius: float, points: PackedVector2Array, hold_s: float, fade_s: float) -> void:
	flashes[key] = {"at": at, "radius": radius, "points": points, "hold": hold_s, "fade": fade_s, "left": hold_s + fade_s}


func step(delta: float) -> void:
	for key: Variant in flashes.keys():
		flashes[key].left -= delta
		if flashes[key].left <= 0.0:
			flashes.erase(key)


func clear() -> void:
	flashes.clear()


## 1 while it holds, down to 0 as it fades.
static func strength(f: Dictionary) -> float:
	return clampf(float(f.left) / maxf(float(f.fade), 0.001), 0.0, 1.0)


## Is `p` lit by a flash right now?
func covers(p: Vector2) -> bool:
	for f: Dictionary in flashes.values():
		if p.distance_to(f.at) <= float(f.radius) and strength(f) > 0.0:
			return true
	return false
