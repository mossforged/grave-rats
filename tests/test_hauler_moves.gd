extends "res://tests/test_case.gd"
## T022: the Mixamo shooter set on the hauler. Every state has a clip, the eight directions pick the right clips
## and those clips step the way they're named, the upper body and flinches leave the legs alone, deaths move the
## body but not the player, and the choices of hit, death, sling and cover.

const OperatorBody := preload("res://src/player/operator_body.gd")
const HaulerClips := preload("res://src/player/hauler_clips.gd")
const Retarget := preload("res://src/player/hauler_retarget.gd")
const Moves := preload("res://src/player/hauler_moves.gd")
const Operator := preload("res://src/player/operator.gd")

## How much of the body's speed a planted foot may slide at. T009's best hauler case was 63% and its worst 102%,
## on a noisier clock; it set no number, so this holds the gain.
const SLIDE_LIMIT := 0.45

var _nodes: Array[Node] = []


func after_each() -> void:
	OperatorBody.forced = ""
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _cfg() -> Dictionary:
	return Data.load_data("hauler_anim")


func _spawn() -> Node3D:
	OperatorBody.forced = "hauler"
	var op: Node3D = Operator.new()
	_nodes.append(op)
	(Engine.get_main_loop() as SceneTree).root.add_child(op)
	op.input_enabled = false
	op.face_now(Vector3(0, 1.2, -100))
	op.aim_point = Vector3(0, 1.2, -100000)
	return op


## Steps the body and its clips by hand on one clock, inside physics frames so move_and_slide has its delta.
func _manual(op: Node3D) -> void:
	op.set_physics_process(false)
	op.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL


func _steps(op: Node3D, n: int) -> void:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var tree := Engine.get_main_loop() as SceneTree
	for i in n:
		await tree.physics_frame
		op.simulate(dt)
		op.anim.tree.advance(dt)


func _library(op: Node3D) -> AnimationLibrary:
	var player: AnimationPlayer = op.get_node("Model").find_children("*", "AnimationPlayer", true, false)[0]
	return player.get_animation_library("hauler")


func _bone_at(op: Node3D, bone: String) -> Vector3:
	var sk: Skeleton3D = op.anim.skeleton
	return sk.get_bone_global_pose(sk.find_bone(bone)).origin


## How far a foot ranges in the body's own space over `n` steps: legs that are walking range far.
func _foot_range(op: Node3D, n: int) -> float:
	var foot: String = _cfg().bones.feet[0]
	var low := Vector3.INF
	var high := -Vector3.INF
	for i in n:
		await _steps(op, 1)
		var at := _bone_at(op, foot)
		low = low.min(at)
		high = high.max(at)
	return (high - low).length()


func test_every_state_in_the_data_has_a_clip_that_loads() -> void:
	var op := _spawn()
	var lib := _library(op)
	for state: String in _cfg().states:
		check(lib.has_animation(state), "%s loaded" % state)
		if lib.has_animation(state):
			check(lib.get_animation(state).length > 0.0, "%s has length" % state)
	check(not HaulerClips.sources().values().any(func(s: String) -> bool: return s.begins_with("stand-in")),
		"nothing is standing in any more")


func test_the_tree_only_names_states_that_exist() -> void:
	var op := _spawn()
	var lib := _library(op)
	var root: AnimationNodeBlendTree = op.anim.tree.tree_root
	for n: StringName in root.get_node_list():
		var node := root.get_node(n)
		if node is AnimationNodeAnimation:
			var state := String((node as AnimationNodeAnimation).animation).trim_prefix("hauler/")
			check(lib.has_animation(state), "%s plays %s" % [n, state])


func test_the_nearest_direction_is_the_one_named() -> void:
	for n: String in Moves.EIGHT:
		check_eq(Moves.nearest(Moves.point(n)), n, n)
	check_eq(Moves.nearest(Vector2(0.1, 1.0)), "fwd", "a little off forward is forward")
	check_eq(Moves.nearest(Vector2(-1.0, -1.1)), "back_left", "and the diagonal behind")


