extends "res://tests/test_case.gd"
## T023: the biological survey vessel against A014-02.layout.json, the routes, its dressing, the A013 graphics
## and choosing the ship. The current ship's own tests hold the current ship; `test_the_current_ship...` here
## holds the door between them shut.

const DeckLayout := preload("res://src/study/deck_layout.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")
const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const Dressing := preload("res://src/kit/dressing.gd")
const CorridorDressing := preload("res://src/kit/corridor_dressing.gd")
const StalkerNav := preload("res://src/enemies/stalker_nav.gd")
const ShipPick := preload("res://src/shift/ship_pick.gd")
const TuningPanel := preload("res://src/debug/tuning_panel.gd")
const PLAN_FILE := "res://assets/source/A014-derelict-2/A014-02.layout.json"
const CATALOGUE := "res://assets/source/props/catalogue.json"
const SHIFT_SCENE := "res://scenes/shift/shift_deck.tscn"
const SHIP := "deck_survey"
const PLAN_IDS := {"BRIDGE": "bridge", "BIO LAB": "bio_lab", "MESS": "mess", "QUARTERS": "quarters", "WEST SPINE": "west_spine",
		"EAST SPINE": "east_spine", "ENGINEERING": "engineering", "AIRLOCK / HOLD": "airlock"}
const CLASS_OF_MARK := {"S": "small", "M": "medium", "H": "heavy", "BB": "heavy"}
## A catalogue prop won't match a plan rect exactly. The plan is a 0.5 m grid: half a cell for centres.
const HALF_CELL := 0.25
## No prop reaches further past its plan rect than this. Only the mess tables' benches need more than a half cell.
const FOOTPRINT_OVER_MAX := 0.3
const ROUTE_CLEAR_M := 1.5
const TOL := 0.001
const SAMPLE_M := 0.1

var _nodes: Array[Node] = []


func before_each() -> void:
	Data.use_ship(SHIP)


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Data.reset_ship()
	Data.clear_cache()


func _keep(n: Node) -> Node:
	_nodes.append(n)
	(Engine.get_main_loop() as SceneTree).root.add_child(n)
	return n


func _plan() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PLAN_FILE))


func _layout() -> DeckLayout:
	var deck: Dictionary = Data.load_data("deck")
	return DeckLayout.new(deck, float(deck.room_scale))


func _at(space: String, at: Array, layout: DeckLayout) -> Vector2:
	return layout.point_in(space, at)


func _rect_dist(r: Rect2, p: Vector2) -> float:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)).distance_to(p)


# --- the door between the ships ---

func test_the_current_ship_is_what_it_was_before_and_after_a_visit() -> void:
	Data.reset_ship()
	var kit_slots: int = (Data.value("kit", "slots") as Dictionary).size()
	var placements: int = (Data.value("salvage", "placements") as Array).size()
	var deck_spaces: Array = (Data.load_data("deck").spaces as Array).map(func(s: Dictionary) -> String: return s.name)
	check_eq(deck_spaces, ["junction", "medbay", "cargo", "side_corridor"], "the first ship's spaces")
	check(not Data.load_data("deck").has(Data.OVERRIDES_KEY), "deck.json has no overrides")
	Data.use_ship(SHIP)
	check(float((Data.value("salvage", "placements") as Array).size()) != float(placements), "the visit is a different ship")
	Data.reset_ship()
	check_eq((Data.value("kit", "slots") as Dictionary).size(), kit_slots, "the slots are back")
	check_eq((Data.value("salvage", "placements") as Array).size(), placements, "the salvage is back")
	check(not (Data.value("enemies", "ambush") as Dictionary).has("none"), "the ambush is back")
	check_eq(Data.ship, Data.BASE_SHIP, "on the first ship")


func test_the_default_stays_the_current_ship() -> void:
	var shift: Dictionary = Data.load_data("shift")
	check_eq(String(shift.ship_pick), ShipPick.FIRST, "ship_pick is first")
	check_eq(String(shift.ships[0]), Data.BASE_SHIP, "the first ship is deck.json")
	check((shift.ships as Array).has(SHIP), "the survey is listed")


func test_a_dictionary_already_held_sees_the_new_ship() -> void:
	Data.reset_ship()
	var held: Dictionary = Data.load_data("audio")
	check(not (held.ambience.rooms as Dictionary).has("bridge"), "no bridge on the first ship")
	Data.use_ship(SHIP)
	check((held.ambience.rooms as Dictionary).has("bridge"), "and the holder sees one on the survey")
	Data.reset_ship()
	check(not (held.ambience.rooms as Dictionary).has("bridge"), "and it's gone again")


