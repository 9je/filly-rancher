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
render_mode cull_back, depth_draw_opaque, specular_disabled, alpha_to_coverage;
#include "res://shaders/bounce.gdshaderinc"
#include "res://shaders/dither.gdshaderinc"
#include "res://shaders/hair.gdshaderinc"

global uniform float dread;
// 0 by day, 1 after dark: set by NightLights. Lights the windows painted into a house's
// texture (window_mask, from tools/window_masks.py) so a night street has warm panes.
global uniform float night_glow;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_texture = false;
uniform vec3 shadow_tint : source_color = vec3(0.72, 0.74, 0.92);
// How much of the sun still reaches the shadow side, before the tint. Ambient sky light
// adds on top, so this stays low.
uniform float shadow_fill : hint_range(0.0, 1.0) = 0.32;
uniform float band_center : hint_range(-1.0, 1.0) = 0.0;
uniform float band_softness : hint_range(0.0, 0.5) = 0.035;
// How much of the sun's cast shadow lands on this surface (ponies 0: see ToonStyler's preset).
uniform float cast_shadow : hint_range(0.0, 1.0) = 1.0;
// A mane or tail (ToonStyler.is_hair): one crisp lighter streak, the show's hair shine.
uniform float hair_shine : hint_range(0.0, 1.0) = 0.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_width : hint_range(0.0, 1.0) = 0.22;
uniform bool spectral = false;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.0;
// BAKED AO (P8; tools/blender_props/bake_ao.py): the props and buildings carry a Cycles ambient
// occlusion map on their second UV set, beside the model as <name>_ao.png; ToonStyler hands it
// in and it is multiplied here by this much. Off (use_ao) for ponies and anything unbaked.
uniform bool use_ao = false;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.85;
uniform bool use_windows = false;
uniform sampler2D window_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

// A Mane Six body whose cutie mark the export stretched over its whole texture: the texture is
// drawn only where she faces sideways (her flanks), and her plain coat everywhere else, so the
// back of her rump does not wear a sliver of the mark (ToonStyler.is_mark_texture).
uniform bool mark_sides_only = false;
// A HUE REMAP (P9 item 71: Spike's texture is a mauve pink, the show draws him purple). Texels
// within hue_remap.y (0..1 hue units) of hue hue_remap.x with some colour in them are turned to
// hue_remap.z, their saturation and value scaled by hue_remap_sv. Off while hue_remap.x < 0.
uniform vec4 hue_remap = vec4(-1.0, 0.0, 0.0, 0.0);
uniform vec2 hue_remap_sv = vec2(1.0, 1.0);
uniform vec4 mark_coat : source_color = vec4(1.0);
varying vec3 model_normal;

// A COAT MARKING (PS7, playtest 2026-11-05 item 6): 0 none, 1 socks, 2 a blaze, 3 a star,
// 4 dapples (PonyLook.Marking), in marking_color. Masked on her REST pose, which PonyPaint
// bakes into CUSTOM0 on the coat meshes of a pony who has one, in model metres facing -Z.
uniform int marking = 0;
uniform vec4 marking_color : source_color = vec4(0.98, 0.97, 0.94, 1.0);
varying vec3 rest_pos;
varying vec3 hair_mid_view;

float marking_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Cellular: the distance to the nearest of one jittered point per cell.
float marking_cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float best = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(marking_hash(i + g), marking_hash(i + g + 17.0), marking_hash(i + g + 41.0));
				best = min(best, length(g + o - f));
			}
		}
	}
	return best;
}

float marking_star(vec2 q, float r) {
	// A five point star of outer radius r, as a 0..1 coverage with a soft edge.
	float a = atan(q.x, q.y);
	float seg = 6.2831853 / 5.0;
	float k = cos(seg * 0.5) / cos(mod(a, seg) - seg * 0.5);
	float edge = mix(r * 0.45, r, pow(clamp(k, 0.0, 1.0), 6.0));
	return 1.0 - smoothstep(edge - 0.006, edge + 0.006, length(q));
}

float marking_mask(vec3 p) {
	if (marking == 1) {
		return 1.0 - smoothstep(0.27, 0.31, p.y);
	}
	if (marking == 2) {
		// Narrow between the eyes, wider down the nose, ending at its tip.
		float face = smoothstep(-0.70, -0.78, p.z);
		float half_w = mix(0.022, 0.05, smoothstep(1.62, 1.25, p.y));
		float stripe = 1.0 - smoothstep(half_w - 0.008, half_w + 0.004, abs(p.x));
		float band = smoothstep(1.17, 1.21, p.y) * (1.0 - smoothstep(1.66, 1.72, p.y));
		return face * stripe * band;
	}
	if (marking == 3) {
		float face = smoothstep(-0.66, -0.74, p.z);
		return face * marking_star(vec2(p.x, p.y - 1.63), 0.075);
	}
	if (marking == 4) {
		float rear = smoothstep(-0.12, 0.05, p.z) * smoothstep(0.62, 0.72, p.y) * step(p.y, 1.3);
		// Freckles, not blobs (P9 item 54): small dots, about 1.5 cm across with gaps between,
		// where they were 3-4 cm white patches that ran together.
		float spot = 1.0 - smoothstep(0.17, 0.22, marking_cells(p * 15.0));
		return rear * spot;
	}
	return 0.0;
}

void vertex() {
	model_normal = NORMAL;
	rest_pos = CUSTOM0.xyz;
	VERTEX += bounce_offset(VERTEX);
	hair_mid_view = (MODELVIEW_MATRIX * vec4(hair_center.xyz, 1.0)).xyz;
}

