extends "res://tests/test_case.gd"
## T020: every recipe and texture, the pools and caps, surfaces to impacts, the shot's layers of sound on the real
## rifle, and the deck's effects.

const ParticleField := preload("res://src/vfx/particle_field.gd")
const DecalRing := preload("res://src/vfx/decal_ring.gd")
const BrassField := preload("res://src/vfx/brass_field.gd")
const SurfaceMap := preload("res://src/vfx/surface_map.gd")
const SoundRules := preload("res://src/audio/sound_rules.gd")
const RifleFx := preload("res://src/weapons/rifle_fx.gd")
const ShotTimeline := preload("res://src/weapons/shot_timeline.gd")
const DT := 1.0 / 60.0

var _nodes: Array[Node] = []
var _heard: Array[String] = []


func before_each() -> void:
	Audio.set_process(false)
	Vfx.set_process(false)
	Audio.reset()
	Vfx.clear()
	_heard.clear()
	Audio.played.connect(_on_played)


func after_each() -> void:
	Audio.played.disconnect(_on_played)
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Vfx.clear()
	Audio.reset()
	Audio.set_process(true)
	Vfx.set_process(true)


func _on_played(cue: String, _at: Vector3, _pitch: float) -> void:
	_heard.append(cue)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _scene(path := "res://scenes/shift/shift_deck.tscn") -> Node:
	var scene: Node = (load(path) as PackedScene).instantiate()
	_tree().root.add_child(scene)
	_nodes.append(scene)
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	if "run_log" in scene:
		scene.run_log.enabled = false
	await _tree().process_frame
	return scene


