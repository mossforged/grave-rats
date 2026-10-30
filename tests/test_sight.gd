extends "res://tests/test_case.gd"
## T004 sight: walls, doors and props against line of sight, three states, targets, the cones,
## the flashlight matching the cone, and "every number comes from data".

const Visibility := preload("res://src/sight/visibility.gd")
const SightGrid := preload("res://src/sight/sight_grid.gd")
const SightSystem := preload("res://src/sight/sight_system.gd")
const SightTarget := preload("res://src/sight/sight_target.gd")
const Flashlight := preload("res://src/sight/flashlight.gd")
const DeckLayout := preload("res://src/study/deck_layout.gd")
const NUMBER_FREE := ["res://src/sight/visibility.gd", "res://src/sight/sight_system.gd",
	"res://src/sight/flashlight.gd", "res://src/sight/sight_target.gd", "res://src/sight/sight_debug.gd",
	"res://src/doors/door_state.gd", "res://src/doors/door.gd", "res://src/doors/door_system.gd"]
const NORTH := 0.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Data.clear_cache()


func _cfg() -> Dictionary:
	return (Data.load_data("sight") as Dictionary).duplicate(true)


func _layout() -> DeckLayout:
	var deck: Dictionary = Data.load_data("deck")
	return DeckLayout.new(deck, float(deck.room_scale))


## A wall from x -5 to 5 at z -3 (north of the eye at the origin).
func _vis_with_wall() -> Visibility:
	var v := Visibility.new(_cfg())
	v.set_static([Rect2(-5, -3.5, 10, 0.5)])
	return v


func test_a_wall_blocks_sight() -> void:
	var v := _vis_with_wall()
	check(v.can_see(Vector2.ZERO, NORTH, true, Vector2(0, -2.9)), "this side of the wall")
	check(not v.can_see(Vector2.ZERO, NORTH, true, Vector2(0, -4)), "behind the wall")
	var poly := v.polygon(Vector2.ZERO, NORTH, true)
	for p in poly:
		check(p.y >= -3.0 - 0.001 or absf(p.x) > 5.0, "polygon stops at the wall face (%s)" % str(p))


func test_touching_rects_have_no_inner_edge() -> void:
	var v := Visibility.new(_cfg())
	v.set_static([Rect2(0, 0, 2, 1), Rect2(2, 0, 2, 1)])
	check_eq(v.edge_count(), 4, "two pieces of one wall make one outline")
	var chain := Visibility.new(_cfg())
	chain.set_static([Rect2(0, 0, 2, 1), Rect2(2, 0, 2, 1), Rect2(4, 0, 1, 3)])
	check_eq(chain.edge_count(), 6, "an L has six sides")


func test_sight_slips_past_a_corner_but_not_through_it() -> void:
	# A room corner: the wall ends at x = 1, so a ray past that end carries on to the cone's limit.
	var v := Visibility.new(_cfg())
	v.set_static([Rect2(-5, -3.5, 6, 0.5)])
	var poly := v.polygon(Vector2.ZERO, NORTH, true)
	var range_m := float(_cfg().cone_on.range_m)
	var reached := false
	var stopped := false
	for p in poly:
		if p.x > 0.0 and p.y < -3.5:
			reached = reached or p.length() > range_m - 0.01
		if p.x < 1.0 and absf(p.y + 3.0) < 0.01:
			stopped = true
	check(reached, "past the wall's end the sight goes on")
	check(stopped, "before it, it stops at the wall")


func test_the_light_off_cone_is_shorter_than_the_on_cone() -> void:
	var cfg := _cfg()
	check(float(cfg.cone_off.range_m) < float(cfg.cone_on.range_m), "off is shorter in the data")
	var v := Visibility.new(cfg)
	v.set_static([])
	var mid := (float(cfg.cone_off.range_m) + float(cfg.cone_on.range_m)) * 0.5
	var p := Vector2(0, -mid)
	check(v.can_see(Vector2.ZERO, NORTH, true, p), "the light reaches %.1f m" % mid)
	check(not v.can_see(Vector2.ZERO, NORTH, false, p), "no light doesn't")


