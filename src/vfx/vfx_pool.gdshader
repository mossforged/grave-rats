// An acid or slime pool: a puddle shape as the mask, two scales of liquid_noise scrolling against each other
// for the surface, and a glowing edge. Looks only. It obeys the sight mask.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://src/sight/sight_lookup.gdshaderinc"

uniform sampler2D puddle : filter_linear, repeat_disable;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform vec3 pool_color : source_color = vec3(0.4, 0.75, 0.2);
uniform vec3 edge_color : source_color = vec3(0.77, 1.0, 0.37);
uniform float edge_energy = 1.5;
uniform vec2 scroll_a = vec2(0.012, 0.007);
uniform vec2 scroll_b = vec2(-0.009, 0.014);
uniform float noise_scale_m = 1.2;
uniform float now = 0.0;
uniform bool masked = false;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float m = texture(puddle, UV).a;
	vec2 w = world_pos.xz / noise_scale_m;
	vec4 a = texture(noise, w + scroll_a * now);
	vec4 b = texture(noise, w * 2.0 + scroll_b * now);
	float surface = a.r * b.g;
	float edge = smoothstep(0.15, 0.55, m) * (1.0 - smoothstep(0.55, 0.9, m));
	ALBEDO = pool_color * (0.35 + surface);
	ROUGHNESS = 0.25;
	EMISSION = pool_color * surface * 0.6 + edge_color * edge * edge_energy * (0.5 + a.g);
	ALPHA = smoothstep(0.1, 0.4, m) * (masked ? sight_knowledge(world_pos.xz).x : 1.0);
}
