extends "res://tests/test_case.gd"
## T011: A010's decals placed from data, the floor's wear from the layout, the mask over the aim cone and
## faded walls, door state readable from above, and the fairness rules (muzzle flash, hit direction).

const DeckLayout := preload("res://src/study/deck_layout.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")
const DeckLighting := preload("res://src/kit/deck_lighting.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const KitMesh := preload("res://src/kit/kit_mesh.gd")
const FloorWear := preload("res://src/kit/floor_wear.gd")
const DoorSystem := preload("res://src/doors/door_system.gd")
const HitDirection := preload("res://src/hud/hit_direction.gd")
const FlashReveals := preload("res://src/sight/flash_reveals.gd")

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _layout() -> DeckLayout:
	var deck := (Data.load_data("deck") as Dictionary).duplicate(true)
	return DeckLayout.new(deck, float(deck.room_scale))


func _scene(path: String) -> Node:
	var scene: Node = (load(path) as PackedScene).instantiate()
	_nodes.append(scene)
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	return scene


func _signs(root: Node) -> Array:
	return root.find_children("*Sign_*", "MeshInstance3D", true, false)


# --- decals ---

func test_decals_come_from_a010_and_exist() -> void:
	var d: Dictionary = KitMaterials.cfg().decals
	for path: String in (d.sheets as Dictionary).values():
		check(path.contains("A010-graphics"), "%s is an A010 sheet" % path)
		check(FileAccess.file_exists("res://" + path), "and it's there")
	for name_key: String in (d.items as Dictionary).keys():
		check(ResourceLoader.exists(KitMaterials.DECAL_DIR % name_key), "%s was cut" % name_key)
		check((d.sheets as Dictionary).has(String(d.items[name_key].sheet)), "from a named sheet")
	for f: String in DirAccess.get_files_at("res://assets/game/kit/decals"):
		if f.ends_with(".png"):
			check((d.items as Dictionary).has(f.get_basename()), "%s is in the data: no A002 sign left" % f)


func test_the_cut_outs_have_real_alpha() -> void:
	var img: Image = (load(KitMaterials.DECAL_DIR % "floor_keep_clear") as Texture2D).get_image()
	img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var clear := 0
	var solid := 0
	for y in range(0, h, 8):
		for x in range(0, w, 8):
			var a := img.get_pixel(x, y).a
			clear += 1 if a < 0.1 else 0
			solid += 1 if a > 0.9 else 0
	check(clear > 0 and solid > 0, "a stencil has holes and ink (%d, %d)" % [clear, solid])


func test_every_decal_is_placed_from_data() -> void:
	var layout := _layout()
	var s: Dictionary = KitMaterials.cfg().signage
	var root := DeckBuilder.build(layout)
	var want := 0
	for e: Dictionary in (s.walls as Array) + (s.floors as Array):
		if layout.spaces.has(String(e.space)):
			want += 1
	var signs := _signs(root)
	check_eq(signs.size(), want, "one quad per entry in the data, and none dropped")
	for space: String in ["medbay", "cargo", "junction", "side_corridor"]:
		var walls: Array = (s.walls as Array).filter(func(e: Dictionary) -> bool: return e.space == space)
		var floors: Array = (s.floors as Array).filter(func(e: Dictionary) -> bool: return e.space == space)
		check(not walls.is_empty() and not floors.is_empty(), "%s has wall and floor decals" % space)
	# An edit to the data moves the decal.
	var first: Dictionary = (s.walls as Array)[0]
	var found := signs.filter(func(n: Node) -> bool: return n.name.begins_with("Sign_%s" % first.image))
	check(not found.is_empty(), "the first entry is on the deck")
	check(is_equal_approx((found[0] as Node3D).position.y, float(first.y_m)), "at the data's height")
	root.free()


func test_overlays_sit_on_top_and_the_owner_is_faded() -> void:
	var s: Dictionary = KitMaterials.cfg().signage
	var items: Dictionary = KitMaterials.cfg().decals.items
	var layered: Array = (s.walls as Array).filter(func(e: Dictionary) -> bool: return int(e.get("layer", 0)) > 0)
	check(layered.size() >= 3, "fresh Remnant stickers over old graphics")
	for e: Dictionary in layered:
		check(String(e.image).begins_with("rem_"), "%s is Remnant's" % e.image)
	for key: String in items.keys():
		if key.begins_with("owner_"):
			check(float(items[key].get("fade", 0.0)) > 0.3, "%s has faded" % key)
		elif key.begins_with("rem_"):
			check(float(items[key].get("fade", 0.0)) == 0.0, "%s is fresh" % key)


func test_signs_on_faded_walls_follow_the_wall() -> void:
	var root := DeckBuilder.build(_layout())
	for mi: Node in _signs(root):
		if mi.get_parent().name != "FloorSigns":
			check(mi.get_parent().is_in_group(&"camera_cutaway"), "%s fades with its wall" % mi.name)
	root.free()


# --- surfaces ---

func test_a_trim_face_keeps_its_rim_on_the_textures_rim() -> void:
	# Any length: the outer band is its real size on the tile, so chips never stretch or wander inward.
	var tile := 2.2
	var band := 0.32
	for length: float in [0.9, 1.4, 2.0, 2.2, 2.6]:
		check_eq(KitMesh._trim_coord(0.0, length, band, tile, 0.3), 0.0, "the near edge is the tile's edge")
		check(is_equal_approx(KitMesh._trim_coord(length, length, band, tile, 0.3), 1.0), "the far edge is the far edge")
		check(is_equal_approx(KitMesh._trim_coord(band, length, band, tile, 0.3), band / tile), "the band's end is the tile's")
		var mid := KitMesh._trim_coord(length * 0.5, length, band, tile, 0.3)
		check(mid >= band / tile and mid <= 1.0 - band / tile, "the middle stays in the middle (%.2f)" % mid)


func test_painted_materials_are_edge_worn_and_the_floor_has_no_splats() -> void:
	var cfg := KitMaterials.cfg()
	for key: String in ["hull", "steel", "clinical"]:
		check(KitMaterials.edge_band(key) > 0.0, "%s maps its rim to the edge band" % key)
		check(float(cfg.textures[key].cover) > 0.99, "and is nearly clean away from it")
		check(float(cfg.textures[key].edge_bite) > 0.0, "chips bite in from the edge")
	check(not (cfg.textures.deck as Dictionary).has("polish_cover"), "the tile has no polished patches any more")


func test_floor_wear_follows_doors_and_feet() -> void:
	var layout := _layout()
	var cfg: Dictionary = KitMaterials.cfg().floor_wear
	var floors: Dictionary = KitMaterials.cfg().floors
	var img := FloorWear.paint(layout, cfg, floors)
	var r := FloorWear.rect_for(layout, cfg)
	var ppm := float(cfg.px_per_m)
	var room: Rect2 = layout.space_rect("medbay")
	var door: Dictionary = layout.doors[0]
	var door_at: Vector2 = door.rect.get_center()
	var inside := Vector2(room.end.x - 0.2, door_at.y)
	var at_door := FloorWear.sample(img, r, ppm, inside)
	var corner := FloorWear.sample(img, r, ppm, room.position + Vector2(0.3, 0.3))
	check(at_door.x > 0.8, "a door's threshold is worn (%.2f)" % at_door.x)
	check(corner.x < 0.05, "a far corner isn't (%.2f)" % corner.x)
	# Halfway along the route from the door to the room's hub.
	var spec: Dictionary = cfg.spaces.medbay
	var hub: Vector2 = room.position + room.size * Vector2(float(spec.hub[0]), float(spec.hub[1]))
	var on_path := FloorWear.sample(img, r, ppm, inside.lerp(hub, 0.5))
	var off_path := FloorWear.sample(img, r, ppm, Vector2(hub.x, room.position.y + 0.3))
	check(on_path.x > off_path.x + 0.3, "the walked line is worn (%.2f against %.2f)" % [on_path.x, off_path.x])
	var drain: Array = floors.spaces.medbay.drains[0]
	var at_drain := FloorWear.sample(img, r, ppm, room.position + room.size * Vector2(float(drain[0]), float(drain[1])))
	check(at_drain.y > 0.8, "it's damp round the drain (%.2f)" % at_drain.y)
	# An edit to the data changes it.
	var edited: Dictionary = cfg.duplicate(true)
	edited.threshold_strength = 0.0
	edited.path_strength = 0.0
	var flat := FloorWear.paint(layout, edited, floors)
	check_eq(FloorWear.sample(flat, r, ppm, inside).x, 0.0, "strengths come from data")


func test_the_deck_plates_read_the_wear_map() -> void:
	var root := DeckBuilder.build(_layout())
	var floor_mi: MeshInstance3D = root.get_node("Floors").get_child(0)
	var seen := false
	for i in floor_mi.mesh.get_surface_count():
		if floor_mi.mesh.surface_get_name(i) == "deck":
			var m := floor_mi.get_surface_override_material(i) as ShaderMaterial
			check(m != null and m.get_shader_parameter("wear_map") != null, "the plates have the map")
			seen = true
	check(seen, "a room has plates")
	root.free()


func test_sheen_is_one_probe_per_room() -> void:
	var layout := _layout()
	var built := DeckBuilder.build(layout)
	var lighting := DeckLighting.new()
	lighting.add_child(built)
	(Engine.get_main_loop() as SceneTree).root.add_child(lighting)
	_nodes.append(lighting)
	var env := Environment.new()
	lighting.setup(layout, env, built)
	check_eq(String(lighting.cfg.sheen.mode), "probe", "the picked one (handoff has the numbers)")
	check_eq(lighting.probes.size(), layout.space_order.size(), "one a room")
	check(not env.ssr_enabled, "and no SSR on top")
	for p: ReflectionProbe in lighting.probes:
		check_eq(p.update_mode, ReflectionProbe.UPDATE_ONCE, "%s renders once" % p.name)
		check_eq(p.cull_mask & 1, 0, "and doesn't see people, doors or the mask")


func test_a_room_nobody_has_seen_runs_no_lamps() -> void:
	var layout := _layout()
	var built := DeckBuilder.build(layout)
	var lighting := DeckLighting.new()
	lighting.add_child(built)
	(Engine.get_main_loop() as SceneTree).root.add_child(lighting)
	_nodes.append(lighting)
	lighting.setup(layout, Environment.new(), built)
	var wait := float(lighting.cfg.fixtures.cull_rooms_after_s)
	var nowhere := Rect2(-1000.0, -1000.0, 1.0, 1.0)
	lighting.cull_rooms(nowhere, wait * 0.5)
	check(lighting.room_lit("medbay"), "on at first, while the probes take their picture")
	lighting.cull_rooms(nowhere, wait)
	lighting.forget_rooms()
	check(not lighting.room_lit("medbay"), "then out, with no one having seen it")
	check(not lighting.room_lit("cargo"), "every room")
	lighting.cull_rooms(layout.space_rect("medbay").grow(0.1), 0.01)
	check(lighting.room_lit("medbay"), "on as soon as sight can reach it")
	check(not lighting.room_lit("cargo"), "and only that room")
	lighting.cull_rooms(nowhere, 0.01)
	check(lighting.room_lit("medbay"), "and it stays on: you remember it")
	lighting.forget_rooms()
	check(not lighting.room_lit("medbay"), "until a new run")


# --- the mask over what draws after it ---

func test_the_aim_cone_is_masked_but_the_ring_is_not() -> void:
	var scene := _scene("res://scenes/sight/sight_deck.tscn")
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var vis: Node = scene.operator.visuals
	var m := vis.under_sight_material() as ShaderMaterial
	check(m != null and m.shader == vis.AIM_FLOOR, "the cone and arc draw through the mask's lookup")
	check(m.get_shader_parameter("visible_mask") == scene.mask.visible_texture(), "with this deck's mask")
	check(m.shader.code.contains("sight_lookup") , "the same lookup as the mask itself")
	var mesh: ImmediateMesh = vis.mesh
	check(mesh.get_surface_count() >= 2, "ring on its own surface")
	check_eq(mesh.surface_get_material(0), m, "cone first, masked")
	check(mesh.surface_get_material(1) is StandardMaterial3D, "the ring stays plain: you have to be able to aim into the dark")
	var cfg: Dictionary = Data.value("player", "aim_visuals", {})
	check(Color(String(cfg.cone_fill_color)).a < 0.05, "fill toned down")
	check(Color(String(cfg.cone_edge_color)).a < 0.2, "edges toned down")


func test_faded_walls_go_under_the_mask_and_come_back() -> void:
	var scene := _scene("res://scenes/sight/sight_deck.tscn")
	await (Engine.get_main_loop() as SceneTree).process_frame
	scene.rig.set_process(false)
	var fade: Node = scene.mask.fade_mask
	var wall: Node3D = scene.get_node("Deck/Walls").get_children().filter(func(n: Node) -> bool: return n.has_meta("cutaway_rect"))[0]
	var mi: MeshInstance3D = wall.get_child(0)
	var before: Material = mi.get_surface_override_material(0)
	mi.transparency = 0.0
	fade.sync_now()
	check_eq(mi.get_surface_override_material(0), before, "a solid wall keeps its own material")
	mi.transparency = 0.65
	fade.sync_now()
	var m := mi.get_surface_override_material(0) as ShaderMaterial
	check(m != null and m.shader == fade.SHADER, "a faded wall looks the mask up itself")
	check(m.get_shader_parameter("visible_mask") == scene.mask.visible_texture(), "this deck's mask")
	check(m.get_shader_parameter("unknown_brightness") != null, "and its numbers")
	check_eq(float(m.get_shader_parameter("unknown_brightness")), float(scene.sight.cfg.mask.unknown_brightness), "from data")
	var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
	check(m.get_shader_parameter("albedo_tex") == src.albedo_texture, "same paint")
	mi.transparency = 0.0
	fade.sync_now()
	check_eq(mi.get_surface_override_material(0), before, "and the wall gets its material back")


func test_a_faded_sign_is_masked_too() -> void:
	var scene := _scene("res://scenes/sight/sight_deck.tscn")
	await (Engine.get_main_loop() as SceneTree).process_frame
	scene.rig.set_process(false)
	var fade: Node = scene.mask.fade_mask
	var sign_mi: MeshInstance3D = _signs(scene.get_node("Deck/Walls"))[0]
	sign_mi.transparency = 0.5
	fade.sync_now()
	var m := sign_mi.get_surface_override_material(0) as ShaderMaterial
	check(m != null, "a faded sign is under the mask")
	check(m != null and float(m.get_shader_parameter("scissor")) > 0.0, "and stays cut out")
	sign_mi.transparency = 0.0
	fade.sync_now()


# --- doors ---

func test_the_state_light_follows_the_door() -> void:
	var sys := DoorSystem.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sys)
	_nodes.append(sys)
	sys.setup(_layout())
	var colors: Dictionary = sys.cfg.colors
	var seen := {}
	for d: Node3D in sys.doors:
		var strips: Array = d.find_children("*FloorStrip*", "MeshInstance3D", false, false)
		check_eq(strips.size(), 2, "a strip on each side of the threshold")
		for s: MeshInstance3D in strips:
			check(s.global_position.y < 0.05, "on the floor")
			var r: Rect2 = d.opening
			var p := Vector2(s.global_position.x, s.global_position.z)
			check(not r.has_point(p), "outside the wall, where nothing hides it")
			check_eq(s.material_override, d._lamp_mat, "the same light as the lamp")
		d.reset("closed")
		check_eq(d.state_color(), Color(String(colors.lamp_closed)), "closed")
		seen[d.state_color().to_html()] = true
		d.reset("open")
		check_eq(d.state_color(), Color(String(colors.lamp_open)), "open")
		seen[d.state_color().to_html()] = true
		d.reset("locked")
		check_eq(d.state_color(), Color(String(colors.lamp_locked)), "locked")
		seen[d.state_color().to_html()] = true
		check_eq(d._lamp_mat.get_shader_parameter("beacon_color"), Color(String(colors.lamp_locked)), "and the material says so")
		d.reset("closed")
		d.bash(float(d.cfg.bash.break_s) * 0.4, d.opening.get_center() + Vector2(3, 3))
		check_eq(d.state_color(), Color(String(colors.lamp_bashed)), "bashed")
		seen[d.state_color().to_html()] = true
		d.bash(float(d.cfg.bash.break_s), d.opening.get_center() + Vector2(3, 3))
		check_eq(d.state_color(), Color(String(colors.lamp_broken)), "broken")
		seen[d.state_color().to_html()] = true
	check_eq(seen.size(), 5, "five states, five colours")


