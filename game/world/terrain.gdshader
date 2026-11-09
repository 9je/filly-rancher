shader_type spatial;
render_mode cull_back, specular_disabled;

// The valley floor shares the toon light model (game/shaders/toon.gdshader) with a softer
// band, so rolling ground reads as the show's painted backgrounds instead of cutting hard
// terminator lines across every hill. `dread` greys it with everything else.
global uniform float dread;
global uniform float night_glow;
global uniform float wet;
uniform vec3 shadow_tint : source_color = vec3(0.74, 0.78, 0.92);
uniform float shadow_fill = 0.42;
uniform float band_softness = 0.16;

// THE GROUND. The mesh, the vertex colours, grass_at(), height_at(), the regions and the
// collider are all untouched by this file: game/world/terrain.gd stays the single authority
// on what colour the ground is at a point, and this adds the high frequency break up, the
// slope treatment, the ridge lift and the painted dirt path that a smooth two colour
// gradient cannot have.
//
// WHY THE GROUND NEEDED THIS. The shipped terrain is a smooth lerp between two greens at 2 m
// resolution, which is subtly WORSE than one flat colour for the "roblox" read, because it is
// smooth and featureless at every scale the player actually sees. No texture, no break up, no
// slope treatment, no dirt anywhere.
//
// SPECULAR IS KILLED IN THE FRAGMENT AND NOT BY A RENDER MODE, deliberately: SPECULAR = 0.0
// is a fragment output that has meant the same thing in every Godot 4 release, and it says
// the same thing the StandardMaterial3D's specular_mode = SPECULAR_DISABLED said.

// Terrain.GRASS_HIGH and Terrain.DIRT, pushed in by terrain.gd so the two colours a human
// picked by eye live in ONE place. Plain uniforms and not source_color hints: the conversion
// out of sRGB happens once, below, for the vertex colour and for these, through the same
// function, so there is exactly one code path and no question about who converted what.
uniform vec4 grass_high = vec4(0.381, 0.551, 0.261, 1.0);
uniform vec4 dirt_color = vec4(0.393, 0.329, 0.157, 1.0);

uniform float fine_metres = 0.9;
uniform float coarse_metres = 4.5;
uniform float fine_amount = 0.055;
uniform float coarse_amount = 0.030;
// THE MEADOW IS NOT ONE GREEN (FS2.2): over patches about macro_metres across the grass drifts
// toward a warmer, sun-dried green, so the valley reads as ground and not as a painted floor.
// THE GRASS AT THINGS' FEET AND A BRUSHED GRAIN (PS10 gap G2; FS2.2). contact_mask is
// painted on the CPU from every solid prop's footprint (Terrain.paint_contact): 1 at a base,
// fading to 0 in the open; it darkens the grass by contact_dark. The grain is a stretched,
// fine noise, like brush strokes laid one way, near the camera only.
uniform sampler2D contact_mask : filter_linear, repeat_disable;
uniform vec2 contact_origin = vec2(-110.0, -110.0);
uniform vec2 contact_size = vec2(220.0, 220.0);
uniform float contact_dark = 0.0;
uniform float grain_amount = 0.0;
uniform float macro_metres = 42.0;
uniform float macro_amount = 0.5;
uniform vec3 macro_warm = vec3(1.12, 1.04, 0.72);
// TUNED TO THIS HEIGHTFIELD, NOT TO A TEXTBOOK. slope here is 1.0 - normal.y, and this map is
// gentle: sampling Terrain.height_at() at the mesh's own 2 m cell over all 220 m, the STEEPEST
// point on the whole map measures 0.0442 (16.8 degrees), on the lake basin's own rim. The
// shipped 0.30 / 0.68 pair wanted a 45 degree bank to begin and a 71 degree cliff to finish, so
// smoothstep returned exactly 0.0 at every point in the game and not one pixel of dirt was ever
// drawn.
//
// A WIDE 0.010 / 0.055 BAND WAS TRIED FIRST AND REJECTED BY EYE: it never saturates anywhere on
// this map (0.055 sits past the map's own worst slope), so even the lake basin's steepest rim
// mixed in at under half strength, and a brown this muted at that fraction reads as a shadow on
// the grass rather than as a second surface. 0.012 / 0.035 is narrower and sits UNDER the map's
// worst slope on purpose: the basin's own rim (0.042 to 0.044) then clears slope_high and gets
// full-strength dirt, the gentler shoulders around it (0.02 to 0.035) shade in partway, and
// nothing below about 7 degrees (0.012) takes any earth at all, which keeps the flat majority of
// the map pure grass. Confirmed by re-rendering the lake basin (shot 20, day and dusk): a
// visible dirt ring around the water that reads as a second surface, not a brown hillside.
uniform float slope_low = 0.012;
uniform float slope_high = 0.035;
uniform float ridge_lift = 0.06;
uniform float ridge_low = -6.0;
uniform float ridge_high = 6.0;
uniform float fade_near = 30.0;
uniform float fade_far = 70.0;
uniform float ground_roughness = 0.95;
// THE SHOW'S MEADOW IS PAINTED IN PATCHES (Fable AAA round 2, #2: "one green, no breakup ...
// the strongest Roblox baseplate tell"). Hard-edged patches a few metres across in a sunnier
// and a deeper green, flat fills with crisp edges the way the show's background painters lay
// a field in, plus clover dots close to the lens.
uniform float patch_metres = 5.0;
uniform float patch_light = 0.24;
uniform float patch_dark = 0.22;
uniform float clover_amount = 0.18;

