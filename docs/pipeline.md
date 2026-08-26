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

Verify: `tools/bin/godot --version` prints `4.5.2.stable.official....`;
`tools/bin/blender/blender --version` prints `Blender 4.2.23 LTS`.

---

## 2. Folder conventions

```
assets_raw/<source>/            # downloaded, unmodified source packs (gitignored)
  blender-native/<Character>_<ver>/...   # tier a: CreatorOfPony/MythicSpeed .blend packs
  sfm/...                                # tier c: SFM/GMod .mdl compiled packs
  props/<model-slug>/...                 # tier b: Sketchfab glTF/FBX prop downloads

game/assets/converted/<kind>/   # pipeline output, gitignored (regenerated from assets_raw/)
  ponies/<name>.glb
  props/<name>.glb

game/assets/audio/voice/<character>/<category>_<nn>.wav   # committed (small, hand-picked)
```

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
  -P tools/export_blend.py -- --out game/assets/converted/ponies/twilight.glb --object TS_Rig --anims --rotate-z 180

tools/bin/blender/blender -b assets_raw/blender-native/RainbowDash_1-1/RainbowDash4.blend \
  -P tools/export_blend.py -- --out game/assets/converted/ponies/rainbowdash.glb --object RD_Rig --anims --rotate-z 180

tools/bin/blender/blender -b assets_raw/blender-native/Fluttershy_1-0/Fluttershy_1-0.blend \
  -P tools/export_blend.py -- --out game/assets/converted/ponies/fluttershy.glb --object FS_Rig --anims --rotate-z 180
```

`--object <Rig>` selects exactly the character (the script walks
`children_recursive`, which naturally pulls in the hair mesh hanging off a
secondary `*_RigPhysics` armature and naturally excludes the camera,
background planes, and unparented `BS_*` helpers). `--anims` authors `idle`
+ `walk` clips onto the rig before export (§5). `--rotate-z 180` fixes a
facing-direction quirk (§5). Omit both flags for a static, unanimated export
(e.g. for a prop or a quick structural check).

Each invocation prints a per-material resolution log line, then
`ANIMS_AUTHORED ['idle', 'walk']` (if `--anims`), then `EXPORT_OK <path>`.

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

---

## 4. Tier b recipe — glTF/FBX props (Sketchfab)

**Status: as-designed, not yet exercised.** Task 8 (map-props probe) is
blocked on the owner's Sketchfab downloads (login-walled; see
`docs/shopping-list.md` §3) and has not run yet. The recipe below is the
plan's intended path, carried into this doc so the pipeline stays complete
end-to-end; it has **not** been proven against a real download the way
tiers a and c have. **Verified pending Task 8** — update this section (and
remove this notice) once that task runs for real, including any quirks it
finds.

**Source:** Sketchfab buildings + tree pack (see `docs/shopping-list.md`
§3), saved into `assets_raw/props/<model-slug>/`.

**As-designed steps:**

1. **glTF downloads** — Sketchfab exports every downloadable model as glTF
   directly. Copy the `.gltf`/`.glb` (plus any loose textures) straight into
   `game/assets/converted/props/<name>.glb` — no Blender round-trip needed.
2. **FBX downloads** (if glTF isn't offered for a given model) — convert via
   Blender: import the FBX headlessly (`bpy.ops.import_scene.fbx(...)`),
   then reuse `export_blend.py`'s export call/material-rebuild logic against
   the imported scene.
3. **Validate** with `tools/validate_gltf.py`, but props don't ship a skin —
   the plan calls for a `--props` mode that only gates on `meshes>=1`, since
   the existing script's `ok = bool(meshes) and bool(skins)` would
   incorrectly fail a static, unrigged prop. This validator extension is
   part of Task 8's scope, not yet implemented.
4. Scatter converted props into a `terrain_probe.tscn` (mirrors
   `model_gallery.gd`'s load-all-from-a-folder pattern) on a large ground
   plane, print `PROBE_OK count=N`, and — per the standing project ruling
   that visual checks batch to the owner separately — get a verdict on
   scale sanity (props sized correctly relative to a dropped-in pony) and
   whether it reads as "a place in Ponyville."

When Task 8 runs, replace this section with the actual commands run, any
per-model quirks found (Sketchfab exports are generally clean glTF, but this
is unverified for these specific 4 models), and the resulting verdict on the
props-on-Godot-terrain approach for Phase 1's ranch map.

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
tools/bin/blender/blender -b -P tools/convert_mdl.py -- \
  --mdl "assets_raw/sfm/SFM Ready Compiled Files/Models/reVAmped_ponies/revamped_maudpie.mdl" \
  --out game/assets/converted/ponies/sfm_probe.glb
# -> MDL_EXPORT_OK game/assets/converted/ponies/sfm_probe.glb

python3 tools/validate_gltf.py game/assets/converted/ponies/sfm_probe.glb
# -> meshes=14 skins=1 materials=12 textured=True animations=[]
```

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

