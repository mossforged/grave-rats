// Screen-space sight mask: a fullscreen quad drawn first among the transparents. Each pixel's
// world position (from depth) looks up the deck-wide masks, so real lighting stays and only
// knowledge changes. The beam, FX and floor drawings draw after this and look the mask up themselves.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

#include "res://src/sight/sight_lookup.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float remembered_brightness = 0.3;
uniform float remembered_saturation = 0.25;
uniform vec3 remembered_tint = vec3(1.0);
uniform float unknown_brightness = 0.03;
uniform float unknown_saturation = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	vec2 k = sight_knowledge(world.xz);
	vec3 color = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	vec3 unknown = mix(vec3(luma), color, unknown_saturation) * unknown_brightness;
	vec3 remembered = mix(vec3(luma), color, remembered_saturation) * remembered_tint * remembered_brightness;
	ALBEDO = mix(mix(unknown, remembered, k.y), color, k.x);
	ALPHA = 1.0;
}
