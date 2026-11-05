// The one light model for everything on screen: ponies, props, buildings.
// Two tones (a hard step on N.L with a narrow soft band), a cool tinted shadow instead of
// grey, and an optional stepped rim. Shadow casts and self-shadow land on the same band, so
// a pony standing in a barn's shadow reads exactly like the shadow side of her own body.
//
// `dread` is a global (project.godot [shader_globals]) set by WorldTone: it pulls albedo
// toward its own luminance so the valley grays out together, except materials flagged
// `spectral`, which stay saturated, because in the dread grade the only color left is the
// Works' output.
shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;
#include "res://shaders/bounce.gdshaderinc"

global uniform float dread;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_texture = false;
uniform vec3 shadow_tint : source_color = vec3(0.72, 0.74, 0.92);
// How much of the sun still reaches the shadow side, before the tint. Ambient sky light
// adds on top, so this stays low.
uniform float shadow_fill : hint_range(0.0, 1.0) = 0.32;
uniform float band_center : hint_range(-1.0, 1.0) = 0.0;
uniform float band_softness : hint_range(0.0, 0.5) = 0.035;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_width : hint_range(0.0, 1.0) = 0.22;
uniform bool spectral = false;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

void vertex() {
	VERTEX += bounce_offset(VERTEX);
}

void fragment() {
	vec4 c = albedo;
	if (use_texture) {
		c *= texture(albedo_texture, UV);
	}
	if (alpha_scissor > 0.0 && c.a < alpha_scissor) {
		discard;
	}
	vec3 rgb = c.rgb;
	if (!spectral) {
		float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
		// Toward a slightly cool grey, not neutral: dread reads as damp, not as sepia.
		vec3 grey = vec3(lum) * vec3(0.96, 0.99, 1.02);
		rgb = mix(rgb, grey, clamp(dread, 0.0, 1.0) * 0.62);
	}
	ALBEDO = rgb;
	EMISSION = emission * emission_energy;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(band_center - band_softness, band_center + band_softness, ndl);
	float falloff = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		// ATTENUATION is the sun's shadow term. It is NOT banded hard like N.L: the ranch sun's
		// soft shadows (PCSS, light_angular_distance 0.9, shadow_blur 1.1) sample the map with a
		// per-pixel rotated pattern, so across a penumbra or a self-shadowed flank the term
		// hovers round 0.5 with pixel noise in it. A 0.45..0.55 step turned that noise into
		// full-contrast salt and pepper: ponies (and trees, and walls) came out grainy and
		// dithered (playtest 2026-10-24, docs/playtest_fixes/ponies.md). A wide ramp keeps
		// the shadow edge but passes the noise at a fifth of the contrast.
		lit = min(lit, smoothstep(0.2, 0.8, ATTENUATION));
	} else {
		// Omni and spot lights keep a soft distance falloff but still band the surface.
		falloff = ATTENUATION;
	}
	vec3 shade = mix(shadow_tint * shadow_fill, vec3(1.0), lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * shade * falloff;
	if (rim_strength > 0.0) {
		float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		rim = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.04, rim) * lit;
		SPECULAR_LIGHT += LIGHT_COLOR * rim * rim_strength * falloff;
	}
}
