extends Node3D
## The weapon light: a shadowed SpotLight3D at the muzzle, a beam sheet cut to the sight polygon
## and dust motes that only show inside it. The cone comes from data/sight.json "cone_on", the
## same numbers sight uses, so light and knowledge match.

const Visibility := preload("res://src/sight/visibility.gd")
const BEAM_SHADER := preload("res://src/sight/beam.gdshader")
const MOTE_SHADER := preload("res://src/sight/mote.gdshader")

var on := true
var cfg: Dictionary
var spot: SpotLight3D

var _beam: MeshInstance3D
var _beam_mesh: ImmediateMesh
var _beam_mat: ShaderMaterial
var _motes: CPUParticles3D
var _mote_mat: ShaderMaterial


func setup(config: Dictionary) -> void:
	cfg = config
	var f: Dictionary = cfg.flashlight
	spot = SpotLight3D.new()
	spot.name = "Spot"
	spot.shadow_enabled = bool(f.shadows)
	spot.shadow_blur = float(f.shadow_blur)
	add_child(spot)
	_beam_mesh = ImmediateMesh.new()
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = BEAM_SHADER
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = _beam_mesh
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.extra_cull_margin = float(cfg.cone_on.range_m)
	add_child(_beam)
	_make_motes()
	apply_cfg()
	set_on(bool(f.start_on))


func _make_motes() -> void:
	var m: Dictionary = cfg.motes
	var half := float(m.box_half_m)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(m.size_m)
	_mote_mat = ShaderMaterial.new()
	_mote_mat.shader = MOTE_SHADER
	quad.material = _mote_mat
	_motes = CPUParticles3D.new()
	_motes.name = "Motes"
	_motes.amount = int(m.count)
	_motes.lifetime = float(m.lifetime_s)
	_motes.randomness = 1.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(half, float(m.height_m) * 0.5, half)
	_motes.direction = Vector3.UP
	_motes.spread = float(m.spread_deg)
	_motes.initial_velocity_min = 0.0
	_motes.initial_velocity_max = float(m.drift_m_s)
	_motes.gravity = Vector3.ZERO
	_motes.mesh = quad
	_motes.local_coords = false
	_motes.top_level = true
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)


## The motes hide where the sight mask is dark, so none shine through a wall.
func set_mask(texture: Texture2D, bounds: Rect2) -> void:
	_mote_mat.set_shader_parameter("visible_mask", texture)
	_mote_mat.set_shader_parameter("mask_origin", bounds.position)
	_mote_mat.set_shader_parameter("mask_size", bounds.size)


## Data to nodes. Called at setup, and while the tuning panel is open.
func apply_cfg() -> void:
	var f: Dictionary = cfg.flashlight
	var c: Dictionary = cfg.cone_on
	var b: Dictionary = cfg.beam
	var m: Dictionary = cfg.motes
	spot.light_color = Color(f.color)
	spot.light_energy = float(f.energy)
	spot.spot_range = float(c.range_m)
	spot.spot_angle = spot_angle_deg()
	spot.spot_attenuation = float(f.attenuation)
	spot.spot_angle_attenuation = float(f.angle_attenuation)
	_beam_mat.set_shader_parameter("beam_color", Color(b.color))
	_beam_mat.set_shader_parameter("strength", float(b.strength))
	_beam_mat.set_shader_parameter("fade_power", float(b.fade_power))
	_mote_mat.set_shader_parameter("mote_color", Color(m.color))
	_mote_mat.set_shader_parameter("strength", float(m.strength))
	_mote_mat.set_shader_parameter("half_angle", deg_to_rad(float(c.half_angle_deg)))
	_mote_mat.set_shader_parameter("range_m", float(c.range_m))


## The light starts at the muzzle, ahead of the eye the sight wedge starts from. This angle makes
## the lit cone as wide as the wedge at full range.
func spot_angle_deg() -> float:
	var r := float(cfg.cone_on.range_m)
	var half := deg_to_rad(float(cfg.cone_on.half_angle_deg))
	return rad_to_deg(atan2(r * tan(half), r - float(cfg.flashlight.muzzle_ahead_m)))


func set_on(value: bool) -> void:
	on = value
	spot.visible = on
	_beam.visible = on
	_motes.visible = on
	_motes.emitting = on


func toggle() -> void:
	set_on(not on)


## Places the light at the muzzle along the gun's yaw, and keeps the motes around it.
func follow(muzzle: Vector3, yaw: float) -> void:
	var pitch := deg_to_rad(float(cfg.flashlight.pitch_deg))
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), muzzle)
	_motes.global_position = Vector3(muzzle.x, float(cfg.motes.height_m) * 0.5, muzzle.z)
	_mote_mat.set_shader_parameter("beam_origin", muzzle)
	var d := Visibility.yaw_dir2(yaw)
	_mote_mat.set_shader_parameter("beam_dir", d)


## Rebuilds the beam sheet: a fan from the muzzle over the part of the polygon inside the wedge.
func draw_beam(polygon: PackedVector2Array, eye: Vector2, yaw: float, muzzle: Vector3) -> void:
	_beam_mesh.clear_surfaces()
	if not on:
		return
	var c: Dictionary = cfg.cone_on
	var half := deg_to_rad(float(c.half_angle_deg))
	var ahead := float(cfg.flashlight.muzzle_ahead_m)
	var range_m := float(c.range_m)
	var start_y := float(cfg.beam.start_height_m)
	var end_y := float(cfg.beam.end_height_m)
	var ring := PackedVector2Array()
	for p in polygon:
		var to := p - eye
		if absf(angle_difference(yaw, atan2(-to.x, -to.y))) <= half:
			# Closer than the muzzle: pushed out to it. Dropping the point would join its neighbours
			# in one big triangle that snapped in and out as a wall came within reach.
			ring.append(eye + to.normalized() * ahead if to.length() < ahead else p)
	if ring.size() < 2:
		return
	var apex := Vector3(muzzle.x, start_y, muzzle.z)
	var apex2 := Vector2(muzzle.x, muzzle.z)
	_beam_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size() - 1:
		_beam_mesh.surface_set_uv(Vector2.ZERO)
		_beam_mesh.surface_add_vertex(apex)
		for k in 2:
			var p := ring[i + k]
			var t := minf(apex2.distance_to(p) / range_m, 1.0)
			_beam_mesh.surface_set_uv(Vector2(t, 0.0))
			_beam_mesh.surface_add_vertex(Vector3(p.x, lerpf(start_y, end_y, t), p.y))
	_beam_mesh.surface_end()
