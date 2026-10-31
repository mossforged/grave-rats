extends RefCounted
## Every piece of the slice kit, generated to A006's dimensions (data/kit.json "dims" plus the deck's
## wall height and depth). Local frame: floor pivot at the centre, X along, Y up, +Z the front face.
## A piece of any length keeps its trim sizes and only its panels change, so the closing pieces the
## ×0.85 rooms need are never stretched bays. Meshes are cached by what makes them different.

const KitMesh := preload("res://src/kit/kit_mesh.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")

static var _meshes := {}


static func _cfg() -> Dictionary:
	return KitMaterials.cfg()


static func _cached(key: String, make: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var mesh: ArrayMesh = make.call()
		mesh.resource_name = key
		_meshes[key] = mesh
	return _meshes[key]


static func _uv_offset(variant: int) -> Vector2:
	# Golden-ratio steps, so variants of a tiling texture don't line up.
	var phi := (sqrt(5.0) - 1.0) * 0.5
	return Vector2(fmod(variant * phi, 1.0), fmod(variant * phi * phi, 1.0))


## A wall bay `length` long, `front` and `back` the families on its +Z and -Z faces, `end_a`/`end_b`
## the post lengths at its -X and +X ends (a post as deep as the wall is the corner piece).
static func wall(length: float, depth: float, height: float, front: String, back: String,
		end_a: float, end_b: float, variant: int) -> ArrayMesh:
	var key := "wall_%.3f_%.3f_%.3f_%s_%s_%.3f_%.3f_%d" % [length, depth, height, front, back, end_a, end_b, variant]
	return _cached(key, func() -> ArrayMesh:
		var m := KitMesh.new()
		m.uv_offset = _uv_offset(variant)
		_wall_body(m, length, depth, height, end_a, end_b)
		var d: Dictionary = _cfg().dims
		var x0 := -length * 0.5 + end_a
		var x1 := length * 0.5 - end_b
		_cap_top(m, x0, x1, depth, height, front, variant)
		if x1 - x0 >= float(d.min_panel_m) * 0.5:
			_face(m, x0, x1, depth, height, front, 1.0, variant)
			_face(m, x0, x1, depth, height, back, -1.0, variant)
		return m.build())


## A short stub: one solid capped block, for what's left over between corners and door posts.
static func wall_cap(length: float, depth: float, height: float, variant: int) -> ArrayMesh:
	var key := "wall_cap_%.3f_%.3f_%.3f_%d" % [length, depth, height, variant]
	return _cached(key, func() -> ArrayMesh:
		var m := KitMesh.new()
		m.uv_offset = _uv_offset(variant)
		_post(m, -length * 0.5, length * 0.5, depth, height)
		return m.build())


## The square post where two walls meet. A corner is bay + corner post + bay, so each leg still
## fades by itself; the measured L (2.0 m outer legs, A006-05b) is what two such pieces add up to.
static func corner_post(depth: float, height: float) -> ArrayMesh:
	return wall_cap(depth, depth, height, 0)


static func _post(m: KitMesh, x0: float, x1: float, depth: float, height: float) -> void:
	var d: Dictionary = _cfg().dims
	var c := float(d.chamfer_m)
	var half := depth * 0.5
	var inset := float(d.cap_insert_inset_m)
	m.box(Vector3(x0, 0.0, -half), Vector3(x1, height - float(d.cap_insert_drop_m), half), "steel", c)
	if x1 - x0 > inset * 2.0:
		m.box(Vector3(x0 + inset, height - float(d.cap_insert_drop_m) * 2.0, -half + inset),
				Vector3(x1 - inset, height, half - inset), "steel", c * 0.5)


static func _wall_body(m: KitMesh, length: float, depth: float, height: float, end_a: float, end_b: float) -> void:
	var d: Dictionary = _cfg().dims
	var c := float(d.chamfer_m)
	var half := depth * 0.5
	var x0 := -length * 0.5
	var x1 := length * 0.5
	var inset := float(d.core_inset_m)
	m.box(Vector3(x0 + end_a, 0.0, -half + inset), Vector3(x1 - end_b, height, half - inset), "steel")
	_post(m, x0, x0 + end_a, depth, height)
	_post(m, x1 - end_b, x1, depth, height)
	var kick_z := half - float(d.proud_m)
	m.box(Vector3(x0 + end_a, 0.0, -kick_z), Vector3(x1 - end_b, float(d.kick_h_m), kick_z), "steel", c)
	m.box(Vector3(x0 + end_a, height - float(d.cap_h_m), -half), Vector3(x1 - end_b, height - float(d.cap_insert_drop_m), half), "steel", c)


## What the camera mostly sees of a wall: its top. A painted insert and, on some bays, a hazard slash.
static func _cap_top(m: KitMesh, x0: float, x1: float, depth: float, height: float, front: String, variant: int) -> void:
	var d: Dictionary = _cfg().dims
	var inset := float(d.cap_insert_inset_m)
	if x1 - x0 <= inset * 2.0:
		return
	var fam: Dictionary = _cfg().wall_families[_family_key(front)]
	var half := depth * 0.5 - inset
	var y0 := height - float(d.cap_insert_drop_m) * 2.0
	var a := x0 + inset
	var b := x1 - inset
	var slash := float(d.hazard_cap_m)
	if variant % 2 == 0 and b - a > slash * 2.0:
		m.box(Vector3(a, y0, -half), Vector3(a + slash, height, half), "hazard")
		a += slash
	m.box(Vector3(a, y0, -half), Vector3(b, height, half), String(fam.cap_insert))


static func _family_key(family: String) -> String:
	return "plain" if family == "corridor" else family


## One face of a bay between its posts, per family (A006-05b). `side` is +1 for +Z, -1 for -Z.
static func _face(m: KitMesh, x0: float, x1: float, depth: float, height: float, family: String, side: float, variant: int) -> void:
	var d: Dictionary = _cfg().dims
	var fam: Dictionary = _cfg().wall_families[_family_key(family)]
	var kick := float(d.kick_h_m)
	var y0 := kick
	var y1 := height - float(d.cap_h_m)
	var out := depth * 0.5 - float(d.face_recess_m)
	var t := float(d.face_plate_t_m)
	var c := float(d.chamfer_m)
	var width := x1 - x0
	# The kick plate's painted band.
	var proud := float(d.proud_m)
	var band := width * float(d.hazard_kick_frac)
	var kx := x0 + (width - band) * (0.5 if variant % 2 == 0 else 0.15)
	_zbox(m, kx, kx + band, kick * 0.2, kick * 0.8, depth * 0.5, proud * 2.0, side, String(fam.kick_band), 0.0)
	match family:
		"pipe":
			_pipe_face(m, x0, x1, y0, y1, depth, side, fam)
		"reinforced":
			_zbox(m, x0, x1, y0, y1, out, t, side, String(fam.panel), c)
			var w := float(fam.window_inset_m)
			if width > w * 3.0:
				var rail := float(d.rail_m)
				_zbox(m, x0 + w - rail, x1 - w + rail, y0 + w - rail, y1 - w + rail, out + proud * 2.0, t, side, "steel", c)
				_zbox(m, x0 + w, x1 - w, y0 + w, y1 - w, out + proud * 3.0, t, side, String(fam.window), 0.0)
				var sb := float(fam.side_band_m)
				_zbox(m, x1 - sb, x1, y0, y1, out + proud, t, side, "hazard", 0.0)
		_:
			_zbox(m, x0, x1, y0, y1, out, t, side, String(fam.panel), c)
			var rail := float(d.rail_m)
			if width > rail * 4.0 and family != "outer":
				# The raised corner brackets and the seam rail around a painted panel.
				_zbox(m, x0, x1, y1 - rail, y1, out + proud * 2.0, t, side, "steel", c)
				_zbox(m, x0, x1, y0, y0 + rail, out + proud * 2.0, t, side, "steel", c)


## Pipes on one side, a louvred vent on the other.
static func _pipe_face(m: KitMesh, x0: float, x1: float, y0: float, y1: float, depth: float, side: float, fam: Dictionary) -> void:
	var d: Dictionary = _cfg().dims
	var out := depth * 0.5 - float(d.face_recess_m)
	var t := float(d.face_plate_t_m)
	var c := float(d.chamfer_m)
	var mid := lerpf(x0, x1, 0.5)
	var r := float(fam.pipe_r_m)
	var gap := float(fam.pipe_gap_m)
	var z := side * (depth * 0.5 - r - float(d.face_recess_m))
	var mats: Array = fam.pipe_mats
	var px := x0 + gap
	for i in mats.size():
		if px > mid - gap * 0.5:
			break
		m.cylinder(Vector3(px, y0, z), y1 - y0, r, 8, String(mats[i]))
		px += gap
	var clamp_h := float(fam.clamp_h_m)
	for j in int(fam.clamps):
		var y := lerpf(y0, y1, (j + 1.0) / (int(fam.clamps) + 1.0))
		_zbox(m, x0, mid, y, y + clamp_h, out + float(d.proud_m) * 3.0, t * 2.0, side, "steel", c * 0.5)
	# The plate behind the pipes, then slats down the vent.
	_zbox(m, x0, mid, y0, y1, out - r, t, side, "steel", 0.0)
	_zbox(m, mid, x1, y0, y1, out - float(d.face_recess_m), t, side, "grate", 0.0)
	var slat := float(fam.slat_h_m)
	var y := y0 + float(fam.slat_gap_m) * 0.5
	while y + slat < y1:
		_zbox(m, mid, x1, y, y + slat, out + float(d.proud_m), float(fam.slat_t_m), side, "steel", c * 0.4)
		y += float(fam.slat_gap_m)


## A plate from z = side × (z_out - thick) to side × z_out.
static func _zbox(m: KitMesh, x0: float, x1: float, y0: float, y1: float, z_out: float, thick: float, side: float, mat: String, chamfer: float) -> void:
	var a := side * z_out
	var b := side * (z_out - thick)
	m.box(Vector3(x0, y0, minf(a, b)), Vector3(x1, y1, maxf(a, b)), mat, chamfer)


# --- doors (A006-06c) ---

## One jamb post, door_frame_m along the wall, a hazard band on the faces.
static func door_jamb(width: float, depth: float, height: float) -> ArrayMesh:
	var key := "jamb_%.3f_%.3f_%.3f" % [width, depth, height]
	return _cached(key, func() -> ArrayMesh:
		var m := KitMesh.new()
		var d: Dictionary = _cfg().dims
		var look: Dictionary = _cfg().door_look
		var half := depth * 0.5
		var hw := width * 0.5
		var proud := float(d.proud_m)
		m.box(Vector3(-hw, 0.0, -half + proud), Vector3(hw, height, half - proud), "steel", float(d.chamfer_m))
		var band := float(look.jamb_band_m)
		var inset := float(look.jamb_inset_m)
		for side: float in [-1.0, 1.0]:
			_zbox(m, -band, band, inset, float(d.door_aperture_h_m) - inset, half, proud * 2.0, side, "hazard", 0.0)
		return m.build())


## The header over the aperture: full bounds, but a slot along its length. Solid, it would hide a side
## door's leaf from the game camera, and then nobody could read the door (handoff).
static func door_header(length: float, depth: float, height: float) -> ArrayMesh:
	var key := "header_%.3f_%.3f_%.3f" % [length, depth, height]
	return _cached(key, func() -> ArrayMesh:
		var m := KitMesh.new()
		var d: Dictionary = _cfg().dims
		var y0 := float(d.door_aperture_h_m)
		var half := depth * 0.5
		var rail := float(d.header_rail_m)
		var rib := float(d.header_rib_m)
		var c := float(d.chamfer_m)
		var hl := length * 0.5
		m.box(Vector3(-hl, y0, half - rail), Vector3(hl, height, half), "steel", c)
		m.box(Vector3(-hl, y0, -half), Vector3(hl, height, -half + rail), "steel", c)
		m.box(Vector3(-hl, y0, -half), Vector3(-hl + rib, height, half), "steel", c)
		m.box(Vector3(hl - rib, y0, -half), Vector3(hl, height, half), "steel", c)
		return m.build())


## The leaf. Blend shapes "dent_front" and "dent_back" bulge it toward +Z or -Z, so the T006 damage
## value drives the same mesh from flat to A006-03c's mid-bash, along whichever way the blows push.
static func door_leaf(width: float, height: float, thick: float) -> ArrayMesh:
	var key := "leaf_%.3f_%.3f_%.3f" % [width, height, thick]
	return _cached(key, func() -> ArrayMesh:
		var look: Dictionary = _cfg().door_look
		var grid: Array = look.leaf_grid
		var nx := int(grid[0])
		var ny := int(grid[1])
		var rng := RandomNumberGenerator.new()
		rng.seed = int(look.seed)
		var lumps: Array = []
		for i in int(look.lump_count):
			lumps.append(Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7), rng.randf_range(0.4, 1.0)))
		var dent := func(u: float, v: float) -> float:
			return _dent_at(u, v, lumps, look)
		var mesh := ArrayMesh.new()
		mesh.add_blend_shape("dent_front")
		mesh.add_blend_shape("dent_back")
		var base := _leaf_arrays(width, height, thick, nx, ny, dent, 0.0)
		var front := _leaf_arrays(width, height, thick, nx, ny, dent, 1.0)
		var back := _leaf_arrays(width, height, thick, nx, ny, dent, -1.0)
		var shapes := []
		for target: Array in [front, back]:
			var shape := []
			shape.resize(Mesh.ARRAY_MAX)
			shape[Mesh.ARRAY_VERTEX] = target[Mesh.ARRAY_VERTEX]
			shape[Mesh.ARRAY_NORMAL] = target[Mesh.ARRAY_NORMAL]
			shape[Mesh.ARRAY_TANGENT] = target[Mesh.ARRAY_TANGENT]
			shapes.append(shape)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base, shapes)
		mesh.surface_set_name(0, "leaf")
		mesh.surface_set_material(0, KitMaterials.material("leaf"))
		return mesh)