func test_the_ship_flag() -> void:
	check_eq(Data.ship_arg(PackedStringArray(["--path", ".", "--ship", "survey"])), "survey", "--ship survey")
	check_eq(Data.ship_arg(PackedStringArray(["--ship=survey"])), "survey", "--ship=survey")
	check_eq(Data.ship_arg(PackedStringArray(["--path", "."])), "", "no flag")
	check_eq(Data.ship_file("survey"), SHIP, "survey names its deck file")
	check_eq(Data.ship_file(SHIP), SHIP, "a file's own name works")


func test_ship_pick_modes() -> void:
	var rng := RandomNumberGenerator.new()
	var cfg := {"ships": ["a", "b"], "ship_pick": ShipPick.FIRST}
	check_eq(ShipPick.pick(cfg, 2, rng), "a", "first stays first")
	cfg.ship_pick = ShipPick.ROTATE
	check_eq([ShipPick.pick(cfg, 1, rng), ShipPick.pick(cfg, 2, rng), ShipPick.pick(cfg, 3, rng)], ["a", "b", "a"], "rotate")
	cfg.ship_pick = ShipPick.RANDOM_SEEDED
	rng.seed = 7
	var first: Array = []
	for i in 8:
		first.append(ShipPick.pick(cfg, i + 1, rng))
	rng.seed = 7
	var again: Array = []
	for i in 8:
		again.append(ShipPick.pick(cfg, i + 1, rng))
	check_eq(again, first, "the same seed picks the same ships")
	check(first.has("a") and first.has("b"), "and picks both: %s" % str(first))


func test_the_panel_never_saves_a_ships_overrides_over_the_base_files() -> void:
	var panel: Node = _keep(TuningPanel.new())
	var dir := "user://t023_panel"
	DirAccess.make_dir_recursive_absolute(dir)
	panel.save_dir = dir
	panel.dirty["kit"] = true
	check_eq(panel.save().size(), 0, "nothing written on the survey")
	check(not FileAccess.file_exists(dir.path_join("kit.json")), "no file")


# --- geometry against the plan ---

func test_the_spaces_are_the_plans_in_final_metres() -> void:
	var layout := _layout()
	var plan := _plan()
	check_eq(layout.space_order.size(), 8, "eight spaces")
	for r: Dictionary in plan.rooms:
		var want := Rect2(float(r.x), float(r.y), float(r.width), float(r.depth))
		check_eq(layout.space_rect(PLAN_IDS[r.name]), want, "%s, unscaled" % r.name)
	check_eq(layout.bounds.size, Vector2(37.5, 29.0), "the hull's envelope, as A014 gives it")
	var other: DeckLayout = DeckLayout.new(Data.load_data("deck"), 1.15)
	check_eq(other.space_rect("bridge"), layout.space_rect("bridge"), "room_scale doesn't touch final metres")
	check_eq(float(Data.load_data("deck").room_scale), 0.85, "and it's still the game's scale")


func test_every_door_is_where_the_plan_has_it() -> void:
	var layout := _layout()
	var plan_doors: Array = _plan().doors
	check_eq(layout.doors.size(), plan_doors.size(), "ten doors")
	for d: Dictionary in plan_doors:
		var want := Rect2(float(d.x), float(d.y), float(d.width), float(d.depth))
		var near: Variant = null
		for door: Dictionary in layout.doors:
			if near == null or (door.rect as Rect2).get_center().distance_to(want.get_center()) < (near.rect as Rect2).get_center().distance_to(want.get_center()):
				near = door
		check((near.rect as Rect2).get_center().distance_to(want.get_center()) <= HALF_CELL, "%s found at %s" % [d.id, near.rect])
		check((near.rect as Rect2).size.is_equal_approx(want.size), "%s is %s, plan %s" % [d.id, near.rect.size, want.size])


func test_the_doors_connect_what_the_plan_says_and_engineering_has_one() -> void:
	var layout := _layout()
	var doors_of := {}
	for door: Dictionary in layout.doors:
		for n: String in layout.space_order:
			if (door.rect as Rect2).grow(0.05).intersects(layout.space_rect(n)):
				doors_of[n] = int(doors_of.get(n, 0)) + 1
	check_eq(int(doors_of.engineering), 1, "engineering is the dead end")
	check_eq(int(doors_of.airlock), 1, "the hold has one door")
	check_eq(int(doors_of.west_spine), 5, "west spine")
	check_eq(int(doors_of.east_spine), 5, "east spine")
	for room: String in ["bridge", "bio_lab", "mess", "quarters"]:
		check_eq(int(doors_of[room]), 2, "%s has a door on each spine" % room)


