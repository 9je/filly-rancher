# Phase 3 Sound Push Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Filly Rancher a full natural sounding audio layer: four Ambient/Effects/UI buses under Master, a `Sound` autoload that is the single gateway to playback, ambient beds that crossfade with the day cycle and with the Strip and Palace zones, world SFX at every transaction the ranch already performs, casino table sound riding the animation state the tables already draw from, UI ticks through one shared hook, hoofsteps under the player, and a `SOUND_OK` gate that proves every file loads.

**Architecture:** The pipeline mirrors the prop pipeline. `tools/sound_manifest.txt` is the curation (one row per file: `dest|source_url|recipe`), `tools/fetch_sounds.sh` is the only thing that downloads and processes, and `game/assets/audio/sound_report.txt` is the measured proof it regenerates. The runtime is one autoload, `game/systems/sound.gd`: a `LIBRARY` constant mapping `StringName` ids to entries, three pools of players (2D, 3D, ambient), a private entropy seeded `RandomNumberGenerator` that makes every variation decision, and five public verbs (`play`, `play_at`, `ambient_set_phase`, `ambient_set_zone`, `stop_all`). Nothing else in the project constructs an `AudioStreamPlayer` for SFX. Callers pass an id and a position and nothing else; no caller ever picks a variant, a pitch or a bus.

**Tech Stack:** Godot 4.5.2, GDScript, GUT 9.5.0, ffmpeg 6.1.1 at `/usr/bin/ffmpeg`, curl, the project's headless gate conventions (`RANCH_OK`, `STORY_OK`, `SOUND_OK`, `bash tools/run_tests.sh`).

**Spec:** `docs/superpowers/specs/2026-09-04-sound-push-design.md`. Read it in full before Task 1. Sections 4 (Architecture), 5 (Content list) and 7 (Testing and the SOUND_OK gate) are the binding ones; section 8's non-goals are what keeps this slice from becoming a music slice.

---

## Global Constraints

These bind every task. A task's own requirements implicitly include all of them.

- **No em dash and no double hyphen dash in ANY new code line.** Not in GDScript, not in a comment, not in a player facing string, not in a manifest row's note. The only exemptions are `# --- section ---` banner comments, CLI flag strings (`--headless`, `--audio-driver`, `--import`), and quoted `"--"` detector literals inside tests. Use ";" or ":" or a comma. Prose documentation (this plan, `docs/testing.md`) uses " -- " as the house dash and that is fine; a `.gd`, `.sh`, `.tres` or `.txt` line is not prose.
- **Explicit type annotations wherever `:=` cannot infer the type.** Godot 4.5 promotes `INFERENCE_ON_VARIANT` to an error on the preload dependency compile path. Never `:=` off `weakref()`, off a `Dictionary.get()`, off an `Array` subscript, or off anything else returning `Variant`. `tools/run_tests.sh`'s parse sweep is what catches this; GUT does not.
- **Preload by `res://` path, never by the global `class_name`,** in production code AND in test code. Every construction, static call and constant read goes through a `const XScript := preload("res://...")` at the top of the file. A bare `class_name` may appear ONLY as a type annotation.
- **Every new `.gd` and every new `.tscn` gets its `.uid` sidecar committed,** and every new audio file gets its `.import` sidecar committed. After creating files run `tools/bin/godot --headless --path game --import` once and `git add` the generated `game/**/*.uid` and `game/assets/audio/**/*.import`. `.tres` files under `game/data/` are the one exception and this slice creates none there.
- **Menus draw and emit; `ranch.gd` transacts and owns pause.** Nothing under `game/ui/` may touch `Economy`, `GameState`, `Ledger` or `Story`. Calling `Sound.play(&"ui_move")` from a menu IS allowed and is the whole point of the shared hook: `Sound` is a system, the menu passes an id and nothing else.
- **No `RandomNumberGenerator` may be constructed anywhere under `game/ui/`, and no `randi`/`randf` call may appear there.** Every variation decision (which hoofstep, which pitch, which chip clink) happens inside `game/systems/sound.gd` on `Sound`'s own private generator.
- **THE MATH DOES NOT CHANGE.** No casino outcome, capture roll, economy path or seeded draw may consume or perturb a game RNG stream because a sound played. `Sound._rng` is its own `RandomNumberGenerator` instance, `randomize()`d once at `_ready()`, and it is the only generator this slice creates. Casino sound triggers read only already public state and signals the drawing code already reads: `animating()`, `cards_dealt()`, `pocket_under_pointer()`, `reel_offset()`, `race_settled`. No new state, no new timing, no new order of operations.
- **Input parity, and no `Button` nodes.** This slice adds two settings rows; they are drawn rows on the existing settings page, driven by `ui_left`/`ui_right` exactly as `Master volume` already is.
- **Census is sacred.** This slice adds no props and no ponies. `RANCH_OK ponies=49 props=111 assets=present` must read exactly the same at the end of Task 9 as it does at the start of Task 1. Nothing here touches `$Buildings`, `$Props` or `$Attendants`.
- **The words "killed", "kill" and "dead" never appear in any player facing string,** in any comment, in any test name, or in any manifest note.
- **`AudioSafety` stays the backstop and every existing `--audio-driver Dummy` invocation stays.** `game/systems/audio_safety.gd` is unchanged by this slice. `Sound` registers in `[autoload]` AFTER `AudioSafety` so the Master mute is already in place before any stream can be preloaded or played.
- **No gate scene may write into `user://saves`.** There is a parked defect about gate boots writing live saves; this slice must not worsen it. `game/scenes/test/sound_test.tscn` hosts NO ranch and touches no save slot; it is a bare `Node` that boots the autoloads and exercises `Sound` directly.
- **Gates: marker after the verdict, exit code IS the verdict.** Command form: `tools/bin/godot --headless --audio-driver Dummy --path game <scene>`. This slice adds `game/scenes/test/sound_test.tscn`, printing `SOUND_OK ids=<n>` or `SOUND_FAILED ids=<n>`.
- **Godot 4.5 traps this project has already paid for.** `assert_le` does not exist; use `assert_lte`. Never wait a fixed number of frames headless for a state to arrive; wait on the state with a hard frame cap. A duplicate `var` declaration is a silent parse failure that hangs a gate scene. A property `Tween` cannot address an `Array` element; use `tween_method`. `draw_*` calls are legal only inside a `NOTIFICATION_DRAW` context.
- **A red intermediate state is never a resting state.** Every task ends with `bash tools/run_tests.sh` green and a commit. A GUT "risky" zero assert test is not a resting state either: every test file this plan adds asserts something.
- **Every commit message ends with these two lines:**

```
Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
```

- **Branch:** `phase3-sound-push`, cut from `master`.

---

## What is on master today

Verified at `618126d`. Every task below is written against it; read this before Task 1.

**Audio, all of it.** The project ships exactly one sound: `game/assets/audio/voice/twilight/greeting_01.wav`, loaded by `game/actors/player/magic_beam.gd:1606` into a bare `AudioStreamPlayer` built in `_build_voice()` (line 1600) and fired once by `_play_first_capture_voice()` (line 1614). **That player is out of scope. Do not modify `_build_voice()`, `_play_first_capture_voice()`, `VOICE_LINE` or `_voice`.** There is no bus layout resource, no `[audio]` block in `game/project.godot`, and no `AudioStreamPlayer3D` anywhere in the project.

**`game/project.godot`'s `[autoload]` block** currently reads, in this order:

```
AudioSafety="*res://systems/audio_safety.gd"
GameState="*res://systems/game_state.gd"
InputDevice="*res://systems/input_device.gd"
```

**`game/systems/audio_safety.gd`** is an autoload `Node` whose `_ready()` mutes the Master bus when `DisplayServer.get_name() == "headless"` or any `OS.get_cmdline_user_args()` entry begins with `"--screenshot"`. Unchanged by this slice.

**`game/systems/settings.gd`** (`Settings`, a `RefCounted`, 91 lines) holds `master_volume := 1.0`, `mouse_sensitivity`, `invert_look`; `const PATH := "user://settings.cfg"`, `const SECTION := "settings"`, `const VOLUME_STEP := 0.1`; `signal changed()`; `load_from(path)`, `save_to(path)`, `step_volume(direction)`, `step_sensitivity(direction)`, `toggle_invert()`, `apply_audio()`. `apply_audio()` mutes rather than setting -inf dB at zero, and re-checks the same two automated run conditions `AudioSafety` uses before ever unmuting. `game/test/test_settings.gd` is its test file.

**`game/systems/world_state.gd`** (`WorldState`) has `enum Phase { DAWN, DAY, DUSK, NIGHT }`, `phase() -> int`, `weather() -> int`, `cycle_index() -> int`, and emits `phase_changed(phase)` and `weather_changed(weather)`.

**`game/world/ranch.gd`** (6614 lines) is the transactor.
- `_on_world_phase_changed(_phase)` at line 1529 and `_on_world_weather_changed(_weather)` at line 1533 both funnel into `_on_world_changed()` at line 1537, which is the ONE handler. `_report()`'s reload probe asserts each signal carries exactly one connection, so a second listener is forbidden: new work goes inside `_on_world_changed()`.
- `_post_due_mail()` at line 3226 posts the batch and calls `_toast(MAIL_ARRIVED)` at the `if posted > 0:` branch.
- `_economy.grant()` is called at line 2758 (cashing out chips), line 3471 (the Survey bonus) and line 3700 (a Request Board reward).
- `signal race_settled(payout: int, winner: int)` is declared at line 130 and emitted once, at line 2954.
- `_physics_process(delta)` at line 4179 runs the interactive only block: `spawner.tick_stock(delta)`, `_update_interaction()`, `enforce_casino_ban()`, `_update_gate_prompt()`, then the farmhouse autosave proximity check. `_interactive` is false for every gate.
- `@onready var strip: Node3D = $Strip` at line 486, `@onready var race_track: Node3D = $Strip/Track` at line 495.
- `_regions_registry().by_id(StripScript.REGION_ID)` returns the Strip `RegionData`; `RegionData.contains(point: Vector2) -> bool` tests its disc.
- `casino_menu` is the Palace interior panel; `CasinoMenu` emits `opened()` and `closed()`.

**`game/systems/region_data.gd`** (`RegionData`) exports `id`, `display_name`, `centre: Vector2`, `radius: float` and has `contains(point: Vector2) -> bool`.

**`game/ui/menu_style.gd`** (`MenuStyle`, 245 lines) is all `static func`: `style_label`, `caret`, `tab_strip`, `footer`, `footer_tabs_and_rows`, `footer_rows`, `footer_reading`, `panel_style`, `apply_panel`, `row_box`, `row_panel`, `title_font`, `numeral_font`, `apply_title`, `rule`. It preloads `res://systems/input_device.gd`. Nine files under `game/ui/` define `move_selection`: `table_menu.gd`, `build_menu.gd`, `depot_menu.gd`, `blackjack_menu.gd`, `casino_menu.gd`, `market_menu.gd`, `wheel_menu.gd`, `slots_menu.gd`, `pause_menu.gd`.

**`game/ui/pause_menu.gd`** (1017 lines) has `enum Page { MAIN, SETTINGS, COMPENDIUM, REQUESTS, MAIL, LEDGER }`, `enum Row { RESUME, COMPENDIUM, REQUESTS, MAIL, LEDGER, SAVE, SETTINGS, QUIT }`, `enum SettingRow { VOLUME, SENSITIVITY, INVERT }`, `signal mail_opened(id)` at line 120 and `signal mail_reply(id, choice)` at 121, `var _page: int = Page.MAIN` at 150, `open()` at 187, `open_page(page)` at 214, `close()` at 227, `_unhandled_input(event)` at 381, `mail_opened.emit(id)` at 670, `refresh_page()` at 788, `_draw_settings()` at 801 whose first row is added by `_add_row(0, "Master volume", "%d%%" % int(round(settings.master_volume * 100.0)))` at line 806.

**`game/ui/table_menu.gd`** (`TableMenu`, a `CanvasLayer`) is the shared base for the four casino tables. It has `signal opened()` and `signal closed()`, `open()`, `close()`, `is_open()`, `move_selection(step)` at line 136, `confirm()` at 269, `switch_tab(step)` at 273, `_process(delta)` at 285 (increments `_anim_t`, queues a redraw), `animating()` at 317 and `_unhandled_input(event)` at 364.

**The four tables' animation state, all already public:**
- `game/ui/slots_menu.gd`: `show_spin(reels, won, stake)` at line 186 sets `_spinning = true` and builds one `Tween`; `reel_offset(index) -> float` at 137 is the live ribbon position of reel `index`; `animating()` at 133; `SlotsScript.REELS` is the reel count and `SlotsScript.REEL_SIZE` the symbols per turn.
- `game/ui/wheel_menu.gd`: `show_spin(pocket, won, stake)` at 282; `pocket_under_pointer() -> int` at 242; `_last_pocket` at 81 is already compared and updated inside `paint()` at lines 348 to 350, which is where the visual ratchet kick is computed; `wheel_angle()` at 213; `animating()` at 263.
- `game/ui/blackjack_menu.gd`: `show_hand(hand, won, stake)` at 199; `cards_dealt() -> int` at 155 returns `_dealt`, which the deal `Tween`'s per card callbacks raise one at a time; `_stamp` at 54 is set to 1.0 on a HIT or STAND stamp; `animating()` at 159.
- `game/ui/race_menu.gd`: `signal race_requested(uid, stake)` at 60. The race itself runs on `$Strip/Track` in the world, and `ranch.gd` owns both `race_track.is_running()` and `race_settled`.

**Gates are documented in `docs/testing.md`, not wired into `tools/run_tests.sh`.** `tools/run_tests.sh` (210 lines) runs the parse sweep, then GUT, then three invariants (nonzero tests, script count matches files on disk, `MIN_TESTS` floor). `MIN_TESTS="${FILLY_MIN_TESTS:-1342}"` is at line 186 and the suite currently reports 1342 tests. Each gate has a prose section in `docs/testing.md` ending in a fenced run command and an `Expect \`X_OK ...\`; the exit code is the verdict.` line; the story gate's section ends at line 1111. The thirteen scene gates are `smoke`, `camera`, `walk`, `world`, `region`, `market`, `collection`, `ledger`, `depot`, `creation`, `casino`, `story` plus `world/ranch.tscn` itself.

**`game/scripts/gate_watchdog.gd`** (`GateWatchdog`) is the shared "a gate must fail loudly, never hang silently" guard. Every gate arms it at the very top of `_ready()`.

**`.gitignore`** already ignores `assets_raw/`, `assets-inbox/`, `tools/bin/`, `game/assets/converted/`, `game/.godot/`, `build/`, `game/addons/gut/` and `game/assets/converted/**/*.import`. It deliberately does NOT blanket ignore `*.import`, because a committed asset must ship its sidecar or UIDs diverge between machines. This slice adds one ignore line for the raw download cache.

---

## File structure

**Created:**

| Path | Responsibility |
|---|---|
| `game/default_bus_layout.tres` | The four bus layout: Master, Ambient, Effects, UI. Referenced from `project.godot`. |
| `game/systems/sound.gd` | The `Sound` autoload. `LIBRARY`, `BEDS`, the three player pools, the private RNG, and the five public verbs. The only file in the project that constructs an `AudioStreamPlayer` for SFX. |
| `tools/sound_manifest.txt` | The curation. One row per audio file: `dest\|source_url\|recipe`, with `#` notes carrying the source description and the alternate candidate ids. |
| `tools/fetch_sounds.sh` | Downloads each row into the cache, runs its ffmpeg recipe, writes the processed file, regenerates `game/assets/audio/sound_report.txt`, fails any row that clips or misses its loudness target. |
| `game/assets/audio/sound_report.txt` | The regenerated measured proof: one PASS/FAIL row per file with duration, integrated LUFS and true peak. Committed. |
| `game/assets/audio/{ambient,world,casino,ui}/*.{ogg,wav}` | The processed audio, with `.import` sidecars. |
| `game/test/test_sound_library.gd` | The corpus test: paths exist, no orphans either way, ids follow the scheme, variant sets contiguous, pitch ranges sane, bus routing correct, every file PASSes in the report. |
| `game/test/test_sound.gd` | The behaviour test: pool stealing, variant and pitch selection off a seeded RNG, phase and zone bookkeeping, missing id is a `push_error` and not a crash. |
| `game/scenes/test/sound_test.gd` + `.tscn` | The `SOUND_OK` gate. Boots headless, loads every stream, asserts loop flags and bus routing, exercises all five verbs, writes no save. |

**Modified:**

| Path | Change |
|---|---|
| `game/project.godot` | `[autoload]` gains `Sound` after `InputDevice`; a new `[audio]` block points `buses/default_bus_layout` at the new `.tres`. |
| `game/systems/settings.gd` | `ambient_volume` and `effects_volume` fields, their persistence, `step_ambient()`, `step_effects()`, and `apply_audio()` pushing all three buses. |
| `game/ui/pause_menu.gd` | Two settings rows, `SettingRow` gains two entries, and the `ui_open`/`ui_page`/`ui_move`/`ui_confirm`/`ui_back`/`ui_denied` call sites. |
| `game/ui/menu_style.gd` | Six tiny static forwarders: `tick_move()`, `tick_confirm()`, `tick_back()`, `tick_open()`, `tick_denied()`, `tick_page()`. |
| `game/ui/{table,slots,wheel,blackjack,race,casino,market,depot,build}_menu.gd` | Calls to the `MenuStyle.tick_*` forwarders and, for the four tables, the animation state triggers. |
| `game/world/ranch.gd` | `_on_world_changed()` gains the phase bed call; `_physics_process()` gains the zone poll; `_post_due_mail()`, the three `_economy.grant()` sites, `deliver_pony()` and `_on_race_settled` gain their one line each. |
| `game/actors/player/player.gd` | The hoofstep cadence: a distance accumulator and one `Sound.play_at()` call. |
| `game/actors/player/magic_beam.gd` | Two lines only: a `capture_charge` beside `_begin_hold()`'s start and a `capture_success` beside `captured.emit()`. The voice player is untouched. |
| `game/test/test_settings.gd` | The two new volumes' clamp, step, persist and apply cases. |
| `tools/run_tests.sh` | `MIN_TESTS` raised to the number the final run reports. |
| `docs/testing.md` | The `SOUND_OK` gate section, and the sound pipeline's own section. |
| `.gitignore` | `tools/sound_cache/`. |

---

## Task 1: The buses, the `Sound` autoload skeleton, and two more volume sliders

**Files:**
- Create: `game/default_bus_layout.tres`
- Create: `game/systems/sound.gd`
- Create: `game/test/test_sound.gd`
- Modify: `game/project.godot` (a new `[audio]` block, and `Sound` appended to `[autoload]`)
- Modify: `game/systems/settings.gd`
- Test: `game/test/test_sound.gd`, `game/test/test_settings.gd`

**Interfaces:**
- Consumes: nothing from a later task.
- Produces, and every later task depends on these exact names:
  - `Sound.BUS_MASTER := &"Master"`, `Sound.BUS_AMBIENT := &"Ambient"`, `Sound.BUS_EFFECTS := &"Effects"`, `Sound.BUS_UI := &"UI"`
  - `Sound.POOL_2D := 12`, `Sound.POOL_3D := 8`, `Sound.BED_VOICES := 10`, `Sound.CROSSFADE_SECONDS := 4.0`, `Sound.SILENT_DB := -60.0`, `Sound.ATTENUATION_METRES := 22.0`
  - `Sound.LIBRARY: Dictionary` mapping `StringName` id to an entry `{"paths": PackedStringArray, "bus": StringName, "volume_db": float, "pitch_min": float, "pitch_max": float, "loop": bool}` (empty in this task; Tasks 3, 4 and 5 fill it)
  - `Sound.BEDS: Dictionary` mapping `WorldState.Phase` int to `Array[Dictionary]` of `{"id": StringName, "volume_db": float}` (empty here; Task 3 fills it)
  - `Sound.ZONE_BEDS: Dictionary` mapping zone `StringName` to the same array shape (empty here; Task 3 fills it)
  - `Sound.ZONE_NONE := &""`, `Sound.ZONE_STRIP := &"strip"`, `Sound.ZONE_CASINO := &"casino"`
  - `Sound.play(id: StringName) -> bool`
  - `Sound.play_at(id: StringName, pos: Vector3) -> bool`
  - `Sound.play_loop(id: StringName) -> bool` and `Sound.stop_loop(id: StringName) -> void` (a held, non ambient loop: the race crowd and the gallop, which start when a race starts and stop when it settles)
  - `Sound.looping_ids() -> Array[StringName]`
  - `Sound.ambient_set_phase(phase: int) -> void`
  - `Sound.ambient_set_zone(zone: StringName) -> void`
  - `Sound.stop_all() -> void`
  - `Sound.ids() -> Array[StringName]`, `Sound.has_id(id: StringName) -> bool`, `Sound.entry(id: StringName) -> Dictionary`
  - `Sound.current_phase() -> int`, `Sound.current_zone() -> StringName`, `Sound.active_bed_ids() -> Array[StringName]`
  - `Sound.pick_variant(count: int) -> int`, `Sound.pick_pitch(low: float, high: float) -> float`
  - `Sound.bus_index_for(bus: StringName) -> int`
  - `Settings.ambient_volume: float`, `Settings.effects_volume: float`, `Settings.step_ambient(direction: int) -> void`, `Settings.step_effects(direction: int) -> void`

### A note on the entry shape, and why it is not literally the spec's

The spec writes an entry as `{path, bus, volume_db, pitch_min, pitch_max, variants: [paths...]}`: a single path plus an optional variant list. This plan collapses that to one always present `paths: PackedStringArray` whose size is 1 for a non variant sound. Same information, one shape rather than two, and the corpus test in Task 3 gets a single rule to check instead of a branch. This is the only deliberate departure from a spec section 4.2 literal, and it is recorded again in "Parked for the owner" at the foot of this plan.

- [ ] **Step 1: Write the bus layout resource**

Create `game/default_bus_layout.tres` with exactly this content. Master is bus 0 and sends nowhere; the other three send to Master, which is what makes `AudioSafety`'s Master mute cover all of them.

```
[gd_resource type="AudioBusLayout" format=3]

[resource]
bus/0/name = &"Master"
bus/0/solo = false
bus/0/mute = false
bus/0/bypass_fx = false
bus/0/volume_db = 0.0
bus/0/send = &""
bus/1/name = &"Ambient"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"Effects"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
bus/3/name = &"UI"
bus/3/solo = false
bus/3/mute = false
bus/3/bypass_fx = false
bus/3/volume_db = 0.0
bus/3/send = &"Master"
```

- [ ] **Step 2: Point the project at it, and register the autoload**

In `game/project.godot`, add an `[audio]` block (put it directly after the `[autoload]` block, before `[rendering]`):

```
[audio]

buses/default_bus_layout="res://default_bus_layout.tres"
```

Then append one line to the `[autoload]` block, AFTER `InputDevice`:

```
Sound="*res://systems/sound.gd"
```

Order is load bearing and there is a comment in that block already explaining why `AudioSafety` is first: `AudioSafety._ready()` must have muted Master before `Sound._ready()` preloads and before anything can play. Add this sentence to the block's comment, directly above the `[autoload]` header, in the same style as the paragraphs already there:

```
; Sound (game/systems/sound.gd): the one gateway to audio playback. Owns the player
; pools, the ambient beds and the private RandomNumberGenerator that makes every
; variation choice, so no menu and no gameplay path ever has to. Registered LAST of the
; four because it is the only autoload that can make noise, and AudioSafety above has to
; have muted Master before this one's _ready() builds a single player.
```

- [ ] **Step 3: Write the failing test**

Create `game/test/test_sound.gd`:

```gdscript
extends GutTest
## Tests for game/systems/sound.gd: the pools, the private generator, the phase and zone
## bookkeeping, and the refusal path. Nothing here needs an audio file on disk; the corpus
## of real sounds is game/test/test_sound_library.gd's job.
##
## Sound is an autoload, so these tests drive the LIVE instance and put it back afterwards.
## The suite runs with --audio-driver Dummy and AudioSafety has muted Master, so a play()
## in here is silent by construction.

const SoundScript := preload("res://systems/sound.gd")


func after_each() -> void:
	Sound.stop_all()


func test_the_four_buses_exist_and_route_into_master() -> void:
	assert_eq(AudioServer.bus_count, 4)
	assert_eq(AudioServer.get_bus_name(0), "Master")
	for bus: StringName in [SoundScript.BUS_AMBIENT, SoundScript.BUS_EFFECTS, SoundScript.BUS_UI]:
		var index: int = AudioServer.get_bus_index(String(bus))
		assert_gt(index, 0, "bus %s must exist and must not be Master" % bus)
		assert_eq(AudioServer.get_bus_send(index), &"Master")


func test_the_pools_are_built_at_the_declared_sizes() -> void:
	assert_eq(Sound.pool_2d_size(), SoundScript.POOL_2D)
	assert_eq(Sound.pool_3d_size(), SoundScript.POOL_3D)
	assert_eq(Sound.bed_voice_size(), SoundScript.BED_VOICES)


func test_an_unknown_id_is_refused_and_does_not_crash() -> void:
	assert_false(Sound.play(&"no_such_sound_at_all"))
	assert_false(Sound.play_at(&"no_such_sound_at_all", Vector3.ZERO))
	assert_false(Sound.has_id(&"no_such_sound_at_all"))
	assert_eq(Sound.entry(&"no_such_sound_at_all").size(), 0)


func test_variant_picks_stay_inside_the_set() -> void:
	for i in range(200):
		var pick: int = Sound.pick_variant(3)
		assert_between(pick, 0, 2)
	assert_eq(Sound.pick_variant(1), 0)
	assert_eq(Sound.pick_variant(0), 0)


func test_pitch_picks_stay_inside_the_range_and_a_zero_range_is_exact() -> void:
	for i in range(200):
		var pitch: float = Sound.pick_pitch(0.92, 1.08)
		assert_between(pitch, 0.92, 1.08)
	assert_almost_eq(Sound.pick_pitch(1.0, 1.0), 1.0, 0.0001)


func test_the_phase_and_zone_are_remembered_and_a_repeat_is_a_no_op() -> void:
	Sound.ambient_set_phase(2)
	assert_eq(Sound.current_phase(), 2)
	Sound.ambient_set_phase(2)
	assert_eq(Sound.current_phase(), 2)
	Sound.ambient_set_zone(SoundScript.ZONE_STRIP)
	assert_eq(Sound.current_zone(), SoundScript.ZONE_STRIP)
	Sound.ambient_set_zone(SoundScript.ZONE_NONE)
	assert_eq(Sound.current_zone(), SoundScript.ZONE_NONE)


func test_stop_all_empties_the_beds() -> void:
	Sound.ambient_set_phase(0)
	Sound.stop_all()
	assert_eq(Sound.active_bed_ids().size(), 0)
	assert_eq(Sound.current_phase(), -1)
	assert_eq(Sound.current_zone(), SoundScript.ZONE_NONE)


func test_the_generator_is_its_own_and_is_seeded() -> void:
	# THE MATH DOES NOT CHANGE: Sound must never reach for a shared stream. The only
	# generator it may touch is its own, and it must not be sitting on the default seed.
	assert_true(Sound.has_private_rng())
	assert_ne(Sound.rng_seed(), 0)
```

