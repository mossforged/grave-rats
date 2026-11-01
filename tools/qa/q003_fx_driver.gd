extends RefCounted
## Q003: holds a deck in one state for the whole of the capture's frame-time window, so frametime.json measures it and
## the same stand runs on commits before T020. Chosen by env Q003_FX:
##   idle     stood at the wall, AI stopped, the deck's own effects if it has any
##   dump     the same, the rifle held down into the metal wall, magazine topped up, so a 30 s window is about 300 rounds
##   effects  the same as idle, plus every environment effect (T020+; the one-shot explosion is re-fired)
##   plume    the same as idle, plus a smoke plume on top of the operator (T020's unmeasured overdraw worry; T020+)
## Writes q003_fx.json beside frametime.json: rounds fired, what the wall was, and the pools at the end.

## T020's own search finds this wall on both decks (docs/screens/T020/frametime_*.json): metal, hull material.
const WALL_AT := Vector2(2.5, 0.0)
const WALL_BACK_M := 2.6
const EXPLOSION_EVERY_S := 3.0

var deck: Node
var mode := ""
var rounds := 0
var _vfx: Node


func _init(owner_deck: Node) -> void:
	deck = owner_deck
	mode = OS.get_environment("Q003_FX")
	_vfx = deck.get_node_or_null("/root/Vfx")


func run() -> void:
	var tree := deck.get_tree()
	await tree.process_frame
	await tree.process_frame
	deck._demo_t = -1.0
	deck.aim_from_mouse = false
	if deck.has_method("_close_form"):
		deck._close_form()
	if "session_live" in deck:
		deck.session_live = false
	if "ambush" in deck:
		deck.ambush.fired = true
	if deck.has_method("_open_all_doors"):
		deck._open_all_doors()
	deck.panel.visible = false
	deck.flashlight.set_on(true)
	var op: Node3D = deck.operator
	op.input_enabled = false
	op.scripted = {}
	await deck._stand_at(WALL_AT + Vector2(0.0, WALL_BACK_M), WALL_AT)
	var info := {"mode": mode, "scene": String(deck.scene_file_path), "has_vfx": _vfx != null, "stood_at": [op.global_position.x, op.global_position.z]}
	if _vfx != null:
		info["surface"] = _wall_surface()
	if mode == "effects" or mode == "plume":
		if _vfx == null:
			push_error("Q003: %s needs T020" % mode)
			return
		if mode == "effects":
			deck.panel.gallery.spawn_environment()
		else:
			deck.panel.gallery.spawn("smoke_plume", op.global_position)
	var rifle: Node = op.rifle
	var full := int(rifle.state.cfg.magazine)
	var last_mag := int(rifle.state.mag)
	var since_write := 0.0
	var since_boom := 0.0
	while true:
		await tree.process_frame
		var dt := deck.get_process_delta_time()
		deck.suit.reset()
		if mode == "dump":
			op.scripted = {"fire": true}
			var mag := int(rifle.state.mag)
			rounds += maxi(last_mag - mag, 0)
			if mag <= 2:
				rifle.state.mag = full
				mag = full
			last_mag = mag
		elif mode == "effects":
			since_boom += dt
			if since_boom >= EXPLOSION_EVERY_S:
				since_boom = 0.0
				var dir: Vector3 = op.aim_dir()
				deck.panel.gallery.spawn("explosion", op.global_position + dir * 3.0)
		since_write += dt
		if since_write >= 2.0:
			since_write = 0.0
			_write(info)


func _wall_surface() -> String:
	var h := float(Data.value("player", "aim_height_m"))
	var from := Vector3(WALL_AT.x, h, WALL_AT.y + WALL_BACK_M)
	var hit: Dictionary = deck.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(WALL_AT.x, h, WALL_AT.y - 1.0)))
	if hit.is_empty() or not hit.collider is StaticBody3D:
		return "none"
	return String(_vfx.surfaces.surface_of(hit.collider, hit.position, hit.normal))


func _write(info: Dictionary) -> void:
	var out := info.duplicate()
	out["rounds"] = rounds
	if _vfx != null:
		out["live_particles"] = _vfx.live_particles()
		out["decals"] = _vfx.visible_decals()
		out["casings"] = _vfx.casings.count
		out["running"] = _vfx.running_count()
	var f := FileAccess.open(Capture._out.path_join("q003_fx.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, " ") + "\n")