func _sim(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await _tree().physics_frame
		Audio.advance(DT)
		Vfx.advance(DT)
		left -= DT


## A wall of a material, in the world, to shoot.
func _wall(material: String, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("kit_material", material)
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 4.0, 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	_tree().root.add_child(body)
	body.global_position = at
	_nodes.append(body)
	return body


# --- recipes and textures ---

func test_every_recipe_loads_and_every_texture_exists() -> void:
	check_eq(Array(Vfx.problems()), [], "the book is clean")
	var cfg: Dictionary = Data.load_data("vfx")
	check(cfg.recipes.size() > 0, "a book")
	for name: String in Vfx.manifest:
		check(ResourceLoader.exists(Vfx.texture_path(name)), "%s is in assets/game/vfx" % name)
		check(load(Vfx.texture_path(name)) is Texture2D, "%s loads" % name)
	for name: String in ["muzzle_smoke", "muzzle_haze", "barrel_wisps", "impact_metal", "impact_panel", "impact_glass", "impact_stalker", "impact_pirate",
			"impact_chew", "sparking_console", "smoke_plume", "steam_jet", "fire", "acid_pool", "explosion", "dust_motes"]:
		check(cfg.recipes.has(name), "the spec's %s has a recipe" % name)


func test_every_recipe_plays_without_complaint() -> void:
	for name: String in Data.value("vfx", "recipes"):
		check(Vfx.play(name, Vector3(0.0, 1.0, 0.0), Vector3.BACK), "%s plays" % name)
	Vfx.advance(DT)
	check(Vfx.live_particles() > 0, "something's alive")


func test_budgets_are_in_data_and_the_sheets_fit_inside_them() -> void:
	var b: Dictionary = Data.value("vfx", "budgets")
	for key: String in ["max_particles", "max_decals", "max_casings"]:
		check(b.has(key), "budget %s" % key)
	check(Vfx.capacity() <= int(b.max_particles), "the sheets' rings add up to no more than max_particles (%d)" % Vfx.capacity())
	check_eq(Vfx.casings.cap, int(b.max_casings), "casing cap")
	check_eq(Vfx.decal_ring.cap, int(b.max_decals), "decal cap")


func test_each_sheet_blends_as_the_manifest_says() -> void:
	var cfg: Dictionary = Data.load_data("vfx")
	for sheet: String in cfg.sheets:
		var c: Dictionary = cfg.sheets[sheet]
		var blend := String(Vfx.manifest[String(c.get("texture", sheet))].blend)
		var additive := String(c.look) == "add"
		if not c.has("texture"):
			check_eq(additive, blend == "add", "%s: %s" % [sheet, blend])
		var code := (Vfx._materials[sheet] as ShaderMaterial).shader.code
		check_eq(code.contains("blend_add"), additive, "%s's shader" % sheet)


# --- pools and caps ---

## The whole shot, round after round: no new object, no new node, however long it goes on.
func _hammer(rounds: int, fx: Node) -> void:
	var dir := Vector3.FORWARD
	for i in rounds:
		var muzzle := Vector3(0.0, 1.2, 0.0)
		fx.shot(muzzle, muzzle + dir * 4.0)
		Vfx.play("muzzle_smoke", muzzle, dir)
		Vfx.play("muzzle_haze", muzzle)
		Vfx.eject_casing(muzzle, dir)
		Vfx.play("impact_metal", muzzle + dir * 4.0, Vector3.BACK, {"dir": dir})
		Vfx.play("impact_stalker", muzzle + dir * 3.0, Vector3.BACK, {"dir": dir})
		if i % 30 == 0:
			Vfx.drop_magazine(muzzle, dir)
		Vfx.advance(0.11)


func test_pools_never_allocate_after_warm_up() -> void:
	var fx: RifleFx = RifleFx.new()
	_tree().root.add_child(fx)
	_nodes.append(fx)
	await _tree().process_frame
	_hammer(5, fx)
	var pools: Dictionary = Vfx.pool_counts()
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var buffers := {}
	for sheet: String in Vfx.fields:
		buffers[sheet] = Vfx.fields[sheet].buffer.size()
	_hammer(500, fx)
	check_eq(Vfx.pool_counts(), pools, "the pools hold what they held")
	check_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no new nodes after 500 shots")
	check_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects, "no new objects after 500 shots")
	for sheet: String in Vfx.fields:
		check_eq(Vfx.fields[sheet].buffer.size(), buffers[sheet], "%s's ring stayed its size" % sheet)


func test_caps_hold_after_500_shots() -> void:
	var fx: RifleFx = RifleFx.new()
	_tree().root.add_child(fx)
	_nodes.append(fx)
	await _tree().process_frame
	_hammer(500, fx)
	var b: Dictionary = Data.value("vfx", "budgets")
	check(Vfx.live_particles() <= int(b.max_particles), "particles %d" % Vfx.live_particles())
	check(Vfx.visible_decals() <= int(b.max_decals), "decals %d" % Vfx.visible_decals())
	check(Vfx.decal_ring.in_use() <= int(b.max_decals), "decal slots %d" % Vfx.decal_ring.in_use())
	check_eq(Vfx.casings.count, int(b.max_casings), "casings stop at the cap")
	check(Vfx.magazines.count <= int(b.max_magazines), "magazines %d" % Vfx.magazines.count)
	check(Vfx.visible_decals() >= int(b.max_decals) / 2, "and the holes are there (%d)" % Vfx.visible_decals())


func test_decals_fade_oldest_first_and_the_cap_never_moves() -> void:
	var ring := DecalRing.new(8, 3, 0.5)
	var first := ring.place()
	for i in 4:
		ring.place()
	check(not ring.fading(first), "well under the cap, nothing fades")
	ring.place()
	check(ring.fading(first), "near the cap, the oldest fades first")
	ring.step(0.25)
	check(ring.strength(first) < 1.0 and ring.strength(first) > 0.0, "and it fades, not pops")
	for i in 100:
		ring.place()
		check(ring.in_use() <= 8, "the cap holds")
	var done := ring.step(1.0)
	check(not done.is_empty(), "faded ones come free")
	check(ring.in_use() <= 8, "still")


func test_casings_fall_bounce_settle_and_never_pass_through_the_floor() -> void:
	var c: Dictionary = (Data.value("vfx", "casing") as Dictionary)
	var f := BrassField.new(c, 4)
	var rng := RandomNumberGenerator.new()
	f.throw(Vector3(0.0, 1.2, 0.0), Vector3(2.0, 2.0, 0.0), 0.0, Vector3.ZERO, Vector3.ZERO, rng)
	var bounces := 0
	var rest := float(c.rest_y_m)
	for i in 600:
		f.step(DT)
		bounces += f.bounced.size()
		check(f.slots[0].pos.y >= rest - 0.0001, "above the floor at step %d" % i)
	check(not f.slots[0].moving, "it settled")
	check(is_equal_approx(f.slots[0].pos.y, rest), "on the floor")
	check(bounces >= int(c.bounces[0]) and bounces <= int(c.bounces[1]) + 1, "bounced once or twice and landed (%d)" % bounces)


func test_a_casing_bounces_off_the_wall_it_was_thrown_at() -> void:
	var f := BrassField.new(Data.value("vfx", "casing"), 2)
	f.throw(Vector3(0.0, 1.2, 0.0), Vector3(2.0, 1.0, 0.0), 0.0, Vector3(0.3, 1.2, 0.0), Vector3.LEFT, RandomNumberGenerator.new())
	for i in 200:
		f.step(DT)
		check(f.slots[0].pos.x <= 0.3001, "it stays this side of the wall")


func test_particles_bounce_once_and_stay_above_the_floor() -> void:
	var f := ParticleField.new(4, 0.02)
	f.spawn(0.0, Vector3(0.0, 1.0, 0.0), Vector3(3.0, 1.0, 0.0), 2.0, 0.1, 0.1, 9.8, 0.0, Color.WHITE, 0.0, 1.0, 0.0, 0.4)
	var low := INF
	var came_back := false
	var was := 1.0
	for i in 120:
		var y := f.position_at(0, float(i) * 0.016).y
		low = minf(low, y)
		came_back = came_back or y > was
		was = y
	check(low >= 0.0199, "above the floor (%f)" % low)
	check(came_back, "it bounced")


func test_a_ring_overwrites_its_oldest() -> void:
	var f := ParticleField.new(3)
	for i in 10:
		f.spawn(float(i), Vector3.ZERO, Vector3.ZERO, 100.0, 1.0, 1.0, 0.0, 0.0, Color.WHITE, 0.0, 1.0, 0.0, -1.0)
	check_eq(f.alive_count(10.0), 3, "no more than the ring holds")
	check_eq(f.spawned, 10, "ten were born")
	check_eq(f.buffer.size(), 3 * ParticleField.STRIDE, "and it never grew")


func test_a_sheet_with_nothing_alive_does_not_draw() -> void:
	Vfx.play("impact_glass", Vector3.UP, Vector3.BACK)
	Vfx.advance(DT)
	check(Vfx._meshes.fleck.visible, "flecks draw")
	Vfx.advance(5.0)
	check(not Vfx._meshes.fleck.visible, "and then they stop")


# --- surfaces ---

func test_every_kit_material_maps_to_the_right_impact() -> void:
	var map: SurfaceMap = Vfx.surfaces
	var by_mat: Dictionary = Data.value("vfx", "surfaces").by_material
	for material: String in Data.value("kit", "materials"):
		check(by_mat.has(material), "%s has a surface" % material)
		check(["metal", "panel", "glass"].has(map.surface_of_material(material)), "%s is a real surface" % material)
	check_eq(map.recipe_for(map.surface_of_material("steel")), "impact_metal", "steel")
	check_eq(map.recipe_for(map.surface_of_material("hull")), "impact_metal", "hull")
	check_eq(map.recipe_for(map.surface_of_material("clinical")), "impact_panel", "clinical")
	check_eq(map.recipe_for(map.surface_of_material("glass")), "impact_glass", "glass")
	var names: Array = (Data.value("vfx", "recipes").impact_metal.layers as Array).map(func(l: Dictionary) -> String: return l.sheet)
	check(names.has("spark_streak"), "metal throws sparks")
	for r: String in ["impact_stalker", "impact_pirate", "impact_panel", "impact_glass"]:
		var sheets: Array = (Data.value("vfx", "recipes")[r].layers as Array).map(func(l: Dictionary) -> String: return l.sheet)
		check(not sheets.has("spark_streak"), "no sparks in %s" % r)
	check(not Data.value("vfx", "recipes").impact_metal.has("splat"), "no blood on steel")


func test_a_wall_answers_with_its_rooms_family_and_a_body_with_its_type() -> void:
	var scene: Node = await _scene()
	var map: SurfaceMap = Vfx.surfaces
	var world := scene.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var h := float(Data.value("player", "aim_height_m"))
	var cases := {"medbay": "panel", "junction": "metal"}
	for space: String in cases:
		var r: Rect2 = scene.layout.space_rect(space)
		var seen := {}
		for i in range(1, 20):
			var x := r.position.x + r.size.x * float(i) / 20.0
			var hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, h, r.position.y + 2.0), Vector3(x, h, r.position.y - 1.0)))
			if not hit.is_empty() and absf(float(hit.position.z) - r.position.y) < 0.5:
				seen[map.surface_of(hit.collider, hit.position, hit.normal)] = true
		check(seen.has(cases[space]), "%s's north wall has %s: %s" % [space, cases[space], str(seen.keys())])
	check_eq(map.surface_of(scene.pack.stalkers[0], Vector3.ZERO, Vector3.UP), "metal", "before it says otherwise, a body is the default")