func test_salvage_is_where_the_plan_has_it_by_class_with_the_black_box_on_the_bridge() -> void:
	var layout := _layout()
	var kinds: Dictionary = Data.value("salvage", "kinds")
	var placed: Array = Data.value("salvage", "placements")
	var marks: Array = _plan().salvage
	check_eq(placed.size(), marks.size(), "ten spots")
	for m: Dictionary in marks:
		var at := Vector2(float(m.x), float(m.y))
		var found: Variant = null
		for s: Dictionary in placed:
			if _at(s.space, s.at, layout).distance_to(at) <= HALF_CELL:
				found = s
		if not check(found != null, "a spot at %s" % at):
			continue
		check_eq(String(kinds[found.kind]["class"]), String(CLASS_OF_MARK[m.kind]), "%s at %s" % [found.kind, at])
		check_eq(bool(kinds[found.kind].get("prize", false)), m.kind == "BB", "only the mark BB is the prize")
		if m.kind == "BB":
			check_eq(String(found.space), "bridge", "the black box is on the bridge")


func test_every_spawn_candidate_is_where_the_plan_has_it() -> void:
	var layout := _layout()
	var points: Array = Data.value("enemies", "spawn_points")
	var marks: Array = _plan().spawn_candidates
	check_eq(points.size(), marks.size(), "as many as the plan")
	var nav := StalkerNav.new(Data.value("enemies", "stalker"), layout)
	for i in marks.size():
		var at := _at(points[i].space, points[i].at, layout)
		check(at.distance_to(Vector2(float(marks[i].x), float(marks[i].y))) <= HALF_CELL, "%s at %s" % [points[i].name, at])
		check_eq(String(points[i].kind), "vent" if marks[i].kind == "V" else "closet", "%s kind" % points[i].name)
		check(nav.is_free(at), "%s stands clear" % points[i].name)
		for w: Array in points[i].patrol:
			var q := _at(points[i].space, w, layout)
			check(layout.space_rect(points[i].space).has_point(q) and nav.is_free(q), "%s patrol %s is walkable" % [points[i].name, q])
	for s: Dictionary in Data.value("enemies", "pack"):
		for w: Array in s.patrol:
			check(nav.is_free(_at(s.space, w, layout)), "%s patrol %s is walkable" % [s.name, w])


func _cover_groups(layout: DeckLayout) -> Dictionary:
	var groups := {}
	var specs: Array = layout.data.props
	for i in specs.size():
		if not specs[i].has("plan_cover"):
			continue
		var k := int(specs[i].plan_cover)
		var g: Rect2 = layout.props[i].rect
		groups[k] = g if not groups.has(k) else (groups[k] as Rect2).merge(g)
	return groups


func test_every_cover_entry_is_catalogue_props_of_the_right_role_within_half_a_cell() -> void:
	var layout := _layout()
	var plan: Array = _plan().cover
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
	var groups := _cover_groups(layout)
	check_eq(groups.size(), plan.size(), "every cover entry is built")
	for i in plan.size():
		var want := Rect2(float(plan[i].x), float(plan[i].y), float(plan[i].width), float(plan[i].depth))
		var got: Rect2 = groups[i]
		check(got.get_center().distance_to(want.get_center()) <= HALF_CELL, "cover %d centre %s, plan %s" % [i, got.get_center(), want.get_center()])
		var over := maxf(maxf(want.position.x - got.position.x, got.end.x - want.end.x), maxf(want.position.y - got.position.y, got.end.y - want.end.y))
		check(over <= FOOTPRINT_OVER_MAX + TOL, "cover %d reaches %.2f m past the plan" % [i, over])
	for i in layout.props.size():
		var p: Dictionary = layout.props[i]
		if not layout.data.props[i].has("plan_cover"):
			check_eq(String(p.type), "tray_trolley", "the only prop that isn't the plan's")
			continue
		var entry: Dictionary = plan[int(layout.data.props[i].plan_cover)]
		var role := String(cat[p.type].role)
		check_eq(role, "cover_low" if entry.kind == "L" else "cover_tall", "%s's role fits a %s" % [p.type, entry.kind])
		check_eq(String(p.cover), "low" if entry.kind == "L" else "tall", "%s's class" % p.type)
		var file := KitPieces.slot_mesh(KitPieces.slot_file(p.type, p.size))
		check_eq(KitPieces.prop(p.type, p.size), file, "%s wears its file, not the box" % p.type)
		check(layout.space_rect(p.space).encloses(p.rect), "%s stays in %s" % [p.type, p.space])


