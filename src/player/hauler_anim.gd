extends Node
## Hooks John's hauler to the OperatorModel: the same public face as operator_anim.gd. Legs blend eight ways by
## move direction against the body, between walk, run and sprint by speed, and into the crouch; the upper body
## (data "upper_bones") plays aim, fire, low or reload on top, and the torso lead turns the spine. Hit reacts
## add on top of whatever's playing; carry, cover, roll and death take the whole body. The states are in
## data/hauler_anim.json, the choices in hauler_moves.gd. See src/player/CONTRACT.md.

const SpineTwist := preload("res://src/player/spine_twist.gd")
const HaulerClips := preload("res://src/player/hauler_clips.gd")
const Retarget := preload("res://src/player/hauler_retarget.gd")
const Moves := preload("res://src/player/hauler_moves.gd")
const LIB := "hauler"
const FRAME_RATE := 30.0
const HIT_STATES := ["hit_front", "hit_back", "hit_left", "hit_right", "hit_head", "hit_rifle"]
const DEATH_STATES := ["death", "death_headshot", "death_forward", "death_backward"]
const FIRE_STATES := ["fire", "fire_walking", "fire_crouch"]

var tree: AnimationTree
var skeleton: Skeleton3D
var twist: SpineTwist
var rest: Dictionary

var _cfg: Dictionary
var _upper := "aim"
var _reload_clip_s := 1.0
var _max_rate := 1.0
var _speed := 0.0
var _dir := Vector2(0, 1)
var _sprint := 0.0
var _sprint_want := 0.0
var _turn := 0.0
var _turn_want := 0.0
var _lock := 1.0
var _kick_deg := 0.0
var _over := ""
var _over_left := 0.0
var _player: AnimationPlayer
var _have := {}
var _last_crouch := 0.0
var _crouch_side := 0.0
var _crouch_side_want := 0.0
var _fire := 0.0
var _fire_want := false
var _fire_count := 0
var _hit := 0.0
var _hit_left := 0.0
var _hit_kind := ""
var _blow_side := ""
var _blow_high := false
var _blow_age := INF
var _death := 0.0
var _death_want := 0.0
var _death_kind := ""
var _action := ""
var _action_left := 0.0
var _carry := 0.0
var _carrying := false
var _cover := 0.0
var _cover_want := 0.0
var _cover_locked := false
var _rifle: Node3D
var _mount: BoneAttachment3D
var _rifle_in_hand := Transform3D.IDENTITY
var _hand_offset := Transform3D.IDENTITY


## `model_root` is the instanced hauler scene. `anim_cfg` is the merged "anim" block.
func setup(model_root: Node3D, anim_cfg: Dictionary, weapon_offset: Transform3D) -> void:
	_cfg = Data.load_data("hauler_anim")
	_reload_clip_s = float(anim_cfg.reload_clip_s)
	_max_rate = float(anim_cfg.max_time_scale)
	_hand_offset = weapon_offset
	skeleton = model_root.find_children("*", "Skeleton3D", true, false)[0]
	_player = model_root.find_children("*", "AnimationPlayer", true, false)[0]
	rest = Retarget.rest_of(skeleton)
	var lib := HaulerClips.library(_cfg, _player, rest)
	if not _player.has_animation_library(LIB):
		_player.add_animation_library(LIB, lib)
	for state: StringName in lib.get_animation_list():
		_have[String(state)] = true
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = _build_tree(float(anim_cfg.upper_xfade_s))
	model_root.add_child(tree)
	tree.root_node = NodePath("..")
	tree.anim_player = tree.get_path_to(_player)
	tree.active = true
	twist = SpineTwist.new()
	twist.name = "SpineTwist"
	twist.spine1_share = float(anim_cfg.spine1_twist_share)
	skeleton.add_child(twist)
	var b: Dictionary = _cfg.bones
	twist.setup(skeleton, skeleton.find_bone(b.hand_right), b.spine_lower, b.spine_upper)
	twist.set_arms(skeleton, String(b.arm_right), String(b.arm_left))
	twist.weapon_offset = weapon_offset
	twist.forward = Vector3(0, 0, 1)