func test_door_lights_only_show_where_the_player_has_been() -> void:
	var scene := _scene("res://scenes/sight/sight_deck.tscn")
	await (Engine.get_main_loop() as SceneTree).process_frame
	for d: Node3D in scene.doors.doors:
		check(bool(d._lamp_mat.get_shader_parameter("masked")), "%s is under the mask" % d.name)
		check(d._lamp_mat.get_shader_parameter("memory_mask") != null, "with the memory to ask")


# --- fairness ---

func test_a_flash_holds_then_fades_and_refreshes_by_key() -> void:
	var r := FlashReveals.new()
	var shape := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP])
	r.add("a", Vector2.ZERO, 2.0, shape, 0.1, 0.4)
	check(r.covers(Vector2(1.5, 0)), "inside the radius")
	check(not r.covers(Vector2(2.5, 0)), "not outside it")
	check_eq(FlashReveals.strength(r.flashes["a"]), 1.0, "full while it holds")
	r.step(0.3)
	check(FlashReveals.strength(r.flashes["a"]) < 1.0, "then fades")
	r.add("a", Vector2.ZERO, 2.0, shape, 0.1, 0.4)
	check_eq(r.flashes.size(), 1, "a burst is one flash")
	r.step(0.6)
	check(not r.covers(Vector2.ZERO), "and it's gone")
	check_eq(r.flashes.size(), 0, "nothing left")


