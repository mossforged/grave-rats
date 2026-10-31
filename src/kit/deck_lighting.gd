extends Node3D
## The deck's mood, from data/kit.json "lighting": the environment (dark ambient, glow, SSAO, fog in
## a box the size of the ship) and the practicals (strip fixtures with their lights, on the walls).
## The sight mask stays the authority: it sits on top of all of this and darkens what you don't know.
## Env KIT_FOG, KIT_PRACTICALS, KIT_SSAO, KIT_GLOW = off switch one thing off to price it. KIT_SHEEN =
## probe, ssr or off overrides how the floors get their wet sheen.

const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")

var cfg: Dictionary
var lights: Array[Light3D] = []
var fog_volume: FogVolume
var probes: Array[ReflectionProbe] = []

## Gives each fixture a home on the wall behind it, so it fades with the wall.
func setup(layout: RefCounted, env: Environment, deck: Node3D) -> void:
	cfg = KitMaterials.cfg().lighting
	name = "DeckLighting"
	_apply_environment(env, layout)
	_apply_sheen(env, layout)
	if _switched_on("KIT_PRACTICALS"):
		_place_fixtures(layout, deck.get_node("Walls"))


func _switched_on(env_name: String) -> bool:
	return OS.get_environment(env_name) != "off"


func _apply_environment(env: Environment, layout: RefCounted) -> void:
	var e: Dictionary = cfg.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(String(e.background_color))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(String(e.ambient_color))
	env.ambient_light_energy = float(e.ambient_energy)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX if String(e.tonemap) == "agx" else Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(e.exposure)
	env.glow_enabled = bool(e.glow) and _switched_on("KIT_GLOW")
	env.glow_intensity = float(e.glow_intensity)
	env.glow_bloom = float(e.glow_bloom)
	env.glow_hdr_threshold = float(e.glow_hdr_threshold)
	env.ssao_enabled = bool(e.ssao) and _switched_on("KIT_SSAO")
	env.ssao_radius = float(e.ssao_radius)
	env.ssao_intensity = float(e.ssao_intensity)
	env.ssao_power = float(e.ssao_power)
	env.ssao_light_affect = float(e.ssao_light_affect)
	var ssao_q: int = RenderingServer.ENV_SSAO_QUALITY_LOW if String(e.ssao_quality) == "low" else RenderingServer.ENV_SSAO_QUALITY_MEDIUM
	var ssao_half: bool = ProjectSettings.get_setting("rendering/environment/ssao/half_size")
	var ssao_adapt: float = ProjectSettings.get_setting("rendering/environment/ssao/adaptive_target")
	var ssao_blur: int = ProjectSettings.get_setting("rendering/environment/ssao/blur_passes")
	var ssao_fade0: float = ProjectSettings.get_setting("rendering/environment/ssao/fadeout_from")
	var ssao_fade1: float = ProjectSettings.get_setting("rendering/environment/ssao/fadeout_to")
	RenderingServer.environment_set_ssao_quality(ssao_q, ssao_half, ssao_adapt, ssao_blur, ssao_fade0, ssao_fade1)
	var f: Dictionary = cfg.fog
	var fog_on := bool(f.enabled) and _switched_on("KIT_FOG")
	env.volumetric_fog_enabled = fog_on
	if not fog_on:
		return
	RenderingServer.environment_set_volumetric_fog_volume_size(int(f.volume_size), int(f.volume_depth))
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_albedo = Color(String(f.albedo))
	env.volumetric_fog_emission = Color(String(f.emission))
	env.volumetric_fog_emission_energy = float(f.emission_energy)
	env.volumetric_fog_anisotropy = float(f.anisotropy)
	env.volumetric_fog_length = float(f.length_m)
	env.volumetric_fog_detail_spread = float(f.detail_spread)
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = float(f.temporal_reprojection)
	# Fog only inside the ship: the camera looks down through 20 m of nothing to get here.
	var mat := FogMaterial.new()
	mat.density = float(f.density)
	mat.albedo = Color(String(f.albedo))
	fog_volume = FogVolume.new()
	fog_volume.name = "ShipFog"
	fog_volume.material = mat
	fog_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var b: Rect2 = layout.bounds.grow(float(f.margin_m))
	var h := float(f.height_m)
	fog_volume.size = Vector3(b.size.x, h, b.size.y)
	fog_volume.position = Vector3(b.get_center().x, h * 0.5, b.get_center().y)
	add_child(fog_volume)


