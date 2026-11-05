// THE SLAPSTICK BOUNCE (actors/pony/rump_bounce.gd; owner's call, DECISIONS.md 2026-11-05):
// vertices near her hindquarters move up and down on a spring, squashing outward on the way
// down and narrowing on the way up. bounce_at is the centre (mesh space, xyz) and radius (w);
// bounce_amount the spring's displacement in metres. Zero (the default, and every prop): as
// modelled.
instance uniform vec4 bounce_at = vec4(0.0);
instance uniform float bounce_amount = 0.0;

vec3 bounce_offset(vec3 v) {
	if (bounce_at.w <= 0.0 || abs(bounce_amount) < 1e-5) {
		return vec3(0.0);
	}
	vec3 rel = v - bounce_at.xyz;
	float w = 1.0 - smoothstep(0.0, 1.0, length(rel) / bounce_at.w);
	w = sqrt(w);
	vec3 side = vec3(rel.x, 0.0, rel.z);
	return (vec3(0.0, bounce_amount, 0.0) - side * bounce_amount * 2.5) * w;
}
