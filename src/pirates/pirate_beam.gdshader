// A pirate's visible beam: a thin additive sheet that only shows where the player has sight, so it
// can come round a corner ahead of the pirate, but never shines out of a room you can't see.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(1.0);
uniform float strength = 0.1;
uniform float fade_power = 1.5;
uniform sampler2D visible_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size = vec2(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float seen = texture(visible_mask, (world_pos.xz - mask_origin) / mask_size).r;
	ALBEDO = beam_color.rgb;
	ALPHA = clamp(strength * pow(max(1.0 - UV.x, 0.0), fade_power) * seen, 0.0, 1.0);
}