// THE ROAD, PAINTED RATHER THAN LAID. A rigid dirt_road.glb plate cannot follow 0.70 m of
// relief across a 2.28 m footprint -- it either buries its far end or floats its near one,
// and sixteen of them in a row read as a ladder of half-buried planks with grass showing
// through every seam (whole-branch review, 2026-09-05 and its re-review, F3). The ground
// itself has no such problem: height_at() already puts every vertex at the true surface, so
// a colour painted onto that surface conforms to it BY CONSTRUCTION. No plate, no seam, no
// step, ever.
//
// PATH_MAX_POINTS is a shader-array size, not a routing limit: game/world/terrain.gd owns
// the actual polyline (see its PATH_POINTS) and pads it out to this length by repeating its
// own last point, which is a zero-length segment here and contributes nothing extra to the
// distance field. path_point_count is the real length; the loop below stops there.
const int PATH_MAX_POINTS = 12;
uniform vec2 path_points[PATH_MAX_POINTS];
uniform int path_point_count = 0;
// HALF THE CORE WIDTH, IN METRES, where the path is full-strength dirt regardless of edge
// noise. "A couple of metres wide" per the ruling -- 2.2 m of solid core, worn rather than
// taped on because of path_edge_softness and path_edge_noise below.
uniform float path_half_width = 1.1;
uniform float path_edge_softness = 1.3;
// METRES the edge wanders in and out by, driven by the same value_noise() the fine ground
// break-up already uses: a perfectly straight-edged band reads as a UI decal, not a track
// worn by hooves and cartwheels.
uniform float path_edge_noise = 0.5;
// HOW MUCH OF THE PATH'S OWN COLOUR IS ADDED BACK AS AN AMBIENT-INDEPENDENT FLOOR (see the
// fragment shader's own comment on EMISSION): without it, `dirt_color`'s naturally dark
// albedo crushes toward black wherever the path passes through a shadow, which this map's
// dawn lighting does for most of this route's length. TUNED BY MEASURING THE RENDER, not by
// eye on a lit swatch: 0.6 (a "modest floor" guess) still measured sRGB (29, 13, 0) in the
// shipped dawn render's worst (most-shadowed) stretch, barely off black; 5.0 measured
// (88-94, 53-58, 9-15) at the same points -- a legible warm brown next to grass at
// (92, 123, 32). Large because DIRT's own linear albedo is small (roughly a fifth of
// GRASS_HIGH's): the multiplier looks big on the uniform, not on the ground.
uniform float path_glow = 5.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

// NOT OPTIONAL, AND THIS IS THE ONE TRAP IN THE WHOLE SLICE. Godot renders in linear space and
// treats vertex colours as ALREADY linear unless told otherwise. StandardMaterial3D said so
// with vertex_color_is_srgb = true; a ShaderMaterial has NO equivalent flag, so the shader has
// to do it. terrain.gd's own comment records what dropping it looks like: "the first render of
// this terrain was a pale mint sheet, not grass". Every colour a human picks by eye is an sRGB
// colour, so this is what makes GRASS_LOW and GRASS_HIGH mean what they say.
// This is Godot's own conversion, cut and dried.
vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)),
		c * (1.0 / 12.92),
		lessThan(c, vec3(0.04045)));
}

