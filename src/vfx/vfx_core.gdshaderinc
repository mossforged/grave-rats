// One particle, worked out here from its instance numbers and the clock (src/vfx/particle_field.gd has the
// layout and the same sum for the tests). The CPU only writes a slot when a particle is born.
#include "res://src/sight/sight_lookup.gdshaderinc"

uniform sampler2D sheet : source_color, filter_linear, repeat_disable;
uniform float now = 0.0;
uniform vec2 grid = vec2(1.0);
uniform float aspect = 1.0;
uniform float floor_y = 0.02;
uniform bool align_velocity = false;
uniform float spin = 0.0;
uniform float fade_power = 1.0;
uniform float fade_in = 0.0;
uniform bool masked = false;
uniform bool cone_only = false;
uniform vec3 beam_origin;
uniform vec2 beam_dir = vec2(0.0, -1.0);
uniform float beam_cos = 0.9;
uniform float beam_range = 10.0;
uniform float beam_on = 0.0;

varying vec2 v_uv;
varying vec4 v_color;
varying float v_view_z;

void vertex() {
	// The instance rows, read as numbers: MODEL_MATRIX's columns hold them (the node's own transform is identity).
	vec3 p0 = vec3(MODEL_MATRIX[0][0], MODEL_MATRIX[1][0], MODEL_MATRIX[2][0]);
	float born = MODEL_MATRIX[3][0];
	vec3 v0 = vec3(MODEL_MATRIX[0][1], MODEL_MATRIX[1][1], MODEL_MATRIX[2][1]);
	float life = MODEL_MATRIX[3][1];
	float size_a = MODEL_MATRIX[0][2];
	float size_b = MODEL_MATRIX[1][2];
	float g = MODEL_MATRIX[2][2];
	float drag = MODEL_MATRIX[3][2];
	float t = now - born;
	float u = life > 0.0 ? t / life : 2.0;
	v_uv = UV;
	v_color = COLOR;
	v_view_z = 0.0;
	if (u < 0.0 || u >= 1.0) {
		// Dead or unborn: behind the camera.
		VERTEX = vec3(0.0, 0.0, 1.0);
		NORMAL = vec3(0.0, 0.0, 1.0);
	} else {
		float along = drag > 0.0 ? (1.0 - exp(-drag * t)) / drag : t;
		vec3 p = p0 + v0 * along;
		p.y -= 0.5 * g * t * t;
		vec3 vel = v0 * exp(-drag * t);
		vel.y -= g * t;
		float bounce = INSTANCE_CUSTOM.w;
		if (bounce >= 0.0 && g > 0.0) {
			float hit = (v0.y + sqrt(max(v0.y * v0.y + 2.0 * g * (p0.y - floor_y), 0.0))) / g;
			if (t > hit) {
				float dt = t - hit;
				float up = -(v0.y - g * hit) * bounce;
				p = vec3(p0.x + v0.x * hit + v0.x * bounce * dt, floor_y + up * dt - 0.5 * g * dt * dt,
						p0.z + v0.z * hit + v0.z * bounce * dt);
				vel = vec3(v0.x * bounce, up - g * dt, v0.z * bounce);
			}
		}
		p.y = max(p.y, floor_y);
		float size = mix(size_a, size_b, u);
		vec2 corner = (UV - 0.5) * vec2(-1.0, 1.0) * vec2(aspect, 1.0) * size;
		vec3 cam_right = INV_VIEW_MATRIX[0].xyz;
		vec3 cam_up = INV_VIEW_MATRIX[1].xyz;
		vec3 right = cam_right;
		vec3 up_dir = cam_up;
		if (align_velocity) {
			vec3 fwd = INV_VIEW_MATRIX[2].xyz;
			vec3 along_v = vel - fwd * dot(vel, fwd);
			float len = length(along_v);
			if (len > 0.0001) {
				right = along_v / len;
				up_dir = cross(fwd, right);
			}
		} else {
			float roll = fract(sin(born * 12.9898 + p0.x * 78.233) * 43758.5453) * 6.2831853 + spin * t;
			float c = cos(roll);
			float s = sin(roll);
			right = cam_right * c + cam_up * s;
			up_dir = cam_up * c - cam_right * s;
		}
		vec3 world = p + right * corner.x - up_dir * corner.y;
		vec4 view = VIEW_MATRIX * vec4(world, 1.0);
		VERTEX = view.xyz;
		NORMAL = vec3(0.0, 0.0, 1.0);
		TANGENT = vec3(1.0, 0.0, 0.0);
		BINORMAL = vec3(0.0, 1.0, 0.0);
		v_view_z = -view.z;

		float frame = INSTANCE_CUSTOM.x;
		float frames = INSTANCE_CUSTOM.y;
		float fps = INSTANCE_CUSTOM.z;
		if (fps > 0.0) {
			frame += min(floor(t * fps), frames - 1.0);
		} else if (fps < 0.0) {
			frame += mod(floor(t * -fps), frames);
		}
		v_uv = (UV + vec2(mod(frame, grid.x), floor(frame / grid.x))) / grid;

		float alpha = COLOR.a * pow(max(1.0 - u, 0.0), fade_power);
		if (fade_in > 0.0) {
			alpha *= clamp(u / fade_in, 0.0, 1.0);
		}
		// One look-up, at the particle's centre: it's seen or it isn't, so none shows through the dark.
		if (masked) {
			alpha *= sight_knowledge(p.xz).x;
		}
		if (cone_only) {
			vec2 to = p.xz - beam_origin.xz;
			float d = length(to);
			alpha *= beam_on * step(beam_cos, dot(to / max(d, 0.0001), beam_dir)) * (1.0 - clamp(d / beam_range, 0.0, 1.0));
		}
		v_color = vec4(COLOR.rgb, alpha);
	}
}