func test_a_round_on_a_wall_plays_that_walls_impact_and_a_hole() -> void:
	var scene: Node = await _scene()
	var seen: Array[String] = []
	var on_played := func(r: String, _at: Vector3) -> void: seen.append(r)
	Vfx.played.connect(on_played)
	for material: String in ["steel", "clinical", "glass"]:
		seen.clear()
		var before := Vfx.decal_ring.in_use()
		var body := _wall(material, Vector3(0.0, 2.0, -50.0))
		await _tree().physics_frame
		Vfx.land(body, Vector3(0.0, 1.2, -49.85), Vector3.BACK, Vector3.FORWARD, 18.0)
		var want: String = Vfx.surfaces.recipe_for(Vfx.surfaces.surface_of_material(material))
		check(seen.has(want), "%s plays %s: %s" % [material, want, str(seen)])
		check_eq(Vfx.decal_ring.in_use(), before + 1, "%s gets a hole" % material)
	Vfx.played.disconnect(on_played)
	check(scene != null, "deck")


func test_chewed_cover_adds_more_the_more_damage() -> void:
	var f: Dictionary = Vfx.fields
	var sparks: ParticleField = f.spark_streak
	var before := sparks.spawned
	Vfx.play("impact_chew", Vector3.UP, Vector3.BACK, {"scale": 1.0})
	var one := sparks.spawned - before
	before = sparks.spawned
	Vfx.play("impact_chew", Vector3.UP, Vector3.BACK, {"scale": 4.0})
	check(sparks.spawned - before > one, "heavier rounds throw more (%d, then %d)" % [one, sparks.spawned - before])
	check(Vfx.surfaces.recipe_for("chew") == "impact_chew", "the map knows it")


