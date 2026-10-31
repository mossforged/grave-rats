extends RefCounted
## Scene-free: which line of company copy gets printed. A line has `id`, and may have `requires` (facts
## that must be truthy), `weight` and `cooldown` (picks of its pool it sits out after printing). A small take
## on the rule-and-played system in docs/studies/2026-10-30-comparable-games.md.

var rng := RandomNumberGenerator.new()

var _played := {}    # line id -> the pool's count when it last printed
var _picks := {}     # pool name -> how many times it's been picked from


func forget() -> void:
	_played = {}
	_picks = {}


## Are this line's `requires` all truthy in `facts`?
static func meets(line: Dictionary, facts: Dictionary) -> bool:
	for key: String in line.get("requires", []):
		if not facts.get(key, false):
			return false
	return true


## The lines of `pool` allowed by `facts`.
static func allowed(pool: Array, facts: Dictionary) -> Array:
	return pool.filter(func(line: Dictionary) -> bool: return meets(line, facts))


func _rested(line: Dictionary, count: int) -> bool:
	if not _played.has(line.id):
		return true
	return count - int(_played[line.id]) > int(line.get("cooldown", 0))


func _mark(line: Dictionary, count: int) -> Dictionary:
	_played[line.id] = count
	return line


func _tick(pool_name: String) -> int:
	_picks[pool_name] = int(_picks.get(pool_name, 0)) + 1
	return int(_picks[pool_name])


## A weighted pick among rested lines. If all are resting, the one printed longest ago: this pool has
## to say something.
func pick(pool_name: String, pool: Array) -> Dictionary:
	var count := _tick(pool_name)
	if pool.is_empty():
		return {}
	var rested := pool.filter(func(line: Dictionary) -> bool: return _rested(line, count))
	if rested.is_empty():
		var oldest: Dictionary = pool[0]
		for line: Dictionary in pool:
			if int(_played[line.id]) < int(_played[oldest.id]):
				oldest = line
		return _mark(oldest, count)
	var total := 0.0
	for line: Dictionary in rested:
		total += float(line.get("weight", 1.0))
	var roll := rng.randf() * total
	for line: Dictionary in rested:
		roll -= float(line.get("weight", 1.0))
		if roll <= 0.0:
			return _mark(line, count)
	return _mark(rested[-1], count)


## The first rested line, or nothing: for the priority-ordered pools that may stay quiet.
func pick_first(pool_name: String, pool: Array) -> Dictionary:
	var count := _tick(pool_name)
	for line: Dictionary in pool:
		if _rested(line, count):
			return _mark(line, count)
	return {}