func test_a_pirate_shot_lights_the_shooter_and_points_at_them() -> void:
	var scene := _scene("res://scenes/pirates/pirate_deck.tscn")
	await (Engine.get_main_loop() as SceneTree).process_frame
	var cfg: Dictionary = Data.value("pirates", "muzzle_reveal", {})
	check(float(cfg.radius_m) > 0.0 and float(cfg.hold_s) > 0.0 and float(cfg.fade_s) > 0.0, "the reveal's numbers are in data")
	scene.flashlight.set_on(false)
	var eye: Vector2 = scene._eye()
	var q: Node3D = scene.squad.pirates[0]
	# Far behind the player: out of sight on any reading.
	var at: Vector2 = eye + Vector2.from_angle(scene.operator.gun_yaw() + PI * 0.5) * 6.0
	q.global_position = Vector3(at.x, 0.0, at.y)
	scene.sight.update_sight(eye, scene.operator.gun_yaw(), false, 0.0, true)
	var st: Node = q.get_node("SightTarget")
	var hidden_before: bool = not st.seen
	var known_before: int = scene.sight.grid.count(scene.sight.grid.VISIBLE) + scene.sight.grid.count(scene.sight.grid.REMEMBERED)
	scene.squad.fired.emit(q)
	check(scene.sight.reveals.flashes.has(q), "the shot makes a flash")
	var flash: Dictionary = scene.sight.reveals.flashes[q]
	check_eq(float(flash.radius), float(cfg.radius_m), "radius from data")
	check_eq(float(flash.hold), float(cfg.hold_s), "hold from data")
	scene.sight.update_sight(eye, scene.operator.gun_yaw(), false, 0.0, true)
	check(st.seen, "the shooter shows (was hidden: %s)" % hidden_before)
	check(q.visible, "model and muzzle flash with it")
	var known_after: int = scene.sight.grid.count(scene.sight.grid.VISIBLE) + scene.sight.grid.count(scene.sight.grid.REMEMBERED)
	check_eq(known_after, known_before, "and nobody learned the room from it")
	scene.sight.update_sight(eye, scene.operator.gun_yaw(), false, float(cfg.hold_s) + float(cfg.fade_s) + 0.01, true)
	check(scene.sight.reveals.flashes.is_empty(), "it passes")
	# The round lands from out of sight: an arc that points at them.
	scene.hud.hits.reset()
	scene._on_round_landed({"damage": 1.0, "shooter": q})
	check_eq(scene.hud.hits.arcs.size(), 1, "a hit from out of sight shows a direction")
	check_eq(scene.hud.hits.arcs[0].from, at, "pointing at where it came from")
	# One you can see doesn't.
	scene.hud.hits.reset()
	scene.flashlight.set_on(true)
	var ahead: Vector2 = eye + scene.sight.visibility.yaw_dir2(scene.operator.gun_yaw())
	q.global_position = Vector3(ahead.x, 0.0, ahead.y)
	scene._on_round_landed({"damage": 1.0, "shooter": q})
	check_eq(scene.hud.hits.arcs.size(), 0, "one you can see needs no arrow")


