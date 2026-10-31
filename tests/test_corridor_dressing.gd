extends "res://tests/test_case.gd"
## T019: the corridors' dressing on both decks: every hallway file loads, nothing intrudes past the limit
## below the line, and nothing touches a doorway, a cover line or a bot's route. Looks only.

const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const Dressing := preload("res://src/kit/dressing.gd")
const CorridorDressing := preload("res://src/kit/corridor_dressing.gd")
const DeckLayout := preload("res://src/study/deck_layout.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")
const DeckLighting := preload("res://src/kit/deck_lighting.gd")
const SectionLights := preload("res://src/shift/section_lights.gd")
const StalkerNav := preload("res://src/enemies/stalker_nav.gd")
const CoverField := preload("res://src/cover/cover_field.gd")
const CATALOGUE := "res://assets/source/props/catalogue.json"
const CAMERA_CUT := &"camera_cutaway"
const TOL := 0.02
const SAMPLE_M := 0.1

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Data.clear_cache()


func _shift_layout() -> DeckLayout:
	var deck: Dictionary = Data.load_data("deck")
	return DeckLayout.new(deck, float(deck.room_scale))


func _pirate_layout() -> DeckLayout:
	var deck: Dictionary = (Data.load_data("deck") as Dictionary).duplicate(true)
	var p: Dictionary = Data.value("pirates", "deck", {})
	deck.spaces = (deck.spaces as Array).filter(func(s: Dictionary) -> bool: return (p.keep_spaces as Array).has(s.name))
	deck.doors = (p.doors as Array).duplicate(true)
	deck.props = (p.props as Array).duplicate(true)
	return DeckLayout.new(deck, float(deck.room_scale))


func _both() -> Array:
	return [["shift", _shift_layout()], ["pirate", _pirate_layout()]]


func _hallway_types() -> Array:
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
	return cat.keys().filter(func(k: String) -> bool: return cat[k] is Dictionary and cat[k].get("set", "") == "hallway")


func _cfg() -> Dictionary:
	return Data.value("deck", "corridor_dressing", {})


func _of(pieces: Array, type: String) -> Array:
	return pieces.filter(func(p: Dictionary) -> bool: return p.type == type)


func _rect_dist(r: Rect2, p: Vector2) -> float:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)).distance_to(p)


## Everything of the mesh below the line, in the world, read from its triangles rather than the placer's sums.
func _low_points(piece: Dictionary, cut: float) -> PackedVector3Array:
	var mesh: ArrayMesh = piece.mesh
	var xform := Transform3D(Basis(Vector3.UP, float(piece.yaw)) * Basis.from_scale(Vector3(float(piece.scale_x), 1.0, 1.0)), piece.position)
	var out := PackedVector3Array()
	for i in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for t in range(0, idx.size(), 3):
			var world := [xform * v[idx[t]], xform * v[idx[t + 1]], xform * v[idx[t + 2]]]
			if world[0].y < cut or world[1].y < cut or world[2].y < cut:
				out.append_array(PackedVector3Array(world))
	return out


# --- files ---

func test_every_hallway_slot_loads_its_file() -> void:
	var slots: Dictionary = KitMaterials.cfg().slots
	var types := _hallway_types()
	check_eq(types.size(), 20, "the set has twenty pieces")
	for type: String in types:
		check_eq(String(slots.get(type, "")), "res://assets/game/props/%s.glb" % type, "%s slot" % type)
		var mesh := KitPieces.slot_mesh(String(slots[type]))
		if check(mesh != null, "%s loads" % type):
			for i in mesh.get_surface_count():
				check((KitMaterials.cfg().materials as Dictionary).has(mesh.surface_get_name(i)), "%s slot %s is a kit material" % [type, mesh.surface_get_name(i)])


