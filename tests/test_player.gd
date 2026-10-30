extends "res://tests/test_case.gd"
## T003 operator weight: turn rate, torso/hips split, acceleration, speed before the move,
## collision, the leg animation, and "the intent responds the same step".

const OperatorModel := preload("res://src/player/operator_model.gd")
const Operator := preload("res://src/player/operator.gd")
const DT := 1.0 / 60.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _cfg() -> Dictionary:
	return (Data.load_data("player") as Dictionary).duplicate(true)


func _turn_time(m: OperatorModel, to_yaw: float, crouch: bool, shooting: bool) -> float:
	var t := 0.0
	while absf(wrapf(to_yaw - m.torso_yaw, -PI, PI)) > 0.0001 and t < 10.0:
		if shooting:
			m.note_shot()
		m.step(DT, Vector2.ZERO, to_yaw, crouch, false)
		t += DT
	return t


func test_180_turn_takes_180_over_rate_within_a_frame() -> void:
	var cases := [
		["standing_deg_s", false, false],
		["firing_deg_s", false, true],
		["crouched_deg_s", true, false],
	]
	for c: Array in cases:
		var cfg := _cfg()
		var m := OperatorModel.new(cfg)
		if c[1]:
			for i in 60:
				m.step(DT, Vector2.ZERO, 0.0, true, false)
		var t := _turn_time(m, PI, c[1], c[2])
		var want: float = 180.0 / float(cfg.turn[c[0]])
		check(absf(t - want) <= DT, "%s: 180° took %.3f s, want %.3f" % [c[0], t, want])


func test_firing_never_speeds_up_a_slower_stance() -> void:
	var cfg := _cfg()
	var m := OperatorModel.new(cfg)
	for i in 60:
		m.step(DT, Vector2.ZERO, 0.0, true, false)
	m.note_shot()
	check_eq(m.current_turn_rate_deg(), minf(float(cfg.turn.crouched_deg_s), float(cfg.turn.firing_deg_s)), "crouched and firing")


func test_torso_leads_within_limit_then_legs_turn() -> void:
	var cfg := _cfg()
	var m := OperatorModel.new(cfg)
	var limit := deg_to_rad(float(cfg.turn.torso_lead_deg))
	m.step(DT, Vector2.ZERO, deg_to_rad(30.0), false, false)
	check_eq(m.hips_yaw, 0.0, "hips stay planted inside the limit")
	check(m.torso_yaw > 0.0, "torso started turning")
	var worst := 0.0
	for i in 120:
		m.step(DT, Vector2.ZERO, deg_to_rad(170.0), false, false)
		worst = maxf(worst, absf(m.torso_lead()))
	check(worst <= limit + 0.0001, "lead capped at %.1f° (got %.1f°)" % [rad_to_deg(limit), rad_to_deg(worst)])
	check(absf(m.hips_yaw) > 0.1, "legs turned once the torso ran out of lead")


func test_walking_brings_hips_back_under_torso() -> void:
	var m := OperatorModel.new(_cfg())
	m.hips_yaw = deg_to_rad(-50.0)
	for i in 60:
		m.step(DT, Vector2(0, -1), 0.0, false, false)
	check(absf(m.torso_lead()) < 0.001, "lead gone after walking (%.3f)" % m.torso_lead())


func test_accel_and_decel_take_their_times() -> void:
	var cfg := _cfg()
	var m := OperatorModel.new(cfg)
	var walk := float(cfg.move.walk_speed_m_s)
	var t := 0.0
	while m.speed < walk and t < 5.0:
		m.step(DT, Vector2(0, -1), 0.0, false, false)
		t += DT
	check(absf(t - float(cfg.move.accel_s)) <= DT * 1.01, "up to speed in %.3f s" % t)
	t = 0.0
	while m.speed > 0.0 and t < 5.0:
		m.step(DT, Vector2.ZERO, 0.0, false, false)
		t += DT
	check(absf(t - float(cfg.move.decel_s)) <= DT * 1.01, "stopped in %.3f s" % t)


