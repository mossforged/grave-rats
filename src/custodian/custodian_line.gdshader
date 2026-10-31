// The cutter's line and beam: a ribbon, its UV.x in metres along it, so dashes stay the same size however
// long it is. With `reveal` on it shows anywhere (it's aiming at you: the fairness rule); off, it reads
// where the player has seen, so a sweep in a room you've never entered stays out of it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://src/sight/sight_lookup.gdshaderinc"

uniform vec3 line_color : source_color = vec3(1.0);
uniform float energy = 1.0;
uniform float dash_m = 0.0;
uniform float gap_m = 0.0;
uniform bool masked = false;
uniform float unknown_share = 0.0;
uniform float reveal = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float pitch = dash_m + gap_m;
	float solid = pitch > 0.0 ? step(mod(UV.x, pitch), dash_m) : 1.0;
	vec2 k = masked ? sight_knowledge(world_pos.xz) : vec2(1.0);
	ALBEDO = line_color * energy;
	ALPHA = solid * max(reveal, mix(unknown_share, 1.0, max(k.x, k.y)));
}
