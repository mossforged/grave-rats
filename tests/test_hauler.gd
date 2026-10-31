extends "res://tests/test_case.gd"
## T009: John's hauler replaces the grey operator. Height, the clip for each state, no root motion,
## the rifle on the hand, the pirates' paint, the data switch.

const OperatorBody := preload("res://src/player/operator_body.gd")
const HaulerClips := preload("res://src/player/hauler_clips.gd")
const Retarget := preload("res://src/player/hauler_retarget.gd")
const PirateRecolour := preload("res://src/pirates/pirate_recolour.gd")
const Operator := preload("res://src/player/operator.gd")

## Every animation state in the packet, as named in the data.
const PACKET_STATES := ["idle", "walk_forward", "walk_back", "strafe_left", "strafe_right", "run", "sprint",
	"turn_left", "turn_right", "crouch_idle", "crouch_walk", "aim", "fire", "reload", "roll", "hit", "death"]

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


func _frames(n: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in n:
		await tree.physics_frame
		await tree.process_frame


func _library(op: Node3D) -> AnimationLibrary:
	var player: AnimationPlayer = op.get_node("Model").find_children("*", "AnimationPlayer", true, false)[0]
	return player.get_animation_library("hauler")


func test_the_data_switch_picks_the_body() -> void:
	OperatorBody.forced = "legacy"
	var old: Node3D = Operator.new()
	_nodes.append(old)
	(Engine.get_main_loop() as SceneTree).root.add_child(old)
	check(old.get_node("Model").find_child("Shotgun", true, false) != null, "the switch gives the legacy operator")
	check(old.anim.play_state("death") == false, "which has no states over the top")
	OperatorBody.forced = ""
	check_eq(OperatorBody.kind("hauler"), "hauler", "the data decides when nothing is forced")
	check_eq(OperatorBody.kind("legacy"), "legacy", "either way")
	var op := _spawn()
	check(op.get_node("Model").find_child("Hauler", false, false) != null, "the hauler")


func test_height_matches_the_data_with_feet_on_the_floor() -> void:
	var op := _spawn()
	var inner: Node3D = op.get_node("Model").get_node("Hauler")
	var mesh: MeshInstance3D = inner.find_children("*", "MeshInstance3D", true, false)[0]
	var aabb: AABB = mesh.mesh.get_aabb()
	var height: float = aabb.size.y * inner.scale.y
	check(absf(height - float(_cfg().height_m)) < 0.005, "rest height %.3f m" % height)
	check(absf(aabb.position.y) < 0.005, "the soles are at the origin (%.3f)" % aabb.position.y)
	op.set_character_scale(1.15)
	var shown: float = aabb.size.y * inner.scale.y * op.get_node("Model").scale.y
	check(absf(shown - float(_cfg().height_m) * 1.15) < 0.005, "the character scale goes on top (%.3f)" % shown)


func test_each_state_resolves_to_a_clip_or_a_declared_stand_in() -> void:
	var op := _spawn()
	var lib := _library(op)
	var sources := HaulerClips.sources()
	var states: Dictionary = _cfg().states
	for state: String in PACKET_STATES:
		check(states.has(state), "%s is in the data" % state)
		if not states.has(state):
			continue
		var has_clip := lib.has_animation(state)
		var spec: Dictionary = states[state]
		check(has_clip or spec.has("stand_in"), "%s has a clip or says what stands in" % state)
		check(sources.has(state) or spec.get("source", "") == "", "%s says where it came from" % state)


func test_a_new_file_named_for_a_state_takes_it_over() -> void:
	var cfg := _cfg().duplicate(true)
	cfg.clip_dir = "res://assets/game/hauler/"
	var key: String = HaulerClips._source_key("reload", {"source": "Walking"}, cfg)
	check_eq(key, "hauler-reload.fbx", "hauler-reload.fbx beats what the data says")
	check_eq(HaulerClips._source_key("run", {"source": "Running"}, cfg), "Running", "no file: the data")


## Nothing uses it today, every state has a better clip, but it's the fallback the packet asks for.
func test_a_legacy_clip_can_be_carried_onto_the_hauler() -> void:
	var op := _spawn()
	var cfg := _cfg()
	var rest: Dictionary = op.anim.rest
	var clip: Animation = HaulerClips._from_legacy("U_LowReady", cfg, rest)
	check(clip != null and clip.length > 0.0, "it makes a clip")
	var hand: String = cfg.bones.hand_right
	var at: Vector3 = Retarget.fk(clip, rest, cfg.skeleton_path, 0.0, [hand])[hand]
	var rest_at: Vector3 = rest.world_pos[rest.index[hand]]
	check(at.distance_to(rest_at) > 0.2, "and the arm moves out of the rest pose")
	check(at.y > 0.5 and at.y < 1.7, "with the hand at body height (%.2f)" % at.y)
	check(HaulerClips._from_legacy("no such clip", cfg, rest) == null, "a clip that isn't there is nothing")


func test_no_clip_moves_the_hips_horizontally() -> void:
	var op := _spawn()
	var lib := _library(op)
	var path := "%s:%s" % [_cfg().skeleton_path, _cfg().bones.hips]
	for state: StringName in lib.get_animation_list():
		var clip := lib.get_animation(state)
		check(clip.find_track(NodePath(path), Animation.TYPE_POSITION_3D) >= 0, "%s has a hips track" % state)
		check(Retarget.hip_travel(clip, path) < 0.0005, "%s stays put (%.3f m)" % [state, Retarget.hip_travel(clip, path)])


func test_stripping_removes_travel_and_keeps_the_bounce() -> void:
	var clip := Animation.new()
	clip.length = 1.0
	var t := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(t, "Sk:Hips")
	clip.position_track_insert_key(t, 0.0, Vector3(0.1, 0.9, 0.2))
	clip.position_track_insert_key(t, 1.0, Vector3(0.5, 1.0, 3.0))
	check(Retarget.hip_travel(clip, "Sk:Hips") > 2.0, "it moves first")
	Retarget.strip_hip_travel(clip, "Sk:Hips")
	check_eq(Retarget.hip_travel(clip, "Sk:Hips"), 0.0, "then it doesn't")
	check_eq(clip.track_get_key_value(t, 1), Vector3(0.1, 1.0, 0.2), "the height stays")


func test_stripping_the_turn_keeps_the_hips_facing() -> void:
	var clip := Animation.new()
	clip.length = 1.0
	var t := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(t, "Sk:Hips")
	var lean := Quaternion(Vector3.RIGHT, 0.2)
	clip.rotation_track_insert_key(t, 0.0, lean)
	clip.rotation_track_insert_key(t, 1.0, Quaternion(Vector3.UP, 1.5) * lean)
	Retarget.strip_hip_yaw(clip, "Sk:Hips")
	check((clip.track_get_key_value(t, 1) as Quaternion).is_equal_approx(lean), "the turn is gone, the lean is not")


## A clip made on Mixamo's body must not leave the hauler floating or in the floor.
func test_retargeted_clips_stand_on_the_floor() -> void:
	var op := _spawn()
	var lib := _library(op)
	var cfg := _cfg()
	var rest: Dictionary = op.anim.rest
	var ankle: float = rest.world_pos[rest.index[cfg.bones.feet[0]]].y
	for state: String in ["idle", "crouch_idle", "crouch_walk", "strafe_left", "strafe_right"]:
		var low: float = Retarget.lowest(lib.get_animation(state), rest, cfg.skeleton_path, cfg.bones.feet)
		check(absf(low - ankle) < 0.02, "%s: lowest ankle %.3f, rest %.3f" % [state, low, ankle])


func test_the_strafe_clips_step_the_way_they_are_named() -> void:
	var op := _spawn()
	var lib := _library(op)
	var cfg := _cfg()
	var rest: Dictionary = op.anim.rest
	# The hauler's file faces +Z, so its right is -X. foot_speed is positive when the body goes along the axis.
	var to_right: float = Retarget.foot_speed(lib.get_animation("strafe_right"), rest, cfg.skeleton_path, cfg.bones.feet, Vector3(-1, 0, 0))
	var to_left: float = Retarget.foot_speed(lib.get_animation("strafe_left"), rest, cfg.skeleton_path, cfg.bones.feet, Vector3(1, 0, 0))
	check(to_right > 0.0, "strafe_right goes right (%.2f m/s)" % to_right)
	check(to_left > 0.0, "strafe_left goes left (%.2f m/s)" % to_left)


## The rifle's mount against the hand as the spine modifier left it. Godot puts bone poses back after
## that stage, so the bone's own pose can't be read from here.
func _hand_error(op: Node3D) -> float:
	var sk: Skeleton3D = op.anim.skeleton
	var rifle: Node3D = op.get_node("Model").find_child("Rifle", true, false)
	var hand: Transform3D = op.anim.twist.weapon_pose * op.anim.twist.weapon_offset.affine_inverse()
	return (rifle.get_parent().global_transform.origin - (sk.global_transform * hand).origin).length()


func test_the_rifle_stays_on_the_hand_through_walk_roll_and_death() -> void:
	var op := _spawn()
	op.scripted = {"keys": Vector2(0, -1)}
	var worst := 0.0
	for i in 30:
		await _frames(1)
		worst = maxf(worst, _hand_error(op))
	check(worst < 0.03, "walking: %.3f m off the hand" % worst)
	op.scripted = {}
	check(op.anim.play_state("roll"), "there is a roll")
	worst = 0.0
	for i in 30:
		await _frames(1)
		worst = maxf(worst, _hand_error(op))
	check(worst < 0.03, "rolling: %.3f m off the hand" % worst)
	op.hold_control(INF)
	check_eq(op.anim.over_state(), "death", "dead means the death clip")
	worst = 0.0
	for i in 30:
		await _frames(1)
		worst = maxf(worst, _hand_error(op))
	check(worst < 0.03, "dying: %.3f m off the hand" % worst)
	op.release_control()
	check_eq(op.anim.over_state(), "", "a respawn gets up")


func test_the_gun_points_where_the_torso_does() -> void:
	var op := _spawn()
	await _frames(20)
	var barrel: Vector3 = (op.anim.skeleton.global_transform * op.anim.twist.weapon_pose).basis.y.normalized()
	check(barrel.dot(Vector3(0, 0, -1)) > 0.97, "standing, aimed at -Z: barrel %s" % barrel)
	op.scripted = {"keys": Vector2(1, 0)}
	await _frames(30)
	barrel = (op.anim.skeleton.global_transform * op.anim.twist.weapon_pose).basis.y.normalized()
	check(barrel.dot(Vector3(0, 0, -1)) > 0.97, "strafing, still at -Z: barrel %s" % barrel)
	op.scripted = {"keys": Vector2.ZERO, "crouch": true}
	await _frames(30)
	barrel = (op.anim.skeleton.global_transform * op.anim.twist.weapon_pose).basis.y.normalized()
	check(barrel.dot(Vector3(0, 0, -1)) > 0.97, "crouched: barrel %s" % barrel)


func test_the_muzzle_is_at_the_barrel_end_ahead_of_the_body() -> void:
	var op := _spawn()
	await _frames(20)
	var muzzle: Vector3 = op.muzzle_position()
	check(muzzle.z < op.global_position.z - 0.3, "ahead of the body (z %.2f)" % muzzle.z)
	check(muzzle.y > 0.8 and muzzle.y < 2.0, "at gun height (y %.2f)" % muzzle.y)


func test_a_step_crouch_does_not_swing_the_feet_around_the_body() -> void:
	var op := _spawn()
	await _frames(20)
	var sk: Skeleton3D = op.anim.skeleton
	var foot: int = sk.find_bone(_cfg().bones.feet[0])
	var start: Vector3 = sk.get_bone_global_pose(foot).origin
	var furthest := 0.0
	op.scripted = {"crouch": true}
	for i in 24:
		await _frames(1)
		var at: Vector3 = sk.get_bone_global_pose(foot).origin
		furthest = maxf(furthest, Vector2(at.x - start.x, at.z - start.z).length())
	var end: Vector3 = sk.get_bone_global_pose(foot).origin
	var settled := Vector2(end.x - start.x, end.z - start.z).length()
	check(furthest <= settled + 0.1, "strayed %.2f m, ends %.2f m away" % [furthest, settled])


func test_a_turn_in_place_plays_only_when_the_hips_are_dragged() -> void:
	var op := _spawn()
	await _frames(5)
	check_eq(op.anim.tree.get("parameters/turn/blend_amount"), 0.0, "still: no turn clip")
	op.aim_point = Vector3(0, 1.2, 100)
	await _frames(36)
	check(float(op.anim.tree.get("parameters/turn/blend_amount")) > 0.5, "dragged round: the turn clip")


func test_the_pirates_get_the_paint_and_the_player_does_not() -> void:
	var scene: Node = (load("res://scenes/pirates/pirate_deck.tscn") as PackedScene).instantiate()
	_nodes.append(scene)
	OperatorBody.forced = "hauler"
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var paint: Dictionary = Data.value("pirates", "body", {}).hauler_paint
	var pirate: Node = scene.squad.pirates[0]
	var body: MeshInstance3D = pirate.get_node("Model").get_node("Hauler").find_children("*", "MeshInstance3D", true, false)[0]
	var worn := body.get_surface_override_material(0) as ShaderMaterial
	check(worn != null, "the pirate wears the shader")
	check_eq(worn.get_shader_parameter("plate_color"), Color(String(paint.plate_color)), "plates from data")
	check_eq(worn.get_shader_parameter("fabric_color"), Color(String(paint.fabric_color)), "fabric from data")
	var source := body.mesh.surface_get_material(0) as BaseMaterial3D
	check(worn.get_shader_parameter("albedo_tex") == source.albedo_texture, "a tint over the same texture, not a new one")
	var mine: MeshInstance3D = scene.operator.get_node("Model").get_node("Hauler").find_children("*", "MeshInstance3D", true, false)[0]
	check(mine.get_surface_override_material(0) == null, "the player keeps the orange")
	var rifle: MeshInstance3D = pirate.get_node("Model").find_child("Rifle", true, false)
	check(rifle.get_surface_override_material(0) != null, "their rifle is painted too")
