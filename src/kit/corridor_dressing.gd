extends RefCounted
## The corridors' structure (T019), from data/deck.json "corridor_dressing": ribs, one high run and one
## low run, door surrounds, corner pillars and a few singles. Looks only, like src/kit/dressing.gd, but
## worked out in metres against the deck it's on, so a door or a crate on another deck just makes a gap.
## A wall piece goes on the wall pivot behind it and fades with it. Env KIT_CORRIDORS=off prices it.

const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const Dressing := preload("res://src/kit/dressing.gd")

const LOW_COVER := "low"

static var _below_cache := {}


## Every corridor piece on this deck: Dressing's fields, plus `box` (world AABB), `low_rect` (footprint
## of what's below `below_m`; empty if nothing is), `scale_x`, `shadow`, and `host_at` (the point on the
## wall behind it; null for floor clutter). Fixtures aren't here: they belong to their lights.
static func placed(layout: RefCounted) -> Array:
	var out: Array = []
	var cfg: Dictionary = layout.data.get("corridor_dressing", {})
	var corridors: Dictionary = cfg.get("corridors", {})
	for space: String in corridors:
		if layout.spaces.has(space):
			out.append_array(_corridor(layout, space, corridors[space], cfg))
	return out


static func build(layout: RefCounted, walls: Node3D, frames: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "CorridorDressing"
	if OS.get_environment("KIT_CORRIDORS") == "off":
		return root
	for piece: Dictionary in placed(layout):
		var mi := MeshInstance3D.new()
		mi.name = String(piece.type).to_pascal_case()
		mi.mesh = piece.mesh
		mi.set_meta("kit_piece", String(piece.type))
		mi.layers = KitPieces.space_layer(layout, String(piece.space))
		mi.rotation.y = piece.yaw
		mi.scale.x = piece.scale_x
		if not piece.shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var host: Node3D = null if piece.host_at == null else _host(walls, frames, piece.host_at)
		if host != null:
			mi.position = (piece.position as Vector3) - Vector3(host.position.x, 0.0, host.position.z)
			host.add_child(mi)
		else:
			mi.position = piece.position
			root.add_child(mi)
	return root


static func _host(walls: Node3D, frames: Node3D, p: Vector2) -> Node3D:
	for parent: Node3D in [walls, frames]:
		for n: Node in parent.get_children():
			if n.has_meta("cutaway_rect") and (n.get_meta("cutaway_rect") as Rect2).has_point(p):
				return n
	return null


static func _corridor(layout: RefCounted, space: String, spec: Dictionary, cfg: Dictionary) -> Array:
	var ctx := {"layout": layout, "space": space, "cfg": cfg, "rect": layout.space_rect(space), "out": [], "solid": [], "ribs": [],
			"runs": [], "keep_all": _door_zones(layout, cfg), "keep_low": []}
	_keep_off_props(ctx)
	_keep_off_named(ctx, spec.get("clear", []))
	_note_fixtures_and_signs(ctx)
	_door_pieces(ctx)
	for e: Dictionary in spec.get("landmarks", []):
		_single(ctx, e)
	for corner: String in spec.get("pillars", []):
		_pillar(ctx, corner)
	_ribs(ctx, spec.get("ribs", {}))
	for run: Dictionary in spec.get("runs", []):
		_run(ctx, run)
	for e: Dictionary in spec.get("singles", []):
		_single(ctx, e)
	for e: Dictionary in spec.get("floor", []):
		_floor_piece(ctx, e)
	return ctx.out


# --- what a piece must stay off ---

static func _door_zones(layout: RefCounted, cfg: Dictionary) -> Array:
	var clear := float(cfg.door_clear_m)
	var zones: Array = []
	for d: Dictionary in layout.doors:
		zones.append((d.rect as Rect2).grow(clear))
	for b: Dictionary in layout.breaches:
		zones.append((b.rect as Rect2).grow(clear))
	return zones


## Every prop's body, and the line along a low prop's long sides where you brace (a tippable bed's: where
## it lands). A square one can be braced from any side. Tall cover only has to be kept off.
static func _keep_off_props(ctx: Dictionary) -> void:
	var layout: RefCounted = ctx.layout
	var gap := float(ctx.cfg.prop_gap_m)
	for i in layout.props.size():
		var p: Dictionary = layout.props[i]
		var r: Rect2 = p.rect
		ctx.keep_all.append(r.grow(gap))
		var reach := 0.0
		if bool(layout.data.props[i].get("tippable", false)):
			reach = (p.size as Vector3).y
		elif p.cover == LOW_COVER:
			reach = float(ctx.cfg.low_cover_line_m)
		if r.size.x == r.size.y:
			ctx.keep_low.append(r.grow(reach))
		elif r.size.y > r.size.x:
			ctx.keep_low.append(r.grow_individual(reach, 0.0, reach, 0.0))
		else:
			ctx.keep_low.append(r.grow_individual(0.0, reach, 0.0, reach))


## Spans of a wall something else lives on (a CUSTODIAN terminal).
static func _keep_off_named(ctx: Dictionary, entries: Array) -> void:
	for e: Dictionary in entries:
		var face := Dressing.wall_face(ctx.rect, String(e.wall))
		var at: Vector2 = face.start + face.along * float(face.length) * float(e.at)
		var half: Vector2 = face.along * float(e.half_m)
		var deep: Vector2 = face.inward * float(ctx.layout.data.dressing_max_intrusion_m)
		var r := Rect2(at - half, Vector2.ZERO).expand(at + half).expand(at - half + deep).expand(at + half + deep)
		ctx.keep_all.append(r)


static func _note_fixtures_and_signs(ctx: Dictionary) -> void:
	var kit: Dictionary = KitMaterials.cfg()
	for e: Dictionary in (kit.lighting.fixtures.spaces as Dictionary).get(ctx.space, []):
		if e.has("prop"):
			var face := Dressing.wall_face(ctx.rect, String(e.wall))
			ctx.solid.append(_wall_piece(ctx, String(e.prop), String(e.wall), float(face.length) * float(e.get("prop_at", e.at))).box)
	for e: Dictionary in kit.signage.walls:
		if String(e.space) == ctx.space:
			var face := Dressing.wall_face(ctx.rect, String(e.wall))
			var at: Vector2 = face.start + face.along * float(face.length) * float(e.at)
			var half := float(e.width_m) * 0.5
			var tex: Texture2D = KitMaterials.decal(String(e.image)).albedo_texture
			var half_h := half * (float(tex.get_height()) / float(tex.get_width()) if tex else 1.0)
			var span := face.along as Vector2 * half
			var deep := face.inward as Vector2 * float(ctx.layout.data.dressing_max_intrusion_m)
			var flat := Rect2(at - span, Vector2.ZERO).expand(at + span).expand(at - span + deep).expand(at + span + deep)
			ctx.solid.append(AABB(Vector3(flat.position.x, float(e.y_m) - half_h, flat.position.y), Vector3(flat.size.x, half_h * 2.0, flat.size.y)))


# --- the pieces, most important first ---

## The corridor's face of each door: a jamb past each post, so the door's lamp still shows, and the
## lintel over the opening, scaled to it.
static func _door_pieces(ctx: Dictionary) -> void:
	var layout: RefCounted = ctx.layout
	var t := float(layout.data.wall_thickness_m)
	for d: Dictionary in layout.doors:
		for wall: String in Dressing.WALL_YAW:
			var face := Dressing.wall_face(ctx.rect, wall)
			var band := _band(face, t)
			if not band.grow(float(ctx.cfg.door_touch_m)).encloses(d.rect):
				continue
			var opening: Rect2 = d.rect
			var mid: float = (opening.get_center() - (face.start as Vector2)).dot(face.along)
			var half: float = (opening.size.x if d.along_x else opening.size.y) * 0.5
			var post := float(layout.data.door_frame_m)
			var jamb := _wall_piece(ctx, "door_jamb", wall, 0.0)
			var jamb_w: float = (jamb.mesh as ArrayMesh).get_aabb().size.x
			for side: int in [-1, 1]:
				var p := _wall_piece(ctx, "door_jamb", wall, mid + side * (half + post + jamb_w * 0.5), _mirror_for(wall, side))
				_keep_host(p, d.frames[0 if side < 0 else 1])
				ctx.out.append(p)
				ctx.solid.append(p.box)
			var lintel_w: float = (KitPieces.slot_mesh(KitPieces.slot_file("door_lintel", Vector3.ZERO))).get_aabb().size.x
			var lintel := _wall_piece(ctx, "door_lintel", wall, mid, half * 2.0 / lintel_w)
			_keep_host(lintel, d.frames[0])
			ctx.out.append(lintel)
			ctx.solid.append(lintel.box)


## Which way a jamb's file faces so the pair mirrors about the door, whichever way the wall runs.
static func _mirror_for(wall: String, side: int) -> float:
	return float(side) if wall in ["north", "west"] else float(-side)


static func _keep_host(piece: Dictionary, frame: Rect2) -> void:
	piece.host_at = frame.get_center()


static func _pillar(ctx: Dictionary, corner: String) -> void:
	var r: Rect2 = ctx.rect
	var north := corner.begins_with("n")
	var west := corner.ends_with("w")
	var t := float(ctx.layout.data.wall_thickness_m)
	var nudge := float(ctx.cfg.corner_probe_m)
	var cx := r.position.x if west else r.end.x
	var cz := r.position.y if north else r.end.y
	var behind_x := Vector2(cx + (nudge if west else -nudge), cz + (-t * 0.5 if north else t * 0.5))
	var behind_z := Vector2(cx + (-t * 0.5 if west else t * 0.5), cz + (nudge if north else -nudge))
	if not _wall_at(ctx.layout, behind_x) or not _wall_at(ctx.layout, behind_z):
		return
	var mesh := _mesh("corner_pillar")
	var yaw: float = Dressing.WALL_YAW["north" if north else "south"]
	var box: AABB = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * mesh.get_aabb()
	var x := cx - box.position.x if west else cx - box.end.x
	var z := cz - box.position.z if north else cz - box.end.z
	var y := float(KitMaterials.cfg().wall_mounts.corner_pillar.mount_y_m)
	var p := _make(ctx, "corner_pillar", "north" if north else "south", mesh, Vector3(x, y, z), yaw, 1.0)
	p.host_at = behind_x
	if _fits(ctx, p, [ctx.solid]):
		ctx.out.append(p)
		ctx.solid.append(p.box)


static func _ribs(ctx: Dictionary, spec: Dictionary) -> void:
	for wall: String in spec.get("start_m", {}):
		var length: float = Dressing.wall_face(ctx.rect, wall).length
		var at := float(spec.start_m[wall])
		while at < length:
			var p := _wall_piece(ctx, String(spec.type), wall, at)
			if _fits(ctx, p, [ctx.solid]):
				ctx.out.append(p)
				ctx.ribs.append(p.box)
				at += float(spec.every_m)
			else:
				at += float(ctx.cfg.run_search_m)


## Sections butted end to end wherever a whole one fits; pipes run through the ribs, as on a real ship.
static func _run(ctx: Dictionary, spec: Dictionary) -> void:
	var type := String(spec.type)
	var wall := String(spec.wall)
	var w: float = _mesh(type).get_aabb().size.x
	var length: float = Dressing.wall_face(ctx.rect, wall).length
	var at := float(spec.get("start_m", 0.0))
	while at + w <= length:
		var p := _wall_piece(ctx, type, wall, at + w * 0.5)
		if _fits(ctx, p, [ctx.solid]):
			ctx.out.append(p)
			ctx.runs.append(p.box)
			at += w
		else:
			at += float(ctx.cfg.run_search_m)


## Where the data says, or the nearest spot within `single_slide_m` that's free on this deck.
static func _single(ctx: Dictionary, e: Dictionary) -> void:
	var wall := String(e.wall)
	var length: float = Dressing.wall_face(ctx.rect, wall).length
	var against: Array = [] if bool(e.get("over", false)) else [ctx.solid, ctx.ribs, ctx.runs]
	var p := _free_spot(ctx, String(e.type), wall, length * float(e.at), float(ctx.cfg.single_slide_m), against)
	if not p.is_empty():
		ctx.out.append(p)
		ctx.solid.append(p.box)


static func _free_spot(ctx: Dictionary, type: String, wall: String, at: float, slide: float, against: Array) -> Dictionary:
	var step := float(ctx.cfg.single_step_m)
	for k in range(0, int(round(slide / step)) + 1):
		for sign_of: float in [1.0, -1.0]:
			var p := _wall_piece(ctx, type, wall, at + sign_of * k * step)
			if _fits(ctx, p, against):
				return p
	return {}


static func _floor_piece(ctx: Dictionary, e: Dictionary) -> void:
	var c: Vector2 = ctx.layout.point_in(ctx.space, e.at)
	var yaw := deg_to_rad(float(e.get("turn_deg", 0.0)))
	var p := _make(ctx, String(e.type), "", _mesh(String(e.type)), Vector3(c.x, 0.0, c.y), yaw, float(e.get("scale_x", 1.0)))
	p.host_at = null
	ctx.out.append(p)


# --- one piece ---

static func _mesh(type: String) -> ArrayMesh:
	return KitPieces.slot_mesh(KitPieces.slot_file(type, Vector3.ZERO))


static func _wall_piece(ctx: Dictionary, type: String, wall: String, along_m: float, scale_x: float = 1.0) -> Dictionary:
	var mesh := _mesh(type)
	var pose := Dressing.wall_pose(ctx.rect, wall, along_m, mesh, type)
	var p := _make(ctx, type, wall, mesh, pose.at, pose.yaw, scale_x)
	var face := Dressing.wall_face(ctx.rect, wall)
	var on_face: Vector2 = face.start + face.along * along_m
	p.host_at = on_face - (face.inward as Vector2) * float(ctx.layout.data.wall_thickness_m) * 0.5
	return p


static func _make(ctx: Dictionary, type: String, wall: String, mesh: ArrayMesh, at: Vector3, yaw: float, scale_x: float) -> Dictionary:
	var xform := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(scale_x, 1.0, 1.0)), at)
	var box: AABB = xform * mesh.get_aabb()
	var cut := float(ctx.cfg.below_m)
	var below := _below(mesh, cut)
	var low := Rect2()
	if below.size != Vector3.ZERO:
		var b: AABB = xform * below
		low = Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
	return {"type": type, "space": ctx.space, "wall": wall, "mesh": mesh, "position": at, "yaw": yaw, "scale_x": scale_x,
			"box": box, "rect": Rect2(box.position.x, box.position.z, box.size.x, box.size.z), "low_rect": low,
			"shadow": (ctx.cfg.cast_shadow as Array).has(type), "host_at": null}