func test_a_stalker_hit_sprays_and_splats_the_wall_behind_it() -> void:
	var scene: Node = await _scene()
	var s: Node = scene.pack.stalkers[0]
	var at := Vector3(0.0, 1.0, -60.0)
	var body := _wall("hull", at + Vector3(0.0, 1.0, -1.0))
	await _tree().physics_frame
	await _tree().physics_frame
	var placed: Array = []
	var on_decal := func(sheet: String, _f: int, p: Vector3, n: Vector3) -> void: placed.append([sheet, p, n])
	Vfx.decal_placed.connect(on_decal)
	s.brain.state = s.brain.State.PROWL
	s.take_hit({"point": at, "direction": Vector3.FORWARD, "damage": 1.0, "origin": at + Vector3.BACK})
	Vfx.decal_placed.disconnect(on_decal)
	check_eq(placed.size(), 1, "one splat")
	if not placed.is_empty():
		check_eq(placed[0][0], "decal_splats", "ichor")
		check(absf(float(placed[0][1].z) - (body.global_position.z + 0.15)) < 0.05, "on the wall behind it: %s" % str(placed[0][1]))
	check(_heard.any(func(c: String) -> bool: return c.begins_with("impact_wet")), "a wet hit")
	check(_heard.has("stalker_hit"), "the pain chirp")


func test_a_pirate_splat_goes_on_the_floor() -> void:
	var placed: Array = []
	var on_decal := func(_s: String, _f: int, p: Vector3, n: Vector3) -> void: placed.append([p, n])
	Vfx.decal_placed.connect(on_decal)
	Vfx.body_hit("pirate", {"point": Vector3(0.0, 1.0, -70.0), "direction": Vector3.FORWARD})
	Vfx.decal_placed.disconnect(on_decal)
	check_eq(placed.size(), 1, "one splat")
	check_eq(placed[0][1], Vector3.UP, "facing up")
	check_eq(placed[0][0].y, 0.0, "on the floor")


# --- the sound of one shot ---

func test_round_robin_never_repeats_a_body_variant() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	var group: Array = Data.value("audio", "groups").rifle_body.cues
	check(group.size() >= 4 and group.size() <= 6, "4-6 variants (%d)" % group.size())
	var robin := SoundRules.RoundRobin.new(group.size())
	var last := -1
	var seen := {}
	for i in 1000:
		var n := robin.next(rng)
		check(n != last, "never twice in a row (shot %d)" % i)
		last = n
		seen[n] = true
	check_eq(seen.size(), group.size(), "and every one gets used")


