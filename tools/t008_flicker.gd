extends SceneTree
## T008: the flashlight's "second shape", measured on the real GPU. Holds a pose (still, or turning
## slowly), saves consecutive frames with the beam on and off, and prints how the beam's outline
## moves frame to frame. tools/t008_flicker_diff.py turns the frames into twinkle numbers.
## usage: godot --path . --fixed-fps 60 -s tools/t008_flicker.gd -- --out=<dir> [--frames=60]
## It also measures the outline the pre-T008 draw_beam would have built, for the "before" column.

const TURN_DEG_S := 10.0
const OUTLINE_RAYS := 49

var out := ""
var frames := 60
var scene: Node


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--frames="):
			frames = int(a.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _size_window()
	var overlay := root.get_node_or_null("DebugOverlay")
	if overlay:
		overlay.visible = false
	await _stalker_deck()
	await _pirate_deck()
	quit()


func _size_window() -> void:
	var want := Vector2i(1920, 1080)
	DisplayServer.window_set_size(want)
	for i in 3:
		for k in 3:
			await process_frame
		var got := Vector2i(root.get_texture().get_size())
		if got == want:
			break
		DisplayServer.window_set_size(Vector2i(Vector2(DisplayServer.window_get_size()) * Vector2(want) / Vector2(got)))


func _load(path: String) -> void:
	if scene:
		scene.free()
	scene = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	scene.aim_from_mouse = false
	scene.operator.input_enabled = false


func _stalker_deck() -> void:
	await _load("res://scenes/enemies/stalker_deck.tscn")
	var d: Node = scene._door("medbay", 0.7)
	scene._open_medbay_door()
	# The ambush's camera kick shakes the whole frame, which swamps everything measured here.
	scene.ambush.fired = true
	for s: Node in scene.pack.stalkers:
		s.set_physics_process(false)
		s.process_mode = Node.PROCESS_MODE_DISABLED
	var p: Vector2 = scene._door_side(d, -1.0, 0.9)
	var look: Vector2 = scene._door_side(d, -1.0, 6.0)
	for beam: bool in [true, false]:
		var tag := "beam_on" if beam else "beam_off"
		await scene._stand_at(p, look)
		scene.flashlight._beam.visible = beam
		await _hold(0.6)
		await _record("still_" + tag, 0.0, look)
		await _record("turn_" + tag, TURN_DEG_S, look)
	scene.flashlight._beam.visible = true


func _pirate_deck() -> void:
	await _load("res://scenes/pirates/pirate_deck.tscn")
	scene._hold_squad = true
	scene._open_all_doors()
	var c: Rect2 = scene._piece_rect(11)
	var me := Vector2(c.get_center().x - 3.5, c.position.y - 2.5)
	await scene._stand_at(me, me + Vector2(4.0, 2.0))
	var q: Node = scene.squad.pirates[2]
	q.global_position = Vector3(me.x + 3.0, 0, me.y + 3.0)
	for o: Node in scene.squad.pirates:
		o.get_node("SightTarget").set_seen(true)
	await _hold(0.4)
	var at := Vector2(q.global_position.x, q.global_position.z)
	var muzzle: Vector3 = q.muzzle_position()
	for turn: float in [0.0, TURN_DEG_S]:
		var yaw: float = PI * 0.25
		var dir := "pirate_still" if turn == 0.0 else "pirate_turn"
		var folder := out.path_join(dir)
		DirAccess.make_dir_recursive_absolute(folder)
		for i in frames:
			yaw += deg_to_rad(turn) / 60.0
			q.light.follow(muzzle, yaw)
			q.light.draw_beam(1.0 / 60.0, scene.squad.visibility, at, yaw, muzzle)
			await RenderingServer.frame_post_draw
			_save(folder, i)
		print("REC ", dir)


func _hold(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0


## Frames in a row, with the outline measured from the scene's own polygon as it goes.
func _record(tag: String, turn_deg_s: float, look: Vector2) -> void:
	var folder := out.path_join(tag)
	DirAccess.make_dir_recursive_absolute(folder)
	var op: Node3D = scene.operator
	var at := Vector2(op.global_position.x, op.global_position.z)
	var a0 := (look - at).angle()
	var prev := PackedFloat64Array()
	var worst := 0.0
	var total := 0.0
	var last_count := -1
	var count_changes := 0
	var fan_prev := PackedVector2Array()
	var fan_worst := 0.0
	for i in frames:
		var a := a0 + deg_to_rad(turn_deg_s) * float(i) / 60.0
		var aim := at + Vector2.from_angle(a) * 6.0
		op.aim_point = Vector3(aim.x, scene._aim_height, aim.y)
		await RenderingServer.frame_post_draw
		_save(folder, i)
		var ring := _old_ring()
		if ring.size() != last_count and last_count >= 0:
			count_changes += 1
		last_count = ring.size()
		var o := _outline(ring)
		if prev.size() == o.size():
			for k in o.size():
				var dm := absf(o[k] - prev[k])
				worst = maxf(worst, dm)
				total += dm
		prev = o
		var fan: RefCounted = scene.flashlight.fan
		if fan:
			var pts := PackedVector2Array()
			for k in fan.reach.size():
				pts.append(fan.point(k))
			if fan_prev.size() == pts.size():
				for k in pts.size():
					fan_worst = maxf(fan_worst, pts[k].distance_to(fan_prev[k]))
			fan_prev = pts
	print("REC %s old-ring: vertex count changed %d times in %d frames; outline jump worst %.3f m, mean %.4f m; fixed fan: worst vertex move %.3f m" % [
			tag, count_changes, frames, worst, total / float(maxi((frames - 1) * OUTLINE_RAYS, 1)), fan_worst])


## What draw_beam built before T008: the sight polygon's points inside the wedge.
func _old_ring() -> PackedVector2Array:
	var cfg: Dictionary = scene.sight.cfg
	var half := deg_to_rad(float(cfg.cone_on.half_angle_deg))
	var ahead := float(cfg.flashlight.muzzle_ahead_m)
	var eye: Vector2 = scene._eye()
	var yaw: float = scene.operator.gun_yaw()
	var ring := PackedVector2Array()
	for p: Vector2 in scene.sight.polygon:
		var to := p - eye
		if absf(angle_difference(yaw, atan2(-to.x, -to.y))) <= half:
			ring.append(eye + to.normalized() * ahead if to.length() < ahead else p)
	return ring


## How far the fan reaches along fixed rays from the muzzle, relative to the gun.
func _outline(ring: PackedVector2Array) -> PackedFloat64Array:
	var o := PackedFloat64Array()
	var m: Vector3 = scene.operator.muzzle_position()
	var apex := Vector2(m.x, m.z)
	var yaw: float = scene.operator.gun_yaw()
	var half := deg_to_rad(float(scene.sight.cfg.cone_on.half_angle_deg))
	for r in OUTLINE_RAYS:
		var y := yaw - half + half * 2.0 * float(r) / float(OUTLINE_RAYS - 1)
		var dir := Vector2(-sin(y), -cos(y))
		var best := 0.0
		for i in ring.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(apex, apex + dir * 40.0, ring[i], ring[i + 1])
			if hit != null:
				best = maxf(best, apex.distance_to(hit))
		o.append(best)
	return o


func _save(folder: String, i: int) -> void:
	root.get_texture().get_image().save_png(folder.path_join("%03d.png" % i))