## The bounds of the triangles with a corner under `cut` (zero size if none): a triangle that crosses
## the line counts whole, so this errs on the side of the wider footprint.
static func _below(mesh: ArrayMesh, cut: float) -> AABB:
	var key := "%s@%f" % [mesh.resource_name, cut]
	if _below_cache.has(key):
		return _below_cache[key]
	var box := AABB()
	var any := false
	for i in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for t in range(0, idx.size(), 3):
			if v[idx[t]].y < cut or v[idx[t + 1]].y < cut or v[idx[t + 2]].y < cut:
				for k in 3:
					box = box.expand(v[idx[t + k]]) if any else AABB(v[idx[t + k]], Vector3.ZERO)
					any = true
	_below_cache[key] = box
	return box


static func _fits(ctx: Dictionary, p: Dictionary, against: Array) -> bool:
	var face := Dressing.wall_face(ctx.rect, String(p.wall))
	var box: AABB = p.box
	var rect: Rect2 = p.rect
	if not _wall_behind(ctx, rect, face):
		return false
	if not (ctx.cfg.over_limit_ok as Array).has(p.type) and _intrusion(p, face) > float(ctx.layout.data.dressing_max_intrusion_m):
		return false
	for r: Rect2 in ctx.keep_all:
		if rect.intersects(r):
			return false
	if (p.low_rect as Rect2).has_area():
		for r: Rect2 in ctx.keep_low:
			if (p.low_rect as Rect2).intersects(r):
				return false
	for list: Array in against:
		for other: AABB in list:
			if box.intersects(other):
				return false
	return true


