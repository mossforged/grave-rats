extends "res://tests/test_case.gd"
## T016: the bed and medbay files, room dressing against everything that needs the floor, salvage
## models, the bed's shield face, and the anti-aliasing modes.

const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const Dressing := preload("res://src/kit/dressing.gd")
const DeckLayout := preload("res://src/study/deck_layout.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")
const StalkerNav := preload("res://src/enemies/stalker_nav.gd")
const CoverField := preload("res://src/cover/cover_field.gd")
const TipBed := preload("res://src/cover/tip_bed.gd")
const SalvageField := preload("res://src/salvage/salvage_field.gd")
const DisplayAA := preload("res://src/debug/display_aa.gd")
const TuningPanel := preload("res://src/debug/tuning_panel.gd")
const TMP := "user://t016_display"
const TOL := 0.02
const SAMPLE_M := 0.1

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Data.clear_cache()
	DisplayAA.apply((Engine.get_main_loop() as SceneTree).root, DisplayAA.starting_mode())
	for f in DirAccess.get_files_at(TMP) if DirAccess.dir_exists_absolute(TMP) else PackedStringArray():
		DirAccess.remove_absolute(TMP.path_join(f))


func _keep(n: Node) -> Node:
	_nodes.append(n)
	(Engine.get_main_loop() as SceneTree).root.add_child(n)
	return n


func _layout(deck: Dictionary = Data.load_data("deck")) -> DeckLayout:
	return DeckLayout.new(deck, float(deck.room_scale))


func _player_radius() -> float:
	return float(Data.value("player", "radius_m"))


func _rect_dist(r: Rect2, p: Vector2) -> float:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)).distance_to(p)


func _clutter(layout: DeckLayout) -> Array:
	return Dressing.placed(layout).filter(func(d: Dictionary) -> bool: return d.wall == "")


# --- bed and slots ---

func test_the_bed_and_medbay_slots_load_their_files() -> void:
	var slots: Dictionary = KitMaterials.cfg().slots
	for type: String in ["bed", "gurney", "surgical_lamp", "iv_stand", "trolley", "med_station"]:
		check_eq(String(slots[type]), "res://assets/game/props/%s.glb" % type, "%s slot" % type)
		check(KitPieces.slot_mesh(String(slots[type])) != null, "%s loads" % type)


func test_the_bed_and_gurney_lie_along_their_props() -> void:
	var layout := _layout()
	var seen := {}
	for p: Dictionary in layout.props:
		if p.type != "bed" and p.type != "gurney":
			continue
		seen[p.type] = true
		check_eq(KitPieces.prop(p.type, p.size), KitPieces.slot_mesh(String(KitMaterials.cfg().slots[p.type])), "%s wears its file" % p.type)
		var yaw := KitPieces.prop_yaw(layout, p)
		var box := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * KitPieces.prop(p.type, p.size).get_aabb()
		check(box.size.x <= p.size.x + TOL and box.size.z <= p.size.z + TOL, "%s turned to %s fits %s" % [p.type, box.size, p.size])
	check(seen.has("bed") and seen.has("gurney"), "the deck has both")


func test_the_gurney_is_low_cover_and_a_nav_blocker() -> void:
	var layout := _layout()
	var gurneys: Array = layout.props.filter(func(p: Dictionary) -> bool: return p.type == "gurney")
	check_eq(gurneys.size(), 1, "one gurney")
	check_eq(String(gurneys[0].cover), CoverField.LOW, "low cover")
	check(not layout.is_free((gurneys[0].rect as Rect2).get_center(), SAMPLE_M), "it blocks")


# --- dressing ---

func test_the_medbay_is_dressed_with_each_piece() -> void:
	var seen := {}
	for d: Dictionary in Dressing.placed(_layout()):
		seen[d.type] = d
	for type: String in ["surgical_lamp", "iv_stand", "trolley", "med_station"]:
		check(seen.has(type), "%s placed" % type)
	check_eq(String(seen.med_station.wall), "north", "the station is on a wall")