func test_low_cover_stays_under_the_cutters_line() -> void:
	var aim_floor := float(Data.value("custodian", "cutter").aim_floor_m)
	for p: Dictionary in _layout().props:
		if String(p.cover) == "low":
			check(float(p.size.y) < aim_floor, "low %s stays under the line" % p.type)


func test_lights_and_colours_are_the_plans() -> void:
	var fixtures: Dictionary = Data.value("kit", "lighting").fixtures.spaces
	var flat: Array = []
	for space: String in _layout().space_order:
		flat.append_array(fixtures[space])
	var plan: Array = _plan().lights
	check_eq(flat.size(), plan.size(), "as many lights")
	var looks: Dictionary = Data.value("kit", "lighting").fixtures.looks
	for l: Dictionary in plan:
		var found: Array = flat.filter(func(e: Dictionary) -> bool: return Vector2(e.light_xz[0], e.light_xz[1]).is_equal_approx(Vector2(l.x, l.y)))
		if check(found.size() == 1, "one light at (%s, %s)" % [l.x, l.y]):
			check(looks.has(found[0].look), "the look %s exists" % found[0].look)
			var want: Array = {"red": ["red"], "cyan": ["cyan"], "orange": ["amber", "amber_low"], "white": ["cool", "cool_low"]}[l.color]
			check(want.has(String(found[0].look)), "(%s, %s) is %s, wears %s" % [l.x, l.y, l.color, found[0].look])


func test_custodian_is_where_the_plan_has_it() -> void:
	var layout := _layout()
	var c: Dictionary = Data.load_data("custodian")
	var plan: Dictionary = _plan().custodian
	check_eq(c.cutters.size(), 1, "one cutter")
	check(_at(c.cutters[0].space, c.cutters[0].at, layout).distance_to(Vector2(plan.cutter[0], plan.cutter[1])) <= TOL, "the cutter")
	check_eq(c.drones.size(), 1, "one drone")
	var route: Array = c.drones[0].route
	check_eq(route.size(), plan.drone_patrol.size(), "the patrol's length")
	var pts: Array = route.map(func(a: Array) -> Vector2: return _at(c.drones[0].space, a, layout))
	var body: Array = c.drone.body_size_m
	var radius := maxf(float(body[0]), float(body[2])) * 0.5
	for i in pts.size():
		check((pts[i] as Vector2).distance_to(Vector2(plan.drone_patrol[i][0], plan.drone_patrol[i][1])) <= TOL, "patrol point %d" % i)
		var from: Vector2 = pts[i]
		var to: Vector2 = pts[(i + 1) % pts.size()]
		for k in int(ceil(from.distance_to(to) / SAMPLE_M)) + 1:
			var at: Vector2 = from.move_toward(to, k * SAMPLE_M)
			check(layout.is_free(at, radius), "patrol leg %d misses walls and props at %s" % [i, at])


# --- routes ---

## The ship's floor with all the dressing that reaches past the wall line counted solid.
func _strict_layout() -> DeckLayout:
	var layout := _layout()
	for d: Dictionary in Dressing.placed(layout):
		layout.walls.append(d.rect)
	for c: Dictionary in CorridorDressing.placed(layout):
		if (c.low_rect as Rect2).has_area() and c.type != "floor_grate":  # a grate is flush: you walk on it
			layout.walls.append(c.low_rect)
	return layout


func _door_at(layout: DeckLayout, x: float, z: float) -> Dictionary:
	for d: Dictionary in layout.doors:
		if (d.rect as Rect2).has_point(Vector2(x, z)):
			return d
	return {}


func test_routes_are_at_least_a_metre_and_a_half_clear() -> void:
	var layout := _strict_layout()
	var hold: Vector2 = layout.space_rect("airlock").get_center()
	var cell := float(layout.data.path_check.cell_m)
	var radius := ROUTE_CLEAR_M * 0.5
	for d: Dictionary in layout.doors:
		check(layout.path_cells(hold, (d.rect as Rect2).get_center(), radius, cell) >= 0, "a %.1f m way to the door at %s" % [ROUTE_CLEAR_M, d.rect])
	for space: String in layout.space_order:
		check(layout.path_cells(hold, layout.space_rect(space).get_center(), radius, cell) >= 0, "a %.1f m way into %s" % [ROUTE_CLEAR_M, space])


