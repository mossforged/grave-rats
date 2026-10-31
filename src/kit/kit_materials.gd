extends RefCounted
## The kit's materials and decals, built from data/kit.json "materials" (A006-08) and the textures
## tools/t010_textures.py generates. Cached once per run; make() builds from any config.

const TEX_DIR := "res://assets/game/kit/tex/%s_%s.png"
const DECAL_DIR := "res://assets/game/kit/decals/%s.png"
const FLOOR_SHADER := preload("res://src/kit/kit_floor.gdshader")

static var _cache := {}
static var _decals := {}


static func cfg() -> Dictionary:
	return Data.load_data("kit")


static func uv_metres(key: String) -> float:
	return float((cfg().materials[key] as Dictionary).uv_m)


## Metres of a face's rim that map to the texture's worn edge band; 0 for plain tiling materials.
static func edge_band(key: String) -> float:
	return float((cfg().materials[key] as Dictionary).get("edge_band_m", 0.0))


static func material(key: String) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = make(cfg().materials[key], cfg().material_shared)
	return _cache[key]


static func make(spec: Dictionary, shared: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = bool(shared.vertex_grime)
	m.vertex_color_is_srgb = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = float(spec.get("roughness", 1.0))
	m.metallic = float(spec.get("metallic", 1.0))
	if spec.has("specular"):
		m.metallic_specular = float(spec.specular)
	m.albedo_color = Color(String(spec.get("tint", spec.get("color", "ffffff"))))
	if spec.has("texture"):
		_add_textures(m, String(spec.texture), spec, shared)
	if spec.has("emission"):
		m.emission_enabled = true
		m.emission = Color(String(spec.emission))
		m.emission_energy_multiplier = float(spec.energy)
	return m


## The deck plate as a floor: `deck`'s textures plus the wear map from floor_wear.gd, placed at `rect`.
static func floor_material(wear: Image, rect: Rect2) -> ShaderMaterial:
	var f: Dictionary = cfg().floor_wear
	var spec: Dictionary = cfg().materials.deck
	var tex := String(spec.texture)
	var m := ShaderMaterial.new()
	m.shader = FLOOR_SHADER
	if ResourceLoader.exists(TEX_DIR % [tex, "albedo"]):
		m.set_shader_parameter("albedo_tex", load(TEX_DIR % [tex, "albedo"]))
		m.set_shader_parameter("normal_tex", load(TEX_DIR % [tex, "normal"]))
		m.set_shader_parameter("orm_tex", load(TEX_DIR % [tex, "orm"]))
		m.set_shader_parameter("breakup_tex", load(TEX_DIR % ["breakup", "albedo"]))
	m.set_shader_parameter("wear_map", ImageTexture.create_from_image(wear))
	m.set_shader_parameter("wear_origin", rect.position)
	m.set_shader_parameter("wear_size", rect.size)
	m.set_shader_parameter("normal_scale", float(spec.get("normal_scale", cfg().material_shared.normal_scale)))
	m.set_shader_parameter("ao_light_affect", float(cfg().material_shared.ao_light_affect))
	for key: String in ["breakup_m", "traffic_rough", "traffic_bright", "traffic_metal", "damp_rough", "damp_dark", "damp_flatten", "damp_edge", "damp_soft"]:
		m.set_shader_parameter(key, float(f.look[key]))
	return m


## The sign `image` as a cut-out: alpha scissor keeps it in the opaque pass, so the sight mask, which
## draws first among the transparents, darkens it like any wall.
static func decal(image: String) -> StandardMaterial3D:
	if _decals.has(image):
		return _decals[image]
	var s: Dictionary = cfg().signage
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = float(s.alpha_scissor)
	m.roughness = float(s.roughness)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var path := DECAL_DIR % image
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	_decals[image] = m
	return m


static func _add_textures(m: StandardMaterial3D, tex: String, spec: Dictionary, shared: Dictionary) -> void:
	var albedo := TEX_DIR % [tex, "albedo"]
	if not ResourceLoader.exists(albedo):
		push_warning("kit: no texture %s; run tools/t010_textures.py and import" % albedo)
		return
	m.albedo_texture = load(albedo)
	m.normal_enabled = true
	m.normal_scale = float(spec.get("normal_scale", shared.normal_scale))
	m.normal_texture = load(TEX_DIR % [tex, "normal"])
	var orm: Texture2D = load(TEX_DIR % [tex, "orm"])
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = orm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = float(shared.ao_light_affect)
