// A flashlight's visible beam: a thin additive sheet that only shows where the player has sight,
// so it can come round a corner ahead of a pirate but never shines out of a room you can't see.
// UV is beam space (forward, across) in ranges, so the fade and the soft sides are the same
// wherever the fan's vertices happen to be.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(1.0);
uniform float strength = 0.1;
uniform float fade_power = 1.5;
uniform float edge_power = 1.5;
uniform float tan_half = 0.5;
uniform sampler2D visible_mask : hint_default_white, filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size = vec2(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = pow(max(1.0 - length(UV), 0.0), fade_power);
	float side = abs(UV.y) / max(UV.x * tan_half, 0.0001);
	float across = pow(max(1.0 - side, 0.0), edge_power);
	float seen = texture(visible_mask, (world_pos.xz - mask_origin) / mask_size).r;
	ALBEDO = beam_color.rgb;
	ALPHA = clamp(strength * along * across * seen, 0.0, 1.0);
}
