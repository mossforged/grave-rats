extends RefCounted
## Turns a DeckLayout into the deck: floors, walls (cut-away pivots), door frames and props, all kit
## pieces from src/kit, each with the same box collision the grey box had, plus the signage.

const DeckLayout := preload("res://src/study/deck_layout.gd")
const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const CUTAWAY_GROUP := &"camera_cutaway"  # the camera rig's contract (src/camera/CONTRACT.md)


## Returns a Node3D named "Deck" holding the whole deck for `layout`.
static func build(layout: DeckLayout) -> Node3D:
	var d := layout.data
	var kit: Dictionary = KitMaterials.cfg()
	var h := float(d.wall_height_m)
	var root := Node3D.new()
	root.name = "Deck"
	var floors := Node3D.new()
	floors.name = "Floors"
	root.add_child(floors)
	var door_rects: Array = layout.doors.map(func(e: Dictionary) -> Rect2: return e.rect)
	door_rects.append_array(layout.breaches.map(func(e: Dictionary) -> Rect2: return e.rect))
	var specs: Dictionary = kit.floors.spaces
	for n: String in layout.space_order:
		var spec: Dictionary = specs.get(n, specs.default)
		_add_floor(floors, n, KitPieces.floor_space(layout.space_rect(n), spec, door_rects), KitPieces.space_layer(layout, n))
	for door: Dictionary in layout.doors:
		_add_floor(floors, "Doorway", KitPieces.threshold(door.rect, door.along_x, true), _layers_around(layout, door.rect))
	for breach: Dictionary in layout.breaches:
		_add_floor(floors, "Breach", KitPieces.threshold(breach.rect, breach.along_x, false), _layers_around(layout, breach.rect))
	var walls := Node3D.new()
	walls.name = "Walls"
	root.add_child(walls)
	for r: Rect2 in layout.walls:
		_add_kit_wall(walls, layout, r, h, kit)
	var frames := Node3D.new()
	frames.name = "DoorFrames"
	root.add_child(frames)
	for door: Dictionary in layout.doors:
		_add_door_frame(frames, layout, door, h)
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	for p: Dictionary in layout.props:
		_add_prop(props, layout, p)
	_add_signage(root, walls, layout, kit.signage)
	return root


static func _add_floor(parent: Node3D, node_name: String, mesh: ArrayMesh, layers: int) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.layers = layers
	mi.set_meta("kit_piece", "floor")
	parent.add_child(mi)


## The render layers of every space touching `r`.
static func _layers_around(layout: DeckLayout, r: Rect2) -> int:
	var layers := 0
	var grown := r.grow(float(layout.data.wall_thickness_m))
	for n: String in layout.space_order:
		if layout.space_rect(n).intersects(grown):
			layers |= KitPieces.space_layer(layout, n)
	return layers if layers != 0 else 1


static func _add_kit_wall(parent: Node3D, layout: DeckLayout, r: Rect2, h: float, kit: Dictionary) -> void:
	var long_x := r.size.x >= r.size.y
	var length := r.size.x if long_x else r.size.y
	var depth := r.size.y if long_x else r.size.x
	var mi := MeshInstance3D.new()
	var dims: Dictionary = kit.dims
	var variant: int = absi(hash(Vector2i(roundi(r.position.x * 10.0), roundi(r.position.y * 10.0)))) % int(kit.bay_variants)
	if length <= float(dims.cap_stub_max_m):
		mi.mesh = KitPieces.wall_cap(length, depth, h, variant)
		mi.set_meta("kit_piece", "wall_cap")
	else:
		var c := r.get_center()
		# +Z of the piece: south on an X wall, west on a Z wall (it turns a quarter).
		var out := Vector2(0.0, depth * 0.5 + 0.1) if long_x else Vector2(-depth * 0.5 - 0.1, 0.0)
		var along := c.x if long_x else c.y
		var front := _family(layout, c + out, along, length, kit)
		var back := _family(layout, c - out, along, length, kit)
		var post := float(dims.post_m)
		var end_a := depth if _corner_at(layout, r, long_x, false, depth) else post
		var end_b := depth if _corner_at(layout, r, long_x, true, depth) else post
		mi.mesh = KitPieces.wall(length, depth, h, front, back, end_a, end_b, variant)
		mi.set_meta("kit_piece", "wall")
	mi.position.y = 0.0
	if not long_x:
		mi.rotation.y = -PI * 0.5
	mi.layers = _layers_around(layout, r)
	_add_wall(parent, "Wall", r, h, mi)


## Which family of wall a room shows on this face.
static func _family(layout: DeckLayout, p: Vector2, along: float, length: float, kit: Dictionary) -> String:
	var fams: Dictionary = kit.wall_families
	var space := layout.space_at(p)
	if space == "":
		return String(fams.outside)
	var fam := String((fams.by_space as Dictionary).get(space, fams.outside))
	if fam == "corridor":
		var bay := float(layout.data.wall_segment_m)
		if length >= float(fams.corridor_pipe_min_m) and posmod(roundi(along / bay), int(fams.corridor_pipe_every)) == 0:
			return "pipe"
	return fam


## True when another wall or post meets `r` from the side, at its low or (`high`) high end.
static func _corner_at(layout: DeckLayout, r: Rect2, long_x: bool, high: bool, depth: float) -> bool:
	var probe: Rect2
	if long_x:
		var x0 := r.end.x - depth if high else r.position.x
		probe = Rect2(x0, r.position.y - 0.01, depth, r.size.y + 0.02)
	else:
		var z0 := r.end.y - depth if high else r.position.y
		probe = Rect2(r.position.x - 0.01, z0, r.size.x + 0.02, depth)
	for other: Rect2 in layout.walls:
		if other != r and other.intersects(probe):
			var i := other.intersection(probe)
			if (i.size.y if long_x else i.size.x) <= 0.03:
				return true
	return false


