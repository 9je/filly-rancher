# Phase 3 Dressing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dress the shipped map with real My Little Pony scenery converted out of the six PonySFM prop packs staged in `assets-inbox/`: the Sweet Apple Acres barn and its yard on the walk out to the Orchard, apple trees in place of the flat colour Kenney oaks around it, Ponyville General standing across the Market yard with its sign at the Market door, a row of Ponyville town buildings and a schoolyard on the road north, the two Las Pegasus arcade games on the Strip, and hay, carts, crates, baskets and a well scattered round the homestead; with a repeatable conversion script, a texture budget, a gallery gate that proves every converted prop loads with its materials, and every census consequence carried.

**Architecture:** Nothing here invents a pipeline. The conversion is `docs/pipeline.md` section 5's proven tier c path (SourceIO's `bpy.ops.sourceio.mdl` into Blender, `export_scene.gltf` out) driven from a committed manifest by a new `tools/convert_props.sh`, the exact shape `tools/convert_roster.sh` already has for characters, with one additive flag on `tools/convert_mdl.py` that caps texture resolution before the export packs them. The map side is `game/world/props.gd`'s existing `LAYOUT` table: entries gain a `family` key so a show scale asset is not multiplied by a Kenney kit factor, and wide mesh props gain a plinth of their own, because `Props.seat()` anchors an entire model to the ground height at ONE point and the flattest 13 by 10 metre rectangle anywhere outside the homestead apron has 0.36 m of relief across it. The procedural `Building`s stay exactly where they are and keep every door the game walks through; the MLP models are scenery.

**Tech Stack:** Godot 4.5.2, GDScript, GUT 9.5.0, portable Blender 4.2.23 with the SourceIO addon, Python 3 stdlib, the project's headless gate conventions.

**Spec:** The owner's 2026-08-31 verdict on the asset hunt, recorded in `assets-inbox/INVENTORY.md`: "i think we should look for more mlp farm assets", "id prefer mlp themed assets". The evidence this plan argues from is `assets-inbox/INVENTORY.md` (the PonySFM haul section at the bottom) and the nine model conversion probe whose findings are reproduced in full under "What the probe found" below, since that probe's own writeup lives in a scratchpad and does not travel with the repository.

## Global Constraints

- **No em dash and no double hyphen in ANY player facing string, nor in new code, comments, docs or data.** ASCII banners like `# --- x ---` are exempt, and so are command line flags (`--props`, `--force`, `--max-texture`). Use ";" or ":" or commas. Single hyphens inside a word are fine. The files you are editing are full of pre existing ` -- ` in their own comments: leave those alone, and do not copy the habit into a line you write.
- **Tone.** Slime Rancher for the ranching feel, Stardew Valley for the town, gambling for fun, a dark humour register. Never grim, never sneering at the player. Any new copy in this slice is scenery naming and doc prose; keep it plain and dry rather than whimsical.
- **Explicit type annotations wherever `:=` cannot infer the type.** Godot 4.5 promotes `INFERENCE_ON_VARIANT` to an error on the preload dependency compile path; GUT's loader does not catch it, `tools/run_tests.sh`'s parse sweep does. `entry["at"]`, `entry.get("family", ...)` and every `Dictionary` read in this plan is a Variant and needs one.
- **Preload by `res://` path, never by the global `class_name`, in production code AND in test code.** Every construction (`X.new()`), every static call (`X.some_static()`) and every constant read (`X.SOME_CONST`) goes through a `const XScript := preload("res://...")` at the top of the file. A bare `class_name` may appear ONLY as a type annotation.
- **Every new `.gd` gets its `.uid` sidecar committed.** After creating a script run `tools/bin/godot --headless --path game --import` once and `git add` the generated `game/**/*.gd.uid`.
- **NO PONY EVER DIES.** Only `Pony._state_leaving` may call `queue_free()` on a pony. Nothing in this plan frees, harms, moves or removes a pony. Props are placed before `spawner.populate()` runs, exactly as they are today, so a pony is never standing where one appears.
- **Converted binary assets are NOT committed, and that is a decision this plan makes rather than inherits.** See "The gitignore decision" below for the reasoning and the cost. `game/assets/converted/` stays gitignored in full; `tools/prop_manifest.txt` plus `tools/convert_props.sh` are what travel, and one command regenerates the tree.
- **Every count consequence is carried through the gates and the docs in the SAME COMMIT that causes it.** `RANCH_OK ponies=49 props=60 assets=present` is quoted verbatim in `docs/distribution.md` (twice), `docs/testing.md`, `docs/pipeline.md` (twice) and `docs/windows-testing.md`. Task 4 moves it to 94 and Task 5 to 110; each task rewrites every one of those six lines in its own commit. Gate check counts that move are re-read from the gate's own output and written into `docs/testing.md` in the task that moves them; never guess one.
- **`MIN_TESTS` in `tools/run_tests.sh` stands at 1162 today.** Raise it in the final task to the number the suite actually reports; do not guess it.
- **Branch: `phase3-dressing`.** Commit after every task with `git commit -F <file>`; conventional prefixes (`feat:`, `fix:`, `test:`, `docs:`). Run `bash tools/run_tests.sh` (no `FILLY_SKIP_SWEEP`) before calling any task finished.
- **A new or regenerated `.glb` needs one editor import pass before the suite will see it.** `tools/bin/godot --headless --path game --import`. `docs/testing.md` section "Quirk / gotcha 3" is the symptom if you skip it: about nineteen red tests and no hint why.

---

## What the probe found

A nine model conversion probe was run against these packs on 2026-08-31, following `docs/pipeline.md` section 5 exactly. Its findings, which this plan is built on:

- **9 of 9 conversions were clean, first attempt, zero failures.** Every model imported, exported and rendered fully textured. No VTF or VMT resolution failures, no missing meshes, no manual content root configuration: SourceIO's `ContentManager` found each pack's sibling `Materials/` tree on its own, exactly as section 5 documents for the reVAmped ponies. All nine reported `textured=True` with `missing_images=[]`.
- **The nine, with their triangle counts:** `barn_base` 20,321 tris and 8 materials; `barn_gb` 4,408 and 2; `apple_tree` 6,768 and 3; `corn_plant` 2,430 and 1; `ponyville_general_building` 58,034 and 4; `ponyville_general_sign` 20,456 and 1; `tower_b` 6,571 and 4; `crate_empy` 28 and 1; `skeeball_game` 33,712 and 2. The 28 triangle crate is a plain box with the plank detail painted into the texture, confirmed by looking at the render.
- **`gb_` prefixed and `_gb` suffixed models are GROUND PATCHES, not building parts.** `barn_gb` renders as a dirt and grass patch with a white paddock fence and worn path rings, meant to sit under the barn. Every real building in `ponysfm-environments` has a `gb_` sibling that is its ground decal. A naive glob would convert about fifty flat ground planes believing they were buildings while missing the ten real ones.
- **Texture size is the one real cost.** `barn_base.glb` alone is 34 MB, almost all of it baked in PNG at native VTF resolution. Converting all 330 models at that rate would produce a multi gigabyte tree. A downscale step at export time is required, and this plan adds one.

Two things this plan establishes on top of the probe, verified against the staged files:

- **`_m` suffixed models are mirrored duplicates.** `barn_base.mdl` and `barn_base_m.mdl` are both 3,108 bytes with their own `.vvd` and `.dx90.vtx` siblings; `hay_pile.mdl` and `hay_pile_m.mdl` are both 1,780. Every model in the Sweet Apple Acres and Ponyville Environments packs has one. They are filtered alongside `gb_`.
- **The Ponyville Schoolhouse pack contains no schoolhouse.** Listed in full, `ponysfm-schoolhouse/SFM/models/` ships `school_roof.mdl`, `school_door.mdl`, `school_window.mdl`, `school_sign.mdl`, `porchroof.mdl`, `porchtop.mdl`, `support_beam_school.mdl` and `belltower.mdl`, and no assembled building: it is a modular kit for a Source map, the same trap `docs/pipeline.md` section 4 quirk 5 records for the Kenney Fantasy Town Kit. This plan therefore places a SCHOOLYARD (bell tower, sign, swings, horseshoe pit, tetherball pole, picnic table, cones) and no schoolhouse, and records the finding.

---

## What is on disk today

Read this before starting. Everything below was verified against `master` at `618126d`.

**The props.** `game/world/props.gd` holds `LAYOUT`, 54 dictionary entries of `{"file", "at": Vector2, "yaw": float, "s": float?}`, and builds them in `build()`. `PROP_DIR` is `res://assets/converted/props/`, scanned at runtime with `ResourceLoader.exists()` rather than referenced from the scene file, because `game/assets/converted/` is gitignored and a static `ext_resource` would break every CI export (`docs/ci.md` section 4). `BASE_SCALE` is 1.5 (derived in `docs/pipeline.md` section 4), `TREE_SCALE` is 3.0 and applies to any file whose name begins with `kenney_tree`, `SCALE_FIX` carries one entry correcting `kenney_survival_structure.glb`'s 4x FBX undersizing, and `SINK_BIAS` is 0.05 m. `expected_count()` is the number of LAYOUT entries whose asset exists on this machine; `has_assets()` is whether any does. `seat(node, ground)` is a static that shifts a node until the bottom of its world AABB sits `SINK_BIAS` below `ground`, and `world_aabb(root)` is the static that measures it over every `MeshInstance3D` under `root`. `_add_collision()` calls `create_trimesh_collision()` per `MeshInstance3D` and puts every generated `StaticBody3D` on `Layers.PROPS`. `is_in_pen_plots(x, z)` guards the 18 m square at `PEN_PLOTS_CENTRE` `Vector2(-14, 13)` with `PEN_PLOTS_HALF_EXTENT` 9.0.

**The buildings.** `game/world/building.gd` assembles a gabled shell from `_slab()` boxes with a `StandardMaterial3D` at `roughness = 0.9`. It is a `StaticBody3D` and IS its own collider. `FLOOR_TOP` 0.85 and `SKIRT_DEPTH` 1.20 make its floor a plinth, `PLINTH_INSET` 0.06 keeps the plinth's outer face from being coplanar with the wall above it, and `DOOR_APRON_RUN` 2.8 turns the 1.80 m rise into a 32.7 degree ramp. `footprint_relief()` and `seat_ground(height_at)` are how `ranch.gd` seats a building against the LOWEST corner of its footprint instead of the point under its origin. `MIN_DOOR_CLEARANCE` is 2.25 m and is asserted, because a pony is 2.138 m to the horn tip. The class comment states in as many words that the Kenney kit has no buildings in it and that "the real fix is an asset task": this is that task, and it does NOT replace these buildings. See "The homestead barn decision" below.

**The census.** `ranch.gd`'s `_report()` computes `expected_props` as `Props.expected_count() + buildings.get_child_count()`. `buildings.get_child_count()` is 6: `Barn`, `Farmhouse`, `Market`, `Board`, `Depot`, `Palace`. 54 + 6 = 60, which is the `props=60` every doc quotes. `_all_props()` is `props.get_placed()` plus the `Buildings` children; every prop in it is checked for at least one collision shape, for the `PROPS` layer on every `StaticBody3D` under it, for not intruding on the pen plot clearing, and for a seating error under `SEATING_TOLERANCE` (0.02 m) against `terrain.height_at()` at its origin, or against `Building.seat_ground()` for a `Building`. The `Strip`'s lamp posts are DELIBERATELY not props and are not counted; `Attendants` are neither props nor ponies and are not counted.

**The map.** `game/world/terrain.gd` is a deterministic heightfield: `HALF` 110, `CELL` 2.0, flat to exactly `y = 0` inside `FLAT_RADIUS` 30.0 of `HOMESTEAD_CENTRE` `Vector2(0, -4)`, easing to full relief by `BLEND_RADIUS` 44.0. `height_at()` is the one source of truth and has no RNG in it, so relief under any footprint can be computed offline; the numbers in this plan were. Regions are `game/data/regions/*.tres`: `orchard` centre `(72, 40)` radius 22 permit 150 gate yaw 180, `everfree` `(-74, -49)` radius 24, `lake` `(60, -62)` radius 24, `nightmeadow` `(-61, 69)` radius 24, `strip` `(0, 74)` radius 26 permit 0 (free, so it has no fence). `RegionFence.RING_MARGIN` is 3.0, so a priced region's timber stands at radius + 3.

**The clearances a prop has to respect.** `props.gd`'s own comment states the rule the existing region trees follow: every one stands at least 4 m past the fence ring, which is radius + 7, and outside every `ZoneMarker` disc. `ZoneMarker.outer_bound()` is `spawn_radius + roam_radius + ROAM_OVERSHOOT` (1.15). On the shipped map that is `NorthMeadow (2, -42)` 18.15, `EastField (40, 8)` 18.15, `SouthOrchard (-30, 38)` 15.15, `HomePasture (7, 19)` 12.15, `WestHollow (-42, -20)` 14.15, `Orchard (72, 40)` 21.15, `Everfree (-74, -49)` 20.15, `Lake (60, -62)` 25.15, `NightMeadow (-61, 69)` 25.15. The six existing Orchard trees all sit at exactly radius 31 from `(72, 40)`, which is the rule made concrete.

**The Strip.** `game/world/strip.gd` builds a ten position lamp ring of radius 21 centred on the region centre `(0, 74)`, at 36 degree steps starting at angle 0. `avoid_footprint()` drops the one position that lands inside the Palace's own rectangle plus `PALACE_CLEARANCE` 1.5, so a built Strip reports nine lamps. `Buildings/Palace` is at `(-10, 0, 61.6)`, 14 by 9, so its footprint is x in [-17, -3], z in [57.1, 66.1]. `game/world/race_track.gd` runs six 2.2 m lanes centred on `(0, 80)` from `START_X` -20 to `FINISH_X` 20 with a paddock at x = -22 and rails at z = 72.2 and z = 87.8. The clear ground on the Strip is the band between the Palace and the south rail: roughly x in [-2, 18], z in [67, 72].

**The interact verb.** `game/world/interaction.gd` is a pure resolver over candidates `ranch.gd` gathers. The building radii are `MARKET_RADIUS` 4.5, `BOARD_RADIUS` 3.0, `DEPOT_RADIUS` 4.0, `PALACE_RADIUS` 6.0, all measured XZ from the building node's origin. Nothing in that resolver knows what a prop is, and nothing in this plan changes that: a prop is never a candidate.

**The conversion tools.** `tools/convert_mdl.py` is 70 lines: parse `--mdl` and `--out`, `read_homefile(use_empty=True)`, `bpy.ops.sourceio.mdl(directory=..., files=[{"name": ...}])`, pack every `FILE` sourced image, `export_scene.gltf(export_format="GLB")`, print `MDL_EXPORT_OK <path>`. `tools/validate_gltf.py` takes `--props` for a `meshes>=1` gate with no skin required and prints `meshes=N skins=N materials=N textured=BOOL animations=[...]`. `tools/convert_roster.sh` is the manifest driver to copy: it reads `id|kind|source|rig` lines, skips a line whose output already exists unless `--force`, honours `--only` and `--dry-run`, sends each Blender run's output to `${TMPDIR:-/tmp}/convert_<id>.log`, redirects both tools' stdin from `/dev/null` because the loop reads the manifest on stdin, removes a `.glb` that exported but failed validation, and ends with `ROSTER_CONVERT ok=N failed=N skipped=N` whose exit code is the verdict. `tools/test_convert_roster.sh` exercises that logic in seconds against `FILLY_EXPORTER`, `FILLY_VALIDATOR` and `FILLY_OUT_DIR` stubs with no Blender involved. Both are the templates for this slice's props equivalents.

**The gallery.** `game/scenes/test/model_gallery.gd` globs `res://assets/converted/ponies/`, has `--stock` and `--mark` modes selected from `OS.get_cmdline_user_args()`, arms `GateWatchdog.arm(self, "GALLERY")` and prints `GALLERY_OK count=N`, quitting non zero under a headless display if fewer than three loaded. This slice adds a `--props` mode alongside those.

**The tests that will break.** `game/test/test_ranch_world.gd` has `test_every_layout_entry_names_a_prop_from_the_converted_kit()`, which asserts every LAYOUT file `begins_with("kenney_")`. Task 4 must widen it. The same file's `test_the_undersized_fbx_prop_still_carries_its_scale_correction()` and `test_the_prop_scale_factor_is_the_one_the_pipeline_validated()` read `SCALE_FIX` and `BASE_SCALE`; both constants survive this plan unchanged, so both tests keep passing.

**The staged packs.** All under `assets-inbox/`, which is gitignored. Verified present: `ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/` with 54 `.mdl` files including `barn_base`, `shed`, `wagon`, `hay_pile`, `hay_block`, `wire_arch`, `water_chute`, `corn_plant`, `fence_old`, `seed_bag`, `tree_narrow`, `tree_wide`; `ponysfm-scenebuild/MLP Scenebuild Props/models/props_pony/` with 17 including `apple_tree`, `crate_empy`, `empty_crate_long`, `basket`, `basket_handle`, `bush`, `jar`, `farm_well`, `chicken_coop`; `ponysfm-general-building/models/MLP_Props/Ponyville_General/Building/` with `ponyville_general_building` and `ponyville_general_sign`; `ponysfm-environments/models/Ponyville_Environments/` with `tower_b`, `wide_b`, `pink_b`, `courtyard_b`, `balcony_b`, `bridged_b`, `ogb_1`, `ogb_2` and their `gb_` and `_m` siblings; `ponysfm-las-pegasus/models/mlp_props/las_pegasus/games/` with `skeeball_game` and `dance_game`; `ponysfm-schoolhouse/SFM/models/` with 64 including `belltower`, `school_sign`, `swingframe`, `playgroundhorseshoe`, `teatherpoll`, `picnictable`, `school_cone`. Every pack has its `materials/` tree as a sibling of its `models/` tree, which is the layout SourceIO's content root discovery wants.

---

## The four decisions this plan makes, and why

### The gitignore decision: converted props stay OUT of git

`game/assets/converted/` is gitignored in full today, and this plan keeps it that way rather than carving out `game/assets/converted/props/`.

**Why.** Three reasons, in the order they matter.

1. **The whole architecture already assumes an assetless checkout is normal, and committing half the tree would break that meaning.** `Props.has_assets()`, `ranch.gd`'s `assets=present|partial|absent` state, the `RANCH NOTE assets=...` explainer, `docs/ci.md` section 4's entire argument and its "expected in CI" troubleshooting row are all built on "the converted tree is either there or it is not". Commit the props and CI's steady state stops being `assets=absent` and becomes `assets=partial`, which is currently the signal that something is HALF broken. Three documents would have to be reworded to say that the state that means "something went wrong" is now the state that means "everything is fine".
2. **The `.import` sidecar rule.** `.gitignore` carries a deliberate, commented exception: only the sidecars of GENERATED assets are ignored, because "any asset committed to the repo must ship its sidecar too, or Godot regenerates it independently on each machine and the resource UIDs diverge". Committing the props means committing 35 machine generated `.glb.import` files whose UIDs came out of one particular editor run, and the first person to reimport gets a diff.
3. **Size, in a history that never forgets.** These are 35 texture heavy models. Even after the downscale step this plan adds, they are tens of megabytes, and a git blob is forever: a later retune of `--max-texture` rewrites every one of them and pays the cost again.

