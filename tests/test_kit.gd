extends "res://tests/test_case.gd"
## T010 slice kit: pieces match A006's measured sheet (docs/handoffs/auto-A006.md) within 1 cm,
## collision, occluders and cover are what T009 had, every piece comes from the builder, and material
## and light values come from data.

const DeckLayout := preload("res://src/study/deck_layout.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")
const DeckLighting := preload("res://src/kit/deck_lighting.gd")
const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const KitMesh := preload("res://src/kit/kit_mesh.gd")
const DoorSystem := preload("res://src/doors/door_system.gd")
const TOLERANCE := 0.01
const SNAPSHOT := "res://tests/fixtures/t009_deck_snapshot.json"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _size_is(mesh: Mesh, want: Vector3, what: String) -> void:
	var got := mesh.get_aabb().size
	check((got - want).abs().x <= TOLERANCE and (got - want).abs().y <= TOLERANCE and (got - want).abs().z <= TOLERANCE,
			"%s is %s, A006 says %s" % [what, got, want])


func _main_deck() -> Dictionary:
	return (Data.load_data("deck") as Dictionary).duplicate(true)


func _pirate_deck() -> Dictionary:
	var deck := _main_deck()
	var p: Dictionary = Data.value("pirates", "deck", {})
	deck.spaces = (deck.spaces as Array).filter(func(s: Dictionary) -> bool: return (p.keep_spaces as Array).has(s.name))
	deck.doors = (p.doors as Array).duplicate(true)
	deck.props = (p.props as Array).duplicate(true)
	return deck


# --- dimensions, against A006's numbers rather than the data's ---

func test_walls_match_a006() -> void:
	for family: String in ["corridor", "pipe", "reinforced", "clinical", "outer"]:
		for variant in 2:
			_size_is(KitPieces.wall(2.0, 0.5, 2.6, family, "outer", 0.2, 0.2, variant), Vector3(2.0, 2.6, 0.5), "%s bay" % family)
	_size_is(KitPieces.wall(1.75, 0.5, 2.6, "clinical", "corridor", 0.5, 0.2, 0), Vector3(1.75, 2.6, 0.5), "a closing piece")
	_size_is(KitPieces.wall_cap(0.6, 0.5, 2.6, 0), Vector3(0.6, 2.6, 0.5), "a cap stub")
	_size_is(KitPieces.corner_post(0.5, 2.6), Vector3(0.5, 2.6, 0.5), "the corner post")


func test_no_bay_on_the_deck_is_over_2_m_and_each_keeps_its_rect() -> void:
	var deck := _main_deck()
	var layout := DeckLayout.new(deck, float(deck.room_scale))
	var root := DeckBuilder.build(layout)
	for pivot: Node3D in root.get_node("Walls").get_children().filter(func(n: Node) -> bool: return n.has_meta("cutaway_rect")):
		var r: Rect2 = pivot.get_meta("cutaway_rect")
		var mi: MeshInstance3D = pivot.get_child(0)
		var s := mi.mesh.get_aabb().size
		check(s.x <= 2.0 + TOLERANCE, "wall piece %.2f m long" % s.x)
		check(absf(s.x - maxf(r.size.x, r.size.y)) <= TOLERANCE, "the mesh fills its rect along (%s vs %s)" % [s, r])
		check(absf(s.z - minf(r.size.x, r.size.y)) <= TOLERANCE, "and across (%s vs %s)" % [s, r])
		check(absf(s.y - 2.6) <= TOLERANCE, "2.6 m tall")
	root.free()


func test_a_corner_adds_up_to_the_measured_l() -> void:
	# A006-05b: 2.0 m outer legs, 0.5 m thick. Here that's two 2.0 m pieces sharing the corner post.
	var d: Dictionary = KitMaterials.cfg().dims
	var leg := float(d.corner_leg_m)
	var along := KitPieces.wall(leg, 0.5, 2.6, "clinical", "outer", 0.5, 0.2, 0).get_aabb()
	check(absf(along.size.x - 2.0) <= TOLERANCE, "one leg is 2.0 m outer")
	check(absf(along.size.z - 0.5) <= TOLERANCE, "0.5 m thick")


