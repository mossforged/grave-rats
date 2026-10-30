extends Node3D
## A pirate's flashlight: a shadowed spot at the muzzle and the same beam as the player's (BeamFan). Colder than yours, so you can tell whose it is. Numbers from data/pirates.json "flashlight".

const BeamFan := preload("res://src/sight/beam_fan.gd")
const BEAM_SHADER := preload("res://src/sight/beam.gdshader")

var cfg: Dictionary
var spot: SpotLight3D
var fan: BeamFan

var _mesh: ImmediateMesh
var _mat: ShaderMaterial
var _beam: MeshInstance3D
var _since_beam := INF


func setup(config: Dictionary) -> void:
	cfg = config
	spot = SpotLight3D.new()
	spot.name = "Spot"
	spot.shadow_enabled = bool(cfg.shadows)
	spot.shadow_blur = float(cfg.shadow_blur)
	add_child(spot)
	_mesh = ImmediateMesh.new()
	_mat = ShaderMaterial.new()
	_mat.shader = BEAM_SHADER
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = _mesh
	_beam.material_override = _mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.extra_cull_margin = float(cfg.range_m)
	add_child(_beam)
	fan = BeamFan.new(int(cfg.beam_rays))
	apply_cfg()
	set_on(bool(cfg.start_on))


func apply_cfg() -> void:
	spot.light_color = Color(String(cfg.color))
	spot.light_energy = float(cfg.energy)
	spot.spot_range = float(cfg.range_m)
	spot.spot_angle = float(cfg.half_angle_deg)
	spot.spot_attenuation = float(cfg.attenuation)
	spot.spot_angle_attenuation = float(cfg.angle_attenuation)
	_mat.set_shader_parameter("beam_color", Color(String(cfg.color)))
	_mat.set_shader_parameter("strength", float(cfg.beam_strength))
	_mat.set_shader_parameter("fade_power", float(cfg.beam_fade_power))
	_mat.set_shader_parameter("edge_power", float(cfg.beam_edge_power))
	_mat.set_shader_parameter("tan_half", tan(deg_to_rad(float(cfg.half_angle_deg))))
	fan.configure(deg_to_rad(float(cfg.half_angle_deg)), float(cfg.range_m), float(cfg.beam_reach_rate_m_s), float(cfg.beam_snap_m))


func set_mask(texture: Texture2D, bounds: Rect2) -> void:
	_mat.set_shader_parameter("visible_mask", texture)
	_mat.set_shader_parameter("mask_origin", bounds.position)
	_mat.set_shader_parameter("mask_size", bounds.size)


func set_on(value: bool) -> void:
	spot.visible = value
	_beam.visible = value
	fan.restart()


func follow(muzzle: Vector3, yaw: float) -> void:
	var pitch := deg_to_rad(float(cfg.pitch_deg))
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), muzzle)


## The fixed fan from the muzzle. `visibility` is the player's Visibility, which knows the walls and
## doors; asked at beam_hz, since it isn't free. The fan eases to its answer every step regardless.
func draw_beam(delta: float, visibility: RefCounted, eye: Vector2, yaw: float, muzzle: Vector3) -> void:
	if not _beam.visible:
		return
	var at := Vector2(muzzle.x, muzzle.z)
	_since_beam += delta
	if _since_beam >= 1.0 / float(cfg.beam_hz):
		_since_beam = 0.0
		fan.cast(visibility, eye, at, yaw)
	fan.step(delta, at, yaw)
	fan.fill(_mesh, muzzle, deg_to_rad(float(cfg.pitch_deg)), float(cfg.beam_floor_m))
