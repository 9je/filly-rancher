# Playtest note 10 -- pony textures and eyes

**The note (owner, real hardware):** "Bad textures on some pony models and weird eyes on others."
**Added by the lead:** some ponies look grainy, speckled or dithered in close-up screenshots
(build/playtest_evidence/beam_highlight.png).

**The order:** a turntable contact sheet of every pony model plus 50 random ones (front, side,
three-quarter, eye close-up); fix every missing or broken texture and every eye issue; a test that
fails if any pony material is missing a texture.

## How it was looked at

`game/scenes/test/pony_turntable.gd`, run by `tools/pony_turntable.sh OUT_DIR`, builds every pony
the same way the game does: the 43 roster records through `pony.tscn` `setup()`, Spike through the
real `SpikeActor`, the 7 story characters through `npc.gd`, and 50 generated Drifters through
`PonyGenerator.generate()` + `set_stock()`. It renders on the invisible display with the real GPU.
Each pony gets six views: front, side, three-quarter, an eye close-up, a 16 m long-lens view, and the
three-quarter view again at the FAR detail tier. The FAR tier uses the outline-free twin materials
and hides tongue and teeth, so a far-off twin that lost its texture shows up in that last view.
The stage uses the ranch's own sun settings (PCSS soft shadows, bias, splits) and environment
(SSAO, glow, grade). The script also runs the material audit below on every pony, at both tiers.

Contact sheets (one row per pony, eight ponies a sheet, plus eyes-only sheets):

- `build/playtest_evidence/ponies/before/sheet_00..12.jpg`, `eyes_00..05.jpg`. These come from the
  first version of the stage: plain light, five columns, no 16 m view.
- `build/playtest_evidence/ponies/after/sheet_00..12.jpg`, `eyes_00..05.jpg`. These come from the
  final stage, rendered on the merged branch.
- `speckle_ingame_before_after.jpg`: the same look from the real-input test, before and after.
- `speckle_dawn_old_vs_new_ramp.jpg`: the ranch at dawn with the old and new shadow ramp, with and
  without PCSS.
- `test/test_pony_materials_before.txt` (the failing run) and `test/test_pony_materials_after.txt`.

## Root causes, model by model

### 1. Purple-checkered eyebrows and eyelashes: 37 canon ponies (the "weird eyes")

Affected: aloeblossom, applebloom, berrypunch, bonbon, braeburn, caramel, carrottop, cheerilee,
cloudchaser, cocopommel, **derpyhooves**, drwhooves, flitter, kerfuffle, lightningdust,
limestonepie, lotusblossom, lyra, mane_allgood, marblepie, maudpie, minuette, nightlight,
**octavia**, pinkamena, pinkiepie, pokeypierce, redheart, scootaloo, shiningarmor, soarin, spitfire,
starlightglimmer, sunsetshimmer, sweetiebelle, **trixie**, vinylscratch. That is every
PonySFM/ReVAmped model on the roster.

Every ReVAmped `eyebrow.vmt` and `eyelashes.vmt`
(`assets_raw/sfm/.../VA_MLP/Common/`) is `$basetexture "vgui/white"` tinted by `$color2 {0 0 0}`.
`vgui/white` is a Source engine texture, and no pony pack ships it. SourceIO could not find it, so
it wrote its own missing-texture checker in its place as `<id>_missing_white.png`. The file is
512x512 and averages RGB (77, 0, 77): it is the magenta-and-black checkerboard. Then
`tools/sfm_rig.py` wired every `$basetexture` straight into Base Color. That rule exists for a good
reason (it fixed hooves that came out untextured), but here it painted the checker onto the brows
and lashes. In game the toon shader drew it, so every canon SFM pony had dark purple, grainy brows
and lashes framing her eyes. Drifters were not affected, because PonyPaint recolours brows and
lashes itself.

**Fix:**