func test_door_parts_match_a006() -> void:
	var d: Dictionary = KitMaterials.cfg().dims
	_size_is(KitPieces.door_jamb(0.2, 0.5, 2.6), Vector3(0.2, 2.6, 0.5), "a jamb")
	var header := KitPieces.door_header(2.0, 0.5, 2.6)
	_size_is(header, Vector3(2.0, 0.4, 0.5), "the header")
	check(absf(header.get_aabb().position.y - 2.2) <= TOLERANCE, "over a 2.2 m aperture")
	# The undented leaf: the mesh's own AABB also holds its blend shapes' full bulge.
	var leaf := KitPieces.door_leaf(2.0, float(d.door_aperture_h_m), float(d.door_leaf_t_m))
	var flat := AABB()
	var verts: PackedVector3Array = leaf.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	flat.position = verts[0]
	for v in verts:
		flat = flat.expand(v)
	check((flat.size - Vector3(2.0, 2.2, 0.12)).length() <= TOLERANCE, "the leaf is %s, A006 says 2.0 x 2.2 x 0.12" % flat.size)
	var outer := 0.2 + 2.0 + 0.2
	check(absf(outer - 2.4) <= TOLERANCE, "2.4 m outer")
	var deck := _main_deck()
	check_eq(float(deck.door_width_m), 2.0, "deck's clear width")
	check_eq(float(deck.door_frame_m), 0.2, "deck's jamb")


func test_crates_match_a006() -> void:
	var cases := {
		"crate_low": [Vector3(1.2, 0.8, 1.2), Vector3(0.8, 0.8, 0.8)],
		"crate_high": [Vector3(1.2, 1.2, 1.2)],
		"crate_stack": [Vector3(1.2, 2.1, 1.2)],
		"ammo_crate": [Vector3(1.0, 0.6, 0.6)],
	}
	for type: String in cases:
		for size: Vector3 in cases[type]:
			_size_is(KitPieces.prop(type, size), size, "%s %s" % [type, size])
	# Whatever size the deck's data asks for, the piece is exactly that.
	for deck: Dictionary in [_main_deck(), _pirate_deck()]:
		var layout := DeckLayout.new(deck, float(deck.room_scale))
		for p: Dictionary in layout.props:
			if KitPieces.slot_file(String(p.type), p.size) != "":
				continue
			var got: Vector3 = KitPieces.prop(String(p.type), p.size).get_aabb().size
			check((got - (p.size as Vector3)).length() <= TOLERANCE, "%s from data is %s" % [p.type, got])


func test_the_bed_stays_the_box() -> void:
	check_eq(String(KitMaterials.cfg().slots.bed), "", "no bed file yet")
	var size := Vector3(0.9, 0.75, 2.0)
	check_eq(KitPieces.prop("bed", size), KitPieces.slot_box(size), "the bed is still the box")
	for type: String in ["console", "cabinet", "locker_bank"]:
		check_eq(KitPieces.prop(type, size), KitPieces.slot_box(size), "a %s whose file won't fit is the box" % type)


# --- T013: scripted props in the slots ---

func _slot_files() -> Array:
	var files := []
	for entry: Variant in KitMaterials.cfg().slots.values():
		if entry is Dictionary:
			files.append_array((entry as Dictionary).values())
		elif String(entry) != "":
			files.append(String(entry))
	return files


func _deck_slot_props() -> Array:
	var out := []
	for deck: Dictionary in [_main_deck(), _pirate_deck()]:
		var layout := DeckLayout.new(deck, float(deck.room_scale))
		for p: Dictionary in layout.props:
			if p.type != "bed" and KitMaterials.cfg().slots.has(p.type):
				out.append([layout, p])
	return out


