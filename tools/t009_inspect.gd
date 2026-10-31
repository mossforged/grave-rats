extends SceneTree
## T009: prints what the hauler and its clips hold: bones, rest pose, clips, hip travel.
## usage: godot --headless --path . -s tools/t009_inspect.gd

const FILES := ["hauler-rigged.glb", "hauler-rifle-idle.fbx", "hauler-crouch-idle.fbx", "hauler-crouch-aim.fbx",
	"hauler-crouch-walk.fbx", "hauler-strafe-a.fbx", "hauler-strafe-b.fbx", "hauler-reload.fbx", "hauler-hit.fbx"]


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _tree(n: Node, depth: int, limit: int) -> void:
	print("  ".repeat(depth), n.name, " <", n.get_class(), ">", " scale ", n.scale if n is Node3D else Vector3.ONE)
	if depth < limit:
		for c in n.get_children():
			_tree(c, depth + 1, limit)


func _run() -> void:
	for f: String in FILES:
		var root: Node = (load("res://assets/game/hauler/" + f) as PackedScene).instantiate()
		get_root().add_child(root)
		print("=== ", f)
		_tree(root, 0, 3)
		var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		print("bones ", sk.get_bone_count(), " first ", sk.get_bone_name(0))
		for b in ["Hips", "Spine2", "LeftUpLeg", "LeftFoot", "LeftArm", "RightHand", "Head"]:
			var i := sk.find_bone("mixamorig_" + b)
			if i < 0:
				print(b, " missing")
				continue
			var g := sk.get_bone_global_rest(i)
			print(b, " at ", g.origin.snappedf(0.001), " y-axis ", g.basis.y.normalized().snappedf(0.01), " scale ", g.basis.get_scale().snappedf(0.001))
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		for a: String in ap.get_animation_list():
			var clip := ap.get_animation(a)
			var hips := -1
			var kinds := {}
			for t in clip.get_track_count():
				kinds[clip.track_get_type(t)] = kinds.get(clip.track_get_type(t), 0) + 1
				if String(clip.track_get_path(t)).ends_with("Hips") and clip.track_get_type(t) == Animation.TYPE_POSITION_3D:
					hips = t
			var s := "%s len %.3f loop %d kinds %s" % [a, clip.length, clip.loop_mode, kinds]
			if hips >= 0:
				var n := clip.track_get_key_count(hips)
				var lo := INF
				var hi := -INF
				for k in n:
					var y: float = (clip.track_get_key_value(hips, k) as Vector3).y
					lo = minf(lo, y)
					hi = maxf(hi, y)
				s += " path %s keys %d first %s last %s y %.3f-%.3f" % [clip.track_get_path(hips), n, clip.track_get_key_value(hips, 0), clip.track_get_key_value(hips, n - 1), lo, hi]
			print(s)
		root.free()
	quit(0)
