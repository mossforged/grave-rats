extends MeshInstance3D
## The ring on the floor around the operator: a quad big enough for the ring, drawn by
## noise_ring.gdshader, fed by NoiseState. Numbers: data/hud.json "ring".

const NoiseState := preload("res://src/hud/noise_state.gd")
const SHADER := preload("res://src/hud/noise_ring.gdshader")

var state: NoiseState

var _mat: ShaderMaterial


func setup(ring_cfg: Dictionary, enemy_senses: Dictionary) -> void:
	state = NoiseState.new(ring_cfg, enemy_senses)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	mesh = plane
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	top_level = true
	visible = false


## One step: where the operator is, what its feet are doing.
func tick(delta: float, at: Vector3, feet_kind: String) -> void:
	state.step(delta, feet_kind)
	var cfg: Dictionary = state.cfg
	var out := maxf(state.radius, state.ripple)
	visible = out > 0.0
	if not visible:
		return
	var size := (out + float(cfg.line_m)) * 2.0
	global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(size, 1.0, size)), Vector3(at.x, float(cfg.height_m), at.z))
	_mat.set_shader_parameter("size_m", size)
	_mat.set_shader_parameter("radius_m", state.radius)
	_mat.set_shader_parameter("ripple_m", state.ripple)
	_mat.set_shader_parameter("line_m", float(cfg.line_m))
	_mat.set_shader_parameter("segments", float(cfg.segments))
	_mat.set_shader_parameter("gap", float(cfg.gap))
	_mat.set_shader_parameter("cold_color", Color(String(cfg.cold_color)))
	_mat.set_shader_parameter("hot_color", Color(String(cfg.hot_color)))
	_mat.set_shader_parameter("heat", state.heat_at(state.radius))
	_mat.set_shader_parameter("alpha", state.alpha_at(state.radius))
	_mat.set_shader_parameter("ripple_alpha", float(cfg.alpha.ripple) * (1.0 - state.heat_at(state.ripple)))