func test_each_slot_loads_its_file() -> void:
	check_eq(_slot_files().size(), 6, "four consoles, a cabinet, a locker bank")
	for path: String in _slot_files():
		check(path.begins_with("res://assets/game/props/"), "%s is a game copy" % path)
		var mesh := KitPieces.slot_mesh(path)
		check(mesh != null and mesh.get_surface_count() > 0, "%s loads" % path)
	var cab := Vector3(0.6, 1.9, 0.5)
	check_eq(KitPieces.prop("cabinet", cab), KitPieces.slot_mesh(String(KitMaterials.cfg().slots.cabinet)), "the cabinet slot")
	var lockers := Vector3(0.6, 2.0, 2.4)
	check_eq(KitPieces.prop("locker_bank", lockers), KitPieces.slot_mesh(String(KitMaterials.cfg().slots.locker_bank)), "the locker slot")


func test_the_console_variant_matches_its_deck_width() -> void:
	var seen := {}
	for pair: Array in _deck_slot_props():
		var p: Dictionary = pair[1]
		if p.type != "console":
			continue
		var long := maxf(p.size.x, p.size.z)
		var width := KitPieces.prop("console", p.size).get_aabb().size.x
		# Every deck console width now has its own file (1.0, 1.2, 1.4 and the pirate deck's 1.6).
		var want := long
		check(absf(width - want) <= TOLERANCE, "a %.1f m console gets %.2f m" % [long, width])
		seen[roundi(long * 10.0)] = true
	for tenths: int in [14, 12, 10, 16]:
		check(seen.has(tenths), "the decks still have a %d dm console" % tenths)


func test_every_material_slot_binds_to_a_kit_material() -> void:
	for path: String in _slot_files():
		var mesh := KitPieces.slot_mesh(path)
		for i in mesh.get_surface_count():
			var key := mesh.surface_get_name(i)
			check((KitMaterials.cfg().materials as Dictionary).has(key), "%s slot %s is a kit key" % [path, key])
			check_eq(mesh.surface_get_material(i), KitMaterials.material(key), "%s %s wears the kit's" % [path, key])


