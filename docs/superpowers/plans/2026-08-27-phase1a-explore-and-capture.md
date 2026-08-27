# Phase 1A: Explore & Capture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable build where you walk around the ranch as Twilight Sparkle, find wild ponies roaming the world, and capture them with the magic beam into limited storage slots.

**Architecture:** Godot 4.5 scene composition over a data-driven character registry. Every collectible character is a `PonyData` resource (`.tres`) naming its model, rarity, spawn zone and stats, so adding character #20 is one file and no code. The player is a `CharacterBody3D` with a `SpringArm3D` camera; wild ponies are the same body type driven by a small explicit state machine. The magic beam is a raycast + hold-point that reparents a grabbed pony, so capture, carry and release are one mechanism rather than three. Pure logic (spawn-table draws, capture rules, storage limits) lives in plain `RefCounted` classes with no scene dependencies, so GUT can test them headlessly.

**Tech Stack:** Godot 4.5.2 (GDScript, Forward+), GUT for headless unit tests, Blender 4.2.23 headless for the asset re-export.

**Spec:** `docs/superpowers/specs/2026-08-26-filly-rancher-design.md` (Phase 1 section)

**Builds on:** `docs/pipeline.md` (Phase 0's asset recipe), `docs/notes-hair-sim.md` (mane/tail spring-bone setup — every spawned pony must get it).

## Global Constraints

- Godot 4.5.2, GDScript only, Forward+ renderer. Linux **and** Windows exports must both build every phase; `game/scenes/test/smoke.tscn` stays the export smoke scene until Task 9 says otherwise.
- **1 unit = 1 metre.** Established in Task 1 and binding on every asset and scene afterwards.
- No pony ever dies. Failure states are escape, flee, or loss of progress — never death.
- Every collectible character is defined by a `PonyData` resource; adding a character must require **zero code changes**.
- Logic that can be tested without a scene tree must live in a `RefCounted` class under `game/systems/` and have GUT tests. Node scripts stay thin.
- Assets and generated imports remain gitignored (`game/assets/converted/**`); anything a fresh checkout needs must be regenerable via `docs/pipeline.md`.
- Every spawned pony gets mane/tail spring bones via the reusable mechanism from `docs/notes-hair-sim.md` — never by hand-editing an imported `.glb`.
- Commit messages end with: `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

## File Structure

```
game/
├── data/ponies/                    # PonyData .tres resources (Task 3)
│   ├── twilight.tres  rainbowdash.tres  fluttershy.tres
├── systems/                        # scene-free logic, GUT-tested
│   ├── pony_data.gd                # Resource class (Task 3)
│   ├── pony_registry.gd            # loads + indexes all PonyData (Task 3)
│   ├── spawn_table.gd              # rarity-weighted draws (Task 6)
│   └── storage.gd                  # capture slots (Task 8)
├── actors/
│   ├── player/player.gd .tscn      # CharacterBody3D + camera rig (Tasks 4,5)
│   ├── pony/pony.gd .tscn          # wild pony actor + state machine (Task 6)
│   └── pony/pony_visuals.gd        # model load + spring bones (Task 3)
├── world/
│   ├── ranch.tscn                  # the playable map (Task 7)
│   └── spawner.gd                  # populates zones from spawn tables (Task 7)
├── ui/hud.tscn hud.gd              # slots, prompts (Task 8)
└── test/                           # GUT tests mirror systems/
    └── test_pony_registry.gd  test_spawn_table.gd  test_storage.gd
```

---

### Task 1: Normalize model scale to 1 unit = 1 metre

Phase 0 left ponies ~4.3 units tall (~3× life size). Fix it in the pipeline before any world geometry exists.

**Files:**
- Modify: `tools/export_blend.py` (add `--scale`), `docs/pipeline.md` (§6 + Deferred section)
- Regenerate: `game/assets/converted/ponies/*.glb`

**Interfaces:**
- Produces: `--scale <float>` flag on `export_blend.py`; all pony `.glb` files at metric scale. Every later task assumes a pony is ~1.2–1.5 units at the withers and that Godot's default gravity/physics values are sane.

- [ ] **Step 1: Measure current heights.** Write a throwaway headless Godot or Python check reporting each pony's AABB height. Record the numbers. Twilight is the reference: her real-world withers height should land ~1.2 m (show-accurate ponies are small).
- [ ] **Step 2: Add `--scale` to `export_blend.py`.** Apply the factor to the exported root/armature before export, additively — omitting the flag must leave existing behavior byte-identical. Follow the script's existing flag conventions and comment style.
- [ ] **Step 3: Re-export all three ponies** with the computed factor using the documented §6 command plus `--scale`. Verify with `python3 tools/validate_gltf.py <glb> --require-anims` (still exactly `['idle','walk']`) and re-measure AABB heights — expect ~1.2–1.5.
- [ ] **Step 4: Re-tune the walk.** `author_anims.py`'s `STRIDE` and `walk_test.gd`'s derived `WALK_SPEED` are in model units; scaling the model changes what a correct stride is. Recompute so implied gait speed matches scene speed (the cross-check comments name every coupled constant). Confirm `WALK_OK laps_progress>=1`. A pony walking ~1.2 m/s is a reasonable real-world target.
- [ ] **Step 5: Verify no regressions.** All four Phase 0 scenes pass headless (`SMOKE_OK`, `GALLERY_OK count=3`, `WALK_OK`, `PROBE_OK count=8`). Props in `terrain_probe` were sized against the OLD pony scale — re-check the prop/pony ratio and record the new recommended prop factor in the report (do not re-source props).
- [ ] **Step 6: Update docs.** `docs/pipeline.md` §6 documents `--scale` as mandatory for new characters and states the metric convention; move "pony scale" out of "Deferred to Phase 1" into a settled decision with the chosen factor.
- [ ] **Step 7: Commit.** `git add tools/export_blend.py docs/pipeline.md game/scenes/test/walk_test.gd tools/author_anims.py && git commit -m "feat: normalize pony models to 1 unit = 1 metre"`

---

### Task 2: GUT test harness

**Files:**
- Create: `game/test/test_smoke.gd`, `tools/run_tests.sh`
- Modify: `tools/setup_env.sh` (fetch GUT), `docs/pipeline.md` (testing section)

**Interfaces:**
- Produces: `bash tools/run_tests.sh` runs the whole suite headlessly, exits non-zero on failure. Every later task's tests live in `game/test/` and run through it.

- [ ] **Step 1: Install GUT.** Add a pinned-version download to `tools/setup_env.sh` following its existing pattern exactly — pinned version, pinned SHA-256 with a provenance comment, hard fail on mismatch, idempotent guard, and success gated on a marker (see the SourceIO block for the established shape). GUT installs as a Godot addon under `game/addons/gut/`.
- [ ] **Step 2: Write a trivially failing test** in `game/test/test_smoke.gd` (`assert_eq(1, 2, "deliberate failure")`) to prove the harness reports failures rather than silently passing.
- [ ] **Step 3: Write `tools/run_tests.sh`** invoking GUT's headless CLI runner over `game/test/`, propagating the exit code. Run it — it MUST exit non-zero and name the failing test.
- [ ] **Step 4: Flip the test to pass** (`assert_eq(1, 1)`), re-run, confirm exit 0.
- [ ] **Step 5: Document** the test command in `docs/pipeline.md`.
- [ ] **Step 6: Commit.**

---

### Task 3: PonyData resource, registry, and pony visuals

**Files:**
- Create: `game/systems/pony_data.gd`, `game/systems/pony_registry.gd`, `game/actors/pony/pony_visuals.gd`, `game/data/ponies/{twilight,rainbowdash,fluttershy}.tres`, `game/test/test_pony_registry.gd`

**Interfaces:**
- Produces:
  - `PonyData` (Resource) fields: `id: StringName`, `display_name: String`, `model_path: String`, `rarity: int` (enum COMMON/UNCOMMON/RARE/LEGENDARY), `spawn_zones: Array[StringName]`, `favorite_foods: Array[StringName]`, `personality: int` (enum SHY/BOLD/CURIOUS), `voice_bank: String`, `base_speed: float`, `base_stamina: float`, `base_spirit: float`.
  - `PonyRegistry.load_all(dir: String) -> Dictionary` returning `{id: PonyData}`; `PonyRegistry.by_zone(zone: StringName) -> Array[PonyData]`; `PonyRegistry.by_rarity(r: int) -> Array[PonyData]`.
  - `PonyVisuals.build(data: PonyData) -> Node3D` — loads the model, attaches mane/tail spring bones per `docs/notes-hair-sim.md`, returns a ready instance with its `AnimationPlayer` reachable at a documented node path. **Every** pony instance in the game comes from here; nothing else loads a `.glb` directly.

- [ ] **Step 1: Write failing tests** in `game/test/test_pony_registry.gd`: loading the data dir returns 3 entries; `by_zone(&"ranch")` returns only ranch-zoned ponies; `by_rarity` filters correctly; an unknown id returns null rather than crashing; a malformed/missing model path is reported not silently swallowed.
- [ ] **Step 2: Run tests, confirm they fail** for the right reason (classes don't exist).
- [ ] **Step 3: Implement `pony_data.gd`** as a `class_name PonyData extends Resource` with `@export` on every field above and the two enums.
- [ ] **Step 4: Author the three `.tres` files.** Twilight: unicorn stats, favorite foods `[&"daffodil", &"hay"]`, personality CURIOUS, rarity RARE. Rainbow Dash: fastest `base_speed`, personality BOLD, rarity RARE. Fluttershy: personality SHY, rarity UNCOMMON. All three `spawn_zones = [&"ranch"]` for now. `voice_bank` points at `res://assets/audio/voice/<id>/` (only Twilight's exists; a missing bank must be non-fatal).
- [ ] **Step 5: Implement `pony_registry.gd`** (extends RefCounted, no scene deps). Run tests to green.
- [ ] **Step 6: Implement `pony_visuals.gd`** and prove it in a scene: extend `model_gallery` (or add `game/scenes/test/registry_gallery.tscn`) to build all three ponies through the registry+visuals path, print `REGISTRY_OK count=3`, and confirm each instance has a working `AnimationPlayer` with `idle`/`walk` AND live spring bones. Verify headless.
- [ ] **Step 7: Commit.**

---

### Task 4: Player controller

**Files:**
- Create: `game/actors/player/player.gd`, `game/actors/player/player.tscn`, `game/scenes/test/playground.tscn`
- Modify: `game/project.godot` (input map)

**Interfaces:**
- Consumes: `PonyVisuals.build()` (Task 3) to build Twilight's body.
- Produces: `Player` (CharacterBody3D) with `get_beam_origin() -> Node3D` (Task 8 attaches the beam here) and a `camera_pivot` node path Task 5 fills in. Input actions: `move_forward/back/left/right`, `jump`, `beam` (all with keyboard + gamepad bindings).

- [ ] **Step 1: Define input actions** in `project.godot` — WASD + arrows + left stick for movement, Space/A for jump, right mouse / right trigger for `beam`.
- [ ] **Step 2: Build `player.tscn`** — CharacterBody3D root, CollisionShape3D (capsule sized to the metric pony from Task 1), a `Visuals` child populated at `_ready()` from `PonyData` for Twilight via the registry, and an empty `CameraPivot` Node3D at head height.
- [ ] **Step 3: Implement movement** in `player.gd`: camera-relative input, walk/gallop speeds (gallop on a held modifier or just a higher speed above an input threshold — pick one and comment why), gravity, jump, and smooth turning toward the movement direction. Use `move_and_slide()`.
- [ ] **Step 4: Drive animation** — play `idle` when speed ≈ 0 and `walk` when moving, with `AnimationPlayer` blending. Scale playback speed with movement speed so the gait matches ground speed (Task 1 established the clip's implied speed; reuse that constant rather than a new magic number).
- [ ] **Step 5: Verify** in `playground.tscn` (ground plane + player + light + temporary fixed camera). Headless check: instantiate, simulate ~60 physics frames of forward input, assert the player's position advanced and it is on the floor; print `PLAYER_OK dist=<x>`; quit 0. Then a windowed run for the owner.
- [ ] **Step 6: Commit.**

---

### Task 5: Third-person camera

**Files:**
- Create: `game/actors/player/camera_rig.gd`, `game/actors/player/camera_rig.tscn`
- Modify: `game/actors/player/player.tscn` (mount the rig), `game/project.godot` (look actions)

**Interfaces:**
- Consumes: `CameraPivot` from Task 4.
- Produces: a `Camera3D` reachable as the current camera; `CameraRig.get_aim_ray() -> (origin: Vector3, direction: Vector3)` — Task 8's beam aims along this, NOT along the player's facing.

- [ ] **Step 1: Build the rig** — SpringArm3D (collision-aware, so it pulls in near walls) + Camera3D, mounted on `CameraPivot`.
- [ ] **Step 2: Implement look** — mouse motion and right-stick yaw/pitch, pitch clamped (about −60°..+70°), configurable sensitivity, mouse captured with Escape to release. Zoom via scroll adjusting spring length within limits.
- [ ] **Step 3: Implement `get_aim_ray()`** returning a ray from the camera through the screen centre (a crosshair-accurate aim, which is what makes the beam feel right).
- [ ] **Step 4: Verify** headless where possible (assert the camera is current, `get_aim_ray()` returns a normalized direction pointing where the camera looks, pitch clamps hold at extremes) — print `CAMERA_OK`. Windowed check by the owner for feel.
- [ ] **Step 5: Commit.**

---

### Task 6: Wild pony actor and spawn tables

**Files:**
- Create: `game/actors/pony/pony.gd`, `game/actors/pony/pony.tscn`, `game/systems/spawn_table.gd`, `game/test/test_spawn_table.gd`

**Interfaces:**
- Consumes: `PonyData`, `PonyVisuals` (Task 3).
- Produces:
  - `SpawnTable.new(entries: Array[PonyData], rng: RandomNumberGenerator)` with `draw() -> PonyData` weighting by rarity (COMMON 60 / UNCOMMON 25 / RARE 12 / LEGENDARY 3 — put the weights in one exported constant dictionary).
  - `Pony` (CharacterBody3D) with `setup(data: PonyData)`, `state: int` (enum IDLE/WANDER/GRAZE/FLEE/APPROACH/HELD), signals `captured()` and `escaped()`, and `set_held(is_held: bool)` used by the beam.

- [ ] **Step 1: Write failing tests** for `SpawnTable`: draws only from supplied entries; with a seeded RNG the distribution over 10 000 draws matches the weights within tolerance; an empty table returns null instead of crashing; a table of one entry always returns it.
- [ ] **Step 2: Run tests, confirm failure. Implement `spawn_table.gd`** (RefCounted, injected RNG so tests are deterministic). Green.
- [ ] **Step 3: Build `pony.tscn`** — CharacterBody3D, capsule collision, `Visuals` child built via `PonyVisuals`, and a `DetectionArea` (Area3D) sized a few metres for noticing the player.
- [ ] **Step 4: Implement the state machine** in `pony.gd` as an explicit `match state` in `_physics_process`, one small function per state: IDLE (pause, then pick WANDER or GRAZE), WANDER (walk to a random nearby point, playing `walk`), GRAZE (stand still playing `idle`), FLEE (SHY personality: move away from the player while in detection range), APPROACH (CURIOUS: move toward the player, stop short), HELD (physics off, movement driven by the beam). BOLD ignores the player and continues its routine. Transitions are driven by the detection area and a per-state timer.
- [ ] **Step 5: Verify** with `game/scenes/test/wild_ponies.tscn` — ground plane, several ponies spawned from a seeded table. Headless: run ~300 physics frames, assert every pony moved at least once and no pony left the ground plane or entered an invalid state; print `WILD_OK count=<n> states=<...>`; quit 0.
- [ ] **Step 6: Commit.**

---

### Task 7: The ranch map

**Files:**
- Create: `game/world/ranch.tscn`, `game/world/spawner.gd`, `game/world/zone_marker.gd`
- Modify: `game/project.godot` (main scene → ranch)

**Interfaces:**
- Consumes: props from `game/assets/converted/props/`, `SpawnTable`, `Pony`, `Player`.
- Produces: `res://world/ranch.tscn` — the playable map. `Spawner.populate()` fills zone markers from the registry's ranch-zoned ponies; `ZoneMarker` (Area3D) declares `zone_id` and a spawn radius.

- [ ] **Step 1: Build the terrain** — a ground mesh with collision (a large `PlaneMesh` with a `StaticBody3D`/trimesh collider is fine; gentle sculpting is optional), a grass-toned material, `WorldEnvironment` with sky and soft ambient light, and a `DirectionalLight3D` sun with shadows.
- [ ] **Step 2: Place props to scale.** Use the Kenney props at the factor Task 1 recomputed. Compose a readable little homestead: a house/barn as the visual anchor, a scattering of trees, and a clear open area for the future pen plots. Every prop needs collision so you can't walk through buildings.
- [ ] **Step 3: Place the player** spawn and two or three `ZoneMarker`s away from the house.
- [ ] **Step 4: Implement `spawner.gd`** — on `_ready()`, for each zone marker draw N ponies from a `SpawnTable` built from the registry's entries for that zone, instance `pony.tscn`, `setup()` it, and place it at a random point in the marker's radius on the ground.
- [ ] **Step 5: Make ranch the main scene** and verify headless: `RANCH_OK ponies=<n> props=<n>`, exit 0, no errors about missing collisions. Confirm the exported Linux binary still runs (the export smoke expectation changes from `SMOKE_OK` to `RANCH_OK` — update `docs/pipeline.md` §9 accordingly).
- [ ] **Step 6: Commit.**

---

### Task 8: Magic beam capture and storage

**Files:**
- Create: `game/actors/player/magic_beam.gd`, `game/systems/storage.gd`, `game/test/test_storage.gd`
- Modify: `game/actors/player/player.gd/.tscn`, `game/actors/pony/pony.gd`

**Interfaces:**
- Consumes: `CameraRig.get_aim_ray()` (Task 5), `Pony.set_held()` (Task 6).
- Produces:
  - `Storage.new(capacity: int)` with `store(data: PonyData) -> bool` (false when full), `release() -> PonyData` (null when empty), `count()`, `capacity`, `is_full()`, and signal `changed`.
  - `MagicBeam` with `grab()`, `release()`, `is_holding() -> bool`, and a visual effect while active.

- [ ] **Step 1: Write failing tests** for `Storage`: stores up to capacity; the store past capacity returns false and does not grow `count()`; release returns entries LIFO and empties correctly; release on empty returns null; `changed` fires on both operations.
- [ ] **Step 2: Run tests, confirm failure. Implement `storage.gd`** (RefCounted). Green.
- [ ] **Step 3: Implement the beam.** While `beam` is held: cast along `get_aim_ray()` to a limited range; if it hits a `Pony`, put it in HELD state and lerp it toward a hold point in front of the camera; a struggle timer runs while held (per the spec, holding too long lets it escape — SHY ponies struggle sooner than BOLD; use `personality` and emit `escaped()`). Releasing the button while holding stores the pony (via `Storage.store()`, freeing the node) if there is room, otherwise drops it back into the world unharmed. Loose non-pony rigid bodies should also be draggable, since it costs nothing and it's the fun part of the mechanic.
- [ ] **Step 4: Visual + audio feedback** — a beam effect while active (a stretched mesh or `Line`/particles between the beam origin and the target), and play Twilight's greeting voice line once on the first successful capture as a placeholder for the future voice system.
- [ ] **Step 5: Verify** headlessly in a purpose-built scene: place a pony at a known position, simulate a grab, assert its state becomes HELD and it moves toward the hold point, then simulate release and assert `Storage.count() == 1` and the pony node is gone; also assert a full storage refuses and leaves the pony in the world. Print `CAPTURE_OK`. Then the owner plays it.
- [ ] **Step 6: Commit.**

---

### Task 9: HUD, integration pass, and cross-platform builds

**Files:**
- Create: `game/ui/hud.tscn`, `game/ui/hud.gd`
- Modify: `game/world/ranch.tscn`, `docs/pipeline.md`

**Interfaces:**
- Consumes: `Storage.changed` (Task 8), player state.
- Produces: the Phase 1A deliverable — an exported build on both platforms that a player can pick up and play.

- [ ] **Step 1: Build the HUD** — a crosshair, storage slots (filled/empty against capacity), a caught-pony name toast, and a small control hints panel toggled with a key. Bind it to `Storage.changed` rather than polling.
- [ ] **Step 2: Integration pass.** Play the game and fix what breaks: ponies stuck in geometry, the camera clipping through props, beam range that feels wrong, capture that feels unfair, ponies spawning inside each other. Record each fix in the report — this step is expected to find real bugs and is the most valuable step in the task.
- [ ] **Step 3: Run every gate.** `bash tools/run_tests.sh` green; every test scene still passes headless; `RANCH_OK` from the exported Linux binary.
- [ ] **Step 4: Export both platforms** per `docs/pipeline.md` §9 into `build/`, confirming the Windows `.exe` and `.pck` are produced (execution is verified on the friend's machine).
- [ ] **Step 5: Write `docs/phase1a-playtest.md`** — how to run the build, the controls, what to try, what is deliberately missing (pens, food, economy, saves — all Phase 1B), and known issues.
- [ ] **Step 6: Commit** and report Phase 1A complete.
