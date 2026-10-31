extends SceneTree
## T009: works out data/hauler_anim.json "rifle" so the legacy rifle sits in the hauler's hands. Where
## each hand grips the gun comes from the legacy body's aim pose; where the hands are comes from the
## hauler's aim clip. Prints the numbers; paste them into the data.
## usage: godot --headless --path . -s tools/t009_rifle_fit.gd [-- --state=aim]


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var Retarget: GDScript = load("res://src/player/hauler_retarget.gd")
	var Clips: GDScript = load("res://src/player/hauler_clips.gd")
	var Body: GDScript = load("res://src/player/operator_body.gd")
	var cfg: Dictionary = root.get_node("Data").load_data("hauler_anim")
	var state := "aim"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--state="):
			state = arg.trim_prefix("--state=")
	var legacy: Node = (load("res://assets/game/legacy/operator.glb") as PackedScene).instantiate()
	root.add_child(legacy)
	var lsk: Skeleton3D = legacy.find_children("*", "Skeleton3D", true, false)[0]
	var lap: AnimationPlayer = legacy.find_children("*", "AnimationPlayer", true, false)[0]
	var lrest: Dictionary = Retarget.rest_of(lsk)
	var aim: Animation = lap.get_animation("U_Aim")
	var lposes: Dictionary = Retarget.fk_poses(aim, lrest, "Rig/Skeleton3D", 0.0, ["weapon", "hand_R", "hand_L"])
	var grip_r: Vector3 = lposes.weapon.affine_inverse() * lposes.hand_R.origin
	var grip_l: Vector3 = lposes.weapon.affine_inverse() * lposes.hand_L.origin
	print("legacy grips in the weapon frame: right ", grip_r.snappedf(0.001), " left ", grip_l.snappedf(0.001))
	var hauler: Node = (load(String(cfg.file)) as PackedScene).instantiate()
	root.add_child(hauler)
	var sk: Skeleton3D = hauler.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = hauler.find_children("*", "AnimationPlayer", true, false)[0]
	var rest: Dictionary = Retarget.rest_of(sk)
	var lib: AnimationLibrary = Clips.library(cfg, ap, rest)
	print("sources ", Clips.sources())
	print("lifts ", Clips.lifts())
	var clip: Animation = lib.get_animation(state)
	var b: Dictionary = cfg.bones
	var poses: Dictionary = Retarget.fk_poses(clip, rest, String(cfg.skeleton_path), 0.0, [b.hand_right, b.hand_left])
	var right: Transform3D = poses[b.hand_right]
	var left: Transform3D = poses[b.hand_left]
	var barrel: Vector3 = (left.origin - right.origin).normalized()
	print("hands: right ", right.origin.snappedf(0.001), " left ", left.origin.snappedf(0.001), " apart ", right.origin.distance_to(left.origin),
		" legacy apart ", grip_r.distance_to(grip_l), " barrel ", barrel.snappedf(0.01))
	var up := (Vector3.UP - barrel * Vector3.UP.dot(barrel)).normalized()
	var basis := Basis(barrel.cross(up).normalized(), barrel, up)
	# The right hand on the grip. The hauler's arms are longer than the legacy grip spacing, so the left
	# hand lands further up the barrel.
	var origin := right.origin - basis * grip_r
	var offset := right.affine_inverse() * Transform3D(basis, origin)
	var euler := offset.basis.get_euler()
	print("\"hand_offset_m\": [%.4f, %.4f, %.4f], \"hand_euler_deg\": [%.2f, %.2f, %.2f]" % [offset.origin.x, offset.origin.y, offset.origin.z,
		rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)])
	print("fit scale ", Body.fit_scale(hauler, float(cfg.height_m)))
	quit(0)
