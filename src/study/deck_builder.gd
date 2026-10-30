extends RefCounted
## Turns a DeckLayout into grey-box nodes: floors, walls (cut-away pivots), hazard door frames
## and real-size props, each with box collision. Plain materials so scale is judged without art.

const DeckLayout := preload("res://src/study/deck_layout.gd")
const CUTAWAY_GROUP := &"camera_cutaway"  # the camera rig's contract (src/camera/CONTRACT.md)
const FLOOR_SLAB := 0.2


## Returns a Node3D named "Deck" holding the whole grey box for `layout`.
static func build(layout: DeckLayout) -> Node3D:
	var d := layout.data
	var colors: Dictionary = d.colors
	var mats := {
		"floor": _floor_material(colors, float(d.floor_tile_m)),
		"wall": _flat(colors.wall),
		"door_frame": _flat(colors.door_frame),
		"prop": _flat(colors.prop),
		"prop_accent": _flat(colors.prop_accent),
	}
	var h := float(d.wall_height_m)
	var root := Node3D.new()
	root.name = "Deck"
	var floors := Node3D.new()
	floors.name = "Floors"
	root.add_child(floors)
	for n in layout.space_order:
		_add_box(floors, n, layout.space_rect(n), -FLOOR_SLAB, FLOOR_SLAB, mats.floor, false)
	for door in layout.doors:
		_add_box(floors, "Doorway", door.rect, -FLOOR_SLAB, FLOOR_SLAB, mats.floor, false)
	for breach in layout.breaches:
		_add_box(floors, "Breach", breach.rect, -FLOOR_SLAB, FLOOR_SLAB, mats.floor, false)
	var walls := Node3D.new()
	walls.name = "Walls"
	root.add_child(walls)
	for r in layout.walls:
		_add_wall(walls, "Wall", r, h, mats.wall)
	var frames := Node3D.new()
	frames.name = "DoorFrames"
	root.add_child(frames)
	for door in layout.doors:
		for fr in door.frames:
			# Frames stick out 5 cm past the wall faces and top so they read and don't z-fight.
			var g := Vector2(0.0, 0.05) if door.along_x else Vector2(0.05, 0.0)
			_add_wall(frames, "Frame", Rect2(fr.position - g, fr.size + g * 2.0), h + 0.05, mats.door_frame)
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	for p in layout.props:
		var mat: Material = mats.prop_accent if p.type == "ammo_crate" else mats.prop
		_add_box(props, String(p.type).to_pascal_case(), p.rect, 0.0, p.size.y, mat, true)
	return root


## A wall piece: a floor-level pivot (scaled in Y by the cut-away) holding the mesh, plus collision.
static func _add_wall(parent: Node3D, node_name: String, r: Rect2, h: float, mat: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = Vector3(r.get_center().x, 0.0, r.get_center().y)
	pivot.set_meta("cutaway_rect", r)
	pivot.set_meta("cutaway_height", h)
	pivot.add_to_group(CUTAWAY_GROUP)
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(r.size.x, h, r.size.y)
	mi.mesh = bm
	mi.material_override = mat
	mi.position.y = h * 0.5
	pivot.add_child(mi)
	_add_collision(parent, r, 0.0, h)


static func _add_box(parent: Node3D, node_name: String, r: Rect2, y0: float, height: float,
		mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = Vector3(r.size.x, height, r.size.y)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(r.get_center().x, y0 + height * 0.5, r.get_center().y)
	parent.add_child(mi)
	if collide:
		_add_collision(parent, r, y0, height)


static func _add_collision(parent: Node3D, r: Rect2, y0: float, height: float) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(r.size.x, height, r.size.y)
	cs.shape = box
	body.position = Vector3(r.get_center().x, y0 + height * 0.5, r.get_center().y)
	body.add_child(cs)
	parent.add_child(body)


static func _flat(hex: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.85
	return m


## Light grey floor with darker lines every `tile_m` metres (world-space UVs), so scale reads.
static func _floor_material(colors: Dictionary, tile_m: float) -> StandardMaterial3D:
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	img.fill(Color(colors.floor))
	var line := Color(colors.floor_line)
	for i in size:
		for w in 2:
			img.set_pixel(i, w, line)
			img.set_pixel(w, i, line)
	img.generate_mipmaps()
	var m := _flat(colors.floor)
	m.albedo_color = Color.WHITE
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	return m