func test_awareness_is_all_around_and_short() -> void:
	var cfg := _cfg()
	var v := Visibility.new(cfg)
	v.set_static([])
	var r := float(cfg.awareness_radius_m)
	for a: float in [90.0, 180.0, 270.0]:
		var dir := Visibility.yaw_dir2(deg_to_rad(a))
		check(v.can_see(Vector2.ZERO, NORTH, true, dir * (r - 0.1)), "inside the radius at %d°" % a)
		check(not v.can_see(Vector2.ZERO, NORTH, true, dir * (r + 0.1)), "outside it at %d°" % a)


func test_the_polygon_is_the_cone_plus_the_circle() -> void:
	var cfg := _cfg()
	var v := Visibility.new(cfg)
	v.set_static([])
	var poly := v.polygon(Vector2.ZERO, NORTH, true)
	var half := deg_to_rad(float(cfg.cone_on.half_angle_deg))
	var far := 0.0
	for p in poly:
		var y := atan2(-p.x, -p.y)
		if absf(absf(y) - half) < 0.0001:
			continue  # the rays right on the wedge's edge can round either way
		var want := float(cfg.cone_on.range_m) if absf(y) <= half else float(cfg.awareness_radius_m)
		far = maxf(far, p.length())
		check(absf(p.length() - want) < 0.01, "at %.1f° reach %.2f, want %.2f" % [rad_to_deg(y), p.length(), want])
	check(is_equal_approx(far, float(cfg.cone_on.range_m)), "reaches the full range")


func test_numbers_come_from_data() -> void:
	var cfg := _cfg()
	cfg.cone_on.range_m = 30.0
	cfg.awareness_radius_m = 0.5
	var v := Visibility.new(cfg)
	v.set_static([])
	check(v.can_see(Vector2.ZERO, NORTH, true, Vector2(0, -29)), "edited cone range is used")
	check(not v.can_see(Vector2.ZERO, NORTH, true, Vector2(0, 1)), "edited awareness is used")


func test_grid_states_and_memory_persist_after_leaving() -> void:
	var g := SightGrid.new(Rect2(0, 0, 10, 10), 0.5)
	var at := Vector2(2, 2)
	var far := Vector2(8, 8)
	check_eq(g.state_at(at), SightGrid.UNKNOWN, "starts unknown")
	g.update(PackedVector2Array([Vector2(1, 1), Vector2(3, 1), Vector2(3, 3), Vector2(1, 3)]))
	check_eq(g.state_at(at), SightGrid.VISIBLE, "seen now")
	check_eq(g.state_at(far), SightGrid.UNKNOWN, "elsewhere still unknown")
	g.update(PackedVector2Array([Vector2(7, 7), Vector2(9, 7), Vector2(9, 9), Vector2(7, 9)]))
	check_eq(g.state_at(at), SightGrid.REMEMBERED, "left: remembered")
	check_eq(g.state_at(far), SightGrid.VISIBLE, "the new place is seen")
	g.update(PackedVector2Array())
	check_eq(g.state_at(far), SightGrid.REMEMBERED, "looking at nothing keeps the memory")
	g.clear()
	check_eq(g.state_at(at), SightGrid.UNKNOWN, "a new run forgets")


## The grid's cells must agree with the polygon they were filled from.
func test_grid_fill_matches_the_polygon() -> void:
	var g := SightGrid.new(Rect2(-6, -6, 12, 12), 0.25)
	var poly := PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 2), Vector2(-3, 0)])
	g.update(poly)
	for z in g.nz:
		for x in g.nx:
			var p := g.origin + (Vector2(x, z) + Vector2(0.5, 0.5)) * g.cell
			var inside := Geometry2D.is_point_in_polygon(p, poly)
			if inside != (g.states[z * g.nx + x] == SightGrid.VISIBLE):
				check(false, "cell at %s: inside %s, state %d" % [str(p), str(inside), g.states[z * g.nx + x]])


func _spawn_system(layout: DeckLayout) -> SightSystem:
	var s := SightSystem.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	_nodes.append(s)
	s.setup(layout)
	return s