func test_prop_textures_are_as_dense_as_the_walls_and_grimed() -> void:
	for path: String in _slot_files():
		var mesh := KitPieces.slot_mesh(path)
		for i in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(i)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var m := KitMaterials.uv_metres(mesh.surface_get_name(i))
			check_eq((a[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size(), v.size() * 4, "%s has tangents" % path)
			for t in range(0, idx.size(), 3):
				# Triangles square to an axis keep their length: a metre is 1 / uv_m of the tile.
				var e := v[idx[t + 1]] - v[idx[t]]
				var along_axis: bool = maxf(absf(n[idx[t]].x), maxf(absf(n[idx[t]].y), absf(n[idx[t]].z))) > 0.999
				if e.length() < 0.05 or not along_axis:
					continue
				var du := (uv[idx[t + 1]] - uv[idx[t]]).length()
				check(absf(du * m - e.length()) < 0.001, "%s %s: %.3f m is %.3f tiles at uv_m %.2f" % [path, mesh.surface_get_name(i), e.length(), du, m])
	var c: PackedColorArray = KitPieces.prop("cabinet", Vector3(0.6, 1.9, 0.5)).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(c.size() > 0, "the cabinet carries vertex grime")
	var mesh := KitPieces.prop("cabinet", Vector3(0.6, 1.9, 0.5))
	var low := 1.0
	var high := 0.0
	for i in mesh.get_surface_count():
		for col: Color in mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]:
			low = minf(low, col.r)
			high = maxf(high, col.r)
	check(low <= float(KitMaterials.cfg().grime.floor_shade) + 0.01, "darkest at the floor (%.2f)" % low)
	check_eq(high, 1.0, "clean up high")


func test_props_face_the_room_and_stay_inside_their_footprints() -> void:
	var cfg: Dictionary = KitMaterials.cfg().slot_fit
	for pair: Array in _deck_slot_props():
		var layout: DeckLayout = pair[0]
		var p: Dictionary = pair[1]
		var yaw := KitPieces.prop_yaw(layout, p)
		var front := Vector2(sin(yaw), cos(yaw))
		var box := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * KitPieces.prop(p.type, p.size).get_aabb()
		var tol := float(cfg.tolerance_m)
		check(absf(box.position.x) <= p.size.x * 0.5 + tol and absf(box.end.x) <= p.size.x * 0.5 + tol, "%s in x: %s" % [p.type, box])
		check(absf(box.position.z) <= p.size.z * 0.5 + tol and absf(box.end.z) <= p.size.z * 0.5 + tol, "%s in z: %s" % [p.type, box])
		check(box.end.y <= p.size.y + tol, "%s height" % p.type)
		check(absf(front.dot(Vector2.RIGHT if p.size.x < p.size.z else Vector2.DOWN)) > 0.99, "%s fronts its long side" % p.type)
		var reach: float = minf(p.size.x, p.size.z) * 0.5 + float(cfg.front_clear_m)
		var r := float(cfg.front_clear_m)
		var ahead: bool = layout.is_free(p.center + front * reach, r)
		var behind: bool = layout.is_free(p.center - front * reach, r)
		check(ahead or not behind, "%s at %s doesn't face blocked floor with open floor behind" % [p.type, p.center])
		var to_centre: Vector2 = layout.space_rect(p.space).get_center() - p.center
		if ahead and behind:
			check(front.dot(to_centre) >= 0.0, "%s at %s faces the room's centre" % [p.type, p.center])


func test_a_turned_prop_is_placed_turned() -> void:
	var deck := _main_deck()
	var layout := DeckLayout.new(deck, float(deck.room_scale))
	var root := DeckBuilder.build(layout)
	var turned := 0
	for mi: Node in root.get_node("Props").get_children():
		if mi is MeshInstance3D and String(mi.get_meta("kit_piece")) == "locker_bank":
			check(absf(absf(mi.rotation.y) - PI * 0.5) < 0.01, "the bank's 2.4 m runs along Z")
			turned += 1
	check_eq(turned, 1, "one locker bank")
	root.free()


func test_the_door_fits_the_people_and_the_walls() -> void:
	# The checks A006 left to the code lane: head room, the travel pocket, the fallen leaf.
	var body_h := float(Data.value("player", "height_m")) * float(_main_deck().character_scale)
	check(body_h < 2.2, "a scaled body (%.2f m) walks under the 2.2 m aperture" % body_h)
	for deck: Dictionary in [_main_deck(), _pirate_deck()]:
		var layout := DeckLayout.new(deck, float(deck.room_scale))
		for i in layout.doors.size():
			var d: Dictionary = layout.doors[i]
			var r: Rect2 = d.rect
			var slide := float(deck.doors[i].slide)
			var pocket := r
			if d.along_x:
				pocket.position.x += slide * r.size.x
			else:
				pocket.position.y += slide * r.size.y
			var covered := 0.0
			var solid: Array = layout.walls.duplicate()
			for other: Dictionary in layout.doors:
				solid.append_array(other.frames)
			for w: Rect2 in solid:
				covered += pocket.intersection(w).get_area()
			check(absf(covered - pocket.get_area()) < 0.01, "door %d's leaf slides into solid wall (%.2f of %.2f m2)" % [i, covered, pocket.get_area()])
			# Flat on the floor it's 2.0 x 2.2 m and walked over; it must not sink into a tall prop.
			for side: float in [-1.0, 1.0]:
				var c := r.get_center()
				var flat: Rect2
				if d.along_x:
					flat = Rect2(c.x - 1.0, c.y if side > 0.0 else c.y - 2.2, 2.0, 2.2)
				else:
					flat = Rect2(c.x if side > 0.0 else c.x - 2.2, c.y - 1.0, 2.2, 2.0)
				for p: Dictionary in layout.props:
					if String(p.cover) == "tall":
						check(not flat.intersects(p.rect), "door %d's fallen leaf misses the %s" % [i, p.type])


# --- unchanged against T009 ---

func test_collision_occluders_and_cover_are_t009s() -> void:
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))
	for key: String in ["main", "pirates"]:
		var deck: Dictionary = _main_deck() if key == "main" else _pirate_deck()
		var layout := DeckLayout.new(deck, float(deck.room_scale))
		var built := DeckBuilder.build(layout)
		(Engine.get_main_loop() as SceneTree).root.add_child(built)
		var bodies: Array = []
		for b: StaticBody3D in built.find_children("*", "StaticBody3D", true, false):
			var cs: CollisionShape3D = b.get_child(0)
			var s: Vector3 = (cs.shape as BoxShape3D).size
			var g := b.global_position
			bodies.append([snappedf(g.x, 0.001), snappedf(g.y, 0.001), snappedf(g.z, 0.001), snappedf(s.x, 0.001), snappedf(s.y, 0.001), snappedf(s.z, 0.001)])
		bodies.sort()
		built.free()
		check_eq(bodies.size(), (want[key].bodies as Array).size(), "%s: same number of collision boxes" % key)
		for i in mini(bodies.size(), (want[key].bodies as Array).size()):
			for k in 6:
				check(absf(float(bodies[i][k]) - float(want[key].bodies[i][k])) < 0.002, "%s body %d: %s, was %s" % [key, i, bodies[i], want[key].bodies[i]])
		var blockers: Array = []
		for r: Rect2 in layout.blockers():
			blockers.append([snappedf(r.position.x, 0.001), snappedf(r.position.y, 0.001), snappedf(r.size.x, 0.001), snappedf(r.size.y, 0.001)])
		blockers.sort()
		check_eq(blockers.size(), (want[key].blockers as Array).size(), "%s: same blockers" % key)
		for i in mini(blockers.size(), (want[key].blockers as Array).size()):
			for k in 4:
				check(absf(float(blockers[i][k]) - float(want[key].blockers[i][k])) < 0.002, "%s blocker %d moved" % [key, i])
		var cover: Array = []
		for p: Dictionary in layout.props:
			cover.append([p.type, p.cover])
		check_eq(JSON.stringify(cover), JSON.stringify(want[key].cover), "%s: same cover classes" % key)


