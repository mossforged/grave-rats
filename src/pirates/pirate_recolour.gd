extends RefCounted
## The rival crew's paint: the legacy operator, with its materials swapped by name from
## data/pirates.json "body.materials". The source glTF isn't touched. One set of swapped materials
## is shared by the whole squad.

static var _made := {}


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
