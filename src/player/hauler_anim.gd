extends Node
## Hooks John's hauler to the OperatorModel: the same public face as operator_anim.gd. Legs blend by
## move direction, then by speed into the sprint and by the crouch; the upper body (data "upper_bones")
## plays aim, low or reload on top, and the torso lead turns the spine. Roll, hit and death play over
## everything. The states are in data/hauler_anim.json. See src/player/CONTRACT.md.

const SpineTwist := preload("res://src/player/spine_twist.gd")
const HaulerClips := preload("res://src/player/hauler_clips.gd")
const Retarget := preload("res://src/player/hauler_retarget.gd")
const LIB := "hauler"

var tree: AnimationTree
var skeleton: Skeleton3D
var twist: SpineTwist
var rest: Dictionary

var _cfg: Dictionary
var _upper := "aim"
var _reload_clip_s := 1.0
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


## `model_root` is the instanced hauler scene. `anim_cfg` is the merged "anim" block.
func setup(model_root: Node3D, anim_cfg: Dictionary, weapon_offset: Transform3D) -> void:
	_cfg = Data.load_data("hauler_anim")
	_reload_clip_s = float(anim_cfg.reload_clip_s)
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
	twist.weapon_offset = weapon_offset
	twist.forward = Vector3(0, 0, 1)


func update(leg_blend: Vector2, leg_scale: float, crouch_scale: float, crouch_amount: float,
		lead: float, upper: String, reload_s: float) -> void:
	# The clips' left and right are measured in the hauler's own facing, as is x in the blend.
	tree.set("parameters/legs/blend_position", leg_blend)
	tree.set("parameters/legs_rate/scale", leg_scale)
	tree.set("parameters/crouch_legs/blend_position", leg_blend.length())
	tree.set("parameters/crouch_rate/scale", crouch_scale)
	tree.set("parameters/crouch/blend_amount", crouch_amount)
	tree.set("parameters/aim_pose/blend_amount", crouch_amount)
	tree.set("parameters/reload_rate/scale", _reload_clip_s / maxf(reload_s, 0.001))
	if upper != _upper:
		_upper = upper
		tree.set("parameters/upper/transition_request", upper)
	var a: Dictionary = _cfg.aim
	var step := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	_sprint = move_toward(_sprint, _sprint_want, step / float(a.sprint_blend_s))
	_turn = move_toward(_turn, _turn_want, step / float(a.turn_blend_s))
	tree.set("parameters/sprint/blend_amount", _sprint)
	tree.set("parameters/turn/blend_amount", _turn * (1.0 - crouch_amount))
	var lock_want := 1.0 if upper == "aim" and _over == "" else 0.0
	_lock = move_toward(_lock, lock_want, step / float(a.lock_blend_s))
	twist.aim_lock = _lock
	twist.kick_deg = _kick_deg if _over == "" else 0.0
	twist.twist = lead if _over != "death" and _over != "roll" else 0.0
	if _over_left > 0.0:
		_over_left -= step
		if _over_left <= 0.0 and _over != "death":
			_over = ""


## What the legacy body doesn't need: the sprint's own clip and rate, and the hips' turn in place.
func set_motion(sprinting: bool, speed: float, hip_turn_deg_s: float) -> void:
	var a: Dictionary = _cfg.aim
	_sprint_want = 1.0 if sprinting else 0.0
	tree.set("parameters/sprint_rate/scale", speed / float(_cfg.anim.clip_speed_sprint_m_s))
	var turning := absf(hip_turn_deg_s) >= float(a.turn_start_deg_s) and speed < float(a.turn_max_speed_m_s)
	_turn_want = 1.0 if turning else 0.0
	if turning:
		var left := hip_turn_deg_s > 0.0
		tree.set("parameters/turn_side/blend_amount", 0.0 if left else 1.0)
		var clip_rate := float(a.turn_left_clip_deg_s) if left else float(a.turn_right_clip_deg_s)
		tree.set("parameters/turn_rate/scale", absf(hip_turn_deg_s) / clip_rate)


## 0..1: how fresh the last shot is. Kicks the upper spine back.
func set_recoil(share: float) -> void:
	_kick_deg = share * float(_cfg.aim.recoil_kick_deg)


