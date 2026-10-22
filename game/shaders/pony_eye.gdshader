// The eye: keeps the texture's white sclera, black pupil and outline, and white highlights,
// and REPLACES the iris (everything that is neither near-white nor near-black) with a
// two-tone ramp of `iris`, picked by the texture's own brightness. Multiplying the baked
// iris instead (the old StockTint way) turns a gold iris tinted blue into mud.
//
// Eyes are lit softly rather than banded: a banded eye goes half-dark when a pony turns
// her head, and the show never does that to an eye.
shader_type spatial;
render_mode cull_back, specular_disabled;

global uniform float dread;

uniform sampler2D eye_texture : source_color, filter_linear_mipmap;
uniform vec3 iris : source_color = vec3(0.35, 0.55, 0.9);
uniform float dark_scale : hint_range(0.0, 1.0) = 0.5;
uniform float highlight_boost : hint_range(0.0, 2.0) = 0.25;

void fragment() {
	vec3 t = texture(eye_texture, UV).rgb;
	float mx = max(t.r, max(t.g, t.b));
	float mn = min(t.r, min(t.g, t.b));
	float white = smoothstep(0.86, 0.95, mn);
	float black = 1.0 - smoothstep(0.05, 0.14, mx);
	float iris_mask = clamp(1.0 - white - black, 0.0, 1.0);
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	vec3 ramp = mix(iris * dark_scale, mix(iris, vec3(1.0), 0.25), smoothstep(0.25, 0.85, lum));
	vec3 c = mix(t, ramp, iris_mask);
	float l2 = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l2), clamp(dread, 0.0, 1.0) * 0.55);
	ALBEDO = c;
	EMISSION = c * white * highlight_boost;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * mix(0.55, 1.0, ndl) * ATTENUATION;
}
