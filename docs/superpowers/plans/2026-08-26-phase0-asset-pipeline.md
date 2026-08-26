# Phase 0: Asset Pipeline Proof — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove community pony assets can be reliably converted into animated Godot characters, produce the repeatable pipeline scripts/docs, and generate the Phase 1 asset shopping list.

**Architecture:** Portable toolchain (Godot 4.5 + Blender 4.2 LTS downloaded into `tools/bin/`, no system installs) driving headless Blender Python scripts that convert sourced models (`.blend` native packs first, Sketchfab glTF second, SFM `.mdl` via the SourceIO addon last) into glTF, loaded by a Godot test project. Raw downloads live gitignored in `assets_raw/`; converted output in `game/assets/`.

**Tech Stack:** Godot 4.5 (GDScript), Blender 4.2 LTS (headless Python), SourceIO Blender addon (Source `.mdl` import), glTF 2.0, Hay Say (community pony voice generation, Docker) for the voice probe.

**Spec:** `docs/superpowers/specs/2026-08-26-filly-rancher-design.md`

## Global Constraints

- No system-level installs: all tools land in `tools/bin/` (portable builds); scripts must run without sudo.
- Everything must work identically on Linux x86_64 and Windows x86_64 (Godot project side; conversion tooling runs on Linux only).
- Godot 4.5 stable, Forward+ renderer, GDScript only.
- The user performs all website downloads (accounts/captchas/taste); scripts consume files already present in `assets_raw/`.
- Converted assets and raw downloads are never committed: `.gitignore` covers `assets_raw/`, `game/assets/converted/`, `tools/bin/`, `.godot/`, `build/`.
- Phase 0 is exploratory: where TDD doesn't apply (asset conversion), every task still ends with an explicit scripted verification step and a commit.

## Phase-0 exit criteria (from spec)

Three converted characters in a Godot scene, one walking a path with animations; documented + scripted conversion recipe (`docs/pipeline.md`, `tools/`); animation-strategy verdict; map-props probe scene; one PPP voice line + quality verdict; shopping list for Phase 1; Linux + Windows export smoke test.

## File Structure

```
filly-rancher/
├── docs/
│   ├── pipeline.md              # the recipe (Task 10)
│   ├── shopping-list.md         # user download list (Task 3)
│   └── superpowers/...          # specs & plans (exists)
├── tools/
│   ├── setup_env.sh             # fetch Godot+Blender portable (Task 1)
│   ├── bin/                     # gitignored tool installs
│   ├── export_blend.py          # Blender headless: .blend → glTF (Task 4)
│   ├── convert_mdl.py           # Blender headless: SourceIO .mdl → glTF (Task 6)
│   └── validate_gltf.py         # rig/anim/material checks on exported glTF (Task 4)
├── assets_raw/                  # gitignored user downloads, one folder per source
├── game/                        # the Godot project
│   ├── project.godot
│   ├── assets/converted/        # gitignored glTF output
│   ├── scenes/test/
│   │   ├── model_gallery.tscn   # 3 ponies on pedestals (Task 5)
│   │   ├── walk_test.tscn       # animated pony on a path (Task 7)
│   │   └── terrain_probe.tscn   # props-on-terrain probe (Task 8)
│   └── export_presets.cfg       # Linux + Windows presets (Task 9)
└── .gitignore
```

---

### Task 1: Portable toolchain setup

**Files:**
- Create: `tools/setup_env.sh`, `.gitignore`

**Interfaces:**
- Produces: `tools/bin/godot` and `tools/bin/blender/blender` executables; all later tasks invoke these exact paths.

- [ ] **Step 1: Write `.gitignore`**

```gitignore
assets_raw/
tools/bin/
game/assets/converted/
game/.godot/
build/
*.import
```

- [ ] **Step 2: Write `tools/setup_env.sh`**

```bash
#!/usr/bin/env bash
# Downloads portable Godot + Blender into tools/bin/. Idempotent. No sudo.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin && cd bin

GODOT_VER="4.5-stable"   # bump patch version here if 4.5.x exists
if [ ! -x godot ]; then
  curl -fLo godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip"
  unzip -o godot.zip && mv "Godot_v${GODOT_VER}_linux.x86_64" godot && rm godot.zip
fi

BLENDER_VER="4.2.3"
if [ ! -x blender/blender ]; then
  curl -fLo blender.tar.xz "https://download.blender.org/release/Blender${BLENDER_VER%.*}/blender-${BLENDER_VER}-linux-x64.tar.xz"
  tar xf blender.tar.xz && mv "blender-${BLENDER_VER}-linux-x64" blender && rm blender.tar.xz
fi

./godot --version
./blender/blender --version | head -1
echo "toolchain ready"
```

