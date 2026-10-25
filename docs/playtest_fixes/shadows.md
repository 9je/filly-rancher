# Playtest note: "Weird shadows around the map, especially on distant hills."

## What was actually on screen

Rendered through the steward's own camera on the GPU (invisible display), at dawn (sun 8 deg),
noon (60 deg) and dusk (8 deg), near (homestead, under 20 m), mid (pens, 20 to 50 m) and far
(the open valley and its hills, past 50 m). Each frame was compared with the same frame drawn
with the sun's shadow map switched off, so anything that differs is the shadow map's doing.

1. **Stipple acne everywhere the sun is low.** Lit ponies were covered in a fine salt-and-pepper
   grain (worst at dawn and dusk; see `zoom_pony_near_dawn_before_left_after_right.jpg`), and the
   ground had the same grain along every shadow edge, in bands up to tens of pixels wide that
   widened with distance from the caster: long dusk tree shadows across the far fields read as
   grainy smears rather than shadows. That is the "weird" look on the hills.
2. **Shadows that end on a ring.** The shadow map stopped at 85 m with a fade over the last 7 m
   (78 to 85 m). Through the toon step a fade is not a fade: it becomes a hard line where the
   faded shadow crosses the step's threshold, so a palace or tree shadow on the far ground ended
   along an arc around the camera and the arc travelled with the player.

## Root cause, setting by setting

| Setting (ranch.tscn, `Sun`) | Old | Artifact it caused |
|---|---|---|
| `light_angular_distance` | 0.9 | Turns on PCSS. Godot samples the blocker search and the filter with a per-pixel rotated noise kernel; the penumbra grows with distance from the caster (0.9 deg is about 1.6 cm per metre). The toon shaders then threshold ATTENUATION (`toon.gdshader`, `terrain.gdshader`), so every noisy partial value became a hard on/off pixel: the stipple on ponies (self-shadow over a whole lit body) and the wide grainy penumbras on the far ground. **The main cause.** |
| `shadow_blur` | 1.1 | Widened the same noisy PCF kernel; measured worse at 2.0, better at 0.6. |
| `directional_shadow_max_distance` | 85 | Shadows stopped at 85 m; everything past it, including most of the visible valley floor from the edges of the map, had none. |
| `directional_shadow_fade_start` | 0.92 | 7 m fade, thresholded by the toon step into a hard, camera-following line (the popping ring). |
| splits 1/2/3 | 0.06 / 0.17 / 0.42 | Re-spread for the longer range so the first cascade stays tight around the player. |
| `shadow_bias` / `shadow_normal_bias` | 0.02 / 1.2 | Marginal at an 8 deg sun with the longer cascades; raised a little. Higher (0.05 / 2.5) measured no better and starts to detach contact shadows. |

The pony agent's change on v1-overhaul (toon shadow step widened to `smoothstep(0.2, 0.8)`) is
merged in and helps, but the before run below is on that merged code and still fails: the noise
itself comes from PCSS, and only `light_angular_distance = 0` removes it.

## The fix (game/world/ranch.tscn, node `Sun`)

| Property | Old | New |
|---|---|---|
| light_angular_distance | 0.9 | 0 (PCSS off; the toon look wants crisp edges anyway) |
| shadow_blur | 1.1 | 0.6 |
| shadow_bias | 0.02 | 0.03 |
| shadow_normal_bias | 1.2 | 1.5 |
| directional_shadow_max_distance | 85 | 160 |
| directional_shadow_split_1 / 2 / 3 | 0.06 / 0.17 / 0.42 (5 / 14 / 36 m) | 0.05 / 0.15 / 0.40 (8 / 24 / 64 m) |
| directional_shadow_fade_start | 0.92 (78 to 85 m) | 0.75 (120 to 160 m) |
| directional_shadow_blend_splits | true | true (kept) |
| directional_shadow_mode | 4 splits | 4 splits (kept) |
| directional_shadow_pancake_size | 20 | 20 (kept) |

Project settings left alone, on purpose:
- `directional_shadow/size` stays the settings menu's preset (1024 / 2048 / 4096 for Low / Medium /
  High, `systems/settings.gd`); the owner plays on High (4096). Nothing in this fix fights the
  preset.
- `soft_shadow_filter_quality` stays at 2 (Soft Low). Medium (3) was measured: about 10% less
  edge speckle on top of the fix, for 50% more filter taps on every shadowed pixel of four
  cascades. Not worth it once PCSS is off.

## The test: game/test_input/test_shadows.gd