func test_the_rifle_fires_its_layers_and_no_body_twice_running() -> void:
	var scene: Node = await _scene()
	var op: Node = scene.operator
	var rifle: Node = op.rifle
	op.scripted = {"fire": true}
	await _sim(1.5)
	op.scripted = {}
	var bodies := _heard.filter(func(c: String) -> bool: return c.begins_with("rifle_body_"))
	check(bodies.size() >= 8, "a burst (%d)" % bodies.size())
	for i in range(1, bodies.size()):
		check(bodies[i] != bodies[i - 1], "round %d isn't the one before" % i)
	check_eq(_heard.count("rifle_mech"), bodies.size(), "the action on every round")
	check_eq(_heard.count("rifle_thump"), bodies.size(), "the local player's thump on every round")
	check(_heard.has(Audio.room_tail("junction")) or _heard.has(Audio.room_tail(String(op.space_at.call(Vector2(op.global_position.x, op.global_position.z))))), "the room answers")
	check(Audio.gun_voices(rifle.timeline.gun_id) <= int(Audio.cfg.gun.voices_per_gun), "voices per gun capped")


func test_last_rounds_layer_only_on_rounds_26_to_30() -> void:
	var gun: Dictionary = Data.value("audio", "gun")
	check_eq(int(gun.last_rounds), 5, "the last five")
	var magazine := int(Data.value("weapons", "rifle").magazine)
	check_eq(magazine, 30, "a 30-round magazine")
	for fired in range(1, magazine + 1):
		var layers: Array = SoundRules.shot_layers(gun, magazine - fired, true)
		check_eq(layers.has(gun.last_rounds_cue), fired >= 26, "round %d" % fired)


func test_last_rounds_layer_on_the_real_magazine() -> void:
	var scene: Node = await _scene()
	var op: Node = scene.operator
	var rifle: Node = op.rifle
	var bright_on: Array = []
	var mag_check := func(cue: String, _at: Vector3, _p: float) -> void:
		if cue == "rifle_mech_bright":
			bright_on.append(30 - rifle.state.mag)
	Audio.played.connect(mag_check)
	rifle.state.mag = 30
	op.scripted = {"fire": true}
	var guard := 0
	while rifle.state.mag > 0 and guard < 600:
		await _tree().physics_frame
		Audio.advance(DT)
		guard += 1
	op.scripted = {}
	Audio.played.disconnect(mag_check)
	check_eq(bright_on, [26, 27, 28, 29, 30], "rounds 26 to 30, and only them")


func test_only_your_own_gun_has_the_thump_and_the_last_rounds() -> void:
	var gun: Dictionary = Data.value("audio", "gun")
	var theirs: Array = SoundRules.shot_layers(gun, 0, false)
	check(theirs.has(gun.mechanical) and theirs.has(gun.body), "they still fire")
	check(not theirs.has(gun.thump), "no thump")
	check(not theirs.has(gun.last_rounds_cue), "no warning for someone else's magazine")


func test_tails_follow_the_room() -> void:
	var tails: Dictionary = Data.value("audio", "room_tail")
	check_eq(tails.junction, "tail_slap", "a corridor slaps")
	check_eq(tails.medbay, "tail_room", "a medbay is a room")
	check_eq(tails.cargo, "tail_hold", "a hold booms")
	var cues: Dictionary = Data.value("audio", "cues")
	var a: AudioStream = load(String(cues.tail_slap.file))
	var b: AudioStream = load(String(cues.tail_hold.file))
	check(b.get_length() > a.get_length() * 2.0, "the hold's is much longer")
	for space: String in tails:
		check(cues.has(tails[space]), "%s's tail is in the bank" % space)


func test_range_and_walls_filter_other_guns() -> void:
	var mix: Dictionary = Data.value("audio", "distance_mix")
	check_eq(SoundRules.distance_mix(mix, 2.0, false).bus, "SFX", "close is dry")
	var far: Dictionary = SoundRules.distance_mix(mix, 12.0, false)
	check_eq(far.bus, "SFX_Far", "further, duller")
	var distant: Dictionary = SoundRules.distance_mix(mix, 30.0, false)
	check_eq(distant.bus, "SFX_Distant", "further still")
	check(float(distant.tail_db) > float(far.tail_db), "with more of the room")
	check_eq(SoundRules.distance_mix(mix, 2.0, true).bus, "SFX_Muffled", "through a wall, muffled even close")
	var buses: Dictionary = Data.value("audio", "buses")
	check(float(buses.SFX_Muffled.lowpass_hz) < float(buses.SFX_Distant.lowpass_hz), "a wall is duller than range")
	check(float(buses.SFX_Distant.lowpass_hz) < float(buses.SFX_Far.lowpass_hz), "range goes by steps")
	for bus: String in ["SFX_Far", "SFX_Distant", "SFX_Muffled"]:
		check(AudioServer.get_bus_index(bus) >= 0, "%s exists" % bus)
		check_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)), &"SFX", "%s follows the SFX slider" % bus)


