// The noise ring: thin segments on the floor, lines rather than a fill so the floor stays readable,
// plus one pulse running out from a shot. Drawn among the transparents after the sight mask, so it
// shows over rooms you can't see: how far you carry doesn't depend on what you've looked at.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform float size_m = 1.0;
uniform float radius_m = 0.0;
uniform float ripple_m = -1.0;
uniform float line_m = 0.1;
uniform float segments = 48.0;
uniform float gap = 0.3;
uniform vec4 cold_color : source_color = vec4(1.0);
uniform vec4 hot_color : source_color = vec4(1.0);
uniform float heat = 0.0;
uniform float alpha = 1.0;
uniform float ripple_alpha = 0.0;

float band(float d, float r, float aa) {
	return 1.0 - smoothstep(line_m * 0.5 - aa, line_m * 0.5 + aa, abs(d - r));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * size_m;
	float d = length(p);
	float aa = fwidth(d);
	float seg = fract(atan(p.y, p.x) / TAU * segments);
	float seg_aa = fwidth(seg) * 0.5;
	float dashes = smoothstep(gap * 0.5 - seg_aa, gap * 0.5 + seg_aa, seg) * (1.0 - smoothstep(1.0 - gap * 0.5 - seg_aa, 1.0 - gap * 0.5 + seg_aa, seg));
	float ring = radius_m > 0.0 ? band(d, radius_m, aa) * dashes * alpha : 0.0;
	float pulse = ripple_m >= 0.0 ? band(d, ripple_m, aa) * ripple_alpha : 0.0;
	ALBEDO = mix(cold_color.rgb, hot_color.rgb, heat);
	ALPHA = clamp(ring + pulse, 0.0, 1.0);
}