void fragment() {
	// Never in the shadow map (P9 item 57): a faded pony still casts her whole shadow, and the
	// near-lens test read the LIGHT's depth there, so a faded body cast a checkerboard.
	if (!IN_SHADOW_PASS) {
		dither_clip_near(FRAGCOORD.xy, -VERTEX.z);
	}
	vec4 c = albedo;
	if (use_texture) {
		vec4 tc = texture(albedo_texture, UV);
		if (mark_sides_only) {
			float side = smoothstep(0.35, 0.6, abs(normalize(model_normal).x));
			tc = mix(mark_coat, tc, side);
		}
		if (hue_remap.x >= 0.0) {
			vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			vec4 P = mix(vec4(tc.bg, K.wz), vec4(tc.gb, K.xy), step(tc.b, tc.g));
			vec4 Q = mix(vec4(P.xyw, tc.r), vec4(tc.r, P.yzx), step(P.x, tc.r));
			float dd = Q.x - min(Q.w, Q.y);
			vec3 hsv = vec3(abs(Q.z + (Q.w - Q.y) / (6.0 * dd + 1e-10)), dd / (Q.x + 1e-10), Q.x);
			float dh = abs(fract(hsv.x - hue_remap.x + 0.5) - 0.5);
			float k = (1.0 - smoothstep(hue_remap.y * 0.8, hue_remap.y, dh)) * smoothstep(0.06, 0.14, hsv.y);
			vec3 to = vec3(hue_remap.z, clamp(hsv.y * hue_remap_sv.x, 0.0, 1.0), hsv.z * hue_remap_sv.y);
			vec3 rgb2 = to.z * mix(vec3(1.0), clamp(abs(fract(to.x + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0), to.y);
			tc.rgb = mix(tc.rgb, rgb2, k);
		}
		c *= tc;
	}
	// Cut hair cards and leaves through the engine's scissor with alpha to coverage, so under
	// MSAA their edges are smoothed rather than stair-stepped (Fable round 4: "slab manes
	// with serrated edges"). Surfaces with no cut pass at alpha 1.
	ALPHA = alpha_scissor > 0.0 ? c.a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = max(alpha_scissor, 0.001);
	ALPHA_ANTIALIASING_EDGE = alpha_scissor > 0.0 ? alpha_scissor * 0.85 : 0.0;
	if (marking > 0) {
		c.rgb = mix(c.rgb, marking_color.rgb, marking_mask(rest_pos));
	}
	vec3 rgb = c.rgb;
	if (use_ao) {
		// Squared: open wall stays white, the crease under an eave reads as one.
		float ao = texture(ao_texture, UV2).r;
		rgb *= mix(1.0, ao * ao, ao_strength);
	}
	if (!spectral) {
		float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
		// Toward a slightly cool grey, not neutral: dread reads as damp, not as sepia.
		vec3 grey = vec3(lum) * vec3(0.96, 0.99, 1.02);
		rgb = mix(rgb, grey, clamp(dread, 0.0, 1.0) * 0.62);
	}
	float lit_window = 0.0;
	if (use_windows && night_glow > 0.0) {
		lit_window = texture(window_mask, UV).r * clamp(night_glow, 0.0, 1.0);
		// Lamplight behind the glass: the pane itself turns warm, and it glows.
		rgb = mix(rgb, vec3(1.0, 0.80, 0.46), lit_window * 0.9);
	}
	ALBEDO = rgb;
	if (hair_center.w > 0.0) {
		NORMAL = normalize(mix(NORMAL, normalize(VERTEX - hair_mid_view), hair_center.w));
	}
	if (hair_shine > 0.0) {
		// THE SHOW'S MANE SHINE (Fable AAA round 2, #3: "the mane is one dark mass"): one crisp
		// lighter streak across the upper curve of the hair, a flat band, not a gloss.
		float up = NORMAL.y;
		float streak = smoothstep(0.40, 0.44, up) * (1.0 - smoothstep(0.64, 0.68, up));
		ALBEDO = mix(ALBEDO, min(ALBEDO * 1.4 + vec3(0.09), vec3(1.0)), streak * 0.8 * hair_shine);
	}
	EMISSION = emission * emission_energy + vec3(1.0, 0.72, 0.38) * lit_window * 2.2;
	ROUGHNESS = 1.0;
	// No sky reflection: the engine's default 0.5 specular laid a Fresnel sheen of the sky
	// round every silhouette, the glossy plastic look (Fable AAA round 2, #3).
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// SCREEN-SPACE SOFTENED STEPS (P9 item 57, "jagged toon bands" at 1440p): a fixed band
	// is a sub-pixel step on a surface seen at a slant, which MSAA cannot touch (it resolves
	// edges, not shading). Widening each step to at least one pixel's worth of its own
	// gradient (fwidth) keeps it crisp head-on and stops it stair-stepping at a slant.
	float bw = max(band_softness, fwidth(ndl) * 0.75);
	float lit = smoothstep(band_center - bw, band_center + bw, ndl);
	float falloff = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		// ATTENUATION is the sun's (or the moon's) shadow term, stepped like N.L so a cast
		// shadow is a flat, the same flat as the shadow side of a body. It was ramped 0.2..0.8
		// while the ranch ran PCSS soft shadows, whose noisy penumbra a hard step turned to salt
		// and pepper (playtest 2026-10-24); the shadows are hard now (P8 S4), so there is no
		// noise to hide and the ramp only smeared every shadow edge.
		float aw = max(0.3, fwidth(ATTENUATION) * 0.6);
		lit = min(lit, mix(1.0, smoothstep(0.5 - aw, 0.5 + aw, ATTENUATION), cast_shadow));
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