## Displacement in metres at (u, v), both -1..1: pinned at the rim, a big bulge and hammer-blow lumps.
static func _dent_at(u: float, v: float, lumps: Array, look: Dictionary) -> float:
	var env := maxf((1.0 - u * u) * (1.0 - v * v), 0.0)
	var out := pow(env, float(look.bulge_power)) * float(look.bulge_m)
	var r := float(look.lump_radius)
	for l: Vector3 in lumps:
		var q := Vector2(u - l.x, v - l.y)
		out += exp(-q.length_squared() / (r * r)) * float(look.lump_m) * l.z * env
	var k := float(look.crease_freq)
	out -= absf(sin(k * (u * 0.8 + v * 0.6)) * sin(k * (v * 0.9 - u * 0.4))) * float(look.crease_m) * env
	return out


static func _leaf_arrays(width: float, height: float, thick: float, nx: int, ny: int, dent: Callable, amount: float) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var step := Vector2(2.0 / nx, 2.0 / ny)
	var size := Vector2(width, height)
	for face: float in [1.0, -1.0]:
		var first := v.size()
		for j in ny + 1:
			for i in nx + 1:
				var a := -1.0 + i * step.x
				var b := -1.0 + j * step.y
				var d: float = dent.call(a, b) * amount
				v.append(Vector3(a * width * 0.5, (b + 1.0) * height * 0.5 - height * 0.5, face * thick * 0.5 + d))
				var dx: float = (dent.call(a + step.x * 0.5, b) - dent.call(a - step.x * 0.5, b)) * amount / (step.x * width * 0.5)
				var dy: float = (dent.call(a, b + step.y * 0.5) - dent.call(a, b - step.y * 0.5)) * amount / (step.y * height * 0.5)
				n.append(Vector3(-dx * face, -dy * face, 1.0).normalized() * Vector3(1.0, 1.0, face))
				t.append_array(PackedFloat32Array([face, 0.0, 0.0, 1.0]))
				uv.append(Vector2((a * face + 1.0) * 0.5, (1.0 - b) * 0.5))
		for j in ny:
			for i in nx:
				var p0 := first + j * (nx + 1) + i
				var p1 := p0 + 1
				var p2 := p0 + nx + 1
				var p3 := p2 + 1
				if face > 0.0:
					idx.append_array(PackedInt32Array([p0, p2, p1, p1, p2, p3]))
				else:
					idx.append_array(PackedInt32Array([p0, p1, p2, p1, p3, p2]))
	# The rim: quads from the front grid's border to the back's.
	var row := nx + 1
	var back := row * (ny + 1)
	var rim := func(a: int, b: int, normal: Vector3) -> void:
		var base := v.size()
		for q: int in [a, b, back + a, back + b]:
			v.append(v[q])
			n.append(normal)
			t.append_array(PackedFloat32Array([0.0, 0.0, 1.0, 1.0]))
			uv.append(Vector2.ZERO)
		var outward := (v[base + 1] - v[base]).cross(v[base + 2] - v[base]).dot(normal) < 0.0
		if outward:
			idx.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
		else:
			idx.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
	for i in nx:
		rim.call(i, i + 1, Vector3.DOWN)
		rim.call(row * ny + i, row * ny + i + 1, Vector3.UP)
	for j in ny:
		rim.call(row * j, row * (j + 1), Vector3.LEFT)
		rim.call(row * j + nx, row * (j + 1) + nx, Vector3.RIGHT)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TANGENT] = t
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


