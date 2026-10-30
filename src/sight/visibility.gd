extends RefCounted
## Scene-free line of sight on the floor plane (world XZ as Vector2, x east, y = z south).
## Occluder footprints become outward-facing edges. The sight polygon is a star around the eye,
## cut from a shape that is a circle (awareness) plus a wedge (the cone). Numbers: data/sight.json.

var cfg: Dictionary

# Edges of the static occluders: start and end, with the wall's outside on the left of a -> b.
var _ax := PackedFloat64Array()
var _az := PackedFloat64Array()
var _bx := PackedFloat64Array()
var _bz := PackedFloat64Array()
var _static_count := 0
var _owner := PackedInt32Array()  # index into dynamic rects, or -1 for a static edge
var dynamic_rects: Array = []     # Rect2 footprints of what can move (door panels, tall props)
## After polygon(): which dynamic rects a ray stopped at (their index -> true).
var hit_dynamic := {}


func _init(config: Dictionary) -> void:
	cfg = config


## Static occluders: edges shared between touching rects vanish, collinear ones merge.
func set_static(rects: Array) -> void:
	_ax.clear(); _az.clear(); _bx.clear(); _bz.clear(); _owner.clear()
	for e: Array in _outline(rects):
		_push(e[0], e[1], -1)
	_static_count = _ax.size()
	set_dynamic([])


## Footprints that change or that want to know they were seen. Empty rects don't block.
func set_dynamic(rects: Array) -> void:
	_ax.resize(_static_count); _az.resize(_static_count)
	_bx.resize(_static_count); _bz.resize(_static_count)
	_owner.resize(_static_count)
	dynamic_rects = rects
	for i in rects.size():
		var r: Rect2 = rects[i]
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var c: Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for k in 4:
			_push(c[k], c[(k + 1) % 4], i)


func edge_count() -> int:
	return _ax.size()


func _push(a: Vector2, b: Vector2, owner_index: int) -> void:
	_ax.append(a.x); _az.append(a.y)
	_bx.append(b.x); _bz.append(b.y)
	_owner.append(owner_index)


## Range and half angle (radians) of the cone for this light state.
func cone(light_on: bool) -> Dictionary:
	var c: Dictionary = cfg.cone_on if light_on else cfg.cone_off
	return {"range": float(c.range_m), "half": deg_to_rad(float(c.half_angle_deg))}


## Yaw 0 faces -Z (north), growing clockwise seen from above; matches OperatorModel.yaw_dir.
static func yaw_dir2(yaw: float) -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


## How far sight reaches along `dir_yaw` from an eye aiming along `aim_yaw`, ignoring occluders.
func reach(dir_yaw: float, aim_yaw: float, c: Dictionary) -> float:
	var awareness := float(cfg.awareness_radius_m)
	if absf(angle_difference(aim_yaw, dir_yaw)) <= c.half:
		return maxf(float(c.range), awareness)
	return awareness


## The whole sight polygon around `eye`, in order around it. Also fills `hit_dynamic`.
func polygon(eye: Vector2, aim_yaw: float, light_on: bool) -> PackedVector2Array:
	var c := cone(light_on)
	var far := maxf(float(c.range), float(cfg.awareness_radius_m))
	var edges := _facing_edges(eye, far)
	var eps := deg_to_rad(float(cfg.edge_step_deg))
	var yaws := PackedFloat64Array()
	# The circle and the wedge's arc, plus both sides of the wedge's straight edges.
	var step := deg_to_rad(float(cfg.arc_step_deg))
	var n := ceili(TAU / step)
	for i in n:
		yaws.append(aim_yaw + TAU * i / n)
	var arc_n := maxi(ceili(c.half * 2.0 / step), 1)
	for i in arc_n + 1:
		yaws.append(aim_yaw - c.half + c.half * 2.0 * i / arc_n)
	for s: float in [-1.0, 1.0]:
		yaws.append(aim_yaw + s * (c.half - eps))
		yaws.append(aim_yaw + s * (c.half + eps))
	# Both sides of every corner in reach: that's where sight can jump past something.
	for i: int in edges:
		for k in 2:
			var px: float = _ax[i] if k == 0 else _bx[i]
			var pz: float = _az[i] if k == 0 else _bz[i]
			var dx := px - eye.x
			var dz := pz - eye.y
			var y := atan2(-dx, -dz)
			if dx * dx + dz * dz <= pow(reach(y, aim_yaw, c), 2.0):
				yaws.append(y - eps)
				yaws.append(y + eps)
	# Sorted relative to the aim, so the wedge never straddles the seam.
	for i in yaws.size():
		yaws[i] = angle_difference(aim_yaw, yaws[i])
	yaws.sort()
	hit_dynamic.clear()
	var out := PackedVector2Array()
	out.resize(yaws.size())
	for i in yaws.size():
		var y := aim_yaw + yaws[i]
		var dir := yaw_dir2(y)
		out[i] = eye + dir * _cast(eye, dir, reach(y, aim_yaw, c), edges)
	return out


## Distance along the unit `dir` to the first edge in `edges`, capped at `limit`.
func _cast(eye: Vector2, dir: Vector2, limit: float, edges: PackedInt32Array) -> float:
	var best := limit
	var best_owner := -1
	for i: int in edges:
		var ax := _ax[i] - eye.x
		var az := _az[i] - eye.y
		var ex := _bx[i] - _ax[i]
		var ez := _bz[i] - _az[i]
		var denom := dir.x * ez - dir.y * ex
		if denom == 0.0:
			continue
		var t := (ax * ez - az * ex) / denom
		if t < 0.0 or t >= best:
			continue
		var u := (ax * dir.y - az * dir.x) / denom
		if u < 0.0 or u > 1.0:
			continue
		best = t
		best_owner = _owner[i]
	if best_owner >= 0:
		hit_dynamic[best_owner] = true
	return best