func test_dressing_adds_no_collision_cover_or_blockers() -> void:
	var deck: Dictionary = (Data.load_data("deck") as Dictionary).duplicate(true)
	var with := _layout(deck)
	var bare_deck := deck.duplicate(true)
	bare_deck.dressing = []
	var bare := _layout(bare_deck)
	check_eq(with.props.size(), bare.props.size(), "same props")
	check_eq(with.blockers().size(), bare.blockers().size(), "same blockers")
	var a := DeckBuilder.build(with)
	var b := DeckBuilder.build(bare)
	_keep(a)
	_keep(b)
	check_eq(a.find_children("*", "StaticBody3D", true, false).size(), b.find_children("*", "StaticBody3D", true, false).size(), "same bodies")
	check_eq(a.get_node("Dressing").get_child_count(), 4, "four pieces on the deck")
	check_eq(b.get_node("Dressing").get_child_count(), 0, "none without the list")


func test_a_deck_without_the_room_goes_undressed() -> void:
	var deck: Dictionary = (Data.load_data("deck") as Dictionary).duplicate(true)
	var p: Dictionary = Data.value("pirates", "deck", {})
	deck.spaces = (deck.spaces as Array).filter(func(s: Dictionary) -> bool: return (p.keep_spaces as Array).has(s.name))
	deck.doors = (p.doors as Array).duplicate(true)
	deck.props = (p.props as Array).duplicate(true)
	check_eq(Dressing.placed(_layout(deck)).size(), 0, "the pirate deck has no medbay")


func test_clutter_stays_inside_its_room_and_off_every_prop_and_door() -> void:
	var layout := _layout()
	for d: Dictionary in _clutter(layout):
		var r: Rect2 = d.rect
		check(layout.space_rect(d.space).encloses(r), "%s inside %s" % [d.type, d.space])
		for p: Dictionary in layout.props:
			check(not r.intersects(p.rect), "%s clear of %s" % [d.type, p.type])
		for door: Dictionary in layout.doors:
			check(not r.intersects((door.rect as Rect2).grow(float(Data.value("player", "radius_m")) * 2.0)), "%s clear of the door of %s" % [d.type, door.space])


## Low cover's long sides are where you brace, and a bed lands on either of its own. Tall cover only
## has to be kept off.
func test_clutter_stays_out_of_every_cover_line() -> void:
	var layout := _layout()
	var deck: Dictionary = Data.load_data("deck")
	for i in layout.props.size():
		var p: Dictionary = layout.props[i]
		var r: Rect2 = p.rect
		var tippable := bool(deck.props[i].get("tippable", false))
		var reach := 0.0
		if tippable:
			reach = (p.size as Vector3).y
		elif p.cover == CoverField.LOW:
			reach = _player_radius() * 2.0
		var line := r.grow_individual(reach, 0.0, reach, 0.0) if r.size.y >= r.size.x else r.grow_individual(0.0, reach, 0.0, reach)
		for d: Dictionary in _clutter(layout):
			check(not (d.rect as Rect2).intersects(line), "%s out of the line of %s at %s" % [d.type, p.type, p.center])


func test_the_wall_prop_sits_on_its_wall_at_its_height_clear_of_doors() -> void:
	var layout := _layout()
	for d: Dictionary in Dressing.placed(layout):
		if d.wall == "":
			continue
		var mesh: ArrayMesh = d.mesh
		var box: AABB = Transform3D(Basis(Vector3.UP, float(d.yaw)), d.position) * mesh.get_aabb()
		var room: Rect2 = layout.space_rect(d.space)
		check(absf(box.position.z - room.position.y) < TOL, "its back on the wall (%.3f, wall %.3f)" % [box.position.z, room.position.y])
		check(box.end.z > box.position.z, "it stands off the wall")
		check_eq(box.position.y, float(KitMaterials.cfg().wall_mounts[d.type].mount_y_m), "at mount_y_m")
		check(box.end.y < float(Data.load_data("deck").wall_height_m), "below the wall top")
		for door: Dictionary in layout.doors:
			check(not (d.rect as Rect2).intersects((door.rect as Rect2).grow(_player_radius())), "clear of a door")


