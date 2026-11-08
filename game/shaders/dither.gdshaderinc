// A SCREEN-DOOR FADE (P8 S5/S6; docs/aaa-review-2026-11-08.md 2.2). The player fades when the
// camera comes in close; drawn half transparent she was a ghost you could see neither clearly
// nor past (playtest 2026-11-08 item 33). A 4x4 ordered dither drops a growing share of pixels
// instead, so every pixel drawn is fully her and the rest is fully the world behind, as in
// Odyssey and Breath of the Wild. Set per INSTANCE (camera_rig.gd), 1 solid, 0 gone.
instance uniform float dither_fade = 1.0;

void dither_clip(vec2 frag) {
	if (dither_fade >= 0.999) {
		return;
	}
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	if (dither_fade * 16.0 <= BAYER[y * 4 + x] + 0.5) {
		discard;
	}
}