## Edges facing the eye and within `far` of it. A closed footprint's back edges can't be first hit.
func _facing_edges(eye: Vector2, far: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _ax.size():
		# Outside lies to the left of a -> b (clockwise rects in x-east, z-south).
		var ex := _bx[i] - _ax[i]
		var ez := _bz[i] - _az[i]
		if ex * (eye.y - _az[i]) - ez * (eye.x - _ax[i]) >= 0.0:
			continue
		var qx := clampf(eye.x, minf(_ax[i], _bx[i]), maxf(_ax[i], _bx[i]))
		var qz := clampf(eye.y, minf(_az[i], _bz[i]), maxf(_az[i], _bz[i]))
		if (qx - eye.x) * (qx - eye.x) + (qz - eye.y) * (qz - eye.y) <= far * far:
			out.append(i)
	return out


## Is `p` seen from `eye` right now? In the circle or the wedge, with nothing between.
func can_see(eye: Vector2, aim_yaw: float, light_on: bool, p: Vector2) -> bool:
	var to := p - eye
	var d := to.length()
	if d == 0.0:
		return true
	var c := cone(light_on)
	if d > reach(atan2(-to.x, -to.y), aim_yaw, c):
		return false
	return not blocked(eye, p)


## Is the flashlight's wedge on `p` right now, with nothing between? The circle doesn't count.
func in_light(eye: Vector2, aim_yaw: float, p: Vector2) -> bool:
	var to := p - eye
	var c := cone(true)
	if to.length() > float(c.range) or absf(angle_difference(aim_yaw, atan2(-to.x, -to.y))) > float(c.half):
		return false
	return not blocked(eye, p)


## True when any occluder edge crosses the straight line from `a` to `b`.
func blocked(a: Vector2, b: Vector2) -> bool:
	var dx := b.x - a.x
	var dz := b.y - a.y
	for i in _ax.size():
		var px := _ax[i] - a.x
		var pz := _az[i] - a.y
		var ex := _bx[i] - _ax[i]
		var ez := _bz[i] - _az[i]
		var denom := dx * ez - dz * ex
		if denom == 0.0:
			continue
		var t := (px * ez - pz * ex) / denom
		if t < 0.0 or t > 1.0:
			continue
		var u := (px * dz - pz * dx) / denom
		if u >= 0.0 and u <= 1.0:
			return true
	return false


## Outer edges of a set of rects, oriented with the outside on the left of a -> b.
## An edge's stretches that lie against a neighbouring rect are removed.
static func _outline(rects: Array) -> Array:
	var out: Array = []
	# Horizontal edges: line z, from x0 to x1. `north` = the rect's north side (outside is -z).
	for north: bool in [true, false]:
		var lines := {}
		for r: Rect2 in rects:
			var z := snappedf(r.position.y if north else r.end.y, 0.0001)
			var spans := _subtract_touching(r.position.x, r.end.x, z, north, rects, true)
			if not lines.has(z):
				lines[z] = []
			lines[z].append_array(spans)
		for z: float in lines:
			for s: Vector2 in _merge_spans(lines[z]):
				if north:
					out.append([Vector2(s.x, z), Vector2(s.y, z)])
				else:
					out.append([Vector2(s.y, z), Vector2(s.x, z)])
	for west: bool in [true, false]:
		var lines := {}
		for r: Rect2 in rects:
			var x := snappedf(r.position.x if west else r.end.x, 0.0001)
			var spans := _subtract_touching(r.position.y, r.end.y, x, west, rects, false)
			if not lines.has(x):
				lines[x] = []
			lines[x].append_array(spans)
		for x: float in lines:
			for s: Vector2 in _merge_spans(lines[x]):
				if west:
					out.append([Vector2(x, s.y), Vector2(x, s.x)])
				else:
					out.append([Vector2(x, s.x), Vector2(x, s.y)])
	return out


## What's left of the span [lo, hi] on `line` after removing stretches where another rect sits
## directly on its outer side (`low_side`: the outer side is the smaller coordinate).
static func _subtract_touching(lo: float, hi: float, line: float, low_side: bool, rects: Array, horizontal: bool) -> Array:
	var spans: Array = [Vector2(lo, hi)]
	var e := 0.0001
	for q: Rect2 in rects:
		var q_lo: float = q.position.x if horizontal else q.position.y
		var q_hi: float = q.end.x if horizontal else q.end.y
		var across_lo: float = q.position.y if horizontal else q.position.x
		var across_hi: float = q.end.y if horizontal else q.end.x
		var touches: bool = (low_side and across_lo < line - e and across_hi >= line - e) \
				or (not low_side and across_hi > line + e and across_lo <= line + e)
		if not touches:
			continue
		var next: Array = []
		for s: Vector2 in spans:
			if q_hi <= s.x + e or q_lo >= s.y - e:
				next.append(s)
				continue
			if q_lo > s.x + e:
				next.append(Vector2(s.x, q_lo))
			if q_hi < s.y - e:
				next.append(Vector2(q_hi, s.y))
		spans = next
	return spans


static func _merge_spans(spans: Array) -> Array:
	var sorted := spans.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array = []
	for s: Vector2 in sorted:
		if not out.is_empty() and s.x <= (out[-1] as Vector2).y + 0.0001:
			out[-1] = Vector2((out[-1] as Vector2).x, maxf((out[-1] as Vector2).y, s.y))
		else:
			out.append(s)
	return out
