// A soft dark vignette for the dread grade, drawn as a full-screen ColorRect.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(0.05, 0.06, 0.08);

void fragment() {
	vec2 q = UV - vec2(0.5);
	float r = length(q * vec2(1.0, 0.85));
	float v = smoothstep(0.32, 0.78, r) * strength;
	COLOR = vec4(tint, v);
}