**The cost, stated plainly.** A fresh clone has no props, exactly as it has no ponies today. The render checklist in Task 6 can only be done on a machine that has the packs. Regeneration is one command, `bash tools/convert_props.sh`, and it is the same shape as the `bash tools/convert_roster.sh` a fresh clone already has to run for the characters.

**The worktree convention, which is currently undocumented and needs to be.** `.claude/worktrees/*/game/assets/converted` is a SYMLINK to the main checkout's `game/assets/converted`. That is why a worktree has ponies without running the pipeline. Two consequences worth writing down, and Task 1 writes them into `docs/pipeline.md`: converting in a worktree writes into the MAIN checkout's tree, so the conversion only ever has to be paid once; and an abandoned branch that converted something leaves it behind on master's disk, where `Props.build()` will ignore it because nothing in `LAYOUT` names it.

### The seating and z fighting decision: wide mesh props get a skirt

`Props.seat(node, ground)` shifts a node until the bottom of its world AABB is `SINK_BIAS` below the ground height at ONE point. That is correct for a tree and wrong for a barn, and `game/world/building.gd`'s entire `FLOOR_TOP` / `SKIRT_DEPTH` / `PLINTH_INSET` / `DOOR_APRON_RUN` block exists because the same problem was found and fixed for the procedural buildings on 2026-08-31 (the owner's "z fighting at the palace base, a flickering skirt where the building meets terrain").

A mesh prop cannot use Building's answer, because Building BUILDS its own plinth and a `.glb`'s floor is whatever the modeller drew. So:

**Every prop entry may carry `"skirt": true`. A skirted prop is seated against the LOWEST of nine samples across its own footprint rather than the height under its origin, and gets a solid box under it, inset on every side, deep enough to bridge the measured relief.** The terrain then always passes through the SIDE of an opaque box, never through a horizontal face, which is exactly the property Building's own comment says the plinth buys. `SKIRT_INSET` is 0.06 for the same reason `PLINTH_INSET` is: a skirt whose outer face is coplanar with the model's own side is two surfaces fighting for the same pixels.

**How deep.** Computed live, `relief + SKIRT_MIN_DEPTH`, not typed in. `SKIRT_MIN_DEPTH` is 0.90 m, comfortably over the worst relief this map can put under a wide footprint. The numbers, computed offline against `terrain.height_at()` and reproduced here so the constant has a source: over a 13 by 10 m footprint the relief is 0.643 m at the barn's site `(41.0, 51.3)`, and the LOWEST it gets anywhere on the map outside the flat apron, searched at every metre in the whole orchard approach, is 0.366 m. There is no siting that avoids this; the plinth is the answer, not a better spot.

**Which props need it.** Any prop whose footprint's longer side exceeds `WIDE_FOOTPRINT` (4.0 m) and which stands outside `Terrain.is_flat_at()`. That rule is not left to memory: `ranch.gd` checks it against the LIVE measured AABBs of the placed props and fails if an entry that needs a skirt does not have one. Inside the flat apron the ground is exactly `y = 0` by construction, so `Ponyville General` at `(19, -2)` measures 0.000 m of relief and needs nothing.

**What about the step at a door.** A skirted prop's floor sits at the lowest footprint sample, so on the high side the ground can rise up to the measured relief into the skirt's flank: at the barn, 0.643 m. Building needed a 2.8 m ramp because its rise is 1.80 m; nothing here needs one, because **MLP mesh props are SCENERY and are never walked into.** No attendant stands at one, no dock marker sits on one, no interaction candidate names one, and the only buildings the player enters stay procedural `Building`s with their asserted `MIN_DOOR_CLEARANCE` and their apron. Task 5 adds the check that keeps that true: no prop's collider may reach inside any building's interaction radius.

### The homestead barn decision: it stays procedural, and the SFM barn is Sweet Apple Acres

`game/world/building.gd`'s class comment gives two reasons its buildings are code, and both still hold.

1. **It is in git.** A converted barn is gitignored, so CI and a fresh clone would have no skyline, and the camera versus a real wall check that `Building` exists to make possible would stop running anywhere but the owner's machine.
2. **Its door is sized from the measurement that matters** and asserted against `MIN_DOOR_CLEARANCE`. The Sweet Apple Acres barn's doorway is whatever a 2015 Source modeller drew, and nothing checks it.

There is a third reason, and it is the good one: **the Sweet Apple Acres barn is not the player's barn.** It is Applejack's, it belongs at an apple orchard, and this map has one. So the homestead keeps its red `Building` barn and gets MLP hay, a cart, crates, a well and a chicken coop scattered round it, and `saa_barn.glb` stands on the walk out to the Orchard region with a shed, a cart, a hay pile, a wire arch and a corn patch around it. `docs/pipeline.md` section 4 quirk 5 explicitly names "find a pack that ships whole buildings" as the outstanding asset task; Task 4 marks it resolved.

### The Market decision: Ponyville General stands beside, not instead

The Market is a `Building` at `(-2, 0, -1)`. Replacing it with a mesh would drop it out of `buildings.get_child_count()` and therefore out of the census; lose the door apron that `ATTENDANT_CLEARANCE` steps the vendor sideways out of; and put a 58,034 triangle two storey shop where a 4.5 m radius interaction check expects an origin. So the Market stays.

`kenney_survival_structure.glb` is what makes room for the General. `docs/pipeline.md` section 4 quirk 5 calls it an open timber frame that "reads as farm equipment abandoned in a field", and `props.gd` places it at `(14, 2)` calling it "the barn beside the yard". Task 4 retires that ONE entry from `LAYOUT` and stands `pv_general.glb` at `(19.0, -2.0)` facing back across the yard: inside the flat apron so its relief is exactly zero, 21.0 m from the Market origin so nothing about `MARKET_RADIUS` or the vendor changes, 10.8 m from the Depot, 11.2 m from the Farmhouse. `pv_general_sign.glb` stands at `(-1.0, 5.0)`, 6.1 m out from the Market origin: past the 4.5 m interaction radius and past the 2.8 m door apron, so it dresses the Market door without standing in it.

`SCALE_FIX` keeps its `kenney_survival_structure.glb` entry and gains a line saying the prop is retired from `LAYOUT` but that the correction stands recorded for anyone who re places it. That keeps `game/test/test_ranch_world.gd`'s existing assertion green and keeps the measured defect written down where `docs/pipeline.md` points at it.

---

## File structure

**New:**

| File | Responsibility |
|---|---|
| `tools/prop_manifest.txt` | The curated set: 35 lines of `id\|source`, the `.mdl` path relative to the pack root. The one place the curation lives. |
| `tools/convert_props.sh` | Manifest driver. Refuses ground patches and mirrored duplicates by name, runs one Blender per model, validates with `--props`, prints `PROP_CONVERT ok=N failed=N skipped=N refused=N`. |
| `tools/test_convert_props.sh` | Self test for the driver against stubs, seconds, no Blender. |
| `game/test/test_props.gd` | The prop layout and the seating rules as data and as pure functions: family scales, the skirt rule, `footprint_relief()`, the clearance invariants over the whole shipped `LAYOUT`. |

**Modified:** `tools/convert_mdl.py` (a `--max-texture` flag), `game/world/props.gd` (families, footprint seating, skirts, harmonised materials, ~50 new `LAYOUT` entries), `game/world/ranch.gd` (the new prop checks and report lines, five new screenshots), `game/scenes/test/model_gallery.gd` and `.tscn` (a `--props` mode), `game/test/test_ranch_world.gd` (the widened source check), `tools/run_tests.sh` (`MIN_TESTS`), `docs/pipeline.md`, `docs/testing.md`, `docs/distribution.md`, `docs/ci.md`, `docs/windows-testing.md`.

**Why this order.** Nothing can be dressed with props that do not exist, so the conversion tooling and the batch come first. The gallery gate comes second because it is what MEASURES the converted models, and the measurement is what sets `MLP_SCALE`: dressing before that number is known would be dressing with a guess. The seating engine comes third, alone, because it is the load bearing change and a reviewer should be able to reject it without rejecting a map layout. The two dressing tasks come next, split so that each one's census move is a reviewable commit of its own. Coherence, the render pass, the docs and the floor come last, because that is where every number that moved is written down.

---

### Task 1: The conversion tooling, and thirty five props on disk

**Files:**
- Create: `tools/prop_manifest.txt`, `tools/convert_props.sh`, `tools/test_convert_props.sh`
- Modify: `tools/convert_mdl.py`, `docs/pipeline.md`
- Test: `tools/test_convert_props.sh` (stub driven, no Blender)

**Interfaces:**
- Consumes: `tools/convert_mdl.py --mdl <path> --out <path>` (prints `MDL_EXPORT_OK <path>`, exits non zero on an import failure); `python3 tools/validate_gltf.py <glb> --props` (prints `meshes=N skins=N materials=N textured=BOOL animations=[...]`, exits 0 when `meshes >= 1`); `tools/bin/blender/blender` (the portable Blender `tools/setup_env.sh` installs, with SourceIO enabled); the manifest driver shape of `tools/convert_roster.sh`.
- Produces:
  - `tools/prop_manifest.txt`: 35 lines of `id|source`, where `source` is the `.mdl` path under the `assets-inbox/` pack root (its first segment is the pack directory).
  - `tools/convert_props.sh [--manifest FILE] [--only id[,id...]] [--force] [--dry-run] [--max-texture N]`, last line `PROP_CONVERT ok=N failed=N skipped=N refused=N`, exit 0 only when `failed` and `refused` are both 0. Honours `FILLY_EXPORTER`, `FILLY_VALIDATOR`, `FILLY_OUT_DIR`.
  - `tools/convert_mdl.py --max-texture N` (0 means leave native), printing one `MDL_TEXTURE_SCALED <image> WxH -> WxH` line per image it shrinks.
  - `game/assets/converted/props/<id>.glb` for all 35 ids, which every later task loads by those exact file names.

**The naming rule, and why the ids are not the model names.** `Props.LAYOUT` names files, `game/test/test_ranch_world.gd` asserts every one of them comes from a kit this project actually converts, and `ranch.gd` prints prop node names in its report. So the id is the name the map uses: `saa_` for the Sweet Apple Acres pack, `pv_` for Ponyville (the General store and the Ponyville Environments row), `school_` for the schoolhouse pack, `lp_` for Las Pegasus, `mlp_` for the Scenebuild props that are not tied to one place. Three of the ids also rename a model whose own filename is a typo or a shorthand: `crate_empy` becomes `mlp_crate`, `teatherpoll` becomes `school_tetherball_pole`, `playgroundhorseshoe` becomes `school_horseshoe`. The manifest is the only place the two spellings meet.

**One source path contains a space** (`ponysfm-scenebuild/MLP Scenebuild Props/...`). `IFS='|' read` splits on the pipe only, and every use of `$source` below is quoted, so it survives; that is why the field separator is a pipe and not whitespace.

- [ ] **Step 1: Write the manifest**

Create `tools/prop_manifest.txt` with exactly these lines:

```
# The curated MLP prop set: id|source, source relative to assets-inbox/.
#
# THE CURATION LIVES HERE AND NOWHERE ELSE. tools/convert_props.sh converts exactly what
# this file names, game/world/props.gd places exactly what it converts, and
# game/test/test_ranch_world.gd asserts nothing else can appear in the layout. Six packs
# ship about 330 models between them; these are the 35 that dress the six places the map
# actually has. See docs/pipeline.md section 5c.
#
# NOT HERE ON PURPOSE: anything named gb_* or *_gb (a ground patch: a flat dirt and grass
# decal meant to sit under a building, not a building), anything named *_m (a mirrored
# duplicate of its unsuffixed sibling), and the whole ponysfm-schoolhouse GMOD/ tree (a
# second copy of its own SFM/ tree). convert_props.sh refuses the first two by name so a
# later hand edit cannot quietly reintroduce one.

# --- Sweet Apple Acres ------------------------------------------------------------------
saa_barn|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/barn_base.mdl
saa_shed|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/shed.mdl
saa_wagon|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/wagon.mdl
saa_hay_pile|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/hay_pile.mdl
saa_hay_block|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/hay_block.mdl
saa_wire_arch|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/wire_arch.mdl
saa_water_chute|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/water_chute.mdl
saa_seed_bag|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/seed_bag.mdl
saa_fence_old|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/fence_old.mdl
saa_corn_plant|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/corn_plant.mdl
saa_corn_plant_dead|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/corn_plant_dead.mdl

# --- Scenebuild props: apples, hedging and yard clutter ---------------------------------
mlp_apple_tree|ponysfm-scenebuild/MLP Scenebuild Props/models/props_pony/apple_tree.mdl
mlp_apple_tree_bare|ponysfm-scenebuild/MLP Scenebuild Props/models/props_pony/apple_tree_noapples.mdl
mlp_bush|ponysfm-scenebuild/MLP Scenebuild Props/models/props_pony/bush.mdl
mlp_crate|ponysfm-scenebuild/MLP Scenebuild Props/models/props_pony/crate_empy.mdl
mlp_basket|ponysfm-scenebuild/MLP Scenebuild Props/models/props_pony/basket.mdl
mlp_farm_well|ponysfm-scenebuild/MLP Scenebuild Props/models/props_pony/farm_well.mdl
mlp_chicken_coop|ponysfm-scenebuild/MLP Scenebuild Props/models/props_pony/chicken_coop.mdl

# --- Ponyville General ------------------------------------------------------------------
pv_general|ponysfm-general-building/models/MLP_Props/Ponyville_General/Building/ponyville_general_building.mdl
pv_general_sign|ponysfm-general-building/models/MLP_Props/Ponyville_General/Building/ponyville_general_sign.mdl

# --- the Ponyville town row -------------------------------------------------------------
pv_tower_b|ponysfm-environments/models/Ponyville_Environments/tower_b.mdl
pv_wide_b|ponysfm-environments/models/Ponyville_Environments/wide_b.mdl
pv_pink_b|ponysfm-environments/models/Ponyville_Environments/pink_b.mdl
pv_courtyard_b|ponysfm-environments/models/Ponyville_Environments/courtyard_b.mdl
pv_balcony_b|ponysfm-environments/models/Ponyville_Environments/balcony_b.mdl
pv_bridged_b|ponysfm-environments/models/Ponyville_Environments/bridged_b.mdl

# --- the schoolyard. THE PACK SHIPS NO SCHOOLHOUSE; see the probe findings above. -------
school_belltower|ponysfm-schoolhouse/SFM/models/belltower.mdl
school_sign|ponysfm-schoolhouse/SFM/models/school_sign.mdl
school_swingframe|ponysfm-schoolhouse/SFM/models/swingframe.mdl
school_horseshoe|ponysfm-schoolhouse/SFM/models/playgroundhorseshoe.mdl
school_tetherball_pole|ponysfm-schoolhouse/SFM/models/teatherpoll.mdl
school_picnic_table|ponysfm-schoolhouse/SFM/models/picnictable.mdl
school_cone|ponysfm-schoolhouse/SFM/models/school_cone.mdl

# --- Las Pegasus ------------------------------------------------------------------------
lp_skeeball|ponysfm-las-pegasus/models/mlp_props/las_pegasus/games/skeeball_game.mdl
lp_dance_game|ponysfm-las-pegasus/models/mlp_props/las_pegasus/games/dance_game.mdl
```

`swingseat.mdl` is deliberately absent even though the pack ships it: `Props.seat()` puts the bottom of a model's AABB on the ground, so a seat that is supposed to hang from a frame would be placed standing on the grass. The swing frame goes up on its own.

- [ ] **Step 2: Write the failing self test**

Create `tools/test_convert_props.sh`:

```bash
#!/usr/bin/env bash
# Self-test for tools/convert_props.sh using a fake exporter and validator, so it runs in
# seconds and needs no Blender. Exit code is the verdict. Same shape and same reasoning as
# tools/test_convert_roster.sh, which is the character side of the same driver.
set -uo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/manifest.txt" <<'EOF'
# id|source
good_barn|fakepack/models/barn_base.mdl
good_sign|fakepack/models/sign.mdl
bad_export|fakepack/models/bad.mdl
bad_validate|fakepack/models/badv.mdl
patch_prefix|fakepack/models/gb_tower_b.mdl
patch_suffix|fakepack/models/barn_gb.mdl
mirror|fakepack/models/barn_base_m.mdl
EOF

# Fake exporter: writes the --out file unless the source says "bad.mdl", and records the
# --max-texture it was handed, so the cap cannot silently stop being passed through.
cat > "$TMP/exporter.sh" <<'EOF'
#!/usr/bin/env bash
out=""; src=""; cap=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="$2"; shift 2;;
    --mdl) src="$2"; shift 2;;
    --max-texture) cap="$2"; shift 2;;
    *) shift;;
  esac
done
case "$src" in *bad.mdl) echo "fake exporter: boom" >&2; exit 1;; esac
mkdir -p "$(dirname "$out")"; printf 'fake %s\n' "$cap" > "$out"
EOF
chmod +x "$TMP/exporter.sh"

# Fake validator: fails for bad_validate.glb, and fails if --props was not passed. A prop
# ships no skin, so the default gate rejects every one of them; a driver that forgot the
# flag would report every model broken and the tally alone would not say why.
cat > "$TMP/validator.sh" <<'EOF'
#!/usr/bin/env bash
case " $* " in *" --props "*) ;; *) echo "fake validator: --props was not passed" >&2; exit 1;; esac
case "$1" in *bad_validate.glb) echo "fake validator: no meshes" >&2; exit 1;; esac
echo "meshes=1 skins=0 materials=1 textured=True animations=[]"
EOF
chmod +x "$TMP/validator.sh"

fails=0
check() { if [ "$1" != "$2" ]; then echo "FAIL: $3 (got '$1', want '$2')"; fails=$((fails+1)); else echo "ok: $3"; fi; }
run() {
  FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
    bash tools/convert_props.sh --manifest "$TMP/manifest.txt" "$@" 2>&1
}

out=$(run); rc=$?
check "$rc" "1" "a manifest with failures and refusals exits 1"
check "$(echo "$out" | tail -1)" "PROP_CONVERT ok=2 failed=2 skipped=0 refused=3" "the summary counts each outcome"
check "$(echo "$out" | grep -c '^REFUSED patch_prefix:')" "1" "a gb_ prefixed ground patch is refused by name"
check "$(echo "$out" | grep -c '^REFUSED patch_suffix:')" "1" "a _gb suffixed ground patch is refused by name"
check "$(echo "$out" | grep -c '^REFUSED mirror:')" "1" "an _m mirrored duplicate is refused by name"
check "$([ -f "$TMP/out/patch_prefix.glb" ] && echo present || echo absent)" "absent" "a refused model never reaches the exporter"
check "$(cat "$TMP/out/good_barn.glb")" "fake 1024" "the texture cap reaches the exporter, 1024 by default"
# The one outcome the tally cannot show, and the same trap convert_roster.sh documents: a
# glb that exported but failed validation sits at the path this script uses to decide a
# model is already done, so leaving it there makes every later run SKIP it, forever.
check "$([ -f "$TMP/out/bad_validate.glb" ] && echo present || echo removed)" "removed" "a glb that failed validation is removed, not left to be skipped forever"

out=$(run --only good_barn); rc=$?
check "$rc" "0" "--only with a good model reaches no refusal and exits 0"
check "$(echo "$out" | tail -1)" "PROP_CONVERT ok=0 failed=0 skipped=1 refused=0" "an existing glb is skipped, not re-exported"

out=$(run --only good_barn --force --max-texture 512)
check "$(echo "$out" | tail -1)" "PROP_CONVERT ok=1 failed=0 skipped=0 refused=0" "--force re-exports"
check "$(cat "$TMP/out/good_barn.glb")" "fake 512" "--max-texture overrides the default"

out=$(run --dry-run); rc=$?
check "$rc:$(echo "$out" | grep -c '^WOULD ')" "1:2" "--dry-run lists only what would be exported and still fails on the refusals"

echo "PROP_CONVERT_SELFTEST failures=$fails"
exit $([ $fails -eq 0 ] && echo 0 || echo 1)
```

