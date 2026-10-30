extends Node3D
## A pirate's flashlight: a shadowed spot at the muzzle and a beam sheet cut by the same walls the
## player's is. Colder than yours, so you can tell whose it is. Numbers from data/pirates.json "flashlight".

const BEAM_SHADER := preload("res://src/pirates/pirate_beam.gdshader")

var cfg: Dictionary
var spot: SpotLight3D

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


func set_mask(texture: Texture2D, bounds: Rect2) -> void:
	_mat.set_shader_parameter("visible_mask", texture)
	_mat.set_shader_parameter("mask_origin", bounds.position)
	_mat.set_shader_parameter("mask_size", bounds.size)


func set_on(value: bool) -> void:
	spot.visible = value
	_beam.visible = value


func follow(muzzle: Vector3, yaw: float) -> void:
	var pitch := deg_to_rad(float(cfg.pitch_deg))
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), muzzle)


## A fan over the part of a sight polygon inside this light's wedge. `visibility` is the player's
## Visibility, which knows the walls and doors; asked at beam_hz, since it isn't free.
func draw_beam(delta: float, visibility: RefCounted, eye: Vector2, yaw: float, muzzle: Vector3) -> void:
	_since_beam += delta
	if _since_beam < 1.0 / float(cfg.beam_hz) or not _beam.visible:
		return
	_since_beam = 0.0
	var half := deg_to_rad(float(cfg.half_angle_deg))
	var range_m := float(cfg.range_m)
	var ring := PackedVector2Array()
	for p: Vector2 in visibility.polygon(eye, yaw, true):
		var to := p - eye
		if absf(angle_difference(yaw, atan2(-to.x, -to.y))) <= half:
			ring.append(eye + to.limit_length(range_m))
	_mesh.clear_surfaces()
	if ring.size() < 2:
		return
	var start_y := float(cfg.beam_start_height_m)
	var end_y := float(cfg.beam_end_height_m)
	var apex := Vector3(muzzle.x, start_y, muzzle.z)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size() - 1:
		_mesh.surface_set_uv(Vector2.ZERO)
		_mesh.surface_add_vertex(apex)
		for k in 2:
			var p := ring[i + k]
			var t := minf(eye.distance_to(p) / range_m, 1.0)
			_mesh.surface_set_uv(Vector2(t, 0.0))
			_mesh.surface_add_vertex(Vector3(p.x, lerpf(start_y, end_y, t), p.y))
	_mesh.surface_end()
