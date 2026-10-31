extends Node3D
## "Here they are": a ring pulsing on the floor and a column of light, over the sight mask so it reads
## from anywhere. Follows one player for as long as the alarm reveals them. data/shift.json "alarm.marker".

var cfg: Dictionary
var time_left := 0.0
var on := false

var _mat: StandardMaterial3D
var _ring: MeshInstance3D
var _column: MeshInstance3D
var _t := 0.0


func setup(config: Dictionary) -> void:
	cfg = config
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.no_depth_test = true
	_mat.albedo_color = Color(String(cfg.color))
	_mat.emission_enabled = true
	_mat.emission = Color(String(cfg.color))
	_mat.emission_energy_multiplier = float(cfg.energy)
	var r := float(cfg.radius_m)
	var w := float(cfg.ring_width_m)
	var torus := TorusMesh.new()
	torus.inner_radius = r - w
	torus.outer_radius = r + w
	torus.rings = int(cfg.segments)
	torus.ring_segments = int(cfg.segments)
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = torus
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = float(cfg.height_m)
	add_child(_ring)
	var cyl := CylinderMesh.new()
	cyl.top_radius = float(cfg.column_radius_m)
	cyl.bottom_radius = float(cfg.column_radius_m)
	cyl.height = float(cfg.column_height_m)
	_column = MeshInstance3D.new()
	_column.name = "Column"
	_column.mesh = cyl
	_column.material_override = _mat
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.position.y = float(cfg.column_height_m) * 0.5
	add_child(_column)
	hide_now()


func show_for(seconds: float) -> void:
	time_left = seconds
	on = true
	_t = 0.0
	visible = true


func hide_now() -> void:
	time_left = 0.0
	on = false
	visible = false


func tick(delta: float, at: Vector2) -> void:
	if not on:
		return
	global_position = Vector3(at.x, 0.0, at.y)
	_t += delta
	time_left = maxf(time_left - delta, 0.0)
	if time_left == 0.0:
		hide_now()
		return
	# 0 to 1 and back; the ring grows through each pulse and fades as it goes.
	var phase := fmod(_t * float(cfg.pulse_hz), 1.0)
	_ring.scale = Vector3.ONE * lerpf(1.0, float(cfg.pulse_grow), phase)
	_mat.albedo_color.a = lerpf(1.0, float(cfg.min_alpha), phase)


func alpha() -> float:
	return _mat.albedo_color.a