func test_the_door_body_and_sight_rect_did_not_follow_the_thin_leaf() -> void:
	var sys := DoorSystem.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sys)
	_nodes.append(sys)
	var deck := _main_deck()
	sys.setup(DeckLayout.new(deck, float(deck.room_scale)))
	var thick := float(Data.value("doors", "panel_thickness_m"))
	for d: Node3D in sys.doors:
		var s: Vector3 = ((d.get_node("PanelBody") as StaticBody3D).get_child(0) as CollisionShape3D).shape.size
		check(is_equal_approx(minf(s.x, s.z), thick), "panel body still %.2f m thick" % thick)
		check(is_equal_approx(s.y, 2.6 - float(Data.value("doors", "panel_top_gap_m"))), "and as tall as ever")
		var r: Rect2 = d.sight_rect()
		check(is_equal_approx(minf(r.size.x, r.size.y), thick), "sight rect too")


# --- door states ---

func test_each_door_state_shows() -> void:
	var sys := DoorSystem.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sys)
	_nodes.append(sys)
	var deck := _main_deck()
	sys.setup(DeckLayout.new(deck, float(deck.room_scale)))
	for d: Node3D in sys.doors:
		var panel: MeshInstance3D = d._panel
		check_eq(panel.mesh.get_blend_shape_count(), 2, "the leaf has its two dents")
		d.reset("closed")
		check(panel.visible, "closed: leaf shows")
		check_eq(panel.get_blend_shape_value(0) + panel.get_blend_shape_value(1), 0.0, "and flat")
		check(absf(panel.position.y - 1.1) < 0.01, "standing in the 2.2 m aperture")
		d.reset("open")
		check(not panel.visible, "open: hidden in the pocket")
		d.reset("locked")
		check(panel.visible, "locked: leaf shows")
		check_eq(d.state_color(), Color(String(d.cfg.colors.lamp_locked)), "and the light is the locked one")
		d.reset("closed")
		var break_s := float(d.cfg.bash.break_s)
		d.bash(break_s * 0.6, d.opening.get_center() + Vector2(3, 3))
		var dent: float = panel.get_blend_shape_value(0) + panel.get_blend_shape_value(1)
		check(absf(dent - 0.6) < 0.01, "mid-bash: the dent is the T006 damage (%.2f)" % dent)
		check(d._seam.visible and d._seam_mat.emission_energy_multiplier > 0.0, "with its seam lit")
		d.bash(break_s, d.opening.get_center() + Vector2(3, 3))
		check(d.door_state.is_broken(), "broken")
		check(panel.visible, "broken: the leaf is on the floor")
		check(not d._seam.visible, "with no seam left to light")
		var up: Vector3 = panel.global_basis.y
		check(absf(up.y) < 0.02, "and lying flat (its up is %s)" % up)
		check(panel.global_position.y < 0.2, "at floor height")


