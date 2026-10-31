// A kit surface while the cut-away is fading it. A faded surface is transparent, so it draws after the
// sight mask and the mask can't touch it; this applies the same three states to its own light instead.
// src/sight/fade_mask.gd swaps it in for as long as the fade lasts. Mirrors the BaseMaterial3D stack
// src/kit uses; `transparency` on the instance still sets how see-through it is.
shader_type spatial;
render_mode depth_draw_never;

#include "res://src/sight/sight_lookup.gdshaderinc"

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform float normal_scale = 1.0;
uniform float ao_light_affect = 0.5;
uniform vec3 emission_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float scissor = 0.0;
uniform float remembered_brightness = 0.3;
uniform float remembered_saturation = 0.25;
uniform vec3 remembered_tint = vec3(1.0);
uniform float unknown_brightness = 0.03;
uniform float unknown_saturation = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
}

void fragment() {
	vec4 base = texture(albedo_tex, UV) * tint;
	if (scissor > 0.0 && base.a < scissor) {
		discard;
	}
	vec2 k = sight_knowledge(world_pos.xz);
	float keep = mix(mix(unknown_brightness, remembered_brightness, k.y), 1.0, k.x);
	float saturation = mix(mix(unknown_saturation, remembered_saturation, k.y), 1.0, k.x);
	vec3 shade = mix(vec3(1.0), remembered_tint, k.y * (1.0 - k.x));
	vec3 lit = base.rgb * COLOR.rgb;
	lit = mix(vec3(dot(lit, vec3(0.2126, 0.7152, 0.0722))), lit, saturation) * shade;
	vec3 orm = has_orm ? texture(orm_tex, UV).rgb : vec3(1.0);
	ALBEDO = lit * keep;
	ROUGHNESS = orm.g * roughness;
	METALLIC = orm.b * metallic;
	SPECULAR = specular * keep;
	AO = orm.r;
	AO_LIGHT_AFFECT = ao_light_affect;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	EMISSION = emission_color * emission_energy * keep;
}
