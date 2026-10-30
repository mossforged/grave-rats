extends SceneTree
## T003: how badly do the feet slide? Walks the real operator in each direction and measures how
## fast a planted foot moves over the ground (foot in the lowest 3 cm of its swing). 0 = perfect.
## usage: godot --headless --path . -s tools/t003_footslide.gd

const CASES := [
	["walk forward", Vector2(0, -1), false, false],
	["walk back", Vector2(0, 1), false, false],
	["strafe right", Vector2(1, 0), false, false],
	["strafe left", Vector2(-1, 0), false, false],
	["crouch forward", Vector2(0, -1), true, false],
	["sprint forward", Vector2(0, -1), false, true],
]


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	# Loaded here, not preloaded: the script needs the Data autoload, which -s scripts compile before.
	var Operator: GDScript = load("res://src/player/operator.gd")
	for c: Array in CASES:
		var op: Node3D = Operator.new()
		root.add_child(op)
		op.input_enabled = false
		op.face_now(Vector3(0, 1.2, -100))
		op.aim_point = Vector3(0, 1.2, -100000)
		op.scripted = {"keys": c[1], "crouch": c[2], "sprint": c[3]}
		var sk: Skeleton3D = op.anim.skeleton
		var foot: int = sk.find_bone("foot_L")
		for i in 40:
			await physics_frame
		var samples: Array[Vector3] = []
		for i in 240:
			await physics_frame
			await process_frame
			samples.append(sk.global_transform * sk.get_bone_global_pose(foot).origin)
		var low := INF
		for p in samples:
			low = minf(low, p.y)
		var dist := 0.0
		var frames := 0
		for i in samples.size() - 1:
			if samples[i].y < low + 0.03:
				var d := samples[i + 1] - samples[i]
				dist += Vector2(d.x, d.z).length()
				frames += 1
		var dt := 1.0 / float(Engine.physics_ticks_per_second)
		print("%-16s body %.2f m/s  planted foot slides %.2f m/s (%d%% of the body speed), planted %d%% of the time" % [
			c[0], op.model.speed, dist / maxf(frames * dt, dt), roundi(dist / maxf(frames * dt, dt) / op.model.speed * 100.0),
			roundi(float(frames) / samples.size() * 100.0)])
		op.free()
	quit(0)