func test_a_gun_can_hold_only_its_voices() -> void:
	var cap := int(Audio.cfg.gun.voices_per_gun)
	for i in cap * 4:
		Audio.play("rifle_body", Vector3.ZERO, {"gun": 99})
	check(Audio.gun_voices(99) <= cap, "held to %d (%d)" % [cap, Audio.gun_voices(99)])


func test_heavy_fire_ducks_the_ambience_and_it_recovers() -> void:
	var cfg: Dictionary = Data.value("audio", "ambience_duck")
	check_eq(float(cfg.db), -3.0, "3 dB")
	check_eq(Audio.ambience_duck_db(), 0.0, "quiet")
	for i in int(cfg.heavy_shots):
		Audio.note_gunfire(Vector3.ZERO)
	check_eq(Audio.ambience_duck_db(), -3.0, "heavy fire")
	var t := 0.0
	# The heat goes first, then the level comes back at its own rate.
	while Audio.ambience_duck_db() < 0.0 and t < 5.0:
		Audio.advance(DT)
		t += DT
	check(t > float(cfg.recover_s) * 0.9, "it takes its time (%.2f s)" % t)
	check(t < float(cfg.recover_s) + float(cfg.heavy_shots) / float(cfg.heat_decay_per_s) + 0.1, "and it comes back (%.2f s)" % t)


func test_one_shot_alone_does_not_duck() -> void:
	Audio.note_gunfire(Vector3.ZERO)
	check_eq(Audio.ambience_duck_db(), 0.0, "one shot isn't heavy fire")


func test_dry_fire_is_a_click_and_a_nothing() -> void:
	var t := ShotTimeline.new()
	t.dry(Vector3.ZERO)
	check(_heard.has("rifle_dry"), "the click")
	check(_heard.has("rifle_dry_tail"), "the nothing")


func test_a_full_reload_has_no_charge_but_an_empty_one_does() -> void:
	var scene: Node = await _scene()
	var op: Node = scene.operator
	op.rifle.state.mag = 10
	await _tree().physics_frame
	check(op.request_reload(), "from a part magazine")
	var mags := Vfx.magazines.count
	check(mags > 0, "the old one falls")
	await _sim(float(op.rifle.state.reload_total) + 0.1)
	check(_heard.has("rifle_mag_in"), "mag in")
	check(not _heard.has("rifle_charge"), "no charge")
	_heard.clear()
	op.rifle.state.mag = 0
	check(op.request_reload(), "from empty")
	await _sim(float(op.rifle.state.reload_total) + 0.1)
	check(_heard.has("rifle_charge"), "the charging handle")
	check_eq(Vfx.magazines.count, mags + 1, "and another magazine on the floor")


func test_casing_tinks_go_by_surface_and_never_repeat() -> void:
	var scene: Node = await _scene()
	var at: Vector2 = scene.layout.point_in("junction", [0.5, 0.5])
	check_eq(Vfx.surfaces.ground_at(Vector3(at.x, 0.0, at.y), Data.value("audio", "footsteps")), "grate", "the junction is grate")
	for i in 5:
		Vfx.eject_casing(Vector3(at.x, 1.2, at.y), Vector3.FORWARD)
	Audio.advance(1.0)
	_heard.clear()
	for i in 30:
		Vfx.eject_casing(Vector3(at.x, 1.2, at.y), Vector3.FORWARD)
		for k in 7:
			Vfx.advance(DT)
			Audio.advance(DT)
	var tinks := _heard.filter(func(c: String) -> bool: return c.begins_with("tink_"))
	check(tinks.size() > 5, "they land (%d)" % tinks.size())
	for t: String in tinks:
		check(t.begins_with("tink_grate"), "on grate: %s" % t)
	for i in range(1, tinks.size()):
		check(tinks[i] != tinks[i - 1], "no sample twice running")


# --- the flash ---