Run with `tools/run_input_tests.sh shadows` (set `FILLY_SHADOW_DUMP=/abs/dir` to keep every
judged frame as PNG). A fresh game from the title screen: New game, the creator, the letter,
Marigold's welcome, all with real mouse and keys. The steward then walks (WASD, mouse look) to
five spots (near the homestead, the pens, and three looks out across the valley to the hills),
at dawn, noon and dusk: 15 frames.

For every frame the test reads the screen twice, with the shadow map on and off (an instrument,
restored before the next input), and the hour is set on the world clock (a player who plays at
dawn; waiting out 20 game minutes per sun angle buys nothing). Everything the steward does is
RealInput.

**The gate is SPECKLE**: the share of pixels whose drawn-shadow state disagrees with at least 7
of its 8 neighbours, counted only where the shadowless frame is smooth (so silhouettes, fence
wires and moving ponies never count), summed over all frames per distance band (camera
distance from a physics ray per 8-pixel cell; HUD panels and pony silhouettes masked out). No
honest shadow is one pixel across, so isolated pixels are acne or filter noise. Ceilings: near
0.001, mid 0.0015, far 0.0025.

Also printed per frame (stdout, `SHADOW_METRIC` lines), as diagnostics only: FALSE (drawn dark
where a physics ray says the point is lit), MISSING (the reverse) and POPPED (a ground point
that changed state after three steps forward with the sun held still). They do not gate
because the colliders are not the meshes (no collider on foliage under 3 m, capsules for
ponies), which leaves a few percent of noise either way; they did confirm the direction of the
fix (for example near-band popping summed over all frames 0.032 before, 0.022 after).

### Before the fix (v1-overhaul at aa9a22e merged in, old Sun values)

```
[shadows] INPUT_TEST_FAILED test_shadows 2 checks failed: near speckle 0.00436 > 0.0010; mid speckle 0.00255 > 0.0015
INPUT_TESTS passed=0 failed=1
```

(Earlier, before the toon step change was merged, the same measurement read near 0.0054,
mid 0.0026, far 0.0036; single frames reached 0.0176 near at dawn.)

### After the fix

```
[shadows] INPUT_TEST_OK test_shadows shadows clean at every distance and hour (speckle near 0.00018, mid 0.00055, far 0.00077)
[first_pony] INPUT_TEST_OK test_first_pony caught on the first try
[settings] INPUT_TEST_OK test_settings keyboard, controller and mouse all drove every tab; apply, revert and the display timeout hold
INPUT_TESTS passed=3 failed=0
```

## Evidence

`build/playtest_evidence/shadows/` (JPEG; `*_before.jpg`, `*_after.jpg`, and `*_compare.jpg`
with before on top):
- near: `near_near_dawn_*`, plus `zoom_pony_near_dawn_before_left_after_right.jpg`
- mid: `mid_mid_dawn_*`, `mid_noon_mid_noon_*`
- far (the valley and hills): `far_farN_dusk_*`, `far2_farW_dawn_*`, `far3_farE_dusk_*`

## Found, not fixed

- **The rim hills' dark halves are not shadows.** The valley rim (`valley_frame.gd`) casts no
  shadow and lies past the shadow range; its big dark faces at dawn and dusk are the toon N.L
  terminator on a smooth, huge mesh. Frames with and without the shadow map are identical
  there. If the owner still calls those "weird", the fix is in the rim's material (a softer
  `band_softness` or a lifted `shadow_fill` for the rim only), not in the light.
- **The race-track sheet z-fights at distance.** `race_track.gd` lays its dirt sheet 7 cm above
  the terrain (`lift`); from 40 m and more the two depth-fight into dashed stripes that the low
  sun's shadows make more visible. Raising the lift or drawing the terrain under it out would fix
  it; not a light setting.
- **Thin rail shadows at a grazing sun** alias into broken dashes in the third cascade. Inherent
  at 8 deg; more atlas would only shrink it.

## For the lead to re-verify on the GPU

Shadow cost went up: the last cascade now reaches 160 m instead of 85 m, so it draws most of the
valley's casters (trees, fences, buildings) into the atlas every frame. PCSS is off, which saves
filter work. Please re-run the perf gate (`game/scenes/test/perf.gd`; its `shadowdist=` hook
can compare 85, 120 and 160). If it regresses, 120 m with fade 0.75 is the fallback; the
speckle gate does not depend on the range.

Also: during setup, two of my early probe launches ran without `FILLY_TEST_SAVE_DIR`, and at
19:34 on 2026-10-24 they wrote fresh-game `slot_0.json` and `slot_9.json` (with `.bak`) into the
owner's real saves folder (`~/.local/share/godot/app_userdata/Filly Rancher/saves/`). Any save
the owner had in slot 0 or 9 before then was overwritten by a fresh game; there was no
`play.sh` stash to restore from. Every run after that used an isolated save directory.
