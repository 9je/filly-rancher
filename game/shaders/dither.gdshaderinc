// A SCREEN-DOOR FADE (P8 S5/S6; docs/aaa-review-2026-11-08.md 2.2). The player fades when the
// camera comes in close; drawn half transparent she was a ghost you could see neither clearly
// nor past (playtest 2026-11-08 item 33). A 4x4 ordered dither drops a growing share of pixels
// instead, so every pixel drawn is fully her and the rest is fully the world behind, as in
// Odyssey and Breath of the Wild. Set per INSTANCE (camera_rig.gd), 1 solid, 0 gone.
instance uniform float dither_fade = 1.0;

void dither_clip_by(vec2 frag, float fade) {
	if (fade >= 0.999) {
		return;
	}
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	if (fade * 16.0 <= BAYER[y * 4 + x] + 0.5) {
		discard;
	}
}

void dither_clip(vec2 frag) {
	dither_clip_by(frag, dither_fade);
}

// NOTHING SITS ON THE LENS (Fable AAA round 1, #5: a follower's eye and hat "clipped by the
// near plane", Spike's back filling the frame). Whatever comes within a metre of the camera
// screen-doors away, as a lens-hugging pony does in Breath of the Wild. `view_depth` is
// -VERTEX.z in fragment().
void dither_clip_near(vec2 frag, float view_depth) {
	dither_clip_by(frag, dither_fade * smoothstep(0.35, 1.0, view_depth));
}
