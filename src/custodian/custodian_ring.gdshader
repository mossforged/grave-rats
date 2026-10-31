// A segmented ring lying flat, filling clockwise as `fill` goes from 0 to 1: the cutter's warm-up. Draws
// over everything: the tell shows wherever it matters. UV over a quad, so the mesh is one quad.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 ring_color : source_color = vec3(1.0);
uniform float energy = 1.0;
uniform float fill = 0.0;
uniform float segments = 8.0;
uniform float gap = 0.14;
uniform float inner = 0.72;
uniform float track_alpha = 0.2;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float band = smoothstep(inner - 0.02, inner, r) * smoothstep(1.0, 0.98, r);
	float turn = fract(atan(p.x, -p.y) / TAU + 1.0);
	float cell = turn * segments;
	float within = fract(cell);
	float solid = step(gap * 0.5, within) * step(within, 1.0 - gap * 0.5);
	float lit = step(floor(cell) + 1.0, fill * segments + 0.001);
	ALBEDO = ring_color * energy;
	ALPHA = band * solid * mix(track_alpha, 1.0, lit);
}