## Move against aim, in the real operator. Each keypress, aimed three ways: the blend position sits on the clip
## with the name you'd say looking at the screen.
func test_move_against_aim_picks_the_right_blend_in_all_eight_directions() -> void:
	# keys (x right, y down) with the camera's yaw at 0, so screen-up is -Z.
	var keys := {"fwd": Vector2(0, -1), "fwd_right": Vector2(1, -1), "right": Vector2(1, 0), "back_right": Vector2(1, 1),
		"back": Vector2(0, 1), "back_left": Vector2(-1, 1), "left": Vector2(-1, 0), "fwd_left": Vector2(-1, -1)}
	var op := _spawn()
	_manual(op)
	var root: AnimationNodeBlendTree = op.anim.tree.tree_root
	for space: String in ["walk", "run"]:
		var blend: AnimationNodeBlendSpace2D = root.get_node(space)
		for i in blend.get_blend_point_count():
			var state := String((blend.get_blend_point_node(i) as AnimationNodeAnimation).animation).trim_prefix("hauler/")
			var dir_name := state.trim_prefix(space + "_")
			check(blend.get_blend_point_position(i).distance_to(Moves.point(dir_name)) < 0.001, "%s sits at its own direction" % state)
	# Aim up the screen: the keys say it directly.
	for n: String in keys:
		op.scripted = {"keys": keys[n]}
		await _steps(op, 30)
		var at: Vector2 = op.anim.tree.get("parameters/run/blend_position")
		check_eq(Moves.nearest(at), n, "aiming up the screen, moving %s" % n)
		check(at.distance_to(Moves.point(n)) < 0.05, "%s is on the clip, not between (%s)" % [n, at])
	# Aim right along the screen, and moving up the screen is moving to your left.
	op.scripted = {"keys": Vector2(0, -1)}
	op.aim_point = Vector3(100000, 1.2, 0)
	op.face_now(op.aim_point)
	await _steps(op, 30)
	check_eq(Moves.nearest(op.anim.tree.get("parameters/run/blend_position")), "left", "aiming right, moving up: strafing left")
	# Aim down the screen, and moving up the screen is backing away.
	op.aim_point = Vector3(0, 1.2, 100000)
	op.face_now(op.aim_point)
	await _steps(op, 30)
	check_eq(Moves.nearest(op.anim.tree.get("parameters/run/blend_position")), "back", "aiming down, moving up: backward")


## The leg blend is measured against the torso; the legs are drawn on the hips, a little behind it in a turn.
func test_the_legs_blend_against_the_hips_in_a_turn() -> void:
	var fwd := Vector2(0, 1)
	var hips_behind := Moves.on_hips(fwd, deg_to_rad(40.0))
	check(hips_behind.x > 0.5, "the torso's gone 40 degrees left of the hips: moving where it faces is the hips' right-forward (%s)" % hips_behind)
	check(hips_behind.y > 0.5, "still forward")


func test_each_direction_steps_the_way_it_is_named_at_its_data_speed() -> void:
	var op := _spawn()
	var lib := _library(op)
	var cfg := _cfg()
	var rest: Dictionary = op.anim.rest
	var scale: float = OperatorBody.fit_scale(op.get_node("Model").get_node("Hauler"), float(cfg.height_m)) * float(Data.value("deck", "character_scale", 1.0))
	for gait: String in ["walk", "run", "sprint", "crouch"]:
		var speeds: Dictionary = cfg.gaits.speeds_m_s[gait]
		var prefix := "crouch_walk_" if gait == "crouch" else gait + "_"
		for n: String in speeds:
			var p := Moves.point(n)
			# The hauler's file faces +Z, so its right is -X.
			var axis := Vector3(-p.x, 0, p.y)
			var v := Retarget.foot_speed(lib.get_animation(prefix + n), rest, cfg.skeleton_path, cfg.bones.feet, axis) * scale
			check(v > 0.0, "%s%s steps that way (%.2f m/s)" % [prefix, n, v])
			check(absf(v - float(speeds[n])) < float(speeds[n]) * 0.3, "%s%s: measured %.2f, data %.2f" % [prefix, n, v, float(speeds[n])])