func test_the_flash_is_on_screen_two_frames_at_most() -> void:
	var fx: RifleFx = RifleFx.new()
	_tree().root.add_child(fx)
	_nodes.append(fx)
	await _tree().process_frame
	fx.shot(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -5.0))
	check(fx._flash.visible and fx._star.visible, "cone and star")
	var frames := 0
	for i in 10:
		if fx._flash.visible:
			frames += 1
		fx._process(DT)
	check(frames <= int(Data.value("weapons", "fx").flash_frames), "%d frames" % frames)
	check(frames >= 1, "and it's seen at all")


func test_the_flash_varies_shot_to_shot() -> void:
	var fx: RifleFx = RifleFx.new()
	_tree().root.add_child(fx)
	_nodes.append(fx)
	await _tree().process_frame
	var offsets := {}
	var sizes := {}
	for i in 30:
		fx.shot(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -5.0))
		offsets[fx._flash_mat.uv1_offset] = true
		sizes[snappedf(fx._star.global_basis.get_scale().x, 0.01)] = true
	check(offsets.size() >= 2, "different frames (%d)" % offsets.size())
	check(sizes.size() >= 3, "different sizes (%d)" % sizes.size())


func test_the_arm_kicks_on_a_round_and_falls_back() -> void:
	var scene: Node = await _scene()
	var state: RefCounted = scene.operator.rifle.state
	check_eq(state.arm_kick, 0.0, "at rest")
	state.try_fire(false)
	check_eq(state.arm_kick, 1.0, "a round")
	state.step(float(state.cfg.arm_kick.recover_s) * 0.5, false)
	check(state.arm_kick > 0.0 and state.arm_kick < 1.0, "on its way back")
	state.step(float(state.cfg.arm_kick.recover_s), false)
	check_eq(state.arm_kick, 0.0, "back")


# --- haze and wisps ---

func test_wisps_only_after_a_long_burst() -> void:
	var seen: Array[String] = []
	var on_played := func(r: String, _a: Vector3) -> void: seen.append(r)
	Vfx.played.connect(on_played)
	var s: Dictionary = Data.value("vfx", "shot")
	var t := ShotTimeline.new()
	for i in int(s.wisps_after_rounds) - 1:
		t.shot(Vector3.ZERO, Vector3.FORWARD, 20, "", false)
		t.step(0.11, Vector3.ZERO, Vector3.FORWARD)
	t.step(float(s.burst_gap_s) + 0.1, Vector3.ZERO, Vector3.FORWARD)
	check(not seen.has(String(s.wisps)), "a short burst doesn't smoke the barrel")
	check_eq(t.burst, 0, "the burst ended")
	for i in int(s.wisps_after_rounds):
		t.shot(Vector3.ZERO, Vector3.FORWARD, 20, "", false)
		t.step(0.11, Vector3.ZERO, Vector3.FORWARD)
	t.step(float(s.burst_gap_s) + 0.1, Vector3.ZERO, Vector3.FORWARD)
	check(seen.has(String(s.wisps)), "a long one does")
	Vfx.played.disconnect(on_played)


func test_wisps_run_their_time_and_end() -> void:
	var r: Dictionary = Data.value("vfx", "recipes").barrel_wisps
	check_eq(float(r.life_s), 1.5, "1.5 s")
	var id := Vfx.start("barrel_wisps", Vector3.ZERO)
	check(Vfx.running(id), "going")
	Vfx.advance(float(r.life_s) + 0.1)
	check(not Vfx.running(id), "gone")


# --- environment effects ---

func test_each_deck_places_a_console_a_plume_a_jet_and_motes() -> void:
	for deck: Dictionary in [Data.load_data("deck"), Data.value("pirates", "deck")]:
		var names: Array = (deck.effects as Array).map(func(e: Dictionary) -> String: return e.recipe)
		for want: String in ["sparking_console", "smoke_plume", "steam_jet", "dust_motes"]:
			check(names.has(want), "%s is placed" % want)
		for not_yet: String in ["fire", "acid_pool", "explosion"]:
			check(not names.has(not_yet), "%s stays in the gallery" % not_yet)


func test_the_shift_deck_runs_its_effects_and_stops_them_with_it() -> void:
	var scene: Node = await _scene()
	var want: int = (Data.load_data("deck").effects as Array).size()
	check_eq(Vfx.running_count(), want, "one emitter per entry")
	_nodes.erase(scene)
	scene.get_parent().remove_child(scene)
	scene.free()
	check_eq(Vfx.running_count(), 0, "gone with the deck")
	check(not Audio.looping("vfx:1"), "and its sounds")


