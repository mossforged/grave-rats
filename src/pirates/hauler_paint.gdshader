shader_type spatial;
render_mode cull_disabled;
// The rival crew's paint on the hauler's one baked texture: the orange plates by hue, the fabric by
// low saturation, each keeping the grime the texture has. Numbers from data/pirates.json "body.hauler_paint".

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float normal_scale = 1.0;
uniform vec3 plate_color : source_color = vec3(0.01, 0.025, 0.11);
uniform vec3 fabric_color : source_color = vec3(0.85, 0.88, 0.91);
uniform float plate_hue_center = 0.06;
uniform float plate_hue_width = 0.07;
uniform float plate_saturation_min = 0.3;
uniform float fabric_saturation_max = 0.45;
uniform float fabric_value_min = 0.22;
uniform float plate_value_min = 0.4;
uniform float plate_gain = 1.0;
uniform float fabric_gain = 0.8;

vec3 hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-5)), d / (q.x + 1e-5), q.x);
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	vec3 c = hsv(pow(base, vec3(1.0 / 2.2)));
	float hue_off = abs(fract(c.x - plate_hue_center + 0.5) - 0.5);
	float plate = (1.0 - smoothstep(plate_hue_width * 0.6, plate_hue_width, hue_off))
		* smoothstep(plate_saturation_min * 0.7, plate_saturation_min, c.y)
		* smoothstep(plate_value_min * 0.7, plate_value_min, c.z);
	float fabric = (1.0 - smoothstep(fabric_saturation_max * 0.8, fabric_saturation_max, c.y))
		* smoothstep(fabric_value_min * 0.7, fabric_value_min, c.z) * (1.0 - plate);
	vec3 shade = vec3(c.z * c.z);
	vec3 out_color = mix(base, plate_color * (0.35 + shade) * plate_gain, plate);
	out_color = mix(out_color, fabric_color * (0.25 + shade) * fabric_gain, fabric);
	ALBEDO = out_color;
	vec4 orm = texture(orm_tex, UV);
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