## The warm line of light down the jambs when a leaf's been dented away from them.
static func door_seam(width: float, height: float) -> ArrayMesh:
	return _cached("seam_%.3f_%.3f" % [width, height], func() -> ArrayMesh:
		var m := KitMesh.new()
		var look: Dictionary = _cfg().door_look
		var w := float(look.seam_w_m)
		var hh := height * float(look.seam_h_frac) * 0.5
		var hw := width * 0.5
		m.box(Vector3(-hw, -hh, -w), Vector3(-hw + w, hh, w), "leak")
		m.box(Vector3(hw - w, -hh, -w), Vector3(hw, hh, w), "leak")
		return m.build())


# --- box props (A006-07b) ---

## The crate for `type` at exactly `size`. Empty string types with a slot in data "slots" get null.
static func prop(type: String, size: Vector3) -> ArrayMesh:
	if _cfg().slots.has(type):
		return slot_box(size)
	var key := "prop_%s_%.3f_%.3f_%.3f" % [type, size.x, size.y, size.z]
	return _cached(key, func() -> ArrayMesh:
		var m := KitMesh.new()
		m.uv_offset = _uv_offset(key.hash() % int(_cfg().uv_variants))
		var c: Dictionary = _cfg().crate
		if type == "ammo_crate":
			_ammo(m, size, c)
		elif size.y >= float(c.stack_min_h_m):
			var half := size.y * 0.5
			_crate(m, Vector3(size.x, half, size.z), 0.0, c, true)
			_crate(m, Vector3(size.x, half, size.z), half, c, true)
		else:
			_crate(m, size, 0.0, c, size.y >= float(c.tall_min_h_m))
		return m.build())