func update(leg_blend: Vector2, _leg_scale: float, _crouch_scale: float, crouch_amount: float,
		lead: float, upper: String, reload_s: float) -> void:
	var a: Dictionary = _cfg.aim
	var step := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	_sprint = move_toward(_sprint, _sprint_want, step / float(a.sprint_blend_s))
	_turn = move_toward(_turn, _turn_want, step / float(a.turn_blend_s))
	_step_legs(leg_blend, lead, crouch_amount)
	_step_crouch_clips(crouch_amount, step)
	tree.set("parameters/crouch/blend_amount", crouch_amount)
	tree.set("parameters/aim_pose/blend_amount", crouch_amount)
	tree.set("parameters/reload_pose/blend_amount", crouch_amount)
	tree.set("parameters/fire_pose/blend_amount", crouch_amount)
	var moving := clampf(_speed / float(_cfg.gaits.idle_fade_m_s), 0.0, 1.0)
	tree.set("parameters/reload_moving/blend_amount", moving)
	tree.set("parameters/fire_moving/blend_amount", moving)
	tree.set("parameters/reload_rate/scale", _reload_clip_s / maxf(reload_s, 0.001))
	if upper != _upper:
		_upper = upper
		tree.set("parameters/upper/transition_request", upper)
	tree.set("parameters/turn/blend_amount", _turn * (1.0 - crouch_amount))
	_fire = move_toward(_fire, 1.0 if _fire_want else 0.0,
		step / float(a.fire_fade_in_s if _fire_want else a.fire_fade_out_s))
	if _fire == 0.0:
		_fire_count = 0
	tree.set("parameters/firing/blend_amount", _fire)
	_step_action(step)
	_step_hit(step)
	_step_whole_body(step, a)
	var lock_want := 1.0 if upper == "aim" and _over == "" and _action == "" and not _carrying and _cover_want == 0.0 else 0.0
	_lock = move_toward(_lock, lock_want, step / float(a.lock_blend_s))
	twist.aim_lock = _lock
	twist.kick_deg = _kick_deg if _over == "" else 0.0
	twist.twist = lead if _over != "death" and _over != "roll" else 0.0
	if _over_left > 0.0:
		_over_left -= step
		if _over_left <= 0.0 and _over != "death":
			_over = ""


func _step_legs(leg_blend: Vector2, lead: float, crouch_amount: float) -> void:
	# The clips' left and right are measured in the hauler's own facing, as is x in the blend.
	if leg_blend.length() > 0.01:
		_dir = Moves.on_hips(leg_blend, lead).normalized()
	var g: Dictionary = Moves.gaits(_cfg.gaits, _dir, _speed, _sprint, _max_rate)
	tree.set("parameters/walk/blend_position", _dir)
	tree.set("parameters/run/blend_position", _dir)
	tree.set("parameters/sprint_space/blend_position", Moves.sprint_dir(_dir))
	tree.set("parameters/walk_rate/scale", g.walk_rate)
	tree.set("parameters/run_rate/scale", g.run_rate)
	tree.set("parameters/sprint_rate/scale", g.sprint_rate)
	tree.set("parameters/low_rate/scale", g.sprint_rate)
	tree.set("parameters/gait/blend_amount", g.run)
	tree.set("parameters/sprint/blend_amount", g.sprint)
	tree.set("parameters/moving/blend_amount", g.moving)
	tree.set("parameters/crouch_space/blend_position", _dir)
	tree.set("parameters/crouch_moving/blend_amount", g.moving)
	var speeds: Dictionary = _cfg.gaits.speeds_m_s
	tree.set("parameters/crouch_rate/scale", Moves.rate_for(_speed, Moves.clip_speed(speeds.crouch, _dir), _max_rate))
	# Going backward the forward-only carry clips run in reverse; sideways they slide.
	var carry_sign := -1.0 if _dir.y < -absf(_dir.x) else 1.0
	tree.set("parameters/carry_moving/blend_amount", g.moving)
	tree.set("parameters/carry_crouch_moving/blend_amount", g.moving)
	tree.set("parameters/carry_pose/blend_amount", crouch_amount)
	tree.set("parameters/carry_rate/scale", carry_sign * Moves.rate_for(_speed, float(speeds.carry.fwd), _max_rate))
	tree.set("parameters/carry_crouch_rate/scale", carry_sign * Moves.rate_for(_speed, float(speeds.carry_crouch.fwd), _max_rate))