func test_a_dent_pushes_away_from_the_blows() -> void:
	var sys := DoorSystem.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sys)
	_nodes.append(sys)
	var deck := _main_deck()
	sys.setup(DeckLayout.new(deck, float(deck.room_scale)))
	for d: Node3D in sys.doors:
		d.reset("closed")
		var from := Vector2(0, 3) if d.along_x else Vector2(3, 0)
		d.bash(1.0, d.opening.get_center() + from)
		var panel: MeshInstance3D = d._panel
		# Blows from +Z or +X push toward -Z or -X: on the turned side door's leaf that's its +Z.
		var want := 1 if d.along_x else 0
		check(panel.get_blend_shape_value(want) > 0.0, "%s door bulges away" % d.side)
		check_eq(panel.get_blend_shape_value(1 - want), 0.0, "and only that way")


# --- from the builder, from data ---

func test_every_mesh_on_the_deck_comes_from_the_builder() -> void:
	var deck := _main_deck()
	var root := DeckBuilder.build(DeckLayout.new(deck, float(deck.room_scale)))
	var count := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		count += 1
		check(mi.has_meta("kit_piece"), "%s is a kit piece" % mi.name)
	check(count > 100, "the deck is made of pieces (%d)" % count)
	root.free()
	# Scenes hold roots, not hand-placed geometry.
	for dir: String in DirAccess.get_directories_at("res://scenes"):
		for f: String in DirAccess.get_files_at("res://scenes".path_join(dir)):
			if f.ends_with(".tscn") and not ["dev"].has(dir):
				var text := FileAccess.get_file_as_string("res://scenes".path_join(dir).path_join(f))
				check(not text.contains("MeshInstance3D"), "%s/%s places no mesh by hand" % [dir, f])


func test_cutaway_still_works_on_kit_walls() -> void:
	var deck := _main_deck()
	var root := DeckBuilder.build(DeckLayout.new(deck, float(deck.room_scale)))
	for section: String in ["Walls", "DoorFrames"]:
		for pivot: Node in root.get_node(section).get_children():
			if pivot is StaticBody3D:
				continue
			check(pivot.is_in_group(&"camera_cutaway"), "%s is in the cut-away" % pivot.name)
			check(is_equal_approx((pivot as Node3D).position.y, 0.0), "pivot on the floor")
			check(pivot.has_meta("cutaway_rect") and pivot.has_meta("cutaway_height"), "and has the contract's meta")
			check(pivot.get_child(0) is GeometryInstance3D, "the fade reaches its mesh")
			check(absf(((pivot.get_child(0) as MeshInstance3D).mesh.get_aabb().size.y) - 2.6) < TOLERANCE, "full-height walls fade, not low ones")
	# The collision isn't under the pivot, so a fade or a drop never touches it.
	var bodies: Array = root.find_children("*", "StaticBody3D", true, false)
	for b: Node in bodies:
		check(not b.get_parent().is_in_group(&"camera_cutaway"), "collision stays out of the pivot")
	root.free()