// A 2D integer hash plus smoothstep interpolation: twelve lines of value noise and no
// texture, which is what keeps this slice assetless.
float hash21(vec2 p) {
	vec2 q = fract(p * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// SHORTEST DISTANCE FROM WORLD XZ `p` TO THE PATH POLYLINE, walking each segment in turn.
// A zero-length segment (two padding points repeating the polyline's own last real point)
// collapses `t` to 0.0 rather than dividing by zero, so the padding is inert instead of NaN.
float path_distance(vec2 p) {
	float d = 1.0e6;
	for (int i = 0; i < PATH_MAX_POINTS - 1; i++) {
		if (i >= path_point_count - 1) {
			break;
		}
		vec2 a = path_points[i];
		vec2 b = path_points[i + 1];
		// A point past 50 km is terrain.gd's PATH_BREAK: the end of one road, not a segment.
		if (a.x > 50000.0 || b.x > 50000.0) {
			continue;
		}
		vec2 ab = b - a;
		float len2 = dot(ab, ab);
		float t = len2 > 0.0001 ? clamp(dot(p - a, ab) / len2, 0.0, 1.0) : 0.0;
		d = min(d, distance(p, a + ab * t));
	}
	return d;
}

void vertex() {
	// World space, taken here rather than in the fragment: NORMAL is VIEW space in a Godot
	// fragment shader, and a slope mask built on a view space normal changes as the camera
	// turns, which would make the hillsides slide around under a moving player.
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = srgb_to_linear(COLOR.rgb);
	vec3 high = srgb_to_linear(grass_high.rgb);
	vec3 dirt = srgb_to_linear(dirt_color.rgb);

	// THE FINE OCTAVE FADES OUT WITH DISTANCE. VERTEX in a fragment shader is the view space
	// position, so its length is the view distance. Without this fade the 0.9 m noise buys
	// aliasing instead of detail: it shimmers in the middle distance under a moving camera,
	// which is worse than the flat gradient it replaced.
	float fine_fade = 1.0 - smoothstep(fade_near, fade_far, length(VERTEX));
	float fine = (value_noise(v_world_pos.xz / fine_metres) - 0.5) * 2.0;
	float coarse = value_noise(v_world_pos.xz / coarse_metres);

	base *= 1.0 + fine * fine_amount * fine_fade;
	base = mix(base, high, coarse * coarse_amount);
	float macro = smoothstep(0.25, 0.75, value_noise(v_world_pos.xz / macro_metres + vec2(17.3, 4.1)));
	base = mix(base, base * macro_warm, macro * macro_amount);

	// The brushed grain: noise stretched 4:1 along a fixed stroke direction, 0.25 m across.
	vec2 stroke = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * v_world_pos.xz;
	float grain = (value_noise(stroke * vec2(1.0, 4.0) / 1.0) - 0.5) * 2.0;
	base *= 1.0 + grain * grain_amount * fine_fade;

	vec2 pq = v_world_pos.xz / patch_metres;
	float pn = value_noise(pq + vec2(3.7, 9.2)) * 0.62 + value_noise(pq * 2.7 + vec2(1.1, 5.3)) * 0.38;
	float lit_patch = smoothstep(0.645, 0.665, pn);
	float deep_patch = smoothstep(0.355, 0.335, pn);
	base *= 1.0 + lit_patch * patch_light - deep_patch * patch_dark;
	base = mix(base, base * vec3(1.07, 1.04, 0.80), lit_patch * 0.7);
	base = mix(base, base * vec3(0.88, 1.0, 1.10), deep_patch * 0.6);
	// Clover: small round darker dots in drifts, only near enough to read as dots.
	float drift_c = smoothstep(0.55, 0.7, value_noise(v_world_pos.xz / 3.3 + vec2(8.8, 2.2)));
	vec2 cc = fract(v_world_pos.xz * 2.2) - 0.5;
	float dot_c = smoothstep(0.24, 0.20, length(cc)) * step(0.55, value_noise(floor(v_world_pos.xz * 2.2) * 1.37));
	base *= 1.0 - dot_c * drift_c * clover_amount * fine_fade;

		// A SLOPE YOU CAN SEE IS A SLOPE YOU CAN PLAN A WALK AROUND. Hillsides and the lake basin
	// walls become earth, which is both more believable and free relief reading.
	float slope = 1.0 - clamp(v_world_normal.y, 0.0, 1.0);
	float earth = smoothstep(slope_low, slope_high, slope);
	base = mix(base, dirt, earth);

	// The ridge lift is small on purpose: grass_at() already does some of this per vertex, and
	// this version is continuous where that one is stepped at 2 m.
	float ridge = smoothstep(ridge_low, ridge_high, v_world_pos.y);
	base = mix(base, high, ridge * ridge_lift * (1.0 - earth));

	// THE PATH IS THE LAST THING DRAWN, on top of slope and ridge both: a worn track reads as
	// dirt whether it happens to cross a hillside or a rise, not as a hillside that got lucky
	// enough to sit under a road. path_edge_noise perturbs the SAME distance field the core
	// width is measured against, so the noise moves the edge itself rather than just painting
	// speckles across it -- a wandering border reads as worn ground, a speckled hard border
	// reads as a decal with dirt on it.
	if (path_point_count > 1) {
		float pd = path_distance(v_world_pos.xz);
		// Two octaves: the broad wander, and a finer one so that seen from a pony's eye height
		// the border breaks into tongues of grass and bites of dirt instead of a ruled line
		// (Fable round 2 renders: "a hard straight seam between grass and dirt").
		float wobble = (value_noise(v_world_pos.xz / 2.5) - 0.5) * path_edge_noise
			+ (value_noise(v_world_pos.xz / 0.55) - 0.5) * path_edge_noise * 0.9;
		float path = clamp(1.0 - smoothstep(path_half_width + wobble,
			path_half_width + path_edge_softness + wobble, pd), 0.0, 1.0);
		// A ROAD WITH WEAR IN IT, NOT A FLAT FILL (owner, 2026-10-25: "starting area is
		// terrible"; the plaza read as one orange sheet). The crown is packed lighter where the
		// hooves go, two darker ruts run a cart's width apart, and small pebbles break it up.
		// All of it rides on the path mask, so the edge itself is unchanged.
		float crown = 1.0 - smoothstep(0.0, path_half_width * 0.8, pd);
		float rut = 1.0 - smoothstep(0.0, 0.16, abs(pd - path_half_width * 0.55));
		float pebble = step(0.8, value_noise(v_world_pos.xz * 3.1)) * value_noise(v_world_pos.xz * 7.3);
		vec3 road = dirt * (1.0 + 0.16 * crown - 0.18 * rut - 0.22 * pebble);
		// RAIN LEAVES PUDDLES (Fable AAA round 2, #7: "no wet ground, no puddles"): flat
		// sky-grey pools in the ruts and dips of the track, a pale rim on their far side.
		float pn2 = value_noise(v_world_pos.xz / 1.7 + vec2(4.4, 1.9)) + rut * 0.18;
		float pool = smoothstep(0.66, 0.68, pn2) * wet;
		float rim = (smoothstep(0.64, 0.66, pn2) - smoothstep(0.66, 0.68, pn2)) * wet;
		road = mix(road, srgb_to_linear(vec3(0.50, 0.55, 0.66)), pool * 0.85);
		road = mix(road, road * 0.62, rim * 0.6);
		road *= 1.0 - 0.22 * wet * (1.0 - pool);
		base = mix(base, road, path);

		// A WORN PATH READS AS PACKED, LIGHTER EARTH EVEN IN SHADOW -- REAL ambient-only
		// lighting DOES NOT AGREE. Measured on this map's own dawn render: the corridor this
		// route runs through sits in the long, low-sun-angle shadow of the trees and fence
		// posts that line it for most of its length, and `dirt`'s already-dark albedo
		// (roughly a fifth of grass's) crushes toward black once only the environment's 0.32
		// ambient energy is left to light it (measured: sRGB (19, 5, 0) in the shipped dawn
		// render, next to grass at (92, 123, 32) two metres away) -- a scorch mark, not a
		// track. `path_glow` is an ambient-INDEPENDENT floor, scaled by the same mask the
		// path's own colour is blended by, so it never reaches past what direct sun already
		// contributes in the open (see path_glow's own comment for the render-measured
		// numbers) -- it only does anything where shadow would otherwise have erased the
		// road entirely.
		EMISSION += dirt * path * path_glow;
	}

	// Darker grass round whatever stands on it (the contact mask), a little cooler too.
	float contact = texture(contact_mask, (v_world_pos.xz - contact_origin) / contact_size).r;
	base *= 1.0 - contact * contact_dark * vec3(1.0, 0.92, 0.85);

	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(lum) * vec3(0.96, 0.99, 1.02), clamp(dread, 0.0, 1.0) * 0.55);
	// MOONLIT, NOT A DIM NOON (Fable AAA round 2, #7: "fully lit saturated green grass under a
	// starry sky"): at night the field loses most of its colour toward a blue-grey, and rain
	// darkens everything a shade more, the way soaked ground reads.
	float ng = clamp(night_glow, 0.0, 1.0);
	base = mix(base, vec3(lum) * vec3(0.78, 0.9, 1.18), ng * 0.5);
	base *= 1.0 - 0.2 * ng;
	base *= 1.0 - 0.14 * clamp(wet, 0.0, 1.0);
	ALBEDO = base;
	ROUGHNESS = ground_roughness;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-band_softness, band_softness, ndl);
	float falloff = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		lit = min(lit, smoothstep(0.35, 0.65, ATTENUATION));
	} else {
		falloff = ATTENUATION;
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * mix(shadow_tint * shadow_fill, vec3(1.0), lit) * falloff;
}
