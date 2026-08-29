# Asset pipeline — Phase 0 recipe

This is the recipe a future session (human or Claude) follows to take a
downloaded community pony/prop model to an animated, in-engine Godot
character or scene prop, without rediscovering anything Phase 0 already
found the hard way. It documents what was **actually run**, including every
deviation, quirk, and dead end — not a restatement of the original plan.

Toolchain: portable Godot `4.5.2-stable` + portable Blender `4.2.23` LTS,
both under `tools/bin/` (nothing installed system-wide, no sudo). Scripts
live in `tools/`. Everything under `assets_raw/`, `tools/bin/`,
`game/assets/converted/`, `game/.godot/`, and `build/` is gitignored — only
the recipe, scripts, and small hand-authored assets are committed.

---

## 1. Toolchain setup

### Prerequisites (host commands, not installed by this repo)

`setup_env.sh` vendors Godot, Blender and SourceIO, but it cannot vendor the
shell utilities it uses to fetch and verify them. Required on the host before
the bootstrap will run at all — the script now preflight-checks these and
exits 1 naming the missing one rather than failing mid-download:

| Command | Used for |
|---|---|
| `curl` | every download |
| `unzip` | Godot zip, SourceIO zip, export-template `.tpz` |
| `tar` | Blender `.tar.xz` |
| `sha256sum`, `sha512sum` | the pinned-checksum verification (§1 quirks) |
| `awk` | parsing checksum-tool output |

Needed by the wider recipe but *not* by the bootstrap, so not preflighted:

| Command | Used for |
|---|---|
| `python3` | `tools/validate_gltf.py` (stdlib only, no pip installs) |
| `ffmpeg` | voice-line resampling (§8, `docs/notes-voice.md`) |
| `xvfb-run` + a software GL/Vulkan stack (Mesa llvmpipe) | the offscreen render check §7 recommends — the only gate that catches a rendering bug the structural gates cannot see |

**`setup_env.sh` is not the *whole* bootstrap.** It does **not** install
Godot's export templates: that is a separate ~1.3GB manual download,
documented in §9, and it is a prerequisite for `--export-release` (nothing
else in this doc). Do it once per machine, before §9.

### Bootstrap

One command, idempotent, run from the repo root:

```bash
bash tools/setup_env.sh
```

This downloads and unpacks Godot + Blender into `tools/bin/godot` and
`tools/bin/blender/`, installs and enables the SourceIO Blender addon (tier
c), and prints version strings ending in `toolchain ready`. Re-running it is
a near-instant no-op once everything is in place (`[ ! -x ... ]` guards).

**Quirks discovered running this for real:**

- **`download.blender.org` is Cloudflare-gated against curl** (HTTP 403,
  JS challenge, no way for a non-browser client to pass it). The script
  pulls Blender from the official mirror `mirror.clarkson.edu` instead — a
  listed Blender mirror, not a random third party. Both the tarball and its
  checksum come from the mirror; the checksum was independently
  cross-checked against a fresh local `sha256sum` of the actual downloaded
  bytes before being pinned, so trusting the mirror's own `.sha256` file
  isn't blind trust.
- **Every download is SHA-pinned and verified before extraction.** Godot's
  hash comes straight from its own `SHA512-SUMS.txt` release asset (no
  mirror involved there); Blender's and SourceIO's hashes come from their
  respective sources and are checked with `verify_checksum()` immediately
  after download — on mismatch the bad file is deleted and the script exits
  1 before anything is unpacked. This matters because the mirror swap above
  means a byte-for-byte guarantee has to come from pinning, not from trusting
  the host. Do not delete or "simplify away" the checksum block if you edit
  this script.
- **SourceIO's enable-state lives outside the repo, in `~/.config/blender/4.2/`.**
  This Blender build has no "portable install" marker, so at runtime it reads
  user prefs/addons from the OS home-dir config, not from `tools/bin/`.
  `setup_env.sh` installs the addon files under a repo-local
  `tools/bin/blender_scripts/addons/SourceIO/`, but *registers* that
  directory as an extra Blender script-search root and *enables* the addon
  via `bpy.context.preferences` + `save_userpref()`, which Blender persists
  into the home-dir `userpref.blend` — not into anything tracked or
  gitignored inside the repo. **Practical consequence: on a brand-new
  machine, or after wiping `~/.config/blender/`, tier-c conversions
  (`tools/convert_mdl.py`) will fail with `ModuleNotFoundError: No module
  named 'SourceIO'` until `tools/setup_env.sh` is run again — the script
  self-heals this every time it runs (its SourceIO block is idempotent: it
  skips the download if the addon directory already exists, but always
  re-runs the enable + script-path-registration + `save_userpref()` steps).**
  Treat `bash tools/setup_env.sh` as the mandatory bootstrap step on *any*
  new machine or fresh checkout, even if `tools/bin/` already looks
  populated — it's cheap (near-instant if already installed) and is the only
  thing that reliably re-establishes SourceIO's enabled state.
- **Blender exits 0 even when a `--python-expr` raises**, so `set -euo
  pipefail` cannot see a failed addon-enable on its own. The SourceIO block
  therefore captures Blender's output and gates on the literal `SOURCEIO_OK`
  marker before `toolchain ready` is printed; a failed enable now exits 1 with
  `ERROR: SourceIO enable failed`. It also rewrites the registered script
  directory *unconditionally* rather than only creating it when absent — the
  entry is keyed by name, so a `userpref.blend` inherited from a moved,
  renamed, or second checkout would otherwise keep a stale path forever. Both
  of these are load-bearing for the self-healing claim above; don't
  "simplify" either away.

Verify: `tools/bin/godot --version` prints `4.5.2.stable.official....`;
`tools/bin/blender/blender --version` prints `Blender 4.2.23 LTS`.

---

## 2. Folder conventions

```
assets_raw/<source>/            # downloaded, unmodified source packs (gitignored)
  blender-native/<Character>_<ver>/...   # tier a: CreatorOfPony/MythicSpeed .blend packs
  sfm/...                                # tier c: SFM/GMod .mdl compiled packs
  props/<pack-slug>/...                   # tier b: Kenney CC0 glTF/FBX prop packs

game/assets/converted/<kind>/   # pipeline output, gitignored (regenerated from assets_raw/)
  ponies/<name>.glb             # tier a only -- the playable character set
  props/<name>.glb              # tier b
  probe/<name>.glb              # tier c probe output, deliberately NOT in ponies/

game/assets/audio/voice/<character>/<category>_<nn>.wav   # committed (small, hand-picked)
```

**`ponies/` holds tier-a characters only.** It is what
`scenes/test/model_gallery.gd` globs (so anything dropped there inflates
`GALLERY_OK count=`) and what §3's validation loop sweeps *with
`--require-anims`* (so anything animation-less there fails the loop). The
tier-c probe ships zero animations and is a probe, not a character, hence the
separate `probe/` folder — see §5.

`assets_raw/` and `game/assets/converted/` are both gitignored — nothing in
either tree is committed. This means **a fresh clone has no converted
assets**; the conversion commands in this doc must be re-run against a
locally re-downloaded `assets_raw/` to regenerate `game/assets/converted/`.
Only the scripts (`tools/`), this doc, the export presets, and the one
hand-picked voice line are committed.

---

## 3. Tier a recipe — `.blend` → glTF (native Blender packs)

**Source:** CreatorOfPony/MythicSpeed Mane 6 Blender packs (see
`docs/shopping-list.md` §1). Verified with Twilight Sparkle, Rainbow Dash,
and Fluttershy; Applejack and Rarity are downloaded but not yet converted.

**Pack inspection first**, to find the object/armature names before writing
any `--object` invocation:

```bash
tools/bin/blender/blender -b assets_raw/blender-native/TwilightSparkle_1-0/TwilightSparkle_1-0.blend \
  --python-expr "import bpy; print(sorted(o.name for o in bpy.data.objects))"
```

Each pack is one self-contained scene: a camera, four background planes, a
set of unparented `BS_*` blendshape-driver helper meshes (used only by a
`Rig.py` init script that Blender disables headlessly — harmless to ignore),
and the actual character parented under one root armature: `TS_Rig`
(Twilight), `RD_Rig` (Rainbow Dash), `FS_Rig` (Fluttershy).

**Conversion** — `tools/export_blend.py`, one Blender process per character:

```bash
mkdir -p game/assets/converted/ponies

tools/bin/blender/blender -b assets_raw/blender-native/TwilightSparkle_1-0/TwilightSparkle_1-0.blend \
  -P tools/export_blend.py -- --out game/assets/converted/ponies/twilight.glb --object TS_Rig --anims --rotate-z 180 --scale 0.5

tools/bin/blender/blender -b assets_raw/blender-native/RainbowDash_1-1/RainbowDash4.blend \
  -P tools/export_blend.py -- --out game/assets/converted/ponies/rainbowdash.glb --object RD_Rig --anims --rotate-z 180 --scale 0.5

tools/bin/blender/blender -b assets_raw/blender-native/Fluttershy_1-0/Fluttershy_1-0.blend \
  -P tools/export_blend.py -- --out game/assets/converted/ponies/fluttershy.glb --object FS_Rig --anims --rotate-z 180 --scale 0.5
```

`--object <Rig>` selects exactly the character (the script walks
`children_recursive`, which naturally pulls in the hair mesh hanging off a
secondary `*_RigPhysics` armature and naturally excludes the camera,
background planes, and unparented `BS_*` helpers). `--anims` authors the
`idle` + `walk` + `gallop` clips onto the rig before export (§5). `--rotate-z 180` fixes a
facing-direction quirk (§5). `--scale 0.5` normalizes the model to metric
scale — see immediately below; it is **mandatory for every new character**.
Omit `--anims`/`--rotate-z` for a static, unanimated export (e.g. for a prop
or a quick structural check) — but keep `--scale`.

Each invocation prints a per-material resolution log line, then
`SCALED factor=0.5 …`, `METRIC_RIG_OK height=2.0525`,
`WALK_IMPLIED_SPEED 0.6600 m/s …`, `GALLOP_IMPLIED_SPEED 3.3000 m/s …`,
`ANIMS_AUTHORED ['idle', 'walk', 'gallop']` (all four only if `--anims`), then
`EXPORT_OK <path>`. The two `*_IMPLIED_SPEED` lines are the authoritative values
for `game/systems/gait.gd`'s `WALK_CLIP_SPEED` / `GALLOP_CLIP_SPEED` — compare
them whenever a clip is retuned.

### Model scale — 1 unit = 1 metre, and `--scale` is how you get there

**Settled decision (Phase 1A task 1).** One Godot unit is one metre,
everywhere: assets, maps, physics, animation constants. The CreatorOfPony
packs are authored at roughly twice that, so every tier-a character is
exported with **`--scale 0.5`**.

How the factor was chosen — measured, not assumed. The withers (top of the
back above the shoulder joint, the conventional way to state a horse's
height) is the reference, because the bounding box of these models is
dominated by a raised head, ears, horn and mane rather than by the body:

| | pack units | at `--scale 0.5` |
|---|---|---|
| Twilight, withers | 2.326 | **1.163 m** |
| Twilight, bounding box (hoof → horn tip) | 4.276 | 2.138 m |
| Rainbow Dash / Fluttershy, withers | 2.326 / 2.343 | 1.163 / 1.171 m |
| front leg chain (shoulder → hoof) | 1.067 | 0.533 m |
| rig extent, hoof plane → highest bone | 4.105 | 2.053 m |

A show pony is small — 1.16 m at the withers is ~11.5 hands, a real (small)
pony — and `0.5` lands there within 3% while being *exactly* representable in
binary, so the rescale is an exponent shift rather than a rounding: verified
by decoding both exports, every vertex position and node translation in the
scaled `.glb` is the unscaled one halved to within 3.5e-6, and the inverse
bind matrices to within 2.2e-5. Note the model's bounding box is **1.84× its
withers height** (cartoon proportions), so "how tall is the pony" has two very
different answers; world geometry has to clear 2.14 m, not 1.16 m.