Before running: check https://github.com/godotengine/godot/releases for the latest 4.5.x stable and https://download.blender.org/release/Blender4.2/ for the latest 4.2.x, and pin those exact versions in the script.

- [ ] **Step 3: Run it and verify**

Run: `bash tools/setup_env.sh`
Expected: prints a `4.5.x.stable` Godot version line, a `Blender 4.2.x` line, then `toolchain ready`. Re-run once to confirm idempotency (completes fast, same output).

- [ ] **Step 4: Commit**

```bash
git add .gitignore tools/setup_env.sh
git commit -m "feat: portable Godot+Blender toolchain setup"
```

---

### Task 2: Godot project scaffold + headless smoke test

**Files:**
- Create: `game/project.godot`, `game/scenes/test/smoke.tscn`, `game/scenes/test/smoke_test.gd`

**Interfaces:**
- Produces: a Godot project at `game/` that later tasks add scenes to; the pattern `tools/bin/godot --headless --path game <scene> --quit-after 5` as the standard scene smoke test.

- [ ] **Step 1: Write minimal `game/project.godot`**

```ini
config_version=5

[application]
config/name="Filly Rancher"
run/main_scene="res://scenes/test/smoke.tscn"
config/features=PackedStringArray("4.5", "Forward Plus")

[rendering]
renderer/rendering_method="forward_plus"
```

- [ ] **Step 2: Write a smoke scene that prints and quits**

`game/scenes/test/smoke_test.gd`:
```gdscript
extends Node

func _ready() -> void:
    print("SMOKE_OK renderer=", RenderingServer.get_current_rendering_method())
    get_tree().quit(0)
```

`game/scenes/test/smoke.tscn`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/test/smoke_test.gd" id="1"]

