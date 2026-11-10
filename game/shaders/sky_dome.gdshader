// THE PAINTED HORIZON (Fable AAA round 1, #1 and #2). A sphere round the camera, drawn over
// the procedural sky and under everything else: a ring of show-style mountains with
// Canterlot on the tallest (assets/sky/skyband.png), flat cartoon clouds drifting above them
// (clouds.png), and after dark stars and a moon. tools/paint_skyband.py paints both bands;
// world/sky_dome.gd lights and hazes them from the sky rig every frame.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled, blend_mix;

uniform sampler2D band : source_color, filter_linear, repeat_enable;
uniform sampler2D clouds : source_color, filter_linear, repeat_enable;
// The bands' elevation range in degrees: their top and bottom rows. Painted for -6..39 and
// lifted 7 degrees here, so the range's feet sit behind the map's own rim of hills and the
// peaks stand clear over them.
uniform float elev_hi = 46.0;
uniform float elev_lo = 1.0;
uniform vec3 horizon : source_color = vec3(0.8, 0.9, 1.0);
uniform vec3 light : source_color = vec3(1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.3;
uniform vec3 cloud_tint : source_color = vec3(1.0);
uniform float cloud_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float drift = 0.0;
uniform float stars : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_dir = vec3(0.4, 0.62, -0.67);
// THE SUN (Fable AAA round 2, #1: the engine's own sun disc came out ringed with black dots,
// "a selection gizmo left on"). Drawn here instead, the show's way: a flat warm disc with a
// soft halo and no edge of any kind. The light no longer draws itself into the sky.
uniform vec3 sun_dir = vec3(0.6, 0.5, 0.6);
uniform float sun_show : hint_range(0.0, 1.0) = 1.0;

varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	vec3 c = (top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / max(a, 1e-4);
	return vec4(c, a);
}

void fragment() {
	vec3 d = normalize(dir);
	float elev = degrees(asin(clamp(d.y, -1.0, 1.0)));
	float u = degrees(atan(d.x, -d.z)) / 360.0 + 0.5;
	float v = (elev_hi - elev) / (elev_hi - elev_lo);
	vec4 col = vec4(0.0);

	if (stars > 0.0 && d.y > 0.0) {
		vec3 p = d * 160.0;
		vec3 cell = floor(p);
		float h = hash(cell);
		if (h > 0.962) {
			vec3 at = cell + 0.5 + (vec3(hash(cell + 3.1), hash(cell + 7.7), hash(cell + 1.3)) - 0.5) * 0.5;
			float r = length(p - at);
			float tw = 0.75 + 0.25 * sin(TIME * (1.5 + h * 4.0) + h * 40.0);
			float s = smoothstep(0.42, 0.0, r) * tw * smoothstep(0.02, 0.3, d.y);
			col = vec4(vec3(1.0, 0.97, 0.9), s * stars);
		}
		float md = degrees(acos(clamp(dot(d, normalize(moon_dir)), -1.0, 1.0)));
		float disc = smoothstep(3.1, 2.9, md);
		// The show's moon: a pale cream disc with a soft blue halo round it.
		vec4 moon = vec4(vec3(1.0, 0.97, 0.86), disc);
		vec4 glow = vec4(vec3(0.75, 0.82, 1.0), exp(-max(md - 3.0, 0.0) / 5.0) * 0.35 * (1.0 - disc));
		col = over(over(moon, glow), col);
		col.a *= stars;
	}
	if (sun_show > 0.0) {
		float sd = degrees(acos(clamp(dot(d, normalize(sun_dir)), -1.0, 1.0)));
		float disc = smoothstep(4.4, 4.1, sd);
		vec4 sun = vec4(vec3(1.7, 1.55, 1.1), disc);
		vec4 halo = vec4(vec3(1.25, 1.15, 0.9), (exp(-max(sd - 4.2, 0.0) / 7.0) * 0.55
				+ exp(-max(sd - 4.2, 0.0) / 1.6) * 0.35) * (1.0 - disc));
		vec4 s = over(sun, halo);
		s.a *= sun_show;
		col = over(s, col);
	}
	if (v >= 0.0 && v <= 1.0) {
		vec4 cl = textureLod(clouds, vec2(u + drift, v), 0.0);
		cl.rgb *= cloud_tint;
		cl.a *= cloud_alpha;
		col = over(cl, col);
		vec4 mb = textureLod(band, vec2(u, v), 0.0);
		mb.rgb = mix(mb.rgb * light, horizon, haze);
		col = over(mb, col);
	}
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
