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
background planes, and unparented `BS_*` helpers). `--anims` authors `idle`
+ `walk` clips onto the rig before export (§5). `--rotate-z 180` fixes a
facing-direction quirk (§5). `--scale 0.5` normalizes the model to metric
scale — see immediately below; it is **mandatory for every new character**.
Omit `--anims`/`--rotate-z` for a static, unanimated export (e.g. for a prop
or a quick structural check) — but keep `--scale`.

Each invocation prints a per-material resolution log line, then
`SCALED factor=0.5 …`, `METRIC_RIG_OK height=2.0525`,
`ANIMS_AUTHORED ['idle', 'walk']` (if `--anims`), then `EXPORT_OK <path>`.

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

**Known limitation carried forward:** glTF cannot express a color-plus-decal
mix in one material, so the exported body keeps its flat base color and
**loses the cutie mark**. This is a real fidelity regression, deferred to
Phase 1 (§9 below — Cycles bake).

### Validation

```bash
for f in game/assets/converted/ponies/*.glb; do
  python3 tools/validate_gltf.py "$f" --require-anims || echo "FAILED: $f"
done
```

Expected, one line per pony:

```
meshes=17 skins=1 materials=13 textured=True animations=['idle', 'walk']   # twilight
meshes=16 skins=1 materials=16 textured=True animations=['idle', 'walk']   # rainbowdash
meshes=15 skins=1 materials=11 textured=True animations=['idle', 'walk']   # fluttershy
```

(Drop `--require-anims` for a plain structural export with no `--anims`
flag — those correctly report `animations=[]` and still pass the base
`meshes>=1 skins>=1` gate.)

The loop above sweeps `ponies/*.glb` and expects **exactly the three tier-a
characters** — keep tier-b props in `props/` and the tier-c probe in `probe/`
(§2), or this loop fails on them. `validate_gltf.py` parses its arguments with
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

**Output goes to `probe/`, not `ponies/`** (§2). Tier c ships no animations,
so a tier-c `.glb` sitting in `ponies/` makes §3's `--require-anims`
validation loop print `VALIDATION FAILED` when run verbatim, and inflates
`model_gallery.tscn`'s `GALLERY_OK count=` past the three real characters.
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

Like tier a, tier c ships zero baked animations — any tier-c model needs
either its own authored clip set or a bone-name remap onto the tier-a
canonical rig (it shares zero bone names with tier a: `Pelvis`, `Chest1`,
`Head`, ... vs `DEF_Chest1`, `DEF_Head`, ...).

---

## 6. Animation strategy — verdict, and how to add animations to a new character