## The box a Meshy prop replaces when its file lands (bed, console, cabinet, lockers).
static func slot_box(size: Vector3) -> ArrayMesh:
	var key := "slot_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	return _cached(key, func() -> ArrayMesh:
		var m := KitMesh.new()
		var d: Dictionary = _cfg().dims
		m.box(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), Vector3(size.x * 0.5, size.y, size.z * 0.5), String(_cfg().slot_mat), float(d.chamfer_m))
		return m.build())


static func _crate(m: KitMesh, size: Vector3, y0: float, c: Dictionary, ribbed: bool) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var y1 := y0 + size.y
	var rail := float(c.rail_m)
	var post := float(c.post_m)
	var inset := float(c.panel_inset_m)
	var cham := float(_cfg().dims.chamfer_m)
	# Body inside the frame.
	m.box(Vector3(-hx + inset, y0, -hz + inset), Vector3(hx - inset, y1 - inset, hz - inset), "steel")
	# Frame: bottom and top rails around, four corner posts.
	for y: Array in [[y0, y0 + rail], [y1 - rail, y1]]:
		m.box(Vector3(-hx, y[0], -hz), Vector3(hx, y[1], -hz + rail), "steel", cham)
		m.box(Vector3(-hx, y[0], hz - rail), Vector3(hx, y[1], hz), "steel", cham)
		m.box(Vector3(-hx, y[0], -hz), Vector3(-hx + rail, y[1], hz), "steel", cham)
		m.box(Vector3(hx - rail, y[0], -hz), Vector3(hx, y[1], hz), "steel", cham)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var a := Vector3(sx * hx, y0, sz * hz)
			var b := Vector3(sx * (hx - post), y1, sz * (hz - post))
			m.box(Vector3(minf(a.x, b.x), y0, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), y1, maxf(a.z, b.z)), "steel", cham)
	# Lid plate, and hazard brackets on its corners: from above, this is what a crate is.
	var lid := float(c.lid_inset_m)
	var top := y1 - float(c.bracket_h_m)
	m.box(Vector3(-hx + lid, top - float(c.bracket_h_m), -hz + lid), Vector3(hx - lid, top, hz - lid), "deck")
	var br := float(c.bracket_m)
	var bh := float(c.bracket_h_m)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var ax := sx * hx
			var az := sz * hz
			m.box(Vector3(minf(ax, ax - sx * br), y1 - bh, minf(az, az - sz * br)),
					Vector3(maxf(ax, ax - sx * br), y1, maxf(az, az - sz * br)), "hazard")
	# Sides: ivory inset panels on a low crate, dark ribs and an ivory strip on a tall one.
	var y2 := y0 + rail
	var y3 := y1 - rail
	for side: float in [-1.0, 1.0]:
		var zo := side * hz
		var zi := side * (hz - inset * 0.6)
		if not ribbed:
			var w := hx - post * 1.3
			m.box(Vector3(-w, y2, minf(zo, zi)), Vector3(w, y3, maxf(zo, zi)), "hull", cham * 0.5)
		else:
			var step := float(c.rib_every_m)
			var rw := float(c.rib_w_m)
			var x := -hx + post + step
			while x + rw < hx - post:
				m.box(Vector3(x, y2, minf(zo, zi)), Vector3(x + rw, y3, maxf(zo, zi)), "steel", cham * 0.5)
				x += step
			m.box(Vector3(-rw * 1.5, y2, minf(zo, zi)), Vector3(rw * 1.5, y3, maxf(zo, zi)), "hull")
		var xo := side * hx
		var xi := side * (hx - inset * 0.6)
		var w2 := hz - post * 1.3
		m.box(Vector3(minf(xo, xi), y2, -w2), Vector3(maxf(xo, xi), y3, w2), "hull" if not ribbed else "steel", cham * 0.5)