func _spawn_target(at: Vector2) -> SightTarget:
	var e := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(e)
	_nodes.append(e)
	e.global_position = Vector3(at.x, 0, at.y)
	var t := SightTarget.new()
	e.add_child(t)
	return t


func test_a_sight_target_behind_a_wall_is_hidden() -> void:
	var layout := _layout()
	var s := _spawn_system(layout)
	var med := layout.space_rect("medbay")
	# In the junction looking due west at the medbay's wall, far from its door.
	var eye := Vector2(2.0, med.position.y + 1.0)
	var behind := _spawn_target(Vector2(-3.0, eye.y))
	var beside := _spawn_target(Vector2(-0.1 + 1.0, eye.y))
	s.update_sight(eye, deg_to_rad(90.0), true, 0.0, true)
	check(not behind.seen, "behind the wall: not seen")
	check(not (behind.get_parent() as Node3D).visible, "and its entity is hidden")
	check(beside.seen, "in front of the wall: seen")
	check((beside.get_parent() as Node3D).visible, "and shown")


func test_low_props_do_not_block_and_tall_props_do() -> void:
	var layout := _layout()
	var s := _spawn_system(layout)
	var low: Dictionary = {}
	var tall: Dictionary = {}
	for p: Dictionary in layout.props:
		if p.type == "crate_low":
			low = p
		if p.type == "locker_bank":
			tall = p
	check(float(low.size.y) < float(s.cfg.tall_prop_min_m), "fixture: this crate is low")
	check(float(tall.size.y) >= float(s.cfg.tall_prop_min_m), "fixture: this locker bank is tall")
	s.update_sight(Vector2(1000, 1000), 0.0, true, 0.0, true)
	for pair: Array in [[low, true], [tall, false]]:
		var c: Vector2 = pair[0].center
		var half: float = (pair[0].rect as Rect2).size.x * 0.5 + 0.5
		var a: Vector2 = c + Vector2(half, 0)
		var b: Vector2 = c - Vector2(half, 0)
		check_eq(not s.visibility.blocked(a, b), pair[1], "%s across its middle" % pair[0].type)


func test_seen_tall_props_and_doors_are_revealed_whole() -> void:
	var layout := _layout()
	var s := _spawn_system(layout)
	var tall: Dictionary = {}
	for p: Dictionary in layout.props:
		if p.type == "locker_bank":
			tall = p
	var c: Vector2 = tall.center
	s.update_sight(c + Vector2(3.0, 0), deg_to_rad(90.0), true, 0.0, true)
	var shown := s.reveal.any(func(r: Rect2) -> bool: return r.is_equal_approx(tall.rect))
	check(shown, "its whole footprint is shown")
	check_eq(s.grid.state_at(c), SightGrid.VISIBLE, "including its far side, on the grid")


func test_scene_memory_and_state_through_the_system() -> void:
	var layout := _layout()
	var s := _spawn_system(layout)
	var at := layout.point_in("junction", [0.5, 0.5])
	var north := at + Vector2(0, -4.0)
	s.update_sight(at, NORTH, true, 0.0, true)
	check_eq(s.grid.state_at(north), SightGrid.VISIBLE, "seen up the corridor")
	s.update_sight(at, PI, true, 0.0, true)
	check_eq(s.grid.state_at(north), SightGrid.REMEMBERED, "looked away: remembered")
	var cargo := layout.point_in("cargo", [0.5, 0.5])
	check_eq(s.grid.state_at(cargo), SightGrid.UNKNOWN, "a room never looked into is unknown")


