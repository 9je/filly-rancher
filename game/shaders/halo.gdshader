// A lamp's halo after dark (Fable AAA round 1, #1: "the two lamp posts on the path have no
// glow"). A soft disc that always faces the lens, added over the scene, scaled by the
// night_glow global so it fades in with the lamps and is gone by day.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

global uniform float night_glow;
uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.5);
uniform float strength = 1.0;

void vertex() {
	// Billboard, keeping the node's own scale.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float core = pow(clamp(1.0 - d, 0.0, 1.0), 3.0);
	float wide = pow(clamp(1.0 - d, 0.0, 1.0), 1.4) * 0.35;
	ALBEDO = tint * (core + wide) * strength * clamp(night_glow, 0.0, 1.0);
}