func test_the_gaits_follow_speed() -> void:
	var g: Dictionary = _cfg().gaits
	var fwd := Vector2(0, 1)
	var slow: Dictionary = Moves.gaits(g, fwd, 1.0, 0.0, 3.2)
	check_eq(slow.run, 0.0, "a slow move is a walk")
	var full: Dictionary = Moves.gaits(g, fwd, 3.4, 0.0, 3.2)
	check_eq(full.run, 1.0, "the normal move is a run")
	check(absf(float(full.run_rate) - 3.4 / float(g.speeds_m_s.run.fwd)) < 0.001, "played at the ground speed")
	var sprint: Dictionary = Moves.gaits(g, fwd, 5.4, 1.0, 3.2)
	check_eq(sprint.sprint, 1.0, "the sprint is the sprint clip")
	check(absf(float(sprint.sprint_rate) - 5.4 / float(g.speeds_m_s.sprint.fwd)) < 0.001, "at its own speed")
	var back: Dictionary = Moves.gaits(g, Vector2(0, -1), 5.4, 1.0, 3.2)
	check_eq(back.sprint, 0.0, "no sprint clip goes backward: the run carries it")
	var mid: Dictionary = Moves.gaits(g, fwd, 2.4, 0.0, 3.2)
	check(absf(float(mid.walk_rate) / float(mid.run_rate) - float(g.cycle_s.walk) / float(g.cycle_s.run)) < 0.001,
		"walk and run keep step while they blend")
	check(float(Moves.gaits(g, fwd, 100.0, 0.0, 3.2).run_rate) <= 3.2001, "the rate is capped")
	check_eq(Moves.clip_speed(g.speeds_m_s.run, Vector2(0, 1)), float(g.speeds_m_s.run.fwd), "on a clip, its own speed")
	var between := Moves.clip_speed(g.speeds_m_s.run, Vector2(0.38, 0.92))
	check(between <= float(g.speeds_m_s.run.fwd) + 0.001 and between >= float(g.speeds_m_s.run.fwd_right) - 0.001, "between two, between them")


func test_planted_feet_do_not_slide() -> void:
	var cases := [["walk", Vector2(0, -1), false, false, 0.5], ["walk", Vector2(1, 1), false, false, 0.5],
		["run", Vector2(0, -1), false, false, 1.0], ["run", Vector2(-1, 0), false, false, 1.0],
		["run", Vector2(0, 1), false, false, 1.0], ["sprint", Vector2(0, -1), false, true, 1.0],
		["crouch", Vector2(1, 0), true, false, 1.0]]
	for c: Array in cases:
		var op := _spawn()
		_manual(op)
		op.scripted = {"keys": c[1], "crouch": c[2], "sprint": c[3]}
		op.model.speed_mult = c[4]
		await _steps(op, 40)
		var sk: Skeleton3D = op.anim.skeleton
		var foot: int = sk.find_bone(_cfg().bones.feet[0])
		var samples: Array[Vector3] = []
		for i in 120:
			await _steps(op, 1)
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
		var slide := dist / maxf(frames / float(Engine.physics_ticks_per_second), 0.001)
		check(slide < float(op.model.speed) * SLIDE_LIMIT, "%s %s: planted foot %.2f m/s at body %.2f" % [c[0], c[1], slide, op.model.speed])
		# Bodies left standing here would block the next one.
		_nodes.erase(op)
		op.free()


