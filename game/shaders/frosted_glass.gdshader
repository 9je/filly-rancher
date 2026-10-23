// The gallery window's frosted pane: milky, slightly blue, with soft drifting frost so what
// is behind it reads only as shapes and light.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.82, 0.88, 0.95);
uniform float opacity : hint_range(0.0, 1.0) = 0.55;
uniform float clear : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float frost = noise(UV * 18.0 + vec2(TIME * 0.02, 0.0)) * 0.6 + noise(UV * 45.0) * 0.4;
	ALBEDO = tint * (0.9 + 0.2 * frost);
	ALPHA = clamp(opacity + frost * 0.18 - clear * 0.5, 0.05, 0.95);
}
