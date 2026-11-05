// THE SLAPSTICK BOUNCE (actors/pony/rump_bounce.gd; owner's call, DECISIONS.md 2026-11-05):
// vertices near her hindquarters move up and down on a spring, squashing outward on the way
// down and narrowing on the way up. bounce_at is the centre (mesh space, xyz) and radius (w);
// bounce_amount the spring's displacement in metres. Zero (the default, and every prop): as
// modelled.
instance uniform vec4 bounce_at = vec4(0.0);
instance uniform float bounce_amount = 0.0;
// Toward her tail, mesh space: the cheeks also push back and pull in along it.
instance uniform vec3 bounce_back = vec3(0.0, 0.0, 1.0);

vec3 bounce_offset(vec3 v) {
	if (bounce_at.w <= 0.0 || abs(bounce_amount) < 1e-5) {
		return vec3(0.0);
	}
	vec3 rel = v - bounce_at.xyz;
	float w = 1.0 - smoothstep(0.0, 1.0, length(rel) / bounce_at.w);
	// The cheeks move down to the top of her thighs; her legs below stay planted.
	w *= smoothstep(-0.95, -0.4, rel.y / bounce_at.w);
	// The rear of her more than her middle: behind the centre counts in full.
	w *= mix(0.35, 1.0, smoothstep(-0.6, 0.2, dot(rel, bounce_back) / bounce_at.w));
	vec3 side = vec3(rel.x, 0.0, rel.z);
	// Down and spread, then up and in, and back and forth along her length with it.
	return (vec3(0.0, bounce_amount, 0.0) - side * bounce_amount * 2.0
		- bounce_back * bounce_amount * 0.8) * w;
}