**Verdict: CANONICAL RIG**, for the tier-a (CreatorOfPony/MythicSpeed)
family. All three converted tier-a rigs (Twilight, Rainbow Dash, Fluttershy)
share a **byte-identical 93-bone core skeleton** — a 100% intersection, zero
core-unique bones on any model — once cosmetic hair/mane/tail/wing chains
(which differ per hairstyle, not per rig design) are excluded. One
`idle`+`walk` clip set, authored once against the shared core bone names,
retargets to every tier-a pack by name alone — **no per-model authoring, no
retargeting step.** This was proven, not just inferred from bone-name
overlap: the identical, unmodified `tools/author_anims.py` was run against
all three rigs and produced valid `idle`+`walk` on each.

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
tools/bin/godot --headless --path game scenes/test/hair_lag_test.tscn -- character=<name>
```

Every hair chain it finds should appear in the `CHAIN` listing and every leaf
chain should trail (see `docs/notes-hair-sim.md` for how to read the numbers).
If a chain is missing, the pack names its hair bones something
`SECONDARY_MOTION_PATTERNS` / `PonyRig.HAIR_PATTERNS` do not match — add the
substring to **both** lists, they must agree.

To add a **new clip** (trot, graze, sleep, ...) that every tier-a pony
should gain simultaneously, add a `build_<clipname>()` function to
`tools/author_anims.py` alongside `build_walk`/`build_idle` and register it
in `author()`. Load-bearing things to know before touching it:

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
- **`WALK_STRIDE` is duplicated** between `tools/author_anims.py` (the
  authoring constant, `0.275` m) and `game/scenes/test/walk_test.gd` (the
  scene's ground-speed constant, derived as
  `STRIDE / (cycle_seconds * 0.5)` = `0.66 m/s`; `hair_lag_test.gd`'s
  `TRAVEL_SPEED` is a third copy) — cross-check comments sit
  at both sites, but they are not automatically kept in sync. If you retune
  `STRIDE`, update both, or the walk-test pony's feet will skate. See §8 for
  why the divisor is *half* the cycle, not the whole cycle. **Four values are
  duplicated, not one**: `STRIDE`, `WALK_FRAMES`, `STANCE_FRACTION`, and the
  frame rate — and the frame rate is the sneaky one, because `author_anims.py`
  reads it from `bpy.context.scene.render.fps` (i.e. from whatever the source
  `.blend` is set to) while `walk_test.gd` hardcodes `24.0`. A pack authored
  at a different fps desyncs the two with no gate failing. Always compare
  against the `WALK_IMPLIED_SPEED` line the export prints.
- **Loop mode is a tracked project default, not a per-asset setting.** glTF
  carries no loop flag, so Godot imports every animation as `LOOP_NONE` —
  since `game/assets/converted/` (and its `.import` sidecars) is gitignored,
  a per-file fix would evaporate on a fresh clone. `game/project.godot`
  carries `[importer_defaults]` forcing `loop_mode=1` (`LOOP_LINEAR`) for
  any animation literally named `idle` or `walk`. **A new clip name needs a
  new entry added to that block**, or it will import non-looping.
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
tools/bin/godot --headless --path game scenes/test/model_gallery.tscn
# -> LOADED <name>.glb skeleton=true bones=<n>   (one line per pony)
# -> GALLERY_OK count=3   exit 0   (the three converted tier-a characters;
#    the tier-c probe lives in probe/, not ponies/, so it is not counted)

# Animated walk test: Twilight walks a 4-waypoint square using the 'walk' clip
tools/bin/godot --headless --path game scenes/test/walk_test.tscn
# -> ANIMS ["idle", "walk"]
# -> WALK_OK laps_progress=<n>   exit 0

# Baseline smoke test (also the export smoke test's main scene, §8)
tools/bin/godot --headless --path game scenes/test/smoke.tscn
# -> SMOKE_OK renderer=forward_plus   exit 0

# Hair follow-through: measures how far the mane/tail trail the body, against a
# rigid-hair baseline, over a scripted start-and-stop (see docs/notes-hair-sim.md)
tools/bin/godot --headless --path game scenes/test/hair_lag_test.tscn
# -> CHAIN <tip> root=<..> joints=<n> leaf=<bool> stiffness=.. drag=.. gravity=..
# -> HAIRLAG <tip> leaf trails body by +N ticks (+M ms) ...   (one line per chain)
# -> HAIRLAG_OK leaf_chains=6 moving=6 lagging=6 worst_wobble=0.032   exit 0
# Add `-- character=rainbowdash` to point it at another pack.

# Map-props probe (Task 8, §4): scatters every converted prop plus Twilight
# on a grass ground plane
tools/bin/godot --headless --path game scenes/test/terrain_probe.tscn
# -> LOADED <name>.glb pos=<Vector3> native_height=<n>   (one line per prop)
# -> PONY twilight height=<n>
# -> PROBE_OK count=<n>   exit 0

# Registry/visuals path (Phase 1A task 3): builds all three ponies through
# PonyRegistry -> PonyVisuals, the only sanctioned way to spawn one
tools/bin/godot --headless --path game scenes/test/registry_gallery.tscn
# -> BUILT <id> anim_ok=true hair_ok=true   (one line per pony)
# -> REGISTRY_OK count=3   exit 0

# Player controller (Phase 1A task 4): drives the player one second forward and
# one second with no input at all, then gates on distance, heading, floor contact
# and the animation state. Windowed, this is the scene you play to judge feel.
tools/bin/godot --headless --path game scenes/test/playground.tscn
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
software Vulkan) and inspecting them. **Recommendation for Phase 1:** add a
cheap render-and-compare check to the pipeline (even "fraction of
non-background pixels in a fixed camera shot") — it would have caught that
defect three tasks earlier than it actually was.

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
./build/filly-rancher-linux.x86_64 --headless
ls -la build/
```

Actual result: both exports complete with exit 0 in ~5s each (`[ DONE ]
savepack`), producing `filly-rancher-linux.x86_64` + `.pck` and
`filly-rancher-windows.exe` + `.pck` in `build/` (gitignored — exports are
never committed). The Linux binary smoke test prints:

```
SMOKE_OK renderer=forward_plus
```

exit 0 — same output as the headless scene run, confirming the exported
binary boots the packed `smoke.tscn` main scene correctly, not just the
editor-driven `--path` run.

**Windows verification is remote.** Godot cross-exports the `.exe` + `.pck`
from Linux with no Wine involved — this machine can confirm the file is a
real PE32+ Windows executable (`file build/filly-rancher-windows.exe`) but
cannot run it. The friend on the Windows machine smoke-tests it there (or,
if Wine is ever installed on this machine, that becomes an option too).

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