## Shut off one door and the box is still reachable, and back: the loop goes both ways.
func test_the_black_box_can_be_reached_both_ways_round_the_loop() -> void:
	var box := Vector2(17.0, 2.5)
	var hold := Vector2(3.0, 25.0)
	var radius := ROUTE_CLEAR_M * 0.5
	var cell := 0.1
	var west := _strict_layout()
	var d2: Dictionary = _door_at(west, 10.25, 4.0)
	check(not d2.is_empty(), "D2 found")
	var via_west := west.path_cells(hold, box, radius, cell)
	check(via_west >= 0, "west of the loop")
	west.walls.append(_door_at(west, 22.25, 4.0).rect)
	check_eq(west.path_cells(hold, box, radius, cell), via_west, "with the east door shut it's the same way")
	var east := _strict_layout()
	east.walls.append(d2.rect)
	var via_east := east.path_cells(hold, box, radius, cell)
	check(via_east > via_west, "with the west door shut it's longer, round the east (%d cells against %d)" % [via_east, via_west])
	check_eq(east.path_cells(box, hold, radius, cell), via_east, "and home the same way")
	# Round the east side needs a cross-link: shut every other west door and it must still go.
	for z: float in [11.0, 19.0]:
		east.walls.append(_door_at(east, 10.25, z).rect)
	check(east.path_cells(hold, box, radius, cell) >= 0, "the far cross-link alone still does it")


func test_every_item_can_be_reached_and_taken() -> void:
	var layout := _layout()
	var nav := StalkerNav.new(Data.value("enemies", "stalker"), layout)
	var start := _at(layout.data.spawn.space, layout.data.spawn.at, layout)
	for s: Dictionary in Data.value("salvage", "placements"):
		var at := _at(s.space, s.at, layout)
		var path := nav.path(start, at)
		if check(path.size() > 0, "%s in %s" % [s.kind, s.space]):
			check(path[-1].distance_to(at) <= float(Data.value("salvage", "reach_m")), "%s is in reach of where the path ends" % s.kind)
		var size: Array = Data.value("salvage", "classes")[Data.value("salvage", "kinds")[s.kind]["class"]].size_m
		check(layout.is_free(at, float(size[0]) * 0.5), "%s lies on open floor" % s.kind)


## The legs a T012 bot walks with nobody in its way (tests/test_dressing.gd, `_bot_legs`).
func _bot_legs(layout: DeckLayout, nav: StalkerNav, greedy: bool) -> Array:
	var on_floor: Array = []
	for s: Dictionary in Data.value("salvage", "placements"):
		var klass := String(Data.value("salvage", "kinds")[s.kind]["class"])
		if greedy or klass != "heavy":
			on_floor.append({"at": layout.point_in(String(s.space), s.at), "small": klass == "small"})
	var home: Vector2 = layout.space_rect("airlock").get_center()
	var pos: Vector2 = layout.point_in(String(layout.data.spawn.space), layout.data.spawn.at)
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


func test_no_clutter_on_the_bots_routes() -> void:
	var layout := _layout()
	var cfg: Dictionary = Data.value("enemies", "stalker")
	var nav := StalkerNav.new(cfg, layout)
	var keep_off: Array = Dressing.placed(layout).filter(func(d: Dictionary) -> bool: return d.wall == "").map(func(d: Dictionary) -> Array: return [d.type, d.rect])
	for c: Dictionary in CorridorDressing.placed(layout):
		if c.host_at == null:
			keep_off.append([c.type, c.rect])
	var clear := float(cfg.nav.cell_m) * 0.5
	for greedy: bool in [true, false]:
		for path: PackedVector2Array in _bot_legs(layout, nav, greedy):
			check(path.size() > 0, "every stop is reachable")
			for i in path.size() - 1:
				var seg: Vector2 = path[i + 1] - path[i]
				for k in int(ceil(seg.length() / SAMPLE_M)) + 1:
					var at: Vector2 = path[i] + seg.normalized() * minf(k * SAMPLE_M, seg.length())
					for off: Array in keep_off:
						check(_rect_dist(off[1], at) >= clear, "%s is %.2f m from a bot's route at %s" % [off[0], _rect_dist(off[1], at), at])


# --- dressing ---