func test_dressing_stays_off_spawns_patrols_salvage_and_targets() -> void:
	var layout := _layout()
	var radius := float(Data.value("enemies", "stalker", {}).radius_m)
	var flat: Array = []
	for s: Dictionary in Data.value("enemies", "spawn_points", []):
		flat.append([s.space, s.at])
		for w: Array in s.patrol:
			flat.append([s.space, w])
	for t: Dictionary in Data.value("weapons", "targets", {}).placements:
		flat.append([t.space, t.at])
	for s: Dictionary in Data.value("salvage", "placements", []):
		flat.append([s.space, s.at])
	for d: Dictionary in _clutter(layout):
		for f: Array in flat:
			var at := layout.point_in(String(f[0]), f[1])
			check(_rect_dist(d.rect, at) >= radius, "%s is %.2f m from a %s point at %s" % [d.type, _rect_dist(d.rect, at), f[0], f[1]])
	# The gurney collides: nothing may spawn, walk to or lie on it.
	var gurney: Rect2 = layout.props.filter(func(p: Dictionary) -> bool: return p.type == "gurney")[0].rect
	for f: Array in flat:
		var at := layout.point_in(String(f[0]), f[1])
		check(_rect_dist(gurney, at) >= radius, "the gurney is %.2f m from a %s point at %s" % [_rect_dist(gurney, at), f[0], f[1]])


## The legs a T012 bot walks with nobody in its way: to the nearest item it wants, home with its hands
## full or six in its pockets, until the ship is empty. tools/t012_bots.gd `_next_item`, `_should_go_home`.
func _bot_legs(bare: DeckLayout, nav: StalkerNav, greedy: bool) -> Array:
	var on_floor: Array = []
	for s: Dictionary in Data.value("salvage", "placements", []):
		var klass := String(Data.value("salvage", "kinds", {})[s.kind]["class"])
		if greedy or klass != "heavy":
			on_floor.append({"at": bare.point_in(String(s.space), s.at), "small": klass == "small"})
	var deck: Dictionary = Data.load_data("deck")
	var a: Dictionary = Data.value("shift", "airlock", {})
	var home: Vector2 = (bare.point_in(String(a.space), a.from) + bare.point_in(String(a.space), a.to)) * 0.5
	var pos: Vector2 = bare.point_in(String(deck.spawn.space), deck.spawn.at)
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


## On the nav without the gurney, since that's the route it mustn't take away. A path runs on nav cells,
## so half a cell clear of it is clear of the route. Nothing here collides but the gurney.
func test_dressing_stays_off_the_t012_bots_routes() -> void:
	var deck: Dictionary = (Data.load_data("deck") as Dictionary).duplicate(true)
	var layout := _layout(deck)
	var without := deck.duplicate(true)
	without.props = (without.props as Array).filter(func(p: Dictionary) -> bool: return p.type != "gurney")
	var bare := _layout(without)
	var cfg: Dictionary = Data.value("enemies", "stalker", {})
	var nav := StalkerNav.new(cfg, bare)
	var keep_off: Array = _clutter(layout).map(func(d: Dictionary) -> Array: return [d.type, d.rect])
	keep_off.append(["gurney", layout.props.filter(func(p: Dictionary) -> bool: return p.type == "gurney")[0].rect])
	var clear := float(cfg.nav.cell_m) * 0.5
	for greedy: bool in [true, false]:
		var legs := _bot_legs(bare, nav, greedy)
		check(legs.size() > Data.value("salvage", "placements", []).size() * 0.5, "%d legs" % legs.size())
		for path: PackedVector2Array in legs:
			check(path.size() > 0, "every stop on the bot's way is reachable")
			for i in path.size() - 1:
				var seg: Vector2 = path[i + 1] - path[i]
				for k in int(ceil(seg.length() / SAMPLE_M)) + 1:
					var at: Vector2 = path[i] + seg.normalized() * minf(k * SAMPLE_M, seg.length())
					for off: Array in keep_off:
						check(_rect_dist(off[1], at) >= clear, "%s is %.2f m from a bot's route at %s" % [off[0], _rect_dist(off[1], at), at])


