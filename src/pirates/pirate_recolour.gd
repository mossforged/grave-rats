extends RefCounted
## The rival crew's paint: the legacy operator, with its materials swapped by name from
## data/pirates.json "body.materials". The source glTF isn't touched. One set of swapped materials
## is shared by the whole squad. The hauler is one baked material, so its paint is a shader over the
## same textures, from "body.hauler_paint".

const HAULER_SHADER := preload("res://src/pirates/hauler_paint.gdshader")

static var _made := {}
static var _hauler_made: ShaderMaterial


static func apply(model_root: Node, cfg: Dictionary) -> void:
	for m: MeshInstance3D in model_root.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null or not cfg.has(mat.resource_name):
				continue
			m.set_surface_override_material(i, _swap(mat, cfg[mat.resource_name]))


static func _swap(mat: BaseMaterial3D, spec: Dictionary) -> BaseMaterial3D:
	var key := "%s %s %s %s" % [mat.resource_name, spec.color, spec.drop_texture, spec.roughness]
	if _made.has(key):
		return _made[key]
	var out := mat.duplicate() as BaseMaterial3D
	out.albedo_color = Color(String(spec.color))
	if bool(spec.drop_texture):
		out.albedo_texture = null
	out.roughness = float(spec.roughness)
	if spec.has("emission"):
		out.emission = Color(String(spec.emission))
	_made[key] = out
	return out


## Repaints a hauler by colour: its orange plates and its fabric. No effect on a legacy body.
static func apply_hauler(model_root: Node, cfg: Dictionary) -> void:
	for m: MeshInstance3D in model_root.find_children("*", "MeshInstance3D", true, false):
		if not m.mesh.get_surface_count() or m.name == "Rifle":
			continue
		var mat := m.mesh.surface_get_material(0) as BaseMaterial3D
		if mat == null or mat.resource_name != "BakedMaterial":
			continue
		if _hauler_made == null:
			_hauler_made = _hauler_paint(mat, cfg)
		m.set_surface_override_material(0, _hauler_made)


static func _hauler_paint(mat: BaseMaterial3D, cfg: Dictionary) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = HAULER_SHADER
	out.set_shader_parameter("albedo_tex", mat.albedo_texture)
	out.set_shader_parameter("normal_tex", mat.normal_texture)
	out.set_shader_parameter("orm_tex", mat.roughness_texture)
	out.set_shader_parameter("normal_scale", mat.normal_scale)
	for key: String in ["plate_color", "fabric_color"]:
		out.set_shader_parameter(key, Color(String(cfg[key])))
	for key: String in ["plate_hue_center", "plate_hue_width", "plate_saturation_min", "plate_value_min",
			"plate_gain", "fabric_saturation_max", "fabric_value_min", "fabric_gain"]:
		out.set_shader_parameter(key, float(cfg[key]))
	return out