func test_every_wall_piece_has_its_mount_from_data() -> void:
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
	var mounts: Dictionary = KitMaterials.cfg().wall_mounts
	for type: String in _hallway_types():
		if String(cat[type].role) in ["wall", "wall_high"]:
			check(mounts.has(type), "%s has a mount" % type)
		if String(cat[type].role) == "wall_high":
			check_eq(float(mounts[type].mount_y_m), 0.0, "%s has its height baked in" % type)


# --- the rule that keeps the game fair ---

func test_nothing_intrudes_past_the_limit_below_the_line() -> void:
	var limit := float(Data.value("deck", "dressing_max_intrusion_m"))
	var cut := float(_cfg().below_m)
	var exempt: Array = _cfg().over_limit_ok
	check_eq(limit, 0.3, "the packet's start")
	check_eq(exempt.size(), 2, "only the corner pillar and the breached panel")
	for row: Array in _both():
		var layout: DeckLayout = row[1]
		for piece: Dictionary in CorridorDressing.placed(layout):
			if piece.wall == "" or exempt.has(piece.type):
				continue
			var face := Dressing.wall_face(layout.space_rect(piece.space), piece.wall)
			var inward: Vector2 = face.inward
			var deepest := 0.0
			for p: Vector3 in _low_points(piece, cut):
				deepest = maxf(deepest, (Vector2(p.x, p.z) - (face.start as Vector2)).dot(inward))
			check(deepest <= limit + 0.001, "%s %s reaches %.3f m at %s" % [row[0], piece.type, deepest, piece.rect])


func test_wall_pieces_stand_on_their_wall_at_their_height() -> void:
	for row: Array in _both():
		var layout: DeckLayout = row[1]
		for piece: Dictionary in CorridorDressing.placed(layout):
			if piece.wall == "" or piece.type == "corner_pillar":
				continue
			var face := Dressing.wall_face(layout.space_rect(piece.space), piece.wall)
			var mount: Dictionary = KitMaterials.cfg().wall_mounts[piece.type]
			var back: float = (piece.rect as Rect2).position.dot(face.inward) if (face.inward as Vector2).x + (face.inward as Vector2).y > 0.0 else (piece.rect as Rect2).end.dot(face.inward)
			var off: float = back - (face.start as Vector2).dot(face.inward)
			check(absf(off + float(mount.get("sink_m", 0.0))) < TOL, "%s %s back is %.3f m off its wall" % [row[0], piece.type, off])
			check(absf((piece.position as Vector3).y - float(mount.mount_y_m)) < TOL, "%s at mount_y_m" % piece.type)


func test_nothing_overlaps_a_doorway() -> void:
	for row: Array in _both():
		var layout: DeckLayout = row[1]
		var radius := float(Data.value("player", "radius_m"))
		for piece: Dictionary in CorridorDressing.placed(layout):
			for door: Dictionary in layout.doors:
				check(not (piece.rect as Rect2).intersects((door.rect as Rect2).grow(-TOL)), "%s %s is in a doorway" % [row[0], piece.type])
				# The surround frames the door; everything else keeps a person's width from it.
				if not ["door_jamb", "door_lintel"].has(piece.type):
					check(not (piece.rect as Rect2).intersects((door.rect as Rect2).grow(radius)), "%s %s crowds a door at %s" % [row[0], piece.type, piece.rect])


func test_nothing_overlaps_a_cover_line_or_a_prop() -> void:
	var radius := float(Data.value("player", "radius_m"))
	for row: Array in _both():
		var layout: DeckLayout = row[1]
		var pieces := CorridorDressing.placed(layout)
		for i in layout.props.size():
			var p: Dictionary = layout.props[i]
			var r: Rect2 = p.rect
			var reach := 0.0
			if bool(layout.data.props[i].get("tippable", false)):
				reach = (p.size as Vector3).y
			elif p.cover == CoverField.LOW:
				reach = radius * 2.0
			var line := r.grow_individual(reach, 0.0, reach, 0.0) if r.size.y >= r.size.x else r.grow_individual(0.0, reach, 0.0, reach)
			for piece: Dictionary in pieces:
				check(not (piece.rect as Rect2).intersects(r), "%s %s on a %s" % [row[0], piece.type, p.type])
				var low: Rect2 = piece.low_rect if piece.wall != "" else piece.rect
				check(not low.intersects(line), "%s %s in the line of %s at %s" % [row[0], piece.type, p.type, p.center])