- [ ] **Step 4: Run it to make sure it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_sound.gd -gexit`
Expected: FAIL. The script will not even load, because `res://systems/sound.gd` does not exist yet.

- [ ] **Step 5: Write `game/systems/sound.gd`**

Create it in full. Note there is no double hyphen anywhere in this file except the `# --- banner ---` comments, which are the one exemption.

```gdscript
extends Node
## THE ONE GATEWAY TO SOUND. Every effect, tick and ambient bed in this game is played by
## this autoload and by nothing else. A caller passes an id and, for a world sound, a
## position; it never picks a file, a pitch, a bus or a player. That is not tidiness for its
## own sake: it is the only way to keep the promise below.
##
## THE MATH DOES NOT CHANGE. The variation this file adds (which hoofstep, which chip clink,
## what pitch) is decided on _rng, a RandomNumberGenerator this file owns and seeds from
## entropy at boot. It is the only generator in the audio path. No casino outcome, capture
## roll, economy payout or seeded draw may ever be perturbed because a sound played, and
## making the choice here rather than at the call site is what guarantees it: a menu that
## cannot construct a generator cannot spend one.
##
## REGISTERED AFTER AudioSafety, on purpose. AudioSafety._ready() mutes the Master bus for
## every headless and offscreen capture run; the three buses this file plays into all send
## to Master, so that one mute covers the lot. Autoloads run in declaration order, so
## AudioSafety is finished before the first player here exists.
##
## PAUSE. UI sounds run PROCESS_MODE_ALWAYS because menus are open while the tree is
## paused. World sounds, casino sounds and every ambient bed run PROCESS_MODE_PAUSABLE, so
## opening the pause menu stills the world's noise exactly as it stills its motion.

const BUS_MASTER := &"Master"
const BUS_AMBIENT := &"Ambient"
const BUS_EFFECTS := &"Effects"
const BUS_UI := &"UI"

## Pool sizes. Twelve 2D voices is comfortably past the busiest real moment measured in
## this game (a slots spin ticking three reels under a casino bed); the pool steals its
## oldest voice rather than growing, so a runaway caller degrades into overlap and never
## into an allocation storm.
const POOL_2D := 12
const POOL_3D := 8
## One voice per simultaneously audible bed, PLUS headroom for the ones still fading out.
## The worst case the tables in Task 3 can produce is five simultaneous beds (NIGHT plus
## the Strip), and a crossfade holds the departing set's voices for CROSSFADE_SECONDS on
## top of that, so the pool is sized for both halves of a change rather than for one.
const BED_VOICES := 10

const CROSSFADE_SECONDS := 4.0
## What "off" means for a bed voice. Not -inf dB: the bus accepts it and then behaves
## oddly, which is the same reason Settings.apply_audio() mutes at zero instead.
const SILENT_DB := -60.0
## Distance at which a 3D one shot has fallen away to nothing. The whole playable map is
## about 160 m across and a pen is 20 m, so this is "the next building over, faintly".
const ATTENUATION_METRES := 22.0

const ZONE_NONE := &""
const ZONE_STRIP := &"strip"
const ZONE_CASINO := &"casino"

## Sound id to entry. Filled by the content tasks; see game/test/test_sound_library.gd for
## the rules every entry is held to.
##   paths      PackedStringArray, one or more res:// paths. Size > 1 is a variant set and
##              the file names must run _1 to _N with no gap.
##   bus        BUS_AMBIENT, BUS_EFFECTS or BUS_UI.
##   volume_db  offset applied on top of the file's own mastered level.
##   pitch_min  lower bound of the per play pitch roll.
##   pitch_max  upper bound; equal to pitch_min means "never vary".
##   loop       true only for the ogg beds; every wav one shot is false.
const LIBRARY: Dictionary = {}

## WorldState.Phase int to the beds that phase runs. Filled in Task 3.
const BEDS: Dictionary = {}

## Zone StringName to the beds that zone overlays on top of the phase. Filled in Task 3.
const ZONE_BEDS: Dictionary = {}


# --- state ------------------------------------------------------------------------------

var _streams: Dictionary = {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next_2d := 0
var _next_3d := 0
var _bed_voices: Array[AudioStreamPlayer] = []
## Held loops that are not beds, one dedicated player per id. See play_loop().
var _loops: Dictionary = {}
## Bed id to the index in _bed_voices currently carrying it.
var _bed_playing: Dictionary = {}
## Voice indices whose bed has been released and is still fading out. Held apart from
## _bed_playing so a departing bed cannot have its voice reassigned mid fade.
var _bed_releasing: Dictionary = {}
var _bed_tweens: Dictionary = {}
var _phase := -1
var _zone: StringName = ZONE_NONE
var _rng: RandomNumberGenerator = null
var _rng_seed := 0


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_rng_seed = _rng.seed
	_build_pools()
	_load_streams()


# --- construction -------------------------------------------------------------------------

func _build_pools() -> void:
	for i in POOL_2D:
		var player := AudioStreamPlayer.new()
		player.name = "Voice2D_%d" % i
		player.bus = String(BUS_EFFECTS)
		# Set per play; PAUSABLE is the safe default for a world sound.
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		_pool_2d.append(player)
	for i in POOL_3D:
		var player3d := AudioStreamPlayer3D.new()
		player3d.name = "Voice3D_%d" % i
		player3d.bus = String(BUS_EFFECTS)
		player3d.process_mode = Node.PROCESS_MODE_PAUSABLE
		player3d.max_distance = ATTENUATION_METRES
		player3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player3d)
		_pool_3d.append(player3d)
	for i in BED_VOICES:
		var bed := AudioStreamPlayer.new()
		bed.name = "Bed_%d" % i
		bed.bus = String(BUS_AMBIENT)
		bed.process_mode = Node.PROCESS_MODE_PAUSABLE
		bed.volume_db = SILENT_DB
		add_child(bed)
		_bed_voices.append(bed)


## Every path named by LIBRARY, loaded once. load() rather than preload(): a missing or
## corrupt file must be a push_error a player can still play through, never a parse error
## that takes the whole autoload down and with it every other sound in the game.
func _load_streams() -> void:
	for id: StringName in LIBRARY.keys():
		var entry: Dictionary = LIBRARY[id]
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			if _streams.has(path):
				continue
			var stream: Resource = load(path)
			if stream is AudioStream:
				_streams[path] = stream
			else:
				push_error("Sound: '%s' (id %s) did not load as an AudioStream" % [path, id])


# --- the public verbs ---------------------------------------------------------------------

## A 2D one shot: something the player is told about rather than something happening at a
## place. UI ticks and the capture stinger. Returns false when the id is unknown or its
## file failed to load, so a gate can assert on the refusal.
func play(id: StringName) -> bool:
	# NOT `var entry :=`: a local of that name would shadow this class's own entry()
	# method, which GDScript reports as a parse error on the dependency compile path the
	# suite's sweep runs. Every reader in this file uses entry_data for the same reason.
	var entry_data: Dictionary = entry(id)
	if entry_data.is_empty():
		push_error("Sound.play: unknown id '%s'" % id)
		return false
	var stream: AudioStream = _pick_stream(entry_data)
	if stream == null:
		return false
	var player: AudioStreamPlayer = _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	player.stop()
	player.stream = stream
	player.bus = String(entry_data.get("bus", BUS_EFFECTS))
	player.volume_db = float(entry_data.get("volume_db", 0.0))
	player.pitch_scale = pick_pitch(
		float(entry_data.get("pitch_min", 1.0)), float(entry_data.get("pitch_max", 1.0)))
	# A UI tick has to be audible while the tree is paused; nothing else does.
	player.process_mode = Node.PROCESS_MODE_ALWAYS \
		if StringName(entry_data.get("bus", BUS_EFFECTS)) == BUS_UI \
		else Node.PROCESS_MODE_PAUSABLE
	player.play()
	return true


## A 3D one shot at a world position: hooves, a gate, a crate set down, a letterbox flap.
func play_at(id: StringName, pos: Vector3) -> bool:
	var entry_data: Dictionary = entry(id)
	if entry_data.is_empty():
		push_error("Sound.play_at: unknown id '%s'" % id)
		return false
	var stream: AudioStream = _pick_stream(entry_data)
	if stream == null:
		return false
	var player: AudioStreamPlayer3D = _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	player.stop()
	player.stream = stream
	player.bus = String(entry_data.get("bus", BUS_EFFECTS))
	player.volume_db = float(entry_data.get("volume_db", 0.0))
	player.pitch_scale = pick_pitch(
		float(entry_data.get("pitch_min", 1.0)), float(entry_data.get("pitch_max", 1.0)))
	player.global_position = pos
	player.play()
	return true


## A HELD LOOP THAT IS NOT A BED: the race crowd and the gallop under it. They start when a
## race starts, stop when it settles, sit on the Effects bus and pause with the world, so
## they are neither a one shot nor an ambient bed. One dedicated player per id, built on
## first use and kept, because a loop stolen out of the one shot pool would never stop.
func play_loop(id: StringName) -> bool:
	var entry_data: Dictionary = entry(id)
	if entry_data.is_empty():
		push_error("Sound.play_loop: unknown id '%s'" % id)
		return false
	if not bool(entry_data.get("loop", false)):
		push_error("Sound.play_loop: '%s' is not a looping entry" % id)
		return false
	var player: AudioStreamPlayer = _loop_player_for(id, entry_data)
	if player == null:
		return false
	if player.playing:
		return true
	player.play()
	return true


func stop_loop(id: StringName) -> void:
	var found: Variant = _loops.get(id, null)
	if found is AudioStreamPlayer:
		found.stop()


func looping_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _loops.keys():
		var player: AudioStreamPlayer = _loops[id]
		if player.playing:
			out.append(id)
	out.sort()
	return out


func _loop_player_for(id: StringName, entry_data: Dictionary) -> AudioStreamPlayer:
	var found: Variant = _loops.get(id, null)
	if found is AudioStreamPlayer:
		return found
	var stream: AudioStream = _pick_stream(entry_data)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = "Loop_%s" % id
	player.stream = stream
	player.bus = String(entry_data.get("bus", BUS_EFFECTS))
	player.volume_db = float(entry_data.get("volume_db", 0.0))
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	_loops[id] = player
	return player


## Cross into this phase's bed set. A repeat of the phase already running is a no op, which
## matters because ranch.gd calls this from _on_world_changed(), which a weather roll can
## fire without the phase having moved at all.
func ambient_set_phase(phase: int) -> void:
	if phase == _phase:
		return
	_phase = phase
	_apply_beds()


## Overlay this zone's beds on top of the phase's. ZONE_NONE takes the overlay away.
func ambient_set_zone(zone: StringName) -> void:
	if zone == _zone:
		return
	_zone = zone
	_apply_beds()


## Everything off, immediately, and the bookkeeping back to boot. Used by the gate between
## checks and by after_each() in the suite.
func stop_all() -> void:
	for player: AudioStreamPlayer in _pool_2d:
		player.stop()
	for player3d: AudioStreamPlayer3D in _pool_3d:
		player3d.stop()
	for id: StringName in _loops.keys():
		var loop: AudioStreamPlayer = _loops[id]
		loop.stop()
	for id: StringName in _bed_tweens.keys():
		var tween: Tween = _bed_tweens[id]
		if tween != null and tween.is_valid():
			tween.kill()
	_bed_tweens.clear()
	for bed: AudioStreamPlayer in _bed_voices:
		bed.stop()
		bed.volume_db = SILENT_DB
	_bed_playing.clear()
	_bed_releasing.clear()
	_phase = -1
	_zone = ZONE_NONE


# --- readers, for callers and for the gate ------------------------------------------------

func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in LIBRARY.keys():
		out.append(id)
	out.sort()
	return out


func has_id(id: StringName) -> bool:
	return LIBRARY.has(id)


func entry(id: StringName) -> Dictionary:
	var found: Variant = LIBRARY.get(id, {})
	return found if found is Dictionary else {}


func current_phase() -> int:
	return _phase


func current_zone() -> StringName:
	return _zone


func active_bed_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _bed_playing.keys():
		out.append(id)
	out.sort()
	return out


func pool_2d_size() -> int:
	return _pool_2d.size()


func pool_3d_size() -> int:
	return _pool_3d.size()


func bed_voice_size() -> int:
	return _bed_voices.size()


func has_private_rng() -> bool:
	return _rng != null


func rng_seed() -> int:
	return _rng_seed


func stream_for(path: String) -> AudioStream:
	var found: Variant = _streams.get(path, null)
	return found if found is AudioStream else null


func bus_index_for(bus: StringName) -> int:
	return AudioServer.get_bus_index(String(bus))


# --- the private generator, and nothing else ----------------------------------------------

## Which variant. Always in range, always on _rng, never on a shared stream.
func pick_variant(count: int) -> int:
	if count <= 1 or _rng == null:
		return 0
	return _rng.randi_range(0, count - 1)


## What pitch. An equal pair means the sound never varies, and that path spends no roll at
## all, so an unvarying sound cannot advance the generator either.
func pick_pitch(low: float, high: float) -> float:
	if _rng == null or is_equal_approx(low, high):
		return low
	return _rng.randf_range(minf(low, high), maxf(low, high))


func _pick_stream(entry_data: Dictionary) -> AudioStream:
	var paths: PackedStringArray = entry_data.get("paths", PackedStringArray())
	if paths.is_empty():
		return null
	var path: String = paths[pick_variant(paths.size())]
	var stream: AudioStream = stream_for(path)
	if stream == null:
		push_error("Sound: no loaded stream for '%s'" % path)
	return stream


# --- the beds -----------------------------------------------------------------------------

## What should be sounding right now: the phase's beds plus the zone's, keyed by id so a
## bed named by both is carried once at the louder of the two levels.
func _wanted_beds() -> Dictionary:
	var wanted: Dictionary = {}
	var phase_rows: Variant = BEDS.get(_phase, [])
	if phase_rows is Array:
		for row: Dictionary in phase_rows:
			var id: StringName = StringName(row.get("id", &""))
			wanted[id] = maxf(float(row.get("volume_db", 0.0)), float(wanted.get(id, SILENT_DB)))
	var zone_rows: Variant = ZONE_BEDS.get(_zone, [])
	if zone_rows is Array:
		for row: Dictionary in zone_rows:
			var id: StringName = StringName(row.get("id", &""))
			wanted[id] = maxf(float(row.get("volume_db", 0.0)), float(wanted.get(id, SILENT_DB)))
	return wanted


## Bring the wanted set in and take the rest out, both over CROSSFADE_SECONDS. Idempotent:
## a bed that is already sounding at the right level is left entirely alone, so a zone
## change under an unchanged phase does not restart the phase's own beds.
func _apply_beds() -> void:
	var wanted: Dictionary = _wanted_beds()
	for id: StringName in _bed_playing.keys():
		if not wanted.has(id):
			_fade_bed_out(id)
	for id: StringName in wanted.keys():
		_fade_bed_in(id, float(wanted[id]))


func _fade_bed_in(id: StringName, target_db: float) -> void:
	var entry_data: Dictionary = entry(id)
	if entry_data.is_empty():
		push_error("Sound: bed id '%s' is not in LIBRARY" % id)
		return
	var voice: AudioStreamPlayer = _bed_voice_for(id)
	if voice == null:
		return
	var stream: AudioStream = _pick_stream(entry_data)
	if stream == null:
		return
	var level: float = target_db + float(entry_data.get("volume_db", 0.0))
	if not voice.playing:
		voice.stream = stream
		voice.volume_db = SILENT_DB
		voice.play()
	_tween_bed(id, voice, level)


## A BED ON ITS WAY OUT KEEPS ITS VOICE UNTIL THE FADE ENDS, but stops counting as playing
## the moment it is released. Those are two different questions and answering them with one
## dictionary was a bug: the voice would be handed to an arriving bed while the departing
## one was still four seconds from silent, and both would write to the same volume.
func _fade_bed_out(id: StringName) -> void:
	var index: int = int(_bed_playing.get(id, -1))
	_bed_playing.erase(id)
	if index < 0 or index >= _bed_voices.size():
		return
	var voice: AudioStreamPlayer = _bed_voices[index]
	_bed_releasing[index] = true
	var previous: Variant = _bed_tweens.get(id, null)
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween: Tween = create_tween()
	tween.tween_property(voice, "volume_db", SILENT_DB, CROSSFADE_SECONDS)
	tween.tween_callback(func() -> void: _release_now(index))
	_bed_tweens[id] = tween


## One tween per bed id, killed and replaced rather than stacked; a phase that flips twice
## inside four seconds otherwise leaves two tweens arguing over one voice's volume.
func _tween_bed(id: StringName, voice: AudioStreamPlayer, target_db: float) -> void:
	var previous: Variant = _bed_tweens.get(id, null)
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween: Tween = create_tween()
	tween.tween_property(voice, "volume_db", target_db, CROSSFADE_SECONDS)
	_bed_tweens[id] = tween


## Stop a releasing voice at once and put it back in the pool.
func _release_now(index: int) -> void:
	if index < 0 or index >= _bed_voices.size():
		return
	var voice: AudioStreamPlayer = _bed_voices[index]
	voice.stop()
	voice.volume_db = SILENT_DB
	_bed_releasing.erase(index)


## The voice already carrying this bed, or a free one, or, failing both, one that is on its
## way out. Never null in practice: cutting a voice that is already most of the way to
## silent is always better than refusing the bed that is arriving.
func _bed_voice_for(id: StringName) -> AudioStreamPlayer:
	var held: int = int(_bed_playing.get(id, -1))
	if held >= 0 and held < _bed_voices.size():
		return _bed_voices[held]
	var taken: Dictionary = {}
	for other: StringName in _bed_playing.keys():
		taken[int(_bed_playing[other])] = true
	for index in _bed_voices.size():
		if taken.has(index) or _bed_releasing.has(index):
			continue
		_bed_playing[id] = index
		return _bed_voices[index]
	for index in _bed_voices.size():
		if taken.has(index):
			continue
		_release_now(index)
		_bed_playing[id] = index
		return _bed_voices[index]
	push_error("Sound: no free bed voice for '%s'; raise BED_VOICES" % id)
	return null
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_sound.gd -gexit`
Expected: PASS, 8 tests.

If `test_the_four_buses_exist_and_route_into_master` fails with `bus_count == 1`, the `[audio]` block is missing or its path is wrong; Godot silently falls back to a one bus layout. Confirm with `tools/bin/godot --headless --path game --check-only --script res://systems/sound.gd` first (a parse failure would present the same way).

- [ ] **Step 7: Write the failing settings test**

Append to `game/test/test_settings.gd`:

```gdscript
func test_the_two_new_volumes_default_open() -> void:
	var s = SettingsScript.new()
	assert_almost_eq(s.ambient_volume, 1.0, 0.0001)
	assert_almost_eq(s.effects_volume, 1.0, 0.0001)


func test_the_two_new_volumes_round_trip_through_a_file() -> void:
	var s = SettingsScript.new()
	s.ambient_volume = 0.3
	s.effects_volume = 0.7
	assert_true(s.save_to(SCRATCH))
	var back = SettingsScript.new()
	back.load_from(SCRATCH)
	assert_almost_eq(back.ambient_volume, 0.3, 0.0001)
	assert_almost_eq(back.effects_volume, 0.7, 0.0001)


func test_ambient_steps_clamp_at_both_ends_and_signal() -> void:
	var s = SettingsScript.new()
	watch_signals(s)
	for i in range(20):
		s.step_ambient(-1)
	assert_almost_eq(s.ambient_volume, 0.0, 0.0001)
	for i in range(20):
		s.step_ambient(1)
	assert_almost_eq(s.ambient_volume, 1.0, 0.0001)
	assert_signal_emitted(s, "changed")


func test_effects_steps_clamp_at_both_ends() -> void:
	var s = SettingsScript.new()
	for i in range(20):
		s.step_effects(-1)
	assert_almost_eq(s.effects_volume, 0.0, 0.0001)
	for i in range(20):
		s.step_effects(1)
	assert_almost_eq(s.effects_volume, 1.0, 0.0001)


func test_a_step_that_changes_nothing_emits_nothing() -> void:
	var s = SettingsScript.new()
	s.ambient_volume = 1.0
	watch_signals(s)
	s.step_ambient(1)
	assert_signal_emit_count(s, "changed", 0)


func test_apply_audio_pushes_all_three_sliders_and_zero_mutes() -> void:
	var s = SettingsScript.new()
	s.master_volume = 1.0
	s.ambient_volume = 0.5
	s.effects_volume = 0.0
	s.apply_audio()
	var ambient: int = AudioServer.get_bus_index("Ambient")
	var effects: int = AudioServer.get_bus_index("Effects")
	var ui: int = AudioServer.get_bus_index("UI")
	assert_gt(ambient, 0)
	assert_false(AudioServer.is_bus_mute(ambient))
	assert_almost_eq(AudioServer.get_bus_volume_db(ambient), linear_to_db(0.5), 0.01)
	# Zero mutes rather than setting -inf dB, and the UI bus rides the effects slider.
	assert_true(AudioServer.is_bus_mute(effects))
	assert_true(AudioServer.is_bus_mute(ui))
	# Put the buses back so a later test in the same run is not reading this one's leavings.
	s.effects_volume = 1.0
	s.apply_audio()


func test_a_loaded_file_missing_the_new_keys_keeps_the_defaults() -> void:
	# A settings.cfg written before this slice has no ambient_volume key at all; it must
	# load as "wide open", not as silence.
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "master_volume", 0.8)
	assert_eq(cfg.save(SCRATCH), OK)
	var s = SettingsScript.new()
	s.load_from(SCRATCH)
	assert_almost_eq(s.master_volume, 0.8, 0.0001)
	assert_almost_eq(s.ambient_volume, 1.0, 0.0001)
	assert_almost_eq(s.effects_volume, 1.0, 0.0001)
```

- [ ] **Step 8: Run it to verify it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_settings.gd -gexit`
Expected: FAIL with "Invalid access to property or key 'ambient_volume'".

- [ ] **Step 9: Grow `game/systems/settings.gd`**

Change the class comment's first sentence to name all three volumes:

```gdscript
## WHAT THE PAUSE MENU'S SETTINGS PAGE EDITS: master, ambient and effects volume, mouse
## sensitivity, invert look. Persisted in user://settings.cfg, deliberately NOT in the
```

Add the two fields directly under `var master_volume := 1.0`:

```gdscript
var master_volume := 1.0
## The two sub mixes, on the Ambient and Effects buses. The UI bus rides effects_volume:
## a fourth slider is knob clutter for a channel nobody wants louder than its own game.
var ambient_volume := 1.0
var effects_volume := 1.0
```

In `load_from()`, directly after the `master_volume` line:

```gdscript
	ambient_volume = clampf(float(cfg.get_value(SECTION, "ambient_volume", ambient_volume)), 0.0, 1.0)
	effects_volume = clampf(float(cfg.get_value(SECTION, "effects_volume", effects_volume)), 0.0, 1.0)
```

In `save_to()`, directly after the `master_volume` line:

```gdscript
	cfg.set_value(SECTION, "ambient_volume", ambient_volume)
	cfg.set_value(SECTION, "effects_volume", effects_volume)
```

Add the two steppers directly after `step_volume()`:

```gdscript
func step_ambient(direction: int) -> void:
	var next := clampf(ambient_volume + VOLUME_STEP * signf(direction), 0.0, 1.0)
	if is_equal_approx(next, ambient_volume):
		return
	ambient_volume = next
	changed.emit()


func step_effects(direction: int) -> void:
	var next := clampf(effects_volume + VOLUME_STEP * signf(direction), 0.0, 1.0)
	if is_equal_approx(next, effects_volume):
		return
	effects_volume = next
	changed.emit()