`--scale` bakes the factor into the geometry and the rig — it does *not* leave
a scaled root node — so the `.glb`'s internal units are metres too: bone
rests, animation translations and anything a consumer reads out of
`Skeleton3D`. `tools/export_blend.py`'s `apply_uniform_scale()` documents
which stored lengths (CHILD\_OF inverse matrices, `STRETCH_TO` rest lengths,
shrinkwrap offsets) have to be scaled by hand because they do not follow the
geometry, and hard-fails if the exported selection's bounding box did not
scale by exactly the requested factor.

**Two consequences to know about.**

- `tools/author_anims.py`'s length constants (`STRIDE`, `LIFT`, `BODY_BOB`,
  `BODY_CROUCH`, `IDLE_*`) are **metres**, and `--scale` runs *before*
  authoring so the clips are solved against the normalised rig.
  `author_anims._require_metric_rig()` refuses to author onto a rig outside
  0.5–3.0 units tall rather than silently baking a stride the model does not
  have. Forgetting `--scale` is therefore a loud failure, not a subtle one.

  **⚠ This is a deliberate breaking change to an old command line.**
  `--anims` *without* `--scale` used to work and now aborts with exit 1 and an
  explanation. That is not the guard being fussy — it is the guard reporting a
  breakage that already existed. Once `STRIDE` became metric, that combination
  stopped being able to reproduce its previous output at all: measured, it
  emits a pack-scale (4.10-unit) rig whose IK hoof targets travel **0.275 per
  stride instead of 0.55** — half the stride the legs want, i.e. the "mincing
  shuffle" `author_anims.py` describes as its rejected first pass — while
  printing `WALK_IMPLIED_SPEED 0.66 m/s`, which a consumer scene would then
  match and get 2× foot skate. The choice was between failing loudly and
  shipping that silently. Geometry-only exports (no `--anims`) are unaffected
  and remain byte-identical without `--scale`.
- The mane/tail spring simulation needed **no re-tuning**:
  `PonyRig.PROFILES` expresses stiffness and gravity per unit of bone length,
  which makes the whole solve scale-invariant. Confirmed by measurement —
  after the rescale `hair_lag_test` reports every chain's trail identical to
  the tick and every displacement column exactly halved. See
  `docs/notes-hair-sim.md` §9.

### Per-pack quirks (fixed generically inside `export_blend.py`, not by hand)

| # | Quirk | Symptom if unfixed | Fix |
|---|---|---|---|
| 1 | **No Principled BSDF anywhere.** All packs are 2015-era Blender Internal files opened in 4.2; materials use hand-built Diffuse/Glossy/Fresnel/Velvet mix-shader graphs. The glTF exporter only recognizes a Principled BSDF wired directly into `Material Output`. | Every material exports `textured=False` even though images are present and UV-mapped. | `rebuild_materials_for_gltf()` walks backward from `Material Output`'s Surface socket through shader mixers to the real color-bearing shader (preferring Diffuse/Principled over Glossy/Sheen/Fresnel rim helpers), resolves its color through `Mix`/color-filter/node-group chains, and wires a fresh Principled BSDF from that. Runs generically over every material, no per-character special-casing. |
| 2 | **Decal composites read as base color.** Twilight's body has *no* body texture at all — only `Eye.png` and `TS_CutieMark.png` exist. `Base_Body` is a solid lavender RGB with the cutie mark alpha-composited on top via a `Mix` node. | Taking "the first Image Texture node" as base color makes the cutie-mark decal (mostly-transparent alpha) the entire body's color *and* alpha — the pony exports **almost entirely invisible** (only mane/tail/eyes/a floating cutie mark render). This passed every structural gate (`meshes>0 skins>0 textured=True`) undetected until a rendered frame was inspected. | Resolving through a `Mix` always takes the *underneath* (`A`/`Color1`) layer as the surface color, and alpha is wired **only** when an image is the *direct*, un-mixed base color (true for eye textures, where transparency is real). Materials with no wired alpha are forced `blend_method=OPAQUE` (every material in these files arrives `HASHED` from the 2015→4.2 conversion, which the exporter turns into blended `alphaMode` for geometry meant to be solid). |
| 3 | **Node-group materials** (`Hair_*`) carry their color in an unlinked node-group input, not a top-level Diffuse/Emission node. | Old fallback found nothing and defaulted to flat 0.8 grey — mane/tail render off-white instead of their real color. | Color resolution descends into `GROUP` nodes and reads the matching `RGBA` input socket's default value. |
| 4 | **Body meshes are viewport-selection-locked** (`hide_select=True`, the outliner's "Disable Selection" toggle — set so animators can't accidentally drag a mesh instead of a bone). | `obj.select_set(True)` silently no-ops on a `hide_select` object (no exception) — export selects only the armature, `meshes=0`. | Script clears `hide_select = False` on every object it intends to export, before selecting. Safe: the `.blend` is never saved back to disk. |
| 5 | **Loose (unpacked) texture PNGs** sit next to the `.blend` rather than packed into it. | Not actually broken (Blender resolves relative paths regardless of cwd) — a resilience measure, not a bug. | `bpy.ops.file.pack_all()` runs before export to remove any path ambiguity and make the export self-contained. |
| 6 | Applejack's pack ships with viewport "simplify" mode on. | Cosmetic only — `export_apply=True` exports against the depsgraph, not simplified viewport display. Not exercised (Applejack unconverted this run) but documented as harmless per the source pack's own notes. | No fix needed. |

| 7 | **The iris is shrinkwrapped onto an eyeball that is not the one we export.** Each eye is four objects — `Base_Eye.*` (the white, SUBSURF 2), `Base_Iris.*` and two `Base_EyeHighlight*.*` — with the caps floated off the white by a SHRINKWRAP in PROJECT/ABOVE_SURFACE mode. The iris's shrinkwrap carries `subsurf_levels=2`, i.e. it conforms to a level-**four** eyeball while the level-two one is what ships. | The sclera tears through the upper rim of every iris: a stable, sawtoothed white/colour boundary, worst on Fluttershy, present on all three packs. This is what the owner's first playtest called "eyes weird" / "eyes also a bit funny?". Nothing structural sees it — `materials=13 textured=True` is as green as ever. | `conform_shrinkwraps_to_exported_surface()` forces every shrinkwrap's `subsurf_levels` to 0 and multiplies **all** of the export's shrinkwrap offsets by one common factor, enough that the smallest clears 0.5% of its target's size. One factor rather than a per-modifier floor, because the caps are stacked (iris 0.0015, highlights 0.0020) and flattening them to the same value just moves the tearing up a layer. Measured on the shipped `.glb`, nearest-vertex signed distance along the sclera normal: iris `-0.00037 → +0.00161 m` minimum, `14 → 0` vertices inside the white; highlight-vs-iris `-0.00002 → +0.00060 m`, `3 → 0` inside. |

**Fixed (was: known limitation).** glTF cannot express a color-plus-decal mix in
one material, so the exported body used to keep its flat base color and **lose the
cutie mark**. That was carried as a fidelity regression awaiting a Cycles bake.

It never needed a bake. The decal is sampled through the mesh's own active UV map,
exactly as a body texture would be, so compositing the two layers in UV space is the
same operation the shader performs per pixel, done once and stored:
`_bake_decal_over_solid()` in `tools/export_blend.py` flattens
`Mix(Factor=Decal.Alpha, A=solid RGB, B=Decal.Color)` into a single opaque image and
wires that in as base color. No render, no bake settings, no lighting to get wrong.

It is generic rather than per character: any material shaped as a flat color with an
alpha decal over it flattens the same way, and a material of any other shape falls
through to the previous behaviour untouched. The decal's alpha stays a MASK and is
never wired to material alpha, which is the distinction that once exported these
ponies as a floating cutie mark and nothing else. Verified by rendering all three
flanks: Twilight's starburst, Rainbow Dash's lightning bolt and Fluttershy's
butterflies are all present, with the SFM ponies (whose marks are painted into the
body texture) unaffected as a control. Baked sizes are 3000x3850, 1600x2343 and
1024x1024 respectively, and `validate_gltf.py` reports the same
`meshes/skins/materials` counts as before.

One trap worth recording, because it cost a debugging round. The factor check compares
`from_node.as_pointer() == decal_tex.as_pointer()`, not `from_node is decal_tex`. Every
attribute access on a bpy collection builds a fresh Python wrapper around the same
underlying RNA data, so `is` is False even when both names refer to the identical node,
and the bake silently took its bail-out path on every character.

### Validation

```bash
for f in game/assets/converted/ponies/*.glb; do
  python3 tools/validate_gltf.py "$f" --require-anims || echo "FAILED: $f"
done
```

Expected, one line per pony:

```
meshes=17 skins=1 materials=13 textured=True animations=['gallop', 'idle', 'walk']   # twilight
meshes=16 skins=1 materials=16 textured=True animations=['gallop', 'idle', 'walk']   # rainbowdash
meshes=15 skins=1 materials=11 textured=True animations=['gallop', 'idle', 'walk']   # fluttershy
```

(Drop `--require-anims` for a plain structural export with no `--anims`
flag — those correctly report `animations=[]` and still pass the base
`meshes>=1 skins>=1` gate.)

The loop above sweeps `ponies/*.glb` and expects **every character named in
`tools/roster_manifest.txt`**: keep tier-b props in `props/` and the tier-c
probe in `probe/` (§2), or this loop fails on them. `validate_gltf.py` parses its arguments with
argparse: a mistyped flag (e.g. `--require-anim`, singular) is a hard error
rather than being silently ignored, which used to turn the animation gate off
without any visible sign.

---

## 4. Tier b recipe — glTF/FBX props (Kenney)

**Status: exercised for real (Task 8).** The original plan sourced this
tier from Sketchfab, but those specific downloads sit behind a login wall
with no anonymous/direct path — a controller ruling redirected Task 8 to
login-free CC0 packs instead. **Source:** Kenney.nl (CC0), fetched with a
plain `curl -A "<browser UA>"` (no login, no API key):