func test_clutter_stays_off_spawns_patrols_and_salvage() -> void:
	var layout := _shift_layout()
	var radius := float(Data.value("enemies", "stalker", {}).radius_m)
	var flat: Array = []
	for s: Dictionary in Data.value("enemies", "spawn_points", []):
		flat.append([s.space, s.at])
		for w: Array in s.patrol:
			flat.append([s.space, w])
	for s: Dictionary in Data.value("salvage", "placements", []):
		flat.append([s.space, s.at])
	for piece: Dictionary in CorridorDressing.placed(layout):
		if piece.type == "floor_grate" or piece.type == "debris_pile" or piece.type == "wall_panel_breached":
			for f: Array in flat:
				var at := layout.point_in(String(f[0]), f[1])
				check(_rect_dist(piece.rect, at) >= radius, "%s is %.2f m from a %s point at %s" % [piece.type, _rect_dist(piece.rect, at), f[0], f[1]])
			# A heap's back may sink into the wall it fell against, and the breached panel's is on it.
			check(layout.space_rect(piece.space).grow(float(Data.value("deck", "wall_thickness_m")) * 0.5).encloses(piece.rect), "%s inside %s" % [piece.type, piece.space])


## The legs a T012 bot walks with nobody in its way, as tests/test_dressing.gd's.
func _bot_legs(layout: DeckLayout, nav: StalkerNav, greedy: bool) -> Array:
	var on_floor: Array = []
	for s: Dictionary in Data.value("salvage", "placements", []):
		var klass := String(Data.value("salvage", "kinds", {})[s.kind]["class"])
		if greedy or klass != "heavy":
			on_floor.append({"at": layout.point_in(String(s.space), s.at), "small": klass == "small"})
	var deck: Dictionary = Data.load_data("deck")
	var a: Dictionary = Data.value("shift", "airlock", {})
	var home: Vector2 = (layout.point_in(String(a.space), a.from) + layout.point_in(String(a.space), a.to)) * 0.5
	var pos: Vector2 = layout.point_in(String(deck.spawn.space), deck.spawn.at)
	var pockets := 0
	var in_hand := false
	var legs: Array = []
	while not on_floor.is_empty() or pockets > 0 or in_hand:
		var full: bool = in_hand or pockets >= int(Data.value("salvage", "pocket_limit"))
		var pick: Variant = null
		if not full:
			for item: Dictionary in on_floor:
				if pick == null or pos.distance_to(item.at) < pos.distance_to(pick.at):
					pick = item
		var goal: Vector2 = home if pick == null else pick.at
		legs.append(nav.path(pos, goal))
		pos = goal
		if pick == null:
			pockets = 0
			in_hand = false
		else:
			on_floor.erase(pick)
			pockets += 1 if pick.small else 0
			in_hand = not pick.small
	return legs


## A path runs on nav cells, so half a cell clear of it is clear of the route. What's over the line
## (a duct at head height) can't touch anyone, so only what's below it counts.
func test_nothing_overlaps_a_t012_bot_route() -> void:
	var layout := _shift_layout()
	var cfg: Dictionary = Data.value("enemies", "stalker", {})
	var nav := StalkerNav.new(cfg, layout)
	var clear := float(cfg.nav.cell_m) * 0.5
	var pieces := CorridorDressing.placed(layout)
	for greedy: bool in [true, false]:
		for path: PackedVector2Array in _bot_legs(layout, nav, greedy):
			check(path.size() > 0, "every stop on the bot's way is reachable")
			for i in path.size() - 1:
				var seg: Vector2 = path[i + 1] - path[i]
				for k in int(ceil(seg.length() / SAMPLE_M)) + 1:
					var at: Vector2 = path[i] + seg.normalized() * minf(k * SAMPLE_M, seg.length())
					for piece: Dictionary in pieces:
						var low: Rect2 = piece.low_rect
						if low.has_area():
							check(_rect_dist(low, at) >= clear, "%s is %.2f m from a route at %s" % [piece.type, _rect_dist(low, at), at])