## Going down or up, standing still, the crouch's own clips are scrubbed by how far down the body is, so the
## crouch keeps the model's timing. Moving, the plain blend does it. Their hips are in place.
func _step_crouch_clips(crouch_amount: float, step: float) -> void:
	var a: Dictionary = _cfg.aim
	if crouch_amount > _last_crouch:
		_crouch_side_want = 0.0
	elif crouch_amount < _last_crouch:
		_crouch_side_want = 1.0
	_last_crouch = crouch_amount
	_crouch_side = move_toward(_crouch_side, _crouch_side_want, step / float(a.crouch_side_blend_s))
	var edge := minf(crouch_amount, 1.0 - crouch_amount) / float(a.transition_edge)
	var still := 1.0 - clampf(_speed / float(a.transition_move_m_s), 0.0, 1.0)
	var share := clampf(edge, 0.0, 1.0) * still
	tree.set("parameters/transition/blend_amount", share)
	if share > 0.0:
		tree.set("parameters/transition_side/blend_amount", _crouch_side)
		tree.set("parameters/stand_to_crouch_seek/seek_request", crouch_amount * clip_length("stand_to_crouch"))
		tree.set("parameters/crouch_to_stand_seek/seek_request", (1.0 - crouch_amount) * clip_length("crouch_to_stand"))