static func _ammo(m: KitMesh, size: Vector3, c: Dictionary) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var cham := float(_cfg().dims.chamfer_m)
	m.box(Vector3(-hx, 0.0, -hz), Vector3(hx, size.y, hz), "ammo", cham * 2.0)
	var strap := float(c.ammo_strap_m)
	for sx: float in [-0.3, 0.3]:
		m.box(Vector3(sx * size.x - strap * 0.5, 0.0, -hz), Vector3(sx * size.x + strap * 0.5, size.y, hz), "steel", cham * 0.5)


# --- floors ---

## All of one space's floor as one mesh, in world coordinates: plates with real seams, cut around grate
## runs and drains, hazard edging and grime at the walls and corners. `doors` are door rects to edge around.
static func floor_space(rect: Rect2, spec: Dictionary, doors: Array) -> ArrayMesh:
	var f: Dictionary = _cfg().floors
	var m := KitMesh.new()
	var g: Dictionary = _cfg().grime
	var low := float(g.floor_shade)
	var corner := float(g.floor_corner_shade)
	var reach := float(g.height_m)
	var tone := float(g.plate_tone)
	var plate_at := Vector2(float(f.plate_m), float(f.plate_m))
	m.shade = func(p: Vector3) -> float:
		var q := Vector2(p.x, p.z)
		var dx := minf(q.x - rect.position.x, rect.end.x - q.x)
		var dz := minf(q.y - rect.position.y, rect.end.y - q.y)
		var wall := lerpf(low, 1.0, smoothstep(0.0, reach, minf(dx, dz)))
		var corners := lerpf(corner, 1.0, smoothstep(0.0, reach * 2.0, maxf(dx, dz)))
		# Each plate a little different, so the floor isn't one sheet.
		var cell := Vector2i(((q - rect.position) / plate_at).floor())
		var vary := 1.0 - tone * absf(sin(float(cell.x * 7 + cell.y * 13)))
		return wall * corners * vary
	var cuts: Array = []
	var seam := float(f.seam_m)
	var plate_h := float(f.plate_h_m)
	var frame := float(f.grate_frame_m)
	var frame_h := float(f.grate_frame_h_m)
	for gr: Dictionary in spec.grates:
		cuts.append(_floor_grate(m, rect, Vector2(float(gr.at[0]), float(gr.at[1])), Vector2(float(gr.size_m[0]), float(gr.size_m[1])), frame, frame_h))
	var dm := float(f.drain_m)
	for dr: Array in spec.drains:
		cuts.append(_floor_grate(m, rect, Vector2(float(dr[0]), float(dr[1])), Vector2(dm, dm), frame, frame_h))
	m.box(Vector3(rect.position.x, -float(f.slab_m), rect.position.y), Vector3(rect.end.x, -plate_h, rect.end.y), "floor_slab")
	# Plates from the room's corner; the last row and column are the closing pieces.
	var tile := float(f.plate_m)
	var nx := ceili(rect.size.x / tile - 0.001)
	var nz := ceili(rect.size.y / tile - 0.001)
	for j in nz:
		for i in nx:
			var o := rect.position + Vector2(i, j) * tile
			var plate := Rect2(o, Vector2(minf(tile, rect.end.x - o.x), minf(tile, rect.end.y - o.y)))
			m.uv_offset = _uv_offset(i * 3 + j * 5)
			for r: Rect2 in _subtract(plate, cuts):
				var inner := r.grow(-seam * 0.5)
				if inner.size.x > 0.0 and inner.size.y > 0.0:
					m.box(Vector3(inner.position.x, -plate_h, inner.position.y), Vector3(inner.end.x, 0.0, inner.end.y), "deck", seam * 0.4)
					_rivets(m, inner, f)
	m.uv_offset = Vector2.ZERO
	_floor_edging(m, rect, doors, f.hazard, cuts)
	return m.build()