func _route_m(layout: DeckLayout, nav: StalkerNav, greedy: bool) -> float:
	var total := 0.0
	for path: PackedVector2Array in _bot_legs(layout, nav, greedy):
		for i in path.size() - 1:
			total += path[i].distance_to(path[i + 1])
	return total


func test_bot_routes_are_the_same_with_and_without_the_dressing() -> void:
	var deck: Dictionary = (Data.load_data("deck") as Dictionary).duplicate(true)
	var with := DeckLayout.new(deck, float(deck.room_scale))
	var bare_deck := deck.duplicate(true)
	bare_deck.erase("corridor_dressing")
	var bare := DeckLayout.new(bare_deck, float(deck.room_scale))
	var cfg: Dictionary = Data.value("enemies", "stalker", {})
	check(CorridorDressing.placed(with).size() > 0 and CorridorDressing.placed(bare).is_empty(), "one has it, one hasn't")
	for greedy: bool in [true, false]:
		check_eq(_route_m(with, StalkerNav.new(cfg, with), greedy), _route_m(bare, StalkerNav.new(cfg, bare), greedy), "greedy %s" % greedy)


func test_it_adds_no_collision_cover_or_blockers() -> void:
	var deck: Dictionary = (Data.load_data("deck") as Dictionary).duplicate(true)
	var bare_deck := deck.duplicate(true)
	bare_deck.erase("corridor_dressing")
	var with := DeckLayout.new(deck, float(deck.room_scale))
	var bare := DeckLayout.new(bare_deck, float(deck.room_scale))
	check_eq(with.blockers().size(), bare.blockers().size(), "same blockers")
	var a := DeckBuilder.build(with)
	var b := DeckBuilder.build(bare)
	_nodes.append_array([a, b])
	var meshes := func(n: Node) -> int: return n.find_children("*", "MeshInstance3D", true, false).size()
	check(meshes.call(a) > meshes.call(b), "the dressing is on the deck")
	check_eq(a.find_children("*", "StaticBody3D", true, false).size(), b.find_children("*", "StaticBody3D", true, false).size(), "same bodies")


# --- the rhythm ---

func test_ribs_keep_the_rhythm_on_both_walls_staggered() -> void:
	for space: String in ["junction", "side_corridor"]:
		var spec: Dictionary = _cfg().corridors[space].ribs
		check(float(spec.every_m) >= 2.4 and float(spec.every_m) <= 3.0, "every %s m" % spec.every_m)
		check_eq((spec.start_m as Dictionary).size(), 2, "both long walls")
		var starts: Array = spec.start_m.values()
		check(absf(float(starts[0]) - float(starts[1])) > 1.0, "staggered")
	for row: Array in _both():
		var layout: DeckLayout = row[1]
		for space: String in ["junction", "side_corridor"]:
			var ribs: Array = _of(CorridorDressing.placed(layout), "wall_rib").filter(func(p: Dictionary) -> bool: return p.space == space)
			var by_wall := {}
			for rib: Dictionary in ribs:
				if not by_wall.has(rib.wall):
					by_wall[rib.wall] = []
				by_wall[rib.wall].append((rib.position as Vector3).x if rib.wall in ["north", "south"] else (rib.position as Vector3).z)
			check_eq(by_wall.size(), 2, "%s %s ribs on both walls" % [row[0], space])
			for wall: String in by_wall:
				var spots: Array = by_wall[wall]
				spots.sort()
				for i in spots.size() - 1:
					check(spots[i + 1] - spots[i] >= float(_cfg().corridors[space].ribs.every_m) - 0.01, "%s %s ribs %.2f apart" % [space, wall, spots[i + 1] - spots[i]])