func test_speeds_walk_crouch_sprint() -> void:
	var cfg := _cfg()
	for c: Array in [[false, false, "walk_speed_m_s"], [true, false, "crouch_speed_m_s"], [false, true, "sprint_speed_m_s"]]:
		var m := OperatorModel.new(cfg)
		for i in 120:
			m.step(DT, Vector2(0, -1), 0.0, c[0], c[1])
		check(is_equal_approx(m.speed, float(cfg.move[c[2]])), "%s reached (%.2f)" % [c[2], m.speed])


func test_sprint_needs_movement_and_no_crouch() -> void:
	var m := OperatorModel.new(_cfg())
	m.step(DT, Vector2.ZERO, 0.0, false, true)
	check(not m.sprinting, "holding sprint while standing still is not sprinting")
	m.step(DT, Vector2(0, -1), 0.0, true, true)
	check(not m.sprinting, "crouch beats sprint")
	for i in 60:
		m.step(DT, Vector2.ZERO, 0.0, false, false)
	m.step(DT, Vector2(0, -1), 0.0, false, true)
	check(m.sprinting, "sprint with a move held, once fully up")


func test_stand_up_takes_its_time() -> void:
	var cfg := _cfg()
	var m := OperatorModel.new(cfg)
	for i in 60:
		m.step(DT, Vector2.ZERO, 0.0, true, false)
	var t := 0.0
	while m.crouch_amount > 0.0 and t < 5.0:
		m.step(DT, Vector2.ZERO, 0.0, false, false)
		t += DT
	check(absf(t - float(cfg.crouch.stand_up_s)) <= DT * 1.01, "stood up in %.3f s" % t)


func test_intent_responds_on_the_first_step() -> void:
	var m := OperatorModel.new(_cfg())
	m.step(DT, Vector2(1, 0), PI, true, false)
	check(m.speed > 0.0, "speed changes the first step")
	check(absf(m.torso_yaw) > 0.0, "torso starts turning the first step")
	check(m.crouch_amount > 0.0, "knees start bending the first step")


func test_leg_blend_is_relative_to_the_torso() -> void:
	var m := OperatorModel.new(_cfg())
	for i in 60:
		m.step(DT, Vector2(0, -1), 0.0, false, false)
	check(m.leg_blend().distance_to(Vector2(0, 1)) < 0.01, "walking at the aim = forward (%s)" % m.leg_blend())
	m = OperatorModel.new(_cfg())
	for i in 60:
		m.step(DT, Vector2(0, 1), 0.0, false, false)
	check(m.leg_blend().distance_to(Vector2(0, -1)) < 0.01, "walking away = back (%s)" % m.leg_blend())
	m = OperatorModel.new(_cfg())
	for i in 60:
		m.step(DT, Vector2(1, 0), 0.0, false, false)
	check(m.leg_blend().distance_to(Vector2(1, 0)) < 0.01, "walking east, aiming north = strafe right (%s)" % m.leg_blend())
	m = OperatorModel.new(_cfg())
	m.face_now(deg_to_rad(90.0))
	for i in 60:
		m.step(DT, Vector2(-1, 0), deg_to_rad(90.0), false, false)
	check(m.leg_blend().distance_to(Vector2(0, 1)) < 0.01, "aiming and walking west = forward (%s)" % m.leg_blend())


func test_numbers_come_from_data() -> void:
	var cfg := _cfg()
	cfg.turn.standing_deg_s = 90.0
	cfg.move.walk_speed_m_s = 1.0
	var m := OperatorModel.new(cfg)
	check(absf(_turn_time(m, PI, false, false) - 2.0) <= DT, "edited turn rate changes the turn")
	for i in 60:
		m.step(DT, Vector2(0, -1), 0.0, false, false)
	check(is_equal_approx(m.speed, 1.0), "edited walk speed changes the speed")


func _spawn_operator() -> Operator:
	var tree := Engine.get_main_loop() as SceneTree
	var op := Operator.new()
	tree.root.add_child(op)
	_nodes.append(op)
	op.input_enabled = false
	return op