func test_clutter_stays_inside_off_props_doors_points_and_cover_lines() -> void:
	var layout := _layout()
	var radius := float(Data.value("player", "radius_m"))
	var stalker_r := float(Data.value("enemies", "stalker").radius_m)
	var flat: Array = []
	for s: Dictionary in Data.value("enemies", "spawn_points"):
		flat.append(_at(s.space, s.at, layout))
		for w: Array in s.patrol:
			flat.append(_at(s.space, w, layout))
	for s: Dictionary in Data.value("salvage", "placements"):
		flat.append(_at(s.space, s.at, layout))
	var clutter: Array = Dressing.placed(layout).filter(func(d: Dictionary) -> bool: return d.wall == "")
	check(clutter.size() >= 10, "%d pieces of clutter" % clutter.size())
	for d: Dictionary in clutter:
		var r: Rect2 = d.rect
		check(layout.space_rect(d.space).encloses(r), "%s inside %s: %s" % [d.type, d.space, r])
		for p: Dictionary in layout.props:
			check(not r.intersects(p.rect), "%s clear of %s" % [d.type, p.type])
			if p.cover == "low":
				var line: Rect2 = (p.rect as Rect2).grow_individual(radius * 2.0, 0.0, radius * 2.0, 0.0) if (p.rect as Rect2).size.y >= (p.rect as Rect2).size.x \
						else (p.rect as Rect2).grow_individual(0.0, radius * 2.0, 0.0, radius * 2.0)
				check(not r.intersects(line), "%s out of the line of %s" % [d.type, p.type])
		for door: Dictionary in layout.doors:
			check(not r.intersects((door.rect as Rect2).grow(radius * 2.0)), "%s clear of the door at %s" % [d.type, door.rect])
		for q: Vector2 in flat:
			check(_rect_dist(r, q) >= stalker_r, "%s is %.2f m from a point at %s" % [d.type, _rect_dist(r, q), q])


func test_each_room_is_dressed_from_its_set() -> void:
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
	var layout := _layout()
	var sets := {}
	for d: Dictionary in Dressing.placed(layout):
		sets[d.space] = (sets.get(d.space, []) as Array) + [String(cat[d.type].set)]
	for p: Dictionary in layout.props:
		sets[p.space] = (sets.get(p.space, []) as Array) + [String(cat[p.type].set)]
	var want := {"bridge": "bridge", "bio_lab": "biolab", "mess": "mess", "quarters": "quarters", "engineering": "engineering", "airlock": "cargo"}
	for room: String in want:
		check((sets.get(room, []) as Array).has(want[room]), "%s has %s pieces: %s" % [room, want[room], sets.get(room)])


func test_three_tanks_along_the_lab_wall_and_they_glow() -> void:
	var layout := _layout()
	var tanks: Array = layout.props.filter(func(p: Dictionary) -> bool: return p.type == "specimen_tank")
	check_eq(tanks.size(), 3, "three tanks")
	var root: Node = _keep(DeckBuilder.build(layout))
	var meshes: Array = root.get_node("Props").find_children("*", "MeshInstance3D", true, false).filter(
			func(m: MeshInstance3D) -> bool: return m.get_meta("kit_piece") == "specimen_tank")
	check_eq(meshes.size(), 3, "three tank meshes")
	for mi: MeshInstance3D in meshes:
		var glows := 0
		for i in mi.mesh.get_surface_count():
			var o: Material = mi.get_surface_override_material(i)
			if o is StandardMaterial3D and (o as StandardMaterial3D).emission_enabled:
				glows += 1
		check(glows >= 2, "its lamps and glass glow: %d" % glows)
	for p: Dictionary in tanks:
		check((p.rect as Rect2).position.y - layout.space_rect("bio_lab").position.y < 1.0, "along the north wall")


func test_the_meal_trolley_stopped_at_the_seal() -> void:
	var layout := _layout()
	var t: Array = layout.props.filter(func(d: Dictionary) -> bool: return d.type == "tray_trolley")
	check_eq(t.size(), 1, "one trolley")
	var d5: Dictionary = _door_at(layout, 22.25, 11.0)
	check(_rect_dist(d5.rect, (t[0].rect as Rect2).get_center()) < 2.5, "by the bio lab's door")
	check_eq(String(t[0].space), "east_spine", "on the corridor side of it")
	check_eq(String(t[0].cover), "none", "it's in the way, not cover")
	check(not (t[0].rect as Rect2).intersects((d5.rect as Rect2).grow(float(Data.value("player", "radius_m")) * 2.0)), "and leaves the door clear")
	check_eq(KitPieces.prop("tray_trolley", t[0].size), KitPieces.slot_mesh(KitPieces.slot_file("tray_trolley", t[0].size)), "wearing its file")


