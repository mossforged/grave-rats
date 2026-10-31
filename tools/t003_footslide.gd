extends SceneTree
## T003: how badly do the feet slide? Walks the real operator in each direction and measures how
## fast a planted foot moves over the ground (foot in the lowest 3 cm of its swing). 0 = perfect.
## usage: godot --headless --path . -s tools/t003_footslide.gd [-- --body=legacy]

## Without --all: T009's six cases, for comparing with its table. With --all: every locomotion clip (T022), and
## the walk gait through speed_mult. --exact steps the body and the clips by hand on one clock, which takes out
## the frame-order noise T009 reported.
const CASES := [
	["walk forward", Vector2(0, -1), false, false, 1.0],
	["walk back", Vector2(0, 1), false, false, 1.0],
	["strafe right", Vector2(1, 0), false, false, 1.0],
	["strafe left", Vector2(-1, 0), false, false, 1.0],
	["crouch forward", Vector2(0, -1), true, false, 1.0],
	["sprint forward", Vector2(0, -1), false, true, 1.0],
]
const EIGHT := [["fwd", Vector2(0, -1)], ["fwd_right", Vector2(1, -1)], ["right", Vector2(1, 0)], ["back_right", Vector2(1, 1)],
	["back", Vector2(0, 1)], ["back_left", Vector2(-1, 1)], ["left", Vector2(-1, 0)], ["fwd_left", Vector2(-1, -1)]]
## Share of the top speed that puts the body in the walk gait's own speed.
const WALK_SHARE := 0.5


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	# Loaded here, not preloaded: the script needs the Data autoload, which -s scripts compile before.
	var Operator: GDScript = load("res://src/player/operator.gd")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body="):
			load("res://src/player/operator_body.gd").forced = arg.trim_prefix("--body=")
	var args := OS.get_cmdline_user_args()
	var cases: Array = CASES
	if args.has("--all"):
		cases = []
		for e: Array in EIGHT:
			cases.append(["walk " + e[0], e[1], false, false, WALK_SHARE])
		for e: Array in EIGHT:
			cases.append(["run " + e[0], e[1], false, false, 1.0])
		for e: Array in [EIGHT[0], EIGHT[2], EIGHT[6]]:
			cases.append(["sprint " + e[0], e[1], false, true, 1.0])
		for e: Array in [EIGHT[0], EIGHT[2], EIGHT[4], EIGHT[6]]:
			cases.append(["crouch " + e[0], e[1], true, false, 1.0])
	var exact := args.has("--exact")
	for c: Array in cases:
		var op: Node3D = Operator.new()
		root.add_child(op)
		op.input_enabled = false
		op.face_now(Vector3(0, 1.2, -100))
		op.aim_point = Vector3(0, 1.2, -100000)
		op.scripted = {"keys": c[1], "crouch": c[2], "sprint": c[3]}
		op.model.speed_mult = c[4]
		var sk: Skeleton3D = op.anim.skeleton
		var feet: Array = []
		for bone: String in op.anim.foot_bones():
			feet.append(sk.find_bone(bone))
		var dt := 1.0 / float(Engine.physics_ticks_per_second)
		var tree: AnimationTree = op.anim.tree
		if exact:
			op.set_physics_process(false)
			tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var samples: Array = [[], []]
		for i in 280:
			await physics_frame
			if exact:
				op.simulate(dt)
				tree.advance(dt)
			else:
				await process_frame
			if i >= 40:
				for f in 2:
					(samples[f] as Array).append(sk.global_transform * sk.get_bone_global_pose(feet[f]).origin)
		var dist := 0.0
		var frames := 0
		for f in 2:
			var low := INF
			for p: Vector3 in samples[f]:
				low = minf(low, p.y)
			for i in (samples[f] as Array).size() - 1:
				if (samples[f][i] as Vector3).y < low + 0.03:
					var d: Vector3 = samples[f][i + 1] - samples[f][i]
					dist += Vector2(d.x, d.z).length()
					frames += 1
		var slide: float = dist / maxf(frames * dt, dt)
		print("%-18s body %.2f m/s  planted foot slides %.2f m/s (%d%% of the body speed), planted %d%% of the time" % [
			c[0], op.model.speed, slide, roundi(slide / maxf(op.model.speed, 0.01) * 100.0),
			roundi(float(frames) / ((samples[0] as Array).size() * 2) * 100.0)])
		op.free()
	quit(0)
