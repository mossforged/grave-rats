// Additive sheets: black adds nothing. Sparks, flames, arcs, glows.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;

#include "res://src/vfx/vfx_core.gdshaderinc"

uniform sampler2D screen_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float soft_m = 0.0;

void fragment() {
	vec4 t = texture(sheet, v_uv);
	float soft = 1.0;
	if (soft_m > 0.0) {
		vec4 at = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(screen_depth, SCREEN_UV).r, 1.0);
		soft = clamp((-at.z / at.w - v_view_z) / soft_m, 0.0, 1.0);
	}
	ALBEDO = t.rgb * v_color.rgb;
	ALPHA = t.a * v_color.a * soft;
}
