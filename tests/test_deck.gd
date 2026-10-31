extends "res://tests/test_case.gd"
## src/study/deck_layout.gd + deck_builder.gd: sizes come from data/deck.json, the deck is walkable
## from the medbay to cargo at every scale, doorways fit the character, and the scene builds.

const DeckLayout := preload("res://src/study/deck_layout.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")

var deck: Dictionary


func before_each() -> void:
	deck = (Data.load_data("deck") as Dictionary).duplicate(true)


## Overlap with real area (pieces that only touch, give or take float error, don't count).
func _overlaps(a: Rect2, b: Rect2) -> bool:
	var i := a.intersection(b)
	return i.size.x > 0.001 and i.size.y > 0.001


func _max_radius() -> float:
	var biggest := 0.0
	for s in deck.character_scale_options:
		biggest = maxf(biggest, float(s))
	return float(deck.stand_in.radius_m) * biggest


func test_space_sizes_come_from_data() -> void:
	for scale in deck.room_scale_options:
		var lay := DeckLayout.new(deck, float(scale))
		for spec in deck.spaces:
			var want := Vector2(float(spec.size_m[0]), float(spec.size_m[1])) * float(scale)
			var got: Vector2 = lay.space_rect(String(spec.name)).size
			var g := float(deck.grid_m)
			check(absf(got.x - want.x) <= g * 0.5 + 0.001 and absf(got.y - want.y) <= g * 0.5 + 0.001,
					"%s at x%.2f is %s, data says %s (within half a grid)" % [spec.name, scale, got, want])
			check(is_equal_approx(fmod(got.x, g), 0.0) or is_equal_approx(fmod(got.x, g), g), "%s width on the grid" % spec.name)


func test_edited_numbers_change_the_deck() -> void:
	deck.spaces[0].size_m = [4.5, 20.0]
	deck.wall_thickness_m = 0.8
	var lay := DeckLayout.new(deck, 1.0)
	check_eq(lay.space_rect("junction").size, Vector2(4.5, 20.0), "junction follows an edited size")
	var thick := 999.0
	for w in lay.walls:
		thick = minf(thick, minf(w.size.x, w.size.y))
	check(is_equal_approx(thick, 0.8), "walls follow an edited wall_thickness_m (thinnest %.2f)" % thick)
	var lay2 := DeckLayout.new(deck, 1.15)
	check(lay2.space_rect("medbay").size.x > lay.space_rect("medbay").size.x, "room scale grows the medbay")


func test_corridor_widths() -> void:
	var lay := DeckLayout.new(deck, 1.0)
	check_eq(lay.space_rect("junction").size.x, 6.0, "junction corridor 6 m wide at x1.0")
	check_eq(lay.space_rect("side_corridor").size.y, 3.5, "side corridor 3.5 m wide at x1.0")
	check_eq(lay.space_rect("medbay").size, Vector2(14, 10), "medbay 14 x 10 m at x1.0")


func test_walls_have_data_height_and_thickness_and_no_overlaps() -> void:
	var lay := DeckLayout.new(deck, 1.0)
	check(lay.walls.size() > 20, "deck has walls (%d)" % lay.walls.size())
	var t := float(deck.wall_thickness_m)
	for w in lay.walls:
		check(maxf(w.size.x, w.size.y) <= float(deck.wall_segment_m) + 0.001, "wall piece no longer than wall_segment_m")
		check(minf(w.size.x, w.size.y) >= t - 0.001, "wall piece at least wall_thickness_m thick")
		for n in lay.space_order:
			check(not _overlaps(lay.space_rect(n), w), "wall %s stays out of %s" % [w, n])
	for i in lay.walls.size():
		for j in range(i + 1, lay.walls.size()):
			check(not _overlaps(lay.walls[i], lay.walls[j]), "walls %d and %d don't overlap" % [i, j])