## Regression for the prototype's walk bug: speed measured after the move, so it read zero.
func test_speed_is_computed_before_the_move() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var walk := float(_cfg().move.walk_speed_m_s)
	var op := _spawn_operator()
	# A wall directly ahead: the body can't move at all, the walk still animates.
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.5)
	cs.shape = box
	wall.add_child(cs)
	wall.position = Vector3(0, 1.5, -0.7)
	tree.root.add_child(wall)
	_nodes.append(wall)
	await tree.physics_frame
	await tree.physics_frame
	var start := op.global_position
	op.scripted = {"keys": Vector2(0, -1)}
	op.simulate(DT)
	check(op.anim_speed > 0.0, "animation speed is non-zero on the first step")
	check(is_equal_approx(op.anim_speed, op.model.speed), "animation reads the model's speed")
	for i in 30:
		op.simulate(DT)
	check(is_equal_approx(op.anim_speed, walk), "pushing a wall still reads walk speed (%.2f)" % op.anim_speed)
	check(op.global_position.distance_to(start) < 0.25, "and the wall really stopped it (%.2f)" % op.global_position.distance_to(start))
	check(op.anim.tree.get("parameters/legs/blend_position").length() > 0.9, "the leg blend got that speed")


func test_operator_collides_with_a_wall() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var op := _spawn_operator()
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 3, 0.5)
	cs.shape = box
	wall.add_child(cs)
	wall.position = Vector3(0, 1.5, -2.0)
	tree.root.add_child(wall)
	_nodes.append(wall)
	await tree.physics_frame
	await tree.physics_frame
	op.scripted = {"keys": Vector2(0, -1)}
	for i in 120:
		await tree.physics_frame
	check(op.global_position.z > -1.75 - 0.01 + 0.0, "stopped at the wall (z = %.2f)" % op.global_position.z)
	check(op.global_position.z < -0.5, "walked up to it (z = %.2f)" % op.global_position.z)


func test_legs_animate_while_walking() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var op := _spawn_operator()
	var sk := op.anim.skeleton
	var thigh := sk.find_bone("thigh_L")
	op.scripted = {"keys": Vector2(0, -1)}
	var lo := INF
	var hi := -INF
	for i in 60:
		await tree.physics_frame
		await tree.process_frame
		var q := sk.get_bone_pose_rotation(thigh)
		lo = minf(lo, q.get_euler().x)
		hi = maxf(hi, q.get_euler().x)
	check(hi - lo > 0.3, "thigh swings while walking (%.2f rad)" % (hi - lo))


func test_torso_twist_reaches_the_gun() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var op := _spawn_operator()
	op.aim_point = Vector3(-5, 1.2, 0)  # 90° left: the torso runs out of lead and drags the hips
	op.scripted = {}
	for i in 90:
		await tree.physics_frame
		await tree.process_frame
	check(absf(op.model.torso_lead()) > deg_to_rad(10.0), "torso leads the hips (%.1f°)" % rad_to_deg(op.model.torso_lead()))
	var muzzle := op.muzzle_position() - op.global_position
	var yaw := atan2(-muzzle.x, -muzzle.z)
	check(absf(wrapf(yaw - op.model.torso_yaw, -PI, PI)) < deg_to_rad(15.0),
		"muzzle is along the torso (%.1f° vs %.1f°)" % [rad_to_deg(yaw), rad_to_deg(op.model.torso_yaw)])


func test_cone_stops_where_shots_stop() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var op := _spawn_operator()
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 3, 0.5)
	cs.shape = box
	wall.add_child(cs)
	wall.position = Vector3(0, 1.5, -3.0)
	tree.root.add_child(wall)
	_nodes.append(wall)
	await tree.physics_frame
	await tree.physics_frame
	check(absf(op.shot_reach(0.0) - 2.75) < 0.01, "stops at the wall (%.2f)" % op.shot_reach(0.0))
	check_eq(op.shot_reach(PI), float(op.rifle.state.cfg.range_m), "open the other way")