func test_materials_come_from_data() -> void:
	var cfg := KitMaterials.cfg()
	for key: String in ["hull", "steel", "deck", "grate", "clinical", "hazard", "rubber", "glass", "emit_cool", "emit_amber", "emit_blue", "emit_red"]:
		check((cfg.materials as Dictionary).has(key), "A006-08's %s is in data" % key)
		check(KitMaterials.material(key) != null, "and builds")
	var spec: Dictionary = (cfg.materials.emit_red as Dictionary).duplicate()
	spec.energy = 123.0
	spec.emission = "102030"
	var m := KitMaterials.make(spec, cfg.material_shared)
	check_eq(m.emission_energy_multiplier, 123.0, "an edited energy is used")
	check_eq(m.emission, Color("102030"), "an edited colour is used")
	var glass: Dictionary = (cfg.materials.glass as Dictionary).duplicate()
	glass.roughness = 0.77
	check(is_equal_approx(KitMaterials.make(glass, cfg.material_shared).roughness, 0.77), "an edited roughness is used")
	# The textures carry A006-08's ranges, and the generator reads them from the same file.
	var tex: Dictionary = cfg.textures
	check_eq(float(tex.hull.rough_paint[0]), 0.65, "hull roughness range")
	check_eq(float(tex.hazard.rough[1]), 0.85, "hazard roughness range")
	check_eq(float(tex.rubber.rough[0]), 0.8, "rubber roughness range")
	check(FileAccess.get_file_as_string("res://tools/t010_textures.py").contains("data/kit.json"), "the generator reads data")


func test_lights_come_from_data_and_stay_in_their_room() -> void:
	var deck := _main_deck()
	var layout := DeckLayout.new(deck, float(deck.room_scale))
	var built := DeckBuilder.build(layout)
	var lighting := DeckLighting.new()
	lighting.add_child(built)
	(Engine.get_main_loop() as SceneTree).root.add_child(lighting)
	_nodes.append(lighting)
	lighting.setup(layout, Environment.new(), built)
	var fx: Dictionary = KitMaterials.cfg().lighting.fixtures
	var want := 0
	for n: String in layout.space_order:
		want += (fx.spaces as Dictionary).get(n, []).size()
	check_eq(lighting.lights.size(), want, "one light per fixture in data")
	for light: Light3D in lighting.lights:
		var p := Vector2(light.position.x, light.position.z)
		var space := layout.space_at(p)
		check(space != "", "%s stands in a room" % light.name)
		var layer := KitPieces.space_layer(layout, space)
		check_eq(light.light_cull_mask, 1 | layer, "%s lights its own room and the people in it" % light.name)
	var first: OmniLight3D = lighting.lights[0]
	var look: Dictionary = fx.looks[String(fx.spaces[layout.space_order[0]][0].look)]
	check(is_equal_approx(first.light_energy, float(look.energy)), "energy from data")
	check_eq(first.light_color, Color(String(look.color)), "colour from data")
	check(is_equal_approx(first.omni_range, float(look.range_m)), "range from data")
	var fixtures: Array = built.find_children("Fixture", "MeshInstance3D", true, false)
	check_eq(fixtures.size(), want, "a strip on the wall for each light")
	for f: Node in fixtures:
		check(f.get_parent().is_in_group(&"camera_cutaway"), "a strip fades with its wall")


func test_kit_scripts_hold_no_look_values() -> void:
	var rx := RegEx.create_from_string("(?<![\\w.\"#%])(\\d+\\.\\d+|\\d+)(?![\\w\"])")
	var allowed := ["0", "1", "2", "0.0", "1.0", "2.0", "0.5"]
	for path: String in ["res://src/kit/kit_materials.gd", "res://src/kit/deck_lighting.gd"]:
		var n := 0
		for raw: String in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var line := raw.get_slice("#", 0)
			var strip := RegEx.create_from_string("\"[^\"]*\"")
			line = strip.sub(line, "\"\"", true)
			for m in rx.search_all(line):
				if not allowed.has(m.get_string(1)):
					check(false, "%s:%d has the literal %s" % [path, n, m.get_string(1)])
	# No colours in any kit script.
	var hex := RegEx.create_from_string("Color\\(\\s*(\"|\\d)")
	for f: String in DirAccess.get_files_at("res://src/kit"):
		if f.ends_with(".gd"):
			var text := FileAccess.get_file_as_string("res://src/kit".path_join(f))
			check(hex.search(text) == null, "%s spells out no colour" % f)