## A rivet in each corner of a plate big enough to want them.
static func _rivets(m: KitMesh, plate: Rect2, f: Dictionary) -> void:
	var inset := float(f.rivet_inset_m)
	var half := float(f.rivet_m) * 0.5
	var y := float(f.rivet_h_m)
	if minf(plate.size.x, plate.size.y) < inset * 2.0 + half * 2.0:
		return
	for x: float in [plate.position.x + inset, plate.end.x - inset]:
		for z: float in [plate.position.y + inset, plate.end.y - inset]:
			m.box(Vector3(x - half, 0.0, z - half), Vector3(x + half, y, z + half), "steel")


## A grate at fractions `at` of the room, clipped to it, with a low frame. Returns its footprint.
static func _floor_grate(m: KitMesh, rect: Rect2, at: Vector2, size: Vector2, frame: float, frame_h: float) -> Rect2:
	var c := rect.position + rect.size * at
	var r := Rect2(c - size * 0.5, size).intersection(rect)
	if r.size == Vector2.ZERO:
		return r
	m.box(Vector3(r.position.x + frame, -frame_h, r.position.y + frame), Vector3(r.end.x - frame, 0.0, r.end.y - frame), "grate")
	for e: Rect2 in [Rect2(r.position, Vector2(r.size.x, frame)), Rect2(r.position.x, r.end.y - frame, r.size.x, frame),
			Rect2(r.position, Vector2(frame, r.size.y)), Rect2(r.end.x - frame, r.position.y, frame, r.size.y)]:
		m.box(Vector3(e.position.x, -frame_h, e.position.y), Vector3(e.end.x, frame_h, e.end.y), "steel")
	return r


