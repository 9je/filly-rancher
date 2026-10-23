// Inverted-hull outline, used as the next_pass of a toon material. The hull is pushed out
// along the view-space normal by a constant number of PIXELS (not meters), so a pony's line
// stays the same weight at 2 m and at 20 m, as a drawn line would. The color is the
// surface's own albedo darkened, not black: the show outlines a lilac pony in deep purple.
//
// Lines fade out past `fade_end` meters; distant ponies are small and a full-weight line on
// a 30-pixel pony is a smudge.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

global uniform float dread;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform float darken : hint_range(0.0, 1.0) = 0.45;
uniform float width_px : hint_range(0.0, 8.0) = 1.6;
uniform float fade_start = 18.0;
uniform float fade_end = 42.0;
// An explicit color wins over the albedo-derived one when its alpha is above zero.
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
// Per INSTANCE, not per material: a far pony turns her line off without her materials being
// swapped (a swap rebuilds her render instance, which is what made tier changes hitch).
instance uniform float outline_on = 1.0;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * view_pos;
	vec2 dir = (PROJECTION_MATRIX * vec4(view_n, 0.0)).xy;
	float len = length(dir);
	if (len > 0.0001) {
		dir /= len;
	}
	float dist = -view_pos.z;
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	clip.xy += dir * width_px * fade * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
	// A line casts no shadow: in a shadow pass EVERY vertex of the hull collapses to one
	// point, so each triangle is degenerate and the rasterizer drops it. Only a test that is
	// the same for the whole draw may do this; a per-vertex one (the fade) would collapse
	// some corners of a triangle and not others and smear it across the screen.
	if (IN_SHADOW_PASS || outline_on < 0.5) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);
	}
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_texture) {
		base *= texture(albedo_texture, UV).rgb;
	}
	vec3 c = base * darken;
	if (line_color.a > 0.0) {
		c = line_color.rgb;
	}
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lum), clamp(dread, 0.0, 1.0) * 0.5);
	ALBEDO = c;
}