[node name="Smoke" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: Run headless, verify**

Run: `tools/bin/godot --headless --path game scenes/test/smoke.tscn`
Expected: output contains `SMOKE_OK`, exit code 0. (First run also generates `.godot/` import caches — that's normal.)

- [ ] **Step 4: Commit**

```bash
git add game/
git commit -m "feat: Godot 4.5 project scaffold with headless smoke test"
```

---

### Task 3: Shopping list for the user  ⛔ USER CHECKPOINT

**Files:**
- Create: `docs/shopping-list.md`

**Interfaces:**
- Produces: `assets_raw/<source>/` folder convention that Tasks 4–9 consume. **Tasks 4+ are blocked until the user downloads these files.**

- [ ] **Step 1: Write `docs/shopping-list.md`**

The document must contain exactly these sections (research current links while writing — verify each URL resolves before listing it):

1. **Blender-native pony pack (tier a — highest priority).** The CreatorOfPony/MythicSpeed Mane 6 `.blend` pack (DeviantArt). Must include Twilight Sparkle plus at least 2 other characters. Save to `assets_raw/blender-native/`.
2. **One SFM model (tier c probe).** Any single background-pony `.mdl` model from PonySFM (with its `.vtx/.vvd/.vmt/.vtf` companion files — download the whole pack zip). Save to `assets_raw/sfm/`. This exists solely to prove the SourceIO path.
3. **Map props (Sketchfab, tier b).** 2–3 Ponyville-style buildings and a tree/foliage set, glTF or FBX direct download. Save to `assets_raw/props/`.
4. **Voice tooling note.** Link to Hay Say (hydrusbeta) and note it needs Docker; if the user prefers not to install Docker, note the alternative of a Hugging Face PPP model space. No download required yet — Task 9 handles it.
5. **A "how to hand off" note:** after downloading, unzip everything into the listed folders and tell Claude "assets are in".

- [ ] **Step 2: Commit and hand off**

```bash
git add docs/shopping-list.md
git commit -m "docs: Phase 0 asset shopping list"
```

Then STOP and tell the user: which files to fetch, into which folders. Do not proceed to Task 4 until the user confirms the tier-a pack is present (Tasks 6/8 can be deferred if their downloads lag).

---

### Task 4: `.blend` → glTF conversion script (tier a)

**Files:**
- Create: `tools/export_blend.py`, `tools/validate_gltf.py`

**Interfaces:**
- Consumes: `assets_raw/blender-native/*.blend` (from Task 3), `tools/bin/blender` (Task 1).
- Produces: `python3 tools/validate_gltf.py <file.glb>` validator used by Tasks 6–7; converted `game/assets/converted/ponies/<name>.glb` files consumed by Task 5. Invocation contract: `tools/bin/blender/blender -b <file.blend> -P tools/export_blend.py -- --out <out.glb> [--object <name>]`.

- [ ] **Step 1: Write `tools/export_blend.py`**

```python
"""Headless Blender: export a .blend (or one collection/object in it) to glTF.
Usage: blender -b file.blend -P tools/export_blend.py -- --out out.glb [--object Twilight]
"""
import argparse, sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--object", default=None, help="only export this object + its armature/children")
args = p.parse_args(argv)

if args.object:
    target = bpy.data.objects.get(args.object)
    if target is None:
        names = sorted(o.name for o in bpy.data.objects)
        sys.exit(f"object {args.object!r} not found; scene has: {names}")
    keep = {target} | set(target.children_recursive)
    for mod in getattr(target, "modifiers", []):
        if mod.type == "ARMATURE" and mod.object:
            keep |= {mod.object} | set(mod.object.children_recursive)
    for obj in bpy.data.objects:
        obj.select_set(obj in keep)
    use_selection = True
else:
    use_selection = False

bpy.ops.export_scene.gltf(
    filepath=args.out,
    export_format="GLB",
    use_selection=use_selection,
    export_apply=True,           # apply modifiers except armatures
    export_animations=True,
    export_skins=True,
    export_yup=True,
)
print(f"EXPORT_OK {args.out}")
```

- [ ] **Step 2: Write `tools/validate_gltf.py`**

```python
"""Sanity-check an exported .glb: mesh present, rigged, textured, lists animations.
Usage: python3 tools/validate_gltf.py file.glb [--require-anims]
Exits non-zero on failure. No deps beyond stdlib (parses GLB's JSON chunk).
"""
import json, struct, sys

path = sys.argv[1]
require_anims = "--require-anims" in sys.argv
with open(path, "rb") as f:
    magic, _ver, _length = struct.unpack("<4sII", f.read(12))
    assert magic == b"glTF", "not a GLB file"
    chunk_len, chunk_type = struct.unpack("<II", f.read(8))
    assert chunk_type == 0x4E4F534A, "first chunk not JSON"
    gltf = json.loads(f.read(chunk_len))

meshes = gltf.get("meshes", [])
skins = gltf.get("skins", [])
anims = [a.get("name", f"anim{i}") for i, a in enumerate(gltf.get("animations", []))]
mats = gltf.get("materials", [])
textured = any("baseColorTexture" in m.get("pbrMetallicRoughness", {}) for m in mats)

print(f"meshes={len(meshes)} skins={len(skins)} materials={len(mats)} "
      f"textured={textured} animations={anims}")
ok = bool(meshes) and bool(skins)
if require_anims:
    ok = ok and bool(anims)
sys.exit(0 if ok else f"VALIDATION FAILED for {path}")
```

- [ ] **Step 3: Inspect the downloaded pack, then convert Twilight + 2 others**

First list what's in the pack:
Run: `tools/bin/blender/blender -b assets_raw/blender-native/<pack>.blend --python-expr "import bpy; print(sorted(o.name for o in bpy.data.objects))"`

Then, per character (exact `--object` names come from that listing; some packs ship one file per pony — then omit `--object`):
Run: `mkdir -p game/assets/converted/ponies && tools/bin/blender/blender -b assets_raw/blender-native/<file>.blend -P tools/export_blend.py -- --out game/assets/converted/ponies/twilight.glb --object <TwilightObjectName>`
Expected: `EXPORT_OK` line per character; three `.glb` files exist.

- [ ] **Step 4: Validate all three**

Run: `for f in game/assets/converted/ponies/*.glb; do python3 tools/validate_gltf.py "$f" || echo "FAILED: $f"; done`
Expected: every file reports `meshes>=1 skins>=1`, `textured=True`, exit 0. If `textured=False`, the pack uses packed images or node setups glTF can't map — fix inside `export_blend.py` (e.g. `bpy.ops.file.pack_all()` before export) rather than by hand, so the recipe stays scripted. Record any per-pack quirks as comments in the script.

- [ ] **Step 5: Commit**

```bash
git add tools/export_blend.py tools/validate_gltf.py
git commit -m "feat: blend-to-glTF conversion + glb validator (tier a proven)"
```

---

### Task 5: Model gallery scene in Godot

**Files:**
- Create: `game/scenes/test/model_gallery.tscn`, `game/scenes/test/model_gallery.gd`

**Interfaces:**
- Consumes: the three `.glb` files from Task 4 (Godot auto-imports files under `game/assets/`).
- Produces: visual confirmation pattern + `GALLERY_OK` headless check used again in Task 7.

- [ ] **Step 1: Write the gallery scene**

`game/scenes/test/model_gallery.gd`:
```gdscript
extends Node3D
## Loads every pony .glb, spaces them on a line, verifies meshes+skeletons arrived.

const PONY_DIR := "res://assets/converted/ponies/"

func _ready() -> void:
    var loaded := 0
    var dir := DirAccess.open(PONY_DIR)
    for file in dir.get_files():
        if file.get_extension() != "glb":
            continue
        var scene: PackedScene = load(PONY_DIR + file)
        var inst := scene.instantiate()
        inst.position = Vector3(loaded * 3.0, 0, 0)
        add_child(inst)
        var skel := inst.find_child("Skeleton3D", true, false)
        print("LOADED ", file, " skeleton=", skel != null,
              " bones=", skel.get_bone_count() if skel else 0)
        loaded += 1
    print("GALLERY_OK count=", loaded)
    if DisplayServer.get_name() == "headless":
        get_tree().quit(0 if loaded >= 3 else 1)
```

`game/scenes/test/model_gallery.tscn` — a `Node3D` root with that script, a `DirectionalLight3D` (rotated ~-45° X), and a `Camera3D` at `(3, 2, 8)`:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/test/model_gallery.gd" id="1"]

[node name="Gallery" type="Node3D"]
script = ExtResource("1")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.707, 0.707, 0, -0.707, 0.707, 0, 10, 0)

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3, 2, 8)
```

- [ ] **Step 2: Headless verify**

Run: `tools/bin/godot --headless --path game scenes/test/model_gallery.tscn`
Expected: three `LOADED <name>.glb skeleton=true bones=<N>` lines (N > 20 for a real pony rig), `GALLERY_OK count=3`, exit 0.

- [ ] **Step 3: Visual verify (user)**

Run: `tools/bin/godot --path game scenes/test/model_gallery.tscn`
Ask the user to eyeball: correct colors, manes present, no missing-texture magenta. Record verdict in the task notes; a materials failure here reopens Task 4 Step 4.

- [ ] **Step 4: Commit**

```bash
git add game/scenes/test/model_gallery.tscn game/scenes/test/model_gallery.gd
git commit -m "feat: model gallery scene proving glb import into Godot"
```

---

### Task 6: SFM `.mdl` → glTF via SourceIO (tier c probe)

**Files:**
- Create: `tools/convert_mdl.py`
- Modify: `tools/setup_env.sh` (add SourceIO addon install)

**Interfaces:**
- Consumes: `assets_raw/sfm/` model files (Task 3), `tools/bin/blender` (Task 1), `tools/validate_gltf.py` (Task 4).
- Produces: verdict on the tier-c pipeline recorded for `docs/pipeline.md`; optionally a fourth `.glb`. Invocation contract: `tools/bin/blender/blender -b -P tools/convert_mdl.py -- --mdl <file.mdl> --out <out.glb>`.

- [ ] **Step 1: Extend `setup_env.sh` to install SourceIO**

Append before the final echo (check https://github.com/REDxEYE/SourceIO/releases for the latest release supporting Blender 4.2 and pin it):

```bash
SOURCEIO_VER="<latest release tag>"
ADDONS_DIR="$PWD/blender/${BLENDER_VER%.*}/scripts/addons"
if [ ! -d "$ADDONS_DIR/SourceIO" ]; then
  curl -fLo sourceio.zip "https://github.com/REDxEYE/SourceIO/releases/download/${SOURCEIO_VER}/SourceIO.zip"
  unzip -o sourceio.zip -d "$ADDONS_DIR" && rm sourceio.zip
