// The Haybrook Rainbow: seven soft bands across the arc's width (UV.y), brightest at the
// heart, fading at both ends of the arc (UV.x) and at its edges. Spectral: the dread grade
// greys everything else and leaves this, because it is what the valley is being turned into.
// `bands` lets the Rescue path take one band out per cut pylon (STORY.md section 5).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float brightness : hint_range(0.0, 3.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.72;
uniform int bands : hint_range(0, 7) = 7;
uniform float flow_speed = 0.06;
// The Rainboom's ring (sky_events.gd): a flat ring, so no fade at the arc's ends, and the
// bands cut crisp the way the show draws the boom, not painted soft.
uniform bool ring = false;
// 0 by day, 1 at full dark (night_lights.gd). At night the arc keeps its glow but thins, so it
// hangs in the dark sky instead of sitting on it like a sticker (Fable round 2 renders).
global uniform float night_glow;

const vec3 COLORS[7] = vec3[](vec3(0.95, 0.27, 0.32), vec3(1.0, 0.58, 0.22), vec3(1.0, 0.9, 0.3),
	vec3(0.36, 0.84, 0.4), vec3(0.3, 0.62, 0.98), vec3(0.42, 0.36, 0.9), vec3(0.7, 0.4, 0.92));

void fragment() {
	float v = clamp(UV.y, 0.0, 0.9999);
	int idx = int(floor(v * 7.0));
	float inband = fract(v * 7.0);
	vec3 c = COLORS[idx];
	// Soft seams between bands, like a painted rainbow.
	vec3 next = COLORS[min(idx + 1, 6)];
	c = mix(c, next, smoothstep(0.82, 1.0, inband) * (ring ? 0.0 : 0.5));
	float shown = idx < bands ? 1.0 : 0.0;
	float soft = ring ? 0.012 : 0.06;
	float edge = smoothstep(0.0, soft, v) * (1.0 - smoothstep(1.0 - soft, 1.0, v));
	float ends = ring ? 1.0 : smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.86, 1.0, UV.x));
	// A slow shimmer flowing out of the Works, as if it were being poured.
	float flow = 0.9 + 0.1 * sin((UV.x * 40.0 - TIME * flow_speed * 40.0));
	ALBEDO = c * brightness * flow;
	ALPHA = alpha * edge * ends * shown * (1.0 - 0.92 * night_glow);
}
