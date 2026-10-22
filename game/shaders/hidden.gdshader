// Draws nothing. Used to hide one surface of a mesh whose other surfaces must stay (a canon
// hair clip sharing a mesh with the mane it sits in).
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never;

void fragment() {
	discard;
}
