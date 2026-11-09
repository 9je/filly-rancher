class_name WorldMarker
extends RefCounted
## A CUE OVER SOMEBODY'S HEAD THAT IS NEVER A GIANT (Fable AAA round 2, #9: "a huge faded
## yellow '!' bubble, about 150 px, bleeding in at the left screen edge"). The news bubble is
## a billboard in the world, hidden by walls like anything else there (round 1 asked for
## that); this material keeps it at its world size far off and SHRINKS it inside NEAR_SIZE
## metres, so on screen it is never bigger than it is at NEAR_SIZE (about 45 px at 1080 p),
## and it fades out entirely within FADE_TO metres of the lens, where the townspony she is
## standing beside needs no bubble to be found.
##
## Static only. Preload by path.

const NEAR_SIZE := 7.0
const FADE_FROM := 1.6
const FADE_TO := 3.2

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float near_size = 7.0;
uniform float fade_from = 1.6;
uniform float fade_to = 3.2;
varying float v_fade;
void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float d = distance(origin, INV_VIEW_MATRIX[3].xyz);
	// Facing the lens, upright with it.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= clamp(d / near_size, 0.0, 1.0);
	v_fade = smoothstep(fade_from, fade_to, d);
}
void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a * v_fade;
}
"""

static var _shader: Shader = null


## A material for a billboard quad showing `texture`, by the rules above.
static func material(texture: Texture2D) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(&"tex", texture)
	m.set_shader_parameter(&"near_size", NEAR_SIZE)
	m.set_shader_parameter(&"fade_from", FADE_FROM)
	m.set_shader_parameter(&"fade_to", FADE_TO)
	m.render_priority = 10
	return m


## How big the marker's quad is drawn at `distance` metres, as a fraction of its world size.
static func scale_at(distance: float) -> float:
	return clampf(distance / NEAR_SIZE, 0.0, 1.0)
