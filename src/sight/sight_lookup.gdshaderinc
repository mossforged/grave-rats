// What the player knows at a world point: x = seen now, y = ever seen. The one lookup behind the sight
// mask and everything that draws after it. SightMask.bind(material) fills these in.
uniform sampler2D visible_mask : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D memory_mask : hint_default_black, filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size = vec2(1.0);
uniform float dilate_m = 0.3;
uniform float edge_low = 0.25;
uniform float edge_high = 0.75;

const float SIGHT_DIAG = 0.7071;

// The brightest of the pixel and a ring around it: sight stops at a wall's face, so this lets it
// spill just far enough to show the wall itself and never through it.
float ring_max(sampler2D mask, vec2 uv, vec2 r) {
	float m = texture(mask, uv).r;
	m = max(m, texture(mask, uv + vec2(r.x, 0.0)).r);
	m = max(m, texture(mask, uv - vec2(r.x, 0.0)).r);
	m = max(m, texture(mask, uv + vec2(0.0, r.y)).r);
	m = max(m, texture(mask, uv - vec2(0.0, r.y)).r);
	m = max(m, texture(mask, uv + r * SIGHT_DIAG).r);
	m = max(m, texture(mask, uv - r * SIGHT_DIAG).r);
	m = max(m, texture(mask, uv + vec2(r.x, -r.y) * SIGHT_DIAG).r);
	m = max(m, texture(mask, uv + vec2(-r.x, r.y) * SIGHT_DIAG).r);
	// Halfway in too, so a shape narrower than the ring doesn't leave stripes.
	m = max(m, texture(mask, uv + vec2(r.x, 0.0) * 0.5).r);
	m = max(m, texture(mask, uv - vec2(r.x, 0.0) * 0.5).r);
	m = max(m, texture(mask, uv + vec2(0.0, r.y) * 0.5).r);
	m = max(m, texture(mask, uv - vec2(0.0, r.y) * 0.5).r);
	return m;
}

vec2 sight_knowledge(vec2 world_xz) {
	vec2 uv = (world_xz - mask_origin) / mask_size;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return vec2(0.0);
	}
	vec2 r = vec2(dilate_m) / mask_size;
	return vec2(smoothstep(edge_low, edge_high, ring_max(visible_mask, uv, r)),
			smoothstep(edge_low, edge_high, ring_max(memory_mask, uv, r)));
}