## Plays "roll", "hit" or "death" over everything. Death holds its last frame until `clear_states`.
func play_state(state: String, seconds := -1.0) -> bool:
	if not _have.has(state) or _over == "death":
		return false
	var clip_s := clip_length(state)
	var length := clip_s if seconds <= 0.0 else seconds
	_over = state
	_over_left = length
	match state:
		"death":
			tree.set("parameters/death_seek/seek_request", 0.0)
			tree.set("parameters/death_mix/blend_amount", 1.0)
		_:
			tree.set("parameters/%s_rate/scale" % state, clip_s / length)
			tree.set("parameters/%s_shot/request" % state, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return true


func clear_states() -> void:
	_over = ""
	_over_left = 0.0
	tree.set("parameters/death_mix/blend_amount", 0.0)
	for state: String in ["hit", "roll"]:
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
	return clip_length("run")


## Each foot bone, left then right.
func foot_bones() -> Array:
	return _cfg.bones.feet


func _build_tree(xfade: float) -> AnimationNodeBlendTree:
	var a: Dictionary = _cfg.aim
	var legs := AnimationNodeBlendSpace2D.new()
	legs.sync = true
	legs.add_blend_point(_clip("idle"), Vector2.ZERO, -1, "idle")
	legs.add_blend_point(_clip("walk_forward"), Vector2(0, float(a.walk_blend_at)), -1, "walk_forward")
	legs.add_blend_point(_clip("run"), Vector2(0, 1), -1, "run")
	legs.add_blend_point(_clip("walk_back"), Vector2(0, -1), -1, "walk_back")
	legs.add_blend_point(_clip("strafe_left"), Vector2(-1, 0), -1, "strafe_left")
	legs.add_blend_point(_clip("strafe_right"), Vector2(1, 0), -1, "strafe_right")
	var crouch_legs := AnimationNodeBlendSpace1D.new()
	crouch_legs.min_space = 0.0
	crouch_legs.add_blend_point(_clip("crouch_idle"), 0.0, -1, "crouch_idle")
	crouch_legs.add_blend_point(_clip("crouch_walk"), 1.0, -1, "crouch_walk")
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
	var hit := _one_shot(float(a.hit_fade_in_s), float(a.hit_fade_out_s))
	var roll := _one_shot(float(a.roll_fade_in_s), float(a.roll_fade_out_s))
	var bt := AnimationNodeBlendTree.new()
	for pair: Array in [["legs", legs], ["legs_rate", AnimationNodeTimeScale.new()],
			["sprint_clip", _clip("sprint")], ["sprint_rate", AnimationNodeTimeScale.new()],
			["sprint", AnimationNodeBlend2.new()], ["turn_left", _clip("turn_left")],
			["turn_right", _clip("turn_right")], ["turn_side", AnimationNodeBlend2.new()],
			["turn_rate", AnimationNodeTimeScale.new()], ["turn", AnimationNodeBlend2.new()],
			["crouch_legs", crouch_legs], ["crouch_rate", AnimationNodeTimeScale.new()],
			["crouch", AnimationNodeBlend2.new()], ["aim_stand", _clip("aim")], ["aim_crouch", _clip("crouch_aim")],
			["aim_pose", AnimationNodeBlend2.new()], ["low", _clip("low")], ["reload", _clip("reload")],
			["reload_rate", AnimationNodeTimeScale.new()], ["upper", upper], ["mix", mix],
			["hit_clip", _clip("hit")], ["hit_rate", AnimationNodeTimeScale.new()], ["hit_shot", hit],
			["roll_clip", _clip("roll")], ["roll_rate", AnimationNodeTimeScale.new()], ["roll_shot", roll],
			["death_clip", _clip("death")], ["death_seek", AnimationNodeTimeSeek.new()],
			["death_mix", AnimationNodeBlend2.new()]]:
		bt.add_node(pair[0], pair[1])
	for edge: Array in [["legs_rate", 0, "legs"], ["sprint_rate", 0, "sprint_clip"],
			["sprint", 0, "legs_rate"], ["sprint", 1, "sprint_rate"],
			["turn_side", 0, "turn_left"], ["turn_side", 1, "turn_right"], ["turn_rate", 0, "turn_side"],
			["turn", 0, "sprint"], ["turn", 1, "turn_rate"],
			["crouch_rate", 0, "crouch_legs"], ["crouch", 0, "turn"], ["crouch", 1, "crouch_rate"],
			["aim_pose", 0, "aim_stand"], ["aim_pose", 1, "aim_crouch"],
			["reload_rate", 0, "reload"], ["upper", 0, "aim_pose"], ["upper", 1, "low"], ["upper", 2, "reload_rate"],
			["mix", 0, "crouch"], ["mix", 1, "upper"],
			["hit_rate", 0, "hit_clip"], ["hit_shot", 0, "mix"], ["hit_shot", 1, "hit_rate"],
			["roll_rate", 0, "roll_clip"], ["roll_shot", 0, "hit_shot"], ["roll_shot", 1, "roll_rate"],
			["death_seek", 0, "death_clip"], ["death_mix", 0, "roll_shot"], ["death_mix", 1, "death_seek"],
			["output", 0, "death_mix"]]:
		bt.connect_node(edge[0], edge[1], edge[2])
	return bt


func _one_shot(fade_in: float, fade_out: float) -> AnimationNodeOneShot:
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade_in
	shot.fadeout_time = fade_out
	return shot


func _clip(state: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = "%s/%s" % [LIB, state]
	return a