func test_flashlight_matches_the_sight_cone() -> void:
	var cfg := _cfg()
	var f := Flashlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(f)
	_nodes.append(f)
	f.setup(cfg)
	check_eq(f.spot.spot_range, float(cfg.cone_on.range_m), "light range is the cone's")
	check(f.spot.shadow_enabled, "it casts shadows")
	var half := float(cfg.cone_on.half_angle_deg)
	check(f.spot.spot_angle >= half and f.spot.spot_angle < half + 5.0, "light angle is the cone's, from the muzzle (%.1f)" % f.spot.spot_angle)
	var r := float(cfg.cone_on.range_m)
	var ahead := float(cfg.flashlight.muzzle_ahead_m)
	var lit := (r - ahead) * tan(deg_to_rad(f.spot.spot_angle))
	check(absf(lit - r * tan(deg_to_rad(half))) < 0.01, "lit as wide as the wedge at full range")
	f.set_on(true)
	check(f.spot.visible, "on")
	f.toggle()
	check(not f.on and not f.spot.visible, "toggles off, light gone")
	f.follow(Vector3(1, 1.2, 2), deg_to_rad(90.0))
	var fwd := -f.global_basis.z
	var flat := Vector2(fwd.x, fwd.z).normalized()
	check(flat.distance_to(Visibility.yaw_dir2(deg_to_rad(90.0))) < 0.001, "the light points along the sight yaw")
	check(fwd.y < 0.0, "tipped toward the floor")


## Scene: walk in, doors, targets, keys, memory, all wired.
func test_sight_deck_scene_runs_with_doors_and_targets() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node = (load("res://scenes/sight/sight_deck.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	await tree.physics_frame
	await tree.process_frame
	check(scene.doors.doors.size() >= 4, "doors are placed")
	var d: Node = scene.doors.doors[0]
	check_eq(d.space, "medbay", "first door is the medbay's")
	var c: Vector2 = d.opening.get_center()
	var inside := Vector2(c.x - 3.0, c.y)
	var eye := Vector2(c.x + 2.0, c.y)
	var t := SightTarget.new()
	var e := Node3D.new()
	scene.add_child(e)
	e.add_child(t)
	e.global_position = Vector3(inside.x, 0, inside.y)
	scene.operator.global_position = Vector3(eye.x, 0, eye.y)
	scene.operator.face_now(Vector3(inside.x, 1.2, inside.y))
	await tree.physics_frame
	await tree.process_frame
	check(not t.seen, "shut door hides what's behind it")
	check_eq(scene.sight.grid.state_at(inside), SightGrid.UNKNOWN, "the room behind is unknown")
	scene.doors.interact(eye)
	check(d.door_state.blocks(), "takes time to open")
	for i in 60:
		await tree.physics_frame
		await tree.process_frame
	check(not d.door_state.blocks(), "opened")
	check(t.seen, "open door shows what's behind it")
	check_eq(scene.sight.grid.state_at(inside), SightGrid.VISIBLE, "the room's visible")
	var before: bool = scene.flashlight.on
	scene._unhandled_input(_key(KEY_F))
	check(scene.flashlight.on != before, "F toggles the light")
	scene._unhandled_input(_key(KEY_E))
	check(d.door_state.blocks() or d.door_state.state == d.door_state.State.CLOSING, "E starts closing the door")
	scene._unhandled_input(_key(KEY_F2))
	await tree.process_frame
	check(scene.sight_debug.visible, "F2 shows the debug view")
	check(scene.sight_debug.mesh.get_surface_count() > 0, "debug view drew something")
	scene.respawn()
	check_eq(scene.sight.grid.state_at(inside), SightGrid.UNKNOWN, "respawn forgets")


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func test_gameplay_scripts_have_no_tunable_literals() -> void:
	var rx := RegEx.create_from_string("(?<![\\w.\"#%])(\\d+\\.\\d+|\\d+)(?![\\w\"])")
	# 4 is a rect's corner count, 0.0001 the geometry's snapping: neither is a designer's number.
	var allowed := ["0", "1", "2", "4", "0.0", "1.0", "2.0", "0.5", "0.0001"]
	var strip := RegEx.create_from_string("\"[^\"]*\"")
	for path: String in NUMBER_FREE:
		var n := 0
		for raw in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var line: String = strip.sub(raw.get_slice("#", 0), "\"\"", true)
			for m in rx.search_all(line):
				if not allowed.has(m.get_string(1)):
					check(false, "%s:%d has the literal %s" % [path, n, m.get_string(1)])
