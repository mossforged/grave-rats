extends RefCounted
## Scene-free grey-box deck layout, generated from data/deck.json (see src/study/CONTRACT.md).
## All rectangles are Rect2 in world XZ metres (x east, y = z south). Rooms and corridors scale
## with room_scale (snapped to grid_m); walls, doors and props keep their real size.
##
## Walls: every space gets a band of wall_thickness_m around its interior. Wall = inside some band,
## inside no interior, inside no doorway or door frame. So shared walls are built once and spaces that touch
## (an open corridor mouth) open into each other. Walls are merged into boxes and split into
## pieces no longer than wall_segment_m, so the camera cut-away can drop them locally.

var data: Dictionary
var room_scale := 1.0
var spaces := {}             # name -> {name, kind, rect: Rect2}
var space_order: Array = []  # names in data order
var doors: Array = []        # {space, side, rect: Rect2 (the opening, wall-thick), frames: [Rect2, Rect2], along_x: bool}
var walls: Array = []        # Rect2 footprints
var props: Array = []        # {type, space, center: Vector2, size: Vector3, rect: Rect2}
var bounds := Rect2()


func _init(deck: Dictionary, scale: float = -1.0) -> void:
	data = deck
	room_scale = float(deck.room_scale) if scale <= 0.0 else scale
	_place_spaces()
	_place_doors()
	_build_walls()
	_place_props()


func thickness() -> float:
	return float(data.wall_thickness_m)


func snap(v: float) -> float:
	var g := float(data.grid_m)
	return roundf(v / g) * g


## Interior size of a space at the current room scale.
func scaled_size(spec: Dictionary) -> Vector2:
	return Vector2(snap(float(spec.size_m[0]) * room_scale), snap(float(spec.size_m[1]) * room_scale))


func space_rect(space_name: String) -> Rect2:
	return spaces[space_name].rect


## World XZ point at fractions (fx, fz) of a space's interior.
func point_in(space_name: String, frac: Array) -> Vector2:
	var r: Rect2 = spaces[space_name].rect
	return r.position + r.size * Vector2(float(frac[0]), float(frac[1]))


## Name of the space whose interior holds `p` ("" if none; a doorway counts as no space).
func space_at(p: Vector2) -> String:
	for n in space_order:
		if spaces[n].rect.has_point(p):
			return n
	return ""


func _place_spaces() -> void:
	var t := thickness()
	for spec in data.spaces:
		var size := scaled_size(spec)
		var pos := Vector2.ZERO
		if spec.has("anchor"):
			var a: Dictionary = spec.anchor
			var q: Rect2 = spaces[String(a.to)].rect
			var gap := 0.0 if bool(a.get("open", false)) else t
			var off := snap(float(a.get("offset_m", 0.0)) * room_scale) + float(a.get("offset_walls", 0)) * t
			match String(a.side):
				"west": pos = Vector2(q.position.x - gap - size.x, q.position.y + off)
				"east": pos = Vector2(q.end.x + gap, q.position.y + off)
				"north": pos = Vector2(q.position.x + off, q.position.y - gap - size.y)
				"south": pos = Vector2(q.position.x + off, q.end.y + gap)
				_: push_error("deck: unknown anchor side %s" % a.side)
		spaces[String(spec.name)] = {"name": String(spec.name), "kind": String(spec.kind), "rect": Rect2(pos, size)}
		space_order.append(String(spec.name))


func _place_doors() -> void:
	var t := thickness()
	var w := float(data.door_width_m)
	var f := float(data.door_frame_m)
	for spec in data.doors:
		var r: Rect2 = spaces[String(spec.space)].rect
		var at := float(spec.at)
		var opening: Rect2
		var frames: Array
		var along_x := String(spec.side) in ["north", "south"]
		if along_x:
			var cx := r.position.x + r.size.x * at
			var z0 := r.position.y - t if spec.side == "north" else r.end.y
			opening = Rect2(cx - w * 0.5, z0, w, t)
			frames = [Rect2(cx - w * 0.5 - f, z0, f, t), Rect2(cx + w * 0.5, z0, f, t)]
		else:
			var cz := r.position.y + r.size.y * at
			var x0 := r.position.x - t if spec.side == "west" else r.end.x
			opening = Rect2(x0, cz - w * 0.5, t, w)
			frames = [Rect2(x0, cz - w * 0.5 - f, t, f), Rect2(x0, cz + w * 0.5, t, f)]
		doors.append({"space": String(spec.space), "side": String(spec.side), "rect": opening,
				"frames": frames, "along_x": along_x})