func test_the_pirate_deck_runs_its_effects_with_no_medbay() -> void:
	await _scene("res://scenes/pirates/pirate_deck.tscn")
	check_eq(Vfx.running_count(), (Data.value("pirates", "deck").effects as Array).size(), "its own list")


func test_effects_obey_the_sight_mask_on_a_deck() -> void:
	await _scene()
	for sheet: String in Vfx._materials:
		check(bool((Vfx._materials[sheet] as ShaderMaterial).get_shader_parameter("masked")), "%s is masked" % sheet)


func test_an_emitter_is_culled_far_from_the_listener() -> void:
	var scene: Node = await _scene()
	var op: Node3D = scene.operator
	Audio.follow(op)
	var field: ParticleField = Vfx.fields.fire_loop
	var before := field.spawned
	var id := Vfx.start("fire", op.global_position + Vector3(0.0, 0.0, 200.0))
	for i in 30:
		Vfx.advance(DT)
	check_eq(field.spawned, before, "too far: nothing spawned")
	Vfx.stop(id)
	id = Vfx.start("fire", op.global_position + Vector3(0.0, 0.0, -1.0))
	for i in 30:
		Vfx.advance(DT)
	check(field.spawned > before, "near: it burns")
	Vfx.stop(id)


func test_every_emitter_busy_is_refused_not_grown() -> void:
	var n := int(Data.value("vfx", "budgets").max_emitters)
	var ids: Array[int] = []
	for i in n:
		ids.append(Vfx.start("dust_motes", Vector3.ZERO))
	check_eq(Vfx.start("dust_motes", Vector3.ZERO), 0, "refused")
	check_eq(Vfx.running_count(), n, "still the budget")
	for id: int in ids:
		Vfx.stop(id)


func test_the_explosion_chooses_near_or_far_and_shakes_by_distance() -> void:
	var scene: Node = await _scene()
	var op: Node3D = scene.operator
	Audio.follow(op)
	Vfx.play("explosion", op.global_position + Vector3(2.0, 0.0, 0.0))
	check(_heard.has("explosion_near"), "near")
	var near_shake: float = Vfx._shake_m
	check(near_shake > 0.0, "it shakes")
	Vfx.clear_debris()
	_heard.clear()
	Vfx.play("explosion", op.global_position + Vector3(40.0, 0.0, 0.0))
	check(_heard.has("explosion_far"), "far")
	check_eq(Vfx._shake_m, 0.0, "out of reach, no shake")


func test_placed_lights_stay_in_their_room() -> void:
	await _scene()
	var lit := 0
	for l: Dictionary in Vfx._lights:
		if l.on:
			lit += 1
			check((l.node as OmniLight3D).light_cull_mask != Vfx.ALL_LAYERS, "a placed light has its room's layers")
			check(not (l.node as OmniLight3D).shadow_enabled, "and no shadow to pay for")
	check(lit > 0, "the console has one")


func test_the_noise_ring_doesnt_care_about_effects() -> void:
	var scene: Node = await _scene()
	var s: Node = scene.pack.stalkers[0]
	s.brain.state = s.brain.State.PROWL
	var left: float = s.brain._noise_left
	Vfx.play("explosion", s.global_position)
	check_eq(s.brain._noise_left, left, "a stalker doesn't hear an effect")


# --- the gallery ---

func test_the_gallery_lists_and_spawns_everything() -> void:
	var scene: Node = await _scene()
	var g: Node = scene.panel.gallery
	check_eq(g.picker.item_count, (Data.value("vfx", "recipes") as Dictionary).size(), "every recipe")
	for i in g.picker.item_count:
		g.spawn(g.picker.get_item_text(i), Vector3(0.0, 1.0, 0.0))
	g.clear()
	g.spawn_environment()
	check(Vfx.running_count() >= (Data.value("vfx", "gallery").environment as Array).size(), "the environment row")
	g.clear()


func test_the_shot_sequence_stands_a_wall_of_each_surface() -> void:
	var scene: Node = await _scene()
	var g: Node = scene.panel.gallery
	g.stand_walls()
	var seen := {}
	for w: StaticBody3D in g.walls:
		seen[Vfx.surfaces.surface_of(w, w.global_position, Vector3.UP)] = true
	check_eq(seen.size(), 3, "metal, panel and glass: %s" % str(seen.keys()))
	g.clear()
