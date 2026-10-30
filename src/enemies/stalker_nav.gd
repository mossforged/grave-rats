extends RefCounted
## Scene-free paths for a stalker's body on a grid over the deck: AStarGrid2D over
## DeckLayout.free_grid, with named blockers (shut doors, beds, the sealed bulkhead) on top.
## Also picks where a stalk goes next: not straight at you, but around, behind things.

var cfg: Dictionary
var cell := 0.5
var origin := Vector2.ZERO
var nx := 0
var nz := 0
var spots: Array = []  # points beside cover and corners, worth stalking to

var _radius := 0.0
var _base := PackedByteArray()
var _grid := AStarGrid2D.new()
var _blockers := {}  # id -> Rect2
var _dirty := false


func _init(config: Dictionary, layout: RefCounted) -> void:
	cfg = config
	cell = float(cfg.nav.cell_m)
	_radius = float(cfg.radius_m)
	var g: Dictionary = layout.free_grid(_radius, cell)
	nx = g.nx
	nz = g.nz
	_base = g.free
	origin = layout.bounds.position
	_grid.region = Rect2i(0, 0, nx, nz)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	_rebuild()
	var margin := float(cfg.stalk.spot_margin_m)
	for p: Dictionary in layout.props:
		if String(p.get("cover", "none")) != "none":
			var r: Rect2 = (p.rect as Rect2).grow(margin)
			var c := r.get_center()
			spots.append_array([Vector2(r.position.x, c.y), Vector2(r.end.x, c.y), Vector2(c.x, r.position.y), Vector2(c.x, r.end.y)])


## A rect nothing can walk through for now; pass an empty Rect2 to clear it.
func set_blocker(id: Variant, rect: Rect2) -> void:
	if rect.size == Vector2.ZERO:
		if _blockers.erase(id):
			_dirty = true
	elif not _blockers.has(id) or _blockers[id] != rect:
		_blockers[id] = rect
		_dirty = true


func _rebuild() -> void:
	_dirty = false
	for z in nz:
		for x in nx:
			_grid.set_point_solid(Vector2i(x, z), _base[z * nx + x] == 0)
	for id: Variant in _blockers:
		var r: Rect2 = (_blockers[id] as Rect2).grow(_radius)
		var a := to_cell(r.position)
		var b := to_cell(r.end)
		for z in range(maxi(a.y, 0), mini(b.y, nz - 1) + 1):
			for x in range(maxi(a.x, 0), mini(b.x, nx - 1) + 1):
				if r.has_point(to_point(Vector2i(x, z))):
					_grid.set_point_solid(Vector2i(x, z), true)


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / cell))


func to_point(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func is_free(p: Vector2) -> bool:
	if _dirty:
		_rebuild()
	var c := to_cell(p)
	return _grid.is_in_boundsv(c) and not _grid.is_point_solid(c)


## The free cell nearest `p`, or (-1, -1).
func nearest_cell(p: Vector2) -> Vector2i:
	if _dirty:
		_rebuild()
	var c := to_cell(p)
	for ring in int(cfg.nav.search_rings):
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var q := c + Vector2i(dx, dz)
				if _grid.is_in_boundsv(q) and not _grid.is_point_solid(q):
					return q
	return Vector2i(-1, -1)


## Points from `from` to `to`, nearest first; empty when there is no way there (a shut door).
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var a := nearest_cell(from)
	var b := nearest_cell(to)
	if a.x < 0 or b.x < 0:
		return out
	for c: Vector2i in _grid.get_id_path(a, b):
		out.append(to_point(c))
	return out


## Where a stalk heads next: a point around the player, off the direct line, hidden from them if
## it can be, on the same side it already chose. `hidden(p)` is true when the player can't see `p`.
func stalk_point(from: Vector2, player: Vector2, side: float, hidden: Callable) -> Vector2:
	var st: Dictionary = cfg.stalk
	var bearing := (from - player).angle()
	var scored: Array = []
	var n := int(st.ring_samples)
	for r: Variant in st.ring_radii_m:
		for i in n:
			var a := bearing + TAU * i / n
			scored.append(player + Vector2.from_angle(a) * float(r))
	for p: Vector2 in spots:
		if p.distance_to(player) <= float(st.spot_range_m):
			scored.append(p)
	var ranked: Array = []
	for p: Vector2 in scored:
		if not is_free(p):
			continue
		var off := angle_difference(bearing, (p - player).angle())
		var score := minf(absf(off), float(st.flank_max_rad)) * float(st.flank_score_per_rad)
		score += float(st.side_score) if signf(off) == side else 0.0
		score -= from.distance_to(p) * float(st.from_cost_per_m)
		score -= p.distance_to(player) * float(st.close_score_per_m)
		if hidden.call(p):
			score += float(st.hidden_score)
		ranked.append([score, p])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k in mini(ranked.size(), int(st.path_tries)):
		if not path(from, ranked[k][1]).is_empty():
			return ranked[k][1]
	return from
