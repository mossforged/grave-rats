extends Node
## Hooks the legacy operator clips to the OperatorModel: L_Idle/L_Run_F/B/L_Strafe_L/R blended by
## move direction relative to the torso, L_Crouch_* blended in by the crouch, U_Aim/U_LowReady/
## U_Reload on the upper body (spine and up), and the torso lead as a spine twist.
## update() reads speed and direction the model computed before the move.

const SpineTwist := preload("res://src/player/spine_twist.gd")
const UPPER_BONES := ["spine1", "spine2", "clavicle_L", "upperarm_L", "forearm_L", "hand_L",
	"clavicle_R", "upperarm_R", "forearm_R", "hand_R", "neck", "head", "weapon", "mag"]
const TWISTED_CLIPS := ["L_Idle", "L_Crouch_Idle"]
const SKELETON_PATH := "Rig/Skeleton3D:"

var tree: AnimationTree
var skeleton: Skeleton3D
var twist: SpineTwist

var _upper := "aim"
var _reload_clip_s := 1.0


## `model_root` is the instanced operator scene.
func setup(model_root: Node3D, cfg: Dictionary, weapon_bone_name: String) -> void:
	_reload_clip_s = float(cfg.reload_clip_s)
	skeleton = model_root.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = model_root.find_children("*", "AnimationPlayer", true, false)[0]
	for clip: String in TWISTED_CLIPS:
		for side: String in ["_L", "_R"]:
			_untwist_leg(player.get_animation(clip), side)
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = _build_tree(float(cfg.upper_xfade_s))
	model_root.add_child(tree)
	tree.root_node = NodePath("..")
	tree.anim_player = tree.get_path_to(player)
	tree.active = true
	twist = SpineTwist.new()
	twist.name = "SpineTwist"
	twist.spine1_share = float(cfg.spine1_twist_share)
	skeleton.add_child(twist)
	twist.setup(skeleton, skeleton.find_bone(weapon_bone_name))


## The idle clips hold each thigh half a turn about its own length from where the walk clips and
## the rest pose hold it, and take that half turn back at the foot. The pose looks fine, but the
## mixer blends rotations away from rest, so a blend into a crouch swung each foot in a loop around
## the body: the corkscrew John saw. This writes the same pose the short way. The clip resources are
## shared between operators, so a clip already untwisted is left alone.
func _untwist_leg(clip: Animation, side: String) -> void:
	var half := Quaternion(Vector3.UP, PI)
	var thigh := clip.find_track(NodePath(SKELETON_PATH + "thigh" + side), Animation.TYPE_ROTATION_3D)
	var shin := clip.find_track(NodePath(SKELETON_PATH + "shin" + side), Animation.TYPE_ROTATION_3D)
	var foot := clip.find_track(NodePath(SKELETON_PATH + "foot" + side), Animation.TYPE_ROTATION_3D)
	var rest := skeleton.get_bone_rest(skeleton.find_bone("thigh" + side)).basis.get_rotation_quaternion()
	var first: Quaternion = clip.track_get_key_value(thigh, 0)
	if absf(rest.dot(first)) >= absf(rest.dot(first * half)):
		return
	for k in clip.track_get_key_count(thigh):
		clip.track_set_key_value(thigh, k, (clip.track_get_key_value(thigh, k) as Quaternion) * half)
	for k in clip.track_get_key_count(shin):
		clip.track_set_key_value(shin, k, half.inverse() * (clip.track_get_key_value(shin, k) as Quaternion) * half)
	for k in clip.track_get_key_count(foot):
		clip.track_set_key_value(foot, k, half.inverse() * (clip.track_get_key_value(foot, k) as Quaternion))


## Call once per step with state from before the move. `reload_s` is the reload's full time.
func update(leg_blend: Vector2, leg_scale: float, crouch_scale: float, crouch_amount: float,
		lead: float, upper: String, reload_s: float) -> void:
	tree.set("parameters/legs/blend_position", leg_blend)
	tree.set("parameters/legs_rate/scale", leg_scale)
	tree.set("parameters/crouch_legs/blend_position", leg_blend.length())
	tree.set("parameters/crouch_rate/scale", crouch_scale)
	tree.set("parameters/crouch/blend_amount", crouch_amount)
	tree.set("parameters/reload_rate/scale", _reload_clip_s / maxf(reload_s, 0.001))
	twist.twist = lead
	if upper != _upper:
		_upper = upper
		tree.set("parameters/upper/transition_request", upper)