## Dashed yellow lines inside the walls, broken at doors and grates.
static func _floor_edging(m: KitMesh, rect: Rect2, doors: Array, h: Dictionary, cuts: Array) -> void:
	var inset := float(h.inset_m)
	var w := float(h.width_m)
	var dash := float(h.dash_m)
	var gap := float(h.gap_m)
	var y := float(h.h_m)
	var inner := rect.grow(-inset)
	var blocked: Array = cuts.duplicate()
	for dr: Rect2 in doors:
		blocked.append(dr.grow(inset + w))
	for line: Rect2 in [Rect2(inner.position, Vector2(inner.size.x, w)), Rect2(inner.position.x, inner.end.y - w, inner.size.x, w),
			Rect2(inner.position, Vector2(w, inner.size.y)), Rect2(inner.end.x - w, inner.position.y, w, inner.size.y)]:
		var along_x := line.size.x > line.size.y
		var length := line.size.x if along_x else line.size.y
		var s := 0.0
		while s < length:
			var e := minf(s + dash, length)
			var r := Rect2(line.position + Vector2(s, 0.0), Vector2(e - s, w)) if along_x \
					else Rect2(line.position + Vector2(0.0, s), Vector2(w, e - s))
			for part: Rect2 in _subtract(r, blocked):
				m.box(Vector3(part.position.x, 0.0, part.position.y), Vector3(part.end.x, y, part.end.y), "line")
			s = e + gap