- In-game (`game/systems/toon_styler.gd`): `is_placeholder()` and `is_face_line()`. An SFM
  `eyebrow` or `eyelashes` surface whose texture is a placeholder, or a flat black, gets
  `_face_line()`. That draws the lashes near-black (Source's own `$color2 {0 0 0}`) and the brows
  in her coat colour darkened, which is exactly what PonyPaint gives a Drifter. The coat colour is
  the commonest colour of her `body` texture, cached per texture. This fixes the converted models
  already on the owner's machine without re-converting anything.
- At the source (`tools/sfm_rig.py`): `_is_placeholder()`. For an eyebrow or eyelashes surface the
  converter no longer wires in the checker; it ships the flat black Source intended. I checked this
  by re-converting kerfuffle and marblepie into a scratch directory: both now come out with
  eyebrow and eyelashes `baseColorFactor [0,0,0,1]` and no texture.

### 2. Marble Pie's forelock: magenta checker

Her `manetop.vmt` asks for `MarblePie/manetop`, but her pack ships `ManeFront.vtf` and
`ManeSide.vtf` and no `manetop`. SourceIO wrote `marblepie_missing_manetop.png` (the checker), so
her forelock rendered purple instead of grey.

**Fix:** `ToonStyler._with_sibling_texture()`. Any other surface whose texture is a placeholder
borrows the real texture of the sibling material with the longest shared name prefix (here
ManeSide, the same grey hair). With no sibling it falls back to a flat darkened coat colour. The
converter now prints `SOURCE_PLACEHOLDER` for this case so the next conversion says so out loud.

### 3. Applejack: invisible body (the worst "bad texture")

Her hat, mane, tail, eyes and teeth floated over the grass with no pony under them, in every view
and at every tier. `PonyLod` (the runtime mesh LODs) rebuilt each mesh with
`add_surface_from_arrays(..., format & ARRAY_FLAG_USE_8_BONE_WEIGHTS)`. That passed only the
bone-weight flag and dropped the CUSTOM0..3 channel format bits. Applejack's `Base_Body` carries a
custom channel, so the rendering server rejected all four of its surfaces ("Invalid array format
for surface"), and the rebuilt mesh had **zero surfaces**: coat, face and mouth all gone. Raw
import: 4 surfaces. After PonyLod: 0.

**Fix** (`game/actors/pony/pony_lod.gd`, reapplied onto v1-overhaul's threaded rebuild):
`_keep_bits()` keeps the custom-channel format bits, both for the decimation and for the assembly.
If the server still refuses a surface, the original un-LOD'd mesh is kept. A pony with too many
triangles is better than a pony missing her body.

### 4. Spike: blank white eyes with a green sliver (for Damon)

His eyeball UVs are a generic sphere unwrap. Source's `eyes` shader never used them: it casts
`$iris` onto the eyeball along the eye's own axis. Through those UVs, his iris texture (a green slit
iris in the middle of a white square) landed as a green edge on a blank white eye.

**Fix:** a `planar` mode in `game/shaders/pony_eye.gdshader`, which projects the iris in model space
along +Z. `SpikeActor._eye()` measures each eyeball from the mesh (centre and extent) and feeds that
in. He now has proper green slit-pupil eyes (`after/sheet_05.jpg`). His body also moved from the
built-in `DIFFUSE_TOON` StandardMaterial to ToonStyler's toon material, the light every pony
wears. That gives him an outline, and the built-in toon's hard shadow step had been speckling him
like the ponies (cause 5).

### 5. Grainy, speckled, dithered ponies (the lead's screenshot)

Not a texture problem and not a dither fade: it is the shadows. The ranch sun uses soft shadows
(PCSS, `light_angular_distance 0.9`, `shadow_blur 1.1`). Godot samples those with a per-pixel
rotated pattern, so across a penumbra or a self-shadowed flank the shadow term `ATTENUATION`
hovers round 0.5 with pixel noise in it. `toon.gdshader` banded that term with
`smoothstep(0.45, 0.55, ...)`, a 10x contrast gain right at 0.5, which turned the noise into
full-contrast salt and pepper on every toon surface: ponies, trees, walls, grass. It was worst at
dawn, where every new game starts, because the low sun throws long penumbras. Turning PCSS off in
the probe made it disappear completely. SSAO, MSAA and 3D scaling made no difference
(`speckle_dawn_old_vs_new_ramp.jpg`).

**Fix:** the shadow term's ramp is now `smoothstep(0.2, 0.8, ATTENUATION)`. The shadow edge stays,
and the noise comes through at about a fifth of the contrast. In the real-input test's view
(`speckle_ingame_before_after.jpg`) Tumble, Night Light and the herd went from fully speckled to
clean.

**Residual, for the shadow agent:** a faint grain is left in deep penumbras. It is the PCSS
sampling noise itself, and with no TAA nothing resolves it. `light_angular_distance = 0` on the
ranch Sun removes it entirely; a higher `soft_shadow_filter_quality` reduces it. I left the light
alone, because the shadow agent owns it.

### Checked and found sound

- **Far-tier twins (`ToonStyler.BARE_META`) keep their textures.** `_toon_from()` copies the
  albedo texture into the twin, and the audit compares every twin's texture with its original's at
  FULL and FAR. No pony anywhere ever lost a texture at distance.
- **Eye materials.** Every eyeball (SFM `eyeball_l/_r`, mane-6 `Base_Iris`/`Base_Eyes`) has a
  material, and every eye-shader material has its `eye_texture`, at every tier.
- **The 50 generated Drifters.** PonyPaint's flat recolours, the eyes and the marks are all correct
  (`after/sheet_06..12.jpg`).
- **Stale import cache.** The fresh import here was clean, and `tools/fix_stale_imports.py` removed
  0 entries after the merge. The owner's copy should still get that script run on it, as play.sh
  already does.

## The test

`game/test_input/test_pony_materials.gd`, run with `tools/run_input_tests.sh pony_materials`, uses
the rules in `game/test_input/pony_material_audit.gd`.

It boots through the real title screen and creator with RealInput. Every roster character (43)
plus 50 generated Drifters are stood in the nearest meadow by the spawner's own
`spawn_guest()` path. The player looks away from them (FAR tier), walks over with W and the mouse
and looks round among them (FULL tier), walks to anyone not yet seen up close, then walks back and
turns away (FAR again). At every look it audits every MeshInstance3D surface of every pony, every
story character, Spike and the player. It fails on:

- a toon or outline pass with `use_texture` on and no texture;
- an eye shader with no `eye_texture`;
- a texture that failed to load (0 x 0) or is the converter's missing-texture placeholder;
- an imported texture the active material dropped (PonyPaint's deliberate recolours are tagged
  `recolored`);
- a StandardMaterial3D that expects a texture and has none;
- an eye surface with no material;
- a visible mesh with no surfaces left;
- a far twin whose texture differs from its original's.

It also fails if any pony was never seen at both FULL and FAR, or if `_play()` ended without
reaching a verdict. That last check guards a harness hazard: `InputTest._main()` calls
`ok("finished")` when `_play()` returns, and a script error returns it early.

**Before the fix (failing):**

```
INPUT_TEST_NOTE 881.5s 19 looks, 93 actors (11 left the world mid-test), 368 distinct problems
INPUT_TEST_NOTE problem: roster:applejack@FULL Base_Body: visible mesh with no surfaces (her geometry was lost)
INPUT_TEST_NOTE problem: roster:berrypunch@FULL bodyparts_feral_heads_reference_RD_reVAmped_head_HWM_dmx#4 eyelashes: placeholder texture 'berrypunch_missing_white.png' (the converter could not find the real one)
...
INPUT_TEST_FAILED test_pony_materials 368 broken pony materials (first: roster:aloeblossom@FAR bodyparts_feral_eyebrows_reVAmped_eyebrows_dmx#0 eyebrow: placeholder texture 'aloeblossom_missing_white.png' (the converter could not find the real one))
```

The 368 are each material at each tier, across the 37 SFM brows and lashes, Marble Pie's ManeTop
and Applejack's body. The turntable audit on the same code printed 300 `TURNTABLE_PROBLEM` lines.

**After the fix, merged with v1-overhaul (passing):**

```
[pony_materials] INPUT_TEST_OK test_pony_materials 93 ponies, cast, Spike and the player: no missing texture or eye, near and far
INPUT_TESTS passed=1 failed=0
```

The turntable audit gives `TURNTABLE_DONE ... problems=0` over all 101 ponies.

Also run after the merge:

- `tools/run_input_tests.sh first_pony` passes (`caught on the first try`).
- GUT: test_pony_visuals, test_pony_generator, test_roster_data, test_creation_screen,
  test_import_settings and test_pony pass, 128/128.

## Found but not fixed

- **Guests fall through the world.** When 93 guests are stood at one marker, some land on
  `Spawner._ground_point()`'s counted fallback, which uses the marker's own height. They fall
  through the terrain: in one run, 6 to 11 of 93 were thousands of metres down within a minute. The
  test names them and judges them on the looks they had. The real herd never asks one marker for
  that many, but the fallback can still put a pony under the ground.
- **Residual PCSS grain** (cause 5 above), left for the shadow agent.
- **Milky Way's eyelashes are a flat lavender** from her own conversion (a factor, not a
  placeholder). They read light next to her eyes, but they are her model's own data, so I left
  them alone.
- **`InputTest._main()` turns a script error inside `_play()` into a pass.** This test guards
  against it; the base class should too.