func test_a_corridors_high_and_low_runs_are_on_opposite_walls_and_butted() -> void:
	var opposite := {"north": "south", "south": "north", "east": "west", "west": "east"}
	for row: Array in _both():
		var layout: DeckLayout = row[1]
		var pieces := CorridorDressing.placed(layout)
		for space: String in ["junction", "side_corridor"]:
			var runs: Array = _cfg().corridors[space].runs
			check_eq(runs.size(), 2, "a high and a low run")
			check_eq(String(opposite[runs[0].wall]), String(runs[1].wall), "on opposite walls")
			for run: Dictionary in runs:
				var sections: Array = pieces.filter(func(p: Dictionary) -> bool: return p.space == space and p.type == run.type and p.wall == run.wall)
				check(sections.size() > 0, "%s %s has %s" % [row[0], space, run.type])
				for k in sections.size() - 1:
					var gap := absf(((sections[k + 1].position as Vector3) - (sections[k].position as Vector3)).length())
					check(gap >= (sections[k].mesh as ArrayMesh).get_aabb().size.x - 0.001, "%s sections don't overlap" % run.type)
				var any_butted := space != "junction"
				for k in sections.size() - 1:
					var gap := absf(((sections[k + 1].position as Vector3) - (sections[k].position as Vector3)).length())
					any_butted = any_butted or absf(gap - (sections[k].mesh as ArrayMesh).get_aabb().size.x) < 0.001
				check(any_butted, "%s %s %s runs end to end" % [row[0], space, run.type])


func test_every_door_has_its_jambs_and_a_lintel_fitted_to_it() -> void:
	for row: Array in _both():
		var layout: DeckLayout = row[1]
		var pieces := CorridorDressing.placed(layout)
		for door: Dictionary in layout.doors:
			var opening: Rect2 = door.rect
			var near := func(p: Dictionary) -> bool: return (p.rect as Rect2).intersects(opening.grow(float(_cfg().door_clear_m)))
			var jambs: Array = _of(pieces, "door_jamb").filter(near)
			var lintels: Array = _of(pieces, "door_lintel").filter(near)
			check_eq(jambs.size(), 2, "%s two jambs at %s" % [row[0], opening])
			check_eq(lintels.size(), 1, "%s one lintel at %s" % [row[0], opening])
			if lintels.size() == 1:
				var width: float = (opening.size.x if door.along_x else opening.size.y)
				var along: Vector2 = (lintels[0].rect as Rect2).size
				check(absf((along.x if door.along_x else along.y) - width) < TOL, "the lintel spans the aperture")
				check(absf((lintels[0].box as AABB).position.y - float(KitMaterials.cfg().dims.door_aperture_h_m)) < TOL, "and sits on top of it")


func test_inner_corners_get_pillars_away_from_routes() -> void:
	var pieces := CorridorDressing.placed(_shift_layout())
	check(_of(pieces, "corner_pillar").size() >= 2, "a corner or two is dressed: %d" % _of(pieces, "corner_pillar").size())
	var layout := _shift_layout()
	for p: Dictionary in _of(pieces, "corner_pillar"):
		check(layout.space_rect(p.space).grow(TOL).encloses(p.rect), "%s stands in its corridor" % p.type)


func test_one_of_each_grim_piece_on_each_deck() -> void:
	for row: Array in _both():
		var pieces := CorridorDressing.placed(row[1])
		for type: String in ["wall_panel_breached", "hanging_cables", "debris_pile"]:
			check_eq(_of(pieces, type).size(), 1, "%s has one %s" % [row[0], type])