func test_weight_deck_scene_runs_and_fires() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node = (load("res://scenes/player/weight_deck.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	check_eq(scene.targets.size(), 6, "six targets")
	var op: Operator = scene.operator
	op.input_enabled = false
	scene.aim_from_mouse = false
	await tree.physics_frame
	await tree.physics_frame
	var t: Node3D = scene.targets[0]
	op.face_now(Vector3(t.global_position.x, 1.2, t.global_position.z))
	var start: int = op.rifle.state.mag
	op.scripted = {"fire": true, "keys": Vector2(0, -1)}
	for i in 30:
		await tree.physics_frame
		await tree.process_frame
	check(op.rifle.state.mag < start, "rounds were fired (%d)" % op.rifle.state.mag)
	check(op.anim_speed > 0.0, "walking")
	op.scripted = {}
	check(scene.panel != null and not scene.panel.visible, "tuning panel is there, closed")
	scene.panel.toggle()
	check(scene.panel.visible, "tuning panel opens")
	scene.respawn()
	check_eq(op.rifle.state.mag, int(op.rifle.state.cfg.magazine), "respawn refills the magazine")
	check_eq(op.rifle.state.reserve, int(op.rifle.state.cfg.reserve), "and the reserve")


## A planted foot has to travel against the body. Guards the legacy strafe clips' swapped names.
func test_strafing_plants_the_feet_against_the_move() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for side: float in [1.0, -1.0]:
		var op := _spawn_operator()
		op.face_now(Vector3(0, 1.2, -100))
		op.aim_point = Vector3(0, 1.2, -100000)
		op.scripted = {"keys": Vector2(side, 0)}
		for i in 40:
			await tree.physics_frame
		var sk := op.anim.skeleton
		var foot := sk.find_bone("foot_L")
		var samples: Array[Vector3] = []
		for i in 120:
			await tree.physics_frame
			await tree.process_frame
			samples.append(sk.get_bone_global_pose(foot).origin)
		var low := INF
		for p in samples:
			low = minf(low, p.y)
		var along := 0.0
		for i in samples.size() - 1:
			if samples[i].y < low + 0.03:
				along += samples[i + 1].x - samples[i].x
		check(along * side < 0.0, "moving %+.0f in x, the planted foot goes the other way (%.2f m)" % [side, along])
		op.free()


## T006, John's corkscrew: the idle clips held each thigh half a turn from the walk clips, and the
## blend into a crouch swung each foot in a loop around the body.
func test_crouching_from_standing_does_not_swing_the_legs_around() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var op: Node3D = (load("res://src/player/operator.gd") as GDScript).new()
	tree.root.add_child(op)
	op.input_enabled = false
	op.face_now(Vector3(0, 1.2, -100))
	var sk: Skeleton3D = op.anim.skeleton
	var foot: int = sk.find_bone("foot_L")
	for i in 20:
		await tree.physics_frame
	await tree.process_frame
	var start: Vector3 = sk.get_bone_global_pose(foot).origin
	var furthest := 0.0
	op.scripted = {"crouch": true}
	for i in 24:
		await tree.physics_frame
		await tree.process_frame
		var at: Vector3 = sk.get_bone_global_pose(foot).origin
		furthest = maxf(furthest, Vector2(at.x - start.x, at.z - start.z).length())
	var end: Vector3 = sk.get_bone_global_pose(foot).origin
	var settled := Vector2(end.x - start.x, end.z - start.z).length()
	check(furthest <= settled + 0.03, "the foot goes straight to its crouched place: strayed %.2f m, ends %.2f m away" % [furthest, settled])
	op.free()


func test_a_second_operator_does_not_untwist_the_shared_clips_again() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var a: Node3D = (load("res://src/player/operator.gd") as GDScript).new()
	tree.root.add_child(a)
	var clip: Animation = a.anim.tree.get_animation("L_Idle")
	var track := clip.find_track(NodePath("Rig/Skeleton3D:thigh_L"), Animation.TYPE_ROTATION_3D)
	var once: Quaternion = clip.track_get_key_value(track, 0)
	var b: Node3D = (load("res://src/player/operator.gd") as GDScript).new()
	tree.root.add_child(b)
	var twice: Quaternion = clip.track_get_key_value(track, 0)
	check(once.is_equal_approx(twice), "the clip is the same after a second operator")
	a.free()
	b.free()