- [ ] **Step 3: Run the self test to verify it fails**

```bash
bash tools/test_convert_props.sh; echo "exit $?"
```
Expected: every `check` line FAILs with an empty "got", because `tools/convert_props.sh` does not exist yet, and `exit 1`.

- [ ] **Step 4: Write the driver**

Create `tools/convert_props.sh`:

```bash
#!/usr/bin/env bash
# Convert every model in tools/prop_manifest.txt that has no .glb yet (or all of them with
# --force), through the two commands docs/pipeline.md section 5 documents by hand:
# tools/convert_mdl.py for the SourceIO import and the glTF export, tools/validate_gltf.py
# --props for the check. One model failing does not stop the others; the last line is the
# tally and the exit code is the verdict. This is tools/convert_roster.sh's shape, applied
# to props: read that file first if anything here looks arbitrary.
#
# usage: tools/convert_props.sh [--manifest FILE] [--only id[,id...]] [--force] [--dry-run]
#                               [--max-texture N]
#
# GROUND PATCHES AND MIRRORS ARE REFUSED BY NAME, and a refusal fails the run. Every
# building in the PonySFM environment packs ships a gb_ sibling that is its ground decal (a
# flat dirt and grass patch, not a building) and an _m sibling that is a mirrored duplicate
# of it. A manifest line naming one is a curation mistake, not an input to work around, so
# it is reported and counted rather than quietly converted into a floating rug.
#
# FILLY_EXPORTER, FILLY_VALIDATOR and FILLY_OUT_DIR override the tools and the output
# directory so tools/test_convert_props.sh can run this in seconds without Blender.
set -uo pipefail
cd "$(dirname "$0")/.."

MANIFEST="tools/prop_manifest.txt"
ONLY=""
FORCE=0
DRY=0
# 1024 is the cap the probe argued for: barn_base.glb came out 34 MB at native VTF
# resolution, almost all of it baked PNG, and thirty five models at that rate is a
# multi gigabyte tree for scenery nobody stands closer than a few metres to.
MAX_TEXTURE=1024
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --max-texture) MAX_TEXTURE="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

OUT_DIR="${FILLY_OUT_DIR:-game/assets/converted/props}"
VALIDATOR="${FILLY_VALIDATOR:-python3 tools/validate_gltf.py}"
BLENDER="tools/bin/blender/blender"
INBOX="assets-inbox"

selected() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

# Prints why this model may not be converted, and returns 0 when there is a reason.
refused_reason() {
  case "$1" in
    gb_*) echo "ground patch (gb_ prefix)"; return 0 ;;
    *_gb) echo "ground patch (_gb suffix)"; return 0 ;;
    *_m)  echo "mirrored duplicate (_m suffix)"; return 0 ;;
  esac
  return 1
}

export_one() {
  local mdl="$1" out="$2"
  if [ -n "${FILLY_EXPORTER:-}" ]; then
    "$FILLY_EXPORTER" --mdl "$mdl" --out "$out" --max-texture "$MAX_TEXTURE"
  else
    "$BLENDER" -b -P tools/convert_mdl.py -- \
      --mdl "$mdl" --out "$out" --max-texture "$MAX_TEXTURE"
  fi
}

ok=0; failed=0; skipped=0; refused=0
# Only when something might actually be written. --dry-run reports what it WOULD convert
# and must not leave an output directory behind as a side effect of being asked.
[ "$DRY" -eq 1 ] || mkdir -p "$OUT_DIR"
while IFS='|' read -r id source; do
  case "$id" in ''|\#*) continue ;; esac
  selected "$id" || continue
  base="$(basename "$source" .mdl)"
  if reason="$(refused_reason "$base")"; then
    echo "REFUSED $id: $base is a $reason"; refused=$((refused + 1)); continue
  fi
  out="$OUT_DIR/$id.glb"
  if [ -f "$out" ] && [ "$FORCE" -eq 0 ]; then
    skipped=$((skipped + 1)); continue
  fi
  if [ "$DRY" -eq 1 ]; then
    echo "WOULD $id ($source)"; continue
  fi
  log="${TMPDIR:-/tmp}/convert_prop_${id}.log"
  # < /dev/null on both tools below: this loop reads the manifest ON STDIN, so anything
  # they read from stdin is eaten out of the manifest and every model after it is never
  # converted at all. Blender reads stdin. See tools/convert_roster.sh's own note.
  if ! export_one "$INBOX/$source" "$out" > "$log" 2>&1 < /dev/null; then
    echo "FAILED $id: export failed, see $log"; failed=$((failed + 1)); rm -f "$out"; continue
  fi
  if ! $VALIDATOR "$out" --props >> "$log" 2>&1 < /dev/null; then
    echo "FAILED $id: validation failed, see $log"; failed=$((failed + 1)); rm -f "$out"; continue
  fi
  echo "CONVERTED $id"; ok=$((ok + 1))
done < "$MANIFEST"

echo "PROP_CONVERT ok=$ok failed=$failed skipped=$skipped refused=$refused"
[ "$failed" -eq 0 ] && [ "$refused" -eq 0 ]
```

Then make both scripts executable:

```bash
chmod +x tools/convert_props.sh tools/test_convert_props.sh
```

- [ ] **Step 5: Run the self test to verify it passes**

```bash
bash tools/test_convert_props.sh; echo "exit $?"
```
Expected: every line `ok:`, then `PROP_CONVERT_SELFTEST failures=0` and `exit 0`.

- [ ] **Step 6: Add the texture cap to the exporter**

In `tools/convert_mdl.py`, add the argument next to the two that are there:

```python
p.add_argument("--max-texture", type=int, default=0,
               help="downscale any packed image whose longest side exceeds N pixels; "
                    "0 (the default) leaves every image at its native VTF resolution")
```

and replace the packing loop:

```python
for img in bpy.data.images:               # Source textures arrive as VTF-decoded images; pack them
    if img.source == "FILE":
        img.pack()
```

with:

```python
# Source textures arrive as VTF-decoded images. Shrink them BEFORE packing: the glTF
# exporter bakes whatever the image currently holds into the .glb, so a resize after the
# pack costs the same bytes it was meant to save. barn_base.glb measured 34 MB at native
# resolution in the tier c prop probe, almost all of it baked PNG.
for img in bpy.data.images:
    if img.source != "FILE":
        continue
    if args.max_texture > 0 and max(img.size) > args.max_texture:
        was_w, was_h = img.size
        factor = args.max_texture / float(max(was_w, was_h))
        img.scale(max(1, int(round(was_w * factor))), max(1, int(round(was_h * factor))))
        print(f"MDL_TEXTURE_SCALED {img.name} {was_w}x{was_h} -> {img.size[0]}x{img.size[1]}")
    img.pack()
```

`argparse` maps `--max-texture` to `args.max_texture`. The default is 0 rather than 1024 so this script's documented behaviour as the section 5 probe tool is unchanged; `convert_props.sh` is what passes a cap.

- [ ] **Step 7: Convert the thirty five models for real**

This needs the staged packs and the portable Blender, so it runs on a machine that has `assets-inbox/`. Expect roughly twenty minutes.

```bash
bash tools/setup_env.sh                       # SourceIO enabled; docs/pipeline.md section 1
bash tools/convert_props.sh --dry-run
bash tools/convert_props.sh 2>&1 | tail -45
```
Expected last line: `PROP_CONVERT ok=35 failed=0 skipped=0 refused=0`, exit 0. A `FAILED <id>` line names its own log under `${TMPDIR:-/tmp}/convert_prop_<id>.log`; the probe converted nine of these models with zero failures, so a failure here is a real surprise and worth reading the log for rather than retrying.

Then check the size the cap bought and import the tree once:

```bash
du -sh game/assets/converted/props
ls game/assets/converted/props | wc -l          # expect 35
tools/bin/godot --headless --path game --import
```

Skipping that `--import` is `docs/testing.md`'s "Quirk / gotcha 3": about nineteen red tests and no hint why.

- [ ] **Step 8: Write the pipeline docs**

Add a new section to `docs/pipeline.md`, immediately after section 5b and before section 6. The block below is fenced with FOUR backticks because it contains a fenced code block of its own; write it into the doc with three, as normal.

````markdown
## 5c. The prop pipeline: `tools/convert_props.sh`

Section 5 converts one `.mdl` by hand. This is the batch, and it is the command a
fresh clone runs to get the map's MLP scenery back.

```bash
bash tools/convert_props.sh
# -> CONVERTED saa_barn
# -> ...
# -> PROP_CONVERT ok=35 failed=0 skipped=0 refused=0
tools/bin/godot --headless --path game --import
```

`tools/prop_manifest.txt` is the curation and the only place it lives: 35 lines of
`id|source`, `source` relative to `assets-inbox/`. The id is the name the map uses,
so `game/world/props.gd`'s `LAYOUT` and `ranch.gd`'s report both speak it.

**Two whole families of model are refused by name, and a refusal fails the run.**

* `gb_` prefixed and `_gb` suffixed models are **ground patches**, not buildings:
  `barn_gb` renders as a dirt and grass patch with a paddock fence and worn path
  rings, meant to sit under the barn. Every building in `ponysfm-environments` has
  one. A glob would convert about fifty flat planes believing they were buildings
  while missing the ten real ones.
* `_m` suffixed models are **mirrored duplicates**. `barn_base.mdl` and
  `barn_base_m.mdl` are both 3,108 bytes with their own `.vvd` and `.dx90.vtx`
  siblings.

**`--max-texture` is not optional at this scale.** `convert_mdl.py` gained the flag
for this driver, which passes 1024 by default. Without it `barn_base.glb` alone is
34 MB of baked PNG at native VTF resolution.

`tools/test_convert_props.sh` exercises the driver against stub exporter and
validator scripts in seconds with no Blender, including both refusal rules, the
cap being passed through, and the removal of a `.glb` that exported but failed
validation (left in place it would be skipped forever, because its existence is
what makes the next run think the model is done).

### The output is gitignored, and worktrees share one copy

`game/assets/converted/` is gitignored in full (§4 of `docs/ci.md` explains what the
project builds on that), so these 35 `.glb` files are not in the repository and a
fresh clone has no props, exactly as it has no ponies.

**`.claude/worktrees/*/game/assets/converted` is a symlink to the main checkout's
`game/assets/converted`.** That is why a worktree has ponies without running the
pipeline, and it has two consequences worth knowing before you convert anything in
one:

* converting inside a worktree writes into the MAIN checkout's tree, so the
  conversion is only ever paid once, from wherever you happen to be standing;
* an abandoned branch that converted something leaves it behind on master's disk.
  Nothing breaks: `Props.build()` ignores any file `LAYOUT` does not name.
````

- [ ] **Step 9: Commit**

```bash
printf 'feat: a manifest driven prop conversion, and a texture budget\n\ntools/prop_manifest.txt is the curated MLP prop set, 35 models across the six\npacks staged in assets-inbox, and the only place that curation lives.\ntools/convert_props.sh drives it the way convert_roster.sh drives the character\nroster: one Blender run per model, validated with validate_gltf.py --props,\nrefusing gb_ ground patches and _m mirrored duplicates by name because a pack\nships one of each per building and converting them is fifty flat planes and no\nbuildings. tools/test_convert_props.sh proves the driver against stubs in\nseconds with no Blender.\n\nconvert_mdl.py gains --max-texture, which convert_props.sh passes as 1024:\nbarn_base alone is 34 MB of baked PNG at native VTF resolution.\n\ndocs/pipeline.md section 5c writes down the batch, both refusal rules, and the\nworktree symlink convention that makes one conversion serve every branch.\n' > /tmp/props-tooling-commit.txt
git add tools/prop_manifest.txt tools/convert_props.sh tools/test_convert_props.sh tools/convert_mdl.py docs/pipeline.md
git commit -F /tmp/props-tooling-commit.txt
```

---

### Task 2: The gallery measures the props, and `MLP_SCALE` stops being a guess

**Files:**
- Modify: `game/scenes/test/model_gallery.gd`, `game/scenes/test/model_gallery.tscn`, `game/world/props.gd`
- Test: `game/test/test_ranch_world.gd` (the scale constants, beside the two that are already there)

**Interfaces:**
- Consumes: `Props.world_aabb(root: Node3D) -> AABB`; `GateWatchdog.arm(node: Node, marker: String) -> void`; `game/assets/converted/props/*.glb` from Task 1.
- Produces:
  - a `--props` mode on `model_gallery.tscn` printing one `PROP <file> size=(x, y, z) meshes=N materials=N textured=N` line per model, one `PROP_SCALE model=saa_barn.glb native_height=... target=... mlp_scale=...` line, and `GALLERY_OK count=N`, exit code the verdict;
  - `Props.MLP_TARGET_BARN_RIDGE` (float, 7.0) and `Props.MLP_SCALE` (float, measured in this task), which Task 3's family table reads and Task 6's ranch check measures against.

**Indentation warning.** `game/scenes/test/model_gallery.gd` is indented with FOUR SPACES, unlike `props.gd` and `ranch.gd`, which use tabs. Match the file you are in; a mixed file does not parse.

**Where 7.0 comes from.** The homestead's own `Building` barn is authored in `game/world/ranch.tscn` at `ridge_height = 4.9`. Sweet Apple Acres is a bigger farm than the one the player is starting, and its barn stands across a valley from the homestead where anything short reads as a shed. 7.0 m is a ridge that clears the player's barn by about two metres and still sits under the 6.0 m `Terrain.BOUNDARY_HEIGHT` wall on the horizon. It is a target, not a measurement: `MLP_SCALE` is the measurement, and it is `MLP_TARGET_BARN_RIDGE` divided by whatever the converted model actually turns out to be.

- [ ] **Step 1: Add the target constant to `props.gd`**

In `game/world/props.gd`, immediately after `const TREE_SCALE := 3.0` and its comment block:

```gdscript
## THE MLP FAMILY'S OWN BASE SCALE, and it REPLACES BASE_SCALE rather than multiplying it.
## BASE_SCALE is a Kenney kit number (docs/pipeline.md section 4 derives it from a 2 unit
## Kenney door module); a Source engine model converted by tools/convert_props.sh arrives
## with the inch to metre conversion already baked into its vertex data by SourceIO, at
## whatever size a 2015 SFM modeller drew it. Those are two unrelated conventions and
## multiplying one by the other has no meaning.
##
## MEASURED, NOT CHOSEN. scenes/test/model_gallery.tscn -- --props loads every converted
## prop and prints the world AABB of each; MLP_SCALE is MLP_TARGET_BARN_RIDGE divided by
## the native height that gate reported for saa_barn.glb. ranch.gd then measures the
## seated barn and fails if it does not stand at the target, so the number below and the
## barn on the map cannot drift apart silently.
const MLP_TARGET_BARN_RIDGE := 7.0
```

`MLP_SCALE` itself is written in step 5, once there is a measurement to write.

- [ ] **Step 2: Add the props mode to the gallery**

In `game/scenes/test/model_gallery.gd`, add two preloads and three constants beside the existing ones (four space indentation throughout this file):

```gdscript
const PropsScript := preload("res://world/props.gd")

const PROP_DIR := "res://assets/converted/props/"

## Metres of clear grass between one prop and the next in the row.
const PROP_GAP := 1.5

## The floor on how many props must load before this gate calls itself a pass. Below the
## manifest's 35 on purpose: a machine mid conversion should not report green, and a
## machine with no packs at all should not be told it is broken in a way it can fix.
const PROP_FLOOR := 30

## The model MLP_SCALE is derived from. See Props.MLP_TARGET_BARN_RIDGE.
const SCALE_REFERENCE := "saa_barn.glb"
```

Add the mode to `_ready()`, before the pony glob:

```gdscript
    if "--props" in OS.get_cmdline_user_args():
        _build_props_row()
        return
```

And add the builder and its helper at the end of the file:

```gdscript
## THE PROPS ROW, and the one measurement the whole dressing slice hangs off.
##
## Every converted prop is loaded, stood in a line spaced by its own measured width, and
## reported with the size of its world AABB. Two things are proved here that no unit test
## can prove. First, that a .glb whose textures came out of a VTF tree still HAS its
## materials after tools/convert_props.sh downscaled them: a texture cap that silently
## dropped the image would leave a fully structured model that renders flat white, and
## validate_gltf.py --props only asks whether meshes exist. Second, how big these models
## actually are, which is where Props.MLP_SCALE comes from. Show scale is not Kenney
## scale, and guessing at it is how a barn ends up the size of a hay bale.
func _build_props_row() -> void:
    GateWatchdogScript.arm(self, "GALLERY")
    var camera := $PropCamera as Camera3D
    var loaded := 0
    var untextured: Array[String] = []
    var empty: Array[String] = []
    var cursor := 0.0
    var dir := DirAccess.open(PROP_DIR)
    if dir == null:
        print("GALLERY props: no ", PROP_DIR, " on this machine; run tools/convert_props.sh")
        print("GALLERY_OK count=0")
        if DisplayServer.get_name() == "headless":
            get_tree().quit(1)
        return
    # PackedStringArray, not Array: DirAccess.get_files() returns the packed kind, and
    # assigning it to a `var x: Array` is a hard type error rather than a conversion.
    # Sorted so the row, and therefore the printed report, is the same on every machine.
    var files := dir.get_files()
    files.sort()
    for file: String in files:
        if file.get_extension() != "glb":
            continue
        var scene: PackedScene = load(PROP_DIR + file)
        var inst: Node3D = scene.instantiate()
        add_child(inst)
        # Measured before it is moved: a translation cannot change a size, and the row
        # wants each model's own width to space it by.
        var box: AABB = PropsScript.world_aabb(inst)
        inst.position = Vector3(cursor + box.size.x * 0.5, 0.0, 0.0)
        cursor += box.size.x + PROP_GAP
        var meshes := 0
        var materials := 0
        var textured := 0
        for mesh: MeshInstance3D in _mesh_instances(inst):
            meshes += 1
            for i in range(mesh.get_surface_override_material_count()):
                var material: Material = mesh.get_active_material(i)
                if material == null:
                    continue
                materials += 1
                var pbr: BaseMaterial3D = material as BaseMaterial3D
                if pbr != null and pbr.albedo_texture != null:
                    textured += 1
        if box.size == Vector3.ZERO:
            empty.append(file)
        if textured == 0:
            untextured.append(file)
        print("PROP %-26s size=(%.3f, %.3f, %.3f) meshes=%d materials=%d textured=%d"
              % [file, box.size.x, box.size.y, box.size.z, meshes, materials, textured])
        if file == SCALE_REFERENCE and box.size.y > 0.001:
            print("PROP_SCALE model=%s native_height=%.3f target=%.2f mlp_scale=%.4f"
                  % [file, box.size.y, PropsScript.MLP_TARGET_BARN_RIDGE,
                     PropsScript.MLP_TARGET_BARN_RIDGE / box.size.y])
        loaded += 1
    camera.position = Vector3(cursor * 0.5, 9.0, 34.0)
    camera.look_at(Vector3(cursor * 0.5, 2.0, 0.0), Vector3.UP)
    camera.make_current()
    print("GALLERY props untextured=", untextured, " empty=", empty)
    print("GALLERY_OK count=", loaded)
    if DisplayServer.get_name() == "headless":
        get_tree().quit(0 if loaded >= PROP_FLOOR and untextured.is_empty() \
            and empty.is_empty() else 1)


## Every MeshInstance3D under `root`, root itself included when it is one. The same walk
## Props.world_aabb() does, kept local for the same reason props.gd keeps its own copy:
## this is a test scene and that is shipping world code.
func _mesh_instances(root: Node3D) -> Array[MeshInstance3D]:
    var result: Array[MeshInstance3D] = []
    if root is MeshInstance3D:
        result.append(root as MeshInstance3D)
    for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
        result.append(mesh)
    return result
```

