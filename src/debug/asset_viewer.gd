extends Node3D
## Dev viewer for the legacy pass-05 assets (scenes/dev/asset_viewer.tscn).
## Lights, camera and environment numbers come from data/viewer.json. Animation is advanced
## manually from one clock so the capture tool can freeze any pose (see capture_shots()).

const LOWER_BONES := ["root", "pelvis", "thigh_L", "thigh_R", "shin_L", "shin_R", "foot_L", "foot_R"]
const UPPER_BONES := ["spine1", "spine2", "clavicle_L", "upperarm_L", "forearm_L", "hand_L",
	"clavicle_R", "upperarm_R", "forearm_R", "hand_R", "neck", "head", "weapon", "mag"]

@onready var _camera: Camera3D = $Camera3D
@onready var _runner: Node3D = $Operator1
@onready var _roller: Node3D = $Operator2
@onready var _robot: Node3D = $Robot

var _cfg: Dictionary
var _run_tree: AnimationTree
var _roll_player: AnimationPlayer
var _robot_player: AnimationPlayer
var _roll_t := 0.0
var _frozen := false


func _ready() -> void:
	_cfg = Data.load_data("viewer")
	_setup_environment(_cfg.environment)
	_setup_camera(_cfg.camera)
	_setup_lights()
	for op in [_runner, _roller]:
		var gun: Node3D = op.find_child("Shotgun", true, false)
		if gun:
			gun.visible = false
	_run_tree = _make_layered_tree(_runner, "L_Run_F", "U_Aim")
	_roll_player = _find_player(_roller)
	_roll_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_roll_player.play("F_Roll")
	_robot_player = _robot.get_node("AnimationPlayer")
	_robot_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_robot_player.play("L_Walk_F")


func _process(delta: float) -> void:
	if _frozen:
		return
	_run_tree.advance(delta)
	_robot_player.advance(delta)
	_roll_t += delta
	var roll_len := _roll_player.get_animation("F_Roll").length
	if _roll_t > roll_len + float(_cfg.roll_pause_s):
		_roll_t = 0.0
		_roll_player.seek(0.0, true)
	else:
		_roll_player.advance(delta)


# --- capture hooks (src/debug/capture.gd calls these) ---

func capture_shots() -> Array:
	return _cfg.shots


## Freezes every animation at shot.time and frames the camera on shot.focus.
func apply_shot(shot: Dictionary) -> void:
	_frozen = true
	var t := float(shot.time)
	_run_tree.set("parameters/Seek/seek_request", t)
	_run_tree.advance(0.0)
	_roll_player.seek(t, true)
	_robot_player.seek(t, true)
	var focus: Node3D = get_node(String(shot.focus))
	var target := focus.global_position + Vector3(0, 0.9, 0)
	_camera.fov = float(shot.fov)
	_camera.look_at_from_position(target + _vec(shot.offset), target)


func release_shot() -> void:
	_frozen = false
	_setup_camera(_cfg.camera)


# --- setup ---

## Operator: lower body from `lower`, upper body (spine up, arms, weapon) from `upper`.
func _make_layered_tree(actor: Node3D, lower: String, upper: String) -> AnimationTree:
	var player := _find_player(actor)
	var bt := AnimationNodeBlendTree.new()
	var a_low := AnimationNodeAnimation.new()
	a_low.animation = lower
	var a_up := AnimationNodeAnimation.new()
	a_up.animation = upper
	var blend := AnimationNodeBlend2.new()
	blend.filter_enabled = true
	for b in UPPER_BONES:
		blend.set_filter_path(NodePath("Rig/Skeleton3D:" + b), true)
	var seek := AnimationNodeTimeSeek.new()
	bt.add_node("Lower", a_low, Vector2(0, 0))
	bt.add_node("Upper", a_up, Vector2(0, 200))
	bt.add_node("Layer", blend, Vector2(300, 100))
	bt.add_node("Seek", seek, Vector2(500, 100))
	bt.connect_node("Layer", 0, "Lower")
	bt.connect_node("Layer", 1, "Upper")
	bt.connect_node("Seek", 0, "Layer")
	bt.connect_node("output", 0, "Seek")
	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = bt
	player.get_parent().add_child(tree)
	tree.root_node = tree.get_path_to(player.get_node(player.root_node))
	tree.anim_player = tree.get_path_to(player)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.set("parameters/Layer/blend_amount", 1.0)
	tree.active = true
	return tree


func _find_player(actor: Node) -> AnimationPlayer:
	return actor.find_children("*", "AnimationPlayer", true, false)[0]


func _setup_environment(e: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(e.background_color)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(e.ambient_color)
	env.ambient_light_energy = float(e.ambient_energy)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX if e.tonemap == "agx" else Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(e.exposure)
	env.glow_enabled = true
	env.glow_intensity = float(e.glow_intensity)
	env.glow_bloom = float(e.glow_bloom)
	env.glow_hdr_threshold = float(e.glow_hdr_threshold)
	env.ssao_enabled = true
	env.ssao_radius = float(e.ssao_radius)
	env.ssao_intensity = float(e.ssao_intensity)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(e.fog_density)
	env.volumetric_fog_albedo = Color(e.fog_albedo)
	env.volumetric_fog_emission = Color(e.fog_emission)
	env.volumetric_fog_anisotropy = float(e.fog_anisotropy)
	env.volumetric_fog_length = float(e.fog_length)
	$WorldEnvironment.environment = env


func _setup_camera(c: Dictionary) -> void:
	_camera.fov = float(c.fov)
	_camera.near = float(c.near)
	_camera.far = float(c.far)
	_camera.look_at_from_position(_vec(c.position), _vec(c.target))


func _setup_lights() -> void:
	var f: Dictionary = _cfg.flashlight
	var spot: SpotLight3D = $Operator1/Flashlight
	spot.position = _vec(f.local_position)
	spot.rotation_degrees = Vector3(float(f.pitch_deg), 0, 0)
	spot.light_color = Color(f.color)
	spot.light_energy = float(f.energy)
	spot.spot_range = float(f.range)
	spot.spot_angle = float(f.angle_deg)
	spot.spot_attenuation = float(f.attenuation)
	spot.spot_angle_attenuation = float(f.angle_attenuation)
	spot.shadow_enabled = bool(f.shadows)
	for key in ["practical_cool", "practical_amber"]:
		var p: Dictionary = _cfg[key]
		var omni: OmniLight3D = get_node(key.to_pascal_case())
		omni.position = _vec(p.position)
		omni.light_color = Color(p.color)
		omni.light_energy = float(p.energy)
		omni.omni_range = float(p.range)
		omni.omni_attenuation = float(p.attenuation)
		omni.shadow_enabled = bool(p.shadows)


func _vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
