shader_type spatial;
render_mode cull_back, diffuse_burley;

// THE GROUND. The mesh, the vertex colours, grass_at(), height_at(), the regions and the
// collider are all untouched by this file: game/world/terrain.gd stays the single authority
// on what colour the ground is at a point, and this adds the high frequency break up, the
// slope treatment and the ridge lift that a smooth two colour gradient cannot have.
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

	// A SLOPE YOU CAN SEE IS A SLOPE YOU CAN PLAN A WALK AROUND. Hillsides and the lake basin
	// walls become earth, which is both more believable and free relief reading.
	float slope = 1.0 - clamp(v_world_normal.y, 0.0, 1.0);
	float earth = smoothstep(slope_low, slope_high, slope);
	base = mix(base, dirt, earth);

	// The ridge lift is small on purpose: grass_at() already does some of this per vertex, and
	// this version is continuous where that one is stepped at 2 m.
	float ridge = smoothstep(ridge_low, ridge_high, v_world_pos.y);
	base = mix(base, high, ridge * ridge_lift * (1.0 - earth));

	ALBEDO = base;
	ROUGHNESS = ground_roughness;
	SPECULAR = 0.0;
}