fi
./blender/blender -b --python-expr "import bpy; bpy.ops.preferences.addon_enable(module='SourceIO'); bpy.ops.wm.save_userpref(); print('SOURCEIO_OK')"
```

Run: `bash tools/setup_env.sh`
Expected: `SOURCEIO_OK` in output.

- [ ] **Step 2: Write `tools/convert_mdl.py`**

```python
"""Headless Blender: import a Source-engine .mdl via SourceIO, export glTF.
Usage: blender -b -P tools/convert_mdl.py -- --mdl pony.mdl --out pony.glb
"""
import argparse, sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
p = argparse.ArgumentParser()
p.add_argument("--mdl", required=True)
p.add_argument("--out", required=True)
args = p.parse_args(argv)

bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.sourceio.mdl(filepath=args.mdl)   # operator id may differ per SourceIO version;
                                          # discover via: bpy.ops.sourceio.<TAB> listing if this fails
for img in bpy.data.images:               # Source textures arrive as VTF-decoded images; pack them
    if img.source == "FILE":
        img.pack()

bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB",
                          export_animations=True, export_skins=True, export_yup=True)
print(f"MDL_EXPORT_OK {args.out}")
```

- [ ] **Step 3: Run on the probe model and validate**

Run: `tools/bin/blender/blender -b -P tools/convert_mdl.py -- --mdl assets_raw/sfm/<model>.mdl --out game/assets/converted/ponies/sfm_probe.glb && python3 tools/validate_gltf.py game/assets/converted/ponies/sfm_probe.glb`
Expected: `MDL_EXPORT_OK`, validator passes with `skins=1`. Known likely issues to fix in-script if hit: wrong operator id (inspect SourceIO's operators), 40x scale factor (Source units are inches — add a 0.0254 scale-and-apply step), materials needing manual principled-BSDF rebuild.

- [ ] **Step 4: Record the tier-c verdict**

Write 3–5 sentences into the commit message and keep notes for `docs/pipeline.md` (Task 10): does tier c produce usable rigs? How much per-model manual work? Is the 1,000+ PonySFM catalog practically usable for Phase 2, or do we constrain the roster to tiers a/b?

- [ ] **Step 5: Commit**

```bash
git add tools/convert_mdl.py tools/setup_env.sh
git commit -m "feat: SourceIO mdl-to-glTF probe — <one-line verdict>"
```

---

### Task 7: Animation strategy + walking pony

**Files:**
- Create: `game/scenes/test/walk_test.tscn`, `game/scenes/test/walk_test.gd`
- Possibly modify: `tools/export_blend.py` (action-selection flag, if the pack stores animations as separate Actions)

**Interfaces:**
- Consumes: Twilight `.glb` (Task 4), gallery pattern (Task 5).
- Produces: the animation-strategy verdict (canonical-rig vs per-model animations) that the Phase 1 plan depends on; a `.glb` with `idle` and `walk` animations; `WALK_OK` headless check.

- [ ] **Step 1: Inventory what animations the sourced rigs actually have**

Run: `python3 tools/validate_gltf.py game/assets/converted/ponies/twilight.glb` and the other two, plus the SFM probe if Task 6 succeeded.
Record: animation lists per model, and whether the three tier-a rigs share bone names (compare via `--python-expr` bone-name dump in Blender). Shared bone names ⇒ canonical rig is cheap; divergent ⇒ per-model animations or manual retarget.

- [ ] **Step 2: Get idle + walk onto Twilight**

Path depends on Step 1 findings, in order of preference:
  a. Pack already ships walk/idle Actions → extend `export_blend.py` with `--actions idle,walk` (set `export_animations=True` exports all Actions when `export_animation_mode='ACTIONS'`; name them `idle`/`walk` in Blender data before export).
  b. No animations shipped → author a minimal 20-frame walk loop + 2-keyframe idle sway in Blender on Twilight's rig, scripted or saved as a `.blend` in `tools/anim_library.blend`, exported with the model.
Either way the deliverable is `twilight.glb` whose validator output includes `animations=['idle', 'walk']`.

Run: `python3 tools/validate_gltf.py game/assets/converted/ponies/twilight.glb --require-anims`
Expected: PASS, listing both animations.

- [ ] **Step 3: Write the walk-test scene**

`game/scenes/test/walk_test.gd`:
```gdscript
extends Node3D
## Twilight walks a square path using her 'walk' animation.

