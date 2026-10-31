extends RefCounted
## Scene-free mesh builder for the kit: chamfered boxes, cylinders and quads gathered per material
## into one ArrayMesh. UVs are in metres (material "uv_m"), so nothing stretches at any length.
## Vertex colours paint the grime, low and in corners, without touching the textures.

const KitMaterials := preload("res://src/kit/kit_materials.gd")
const FRONT_FACING_SIGN := -1.0  # Godot's front faces wind clockwise

var uv_offset := Vector2.ZERO
## Optional fn(world point) -> shade 0..1; default is the height falloff in data "grime".
var shade: Callable

var _surfaces := {}
var _grime_h := 1.0
var _grime_floor := 1.0


func _init() -> void:
	var g: Dictionary = KitMaterials.cfg().grime
	_grime_h = float(g.height_m)
	_grime_floor = float(g.floor_shade)


func _surface(mat: String) -> Dictionary:
	if not _surfaces.has(mat):
		_surfaces[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "t": PackedFloat32Array(),
				"uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array(),
				"uv_m": KitMaterials.uv_metres(mat)}
	return _surfaces[mat]


func _colour(p: Vector3) -> Color:
	var s: float
	if shade.is_valid():
		s = shade.call(p)
	else:
		s = lerpf(_grime_floor, 1.0, smoothstep(0.0, _grime_h, p.y))
	return Color(s, s, s)


## One flat polygon (triangle or quad, any winding) with normal `n`, tangent `t`.
func _poly(s: Dictionary, pts: Array, n: Vector3, t: Vector3) -> void:
	var base: int = s.v.size()
	var b := n.cross(t)
	var m: float = s.uv_m
	for p: Vector3 in pts:
		s.v.append(p)
		s.n.append(n)
		s.t.append_array(PackedFloat32Array([t.x, t.y, t.z, 1.0]))
		# Image up is the binormal, so the OpenGL normal maps agree with the UVs.
		s.uv.append(Vector2(p.dot(t) / m, -p.dot(b) / m) + uv_offset)
		s.c.append(_colour(p))
	var a: Vector3 = pts[0]
	var flip: bool = (pts[1] - a).cross(pts[2] - a).dot(n) * FRONT_FACING_SIGN < 0.0
	for k in pts.size() - 2:
		var j1: int = k + (2 if flip else 1)
		var j2: int = k + (1 if flip else 2)
		s.i.append(base)
		s.i.append(base + j1)
		s.i.append(base + j2)


## Axis-aligned box from `lo` to `hi`, its edges cut by `chamfer` metres. The outer bounds stay exact.
func box(lo: Vector3, hi: Vector3, mat: String, chamfer := 0.0) -> void:
	var s := _surface(mat)
	var c := minf(chamfer, minf(hi.x - lo.x, minf(hi.y - lo.y, hi.z - lo.z)) * 0.5)
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var pt := func(sx: float, sy: float, sz: float, keep: int) -> Vector3:
		return Vector3(
				(hi.x if sx > 0.0 else lo.x) - sx * (0.0 if keep == 0 else c),
				(hi.y if sy > 0.0 else lo.y) - sy * (0.0 if keep == 1 else c),
				(hi.z if sz > 0.0 else lo.z) - sz * (0.0 if keep == 2 else c))
	var at := func(a: int, sa: float, b: int, sb: float, d: int, sd: float, keep: int) -> Vector3:
		var v := Vector3.ZERO
		v[a] = sa
		v[b] = sb
		v[d] = sd
		return pt.call(v.x, v.y, v.z, keep)
	for a in 3:
		var b: int = (a + 1) % 3
		var d: int = (a + 2) % 3
		for sa: float in [-1.0, 1.0]:
			var n: Vector3 = axes[a] * sa
			var t: Vector3 = Vector3.RIGHT
			if a == 0:
				t = Vector3.BACK * -sa
			elif a == 2:
				t = Vector3.RIGHT * sa
			_poly(s, [at.call(a, sa, b, -1.0, d, -1.0, a), at.call(a, sa, b, 1.0, d, -1.0, a),
					at.call(a, sa, b, 1.0, d, 1.0, a), at.call(a, sa, b, -1.0, d, 1.0, a)], n, t)
	if c <= 0.0:
		return
	# The cut edges: a quad along each of the twelve, a triangle at each of the eight corners.
	for a in 3:
		var b: int = (a + 1) % 3
		var d: int = (a + 2) % 3
		for sb: float in [-1.0, 1.0]:
			for sd: float in [-1.0, 1.0]:
				var n: Vector3 = (axes[b] * sb + axes[d] * sd).normalized()
				_poly(s, [at.call(a, -1.0, b, sb, d, sd, b), at.call(a, 1.0, b, sb, d, sd, b),
						at.call(a, 1.0, b, sb, d, sd, d), at.call(a, -1.0, b, sb, d, sd, d)], n, axes[a])
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var n := Vector3(sx, sy, sz).normalized()
				var t := n.cross(Vector3.UP).normalized() if absf(n.y) < 0.99 else Vector3.RIGHT
				_poly(s, [pt.call(sx, sy, sz, 0), pt.call(sx, sy, sz, 1), pt.call(sx, sy, sz, 2)], n, t)


## An upright cylinder, smooth-shaded, no caps below.
func cylinder(base: Vector3, height: float, radius: float, sides: int, mat: String) -> void:
	var s := _surface(mat)
	var m: float = s.uv_m
	var first: int = s.v.size()
	for k in sides + 1:
		var a := TAU * k / sides
		var n := Vector3(cos(a), 0.0, sin(a))
		var t := Vector3(-sin(a), 0.0, cos(a))
		for j in 2:
			var p := base + n * radius + Vector3.UP * (height * j)
			s.v.append(p)
			s.n.append(n)
			s.t.append_array(PackedFloat32Array([t.x, t.y, t.z, 1.0]))
			s.uv.append(Vector2(a * radius / m, -p.y / m) + uv_offset)
			s.c.append(_colour(p))
	for k in sides:
		var i0 := first + k * 2
		for idx: int in [i0, i0 + 2, i0 + 1, i0 + 1, i0 + 2, i0 + 3]:
			s.i.append(idx)


## Finishes the mesh: one surface per material, sorted, named after its material key.
func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var keys: Array = _surfaces.keys()
	keys.sort()
	for key: String in keys:
		var s: Dictionary = _surfaces[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.v
		arrays[Mesh.ARRAY_NORMAL] = s.n
		arrays[Mesh.ARRAY_TANGENT] = s.t
		arrays[Mesh.ARRAY_TEX_UV] = s.uv
		arrays[Mesh.ARRAY_COLOR] = s.c
		arrays[Mesh.ARRAY_INDEX] = s.i
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var idx := mesh.get_surface_count() - 1
		mesh.surface_set_name(idx, key)
		mesh.surface_set_material(idx, KitMaterials.material(key))
	return mesh