func test_with_the_gurney_in_every_item_is_still_reachable() -> void:
	var layout := _layout()
	var nav := StalkerNav.new(Data.value("enemies", "stalker", {}), layout)
	var start: Vector2 = layout.point_in("junction", (Data.load_data("deck").spawn as Dictionary).at)
	for s: Dictionary in Data.value("salvage", "placements", []):
		check(nav.path(start, layout.point_in(String(s.space), s.at)).size() > 0, "%s in %s" % [s.kind, s.space])


# --- salvage ---

func test_every_salvage_kind_loads_its_file() -> void:
	var kinds: Dictionary = Data.value("salvage", "kinds", {})
	check_eq(kinds.size(), 9, "nine kinds")
	for kind: String in kinds:
		check_eq(String(kinds[kind].file), "res://assets/game/props/salvage_%s.glb" % kind, "%s maps to its file" % kind)
		var mesh := KitPieces.slot_mesh(String(kinds[kind].file))
		if check(mesh != null, "%s loads" % kind):
			for i in mesh.get_surface_count():
				check((KitMaterials.cfg().materials as Dictionary).has(mesh.surface_get_name(i)), "%s slot %s is a kit material" % [kind, mesh.surface_get_name(i)])


func test_brass_binds_to_the_kit_material() -> void:
	var mesh := KitPieces.slot_mesh(String(Data.value("salvage", "kinds", {}).fuse.file))
	var found := false
	for i in mesh.get_surface_count():
		if mesh.surface_get_name(i) == "brass":
			found = true
			check_eq(mesh.surface_get_material(i), KitMaterials.material("brass"), "brass is the kit's")
	check(found, "the fuse has a brass surface")


func _field(cfg: Dictionary) -> SalvageField:
	var field := SalvageField.new()
	_keep(field)
	field.setup(cfg, _layout(), Callable())
	var rng := RandomNumberGenerator.new()
	rng.seed = 16
	field.reset(rng)
	return field


func test_a_field_wears_the_models_and_keeps_the_class_code() -> void:
	var cfg: Dictionary = Data.load_data("salvage")
	var field := _field(cfg)
	var seen := {}
	for item: RefCounted in field.items:
		seen[item.kind] = true
		var root: Node3D = field.get_child(item.id)
		var body: MeshInstance3D = root.get_node("Body")
		var rim: MeshInstance3D = root.get_node("Rim")
		var spec: Dictionary = field.rules.kind_spec(item.kind)
		var c: Dictionary = field.rules.class_of(item)
		check_eq(body.mesh, KitPieces.slot_mesh(String(spec.file)), "%s wears its model" % item.kind)
		var want_rim := Color(String(spec.get("rim_color", c.rim_color)))
		check((rim.material_override as ShaderMaterial).get_shader_parameter("beacon_color").is_equal_approx(want_rim), "%s keeps its rim colour" % item.kind)
		var box: AABB = body.mesh.get_aabb()
		check(Vector2(box.size.x, box.size.z).length() * 0.5 < float(c.rim_radius_m) + TOL, "%s stands inside its ring" % item.kind)
		check(box.position.y < TOL and box.position.y > -TOL, "%s stands on the floor" % item.kind)
	check_eq(seen.size(), 9, "the placements use all nine kinds")


func test_the_class_colour_tints_the_body_but_not_its_lights() -> void:
	var field := _field(Data.load_data("salvage"))
	var by_class := {}
	for item: RefCounted in field.items:
		var body: MeshInstance3D = field.get_child(item.id).get_node("Body")
		for i in body.mesh.get_surface_count():
			var kit: StandardMaterial3D = body.mesh.surface_get_material(i)
			var worn: StandardMaterial3D = body.get_surface_override_material(i)
			if kit.emission_enabled:
				check_eq(worn, kit, "%s %s stays the kit's light" % [item.kind, body.mesh.surface_get_name(i)])
			elif body.mesh.surface_get_name(i) == "steel":
				by_class[item.klass] = worn.albedo_color
	check_eq(by_class.size(), 3, "steel in every class")
	check(by_class.small != by_class.medium and by_class.medium != by_class.heavy and by_class.small != by_class.heavy, "steel differs by class: %s" % by_class)