var pony: Node3D
var waypoints := [Vector3(4,0,4), Vector3(4,0,-4), Vector3(-4,0,-4), Vector3(-4,0,4)]
var target_idx := 0
var frames := 0

func _ready() -> void:
    pony = load("res://assets/converted/ponies/twilight.glb").instantiate()
    add_child(pony)
    var anim: AnimationPlayer = pony.find_child("AnimationPlayer", true, false)
    assert(anim != null, "no AnimationPlayer in glb")
    print("ANIMS ", anim.get_animation_list())
    anim.play("walk")

func _physics_process(delta: float) -> void:
    var target: Vector3 = waypoints[target_idx]
    var to_target := target - pony.position
    if to_target.length() < 0.2:
        target_idx = (target_idx + 1) % waypoints.size()
    else:
        pony.position += to_target.normalized() * 2.0 * delta
        pony.look_at(target, Vector3.UP)
    frames += 1
    if frames == 300 and DisplayServer.get_name() == "headless":
        print("WALK_OK laps_progress=", target_idx)
        get_tree().quit(0 if target_idx >= 1 else 1)
```

`game/scenes/test/walk_test.tscn` — same skeleton as the gallery tscn (root `Node3D` with this script, `DirectionalLight3D`, `Camera3D` at `(0, 6, 12)`), plus a 20×20 `MeshInstance3D` with a `PlaneMesh` floor.

- [ ] **Step 4: Verify headless + visual**

Run: `tools/bin/godot --headless --path game scenes/test/walk_test.tscn`
Expected: `ANIMS` list containing walk, `WALK_OK laps_progress>=1`, exit 0.
Then run windowed for the user: legs should move (not sliding statue), no T-pose, correct facing. User verdict recorded.

- [ ] **Step 5: Commit (message includes the strategy verdict)**

```bash
git add game/scenes/test/walk_test.* tools/export_blend.py
git commit -m "feat: animated walk test — anim strategy: <canonical-rig | per-model>"
```

---

### Task 8: Map-props probe

**Files:**
- Create: `game/scenes/test/terrain_probe.tscn`, `game/scenes/test/terrain_probe.gd`

**Interfaces:**
- Consumes: `assets_raw/props/` downloads (Task 3); `export_blend.py`/direct glTF copy for conversion.
- Produces: verdict on the props-on-Godot-terrain approach for the Phase 1 ranch map.

- [ ] **Step 1: Convert/copy props**

glTF props: copy into `game/assets/converted/props/`. FBX props: convert via Blender (`blender -b --python-expr` importing FBX then reusing the glTF export from `export_blend.py` logic). Validate each with `validate_gltf.py` (skins not required — that check only gates on meshes when there's no rig; adjust the call: props validate as `meshes>=1`).

- [ ] **Step 2: Build the probe scene**

`terrain_probe.tscn`: `Node3D` root + script, `DirectionalLight3D`, `Camera3D`, and a ground `MeshInstance3D` (`PlaneMesh`, 60×60, a grass-green `StandardMaterial3D` albedo). `terrain_probe.gd` mirrors `model_gallery.gd` but loads from `res://assets/converted/props/`, scatters instances at hardcoded positions, prints `PROBE_OK count=N`, quits headless.