## The hauler's sprint, turn, recoil and full-body states. The legacy body has none of them.
func set_motion(_sprinting: bool, _speed: float, _hip_turn_deg_s: float) -> void:
	pass


func set_recoil(_share: float) -> void:
	pass


func set_arm_kick(_share: float) -> void:
	pass


func play_state(_state: String, _seconds := -1.0) -> bool:
	return false


func clear_states() -> void:
	pass


func over_state() -> String:
	return ""


func _build_tree(xfade: float) -> AnimationNodeBlendTree:
	var legs := AnimationNodeBlendSpace2D.new()
	legs.sync = true
	legs.add_blend_point(_clip("L_Idle"), Vector2.ZERO)
	legs.add_blend_point(_clip("L_Run_F"), Vector2(0, 1))
	legs.add_blend_point(_clip("L_Run_B"), Vector2(0, -1))
	# The legacy strafe clips are named backwards: in L_Strafe_L the planted feet sweep toward -X
	# (model left), which is what stepping to the right looks like. Measured with tools/t003_footslide.gd.
	legs.add_blend_point(_clip("L_Strafe_R"), Vector2(-1, 0))
	legs.add_blend_point(_clip("L_Strafe_L"), Vector2(1, 0))
	var crouch_legs := AnimationNodeBlendSpace1D.new()
	crouch_legs.min_space = 0.0
	crouch_legs.add_blend_point(_clip("L_Crouch_Idle"), 0.0)
	crouch_legs.add_blend_point(_clip("L_Crouch_Walk"), 1.0)
	var upper := AnimationNodeTransition.new()
	upper.xfade_time = xfade
	upper.input_count = 3
	upper.set_input_name(0, "aim")
	upper.set_input_name(1, "low")
	upper.set_input_name(2, "reload")
	var mix := AnimationNodeBlend2.new()
	mix.filter_enabled = true
	for b in UPPER_BONES:
		mix.set_filter_path(NodePath(SKELETON_PATH + b), true)
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("legs", legs)
	bt.add_node("legs_rate", AnimationNodeTimeScale.new())
	bt.add_node("crouch_legs", crouch_legs)
	bt.add_node("crouch_rate", AnimationNodeTimeScale.new())
	bt.add_node("crouch", AnimationNodeBlend2.new())
	bt.add_node("aim", _clip("U_Aim"))
	bt.add_node("low", _clip("U_LowReady"))
	bt.add_node("reload", _clip("U_Reload"))
	bt.add_node("reload_rate", AnimationNodeTimeScale.new())
	bt.add_node("upper", upper)
	bt.add_node("mix", mix)
	bt.connect_node("legs_rate", 0, "legs")
	bt.connect_node("crouch_rate", 0, "crouch_legs")
	bt.connect_node("crouch", 0, "legs_rate")
	bt.connect_node("crouch", 1, "crouch_rate")
	bt.connect_node("reload_rate", 0, "reload")
	bt.connect_node("upper", 0, "aim")
	bt.connect_node("upper", 1, "low")
	bt.connect_node("upper", 2, "reload_rate")
	bt.connect_node("mix", 0, "crouch")
	bt.connect_node("mix", 1, "upper")
	bt.connect_node("output", 0, "mix")
	return bt


func start() -> void:
	tree.set("parameters/mix/blend_amount", 1.0)
	tree.set("parameters/crouch/blend_amount", 0.0)


func clip_length(clip_name: String) -> float:
	return tree.get_animation(clip_name).length


## The clip whose length sets the walk's beat.
func cycle_length() -> float:
	return clip_length("L_Run_F")


## Each foot bone, left then right.
func foot_bones() -> Array:
	return ["foot_L", "foot_R"]


func _clip(clip_name: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = clip_name
	return a