- [ ] **Step 3: Give the scene a camera that can see a row of props**

The existing `Camera3D` sits at `(3, 2, 8)` and frames one pony. A row of 35 props is tens of metres wide. Add a second camera to `game/scenes/test/model_gallery.tscn`, after the existing `Camera3D` node block:

```
[node name="PropCamera" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 9, 34)
current = false
far = 400.0
```

Its position and aim are overwritten by `_build_props_row()` once the row's width is known; the authored transform is only what a person sees if they open the scene in the editor.

- [ ] **Step 4: Run the gate and read the measurements**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game \
  scenes/test/model_gallery.tscn -- --props 2>&1 | tail -45
echo "exit ${PIPESTATUS[0]}"
```
Expected: 35 `PROP ` lines each with `meshes>=1` and `textured>=1`, one `PROP_SCALE` line, `GALLERY props untextured=[] empty=[]`, `GALLERY_OK count=35`, exit 0.

Write down the `mlp_scale=` value from the `PROP_SCALE` line and the `native_height=` beside it. If any model reports `textured=0`, re-run its conversion at a larger cap and look at the log: `tools/convert_props.sh --only <id> --force --max-texture 2048`.

- [ ] **Step 5: Write the measured scale into `props.gd`**

Immediately below `MLP_TARGET_BARN_RIDGE`, add the constant with the numbers the gate printed substituted for `<native>` and `<measured>`:

```gdscript
## From the run above: scenes/test/model_gallery.tscn -- --props reported saa_barn.glb at
## <native> m tall as converted, so MLP_TARGET_BARN_RIDGE / <native> = <measured>. Re-run
## that gate and redo this division if tools/convert_props.sh's export ever changes shape.
const MLP_SCALE := <measured>
```

- [ ] **Step 6: Write the failing tests**

Append to `game/test/test_ranch_world.gd`, immediately after `test_the_prop_scale_factor_is_the_one_the_pipeline_validated()`:

```gdscript
func test_the_mlp_family_has_its_own_base_scale_and_it_is_not_the_kenney_one() -> void:
	# The whole point of the family key: a Source model is not a Kenney kit piece and must
	# not be multiplied by a number derived from a Kenney door module. If these two ever
	# come out equal it is a coincidence worth looking at, not a pass.
	assert_gt(PropsScript.MLP_SCALE, 0.0, "MLP_SCALE must be a positive multiplier")
	assert_lt(PropsScript.MLP_SCALE, 100.0,
		"MLP_SCALE above 100 means the measurement was read off the wrong model")


func test_the_sweet_apple_acres_barn_has_a_target_ridge_to_be_scaled_against() -> void:
	# 7.0 m: about two metres over the homestead barn's own 4.9 m ridge (authored in
	# game/world/ranch.tscn), and under Terrain.BOUNDARY_HEIGHT. ranch.gd measures the
	# seated barn against this same constant, so a scale that stopped producing it fails
	# a gate rather than only looking wrong.
	assert_almost_eq(PropsScript.MLP_TARGET_BARN_RIDGE, 7.0, 0.0001,
		"the target ridge is quoted in props.gd's MLP_SCALE derivation and in ranch.gd")
```

- [ ] **Step 7: Run the suite**

```bash
bash tools/run_tests.sh 2>&1 | tail -12
```
Expected: green, with two more tests than the previous run.

- [ ] **Step 8: Commit**

```bash
printf 'feat: the gallery measures the converted props, and MLP_SCALE is that measurement\n\nmodel_gallery.tscn gains a --props mode beside --stock and --mark: it loads\nevery .glb in assets/converted/props, stands them in a row spaced by their own\nmeasured widths, and prints the world AABB, mesh count, material count and\ntextured surface count of each. Two things it proves that no unit test can: that\nthe --max-texture downscale left the materials attached (validate_gltf.py --props\nonly asks whether meshes exist), and how big a show scale model actually is.\n\nProps.MLP_TARGET_BARN_RIDGE is 7.0 m, about two metres over the homestead barn.\nProps.MLP_SCALE is that target divided by the height the gate reported for\nsaa_barn.glb, so the family scale is a division rather than a guess.\n' > /tmp/gallery-props-commit.txt
git add game/scenes/test/model_gallery.gd game/scenes/test/model_gallery.tscn game/world/props.gd game/test/test_ranch_world.gd
git commit -F /tmp/gallery-props-commit.txt
```

---

### Task 3: Families, footprint seating and skirts

**Files:**
- Modify: `game/world/props.gd`
- Create: `game/test/test_props.gd`

**Interfaces:**
- Consumes: `Props.BASE_SCALE` (1.5), `Props.TREE_SCALE` (3.0), `Props.SCALE_FIX`, `Props.MLP_SCALE` and `Props.MLP_TARGET_BARN_RIDGE` from Task 2, `Props.SINK_BIAS` (0.05), `Props.world_aabb()`, `Props.seat()`, `Terrain.height_at(x, z)`, `RegionFence.RING_MARGIN` (3.0), `RegionData.centre`/`radius`/`permit_cost`.
- Produces, all read by Tasks 4, 5 and 6:
  - `Props.FAMILY_KENNEY` (`&"kenney"`), `Props.FAMILY_TREE` (`&"tree"`), `Props.FAMILY_MLP` (`&"mlp"`), `Props.FAMILY_SCALE` (Dictionary, StringName to float);
  - `Props.family_of(entry: Dictionary) -> StringName` (static);
  - `Props.scale_for(entry: Dictionary) -> float` (static);
  - `Props.footprint_relief(centre: Vector2, half: Vector2, ground_sampler: Callable) -> Vector2` (static, returns lowest then highest);
  - `Props.needs_skirt(box: AABB, flat: bool) -> bool` (static);
  - `Props.is_foliage(node_name: String) -> bool` (static);
  - `Props.SKIRT_INSET` (0.06), `Props.SKIRT_MIN_DEPTH` (0.90), `Props.WIDE_FOOTPRINT` (4.0), `Props.SKIRT_COLOUR`;
  - `Props.entry_of(node: Node3D) -> Dictionary`, `Props.has_seat_ground(node: Node3D) -> bool`, `Props.seat_ground_of(node: Node3D) -> float`, `Props.get_skirts() -> Array[MeshInstance3D]` (all instance methods).

**Nothing in this task changes the shipped map.** `LAYOUT` is untouched; every existing entry keeps the exact scale it has today, because `FAMILY_SCALE[&"kenney"]` is `BASE_SCALE` and `FAMILY_SCALE[&"tree"]` is `BASE_SCALE * TREE_SCALE`, which is the product `build()` already computes for a `kenney_tree` file. A reviewer can reject this task without rejecting a map layout, which is why it is on its own.

**Why the skirt is a child of `Props` and not of the prop.** `Props.seat()` and `ranch.gd`'s seating check both read `world_aabb(prop).position.y`, the bottom of everything visible under the node. A box hanging below the model would move that bottom, so the prop would appear to be sunk by the skirt's whole depth and the seating check would go red on every skirted prop. The skirt is therefore a sibling: a `MeshInstance3D` under `Props` named `<prop>_skirt`, positioned in world space, collided and layered exactly like a prop, and deliberately NOT in `_placed`, so it never enters the census.

- [ ] **Step 1: Write the failing tests**

Create `game/test/test_props.gd`:

```gdscript
extends GutTest
## The prop layout and the seating rules as DATA and as PURE FUNCTIONS: family scales,
## the footprint sampler, the skirt rule, and the clearance invariants the whole shipped
## LAYOUT has to satisfy.
##
## The live half of this lives in game/world/ranch.gd, which builds the map and measures
## it. These are the parts that need no scene, so a family scale that stopped applying or
## a prop planted inside a region fence fails in half a second with a sentence.
##
## Preloads by path rather than by class_name, per the convention at the top of
## game/scripts/pony_rig.gd (the global class cache lives in the gitignored game/.godot/
## and a fresh clone has not built it yet).

const PropsScript := preload("res://world/props.gd")
const RegionFenceScript := preload("res://world/region_fence.gd")

const REGION_DIR := "res://data/regions/"

## Metres a prop must stand past a region's fence ring, from props.gd's own comment: the
## ring is at radius + RegionFence.RING_MARGIN, and every planted tree clears it by 4 m.
const REGION_PROP_MARGIN := 4.0


# --- families and scales ----------------------------------------------------------------

func test_an_entry_with_no_family_is_a_kenney_kit_piece() -> void:
	var entry := {"file": "kenney_market_stall.glb", "at": Vector2.ZERO, "yaw": 0.0}
	assert_eq(PropsScript.family_of(entry), PropsScript.FAMILY_KENNEY)
	assert_almost_eq(PropsScript.scale_for(entry), PropsScript.BASE_SCALE, 0.0001)


func test_a_kenney_tree_falls_into_the_tree_family_without_being_told() -> void:
	# 50 of the 54 shipped entries are trees and none of them names a family. The prefix
	# rule is what keeps this task from being a 50 line diff to the layout.
	var entry := {"file": "kenney_tree_oak.glb", "at": Vector2.ZERO, "yaw": 0.0}
	assert_eq(PropsScript.family_of(entry), PropsScript.FAMILY_TREE)
	assert_almost_eq(PropsScript.scale_for(entry),
		PropsScript.BASE_SCALE * PropsScript.TREE_SCALE, 0.0001)


func test_an_explicit_family_beats_the_filename_rule() -> void:
	var entry := {"file": "kenney_tree_oak.glb", "at": Vector2.ZERO, "yaw": 0.0,
		"family": PropsScript.FAMILY_KENNEY}
	assert_eq(PropsScript.family_of(entry), PropsScript.FAMILY_KENNEY)


func test_the_mlp_family_is_scaled_by_its_own_number_and_not_by_the_kenney_base() -> void:
	var entry := {"file": "saa_barn.glb", "at": Vector2.ZERO, "yaw": 0.0,
		"family": PropsScript.FAMILY_MLP}
	assert_almost_eq(PropsScript.scale_for(entry), PropsScript.MLP_SCALE, 0.0001,
		"an MLP prop must not be multiplied by BASE_SCALE as well")


func test_the_per_entry_jitter_and_the_scale_fix_still_multiply_on_top() -> void:
	var jittered := {"file": "kenney_tree_oak.glb", "at": Vector2.ZERO, "yaw": 0.0, "s": 1.2}
	assert_almost_eq(PropsScript.scale_for(jittered),
		PropsScript.BASE_SCALE * PropsScript.TREE_SCALE * 1.2, 0.0001)
	var fixed := {"file": "kenney_survival_structure.glb", "at": Vector2.ZERO, "yaw": 0.0}
	assert_almost_eq(PropsScript.scale_for(fixed), PropsScript.BASE_SCALE * 4.0, 0.0001,
		"the FBX unit-conversion correction still applies, family or no family")


func test_every_family_the_layout_names_has_a_scale() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		var family: StringName = PropsScript.family_of(entry)
		assert_true(PropsScript.FAMILY_SCALE.has(family),
			"'%s' names family '%s', which has no scale" % [entry["file"], family])


# --- the footprint sampler --------------------------------------------------------------

func test_the_footprint_sampler_reports_the_lowest_and_highest_of_nine_points() -> void:
	# A ramp running with x: the lowest sample is the west edge, the highest the east one,
	# and the centre column is what a single origin sample would have seen instead.
	var ramp := func(x: float, _z: float) -> float: return x * 0.1
	var relief: Vector2 = PropsScript.footprint_relief(
		Vector2(10.0, 4.0), Vector2(5.0, 3.0), ramp)
	assert_almost_eq(relief.x, 0.5, 0.0001, "lowest is the west edge at x = 5")
	assert_almost_eq(relief.y, 1.5, 0.0001, "highest is the east edge at x = 15")


func test_a_flat_footprint_has_no_relief_across_it() -> void:
	var flat := func(_x: float, _z: float) -> float: return 2.5
	var relief: Vector2 = PropsScript.footprint_relief(
		Vector2.ZERO, Vector2(6.0, 5.0), flat)
	assert_almost_eq(relief.x, 2.5, 0.0001)
	assert_almost_eq(relief.y, 2.5, 0.0001)


# --- the skirt rule ---------------------------------------------------------------------

func test_a_wide_prop_off_the_flat_apron_needs_a_skirt() -> void:
	var wide := AABB(Vector3.ZERO, Vector3(13.0, 7.0, 10.0))
	assert_true(PropsScript.needs_skirt(wide, false))


func test_the_same_prop_inside_the_flat_apron_does_not() -> void:
	# Terrain.is_flat_at() is true within FLAT_RADIUS of the homestead centre, where the
	# ground is exactly y = 0 by construction, so there is no relief for a skirt to bridge.
	var wide := AABB(Vector3.ZERO, Vector3(13.0, 7.0, 10.0))
	assert_false(PropsScript.needs_skirt(wide, true))


func test_a_narrow_prop_never_needs_one() -> void:
	var narrow := AABB(Vector3.ZERO, Vector3(1.2, 2.0, 1.2))
	assert_false(PropsScript.needs_skirt(narrow, false))


func test_the_wide_threshold_takes_the_longer_of_the_two_sides() -> void:
	var slab := AABB(Vector3.ZERO, Vector3(1.0, 2.0, 9.0))
	assert_true(PropsScript.needs_skirt(slab, false),
		"a nine metre fence line is as wide a footprint as a nine metre barn")


func test_the_skirt_constants_are_the_ones_the_relief_survey_argued_for() -> void:
	# 0.06 is Building.PLINTH_INSET's number and is here for the same reason: a skirt whose
	# outer face is coplanar with the model's own side is two surfaces fighting for one
	# pixel. 0.90 clears the 0.643 m of relief measured under the barn's own site and the
	# 0.366 m floor found anywhere on the map outside the flat apron.
	assert_almost_eq(PropsScript.SKIRT_INSET, 0.06, 0.0001)
	assert_almost_eq(PropsScript.SKIRT_MIN_DEPTH, 0.90, 0.0001)
	assert_almost_eq(PropsScript.WIDE_FOOTPRINT, 4.0, 0.0001)


# --- foliage --------------------------------------------------------------------------

func test_both_tree_families_read_as_foliage() -> void:
	# ranch.gd frames its camera shots off "the tallest building", which is every prop that
	# is not a tree. A canopy is a bad thing to prove a camera against, and the apple trees
	# are as much a canopy as the Kenney ones.
	assert_true(PropsScript.is_foliage("kenney_tree_oak_12"))
	assert_true(PropsScript.is_foliage("mlp_apple_tree_31"))
	assert_true(PropsScript.is_foliage("mlp_apple_tree_bare_33"))
	assert_false(PropsScript.is_foliage("saa_barn_54"))
	assert_false(PropsScript.is_foliage("kenney_windmill_0"))


# --- the shipped layout, as data --------------------------------------------------------

func test_every_layout_entry_carries_the_keys_build_reads() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		assert_true(entry.has("file"), "an entry with no file cannot be loaded")
		assert_true(entry.has("at"), "%s has no position" % entry["file"])
		assert_true(entry.has("yaw"), "%s has no yaw" % entry["file"])
		assert_true(entry["at"] is Vector2, "%s's position is not a Vector2" % entry["file"])


func test_nothing_in_the_layout_stands_in_the_pen_plot_clearing() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		var at: Vector2 = entry["at"]
		assert_false(PropsScript.is_in_pen_plots(at.x, at.y),
			"%s at %s is inside the reserved pen plot clearing" % [entry["file"], at])


func test_every_prop_stands_clear_of_every_priced_region_fence_ring() -> void:
	# props.gd's own rule: at least 4 m past the ring, which RegionFence puts at
	# radius + RING_MARGIN. A trunk ON the ring is a tree growing through a fence rail, and
	# a prop INSIDE it is something a resident can spawn on top of.
	for region: RegionData in _priced_regions():
		var ring: float = region.radius + RegionFenceScript.RING_MARGIN + REGION_PROP_MARGIN
		for entry: Dictionary in PropsScript.LAYOUT:
			var at: Vector2 = entry["at"]
			assert_gt(at.distance_to(region.centre), ring,
				"%s at %s stands inside region '%s'" % [entry["file"], at, region.id])


func _priced_regions() -> Array[RegionData]:
	var result: Array[RegionData] = []
	var dir := DirAccess.open(REGION_DIR)
	assert_not_null(dir, "no %s on this machine" % REGION_DIR)
	if dir == null:
		return result
	for file: String in dir.get_files():
		if file.get_extension() != "tres":
			continue
		var region: RegionData = load(REGION_DIR + file)
		if region != null and region.permit_cost > 0:
			result.append(region)
	return result
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_props.gd -gexit 2>&1 | tail -25
```
Expected: the script fails to load, or every test errors, on `Invalid call. Nonexistent function 'family_of' in base 'GDScript'`.

- [ ] **Step 3: Add the families to `props.gd`**

Immediately below `MLP_SCALE`, add:

```gdscript
## THE FAMILY A LAYOUT ENTRY BELONGS TO, and the base scale each family is built at.
##
## Three, and they are three different measuring conventions rather than three tastes:
## a Kenney kit piece (BASE_SCALE, derived from a 2 unit door module), a Kenney Nature Kit
## tree (BASE_SCALE again, then TREE_SCALE on top, because the kit's trees are stylised
## shorter than a pony), and an MLP prop converted out of a Source model (MLP_SCALE, which
## replaces BASE_SCALE outright: see its own comment).
##
## An entry may name its family explicitly. An entry that does not is a Kenney piece,
## unless its file begins with "kenney_tree", which is the rule the shipped treeline
## already follows and which is why 50 layout entries did not have to be edited to say so.
const FAMILY_KENNEY := &"kenney"
const FAMILY_TREE := &"tree"
const FAMILY_MLP := &"mlp"

const FAMILY_SCALE := {
	&"kenney": BASE_SCALE,
	&"tree": BASE_SCALE * TREE_SCALE,
	&"mlp": MLP_SCALE,
}

