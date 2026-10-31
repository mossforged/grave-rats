// The deck plates: the same PBR stack as a plain kit material, plus where feet went and where it's damp,
// from src/kit/floor_wear.gd's map in world XZ. Traffic polishes and lightens; damp darkens a touch and
// goes glossy, with less normal showing through. Nothing here has an edge: fine `breakup` grain fades both
// in and out, so wear reads as scuffing and sheen rather than as patches. `base_damp` is the whole
// floor's film of damp; `tone` the slow unevenness of old steel.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D breakup_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D wear_map : hint_default_black, filter_linear, repeat_disable;
uniform vec2 wear_origin;
uniform vec2 wear_size = vec2(1.0);
uniform float normal_scale = 1.0;
uniform float ao_light_affect = 0.5;
uniform float breakup_m = 3.0;
uniform float traffic_rough = 0.3;
uniform float traffic_bright = 0.2;
uniform float traffic_metal = 0.3;
uniform float damp_rough = 0.12;
uniform float damp_dark = 0.3;
uniform float damp_flatten = 0.6;
uniform float base_damp = 0.2;
uniform float tone = 0.3;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
}

void fragment() {
	vec3 orm = texture(orm_tex, UV).rgb;
	vec2 wear = texture(wear_map, (world_pos.xz - wear_origin) / wear_size).rg;
	vec2 grain = texture(breakup_tex, world_pos.xz / breakup_m).rg;
	float traffic = clamp(wear.r * (0.35 + 1.1 * grain.g), 0.0, 1.0);
	float damp = clamp(max(wear.g, base_damp) * (0.2 + 1.5 * grain.g * (0.5 + grain.r)), 0.0, 1.0);
	float steel_tone = 1.0 - tone + tone * 2.0 * grain.r;
	ALBEDO = texture(albedo_tex, UV).rgb * COLOR.rgb * steel_tone * (1.0 + traffic * traffic_bright) * (1.0 - damp * damp_dark);
	ROUGHNESS = mix(mix(orm.g, traffic_rough, traffic), damp_rough, damp);
	METALLIC = mix(orm.b, traffic_metal, traffic);
	AO = orm.r;
	AO_LIGHT_AFFECT = ao_light_affect;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale * (1.0 - damp * damp_flatten);
}