func test_doorways_fit_the_character() -> void:
	var margin := 0.3
	var need := _max_radius() * 2.0 + margin
	for scale in deck.room_scale_options:
		var lay := DeckLayout.new(deck, float(scale))
		check_eq(lay.doors.size(), deck.doors.size(), "every door placed")
		for d in lay.doors:
			var clear: float = d.rect.size.x if d.along_x else d.rect.size.y
			check(clear > need, "door in %s %s is %.2f m, needs > %.2f" % [d.space, d.side, clear, need])
			check(is_equal_approx(clear, float(deck.door_width_m)), "door width from data")
			for w in lay.walls:
				check(not _overlaps(w, d.rect), "no wall in the doorway of %s" % d.space)
				for fr in d.frames:
					check(not _overlaps(w, fr), "door frame of %s is its own piece (no z-fight)" % d.space)
			for p in lay.props:
				check(not p.rect.intersects(d.rect.grow(0.5)), "no prop blocks the door of %s" % d.space)


func test_walkable_path_medbay_to_cargo_every_scale() -> void:
	var pc: Dictionary = deck.path_check
	for scale in deck.room_scale_options:
		var lay := DeckLayout.new(deck, float(scale))
		var from: Vector2 = lay.space_rect(String(pc.from)).get_center()
		var to: Vector2 = lay.space_rect(String(pc.to)).get_center()
		var r := _max_radius() + float(pc.margin_m)
		var steps := lay.path_cells(from, to, r, float(pc.cell_m))
		check(steps > 0, "walkable path %s -> %s at room x%.2f (radius %.2f): %d cells" % [pc.from, pc.to, scale, r, steps])


func test_path_check_catches_a_blocked_door() -> void:
	deck.door_width_m = 0.6
	var lay := DeckLayout.new(deck, 1.0)
	var steps := lay.path_cells(lay.space_rect("medbay").get_center(), lay.space_rect("cargo").get_center(),
			_max_radius(), 0.1)
	check_eq(steps, -1, "a 0.6 m door blocks the path (the test can fail)")


func test_spawn_and_props_are_free() -> void:
	for scale in deck.room_scale_options:
		var lay := DeckLayout.new(deck, float(scale))
		var sp := lay.point_in(String(deck.spawn.space), deck.spawn.at)
		check(lay.is_free(sp, _max_radius()), "spawn is free at x%.2f" % scale)
		for p in lay.props:
			check(lay.space_rect(p.space).encloses(p.rect), "%s inside %s at x%.2f" % [p.type, p.space, scale])


func test_props_at_real_size() -> void:
	var lay := DeckLayout.new(deck, 1.15)
	var beds: Array = lay.props.filter(func(p: Dictionary) -> bool: return p.type == "bed")
	check(beds.size() > 0, "deck has a bed")
	for b in beds:
		check(is_equal_approx(b.rect.size.x, 0.9) and is_equal_approx(b.rect.size.y, 2.0), "bed is 0.9 x 2.0 m at any room scale")
	var heights := {}
	for p in lay.props:
		if String(p.type).begins_with("crate"):
			heights[snappedf(p.size.y, 0.01)] = true
	check(heights.has(1.2) and heights.has(0.8), "crates 1.2 and 0.8 m tall: %s" % heights.keys())


func test_builder_makes_cutaway_walls_and_collision() -> void:
	var lay := DeckLayout.new(deck, 1.0)
	var root := DeckBuilder.build(lay)
	var walls := root.get_node("Walls")
	var pivots := walls.get_children().filter(func(n: Node) -> bool: return n.has_meta("cutaway_rect"))
	check_eq(pivots.size(), lay.walls.size(), "one cut-away pivot per wall piece")
	var bodies := root.find_children("*", "StaticBody3D", true, false)
	check(bodies.size() >= lay.walls.size() + lay.props.size(), "walls and props collide (%d bodies)" % bodies.size())
	var mesh := (pivots[0] as Node3D).get_child(0) as MeshInstance3D
	check(absf(mesh.mesh.get_aabb().size.y - float(deck.wall_height_m)) < 0.01, "wall height from data")
	root.free()


