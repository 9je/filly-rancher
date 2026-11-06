// Stylised water for a region's lake (Terrain.build_water): the show's flat, bright blue,
// lighter in the shallows toward the shore, a soft white foam line where it meets the bank,
// and slow bands of sparkle drifting across it. Unshaded colour plus a little sky light, like
// the rest of the toon world: no reflections, no refraction.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_disabled;

global uniform float dread;

uniform vec3 centre = vec3(0.0);
uniform float radius = 16.0;
uniform vec4 deep : source_color = vec4(0.16, 0.42, 0.72, 1.0);
uniform vec4 shallow : source_color = vec4(0.42, 0.74, 0.88, 1.0);
uniform vec4 foam : source_color = vec4(0.94, 0.98, 1.0, 1.0);
// 1.0 for a lake: nothing under it shows through (playtest 2026-11-05: grass under the water).
uniform float opacity = 0.92;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 d = world_pos.xz - centre.xz;
	float r = length(d) / max(radius, 0.01);
	vec3 c = mix(deep.rgb, shallow.rgb, smoothstep(0.35, 0.95, r));
	// Foam: a ragged band at the rim.
	float wob = sin(atan(d.y, d.x) * 9.0 + TIME * 0.6) * 0.015;
	float edge = smoothstep(0.9 + wob, 0.985 + wob, r);
	c = mix(c, foam.rgb, edge * 0.85);
	// Sparkle bands, drifting.
	float band = sin(world_pos.x * 0.9 + world_pos.z * 0.35 + TIME * 0.8) * sin(world_pos.z * 1.3 - TIME * 0.5);
	c += vec3(0.12) * smoothstep(0.82, 0.98, band) * (1.0 - edge);
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lum) * vec3(0.92, 0.95, 1.0), clamp(dread, 0.0, 1.0) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	ALPHA = opacity;
}
