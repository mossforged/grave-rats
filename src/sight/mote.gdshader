// Dust motes: little additive billboards that only show inside the beam's wedge.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 mote_color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform vec3 beam_origin;
uniform vec2 beam_dir = vec2(0.0, -1.0);
uniform float half_angle = 0.4;
uniform float range_m = 10.0;
uniform sampler2D visible_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size = vec2(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = MODEL_MATRIX[3].xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 to = world_pos.xz - beam_origin.xz;
	float d = length(to);
	float inside = step(cos(half_angle), dot(to / max(d, 0.0001), beam_dir)) * (1.0 - clamp(d / range_m, 0.0, 1.0));
	float seen = texture(visible_mask, (world_pos.xz - mask_origin) / mask_size).r;
	ALBEDO = mote_color.rgb;
	ALPHA = clamp(strength * inside * seen, 0.0, 1.0);
}
