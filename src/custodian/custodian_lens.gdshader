// CUSTODIAN's mark: one concentric lens inside four corner brackets, always facing the camera. Dim when
// dormant, bright awake. It reads wherever the player has seen, like a door light; walls still hide it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://src/sight/sight_lookup.gdshaderinc"

uniform vec3 lens_color : source_color = vec3(1.0);
uniform float energy = 1.0;
uniform bool masked = false;
uniform float unknown_share = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = MODEL_MATRIX[3].xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float mark = smoothstep(0.26, 0.2, r) + smoothstep(0.36, 0.4, r) * smoothstep(0.54, 0.5, r);
	vec2 c = abs(p);
	// Brackets: the outer corners of a square frame.
	float frame = step(0.8, max(c.x, c.y)) * step(max(c.x, c.y), 0.94);
	mark += frame * step(0.58, min(c.x, c.y));
	vec2 k = masked ? sight_knowledge(world_pos.xz) : vec2(1.0);
	ALBEDO = lens_color * energy;
	ALPHA = clamp(mark, 0.0, 1.0) * mix(unknown_share, 1.0, max(k.x, k.y));
}