func test_reload_fire_and_hit_never_leave_the_legs_stuck() -> void:
	var op := _spawn()
	_manual(op)
	op.scripted = {"keys": Vector2(0, -1)}
	await _steps(op, 30)
	var walking: float = await _foot_range(op, 40)
	check(walking > 0.3, "walking, the foot ranges %.2f m" % walking)
	check(op.request_reload() or op.rifle.state.mag == op.rifle.state.cfg.magazine, "a reload")
	op.rifle.state.mag = 3
	check(op.request_reload(), "a reload")
	var reloading: float = await _foot_range(op, 40)
	check(reloading > walking * 0.7, "reloading, it still ranges %.2f m" % reloading)
	await _steps(op, 150)
	op.scripted = {"keys": Vector2(0, -1), "fire": true}
	var firing: float = await _foot_range(op, 40)
	check(firing > walking * 0.7, "firing, it still ranges %.2f m" % firing)
	op.scripted = {"keys": Vector2(0, -1)}
	op.note_hit_from(Vector2(0, -5))
	var flinching: float = await _foot_range(op, 40)
	check(flinching > walking * 0.7, "flinching, it still ranges %.2f m" % flinching)
	check(not op.control_held(), "and a flinch takes no control")
	check_eq(op.anim.over_state(), "", "and plays over nothing")


func test_a_flinch_adds_to_the_spine_and_leaves_the_feet() -> void:
	var op := _spawn()
	_manual(op)
	await _steps(op, 10)
	var sk: Skeleton3D = op.anim.skeleton
	var spine := sk.find_bone("mixamorig_Spine1")
	var before := sk.get_bone_pose_rotation(spine)
	var foot_before := sk.get_bone_pose_rotation(sk.find_bone(_cfg().bones.feet[0]))
	op.note_hit_from(Vector2(0, -5))
	var most := 0.0
	for i in 20:
		await _steps(op, 1)
		most = maxf(most, before.angle_to(sk.get_bone_pose_rotation(spine)))
	check(float(op.anim.tree.get("parameters/hit_add/add_amount")) > 0.0, "the flinch is on")
	check(most > deg_to_rad(1.0), "the spine moves %.1f degrees" % rad_to_deg(most))
	check(most < deg_to_rad(60.0), "on top of the pose, not through a T-pose (%.1f degrees)" % rad_to_deg(most))
	check(foot_before.angle_to(sk.get_bone_pose_rotation(sk.find_bone(_cfg().bones.feet[0]))) < deg_to_rad(8.0), "the feet stay")
	await _steps(op, 60)
	check_eq(op.anim.tree.get("parameters/hit_add/add_amount"), 0.0, "and it's over quickly")


func test_a_shot_restarts_the_firing_clip_the_same_step() -> void:
	var op := _spawn()
	_manual(op)
	await _steps(op, 5)
	var shots := [0]
	op.rifle.fired.connect(func(_a: Vector3, _b: Vector3, _c: Vector3, _d: Object) -> void: shots[0] += 1)
	var counted: int = op.anim._fire_count
	op.scripted = {"fire": true}
	for i in 30:
		await _steps(op, 1)
		check_eq(op.anim._fire_count - counted, shots[0], "step %d: one kick per round" % i)
	check(shots[0] >= 2, "it fired")
	check(float(op.anim.tree.get("parameters/firing/blend_amount")) > 0.9, "the upper body's in the firing clip")
	check(op.anim.twist.arm_kick_deg != 0.0 or op.rifle.state.arm_kick == 0.0, "the arm kick is still on top")
	var f: Dictionary = _cfg().fire.fire
	var want: float = float(f.frames_per_shot) / 30.0 / float(Data.value("weapons", "rifle").fire_interval_s)
	check(absf(float(op.anim.tree.get("parameters/fire_rate/scale")) - want) < 0.001, "one kick lasts one round")
	op.scripted = {}
	await _steps(op, 60)
	check_eq(op.anim.tree.get("parameters/firing/blend_amount"), 0.0, "and it lets go")


