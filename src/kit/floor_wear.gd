extends RefCounted
## Scene-free map of how a deck's floor has aged, from its layout: R foot traffic (door to door through
## each room, and the door thresholds), G damp (round drains and grates, and any data patches). A tile
## can't know where people walk; this can. Read by kit_floor.gdshader in world XZ. Numbers: data/kit.json
## "floor_wear" and its "floors" drains and grates.


## The whole deck's map; its rect in the world is `rect_for(layout, cfg)`.
static func paint(layout: RefCounted, cfg: Dictionary, floors: Dictionary) -> Image:
	var r := rect_for(layout, cfg)
	var ppm := float(cfg.px_per_m)
	var w := maxi(ceili(r.size.x * ppm), 1)
	var h := maxi(ceili(r.size.y * ppm), 1)
	var img := Image.create(w, h, false, Image.FORMAT_RG8)
	for space: String in layout.space_order:
		_paint_space(img, r, ppm, layout, space, cfg, floors)
	return img


static func rect_for(layout: RefCounted, cfg: Dictionary) -> Rect2:
	return layout.bounds.grow(float(cfg.margin_m))


## The map's value at a world point (tests, and anything else that wants to ask).
static func sample(img: Image, r: Rect2, ppm: float, p: Vector2) -> Vector2:
	var q := ((p - r.position) * ppm).floor()
	var c := img.get_pixel(clampi(int(q.x), 0, img.get_width() - 1), clampi(int(q.y), 0, img.get_height() - 1))
	return Vector2(c.r, c.g)


static func _paint_space(img: Image, r: Rect2, ppm: float, layout: RefCounted, space: String, cfg: Dictionary, floors: Dictionary) -> void:
	var room: Rect2 = layout.space_rect(space)
	var grown := room.grow(float(layout.data.wall_thickness_m))
	var openings: Array = []
	for d: Dictionary in layout.doors + layout.breaches:
		if grown.intersects(d.rect):
			openings.append(d.rect)
	var spec: Dictionary = (cfg.spaces as Dictionary).get(space, cfg.spaces.default)
	var segs := _paths(room, openings, spec)
	var patches := _damp_patches(room, (floors.spaces as Dictionary).get(space, floors.spaces.default), spec, cfg, float(floors.drain_m))
	var traffic_w := float(cfg.path_width_m)
	var path_power := float(cfg.path_strength)
	var door_m := float(cfg.threshold_m)
	var door_power := float(cfg.threshold_strength)
	var x0 := maxi(int((room.position.x - r.position.x) * ppm), 0)
	var y0 := maxi(int((room.position.y - r.position.y) * ppm), 0)
	var x1 := mini(ceili((room.end.x - r.position.x) * ppm), img.get_width())
	var y1 := mini(ceili((room.end.y - r.position.y) * ppm), img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var p := r.position + Vector2(x + 0.5, y + 0.5) / ppm
			var t := 0.0
			for seg: Array in segs:
				var d := _segment_distance(p, seg[0], seg[1])
				t = maxf(t, (1.0 - smoothstep(0.0, traffic_w, d)) * path_power)
			for o: Rect2 in openings:
				var d := _rect_distance(p, o)
				t = maxf(t, (1.0 - smoothstep(0.0, door_m, d)) * door_power)
			var damp := 0.0
			for patch: Array in patches:
				var d := _rect_distance(p, patch[0])
				damp = maxf(damp, (1.0 - smoothstep(0.0, float(patch[1]), d)) * float(patch[2]))
			img.set_pixel(x, y, Color(t, damp, 0.0))


## Door to door through the middle of the room, plus any routes in the data (fractions of the room).
static func _paths(room: Rect2, openings: Array, spec: Dictionary) -> Array:
	var segs: Array = []
	var hub: Vector2 = room.position + room.size * Vector2(float(spec.hub[0]), float(spec.hub[1]))
	for o: Rect2 in openings:
		var door: Vector2 = o.get_center()
		var inside := Vector2(clampf(door.x, room.position.x, room.end.x), clampf(door.y, room.position.y, room.end.y))
		segs.append([inside, hub])
	for route: Array in spec.routes:
		for i in route.size() - 1:
			var a: Array = route[i]
			var b: Array = route[i + 1]
			segs.append([room.position + room.size * Vector2(float(a[0]), float(a[1])),
					room.position + room.size * Vector2(float(b[0]), float(b[1]))])
	return segs


## [rect, reach, strength] for each drain, grate and data patch.
static func _damp_patches(room: Rect2, floor_spec: Dictionary, spec: Dictionary, cfg: Dictionary, drain_m: float) -> Array:
	var out: Array = []
	for dr: Array in floor_spec.drains:
		var c: Vector2 = room.position + room.size * Vector2(float(dr[0]), float(dr[1]))
		out.append([Rect2(c - Vector2.ONE * drain_m * 0.5, Vector2.ONE * drain_m), float(cfg.drain_reach_m), float(cfg.drain_strength)])
	for gr: Dictionary in floor_spec.grates:
		var size := Vector2(float(gr.size_m[0]), float(gr.size_m[1]))
		var c: Vector2 = room.position + room.size * Vector2(float(gr.at[0]), float(gr.at[1]))
		out.append([Rect2(c - size * 0.5, size), float(cfg.grate_reach_m), float(cfg.grate_strength)])
	for patch: Array in spec.damp:
		var c: Vector2 = room.position + room.size * Vector2(float(patch[0]), float(patch[1]))
		out.append([Rect2(c, Vector2.ZERO), float(patch[2]), float(cfg.patch_strength)])
	return out


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


static func _rect_distance(p: Vector2, r: Rect2) -> float:
	return p.distance_to(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))
