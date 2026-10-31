extends SceneTree
## T022: what each Mixamo file actually does once it's on the hauler, at the game's scale. Ground speed and
## direction from the planted feet, stride phase, how far a turn clip turns, how far the hands travel over time
## (for marking the reload's and the shot's frames). Reads files, not the data, so it can be run before wiring.
## usage: godot --headless --path . -s tools/t022_measure.gd [-- --hands=rifle_reload,rifle_fire]

const DIR := "res://assets/game/hauler/clips/"


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var Clips: GDScript = load("res://src/player/hauler_clips.gd")
	var Retarget: GDScript = load("res://src/player/hauler_retarget.gd")
	var Body: GDScript = load("res://src/player/operator_body.gd")
	var data: Node = root.get_node("Data")
	var cfg: Dictionary = data.load_data("hauler_anim")
	var inner: Node3D = (load(String(cfg.file)) as PackedScene).instantiate()
	var sk: Skeleton3D = inner.find_children("*", "Skeleton3D", true, false)[0]
	var rest: Dictionary = Retarget.rest_of(sk)
	# Skeleton space to the world: the fit to the data's height, then the deck's character scale.
	var scale: float = Body.fit_scale(inner, float(cfg.height_m)) * float(data.value("deck", "character_scale", 1.0))
	var hands := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hands="):
			hands = arg.trim_prefix("--hands=")
	print("world scale of the skeleton: %.4f" % scale)
	var feet: Array = cfg.bones.feet
	var hip_path := "%s:%s" % [cfg.skeleton_path, cfg.bones.hips]
	var files: Array = Array(DirAccess.get_files_at(DIR))
	files.sort()
	for f: String in files:
		if not f.ends_with(".fbx"):
			continue
		var clip: Animation = Clips._from_file(DIR + f, cfg, rest)
		if clip == null:
			print("%s DID NOT LOAD" % f)
			continue
		var travel: float = Retarget.hip_travel(clip, hip_path)
		Retarget.strip_hip_travel(clip, hip_path)
		var v := _ground(Retarget, clip, rest, cfg.skeleton_path, feet) * scale
		print("%-34s %5.2fs  right %+5.2f fwd %+5.2f  |v| %4.2f  phase %.2f  hip_travel %.2f  turn %+6.1f" % [
			f.get_basename(), clip.length, v.x, v.y, v.length(),
			_phase(Retarget, clip, rest, cfg.skeleton_path, feet), travel * scale, _turn_deg(clip, hip_path)])
		if hands.split(",").has(f.get_basename()):
			_hands(Retarget, clip, rest, cfg)
	inner.free()
	quit(0)


## Ground velocity the planted feet imply: x right, y forward, in the hauler's own facing (its file faces +Z).
func _ground(R: GDScript, clip: Animation, rest: Dictionary, path: String, feet: Array) -> Vector2:
	var samples := 90
	var low: float = R.lowest(clip, rest, path, feet, samples)
	var dt := clip.length / float(samples)
	var sum := Vector3.ZERO
	var time := 0.0
	for s in samples:
		var a: Dictionary = R.fk(clip, rest, path, dt * s, feet)
		var b: Dictionary = R.fk(clip, rest, path, dt * (s + 1), feet)
		for foot: String in feet:
			if (a[foot] as Vector3).y < low + 0.03 and (b[foot] as Vector3).y < low + 0.03:
				sum -= (b[foot] as Vector3) - (a[foot] as Vector3)
				time += dt
	var v := sum / maxf(time, dt)
	return Vector2(-v.x, v.z)


## Where in its loop a clip is: the first harmonic of left foot height minus right foot height, 0..1.
func _phase(R: GDScript, clip: Animation, rest: Dictionary, path: String, feet: Array) -> float:
	var n := 48
	var re := 0.0
	var im := 0.0
	for s in n:
		var at: Dictionary = R.fk(clip, rest, path, clip.length * s / float(n), feet)
		var diff: float = (at[feet[0]] as Vector3).y - (at[feet[1]] as Vector3).y
		var a := TAU * s / float(n)
		re += diff * cos(a)
		im += diff * sin(a)
	return fposmod(atan2(im, re) / TAU, 1.0)


func _turn_deg(clip: Animation, hip_path: String) -> float:
	var t := clip.find_track(NodePath(hip_path), Animation.TYPE_ROTATION_3D)
	if t < 0:
		return 0.0
	var total := 0.0
	var last: Quaternion = clip.track_get_key_value(t, 0)
	for k in range(1, clip.track_get_key_count(t)):
		var q: Quaternion = clip.track_get_key_value(t, k)
		var change := q * last.inverse()
		total += rad_to_deg(2.0 * atan2(change.y, change.w))
		last = q
	return total


func _hands(R: GDScript, clip: Animation, rest: Dictionary, cfg: Dictionary) -> void:
	var left: String = cfg.bones.hand_left
	var right: String = cfg.bones.hand_right
	var hips: String = cfg.bones.hips
	var frames := int(clip.length * 30.0)
	var step := maxi(frames / 40, 1)
	var first: Dictionary = R.fk(clip, rest, cfg.skeleton_path, 0.0, [left, right, hips])
	for f in range(0, frames + 1, step):
		var at: Dictionary = R.fk(clip, rest, cfg.skeleton_path, f / 30.0, [left, right, hips])
		print("    f%3d  hands apart %.2f  left y %.2f  right y %.2f  right moved %.3f  hips y %.2f" % [f,
			(at[left] as Vector3).distance_to(at[right]), (at[left] as Vector3).y, (at[right] as Vector3).y,
			(at[right] as Vector3).distance_to(first[right]), (at[hips] as Vector3).y])