## How far past the wall's face the part below the line reaches.
static func _intrusion(p: Dictionary, face: Dictionary) -> float:
	var low: Rect2 = p.low_rect
	if not low.has_area():
		return 0.0
	var inward: Vector2 = face.inward
	var far := low.end.dot(inward) if inward.x + inward.y > 0.0 else low.position.dot(inward)
	return far - (face.start as Vector2).dot(inward)


static func _wall_behind(ctx: Dictionary, rect: Rect2, face: Dictionary) -> bool:
	var along: Vector2 = face.along
	var t := float(ctx.layout.data.wall_thickness_m)
	var nudge := float(ctx.cfg.corner_probe_m)
	var from: float = (face.start as Vector2).dot(along)
	var a := rect.position.dot(along) - from + nudge
	var b := rect.end.dot(along) - from - nudge
	if a < 0.0 or b > float(face.length):
		return false
	for at: float in [a, (a + b) * 0.5, b]:
		var p: Vector2 = (face.start as Vector2) + along * at - (face.inward as Vector2) * t * 0.5
		if not _wall_at(ctx.layout, p):
			return false
	return true


static func _wall_at(layout: RefCounted, p: Vector2) -> bool:
	for r: Rect2 in layout.walls:
		if r.has_point(p):
			return true
	return false


static func _band(face: Dictionary, t: float) -> Rect2:
	var a: Vector2 = face.start
	var b: Vector2 = a + (face.along as Vector2) * float(face.length)
	var back: Vector2 = -(face.inward as Vector2) * t
	return Rect2(a, Vector2.ZERO).expand(b).expand(a + back).expand(b + back)