func _step_action(step: float) -> void:
	if _action == "":
		return
	_action_left -= step
	if _action_left <= 0.0:
		_action = ""
	elif _speed >= float(_cfg.aim.action_cut_m_s):
		tree.set("parameters/%s_shot/request" % _action, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		_action = ""


func _step_hit(step: float) -> void:
	var h: Dictionary = _cfg.hits
	_blow_age += step
	_hit_left = maxf(_hit_left - step, 0.0)
	var want := 1.0 if _hit_left > float(h.fade_out_s) else 0.0
	_hit = move_toward(_hit, want, step / float(h.fade_in_s if want > _hit else h.fade_out_s))
	tree.set("parameters/hit_add/add_amount", _hit)


func _step_whole_body(step: float, a: Dictionary) -> void:
	_carry = move_toward(_carry, 1.0 if _carrying else 0.0, step / float(a.carry_blend_s))
	tree.set("parameters/carry_mix/blend_amount", _carry)
	_cover = move_toward(_cover, _cover_want, step / float(a.cover_blend_s))
	tree.set("parameters/cover_mix/blend_amount", _cover)
	_death = move_toward(_death, _death_want, step / float(a.death_fade_in_s))
	tree.set("parameters/death_mix/blend_amount", _death)


## What the legacy body doesn't need: the speed the gaits read, and the hips' turn in place.
func set_motion(sprinting: bool, speed: float, hip_turn_deg_s: float) -> void:
	var a: Dictionary = _cfg.aim
	_sprint_want = 1.0 if sprinting else 0.0
	_speed = speed
	var turning := absf(hip_turn_deg_s) >= float(a.turn_start_deg_s) and speed < float(a.turn_max_speed_m_s)
	_turn_want = 1.0 if turning else 0.0
	if turning:
		var left := hip_turn_deg_s > 0.0
		tree.set("parameters/turn_side/blend_amount", 0.0 if left else 1.0)
		var clip_rate := float(a.turn_left_clip_deg_s) if left else float(a.turn_right_clip_deg_s)
		tree.set("parameters/turn_rate/scale", absf(hip_turn_deg_s) / clip_rate)


## 0..1: how fresh the last shot is. Kicks the upper spine back and holds the firing pose.
func set_recoil(share: float) -> void:
	_kick_deg = share * float(_cfg.aim.recoil_kick_deg)
	_fire_want = share > 0.0


## 0..1: one round's kick, through both arms. Sharp, on top of set_recoil's slower lean.
func set_arm_kick(share: float) -> void:
	twist.arm_kick_deg = share * float(_cfg.aim.arm_kick_deg)


## A round went off, this step. Each firing clip jumps to its next kick, played so one kick lasts one round.
func note_shot() -> void:
	var interval := float(Data.value("weapons", "rifle").fire_interval_s)
	for state: String in FIRE_STATES:
		var f: Dictionary = _cfg.fire[state]
		var frames: Array = f.shot_frames
		tree.set("parameters/%s_seek/seek_request" % state, float(frames[_fire_count % frames.size()]) / FRAME_RATE)
		tree.set("parameters/%s_rate/scale" % state, float(f.frames_per_shot) / FRAME_RATE / interval)
	_fire_count += 1
	_fire_want = true


## A blow from flat direction `from` against facing `yaw`: a flinch on top of what's playing, and it's what a
## death in the next moments falls from. `point_y` above the neck is the head; below 0, nobody knows.
func note_hit(from: Vector2, yaw: float, point_y: float, height: float, shouldered: bool) -> void:
	if _over == "death":
		return
	var h: Dictionary = _cfg.hits
	_blow_side = Moves.side(from, yaw, float(h.front_cos))
	_blow_high = point_y > float(h.neck_height_share) * height
	_blow_age = 0.0
	_react(Moves.hit_state(_blow_side, _blow_high, shouldered), float(h.seconds))


func _react(state: String, seconds: float) -> void:
	var length := clip_length(state) / maxf(seconds, 0.001)
	_hit_kind = state
	_hit_left = seconds
	tree.set("parameters/hit_kind/transition_request", state)
	tree.set("parameters/hit_seek/seek_request", 0.0)
	tree.set("parameters/hit_rate/scale", length)


## Plays over everything: "roll", "death". Death holds its last frame until `clear_states`, and falls by the last
## blow if there was a recent one. "hit" is a flinch for `seconds`, on top: it never takes the legs.
func play_state(state: String, seconds := -1.0) -> bool:
	if state == "hit":
		_react(_hit_kind if _hit_kind != "" else "hit_front", seconds if seconds > 0.0 else float(_cfg.hits.seconds))
		return true
	if not _have.has(state) or _over == "death":
		return false
	var clip_s := clip_length(state)
	var length := clip_s if seconds <= 0.0 else seconds
	_over = state
	_over_left = length
	match state:
		"death":
			var fresh := _blow_age <= float(_cfg.hits.memory_s)
			_death_kind = Moves.death_state(_blow_side, _blow_high) if fresh else "death"
			tree.set("parameters/death_kind/transition_request", _death_kind)
			tree.set("parameters/death_seek/seek_request", 0.0)
			_death_want = 1.0
		_:
			tree.set("parameters/%s_rate/scale" % state, clip_s / length)
			tree.set("parameters/%s_shot/request" % state, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return true


## The death that's playing ("death", "death_headshot"...), or "".
func death_kind() -> String:
	return _death_kind if _over == "death" else ""


## A job for the hands, on the upper body: "pick_up", "interact". Moving cuts it short.
func play_action(state: String) -> void:
	var a: Dictionary = _cfg.actions[state]
	_action = state
	_action_left = float(a.seconds)
	tree.set("parameters/%s_rate/scale" % state, clip_length(state) / float(a.seconds))
	tree.set("parameters/%s_shot/request" % state, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func action() -> String:
	return _action


## Both hands full: the unarmed clips, the rifle on the back.
func set_carrying(on: bool) -> void:
	if on == _carrying:
		return
	_carrying = on
	_sling(on)


func carrying() -> bool:
	return _carrying


## The lock to cover: `share` of the cover pose on the upper body (none while braced over it; the clip stands
## taller than low cover, so the crouch keeps the legs), and letting go steps out of it.
func set_cover(share: float, locked: bool) -> void:
	_cover_want = share
	if _cover_locked and not locked:
		var seconds := float(_cfg.cover.to_stand_s)
		_action = "cover_to_stand"
		_action_left = seconds
		tree.set("parameters/cover_to_stand_rate/scale", clip_length("cover_to_stand") / seconds)
		tree.set("parameters/cover_to_stand_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_cover_locked = locked


func _sling(on: bool) -> void:
	if _mount == null:
		_mount = skeleton.find_children("*", "BoneAttachment3D", false, false)[0]
		_rifle = _mount.get_child(0)
		_rifle_in_hand = _rifle.transform
	var r: Dictionary = _cfg.rifle
	if on:
		# Given in the skeleton's axes (it faces +Z, the barrel is the weapon's +Y), measured from the bone.
		var e: Array = r.sling.euler_deg
		var p: Array = r.sling.offset_m
		var bone_rot := skeleton.get_bone_global_rest(skeleton.find_bone(String(r.sling.bone))).basis.get_rotation_quaternion().inverse()
		var at := Transform3D(Basis(bone_rot) * Basis.from_euler(Vector3(deg_to_rad(float(e[0])), deg_to_rad(float(e[1])), deg_to_rad(float(e[2])))),
			bone_rot * Vector3(float(p[0]), float(p[1]), float(p[2])))
		_mount.bone_name = String(r.sling.bone)
		_rifle.transform = at * _hand_offset.affine_inverse() * _rifle_in_hand
	else:
		_mount.bone_name = String(_cfg.bones.hand_right)
		_rifle.transform = _rifle_in_hand


func clear_states() -> void:
	_over = ""
	_over_left = 0.0
	_death_want = 0.0
	_death = 0.0
	_blow_age = INF
	_hit = 0.0
	_hit_left = 0.0
	_action = ""
	_cover = 0.0
	_cover_want = 0.0
	_cover_locked = false
	tree.set("parameters/death_mix/blend_amount", 0.0)
	tree.set("parameters/hit_add/add_amount", 0.0)
	tree.set("parameters/cover_mix/blend_amount", 0.0)
	for state: String in ["roll", "pick_up", "interact", "cover_to_stand"]:
		tree.set("parameters/%s_shot/request" % state, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)


## The state playing over everything, or "".
func over_state() -> String:
	return _over


func start() -> void:
	tree.set("parameters/mix/blend_amount", 1.0)
	tree.set("parameters/crouch/blend_amount", 0.0)


func clip_length(state: String) -> float:
	return _player.get_animation("%s/%s" % [LIB, state]).length


## The clip whose length sets the walk's beat.
func cycle_length() -> float:
	return clip_length("run_fwd")


## Each foot bone, left then right.
func foot_bones() -> Array:
	return _cfg.bones.feet


func _build_tree(xfade: float) -> AnimationNodeBlendTree:
	var a: Dictionary = _cfg.aim
	var upper := AnimationNodeTransition.new()
	upper.xfade_time = xfade
	upper.input_count = 3
	upper.set_input_name(0, "aim")
	upper.set_input_name(1, "low")
	upper.set_input_name(2, "reload")
	var mix := AnimationNodeBlend2.new()
	mix.filter_enabled = true
	var path: String = _cfg.skeleton_path
	for b: String in _cfg.upper_bones:
		mix.set_filter_path(NodePath("%s:mixamorig_%s" % [path, b]), true)
	var hit_add := AnimationNodeAdd2.new()
	hit_add.filter_enabled = true
	for b: String in _cfg.hits.bones:
		hit_add.set_filter_path(NodePath("%s:mixamorig_%s" % [path, b]), true)
	var cover_mix := AnimationNodeBlend2.new()
	cover_mix.filter_enabled = true
	for b: String in _cfg.upper_bones:
		cover_mix.set_filter_path(NodePath("%s:mixamorig_%s" % [path, b]), true)
	var bt := AnimationNodeBlendTree.new()
	var nodes: Array = [["walk", _space("walk", Moves.EIGHT)], ["walk_rate", AnimationNodeTimeScale.new()],
			["run", _space("run", Moves.EIGHT)], ["run_rate", AnimationNodeTimeScale.new()],
			["gait", _synced()], ["sprint_space", _space("sprint", ["fwd", "left", "right"])],
			["sprint_rate", AnimationNodeTimeScale.new()], ["sprint", _synced()],
			["idle", _clip("idle")], ["moving", AnimationNodeBlend2.new()],
			["turn_left", _clip("turn_left")], ["turn_right", _clip("turn_right")],
			["turn_side", AnimationNodeBlend2.new()], ["turn_rate", AnimationNodeTimeScale.new()],
			["turn", AnimationNodeBlend2.new()],
			["crouch_idle", _clip("crouch_idle")], ["crouch_space", _space("crouch_walk", ["fwd", "back", "left", "right"])],
			["crouch_rate", AnimationNodeTimeScale.new()], ["crouch_moving", AnimationNodeBlend2.new()],
			["crouch", AnimationNodeBlend2.new()], ["transition", AnimationNodeBlend2.new()],
			["transition_side", AnimationNodeBlend2.new()],
			["stand_to_crouch", _clip("stand_to_crouch")], ["stand_to_crouch_seek", AnimationNodeTimeSeek.new()],
			["crouch_to_stand", _clip("crouch_to_stand")], ["crouch_to_stand_seek", AnimationNodeTimeSeek.new()],
			["aim_stand", _clip("aim")], ["aim_crouch", _clip("crouch_aim")], ["aim_pose", AnimationNodeBlend2.new()],
			["fire_moving", _synced()], ["fire_pose", _synced()], ["firing", _synced()],
			["low", _clip("low")], ["low_rate", AnimationNodeTimeScale.new()],
			["reload_moving", _synced()], ["reload_pose", _synced()], ["reload_rate", AnimationNodeTimeScale.new()],
			["reload_stand", _clip("reload")], ["reload_walking", _clip("reload_walking")], ["reload_crouch", _clip("reload_crouch")],
			["upper", upper], ["mix", mix],
			["carry_idle", _clip("carry_idle")], ["carry_walk", _clip("carry_walk")], ["carry_rate", AnimationNodeTimeScale.new()],
			["carry_moving", AnimationNodeBlend2.new()], ["carry_crouch_idle", _clip("carry_crouch_idle")],
			["carry_crouch_walk", _clip("carry_crouch_walk")], ["carry_crouch_rate", AnimationNodeTimeScale.new()],
			["carry_crouch_moving", AnimationNodeBlend2.new()], ["carry_pose", AnimationNodeBlend2.new()],
			["carry_mix", AnimationNodeBlend2.new()],
			["cover_idle", _clip("cover_idle")], ["cover_mix", cover_mix],
			["hit_kind", _kinds(HIT_STATES)], ["hit_rate", AnimationNodeTimeScale.new()],
			["hit_seek", AnimationNodeTimeSeek.new()], ["hit_add", hit_add],
			["death_kind", _kinds(DEATH_STATES)], ["death_seek", AnimationNodeTimeSeek.new()],
			["death_mix", AnimationNodeBlend2.new()]]
	for state: String in FIRE_STATES:
		nodes.append_array([[state, _clip(state)], [state + "_rate", AnimationNodeTimeScale.new()],
			[state + "_seek", AnimationNodeTimeSeek.new()]])
	var fades := {"pick_up": a.action_fade_s, "interact": a.action_fade_s, "cover_to_stand": a.action_fade_s,
		"roll": a.roll_fade_in_s}
	for state: String in fades:
		nodes.append_array([[state + "_clip", _clip(state)], [state + "_rate", AnimationNodeTimeScale.new()],
			[state + "_shot", _one_shot(float(fades[state]), float(a.roll_fade_out_s if state == "roll" else fades[state]))]])
	for pair: Array in nodes:
		bt.add_node(pair[0], pair[1])
	for state: String in HIT_STATES:
		bt.add_node("clip_" + state, _clip(state))
	for state: String in DEATH_STATES:
		bt.add_node("clip_" + state, _clip(state))
	var edges: Array = [["walk_rate", 0, "walk"], ["run_rate", 0, "run"], ["gait", 0, "walk_rate"], ["gait", 1, "run_rate"],
			["sprint_rate", 0, "sprint_space"], ["sprint", 0, "gait"], ["sprint", 1, "sprint_rate"],
			["moving", 0, "idle"], ["moving", 1, "sprint"],
			["turn_side", 0, "turn_left"], ["turn_side", 1, "turn_right"], ["turn_rate", 0, "turn_side"],
			["turn", 0, "moving"], ["turn", 1, "turn_rate"],
			["crouch_rate", 0, "crouch_space"], ["crouch_moving", 0, "crouch_idle"], ["crouch_moving", 1, "crouch_rate"],
			["crouch", 0, "turn"], ["crouch", 1, "crouch_moving"],
			["stand_to_crouch_seek", 0, "stand_to_crouch"], ["crouch_to_stand_seek", 0, "crouch_to_stand"],
			["transition_side", 0, "stand_to_crouch_seek"], ["transition_side", 1, "crouch_to_stand_seek"],
			["transition", 0, "crouch"], ["transition", 1, "transition_side"],
			["aim_pose", 0, "aim_stand"], ["aim_pose", 1, "aim_crouch"],
			["fire_rate", 0, "fire"], ["fire_seek", 0, "fire_rate"],
			["fire_walking_rate", 0, "fire_walking"], ["fire_walking_seek", 0, "fire_walking_rate"],
			["fire_crouch_rate", 0, "fire_crouch"], ["fire_crouch_seek", 0, "fire_crouch_rate"],
			["fire_moving", 0, "fire_seek"], ["fire_moving", 1, "fire_walking_seek"],
			["fire_pose", 0, "fire_moving"], ["fire_pose", 1, "fire_crouch_seek"],
			["firing", 0, "aim_pose"], ["firing", 1, "fire_pose"],
			["pick_up_rate", 0, "pick_up_clip"], ["pick_up_shot", 0, "firing"], ["pick_up_shot", 1, "pick_up_rate"],
			["interact_rate", 0, "interact_clip"], ["interact_shot", 0, "pick_up_shot"], ["interact_shot", 1, "interact_rate"],
			["low_rate", 0, "low"],
			["reload_moving", 0, "reload_stand"], ["reload_moving", 1, "reload_walking"],
			["reload_pose", 0, "reload_moving"], ["reload_pose", 1, "reload_crouch"], ["reload_rate", 0, "reload_pose"],
			["upper", 0, "interact_shot"], ["upper", 1, "low_rate"], ["upper", 2, "reload_rate"],
			["mix", 0, "transition"], ["mix", 1, "upper"],
			["carry_rate", 0, "carry_walk"], ["carry_moving", 0, "carry_idle"], ["carry_moving", 1, "carry_rate"],
			["carry_crouch_rate", 0, "carry_crouch_walk"], ["carry_crouch_moving", 0, "carry_crouch_idle"],
			["carry_crouch_moving", 1, "carry_crouch_rate"], ["carry_pose", 0, "carry_moving"], ["carry_pose", 1, "carry_crouch_moving"],
			["carry_mix", 0, "mix"], ["carry_mix", 1, "carry_pose"],
			["cover_mix", 0, "carry_mix"], ["cover_mix", 1, "cover_idle"],
			["cover_to_stand_rate", 0, "cover_to_stand_clip"], ["cover_to_stand_shot", 0, "cover_mix"],
			["cover_to_stand_shot", 1, "cover_to_stand_rate"],
			["hit_rate", 0, "hit_kind"], ["hit_seek", 0, "hit_rate"],
			["hit_add", 0, "cover_to_stand_shot"], ["hit_add", 1, "hit_seek"],
			["roll_rate", 0, "roll_clip"], ["roll_shot", 0, "hit_add"], ["roll_shot", 1, "roll_rate"],
			["death_seek", 0, "death_kind"], ["death_mix", 0, "roll_shot"], ["death_mix", 1, "death_seek"],
			["output", 0, "death_mix"]]
	for i in HIT_STATES.size():
		edges.append(["hit_kind", i, "clip_" + HIT_STATES[i]])
	for i in DEATH_STATES.size():
		edges.append(["death_kind", i, "clip_" + DEATH_STATES[i]])
	for edge: Array in edges:
		bt.connect_node(edge[0], edge[1], edge[2])
	return bt


## The clips of one gait around the circle. The blend position stays on the circle, so it's always between the
## two clips either side of the way you're going, and every clip keeps playing so they stay in step.
func _space(gait: String, directions: Array) -> AnimationNodeBlendSpace2D:
	var space := AnimationNodeBlendSpace2D.new()
	space.sync = true
	for d: String in directions:
		var state := "%s_%s" % [gait, d]
		space.add_blend_point(_clip(state), Moves.point(d), -1, state)
	return space


func _synced() -> AnimationNodeBlend2:
	var blend := AnimationNodeBlend2.new()
	blend.sync = true
	return blend


func _kinds(states: Array) -> AnimationNodeTransition:
	var kinds := AnimationNodeTransition.new()
	kinds.input_count = states.size()
	for i in states.size():
		kinds.set_input_name(i, states[i])
	return kinds


func _one_shot(fade_in: float, fade_out: float) -> AnimationNodeOneShot:
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade_in
	shot.fadeout_time = fade_out
	return shot


func _clip(state: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = "%s/%s" % [LIB, state]
	return a
