// Screen-space sight mask: a fullscreen quad drawn first among the transparents. Each pixel's
// world position (from depth) looks up the deck-wide masks, so real lighting stays and only
// knowledge changes. The beam, FX and floor drawings draw after this, on top.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D visible_mask : filter_linear, repeat_disable;
uniform sampler2D memory_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size = vec2(1.0);
uniform float dilate_m = 0.3;
uniform float edge_low = 0.25;
uniform float edge_high = 0.75;
uniform float remembered_brightness = 0.3;
uniform float remembered_saturation = 0.25;
uniform vec3 remembered_tint = vec3(1.0);
uniform float unknown_brightness = 0.03;
uniform float unknown_saturation = 0.0;

const float DIAG = 0.7071;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// The brightest of the pixel and a ring around it: sight stops at a wall's face, so this lets it
// spill just far enough to show the wall itself and never through it.
float ring_max(sampler2D mask, vec2 uv, vec2 r) {
	float m = texture(mask, uv).r;
	m = max(m, texture(mask, uv + vec2(r.x, 0.0)).r);
	m = max(m, texture(mask, uv - vec2(r.x, 0.0)).r);
	m = max(m, texture(mask, uv + vec2(0.0, r.y)).r);
	m = max(m, texture(mask, uv - vec2(0.0, r.y)).r);
	m = max(m, texture(mask, uv + r * DIAG).r);
	m = max(m, texture(mask, uv - r * DIAG).r);
	m = max(m, texture(mask, uv + vec2(r.x, -r.y) * DIAG).r);
	m = max(m, texture(mask, uv + vec2(-r.x, r.y) * DIAG).r);
	return m;
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	vec2 uv = (world.xz - mask_origin) / mask_size;
	vec2 r = vec2(dilate_m) / mask_size;
	float seen = 0.0;
	float known = 0.0;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		seen = smoothstep(edge_low, edge_high, ring_max(visible_mask, uv, r));
		known = smoothstep(edge_low, edge_high, ring_max(memory_mask, uv, r));
	}
	vec3 color = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	vec3 unknown = mix(vec3(luma), color, unknown_saturation) * unknown_brightness;
	vec3 remembered = mix(vec3(luma), color, remembered_saturation) * remembered_tint * remembered_brightness;
	ALBEDO = mix(mix(unknown, remembered, known), color, seen);
	ALPHA = 1.0;
}