func test_a_carried_item_keeps_its_model_and_drops_its_ring() -> void:
	var field := _field(Data.load_data("salvage"))
	var item: RefCounted = field.items.filter(func(i: RefCounted) -> bool: return i.klass == "medium")[0]
	field.hold_up(item, Transform3D.IDENTITY)
	var root: Node3D = field.get_child(item.id)
	check(root.visible, "shown in hand")
	check(not (root.get_node("Rim") as Node3D).visible, "no ring in hand")
	check_eq((root.get_node("Body") as MeshInstance3D).mesh, KitPieces.slot_mesh(String(field.rules.kind_spec(item.kind).file)), "the same model")


# --- the tipped bed ---

func _bed(rect: Rect2, from: Vector2) -> TipBed:
	var bed := TipBed.new()
	_keep(bed)
	var cfg: Dictionary = Data.value("cover", "bed", {})
	var spec := {"size_m": [0.9, 0.75, 2.0]}
	bed.setup(spec, rect, CoverField.new(Data.load_data("cover")), cfg)
	check(bed.try_tip(from), "it starts")
	return bed


func _mesh_box(bed: TipBed) -> AABB:
	var mi: MeshInstance3D = bed.get_node("Pivot/Mesh")
	return mi.global_transform * mi.mesh.get_aabb()


func _each_way() -> Array:
	var along_z := Rect2(-0.45, -1.0, 0.9, 2.0)
	var along_x := Rect2(-1.0, -0.45, 2.0, 0.9)
	return [
		[along_z, Vector2(-2.0, 0.0), Vector3.RIGHT],
		[along_z, Vector2(2.0, 0.0), Vector3.LEFT],
		[along_x, Vector2(0.0, -2.0), Vector3.BACK],
		[along_x, Vector2(0.0, 2.0), Vector3.FORWARD],
	]


func test_a_tipped_bed_turns_its_plated_face_away_from_whoever_tipped_it() -> void:
	for way: Array in _each_way():
		var bed := _bed(way[0], way[1])
		bed.tick(float(bed.cfg.tip_s))
		var mi: MeshInstance3D = bed.get_node("Pivot/Mesh")
		var underside: Vector3 = mi.global_transform.basis * Vector3.DOWN
		check(underside.dot(way[2]) > 0.99, "from %s the underside faces %s, not %s" % [way[1], underside, way[2]])


func test_the_files_underside_is_a_solid_plate() -> void:
	var mesh := KitPieces.prop("bed", Vector3(0.9, 0.75, 2.0))
	var area := 0.0
	for i in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for t in range(0, idx.size(), 3):
			var cross := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
			if absf(cross.normalized().y) > 0.9:
				var n: Vector3 = (a[Mesh.ARRAY_NORMAL] as PackedVector3Array)[idx[t]]
				if n.y < 0.0:
					area += cross.length() * 0.5
	check(area > 0.9 * 2.0 * 0.6, "%.2f m2 faces down" % area)


func test_a_tipped_bed_lands_inside_its_unchanged_footprint() -> void:
	for way: Array in _each_way():
		var rect: Rect2 = way[0]
		var bed := _bed(rect, way[1])
		bed.tick(float(bed.cfg.tip_s))
		var box := _mesh_box(bed)
		var want: Rect2 = bed.footprint()
		var got := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		check(want.grow(TOL).encloses(got), "%s inside %s" % [got, want])
		check(not want.intersects(rect.grow(-TOL)), "the footprint is still past the far edge")
		check_eq(want.size.x if rect.size.y >= rect.size.x else want.size.y, 0.75, "as thick as the bed is high")