func _build_walls() -> void:
	var t := thickness()
	var outers: Array = []
	var interiors: Array = []
	for n in space_order:
		var r: Rect2 = spaces[n].rect
		interiors.append(r)
		outers.append(r.grow(t))
	# Doorways and their frame posts are cut out of the walls (frames are their own pieces).
	var openings: Array = []
	for d in doors:
		openings.append(d.rect)
		openings.append_array(d.frames)
	# Coordinate-compressed grid over every edge, so cells are exact.
	var xs := {}
	var zs := {}
	for r in outers + interiors + openings:
		xs[snappedf(r.position.x, 0.0001)] = true
		xs[snappedf(r.end.x, 0.0001)] = true
		zs[snappedf(r.position.y, 0.0001)] = true
		zs[snappedf(r.end.y, 0.0001)] = true
	var gx: Array = xs.keys()
	var gz: Array = zs.keys()
	gx.sort()
	gz.sort()
	var cells := []  # rows (z) of bools (x)
	for j in gz.size() - 1:
		var row: Array[bool] = []
		for i in gx.size() - 1:
			var c := Vector2((gx[i] + gx[i + 1]) * 0.5, (gz[j] + gz[j + 1]) * 0.5)
			row.append(_inside_any(outers, c) and not _inside_any(interiors, c) and not _inside_any(openings, c))
		cells.append(row)
	# Greedy merge: runs along x, then extend runs down z while the same run repeats.
	var used := {}
	for j in cells.size():
		var i := 0
		while i < gx.size() - 1:
			if not cells[j][i] or used.has(Vector2i(i, j)):
				i += 1
				continue
			var i_end := i
			while i_end + 1 < gx.size() - 1 and cells[j][i_end + 1] and not used.has(Vector2i(i_end + 1, j)):
				i_end += 1
			var j_end := j
			while j_end + 1 < cells.size() and _run_free(cells, used, j_end + 1, i, i_end):
				j_end += 1
			for jj in range(j, j_end + 1):
				for ii in range(i, i_end + 1):
					used[Vector2i(ii, jj)] = true
			_add_split_wall(Rect2(gx[i], gz[j], gx[i_end + 1] - gx[i], gz[j_end + 1] - gz[j]))
			i = i_end + 1
	bounds = Rect2()
	for r in outers:
		bounds = r if bounds.size == Vector2.ZERO else bounds.merge(r)


func _run_free(cells: Array, used: Dictionary, j: int, i0: int, i1: int) -> bool:
	if i0 > 0 and cells[j][i0 - 1] and not used.has(Vector2i(i0 - 1, j)):
		return false  # the row continues further left: keep runs maximal along x
	for i in range(i0, i1 + 1):
		if not cells[j][i] or used.has(Vector2i(i, j)):
			return false
	if i1 + 1 < cells[j].size() and cells[j][i1 + 1]:
		return false
	return true


func _add_split_wall(r: Rect2) -> void:
	var seg := float(data.wall_segment_m)
	var long_x := r.size.x >= r.size.y
	var length := r.size.x if long_x else r.size.y
	var n := maxi(1, ceili(length / seg - 0.001))
	var step := length / n
	for k in n:
		if long_x:
			walls.append(Rect2(r.position.x + step * k, r.position.y, step, r.size.y))
		else:
			walls.append(Rect2(r.position.x, r.position.y + step * k, r.size.x, step))


static func _inside_any(rects: Array, p: Vector2) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false


func _place_props() -> void:
	for spec in data.props:
		var c := point_in(String(spec.space), spec.at)
		var s := Vector3(float(spec.size_m[0]), float(spec.size_m[1]), float(spec.size_m[2]))
		props.append({"type": String(spec.type), "space": String(spec.space), "center": c, "size": s,
				"rect": Rect2(c.x - s.x * 0.5, c.y - s.z * 0.5, s.x, s.z)})