## One cheap probe per room, or screen-space reflections. The handoff has what each costs.
func _apply_sheen(env: Environment, layout: RefCounted) -> void:
	var sheen: Dictionary = cfg.sheen
	var mode := OS.get_environment("KIT_SHEEN")
	if mode == "":
		mode = String(sheen.mode)
	env.ssr_enabled = mode == "ssr"
	if mode == "ssr":
		var s: Dictionary = sheen.ssr
		env.ssr_max_steps = int(s.max_steps)
		env.ssr_fade_in = float(s.fade_in)
		env.ssr_fade_out = float(s.fade_out)
		env.ssr_depth_tolerance = float(s.depth_tolerance)
	elif mode == "probe":
		for space: String in layout.space_order:
			_place_probe(layout, space, sheen.probe)


## Sees only its room's static layer: not people, doors or the sight mask, which all sit on layer 1.
func _place_probe(layout: RefCounted, space: String, p: Dictionary) -> void:
	var r: Rect2 = layout.space_rect(space)
	var layer: int = KitPieces.space_layer(layout, space)
	var probe := ReflectionProbe.new()
	probe.name = "Probe_%s" % space
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.box_projection = true
	probe.interior = true
	probe.enable_shadows = false
	probe.intensity = float(p.intensity)
	probe.blend_distance = float(p.blend_m)
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.cull_mask = layer
	probe.reflection_mask = layer
	probe.size = Vector3(r.size.x, float(p.height_m), r.size.y)
	probe.max_distance = float(p.max_distance_m)
	probe.position = Vector3(r.get_center().x, float(p.y_m), r.get_center().y)
	add_child(probe)
	probes.append(probe)


func _place_fixtures(layout: RefCounted, walls: Node3D) -> void:
	var fx: Dictionary = cfg.fixtures
	var spaces: Dictionary = fx.spaces
	for space: String in layout.space_order:
		if not spaces.has(space):
			continue
		for e: Dictionary in spaces[space]:
			_place_fixture(layout, walls, space, e, fx)


func _place_fixture(layout: RefCounted, walls: Node3D, space: String, e: Dictionary, fx: Dictionary) -> void:
	var r: Rect2 = layout.space_rect(space)
	var t := float(layout.data.wall_thickness_m)
	var wall := String(e.wall)
	var at := float(e.at)
	var face: Vector2
	var inward: Vector2
	match wall:
		"north":
			face = Vector2(r.position.x + r.size.x * at, r.position.y)
			inward = Vector2.DOWN
		"south":
			face = Vector2(r.position.x + r.size.x * at, r.end.y)
			inward = Vector2.UP
		"west":
			face = Vector2(r.position.x, r.position.y + r.size.y * at)
			inward = Vector2.RIGHT
		_:
			face = Vector2(r.end.x, r.position.y + r.size.y * at)
			inward = Vector2.LEFT
	var look: Dictionary = fx.looks[String(e.look)]
	var vertical := bool(e.get("vertical", false))
	var host: Node3D = DeckBuilder.wall_at(walls, face - inward * t * 0.5)
	var layer: int = KitPieces.space_layer(layout, space)
	if host != null:
		var mi := MeshInstance3D.new()
		mi.name = "Fixture"
		mi.mesh = KitPieces.fixture(String(look.mat), vertical)
		mi.set_meta("kit_piece", "fixture")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = layer
		var y := float(fx.vertical_y_m if vertical else fx.default_y_m)
		mi.position = Vector3(face.x - host.position.x, y, face.y - host.position.z)
		mi.rotation.y = atan2(inward.x, inward.y)
		host.add_child(mi)
	var light := OmniLight3D.new()
	light.name = "Practical_%s_%s" % [space, wall]
	light.light_color = Color(String(look.color))
	light.light_energy = float(look.energy)
	light.omni_range = float(look.range_m)
	light.omni_attenuation = float(look.attenuation)
	light.light_specular = float(look.specular)
	light.light_volumetric_fog_energy = float(cfg.fog.practical_energy)
	light.light_cull_mask = 1 | layer
	light.shadow_enabled = bool(e.get("shadow", false))
	light.shadow_blur = float(fx.shadow_blur)
	var out := float(fx.light_out_m)
	light.position = Vector3(face.x + inward.x * out, float(fx.light_y_m), face.y + inward.y * out)
	add_child(light)
	lights.append(light)