## Node name prefixes that are foliage rather than structure. ranch.gd frames its shots and
## runs its camera-against-a-wall probe against "every prop that is not one of these": a
## canopy is a bad obstacle to prove a camera with, because the arm may be stopping on a
## leaf a player would walk straight under.
const FOLIAGE_PREFIXES := ["kenney_tree", "mlp_apple_tree"]
```

And the two statics, next to `is_in_pen_plots()`:

```gdscript
## The family `entry` belongs to. See FAMILY_SCALE.
static func family_of(entry: Dictionary) -> StringName:
	if entry.has("family"):
		return StringName(entry["family"])
	var file: String = entry["file"]
	if file.begins_with("kenney_tree"):
		return FAMILY_TREE
	return FAMILY_KENNEY


## The uniform scale `entry` is built at: its family's base, times any per-file correction
## in SCALE_FIX, times the entry's own `s` jitter. The one place these three multiply, so
## nothing can apply two of them and forget the third.
static func scale_for(entry: Dictionary) -> float:
	var file: String = entry["file"]
	var base: float = float(FAMILY_SCALE.get(family_of(entry), BASE_SCALE))
	return base * float(SCALE_FIX.get(file, 1.0)) * float(entry.get("s", 1.0))


## True if `node_name` is one of the foliage families. See FOLIAGE_PREFIXES.
static func is_foliage(node_name: String) -> bool:
	for prefix: String in FOLIAGE_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false
```

- [ ] **Step 4: Add the skirt constants and the footprint sampler**

Below `SINK_BIAS`, add:

```gdscript
## A PROP WIDER THAN THIS, STANDING OFF THE FLAT APRON, GETS A PLINTH OF ITS OWN.
##
## seat() puts the bottom of a model's AABB SINK_BIAS below the ground height at ONE point.
## That is right for a tree and wrong for a barn: the flattest 13 by 10 m rectangle anywhere
## on this map outside the homestead apron still has 0.366 m of relief across it, and the
## barn's own site has 0.643 m. Seated at one point, a wide model shows daylight under one
## corner and buries the other, and the terrain passes through its floor plane, which is a
## horizontal face and therefore z fights.
##
## game/world/building.gd solved exactly this for the procedural buildings on 2026-08-31
## (FLOOR_TOP, SKIRT_DEPTH, PLINTH_INSET). A mesh prop cannot use that answer, because a
## Building BUILDS its own plinth and a .glb's floor is whatever the modeller drew. So the
## prop gets a solid box under it instead: seated against the LOWEST of nine samples across
## its own footprint, deep enough to bridge the measured relief, inset on every side so its
## own outer face is never coplanar with the model's. The terrain then always passes through
## the SIDE of an opaque box, which is the property the Building plinth buys.
##
## SKIRT_INSET is PLINTH_INSET's number for PLINTH_INSET's reason. SKIRT_MIN_DEPTH is what
## the box has UNDER the relief it is bridging, so a 0.64 m dip gets a 1.54 m box.
## WIDE_FOOTPRINT is the longer side at which one point seating stops being good enough.
const SKIRT_INSET := 0.06
const SKIRT_MIN_DEPTH := 0.90
const WIDE_FOOTPRINT := 4.0

## Turned earth, and deliberately not a colour any of the models use: a skirt that reads as
## part of the building is a building with a strangely tall base, while a skirt that reads
## as ground the building is standing in is what it actually is.
const SKIRT_COLOUR := Color(0.21, 0.17, 0.13)
```

And beside `world_aabb()`:

```gdscript
## Ground height at the four corners, the four edge midpoints and the centre of the
## rectangle `centre` plus or minus `half`, sampled through `ground_sampler`. Returns
## (lowest, highest).
##
## Nine points and not one, for the reason game/world/building.gd's footprint_relief() takes
## nine: the height under a wide model's ORIGIN says nothing about the corner that is going
## to hang in the air. Deliberately the same shape as that function, so a reviewer reading
## one has read both; it is a free function here because a prop has no footprint of its own
## to ask, only the AABB of whatever the modeller drew.
static func footprint_relief(centre: Vector2, half: Vector2, ground_sampler: Callable) -> Vector2:
	var lowest := INF
	var highest := -INF
	for dx: float in [-half.x, 0.0, half.x]:
		for dz: float in [-half.y, 0.0, half.y]:
			var h: float = float(ground_sampler.call(centre.x + dx, centre.y + dz))
			lowest = minf(lowest, h)
			highest = maxf(highest, h)
	return Vector2(lowest, highest)


## True if a prop with this world AABB, standing on ground that is `flat` or not, has to be
## seated by its footprint and given a skirt. ranch.gd asks this of every LIVE placed prop
## and fails the gate if an entry that needs one does not carry `"skirt": true`, so the rule
## is checked against measurements rather than remembered.
static func needs_skirt(box: AABB, flat: bool) -> bool:
	return not flat and maxf(box.size.x, box.size.z) > WIDE_FOOTPRINT
```

- [ ] **Step 5: Teach `build()` families, footprint seating and skirts**

Add three fields beside `_placed`:

```gdscript
var _entries: Array[Dictionary] = []
var _skirts: Array[MeshInstance3D] = []
var _seat_grounds: Dictionary = {}
```

Replace the scale block in `build()`:

```gdscript
		var at: Vector2 = entry["at"]
		var scale_factor: float = BASE_SCALE * float(SCALE_FIX.get(file, 1.0)) \
			* float(entry.get("s", 1.0))
		if file.begins_with("kenney_tree"):
			scale_factor *= TREE_SCALE

		inst.name = "%s_%d" % [file.get_basename(), _placed.size()]
		inst.scale = Vector3.ONE * scale_factor
		inst.rotation.y = deg_to_rad(float(entry["yaw"]))
		var ground := _ground_height(at.x, at.y)
		inst.position = Vector3(at.x, ground, at.y)
		add_child(inst)

		seat(inst, ground)

		_shape_count += _add_collision(inst)
		_placed.append(inst)
```

with:

```gdscript
		var at: Vector2 = entry["at"]
		inst.name = "%s_%d" % [file.get_basename(), _placed.size()]
		inst.scale = Vector3.ONE * scale_for(entry)
		inst.rotation.y = deg_to_rad(float(entry["yaw"]))
		var ground := _ground_height(at.x, at.y)
		inst.position = Vector3(at.x, ground, at.y)
		add_child(inst)

		# Measured AFTER the scale and the yaw are applied and the node is in the tree:
		# world_aabb() is a world space measurement, and a footprint is the footprint of
		# the model as it will actually stand.
		var box := world_aabb(inst)
		var centre := Vector2(box.get_center().x, box.get_center().z)
		var half := Vector2(box.size.x * 0.5, box.size.z * 0.5)
		var relief := Vector2(ground, ground)
		var skirted: bool = bool(entry.get("skirt", false))
		if skirted:
			relief = footprint_relief(centre, half, Callable(self, "_ground_height"))
			ground = relief.x

		seat(inst, ground)
		_seat_grounds[inst] = ground

		if skirted:
			_add_skirt(inst, centre, half, relief.y - relief.x, ground)

		_shape_count += _add_collision(inst)
		_placed.append(inst)
		_entries.append(entry)
```

Add the skirt builder next to `_add_collision()`:

```gdscript
## A solid box under a wide prop, so the terrain always passes through the SIDE of
## something opaque instead of through a horizontal face. See SKIRT_INSET above for the
## whole argument, and game/world/building.gd's PLINTH_INSET for the same fix on the
## procedural buildings.
##
## PARENTED TO Props, NOT TO THE PROP, and that is load bearing. world_aabb() is what
## seat() and ranch.gd's seating check both measure, and a box hanging below the model
## would move the bottom they read: every skirted prop would report itself sunk by the
## skirt's whole depth and the gate would go red on a correctly placed barn. As a sibling
## it is collided and layered like any prop and is deliberately absent from _placed, so it
## never enters the census either.
func _add_skirt(inst: Node3D, centre: Vector2, half: Vector2, relief: float,
		top: float) -> MeshInstance3D:
	var depth: float = relief + SKIRT_MIN_DEPTH
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(0.2, (half.x - SKIRT_INSET) * 2.0), depth,
		maxf(0.2, (half.y - SKIRT_INSET) * 2.0))
	var material := StandardMaterial3D.new()
	material.albedo_color = SKIRT_COLOUR
	material.roughness = 0.95
	mesh.material = material

	var skirt := MeshInstance3D.new()
	skirt.name = "%s_skirt" % inst.name
	skirt.mesh = mesh
	add_child(skirt)
	# Its top face meets the model's own floor, which seat() has just put SINK_BIAS below
	# the lowest footprint sample.
	skirt.global_position = Vector3(centre.x, top - SINK_BIAS - depth * 0.5, centre.y)
	_shape_count += _add_collision(skirt)
	_skirts.append(skirt)
	return skirt
```

And the three accessors, next to `get_placed()`:

```gdscript
## The LAYOUT entry a placed prop came from, or {} for anything Props did not place.
func entry_of(node: Node3D) -> Dictionary:
	var index := _placed.find(node)
	return _entries[index] if index >= 0 else {}


## True if Props seated `node` and recorded the height it used.
func has_seat_ground(node: Node3D) -> bool:
	return _seat_grounds.has(node)


## The ground height `node` was actually seated against: the height under its origin for
## an ordinary prop, the lowest of nine footprint samples for a skirted one. ranch.gd's
## seating check reads this rather than re-deriving it, for the same reason it reads
## Building.seat_ground() for a building: the number a prop was seated by and the number
## the gate checks it against must not be able to drift apart.
func seat_ground_of(node: Node3D) -> float:
	return float(_seat_grounds.get(node, 0.0))


## Every skirt box standing under a wide prop. Not props, not in the census; ranch.gd
## checks their collision layer alongside the props' own.
func get_skirts() -> Array[MeshInstance3D]:
	return _skirts
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_props.gd -gexit 2>&1 | tail -12
```
Expected: 17 passing, 0 failing.

- [ ] **Step 7: Commit the new script's uid and run the whole suite**

```bash
tools/bin/godot --headless --path game --import
bash tools/run_tests.sh 2>&1 | tail -12
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 \
  | grep -E "RANCH props|RANCH_OK|RANCH_FAILED"
```
Expected: the suite green, and the ranch still reporting `RANCH_OK ponies=49 props=60 assets=present`. This task must not move a single number on the map.

- [ ] **Step 8: Commit**

```bash
printf 'feat: prop families, footprint seating and skirts under the wide props\n\nA LAYOUT entry may now name a family, and the family carries the base scale: a\nKenney kit piece at BASE_SCALE, a Nature Kit tree at BASE_SCALE times TREE_SCALE,\nan MLP prop at MLP_SCALE, which REPLACES BASE_SCALE because a Source model and a\nKenney door module are two unrelated conventions. An entry with no family is a\nKenney piece, and a kenney_tree file is a tree, so the 54 shipped entries keep\nexactly the scales they have today.\n\nAn entry may also carry skirt: true. A skirted prop is seated against the lowest\nof nine samples across its own measured footprint instead of the height under its\norigin, and gets a solid box under it, inset on every side and deep enough to\nbridge the measured relief, so the terrain passes through the side of something\nopaque rather than through a horizontal floor plane. The flattest 13 by 10 m\nrectangle off the homestead apron still has 0.366 m of relief across it; there is\nno siting that avoids this. The box is parented to Props rather than to the prop,\nbecause world_aabb() is what seat() and the gate both measure.\n\ngame/test/test_props.gd covers the rules as pure functions, plus the pen plot and\nregion fence clearances over the whole shipped layout. Nothing on the map moves.\n' > /tmp/props-engine-commit.txt
git add game/world/props.gd game/test/test_props.gd game/test/test_props.gd.uid
git commit -F /tmp/props-engine-commit.txt
```

---

### Task 4: Sweet Apple Acres, the apple trees and Ponyville General (props 60 to 94)

**Files:**
- Modify: `game/world/props.gd` (LAYOUT: one entry deleted, six edited in place, 35 added; three comments), `game/test/test_ranch_world.gd:145-149`, `docs/pipeline.md`, `docs/testing.md`, `docs/distribution.md`, `docs/windows-testing.md`
- Test: `game/test/test_ranch_world.gd`, `game/test/test_props.gd` (no new tests; both files' existing sweeps now walk 88 entries)

**Interfaces:**
- Consumes: `Props.FAMILY_MLP`, `Props.scale_for()`, `Props.footprint_relief()`, the `"skirt"` key and `Props.entry_of()` from Task 3; the converted files `saa_barn.glb`, `saa_shed.glb`, `saa_wagon.glb`, `saa_hay_pile.glb`, `saa_wire_arch.glb`, `saa_water_chute.glb`, `saa_seed_bag.glb`, `saa_fence_old.glb`, `saa_corn_plant.glb`, `saa_corn_plant_dead.glb`, `mlp_bush.glb`, `mlp_apple_tree.glb`, `mlp_apple_tree_bare.glb`, `pv_general.glb`, `pv_general_sign.glb` from Task 1.
- Produces: `Props.LAYOUT` at 88 entries, so `ranch.gd` reports `RANCH_OK ponies=49 props=94 assets=present`; `game/test/test_ranch_world.gd`'s `PROP_PREFIXES`, which Task 5's new files must also match.

**The arithmetic, so the census move is checkable rather than hopeful.** 54 entries today. One is deleted (`kenney_survival_structure.glb`). Six are edited in place, keeping their exact coordinates: the Orchard's Kenney oaks and fats become apple trees, so the count does not move and the six positions keep the clearance property they were sited for. 35 are added. 54 minus 1 plus 35 is 88, plus the six `Buildings` children is 94.

**Why the six Orchard positions are reused rather than replanted.** `props.gd`'s comment states the rule and the existing entries obey it: every region tree stands at least 4 m past the fence ring, which is radius plus 7, and outside every `ZoneMarker` disc. All six sit at exactly radius 31 from the Orchard centre `(72, 40)`. Changing the file on those lines is the smallest possible change that puts apple trees in an apple orchard, and it cannot break a clearance that was already verified.

**Where the new planting stands, and the one rule it all had to satisfy.** The Orchard region is priced, so its fence ring is at 22 plus 3, and a prop must clear it by 4: nothing below may stand within 29 m of `(72, 40)`. That constraint is what pushed the corn patch north and the wagon east; every coordinate in the block below was checked against it, and `game/test/test_props.gd`'s `test_every_prop_stands_clear_of_every_priced_region_fence_ring` is what keeps it true.

- [ ] **Step 1: Widen the source check first, and watch it stay green**

`game/test/test_ranch_world.gd:145-149` asserts every layout file begins with `kenney_`. Replace that function and add the constant above it:

```gdscript
## THE TWO KITS THE MAP IS DRESSED FROM. Kenney for the yard fixtures and the treeline;
## the converted PonySFM props for Sweet Apple Acres, Ponyville General, the town row, the
## schoolyard and the Strip. Every prefix here is an id prefix in tools/prop_manifest.txt,
## which is the only thing tools/convert_props.sh will produce. A file with any other
## prefix is one nothing converts, so it would never load on any machine: it would quietly
## lower expected_count() instead of failing, and the layout would be one prop short
## everywhere with nothing saying so.
const PROP_PREFIXES := ["kenney_", "saa_", "pv_", "mlp_", "school_", "lp_"]


func test_every_layout_entry_names_a_prop_from_the_converted_kit() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		var file: String = entry["file"]
		var known := false
		for prefix: String in PROP_PREFIXES:
			if file.begins_with(prefix):
				known = true
				break
		assert_true(known, "unexpected prop source: %s" % file)
		assert_eq(file.get_extension(), "glb", "props are loaded as .glb: %s" % file)
```

Run it before touching the layout, so the widening is proved not to have broken the check it replaces:

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_ranch_world.gd -gexit 2>&1 | tail -8
```
Expected: green, on the 54 entry layout that is still all Kenney.

- [ ] **Step 2: Retire the survival structure, and say why in `SCALE_FIX`**

Delete this line from `LAYOUT`:

```gdscript
	{"file": "kenney_survival_structure.glb", "at": Vector2(14.0, 2.0), "yaw": 90.0},
```

and extend the `SCALE_FIX` comment so the measured defect stays written down where `docs/pipeline.md` points at it:

```gdscript
## Per-file multiplier ON TOP of BASE_SCALE. Only ever for a prop whose shipped
## asset is at a known-wrong scale.
##
## kenney_survival_structure.glb IS NO LONGER IN LAYOUT and its entry below stays anyway.
## docs/pipeline.md section 4 quirk 5 calls it an open timber frame that "reads as farm
## equipment abandoned in a field"; the Ponyville General store stands where it used to,
## across the Market yard. The correction is a MEASUREMENT of a defect in that pack's FBX
## branch (2.0 units as Kenney's own GLB, 0.50 after the round trip), not a decoration on
## a layout line, so it is kept for anyone who re places the prop and so the doc that
## records the defect still has something to point at.
const SCALE_FIX := {
	"kenney_survival_structure.glb": 4.0,  # FBX unit-conversion defect, quirk 4.
}
```

- [ ] **Step 3: Turn the six Orchard Kenney trees into apple trees**

Replace these six lines under the `# The Orchard, (72, 40) r 22:` comment:

```gdscript
	{"file": "kenney_tree_oak.glb", "at": Vector2(101.1, 50.6), "yaw": 25.0, "s": 1.20},
	{"file": "kenney_tree_fat.glb", "at": Vector2(87.5, 66.8), "yaw": 140.0, "s": 1.10},
	{"file": "kenney_tree_oak.glb", "at": Vector2(66.6, 70.5), "yaw": 265.0, "s": 1.25},
	{"file": "kenney_tree_fat.glb", "at": Vector2(48.3, 59.9), "yaw": 60.0, "s": 1.05},
	{"file": "kenney_tree_oak.glb", "at": Vector2(87.5, 13.2), "yaw": 195.0, "s": 1.15},
	{"file": "kenney_tree_fat.glb", "at": Vector2(98.8, 24.5), "yaw": 310.0, "s": 1.20},
```

with:

```gdscript
	# APPLE TREES, ON THE SAME SIX POINTS. The Kenney Nature Kit's foliage is a flat
	# cyan/mint swatch (docs/pipeline.md section 4 quirk 6: it is Kenney's authored
	# "leafsGreen" colour, checked and not a colour space bug), which read as a lawn
	# ornament in an orchard the player pays a permit to reach. These six coordinates are
	# unchanged on purpose: each sits at exactly radius 31 from the region centre, which is
	# the fence ring plus the 4 m every planted tree clears it by, and reusing them cannot
	# break a clearance that was already verified.
	{"file": "mlp_apple_tree.glb", "at": Vector2(101.1, 50.6), "yaw": 25.0, "s": 1.20, "family": &"mlp"},
	{"file": "mlp_apple_tree.glb", "at": Vector2(87.5, 66.8), "yaw": 140.0, "s": 1.10, "family": &"mlp"},
	{"file": "mlp_apple_tree_bare.glb", "at": Vector2(66.6, 70.5), "yaw": 265.0, "s": 1.25, "family": &"mlp"},
	{"file": "mlp_apple_tree.glb", "at": Vector2(48.3, 59.9), "yaw": 60.0, "s": 1.05, "family": &"mlp"},
	{"file": "mlp_apple_tree.glb", "at": Vector2(87.5, 13.2), "yaw": 195.0, "s": 1.15, "family": &"mlp"},
	{"file": "mlp_apple_tree_bare.glb", "at": Vector2(98.8, 24.5), "yaw": 310.0, "s": 1.20, "family": &"mlp"},
```