## Every footprint a character can't stand in: walls, door frames and props.
func blockers() -> Array:
	var out: Array = walls.duplicate()
	for d in doors:
		out.append_array(d.frames)
	for p in props:
		out.append(p.rect)
	return out


## Breadth-first search on a `cell` m grid for a disc of `radius` m from `from` to `to`.
## Returns the path length in cells (>= 0) or -1 when there is no walkable path.
func path_cells(from: Vector2, to: Vector2, radius: float, cell: float) -> int:
	var grid := free_grid(radius, cell)
	var nx: int = grid.nx
	var nz: int = grid.nz
	var free: PackedByteArray = grid.free
	var start := _nearest_free(free, nx, nz, _to_cell(from, cell))
	var goal := _nearest_free(free, nx, nz, _to_cell(to, cell))
	if start < 0 or goal < 0:
		return -1
	var dist := PackedInt32Array()
	dist.resize(nx * nz)
	dist.fill(-1)
	dist[start] = 0
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == goal:
			return dist[c]
		var cx := c % nx
		var cz := c / nx
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var x: int = cx + d.x
			var z: int = cz + d.y
			if x < 0 or z < 0 or x >= nx or z >= nz:
				continue
			var nb := z * nx + x
			if free[nb] == 0 or dist[nb] >= 0:
				continue
			dist[nb] = dist[c] + 1
			queue.append(nb)
	return -1


## Grid over `bounds`: free[i] = 1 where a disc of `radius` m centred on the cell centre stands
## inside a space or doorway and overlaps no blocker.
func free_grid(radius: float, cell: float) -> Dictionary:
	var nx := int(ceil(bounds.size.x / cell))
	var nz := int(ceil(bounds.size.y / cell))
	var free := PackedByteArray()
	free.resize(nx * nz)
	free.fill(0)
	var floors: Array = space_order.map(func(n: String) -> Rect2: return spaces[n].rect)
	floors.append_array(doors.map(func(d: Dictionary) -> Rect2: return d.rect))
	for r in floors:
		_mark(free, nx, nz, cell, r, 0.0, 1)
	for r in blockers():
		_mark(free, nx, nz, cell, r, radius, 0)
	return {"nx": nx, "nz": nz, "free": free}


## Sets cells whose centre lies within `grow` m of rect `r` (inside it when grow is 0) to `value`.
func _mark(grid: PackedByteArray, nx: int, nz: int, cell: float, r: Rect2, grow: float, value: int) -> void:
	var o := bounds.position
	var x0 := maxi(0, int(floor((r.position.x - grow - o.x) / cell)))
	var x1 := mini(nx - 1, int(ceil((r.end.x + grow - o.x) / cell)))
	var z0 := maxi(0, int(floor((r.position.y - grow - o.y) / cell)))
	var z1 := mini(nz - 1, int(ceil((r.end.y + grow - o.y) / cell)))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var p := o + (Vector2(x, z) + Vector2(0.5, 0.5)) * cell
			var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			var d2 := q.distance_squared_to(p)
			if (grow > 0.0 and d2 < grow * grow) or (grow == 0.0 and r.has_point(p)):
				grid[z * nx + x] = value


func _to_cell(p: Vector2, cell: float) -> Vector2i:
	return Vector2i(int((p.x - bounds.position.x) / cell), int((p.y - bounds.position.y) / cell))


func _nearest_free(free: PackedByteArray, nx: int, nz: int, c: Vector2i) -> int:
	for ring in 40:
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var q := c + Vector2i(dx, dz)
				if q.x >= 0 and q.y >= 0 and q.x < nx and q.y < nz and free[q.y * nx + q.x] == 1:
					return q.y * nx + q.x
	return -1


## True when a disc of `radius` m at `p` stands in a space or doorway and touches no blocker.
func is_free(p: Vector2, radius: float) -> bool:
	if space_at(p) == "" and not doors.any(func(d: Dictionary) -> bool: return d.rect.has_point(p)):
		return false
	for r in blockers():
		var rr := r as Rect2
		var q := Vector2(clampf(p.x, rr.position.x, rr.end.x), clampf(p.y, rr.position.y, rr.end.y))
		if q.distance_squared_to(p) < radius * radius:
			return false
	return true