func test_a_bed_never_dips_under_the_floor_and_takes_the_same_time() -> void:
	for way: Array in _each_way():
		var bed := _bed(way[0], way[1])
		var tip_s := float(bed.cfg.tip_s)
		var steps := 16
		for i in steps:
			check(not bed.tip.state == bed.tip.State.OVERTURNED, "still going at step %d" % i)
			bed.tick(tip_s / steps)
			check(_mesh_box(bed).position.y > -TOL, "at %.2f the bed is at y %.3f" % [bed.tip.progress, _mesh_box(bed).position.y])
		check_eq(bed.tip.state, bed.tip.State.OVERTURNED, "down in tip_s")


func test_an_upright_bed_sits_on_its_rect() -> void:
	var bed := TipBed.new()
	_keep(bed)
	var rect := Rect2(3.0, 4.0, 0.9, 2.0)
	bed.setup({"size_m": [0.9, 0.75, 2.0]}, rect, CoverField.new(Data.load_data("cover")), Data.value("cover", "bed", {}))
	var box := _mesh_box(bed)
	check(rect.grow(TOL).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "%s on %s" % [box, rect])


# --- anti-aliasing ---

func test_the_four_modes_each_switch_the_viewport() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var want := {"msaa2": [Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_DISABLED], "msaa4": [Viewport.MSAA_4X, Viewport.SCREEN_SPACE_AA_DISABLED],
			"msaa2_smaa": [Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_SMAA], "msaa2_fxaa": [Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_FXAA]}
	check_eq(DisplayAA.modes().size(), 4, "four modes")
	for id: String in want:
		check(DisplayAA.apply(root, id), "%s applies" % id)
		check_eq(root.msaa_3d, want[id][0], "%s msaa" % id)
		check_eq(root.screen_space_aa, want[id][1], "%s screen space" % id)
		check_eq(DisplayAA.mode_of(root), id, "%s reads back" % id)


func test_the_panel_picks_a_mode_live_and_saves_only_that() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var root := (Engine.get_main_loop() as SceneTree).root
	var panel := TuningPanel.new()
	panel.save_dir = TMP
	_keep(panel)
	check(panel.aa_picker != null and panel.aa_picker.item_count == 4, "four entries under Display")
	var before := FileAccess.get_file_as_string("res://data/display.json")
	for mode: Dictionary in DisplayAA.modes():
		check(panel.pick_aa(String(mode.id)), "%s picked" % mode.id)
		check_eq(DisplayAA.mode_of(root), String(mode.id), "live")
		check_eq(String(panel.aa_picker.get_item_metadata(panel.aa_picker.selected)), String(mode.id), "the picker follows")
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TMP.path_join("display.json")))
		check_eq(String(saved.aa_mode), String(mode.id), "saved")
		check_eq((saved.aa_modes as Array).size(), 4, "the modes survive a save")
	check_eq(DirAccess.get_files_at(TMP).size(), 1, "only display.json written")
	check_eq(FileAccess.get_file_as_string("res://data/display.json"), before, "the test left the real file alone")
	check(panel.dirty.is_empty(), "no tuning swept along")


func test_a_saved_mode_is_what_the_next_run_starts_in() -> void:
	(Data.load_data("display") as Dictionary).aa_mode = "msaa4"
	if OS.get_environment("DISPLAY_AA") == "":
		check_eq(DisplayAA.starting_mode(), "msaa4", "starts in the saved mode")


func test_an_unknown_mode_changes_nothing() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var root := (Engine.get_main_loop() as SceneTree).root
	DisplayAA.apply(root, "msaa4")
	var panel := TuningPanel.new()
	panel.save_dir = TMP
	_keep(panel)
	check(not panel.pick_aa("nope"), "refused")
	check_eq(DisplayAA.mode_of(root), "msaa4", "still 4x")
	check_eq(DirAccess.get_files_at(TMP).size(), 0, "nothing saved")


func test_the_panel_shows_frame_time() -> void:
	var panel := TuningPanel.new()
	_keep(panel)
	panel.show_frame_time(7.5, 9.25)
	check(panel.frame_label.text.contains("7.50") and panel.frame_label.text.contains("9.25"), panel.frame_label.text)