## The floor of a doorway: plate, with a hazard strip on each lip.
static func threshold(rect: Rect2, along_x: bool, hazard: bool) -> ArrayMesh:
	var f: Dictionary = _cfg().floors
	var m := KitMesh.new()
	var t: Dictionary = f.threshold
	var plate_h := float(f.plate_h_m)
	m.box(Vector3(rect.position.x, -float(f.slab_m), rect.position.y), Vector3(rect.end.x, 0.0, rect.end.y), "steel")
	if hazard:
		var w := float(t.strip_m)
		var hh := float(t.h_m)
		var strips: Array = [Rect2(rect.position, Vector2(rect.size.x, w)), Rect2(rect.position.x, rect.end.y - w, rect.size.x, w)] if along_x \
				else [Rect2(rect.position, Vector2(w, rect.size.y)), Rect2(rect.end.x - w, rect.position.y, w, rect.size.y)]
		for s: Rect2 in strips:
			m.box(Vector3(s.position.x, 0.0, s.position.y), Vector3(s.end.x, hh, s.end.y), "hazard")
	m.box(Vector3(rect.position.x, -float(f.slab_m), rect.position.y), Vector3(rect.end.x, -plate_h, rect.end.y), "floor_slab")
	return m.build()


## `r` minus every rect in `cuts`, as up to a few rects.
static func _subtract(r: Rect2, cuts: Array) -> Array:
	var parts: Array = [r]
	for c: Rect2 in cuts:
		var next: Array = []
		for p: Rect2 in parts:
			var i := p.intersection(c)
			if i.size.x <= 0.0 or i.size.y <= 0.0:
				next.append(p)
				continue
			if i.position.y > p.position.y:
				next.append(Rect2(p.position, Vector2(p.size.x, i.position.y - p.position.y)))
			if i.end.y < p.end.y:
				next.append(Rect2(p.position.x, i.end.y, p.size.x, p.end.y - i.end.y))
			if i.position.x > p.position.x:
				next.append(Rect2(p.position.x, i.position.y, i.position.x - p.position.x, i.size.y))
			if i.end.x < p.end.x:
				next.append(Rect2(i.end.x, i.position.y, p.end.x - i.end.x, i.size.y))
		parts = next
	return parts


# --- practical fixtures ---

## A light strip: a housing on the wall (its back at Z 0) and the emissive tube, horizontal along X
## or `vertical` along Y.
static func fixture(mat: String, vertical: bool) -> ArrayMesh:
	return _cached("fixture_%s_%s" % [mat, vertical], func() -> ArrayMesh:
		var m := KitMesh.new()
		var f: Dictionary = _cfg().lighting.fixtures
		var l := float(f.vertical_length_m if vertical else f.length_m) * 0.5
		var hw := float(f.housing.w_m) * 0.5
		var ht := float(f.housing.t_m)
		var sw := float(f.strip.w_m) * 0.5
		var st := float(f.strip.t_m)
		var e := Vector3(hw, l, 0.0) if vertical else Vector3(l, hw, 0.0)
		var s := Vector3(sw, l - hw * 0.5, 0.0) if vertical else Vector3(l - hw * 0.5, sw, 0.0)
		m.box(Vector3(-e.x, -e.y, 0.0), Vector3(e.x, e.y, ht), "housing", float(_cfg().dims.chamfer_m) * 0.5)
		m.box(Vector3(-s.x, -s.y, ht), Vector3(s.x, s.y, ht + st), mat)
		return m.build())


## The layer only floor plates are on: probes reflect in these and nothing else, for what the sheen's
## on and no more (T011). No light or camera asks for it by itself.
static func floor_layer() -> int:
	return 1 << int(_cfg().floor_wear.layer_index)


## Bit of the render layer a space's static geometry sits on. Its lights touch only that layer (and
## the default layer: characters, doors), so a room's lamp can't shine through a wall into the next.
static func space_layer(layout: RefCounted, space: String) -> int:
	var i: int = layout.space_order.find(space)
	return 0 if i < 0 else 1 << (i + 1)