- [ ] **Step 4: Add Sweet Apple Acres and the General**

Append this block at the END of `LAYOUT`, after the Night Meadow windbreak:

```gdscript
	# --- Sweet Apple Acres, on the walk out to the Orchard --------------------------
	# APPLEJACK'S FARM, NOT THE PLAYER'S. The homestead keeps its own procedural red barn
	# (game/world/building.gd says why it is code and not a mesh, and both reasons still
	# hold); this is the farm the orchard belongs to, on the walk out to it. Nothing here
	# is walked into: an MLP mesh prop is SCENERY. No attendant stands at one, no dock
	# marker sits on one, and ranch.gd checks that no prop's collider reaches inside a
	# building's interaction radius, so the only doors the game opens stay procedural.
	#
	# The barn, the shed and the town row carry "skirt": true. Everything within 29 m of
	# the Orchard centre (72, 40) is inside its fence ring plus the 4 m margin every prop
	# clears it by, so nothing below is: test_props.gd checks that on every entry.
	{"file": "saa_barn.glb", "at": Vector2(41.0, 51.3), "yaw": 205.0, "family": &"mlp", "skirt": true},
	{"file": "saa_shed.glb", "at": Vector2(34.0, 45.0), "yaw": 160.0, "family": &"mlp", "skirt": true},
	{"file": "saa_wagon.glb", "at": Vector2(46.0, 58.0), "yaw": 75.0, "family": &"mlp"},
	{"file": "saa_hay_pile.glb", "at": Vector2(35.0, 42.0), "yaw": 20.0, "family": &"mlp"},
	{"file": "saa_hay_pile.glb", "at": Vector2(37.5, 40.5), "yaw": 200.0, "family": &"mlp", "s": 0.90},
	{"file": "saa_wire_arch.glb", "at": Vector2(32.0, 52.0), "yaw": 115.0, "family": &"mlp"},
	{"file": "saa_water_chute.glb", "at": Vector2(34.0, 66.0), "yaw": 250.0, "family": &"mlp"},
	{"file": "saa_seed_bag.glb", "at": Vector2(33.0, 47.0), "yaw": 40.0, "family": &"mlp"},
	{"file": "saa_fence_old.glb", "at": Vector2(30.0, 48.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "saa_fence_old.glb", "at": Vector2(30.0, 54.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "saa_fence_old.glb", "at": Vector2(49.0, 63.0), "yaw": 90.0, "family": &"mlp"},
	{"file": "saa_fence_old.glb", "at": Vector2(48.0, 67.0), "yaw": 90.0, "family": &"mlp"},
	# The corn patch: two rows of six. The two dead stalks are placed, not drawn from an
	# RNG, for the same reason the treeline's size jitter is: a hand varied row is
	# reproducible, and reproducibility is what makes a screenshot regression legible.
	{"file": "saa_corn_plant.glb", "at": Vector2(30.0, 58.0), "yaw": 10.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(33.0, 58.0), "yaw": 200.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(36.0, 58.0), "yaw": 95.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(39.0, 58.0), "yaw": 280.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(42.0, 58.0), "yaw": 150.0, "family": &"mlp"},
	{"file": "saa_corn_plant_dead.glb", "at": Vector2(45.0, 58.0), "yaw": 25.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(30.0, 61.0), "yaw": 320.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(33.0, 61.0), "yaw": 60.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(36.0, 61.0), "yaw": 240.0, "family": &"mlp"},
	{"file": "saa_corn_plant_dead.glb", "at": Vector2(39.0, 61.0), "yaw": 130.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(42.0, 61.0), "yaw": 300.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(45.0, 61.0), "yaw": 175.0, "family": &"mlp"},
	# Hedging, so the yard has an edge that is not a fence.
	{"file": "mlp_bush.glb", "at": Vector2(38.0, 43.5), "yaw": 0.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(42.0, 42.0), "yaw": 140.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(33.0, 56.0), "yaw": 260.0, "family": &"mlp"},
	# Apple trees along the walk itself, so the orchard starts before the fence does.
	{"file": "mlp_apple_tree.glb", "at": Vector2(30.0, 40.0), "yaw": 75.0, "family": &"mlp", "s": 1.05},
	{"file": "mlp_apple_tree.glb", "at": Vector2(30.0, 44.0), "yaw": 30.0, "family": &"mlp", "s": 1.10},
	{"file": "mlp_apple_tree.glb", "at": Vector2(33.0, 50.0), "yaw": 150.0, "family": &"mlp", "s": 1.00},
	{"file": "mlp_apple_tree.glb", "at": Vector2(47.0, 60.0), "yaw": 245.0, "family": &"mlp", "s": 1.15},
	{"file": "mlp_apple_tree.glb", "at": Vector2(38.0, 64.0), "yaw": 300.0, "family": &"mlp", "s": 1.05},
	{"file": "mlp_apple_tree_bare.glb", "at": Vector2(27.0, 64.0), "yaw": 100.0, "family": &"mlp", "s": 1.10},
	# --- Ponyville General, across the Market yard ----------------------------------
	# WHERE kenney_survival_structure USED TO STAND, and the Market itself is untouched.
	# Replacing the Market with a mesh would drop it out of buildings.get_child_count() and
	# therefore out of the census, lose the door apron ATTENDANT_CLEARANCE steps the vendor
	# sideways out of, and put a 58,034 triangle two storey shop where a 4.5 m radius
	# interaction check expects an origin. So the General stands BESIDE it: 21.0 m from the
	# Market's origin, 10.8 m from the Depot's, 11.2 m from the Farmhouse's, and inside
	# Terrain's flat apron, where the relief across its footprint is exactly zero and it
	# needs no skirt. Its sign stands 6.1 m out from the Market door: past MARKET_RADIUS
	# and past the 2.8 m door apron, so it dresses the door without standing in it.
	{"file": "pv_general.glb", "at": Vector2(19.0, -2.0), "yaw": 250.0, "family": &"mlp"},
	{"file": "pv_general_sign.glb", "at": Vector2(-1.0, 5.0), "yaw": 200.0, "family": &"mlp"},
```

- [ ] **Step 5: Fix the two `LAYOUT` comments that now describe a map that is gone**

In the `LAYOUT` doc comment, the sentence "the survival structure is the barn beside the yard" names a prop that no longer exists, and "Note what is NOT here: a house or a barn" is no longer true. Replace those two sentences:

```gdscript
## Read as a picture: the windmill is the tall thing you see from anywhere on the
## map and steer by; the watermill is the farmhouse you spawn facing; the stall is the
## clutter that makes a yard look lived in; Ponyville General stands across the yard where
## an open Kenney timber frame used to. Trees ring the open country and thin out toward the
## buildings, so the homestead reads as a clearing somebody made rather than a field with
## objects dropped on it. `y` is never specified -- every prop is sat on height_at() so
## nothing floats and nothing sinks.
```

and

```gdscript
## The ranch's OWN buildings are still not in here and still not meshes: game/world/
## building.gd assembles them from primitives, because they are in git, they exist in CI
## and in a fresh clone, and their doorways are asserted against MIN_DOOR_CLEARANCE. What
## the MLP props below are is scenery: a farm on the walk to the Orchard, a shop across the
## yard, a town on the road north. Nothing here is ever walked into.
```

- [ ] **Step 6: Run the gate and read the numbers back**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 \
  | grep -E "RANCH prop (saa|pv|mlp)|RANCH props |RANCH_OK|RANCH_FAILED|FAILED check"
```
Expected: `RANCH props placed=94 expected=94 shapes=<n> missing=-` and `RANCH_OK ponies=49 props=94 assets=present`, exit 0. Every `RANCH prop saa_...` line should show `seat_error=+0.000`; a non zero seat error on a skirted prop means the footprint sampler and the seating check disagree, which Task 3's `seat_ground_of()` exists to prevent.

If `missing=` names a file, that model did not convert: `bash tools/convert_props.sh --only <id> --force` and re-import.

- [ ] **Step 7: Run the suite**

```bash
bash tools/run_tests.sh 2>&1 | tail -12
```
Expected: green. Both `test_props.gd`'s layout sweeps and `test_ranch_world.gd`'s widened source check now walk 88 entries.

- [ ] **Step 8: Carry the census through all six documents, in this commit**

`RANCH_OK ponies=49 props=60 assets=present` is quoted verbatim in six places. Change `props=60` to `props=94` in every one:

```bash
grep -rn "props=60" docs/
sed -i 's/props=60/props=94/g' docs/distribution.md docs/testing.md docs/pipeline.md docs/windows-testing.md
grep -rn "props=60\|props=94" docs/
```
Expected after: no `props=60` anywhere, and six `props=94` lines (`docs/distribution.md` twice, `docs/pipeline.md` twice, `docs/testing.md` once, `docs/windows-testing.md` once).

Then mark the outstanding asset task resolved. In `docs/pipeline.md` section 4, quirk 5's row ends by naming "find a pack that ships whole buildings" as the fix. Append to that cell:

```markdown
**Resolved 2026-09-01.** `tools/prop_manifest.txt` and §5c convert the Sweet Apple
Acres barn and shed, Ponyville General and six Ponyville Environments town
buildings out of the PonySFM packs, and `game/world/props.gd` stands them on the
map. The Kenney kit still ships no buildings; the ranch's own barn, farmhouse,
Market, board, Depot and Palace are still `game/world/building.gd` primitives, and
still are for the reasons that file's class comment gives.
```

- [ ] **Step 9: Commit**

```bash
printf 'feat: Sweet Apple Acres, apple trees and Ponyville General\n\nThe walk out to the Orchard now passes a farm: the SFM barn and shed on skirts,\na wagon, two hay piles, a wire arch, a water chute, a seed bag, four lengths of\nold fence, a twelve plant corn patch with two dead stalks in it, three bushes and\nsix apple trees. The Orchard region trees stay on the six coordinates they were\nsited at and become apple trees, because the Kenney Nature Kit foliage is a flat\ncyan swatch and this is an orchard the player pays a permit to reach.\n\nPonyville General stands across the Market yard where the Kenney survival\nstructure used to, 21.0 m from the Market origin and inside the flat apron, with\nits sign 6.1 m out from the Market door: past the interaction radius and past the\ndoor apron. The Market itself is untouched, and so is every door the game walks\nthrough. The survival structure keeps its SCALE_FIX entry, because that entry\nrecords a measured defect in the pack rather than a decoration on a layout line.\n\nprops 60 to 94, carried through all six documents that quote the line, and\npipeline section 4 quirk 5 marked resolved.\n' > /tmp/saa-commit.txt
git add game/world/props.gd game/test/test_ranch_world.gd docs/pipeline.md docs/testing.md docs/distribution.md docs/windows-testing.md
git commit -F /tmp/saa-commit.txt
```

---

### Task 5: The town row, the schoolyard, the arcade and the yard (props 94 to 110)

**Files:**
- Modify: `game/world/props.gd` (LAYOUT: five entries deleted, 21 added; one comment), `docs/pipeline.md`, `docs/testing.md`, `docs/distribution.md`, `docs/windows-testing.md`
- Test: `game/test/test_props.gd`, `game/test/test_ranch_world.gd` (existing sweeps, now over 104 entries)

**Interfaces:**
- Consumes: everything Task 3 produced, plus the converted files `pv_tower_b.glb`, `pv_wide_b.glb`, `pv_pink_b.glb`, `pv_courtyard_b.glb`, `pv_balcony_b.glb`, `pv_bridged_b.glb`, `school_belltower.glb`, `school_sign.glb`, `school_swingframe.glb`, `school_horseshoe.glb`, `school_tetherball_pole.glb`, `school_picnic_table.glb`, `school_cone.glb`, `lp_skeeball.glb`, `lp_dance_game.glb`, `saa_hay_block.glb`, `mlp_crate.glb`, `mlp_basket.glb`, `mlp_farm_well.glb`, `mlp_chicken_coop.glb`; `saa_wagon.glb` again.
- Produces: `Props.LAYOUT` at 104 entries, so `ranch.gd` reports `RANCH_OK ponies=49 props=110 assets=present`. This is the layout Task 6's new checks and screenshots are written against, and after it every one of `tools/prop_manifest.txt`'s 35 models is named by at least one entry.

**The arithmetic.** 88 entries after Task 4. Five are deleted, 21 are added: 88 minus 5 plus 21 is 104, plus six buildings is 110.

**Why five Kenney trees come out.** Four of them stand in the corridor the town row now occupies (`(-2, 31)`, `(21, 36)`, `(12, 42)` and `(-22, 27)`, all on the road north), and the fifth, `kenney_tree_fat` at `(17, 7.5)`, is one of the two the layout comment calls "inside the clearing, for shade": the homestead yard is where the crates, the basket, the well and the coop go, and one shade tree in the middle of it is one too many. The oak at `(-20, 1)` stays, so the clearing keeps a tree. **`kenney_tree_oak` at `(14, 27)` must NOT be removed**: `ranch.gd`'s own class comment records that HomePasture's 6.5 m spawn radius is the largest circle at `(7, 19)` that clears the pen plots to the west and that oak to the north east, so deleting it silently unpins a marker radius that was measured against it.

**Where the town goes, and what it had to avoid.** The road north runs from the homestead at `(0, -4)` to the Strip at `(0, 74)`. The row stands at `x = 15` on the east side and `x = -12` on the west, at `z = 36`, `43` and `50`, which clears `HomePasture`'s 12.15 m outer bound, `SouthOrchard`'s 15.15 m, and the Strip region disc at radius 26. The schoolyard sits west of the road around `(-26, 58)`: outside `SouthOrchard`, outside the Night Meadow fence ring plus its margin, west of the Palace's own rectangle (`x` in [-17, -3], `z` in [57.1, 66.1]) and past `PALACE_RADIUS`. The two arcade games stand in the Strip's clear band, `x` in [-2, 18] and `z` in [67, 72], which is the ground between the Palace and the race track's south rail at `z = 72.2`, and well inside the ten position lamp ring of radius 21.

- [ ] **Step 1: Delete the five Kenney tree entries**

Remove these five lines from `LAYOUT`, each of which appears exactly once:

```gdscript
	{"file": "kenney_tree_default.glb", "at": Vector2(-22.0, 27.0), "yaw": 120.0, "s": 1.05},
	{"file": "kenney_tree_pine.glb", "at": Vector2(-2.0, 31.0), "yaw": 90.0, "s": 1.15},
	{"file": "kenney_tree_default.glb", "at": Vector2(12.0, 42.0), "yaw": 200.0, "s": 1.10},
	{"file": "kenney_tree_pine.glb", "at": Vector2(21.0, 36.0), "yaw": 55.0, "s": 1.20},
	{"file": "kenney_tree_fat.glb", "at": Vector2(17.0, 7.5), "yaw": 35.0, "s": 1.05},
```

and change the comment above the last of them, which now describes one tree rather than two:

```gdscript
	# One inside the clearing, for shade and to break up the yard. Its neighbour at
	# (17, 7.5) came out when the yard grew crates, a basket, a well and a coop; a shade
	# tree in the middle of that is a tree in the middle of a yard.
	{"file": "kenney_tree_oak.glb", "at": Vector2(-20.0, 1.0), "yaw": 165.0, "s": 1.10},
