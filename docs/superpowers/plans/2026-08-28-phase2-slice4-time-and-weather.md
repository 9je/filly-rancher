# Phase 2 Slice 4: Time and Weather Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the world a clock and a sky: four phases of day and four kinds of weather, derived deterministically from the save's seed and elapsed play time, rendered by the sun, the sky, the fog and a rain layer, and persisted so a save resumes at the phase and weather it was written in.

**Architecture:** `WorldState` is pure logic (RefCounted): elapsed seconds in, phase and weather out, emitting `phase_changed` and `weather_changed` when either flips. It knows nothing about rendering. `SkyRig` is a Node in `ranch.tscn` that owns the Sun, the WorldEnvironment and a rain emitter and applies a `WorldState` reading to them through small pure mapping functions (sun elevation, light colour, sky colours, fog density) that are unit-tested as arithmetic. `ranch.gd` ticks the state while interactive, hands the reading to the sky rig and the HUD, writes `world_time` into the save (format version 3), and honours `--phase=` and `--weather=` override arguments so gates and renders can pin a look. A hosted gate proves the cycle, the determinism, the save resume, and that the rendering values actually land on the nodes. A screenshot sweep renders every phase against every weather for a person to look at.

**Tech Stack:** Godot 4.5.2, GDScript, GUT, the project's gate conventions, `xvfb-run` for renders.

**Spec:** `docs/superpowers/specs/2026-08-28-phase2-bigger-world-design.md`, sections "WorldState", "Data model changes" (`world_time`), "Testing" (the visual harness for time of day and weather), build order item 4.

## Global Constraints