func test_hit_arcs_come_from_data() -> void:
	var cfg: Dictionary = Data.value("hud", "hit_direction", {})
	var h := HitDirection.new(cfg)
	h.add(Vector2(4, 0), "rifle")
	h.add(Vector2(4.5, 0), "rifle")
	check_eq(h.arcs.size(), 1, "one shooter is one arc")
	h.add(Vector2(-4, 0), "spit")
	check_eq(h.arcs.size(), 2, "another source is another")
	check_eq(h.color_for("spit"), Color(String(cfg.colors.spit)), "acid has its colour")
	check_eq(h.color_for("rifle"), Color(String(cfg.colors.rifle)), "bullets theirs")
	check(h.color_for("spit") != h.color_for("rifle"), "and you can tell them apart")
	check_eq(h.alpha_of(h.arcs[0]), 1.0, "solid at first")
	h.step(float(cfg.life_s) - float(cfg.fade_s) * 0.5)
	check(h.alpha_of(h.arcs[0]) < 1.0, "then fades")
	h.step(float(cfg.fade_s))
	check(h.arcs.is_empty(), "and goes")


func test_the_ambush_panel_has_a_tell_while_sealed() -> void:
	var scene := _scene("res://scenes/enemies/stalker_deck.tscn")
	await (Engine.get_main_loop() as SceneTree).process_frame
	var b: Node3D = scene.bulkhead
	check(b.tell_visible(), "a sealed panel shows its tell")
	check(bool(b._tell_mat.get_shader_parameter("masked")), "only once you've seen that wall")
	var t: Dictionary = Data.value("enemies", "ambush", {}).tell
	check_eq(b._tell_mat.get_shader_parameter("beacon_color"), Color(String(t.color)), "colour from data")
	b.blow()
	check(not b.tell_visible(), "gone once it's blown")
	b.reset()
	check(b.tell_visible(), "back on reset")