func test_both_spines_have_t19s_dressing_by_the_same_generator() -> void:
	var layout := _layout()
	var pieces := CorridorDressing.placed(layout)
	var limit := float(layout.data.dressing_max_intrusion_m)
	var exempt: Array = layout.data.corridor_dressing.over_limit_ok
	for spine: String in ["west_spine", "east_spine"]:
		var here: Array = pieces.filter(func(c: Dictionary) -> bool: return c.space == spine)
		var counts := {}
		for c: Dictionary in here:
			counts[c.type] = int(counts.get(c.type, 0)) + 1
		for type: String in ["wall_rib", "pipe_run_high", "pipe_run_low", "door_jamb", "door_lintel", "wall_panel_breached", "hanging_cables"]:
			check(int(counts.get(type, 0)) >= 1, "%s has %s: %s" % [spine, type, counts])
		check(int(counts.wall_rib) >= 6, "%s has a rhythm of ribs: %d" % [spine, counts.wall_rib])
		check_eq(int(counts.door_lintel), 5, "%s dresses its five doors" % spine)
		var r: Rect2 = layout.space_rect(spine)
		for c: Dictionary in here:
			if c.host_at != null and not exempt.has(c.type) and (c.low_rect as Rect2).has_area():
				var low: Rect2 = c.low_rect
				var room_w: float = minf(low.end.x - r.position.x, r.end.x - low.position.x)
				var room_n: float = minf(low.end.y - r.position.y, r.end.y - low.position.y)
				check(minf(room_w, room_n) <= limit + 0.02, "%s reaches %.2f m past the wall" % [c.type, minf(room_w, room_n)])
	var fixtures: Dictionary = Data.value("kit", "lighting").fixtures.spaces
	for spine: String in ["west_spine", "east_spine"]:
		for f: Dictionary in fixtures[spine]:
			check(f.has("prop"), "%s's lights wear hallway fixtures" % spine)


# --- A013 graphics ---

func test_every_a013_decal_loads_and_is_placed() -> void:
	var items: Dictionary = KitMaterials.cfg().room_decals.items
	check_eq(items.size(), 37, "A013's thirty-seven graphics")
	var signage: Dictionary = KitMaterials.cfg().signage
	var used := {}
	for list: String in ["walls", "floors", "stuck"]:
		for e: Dictionary in signage[list]:
			used[e.image] = true
	for image: String in items:
		var tex: Texture2D = KitMaterials.decal(image).albedo_texture
		if check(tex != null, "%s loads" % image):
			check(tex.get_width() > 100, "%s has pixels" % image)
		check(used.has(image), "%s is on the ship" % image)


func test_every_sign_lands_on_a_real_surface() -> void:
	var layout := _layout()
	var root: Node = _keep(DeckBuilder.build(layout))
	var s: Dictionary = KitMaterials.cfg().signage
	var on_walls := 0
	for n: Node in root.get_node("Walls").find_children("Sign_*", "MeshInstance3D", true, false):
		on_walls += 1
	check_eq(on_walls, (s.walls as Array).size(), "every wall sign found its wall, none in a doorway")
	check_eq(root.get_node("FloorSigns").get_child_count(), (s.floors as Array).size() + (s.stuck as Array).size(), "floor signs and stickers")


func test_every_room_has_its_plate() -> void:
	var by_space := {}
	for e: Dictionary in KitMaterials.cfg().signage.walls:
		if String(e.image).begins_with("plate_"):
			by_space[e.space] = e.image
	for room: String in ["bridge", "bio_lab", "mess", "quarters", "engineering", "west_spine", "east_spine"]:
		check(by_space.has(room), "%s has a plate" % room)
	check((KitMaterials.cfg().signage.walls as Array).any(func(e: Dictionary) -> bool: return e.space == "airlock" and e.image == "airlock_fee"), "the hold has its fee")


func test_the_inventory_tags_are_on_their_props() -> void:
	var layout := _layout()
	var stuck: Array = KitMaterials.cfg().signage.stuck
	var reactor: Dictionary = layout.props.filter(func(p: Dictionary) -> bool: return p.type == "reactor_core")[0]
	var chair: Dictionary = Dressing.placed(layout).filter(func(d: Dictionary) -> bool: return d.type == "captain_chair")[0]
	for e: Dictionary in stuck:
		var at := _at(e.space, e.at, layout)
		if e.image == "rem_tag_reactor":
			check(_rect_dist(reactor.rect, at) < 0.05, "the reactor tag is on the reactor, %.2f m off" % _rect_dist(reactor.rect, at))
		elif e.image == "rem_tag_chair":
			check(_rect_dist(chair.rect, at) < 0.05, "the chair tag is on the chair, %.2f m off" % _rect_dist(chair.rect, at))
	var overlays: Array = stuck.filter(func(e: Dictionary) -> bool: return String(e.image).begins_with("rem_stamp") or String(e.image).begins_with("rem_priority"))
	check(overlays.size() >= 4, "a few Remnant overlays: %d" % overlays.size())
	for e: Dictionary in overlays:
		var at := _at(e.space, e.at, layout)
		check(layout.props.any(func(p: Dictionary) -> bool: return (p.rect as Rect2).grow(0.05).has_point(at)), "%s at %s is on a prop" % [e.image, at])


