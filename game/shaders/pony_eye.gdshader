// The eye: keeps the texture's white sclera, black pupil and outline, and white highlights,
// and REPLACES the iris (everything that is neither near-white nor near-black) with a
// two-tone ramp of `iris`, picked by the texture's own brightness. Multiplying the baked
// iris instead (the old StockTint way) turns a gold iris tinted blue into mud.
//
// Eyes are lit softly rather than banded: a banded eye goes half-dark when a pony turns
// her head, and the show never does that to an eye.
shader_type spatial;
render_mode cull_back, specular_disabled;
// The bounce include first, so dither_fade sits at the same instance slot as on the toon and
// outline materials sharing her mesh (instance uniforms are matched by index).
#include "res://shaders/bounce.gdshaderinc"
#include "res://shaders/dither.gdshaderinc"
#include "res://shaders/hair.gdshaderinc"

global uniform float dread;

uniform sampler2D eye_texture : source_color, filter_linear_mipmap;
uniform vec3 iris : source_color = vec3(0.35, 0.55, 0.9);
uniform float dark_scale : hint_range(0.0, 1.0) = 0.5;
uniform float highlight_boost : hint_range(0.0, 2.0) = 0.25;
// The blink, drawn the show's way: the lid sweeps down from the top of the eye (UV v = 0)
// in the coat's color and ends in a dark lash line. 0 open, 1 shut.
uniform float lid : hint_range(0.0, 1.0) = 0.0;
uniform vec3 lid_color : source_color = vec3(0.95, 0.9, 0.85);
uniform float lid_top = 0.08;
uniform float lid_bottom = 0.92;
// HER EYE SHAPE (PS7 item 6): the lid never rises above rest_lid (a sleepy eye), and
// lower_lid closes the eye from below by that much (an almond eye).
uniform float rest_lid : hint_range(0.0, 1.0) = 0.0;
uniform float lower_lid : hint_range(0.0, 1.0) = 0.0;
// THE IRIS, SHRUNK THE WAY SOURCE DRAWS IT. A PonySFM eyeball's UVs cover only the middle of
// its iris texture (Source's "eyes" shader projected the iris small onto a white eyeball; the
// conversion pasted it across the whole ball), so the pupil filled the eye. Above 1 the iris
// is drawn that many times smaller about iris_centre, with white sclera outside it.
uniform float iris_scale = 1.0;
uniform vec2 iris_centre = vec2(0.554, 0.511);
// Off for a canon pony: her own iris colours stay, rather than the Drifters' recolour ramp.
uniform bool recolor = true;
// THE IRIS PROJECTED, NOT UV-MAPPED, the way Source's "eyes" shader draws it ($iris is cast
// onto the eyeball along the eye's own axis; the mesh UVs are a generic sphere unwrap that was
// never meant for it). Spike's eyeballs (world/spike_actor.gd) need this: through their UVs his
// iris landed as a green sliver at the edge of a blank white eye. Model space: the iris centre,
// the eye's right and up axes, and the width and height the whole texture spans.
uniform bool planar = false;
uniform vec3 eye_origin = vec3(0.0);
uniform vec3 eye_right = vec3(1.0, 0.0, 0.0);
uniform vec3 eye_up = vec3(0.0, 1.0, 0.0);
uniform vec2 eye_size = vec2(0.1);
varying vec2 planar_uv;
// Where this eye looks, as a shift of the iris across the eyeball (texture UV). Zero for
// everyone but Derpy, whose eyes each go their own way (ToonStyler.CROSS_EYED).
uniform vec2 gaze = vec2(0.0);

void vertex() {
	vec3 d = VERTEX - eye_origin;
	planar_uv = vec2(dot(d, eye_right) / eye_size.x, -dot(d, eye_up) / eye_size.y) + vec2(0.5);
}

void fragment() {
	dither_clip_near(FRAGCOORD.xy, -VERTEX.z);
	vec2 base_uv = planar ? planar_uv : UV;
	vec2 iuv = (planar ? base_uv : iris_centre + (UV - iris_centre) * iris_scale) - gaze;
	vec4 tex = texture(eye_texture, iuv);
	bool outside = iuv.x < 0.0 || iuv.y < 0.0 || iuv.x > 1.0 || iuv.y > 1.0 || tex.a < 0.5;
	vec3 t = outside ? vec3(1.0) : tex.rgb;
	float mx = max(t.r, max(t.g, t.b));
	float mn = min(t.r, min(t.g, t.b));
	float white = smoothstep(0.86, 0.95, mn);
	float black = 1.0 - smoothstep(0.05, 0.14, mx);
	float iris_mask = clamp(1.0 - white - black, 0.0, 1.0);
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	vec3 ramp = mix(iris * dark_scale, mix(iris, vec3(1.0), 0.25), smoothstep(0.25, 0.85, lum));
	vec3 c = recolor ? mix(t, ramp, iris_mask) : t;
	float l2 = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l2), clamp(dread, 0.0, 1.0) * 0.55);
	float shut = max(lid, rest_lid);
	float edge = mix(lid_top, lid_bottom, shut);
	float top_lidded = (1.0 - smoothstep(edge - 0.01, edge + 0.01, UV.y)) * step(0.001, shut);
	float low_edge = mix(lid_bottom, lid_top, lower_lid);
	float low_lidded = step(0.001, lower_lid) * smoothstep(low_edge - 0.01, low_edge + 0.01, UV.y);
	float lidded = max(top_lidded, low_lidded);
	// The lash line along each lid's own edge, dark; the rest of the lid is her coat.
	float lash = smoothstep(edge - 0.045, edge - 0.01, UV.y) * top_lidded * step(0.02, shut);
	lash = max(lash, (1.0 - smoothstep(low_edge + 0.01, low_edge + 0.035, UV.y)) * low_lidded * 0.7);
	vec3 lc = mix(lid_color, lid_color * 0.18, lash);
	c = mix(c, lc, lidded);
	ALBEDO = c;
	EMISSION = c * white * highlight_boost * (1.0 - lidded);
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * mix(0.55, 1.0, ndl) * ATTENUATION;
}