```

Replace `apply_audio()`'s body with the three bus version. The automated run check is unchanged and still guards only the Master unmute; the three sub buses feed Master, so a muted Master silences them whatever they are set to.

```gdscript
func apply_audio() -> void:
	_apply_bus("Ambient", ambient_volume)
	_apply_bus("Effects", effects_volume)
	# The UI bus deliberately rides the effects slider; see the field comment.
	_apply_bus("UI", effects_volume)
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(master, true)
		return
	AudioServer.set_bus_volume_db(master, linear_to_db(master_volume))
	var automated := DisplayServer.get_name() == "headless"
	if not automated:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--screenshot"):
				automated = true
				break
	if not automated:
		AudioServer.set_bus_mute(master, false)


## One sub bus, same "zero mutes rather than -inf dB" rule Master gets. Silent about a bus
## that is not in the layout, so a settings object built in a test with no bus layout
## loaded is still usable.
func _apply_bus(name: String, level: float) -> void:
	var index := AudioServer.get_bus_index(name)
	if index < 0:
		return
	if level <= 0.0:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(level))
```

- [ ] **Step 10: Run the whole suite**

Run: `bash tools/run_tests.sh`
Expected: green, with the parse sweep passing and the test count up by 15 (8 in `test_sound.gd`, 7 in `test_settings.gd`).

- [ ] **Step 11: Import pass and commit**

```bash
tools/bin/godot --headless --path game --import
git add game/default_bus_layout.tres game/project.godot game/systems/sound.gd \
  game/systems/sound.gd.uid game/systems/settings.gd \
  game/test/test_sound.gd game/test/test_sound.gd.uid game/test/test_settings.gd
git commit -m "$(cat <<'MSG'
feat: four buses, a Sound autoload and two more volume sliders

The gateway, with an empty library: pools, the private generator, the bed
crossfade machinery and the phase and zone bookkeeping. Nothing plays yet
because nothing is in LIBRARY; the content tasks fill it.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
MSG
)"
```

---

## Task 2: The manifest, the fetch script, and two probe rows proved end to end

**Files:**
- Create: `tools/sound_manifest.txt`
- Create: `tools/fetch_sounds.sh`
- Create: `game/assets/audio/sound_report.txt` (generated)
- Create: `game/assets/audio/world/gate_open.wav`, `game/assets/audio/ui/ui_move.wav` (generated)
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `tools/sound_manifest.txt`, rows of `dest|source_url|recipe` where `dest` is relative to `game/assets/audio/`.
  - `tools/fetch_sounds.sh`, idempotent, `--only`, `--force`, `--dry-run`, `--manifest FILE`.
  - `game/assets/audio/sound_report.txt`, one row per dest: `PASS|FAIL  <dest>  dur=<s>  I=<LUFS>  TP=<dBTP>  target=<LUFS>`.
  - The recipe verb set every later manifest row is written in: `rate=N`, `mono`, `trim=START-END`, `pick=N`, `speed=F`, `loop=SECONDS`, `fade=IN:OUT`, `gain=LUFS`, `gain_db=N`.

**Why two probe rows, and only two.** The pipeline has two source kinds: a direct BBC wav, and one member out of a Kenney zip. Proving one row of each before the content tasks pile forty three more on top is the difference between debugging a script and debugging a script under forty five failures. `world/gate_open.wav` and `ui/ui_move.wav` are real, kept rows; Task 4 and Task 5 note them as already present rather than adding them again.

- [ ] **Step 1: Ignore the download cache**

Append to `.gitignore`, under the `assets_raw/` group:

```
# Raw sound downloads. tools/fetch_sounds.sh caches every source file here and processes
# out of it; only the processed results under game/assets/audio/ are committed, exactly as
# assets_raw/ holds the raw models and game/assets/converted/ the converted ones.
tools/sound_cache/
```

- [ ] **Step 2: Write `tools/sound_manifest.txt` with the two probe rows**

```
# THE SOUND CURATION, AND IT LIVES HERE AND NOWHERE ELSE. tools/fetch_sounds.sh fetches and
# processes exactly what this file names, game/systems/sound.gd's LIBRARY plays exactly what
# it produces, and game/test/test_sound_library.gd asserts the two sets match with no orphan
# on either side. See docs/testing.md, section "The sound pipeline".
#
# ROW FORMAT: dest|source_url|recipe
#   dest        path under game/assets/audio/, e.g. world/gate_open.wav
#   source_url  a direct file URL, OR a zip URL with a #member fragment naming one file
#               inside it, e.g. https://.../kenney_interface-sounds.zip#Audio/click_002.ogg
#   recipe      comma separated verbs, applied in the script's own fixed order:
#                 rate=N        resample (default 44100)
#                 mono          downmix to one channel (default: keep stereo)
#                 trim=A-B      seconds, from A to B of the source
#                 pick=N        take the Nth non silent segment of the source (1 based).
#                               Use this rather than trim= whenever the wanted event is one
#                               strike inside a long take; it is reproducible and it does
#                               not drift when a source is re-downloaded.
#                 pick=N@G:D    the same, with the silence detector tuned for this row:
#                               G is the noise floor in dB (default -45) and D the minimum
#                               silence in seconds (default 0.12). A walking horse's
#                               hoofbeats are 0.4s apart with room tone between them and
#                               need something like pick=3@-38:0.05; a single dry creak in
#                               a quiet take is fine on the defaults.
#                 speed=F       tape speed change: pitch and duration together
#                 loop=S        seamless butt loop: take S seconds and crossfade the tail
#                               into the head. Beds only; implies an ogg dest.
#                 fade=IN:OUT   seconds of fade at each end
#                 gain=L        normalise to L LUFS integrated (the report checks it)
#                 gain_db=N     flat gain in dB instead of a loudness pass. The escape
#                               hatch for a one shot too short for EBU gating to measure
#                               honestly; a row using it is exempted from the LUFS check
#                               but never from the true peak ceiling.
#
# LOUDNESS TARGETS: ambient beds -24 LUFS, world and casino SFX -18, UI -20. True peak
# ceiling -1.5 dBTP everywhere, and a row over it FAILS the run.
#
# EVERY SLOT RECORDS ITS ALTERNATES in the comment above it, so the owner can swap a sound
# by editing one URL and re-running the script. That is the whole point of this file.
#
# SOURCES, all fetched with no account and no login:
#   BBC Sound Effects  https://sound-effects.bbcrewind.co.uk , media at
#                      https://sound-effects-media.bbcrewind.co.uk/wav/<ID>.wav
#   Kenney             https://kenney.nl , direct zips, CC0

# --- world ------------------------------------------------------------------------------

# gate_open: BBC 07037342, "Wooden Creak." 13.3s stereo 44.1k. One dry creak, no room, no
# voices. Alternates: 07037352 "Wooden Door Creak." 8.4s; 07037341 "Wooden Creak." 6.1s.
world/gate_open.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07037342.wav|rate=44100,mono,pick=1,fade=0.01:0.12,gain=-18

# --- ui ---------------------------------------------------------------------------------

# ui_move: Kenney Interface Sounds, click_002. A short woody tick, not a beep; the softest
# of the five clicks in the pack by file size and by envelope. Alternates: click_004.ogg;
# select_002.ogg.
ui/ui_move.wav|https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip#Audio/click_002.ogg|rate=44100,mono,fade=0.002:0.02,gain_db=0
```

- [ ] **Step 3: Write `tools/fetch_sounds.sh`**

```bash
#!/usr/bin/env bash
# Fetch and process every row of tools/sound_manifest.txt into game/assets/audio/, then
# regenerate game/assets/audio/sound_report.txt. This is tools/convert_props.sh's shape
# applied to audio: read that file first if anything here looks arbitrary.
#
# usage: tools/fetch_sounds.sh [--manifest FILE] [--only dest[,dest...]] [--force]
#                              [--dry-run]
#
# IDEMPOTENT. A dest that already exists is skipped unless --force or --only names it, so
# re-running after adding one row costs one download and one encode, not forty nine. The
# raw downloads live in tools/sound_cache/ (gitignored) and are never re-fetched.
#
# THE REPORT IS THE VERDICT. Every processed file is measured with ebur128 and written to
# the report as PASS or FAIL; a FAIL row makes the whole run exit non zero. Two things can
# fail a row: a true peak over the ceiling (the file clips), or an integrated loudness more
# than the tolerance away from the row's own gain= target. game/test/test_sound_library.gd
# asserts every LIBRARY file appears in that report with PASS, so a red row cannot be
# committed and forgotten.
#
# FILLY_FFMPEG and FILLY_FFPROBE override the binaries.
set -uo pipefail
cd "$(dirname "$0")/.."

MANIFEST="tools/sound_manifest.txt"
CACHE="tools/sound_cache"
OUT_ROOT="game/assets/audio"
REPORT="$OUT_ROOT/sound_report.txt"
FFMPEG="${FILLY_FFMPEG:-/usr/bin/ffmpeg}"
FFPROBE="${FILLY_FFPROBE:-/usr/bin/ffprobe}"
# kenney.nl's page serving is fine with curl, but a browser agent costs nothing and this
# script is the only thing in the project that talks to it.
UA="Mozilla/5.0 (X11; Linux x86_64)"
# True peak ceiling, dBTP. A row over this clips and fails.
PEAK_CEILING="-1.5"
# How far an integrated loudness may sit from its target before the row fails, in LU.
LUFS_TOLERANCE="2.0"

ONLY=""
FORCE=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

for bin in "$FFMPEG" "$FFPROBE" curl unzip; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: '$bin' not found on PATH." >&2
    exit 1
  fi
done
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: manifest '$MANIFEST' not found." >&2
  exit 1
fi

mkdir -p "$CACHE"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

wanted_row() {
  # $1 dest. Empty --only means every row.
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

# --- source acquisition -------------------------------------------------------------------
#
# Two kinds of source. A plain URL is curled into the cache under its own basename. A URL
# with a #fragment is a zip plus the member wanted out of it: the zip is curled once, and
# the member is extracted into the cache under a name derived from both, so two rows taking
# two members of one zip share the single download.
fetch_source() {
  # $1 source_url. Prints the cached file path on stdout, or nothing on failure.
  local url="$1" zip_url member zip_path out
  case "$url" in
    *"#"*)
      zip_url="${url%%#*}"
      member="${url#*#}"
      zip_path="$CACHE/$(basename "$zip_url")"
      out="$CACHE/$(basename "$zip_url" .zip)__$(basename "$member")"
      if [ ! -s "$zip_path" ]; then
        curl -sSL -A "$UA" -o "$zip_path" "$zip_url" || return 1
      fi
      if [ ! -s "$out" ]; then
        unzip -p "$zip_path" "$member" > "$out" 2>/dev/null || return 1
        [ -s "$out" ] || return 1
      fi
      ;;
    *)
      out="$CACHE/$(basename "$url")"
      if [ ! -s "$out" ]; then
        curl -sSL -A "$UA" -o "$out" "$url" || return 1
      fi
      ;;
  esac
  [ -s "$out" ] || return 1
  printf '%s' "$out"
}

# --- the pick verb --------------------------------------------------------------------------
#
# "The Nth non silent segment". silencedetect prints a silence_end for the start of every
# non silent run and a silence_start for its end; walking those pairs gives a segment list
# that is a function of the audio and of nothing else, which is why this exists instead of
# hand typed trim windows that drift the moment a source is re-downloaded.
pick_window() {
  # $1 file, $2 index (1 based), $3 noise floor dB, $4 minimum silence seconds.
  # Prints "START END" or nothing.
  local file="$1" want="$2" noise="${3:--45}" dur="${4:-0.12}"
  "$FFMPEG" -nostats -hide_banner -i "$file" \
    -af "silencedetect=noise=${noise}dB:d=$dur" -f null - 2>&1 \
  | awk -v want="$want" '
      /silence_end/ { for (i = 1; i <= NF; i++) if ($i == "silence_end:") start = $(i + 1) + 0 ; have = 1 }
      /silence_start/ {
        if (have) {
          for (i = 1; i <= NF; i++) if ($i == "silence_start:") stop = $(i + 1) + 0
          n += 1
          if (n == want) { printf "%.3f %.3f\n", start, stop ; exit }
          have = 0
        }
      }
    '
}

# --- one row ---------------------------------------------------------------------------------
process_row() {
  # $1 dest, $2 source_url, $3 recipe. Echoes one report line. Returns 1 on failure.
  local dest="$1" url="$2" recipe="$3"
  local out="$OUT_ROOT/$dest"
  local src work ext filters rate="44100" chans="2"
  local trim="" pick="" speed="" loopsec="" fadein="" fadeout="" target="" gaindb=""

  local verb
  IFS=',' read -ra verbs <<< "$recipe"
  for verb in "${verbs[@]}"; do
    case "$verb" in
      rate=*)    rate="${verb#rate=}" ;;
      mono)      chans="1" ;;
      trim=*)    trim="${verb#trim=}" ;;
      pick=*)    pick="${verb#pick=}" ;;
      speed=*)   speed="${verb#speed=}" ;;
      loop=*)    loopsec="${verb#loop=}" ;;
      fade=*)    fadein="${verb#fade=}"; fadeout="${fadein#*:}"; fadein="${fadein%%:*}" ;;
      gain=*)    target="${verb#gain=}" ;;
      gain_db=*) gaindb="${verb#gain_db=}" ;;
      "")        ;;
      *) echo "  unknown recipe verb '$verb' in row '$dest'" >&2; return 1 ;;
    esac
  done

  src="$(fetch_source "$url")" || { echo "  download failed: $url" >&2; return 1; }
  [ -n "$src" ] || { echo "  download failed: $url" >&2; return 1; }

  mkdir -p "$(dirname "$out")"
  work="$tmp_root/$(basename "$dest").wav"

  # STAGE 1: cut. pick= wins over trim= when both are given, because pick= is the measured
  # answer and trim= is the guess somebody wrote down.
  local cut_args=()
  if [ -n "$pick" ]; then
    local window start stop pick_n pick_noise pick_dur pick_tune
    pick_n="${pick%%@*}"
    pick_noise="-45"; pick_dur="0.12"
    case "$pick" in
      *"@"*)
        pick_tune="${pick#*@}"
        pick_noise="${pick_tune%%:*}"
        pick_dur="${pick_tune#*:}"
        ;;
    esac
    window="$(pick_window "$src" "$pick_n" "$pick_noise" "$pick_dur")"
    if [ -z "$window" ]; then
      echo "  pick=$pick found no such segment in $src" >&2
      return 1
    fi
    start="${window%% *}"; stop="${window##* }"
    cut_args=(-ss "$start" -to "$stop")
  elif [ -n "$trim" ]; then
    cut_args=(-ss "${trim%%-*}" -to "${trim##*-}")
  fi

  # STAGE 2: the filter chain, in a fixed order so a row's meaning never depends on the
  # order somebody happened to type the verbs in.
  filters="aresample=$rate"
  [ "$chans" = "1" ] && filters="$filters,pan=mono|c0=0.5*c0+0.5*c1"
  if [ -n "$speed" ]; then
    filters="$filters,asetrate=$(awk -v r="$rate" -v s="$speed" 'BEGIN{printf "%d", r*s}'),aresample=$rate"
  fi

  if [ -n "$loopsec" ]; then
    # A SEAMLESS BUTT LOOP. Take loopsec plus one second of overlap, split it, and
    # acrossfade the overlap tail into the head: the file's last second and its first are
    # then the same material, so playing it end to start has no seam. Godot loops the ogg
    # on its own with loop=true in the .import sidecar; this is only about the join.
    local total overlap
    overlap="1.0"
    total="$(awk -v a="$loopsec" -v b="$overlap" 'BEGIN{printf "%.3f", a+b}')"
    "$FFMPEG" -y -nostats -hide_banner "${cut_args[@]}" -i "$src" -t "$total" \
      -filter_complex \
        "[0:a]$filters,asplit=2[a][b];[a]atrim=0:$loopsec[head];[b]atrim=$loopsec,asetpts=PTS-STARTPTS[tail];[head][tail]acrossfade=d=$overlap:c1=tri:c2=tri[out]" \
      -map "[out]" -c:a pcm_s16le "$work" >/dev/null 2>&1 || {
        echo "  ffmpeg loop stage failed for $dest" >&2; return 1; }
  else
    [ -n "$fadein" ] && filters="$filters,afade=t=in:st=0:d=$fadein"
    "$FFMPEG" -y -nostats -hide_banner "${cut_args[@]}" -i "$src" \
      -af "$filters" -c:a pcm_s16le "$work" >/dev/null 2>&1 || {
        echo "  ffmpeg cut stage failed for $dest" >&2; return 1; }
    if [ -n "$fadeout" ]; then
      local dur faded
      dur="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$work")"
      faded="$tmp_root/faded_$(basename "$dest").wav"
      "$FFMPEG" -y -nostats -hide_banner -i "$work" \
        -af "afade=t=out:st=$(awk -v d="$dur" -v f="$fadeout" 'BEGIN{printf "%.3f", (d-f > 0 ? d-f : 0)}'):d=$fadeout" \
        -c:a pcm_s16le "$faded" >/dev/null 2>&1 || {
          echo "  ffmpeg fade stage failed for $dest" >&2; return 1; }
      mv "$faded" "$work"
    fi
  fi

  # STAGE 3: level. A loudness target gets a loudnorm pass; gain_db= gets a flat gain,
  # for a one shot too short for EBU gating to measure honestly.
  local levelled="$tmp_root/level_$(basename "$dest").wav"
  if [ -n "$target" ]; then
    "$FFMPEG" -y -nostats -hide_banner -i "$work" \
      -af "loudnorm=I=$target:TP=-2.0:LRA=11:dual_mono=true" \
      -ar "$rate" -c:a pcm_s16le "$levelled" >/dev/null 2>&1 || {
        echo "  loudnorm failed for $dest" >&2; return 1; }
  else
    "$FFMPEG" -y -nostats -hide_banner -i "$work" \
      -af "volume=${gaindb:-0}dB,alimiter=limit=0.84" \
      -ar "$rate" -c:a pcm_s16le "$levelled" >/dev/null 2>&1 || {
        echo "  gain stage failed for $dest" >&2; return 1; }
  fi

  # STAGE 4: encode to whatever the dest's extension asks for.
  ext="${dest##*.}"
  if [ "$ext" = "ogg" ]; then
    "$FFMPEG" -y -nostats -hide_banner -i "$levelled" -c:a libvorbis -q:a 5 "$out" \
      >/dev/null 2>&1 || { echo "  ogg encode failed for $dest" >&2; return 1; }
  else
    "$FFMPEG" -y -nostats -hide_banner -i "$levelled" -c:a pcm_s16le "$out" \
      >/dev/null 2>&1 || { echo "  wav encode failed for $dest" >&2; return 1; }
  fi

  measure_row "$dest" "$out" "${target:-none}"
}

# --- measurement -------------------------------------------------------------------------
measure_row() {
  # $1 dest, $2 file, $3 target LUFS or "none". Echoes the report line; returns 1 on FAIL.
  local dest="$1" file="$2" target="$3" summary integrated peak dur verdict
  dur="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$file")"
  summary="$("$FFMPEG" -nostats -hide_banner -i "$file" -filter_complex ebur128=peak=true \
    -f null - 2>&1 | tail -40)"
  integrated="$(printf '%s' "$summary" | grep -A1 'Integrated loudness' | grep -oE 'I: *-?[0-9.]+' | grep -oE '\-?[0-9.]+$' | tail -1)"
  peak="$(printf '%s' "$summary" | grep -A1 'True peak' | grep -oE 'Peak: *-?[0-9.]+' | grep -oE '\-?[0-9.]+$' | tail -1)"
  integrated="${integrated:-0}"
  peak="${peak:-0}"
  verdict="PASS"
  if awk -v p="$peak" -v c="$PEAK_CEILING" 'BEGIN{exit !(p > c)}'; then
    verdict="FAIL"
  fi
  if [ "$target" != "none" ]; then
    if awk -v i="$integrated" -v t="$target" -v tol="$LUFS_TOLERANCE" \
        'BEGIN{d = i - t; if (d < 0) d = -d; exit !(d > tol)}'; then
      verdict="FAIL"
    fi
  fi
  printf '%-4s  %-34s  dur=%-8.2f  I=%-8s  TP=%-7s  target=%s\n' \
    "$verdict" "$dest" "$dur" "$integrated" "$peak" "$target"
  [ "$verdict" = "PASS" ]
}

# --- the run -------------------------------------------------------------------------------
rows=0; made=0; skipped=0; failed=0
report_lines=""

while IFS= read -r line; do
  case "$line" in ""|"#"*) continue ;; esac
  dest="${line%%|*}"
  rest="${line#*|}"
  url="${rest%%|*}"
  recipe="${rest#*|}"
  rows=$((rows + 1))
  wanted_row "$dest" || continue
  if [ "$DRY" = "1" ]; then
    echo "would process: $dest  <- $url  [$recipe]"
    continue
  fi
  if [ -s "$OUT_ROOT/$dest" ] && [ "$FORCE" = "0" ] && [ -z "$ONLY" ]; then
    skipped=$((skipped + 1))
    line_out="$(measure_row "$dest" "$OUT_ROOT/$dest" \
      "$(printf '%s' "$recipe" | grep -oE 'gain=-?[0-9.]+' | cut -d= -f2 || true)")"
    measured=$?
    report_lines="$report_lines$line_out"$'\n'
    [ "$measured" -ne 0 ] && failed=$((failed + 1))
    continue
  fi
  echo "processing: $dest"
  if line_out="$(process_row "$dest" "$url" "$recipe")"; then
    made=$((made + 1))
  else
    failed=$((failed + 1))
    line_out="${line_out:-FAIL  $dest  (processing error, see above)}"
  fi
  report_lines="$report_lines$line_out"$'\n'
done < "$MANIFEST"

if [ "$DRY" = "1" ]; then
  echo "dry run: $rows row(s) in $MANIFEST"
  exit 0
fi

{
  echo "# Regenerated by tools/fetch_sounds.sh. Do not hand edit."
  echo "# Loudness targets: ambient beds -24 LUFS, world and casino SFX -18, UI -20."
  echo "# True peak ceiling $PEAK_CEILING dBTP; LUFS tolerance $LUFS_TOLERANCE LU."
  echo "# A row reading FAIL fails the run, and game/test/test_sound_library.gd fails too."
  printf '%s' "$report_lines" | sort -k2
} > "$REPORT"

echo "sounds: $made processed, $skipped already present, $failed failed, of $rows row(s)."
[ "$failed" -eq 0 ]
```

- [ ] **Step 4: Make it executable and run the two probe rows**

```bash
chmod +x tools/fetch_sounds.sh
bash tools/fetch_sounds.sh
```

Expected: two `processing:` lines, then `sounds: 2 processed, 0 already present, 0 failed, of 2 row(s).` and exit 0.

- [ ] **Step 5: Read the report and the files**

```bash
cat game/assets/audio/sound_report.txt
/usr/bin/ffprobe -v error -show_entries format=duration,size -of default=nw=1 game/assets/audio/world/gate_open.wav
/usr/bin/ffprobe -v error -show_entries format=duration,size -of default=nw=1 game/assets/audio/ui/ui_move.wav
```

Expected: both rows `PASS`. `world/gate_open.wav` should be roughly 0.5 s to 2 s (one creak, not the whole thirteen second take) and its `I=` within 2 LU of -18. `ui/ui_move.wav` should be under 0.2 s. If `gate_open.wav` came out the full length, `pick=` found no silence at the -45 dB threshold: raise the threshold in `pick_window` (it is one number in one place) rather than replacing `pick=` with a hand typed `trim=`.

- [ ] **Step 6: Prove the failure path is real**

The report is only worth anything if a bad row actually fails. Force one:

```bash
sed -i 's|gain=-18$|gain=-3|' tools/sound_manifest.txt
bash tools/fetch_sounds.sh --only world/gate_open.wav; echo "expected non zero: $?"
grep gate_open game/assets/audio/sound_report.txt
```

Expected: a non zero exit, and the `gate_open` row reading `FAIL` (a -3 LUFS target cannot be met under a -1.5 dBTP ceiling). Then put it back and re-run:

```bash
sed -i 's|gain=-3$|gain=-18|' tools/sound_manifest.txt
bash tools/fetch_sounds.sh --force; echo "expected 0: $?"
```

- [ ] **Step 7: Prove it is idempotent**

```bash
bash tools/fetch_sounds.sh
```

Expected: `sounds: 0 processed, 2 already present, 0 failed, of 2 row(s).` and exit 0. Nothing re-downloaded, nothing re-encoded, and the report still written.

- [ ] **Step 8: Import pass, and check the sidecars appeared**

```bash
tools/bin/godot --headless --path game --import
ls game/assets/audio/world/gate_open.wav.import game/assets/audio/ui/ui_move.wav.import
```

Expected: both `.import` files exist. Open `game/assets/audio/world/gate_open.wav.import` and confirm it contains `loop=false`. A wav's importer defaults to `loop=false` in Godot 4.5; if it does not, set it there and note it, because Task 3's ogg beds set `loop=true` in exactly the same way and the gate asserts both.

- [ ] **Step 9: Run the suite**

Run: `bash tools/run_tests.sh`
Expected: green and unchanged in count. Nothing in this task is loaded by any script yet.

- [ ] **Step 10: Commit**

```bash
git add .gitignore tools/sound_manifest.txt tools/fetch_sounds.sh \
  game/assets/audio/sound_report.txt \
  game/assets/audio/world/gate_open.wav game/assets/audio/world/gate_open.wav.import \
  game/assets/audio/ui/ui_move.wav game/assets/audio/ui/ui_move.wav.import
