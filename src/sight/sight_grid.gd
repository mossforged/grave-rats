extends RefCounted
## Scene-free memory of the deck: a grid of cells, each UNKNOWN, REMEMBERED or VISIBLE. This is
## the rules' truth; the mask's smoother memory texture is drawn from the same polygons.
## Cells rather than rooms, because a sight polygon cuts rooms: seeing half a room should leave
## the other half unknown, and that half is the corner you fear.

enum { UNKNOWN, REMEMBERED, VISIBLE }

var origin := Vector2.ZERO
var cell := 1.0
var nx := 0
var nz := 0
var states := PackedByteArray()

var _visible_now := PackedInt32Array()


func _init(bounds: Rect2, cell_m: float) -> void:
	origin = bounds.position
	cell = cell_m
	nx = maxi(ceili(bounds.size.x / cell), 1)
	nz = maxi(ceili(bounds.size.y / cell), 1)
	states.resize(nx * nz)
	clear()


## Forgets everything (a new run).
func clear() -> void:
	states.fill(UNKNOWN)
	_visible_now.clear()


func state_at(p: Vector2) -> int:
	var x := int(floor((p.x - origin.x) / cell))
	var z := int(floor((p.y - origin.y) / cell))
	if x < 0 or z < 0 or x >= nx or z >= nz:
		return UNKNOWN
	return states[z * nx + x]


func count(state: int) -> int:
	return states.count(state)


## This update's sight: what was visible drops to remembered, then `poly` and `rects` go visible.
func update(poly: PackedVector2Array, rects: Array = []) -> void:
	for i: int in _visible_now:
		states[i] = REMEMBERED
	_visible_now.clear()
	_fill_polygon(poly)
	for r: Rect2 in rects:
		_fill_rect(r)


func _mark(i: int) -> void:
	if states[i] == VISIBLE:
		return
	states[i] = VISIBLE
	_visible_now.append(i)


## Scanline fill by cell centres (the polygon is a star, but this doesn't rely on it).
func _fill_polygon(poly: PackedVector2Array) -> void:
	var n := poly.size()
	if n < 3:
		return
	var crossings := {}
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		if a.y == b.y:
			continue
		if a.y > b.y:
			var t := a
			a = b
			b = t
		# Rows whose centre line is in [a.y, b.y).
		var z0 := maxi(ceili((a.y - origin.y) / cell - 0.5), 0)
		var z1 := mini(ceili((b.y - origin.y) / cell - 0.5) - 1, nz - 1)
		var slope := (b.x - a.x) / (b.y - a.y)
		for z in range(z0, z1 + 1):
			var line := origin.y + (z + 0.5) * cell
			if not crossings.has(z):
				crossings[z] = []
			crossings[z].append(a.x + (line - a.y) * slope)
	for z: int in crossings:
		var xs: Array = crossings[z]
		xs.sort()
		var row := z * nx
		for k in range(0, xs.size() - 1, 2):
			var x0 := maxi(ceili((float(xs[k]) - origin.x) / cell - 0.5), 0)
			var x1 := mini(ceili((float(xs[k + 1]) - origin.x) / cell - 0.5) - 1, nx - 1)
			for x in range(x0, x1 + 1):
				_mark(row + x)


func _fill_rect(r: Rect2) -> void:
	var x0 := maxi(int(floor((r.position.x - origin.x) / cell)), 0)
	var x1 := mini(int(floor((r.end.x - origin.x) / cell)), nx - 1)
	var z0 := maxi(int(floor((r.position.y - origin.y) / cell)), 0)
	var z1 := mini(int(floor((r.end.y - origin.y) / cell)), nz - 1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			_mark(z * nx + x)


## Line segments (pairs of points) along every boundary around cells in `state`. Debug drawing.
func boundary(state: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for z in nz:
		for x in nx:
			if states[z * nx + x] != state:
				continue
			var p := origin + Vector2(x, z) * cell
			if z == 0 or states[(z - 1) * nx + x] != state:
				out.append_array([p, p + Vector2(cell, 0)])
			if z == nz - 1 or states[(z + 1) * nx + x] != state:
				out.append_array([p + Vector2(0, cell), p + Vector2(cell, cell)])
			if x == 0 or states[z * nx + x - 1] != state:
				out.append_array([p, p + Vector2(0, cell)])
			if x == nx - 1 or states[z * nx + x + 1] != state:
				out.append_array([p + Vector2(cell, 0), p + Vector2(cell, cell)])
	return out
