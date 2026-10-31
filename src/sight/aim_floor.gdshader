// The gun's floor drawings under sight: they show where you can see, faintly where you remember, and
// never in the dark. Colours come in per vertex (src/player/aim_visuals.gd).
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://src/sight/sight_lookup.gdshaderinc"

uniform float remembered_share = 0.25;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 k = sight_knowledge(world_pos.xz);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * mix(k.y * remembered_share, 1.0, k.x);
}