```

- [ ] **Step 2: Add the town row, the schoolyard, the arcade and the yard scatter**

Append at the END of `LAYOUT`, after the Ponyville General pair:

```gdscript
	# --- the town row, on the road north --------------------------------------------
	# SIX PONYVILLE ENVIRONMENTS BUILDINGS, three a side, facing the road. They are
	# scenery: none has a door the game opens, none is an interaction candidate, and
	# ranch.gd fails if any of their colliders reaches inside a building's interaction
	# radius. All six carry a skirt: they are wide and they stand well outside Terrain's
	# flat apron, which is exactly the case Props.needs_skirt() names.
	#
	# The pack ships a gb_ ground decal and an _m mirror for every one of these;
	# tools/convert_props.sh refuses both by name, so nothing in this block can be one.
	{"file": "pv_tower_b.glb", "at": Vector2(15.0, 36.0), "yaw": 270.0, "family": &"mlp", "skirt": true},
	{"file": "pv_wide_b.glb", "at": Vector2(15.0, 43.0), "yaw": 270.0, "family": &"mlp", "skirt": true},
	{"file": "pv_pink_b.glb", "at": Vector2(15.0, 50.0), "yaw": 270.0, "family": &"mlp", "skirt": true},
	{"file": "pv_courtyard_b.glb", "at": Vector2(-12.0, 36.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
	{"file": "pv_balcony_b.glb", "at": Vector2(-12.0, 43.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
	{"file": "pv_bridged_b.glb", "at": Vector2(-12.0, 50.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
	# --- the schoolyard, west of the road --------------------------------------------
	# A SCHOOLYARD AND NO SCHOOL, and that is the pack rather than an omission.
	# ponysfm-schoolhouse ships school_roof, school_door, school_window, school_sign,
	# porchroof, porchtop, support_beam_school and belltower: a modular kit for a Source
	# map with no assembled building in it, the same trap docs/pipeline.md section 4 quirk
	# 5 records for the Kenney Fantasy Town Kit. So the bell tower stands over a yard with
	# swings, a horseshoe pit, a tetherball pole, a picnic table and a cone, and the
	# schoolhouse is a building this project does not have an asset for.
	#
	# The pack's swingseat.mdl is not converted: Props.seat() puts the bottom of a model on
	# the ground, so a seat meant to hang from the frame would be placed standing on it.
	{"file": "school_belltower.glb", "at": Vector2(-26.0, 58.0), "yaw": 100.0, "family": &"mlp", "skirt": true},
	{"file": "school_sign.glb", "at": Vector2(-22.0, 54.0), "yaw": 120.0, "family": &"mlp"},
	{"file": "school_swingframe.glb", "at": Vector2(-30.0, 55.0), "yaw": 20.0, "family": &"mlp"},
	{"file": "school_horseshoe.glb", "at": Vector2(-30.0, 61.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "school_tetherball_pole.glb", "at": Vector2(-23.0, 61.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "school_picnic_table.glb", "at": Vector2(-27.0, 63.0), "yaw": 45.0, "family": &"mlp"},
	{"file": "school_cone.glb", "at": Vector2(-21.0, 58.0), "yaw": 0.0, "family": &"mlp"},
	# --- Las Pegasus, on the Strip -----------------------------------------------------
	# THE CLEAR BAND BETWEEN THE PALACE AND THE RACE TRACK: x in [-2, 18], z in [67, 72].
	# The Palace's own rectangle is x in [-17, -3], z in [57.1, 66.1]; race_track.gd's south
	# rail is at z = 87.8 with the near one at z = 72.2; strip.gd's lamp ring is radius 21
	# about (0, 74), so both of these stand inside the ring rather than in it, and
	# Strip.avoid_footprint() is not asked to drop a lamp for them.
	#
	# They are cabinets, not tables: the games the player actually plays are casino_menu's,
	# and nothing here is an interaction candidate. They are what makes the Strip look like
	# somewhere people go.
	{"file": "lp_skeeball.glb", "at": Vector2(4.0, 69.0), "yaw": 180.0, "family": &"mlp", "skirt": true},
	{"file": "lp_dance_game.glb", "at": Vector2(11.0, 69.0), "yaw": 180.0, "family": &"mlp", "skirt": true},
	# --- the homestead yard ------------------------------------------------------------
	# INSIDE TERRAIN'S FLAT APRON, where the ground is exactly y = 0 by construction, so
	# none of these needs a skirt. Every one stands clear of the pen plot clearing
	# (PEN_PLOTS_CENTRE (-14, 13), half extent 9) and outside MARKET_RADIUS 4.5,
	# BOARD_RADIUS 3.0 and DEPOT_RADIUS 4.0 from the buildings they sit between; ranch.gd
	# measures both of those against the LIVE colliders rather than against these origins.
	{"file": "saa_hay_block.glb", "at": Vector2(-3.5, -14.0), "yaw": 15.0, "family": &"mlp"},
	{"file": "saa_wagon.glb", "at": Vector2(7.5, -13.5), "yaw": 200.0, "family": &"mlp"},
	{"file": "mlp_crate.glb", "at": Vector2(4.0, 7.0), "yaw": 30.0, "family": &"mlp"},
	{"file": "mlp_basket.glb", "at": Vector2(2.5, 6.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "mlp_farm_well.glb", "at": Vector2(-3.0, 5.0), "yaw": 60.0, "family": &"mlp"},
	{"file": "mlp_chicken_coop.glb", "at": Vector2(-8.0, -2.0), "yaw": 250.0, "family": &"mlp"},
```

- [ ] **Step 3: Run the gate**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 \
  | grep -E "RANCH prop (pv_|school_|lp_|mlp_|saa_)|RANCH props |RANCH strip|RANCH_OK|RANCH_FAILED|FAILED check"
```
Expected: `RANCH props placed=110 expected=110 shapes=<n> missing=-`, `RANCH strip lamps=9 clear=true` unchanged (neither arcade cabinet is inside the Palace rectangle, so no lamp is dropped for them), and `RANCH_OK ponies=49 props=110 assets=present`, exit 0.

- [ ] **Step 4: Run the suite**

```bash
bash tools/run_tests.sh 2>&1 | tail -12
```
Expected: green, with `test_props.gd`'s pen plot and fence ring sweeps now walking 104 entries.

- [ ] **Step 5: Carry the census again, in this commit**

```bash
grep -rn "props=94" docs/
sed -i 's/props=94/props=110/g' docs/distribution.md docs/testing.md docs/pipeline.md docs/windows-testing.md
grep -rn "props=94\|props=110" docs/
```
Expected after: no `props=94` anywhere and six `props=110` lines.

- [ ] **Step 6: Commit**

```bash
printf 'feat: a town row, a schoolyard, two arcade games and a lived in yard\n\nThe road north gains six Ponyville Environments buildings, three a side, all on\nskirts because they are wide and stand well off the flat apron. West of them is a\nschoolyard: a bell tower, a sign, a swing frame, a horseshoe pit, a tetherball\npole, a picnic table and a cone. There is no schoolhouse because the pack ships\nnone: it is a modular kit of roofs, doors, windows and beams with no assembled\nbuilding in it, the same trap the Kenney Fantasy Town Kit set, and that finding is\nrecorded in the layout rather than rediscovered later.\n\nThe Strip gains the skeeball and dance cabinets, in the clear band between the\nPalace and the race track rail, inside the lamp ring and outside the Palace\nrectangle, so the lamp count does not move. The homestead yard gains hay, a cart,\na crate, a basket, a well and a chicken coop, all inside the flat apron and all\nclear of the pen plot clearing and of every building interaction radius.\n\nFive Kenney trees come out: four stood in the road the town row now occupies, and\none stood in the middle of the yard. The oak at (14, 27) stays, because\nHomePasture s spawn radius was measured against it.\n\nprops 94 to 110, carried through all six documents that quote the line.\n' > /tmp/town-commit.txt
git add game/world/props.gd docs/pipeline.md docs/testing.md docs/distribution.md docs/windows-testing.md
git commit -F /tmp/town-commit.txt
```

---

### Task 6: The checks, the renders, the docs and the floor

**Files:**
- Modify: `game/world/ranch.gd` (the prop check block in `_report()`, `_buildings_by_height()`, the capture pass, two new helpers, two new constants), `tools/run_tests.sh`, `docs/testing.md`, `docs/ci.md`
- Test: the whole suite, every gate, and a render pass

**Interfaces:**
- Consumes: `Props.entry_of()`, `Props.has_seat_ground()`, `Props.seat_ground_of()`, `Props.get_skirts()`, `Props.family_of()`, `Props.needs_skirt()`, `Props.is_foliage()`, `Props.FAMILY_MLP`, `Props.MLP_SCALE`, `Props.MLP_TARGET_BARN_RIDGE` (Tasks 2 and 3); `Terrain.is_flat_at(x, z)`; `MARKET_RADIUS` 4.5, `BOARD_RADIUS` 3.0, `DEPOT_RADIUS` 4.0, `PALACE_RADIUS` 6.0 (all already on `ranch.gd`); the 110 prop layout (Task 5).
- Produces: three new `_report()` checks, two new `RANCH` lines, five new screenshots (`13_sweet_apple_acres`, `14_ponyville_general`, `15_town_row_north_road`, `16_schoolyard`, `17_strip_arcade`), and `MIN_TESTS` at the number the suite actually reports.

**What is NOT checked here, and why.** There is no "every prop stands outside every `ZoneMarker` disc" gate. The shipped map already puts `kenney_tree_oak` at `(14, 27)` about 10.6 m from `HomePasture` at `(7, 19)`, whose outer bound is 12.15 m, and that is deliberate: `ranch.gd`'s class comment records that the marker's SPAWN radius was sized to clear that oak, and the spawner rerolls any placement whose ground ray hits a prop. Writing a gate that fails on a layout the project chose on purpose would mean loosening it until it proved nothing. The clearance that IS a rule, four metres past every priced region's fence ring, is unit tested over the whole layout in `game/test/test_props.gd`.

- [ ] **Step 1: Add the two constants**

In `game/world/ranch.gd`, beside `SEATING_TOLERANCE`:

```gdscript
## The model Props.MLP_SCALE was derived from, and how far its seated height may drift from
## Props.MLP_TARGET_BARN_RIDGE before that derivation is stale. The arithmetic is exact
## (MLP_SCALE is the target divided by the measured native height), so this tolerance is
## not slack for the division: it is what catches the barn's layout entry quietly growing
## an `s` jitter, or a re-conversion coming out at a different size.
const BARN_MODEL := "saa_barn.glb"
const MLP_RIDGE_TOLERANCE := 0.25
```

- [ ] **Step 2: Add the two helpers**

Next to `_bodies_of()`:

```gdscript
## Shortest XZ distance from `point` to the footprint rectangle of `box`; 0 when the point
## is inside it.
##
## Asked of the footprint and not of the origin, because the question the door check is
## really asking is "how close does this prop's SOLID come to the spot the interact verb
## measures from". An origin-to-origin distance says a twelve metre building is far away
## right up until its wall is in the doorway. The prop's world AABB is a bound on its
## trimesh collider, so this is conservative in the safe direction: it can call a prop too
## close, never too far.
func _footprint_gap(box: AABB, point: Vector2) -> float:
	var min_x: float = box.position.x
	var max_x: float = box.position.x + box.size.x
	var min_z: float = box.position.z
	var max_z: float = box.position.z + box.size.z
	var dx: float = maxf(maxf(min_x - point.x, 0.0), point.x - max_x)
	var dz: float = maxf(maxf(min_z - point.y, 0.0), point.y - max_z)
	return Vector2(dx, dz).length()


## The four building origins the interact verb measures from, each with the radius it opens
## at. Read off the live scene rather than from typed-in coordinates, so a building moved in
## ranch.tscn moves its own door with it and this check cannot go stale silently.
func _interaction_doors() -> Array[Dictionary]:
	var radii := {
		"Buildings/Market": MARKET_RADIUS,
		"Buildings/Board": BOARD_RADIUS,
		"Buildings/Depot": DEPOT_RADIUS,
		"Buildings/Palace": PALACE_RADIUS,
	}
	var doors: Array[Dictionary] = []
	for path: String in radii:
		var node := get_node_or_null(NodePath(path)) as Node3D
		if node == null:
			continue
		doors.append({
			"name": String(node.name),
			"at": Vector2(node.global_position.x, node.global_position.z),
			"radius": float(radii[path]),
		})
	return doors
```

- [ ] **Step 3: Rewrite the prop block in `_report()`**

Replace the whole `# --- props ---` block (from `var all_props := _all_props()` down to the `"every prop is seated on the ground (none floats or sinks)"` check) with:

```gdscript
	# --- props ------------------------------------------------------------------
	var all_props := _all_props()
	var doors := _interaction_doors()
	var total_shapes := 0
	var uncollided: Array[String] = []
	var prop_layers_ok := true
	var props_seated := true
	var pen_intrusions: Array[String] = []
	var skirtless: Array[String] = []
	var door_intrusions: Array[String] = []
	var mlp_props := 0
	var skirted_props := 0
	var barn_ridge := 0.0
	var tightest_door := "-"
	var tightest_slack := INF
	for prop: Node3D in all_props:
		var box: AABB = PropsScript.world_aabb(prop)
		# Measured off the live scene tree rather than from a counter kept during
		# construction: a counter can only tell you what the builder THOUGHT it made.
		var shapes: int = prop.find_children("*", "CollisionShape3D", true, false).size()
		total_shapes += shapes
		if shapes == 0:
			uncollided.append(prop.name)
		for body: StaticBody3D in _bodies_of(prop):
			if body.collision_layer != LayersScript.PROPS:
				prop_layers_ok = false
		if PropsScript.is_in_pen_plots(prop.global_position.x, prop.global_position.z):
			pen_intrusions.append(prop.name)

		# A Building is not a layout entry and has no family; everything Props placed has
		# both. entry_of() returns {} for the former, which is what tells the two apart
		# without asking any node what class it is.
		var entry: Dictionary = props.entry_of(prop)
		var family: StringName = &"building"
		var skirted := false
		if not entry.is_empty():
			family = PropsScript.family_of(entry)
			skirted = bool(entry.get("skirt", false))
			if family == PropsScript.FAMILY_MLP:
				mlp_props += 1
			if skirted:
				skirted_props += 1
			# THE SKIRT RULE, CHECKED AGAINST THE MEASURED MODEL AND NOT AGAINST MEMORY.
			# A prop wider than WIDE_FOOTPRINT standing off Terrain's flat apron is seated
			# at one point across a footprint the ground is not flat under; see props.gd's
			# SKIRT_INSET comment for the whole argument. The layout says which props have
			# a skirt, and this is what says which ones NEED one.
			if PropsScript.needs_skirt(box, terrain.is_flat_at(
					prop.global_position.x, prop.global_position.z)) and not skirted:
				skirtless.append(prop.name)
			if String(entry["file"]) == BARN_MODEL:
				barn_ridge = box.size.y
			# NOTHING THE MLP PACKS PUT ON THIS MAP IS EVER WALKED INTO. They are scenery:
			# no attendant stands at one, no dock marker sits on one, and no interaction
			# candidate names one. That only stays true if none of them is standing in a
			# doorway the player walks up to, which is measured here rather than judged by
			# eye once. Scoped to the MLP family on purpose: the four Kenney yard fixtures
			# were placed before this rule existed and the market stall in particular is
			# deliberately clutter beside the request board. Its gap is printed below with
			# everything else's, so widening the rule later is a decision with a number
			# next to it rather than a guess.
			for door: Dictionary in doors:
				var gap: float = _footprint_gap(box, door["at"])
				var slack: float = gap - float(door["radius"])
				if slack < tightest_slack:
					tightest_slack = slack
					tightest_door = "%s/%s" % [prop.name, door["name"]]
				if slack < 0.0 and family == PropsScript.FAMILY_MLP:
					door_intrusions.append("%s/%s" % [prop.name, door["name"]])

		# How far the bottom of the visible model sits from where it was seated. Zero means
		# the prop is standing ON the ground, not floating over it and not buried in it.
		# THREE SEATING RULES, and each prop is checked against the one it was actually
		# placed by: a Building against its own footprint's lowest corner, a skirted prop
		# against the lowest of nine samples across its measured footprint (which Props
		# recorded when it seated it), and everything else against the height under its
		# origin. Re-deriving instead of reading is how the number a prop was seated by and
		# the number the gate checks it against come to drift apart.
		var expected_ground: float = terrain.height_at(
			prop.global_position.x, prop.global_position.z)
		var checked_building: Building = prop as BuildingScript
		if checked_building != null:
			expected_ground = checked_building.seat_ground(Callable(terrain, "height_at"))
		elif props.has_seat_ground(prop):
			expected_ground = props.seat_ground_of(prop)
		var sunk: float = box.position.y - (expected_ground - PropsScript.SINK_BIAS)
		if absf(sunk) > SEATING_TOLERANCE:
			props_seated = false
		print(("RANCH prop %-34s pos=(%6.1f, %5.2f, %6.1f) height=%.2f seat_error=%+.3f " +
			"family=%s skirt=%s")
			% [prop.name, prop.global_position.x, prop.global_position.y,
				prop.global_position.z, box.size.y, sunk, family, skirted])

	# The skirts are not props and are not in the census: they are boxes under wide props,
	# parented to Props so they cannot move the AABB the seating check reads. They still
	# have to be solid and still have to be on the PROPS layer, so they are walked here.
	var skirt_shapes := 0
	for skirt: MeshInstance3D in props.get_skirts():
		skirt_shapes += skirt.find_children("*", "CollisionShape3D", true, false).size()
		for body: StaticBody3D in _bodies_of(skirt):
			if body.collision_layer != LayersScript.PROPS:
				prop_layers_ok = false

	print("RANCH props placed=%d expected=%d shapes=%d missing=%s"
		% [prop_count, expected_props, total_shapes,
			", ".join(props.get_missing()) if not props.get_missing().is_empty() else "-"])
	print("RANCH props mlp=%d skirted=%d skirt_shapes=%d barn_ridge=%.2f mlp_scale=%.4f"
		% [mlp_props, skirted_props, skirt_shapes, barn_ridge, PropsScript.MLP_SCALE])
	print("RANCH prop doors intrusions=%s tightest=%s slack=%.2f"
		% [", ".join(door_intrusions) if not door_intrusions.is_empty() else "-",
			tightest_door, tightest_slack])
	_set_check(checks, "every layout entry with an asset was placed", prop_count == expected_props)
	_set_check(checks, "every prop got at least one collision shape", uncollided.is_empty())
	if not uncollided.is_empty():
		push_error("ranch: props with NO collision shape: %s" % ", ".join(uncollided))
	_set_check(checks, "every prop collider is on the PROPS layer", prop_layers_ok)
	_set_check(checks, "every prop is seated on the ground (none floats or sinks)", props_seated)
	_set_check(checks, "every wide prop off the flat apron stands on a skirt",
		skirtless.is_empty())
	if not skirtless.is_empty():
		push_error(("ranch: wide props seated at one point with no skirt under them: %s; " +
			"add \"skirt\": true to their LAYOUT entries")
			% ", ".join(skirtless))
	_set_check(checks, "no MLP prop's collider reaches inside a building's interaction radius",
		door_intrusions.is_empty())
	if not door_intrusions.is_empty():
		push_error("ranch: props standing in a doorway: %s" % ", ".join(door_intrusions))
	_set_check(checks, "the Sweet Apple Acres barn stands at the height MLP_SCALE was derived for",
		barn_ridge <= 0.0
			or absf(barn_ridge - PropsScript.MLP_TARGET_BARN_RIDGE) <= MLP_RIDGE_TOLERANCE)
```

Note the existing `pen_intrusions` array keeps its existing check further down the function; nothing about it changes, and it now covers 104 layout entries instead of 54.

- [ ] **Step 4: Stop the apple trees pretending to be buildings**

`_buildings_by_height()` filters by the name prefix `kenney_tree`, so the twelve `mlp_apple_tree` props would be sorted in among the buildings and could become `_tallest_building()` or the wall the camera probe presses against. Replace its loop:

```gdscript
	for prop: Node3D in _all_props():
		if not PropsScript.is_foliage(prop.name):
			result.append(prop)
```

and widen its own doc comment's first line:

```gdscript
## Buildings (never trees, Kenney's or the orchard's; a canopy is a bad camera obstacle to
## prove anything with, because the arm could be stopping on a leaf a player would happily
## walk under), tallest first. Props.is_foliage() is the one place the list of tree
## families lives, so a new one cannot be added to the layout and forgotten here.
```

- [ ] **Step 5: Add the five screenshots**

At the end of `_capture_all()`, after `await _capture_plots()`:

```gdscript
	await _capture_props()
```

and add both functions next to `_capture_plots()`:

```gdscript
## 13 to 17: THE FIVE PLACES THIS SLICE DRESSED, each framed on the thing it added.
##
## Screenshot runs only, like everything below the headless quit. These are the only
## judgement a prop layout can get: no assertion in this project can say whether a barn at
## MLP_SCALE reads as a barn, whether a town row reads as a street or as six buildings
## standing in a field, or whether a skirt reads as ground the building is set into or as a
## plinth somebody forgot to hide. The gates say the props are placed, solid, seated and
## out of the doorways; these say whether the place is any good.
func _capture_props() -> void:
	await _frame_on(Vector2(41.0, 51.3), Vector3(-14.0, 11.0, -16.0), 4.0, "13_sweet_apple_acres")
	await _frame_on(Vector2(19.0, -2.0), Vector3(-13.0, 8.0, -12.0), 3.0, "14_ponyville_general")
	await _frame_on(Vector2(1.5, 43.0), Vector3(0.0, 10.0, -22.0), 3.5, "15_town_row_north_road")
	await _frame_on(Vector2(-26.0, 58.0), Vector3(9.0, 8.0, -13.0), 3.0, "16_schoolyard")
	await _frame_on(Vector2(7.5, 69.0), Vector3(0.0, 7.0, -13.0), 2.0, "17_strip_arcade")


## Point the capture camera at world XZ `at`, standing `offset.x`/`offset.z` metres away and
## `offset.y` metres above the ground under the eye, aiming `look_height` metres above the
## ground under the target. Every shot above keeps the horizon in frame on purpose: a prop
## photographed from straight above says nothing about whether it is standing on the ground
## correctly, which is half of what these pictures are for.
func _frame_on(at: Vector2, offset: Vector3, look_height: float, shot_name: String) -> void:
	var target := Vector3(at.x, terrain.height_at(at.x, at.y) + look_height, at.y)
	var eye := target + offset
	eye.y = terrain.height_at(eye.x, eye.z) + offset.y
	capture_camera.global_position = eye
	capture_camera.look_at(target, Vector3.UP)
	capture_camera.make_current()
	await _capture(shot_name)
```

- [ ] **Step 6: Run the ranch gate and read every new line**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 \
  | grep -E "RANCH props |RANCH prop doors|RANCH_OK|RANCH_FAILED|FAILED check"
echo "exit ${PIPESTATUS[0]}"
```
Expected: `RANCH props placed=110 expected=110 shapes=<n> missing=-`, a `RANCH props mlp=<n> skirted=<n> skirt_shapes=<n> barn_ridge=7.0<x> mlp_scale=<n>` line whose `barn_ridge` is within 0.25 of 7.0, `RANCH prop doors intrusions=- tightest=<name> slack=<n>`, then `RANCH_OK ponies=49 props=110 assets=present`, exit 0.

Two failures are expected to be possible here and each has one fix:

* `ranch: wide props seated at one point with no skirt under them: <names>` means a model measured wider than `WIDE_FOOTPRINT` that this plan did not mark. Add `"skirt": true` to exactly those `LAYOUT` entries and re-run; do not widen `WIDE_FOOTPRINT` to make the message go away, because the threshold is what the check means.
* `ranch: props standing in a doorway: <prop>/<building>` means an MLP prop's footprint reaches inside an interaction radius. Move that entry, do not exempt it.

Write down `tightest=` and `slack=`. A negative slack on a `kenney_` prop is the known, deliberate case (the market stall beside the request board) and is not a failure; it is the number to quote if anyone later wants the rule widened past the MLP family.

- [ ] **Step 7: Take the renders and look at them**

```bash
rm -rf /tmp/shots && mkdir -p /tmp/shots
xvfb-run -a tools/bin/godot --audio-driver Dummy --path game world/ranch.tscn \
  -- --screenshot-dir=/tmp/shots 2>&1 | grep -E "SCREENSHOT_SAVED|RANCH_OK|RANCH_FAILED"
ls /tmp/shots
```
Expected: the existing shots plus `13_sweet_apple_acres.png`, `14_ponyville_general.png`, `15_town_row_north_road.png`, `16_schoolyard.png` and `17_strip_arcade.png`.

Then look at all five, because this is the half of the slice no gate covers. What each one is asked:

| Shot | The question |
|---|---|
| `13_sweet_apple_acres` | Does the barn read as a barn at this scale, next to the corn and the fence? Is its skirt reading as ground it is set into, or as a visible plinth? |
| `14_ponyville_general` | Does the shop sit in the yard with the Market rather than in front of it? Is the sign at the Market door legible and clear of the doorway? |
| `15_town_row_north_road` | Six buildings, or a street? Are the two sides facing each other or facing away? |
| `16_schoolyard` | Does a yard with no school read as a schoolyard, with the bell tower doing the work? |
| `17_strip_arcade` | Do the cabinets sit on the Strip, clear of the lamps and the race rail, at a size a pony could use? |

- [ ] **Step 8: Run every gate and the whole suite, clean**

```bash
bash tools/run_tests.sh 2>&1 | tail -20
for scene in market_test region_test world_test collection_test ledger_test depot_test creation_test casino_test; do
  echo "--- $scene"
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" 2>&1 | grep -E "_OK|_FAILED"
  echo "exit ${PIPESTATUS[0]}"
done
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/model_gallery.tscn -- --props 2>&1 | tail -3
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```

Write down, verbatim, the number each gate prints. Nothing in this slice touches a market, a ledger, a region or a casino, so those counts are expected to be unchanged; the two that move are the ranch's own report and `GALLERY_OK count=35` from the new gallery mode. Any other count that moved is a surprise worth reading before writing it down.

- [ ] **Step 9: Raise the floor**

`MIN_TESTS` in `tools/run_tests.sh` stands at 1162. This plan adds 17 tests in `game/test/test_props.gd` and 2 in `game/test/test_ranch_world.gd`, so expect a number near 1181. **Do not guess it; read it off the suite's own `Tests` line.**

```bash
tests=$(bash tools/run_tests.sh 2>&1 | grep -oP '^Tests\s+\K[0-9]+' | tail -1)
echo "suite reports $tests"
sed -i "s/MIN_TESTS=\"\${FILLY_MIN_TESTS:-1162}\"/MIN_TESTS=\"\${FILLY_MIN_TESTS:-$tests}\"/" tools/run_tests.sh
grep -n 'MIN_TESTS=' tools/run_tests.sh
```

Then prove the floor still bites:

```bash
FILLY_MIN_TESTS=99999 bash tools/run_tests.sh; echo "expected 1, got $?"
```

- [ ] **Step 10: Write the docs**

Four edits.

**a.** `docs/testing.md`, in the Files table, replace the model gallery row so it names all three modes:

```
| `game/scenes/test/model_gallery.gd` | The model gallery, and its `--stock`, `--mark` and `--props` rows (see below) |
```

and add a row beside it:

```
| `game/test/test_props.gd` | The prop layout as data: family scales, the footprint sampler, the skirt rule, and the clearances the whole shipped layout has to hold |
```

**b.** `docs/testing.md`, in the model gallery section, after the paragraph describing `--mark`, add:

```markdown
**And a third row, for the props.**
`tools/bin/godot --path game scenes/test/model_gallery.tscn -- --props` loads every
`.glb` in `game/assets/converted/props/`, stands them in a line spaced by their own
measured widths, and prints one `PROP <file> size=(x, y, z) meshes=N materials=N
textured=N` line each. Headless it prints `GALLERY_OK count=35` and the exit code
is the verdict: it fails if fewer than 30 loaded, if any model measured an empty
AABB, or if any model came back with no textured surface at all.

That last one is the reason this mode exists rather than just running
`validate_gltf.py --props` over the directory. The validator parses the GLB's JSON
chunk and asks whether meshes exist; it cannot tell you that
`tools/convert_props.sh --max-texture` dropped an image on the floor and left a
fully structured model that renders flat white.

It also prints one `PROP_SCALE model=saa_barn.glb native_height=... target=...
mlp_scale=...` line, which is where `Props.MLP_SCALE` comes from: the target ridge
height divided by the height the converted barn actually measured. `ranch.gd` then
measures the seated barn against the same `Props.MLP_TARGET_BARN_RIDGE` and fails
if the two have drifted, so that division cannot go stale quietly.
```

**c.** `docs/testing.md`, in the section describing the ranch's own report, after the paragraph naming the `RANCH_OK` line, add:

```markdown
**Three checks landed with the MLP scenery, and two new lines beside them.**

`RANCH props mlp=<n> skirted=<n> skirt_shapes=<n> barn_ridge=<m> mlp_scale=<f>` and
`RANCH prop doors intrusions=<list> tightest=<prop/building> slack=<m>`.

* **"every wide prop off the flat apron stands on a skirt"** measures each placed
  prop's live AABB and asks `Props.needs_skirt()`. A prop whose longer footprint
  side clears `WIDE_FOOTPRINT` (4.0 m) and which stands outside
  `Terrain.is_flat_at()` is being seated at one point across ground that is not
  flat under it: the flattest 13 by 10 m rectangle anywhere off the homestead apron
  still has 0.366 m of relief across it. The layout says which props carry
  `"skirt": true`; this says which ones need it.
* **"no MLP prop's collider reaches inside a building's interaction radius"** is
  what keeps "MLP mesh props are scenery and are never walked into" true. It is
  measured from each prop's footprint rectangle to each building's origin, not
  origin to origin, because an origin distance says a twelve metre building is far
  away right up until its wall is in the doorway. Scoped to the MLP family: the
  four Kenney yard fixtures predate the rule and the market stall is deliberately
  clutter beside the request board. Every gap is printed, MLP or not, so widening
  the rule later is a decision with a number attached.
* **"the Sweet Apple Acres barn stands at the height MLP_SCALE was derived for"**
  closes the loop on the gallery's measurement, within
  `MLP_RIDGE_TOLERANCE` (0.25 m) of `Props.MLP_TARGET_BARN_RIDGE` (7.0 m).

The seating check also learned a third rule. It already knew a `Building` is seated
against the lowest corner of its own footprint rather than the point under its
origin; a skirted prop is seated against the lowest of nine samples across its
measured footprint, and the gate reads the height `Props` recorded when it seated
it rather than re-deriving one, so the two cannot drift apart.
```

**d.** `docs/ci.md`, fix the assetless line, which has been stale since the ranch grew from two buildings to six:

```bash
sed -i 's/`RANCH_OK ponies=0 props=2 assets=absent`/`RANCH_OK ponies=0 props=6 assets=absent`/' docs/ci.md
grep -n "props=6 assets=absent" docs/ci.md
```

The same stale `props=2` is quoted in a comment inside `game/world/ranch.gd`'s camera check block. Fix it there too, so the two agree:

```bash
grep -n "props=2 assets=absent" game/world/ranch.gd
sed -i 's/`RANCH_OK ponies=0 props=2 assets=absent` printed/`RANCH_OK ponies=0 props=6 assets=absent` printed/' game/world/ranch.gd
```

`props` on an assetless checkout is `Props.expected_count()` (zero, because `game/assets/converted/` is gitignored) plus `buildings.get_child_count()`, and `Buildings` has held six children (`Barn`, `Farmhouse`, `Market`, `Board`, `Depot`, `Palace`) since the Palace landed. Verify:

```bash
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | grep "RANCH props placed"
```
against a checkout with the converted tree moved aside, or take the six from `ranch.tscn`'s `Buildings` node.

- [ ] **Step 11: Sweep for the copy rule across everything this branch added**

```bash
git diff master...HEAD --name-only | grep -E '\.(gd|md|sh|py|txt)$' | while read -r f; do
  [ -f "$f" ] || continue
  git diff master...HEAD -- "$f" | grep -n '^+' | grep -E '\-\-|—' \
    | grep -v '^\+.*# ---' | grep -v '^\+.*--headless' | grep -v '^\+.*--audio-driver' \
    | grep -v '^\+.*--path' | grep -v '^\+.*--stock' | grep -v '^\+.*--mark' \
    | grep -v '^\+.*--props' | grep -v '^\+.*--import' | grep -v '^\+.*--force' \
    | grep -v '^\+.*--only' | grep -v '^\+.*--dry-run' | grep -v '^\+.*--max-texture' \
    | grep -v '^\+.*--manifest' | grep -v '^\+.*--mdl' | grep -v '^\+.*--out' \
    | grep -v '^\+.*--require-anims' | grep -v '^\+.*--screenshot-dir' \
    | grep -v '^\+.*-- --' | grep -v '^\+.*shift 2' \
    | sed "s|^|$f:|"
done
```
Expected: no output, except lines that are verbatim copies of pre existing comments this branch moved rather than wrote. Anything else is a new em dash or double hyphen outside a banner or a flag; fix it.

Then the same sweep at run time, which catches a string built by interpolation rather than written as a literal:

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gdir=res://test -gexit 2>&1 | grep -E '\-\-|—' | grep -v 'gut_cmdln' || echo "clean"
```

- [ ] **Step 12: Final full run**

```bash
bash tools/run_tests.sh
bash tools/test_convert_props.sh
for scene in market_test region_test world_test collection_test ledger_test depot_test creation_test casino_test; do
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" >/dev/null 2>&1
  echo "$scene exit $?"
done
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/model_gallery.tscn -- --props >/dev/null 2>&1
echo "gallery props exit $?"
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
bash tools/prove_atomic_save.sh
```
Expected: everything green, every gate exit 0, `PROP_CONVERT_SELFTEST failures=0`, `RANCH_OK ponies=49 props=110 assets=present`, `ATOMIC_SAVE_PROOF_OK`.

- [ ] **Step 13: Commit**

```bash
printf 'feat: the prop checks, five renders, the docs and the floor\n\nThree checks landed with the scenery. Every wide prop standing off the flat apron\nmust have a skirt under it, measured against its live AABB rather than remembered\nfrom the layout. No MLP prop collider may reach inside a building interaction\nradius, measured from the prop footprint to the building origin rather than origin\nto origin, because an origin distance says a twelve metre building is far away\nright up until its wall is in the doorway. And the Sweet Apple Acres barn has to\nstand at the height MLP_SCALE was derived for, which closes the loop on the\ngallery measurement.\n\nThe seating check learned the third seating rule: a skirted prop is seated against\nthe lowest of nine footprint samples, and the gate reads the height Props recorded\nrather than re-deriving one. The camera framing helper stopped treating twelve\napple trees as buildings.\n\nFive screenshots: Sweet Apple Acres, Ponyville General, the town row, the\nschoolyard and the Strip arcade. They are the only judgement a prop layout gets.\n\ndocs/ci.md corrected: the assetless checkout has reported props=6 since the ranch\ngrew from two buildings to six, not props=2. MIN_TESTS raised to the suite s\nreported count.\n' > /tmp/prop-checks-commit.txt
git add game/world/ranch.gd tools/run_tests.sh docs/testing.md docs/ci.md
git commit -F /tmp/prop-checks-commit.txt
```

---

## Self review

Run against the Goal sentence and the four decisions above, with fresh eyes.

**1. Coverage.**

| The Goal names | Task | Where |
|---|---|---|
| The Sweet Apple Acres barn and its yard on the walk out to the Orchard | 4 | `saa_barn` on a skirt at `(41.0, 51.3)`, plus the shed, wagon, two hay piles, wire arch, water chute, seed bag, four fence lengths, a twelve plant corn patch and three bushes. Every coordinate clears the Orchard fence ring by the 4 m `props.gd`'s own comment requires, and `test_props.gd` asserts it over the whole layout. |
| Apple trees in place of the flat colour Kenney oaks around it | 4 | The six Orchard entries keep their coordinates and change file, plus six more along the walk. `docs/pipeline.md` section 4 quirk 6 is the finding that argues for it. |
| Ponyville General across the Market yard with its sign at the Market door | 4 | `(19.0, -2.0)` and `(-1.0, 5.0)`; 21.0 m from the Market origin, 6.1 m for the sign, both verified against `ranch.tscn`'s authored positions. The Market itself is untouched, and Task 6's door check is what keeps that true. |
| A row of Ponyville town buildings and a schoolyard on the road north | 5 | Six environment buildings at `x = 15` and `x = -12`, `z = 36/43/50`, all skirted; the schoolyard around `(-26, 58)`, with the bell tower and no schoolhouse, and the pack's own emptiness recorded in the layout comment. |
| The two Las Pegasus arcade games on the Strip | 5 | `(4.0, 69.0)` and `(11.0, 69.0)`, inside the lamp ring, clear of the Palace rectangle and the race track's near rail at `z = 72.2`. |
| Hay, carts, crates, baskets and a well round the homestead | 5 | `saa_hay_block`, `saa_wagon`, `mlp_crate`, `mlp_basket`, `mlp_farm_well` and `mlp_chicken_coop`, all inside the flat apron and all clear of the pen plot clearing. |
| A repeatable conversion script | 1 | `tools/convert_props.sh` plus `tools/prop_manifest.txt`, self tested by `tools/test_convert_props.sh` with no Blender. |
| A texture budget | 1 | `convert_mdl.py --max-texture`, passed as 1024 by the driver, asserted to reach the exporter by the self test. |
| A gallery gate that proves every converted prop loads with its materials | 2 | `model_gallery.tscn -- --props`, gating on load count, empty AABBs and untextured models, and printing the measurement `MLP_SCALE` is derived from. |
| Every census consequence carried | 4, 5 | 60 to 94 and 94 to 110, each in its own commit, each rewriting all six documented copies of the line in that same commit. |
| The seating and z fighting decision | 3, 6 | `footprint_relief()`, `needs_skirt()`, `"skirt": true`, `_add_skirt()`, and the live check in `ranch.gd` that fails if a prop needing one lacks it. |
| The gitignore decision | 1 | `docs/pipeline.md` section 5c, including the worktree symlink convention that was undocumented. |
| The homestead barn decision | 4 | The layout comment states it; `building.gd` is untouched; quirk 5 is marked resolved without claiming the Kenney kit gained buildings. |
| The Market decision | 4 | The survival structure leaves `LAYOUT` and keeps its `SCALE_FIX` entry with the reason written beside it, which is what keeps `test_the_undersized_fbx_prop_still_carries_its_scale_correction()` green. |

**2. Placeholder scan.** Every code step carries the actual GDScript, bash or Python. Three steps name a procedure rather than a literal, and each states exactly how to get the number and where to write it: `MLP_SCALE` (the `PROP_SCALE` line's `mlp_scale=` value, from the run in Task 2 step 4, written in step 5 with the native height in the comment beside it); the gate check counts in Task 6 step 8 (read from each gate's own printed output, never guessed); and `MIN_TESTS` (read off the suite's `Tests` line by the `sed` command given, with 1181 stated only as what to expect, not as what to write). No step says "similar to" another; the two dressing tasks repeat the family and skirt keys in full rather than referring back to Task 3.

**3. Type and name consistency, checked across tasks.**
- `Props.family_of(entry: Dictionary) -> StringName` is defined in Task 3 and called in Task 3's tests and Task 6's report; `Props.scale_for(entry: Dictionary) -> float` is called only from `build()` and the tests. One signature each.
- `Props.footprint_relief(centre: Vector2, half: Vector2, ground_sampler: Callable) -> Vector2` returns lowest then highest, matching `Building.footprint_relief()`'s convention, and both callers (`build()` and `test_props.gd`) read `.x` as the lowest.
- `Props.needs_skirt(box: AABB, flat: bool) -> bool` takes the flat flag rather than a `Terrain`, so the unit tests need no scene and `ranch.gd` passes `terrain.is_flat_at()` at the call site. Same argument order in all four call sites.
- `Props.entry_of()`, `has_seat_ground()`, `seat_ground_of()` and `get_skirts()` are instance methods on the `Props` node and are called through `ranch.gd`'s `props` reference, never through `PropsScript`. The statics (`world_aabb`, `seat`, `family_of`, `scale_for`, `needs_skirt`, `footprint_relief`, `is_foliage`, `is_in_pen_plots`) are all called through `PropsScript`, per the preload convention.
- `Props.FAMILY_MLP` is `&"mlp"` and every LAYOUT entry in Tasks 4 and 5 writes `"family": &"mlp"` as a literal, which `family_of()` passes through `StringName()`. `FAMILY_SCALE`'s keys are the same three literals.
- `Props.MLP_TARGET_BARN_RIDGE` (7.0) is defined in Task 2, read by `model_gallery.gd` and by `ranch.gd`'s barn ridge check, and asserted in `test_ranch_world.gd`. `Props.MLP_SCALE` is defined in the same task and read by `FAMILY_SCALE` and by `ranch.gd`'s report line.
- `ranch.gd`'s `BARN_MODEL` is `"saa_barn.glb"`, which is `model_gallery.gd`'s `SCALE_REFERENCE` and manifest id `saa_barn`. Three places, one spelling.
- `tools/prop_manifest.txt`'s 35 ids and the 35 `<id>.glb` filenames in `LAYOUT` match one for one, and every id prefix is in `test_ranch_world.gd`'s `PROP_PREFIXES`.
- The census numbers: 54 entries today, 88 after Task 4 (`54 - 1 + 35`), 104 after Task 5 (`88 - 5 + 21`), plus six `Buildings` children giving 60, 94 and 110. Every doc sed in Tasks 4 and 5 moves the same six lines, and no third task touches them.
- `PROP_CONVERT ok=N failed=N skipped=N refused=N` is the exact line the driver prints, the self test greps and the pipeline doc quotes.
- The five new screenshot names are used once each, in `_capture_props()` and in Task 6 step 7's table.

**4. One thing deliberately not done.** No gate asserts that props do not intersect each other. Nothing in the project measures that today, the arrangements above were checked by arithmetic rather than by a solver, and the five renders in Task 6 are what a person looks at to catch it. Adding a pairwise overlap gate is a reasonable later task; inventing one here, tuned until the shipped layout passed it, would prove less than the pictures do.