func test_every_firing_clip_has_its_marks_inside_it() -> void:
	var op := _spawn()
	var lib := _library(op)
	for state: String in _cfg().fire:
		var length := lib.get_animation(state).length
		for f: Variant in _cfg().fire[state].shot_frames:
			check(float(f) / 30.0 < length, "%s frame %d is inside" % [state, f])


func test_the_reloads_share_one_timeline_with_the_sounds() -> void:
	var op := _spawn()
	var lib := _library(op)
	var cfg := _cfg()
	var length := float(cfg.anim.reload_clip_s)
	var stages: Array = Data.value("audio", "reload_stages")
	for state: String in ["reload", "reload_walking", "reload_crouch"]:
		check(absf(lib.get_animation(state).length - length) < 0.001, "%s is %.2f s long" % [state, length])
		var marks: Dictionary = cfg.states[state].marks
		var last := -1.0
		for key: String in ["start", "mag_out", "mag_drop", "mag_in", "charge", "end"]:
			check(float(marks[key]) > last, "%s: %s comes in order" % [state, key])
			last = float(marks[key])
		check(last / 30.0 <= _source_seconds(state) + 0.05, "%s: its marks fit the file" % state)
	for s: Dictionary in stages:
		check(s.has("mark"), "%s says which moment it is" % s)
	# A moment on the source frame must play at the stage's share: the warp itself.
	var clip := Animation.new()
	clip.length = 2.0
	var t := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(t, "Sk:Hips")
	clip.position_track_insert_key(t, 0.0, Vector3.ZERO)
	clip.position_track_insert_key(t, 2.0, Vector3(2, 0, 0))
	var bent := Retarget.warped(clip, [0.0, 0.5, 2.0], [0.0, 1.0, 3.0], 30.0)
	check_eq(bent.length, 3.0, "as long as asked")
	check(absf(bent.position_track_interpolate(0, 1.0).x - 0.5) < 0.01, "the moment lands where it was told")


func _source_seconds(state: String) -> float:
	var path: String = _cfg().clip_dir + _cfg().states[state].source
	var scene: Node = (load(path) as PackedScene).instantiate()
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var longest := 0.0
	for a: StringName in ap.get_animation_list():
		longest = maxf(longest, ap.get_animation(a).length)
	scene.free()
	return longest


func test_the_reload_fits_the_data_and_picks_up_the_gait() -> void:
	var op := _spawn()
	_manual(op)
	await _steps(op, 5)
	op.rifle.state.mag = 2
	op.request_reload()
	await _steps(op, 2)
	var want := float(_cfg().anim.reload_clip_s) / float(op.rifle.state.reload_total)
	check(absf(float(op.anim.tree.get("parameters/reload_rate/scale")) - want) < 0.001, "stretched to reload_s")
	check_eq(op.anim.tree.get("parameters/reload_moving/blend_amount"), 0.0, "standing: the standing reload")
	op.scripted = {"keys": Vector2(0, -1)}
	await _steps(op, 20)
	check_eq(op.anim.tree.get("parameters/reload_moving/blend_amount"), 1.0, "walking: the walking one")
	op.scripted = {"keys": Vector2.ZERO, "crouch": true}
	await _steps(op, 30)
	check_eq(op.anim.tree.get("parameters/reload_pose/blend_amount"), 1.0, "crouched: the crouched one")


