extends RefCounted
## T020's capture stands, on the real decks: the shots the packet asks for from the game camera, and the frame-time
## windows (idle, a full mag dump into a metal wall at close range, every environment effect running). The AI is
## stopped by the stand scripts so nobody interrupts a measurement. Dev only.

const AIM_FRONT := 3.5
const DUMP_MAGS := 3
const WINDOW_S := 6.0
const WALL_BACK_M := 2.6
const SETTLE_S := 0.3
const BRASS_BACK_M := 1.8
const EFFECT_S := {"explosion": 0.42, "fire": 2.4, "smoke_plume": 4.5, "steam_jet": 1.3, "sparking_console": 2.0, "acid_pool": 2.0, "dust_motes": 8.0}

var deck: Node
var results := {}


func _init(owner_deck: Node) -> void:
	deck = owner_deck


func shots(has_medbay: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"name": "t020_measure_idle", "do": "measure_idle"},
		{"name": "t020_measure_mag_dump", "do": "measure_dump"},
		{"name": "t020_measure_effects", "do": "measure_effects"},
		{"name": "t020_burst_metal", "do": "burst", "space": "junction", "want": "metal"},
		{"name": "t020_burst_glass", "do": "burst", "space": "cargo", "want": "glass"},
		{"name": "t020_stalker_shot", "do": "stalker"},
		{"name": "t020_brass_and_magazine", "do": "brass"},
		{"name": "t020_sequence_walls", "do": "sequence"},
	]
	if has_medbay:
		out.insert(4, {"name": "t020_burst_panel", "do": "burst", "space": "medbay", "want": "panel"})
	for recipe: String in Data.value("vfx", "gallery").environment:
		out.append({"name": "t020_gallery_%s" % recipe, "do": "gallery", "recipe": recipe})
	return out


func apply(shot: Dictionary) -> void:
	Engine.time_scale = 1.0
	deck.panel.visible = false
	deck.panel.gallery.clear()
	deck.respawn()
	deck.rig.set_preset(int(Data.value("camera", "default_preset")))
	deck.flashlight.set_on(true)
	deck.operator.scripted = {}
	match String(shot.do):
		"measure_idle":
			await _to_wall("junction", "metal")
			await _measure("idle")
		"measure_dump":
			await _to_wall("junction", "metal")
			deck.operator.scripted = {"fire": true}
			var rifle: Node = deck.operator.rifle
			var w := Window_.new()
			for m in DUMP_MAGS:
				rifle.state.mag = int(rifle.state.cfg.magazine)
				while rifle.state.mag > 0:
					await w.frame(deck)
				deck.operator.scripted = {}
				await deck._sim(SETTLE_S)
				w.pause()
				deck.operator.scripted = {"fire": true}
			results["mag_dump"] = w.report()
			results["mag_dump"]["decals"] = Vfx.visible_decals()
			results["mag_dump"]["casings"] = Vfx.casings.count
			results["mag_dump"]["live_particles_end"] = Vfx.live_particles()
			deck.operator.scripted = {}
		"measure_effects":
			await _to_wall("junction", "metal")
			deck.panel.gallery.spawn_environment()
			await deck._sim(EFFECT_S.smoke_plume)
			await _measure("all_environment_effects")
			results["all_environment_effects"]["running"] = Vfx.running_count()
			results["all_environment_effects"]["live_particles"] = Vfx.live_particles()
			_write()
		"burst":
			var found := await _to_wall(String(shot.space), String(shot.want))
			results[String(shot.name)] = found
			await _burst(0.55)
		"stalker":
			await _stalker()
		"brass":
			await _brass()
		"sequence":
			var c: Vector2 = _open_spot()
			await deck._stand_at(c, c + Vector2(0.0, -AIM_FRONT))
			await deck.panel.gallery.run_sequence()
		"gallery":
			var c2: Vector2 = _open_spot()
			await deck._stand_at(c2, c2 + Vector2(0.0, -AIM_FRONT))
			var at: Vector3 = deck.operator.global_position + Vector3(0.0, 0.0, -AIM_FRONT)
			deck.panel.gallery.spawn(String(shot.recipe), at)
			await deck._sim(float(EFFECT_S.get(String(shot.recipe), 1.5)))
	Engine.time_scale = 0.0


func _open_spot() -> Vector2:
	var space := "medbay" if deck.layout.spaces.has("medbay") else "cargo"
	for frac: Array in [[0.55, 0.62], [0.7, 0.6], [0.5, 0.7], [0.75, 0.75], [0.6, 0.85]]:
		var p: Vector2 = deck.layout.point_in(space, frac)
		var ahead := p + Vector2(0.0, -AIM_FRONT)
		if deck.layout.is_free(p, deck.operator.body_radius()) and deck.layout.is_free(ahead, deck.operator.body_radius() * 2.0):
			return p
	return deck.layout.point_in(space, [0.55, 0.62])


