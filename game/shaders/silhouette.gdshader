// A pony seen through frosted glass: a flat dark shape with a faint cool rim, never a lit
// body. The window set piece (game/world/factory_window.gd) shows only shapes, and colour
// only as light (STORY.md R.4: silhouettes, colour, and sound).
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 fill : source_color = vec3(0.08, 0.08, 0.11);
uniform vec3 rim_color : source_color = vec3(0.55, 0.6, 0.72);
uniform float rim = 0.35;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(fill, rim_color, r * rim);
	ALPHA = fade;
	if (fade < 0.999) {
		// Dither the fade so it needs no sorting.
		float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
		if (n > fade) {
			discard;
		}
	}
}