# --- effects ---

func test_the_effects_the_packet_lists() -> void:
	var layout := _layout()
	var effects: Array = layout.data.effects
	var recipes: Dictionary = Data.value("vfx", "recipes")
	var by := {}
	for e: Dictionary in effects:
		check(recipes.has(e.recipe), "%s exists" % e.recipe)
		by[e.recipe] = (by.get(e.recipe, []) as Array) + [String(e.space)]
	check((by.sparking_console as Array).has("bridge"), "a sparking console on the bridge")
	check((by.steam_jet as Array).has("engineering"), "steam in engineering")
	check((by.acid_pool as Array).has("bio_lab"), "a pool in the lab")
	for space: String in layout.space_order:
		check((by.dust_motes as Array).has(space), "dust in %s" % space)
	check(effects.size() <= int(Data.value("vfx", "budgets").max_emitters), "within the emitter budget")


## Whatever else, the pool is looks: nothing in `data/enemies.json` puddles or the suit reads effects.
func test_the_pool_does_no_damage() -> void:
	var scene: Node = (load(SHIFT_SCENE) as PackedScene).instantiate()
	_keep(scene)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var pool: Dictionary = (scene.layout.data.effects as Array).filter(func(e: Dictionary) -> bool: return e.recipe == "acid_pool")[0]
	var at: Vector2 = scene.layout.point_in(pool.space, pool.at)
	check_eq(scene.pack.spits.puddles.damage_at(at, 1.0), 0.0, "no damage on the pool")


# --- the ship in the real scene ---

func test_the_shift_deck_runs_on_the_survey() -> void:
	var scene: Node = (load(SHIFT_SCENE) as PackedScene).instantiate()
	_keep(scene)
	await (Engine.get_main_loop() as SceneTree).process_frame
	check_eq(scene.layout.space_order.size(), 8, "no closet added: eight spaces")
	check_eq(scene.doors.doors.size(), 10, "ten doors")
	check_eq(scene.field.items.size(), 10, "ten items")
	check(scene.layout.breaches.is_empty(), "no breach")
	check(scene.airlock.has_point(scene._eye()), "you start in the hold")
	check_eq(scene.layout.space_at(scene.airlock.rect.get_center()), "airlock", "the hold is its own room")
	var prize: Array = scene.field.items.filter(func(i: RefCounted) -> bool: return String(i.kind) == "black_box")
	check_eq(prize.size(), 1, "one black box")
	check_eq(scene.layout.space_at(prize[0].at), "bridge", "on the bridge")
	check_eq(scene.pack.stalkers.size(), 2, "two stalkers")
	check(scene.pack.stalkers.all(func(s: Node) -> bool: return s.brain.state != s.brain.State.DORMANT), "neither waits on a panel")
	check_eq(scene.custodian.cutters.size(), 1, "the cutter")
	check_eq(scene.custodian.drones.size(), 1, "the drone")
	for i in 30:
		scene.simulate_world(1.0 / 30.0)
	check(not scene.ambush.fired, "there's no panel to fire")
	# The prize's alarm, which would blow a panel on the other ship.
	scene._trip_alarm()
	check(scene.ambush.fired, "the alarm's still marked it spent")
	check(scene.custodian.awake, "and it wakes CUSTODIAN")
	for i in 30:
		scene.simulate_world(1.0 / 30.0)
	scene.respawn()
	check_eq(scene.field.items.size(), 10, "and a new shift rolls the ten again")


func test_a_tiers_lights_exist_on_this_ship() -> void:
	var layout := _layout()
	var words: Dictionary = Data.value("shift", "section_words")
	for tier: Dictionary in Data.value("shift", "tiers"):
		for space: String in tier.get("lights", []):
			check(layout.spaces.has(space), "%s is a room" % space)
			check(words.has(space), "%s has a word" % space)


func test_every_space_has_its_tone_tail_step_and_word() -> void:
	var layout := _layout()
	var audio: Dictionary = Data.load_data("audio")
	var words: Dictionary = Data.value("paperwork", "space_words")
	for space: String in layout.space_order:
		check((audio.ambience.rooms as Dictionary).has(space), "%s tone" % space)
		check((audio.room_tail as Dictionary).has(space), "%s tail" % space)
		check((audio.footsteps.surfaces as Dictionary).has(space), "%s steps" % space)
		check(words.has(space), "%s's word on the forms" % space)
		check((Data.value("vfx", "room_draft") as Dictionary).has(space), "%s draft" % space)
		check((KitMaterials.cfg().wall_families.by_space as Dictionary).has(space), "%s walls" % space)