- No em dash (U+2014) and no double hyphen (` -- `) in anything a player can read (the HUD's time line) or in new code, comments, docs, or data.
- `WorldState` is RefCounted, no Node, no scene, GUT-tested in isolation; derivation is a pure function of `(seed, elapsed_seconds)`, so the same save always produces the same sky.
- A full cycle is 20 real minutes: DAWN 2 min, DAY 9 min, DUSK 2 min, NIGHT 7 min (in that order, then repeat). Weather is rolled once per phase from the seed and the phase index: CLEAR 55 percent, RAIN 20, FOG 15, STORM 10.
- Save: `world_time: float` (elapsed seconds) under key `"world_time"`; `SaveIO.FORMAT_VERSION` becomes 3; `migrate()` adds `world_time: 0.0` for older files; a version 1 and a version 2 file must both still load (extend the existing composed-path test to a v2 fixture too).
- Rendering values are applied, never animated by physics: the sky rig lerps toward the target over `TRANSITION_SECONDS` (8 s) in `_process`, so a phase flip is a gentle change, and `apply_immediately()` exists for gates and renders.
- Gates and renders: `--phase=DAWN|DAY|DUSK|NIGHT` and `--weather=CLEAR|RAIN|FOG|STORM` user args pin the state for that run and stop the clock; `--world-time=<seconds>` sets the clock. A pinned run never writes `world_time` back to the state (a gate must not change a player's clock).
- The HUD shows the phase and weather as one short line under the bits line: `"Dusk, rain"`.
- `NO PONY EVER DIES`; nothing here touches ponies. Conditional spawns are slice 5.
- Hosted ranch mode is used by the gate as before.
- Branch: `phase2-slice4-sky`. Commit after every task.

---

### Task 1: WorldState

**Files:**
- Create: `game/systems/world_state.gd`
- Test: `game/test/test_world_state.gd`

**Interfaces:**
- `class_name WorldState extends RefCounted`; `enum Phase { DAWN, DAY, DUSK, NIGHT }`; `enum Weather { CLEAR, RAIN, FOG, STORM }`; `const CYCLE_SECONDS := 1200.0`; `const PHASE_SECONDS := [120.0, 540.0, 120.0, 420.0]`; `const WEATHER_WEIGHTS := [55, 20, 15, 10]`.
- `_init(seed: int, elapsed: float = 0.0)`; `signal phase_changed(phase: int)`; `signal weather_changed(weather: int)`; `advance(delta: float) -> void`; `set_elapsed(seconds: float) -> void`; `elapsed() -> float`; `phase() -> int`; `weather() -> int`; `phase_progress() -> float` (0 at the start of the current phase, 1 at its end); `cycle_index() -> int`; `static func phase_at(elapsed: float) -> int`; `static func weather_for(seed: int, cycle: int, phase: int) -> int` (deterministic); `static func phase_name(p: int) -> String` ("Dawn"...); `static func weather_name(w: int) -> String` ("clear"...); `describe() -> String` ("Dusk, rain"); `pin(phase: int, weather: int) -> void` (freezes the state at a chosen pair; `advance` is a no-op while pinned; `is_pinned()`).

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest
## The world clock as arithmetic: game/systems/world_state.gd. Nothing here renders.

const WorldStateScript := preload("res://systems/world_state.gd")


func test_phases_partition_the_cycle_in_order() -> void:
	var sum := 0.0
	for s in WorldStateScript.PHASE_SECONDS:
		sum += s
	assert_almost_eq(sum, WorldStateScript.CYCLE_SECONDS, 0.001)
	assert_eq(WorldStateScript.phase_at(0.0), WorldStateScript.Phase.DAWN)
	assert_eq(WorldStateScript.phase_at(119.9), WorldStateScript.Phase.DAWN)
	assert_eq(WorldStateScript.phase_at(120.0), WorldStateScript.Phase.DAY)
	assert_eq(WorldStateScript.phase_at(659.9), WorldStateScript.Phase.DAY)
	assert_eq(WorldStateScript.phase_at(660.0), WorldStateScript.Phase.DUSK)
	assert_eq(WorldStateScript.phase_at(780.0), WorldStateScript.Phase.NIGHT)
	assert_eq(WorldStateScript.phase_at(1199.9), WorldStateScript.Phase.NIGHT)
	assert_eq(WorldStateScript.phase_at(1200.0), WorldStateScript.Phase.DAWN, "the cycle wraps")


func test_advance_emits_on_a_phase_flip_and_not_otherwise() -> void:
	var w = WorldStateScript.new(7)
	watch_signals(w)
	w.advance(60.0)
	assert_signal_not_emitted(w, "phase_changed")
	w.advance(60.0)
	assert_signal_emitted_with_parameters(w, "phase_changed", [WorldStateScript.Phase.DAY])
	assert_eq(w.phase(), WorldStateScript.Phase.DAY)
	assert_almost_eq(w.phase_progress(), 0.0, 0.001)


func test_weather_is_deterministic_in_the_seed_and_varies_across_phases() -> void:
	var a := WorldStateScript.weather_for(42, 0, 0)
	var b := WorldStateScript.weather_for(42, 0, 0)
	assert_eq(a, b, "same seed, cycle and phase: same weather")
	var seen := {}
	for cycle in range(40):
		for phase in range(4):
			seen[WorldStateScript.weather_for(42, cycle, phase)] = true
	assert_eq(seen.size(), 4, "over 160 rolls every kind of weather appears")


func test_weather_frequencies_follow_the_weights_roughly() -> void:
	var counts := [0, 0, 0, 0]
	var rolls := 4000
	for i in range(rolls):
		counts[WorldStateScript.weather_for(1000 + i, 0, 0)] += 1
	assert_between(float(counts[0]) / rolls, 0.50, 0.60, "clear about 55 percent")
	assert_between(float(counts[3]) / rolls, 0.06, 0.14, "storm about 10 percent")


func test_weather_changes_only_at_a_phase_boundary() -> void:
	var w = WorldStateScript.new(3)
	var before := w.weather()
	watch_signals(w)
	w.advance(100.0)
	assert_eq(w.weather(), before)
	assert_signal_not_emitted(w, "weather_changed")
	# Advance into a phase whose roll differs; search the first boundary that changes it.
	var changed := false
	for i in range(8):
		w.advance(WorldStateScript.PHASE_SECONDS[w.phase()] - w.phase_progress() * WorldStateScript.PHASE_SECONDS[w.phase()] + 0.01)
		if w.weather() != before:
			changed = true
			break
	assert_true(changed, "some later phase rolls a different weather")
	assert_signal_emitted(w, "weather_changed")


func test_set_elapsed_resumes_a_save_exactly() -> void:
	var w = WorldStateScript.new(9)
	w.advance(700.0)
	var copy = WorldStateScript.new(9, w.elapsed())
	assert_eq(copy.phase(), w.phase())
	assert_eq(copy.weather(), w.weather())
	assert_almost_eq(copy.elapsed(), 700.0, 0.001)


func test_pin_freezes_the_state() -> void:
	var w = WorldStateScript.new(1)
	w.pin(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.STORM)
	assert_true(w.is_pinned())
	w.advance(5000.0)
	assert_eq(w.phase(), WorldStateScript.Phase.NIGHT)
	assert_eq(w.weather(), WorldStateScript.Weather.STORM)
	assert_almost_eq(w.elapsed(), 0.0, 0.001, "a pinned clock does not run")


func test_names_and_describe_carry_no_dashes() -> void:
	var w = WorldStateScript.new(1)
	w.pin(WorldStateScript.Phase.DUSK, WorldStateScript.Weather.RAIN)
	assert_eq(w.describe(), "Dusk, rain")
	for p in range(4):
		assert_false(WorldStateScript.phase_name(p).contains("-"))
	for x in range(4):
		assert_false(WorldStateScript.weather_name(x).contains("-"))
```

- [ ] **Step 2: Run to verify failure** (preload error).

- [ ] **Step 3: Implement**

```gdscript
class_name WorldState
extends RefCounted
## THE WORLD CLOCK, AS ARITHMETIC. Elapsed play time in, a phase of day and a kind of
## weather out. Both are pure functions of the save's seed and the clock, so the same
## save always shows the same sky, and a gate can pin any pair without touching anyone's
## file. Nothing here renders: game/world/sky_rig.gd reads this and moves the sun.
##
## THE CYCLE IS TWENTY REAL MINUTES, so a single sitting sees every phase; DAY is the
## longest because it is where the ranch work happens. Weather is rolled once per phase
## from the seed, the cycle index and the phase, never simulated, so a player who quits
## in a storm comes back to the same storm.

enum Phase { DAWN, DAY, DUSK, NIGHT }
enum Weather { CLEAR, RAIN, FOG, STORM }

const CYCLE_SECONDS := 1200.0
const PHASE_SECONDS: Array[float] = [120.0, 540.0, 120.0, 420.0]
const WEATHER_WEIGHTS: Array[int] = [55, 20, 15, 10]

const PHASE_NAMES: Array[String] = ["Dawn", "Day", "Dusk", "Night"]
const WEATHER_NAMES: Array[String] = ["clear", "rain", "fog", "storm"]

signal phase_changed(phase: int)
signal weather_changed(weather: int)

var _seed: int
var _elapsed := 0.0
var _phase: int = Phase.DAWN
var _weather: int = Weather.CLEAR
var _pinned := false


func _init(seed: int, elapsed: float = 0.0) -> void:
	_seed = seed
	_elapsed = maxf(0.0, elapsed)
	_phase = phase_at(_elapsed)
	_weather = weather_for(_seed, cycle_index(), _phase)


static func phase_at(elapsed: float) -> int:
	var t := fposmod(elapsed, CYCLE_SECONDS)
	for p in range(PHASE_SECONDS.size()):
		if t < PHASE_SECONDS[p]:
			return p
		t -= PHASE_SECONDS[p]
	return Phase.NIGHT


## A hash of (seed, cycle, phase) folded onto the weights. Deterministic and cheap; a
## RandomNumberGenerator would be seeded the same way and give the same answer with more
## ceremony.
static func weather_for(seed: int, cycle: int, phase: int) -> int:
	var h := hash(Vector3i(seed, cycle, phase))
	var total := 0
	for w in WEATHER_WEIGHTS:
		total += w
	var roll := int(absi(h) % total)
	for i in range(WEATHER_WEIGHTS.size()):
		if roll < WEATHER_WEIGHTS[i]:
			return i
		roll -= WEATHER_WEIGHTS[i]
	return Weather.CLEAR


static func phase_name(p: int) -> String:
	return PHASE_NAMES[clampi(p, 0, PHASE_NAMES.size() - 1)]


static func weather_name(w: int) -> String:
	return WEATHER_NAMES[clampi(w, 0, WEATHER_NAMES.size() - 1)]


func advance(delta: float) -> void:
	if _pinned or delta <= 0.0:
		return
	set_elapsed(_elapsed + delta)


func set_elapsed(seconds: float) -> void:
	if _pinned:
		return
	_elapsed = maxf(0.0, seconds)
	var new_phase := phase_at(_elapsed)
	var new_weather := weather_for(_seed, cycle_index(), new_phase)
	if new_phase != _phase:
		_phase = new_phase
		phase_changed.emit(_phase)
	if new_weather != _weather:
		_weather = new_weather
		weather_changed.emit(_weather)


func elapsed() -> float:
	return _elapsed


func phase() -> int:
	return _phase


func weather() -> int:
	return _weather


func cycle_index() -> int:
	return int(floor(_elapsed / CYCLE_SECONDS))


## 0 at the start of the current phase, 1 at its end.
func phase_progress() -> float:
	var t := fposmod(_elapsed, CYCLE_SECONDS)
	for p in range(_phase):
		t -= PHASE_SECONDS[p]
	return clampf(t / PHASE_SECONDS[_phase], 0.0, 1.0)


## Freeze at a chosen pair. For gates and renders. The clock stops so a pinned run can
## never write a moved clock back into a save.
func pin(phase_value: int, weather_value: int) -> void:
	_pinned = true
	if phase_value != _phase:
		_phase = phase_value
		phase_changed.emit(_phase)
	if weather_value != _weather:
		_weather = weather_value
		weather_changed.emit(_weather)


func is_pinned() -> bool:
	return _pinned


func describe() -> String:
	return "%s, %s" % [phase_name(_phase), weather_name(_weather)]
```

The `test_weather_changes_only_at_a_phase_boundary` loop advances exactly to each next boundary; if the arithmetic in the test reads awkwardly, replace its body with `w.set_elapsed(<next boundary>)` computed from `PHASE_SECONDS` sums, keeping the assertions.

- [ ] **Step 4: Run the test** (8 passing). **Step 5: Commit** `feat: WorldState, the clock and the weather as arithmetic`.

---

### Task 2: `world_time` in the save, format version 3

**Files:**
- Modify: `game/systems/game_state.gd`, `game/systems/save_io.gd`
- Test: `game/test/test_game_state.gd`, `game/test/test_save_io.gd`

**Interfaces:**
- `GameState.world_time: float` (default 0.0), `const KEY_WORLD_TIME := "world_time"`; in `to_dict`, `from_dict` (missing or non-number falls back to 0.0, negative clamps to 0.0), `reset`.
- `SaveIO.FORMAT_VERSION := 3`; `migrate()` adds `world_time: 0.0` when absent (its `from_version < 3` branch); the class comment's version list gains a line.

- [ ] **Step 1: Tests.** In `test_game_state.gd`: extend the round-trip test with `state.world_time = 733.5` and `assert_almost_eq(copy.world_time, 733.5, 0.001)`; add `test_a_save_without_world_time_starts_at_dawn` (`from_dict({"bits": 1})` gives `world_time == 0.0`) and a negative-clamp case. In `test_save_io.gd`: pin `FORMAT_VERSION` to 3; extend the migrate test to assert `world_time` is added; add a composed v2-file test mirroring the existing v1 one (a hand-written v2 fixture with `gems`/`inventory` but no `world_time`, loaded through `SaveIO.load()` then `GameState.from_dict()`, asserting gems survive and `world_time` is 0.0). **Step 2:** run, expect failures. **Step 3:** implement. **Step 4:** run both files and the market gate (it saves and reloads). **Step 5: Commit** `feat: the world clock survives quitting; save format version 3`.

---

### Task 3: SkyRig, the rendering

**Files:**
- Create: `game/world/sky_rig.gd`
- Modify: `game/world/ranch.tscn` (a `SkyRig` Node3D with the script; the Sun and WorldEnvironment stay where they are and are found by path; a `Rain` GPUParticles3D child, emitting false)
- Test: `game/test/test_sky_rig.gd`

**Interfaces:**
- `class_name SkyRig extends Node3D`; `@export var sun_path: NodePath`, `@export var environment_path: NodePath`; `const TRANSITION_SECONDS := 8.0`.
- Pure mapping (static, tested): `sun_elevation_degrees(phase: int, progress: float) -> float` (DAWN rises from -4 to 20; DAY 20 to 60 to 20 across; DUSK 20 to -4; NIGHT -12 flat), `sun_azimuth_degrees(phase, progress)` (east to west over the day, fixed at night), `light_energy(phase, weather) -> float`, `light_color(phase, weather) -> Color`, `sky_top(phase, weather) -> Color`, `sky_horizon(phase, weather) -> Color`, `ambient_energy(phase, weather) -> float`, `fog_density(weather) -> float` (CLEAR 0.0011, RAIN 0.004, FOG 0.018, STORM 0.008), `rain_amount(weather) -> int` (0, 600, 0, 1400).
- Instance: `apply(state: WorldState) -> void` (sets the target from the state and starts the lerp), `apply_immediately(state: WorldState) -> void`, `current_targets() -> Dictionary` (for gates), `follow(target: Node3D)` (the rain emitter follows the player).

- [ ] **Step 1: Tests** for the pure mapping: the sun is below the horizon at NIGHT and above at DAY noon; elevation is continuous at phase boundaries (DAWN end equals DAY start, DAY end equals DUSK start) to within 0.01; STORM is darker than CLEAR in `light_energy`; FOG has the highest `fog_density`; `rain_amount` is 0 for CLEAR and FOG and positive for RAIN and STORM; `sky_top(NIGHT, CLEAR)` is darker (lower luminance) than `sky_top(DAY, CLEAR)`. Plus an instance test: build a rig under a world with a real `DirectionalLight3D` and `WorldEnvironment` (with an `Environment` that has a `Sky` with a `ProceduralSkyMaterial`), call `apply_immediately` with a pinned NIGHT/STORM state, assert the light's `rotation_degrees.x` puts it below the horizon, `light_energy` below the DAY value, `environment.fog_density` equals `fog_density(STORM)`, and the rain emitter's `amount` equals `rain_amount(STORM)` with `emitting` true.
- [ ] **Step 2:** run, expect failure. **Step 3:** implement (the colours: DAY light `(1.0, 0.97, 0.91)`, DAWN `(1.0, 0.78, 0.60)`, DUSK `(1.0, 0.62, 0.45)`, NIGHT `(0.55, 0.62, 0.85)` at energy 0.25; weather multiplies energy: RAIN 0.7, FOG 0.6, STORM 0.45; sky top DAY `(0.31, 0.51, 0.76)`, DAWN `(0.62, 0.55, 0.70)`, DUSK `(0.58, 0.40, 0.55)`, NIGHT `(0.05, 0.07, 0.15)`; horizons lighter per the existing `ranch.tscn` ratios; the rain emitter is a `GPUParticles3D` with a `BoxMesh` streak 0.02 x 0.5 x 0.02, `ParticleProcessMaterial` gravity `(0, -18, 0)`, emission box 14 x 1 x 14 above the followed node, lifetime 1.2; `_process` lerps every applied property toward its target at `delta / TRANSITION_SECONDS`).
- [ ] **Step 4:** run the tests and the direct ranch scene (the rig must not change the ranch's checks; the sky at boot is whatever the loaded state says). **Step 5: Commit** `feat: SkyRig moves the sun, tints the sky, thickens the fog and lets it rain`.

---

### Task 4: Ranch wiring, the HUD line, and the override arguments

**Files:**
- Modify: `game/world/ranch.gd`, `game/ui/hud.gd`, `game/ui/hud.tscn`
- Test: `game/test/test_hud.gd`

**Interfaces:**
- `Ranch.get_world_state() -> WorldState`; `Ranch.advance_world(seconds: float)` (public, for gates); ranch creates the state from `GameState.world_seed` and `GameState.world_time` in `_bind_game_state()`, rebuilds it on `state_loaded` (like `rebind_economy()`), applies overrides from `--phase=`, `--weather=`, `--world-time=`, ticks it in `_physics_process()` when `_interactive` and not pinned, writes `world_time` back in `_sync_game_state()` unless pinned, connects `phase_changed`/`weather_changed` to `sky_rig.apply(state)` and `hud.set_world_line(state.describe())`, calls `sky_rig.apply_immediately(state)` at boot and `sky_rig.follow(player)`.
- `HUD.set_world_line(text: String)`, `HUD.get_world_line() -> String`; a `World` label under `Bits` in the `Bag` box (raise the box height as Task 11 of slice 1 did, by exactly the label's height plus separation).
- `_report()` gains: `"the world state exists"`, `"the sky rig is wired to the state"` (the rig's current targets match the state's phase), `"a pinned run does not move the clock"` (only when pinned), and prints `RANCH world elapsed=%.1f phase=%s weather=%s pinned=%s`.

- [ ] **Step 1:** HUD tests (`set_world_line("Dusk, rain")` reads back; the line carries no dash). **Step 2:** implement. **Step 3:** the direct ranch scene with and without `-- --phase=NIGHT --weather=STORM` (the `RANCH world` line must reflect the pin), the market and region gates (still green; they save and reload, and `world_time` now rides along), and the suite. **Step 4: Commit** `feat: the ranch keeps time; the HUD says what hour it is and what the sky is doing`.

---

### Task 5: The world gate, the sky sheet, docs and the floor

**Files:**
- Create: `game/scenes/test/world_test.gd`, `.tscn` (hosted ranch, like `region_test`)
- Create: `tools/sky_sheet.sh` (renders `world/ranch.tscn` with `--screenshot-dir` per phase x weather and tiles the 16 into `build/sky_sheet.png`)
- Modify: `tools/run_tests.sh`, `docs/testing.md`

Gate checks, in order: the ranch is hosted and its report passed; the state starts at DAWN with elapsed 0 on a fresh state; `advance_world(120.0)` flips to DAY and the sky rig's targets follow (sun elevation rises, `current_targets()["phase"] == DAY`); `advance_world(540.0)` flips to DUSK; the weather across a full cycle equals `WorldState.weather_for(seed, ...)` for each phase (determinism against the static function); the HUD line reads the state's `describe()`; saving writes `world_time` (read the file), reloading resumes at the same phase and weather (`state.reset()`, `rebind`, `load_from_slot`, compare); pinning via a second hosted instance is out of scope (covered by the direct-scene run in Task 4); `apply_immediately` at NIGHT/STORM sets the environment fog to `fog_density(STORM)` and the rain emitting. Marker `WORLD_OK checks=N` after the verdict.

The sky sheet loops phases x weathers, runs `xvfb-run -a tools/bin/godot --path game --audio-driver Dummy --resolution 960x540 world/ranch.tscn -- --screenshot-dir=<dir> --phase=<P> --weather=<W>`, keeps only the first shot each run produces (read `_capture_all()` for its shot names and pick the wide establishing one), and tiles 4 x 4 with labels. Look at the sheet and report anything that reads wrong (a black sky at DAWN, rain in FOG, a sun visible at NIGHT).

- [ ] **Step 1:** the gate; iterate to `WORLD_OK`. **Step 2:** the sheet, run in the background, then look. **Step 3:** docs subsection "The world gate" and a line on the sheet; `MIN_TESTS` to the new count. **Step 4: Commit** `test: the world gate and a sky sheet`.

---

## Self-review

**Spec coverage.** WorldState: phases, weather table, deterministic from seed, emits, `world_time` saved and resumed (Tasks 1, 2, 4). Rendering: sun, sky, fog, rain (Task 3). The visual harness for time and weather (Task 5's sheet). Not in this slice by design: conditional spawns and the spawner's re-evaluation (slice 5).

**Placeholder scan.** None; Tasks 3 to 5 give exact values and the checks by name.

**Type consistency.** `WorldState.pin/is_pinned/describe/weather_for` used by Tasks 3 to 5 as defined in Task 1; `SkyRig.apply/apply_immediately/current_targets/follow` used in Tasks 4 and 5 as defined in Task 3; `Ranch.get_world_state/advance_world` used in Task 5 as defined in Task 4.