## A wall piece: a floor-level pivot (scaled in Y or faded by the cut-away) holding the mesh, plus collision.
static func _add_wall(parent: Node3D, node_name: String, r: Rect2, h: float, mesh: MeshInstance3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = Vector3(r.get_center().x, 0.0, r.get_center().y)
	pivot.set_meta("cutaway_rect", r)
	pivot.set_meta("cutaway_height", h)
	pivot.add_to_group(CUTAWAY_GROUP)
	parent.add_child(pivot)
	pivot.add_child(mesh)
	_add_collision(parent, r, 0.0, h)
	return pivot


## Two jamb posts and the header over them. The visible post is A006's exact size; its collision and
## cut-away footprint stay what they were, 5 cm proud of the wall faces and top.
static func _add_door_frame(parent: Node3D, layout: DeckLayout, door: Dictionary, h: float) -> void:
	var along_x: bool = door.along_x
	var depth := float(layout.data.wall_thickness_m)
	var first: Node3D = null
	var layers := _layers_around(layout, door.rect)
	for fr: Rect2 in door.frames:
		var g := Vector2(0.0, 0.05) if along_x else Vector2(0.05, 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = KitPieces.door_jamb(float(layout.data.door_frame_m), depth, h)
		mi.set_meta("kit_piece", "door_jamb")
		mi.layers = layers
		if not along_x:
			mi.rotation.y = -PI * 0.5
		var pivot := _add_wall(parent, "Frame", Rect2(fr.position - g, fr.size + g * 2.0), h + 0.05, mi)
		if first == null:
			first = pivot
	# The header lives on the first post's pivot, so it fades with the frame (src/camera's contract).
	var header := MeshInstance3D.new()
	var rect: Rect2 = door.rect
	header.mesh = KitPieces.door_header(rect.size.x if along_x else rect.size.y, depth, h)
	header.name = "Header"
	header.set_meta("kit_piece", "door_header")
	header.layers = layers
	var off := rect.get_center() - Vector2(first.position.x, first.position.z)
	header.position = Vector3(off.x, 0.0, off.y)
	if not along_x:
		header.rotation.y = -PI * 0.5
	first.add_child(header)


static func _add_prop(parent: Node3D, layout: DeckLayout, p: Dictionary) -> void:
	var r: Rect2 = p.rect
	var mi := MeshInstance3D.new()
	mi.name = String(p.type).to_pascal_case()
	mi.mesh = KitPieces.prop(String(p.type), p.size)
	mi.set_meta("kit_piece", String(p.type))
	mi.position = Vector3(r.get_center().x, 0.0, r.get_center().y)
	mi.layers = KitPieces.space_layer(layout, String(p.space))
	parent.add_child(mi)
	_add_collision(parent, r, 0.0, p.size.y)


static func _add_collision(parent: Node3D, r: Rect2, y0: float, height: float) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(r.size.x, height, r.size.y)
	cs.shape = box
	body.position = Vector3(r.get_center().x, y0 + height * 0.5, r.get_center().y)
	body.add_child(cs)
	parent.add_child(body)


# --- signage (A002-08b): quads from data, on the wall pieces so they fade with them ---

static func _add_signage(root: Node3D, walls: Node3D, layout: DeckLayout, s: Dictionary) -> void:
	var out := float(s.wall_out_m)
	for e: Dictionary in s.walls:
		var space := String(e.space)
		if not layout.spaces.has(space):
			continue
		var r := layout.space_rect(space)
		var x := r.position.x + r.size.x * float(e.at)
		var face := r.position.y
		var pivot := wall_at(walls, Vector2(x, face - float(layout.data.wall_thickness_m) * 0.5))
		if pivot == null:
			continue
		var mi := _sign_quad(String(e.image), float(e.width_m), KitPieces.space_layer(layout, space))
		mi.position = Vector3(x - pivot.position.x, float(e.y_m), face + out - pivot.position.z)
		pivot.add_child(mi)
	var signs := Node3D.new()
	signs.name = "FloorSigns"
	root.add_child(signs)
	for e: Dictionary in s.floors:
		var space := String(e.space)
		if not layout.spaces.has(space):
			continue
		var p := layout.point_in(space, e.at)
		var mi := _sign_quad(String(e.image), float(e.width_m), KitPieces.space_layer(layout, space))
		mi.position = Vector3(p.x, float(s.floor_y_m), p.y)
		mi.rotation = Vector3(-PI * 0.5, deg_to_rad(float(e.turn_deg)), 0.0)
		mi.rotation_order = EULER_ORDER_YXZ
		signs.add_child(mi)


## The wall pivot whose footprint holds `p`, or null.
static func wall_at(walls: Node3D, p: Vector2) -> Node3D:
	for n: Node in walls.get_children():
		if n.has_meta("cutaway_rect") and (n.get_meta("cutaway_rect") as Rect2).has_point(p):
			return n
	return null


static func _sign_quad(image: String, width: float, layers: int) -> MeshInstance3D:
	var mat := KitMaterials.decal(image)
	var tex: Texture2D = mat.albedo_texture
	var aspect := float(tex.get_height()) / float(tex.get_width()) if tex else 0.5
	var quad := QuadMesh.new()
	quad.size = Vector2(width, width * aspect)
	var mi := MeshInstance3D.new()
	mi.name = "Sign_%s" % image
	mi.mesh = quad
	mi.material_override = mat
	mi.layers = layers
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("kit_piece", "sign")
	return mi