## Close to a north wall of the surface asked for (the camera looks north, so it faces us). Returns what it found.
func _to_wall(space: String, want: String) -> Dictionary:
	var r: Rect2 = deck.layout.space_rect(space)
	var h := float(Data.value("player", "aim_height_m"))
	var world: PhysicsDirectSpaceState3D = deck.get_world_3d().direct_space_state
	var tries: Array[float] = []
	for i in range(0, 10):
		tries.append_array([0.5 + float(i) / 20.0, 0.5 - float(i) / 20.0])
	for share: float in tries:
		var x := r.position.x + r.size.x * share
		var from := Vector3(x, h, r.position.y + WALL_BACK_M + 0.2)
		if not _clear_lane(world, from, Vector3(x, h, r.position.y - 1.0)):
			continue
		var hit: Dictionary = world.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(x, h, r.position.y - 1.0)))
		if hit.is_empty() or not hit.collider is StaticBody3D or absf(hit.position.z - r.position.y) > 0.5:
			continue
		var surface: String = Vfx.surfaces.surface_of(hit.collider, hit.position, hit.normal)
		if surface != want:
			continue
		var stand := Vector2(x, hit.position.z + WALL_BACK_M)
		if not deck.layout.is_free(stand, deck.operator.body_radius()):
			continue
		await deck._stand_at(stand, Vector2(x, hit.position.z))
		return {"wall_at": [hit.position.x, hit.position.z], "surface": surface, "material": Vfx.surfaces.material_at(hit.collider, hit.position, hit.normal)}
	push_error("T020: no %s wall in %s" % [want, space])
	return {"surface": "none"}


## Nothing but the far wall for a shot with some spread: three rays must all reach it.
func _clear_lane(world: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	for off: float in [-0.7, 0.0, 0.7]:
		var hit: Dictionary = world.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3(off, 0.0, 0.0), to + Vector3(off, 0.0, 0.0)))
		if hit.is_empty() or absf(float(hit.position.z) - to.z) > 1.5:
			return false
	return true


func _burst(seconds: float) -> void:
	deck.operator.scripted = {"fire": true}
	await deck._sim(seconds)
	var fx: Node = deck.operator.rifle.fx
	while not fx._flash.visible:
		await deck.get_tree().process_frame
	deck.operator.scripted = {}


func _stalker() -> void:
	var space := "junction"
	await _to_wall(space, "metal")
	var s: Node = deck.pack.stalkers[0] if "pack" in deck else deck.squad.pirates[0]
	var op: Node3D = deck.operator
	var at := Vector2(op.global_position.x, op.global_position.z - WALL_BACK_M * 0.6)
	s.global_position = Vector3(at.x, 0.0, at.y)
	if "pack" in deck:
		s.brain.force_hunt(at, Vector2(op.global_position.x, op.global_position.z))
		s.brain.health = float(s.cfg.health) * 3.0
	s.visible = true
	await deck._sim(0.1)
	await _burst(0.4)


func _brass() -> void:
	await _to_wall("junction", "metal")
	var rifle: Node = deck.operator.rifle
	rifle.state.mag = int(rifle.state.cfg.magazine)
	deck.operator.scripted = {"fire": true}
	while rifle.state.mag > 0:
		await deck.get_tree().process_frame
	deck.operator.scripted = {}
	await deck._sim(0.5)
	deck.operator.request_reload()
	await deck._sim(1.4)
	# Step back and light what fell, clear of the RELOADING tag.
	var op: Node3D = deck.operator
	var mag: Vector3 = Vfx.magazines.slots[0].pos
	var mid := mag
	for i in Vfx.casings.count:
		mid += Vfx.casings.slots[i].pos
	mid /= float(Vfx.casings.count + 1)
	var back := Vector2(op.global_position.x, op.global_position.z + BRASS_BACK_M)
	await deck._stand_at(back, Vector2(mid.x, mid.z))
	results["brass"] = {"casings": Vfx.casings.count, "magazines": Vfx.magazines.count, "magazine_at": [mag.x, mag.y, mag.z]}
	_write()
	await deck._sim(0.2)


func _measure(key: String) -> void:
	var w := Window_.new()
	var t_end := Time.get_ticks_usec() + int(WINDOW_S * 1e6)
	while Time.get_ticks_usec() < t_end:
		await w.frame(deck)
	results[key] = w.report()


func _write() -> void:
	var f := FileAccess.open(Capture._out.path_join("frametime_%s.json" % String(deck.scene_file_path).get_file().get_basename()), FileAccess.WRITE)
	results["resolution"] = str(deck.get_viewport().get_texture().get_size())
	results["adapter"] = RenderingServer.get_video_adapter_name()
	results["budgets"] = Data.value("vfx", "budgets")
	f.store_string(JSON.stringify(results, "  ") + "\n")


class Window_:
	var frames: PackedFloat64Array = []
	var _last := 0
	var peak := 0

	func frame(deck: Node) -> void:
		if _last == 0:
			_last = Time.get_ticks_usec()
		await deck.get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - _last) / 1000.0)
		_last = now
		if frames.size() % 30 == 0:
			peak = maxi(peak, Vfx.live_particles())

	## The next frame starts a new stretch: time between measured stretches isn't a frame.
	func pause() -> void:
		_last = 0

	func report() -> Dictionary:
		var s := frames.duplicate()
		s.sort()
		var t := 0.0
		for v in s:
			t += v
		return {"frames": s.size(), "ms_avg": t / maxi(s.size(), 1), "ms_p95": s[int(s.size() * 0.95)], "ms_p99": s[int(s.size() * 0.99)], "ms_max": s[-1], "peak_particles": peak}