- [ ] **Step 3: Verify headless + visual**

Run: `tools/bin/godot --headless --path game scenes/test/terrain_probe.tscn`
Expected: `PROBE_OK count>=3`, exit 0. Windowed run for the user: does it read as "a place in Ponyville"? Scale sane relative to Twilight (drop her in via one extra load call if needed)? Verdict recorded for the Phase 1 ranch-map plan.

- [ ] **Step 4: Commit**

```bash
git add game/scenes/test/terrain_probe.*
git commit -m "feat: props-on-terrain probe scene"
```

---

### Task 9: Voice-line probe (PPP / Hay Say)

**Files:**
- Create: `game/assets/audio/voice/twilight/greeting_01.wav` (committed — small, and it's a deliverable), `docs/notes-voice.md`

**Interfaces:**
- Produces: the voice-quality verdict (PPP vs paid fallback) the Phase 4 spec depends on; the `voice/<character>/<category>_<nn>.wav` naming convention.

- [ ] **Step 1: Check Docker availability**

Run: `command -v docker && docker info >/dev/null 2>&1 && echo DOCKER_OK || echo NO_DOCKER`
If NO_DOCKER: ask the user whether to install Docker (their call — system-level) or use a hosted PPP model (Hugging Face space) in the browser instead. Record the choice.

- [ ] **Step 2: Generate one line**

Target line: "Welcome to the ranch! I'm so excited to meet you!" in Twilight's voice, via Hay Say (Docker route: follow https://github.com/hydrusbeta/hay_say_ui — user drives the web UI, Claude preps the text) or the hosted-space route. Save output as `game/assets/audio/voice/twilight/greeting_01.wav`, 44.1kHz mono.

- [ ] **Step 3: Verdict**

Play it for the user (`tools/bin/godot` isn't needed — any player). User judges: shippable / usable-but-meh / bad. Write `docs/notes-voice.md`: tool used, steps, time cost per line, verdict, and the go/no-go on generating ~100 lines this way in Phase 4 vs paying for ElevenLabs.

- [ ] **Step 4: Commit**

```bash
git add game/assets/audio/voice/twilight/greeting_01.wav docs/notes-voice.md
git commit -m "feat: first PPP voice line + tooling verdict"
```

---

### Task 10: Pipeline docs + cross-platform export smoke test

**Files:**
- Create: `docs/pipeline.md`, `game/export_presets.cfg`

**Interfaces:**
- Consumes: everything above.
- Produces: the Phase 0 exit deliverable — the recipe a future session follows verbatim; `build/` exports for both platforms.

- [ ] **Step 1: Install export templates**

Run: `tools/bin/godot --headless --path game --install-export-templates` (Godot 4.5 supports headless template install; if the flag is unavailable in the shipped build, download the matching `.tpz` from the same GitHub release as Task 1 and unzip into `~/.local/share/godot/export_templates/<full-version>/`).
Verify: `ls ~/.local/share/godot/export_templates/` shows the 4.5.x folder.

- [ ] **Step 2: Write `game/export_presets.cfg`** with two presets:

```ini
[preset.0]
name="Linux"
platform="Linux"
runnable=true
export_filter="all_resources"
export_path="../build/filly-rancher-linux.x86_64"

[preset.0.options]
binary_format/architecture="x86_64"

[preset.1]
name="Windows"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
export_path="../build/filly-rancher-windows.exe"

[preset.1.options]
binary_format/architecture="x86_64"
```

- [ ] **Step 3: Export both and smoke test**

Run:
```bash
mkdir -p build
tools/bin/godot --headless --path game --export-release "Linux" ../build/filly-rancher-linux.x86_64
tools/bin/godot --headless --path game --export-release "Windows" ../build/filly-rancher-windows.exe
./build/filly-rancher-linux.x86_64 --headless
ls -la build/
```
Expected: both exports complete without errors; the Linux binary run prints `SMOKE_OK` (main scene is still smoke.tscn); `filly-rancher-windows.exe` + `.pck` exist. The Windows exe gets smoke-tested by the friend (or under wine if ever installed) — note in pipeline.md that Windows verification is remote.

- [ ] **Step 4: Write `docs/pipeline.md`**

Must contain, with exact commands (copy from the tasks as actually run, including every deviation discovered):
1. Toolchain setup (`tools/setup_env.sh`).
2. Tier a recipe: `.blend` → glb (per-pack quirks table).
3. Tier b recipe: glTF/FBX props.
4. Tier c recipe: SourceIO `.mdl` path + the Task 6 verdict on bulk viability.
5. Animation strategy verdict + how to add animations to a new character.
6. Validation + gallery/walk smoke-test commands.
7. Voice-line recipe + verdict.
8. Export commands for both platforms.
9. Folder conventions (`assets_raw/<source>/`, `game/assets/converted/<kind>/`, `voice/<character>/<category>_<nn>.wav`).

- [ ] **Step 5: Final Phase 0 exit check + commit**

Walk the spec's Phase 0 exit criteria list; each item must map to a committed artifact. Then:
```bash
git add docs/pipeline.md game/export_presets.cfg
git commit -m "docs: asset pipeline recipe; feat: cross-platform export presets — Phase 0 complete"
```
Report Phase 0 verdicts to the user and propose starting the Phase 1 plan.
