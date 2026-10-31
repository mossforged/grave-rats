// A light the player needs to read outside the cone (door state, the ambush panel's tell): it draws after
// the sight mask at full strength wherever they've ever seen, and at `unknown_share` where they haven't.
// Walls and props still hide it. With `masked` off (no mask in this scene) it just shows.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://src/sight/sight_lookup.gdshaderinc"

uniform vec3 beacon_color : source_color = vec3(1.0);
uniform float energy = 1.0;
uniform bool masked = false;
uniform float unknown_share = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 k = masked ? sight_knowledge(world_pos.xz) : vec2(1.0);
	ALBEDO = beacon_color * energy;
	ALPHA = mix(unknown_share, 1.0, max(k.x, k.y));
}
