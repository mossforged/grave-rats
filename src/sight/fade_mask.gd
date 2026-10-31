extends Node
## Keeps cut-away surfaces under the sight mask. A faded GeometryInstance3D is transparent, so it draws
## after the mask's quad and a wall in unknown space would stay lit. While one is faded this gives its
## surfaces a copy of their material with the mask lookup in it (faded_surface.gdshader), and hands the
## originals back when it isn't. Runs after the camera rig has set this frame's fades.

const SHADER := preload("res://src/sight/faded_surface.gdshader")
const CUTAWAY_GROUP := &"camera_cutaway"  # the camera rig's contract
const SAVED_META := &"fade_mask_saved"

var _mask: Node
var _copies := {}


func setup(mask: Node) -> void:
	_mask = mask
	name = "FadeMask"
	process_priority = 100


func _process(_delta: float) -> void:
	sync_now()


## Public so tests can drive it.
func sync_now() -> void:
	for n: Node in get_tree().get_nodes_in_group(CUTAWAY_GROUP):
		for g: Node in n.get_children():
			if g is MeshInstance3D:
				_sync(g)


func masked_surfaces() -> int:
	var count := 0
	for n: Node in get_tree().get_nodes_in_group(CUTAWAY_GROUP):
		for g: Node in n.get_children():
			if g.has_meta(SAVED_META):
				count += 1
	return count


func _sync(mi: MeshInstance3D) -> void:
	var faded := mi.transparency > 0.0
	if faded == mi.has_meta(SAVED_META):
		if faded:
			_refresh(mi)
		return
	if faded:
		_swap_in(mi)
	else:
		_swap_out(mi)


func _swap_in(mi: MeshInstance3D) -> void:
	var saved: Array = []
	for i in mi.mesh.get_surface_count():
		saved.append(mi.get_surface_override_material(i))
		var source := _source(mi, i)
		if source != null:
			mi.set_surface_override_material(i, _copy_of(source))
	mi.set_meta(SAVED_META, saved)


func _swap_out(mi: MeshInstance3D) -> void:
	var saved: Array = mi.get_meta(SAVED_META)
	for i in saved.size():
		mi.set_surface_override_material(i, saved[i])
	mi.remove_meta(SAVED_META)


## A door leaf's paint darkens under blows, and it may do that mid-fade.
func _refresh(mi: MeshInstance3D) -> void:
	var saved: Array = mi.get_meta(SAVED_META)
	for i in saved.size():
		if saved[i] is BaseMaterial3D:
			var copy := mi.get_surface_override_material(i) as ShaderMaterial
			copy.set_shader_parameter("tint", (saved[i] as BaseMaterial3D).albedo_color)


## The surface's real material, if it's one this can copy. A material_override or a shader of its own
## (door lamps) already knows what it's doing.
func _source(mi: MeshInstance3D, i: int) -> BaseMaterial3D:
	if mi.material_override != null:
		return null
	var m := mi.get_surface_override_material(i)
	if m == null:
		m = mi.mesh.surface_get_material(i)
	return m as BaseMaterial3D


func _copy_of(src: BaseMaterial3D) -> ShaderMaterial:
	if _copies.has(src):
		return _copies[src]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tint", src.albedo_color)
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("roughness", src.roughness)
	m.set_shader_parameter("metallic", src.metallic)
	m.set_shader_parameter("specular", src.metallic_specular)
	m.set_shader_parameter("ao_light_affect", src.ao_light_affect)
	if src.normal_enabled:
		m.set_shader_parameter("has_normal", true)
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("normal_scale", src.normal_scale)
	if src.roughness_texture != null:
		m.set_shader_parameter("has_orm", true)
		m.set_shader_parameter("orm_tex", src.roughness_texture)
	if src.emission_enabled:
		m.set_shader_parameter("emission_color", Vector3(src.emission.r, src.emission.g, src.emission.b))
		m.set_shader_parameter("emission_energy", src.emission_energy_multiplier)
	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.set_shader_parameter("scissor", src.alpha_scissor_threshold)
	_mask.bind(m)
	_copies[src] = m
	return m
