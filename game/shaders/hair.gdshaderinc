// HAIR SHADES AS ONE ROUNDED MASS (P8 S6; playtest 2026-11-08 item 34: "the player mane is a flat
// cutout"; docs/aaa-review-2026-11-08.md 2.2). A mane is a stack of cards, and each card lit by
// its own normal is a flat tone with a hard edge. Bending every normal toward the direction
// out from the hair's own middle (xyz, mesh space) by `w` makes the cards light as one soft
// shape, the standard anime hair fix, without new models. Set per INSTANCE by PonyPaint on a
// mesh that is only hair; w 0 (every other mesh) leaves the normal alone.
// Declared right after dither.gdshaderinc in every shader that shares a pony's mesh, so the
// instance slots line up.
instance uniform vec4 hair_center = vec4(0.0);