func test_a_hit_is_named_by_where_it_came_from() -> void:
	# Facing -Z at yaw 0: its right is +X.
	check_eq(Moves.side(Vector2(0, -1), 0.0, 0.5), "front", "ahead")
	check_eq(Moves.side(Vector2(0, 1), 0.0, 0.5), "back", "behind")
	check_eq(Moves.side(Vector2(1, 0), 0.0, 0.5), "right", "right")
	check_eq(Moves.side(Vector2(-1, 0), 0.0, 0.5), "left", "left")
	check_eq(Moves.side(Vector2(1, 0), -PI / 2.0, 0.5), "front", "facing +X, it's ahead")
	check_eq(Moves.side(Vector2.ZERO, 0.0, 0.5), "front", "on top of you: front")
	check_eq(Moves.hit_state("left", false, false), "hit_left", "by side")
	check_eq(Moves.hit_state("left", true, false), "hit_head", "the head wins")
	check_eq(Moves.hit_state("left", false, true), "hit_rifle", "gun up: the rifle's react")
	check_eq(Moves.hit_state("left", true, true), "hit_head", "the head still wins")
	check_eq(Moves.death_state("back", false), "death_forward", "shot from behind: forward")
	check_eq(Moves.death_state("front", false), "death_backward", "from the front: backward")
	check_eq(Moves.death_state("left", false), "death", "from the side: the plain one")
	check_eq(Moves.death_state("back", true), "death_headshot", "the head wins")


func test_the_death_clips_fall_the_way_they_are_named() -> void:
	var op := _spawn()
	var lib := _library(op)
	var cfg := _cfg()
	var hips: String = cfg.bones.hips
	for pair: Array in [["death_forward", 1.0], ["death_backward", -1.0]]:
		var clip := lib.get_animation(pair[0])
		var start: Vector3 = Retarget.fk(clip, op.anim.rest, cfg.skeleton_path, 0.0, ["mixamorig_Head"])["mixamorig_Head"]
		var end: Vector3 = Retarget.fk(clip, op.anim.rest, cfg.skeleton_path, clip.length, ["mixamorig_Head"])["mixamorig_Head"]
		# The hauler's file faces +Z.
		check((end - start).z * float(pair[1]) > 0.1, "%s: the head ends %.2f m along its facing" % [pair[0], (end - start).z])
		check(end.y < start.y - 0.4, "%s: and goes down (%.2f to %.2f)" % [pair[0], start.y, end.y])
	check(hips != "", "the hips are named")


func test_the_last_blow_picks_the_death_and_the_body_stays_put() -> void:
	var op := _spawn()
	_manual(op)
	await _steps(op, 5)
	op.note_hit_from(Vector2(0, 5))
	op.hold_control(INF)
	check_eq(op.anim.over_state(), "death", "dead")
	check_eq(op.anim.death_kind(), "death_forward", "shot from behind, it falls forward")
	var stood: Vector3 = op.global_position
	var hips: String = _cfg().bones.hips
	var start := _bone_at(op, hips)
	await _steps(op, 150)
	check(op.global_position.distance_to(stood) < 0.001, "the player stays where it fell")
	check(Vector2(_bone_at(op, hips).x - start.x, _bone_at(op, hips).z - start.z).length() > 0.05 or _bone_at(op, hips).y < start.y - 0.1, "while the body moves")
	op.release_control()
	check_eq(op.anim.death_kind(), "", "a respawn gets up")
	op.note_hit_from(Vector2(0, -5), 3.0)
	op.hold_control(INF)
	check_eq(op.anim.death_kind(), "death_headshot", "above the neck: the head")
	op.release_control()
	op.note_hit_from(Vector2(0, -5))
	await _steps(op, 60)
	op.hold_control(INF)
	check_eq(op.anim.death_kind(), "death", "a blow a second ago didn't do this: the plain one")
	op.release_control()
	op.hold_control(INF)
	check_eq(op.anim.death_kind(), "death", "no blow at all: the plain one")


func test_an_action_plays_on_the_hands_and_moving_cuts_it_short() -> void:
	var op := _spawn()
	_manual(op)
	await _steps(op, 5)
	op.play_action("pick_up")
	check_eq(op.anim.action(), "pick_up", "it plays")
	await _steps(op, 5)
	check(op.anim._lock < 1.0, "the gun lets go of the aim")
	op.scripted = {"keys": Vector2(0, -1)}
	await _steps(op, 20)
	check_eq(op.anim.action(), "", "moving cuts it short")
	op.scripted = {}
	await _steps(op, 20)
	op.play_action("interact")
	await _steps(op, int(float(_cfg().actions.interact.seconds) * Engine.physics_ticks_per_second) + 2)
	check_eq(op.anim.action(), "", "and it ends by itself")


