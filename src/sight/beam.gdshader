// The flashlight's visible beam: a thin additive sheet, already cut to the sight polygon.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(1.0);
uniform float strength = 0.1;
uniform float fade_power = 1.5;

void fragment() {
	ALBEDO = beam_color.rgb;
	ALPHA = strength * pow(max(1.0 - UV.x, 0.0), fade_power);
}