### How to add animations to a new character

If the new character is a **tier-a** (CreatorOfPony/MythicSpeed-family)
pack, the existing clips apply for free — just export it:

```bash
tools/bin/blender/blender -b assets_raw/blender-native/<Pack>/<file>.blend \
  -P tools/export_blend.py -- --out game/assets/converted/ponies/<name>.glb --object <X>_Rig --anims --rotate-z 180
```

No changes to `tools/author_anims.py` are needed as long as the pack shares
the 93-bone core naming convention (`DEF_*`, `FK_*`, `IK_*`, `CON_*`
prefixes) — Applejack and Rarity are already downloaded and expected to work
unchanged, just not yet run.

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
  authoring constant, `0.55`) and `game/scenes/test/walk_test.gd` (the
  scene's ground-speed constant, derived as
  `STRIDE / (cycle_seconds * 0.5)` = `1.32 u/s`) — cross-check comments sit
  at both sites, but they are not automatically kept in sync. If you retune
  `STRIDE`, update both, or the walk-test pony's feet will skate. See §8 for
  why the divisor is *half* the cycle, not the whole cycle.
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
  scenes stay free of a per-model fudge rotation. It is a silent no-op
  without `--object` (there's no single target to rotate for a whole-scene
  export).

---

## 7. Validation + gallery/walk smoke-test commands

```bash
# Structural validation of any converted .glb
python3 tools/validate_gltf.py game/assets/converted/ponies/twilight.glb
python3 tools/validate_gltf.py game/assets/converted/ponies/twilight.glb --require-anims

# Gallery: loads every pony .glb in the folder, verifies skeleton + bone count
tools/bin/godot --headless --path game scenes/test/model_gallery.tscn
# -> LOADED <name>.glb skeleton=true bones=<n>   (one line per pony)
# -> GALLERY_OK count=<n>   exit 0

# Animated walk test: Twilight walks a 4-waypoint square using the 'walk' clip
tools/bin/godot --headless --path game scenes/test/walk_test.tscn
# -> ANIMS ["idle", "walk"]
# -> WALK_OK laps_progress=<n>   exit 0

# Baseline smoke test (also the export smoke test's main scene, §8)
tools/bin/godot --headless --path game scenes/test/smoke.tscn
# -> SMOKE_OK renderer=forward_plus   exit 0
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

1. **Model scale is undecided.** The converted ponies measure roughly `1.68
   × 4.28 × 4.31` Blender units (width × height × depth,
   `MODEL_AABB size=(1.68, 4.28, 4.31)`) — if 1 unit is meant to be 1 metre,
   these ponies are **roughly 3× life size**. Two ways to resolve it:
   normalize scale at export time (rescale every converted model into a
   sane meter range), or build world geometry (terrain, buildings, props) to
   match the models' native scale instead. Not decided; needs a deliberate
   call before Phase 1 world geometry gets built around either assumption,
   since redoing it later means reworking either every asset or every map.
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
   (`STRIDE=0.55` → `1.32 u/s`, reducing measured slide ~3.5x from the
   original tuning), but a residual **~0.257 u/s** stance slide remains —
   caused by Bezier interpolation between authored keys plus Godot
   resampling a 24fps clip against `animation/fps=30` at a 60Hz physics
   tick, not by an error in the authored gait itself. Driving it to exactly
   zero needs either a linear-interpolation stance segment with matched
   clip/physics rates, or (the more robust long-term fix) extracting true
   root motion from the clip instead of hand-matching a scene-side speed
   constant — which would also remove the `WALK_STRIDE` duplication between
   `tools/author_anims.py` and `game/scenes/test/walk_test.gd` noted in §6.