- [Fantasy Town Kit 2.0](https://kenney.nl/assets/fantasy-town-kit) —
  `windmill.glb`, `watermill.glb`, `stall-red.glb` (buildings/structures).
- [Nature Kit 2.1](https://kenney.nl/assets/nature-kit) — `tree_oak.glb`,
  `tree_pineTallA.glb`, `tree_default.glb`, `tree_fat.glb`.
- [Survival Kit 2.0](https://kenney.nl/assets/survival-kit) —
  `structure.fbx` (taken through the FBX path deliberately, to exercise
  that branch; every other prop here had a ready-made GLB).

All saved into `assets_raw/props/kenney-<pack>/`.

**glTF/GLB downloads** — copy straight into
`game/assets/converted/props/<name>.glb`, no Blender round-trip:

```bash
cp "assets_raw/props/kenney-fantasy-town-kit/extracted/Models/GLB format/windmill.glb" \
   game/assets/converted/props/kenney_windmill.glb
# ...and so on for watermill.glb, stall-red.glb, the four tree_*.glb files
```

**FBX downloads** — `tools/export_blend.py` gained an additive `--fbx-in`
flag (existing `--object`/`--anims`/`--rotate-z` callers, and the plain
`blender -b file.blend -P export_blend.py --` invocation, are unaffected):

```bash
tools/bin/blender/blender -b -P tools/export_blend.py -- \
  --fbx-in "assets_raw/props/kenney-survival-kit/extracted/Models/FBX format/structure.fbx" \
  --out game/assets/converted/props/kenney_survival_structure.glb
```

**Validate** — `tools/validate_gltf.py` gained an additive `--props` flag:
gates on `meshes>=1` only (no skin required), instead of the character
gate's `meshes>=1 and skins>=1`. Existing calls (`validate_gltf.py file.glb`
and `--require-anims`) are unchanged.

```bash
for f in game/assets/converted/props/*.glb; do
  python3 tools/validate_gltf.py "$f" --props
done
```

All 8 pass: `meshes=1 skins=0 ... textured=True` for the 4 buildings/GLB
props (windmill, watermill, stall, the FBX-converted structure); the 4
Nature Kit trees report `textured=False` **by design**, not a defect — that
pack ships flat named materials (`leafsGreen`, `woodBark`, solid
`baseColorFactor`, no image) rather than a colormap texture.

### Quirks discovered running this for real

| # | Quirk | Symptom if unfixed | Fix |
|---|---|---|---|
| 1 | **Kenney's own "GLB" files aren't fully self-contained.** `windmill.glb`, `watermill.glb`, and `stall-red.glb` reference their shared atlas via an external `"uri":"Textures/colormap.png"` image entry rather than embedding it in the binary chunk — unusual for a `.glb`, but that's what these ship. | Importing the bare `.glb` alone leaves every building textureless (`ERROR: Can't open file from path '.../Textures/colormap.png'`, silently falls back to grey/white — no crash, no failed validator, just a flat-shaded box). | Copy the pack's `Models/GLB format/Textures/colormap.png` alongside the copied `.glb`s, into `game/assets/converted/props/Textures/colormap.png`, before the Godot editor import pass. |
| 2 | **Godot's importer doesn't retroactively notice a newly-added dependency.** Running the editor import pass *before* `Textures/colormap.png` existed baked a texture-less import for the three affected `.glb`s into `.godot/imported/`; adding the PNG afterward and re-running the editor pass did **not** relink them — their `.import` mtime hadn't changed, so Godot skipped reimporting them. | Buildings render flat grey/white even though the texture file is now present on disk and imports cleanly on its own. | Delete the affected `.glb.import` files (forces a fresh import) before rerunning the editor pass, once every referenced texture is actually in place. Order matters: get all dependent files present *first*, then do the one editor pass. |
| 3 | **`blender -b` with no `.blend` argument opens Blender's default startup scene** (a Cube + Camera + Light), not an empty one — relevant only to the new `--fbx-in` path, which by design runs with no `.blend`. Exporting afterward with no `--object` filter (`use_selection=False`) included that leftover default Cube alongside the real imported prop. | `kenney_survival_structure.glb` silently came out with **two** meshes: an untextured 2×2×2 "Cube" plus the real "structure" mesh. This passed `validate_gltf.py --props` (`meshes>=1`) without complaint — only a rendered frame showed a flat grey box sitting on top of the real prop. | `export_blend.py`'s `--fbx-in` handling now snapshots `bpy.data.objects` before import and deletes exactly that snapshot's objects afterward, so only what the FBX import actually added survives to export. Safe because this `.blend` is never saved back to disk. |
| 4 | **FBX unit conversion is not reliable for this pack.** The same `structure` model exists as both a Kenney-authored `.glb` (already correctly scaled to the pack's 2-unit module grid: `2×2×2`) and an `.fbx` (imported via Blender's automatic cm→m unit conversion). After quirk 3's fix, the FBX path's `structure` mesh measures **0.5 units tall in Godot — 4× smaller** than the GLB sibling's 2.0. | A prop converted via the FBX path can silently land at the wrong scale relative to the same pack's other (GLB-sourced) props, with no validator check catching it (structural gates don't know what size is "correct"). | Not fixed in-place (documented, not patched, per this doc's own "record quirks, don't paper over them" convention) — kept as `kenney_survival_structure.glb` at its native (undersized) scale. **Recommendation:** prefer the direct-GLB path whenever a pack offers one; if only FBX is available, sanity-check the imported scale against a known reference (another model from the same pack, or the pack's own stated grid unit) rather than trusting Blender's automatic FBX unit conversion. |
| 5 | **Three of the four "buildings" in this set are not buildings.** Discovered in Phase 1A task 7, the first time any of them was rendered from ground level rather than measured. `kenney_windmill.glb` is the Fantasy Town Kit's SAILS module -- a bare X of blades, no tower behind it. `kenney_watermill.glb` is a bare waterwheel, no mill. `kenney_survival_structure.glb` is an open timber frame. Only `kenney_market_stall.glb` is a complete object. These kits are MODULAR: their houses are assembled from wall/roof/door pieces, and the files whose names sound like buildings are the decorative attachments. | A homestead composed from them reads as farm equipment abandoned in a field. Nothing structural notices: they import, they validate (`meshes>=1`), they measure a plausible height, and they collide. The §4 scale table above lists windmill and watermill under "buildings/structures" purely on the strength of those numbers. | Not fixed at the asset level (task 7 was scoped away from `game/assets/`). The ranch's actual barn and farmhouse are assembled from primitives in `game/world/building.gd`, and the Kenney pieces are placed as yard fixtures. **The real fix is an asset task:** convert the Fantasy Town Kit's wall / roof / door / window modules and assemble a house from them, or find a pack that ships whole buildings. Until then, look at a prop before trusting its filename. |
| 6 | **The Nature Kit trees render cyan/mint, not green — and it is NOT the terrain's `vertex_color_is_srgb` bug repeating.** Checked in the Task 7 fix round after a reviewer flagged the colour from a render. The trees carry no vertex colours at all (`COLOR_0` absent from every mesh primitive) — their colour comes entirely from each material's glTF `baseColorFactor`, a completely different code path from `terrain.gd`'s hand-rolled vertex-colour mesh. `leafsGreen`'s factor is `[0.161, 0.788, 0.671]`: byte-identical, confirmed by diffing the converted `.glb` against the untouched file straight out of Kenney's own `kenney_nature-kit.zip` (`assets_raw/props/kenney-nature-kit/`) — nothing in this project's pipeline altered it. That RGB triple's hue is ~169° (cyan/teal) whether read as linear (glTF's own convention) or converted to sRGB for display (~172°) — it is a teal swatch by construction, not an artefact of which colour space you read it in. | None — a render shows real cyan/mint foliage, exactly as a reviewer described it, but it is Kenney's authored "leafsGreen"/"leafsDark" swatch, not a bug. | **Not fixed — this is Kenney's shipped palette, left as-is per this doc's "record quirks, don't paper over them" convention.** Confirmed visually in the same `xvfb-run` + llvmpipe render pass used for the tree-scale fix above (`05_scale_at_the_barn.png` and the establishing shot). If a future task wants true green foliage, the fix is sourcing a different tree pack or hand-editing the material colour at map-build time (`game/world/props.gd`), not chasing a colour-space bug that was checked for and ruled out here. |

### Scale finding — props vs. the converted ponies

Measured in Godot (world-space AABB height, native/as-imported prop scale, no
manual correction applied). **The pony column has moved**: since Phase 1A task
1 the ponies ship metric (§3), so Twilight is 2.14 m tall / 1.16 m at the
withers rather than the 4.28 units these props were originally judged against.
Prop heights themselves are unchanged — nothing was re-sourced or re-scaled.

| Prop | Height (units) | vs. Twilight's 2.14 m box | vs. her 1.16 m withers |
|---|---|---|---|
| Twilight (`twilight.glb`) | 2.14 | — | — |
| `kenney_windmill.glb` | 3.11 | 146% | 268% |
| `kenney_watermill.glb` | 1.80 | 84% | 155% |
| `kenney_survival_structure.glb` | 0.50 | 23% | 43% (see quirk 4) |
| `kenney_market_stall.glb` | 1.24 | 58% | 106% |
| `kenney_tree_default.glb` | 1.71 | 80% | 147% |
| `kenney_tree_pine.glb` | 1.53 | 72% | 132% |
| `kenney_tree_oak.glb` | 1.23 | 57% | 105% |
| `kenney_tree_fat.glb` | 1.15 | 54% | 99% |

Task 8's original finding — every prop, trees included, shorter than the pony —
was confirmed visually via an `xvfb-run` + llvmpipe offscreen capture of
`terrain_probe.tscn`, and it identified the pony rigs as the side that was
wrong: Kenney's kits are built on a real-world-metre module grid (their
standard wall/door piece is a 2-unit cube, i.e. ~2 m, sane for a human-scale
doorway). Task 1 fixed the pony side, which is why the ratios above are no
longer absurd — but they are still not right. A market stall the same height
as the pony's withers, and trees she can look over, still read as a toy
village.

**Recommended prop factor for the Phase 1A map-build task: `1.5×`.** That is
exactly Task 8's validated `3.0×` carried through the pony rescale (`3.0 ×
2.138 / 4.276 = 1.5`), so it reproduces the prop/pony relationship that was
already judged to read sensibly on screen — windmill 4.67 m, watermill 2.70 m,
trees 1.73–2.56 m, market stall 1.86 m against a 2.14 m pony. It is a
map-build-time multiplier on imported world geometry, not a change to any
shipped asset. Two things to weigh before committing to it:

- **`1.0×` is the "trust Kenney's grid" answer** and it is not crazy — the
  kits claim metre-scale — but it makes the stall (1.24 m) shorter than the
  pony's withers and every tree shorter than she is, which is the same failure
  Task 8 rejected. The kits are stylised small, not metric.
- **Doorways must clear 2.14 m, not 1.16 m.** These models are 1.84× taller at
  the ear/horn tip than at the withers, so anything sized off "how tall is a
  pony" against the withers figure will be too short to walk through. At
  `1.5×` a Kenney 2-unit door module becomes 3 m, which clears comfortably.

Re-render `terrain_probe.tscn` with `-- --prop-scale=1.5` before settling it;
the probe takes the factor on the command line precisely so this call can be
made from a picture rather than a table.

**Task 7 applied 1.5× as written, and the map it produced flags one open
question about it.** Everything derived above holds for the built objects: the
market stall at 1.86 m next to a 2.14 m pony reads correctly, and the ranch's
own hand-built barn (4.9 m to the ridge, `game/world/building.gd`) was
deliberately sized into the same family. **The trees are the part that still
looks wrong.** At 1.5× the Nature Kit trees stand 1.7–3.2 m, i.e. from
shoulder-height on a pony to a little over her horn tip, and next to the barn
they read as saplings or shrubs rather than trees — visible in the task-7
renders (the establishing shot and the spawn-zone shot especially, where a tree
and a pony are the same height). Task 7 did **not** override the factor, on the
grounds that 1.5× is a validated number and a map-build task should not quietly
re-derive one. The recommendation for whoever picks this up: keep 1.5× as the
kit-wide factor and add a **tree-category multiplier of roughly 2×** on top
(giving 3.5–6.5 m trees), or source a taller tree model. Either way it is a
decision to make from the pictures, deliberately, and to record here.

**RESOLVED, in the Task 7 fix round: `TREE_SCALE = 3.0`, not 2×.** Rendered
against a render at 2× first (on paper, from the numbers above): a 2× oak still
tops out around 4.3 m, below the barn's 4.9 m ridge and not far above its 3.4 m
eave, i.e. still reads as undersized next to the building even though it now
clears a pony. 3× was rendered instead (`xvfb-run` + llvmpipe,
`05_scale_at_the_barn.png`) and reads correctly: the oak beside the barn now
rises well past the ridge line, and every tree in the establishing/eye-level
shots stands taller than the buildings and multiple pony-heights tall rather
than level with one. See `game/world/props.gd`'s `TREE_SCALE` constant, applied
on top of `BASE_SCALE` for every `kenney_tree_*` layout entry only — the
yard fixtures and buildings are unaffected and still read correctly at 1.5×
alone.

**Kenney prop origins are not consistent, so seat props by their bounding box.**
`kenney_survival_structure` and `kenney_market_stall` have their origin at the
base; `kenney_windmill` and `kenney_watermill` have theirs at the model's
CENTRE. Placing every prop at `y = ground` therefore buried the windmill 2.34 m
and the watermill 1.35 m — exactly half their height each — while leaving the
other two correct, which looks like a layout mistake and is not one.
`game/world/props.gd` seats each prop by measuring its world AABB and shifting
it until its floor meets the terrain; do that rather than typing per-prop `y`
offsets.

### Task 8 verdict — props-on-Godot-terrain viability

*(Task 8's verdict below predates the pony rescale; its "recommend ~3×" is
superseded by the `1.5×` above, which is the same visual relationship measured
against the metric ponies. Everything else it says still stands.)*

**Viable for Phase 1, with two caveats to carry forward.** Kenney's CC0
kits convert cleanly through both the direct-GLB and FBX-via-Blender
paths (`export_blend.py --fbx-in`, additive), validate structurally
(`validate_gltf.py --props`), import into Godot without incident once
their external textures are copied alongside them, and render with real
textures and a low-poly cartoon look that suits this project. The
`terrain_probe.tscn` gate (`PROBE_OK count=8`, exit 0) passes comfortably
above the `count>=3` bar. Caveats: (1) the pony/prop scale mismatch is
real and must be resolved with a deliberate map-build-time scale factor
(recommend ~3×, see above) — not a blocker, but a decision Phase 1 must
make explicitly rather than inherit by accident; (2) FBX-sourced props
need a manual scale sanity-check against a same-pack reference, since
Blender's automatic unit conversion is not trustworthy on its own (quirk 4).

---

## 5. Tier c recipe — SourceIO `.mdl` (SFM/GMod compiled models)

**Source:** SFM "SFM Ready Compiled Files" pack (`revamped-sfw-ponies`, see
`docs/shopping-list.md` §2), saved into `assets_raw/sfm/`.

**Prerequisite:** SourceIO must be enabled — this is handled automatically
by `tools/setup_env.sh` every run (§1). If you see
`ModuleNotFoundError: No module named 'SourceIO'`, re-run
`bash tools/setup_env.sh` before anything else.

**Conversion** — `tools/convert_mdl.py`:

```bash
mkdir -p game/assets/converted/probe

tools/bin/blender/blender -b -P tools/convert_mdl.py -- \
  --mdl "assets_raw/sfm/SFM Ready Compiled Files/Models/reVAmped_ponies/revamped_maudpie.mdl" \
  --out game/assets/converted/probe/sfm_probe.glb
# -> MDL_EXPORT_OK game/assets/converted/probe/sfm_probe.glb

python3 tools/validate_gltf.py game/assets/converted/probe/sfm_probe.glb
# -> meshes=14 skins=1 materials=12 textured=True animations=[]
```

**This probe's output goes to `probe/`, not `ponies/`** (§2): `convert_mdl.py`
authors no animations, so its `.glb` sitting in `ponies/` makes §3's
`--require-anims` validation loop print `VALIDATION FAILED` when run verbatim,
and inflates `model_gallery.tscn`'s `GALLERY_OK count=`. A tier-c model
promoted through **§5b** does ship clips and does belong in `ponies/`.
Note also that `convert_mdl.py` applies neither `rebuild_materials_for_gltf()`
(unneeded — SourceIO already emits Principled BSDFs) nor `--rotate-z 180`, so
the probe faces backwards relative to the tier-a ponies; harmless for a
structural probe, but any tier-c model promoted to a real character needs that
yaw baked in (§6).

### Quirks discovered

- `bpy.ops.sourceio.mdl` does **not** take `filepath=` — on Blender 4.1+ its
  `execute()` reads `self.directory` + `self.files` (a list of
  `{"name": ...}` dicts). Passing only `filepath=` leaves `self.directory`
  empty and the import silently finds nothing. Correct call:
  `bpy.ops.sourceio.mdl(directory=mdl_dir, files=[{"name": mdl_name}])`.
- **No manual Source-inch-to-meter scale step is needed.** SourceIO 5.5.4
  bakes the unit conversion into vertex data on import — `object.scale`
  stays `(1,1,1)` and dimensions come out already in a sane meters range.
  Adding the classically-suggested extra `0.0254` scale-and-apply step would
  make the model **40x too small**; this was confirmed by computing what
  that step would have produced, not assumed.
- Materials/textures resolve automatically — SourceIO's `ContentManager`
  finds the sibling `Materials/` tree next to `Models/` with no manual
  content-root configuration, even across a folder-case mismatch
  (`models\VA_MLP\maudpie\` in the `.mdl` vs `VA_MLP/MaudPie` on disk).
- **A single `.mdl` imports every bodygroup variant** (alternate
  ears/hooves/heads) as separate objects in one scene. Picking the
  "canonical" combination per pony is manual work this script does not
  automate.

### Task 6 verdict — bulk viability

**Tier c is viable, with real per-model manual work, and is NOT proven at
catalog scale.** The probe succeeded end-to-end on one curated, ~20-pony,
single-author, consistently-packaged set (72-bone rigged+textured result,
independently verified beyond the validator: real accessor bounds, decoded
2048×2048 PBR-ish textures, vertex-group-backed skin data). It says nothing
about the wider 1,000+ PonySFM catalog, which is crowd-sourced with
inconsistent packaging quality.

**Recommendation for Phase 2 (and beyond): default the roster to tiers a/b;
use tier c opportunistically for specific well-packaged SFM downloads (like
this reVAmped set) when a needed character isn't available in a/b.** Do not
plan roster breadth on the unaudited PonySFM catalog sight-unseen.

Like tier a, tier c ships zero baked animations, and it shares zero bone names
with tier a (`Pelvis`, `Chest1`, `Head`, ... vs `DEF_Chest1`, `DEF_Head`, ...).
Neither of those turned out to require a bone-name remap: **§5b** is the path
that promotes a tier-c model to a playable, animated character, and it takes
the third option — build tier a's animation interface onto the Source rig and
let the existing clip authoring solve against it.

---

## 5b. Tier c, promoted — an SFM pony that walks

§5 converts a Source `.mdl` to a structural probe. This section is how one
becomes a playable character, and it is the path
`game/data/ponies/{pinkiepie,derpyhooves,starlightglimmer}.tres` point at.

```bash
SRC="assets_raw/sfm/SFM Ready Compiled Files/Models/reVAmped_ponies"

tools/bin/blender/blender -b -P tools/export_blend.py -- \
  --mdl-in "$SRC/revamped_pinkiepie.mdl" \
  --out game/assets/converted/ponies/pinkiepie.glb \
  --anims --rotate-z 180 --scale 2.0

python3 tools/validate_gltf.py game/assets/converted/ponies/pinkiepie.glb --require-anims
# -> meshes=8 skins=1 materials=9 textured=True animations=['gallop', 'idle', 'walk']
```

The character name is the only thing that changes between models. `--scale
2.0` (not tier a's 0.5 — the SFM pack is authored at roughly half life size,
§3), and `--rotate-z 180` for the same reason tier a needs it.

#### The roster manifest

The two commands above convert **one** character. `tools/roster_manifest.txt` names
every character in the game, one line of `id|kind|source|rig`, and
`tools/convert_roster.sh` runs exactly those two commands over the list:
`tools/export_blend.py` for the export, `tools/validate_gltf.py --require-anims` for
the check. `kind` selects the invocation, `blend` (tier a: `--object <rig>`,
`--scale 0.5`, §3) or `sfm` (tier c: `--mdl-in`, `--scale 2.0`, above), so adding a
character is one manifest line and nothing else. The six already shipped characters
are listed too, so the manifest describes the whole game and not just the newest
batch.

One character failing does not stop the others. Each export's Blender output goes to
`${TMPDIR:-/tmp}/convert_<id>.log`, a failure prints `FAILED <id>` naming that log and
removes the half written `.glb`, and the last line is the tally, which is also the
exit code:

```bash
bash tools/convert_roster.sh
# -> CONVERTED applejack
# ...one line per character...
# -> ROSTER_CONVERT ok=37 failed=0 skipped=6   exit 0
```

That is the whole regeneration step: once `tools/setup_env.sh` has fetched Blender and
the asset packs (§1), one run rebuilds every `.glb` under
`game/assets/converted/ponies/`. `game/assets/converted/` is entirely gitignored, so on
an actual fresh clone none of the manifest's 43 entries has a `.glb` yet: all 43
convert, and the tally reads `ROSTER_CONVERT ok=43 failed=0 skipped=0`, proportionally
longer than the run measured below (roughly 16 minutes at the same per-character rate,
not separately timed). The tally shown above was measured in a worktree that already
held the six previously shipped characters' `.glb` files, hence `ok=37 failed=0
skipped=6`, about 14 minutes for the 37 newly-converted characters. Either way, a
character that already has a `.glb` is skipped, so a re-run once everything exists is
cheap; `--force` rebuilds anyway, `--only id[,id...]` restricts the run to named
characters (which is how you re-run after fixing a pipeline bug), and `--dry-run`
prints what would be exported without opening Blender.
`tools/test_convert_roster.sh` exercises the script's own logic in seconds against
`FILLY_EXPORTER` / `FILLY_VALIDATOR` / `FILLY_OUT_DIR` stubs, with no Blender
involved.

**What the manifest leaves out.** The reVAmped SFM pack ships 46 `.mdl` files and the
manifest lists 38 of them. The eight it does not list are `twilightsparkle`,
`rainbowdash`, `fluttershy`, `applejack` and `rarity`, which the Blender native tier-a
packs cover at higher fidelity (§3), `raricow`, a joke variant rather than a
character, `changelingdrone`, whose export has no usable textures (see below), and
`songbirdserenade`, whose mane mesh is modelled over her whole face (see below); both
of the last two are left out of the manifest entirely rather than converted and then
unused.
Three of the 38 it does list, `pinkiepie`, `derpyhooves` and
`starlightglimmer`, were already shipped before this batch; they stay in the manifest
so a fresh clone regenerates them, but they are not new characters. That leaves 35 new
tier-c characters plus the 2 new tier-a ones, `applejack` and `rarity`.

**What converted but is not in the roster.** `changelingdrone` exports and passes the
structural gate when run directly (it is no longer in the manifest, so a fresh clone
does not spend a Blender run on her), and is excluded, with no `PonyData` resource
pointing at it. Its `.mdl` was compiled against a material path this download does not contain: all 16
of the materials it references fail to resolve, so the export carries **zero images and
zero textures** and every surface falls back to a random pastel base colour.

```
[INFO]--[Source1::ModelLoader:import_materials]: Material body not found
[INFO]--[Source1::ModelLoader:import_materials]: Material hair not found
[INFO]--[Source1::ModelLoader:import_materials]: Material wings_changeling not found
...16 of 16, from ${TMPDIR:-/tmp}/convert_changelingdrone.log

meshes=11 skins=1 materials=10 textured=False animations=['gallop', 'idle', 'walk']
```

The model asks for `materials/models/VA_mlp_v4/changeling/` and
`materials/models/VA_mlp_v4/common/`. The pack files every other character's materials
under `Materials/Models/VA_MLP/<character>/` with shared maps in `VA_MLP/Common/`, and
ships no `VA_mlp_v4` tree at all. This is specific to this one model, not a pipeline
bug: `wings_changeling.vmt` and `Earlighter.vmt` exist nowhere in the download, and
`body.vmt` exists 45 times over, once in nearly every character's folder, so there is
no name that could be searched for generically without dressing the changeling in some
other pony's coat.
The line was removed from `tools/roster_manifest.txt` rather than left in with an
unused `.glb`, so a fresh clone does not spend a Blender export on a character nobody
sees; her export command above still works if this is ever revisited, once a matching
material tree can be sourced.

`songbirdserenade` exports cleanly and passes every gate (`textured=True`,
`hair_ok=true`, a `SpringBoneSimulator3D` on twelve mane chains) and renders with her
mane hanging over her entire face, both eyes covered, from the front and from
three-quarter. She is excluded for the same reason as the changeling: the defect is in
the model, not in the pipeline. Measured, in the order the hypotheses were worth
testing:

- **Not a rest-pose or roll defect.** `sfm_rig.check_rest_pose_preserved()` reports
  `SFM_RIG_REST_DRIFT moved=0.000000m turned=0.0000deg` on her export, so `adapt()`
  leaves every bone the `.mdl` shipped exactly where it put it.
- **Not the spring simulation.** Rendering her face with the simulator's `influence`
  pinned to 0, i.e. hair welded to the skull, is pixel for pixel the same curtain
  (`scenes/test/visual_review.tscn`, `mode=face tag=rigid`; the handling lives in
  `scenes/test/visual_review.gd`, which now honours `rigid` outside `mode=motion` for
  exactly this test). Nothing the springs do is involved.
- **Not a chain-length or gravity tuning problem.** Her mane is twelve chains of two
  joints each (`LeftHair1-6` and `RightHair1-6`, each with one `*_jiggle_hair*` child),
  well under `PonyRig.SPAN_REFERENCE_JOINTS`, so the long-chain stiffening never
  engages.
- **Not a misclassified accessory.** The kept bodygroup is `manes/VA_Mane_Sia.dmx`, her
  own mane and not a hat; her hat is in `accessories/`, which is dropped.
- **The mesh itself covers the face.** Decoding the exported `.glb`, every mesh's
  skinned rest pose equals its authored pose to `maxdisp=0.000000` (the rig deforms
  nothing at rest), and 429 of the mane's 21300 vertices sit inside a 0.18 m box
  centred on each eye and in front of it, symmetrically, on both sides. The same
  measurement straight out of SourceIO, before any of this repository's code runs, puts
  the raw `manes/VA_Mane_Sia.dmx` vertices at `y[-0.5301 -0.1072]` against the head
  mesh's `y[-0.4744 -0.0715]`, i.e. 0.056 units in front of the muzzle and below eye
  level. For contrast the same measurement finds 0 of `sunsetshimmer`'s and 0 of
  `octavia`'s in front of either eye, and `trixie`'s canon one-eye swoop is 108 verts
  in front of ONE eye and 0 in front of the other.

The mane is a deliberate face-covering bob (the model is the pony of Sia, whose
trademark wig covers her eyes), so there is no generic rule that could uncover them
without moving another character's hair. Nothing was changed in `sfm_rig.py`,
`export_blend.py` or `pony_rig.gd` for her.

For contrast, a handful of missing materials is normal and does not disqualify anyone:
`applebloom` is missing only her `-alt` eyeball variants and `milkyway` her teeth,
tongue, eyelashes, eyelens and eyebrow, all of which land on the `missing_white`
substitution documented under "Known fidelity losses" below, with body and hair
textures resolving normally.
Both export `textured=True`.

**The roster.** 43 characters: 5 tier a (`twilight`, `rainbowdash`, `fluttershy`,
`applejack`, `rarity`) and 38 tier c. By rarity that is COMMON 17, UNCOMMON 15, RARE 8
and LEGENDARY 3 (`sunsetshimmer`, `trixie`, `shiningarmor`). Those tier sizes are not
bookkeeping: `game/systems/spawn_table.gd` gives each TIER a fixed share of the draw and
splits it among that tier's members, so a member's own rarity is the tier weight divided
by the tier size. The slice plan's projected 11 RARE and 2 LEGENDARY lost
`changelingdrone` and `songbirdserenade` to the exclusions above, which left LEGENDARY
at one member holding the whole 3% share: a single legendary was 3.00% per draw against
a RARE pony's 1.20%, i.e. the rarest tier was the easiest individual to meet. Promoting
`trixie` and `shiningarmor` restores the ordering the tier names promise, per individual
per draw: COMMON 3.53%, UNCOMMON 1.67%, RARE 1.50%, LEGENDARY 1.00%. That ordering is
asserted against the real roster in `game/test/test_spawn_table.gd`, so the next roster
change that inverts it fails a test instead of shipping.

**When each character is out.** Slice 5 gave `PonyData` two more fields,
`phases` and `weathers`, both arrays of `WorldState` enum values, and one
function that interprets them: `available(phase, weather)`. An **empty array
means any**, in each list independently, and both non-empty is an AND, so
`[NIGHT], []` is a pony who keeps night hours in any weather and `[], [FOG]` is
one who wants fog at any hour. A `.tres` with neither line in it (most of them,
`kerfuffle.tres` for one) is unconditional and can be drawn at any hour in any
weather; adding the fields therefore broke no roster file. `game/world/spawner.gd`
asks `available()` on every draw and again on every change of sky, so a
character whose hours have ended walks off the map (`Pony.leave()`, never
freed in front of the player unless she cannot get away at all) and whoever
the new hour allows walks on.

**And the new hour's characters go first.** A slot freed by a departure used to
go straight back into the rarity weighted draw, where a night only legendary
competed against every unconditional common in the zone who was standing there
an hour ago and is eligible again now; measured on the real ranch, that cost a
night only character three extra cycles before she appeared. `refresh()` now
offers each marker's free slots first to its **newcomers** (the characters who
can be drawn now, could not be drawn at the pair the spawner last drew for, and
are standing nowhere on the map), and only then falls back to the weighted
draw. A marker with no free slot and no departure in flight sends **one**
unconditional resident home (empty `phases` and empty `weathers`, so she can
walk back in at any hour) to let a newcomer in, at most one per marker per
refresh, counted as `made_room` in what `refresh()` returns.

**17 of the 43 are conditional**, and this table is generated from the `.tres`
files rather than written by hand, so it is what the shipped roster actually
says:

| Character | id | Phases | Weathers | Zone |
|---|---|---|---|---|
| Carrot Top | `carrottop` | DAWN, DAY | any | `orchard` |
| Cloudchaser | `cloudchaser` | any | CLEAR, FOG | `lake` |
| Coco Pommel | `cocopommel` | DAY | any | `nightmeadow` |
| Flitter | `flitter` | any | CLEAR, RAIN | `lake` |
| Lightning Dust | `lightningdust` | any | STORM | `everfree` |
| Marble Pie | `marblepie` | DAWN, DUSK | any | `nightmeadow` |
| Maud Pie | `maudpie` | any | FOG, RAIN | `nightmeadow` |
| Milky Way | `milkyway` | NIGHT, DAWN | any | `lake` |
| Night Light | `nightlight` | NIGHT | any | `nightmeadow` |
| Octavia | `octavia` | DUSK, NIGHT | any | `nightmeadow` |
| Pinkamena | `pinkamena` | NIGHT, DUSK | RAIN, STORM | `everfree` |
| Shining Armor | `shiningarmor` | NIGHT | CLEAR | `nightmeadow` |
| Soarin | `soarin` | DAY, DAWN | CLEAR | `lake` |
| Spitfire | `spitfire` | DAY | CLEAR | `lake` |
| Sunset Shimmer | `sunsetshimmer` | DUSK | CLEAR | `everfree` |
| Trixie | `trixie` | NIGHT | any | `everfree` |
| Vinyl Scratch | `vinylscratch` | NIGHT | any | `nightmeadow` |

Four of those come out at **night and at no other hour** (Night Light, Shining
Armor, Trixie, Vinyl Scratch) and two only in the **day** (Coco Pommel,
Spitfire); the rest are open at two or three phases, or at any phase in
particular weather. That spread is what `scenes/test/collection_test.tscn`
classifies at run time rather than by name, and what it walks the clock through
a night at a time to exercise. See docs/testing.md, "The collection gate".

**Reviewing the roster at a glance.** `bash tools/roster_sheet.sh` renders a face shot
of every character (about 15 to 20 minutes under xvfb) and tiles them, with each
character's display name, into `build/roster_sheet.png` and a larger four column
`build/roster_sheet_large.png`; neither PNG is committed.

**Reviewing the sky at a glance.** The same idea for slice 4's time and weather:
`bash tools/sky_sheet.sh` renders `world/ranch.tscn` once per (phase, weather)
pair, pinned with `--phase=` and `--weather=` and pointed at a screenshot
directory, keeps the wide `01_establishing` shot of each run and tiles the
sixteen into `build/sky_sheet.png` (about twenty minutes under xvfb, not
committed). It is not a gate: `game/scenes/test/world_test.tscn` is what asserts
the sky rig is wired to the clock, in numbers; this is for the pair of eyes.

**Known follow-ups.** Two things this batch measured, did not fix, and should not lose.
Neither is breaking a shipped character today; both are gaps between what the pipeline
says it does and what it does on this pack, and both need a re-export and a look at the
renders, which is why they were out of scope of the batch that found them.

1. **`prune_bodygroups()` groups by the `manes/` path fragment, so a `_back` mane piece
   can be dropped.** `songbirdserenade`'s `.mdl` ships both `manes/VA_Mane_Sia.dmx`
   (21300 verts) and `manes/VA_Mane_Sia_back.dmx` (1770 verts, entirely behind the
   head). The rule sees two names containing `mane`, treats them as alternative STYLES,
   and keeps the first alphabetically. A `_back` suffix is a second PIECE of one hairdo,
   not a style, and the current rule cannot tell them apart. It cost nothing on her (she
   is excluded, and a piece behind the head could never have covered her eyes); whether
   any character who ships is missing the back of her mane has not been checked.
2. **Mane bones named `*Hair*` get the forelock stiffness profile.** `PROFILES` picks
   the mane profile by bone name, and the reVAmped rig spells its mane bones `Hair`, so
   `sunsetshimmer`, `trixie` and `pinkamena` run their manes at stiffness 10 rather than
   22. Their renders look right, so this may be the better number for them, but it is
   being applied by accident rather than by choice.

### Why this is not retargeting

The reVAmped skeleton shares **zero** bone names with tier a and, more to the
point, is not the same animal underneath: tier a's front leg splits 0.229 m /
0.305 m across two IK-chain bones, the SFM pony's splits 0.114 / 0.198 / 0.074
across three. Copying tier a's baked per-bone rotations onto those bones moves
the hoof somewhere else, and specifically changes how far a planted hoof
travels per stride — which is the one number `game/systems/gait.gd` matches to
stop the pony skating.

So `tools/sfm_rig.py` does the opposite. It **builds the tier-a animation
interface onto the imported Source rig** — `CON_Root`, `CON_Belly`, a
`DEF_Head` alias, and four `IK_*Hoof.*` world-space foot targets with real IK
chains behind them — and then `tools/author_anims.py` runs **completely
unchanged** and solves the same gait against the SFM pony's own leg geometry.
There is one copy of the gait code and no per-family branch in it.

Measured on the exported clips, sampling the hoof contact point at 60 steps
per cycle (`STRIDE` and `GALLOP_STRIDE` are both 0.275 m):

| | walk | gallop | IK error |
|---|---|---|---|
| Twilight (tier a) | 0.2659 m | 0.2729 m | — |
| Pinkie / Derpy / Starlight (tier c) | 0.2661–0.2667 m | 0.2717–0.2730 m | ≤ 0.009 m |

Same stride, same clip, two unrelated skeletons. That is the whole argument
for authoring against target geometry rather than transferring clips.

### What is and is not per character

Nothing in `sfm_rig.py` is. Verified across six models (Pinkie Pie, Rarity,
Maud Pie, Derpy Hooves, Applebloom, Shining Armor): the pack shares a 70-bone
core skeleton whose body and leg bones sit at identical rest positions to four
decimal places on every character — `Chest2` at z=0.4676, `LeftShoulder` at
z=0.4314, front leg span 0.3650, rear 0.4161 — filly and stallion alike. Only
hair/tail/wing/accessory chains and the head mesh differ. One authored clip
set covers all 47 models in the pack.

### Two defects that every structural gate was green through

Both were found by rendering a frame and looking at it
(`scenes/test/visual_review.tscn`, §7), not by a validator.

**The head cranked back over the shoulders**, in every clip, on every
character. A Blender bone's orientation is (head, tail, **roll**), and
`sfm_rig.py`'s bone-builder was zeroing roll. That is harmless for the control
bones that are nobody's twin — `CON_Root`, `CON_Belly`, the four IK
end-effectors and the four IK targets are all read for their position — but
`DEF_Head` is a twin of `Head` by construction: SourceIO gives every bone on these rigs the same 19 mm stub tail
and encodes the Source bone's real rotation in the roll, so `Head` imports at
roll −89.9994°, and an alias built from its head and tail alone sat a quarter
turn off it. The `COPY_TRANSFORMS` that drives the alias onto the head then
handed that quarter turn to the head on every evaluated frame.

The fix is one parameter; the guard is `sfm_rig.check_rest_pose_preserved()`,
which now runs at the end of every `adapt()` and asserts the thing that was
actually violated — **with no Action assigned, a pony that has been through
`adapt()` stands exactly where the `.mdl` put her.** It prints
`SFM_RIG_REST_DRIFT moved=<m> (<bone>) turned=<deg> (<bone>)` — the two maxima
tracked separately, because a pure twist about a bone's own head displaces it
by nothing and would hide behind any bone that had drifted a fraction of a
millimetre — and fails the export above 1 mm / 0.25°. Current drift on all
three shipped characters: 0.000000 m / 0.0000°.

**Every coat rendered as wet plastic** — most visible on Pinkie Pie, whose
pale pink coat washed out toward white. SourceIO wires the Source
`$phongexponenttexture` into Principled's Roughness, and glTF's
metallicRoughness texture is a fixed channel packing whose **green** channel
is roughness. Green in a Source exponent map is the albedo-tint mask (red is
the exponent), and on this pack it is 15/255 everywhere — roughness 0.06, a
mirror. Measured on the shipped `common/body_exponent`: min 15, max 89, mean
15.2, identical on all three characters, so there was also no hoof/coat
distinction to preserve. Source confines that specular lobe with
`$phongfresnelranges`/`$phongboost`; glTF carries no equivalent and Godot
ignores the `KHR_materials_specular` factor the exporter writes. So
`flatten_source_materials()` now drops the map and sets `ROUGHNESS_FLAT = 0.5`
— the same value every tier-a material already ships, so a Source pony and a
Blender pony standing in the same field are lit alike.

### Known fidelity losses

- **Flat irises.** SourceIO's eye materials are procedural `ADD_SHADER`/
  `MIX_SHADER` stacks doing parallax refraction from `!EYE_LOC` attributes.
  glTF cannot express that, so the iris texture is pulled out as a flat base
  colour.
- **Eyebrow and eyelash materials bind a `missing_white` placeholder** (a
  solid `#4D004D`), because the pack ships no VMT for them. It reads as dark
  lashes and nobody has objected, but it is a substitution, not the art.
- **Bodygroups are chosen here, not by the `.mdl`.** A Source model carries
  every ear/hoof/mane/tail variant as a separate mesh and the default index is
  data SourceIO does not apply, so `sfm_rig.BODYGROUPS` picks one of each and
  drops accessories and the eye-lens refraction shell. That last one is a
  judgement call and is flagged as such in the code.


---

## 6. Animation strategy — verdict, and how to add animations to a new character

**Verdict: CANONICAL RIG**, for the tier-a (CreatorOfPony/MythicSpeed)
family. All three converted tier-a rigs (Twilight, Rainbow Dash, Fluttershy)
share a **byte-identical 93-bone core skeleton** — a 100% intersection, zero
core-unique bones on any model — once cosmetic hair/mane/tail/wing chains
(which differ per hairstyle, not per rig design) are excluded. One
`idle`+`walk`+`gallop` clip set, authored once against the shared core bone
names, retargets to every tier-a pack by name alone — **no per-model
authoring, no retargeting step.** This was proven, not just inferred from
bone-name overlap: the identical, unmodified `tools/author_anims.py` was run
against all three rigs and produced valid clips on each (and, for the
locomotion clips, IK solutions that agree to four decimal places — the three
packs' leg geometry is the same rig).

The tier-c SFM probe shares **zero** bone names with tier a (`Pelvis`,
`Chest1`, `Head`, `Javv`, ... vs `DEF_Chest1`, `DEF_Head`, ...) — a
different rig family entirely, needing its own clips or a name-mapping
layer if ever animated.

None of the source packs ship any character animation — every tier-a `.blend`
carries exactly one Action (`CameraAxisAction`, a camera-orbit helper) and
zero NLA tracks or shape-key animation. A ~15-minute resource hunt for an
adoptable community Action library for this specific rig (archive.org's own
manifest, MythicSpeed's post, CreatorOfPony's dead Mediafire links, EqD
showcase posts, general searches) found nothing loginless/curl-reachable
with matching bone names. **Animations are authored in-script, not
downloaded or hand-keyed in the `.blend`.**

### The locomotion clips, and why there are two of them

| clip | frames @ 24 fps | stance | stride | implied ground speed |
|---|---|---|---|---|
| `walk` | 20 (0.833 s) | 1/2 of the cycle | 0.275 m | **0.66 m/s** |
| `gallop` | 12 (0.500 s) | 1/6 of the cycle | 0.275 m | **3.30 m/s** |

The strides are identical on purpose, and that is the whole design. The front
IK chain is 0.5334 m long against a 0.5269 m rest reach — **98.8% extended
standing still**, with 6.5 mm of bend to play with — so a hoof cannot be swung
further fore or aft without the solver hitting full extension and the knee
popping. `STRIDE` was already at that ceiling. The only remaining lever for
speed is the **cycle**, so `gallop` rides the same stride through a stance six
times shorter (0.083 s of ground contact, which is about what a real galloping
horse's limb gets) and depicts exactly 5x the speed.

`gallop` is a **transverse gallop on the left lead**, not a fast walk: four
separate beats (right-hind, left-hind, right-fore, left-fore, the leading
foreleg landing last) and two airborne phases — a short gathered suspension
after the hinds leave, a long extended one after the leading fore does,
**50% of the cycle with nothing on the ground** (an 8.3% gathered suspension
from `t=0.250` to `t=0.333`, plus a 41.7% extended one from `t=0.583` to
`t=1.000` — `tools/author_anims.py`'s own `GALLOP_FEET` comment gives that
exact split; a previous version of this doc quoted 42%, which is the extended
phase alone, not the total airborne fraction). The walk's symmetric diagonal
pairs are gone entirely. **"Leading" here is timing only, not reach**: the
left and right forelegs both run through the identical
`_gallop_foot_offset()` function against the same `GALLOP_STRIDE` — the only
difference between them is that `GALLOP_FEET` schedules the left foreleg's
contact 1/12 of a cycle after the right's, so it lands last. Nothing in the
clip makes it reach further forward than its counterpart; a previous version
of this doc claimed it did, which was not implemented and has been corrected
here. Two rig-specific accommodations make it fit:

- **A deeper body crouch** (`GALLOP_CROUCH` 0.055 m against the walk's 0.045),
  with one bob per cycle instead of two, timed so the body rides lowest through
  the forelimb stance — exactly when the front hooves are furthest fore/aft.
  Measured over the cycle the front chain peaks at **93.0%** extension against
  the walk's 95.1% and the idle's 101%, and the knee's bend direction never
  changes sign on any of the three packs. This clip is *further* from the
  singularity than the ones that came before it.
- **`GALLOP_REAR_REACH`** plants the hind hooves 0.06 m further under the body
  for the whole clip. The hind hoof sits 0.21 m *behind* its hip at rest (the
  hock's zig-zag), so unlike the front leg — which hangs almost straight down —
  the rear chain runs out of reach asymmetrically and swinging a hind hoof
  backwards costs far more extension than swinging it forwards. Re-centring
  the excursion is both the cheap fix and what a galloping quadruped actually
  does with its hindquarters.

Consumers must not pick or scale these clips by hand: `game/systems/gait.gd`
owns the speed ladder (which clip at which ground speed, at what playback
rate), and the two bands are arranged to meet *exactly* at 1.98 m/s so no
speed between a standstill and 4.29 m/s has to skate.

### Hair is NOT animated — it is simulated, and that takes two halves

Mane, tail and forelock chains are deliberately excluded from the clips and
driven at runtime by a Godot `SpringBoneSimulator3D`, so they lag the body's
bob instead of snapping with it. **Both halves are required**, and doing only
one of them looks exactly like doing neither. Full write-up, tuning values and
the measured evidence live in **`docs/notes-hair-sim.md`**; the rules a future
session must not break are:

1. **Export side (`tools/author_anims.py` → `SECONDARY_MOTION_PATTERNS`).** Any
   bone whose name contains `mane`, `tail`, `hair`, `forelock` or `fringe`
   (case-insensitive, any rig layer — `DEF_`, `CON_`, `FK_`, ...) ships with
   **zero animation channels**. `tools/export_blend.py` enforces this by
   filtering the glTF exporter's per-bone channel gather and then re-opening
   the written `.glb` to assert no such channel survived — a leak fails the
   export. This is load-bearing: in Godot an `AnimationPlayer` track and a
   `SkeletonModifier3D` write the same bone pose and the animation wins, so
   even a *constant* rest-pose track (which is exactly what
   `export_bake_animation` emits for every idle bone) silently overwrites the
   simulation and the spring bones appear to do nothing at all.
2. **Runtime side (`game/scripts/pony_rig.gd`).** `PonyRig.spawn("<name>")`
   loads the `.glb`, finds the hair chains by the same name patterns, and
   attaches a configured `SpringBoneSimulator3D` under the `Skeleton3D`.
   `game/scenes/characters/pony.tscn` is the editor-facing wrapper. **Never
   instance a pony `.glb` directly** — a bare instance has no hair simulation.
   The simulator cannot be saved inside the `.glb` or its `.import` sidecar:
   `game/assets/converted/` is gitignored and regenerated per machine (§2), so
   anything hand-added there evaporates. It lives in tracked script instead.

Two rig facts behind those rules, both verified rather than assumed:

- **The hair mesh binds to a second, hidden armature.** Every pack ships a
  `<X>_RigPhysics` armature (a child of the main rig) carrying duplicate,
  identically-named copies of the `DEF_Mane*`/`DEF_Hair*`/`DEF_Tail*` chains
  plus spline-IK constraints; the hair mesh's Armature modifier points at
  *that*, and it is flagged `hide_viewport`, so it is absent from the
  evaluated depsgraph and `export_apply=True` exported against the depsgraph.
  Result before this was fixed: the mane and tail exported **unskinned**,
  rigidly parented to the rig root, not following the head or body at all —
  while `meshes=17 skins=1 textured=True` and `WALK_OK` all still passed.
  `export_blend.py`'s `rebind_secondary_armatures()` now retargets such meshes
  onto the primary rig (only when every vertex group names a bone that exists
  there; the duplicated rest matrices agree to <5e-5 on all three packs). It
  prints one `REBIND <mesh> armature <secondary> -> <primary>` line per mesh.
- **`DEF_` deforms, `CON_` does not.** Decoding the exported mesh's
  `JOINTS_0`/`WEIGHTS_0` shows 100% of the hair mesh's weight on `DEF_Head`
  plus `DEF_Mane*`/`DEF_Hair*`/`DEF_Tail*`, and exactly 0% on any `CON_` bone —
  the `CON_` layer drove spline-IK curves that do not survive glTF. So the
  exclusion covers both layers (a keyframe on either is pointless), but only
  the `DEF_` chains are simulated.

**The IK solver is forced to `LEGACY` for the bake** (`author_anims.py`,
`author()`). The packs ship iTaSC, whose damped-least-squares solve is not
reproducible when the front chain sits at 98.8% extension as this rig's does:
once the hair rebind perturbed depsgraph evaluation, Fluttershy's idle started
flipping a front knee in roughly one export in six, i.e. the same `.blend`
produced different `.glb` files. `LEGACY` agrees with the iTaSC solve to within
0.0028 of a quaternion component (~0.3°) on every channel and is byte-stable
across repeated exports. Do not remove it.

### How to add animations to a new character

If the new character is a **tier-a** (CreatorOfPony/MythicSpeed-family)
pack, the existing clips apply for free — just export it:

```bash
tools/bin/blender/blender -b assets_raw/blender-native/<Pack>/<file>.blend \
  -P tools/export_blend.py -- --out game/assets/converted/ponies/<name>.glb --object <X>_Rig --anims --rotate-z 180 --scale 0.5
```

`--scale 0.5` is not optional (§3): the clips are authored in metres against
the normalised rig, and `author_anims._require_metric_rig()` aborts the export
if the rig it is handed is not metre-sized. If a future pack is authored at
some other size, the abort message prints the factor to use.

**If you are copying an older command from somewhere and it fails**, this is
why — `--anims` without `--scale` exits 1 since Phase 1A task 1. It is not a
regression to route around: adding `--scale 0.5` is the whole fix, and the
combination that now aborts would otherwise have shipped a full-size pony
walking a half-length stride. §3's "Model scale" section has the measurements.
Exports that do *not* pass `--anims` never enter this path and are unchanged.

No changes to `tools/author_anims.py` are needed as long as the pack shares
the 93-bone core naming convention (`DEF_*`, `FK_*`, `IK_*`, `CON_*`
prefixes) — Applejack and Rarity are already downloaded and expected to work
unchanged, just not yet run.

**Then check the hair actually works, because nothing above will fail if it
doesn't.** Confirm the export printed a `REBIND` line for the pack's hair mesh
(no line = the hair mesh is not skinned to the main rig and will sit rigid at
the model root) and a `SECONDARY_MOTION_FILTERED n` line with a plausible bone
count. Then run the lag scene against the new character:

```bash
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/hair_lag_test.tscn -- character=<name>
```

Every hair chain it finds should appear in the `CHAIN` listing and every leaf
chain should trail (see `docs/notes-hair-sim.md` for how to read the numbers).
If a chain is missing, the pack names its hair bones something
`SECONDARY_MOTION_PATTERNS` / `PonyRig.HAIR_PATTERNS` do not match — add the
substring to **both** lists, they must agree.

To add a **new clip** (trot, graze, sleep, ...) that every tier-a pony
should gain simultaneously, add a `build_<clipname>()` function to
`tools/author_anims.py` alongside `build_walk`/`build_idle`/`build_gallop`
and register it in `author()`. Load-bearing things to know before touching it:

- **The rig is permanently in IK mode.** Every `DEF_*Leg*`/`DEF_*Hoof*` bone
  carries two `COPY_TRANSFORMS` constraints (from its `FK_` then `IK_`
  twin, both influence 1.0) — last constraint wins, so keyframing `DEF_*` or
  `FK_*` bones directly produces tracks that do nothing. **Animate the four
  IK hoof targets** (`IK_FrontHoof.L/R`, `IK_RearHoof.L/R`, parented to
  `CON_Root` as world-space foot targets) instead.
- **Pose-bone `location` is in the bone's own local rest axes**, not world
  space or parent space — the hoof target bones point straight down, so a
  naive `location.z += lift` pushes a hoof sideways. Use the existing
  `_to_bone_space()` helper to convert an intended armature-space delta.
- **A pose bone's basis is shared state across clips.** Every clip must key
  every bone any sibling clip touches, even the ones it holds still — the
  original `idle` clip only keyed the belly/head and inherited the walk's
  mid-stride hoof pose as a result. Keep the `ANIMATED` bone set shared
  across all `build_*` functions.
- **Start clips at frame 0**, not frame 1 — a frame-1 start bakes a leading
  1/fps hold that reads as a per-cycle stutter once Godot loops it.
- **`export_bake_animation=True`/`export_animation_mode="ACTIONS"` must stay
  gated behind `--anims`.** Applied unconditionally, an armature with *no*
  Action still emits a full baked rest-pose clip named after the object —
  this broke the no-anims contract for a plain Task-4-style export and made
  `validate_gltf.py --require-anims` pass vacuously on an unanimated model.
  This was caught and fixed in review; the gating is load-bearing, don't
  remove it.
- **A clip's implied ground speed is duplicated across the Python/GDScript
  boundary, and `game/systems/gait.gd` is the single place the engine side of
  it may live.** Four values make up each derivation — the stride, the cycle
  length, the stance fraction, and the frame rate — and the frame rate is the
  sneaky one, because `author_anims.py` reads it from
  `bpy.context.scene.render.fps` (i.e. from whatever the source `.blend` is
  set to) while GDScript hardcodes `24.0`. A pack authored at a different fps
  desyncs the two with no gate failing and no symptom but foot skate. Nothing
  can check this automatically, so: **always compare against the
  `WALK_IMPLIED_SPEED` / `GALLOP_IMPLIED_SPEED` lines the export prints**, and
  `game/test/test_gait.gd` pins both numbers so a retune on one side fails a
  test rather than shipping. See §8 for why the divisor is the *stance*
  duration, not the whole cycle. `hair_lag_test.gd`'s `TRAVEL_SPEED` is the
  one remaining hand-copied derivation (walk_test.gd's was migrated onto Gait
  when `gallop` was added).
- **Loop mode is a tracked project default, not a per-asset setting.** glTF
  carries no loop flag, so Godot imports every animation as `LOOP_NONE` —
  since `game/assets/converted/` (and its `.import` sidecars) is gitignored,
  a per-file fix would evaporate on a fresh clone. `game/project.godot`
  carries `[importer_defaults]` forcing `loop_mode=1` (`LOOP_LINEAR`) for
  any animation literally named `idle`, `walk` or `gallop`. **A new clip name
  needs a new entry added to that block**, or it will import non-looping.
- **`animation/fps` in that same `[importer_defaults]` block is set to 24, and
  it must match the source `.blend`'s frame rate.** Godot does not import
  animation keys as authored: it *resamples* every clip onto a uniform grid at
  this rate, and its default is 30. Thirty does not divide twenty-four, so at
  the default only every fifth authored pose of a 24 fps clip survives
  unmoved and the rest are replaced by interpolations between neighbours. That
  is invisible in a still and cheap-looking in motion: measured on `walk` it
  shortened a planted hoof's stance travel from 0.275 m to 0.264 (4% of
  permanent foot skate), and on the 12-frame `gallop`, whose entire stance is
  two frames, it rounded the stance corners off for 16%. Setting it to the
  authoring rate makes the resample an identity. Verify after any re-export
  with `Animation.track_get_key_time()` — the imported key times should be
  exact multiples of 1/24.
- **`export_blend.py --rotate-z 180`** exists because the rig faces −Y in
  Blender, which `export_yup` maps to +Z in glTF, but Godot's
  `Node3D.look_at()` aims −Z — an unrotated pony moonwalks down her own
  path. This is baked into the asset (not fixed in scene code) so consumer
  scenes stay free of a per-model fudge rotation. It is a no-op without
  `--object` (there's no single target to rotate for a whole-scene export) —
  no longer a *silent* one: that combination now prints a `WARNING: --rotate-z
  ... ignored` line to stderr.

---

## 7. Validation + gallery/walk smoke-test commands

```bash
# Structural validation of any converted .glb
python3 tools/validate_gltf.py game/assets/converted/ponies/twilight.glb
python3 tools/validate_gltf.py game/assets/converted/ponies/twilight.glb --require-anims

# Gallery: loads every pony .glb in the folder, verifies skeleton + bone count
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/model_gallery.tscn
# -> LOADED <name>.glb skeleton=true bones=<n>   (one line per pony)
# -> GALLERY_OK count=3   exit 0   (the three converted tier-a characters;
#    the tier-c probe lives in probe/, not ponies/, so it is not counted)

# Animated walk test: Twilight walks a 4-waypoint square using the 'walk' clip
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/walk_test.tscn
# -> ANIMS ["gallop", "idle", "walk"]
# -> WALK_OK laps_progress=<n>   exit 0

# Baseline smoke test. NO LONGER the main scene -- since Phase 1A task 7 that is
# world/ranch.tscn (§9). Still kept and still run: it is the one gate that proves the
# engine boots with no content at all involved.
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/smoke.tscn
# -> SMOKE_OK renderer=forward_plus   exit 0

# The ranch: the game's main scene. Terrain + homestead + herd, and every check
# game/world/ranch.gd runs (player on the ground, props seated and collided, ponies
# raycast onto real ground inside their zones, camera spring arm pulling in against
# an actual building). Prints the marker ONLY if all of them held.
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn
# -> RANCH_OK ponies=22 props=58 assets=present   exit 0
# (assets=absent + zero counts on a checkout that has not run the asset pipeline)

# Hair follow-through: measures how far the mane/tail trail the body, against a
# rigid-hair baseline, over a scripted start-and-stop (see docs/notes-hair-sim.md)
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/hair_lag_test.tscn
# -> CHAIN <tip> root=<..> joints=<n> leaf=<bool> stiffness=.. drag=.. gravity=..
# -> HAIRLAG <tip> leaf trails body by +N ticks (+M ms) ...   (one line per chain)
# -> HAIRLAG_OK leaf_chains=6 passing=6 bob_retention=56%..199% worst_self_gain=1.16
#      worst_wobble=0.036   exit 0
# This gate drives a 0.66 m/s WALK ramp and nothing else. Hair that passes it can still
# stream out horizontally at the player's 4.0 m/s gallop -- that is a real defect this
# project shipped, and only scenes/test/visual_review.tscn (below) can see it.
# Add `-- character=rainbowdash` to point it at another pack.
#
# WATCHDOG: armed at 120s (GateWatchdogScript.arm, see game/scripts/gate_watchdog.gd).
# A bad `character=` value used to hang this gate indefinitely -- a reviewer confirmed
# it twice, rc=124 on an external timeout, no marker printed at all. PonyRig.spawn()
# returns null for an unknown name rather than hanging itself, but the very next line,
# `add_child(pony)`, then raises an ordinary GDScript runtime error on that null, which
# aborts _ready()'s coroutine (including its own eventual quit()) while the engine keeps
# ticking -- nothing about that looks like an infinite loop from the outside. If this
# still hangs past ~120s, the watchdog itself is broken; that is now the bug to chase,
# not "give it more time." A correct run against a bad character now prints
# `HAIRLAG_FAILED watchdog_timeout=120s` and exits 1 well inside that window instead of
# hanging.
#
# EXPECTED FAILURE, BY DESIGN, ON RAINBOW DASH AND FLUTTERSHY: `-- character=rainbowdash`
# and `-- character=fluttershy` both print `HAIRLAG_FAIL`, not `HAIRLAG_OK` -- their hair
# chains are known-failing and explicitly out of scope (see docs/notes-hair-sim.md's
# verdict section: Rainbow Dash 10/14 leaf chains pass, Fluttershy 1/3). An operator
# running this gate against either of those characters should expect `HAIRLAG_FAIL` and
# must not treat it as a regression. (This gate is not part of automated CI at all --
# see .github/workflows/smoke_run.sh, which only checks the exported build for
# `RANCH_OK` -- so the character this must pass for is whichever one a task or a
# reviewer is actually validating; the default with no `character=` argument, Twilight,
# is the one this project ships as passing.)

# Map-props probe (Task 8, §4): scatters every converted prop plus Twilight
# on a grass ground plane
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/terrain_probe.tscn
# -> LOADED <name>.glb pos=<Vector3> native_height=<n>   (one line per prop)
# -> PONY twilight height=<n>
# -> PROBE_OK count=<n>   exit 0

# Registry/visuals path (Phase 1A task 3): builds all three ponies through
# PonyRegistry -> PonyVisuals, the only sanctioned way to spawn one
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/registry_gallery.tscn
# -> BUILT <id> anim_ok=true hair_ok=true   (one line per pony)
# -> REGISTRY_OK count=3   exit 0

# Player controller (Phase 1A task 4): drives the player one second forward and
# one second with no input at all, then gates on distance, heading, floor contact
# and the animation state. Windowed, this is the scene you play to judge feel.
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/playground.tscn
# -> PLAYER drive dist=<m> travel=(x, y, z) speed=<m/s> on_floor=true clip=walk scale=<n>
# -> PLAYER coast dist=<m> residual_speed=<m/s> y=<m> clip=idle
# -> PLAYER_OK dist=<m>   exit 0
# (a failing run prints PLAYER_FAILED plus one line naming each broken check)
```

**Quirk: the first `.glb` import needs an editor pass before headless runs
succeed.** Because `game/assets/converted/` is gitignored, Godot has never
seen a freshly (re)generated `.glb` file — headless mode does not run the
import pipeline itself. The first time (after regenerating any `.glb`, or on
a fresh clone/checkout), run an editor pass once to populate `.godot/`'s
import cache before headless runs will pick the asset up:

```bash
tools/bin/godot --headless --path game --editor --quit-after 60
```

(~15 seconds is typically enough; `--quit-after 60` is a safe ceiling.)
Subsequent headless runs work normally until the `.glb` changes again.

**Structural gates cannot see a rendering bug.** `meshes>0 skins>0
textured=True`, correct bone counts, and `WALK_OK` all passed while an
early export of Twilight was rendering almost entirely invisible (§3, quirk
2) — none of these checks look at a single pixel. That defect was only
caught by rendering actual frames off-screen (`xvfb-run` + llvmpipe
software Vulkan) and inspecting them. It happened again in the owner's first
real playtest: three separate defects (torn irises, hair streaming out
horizontally, a magic beam emerging from Twilight's cheek) that every gate
above was green through.

**So there is now a scene whose whole job is to render frames a human looks
at**, `scenes/test/visual_review.tscn`. It asserts nothing — read the PNGs.

```bash
xvfb-run -a tools/bin/godot --path game --audio-driver Dummy \
  --resolution 1280x720 scenes/test/visual_review.tscn -- \
  mode=face character=fluttershy out=/tmp/shots
# -> SHOT /tmp/shots/fluttershy_face_front.png  (+ threequarter, eye closeup, head wide)
# -> VISUAL_REVIEW_DONE mode=face character=fluttershy shots=4
```

- `mode=face` — head close-ups. What "the eyes look funny" is judged on.
- `mode=motion clip=walk|gallop` — the character travelling at the clip's own
  speed with the springs live, captured at instants far enough apart to see
  the trail. **Add `tag=rigid` for the reference shot** (`influence = 0`,
  hair welded to the skull): that is the shape the model and the clip
  intend, and every judgement about the springs is a comparison against it.
  Judge the gallop, not just the walk — `hair_lag_test` only ever drives a
  0.66 m/s walk ramp, and hair that reads fine there can still stream out
  like a flag at the player's 4.0 m/s gallop. That is exactly the defect the
  owner reported and the numbers missed.
- `mode=beam` — a real `Player` with the beam on, side-on at head height,
  and it prints `BEAM horn_tip=(…) beam_origin=(…) gap=…` so the mount's
  placement is a number as well as a picture.
- `mode=probe` — no pictures; prints measured landmarks (horn tip in model
  space, eye centres) and every `MeshInstance3D` with its world position and
  material. `player.tscn`'s `BeamOrigin` default came from here.

Windowed/offscreen, **not** `--headless` (headless renders nothing to
capture); `--audio-driver Dummy` as everywhere else.

---

## 8. Voice-line recipe + verdict

Full recipe, reproduction steps, timing data, and the go/no-go call live in
**`docs/notes-voice.md`** — not duplicated here to avoid drift between two
copies. Summary:

- **Route:** `edge-tts` (free, local, neural TTS) generates a source take →
  a hosted Hugging Face Space (**Ultimate RVC**,
  `JackismyShephard/ultimate-rvc`, free `cpu-basic` tier) does RVC voice
  conversion using a community **Pony Preservation Project** model
  (`therealvul/RVCv2`, `TwilightSparkle-Titan`) → `ffmpeg` resamples to
  44.1kHz mono 16-bit PCM.
- **Delivered:** `game/assets/audio/voice/twilight/greeting_01.wav`
  (committed — small, and it's a Phase 0 deliverable).
- **Quality verdict:** pending owner listen (objective measurements — no
  clipping, duration match, plausible pitch range/stability — are recorded
  in `docs/notes-voice.md`; shippable/meh/bad is the owner's call).
- **Go/no-go for Phase 4's ~100-line batch:** **no-go on the public Space
  as-is.** RVC inference itself is cheap (~15s/line), but the free shared
  queue made a single line take anywhere from under a minute to 40+ minutes
  unresolved across 4 attempts — unattended batch generation at that
  variance is impractical. `docs/notes-voice.md` recommends a **local
  `ultimate-rvc` pip install** (same pipeline, no queue) as the next step
  for Phase 4, with ElevenLabs (paid) as a fallback if that proves
  impractical.

---

## 9. Export commands — both platforms

### One-time: export templates

This portable Godot build's `--headless` help lists no
`--install-export-templates` flag (only `--install-android-build-template`)
— confirmed by running it and inspecting `--help` output directly, not
assumed. Fall back to downloading the matching `.tpz` from the same GitHub
release used for the Godot binary itself (Task 1: `4.5.2-stable`):

```bash
curl -fL --connect-timeout 30 --max-time 600 -C - \
  -o /tmp/Godot_v4.5.2-stable_export_templates.tpz \
  "https://github.com/godotengine/godot/releases/download/4.5.2-stable/Godot_v4.5.2-stable_export_templates.tpz"

# Verify against the release's own SHA512-SUMS.txt before unpacking (~1.3GB download):
sha512sum /tmp/Godot_v4.5.2-stable_export_templates.tpz
# expected: 003aa33743f58fb657717f090fc872ed3975e48d08a6012201a2259970d458a63d4d8a83090585307c23455ebfa4e6e0050e1057761c34863536095e3fcfab6c

mkdir -p ~/.local/share/godot/export_templates
unzip -oq /tmp/Godot_v4.5.2-stable_export_templates.tpz -d /tmp/tpz_extract
mv /tmp/tpz_extract/templates ~/.local/share/godot/export_templates/4.5.2.stable
```

The `.tpz`'s own `templates/version.txt` reads `4.5.2.stable`, which must
match the destination folder name exactly (Godot's `--version` output is
`4.5.2.stable.official.<hash>` — the folder name is the `major.minor.patch.status`
prefix only, no build hash). Verify:
`ls ~/.local/share/godot/export_templates/` shows `4.5.2.stable`.

The `-C -` resume flag matters — this is a ~1.3GB download; if it can't
finish inside a single timeout window, re-running the same command resumes
from where it left off rather than restarting.

### Presets

`game/export_presets.cfg` (committed) defines two presets, `Linux` and
`Windows`, both `runnable`, `all_resources`, `x86_64`.

### Export + smoke test

```bash
mkdir -p build
tools/bin/godot --headless --path game --export-release "Linux"   ../build/filly-rancher-linux.x86_64
tools/bin/godot --headless --path game --export-release "Windows" ../build/filly-rancher-windows.exe
./build/filly-rancher-linux.x86_64 --headless --audio-driver Dummy
ls -la build/
```

Actual result: both exports complete with exit 0 in ~5s each (`[ DONE ]
savepack`), producing `filly-rancher-linux.x86_64` and
`filly-rancher-windows.exe` in `build/` (gitignored — exports are never
committed).

**The export smoke expectation is `RANCH_OK`, not `SMOKE_OK`.** Since Phase 1A
Task 7 the main scene is `res://world/ranch.tscn` (`game/project.godot`), not
`res://scenes/test/smoke.tscn`. The Linux binary prints:

```
RANCH_OK ponies=22 props=58 assets=present
```

exit 0 — the same line the headless scene run prints, confirming the exported
binary boots the packed ranch, builds its terrain, loads its props, spawns its
herd and passes every check `game/world/ranch.gd` runs, not just that it starts.
`smoke.tscn` still exists and still prints `SMOKE_OK` when run directly as a
gate; it is simply no longer what the game boots into, and `SMOKE_OK` has been
removed from the accepted markers in `.github/workflows/smoke_run.sh` so a
future accidental revert of `run/main_scene` cannot pass CI silently.

**`ponies=0 props=…` in the trailing fields is expected on a machine that has
not run the asset pipeline** (and in CI): `game/assets/converted/` is gitignored,
so those builds are assetless and the ranch says so with `assets=absent` /
`assets=partial` rather than reporting a bare zero. See `docs/ci.md` §4.

**Two bugs this export step caught the first time it was run against the ranch**,
both invisible to every gate that ran the project from source with `--path game`:

1. **The exporter converts `.tres` to binary `.res`** (`convert_text_resources_to_binary`
   defaults on), and `PonyRegistry.load_all()` was filtering directory entries on
   the `tres` extension — so in the **shipped game** the roster loaded as empty:
   the player spawned with no body and no wild pony spawned at all. Fixed in
   `game/systems/pony_registry.gd` (`_resource_path()` now accepts `.res` and
   `.tres`, and follows `.remap` stubs). Anything else that scans a directory for
   resources by extension needs the same treatment.
2. Nothing in the repo had ever run the exported binary against a scene that
   *needed* content. The lesson is the doc-level one: **re-run the export smoke
   test whenever the main scene starts depending on something new**, because
   `--path game` and the `.pck` are not the same filesystem.

**Windows verification is remote.** Godot cross-exports the `.exe` from Linux
with no Wine involved — this machine can confirm the file is a
real PE32+ Windows executable (`file build/filly-rancher-windows.exe`) but
cannot run it. `windows-latest` in `.github/workflows/build-and-smoke.yml`
runs it for real on every push; the friend on the Windows machine is the
second check, not the only one.

**`RANCH_OK` is necessary and not sufficient — render the exported binary too.**
The export smoke test above proves the packed game boots and passes every
structural check. It cannot see whether anything is on screen. This project has
shipped a build that loaded zero characters while printing a green marker (the
`.tres`-to-`.res` bug two paragraphs up), so since Phase 1A Task 9 the export
step also runs the shipped binary under a virtual display and looks at the frames:

```bash
xvfb-run -a ./build/filly-rancher-linux.x86_64 --audio-driver Dummy -- --screenshot-dir=/tmp/shots
```

(`--`, then `--screenshot-dir=`; `game/world/ranch.gd` reads it out of
`OS.get_cmdline_user_args()`.) That saves the same six shots the scene run
saves — establishing, player's-eye, a spawn zone, the camera pressed against a
wall (`04a`) and backed off from it (`04b`), and the barn at eye level —
**from inside the `.pck`**, so a missing model, a missing
material or a HUD whose script failed to pack shows up as a picture rather than
as nothing at all. Note that it is `xvfb-run` **without** `--headless`: headless
uses the dummy rasteriser and renders nothing. Because of that, `--headless`'s
usual side effect of forcing the dummy *audio* driver does not apply here either —
`--audio-driver Dummy` has to be passed explicitly, or this run (like every other
non-interactive/scripted run of this game) would open a real audio device and,
on this scene, could play Twilight's capture voice line out loud. (Belt-and-braces:
`game/systems/audio_safety.gd`, an autoload, also mutes the Master bus on its own
whenever it sees a `--screenshot...` arg, so forgetting this flag here no longer
means an audible run.)

---

## Deferred to Phase 1

Findings and decisions that came up during Phase 0 but were explicitly
scoped out of it. Recorded here — as a tracked doc — because they had
previously existed only in gitignored task-report files
(`.superpowers/sdd/.../task-7-report.md`) or the ledger, which is not a
durable home for a decision Phase 1 planning needs.

1. ~~**Model scale is undecided.**~~ **SETTLED (Phase 1A task 1): 1 unit = 1
   metre, ponies exported with `--scale 0.5`.** The factor was picked from a
   withers measurement (2.326 pack units → 1.163 m, a small show pony) rather
   than from the bounding box, which these cartoon proportions inflate to
   1.84× the withers height. The full reasoning, the measured numbers and the
   two things that follow from the decision (metric constants in
   `author_anims.py`; the hair sim being scale-invariant by construction) live
   in §3, "Model scale". The prop side is re-derived in §4: the recommended
   map-build-time prop multiplier is now **1.5×**, not the 3× Task 8 quoted
   against the old pony scale.
2. **Owner's visual/audio verdicts are still pending**, across three
   deliverables that were structurally validated but never subjectively
   judged by a human: walk quality *in motion* (the gait is measured
   symmetric/seamless/smooth — see `tools/author_anims.py`'s tuning
   constants `STRIDE`, `LIFT`, `BODY_BOB`, `BODY_PITCH`, `BODY_CROUCH` if it
   needs retuning — but "does this read as a good walk" is a judgment call
   no automated metric can make), pony materials/appearance, and the one
   voice line's quality (`docs/notes-voice.md`).
3. **Cutie-mark decal restoration.** glTF cannot express the source
   materials' color-plus-decal composite in one material (§3, quirk 2), so
   every converted pony currently ships with a flat body color and no cutie
   mark. Fixing this means baking the composite down to an actual body
   texture — a Cycles bake over the existing UVs — before export. Documented
   as a known limitation in `tools/export_blend.py`'s module comment as well.
4. **Root-motion extraction to eliminate residual foot slide.** The walk
   clip's stance speed was tuned to match `walk_test.gd`'s ground speed
   (`STRIDE=0.275 m` → `0.66 m/s`, reducing measured slide ~3.5x from the
   original tuning), but a residual **~0.13 m/s** stance slide remains
   (it was measured as 0.257 u/s before the metric rescale halved every
   length in the clip; the *relative* slide is unchanged) —
   caused by Bezier interpolation between authored keys plus Godot
   resampling a 24fps clip against `animation/fps=30` at a 60Hz physics
   tick, not by an error in the authored gait itself. Driving it to exactly
   zero needs either a linear-interpolation stance segment with matched
   clip/physics rates, or (the more robust long-term fix) extracting true
   root motion from the clip instead of hand-matching a scene-side speed
   constant — which would also remove the `WALK_STRIDE` duplication between
   `tools/author_anims.py` and `game/scenes/test/walk_test.gd` noted in §6.