func test_the_singles_are_on_the_deck() -> void:
	var pieces := CorridorDressing.placed(_shift_layout())
	for type: String in ["maintenance_hatch", "fire_hose_reel", "wall_sign_arrow", "handrail", "floor_grate"]:
		check(_of(pieces, type).size() >= 1, "%s placed" % type)


# --- camera and lights ---

func test_wall_pieces_fade_with_the_wall_behind_them() -> void:
	var layout := _shift_layout()
	var root := DeckBuilder.build(layout)
	_nodes.append(root)
	var loose := root.get_node("CorridorDressing")
	for n: Node in loose.get_children():
		check(["debris_pile", "floor_grate"].has(n.get_meta("kit_piece")), "only clutter is off the walls: %s" % n.name)
	var hosted := 0
	var types := {}
	for type: String in _hallway_types():
		types[type] = true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not types.has(mi.mesh.resource_name) or mi.get_parent() == loose or mi.get_meta("kit_piece") == "fixture":
			continue
		hosted += 1
		check(mi.get_parent().is_in_group(CAMERA_CUT), "%s is a direct child of a cut-away pivot" % mi.name)
	check_eq(hosted + loose.get_child_count(), CorridorDressing.placed(layout).size(), "all of them accounted for")


## T002: the wall tops are how you read the walls from the steep camera. A run can't cover them if it stops
## below them, and the camera is never behind one far enough to look under.
func test_the_high_runs_stay_under_the_wall_tops() -> void:
	var h := float(Data.value("deck", "wall_height_m"))
	for piece: Dictionary in CorridorDressing.placed(_shift_layout()):
		if ["pipe_run_high", "conduit_tray", "air_duct"].has(piece.type):
			check((piece.box as AABB).end.y < h, "%s tops out at %.2f, under the wall's %.2f" % [piece.type, (piece.box as AABB).end.y, h])


func test_a_fixture_explains_each_corridor_light_and_goes_out_with_it() -> void:
	var deck: Dictionary = (Data.load_data("deck") as Dictionary).duplicate(true)
	var layout := DeckLayout.new(deck, float(deck.room_scale))
	var built := DeckBuilder.build(layout)
	var lighting := DeckLighting.new()
	lighting.add_child(built)
	(Engine.get_main_loop() as SceneTree).root.add_child(lighting)
	_nodes.append(lighting)
	lighting.setup(layout, Environment.new(), built)
	var fx: Dictionary = KitMaterials.cfg().lighting.fixtures
	var walls: Node3D = built.get_node("Walls")
	for space: String in ["junction", "side_corridor"]:
		var layer := KitPieces.space_layer(layout, space)
		var mine: Array = walls.find_children("Fixture*", "MeshInstance3D", true, false).filter(func(f: MeshInstance3D) -> bool: return f.layers == layer)
		check_eq(mine.size(), (fx.spaces[space] as Array).size(), "%s: one per light" % space)
		for f: MeshInstance3D in mine:
			check(["wall_light_strip", "emergency_lamp"].has(f.mesh.resource_name), "%s wears %s" % [space, f.mesh.resource_name])
			for i in f.mesh.get_surface_count():
				if f.mesh.surface_get_name(i).begins_with("emit_"):
					var want: Array = ["emit_cool", "emit_amber"].map(func(k: String) -> Material: return KitMaterials.material(k))
					check(want.has(f.get_surface_override_material(i)), "its lit part wears its light's colour")
	var section := SectionLights.new()
	_nodes.append(section)
	section.setup(Data.value("shift", "lights", {}), layout, lighting.lights, walls)
	section.fail("side_corridor")
	section.tick(float(Data.value("shift", "lights", {}).flicker_s) + 0.1)
	var side_layer := KitPieces.space_layer(layout, "side_corridor")
	for f: MeshInstance3D in walls.find_children("Fixture*", "MeshInstance3D", true, false):
		if f.layers == side_layer:
			check(not f.visible, "a failed section's fixture goes out")
	section.reset()
