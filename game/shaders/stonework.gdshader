// Building foundations and door ramps, in the toon world's own light (the light() below is
// shaders/toon.gdshader's): `pattern` 0 is a stone foundation (blocks in running bond, each a
// shade of its own, mortar between), 1 is wooden planks across a ramp. Laid out in WORLD space,
// so a block is the same size on every face of every plinth and nothing stretches.
shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

global uniform float dread;

uniform int pattern = 0;
uniform vec4 base : source_color = vec4(0.66, 0.62, 0.56, 1.0);
uniform vec4 joint : source_color = vec4(0.42, 0.38, 0.34, 1.0);
uniform float block_w = 0.62;
uniform float block_h = 0.3;
uniform vec2 plank_dir = vec2(1.0, 0.0);
uniform vec3 shadow_tint : source_color = vec3(0.72, 0.74, 0.92);
uniform float shadow_fill : hint_range(0.0, 1.0) = 0.34;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 rgb;
	if (pattern == 0) {
		vec2 uv;
		vec3 an = abs(wnrm);
		if (an.y > 0.7) {
			uv = wpos.xz;
		} else if (an.x > an.z) {
			uv = vec2(wpos.z, wpos.y);
		} else {
			uv = vec2(wpos.x, wpos.y);
		}
		float row = floor(uv.y / block_h);
		float u = uv.x / block_w + 0.5 * mod(row, 2.0);
		float cell = floor(u);
		vec2 f = vec2(fract(u), fract(uv.y / block_h));
		float edge = min(min(f.x, 1.0 - f.x) * block_w, min(f.y, 1.0 - f.y) * block_h);
		float shade = 0.84 + 0.28 * hash(vec2(cell, row));
		rgb = mix(joint.rgb, base.rgb * shade, smoothstep(0.018, 0.03, edge));
	} else {
		vec2 d = normalize(plank_dir);
		float across = dot(wpos.xz, vec2(-d.y, d.x));
		float along = dot(wpos.xz, d);
		float board = floor(across / 0.26);
		float f = fract(across / 0.26);
		float gap = smoothstep(0.0, 0.06, min(f, 1.0 - f));
		float grain = 0.94 + 0.06 * sin(along * 9.0 + hash(vec2(board, 1.0)) * 6.0);
		float shade = 0.86 + 0.22 * hash(vec2(board, 7.0));
		rgb = mix(joint.rgb, base.rgb * shade * grain, gap);
	}
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(rgb, vec3(lum) * vec3(0.96, 0.99, 1.02), clamp(dread, 0.0, 1.0) * 0.62);
	ALBEDO = rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float bw = max(0.035, fwidth(ndl) * 0.75);
	float lit = smoothstep(-bw, bw, ndl);
	float falloff = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		// P9 item 57: at least a pixel of ramp on the shadow's edge (see toon.gdshader).
		float aw = max(0.3, fwidth(ATTENUATION) * 0.6);
		lit = min(lit, smoothstep(0.5 - aw, 0.5 + aw, ATTENUATION));
	} else {
		falloff = ATTENUATION;
	}
	vec3 shade = mix(shadow_tint * shadow_fill, vec3(1.0), lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * shade * falloff;
}