git commit -m "$(cat <<'MSG'
feat: the sound pipeline, and two rows proved through it

A manifest that is the curation, a script that is the only thing that
downloads, and a report that is the measured verdict. One BBC row and one
Kenney zip member row, so both source kinds are proved before the content
tasks add forty three more.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
MSG
)"
```

---

## Task 3: The ambient beds, and the corpus test that holds the whole library honest

**Files:**
- Modify: `tools/sound_manifest.txt` (nine bed rows)
- Modify: `game/systems/sound.gd` (`LIBRARY`, `BEDS`, `ZONE_BEDS`)
- Create: `game/test/test_sound_library.gd`
- Create: `game/assets/audio/ambient/*.ogg` and their `.import` sidecars (generated)

**Interfaces:**
- Consumes: `Sound.LIBRARY`, `Sound.BEDS`, `Sound.ZONE_BEDS`, `Sound.BUS_AMBIENT`, `Sound.ZONE_STRIP`, `Sound.ZONE_CASINO` from Task 1; `tools/fetch_sounds.sh` and the recipe verbs from Task 2.
- Produces: nine bed ids (`bed_dawn_chorus`, `bed_day_meadow`, `bed_dusk_calm`, `bed_night_insects`, `bed_night_owl`, `bed_wind_soft`, `bed_strip_hum`, `bed_strip_crowd`, `bed_casino_room`), the two probe ids promoted into `LIBRARY` (`gate_open`, `ui_move`), a filled `BEDS` keyed by `WorldState.Phase`, a filled `ZONE_BEDS`, and `game/test/test_sound_library.gd` with the rules every later entry must satisfy.

**The pinned sources.** Every id below was chosen by querying the BBC search API on 2026-09-04 and reading metadata: description, duration, channel count and sample rate. All are 44.1 kHz 16 bit stereo unless noted. Every download URL was confirmed to return HTTP 200. The owner swaps any of them by editing one URL in the manifest and running `bash tools/fetch_sounds.sh --only <dest>`.

| Bed id | Primary | Description | Length | Alternates |
|---|---|---|---|---|
| `bed_dawn_chorus` | `NHU05104268` | "Song thrush, blackbird, wren, carrion crow, distant rooster, hedge sparrow, wood pigeon, robin, rooks. recorded at height of chorus." | 362.4 s | `NHU05104269` (367.9 s, adds a tawny owl at the edge of it); `NHU05104271` (109.5 s) |
| `bed_day_meadow` | `07013003` | "Countryside atmosphere in summer with birdsong." | 892.8 s | `07059030` (274.3 s, "Countryside in summer, use at low level"); `0009033` (29.6 s, "countryside, summer skylarks") |
| `bed_dusk_calm` | `07030055` | "Countryside: Dusk Atmosphere, March, (For use at low level)." | 390.3 s | `07030062` (211.4 s, "Autumn, Atmosphere: Blackbirds, evening calls"); `07052037` (195.9 s, Spain countryside with birdsong) |
| `bed_night_insects` | `NHU05035029` | "Night. Many crickets and other insects." | 259.0 s | `NHU05068084` (126.0 s, tree crickets and wind in trees); `NHU05079182` (240.1 s, crickets and frogs) |
| `bed_night_owl` | `NHU05053051` | "Adult sleeping, with occasional Tawny Owl calls." Sparse, which is what a distant owl layer needs. | 132.1 s | `NHU05074178` (100.3 s, "Chorus with very distant tawny owl"); `NHU05053052` (327.0 s, rooks and occasional tawny owl) |
| `bed_wind_soft` | `07027032` | "Weather: Wind in trees." | 380.5 s | `07005205` (356.0 s, "Wind in trees"); `07061034` (243.0 s, "Soft sea breeze, light, wispy gentle wind") |
| `bed_strip_hum` | `07059070` | "Strip lighting hum." Literally lamp hum, for a strip lit by ten lamps. | 96.4 s | `07004188` (134.4 s, "A varying electrical hum"); `07027236` (295.3 s, refrigerator hum, for use at low level) |
| `bed_strip_crowd` | `07072151` | "General fairground atmosphere, Nov 1980, recorded Battersea Funfair." | 192.0 s | `07072168` (288.6 s, roundabouts with fairground atmosphere); `07031045` (364.1 s, "Outdoor Crowd: Fete, children and adults, distant birdsong") |
| `bed_casino_room` | `07044043` | "Amusement Arcade atmosphere, with electronic games, fruit machines and musical jingles." | 246.4 s | `07025131` (422.1 s, "Atmosphere: Amusement arcade"); `07062096` (305.6 s, arcade atmosphere 1985) |

- [ ] **Step 1: Append the nine bed rows to `tools/sound_manifest.txt`**

Put them under a new banner, above the existing `# --- world ---` banner:

```
# --- ambient beds -----------------------------------------------------------------------
#
# Every bed is a 45 second seamless loop at -24 LUFS, except the strip hum, which is 30
# (a hum has nothing in it that a longer window would reveal). loop= crossfades the tail
# into the head so the file butt loops with no seam; Godot loops it with loop=true in the
# committed .import sidecar. The trim window is one second longer than the loop, which is
# the overlap the crossfade eats.
#
# THE WINDOWS ARE INTO THE MIDDLE OF EACH TAKE, never the first seconds: BBC recordings
# routinely open with a slate, a level check or a recordist walking away from the mic.

# bed_dawn_chorus: BBC NHU05104268, "Song thrush, blackbird, wren, carrion crow, distant
# rooster, hedge sparrow, wood pigeon, robin, rooks. recorded at height of chorus." 362.4s.
# Alternates: NHU05104269 (367.9s, a tawny owl at the edge of it); NHU05104271 (109.5s).
ambient/bed_dawn_chorus.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/NHU05104268.wav|rate=44100,trim=60-106,loop=45,gain=-24

# bed_day_meadow: BBC 07013003, "Countryside atmosphere in summer with birdsong." 892.8s.
# Alternates: 07059030 (274.3s, use at low level); 0009033 (29.6s, summer skylarks).
ambient/bed_day_meadow.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/07013003.wav|rate=44100,trim=200-246,loop=45,gain=-24

# bed_dusk_calm: BBC 07030055, "Countryside: Dusk Atmosphere, March, (For use at low
# level)." 390.3s. Alternates: 07030062 (211.4s, blackbirds, evening calls); 07052037
# (195.9s, Spain countryside with birdsong).
ambient/bed_dusk_calm.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/07030055.wav|rate=44100,trim=120-166,loop=45,gain=-24

# bed_night_insects: BBC NHU05035029, "Night. Many crickets and other insects." 259.0s.
# Alternates: NHU05068084 (126.0s, tree crickets and wind in trees); NHU05079182 (240.1s,
# crickets and frogs).
ambient/bed_night_insects.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/NHU05035029.wav|rate=44100,trim=80-126,loop=45,gain=-24

# bed_night_owl: BBC NHU05053051, "Adult sleeping, with occasional Tawny Owl calls." 132.1s.
# Sparse on purpose; this layer is meant to be noticed twice a night, not held.
# Alternates: NHU05074178 (100.3s, chorus with very distant tawny owl); NHU05053052 (327.0s,
# rooks and occasional tawny owl).
ambient/bed_night_owl.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/NHU05053051.wav|rate=44100,trim=20-66,loop=45,gain=-30

# bed_wind_soft: BBC 07027032, "Weather: Wind in trees." 380.5s. The constant floor under
# every phase; the BEDS table sets how far under. Alternates: 07005205 (356.0s, wind in
# trees); 07061034 (243.0s, soft sea breeze, light, wispy gentle wind).
ambient/bed_wind_soft.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/07027032.wav|rate=44100,trim=100-146,loop=45,gain=-24

# bed_strip_hum: BBC 07059070, "Strip lighting hum." 96.4s. Alternates: 07004188 (134.4s,
# a varying electrical hum); 07027236 (295.3s, refrigerator hum, for use at low level).
ambient/bed_strip_hum.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/07059070.wav|rate=44100,trim=20-51,loop=30,gain=-24

# bed_strip_crowd: BBC 07072151, "General fairground atmosphere, Nov 1980, recorded
# Battersea Funfair." 192.0s. Alternates: 07072168 (288.6s, roundabouts with fairground
# atmosphere); 07031045 (364.1s, fete crowd with distant birdsong).
ambient/bed_strip_crowd.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/07072151.wav|rate=44100,trim=60-106,loop=45,gain=-24

# bed_casino_room: BBC 07044043, "Amusement Arcade atmosphere, with electronic games, fruit
# machines and musical jingles." 246.4s. Alternates: 07025131 (422.1s, amusement arcade);
# 07062096 (305.6s, arcade atmosphere 1985).
ambient/bed_casino_room.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/07044043.wav|rate=44100,trim=60-106,loop=45,gain=-24
```

- [ ] **Step 2: Fetch them**

```bash
bash tools/fetch_sounds.sh
cat game/assets/audio/sound_report.txt
```

Expected: nine `processing:` lines, `sounds: 9 processed, 2 already present, 0 failed, of 11 row(s).`, exit 0, and every report row `PASS`. Roughly 400 MB of source wav lands in `tools/sound_cache/` (it is gitignored) and about 5 MB of ogg lands under `game/assets/audio/ambient/`.

If a row FAILs on loudness, the usual cause is a trim window that caught a silent passage, which drags the integrated measurement down. Move that row's window (the note above it lists the take's full length) and re-run `bash tools/fetch_sounds.sh --only <dest>`.

- [ ] **Step 3: Import, and set the ogg loop flags**

```bash
tools/bin/godot --headless --path game --import
grep -H loop game/assets/audio/ambient/*.ogg.import
```

Godot's Ogg Vorbis importer writes `loop=false` by default. Every one of these nine must read `loop=true`, because `Sound` plays a bed once and expects the stream itself to repeat. Edit each `.import` file's `[params]` block so it reads:

```
loop=true
loop_offset=0
```

Then re-run the import pass and confirm the flags stuck:

```bash
tools/bin/godot --headless --path game --import
grep -H "^loop=" game/assets/audio/ambient/*.ogg.import
```

Expected: nine `loop=true` lines. This is what the gate in Task 9 asserts through `AudioStreamOggVorbis.loop`.

- [ ] **Step 4: Fill `LIBRARY`, `BEDS` and `ZONE_BEDS` in `game/systems/sound.gd`**

Replace `const LIBRARY: Dictionary = {}` with the entries below. The two probe files from Task 2 are promoted here so the manifest and the library match with no orphan on either side, which is what the corpus test in Step 5 asserts.

```gdscript
const LIBRARY: Dictionary = {
	# --- ambient beds ---
	&"bed_dawn_chorus": {
		"paths": PackedStringArray(["res://assets/audio/ambient/bed_dawn_chorus.ogg"]),
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_day_meadow": {
		"paths": PackedStringArray(["res://assets/audio/ambient/bed_day_meadow.ogg"]),
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_dusk_calm": {
		"paths": PackedStringArray(["res://assets/audio/ambient/bed_dusk_calm.ogg"]),
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_night_insects": {
		"paths": PackedStringArray(["res://assets/audio/ambient/bed_night_insects.ogg"]),
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_night_owl": {
		"paths": PackedStringArray(["res://assets/audio/ambient/bed_night_owl.ogg"]),
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_wind_soft": {
		"paths": PackedStringArray(["res://assets/audio/ambient/bed_wind_soft.ogg"]),
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_strip_hum": {
		"paths": PackedStringArray(["res://assets/audio/ambient/bed_strip_hum.ogg"]),
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_strip_crowd": {
		"paths": PackedStringArray(["res://assets/audio/ambient/bed_strip_crowd.ogg"]),
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_casino_room": {
		"paths": PackedStringArray(["res://assets/audio/ambient/bed_casino_room.ogg"]),
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	# --- world ---
	&"gate_open": {
		"paths": PackedStringArray(["res://assets/audio/world/gate_open.wav"]),
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.94, "pitch_max": 1.06, "loop": false},
	# --- ui ---
	&"ui_move": {
		"paths": PackedStringArray(["res://assets/audio/ui/ui_move.wav"]),
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 0.97, "pitch_max": 1.03, "loop": false},
}
```

Replace `const BEDS: Dictionary = {}` and `const ZONE_BEDS: Dictionary = {}`:

```gdscript
## WorldState.Phase int to the beds that phase runs. The ints are written out rather than
## read off WorldState.Phase because a const initialiser cannot preload a script; the
## corpus test asserts these four keys are exactly WorldState's four phases, so the two
## cannot drift apart in silence.
const BEDS: Dictionary = {
	0: [  # DAWN
		{"id": &"bed_dawn_chorus", "volume_db": 0.0},
		{"id": &"bed_wind_soft", "volume_db": -6.0},
	],
	1: [  # DAY
		{"id": &"bed_day_meadow", "volume_db": 0.0},
		{"id": &"bed_wind_soft", "volume_db": -8.0},
	],
	2: [  # DUSK
		{"id": &"bed_dusk_calm", "volume_db": 0.0},
		{"id": &"bed_wind_soft", "volume_db": -6.0},
	],
	3: [  # NIGHT
		{"id": &"bed_night_insects", "volume_db": 0.0},
		{"id": &"bed_night_owl", "volume_db": -4.0},
		{"id": &"bed_wind_soft", "volume_db": -4.0},
	],
}

## Zone StringName to the beds that zone overlays ON TOP of the phase's, never instead of
## them: the Strip is outdoors and the meadow is still out there behind the lamps. The
## worst case is NIGHT plus strip, which is five simultaneous beds against BED_VOICES of 10
## (the extra five are headroom for the outgoing set, which holds its voices while it fades).
const ZONE_BEDS: Dictionary = {
	ZONE_STRIP: [
		{"id": &"bed_strip_hum", "volume_db": -3.0},
		{"id": &"bed_strip_crowd", "volume_db": -8.0},
	],
	ZONE_CASINO: [
		{"id": &"bed_casino_room", "volume_db": -3.0},
	],
}
```

- [ ] **Step 5: Write the corpus test**

Create `game/test/test_sound_library.gd`. It is the rule book for every entry this slice adds; Tasks 4 and 5 add content and this file does not change again.

```gdscript
extends GutTest
## THE CORPUS TEST. Sound.LIBRARY, tools/sound_manifest.txt and
## game/assets/audio/sound_report.txt are three lists of the same set of files, maintained
## by three different hands, and this file is what keeps them one set. It never plays
## anything; it reads.
##
## THE ORPHAN RULE RUNS BOTH WAYS on purpose. A manifest row nobody plays is a file that
## was downloaded, committed and forgotten. A LIBRARY path with no manifest row is a file
## nobody can reproduce, which is the same as no file at all the first time somebody
## re-runs the pipeline on a clean checkout.

const SoundScript := preload("res://systems/sound.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

const AUDIO_ROOT := "res://assets/audio/"
const REPORT := "res://assets/audio/sound_report.txt"


## tools/ sits beside the Godot project root rather than inside it, so res:// cannot reach
## it; globalize and walk up one.
static func manifest_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../tools/sound_manifest.txt").simplify_path()


## dest path (relative to game/assets/audio/) for every non comment manifest row.
static func manifest_dests() -> PackedStringArray:
	var out := PackedStringArray()
	var file := FileAccess.open(manifest_path(), FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		out.append(line.split("|", true, 1)[0])
	return out


## Every path any LIBRARY entry names, once each.
static func library_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			if not out.has(path):
				out.append(path)
	return out


func test_the_library_is_not_empty() -> void:
	assert_gt(SoundScript.LIBRARY.size(), 0)


func test_every_id_follows_the_naming_scheme() -> void:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	for id: StringName in SoundScript.LIBRARY.keys():
		assert_not_null(pattern.search(String(id)), "id '%s' must be lower snake case" % id)


func test_every_entry_carries_the_whole_shape() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		for key: String in ["paths", "bus", "volume_db", "pitch_min", "pitch_max", "loop"]:
			assert_true(entry.has(key), "entry '%s' is missing '%s'" % [id, key])
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		assert_gt(paths.size(), 0, "entry '%s' names no file" % id)


func test_every_path_is_under_the_audio_root_and_exists_on_disk() -> void:
	for path: String in library_paths():
		assert_true(path.begins_with(AUDIO_ROOT), "'%s' is outside %s" % [path, AUDIO_ROOT])
		assert_true(FileAccess.file_exists(path), "'%s' is not on disk" % path)
		assert_true(FileAccess.file_exists(path + ".import"),
			"'%s' has no committed .import sidecar" % path)


func test_no_orphans_in_either_direction() -> void:
	var dests: PackedStringArray = manifest_dests()
	assert_gt(dests.size(), 0, "the manifest could not be read at %s" % manifest_path())
	var from_library: PackedStringArray = PackedStringArray()
	for path: String in library_paths():
		from_library.append(path.trim_prefix(AUDIO_ROOT))
	for dest: String in dests:
		assert_true(from_library.has(dest), "manifest row '%s' is played by nothing" % dest)
	for dest: String in from_library:
		assert_true(dests.has(dest), "LIBRARY path '%s' has no manifest row" % dest)


func test_variant_sets_are_contiguous_from_one() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		if paths.size() < 2:
			continue
		for index in paths.size():
			var stem: String = paths[index].get_file().get_basename()
			assert_eq(stem, "%s_%d" % [String(id), index + 1],
				"variant %d of '%s' must be named %s_%d" % [index + 1, id, id, index + 1])


func test_pitch_ranges_are_sane() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var low: float = float(entry.get("pitch_min", 1.0))
		var high: float = float(entry.get("pitch_max", 1.0))
		assert_gte(low, 0.5, "'%s' pitch_min is below 0.5" % id)
		assert_lte(high, 2.0, "'%s' pitch_max is above 2.0" % id)
		assert_lte(low, high, "'%s' has pitch_min above pitch_max" % id)


func test_every_bus_is_one_of_the_three() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var bus: StringName = StringName(entry.get("bus", &""))
		assert_true(bus == SoundScript.BUS_AMBIENT or bus == SoundScript.BUS_EFFECTS
			or bus == SoundScript.BUS_UI, "'%s' routes to '%s'" % [id, bus])


func test_the_directory_a_file_sits_in_decides_its_bus() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var bus: StringName = StringName(entry.get("bus", &""))
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			var folder: String = path.trim_prefix(AUDIO_ROOT).get_base_dir()
			match folder:
				"ambient": assert_eq(bus, SoundScript.BUS_AMBIENT, "'%s' is a bed" % id)
				"ui": assert_eq(bus, SoundScript.BUS_UI, "'%s' is a menu tick" % id)
				_: assert_eq(bus, SoundScript.BUS_EFFECTS, "'%s' is a world sound" % id)


func test_ogg_entries_loop_and_wav_entries_do_not() -> void:
	for id: StringName in SoundScript.LIBRARY.keys():
		var entry: Dictionary = SoundScript.LIBRARY[id]
		var wants_loop: bool = bool(entry.get("loop", false))
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			var is_ogg: bool = path.get_extension() == "ogg"
			assert_eq(wants_loop, is_ogg,
				"'%s': ogg means a loop and wav means a one shot, and '%s' disagrees"
					% [id, path])


func test_the_bed_tables_name_only_real_looping_ambient_entries() -> void:
	var tables: Array[Dictionary] = [SoundScript.BEDS, SoundScript.ZONE_BEDS]
	for table: Dictionary in tables:
		for key: Variant in table.keys():
			var rows: Array = table[key]
			assert_gt(rows.size(), 0, "bed table key '%s' is empty" % str(key))
			for row: Dictionary in rows:
				var id: StringName = StringName(row.get("id", &""))
				assert_true(SoundScript.LIBRARY.has(id), "bed '%s' is not in LIBRARY" % id)
				var entry: Dictionary = SoundScript.LIBRARY[id]
				assert_eq(StringName(entry.get("bus", &"")), SoundScript.BUS_AMBIENT)
				assert_true(bool(entry.get("loop", false)), "bed '%s' must loop" % id)
				assert_lte(float(row.get("volume_db", 0.0)), 0.0,
					"bed '%s' is mixed above its mastered level" % id)


func test_the_phase_table_covers_exactly_the_four_phases() -> void:
	assert_eq(SoundScript.BEDS.size(), 4)
	for phase: int in [WorldStateScript.Phase.DAWN, WorldStateScript.Phase.DAY,
			WorldStateScript.Phase.DUSK, WorldStateScript.Phase.NIGHT]:
		assert_true(SoundScript.BEDS.has(phase), "no beds for phase %d" % phase)


func test_the_zone_table_covers_exactly_the_two_zones() -> void:
	assert_eq(SoundScript.ZONE_BEDS.size(), 2)
	assert_true(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_STRIP))
	assert_true(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_CASINO))
	assert_false(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_NONE))


func test_no_phase_and_zone_pair_asks_for_more_beds_than_there_are_voices() -> void:
	for phase: Variant in SoundScript.BEDS.keys():
		var phase_rows: Array = SoundScript.BEDS[phase]
		for zone: Variant in SoundScript.ZONE_BEDS.keys():
			var ids: Dictionary = {}
			for row: Dictionary in phase_rows:
				ids[StringName(row.get("id", &""))] = true
			for row: Dictionary in SoundScript.ZONE_BEDS[zone]:
				ids[StringName(row.get("id", &""))] = true
			assert_lte(ids.size(), SoundScript.BED_VOICES,
				"phase %s in zone %s wants %d beds" % [str(phase), str(zone), ids.size()])


func test_every_library_file_passed_the_loudness_report() -> void:
	var file := FileAccess.open(REPORT, FileAccess.READ)
	assert_not_null(file, "no report at %s; run bash tools/fetch_sounds.sh" % REPORT)
	if file == null:
		return
	var passed: Dictionary = {}
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(" ", false)
		if fields.size() < 2:
			continue
		passed[fields[1]] = fields[0] == "PASS"
	for path: String in library_paths():
		var dest: String = path.trim_prefix(AUDIO_ROOT)
		assert_true(passed.has(dest), "'%s' is not in the loudness report" % dest)
		assert_true(bool(passed.get(dest, false)), "'%s' FAILED the loudness report" % dest)


func test_no_id_and_no_path_carries_a_dash_of_either_kind() -> void:
	# The house rule, checked on the one corpus a hand edit is most likely to slip into.
	for id: StringName in SoundScript.LIBRARY.keys():
		assert_false(String(id).contains("--"))
		assert_false(String(id).contains(char(0x2014)))
	for path: String in library_paths():
		assert_false(path.contains("--"))
		assert_false(path.contains(char(0x2014)))
```

- [ ] **Step 6: Run the corpus test**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_sound_library.gd -gexit`
Expected: PASS, 16 tests.

`test_no_orphans_in_either_direction` failing with "the manifest could not be read" means `manifest_path()` did not resolve; print it (`gut.p(manifest_path())`) and compare against `pwd`. Everything else failing names the offending id in its own message.

- [ ] **Step 7: Add a bed behaviour test**

Append to `game/test/test_sound.gd`:

```gdscript
func test_a_phase_brings_its_beds_up_and_takes_the_previous_ones_down() -> void:
	Sound.stop_all()
	Sound.ambient_set_phase(SoundScript.BEDS.keys()[0])
	var dawn: Array[StringName] = Sound.active_bed_ids()
	assert_true(dawn.has(&"bed_dawn_chorus"))
	assert_true(dawn.has(&"bed_wind_soft"))
	Sound.ambient_set_phase(3)
	var night: Array[StringName] = Sound.active_bed_ids()
	assert_true(night.has(&"bed_night_insects"))
	assert_false(night.has(&"bed_dawn_chorus"),
		"the dawn chorus must be released the moment night takes over")


func test_a_zone_overlays_the_phase_rather_than_replacing_it() -> void:
	Sound.stop_all()
	Sound.ambient_set_phase(1)
	Sound.ambient_set_zone(SoundScript.ZONE_STRIP)
	var beds: Array[StringName] = Sound.active_bed_ids()
	assert_true(beds.has(&"bed_day_meadow"), "the meadow is still out there behind the lamps")
	assert_true(beds.has(&"bed_strip_hum"))
	assert_true(beds.has(&"bed_strip_crowd"))
	Sound.ambient_set_zone(SoundScript.ZONE_NONE)
	beds = Sound.active_bed_ids()
	assert_true(beds.has(&"bed_day_meadow"))
	assert_false(beds.has(&"bed_strip_hum"))


func test_leaving_a_zone_never_disturbs_the_phase_beds() -> void:
	Sound.stop_all()
	Sound.ambient_set_phase(3)
	var before: Array[StringName] = Sound.active_bed_ids()
	Sound.ambient_set_zone(SoundScript.ZONE_CASINO)
	Sound.ambient_set_zone(SoundScript.ZONE_NONE)
	assert_eq(Sound.active_bed_ids(), before)
```

- [ ] **Step 8: Run the whole suite**

Run: `bash tools/run_tests.sh`
Expected: green, count up by 19 (16 new in `test_sound_library.gd`, 3 appended to `test_sound.gd`).

- [ ] **Step 9: Commit**

```bash
tools/bin/godot --headless --path game --import
git add tools/sound_manifest.txt game/systems/sound.gd \
  game/test/test_sound_library.gd game/test/test_sound_library.gd.uid game/test/test_sound.gd \
  game/assets/audio/ambient game/assets/audio/sound_report.txt
git commit -m "$(cat <<'MSG'
feat: nine ambient beds, and the corpus test that holds the library honest

Dawn chorus, summer meadow, dusk, crickets, a distant owl and wind in trees,
plus the Strip's lamp hum and fairground murmur and the Palace's arcade room.
All BBC recordings, all seamless 45 second loops at -24 LUFS. The corpus test
makes the manifest, the library and the loudness report one list.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
MSG
)"
```

---

## Task 4: The world SFX

**Files:**
- Modify: `tools/sound_manifest.txt` (fifteen rows)
- Modify: `game/systems/sound.gd` (`LIBRARY`, the world block)
- Create: `game/assets/audio/world/*.wav` and their `.import` sidecars (generated)

**Interfaces:**
- Consumes: the manifest format, `tools/fetch_sounds.sh`, `Sound.LIBRARY` and `Sound.BUS_EFFECTS` from Tasks 1 to 3; `game/test/test_sound_library.gd`'s rules, which do not change here.
- Produces nine new ids, all on `BUS_EFFECTS`: `mail_arrive`, `mail_open`, `mail_stamp`, `capture_charge`, `capture_success`, `hoofsteps_grass` (4 variants), `hoofsteps_hard` (4), `delivery_thud`, `coins_grant`. `gate_open` already exists from Task 2 and is not touched.

**THE PONY VOICE SLOTS ARE CUT, BY OWNER DIRECTIVE (2026-09-04).** Spec section 5.2's `pony_whinny_1..3` and `pony_snort_1..2` are removed from the spec and from this plan. The owner's words: "the mlp ponies dont make realistic horse noises." These are cartoon characters, not livestock, and a real mare's neigh over one of them breaks the register the whole slice is built to protect. No BBC id is pinned for either slot and no manifest row exists for them. The moments that would have carried a whinny carry the capture chime or nothing at all: a capture lands on `capture_success`, a delivery is `delivery_thud` alone, and a pony walked into a pen is `gate_open` alone. **HOOFSTEPS STAY, and the owner asked for them explicitly ("walking is the big one we do need"):** a hoof on turf is physical sound rather than vocalization, so a real recording is still the right answer there. Pony VOICE, if it ever happens, is a separate effort beside the parked placeholder voice line, not this slice.

**The pinned sources.** All BBC unless the row says Kenney. All were confirmed by metadata on 2026-09-04.

| Id | Primary | Description | Length | Alternates |
|---|---|---|---|---|
| `mail_arrive` | `07011078` | "Several newspapers pushed through letterbox." The only letterbox recording in the archive. | 17.0 s | `07045094` ("Tool box closed", 9.3 s, for the metal flag reading); `07037356` ("Metal Gate opened and closed", 6.8 s) |
| `mail_open` | `07045125` | "Sanding, paper folded then sheet of plywood." Carries an isolated paper fold. | 92.0 s | `07047018` (243.5 s, staff extracting and sorting newspaper cuttings); Kenney Interface `scratch_002.ogg` |
| `mail_stamp` | `07040153` | "Mail Sorting Office, letter stamping machine operating." Literally a letter being stamped. | 55.7 s | `07013135` ("Almex ticket machine, setting machine", 7.7 s); `07013132` (Gibson ticket machine, 16.0 s) |
| `capture_charge` | `07043314` | "Generator hum. (Futuristic Spot Effect.)" Sped up so it reads as magical rather than industrial. | 98.6 s | `07004188` ("A varying electrical hum", 134.4 s); `07024189` ("Electrical: Fan", 64.9 s) |
| `capture_success` | Kenney Interface `confirmation_001.ogg` | See the note under the table | | `confirmation_003.ogg`; `bong_001.ogg` |
| `hoofsteps_grass_1..4` | `07024157` and `07024158` | "Horse On Turf: Walking, Approach and stop." and "Horse On Turf: Walking, Depart." Two takes of the same horse on the same turf, so four strikes across them sit together. | 18.1 s, 12.9 s | `07039304` ("Troop of horses galloping on turf", 149.8 s) |
| `hoofsteps_hard_1..4` | `07039310` | "Horse walking on cobblestones." One horse, sixty seconds of even walking, which is four clean strikes and change. | 60.7 s | `07024164` ("Horse On Hard Road: Walking, Depart.", 23.0 s); `07039298` ("Horse walking on road.", 62.5 s) |
| `delivery_thud` | `07004235` | "Bucket dropped 3 times." Three separate impacts in one take; take the first. | 31.9 s | `07002071` ("Emptying hod of coal into grate", 12.8 s); `07045094` ("Tool box closed", 9.3 s) |
| `coins_grant` | `07005178` | "Cash register, bell, change given and coins put in drawer, closed." The coins are the second event. | 9.7 s | `07074208` (manual register, bell, change, drawer closed, 16.3 s); `07005180` (the same setup, twice through, 16.4 s) |

`capture_success` is the one world slot the spec explicitly allows a designed sound for ("soft chime and pop; Kenney jingle acceptable here"), because there is no real world recording of a pony being lifted into a bag by a horn. Primary: Kenney Interface Sounds `Audio/confirmation_001.ogg`. Alternates: `confirmation_003.ogg`, `bong_001.ogg`.

- [ ] **Step 1: Append the twenty rows to `tools/sound_manifest.txt`**

Put them under the existing `# --- world ---` banner, below the `gate_open` row.

```
# mail_arrive: BBC 07011078, "Several newspapers pushed through letterbox." 17.0s; the one
# letterbox recording in the archive. Alternates: 07045094 "Tool box closed" 9.3s (for the
# metal flag reading); 07037356 "Metal Gate opened & closed" 6.8s.
world/mail_arrive.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07011078.wav|rate=44100,mono,pick=2,fade=0.01:0.15,gain=-18

# mail_open: BBC 07045125, "Sanding, paper folded then sheet of plywood." 92.0s; the fold
# is an isolated event inside it. Alternates: 07047018 (243.5s, sorting newspaper cuttings);
# Kenney Interface scratch_002.ogg.
world/mail_open.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07045125.wav|rate=44100,mono,pick=2@-40:0.20,fade=0.01:0.18,gain=-18

# mail_stamp: BBC 07040153, "Mail Sorting Office, letter stamping machine operating." 55.7s.
# Alternates: 07013135 "Almex ticket machine, setting machine" 7.7s; 07013132 "Gibson ticket
# machine, setting machine" 16.0s.
world/mail_stamp.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07040153.wav|rate=44100,mono,pick=3@-38:0.08,fade=0.005:0.10,gain=-18

# capture_charge: BBC 07043314, "Generator hum. (Futuristic Spot Effect.)" 98.6s. speed=1.35
# lifts it a fifth and shortens it, which is what turns an industrial hum into something
# magical instead of ominous; the register note in the spec is explicit about that.
# Alternates: 07004188 "A varying electrical hum" 134.4s; 07024189 "Electrical: Fan" 64.9s.
world/capture_charge.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07043314.wav|rate=44100,mono,trim=20-21.6,speed=1.35,fade=0.06:0.30,gain=-18

# capture_success: Kenney Interface Sounds, confirmation_001. The one world slot the spec
# allows a designed sound for; there is no recording of a pony going into a bag.
# Alternates: confirmation_003.ogg; bong_001.ogg.
world/capture_success.wav|https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip#Audio/confirmation_001.ogg|rate=44100,mono,fade=0.002:0.05,gain_db=0

# NO PONY VOICE ROWS. Whinnies and snorts are cut by owner directive: these ponies are
# cartoon characters and a real mare's neigh over one of them breaks the register. Hooves
# stay, because a hoof on turf is physical sound rather than a voice.

# hoofsteps_grass_1..4: BBC 07024157 "Horse On Turf: Walking, Approach and stop." 18.1s and
# 07024158 "Horse On Turf: Walking, Depart." 12.9s. Two takes of the same horse on the same
# turf, so four strikes taken across them sit together. The detector is tuned down to -38dB
# and 0.05s because a walking horse leaves room tone between strikes, not silence.
# Alternate: 07039304 "Troop of horses galloping on turf" 149.8s.
world/hoofsteps_grass_1.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07024157.wav|rate=44100,mono,pick=3@-38:0.05,fade=0.003:0.09,gain=-18
world/hoofsteps_grass_2.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07024157.wav|rate=44100,mono,pick=5@-38:0.05,fade=0.003:0.09,gain=-18
world/hoofsteps_grass_3.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07024158.wav|rate=44100,mono,pick=2@-38:0.05,fade=0.003:0.09,gain=-18
world/hoofsteps_grass_4.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07024158.wav|rate=44100,mono,pick=4@-38:0.05,fade=0.003:0.09,gain=-18

# hoofsteps_hard_1..4: BBC 07039310, "Horse walking on cobblestones." 60.7s of one horse
# walking evenly. Alternates: 07024164 "Horse On Hard Road: Walking, Depart." 23.0s;
# 07039298 "Horse walking on road." 62.5s.
world/hoofsteps_hard_1.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07039310.wav|rate=44100,mono,pick=4@-38:0.05,fade=0.003:0.08,gain=-18
world/hoofsteps_hard_2.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07039310.wav|rate=44100,mono,pick=6@-38:0.05,fade=0.003:0.08,gain=-18
world/hoofsteps_hard_3.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07039310.wav|rate=44100,mono,pick=8@-38:0.05,fade=0.003:0.08,gain=-18
world/hoofsteps_hard_4.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07039310.wav|rate=44100,mono,pick=10@-38:0.05,fade=0.003:0.08,gain=-18

# delivery_thud: BBC 07004235, "Bucket dropped 3 times." 31.9s; take the first drop.
# Alternates: 07002071 "Emptying hod of coal into grate" 12.8s; 07045094 "Tool box closed"
# 9.3s.
world/delivery_thud.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07004235.wav|rate=44100,mono,pick=1,fade=0.003:0.20,gain=-18

# coins_grant: BBC 07005178, "Cash register, bell, change given and coins put in drawer,
# closed." 9.7s; the coins are the second event, after the bell. Alternates: 07074208
# (16.3s, manual register); 07005180 (16.4s, the same setup twice through).
world/coins_grant.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07005178.wav|rate=44100,mono,pick=2,fade=0.005:0.15,gain=-18
```

- [ ] **Step 2: Fetch, and check the durations are one shots and not whole takes**

```bash
bash tools/fetch_sounds.sh
for f in game/assets/audio/world/*.wav; do
  printf '%-46s %s\n' "$f" "$(/usr/bin/ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")"
done
```

Expected: exit 0, every report row `PASS`, and:
- every `hoofsteps_*` under 0.60 s (a single strike; anything over a second means `pick` swallowed several)
- `capture_charge` about 1.2 s (1.6 s of source at speed 1.35)
- `mail_arrive`, `mail_open`, `mail_stamp`, `delivery_thud`, `coins_grant` each between 0.2 s and 3.0 s

A row outside its band is a `pick` that grabbed the wrong segment. Walk it: `bash tools/fetch_sounds.sh --only world/<name>.wav` after changing the index, and if no index works, move to that row's first alternate URL. Both are one line edits and that is the point of the file.

- [ ] **Step 3: Add the nine entries to `LIBRARY`**

In `game/systems/sound.gd`, under the `# --- world ---` banner inside `LIBRARY`, beside the existing `gate_open` entry. The pitch ranges are the taste knob: a hoofstep varies most (it is the most repeated sound in the game and an unvarying one turns into a machine gun within ten seconds), a stinger not at all.

```gdscript
	&"mail_arrive": {
		"paths": PackedStringArray(["res://assets/audio/world/mail_arrive.wav"]),
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"mail_open": {
		"paths": PackedStringArray(["res://assets/audio/world/mail_open.wav"]),
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.97, "pitch_max": 1.03, "loop": false},
	&"mail_stamp": {
		"paths": PackedStringArray(["res://assets/audio/world/mail_stamp.wav"]),
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.96, "pitch_max": 1.04, "loop": false},
	&"capture_charge": {
		"paths": PackedStringArray(["res://assets/audio/world/capture_charge.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -3.0, "pitch_min": 0.98, "pitch_max": 1.06, "loop": false},
	&"capture_success": {
		"paths": PackedStringArray(["res://assets/audio/world/capture_success.wav"]),
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"hoofsteps_grass": {
		"paths": PackedStringArray([
			"res://assets/audio/world/hoofsteps_grass_1.wav",
			"res://assets/audio/world/hoofsteps_grass_2.wav",
			"res://assets/audio/world/hoofsteps_grass_3.wav",
			"res://assets/audio/world/hoofsteps_grass_4.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -8.0, "pitch_min": 0.90, "pitch_max": 1.12, "loop": false},
	&"hoofsteps_hard": {
		"paths": PackedStringArray([
			"res://assets/audio/world/hoofsteps_hard_1.wav",
			"res://assets/audio/world/hoofsteps_hard_2.wav",
			"res://assets/audio/world/hoofsteps_hard_3.wav",
			"res://assets/audio/world/hoofsteps_hard_4.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -8.0, "pitch_min": 0.90, "pitch_max": 1.12, "loop": false},
	&"delivery_thud": {
		"paths": PackedStringArray(["res://assets/audio/world/delivery_thud.wav"]),
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.94, "pitch_max": 1.06, "loop": false},
	&"coins_grant": {
		"paths": PackedStringArray(["res://assets/audio/world/coins_grant.wav"]),
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.97, "pitch_max": 1.05, "loop": false},
```

- [ ] **Step 4: Write the failing test for the world block**

Append to `game/test/test_sound.gd`:

```gdscript
func test_every_world_sound_plays_and_reports_that_it_did() -> void:
	for id: StringName in [&"mail_arrive", &"mail_open", &"mail_stamp", &"capture_charge",
			&"capture_success", &"hoofsteps_grass", &"hoofsteps_hard", &"gate_open",
			&"delivery_thud", &"coins_grant"]:
		assert_true(Sound.has_id(id), "'%s' is missing from LIBRARY" % id)
		assert_true(Sound.play_at(id, Vector3(1.0, 0.0, 2.0)), "'%s' would not play" % id)


func test_the_variant_sets_are_the_sizes_the_plan_asked_for() -> void:
	assert_eq(PackedStringArray(Sound.entry(&"hoofsteps_grass").get("paths")).size(), 4)
	assert_eq(PackedStringArray(Sound.entry(&"hoofsteps_hard").get("paths")).size(), 4)


func test_no_pony_voice_ever_entered_the_library() -> void:
	# Owner directive: these ponies are cartoon characters, not livestock. A realistic
	# whinny or snort would break the register the whole slice exists to protect.
	for id: StringName in Sound.ids():
		assert_false(String(id).contains("whinny"), "'%s' is a pony voice" % id)
		assert_false(String(id).contains("snort"), "'%s' is a pony voice" % id)
		assert_false(String(id).contains("neigh"), "'%s' is a pony voice" % id)


func test_hoofsteps_are_mixed_well_under_everything_else() -> void:
	# The most heard sound in the game. If it sits at the same level as a slots stinger the game
	# is exhausting inside a minute; the owner's knob for this is parked in the plan.
	for id: StringName in [&"hoofsteps_grass", &"hoofsteps_hard"]:
		assert_lte(float(Sound.entry(id).get("volume_db", 0.0)), -6.0)


func test_the_3d_pool_steals_its_oldest_voice_rather_than_growing() -> void:
	Sound.stop_all()
	for i in range(SoundScript.POOL_3D + 5):
		assert_true(Sound.play_at(&"hoofsteps_grass", Vector3(float(i), 0.0, 0.0)))
	assert_eq(Sound.pool_3d_size(), SoundScript.POOL_3D)


func test_the_2d_pool_steals_its_oldest_voice_rather_than_growing() -> void:
	Sound.stop_all()
	for i in range(SoundScript.POOL_2D + 5):
		assert_true(Sound.play(&"ui_move"))
	assert_eq(Sound.pool_2d_size(), SoundScript.POOL_2D)
```

- [ ] **Step 5: Import, then run the suite**

```bash
tools/bin/godot --headless --path game --import
grep -L "^loop=false" game/assets/audio/world/*.wav.import
bash tools/run_tests.sh
```

Expected: the `grep -L` prints nothing (every world wav imported with `loop=false`), and the suite is green with the count up by 6.

- [ ] **Step 6: Commit**

```bash
git add tools/sound_manifest.txt game/systems/sound.gd game/test/test_sound.gd \
  game/assets/audio/world game/assets/audio/sound_report.txt
git commit -m "$(cat <<'MSG'
feat: fifteen world sounds, from a letterbox to a hoof on cobbles

Mail, the beam, two surfaces of hoofstep, a crate set down and coins into a
drawer. All BBC recordings except the capture stinger, which the spec allows
to be designed because there is no recording of what it depicts. No pony
voice: whinnies and snorts are cut by owner directive because these ponies are
cartoon characters, not livestock.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
MSG
)"
```

### Task 4 AMENDMENT (owner directive 2026-09-04, added mid-build): the one sanctioned neigh

The owner, after cutting realistic pony vocalizations: "slipping in a single realistic horse neigh in a comedic point could be pretty funny." Exactly ONE realistic neigh enters the game, as a rare deadpan gag on capture. The joke works because the no-vocals rule holds everywhere else; nothing else may ever use this id.

- [ ] **Amendment step A: one more manifest row**

Append to `tools/sound_manifest.txt` in the world block:

```
# THE ONE SANCTIONED NEIGH. A rare gag on capture: the pastel pony emits one fully
# realistic mare neigh instead of the chime, and the game does not comment. Owner
# directive 2026-09-04. Alternates: NHU05083084 (mare answered by foal), NHU05078167
# (threatening neigh, 18.0 s).
world/neigh_real.wav|https://sound-effects-media.bbcrewind.co.uk/wav/NHU05084168.wav|pick=2@-38:0.10,rate=44100,fade=0.01:0.15,gain_db=-4
```

`NHU05084168` is "Snort and neigh of mare", 27.9 s: the snort is the first event, the neigh the second, so `pick=2` takes the neigh. If the segment picker lands wrong (a snort is quieter and may merge into room tone), fall back to a `trim=` window found by reading `ffprobe -f lavfi -i "amovie=<cache file>,astats=metadata=1:reset=1"` peaks, exactly as the Task 4 hoofstep walk-it procedure describes; the deliverable is one clean neigh of roughly 1.5 to 3.5 s. `gain_db` not `gain=` because the clip is too short for EBU gating; the peak ceiling still applies.

- [ ] **Amendment step B: the entry and the gag constants in `game/systems/sound.gd`**

Add `neigh_real` to the world block of `LIBRARY`, on `BUS_EFFECTS`, `pitch_min` and `pitch_max` both `1.0` (the joke is deadpan; a pitch-shifted neigh is a different, worse joke):

```gdscript
	&"neigh_real": {
		"paths": PackedStringArray(["res://assets/audio/world/neigh_real.wav"]),
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0,
		"loop": false,
	},
```

Below the pool constants add:

```gdscript
# --- the one sanctioned neigh -------------------------------------------------------------
#
# Exactly one realistic horse vocalization exists in this game, by owner directive: a rare
# gag where a landed capture plays a fully deadpan mare neigh instead of the chime. The
# roll happens on the private RNG, so THE MATH DOES NOT CHANGE. Nothing else may reference
# GAG_ID, and the corpus test holds both facts.
const GAG_SOURCE := &"capture_success"
const GAG_ID := &"neigh_real"
const GAG_CHANCE := 0.042
```

In the one internal resolution path both `play()` and `play_at()` share, before the entry lookup: if the requested id equals `GAG_SOURCE` and `_rng.randf() < GAG_CHANCE`, the id becomes `GAG_ID`. One site, both verbs covered.

- [ ] **Amendment step C: tests**

All in `game/test/test_sound.gd` (the same file Step 4 appends to). Step 4's `test_no_pony_voice_ever_entered_the_library` sweep gains its one exemption: skip the id that equals `SoundScript.GAG_ID` literally (the constant, never the string `"neigh_real"`, so a rename breaks the test), and the same test then asserts `Sound.has_id(SoundScript.GAG_ID)`, `Sound.has_id(SoundScript.GAG_SOURCE)`, and `SoundScript.GAG_CHANCE > 0.0 and SoundScript.GAG_CHANCE <= 0.1` (rare stays rare). Add one more test: seed the private generator directly (`Sound._rng.seed = 1234`), resolve `GAG_SOURCE` 2000 times through the internal resolution helper, and assert the gag id came up at least once and fewer than 400 times, and that 2000 resolutions of `&"gate_open"` never yield `GAG_ID`.

Fold these into Task 4's existing steps (the manifest row fetches with Step 2's batch, the entry with Step 3, the tests run and commit with Steps 5 and 6; the commit message gains one line: "Plus the one sanctioned neigh, a rare deadpan gag on capture, by owner directive.").

---

## Task 5: The casino and UI SFX

**Files:**
- Modify: `tools/sound_manifest.txt` (nineteen rows)
- Modify: `game/systems/sound.gd` (`LIBRARY`, the casino and ui blocks)
- Create: `game/assets/audio/casino/*.{wav,ogg}` and `game/assets/audio/ui/*.wav` with sidecars

**Interfaces:**
- Consumes: everything from Tasks 1 to 4.
- Produces sixteen new ids: `chip_clink` (3 variants), `card_slide` (2), `card_flip`, `reel_tick`, `reel_stop`, `slots_win`, `wheel_ratchet`, `wheel_settle`, `race_crowd_loop`, `race_cheer`, `race_gallop` on `BUS_EFFECTS`; `ui_confirm`, `ui_back`, `ui_open`, `ui_denied`, `ui_page` on `BUS_UI`. `ui_move` already exists from Task 2.

**The pinned sources.**

Kenney Casino Audio, verified 2026-09-04: `https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip`, HTTP 200, 876839 bytes, 59 files. Its `Audio/` directory holds `card-fan-1..2`, `card-place-1..4`, `card-shove-1..4`, `card-shuffle`, `card-slide-1..8`, `cards-pack-open-1..2`, `cards-pack-take-out-1..2`, `chip-lay-1..3`, `chips-collide-1..4`, `chips-handle-1..6`, `chips-stack-1..6`, `dice-grab-1..2`, `dice-shake-1..3`, `dice-throw-1..3`, `die-throw-1..4`, all `.ogg`. Recorded, not synthesized, which is what the spec asked for.

Kenney Interface Sounds, verified 2026-09-04: `https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip`, HTTP 200, 834536 bytes, 104 files. Its `Audio/` directory holds `back_001..004`, `bong_001`, `click_001..005`, `close_001..004`, `confirmation_001..004`, `drop_001..004`, `error_001..008`, `glass_001..006`, `glitch_001..004`, `maximize_001..009`, `minimize_001..009`, `open_001..004`, `pluck_001..002`, `question_001..004`, `scratch_001..005`, `scroll_001..005`, `select_001..008`, `switch_001..007`, `tick_001,002,004`, `toggle_001..004`.

| Id | Primary | Why | Alternates |
|---|---|---|---|
| `chip_clink_1..3` | Kenney Casino `chip-lay-1..3.ogg` | A chip laid down, three takes, which is the exact gesture a bet is | `chips-stack-1..3.ogg`; `chips-collide-1..3.ogg` |
| `card_slide_1..2` | Kenney Casino `card-slide-1.ogg`, `card-slide-2.ogg` | Eight takes in the pack; the first two are the driest | `card-slide-3..8.ogg` |
| `card_flip` | Kenney Casino `card-place-1.ogg` | A card set face up on felt | `card-place-2.ogg`; `card-shove-1.ogg` |
| `reel_tick` | BBC `07032188` | "1960 Fruit Machine operating." 123.5 s of a real mechanical slot machine; the ticks in it are the real thing, not a click | Kenney Interface `tick_001.ogg`; `click_003.ogg` |
| `reel_stop` | BBC `07032188` | The same machine's heavier landing clunk, a later segment of the same take, so tick and stop belong to one object | Kenney Interface `drop_003.ogg`; `switch_003.ogg` |
| `slots_win` | Kenney Interface `confirmation_002.ogg` | ONE stinger. The spec is explicit that this is not an escalating fanfare; the house publishes its edge on the wall and does not need to lie with sound | `confirmation_004.ogg`; `bong_001.ogg` |
| `wheel_ratchet` | BBC `07021009` | "A roulette wheel spun several times. (Close perspective, no background)." The cleanest wheel recording in the archive | `07051027` ("Roulette, wheel spinning with small ball", 17.3 s); `07051026` (large ball, 23.7 s) |
| `wheel_settle` | BBC `07021009` | The settle at the end of the same spin, so ratchet and settle are one wheel | Kenney Interface `switch_004.ogg`; BBC `07051026` |
| `race_crowd_loop` | BBC `07035148` | "Italian crowd, exterior, murmuring crowd." 194.0 s. A murmur, not a roar; the roar is `race_cheer`'s job | `00008065` ("Large restless crowd", 29.0 s, mono 48 kHz); `07031045` (fete crowd, 364.1 s) |
| `race_cheer` | BBC `07035069` | "100 men, prolonged cheer." 12.8 s | `07035070` ("100 men, single cheer", 10.6 s); `07031059` (large cheer outside St Paul's, 48.7 s) |
| `race_gallop` | BBC `07039304` | "Troop of horses galloping on turf." 149.8 s, which loops | `07024162` ("Horse On Turf: Galloping past", 12.8 s); `07039336` (two horses on turf, 18.0 s) |
| `ui_confirm` | Kenney Interface `select_003.ogg` | Woody, not a beep | `confirmation_001.ogg`; `click_005.ogg` |
| `ui_back` | Kenney Interface `back_002.ogg` | | `back_001.ogg`; `close_001.ogg` |
| `ui_open` | Kenney Interface `open_004.ogg` | | `open_002.ogg`; `maximize_006.ogg` |
| `ui_denied` | Kenney Interface `error_004.ogg` | The shortest and least shrill of the eight errors by file size | `error_002.ogg`; `glitch_002.ogg` |
| `ui_page` | Kenney Interface `scratch_003.ogg` | The paper turn that ties into the stationery look | `scratch_001.ogg`; BBC `07045125` (the paper fold `mail_open` comes from) |

- [ ] **Step 1: Append the casino rows to `tools/sound_manifest.txt`**

Under a new `# --- casino ---` banner:

```
# --- casino -----------------------------------------------------------------------------
#
# Kenney Casino Audio is CC0 and RECORDED rather than synthesized, which is why the chips
# and cards come from it rather than from a designed pack. The reels and the wheel come
# from BBC recordings of the real machines, because those exist and are better.

# chip_clink_1..3: Kenney Casino Audio, chip-lay-1..3. A chip laid down, three takes, which
# is exactly the gesture a bet is. Alternates: chips-stack-1..3.ogg; chips-collide-1..3.ogg.
casino/chip_clink_1.wav|https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip#Audio/chip-lay-1.ogg|rate=44100,mono,fade=0.002:0.04,gain_db=0
casino/chip_clink_2.wav|https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip#Audio/chip-lay-2.ogg|rate=44100,mono,fade=0.002:0.04,gain_db=0
casino/chip_clink_3.wav|https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip#Audio/chip-lay-3.ogg|rate=44100,mono,fade=0.002:0.04,gain_db=0

# card_slide_1..2: Kenney Casino Audio, card-slide-1..2. Eight takes in the pack; these two
# are the driest. Alternates: card-slide-3..8.ogg.
casino/card_slide_1.wav|https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip#Audio/card-slide-1.ogg|rate=44100,mono,fade=0.002:0.04,gain_db=0
casino/card_slide_2.wav|https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip#Audio/card-slide-2.ogg|rate=44100,mono,fade=0.002:0.04,gain_db=0

# card_flip: Kenney Casino Audio, card-place-1. A card set face up on felt.
# Alternates: card-place-2.ogg; card-shove-1.ogg.
casino/card_flip.wav|https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip#Audio/card-place-1.ogg|rate=44100,mono,fade=0.002:0.04,gain_db=0

# reel_tick: BBC 07032188, "1960 Fruit Machine operating." 123.5s of a real mechanical slot
# machine. Alternates: Kenney Interface tick_001.ogg; click_003.ogg.
casino/reel_tick.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07032188.wav|rate=44100,mono,pick=4@-36:0.04,fade=0.002:0.04,gain=-18

# reel_stop: the same machine, a later and heavier landing, so tick and stop belong to one
# object. Alternates: Kenney Interface drop_003.ogg; switch_003.ogg.
casino/reel_stop.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07032188.wav|rate=44100,mono,pick=9@-36:0.04,fade=0.002:0.10,gain=-18

# slots_win: Kenney Interface Sounds, confirmation_002. ONE stinger; the spec is explicit
# that this is not an escalating fanfare. Alternates: confirmation_004.ogg; bong_001.ogg.
casino/slots_win.wav|https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip#Audio/confirmation_002.ogg|rate=44100,mono,fade=0.002:0.06,gain_db=0

# wheel_ratchet: BBC 07021009, "A roulette wheel spun several times. (Close perspective, no
# background)." 82.4s; the cleanest wheel in the archive. Alternates: 07051027 (small ball,
# 17.3s); 07051026 (large ball, 23.7s).
casino/wheel_ratchet.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07021009.wav|rate=44100,mono,pick=3@-36:0.03,fade=0.002:0.03,gain=-18

# wheel_settle: the settle at the end of a spin on the same wheel. Alternates: Kenney
# Interface switch_004.ogg; BBC 07051026.
casino/wheel_settle.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07021009.wav|rate=44100,mono,pick=12@-36:0.03,fade=0.002:0.12,gain=-18

# race_crowd_loop: BBC 07035148, "Italian crowd, exterior, murmuring crowd." 194.0s. A
# murmur, not a roar; the roar is race_cheer's job. Alternates: 00008065 "Large restless
# crowd" 29.0s mono 48k; 07031045 (fete crowd, 364.1s).
casino/race_crowd_loop.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/07035148.wav|rate=44100,trim=40-71,loop=30,gain=-22

# race_gallop: BBC 07039304, "Troop of horses galloping on turf." 149.8s, which loops.
# Alternates: 07024162 "Horse On Turf: Galloping past" 12.8s; 07039336 (two horses, 18.0s).
casino/race_gallop.ogg|https://sound-effects-media.bbcrewind.co.uk/wav/07039304.wav|rate=44100,trim=40-61,loop=20,gain=-22

# race_cheer: BBC 07035069, "100 men, prolonged cheer." 12.8s. Alternates: 07035070 "100
# men, single cheer" 10.6s; 07031059 (large cheer outside St Paul's, 48.7s).
casino/race_cheer.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07035069.wav|rate=44100,mono,pick=1,fade=0.05:0.60,gain=-18
```

- [ ] **Step 2: Append the UI rows**

Under the existing `# --- ui ---` banner, below `ui_move`:

```
# ui_confirm: Kenney Interface Sounds, select_003. Woody, not a beep.
# Alternates: confirmation_001.ogg; click_005.ogg.
ui/ui_confirm.wav|https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip#Audio/select_003.ogg|rate=44100,mono,fade=0.002:0.03,gain_db=-2

# ui_back: Kenney Interface Sounds, back_002. Alternates: back_001.ogg; close_001.ogg.
ui/ui_back.wav|https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip#Audio/back_002.ogg|rate=44100,mono,fade=0.002:0.03,gain_db=-2

# ui_open: Kenney Interface Sounds, open_004. Alternates: open_002.ogg; maximize_006.ogg.
ui/ui_open.wav|https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip#Audio/open_004.ogg|rate=44100,mono,fade=0.002:0.04,gain_db=-2

# ui_denied: Kenney Interface Sounds, error_004. The shortest and least shrill of the eight
# errors in the pack. Alternates: error_002.ogg; glitch_002.ogg.
ui/ui_denied.wav|https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip#Audio/error_004.ogg|rate=44100,mono,fade=0.002:0.04,gain_db=-4

# ui_page: Kenney Interface Sounds, scratch_003. The paper turn that ties into the
# stationery look the Mail page already has. Alternates: scratch_001.ogg; BBC 07045125,
# the paper fold world/mail_open.wav comes from.
ui/ui_page.wav|https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip#Audio/scratch_003.ogg|rate=44100,mono,fade=0.002:0.05,gain_db=-3
```

- [ ] **Step 3: Fetch and check**

```bash
bash tools/fetch_sounds.sh
grep -c PASS game/assets/audio/sound_report.txt
grep FAIL game/assets/audio/sound_report.txt || echo "no failures"
for f in game/assets/audio/casino/*.wav game/assets/audio/ui/*.wav; do
  printf '%-46s %s\n' "$f" "$(/usr/bin/ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")"
done
```

Expected: exit 0, forty five PASS rows, no FAIL. `reel_tick` and `wheel_ratchet` must each be under 0.25 s (they fire many times a second during a spin; anything longer overlaps into mush). `race_cheer` should be 2 s to 6 s.

- [ ] **Step 4: Set the two new ogg loop flags**

```bash
tools/bin/godot --headless --path game --import
grep -H "^loop=" game/assets/audio/casino/*.ogg.import
```

Both `race_crowd_loop.ogg.import` and `race_gallop.ogg.import` must read `loop=true`; edit them the way the beds were edited in Task 3 Step 3 and re-run the import pass.

- [ ] **Step 5: Add the sixteen entries to `LIBRARY`**

Two new banners inside `LIBRARY`, after the world block:

```gdscript
	# --- casino ---
	&"chip_clink": {
		"paths": PackedStringArray([
			"res://assets/audio/casino/chip_clink_1.wav",
			"res://assets/audio/casino/chip_clink_2.wav",
			"res://assets/audio/casino/chip_clink_3.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -4.0, "pitch_min": 0.94, "pitch_max": 1.08, "loop": false},
	&"card_slide": {
		"paths": PackedStringArray([
			"res://assets/audio/casino/card_slide_1.wav",
			"res://assets/audio/casino/card_slide_2.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -4.0, "pitch_min": 0.95, "pitch_max": 1.07, "loop": false},
	&"card_flip": {
		"paths": PackedStringArray(["res://assets/audio/casino/card_flip.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -3.0, "pitch_min": 0.96, "pitch_max": 1.05, "loop": false},
	&"reel_tick": {
		"paths": PackedStringArray(["res://assets/audio/casino/reel_tick.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -14.0, "pitch_min": 0.96, "pitch_max": 1.06, "loop": false},
	&"reel_stop": {
		"paths": PackedStringArray(["res://assets/audio/casino/reel_stop.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -4.0, "pitch_min": 0.96, "pitch_max": 1.04, "loop": false},
	&"slots_win": {
		"paths": PackedStringArray(["res://assets/audio/casino/slots_win.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -2.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"wheel_ratchet": {
		"paths": PackedStringArray(["res://assets/audio/casino/wheel_ratchet.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -12.0, "pitch_min": 0.96, "pitch_max": 1.06, "loop": false},
	&"wheel_settle": {
		"paths": PackedStringArray(["res://assets/audio/casino/wheel_settle.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -3.0, "pitch_min": 0.97, "pitch_max": 1.04, "loop": false},
	&"race_crowd_loop": {
		"paths": PackedStringArray(["res://assets/audio/casino/race_crowd_loop.ogg"]),
		"bus": BUS_EFFECTS, "volume_db": -6.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"race_gallop": {
		"paths": PackedStringArray(["res://assets/audio/casino/race_gallop.ogg"]),
		"bus": BUS_EFFECTS, "volume_db": -8.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"race_cheer": {
		"paths": PackedStringArray(["res://assets/audio/casino/race_cheer.wav"]),
		"bus": BUS_EFFECTS, "volume_db": -2.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	# --- ui ---
	&"ui_confirm": {
		"paths": PackedStringArray(["res://assets/audio/ui/ui_confirm.wav"]),
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 0.98, "pitch_max": 1.02, "loop": false},
	&"ui_back": {
		"paths": PackedStringArray(["res://assets/audio/ui/ui_back.wav"]),
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 0.98, "pitch_max": 1.02, "loop": false},
	&"ui_open": {
		"paths": PackedStringArray(["res://assets/audio/ui/ui_open.wav"]),
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"ui_denied": {
		"paths": PackedStringArray(["res://assets/audio/ui/ui_denied.wav"]),
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"ui_page": {
		"paths": PackedStringArray(["res://assets/audio/ui/ui_page.wav"]),
		"bus": BUS_UI, "volume_db": -2.0, "pitch_min": 0.98, "pitch_max": 1.02, "loop": false},
```

Note that `race_crowd_loop` and `race_gallop` are `loop: true` but route to `BUS_EFFECTS`, not `BUS_AMBIENT`: they are a thing happening at the track, they stop when the race does, and they duck under the pause menu the way every other world sound does. `test_the_directory_a_file_sits_in_decides_its_bus` allows this because the rule is keyed on the directory (`casino/`), and `test_ogg_entries_loop_and_wav_entries_do_not` allows it because the rule is keyed on the extension. Neither test needs changing.

- [ ] **Step 6: Add the casino and UI behaviour test**

Append to `game/test/test_sound.gd`:

```gdscript
func test_every_casino_and_ui_sound_plays() -> void:
	for id: StringName in [&"chip_clink", &"card_slide", &"card_flip", &"reel_tick",
			&"reel_stop", &"slots_win", &"wheel_ratchet", &"wheel_settle",
			&"race_crowd_loop", &"race_gallop", &"race_cheer"]:
		assert_true(Sound.play(id), "'%s' would not play" % id)
	for id: StringName in [&"ui_move", &"ui_confirm", &"ui_back", &"ui_open", &"ui_denied",
			&"ui_page"]:
		assert_true(Sound.play(id), "'%s' would not play" % id)


func test_a_held_loop_starts_once_and_stops_when_told() -> void:
	Sound.stop_all()
	assert_true(Sound.play_loop(&"race_crowd_loop"))
	assert_true(Sound.play_loop(&"race_gallop"))
	# Asking twice must not stack a second voice on the same id.
	assert_true(Sound.play_loop(&"race_crowd_loop"))
	assert_eq(Sound.looping_ids(), [&"race_crowd_loop", &"race_gallop"] as Array[StringName])
	Sound.stop_loop(&"race_crowd_loop")
	assert_eq(Sound.looping_ids(), [&"race_gallop"] as Array[StringName])
	Sound.stop_all()
	assert_eq(Sound.looping_ids().size(), 0)


func test_a_one_shot_is_refused_as_a_held_loop() -> void:
	# play_loop() on a wav would start something nothing ever stops.
	assert_false(Sound.play_loop(&"chip_clink"))


func test_the_rapid_triggers_are_mixed_far_down() -> void:
	# reel_tick fires per symbol step and wheel_ratchet per pocket; at the level of a chip
	# clink either one is a drill. This is a mix decision the plan makes on purpose.
	assert_lte(float(Sound.entry(&"reel_tick").get("volume_db", 0.0)), -10.0)
	assert_lte(float(Sound.entry(&"wheel_ratchet").get("volume_db", 0.0)), -10.0)


func test_there_is_exactly_one_slots_celebration() -> void:
	# The spec: ONE stinger, not escalating fanfares. Anything matching slots_win_ or
	# slots_jackpot would be the beginning of a skinner box.
	var celebrations := 0
	for id: StringName in Sound.ids():
		if String(id).begins_with("slots_") and String(id).ends_with("win"):
			celebrations += 1
		assert_false(String(id).contains("jackpot"))
	assert_eq(celebrations, 1)


func test_ui_sounds_are_the_only_ones_that_survive_a_pause() -> void:
	# Sound.play() gives a UI bus entry PROCESS_MODE_ALWAYS and everything else PAUSABLE,
	# because menus are open while the tree is paused and the world is not.
	for id: StringName in Sound.ids():
		var entry: Dictionary = Sound.entry(id)
		var is_ui: bool = StringName(entry.get("bus", &"")) == SoundScript.BUS_UI
		Sound.stop_all()
		assert_true(Sound.play(id))
		assert_eq(Sound.last_process_mode() == Node.PROCESS_MODE_ALWAYS, is_ui,
			"'%s' has the wrong pause behaviour" % id)
```

That last test needs one reader on `Sound`. Add it beside the other readers in `game/systems/sound.gd`:

```gdscript
## The process mode the most recent play() set on its voice. Exists for the test that
## asserts UI ticks outlive a pause and world sounds do not; nothing in the game reads it.
func last_process_mode() -> int:
	if _pool_2d.is_empty():
		return Node.PROCESS_MODE_INHERIT
	var last: int = (_next_2d - 1 + _pool_2d.size()) % _pool_2d.size()
	return _pool_2d[last].process_mode
```

- [ ] **Step 7: Import, run the suite**

```bash
tools/bin/godot --headless --path game --import
bash tools/run_tests.sh
```

Expected: green, count up by 6.

- [ ] **Step 8: Commit**

```bash
git add tools/sound_manifest.txt game/systems/sound.gd game/test/test_sound.gd \
  game/assets/audio/casino game/assets/audio/ui game/assets/audio/sound_report.txt
git commit -m "$(cat <<'MSG'
feat: the tables and the menus get their sound

Kenney chips and cards, a real 1960 fruit machine for the reels, a real
roulette wheel for the pointer, a murmuring crowd and a troop of horses on
turf for the track, and six soft Kenney ticks for the menus. One slots
stinger and only one.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
MSG
)"
```

---

## Task 6: `ranch.gd` and the beam: the world starts making noise

**Files:**
- Modify: `game/world/ranch.gd`
- Modify: `game/actors/player/magic_beam.gd` (two call sites; the voice player is untouched)
- Test: `game/test/test_ranch_sound.gd` (create)

**Interfaces:**
- Consumes: every id from Tasks 3, 4 and 5, and `Sound.play`, `Sound.play_at`, `Sound.play_loop`, `Sound.stop_loop`, `Sound.ambient_set_phase`, `Sound.ambient_set_zone` from Task 1.
- Produces: `Ranch.sound_zone() -> StringName` (the zone the ranch last pushed; the test and the gate read it), and `Ranch._update_sound_zone() -> void`.

**Every hook point, pinned.** Nothing here changes the order of operations at any of these sites; each is one added line beside an existing one.

| Site | File and anchor | Call |
|---|---|---|
| Phase turns over | `ranch.gd::_on_world_changed()` (line 1537), inside the existing body | `Sound.ambient_set_phase(_world.phase())` |
| Boot | `ranch.gd::_rebuild_world_state()` (line ~1487), after `_show_world_line()` | the same, so a fresh boot has a bed before the first step |
| Zone poll | `ranch.gd::_physics_process()` (line 4179), after `_update_gate_prompt()` | `_update_sound_zone()` |
| Mail batch posted | `ranch.gd::_post_due_mail()` (line 3226), inside `if posted > 0:` beside `_toast(MAIL_ARRIVED)` | `Sound.play_at(&"mail_arrive", <mailbox position>)` |
| Pony delivered | `ranch.gd::deliver_pony()` (line 2602), beside the receipt `_toast` | `Sound.play_at(&"delivery_thud", crate_position())` |
| Pony into a pen | `ranch.gd::_move_pony_into_pen()`, on the successful return | `Sound.play_at(&"gate_open", ...)` |
| Survey bonus paid | `ranch.gd` line 3471, beside `_economy.grant(StoryScript.SURVEY_BONUS_BITS)` | `Sound.play(&"coins_grant")` |
| Board reward paid | `ranch.gd` line 3700, beside `_economy.grant(reward_bits)` | `Sound.play(&"coins_grant")` |
| Race starts | `ranch.gd::start_race()` (line ~2925), after `started` is true and before the toast | `Sound.play_loop(&"race_crowd_loop")` and `Sound.play_loop(&"race_gallop")` |
| Race settles | `ranch.gd::_on_race_finished()` (line 2936), beside `race_settled.emit(won, winner)` | both `stop_loop`s, then `Sound.play(&"race_cheer")` |
| Beam charge begins | `magic_beam.gd::_begin_hold()` (line 1372) | `Sound.play_at(&"capture_charge", global_position)` |
| Pony captured | `magic_beam.gd::_settle_pony()` (line ~1519), beside `captured.emit(instance)` | `Sound.play_at(&"capture_success", global_position)` |

The casino cash out at `ranch.gd:2758` deliberately gets NO `coins_grant`: the spec scopes that id to "Economy.grant payouts outside casino", and the cage has chips of its own from Task 7.

- [ ] **Step 1: Write the failing test**

Create `game/test/test_ranch_sound.gd`:

```gdscript
extends GutTest
## The ranch's own sound seams, tested without booting the ranch: the zone rule is a pure
## function of a position, an open casino panel and a region disc, so it is tested as one.
##
## THE HOOK SITES THEMSELVES are proved by the gate (game/scenes/test/sound_test.gd) and by
## the ranch gate, which boots the whole scene. What is here is the part that has a right
## and a wrong answer independent of a scene.

const SoundScript := preload("res://systems/sound.gd")
const RegionDataScript := preload("res://systems/region_data.gd")
const RanchScript := preload("res://world/ranch.gd")


func test_the_strip_disc_decides_the_strip_zone() -> void:
	var region: RegionData = RegionDataScript.new()
	region.id = &"strip"
	region.centre = Vector2(-10.0, 60.0)
	region.radius = 26.0
	assert_true(region.contains(Vector2(-10.0, 60.0)))
	assert_true(region.contains(Vector2(-10.0, 80.0)))
	assert_false(region.contains(Vector2(-10.0, 120.0)))


func test_the_zone_names_are_the_ones_the_bed_table_carries() -> void:
	# A typo here would be a zone that silently overlays nothing at all.
	assert_true(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_STRIP))
	assert_true(SoundScript.ZONE_BEDS.has(SoundScript.ZONE_CASINO))
	assert_eq(String(SoundScript.ZONE_STRIP), "strip")
	assert_eq(String(SoundScript.ZONE_CASINO), "casino")


func test_ranch_declares_a_sound_zone_reader() -> void:
	assert_true(RanchScript.new().has_method("sound_zone"))


func test_every_id_the_ranch_fires_is_in_the_library() -> void:
	# The whole point of a registry is that a typo at a call site is caught here rather
	# than by a player hearing nothing.
	for id: StringName in [&"mail_arrive", &"delivery_thud", &"gate_open", &"coins_grant",
			&"race_crowd_loop", &"race_gallop", &"race_cheer", &"capture_charge",
			&"capture_success"]:
		assert_true(SoundScript.LIBRARY.has(id), "ranch fires '%s' and it is not in LIBRARY" % id)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_ranch_sound.gd -gexit`
Expected: FAIL on `test_ranch_declares_a_sound_zone_reader` ("has_method" answers false). The other three should already pass.

- [ ] **Step 3: Add the zone poll to `ranch.gd`**

Add the field beside the other per frame trackers (near `_gate_prompted`):

```gdscript
## The ambient zone last pushed to Sound. Kept here rather than asked of Sound every frame
## so the region lookup below runs only when the answer could have changed.
var _sound_zone: StringName = &""
```

Add the two functions in the section that holds `_update_gate_prompt()`, directly after it:

```gdscript
## WHICH AMBIENT ZONE SHE IS STANDING IN. Presentation only; nothing here decides anything
## the game already decided. The Palace interior wins over the Strip, because a player at a
## table is indoors even though the building is on the Strip's own disc.
##
## THE REGION IS THE ONE THE MAP ALREADY DRAWS. Strip.REGION_ID's RegionData carries the
## centre and radius the lamps were placed around, so "on the Strip" here means exactly what
## it means everywhere else in this file rather than a second circle typed out beside it.
func _update_sound_zone() -> void:
	var zone: StringName = SoundScript.ZONE_NONE
	if casino_menu != null and casino_menu.has_method("is_open") and bool(casino_menu.is_open()):
		zone = SoundScript.ZONE_CASINO
	elif player != null:
		var region: RegionData = _regions_registry().by_id(StripScript.REGION_ID)
		if region != null and region.contains(
				Vector2(player.global_position.x, player.global_position.z)):
			zone = SoundScript.ZONE_STRIP
	if zone == _sound_zone:
		return
	_sound_zone = zone
	Sound.ambient_set_zone(zone)


## The zone this ranch last pushed. Read by the sound gate and by the suite; nothing in the
## game reads it.
func sound_zone() -> StringName:
	return _sound_zone
```

Add the preload beside the other `const XScript :=` lines at the top of the file:

```gdscript
const SoundScript := preload("res://systems/sound.gd")
```

Call it from `_physics_process()`, directly after `_update_gate_prompt()`:

```gdscript
	_update_gate_prompt()
	_update_sound_zone()
```

- [ ] **Step 4: Add the phase push**

Inside `_on_world_changed()`, as the first line of the body, above the `sky_rig` block:

```gdscript
func _on_world_changed() -> void:
	# THE SKY AND THE SOUND TURN OVER TOGETHER, off the one connection this handler is.
	if _world != null:
		Sound.ambient_set_phase(_world.phase())
	if sky_rig != null and sky_rig.has_method("apply"):
```

And in `_rebuild_world_state()`, directly after the `_show_world_line()` call at its end:

```gdscript
	_show_world_line()
	# The bed for the hour she loaded into, before her first step rather than after her
	# first phase change three minutes later.
	if _world != null:
		Sound.ambient_set_phase(_world.phase())
```

- [ ] **Step 5: Add the world transaction sounds**

In `_post_due_mail()`, inside the `if posted > 0:` branch, directly under the existing `_toast(MAIL_ARRIVED)`:

```gdscript
	if posted > 0:
		_toast(MAIL_ARRIVED)
		var box: Mailbox = get_mailbox()
		if box != null:
			Sound.play_at(&"mail_arrive", box.global_position)
```

In `deliver_pony()`, directly after the receipt `_toast(...)` call:

```gdscript
	# The crate goes down and that is the whole of it. She says nothing, on purpose: the
	# pony voice slots are cut by owner directive, and a real mare's neigh here would be
	# the loudest wrong note in the game.
	Sound.play_at(&"delivery_thud", crate_position())
```

In `_move_pony_into_pen()`, on the path that actually seats her (immediately before the `return true` that reports success):

```gdscript
	Sound.play_at(&"gate_open", pen.global_position)
```

If the local holding the pen is named something else in that function, use whatever it is; the position wanted is the pen she was put into, not the player.

Beside `_economy.grant(StoryScript.SURVEY_BONUS_BITS)` (line 3471):

```gdscript
	Sound.play(&"coins_grant")
```

Beside `_economy.grant(reward_bits)` (line 3700):

```gdscript
	Sound.play(&"coins_grant")
```

- [ ] **Step 6: Add the race loops**

In `start_race()`, after the `if not started:` unwind block and before `_race_entrant = uid`:

```gdscript
	# THE TRACK IS AUDIBLE WHILE IT RUNS AND SILENT WHEN IT DOES NOT. Held loops, not one
	# shots: _on_race_finished() below is the only thing that stops them, and it is the only
	# way a race ever ends.
	Sound.play_loop(&"race_crowd_loop")
	Sound.play_loop(&"race_gallop")
```

In `_on_race_finished()`, directly above `race_settled.emit(won, winner)`:

```gdscript
	Sound.stop_loop(&"race_gallop")
	Sound.stop_loop(&"race_crowd_loop")
	Sound.play(&"race_cheer")
	race_settled.emit(won, winner)
```

The cheer plays whoever won. A crowd cheers the winner, not the player, and a track that only cheered when she won would be a track that was lying to her.

- [ ] **Step 7: Add the two beam lines**

In `game/actors/player/magic_beam.gd`, add the preload beside the other `const XScript :=` lines:

```gdscript
const SoundScript := preload("res://systems/sound.gd")
```

In `_begin_hold(body)` (line 1372), directly after `_hold_seconds = 0.0`:

```gdscript
	Sound.play_at(&"capture_charge", global_position)
```

In `_settle_pony()`, in the successful branch, directly after the existing `_play_first_capture_voice()` line and before `captured.emit(instance)`:

```gdscript
		_play_first_capture_voice()
		Sound.play_at(&"capture_success", global_position)
		captured.emit(instance)
```

**Do not touch `_build_voice()`, `_play_first_capture_voice()`, `VOICE_LINE` or `_voice`.** The placeholder voice line is out of scope for this slice by the standing verdict, and the two lines above sit beside it without changing it.

- [ ] **Step 8: Run the new test and the ranch gate**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_ranch_sound.gd -gexit
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```

Expected: 4 tests PASS, and `RANCH_OK ponies=49 props=111 assets=present` exactly as before. The census must not have moved: this task added no node to `$Buildings` or `$Props`.

- [ ] **Step 9: Run every other scene gate, because ranch.gd is under all of them**

```bash
for scene in smoke camera walk world region market collection ledger depot creation casino story; do
  printf '%-12s ' "$scene"
  path="scenes/test/${scene}_test.tscn"
  [ "$scene" = "smoke" ] && path="scenes/test/smoke.tscn"
  tools/bin/godot --headless --audio-driver Dummy --path game "$path" 2>&1 \
    | grep -E "_OK|_FAILED" | tail -1
done
```

Expected: every line an `_OK`. A gate that now hangs is the trap the `GateWatchdog` exists for: check whether a bed tween is keeping something alive that a gate waits to die.

- [ ] **Step 10: Full suite, then commit**

```bash
bash tools/run_tests.sh
tools/bin/godot --headless --path game --import
git add game/world/ranch.gd game/actors/player/magic_beam.gd \
  game/test/test_ranch_sound.gd game/test/test_ranch_sound.gd.uid
git commit -m "$(cat <<'MSG'
feat: the ranch makes noise at the seams it already transacts at

The phase pushes a bed, the Strip and the Palace overlay their own, the post
lands at the mailbox, a delivery is a thud at the crate, a pen
gate creaks, a payout counts coins, the track holds a crowd while it runs, and
the beam charges and lands. Every one of them is one line beside a line that
was already there.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
MSG
)"
```

---

## Task 7: The menus tick, the tables sound, and the settings page grows two rows

**Files:**
- Modify: `game/ui/menu_style.gd` (six static forwarders)
- Modify: `game/ui/pause_menu.gd` (two settings rows, and the six tick sites)
- Modify: `game/ui/table_menu.gd`, `casino_menu.gd`, `market_menu.gd`, `depot_menu.gd`, `build_menu.gd` (tick sites)
- Modify: `game/ui/slots_menu.gd`, `wheel_menu.gd`, `blackjack_menu.gd`, `race_menu.gd` (the animation state triggers and the bet clink)
- Test: `game/test/test_menu_sound.gd` (create), and additions to `game/test/test_pause_menu.gd`

**Interfaces:**
- Consumes: `Sound.play`, and the six UI ids plus `chip_clink`, `card_slide`, `card_flip`, `reel_tick`, `reel_stop`, `slots_win`, `wheel_ratchet`, `wheel_settle` from Tasks 3 to 5. `Settings.step_ambient`, `Settings.step_effects` from Task 1.
- Produces: `MenuStyle.tick_move()`, `tick_confirm()`, `tick_back()`, `tick_open()`, `tick_denied()`, `tick_page()`, all `static func ... -> void`. `PauseMenu.SettingRow` becomes `{ VOLUME, AMBIENT, EFFECTS, SENSITIVITY, INVERT }`.

**Why six forwarders rather than a call to `Sound` at each site.** The spec asks for "one shared hook point" so all menus gain ticks without per menu wiring. GDScript has no way to intercept a `move_selection()` that nine separate files define, so the shared thing is the DECISION, not the call: which id a move makes, at what level, whether a move even ticks. That lives in `MenuStyle` in six one line functions, and the menus call those. Changing the whole game's UI character afterwards is then six lines in one file, which is what the spec was actually asking for.

- [ ] **Step 1: Add the forwarders to `game/ui/menu_style.gd`**

At the foot of the file, under a new banner:

```gdscript
# --- the menu tick kit --------------------------------------------------------------------
#
# THE ONE PLACE THAT DECIDES WHAT A MENU SOUNDS LIKE. Nine files under game/ui/ call these
# six functions and none of them names a sound id, a level or a bus. Changing the character
# of every menu in the game is changing six lines here.
#
# THESE ARE THE ONLY AUDIO CALLS ALLOWED UNDER game/ui/ THAT NAME AN ID. A menu calls
# MenuStyle.tick_move(); it never calls Sound.play(&"ui_move") itself. The RNG rule is
# untouched either way: every variation decision is made inside game/systems/sound.gd.

const SoundScript := preload("res://systems/sound.gd")


## The selection cursor moved.
static func tick_move() -> void:
	Sound.play(&"ui_move")


## An action was taken.
static func tick_confirm() -> void:
	Sound.play(&"ui_confirm")


## A panel or a page was left.
static func tick_back() -> void:
	Sound.play(&"ui_back")


## A panel was opened.
static func tick_open() -> void:
	Sound.play(&"ui_open")


## An action was refused: a row that cannot be taken, a price she cannot pay.
static func tick_denied() -> void:
	Sound.play(&"ui_denied")


## A page turned inside a panel that was already open.
static func tick_page() -> void:
	Sound.play(&"ui_page")
```

The `SoundScript` preload is there so the file declares its dependency the way every other file in this project does, even though the calls go through the autoload singleton by name. Do not remove it; the parse sweep is what makes a stale preload visible.

- [ ] **Step 2: Write the failing test**

Create `game/test/test_menu_sound.gd`:

```gdscript
extends GutTest
## The UI tick kit, and the rule that keeps it the only audio decision under game/ui/.
##
## THE SOURCE SCAN AT THE BOTTOM is the load bearing test in this file. Six forwarders are
## easy to write and easy to bypass, and a menu that reaches past them for Sound.play() with
## an id of its own is exactly the drift this kit exists to prevent.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const SoundScript := preload("res://systems/sound.gd")

const UI_DIR := "res://ui/"
## menu_style.gd is the kit itself, so it is the one file allowed to name a UI id.
const KIT := "menu_style.gd"


func test_the_six_forwarders_exist_and_run() -> void:
	MenuStyleScript.tick_move()
	MenuStyleScript.tick_confirm()
	MenuStyleScript.tick_back()
	MenuStyleScript.tick_open()
	MenuStyleScript.tick_denied()
	MenuStyleScript.tick_page()
	assert_true(true, "six forwarders ran without an error")


func test_every_ui_id_the_kit_names_is_in_the_library() -> void:
	for id: StringName in [&"ui_move", &"ui_confirm", &"ui_back", &"ui_open", &"ui_denied",
			&"ui_page"]:
		assert_true(SoundScript.LIBRARY.has(id), "'%s' is not in LIBRARY" % id)
		var entry: Dictionary = SoundScript.LIBRARY[id]
		assert_eq(StringName(entry.get("bus", &"")), SoundScript.BUS_UI)


func test_no_menu_names_a_ui_sound_id_behind_the_kit() -> void:
	var offenders: Array[String] = []
	for name: String in DirAccess.get_files_at(UI_DIR):
		if not name.ends_with(".gd") or name == KIT:
			continue
		var text: String = FileAccess.get_file_as_string(UI_DIR + name)
		for id: String in ["ui_move", "ui_confirm", "ui_back", "ui_open", "ui_denied",
				"ui_page"]:
			if text.contains("&\"%s\"" % id):
				offenders.append("%s names %s" % [name, id])
	assert_eq(offenders, [] as Array[String],
		"menus call MenuStyle.tick_*(); only menu_style.gd may name a UI id")


func test_no_menu_constructs_a_generator() -> void:
	# The standing rule, re-asserted here because this slice adds calls under game/ui/ and
	# a variation decision is exactly the thing somebody would be tempted to make locally.
	var offenders: Array[String] = []
	for name: String in DirAccess.get_files_at(UI_DIR):
		if not name.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string(UI_DIR + name)
		if text.contains("RandomNumberGenerator") or text.contains("randi(") \
				or text.contains("randf("):
			offenders.append(name)
	assert_eq(offenders, [] as Array[String], "no RNG may live under game/ui/")


func test_no_new_ui_line_carries_a_dash_of_either_kind() -> void:
	var kit: String = FileAccess.get_file_as_string(UI_DIR + KIT)
	for line: String in kit.split("\n"):
		if line.strip_edges().begins_with("# ---"):
			continue
		assert_false(line.contains("--"), "menu_style.gd line carries a double hyphen: %s" % line)
		assert_false(line.contains(char(0x2014)), "menu_style.gd line carries an em dash")
```

- [ ] **Step 3: Run it to verify it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_menu_sound.gd -gexit`
Expected: FAIL on `test_the_six_forwarders_exist_and_run` before Step 1 is done; after Step 1 all five should pass. Run it now to see the state you are in.

`test_no_new_ui_line_carries_a_dash_of_either_kind` reads `menu_style.gd`, which has pre existing ` -- ` in its own older comments. If it fires on a line you did not write, that is a pre existing line: narrow the test to the lines below the `# --- the menu tick kit ---` banner by slicing the file at that banner, rather than rewriting comments this slice did not author.

- [ ] **Step 4: The pause menu's two new rows**

In `game/ui/pause_menu.gd`, widen the enum so the three volumes sit together:

```gdscript
enum SettingRow { VOLUME, AMBIENT, EFFECTS, SENSITIVITY, INVERT }
```

`_row_count()` already answers `SettingRow.size()` for `Page.SETTINGS`, so the cursor grows on its own and nothing else needs touching for input parity.

In `adjust()`, add the two cases between `VOLUME` and `SENSITIVITY`:

```gdscript
	match _selected:
		SettingRow.VOLUME:
			settings.step_volume(direction)
		SettingRow.AMBIENT:
			settings.step_ambient(direction)
		SettingRow.EFFECTS:
			settings.step_effects(direction)
		SettingRow.SENSITIVITY:
			settings.step_sensitivity(direction)
		SettingRow.INVERT:
			settings.toggle_invert()
```

In `_draw_settings()`, replace the three `_add_row` calls with five. The labels say what the slider actually covers, because "Effects" alone would not tell her the menu ticks ride it:

```gdscript
	_add_row(SettingRow.VOLUME, "Master volume",
		"%d%%" % int(round(settings.master_volume * 100.0)))
	_add_row(SettingRow.AMBIENT, "Ambience",
		"%d%%" % int(round(settings.ambient_volume * 100.0)))
	_add_row(SettingRow.EFFECTS, "Effects and menus",
		"%d%%" % int(round(settings.effects_volume * 100.0)))
	_add_row(SettingRow.SENSITIVITY, "Mouse sensitivity",
		"%.1f" % (settings.mouse_sensitivity * 1000.0))
	_add_row(SettingRow.INVERT, "Invert look", "On" if settings.invert_look else "Off")
```

- [ ] **Step 5: The pause menu's tick sites**

`open()`: after the body has decided it is opening and before it returns true, add `MenuStyleScript.tick_open()`.

`open_page(page)`: the same, `MenuStyleScript.tick_open()` when the panel was closed and `MenuStyleScript.tick_page()` when it was already open (a page switch inside an open panel is a page turn, not an opening).

`move_selection(step)`: as its last line, `MenuStyleScript.tick_move()`.

`confirm()`: this function has many `return false` paths and several `return true` paths. Tick at the ends, not at the top:
- every `return false` in it becomes `MenuStyleScript.tick_denied()` then `return false`
- the `Row.SETTINGS`, `Row.COMPENDIUM`, `Row.REQUESTS`, `Row.MAIL` and `Row.LEDGER` branches call `MenuStyleScript.tick_page()` (they turn to a page inside an already open panel)
- every other successful path calls `MenuStyleScript.tick_confirm()`

`back()`: as its first line, `MenuStyleScript.tick_back()`.

`adjust()`: after the `match`, `MenuStyleScript.tick_move()`. A slider that moves silently while every other row ticks reads as broken.

`open_letter(id)` (the site that emits `mail_opened` at line 670): `Sound.play(&"mail_open")` directly, because this is a world sound and not a UI tick; it belongs on the Effects bus with the paper it depicts. Add the preload `const SoundScript := preload("res://systems/sound.gd")` at the top of `pause_menu.gd` for the same declare your dependencies reason as `menu_style.gd`.

The reply path in `confirm()` (the `mail_reply.emit(answered, choice)` site): `Sound.play(&"mail_stamp")` directly, on the same reasoning; that is the ANSWERED stamp coming down.

- [ ] **Step 6: The shared table and panel ticks**

In `game/ui/table_menu.gd`:
- `open()`: `MenuStyleScript.tick_open()` on the success path
- `close()`: `MenuStyleScript.tick_back()`
- `move_selection(step)`: `MenuStyleScript.tick_move()` as its last line
- `switch_tab(step)`: `MenuStyleScript.tick_page()`

The four tables inherit all four of those; `slots_menu.gd`, `wheel_menu.gd` and `blackjack_menu.gd` override `move_selection()` and `switch_tab()`, so add the same call to each override's last line rather than relying on `super()`.

In `game/ui/casino_menu.gd`, `market_menu.gd`, `depot_menu.gd` and `build_menu.gd`, do the same four: `tick_open()` on open, `tick_back()` on close, `tick_move()` at the end of `move_selection()`, `tick_page()` in `switch_tab()` where one exists.

- [ ] **Step 7: The bet clink, at the four tables and the cage**

Each table emits its request from `confirm()`. Directly before that emit, add:

```gdscript
	MenuStyleScript.tick_confirm()
	Sound.play(&"chip_clink")
```

The four sites are `slots_menu.gd::confirm()` (before `spin_requested.emit(...)`), `wheel_menu.gd::confirm()` (before `bet_requested.emit(...)`), `blackjack_menu.gd::confirm()` (before `deal_requested.emit(...)`) and `race_menu.gd::confirm()` (before `race_requested.emit(...)`). In `casino_menu.gd::confirm()`, the cage rows that emit `buy_chips_requested` and `cash_out_requested` get the same pair; the room rows that emit `room_requested` get `tick_confirm()` only.

Each of those files needs `const SoundScript := preload("res://systems/sound.gd")` at the top beside its existing preloads.

- [ ] **Step 8: The slots reels**

In `game/ui/slots_menu.gd`, add the state and the per frame reader. Nothing here reads or writes anything the drawing code did not already read: `_reel_offset` is the ribbon position `reel_offset()` already publishes, and `_spinning` is what `animating()` already publishes.

```gdscript
## Below this many symbols per second a reel counts as landed. The spin runs at REEL_SPEED
## and the landing tween eases to a stop, so anything this slow is the settle and not the
## run.
const REEL_LANDED_SPEED := 1.2

var _reel_step: Array[int] = [-1, -1, -1]
var _reel_prev: Array[float] = [0.0, 0.0, 0.0]
var _reel_landed: Array[bool] = [true, true, true]


func _process(delta: float) -> void:
	super(delta)
	_sound_reels(delta)


## ONE TICK PER SYMBOL WHILE A REEL RUNS, ONE CLUNK WHEN IT STOPS. Derived from the ribbon
## position the paint pass already reads, so no timing, no state and no tween changes shape
## because the machine now makes a noise. THE MATH DOES NOT CHANGE: nothing here touches
## Slots, the stake, or any generator.
func _sound_reels(delta: float) -> void:
	if not is_open() or delta <= 0.0:
		return
	for reel: int in SlotsScript.REELS:
		var offset: float = _reel_offset[reel]
		var speed: float = absf(offset - _reel_prev[reel]) / delta
		_reel_prev[reel] = offset
		if speed > REEL_LANDED_SPEED:
			_reel_landed[reel] = false
			var step: int = int(floor(offset))
			if step != _reel_step[reel]:
				_reel_step[reel] = step
				Sound.play(&"reel_tick")
		elif not _reel_landed[reel]:
			_reel_landed[reel] = true
			Sound.play(&"reel_stop")
```

`_reel_landed` starts `[true, true, true]` on purpose: a reel has to be seen running before it can be heard stopping, so opening the cabinet on a still machine is silent.

In `show_spin()`, directly after `_spinning = true`, resync so a second spin cannot inherit the first one's readings:

```gdscript
	_spinning = true
	for reel: int in SlotsScript.REELS:
		_reel_prev[reel] = _reel_offset[reel]
		_reel_landed[reel] = true
```

And for the win stinger, append one sequential step after the existing `_tween.tween_callback(func() -> void: _spinning = false)` at the end of `show_spin()`:

```gdscript
	_tween.tween_callback(func() -> void: _spinning = false)
	if won > 0:
		_tween.tween_callback(func() -> void: Sound.play(&"slots_win"))
```

ONE stinger and nothing else. A loss stays quiet, exactly as `_flash` already does, and for the same reason the cabinet publishes its house edge on the wall outside.

- [ ] **Step 9: The wheel**

In `game/ui/wheel_menu.gd`, the ratchet detection already exists inside `paint()` at lines 348 to 350:

```gdscript
	if now != _last_pocket:
		_last_pocket = now
		_ratchet = 1.0
```

Add one line inside that branch, guarded so a wheel nudged while idle is silent:

```gdscript
	if now != _last_pocket:
		_last_pocket = now
		_ratchet = 1.0
		if _spinning:
			Sound.play(&"wheel_ratchet")
```

And in `show_spin()`, change the settle callback so the sound rides the state change that already exists:

```gdscript
	_tween.tween_callback(func() -> void:
		_spinning = false
		Sound.play(&"wheel_settle"))
```

- [ ] **Step 10: Blackjack**

In `game/ui/blackjack_menu.gd::show_hand()`, inside the existing per card `tween_callback`, directly after `_dealt = step + 1`:

```gdscript
			_dealt = step + 1
			# The first four cards are the deal; everything past them is a card turned over
			# in the open, which is a different gesture and a different sound.
			Sound.play(&"card_slide" if step < 4 else &"card_flip")
```

`Sound.play()` takes a `StringName`; the ternary above yields one either way, so no cast is needed. If the parse sweep objects to inference on that expression, write it as two lines with an explicit `var id: StringName`.

- [ ] **Step 11: Run the menu tests and the casino gate**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_menu_sound.gd -gexit
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn 2>&1 | tail -3
```

Expected: 5 tests PASS, and `CASINO_OK checks=76`. The casino gate is the one that would catch a table whose animation timing moved; if its check count or its verdict changed, something in Steps 8 to 10 did more than add a call.

- [ ] **Step 12: Extend the pause menu test**

Append to `game/test/test_pause_menu.gd` (match the file's existing preload and helper style):

```gdscript
func test_the_settings_page_has_five_rows_now() -> void:
	var menu = PauseMenuScript.new()
	assert_eq(PauseMenuScript.SettingRow.size(), 5)
	assert_eq(PauseMenuScript.SettingRow.VOLUME, 0)
	assert_eq(PauseMenuScript.SettingRow.AMBIENT, 1)
	assert_eq(PauseMenuScript.SettingRow.EFFECTS, 2)
	menu.free()


func test_adjusting_the_ambient_row_moves_the_ambient_volume_and_nothing_else() -> void:
	var menu = PauseMenuScript.new()
	var settings = SettingsScript.new()
	menu.settings = settings
	menu.open_page(PauseMenuScript.Page.SETTINGS)
	menu.move_selection(PauseMenuScript.SettingRow.AMBIENT)
	var master_before: float = settings.master_volume
	menu.adjust(-1)
	assert_lt(settings.ambient_volume, 1.0)
	assert_almost_eq(settings.master_volume, master_before, 0.0001)
	assert_almost_eq(settings.effects_volume, 1.0, 0.0001)
	menu.free()
```

If `test_pause_menu.gd` does not already preload `Settings`, add `const SettingsScript := preload("res://systems/settings.gd")` at its top. If its existing tests construct the menu through a scene instead of `new()`, follow whatever it already does rather than the shape above; the assertions are the point.

- [ ] **Step 13: Full suite and every gate**

```bash
bash tools/run_tests.sh
for scene in smoke camera walk world region market collection ledger depot creation casino story; do
  printf '%-12s ' "$scene"
  path="scenes/test/${scene}_test.tscn"
  [ "$scene" = "smoke" ] && path="scenes/test/smoke.tscn"
  tools/bin/godot --headless --audio-driver Dummy --path game "$path" 2>&1 \
    | grep -E "_OK|_FAILED" | tail -1
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -1
```

Expected: green suite, every gate `_OK`, and `RANCH_OK ponies=49 props=111 assets=present`.

- [ ] **Step 14: Commit**

```bash
tools/bin/godot --headless --path game --import
git add game/ui game/test/test_menu_sound.gd game/test/test_menu_sound.gd.uid \
  game/test/test_pause_menu.gd
git commit -m "$(cat <<'MSG'
feat: the menus tick and the tables sound

Six forwarders in MenuStyle are the only place in the game that decides what a
menu sounds like, and nine panels call them. The reels tick per symbol and
clunk when they land, the wheel ratchets past each pocket and settles, cards
slide on the deal and turn over on a hit, a bet clinks. One slots stinger.
Ambience and Effects are two more rows on the settings page.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
MSG
)"
```

---

## Task 8: Hoofsteps under the player

**Files:**
- Modify: `game/actors/player/player.gd`
- Modify: `game/world/ranch.gd` (`_update_sound_zone()` also pushes the surface)
- Test: `game/test/test_player_steps.gd` (create)

**Interfaces:**
- Consumes: `hoofsteps_grass`, `hoofsteps_hard` from Task 4; `Ranch._update_sound_zone()` from Task 6.
- Produces: `Player.STEP_STRIDE := 1.1`, `Player.STEP_MIN_SPEED := 0.4`, `Player.SURFACE_GRASS := &"hoofsteps_grass"`, `Player.SURFACE_HARD := &"hoofsteps_hard"`, `Player.set_step_surface(id: StringName) -> void`, `Player.step_surface() -> StringName`, `Player.step_distance() -> float`.

**The cadence decision, and why it is distance and not a timer.** The spec left this open: "the plan pins a step-timer hook; if cadence detection turns out invasive, footsteps degrade to a fixed-interval walk loop." Neither is what this plan does. `Player._physics_process()` already computes `get_ground_speed()` every frame, so **a step fires every `STEP_STRIDE` metres actually travelled**. That is one accumulator and one comparison, it needs nothing from the animation system, and it is correct at every speed for free: sneaking gives a slow walk and running gives a gallop, with no second constant to keep in sync. A fixed interval would have been wrong at one of the two speeds by construction.

**And why `ranch.gd` picks the surface.** The player does not know what a region is, and teaching her would put map knowledge in an actor. `ranch.gd` already resolves the zone every frame for the ambient beds (Task 6); the surface falls out of the same answer for free, and it is pushed to the player with one setter.

- [ ] **Step 1: Write the failing test**

Create `game/test/test_player_steps.gd`:

```gdscript
extends GutTest
## The hoofstep cadence: a step every STEP_STRIDE metres actually travelled, no step
## standing still, no step in the air, and a surface the ranch chooses rather than the
## player guessing at one.

const PlayerScript := preload("res://actors/player/player.gd")
const SoundScript := preload("res://systems/sound.gd")


func test_the_two_surfaces_are_library_ids() -> void:
	assert_true(SoundScript.LIBRARY.has(PlayerScript.SURFACE_GRASS))
	assert_true(SoundScript.LIBRARY.has(PlayerScript.SURFACE_HARD))


func test_the_stride_is_a_quadruped_stride_and_not_a_machine_gun() -> void:
	# At RUN_SPEED this is about five steps a second across four hooves, which is a gallop.
	# Under half a metre would be a drill and over two would be a limp.
	assert_gte(PlayerScript.STEP_STRIDE, 0.6)
	assert_lte(PlayerScript.STEP_STRIDE, 2.0)
	assert_gt(PlayerScript.STEP_MIN_SPEED, 0.0)


func test_a_fresh_player_starts_on_grass() -> void:
	var player = PlayerScript.new()
	assert_eq(player.step_surface(), PlayerScript.SURFACE_GRASS)
	player.free()


func test_the_surface_is_the_rancher_s_to_set() -> void:
	var player = PlayerScript.new()
	player.set_step_surface(PlayerScript.SURFACE_HARD)
	assert_eq(player.step_surface(), PlayerScript.SURFACE_HARD)
	# An id that is not a real surface is refused rather than played into a push_error on
	# every single step for the rest of the session.
	player.set_step_surface(&"not_a_surface")
	assert_eq(player.step_surface(), PlayerScript.SURFACE_HARD)
	player.free()


func test_standing_still_never_accumulates_a_step() -> void:
	var player = PlayerScript.new()
	for i in range(120):
		player.accumulate_step(0.0, 1.0 / 60.0, true)
	assert_almost_eq(player.step_distance(), 0.0, 0.0001)
	player.free()


func test_leaving_the_ground_resets_the_accumulator() -> void:
	var player = PlayerScript.new()
	player.accumulate_step(3.0, 1.0 / 60.0, true)
	assert_gt(player.step_distance(), 0.0)
	player.accumulate_step(3.0, 1.0 / 60.0, false)
	assert_almost_eq(player.step_distance(), 0.0, 0.0001)
	player.free()


func test_a_step_fires_once_per_stride_and_the_remainder_carries() -> void:
	var player = PlayerScript.new()
	var steps := 0
	# Ten metres at one metre per frame.
	for i in range(10):
		if player.accumulate_step(60.0, 1.0 / 60.0, true):
			steps += 1
	assert_eq(steps, int(floor(10.0 / PlayerScript.STEP_STRIDE)),
		"a step every STEP_STRIDE metres, and the remainder carried into the next one")
	player.free()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_player_steps.gd -gexit`
Expected: FAIL on every case; none of these constants or methods exists yet.

- [ ] **Step 3: Add the cadence to `game/actors/player/player.gd`**

Add the preload beside the existing ones at the top of the file:

```gdscript
const SoundScript := preload("res://systems/sound.gd")
```

Add the constants beside `RUN_SPEED` and `SNEAK_SPEED`:

```gdscript
## HOOFSTEPS ARE A FUNCTION OF DISTANCE, NOT OF TIME. One step every STEP_STRIDE metres
## actually travelled, so sneaking gives a walk and running gives a gallop out of one
## constant instead of two that would drift apart. At RUN_SPEED this is roughly five steps
## a second across four hooves.
const STEP_STRIDE := 1.1
## Below this she is shuffling, not walking, and a sound there is a sound with no gesture
## behind it.
const STEP_MIN_SPEED := 0.4
const SURFACE_GRASS := &"hoofsteps_grass"
const SURFACE_HARD := &"hoofsteps_hard"
```

Add the state beside the other private fields:

```gdscript
var _step_distance := 0.0
var _step_surface: StringName = SURFACE_GRASS
```

Add the three public members and the accumulator:

```gdscript
## Which surface she is walking on. Set by ranch.gd, which is the only thing that knows
## what a region is; an unknown id is refused so a typo cannot turn every step in the rest
## of the session into a push_error.
func set_step_surface(id: StringName) -> void:
	if id != SURFACE_GRASS and id != SURFACE_HARD:
		push_error("Player.set_step_surface: '%s' is not a surface" % id)
		return
	_step_surface = id


func step_surface() -> StringName:
	return _step_surface


func step_distance() -> float:
	return _step_distance


## Roll the accumulator forward and answer whether a hoof landed this frame. Pure: it makes
## no sound and reads no node, which is what lets the suite drive it with numbers.
func accumulate_step(speed: float, delta: float, on_floor: bool) -> bool:
	if not on_floor or speed < STEP_MIN_SPEED or delta <= 0.0:
		_step_distance = 0.0
		return false
	_step_distance += speed * delta
	if _step_distance < STEP_STRIDE:
		return false
	_step_distance -= STEP_STRIDE
	return true
```

And call it from `_physics_process()`, as the last line, directly after `_update_animation(get_ground_speed())`:

```gdscript
	_update_facing(direction, delta)
	_update_animation(get_ground_speed())
	if accumulate_step(get_ground_speed(), delta, is_on_floor()):
		Sound.play_at(_step_surface, global_position)
```

`is_on_floor()` is re-read rather than reusing the `on_floor` local from the top of the function, because `move_and_slide()` has run since then and the answer can have changed; a step fired on last frame's answer is a step through the floor she just left.

- [ ] **Step 4: Push the surface from `ranch.gd`**

In `_update_sound_zone()` (Task 6, Step 3), directly after `Sound.ambient_set_zone(zone)`:

```gdscript
	Sound.ambient_set_zone(zone)
	# THE SURFACE FALLS OUT OF THE SAME ANSWER. The Strip is boards and the Palace floor is
	# not grass; everywhere else on this map is turf. The player does not know what a
	# region is and this is the one place that does.
	if player != null and player.has_method("set_step_surface"):
		player.set_step_surface(PlayerScript.SURFACE_GRASS if zone == SoundScript.ZONE_NONE
			else PlayerScript.SURFACE_HARD)
```

`ranch.gd` already preloads the player script; if it does not, add `const PlayerScript := preload("res://actors/player/player.gd")` beside the other preloads.

- [ ] **Step 5: Run the test, then the walk gate**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/test_player_steps.gd -gexit
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/walk_test.tscn 2>&1 | tail -3
```

Expected: 7 tests PASS, and the walk gate's own `_OK` unchanged. The walk gate drives the player around for hundreds of frames and is the one most likely to notice if `accumulate_step()` did something to movement; it must not have, because nothing above writes `velocity`.

- [ ] **Step 6: Full suite and commit**

```bash
bash tools/run_tests.sh
tools/bin/godot --headless --path game --import
git add game/actors/player/player.gd game/world/ranch.gd \
  game/test/test_player_steps.gd game/test/test_player_steps.gd.uid
git commit -m "$(cat <<'MSG'
feat: hooves, one step every stride she actually walks

Distance driven rather than timed, so sneaking is a walk and running is a
gallop out of one constant. The ranch picks the surface, because the ranch is
the only thing that knows what a region is.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
MSG
)"
```

---

## Task 9: The `SOUND_OK` gate, the docs, and the raised floor

**Files:**
- Create: `game/scenes/test/sound_test.gd` and `game/scenes/test/sound_test.tscn`
- Modify: `tools/run_tests.sh` (`MIN_TESTS` only)
- Modify: `docs/testing.md` (the gate's section, and a section for the pipeline)

**Interfaces:**
- Consumes: everything. This is the whole slice, booted.
- Produces: the marker `SOUND_OK ids=<n>` and exit code 0, or `SOUND_FAILED ids=<n> failed=<m>` and exit 1.

**Why this gate hosts nothing.** Every other gate in this project instances `world/ranch.tscn` because what it checks is a ranch. This one checks the audio layer, which is four autoloads and a directory of files, so it hosts a bare `Node` and nothing else. That is not just economy: **a gate that boots the ranch can write a live save** (the parked defect), and the one gate this slice adds must not be another way for that to happen. The gate proves it too, by listing `user://saves` before and after and asserting the listing is identical.

- [ ] **Step 1: Write the gate scene**

Create `game/scenes/test/sound_test.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/test/sound_test.gd" id="1"]

[node name="SoundTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Write the gate**

Create `game/scenes/test/sound_test.gd`:

```gdscript
extends Node
## THE SOUND GATE. Everything about this game's audio that a unit test cannot see, because
## it needs a real engine with a real bus layout and real imported streams behind it: that
## the four buses came out of default_bus_layout.tres and route into Master, that every
## file in Sound.LIBRARY actually decoded, that the beds import as loops and the one shots
## do not, that all five verbs run without an error, and that the pools steal rather than
## grow when they are asked for more voices than they have.
##
## THIS GATE HOSTS NOTHING. No ranch, no player, no save. Every other gate instances
## world/ranch.tscn because a ranch is what it is checking; this one is checking four
## autoloads and a directory, and a gate that boots the ranch is a gate that can write a
## live save. It proves it rather than promising it: the last check lists user://saves
## before and after and asserts nothing moved.
##
## AudioSafety has muted Master before this file's _ready() runs, and the command line adds
## --audio-driver Dummy on top, so nothing here can make noise on the machine running it.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.
##
## Run it with:
##   tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const SoundScript := preload("res://systems/sound.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const SettingsScript := preload("res://systems/settings.gd")

const SAVE_DIR := "user://saves"

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


func _ready() -> void:
	GateWatchdogScript.arm(self, "SOUND", 120.0)
	var saves_before: PackedStringArray = _save_listing()
	_check_the_buses()
	_check_every_stream()
	_check_the_loop_flags()
	_check_the_verbs()
	_check_the_pools()
	_check_the_volume_sliders()
	_set_check("the gate wrote nothing into the save directory",
		_save_listing() == saves_before)
	_finish()


# --- the checks ---------------------------------------------------------------------------

func _check_the_buses() -> void:
	_set_check("the layout carries exactly four buses", AudioServer.bus_count == 4)
	_set_check("bus zero is Master", AudioServer.get_bus_name(0) == "Master")
	for bus: StringName in [SoundScript.BUS_AMBIENT, SoundScript.BUS_EFFECTS,
			SoundScript.BUS_UI]:
		var index: int = AudioServer.get_bus_index(String(bus))
		_set_check("the %s bus exists" % bus, index > 0)
		if index > 0:
			_set_check("the %s bus sends into Master" % bus,
				AudioServer.get_bus_send(index) == &"Master")


func _check_every_stream() -> void:
	var missing: Array[String] = []
	var total := 0
	for id: StringName in Sound.ids():
		var entry: Dictionary = Sound.entry(id)
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			total += 1
			if Sound.stream_for(path) == null:
				missing.append("%s (%s)" % [path, id])
	for line: String in missing:
		push_error("SOUND: stream did not load: %s" % line)
	print("SOUND streams=%d ids=%d" % [total, Sound.ids().size()])
	_set_check("every file in the library decoded", missing.is_empty())
	_set_check("the library is not empty", Sound.ids().size() > 0)


## THE IMPORT FLAGS, WHICH ONLY A REAL ENGINE KNOWS. A bed whose .import says loop=false
## plays forty five seconds of birdsong and then leaves the ranch silent for the rest of
## the phase, and no unit test can see it: the flag lives in the imported resource, not in
## the source file and not in LIBRARY.
func _check_the_loop_flags() -> void:
	var wrong: Array[String] = []
	for id: StringName in Sound.ids():
		var entry: Dictionary = Sound.entry(id)
		var wants_loop: bool = bool(entry.get("loop", false))
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			var stream: AudioStream = Sound.stream_for(path)
			if stream == null:
				continue
			var loops := false
			if stream is AudioStreamOggVorbis:
				loops = (stream as AudioStreamOggVorbis).loop
			elif stream is AudioStreamWAV:
				loops = (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
			else:
				wrong.append("%s is neither ogg nor wav" % path)
				continue
			if loops != wants_loop:
				wrong.append("%s imported loop=%s, library says %s"
					% [path, loops, wants_loop])
	for line: String in wrong:
		push_error("SOUND: %s" % line)
	_set_check("every bed imported as a loop and every one shot did not", wrong.is_empty())


func _check_the_verbs() -> void:
	var refused: Array[String] = []
	for id: StringName in Sound.ids():
		if not Sound.play(id):
			refused.append("play(%s)" % id)
		if not Sound.play_at(id, Vector3(3.0, 0.0, -4.0)):
			refused.append("play_at(%s)" % id)
	Sound.stop_all()
	for line: String in refused:
		push_error("SOUND: %s was refused" % line)
	_set_check("play and play_at accept every id in the library", refused.is_empty())

	# Every phase, then every zone on top of every phase, then back to nothing. Any
	# combination that wanted more beds than there are voices would push_error here.
	var beds_seen := 0
	for phase: int in [WorldStateScript.Phase.DAWN, WorldStateScript.Phase.DAY,
			WorldStateScript.Phase.DUSK, WorldStateScript.Phase.NIGHT]:
		Sound.ambient_set_phase(phase)
		beds_seen = maxi(beds_seen, Sound.active_bed_ids().size())
		for zone: StringName in [SoundScript.ZONE_STRIP, SoundScript.ZONE_CASINO,
				SoundScript.ZONE_NONE]:
			Sound.ambient_set_zone(zone)
			beds_seen = maxi(beds_seen, Sound.active_bed_ids().size())
	print("SOUND beds_peak=%d voices=%d" % [beds_seen, SoundScript.BED_VOICES])
	_set_check("no phase and zone pair outran the bed voices",
		beds_seen > 0 and beds_seen <= SoundScript.BED_VOICES)

	Sound.stop_all()
	_set_check("stop_all clears the beds and the bookkeeping",
		Sound.active_bed_ids().is_empty() and Sound.current_phase() == -1
			and Sound.current_zone() == SoundScript.ZONE_NONE)

	var crowd_started: bool = Sound.play_loop(&"race_crowd_loop")
	var gallop_started: bool = Sound.play_loop(&"race_gallop")
	_set_check("the held loops start", crowd_started and gallop_started)
	Sound.stop_loop(&"race_crowd_loop")
	Sound.stop_loop(&"race_gallop")
	_set_check("the held loops stop", Sound.looping_ids().is_empty())


## THE THIRTEENTH VOICE. A pool that grew instead of stealing would allocate a player per
## trigger for as long as the session lasts, and the symptom would be a machine getting
## slower over an hour rather than anything a test would notice.
func _check_the_pools() -> void:
	Sound.stop_all()
	for i in range(SoundScript.POOL_2D + 1):
		Sound.play(&"ui_move")
	_set_check("the 2D pool steals rather than growing",
		Sound.pool_2d_size() == SoundScript.POOL_2D)
	for i in range(SoundScript.POOL_3D + 1):
		Sound.play_at(&"hoofsteps_grass", Vector3(float(i), 0.0, 0.0))
	_set_check("the 3D pool steals rather than growing",
		Sound.pool_3d_size() == SoundScript.POOL_3D)
	Sound.stop_all()


func _check_the_volume_sliders() -> void:
	var settings: Settings = SettingsScript.new()
	settings.master_volume = 1.0
	settings.ambient_volume = 0.5
	settings.effects_volume = 0.0
	settings.apply_audio()
	var ambient: int = AudioServer.get_bus_index("Ambient")
	var effects: int = AudioServer.get_bus_index("Effects")
	var ui: int = AudioServer.get_bus_index("UI")
	_set_check("the ambient slider reaches its bus",
		ambient > 0 and not AudioServer.is_bus_mute(ambient)
			and absf(AudioServer.get_bus_volume_db(ambient) - linear_to_db(0.5)) < 0.05)
	_set_check("zero on the effects slider mutes effects and the menus with it",
		effects > 0 and ui > 0 and AudioServer.is_bus_mute(effects)
			and AudioServer.is_bus_mute(ui))
	settings.effects_volume = 1.0
	settings.apply_audio()
	# AudioSafety muted Master for this headless run and nothing here may undo that.
	_set_check("Master is still muted for an automated run",
		AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))


# --- plumbing ------------------------------------------------------------------------------

func _save_listing() -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return PackedStringArray()
	return DirAccess.get_files_at(SAVE_DIR)


func _set_check(label: String, ok: bool) -> void:
	if _checks.has(label):
		_duplicates.append(label)
	_checks[label] = ok


func _finish() -> void:
	var failed: Array[String] = []
	for label in _checks:
		if not bool(_checks[label]):
			failed.append(String(label))
	for label in _duplicates:
		failed.append("duplicate check label: %s" % label)
	for label in _checks:
		print("SOUND %s %s" % ["ok  " if bool(_checks[label]) else "FAIL", label])
	var all_ok: bool = failed.is_empty()
	# Marker after the verdict, exit code IS the verdict. See docs/testing.md.
	if all_ok:
		print("SOUND_OK ids=%d" % Sound.ids().size())
	else:
		print("SOUND_FAILED ids=%d failed=%d" % [Sound.ids().size(), failed.size()])
	get_tree().quit(0 if all_ok else 1)
```

- [ ] **Step 3: Run the gate**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn; echo "exit: $?"
```

Expected: a `SOUND ok` line per check, then `SOUND_OK ids=36` (thirty six ids over forty five files; read the number off the run rather than trusting this one, and put what it printed into the docs in Step 5) and exit 0.

If it hangs with no marker at all, that is the failure `GateWatchdog` exists for: something raised mid coroutine. The watchdog will print and exit after 120 s; the `push_error` lines above the marker name the cause.

If `the gate wrote nothing into the save directory` fails, something in the autoload chain is writing a save at boot. That is the parked defect and this gate has just caught it doing something new: do NOT relax the check, report it.

- [ ] **Step 4: Prove the gate has teeth**

A gate that cannot fail is not a gate. Break one thing and confirm it says so:

```bash
sed -i 's/^loop=true/loop=false/' game/assets/audio/ambient/bed_wind_soft.ogg.import
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn; echo "expected non zero: $?"
```

Expected: `SOUND FAIL every bed imported as a loop and every one shot did not`, `SOUND_FAILED ...`, and a non zero exit. Then put it back:

```bash
sed -i 's/^loop=false/loop=true/' game/assets/audio/ambient/bed_wind_soft.ogg.import
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn; echo "expected 0: $?"
```

- [ ] **Step 5: Document the gate in `docs/testing.md`**

Add a section directly after the story gate's section (which ends at the line `Expect \`STORY_OK checks=55\`; the exit code is the verdict.`), in the same prose shape every other gate section uses:

```markdown
## The sound gate

`game/scenes/test/sound_test.tscn` is the one gate in this project that hosts
nothing. Every other gate instances `world/ranch.tscn`, because what it is
checking is a ranch. This one is checking four autoloads and a directory of
files, and there is a second reason to keep the ranch out of it: a gate that
boots the ranch is a gate that can write a live save, which is a defect this
project already has parked. The gate proves its own innocence rather than
promising it, by listing `user://saves` on the way in and on the way out and
asserting the two listings match.

What it checks that a unit test cannot see:

* the four buses actually came out of `game/default_bus_layout.tres` and all
  three sub buses send into Master, which is what makes `AudioSafety`'s single
  Master mute cover the whole game
* every file named by `Sound.LIBRARY` decoded into a real `AudioStream`; a
  truncated download or a corrupt ogg fails here and nowhere else
* every bed imported with `loop=true` and every one shot with `loop=false`.
  This flag lives in the committed `.import` sidecar, not in the source file
  and not in `LIBRARY`, so no unit test can reach it. A bed that imported
  without it plays its forty five seconds once and then leaves the ranch
  silent for the rest of the phase.
* all five verbs accept every id, and every phase crossed with every zone
  wants no more simultaneous beds than there are bed voices
* the player pools steal their oldest voice rather than growing. A pool that
  grew would allocate a player per trigger for as long as the session lasted,
  and the symptom would be a machine getting slower over an hour rather than
  anything that looks like a bug
* the two new volume sliders reach their buses, zero on the effects slider
  takes the menu ticks down with it, and nothing in the settings path undoes
  `AudioSafety`'s mute on an automated run

Run it with:

```
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn
```

Expect `SOUND_OK ids=<the number the run prints>`; the exit code is the verdict.

## The sound pipeline

`tools/sound_manifest.txt` is the curation and the only place a sound is
chosen. One row per file, `dest|source_url|recipe`, with the source's own
description and two or three alternate candidates in the comment above it, so
swapping any sound in the game is editing one URL and running one command:

```
bash tools/fetch_sounds.sh --only ambient/bed_dawn_chorus.ogg
```

`tools/fetch_sounds.sh` is the only thing that downloads. It caches raw
sources in `tools/sound_cache/` (gitignored), runs each row's ffmpeg recipe,
writes the processed file under `game/assets/audio/`, and regenerates
`game/assets/audio/sound_report.txt`. It is idempotent: a dest that already
exists is skipped unless `--force` or `--only` names it.

The report is the verdict, not a log. Every processed file is measured with
`ebur128` and written as PASS or FAIL against the row's own loudness target,
under a true peak ceiling of -1.5 dBTP. A FAIL row exits the script non zero,
and `game/test/test_sound_library.gd` asserts that every file the game plays
appears in that report with PASS, so a clipping sound cannot be committed and
forgotten.

Loudness targets: ambient beds -24 LUFS, world and casino SFX -18, UI -20.

Sources, all fetched with no account and no login: the BBC Sound Effects
archive (`https://sound-effects.bbcrewind.co.uk`, media at
`https://sound-effects-media.bbcrewind.co.uk/wav/<ID>.wav`) for everything
ambient, animal, mechanical and crowd; Kenney (`https://kenney.nl`, CC0
direct zips) for the menu ticks and the casino chips and cards.

`game/test/test_sound_library.gd` is what keeps the manifest, `Sound.LIBRARY`
and the report one list: a manifest row nobody plays is a file that was
downloaded and forgotten, and a `LIBRARY` path with no manifest row is a file
nobody can reproduce on a clean checkout.
```

Also add `sound` to the gate list wherever `docs/testing.md` enumerates the scene gates, and update the count if it states one.

- [ ] **Step 6: Raise the floor, and read the number off the run**

Never guess this number.

```bash
bash tools/run_tests.sh 2>&1 | tee /tmp/sound-suite.log
grep -E "^Tests[[:space:]]" /tmp/sound-suite.log
```

Put exactly the number that run printed into `tools/run_tests.sh` at line 186:

```bash
MIN_TESTS="${FILLY_MIN_TESTS:-<the number the run above printed>}"
```

Then prove the guard still bites, both ways:

```bash
FILLY_MIN_TESTS=99999 bash tools/run_tests.sh; echo "expected non zero: $?"
bash tools/run_tests.sh; echo "expected 0: $?"
```

The first must fail with the "below this suite's floor" message; the second must pass.

- [ ] **Step 7: The whole board, green**

```bash
for scene in smoke camera walk world region market collection ledger depot creation casino story sound; do
  printf '%-12s ' "$scene"
  path="scenes/test/${scene}_test.tscn"
  [ "$scene" = "smoke" ] && path="scenes/test/smoke.tscn"
  tools/bin/godot --headless --audio-driver Dummy --path game "$path" 2>&1 \
    | grep -E "_OK|_FAILED" | tail -1
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -1
```

Every line must be an `_OK`, including the new `SOUND_OK`, and the ranch must print `RANCH_OK ponies=49 props=111 assets=present`. The census must be untouched: this slice added no prop and no pony.

- [ ] **Step 8: Commit**

```bash
tools/bin/godot --headless --path game --import
git add game/scenes/test/sound_test.gd game/scenes/test/sound_test.gd.uid \
  game/scenes/test/sound_test.tscn docs/testing.md tools/run_tests.sh
git commit -m "$(cat <<'MSG'
test: the sound gate, and the floor raised to meet it

A gate that hosts nothing, so it cannot be another way for a boot to write a
live save, and proves it by listing the save directory on the way in and out.
It catches the two things no unit test can see: a file that did not decode,
and a bed whose .import forgot to loop.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WDozY2JqdaZNapYzxyHraR
MSG
)"
```

---

## Done means

- `bash tools/run_tests.sh` green at the raised floor, and `FILLY_MIN_TESTS=99999` still red.
- `RANCH_OK ponies=49 props=111 assets=present`, unchanged, and every one of the fourteen gates `_OK`, including the new `SOUND_OK`.
- `bash tools/fetch_sounds.sh` on a clean `tools/sound_cache/` reproduces every committed file, and every row of `game/assets/audio/sound_report.txt` reads PASS.
- Walking on the ranch at dawn is birdsong and wind; walking at night is crickets, a distant owl and wind. Walking onto the Strip adds a lamp hum and a fairground murmur without taking the meadow away. Sitting down at a table adds the arcade room.
- Hooves under every step, turf out on the ranch and hard on the Strip, at a rate that follows how fast she is actually going.
- Every menu ticks, every confirm and every refusal sounds different, and the settings page has Ambience and Effects rows that a gamepad can drive with no mouse.
- The reels tick per symbol and clunk when each one lands, the wheel ratchets past each pocket and settles, cards slide on the deal and turn over on a hit, a bet clinks, a race holds a crowd while it runs and cheers when it settles, and there is exactly ONE slots stinger.
- No pony makes a horse noise anywhere in the build.
- No em dash and no double hyphen in a single new code line, and the word this project does not use appears nowhere.

## Parked for the owner

1. **Every individual sound choice.** Every slot in `tools/sound_manifest.txt` records its source's own description plus two or three alternates. Swapping one is editing a URL and running `bash tools/fetch_sounds.sh --only <dest>`. The build loop cannot listen; the owner's playtest is the real ear and this is the knob it turns.
2. **Music, yes or no, and its register if yes.** Out of scope by the spec. The Strip hum, the arcade room and the slots stinger carry the casino; the ranch is carried by nature. If the answer is yes, it is its own slice.
3. **Hoofstep loudness and rate.** `Player.STEP_STRIDE` is 1.1 m and `hoofsteps_*` are mixed at -8 dB. This is the most heard sound in the game and the most taste sensitive; both numbers are one line each.
4. **Whether a big slots win wants more celebration.** Deliberately modest: one stinger, no escalation, and a loss stays silent. The house publishes its edge on the wall outside and does not need to lie with sound. The owner may want more juice.
5. **UI tick character.** Currently Kenney's woody clicks and a paper scratch for the page turn, chosen for softness over the pack's beeps. `MenuStyle.tick_*()` is six lines and changing all of them changes the whole game's menu character.
6. **The two new sliders' defaults.** Both start wide open at 1.0, and the UI bus rides the effects slider rather than getting a fourth knob. If ambience wants to sit lower out of the box, that is `Settings.ambient_volume`'s initialiser.
7. **Pony voice.** Cut from this slice by owner directive: these ponies are cartoon characters and a real mare's neigh breaks the register. If they should ever make a sound, it is a cartoon vocalisation and it belongs beside the parked placeholder voice line, not in a foley library.
8. **The entry shape departs from spec section 4.2 in one way:** an entry carries one always present `paths: PackedStringArray` rather than a `path` plus an optional `variants` list. Same information, one shape instead of two, one rule for the corpus test instead of a branch.