func test_study_scene_builds_and_switches() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node3D = load("res://scenes/study/scale_deck.tscn").instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	check(scene.get_node_or_null("Deck") != null, "deck built")
	check(scene.stand_in != null and scene.rig.camera.current, "stand-in and current camera")
	var shots: Array = scene.capture_shots()
	check(shots.size() >= deck.room_scale_options.size() + 5, "shots for every preset and room scale")
	scene.apply_shot({"preset": 3, "room": 0.85, "char": 1.15})
	await tree.process_frame
	check_eq(scene.rig.camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "preset 4 is orthographic")
	check(is_equal_approx(scene.room_scale, 0.85), "room scale switched")
	check(is_equal_approx(scene.stand_in.radius(), float(deck.stand_in.radius_m) * 1.15), "character scale switched")
	check_eq(tree.get_nodes_in_group(&"camera_cutaway").size(), scene.layout.walls.size() + scene.layout.doors.size() * 2,
			"old deck's walls left the tree")
	scene.release_shot()
	scene.queue_free()
	await tree.process_frame


func test_stand_in_collides_with_walls() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node3D = load("res://scenes/study/scale_deck.tscn").instantiate()
	tree.root.add_child(scene)
	await tree.physics_frame
	await tree.physics_frame
	var body: CharacterBody3D = scene.stand_in
	body.input_enabled = false
	# Stand in the junction level with solid medbay wall (not the door) and push west into it.
	var j: Rect2 = scene.layout.space_rect("junction")
	body.global_position = Vector3(j.position.x + 1.5, 0, j.position.y + 4.0)
	await tree.physics_frame
	var hit := body.move_and_collide(Vector3(-5, 0, 0))
	check(hit != null, "stand-in hits the junction's west wall")
	check(body.global_position.x > j.position.x - 0.01, "stand-in stops at the wall (x %.2f, wall face %.2f)" % [body.global_position.x, j.position.x])
	scene.queue_free()
	await tree.process_frame


func test_johns_stage_1_picks_are_the_defaults() -> void:
	var d: Dictionary = Data.load_data("deck")
	check_eq(float(d.room_scale), 0.85, "rooms x0.85")
	check_eq(float(d.character_scale), 1.15, "character x1.15")
	var c: Dictionary = (Data.load_data("camera") as Dictionary).cutaway
	check_eq(String(c.mode), "fade", "fade cut-away")
	check_eq(float(c.fade_transparency), 0.65, "less see-through")
	var has_slider := (Data.value("debug", "tuning", []) as Array).any(func(e: Dictionary) -> bool:
		return String(e.get("path", "")) == "cutaway.fade_transparency")
	check(has_slider, "see-through has an F1 slider")


func test_everything_fits_at_the_default_scale() -> void:
	var d: Dictionary = Data.load_data("deck")
	var lay := DeckLayout.new(d, float(d.room_scale))
	var body := float(Data.value("player", "radius_m")) * float(d.character_scale)
	for i in lay.props.size():
		var a: Dictionary = lay.props[i]
		var r: Rect2 = a.rect
		check((lay.spaces[String(a.space)].rect as Rect2).encloses(r), "%s %d inside its space" % [a.type, i])
		for k in range(i + 1, lay.props.size()):
			check(not r.intersects(lay.props[k].rect), "%s %d overlaps %s %d" % [a.type, i, lay.props[k].type, k])
		for door: Dictionary in lay.doors:
			check(not r.intersects(door.rect), "%s %d is in a doorway" % [a.type, i])
	var spawn: Dictionary = d.spawn
	check(lay.is_free(lay.point_in(String(spawn.space), spawn.at), body), "the spawn is clear of a scaled body")
	for door: Dictionary in lay.doors:
		var c: Vector2 = (door.rect as Rect2).get_center()
		check((door.rect as Rect2).size[int(door.along_x) ^ 1] >= body * 2.0, "a scaled body fits through a door")
		check(lay.is_free(c, body), "the doorway at %s is clear of a scaled body" % c)
