// Smoke and dust: lit by the deck's lights, so in the dark you only see it where the flashlight, the muzzle
// or a lamp finds it. `emit_share` keeps a trace of it showing outside them.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;

#include "res://src/vfx/vfx_core.gdshaderinc"

uniform sampler2D screen_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float soft_m = 0.0;
uniform float emit_share = 0.1;

void fragment() {
	vec4 t = texture(sheet, v_uv);
	float soft = 1.0;
	if (soft_m > 0.0) {
		vec4 at = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(screen_depth, SCREEN_UV).r, 1.0);
		soft = clamp((-at.z / at.w - v_view_z) / soft_m, 0.0, 1.0);
	}
	vec3 c = t.rgb * v_color.rgb;
	ALBEDO = c;
	EMISSION = c * emit_share;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = t.a * v_color.a * soft;
}