func test_a_heavy_load_slings_the_rifle_and_walks_unarmed() -> void:
	var op := _spawn()
	_manual(op)
	await _steps(op, 5)
	var mount: BoneAttachment3D = op.anim.skeleton.find_children("*", "BoneAttachment3D", false, false)[0]
	check_eq(mount.bone_name, _cfg().bones.hand_right, "in the hand")
	var free_hands := {"speed_mult": 1.0, "can_sprint": true, "can_fire": true, "cone_extra_deg": 0.0}
	var heavy := {"speed_mult": 0.65, "can_sprint": false, "can_fire": false, "cone_extra_deg": 0.0}
	op.set_carry(heavy)
	check(op.anim.carrying(), "both hands full")
	check_eq(mount.bone_name, _cfg().rifle.sling.bone, "the rifle's on the back")
	op.scripted = {"keys": Vector2(0, -1)}
	await _steps(op, 40)
	check_eq(op.anim.tree.get("parameters/carry_mix/blend_amount"), 1.0, "the carry clips have the body")
	check(float(op.anim.tree.get("parameters/carry_rate/scale")) > 0.0, "walking forward plays forward")
	op.scripted = {"keys": Vector2(0, 1)}
	await _steps(op, 40)
	check(float(op.anim.tree.get("parameters/carry_rate/scale")) < 0.0, "backing up plays it backward")
	op.set_carry(free_hands)
	check(not op.anim.carrying(), "put it down")
	check_eq(mount.bone_name, _cfg().bones.hand_right, "the rifle's back in the hand")
	op.scripted = {}
	await _steps(op, 30)
	check_eq(op.anim.tree.get("parameters/carry_mix/blend_amount"), 0.0, "and the clips let go")


func test_the_lock_holds_the_cover_pose_and_letting_go_steps_out() -> void:
	var op := _spawn()
	_manual(op)
	await _steps(op, 5)
	op.anim.set_cover(1.0, true)
	await _steps(op, 20)
	check_eq(op.anim.tree.get("parameters/cover_mix/blend_amount"), 1.0, "down behind it")
	op.anim.set_cover(0.0, true)
	await _steps(op, 20)
	check_eq(op.anim.tree.get("parameters/cover_mix/blend_amount"), 0.0, "braced over it, the aiming pose")
	op.anim.set_cover(0.0, false)
	check_eq(op.anim.action(), "cover_to_stand", "letting go steps out")


func test_the_pirates_wear_the_same_states() -> void:
	OperatorBody.forced = "hauler"
	var scene: Node = (load("res://scenes/pirates/pirate_deck.tscn") as PackedScene).instantiate()
	_nodes.append(scene)
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var q: Node = scene.squad.pirates[0]
	check(q.anim.has_method("note_shot"), "the same body")
	check_eq(_library_of(q), _library(scene.operator), "the same clips, shared")
	var count: int = q.anim._fire_count
	q.anim.note_shot()
	check_eq(q.anim._fire_count, count + 1, "a shot kicks it")
	var yaw: float = q.brain.model.torso_yaw
	var ahead := Vector2(-sin(yaw), -cos(yaw)) * 5.0
	q.take_hit({"damage": 1000.0, "point": q.global_position + Vector3.UP, "direction": Vector3.FORWARD,
		"origin": q.global_position + Vector3(ahead.x, 0, ahead.y)})
	check_eq(q.anim.over_state(), "death", "a killing round drops it")
	check_eq(q.anim.death_kind(), "death_backward", "backward, from the front")


func _library_of(q: Node) -> AnimationLibrary:
	var player: AnimationPlayer = q.get_node("Model").find_children("*", "AnimationPlayer", true, false)[0]
	return player.get_animation_library("hauler")
