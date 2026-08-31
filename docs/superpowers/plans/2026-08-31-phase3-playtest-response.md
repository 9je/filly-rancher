# Phase 3 Playtest Response Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the four bugs and the six usability holes the owner filed after playing slices 1 and 2 on 2026-08-31: a cutie mark that renders upside down on both flanks, an E key that is ambiguous near ponies and plots, a Palace that flickers where it meets the ground and a marquee that runs off its own roof; then one shared menu look with hints for the device actually in the player's hands, a casino that can be played without reading a document, a bits onboarding path legible in the first two minutes, a racing screen where your pony IS your bet, mane variety drawn from models already on disk, and a vendor at the Market and a teller at the cage.

**Architecture:** Nothing here invents a system. Every fix goes through a seam this codebase already has. The mark is a `Decal` basis with a documented UV convention and helpers a headless test can read. The interact verb becomes ONE pure resolver (`game/world/interaction.gd`) that scores candidates and answers with exactly one, plus a persistent HUD prompt that says what E will do; the five `_update_*_interaction()` functions and their six latches go away. The menu style becomes one static helper (`game/ui/menu_style.gd`) reading one static device tracker (`game/systems/input_device.gd`, an autoload with static state); every menu keeps its draw and emit shape and `ranch.gd` keeps every transaction. Racing loses a whole tab: the ENTER tab becomes a form guide of every penned pony priced off `RaceCard` itself, and `start_race()` drops its lane argument. Mane variety is a curated pool of `res://` paths on `StockPalette`, an optional model path argument on `PonyVisuals.build()`, and the `PlayerLook.mane_style` field that has been saved and unread since slice 1. The vendor and the teller are `Attendant` nodes: `PonyVisuals.build` plus `StockTint`, exactly what `RaceRunner` is, with nothing a beam can grab.

**Tech Stack:** Godot 4.5.2, GDScript, GUT 9.5.0, the project's headless gate conventions.

**Spec:** `docs/superpowers/specs/2026-08-30-phase3-rainbow-factory-design.md`. The racing rework in Task 6 implements the freshly amended casino paragraph verbatim: "your pony IS your bet: the enter screen lists every penned pony with her live odds (a form guide for your whole roster), you pick one and a stake, and she runs against five Company owned runners. You can only back your own entrant; winning pays her odds. Side bets on other lanes are out (playtest verdict 2026-08-31: betting against your own pony felt wrong)." Everything else in this plan is a response to the owner's 2026-08-31 playtest list, which is reproduced task by task below.

## Global Constraints

- **No em dash and no double hyphen in ANY player facing string, nor in new code, comments, docs or data.** ASCII banners like `# --- x ---` are exempt, and so are command line flags. Use ";" or ":" or commas. Single hyphens inside a word ("D-pad") are fine and already ship. The files you are editing are full of pre existing ` -- ` in their own comments: leave those alone, and do not copy the habit into a line you write.
- **Tone.** Slime Rancher for the ranching feel, Stardew Valley for the town and the forever loop, gambling for fun, a dark humour register. Casino copy is glitzy corporate: "Spectra Palace, proudly sponsored by Cloudsdale Weather Corporation". Company letters read like an HR poster. Never grim, never sneering at the player.
- **Explicit type annotations wherever `:=` cannot infer the type.** Godot 4.5 promotes `INFERENCE_ON_VARIANT` to an error on the preload dependency compile path; GUT's loader does not catch it, `tools/run_tests.sh`'s parse sweep does.
- **Preload by `res://` path, never by the global `class_name`, in production code AND in test code.** Every construction (`X.new()`), every static call (`X.some_static()`) and every constant or enum read (`X.SOME_CONST`) goes through a `const XScript := preload("res://...")` at the top of the file. A bare `class_name` may appear ONLY as a type annotation (`var s: MenuStyle = ...`), because an annotation does not need the class cache, and the class cache lives in the gitignored `game/.godot/`.
- **Every new `.gd` gets its `.uid` sidecar committed.** After creating a script run `tools/bin/godot --headless --path game --import` once and `git add` the generated `game/**/*.gd.uid`.
- **Menus draw and emit; `ranch.gd` transacts and pays.** No file under `game/ui/` may reference `Economy`, `Casino`, `Ledger`, `GameState`, `Pen` or `PonyInstance`. Each menu is handed Callables and hands back signals, exactly as `game/ui/depot_menu.gd` is. A menu must never write `get_tree().paused` itself; `ranch.gd` owns pause through `_on_menu_opened_any()` and `_on_menu_closed()`. (`game/ui/creation_screen.gd` is the one shipped exception and this plan does not change that.)
- **NO PONY EVER DIES.** Only `Pony._state_leaving` may call `queue_free()` on a pony. Nothing in this plan frees, harms, moves or removes a pony. The vendor and the teller in Task 8 are NOT `Pony` nodes and must never become them.
- **Gates print their marker only after the verdict is decided; the exit code IS the verdict.** Run as `tools/bin/godot --headless --audio-driver Dummy --path game <scene>`.
- **Every count consequence is carried through the gates and the docs in the same commit that causes it.** The ranch gate prints `RANCH_OK ponies=49 props=60 assets=present` today. The vendor and the teller must NOT move either number: they are children of a new `Attendants` node, which is neither `Props` nor `Buildings`, and Task 8 adds an explicit `RANCH attendants=2` line and a census check saying so out loud. Gate check counts that move (`CASINO_OK checks=`, `CREATION_OK checks=`) are re-read from the gate's own output and written into `docs/testing.md` in the task that moves them; never guess one.
- **`MIN_TESTS` in `tools/run_tests.sh` stands at 1020 today.** Raise it in the final task to the number the suite actually reports; do not guess it.
- **Branch: `phase3-playtest`.** Commit after every task with `git commit -F <file>`; conventional prefixes (`feat:`, `fix:`, `test:`, `docs:`). Run `bash tools/run_tests.sh` (no `FILLY_SKIP_SWEEP`) before calling any task finished.

---

## The playtest list this plan answers

Filed by the owner on 2026-08-31 after playing slices 1 and 2. Each item names the task that closes it.

| # | Report | Task |
|---|---|---|
| 1 | The cutie mark renders upside down on the flanks (screenshot confirmed: a heart drawn point down shows point up) | 1 |
| 2 | "pressing e to build a new paddock doesnt always work; gets confused if you got ponies" | 2 |
| 3 | Z fighting at the Palace base: a flickering skirt where the building meets the terrain | 3 |
| 4 | The marquee is unreadable and clips the roof | 3 |
| 5 | Menu polish: one shared style, and hints for the device in your hands rather than both at once | 4 |
| 6 | The casino cannot be played without reading a document | 5 |
| 7 | How do I earn money is not legible in the first minutes | 7 |
| 8 | Racing redesign: your pony IS your bet | 6 |
| 9 | Every pony has the same mane | 8 |
| 10 | Nobody is standing behind the Market counter or the casino cage | 8 |

---

## What is on disk today

Read this before starting. Everything below was verified against the tree this plan was written on (`master`, `687a441`).

**The mark.** `game/systems/cutie_mark.gd` hangs two `Decal` nodes off a `BoneAttachment3D` on the `Pelvis` bone. `_flank_transform(model, side)` builds the basis, `FLANK` is `Vector3(0.26, 0.86, 0.22)` in model space and `DECAL_SIZE` is `Vector3(0.30, 0.26, 0.30)`. The current basis is `Basis(Vector3(0, 0, -side), Vector3(side, 0, 0), Vector3(0, 1, 0))`, whose determinant is `-1` for both flanks. `game/test/test_cutie_mark.gd` asserts the two decals exist, carry the texture and sit on opposite sides; it says nothing at all about which way up the drawing lands. `game/systems/mark_paint.gd` is the 64 by 64 drawing engine (`SIZE`, `FORMAT`, `blank()`, `copy_of()`, `dot()`, `stroke()`, `is_blank()`, `equal()`).

**The interact verb.** `game/world/ranch.gd`'s `_physics_process` calls five handlers in a fixed order: `_update_plot_interaction()`, `_update_market_interaction()`, `_update_board_interaction()`, `_update_depot_interaction()`, `_update_palace_interaction()`, then `enforce_casino_ban()` and the button free `_update_gate_prompt()`. Each handler asks `_no_other_menu_open()`, keeps its own "fire once per approach" latch (`_prompt_slot`, `_market_prompted`, `_board_prompted`, `_depot_prompted`, `_palace_prompted`, `_gate_prompted`), and four of the five additionally require `_prompt_slot == null` before reacting to `Input.is_action_just_pressed(&"interact")`. Radii: `MARKET_RADIUS` 4.5, `BOARD_RADIUS` 3.0, `DEPOT_RADIUS` 4.0, `PALACE_RADIUS` 5.0, all measured XZ to the building node origin. Plot membership is an `Area3D` overlap (`player in slot.get_overlapping_bodies()`), first match wins. `is_near_board()` hard codes `and not is_near_market()`. The Palace prompt is gated on `casino_can_enter()` but the PRESS is not. `_prompt_slot` goes stale whenever a menu is open, because `_update_plot_interaction()` returns before assigning it. **There is no HUD prompt at all:** every one of those six strings goes through `ranch._toast()` to `HUD.toast()`, a queued label that fades after `TOAST_HOLD + TOAST_FADE` (3.1 s), so a player standing on a plot sees "Press E / X to build here." once and then nothing.

**The buildings.** `game/world/building.gd` assembles a gabled shell out of `_slab()` boxes. Its `Floor` slab is `Vector3(width, 0.14, depth)` centred at `Vector3(0, 0.07, 0)`, so its bottom face sits at exactly local y = 0. `Props.seat(node, ground)` then drops the node until the bottom of its world AABB is `SINK_BIAS` (0.05 m) below the ground height at ONE point. `ranch.gd`'s `PALACE_MAX_RELIEF` is 0.65 and its comment records the measurement: the terrain under `Buildings/Palace` (world origin `(-10, 0, 61.6)`, `width` 14.0, `depth` 9.0, `wall_height` 3.6, `ridge_height` 4.6) has 0.633 m of relief across the footprint, the flattest a 14 by 9 m rectangle gets anywhere inside the Strip. 0.633 m of relief against a floor slab 0.14 m thick is the flicker.

**The marquee.** `game/world/strip.gd`'s `_marquee()` is a bare `Label3D` at `MARQUEE_AT = Vector3(-10.0, 5.4, 56.2)` carrying `CasinoSign.MARQUEE`, a 66 character single line at `font_size` 64 and `pixel_size` `MARQUEE_SIZE / 64.0` (0.0086 m per pixel), which renders about 18 m wide against a 14 m building whose ridge is at 4.6 m. It has no board behind it, no width limit and no wrapping.

**The menus.** `game/ui/table_menu.gd` is the base of the four casino tables; `casino_menu.gd`, `build_menu.gd`, `market_menu.gd`, `depot_menu.gd` and `pause_menu.gd` each declare their own colours and their own footer. Three different footers ship today: `"  ← → / D-pad  tab      ↑ ↓  choose      Enter / A  confirm      Esc / B  back"` (market, depot, pause), `"  ↑ ↓ / D-pad  choose      Enter / A  build      Esc / B  back"` (build), and `"  up down  choose      left right  tab      Enter / A  confirm      Esc / B  leave"` (the casino suite). Every one of them prints both control schemes at once. `game/ui/hud.gd`'s `HINTS` card is a three column grid doing the same thing on purpose ("the build is handed to two people and only one of them is going to be at the keyboard"). `game/project.godot` has an `[autoload]` block holding `AudioSafety` and `GameState`.

**Racing.** `game/ui/race_menu.gd` has three tabs, `Tab { ENTER, BET, CARD }`, and two signals, `entrant_chosen(uid)` and `race_requested(uid, lane, stake)`. `ranch.gd` answers with `race_entrants()` (uid, name, happiness for every pony in every pen), `_on_entrant_chosen()` (builds a field, caches it in `_priced_uid`/`_priced_field`, pushes six prices through `race_menu.set_field()`), and `start_race(uid, lane, stake)`. `RaceCard` already publishes `win_chances(field)`, `decimal_odds(field, lane)`, `odds_text(odds)`, `PLAYER_LANE` (0), `LANES` (6) and `TAKEOUT` (0.06), and the takeout is identical on every lane by construction, so a form guide priced off `decimal_odds(field, PLAYER_LANE)` is exactly the price the settle uses.

**The look pipeline.** `game/systems/stock_tint.gd` matches surfaces by material name: coat is `body` and `wings`, mane is `hair` and `tail`, eyes are `eyeball_l` and `eyeball_r`; anything else gets no override. `game/systems/stock_palette.gd` holds `IDS` (the three hidden records), the colour rows and `draw_triple(rng)`. `game/actors/pony/pony_visuals.gd`'s `build(data)` takes ONLY a `PonyData` and resolves `data.model_path`. All three hidden records in `game/data/hidden/` point at `res://assets/converted/ponies/pokeypierce.glb`, which is why every stock pony has the same mane; so does the player, whose `Player.pony_id` is `&"stock_shy"`. There are 43 converted `.glb` files and 43 named `.tres` records, and the set difference is empty: every model on disk is already some named character's model, `pokeypierce.glb` included. **`game/systems/player_look.gd` already declares, saves and restores `var mane_style := 0`**, documented as "the field exists so a second sourced style is data rather than a schema change", and nothing anywhere reads it. `PonyInstance.from_dict()` rebuilds `stock` with exactly `coat`, `mane` and `eyes` and drops every other key.

**The four `PonyVisuals.build()` call sites**, which is the whole surface a model override has to cover: `game/actors/pony/pony.gd:_apply_data()` (every roaming and penned pony), `game/actors/player/player.gd:_build_visuals()` (the player, which also calls `_place_beam_origin()` to put the beam on the horn tip it measures off the model), `game/ui/creation_screen.gd:_build_model()` (the turntable) and `game/world/race_runner.gd:dress()` (the six lanes).

**The gates.** `market_test`, `region_test`, `world_test`, `collection_test`, `ledger_test`, `depot_test`, `creation_test` and `casino_test` all host `world/ranch.tscn`, await `gate_report_finished`, keep a `_checks` dictionary with a duplicate label guard and print `<NAME>_OK checks=<n>` after the verdict. `casino_test` expects 70 checks today and `creation_test` 89; both move in this plan.

---

## File structure

**New:**

| File | Responsibility |
|---|---|
| `game/world/interaction.gd` | `Interaction`: the pure resolver. Candidates in, exactly one winner out, and the prompt line that names it. No nodes, no `Input`, no scene. |
| `game/systems/input_device.gd` | `InputDevice`: which thing is in the player's hands, as static state, plus the glyph table every hint reads. Registered as an autoload for the `_input()` hook. |
| `game/ui/menu_style.gd` | `MenuStyle`: one palette, one row treatment, one tab strip and one footer builder for every panel in the game. |
| `game/world/attendant.gd` | `Attendant`: a dressed pony body standing behind a counter. Not a `Pony`, nothing to grab, no census weight. |
| `game/test/test_interaction.gd` | The resolver's priority order and every overlap case. |
| `game/test/test_input_device.gd` | The device tracker, the deadzone, and the glyph table against the real `InputMap`. |
| `game/test/test_menu_style.gd` | The shared style and the device aware footer. |
| `game/test/test_attendant.gd` | The vendor and the teller build, dress, face and stay out of the census. |
| `game/test/test_mane_pool.gd` | Every model in the curated pool tints, animates and stands like the base one. |

**Modified:** `game/systems/cutie_mark.gd`, `game/systems/mark_paint.gd`, `game/systems/stock_palette.gd`, `game/systems/pony_instance.gd`, `game/systems/letters.gd`, `game/systems/request_board.gd`, `game/systems/casino_sign.gd`, `game/world/building.gd`, `game/world/strip.gd`, `game/world/spawner.gd`, `game/world/race_runner.gd`, `game/world/ranch.gd`, `game/world/ranch.tscn`, `game/actors/pony/pony.gd`, `game/actors/pony/pony_visuals.gd`, `game/actors/player/player.gd`, `game/ui/hud.gd`, `game/ui/hud.tscn`, `game/ui/table_menu.gd`, `game/ui/casino_menu.gd`, `game/ui/race_menu.gd`, `game/ui/build_menu.gd`, `game/ui/market_menu.gd`, `game/ui/depot_menu.gd`, `game/ui/pause_menu.gd`, `game/ui/creation_screen.gd`, `game/ui/creation_screen.tscn`, `game/project.godot`, `game/scenes/test/model_gallery.gd`, `game/scenes/test/creation_test.gd`, `game/scenes/test/casino_test.gd`, and the test files each task names; plus `tools/run_tests.sh` and `docs/testing.md` in Task 9.

**Why this order.** The four bugs come first because they are wrong output the owner can see, and because Task 2's HUD prompt is the thing Task 7's onboarding checklist sits next to. The shared menu style (Task 4) comes before the two menu reworks (Tasks 5 and 6) so those are written in the finished style rather than restyled twice. Variety and the attendants (Task 8) come last of the feature work because they touch the same `PonyVisuals.build()` seam and the same census the gates assert on, and Task 9 is where every count that moved is written down.

---

### Task 1: The mark, right way up on both flanks

**Files:**
- Modify: `game/systems/cutie_mark.gd`, `game/systems/mark_paint.gd`, `game/scenes/test/model_gallery.gd`, `game/scenes/test/creation_test.gd`
- Test: `game/test/test_cutie_mark.gd`, `game/test/test_mark_paint.gd`

**Interfaces:**
- Consumes: `MarkPaint.SIZE` (64), `MarkPaint.blank() -> Image`, `MarkPaint.stroke(image: Image, from: Vector2i, to: Vector2i, colour: Color, radius: int) -> void`, `MarkPaint.is_blank(image: Image) -> bool`, `CutieMark.apply(model: Node3D, mark: Image) -> int`, `CutieMark.decals_of(model: Node3D) -> Array[Decal]`, `CutieMark.LEFT_NAME` (`&"CutieMarkLeft"`), `CutieMark.RIGHT_NAME` (`&"CutieMarkRight"`).
- Produces:
  - `MarkPaint.orientation_probe(colour: Color = Color(0.10, 0.10, 0.12, 1.0)) -> Image`.
  - `CutieMark.image_up(decal: Decal) -> Vector3`, `CutieMark.image_right(decal: Decal) -> Vector3`, `CutieMark.image_out(decal: Decal) -> Vector3`, `CutieMark.is_mirrored(decal: Decal) -> bool`, `CutieMark.image_point_to_world(decal: Decal, u: float, v: float) -> Vector3`.
  - `model_gallery.tscn` gains a `--mark` mode printing `GALLERY_MARK_OK count=3`.

**The bug, and why the fix is one column of one basis.** A `Decal` projects along its own local minus Y and samples its albedo across the local XZ plane: sampled U runs with local plus X, sampled V runs with local plus Z, and V = 0 is the TOP row of the image. So the world direction the drawing's own "up" points in is the decal's MINUS Z axis, and its "right" is the PLUS X axis. `_flank_transform()` currently passes `Vector3(0.0, 1.0, 0.0)` as the local Z column, with the comment "local Z runs up the barrel", which puts image up at world DOWN. That basis is also left handed (its determinant is minus one on both flanks), so the drawing is mirrored as well. A vertical flip plus a mirror is a half turn, and a half turn is exactly what the owner's screenshot shows: a heart drawn point down comes back point up. Changing that one column to `Vector3(0.0, -1.0, 0.0)` puts image up at world up AND makes the basis right handed, which fixes both halves at once.

**The decision this task also has to record: the right flank REPEATS the drawing, it does not mirror it.** With the corrected basis, image right is world minus Z on the plus X flank and world plus Z on the minus X flank; a viewer standing outside either flank has the pony's nose or her tail on her own right respectively, and in both cases the image's right lands on the viewer's right. So a letter reads as a letter from both sides and a heart reads as a heart from both sides, which is what a cutie mark is for. The cost is that an asymmetric mark is not physically the same paint seen from two sides; that is the correct trade for a game about drawing your own mark and being able to read it.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_mark_paint.gd`:

```gdscript
func test_the_orientation_probe_is_not_blank_and_is_asymmetric() -> void:
	var probe: Image = MarkPaintScript.orientation_probe()
	assert_false(MarkPaintScript.is_blank(probe), "the probe has to be visible to prove anything")
	var top_left := 0
	var bottom_right := 0
	for y in MarkPaintScript.SIZE:
		for x in MarkPaintScript.SIZE:
			if probe.get_pixel(x, y).a <= 0.0:
				continue
			if x < MarkPaintScript.SIZE / 2 and y < MarkPaintScript.SIZE / 2:
				top_left += 1
			elif x >= MarkPaintScript.SIZE / 2 and y >= MarkPaintScript.SIZE / 2:
				bottom_right += 1
	assert_gt(top_left, bottom_right * 2,
		"the probe must be top heavy and left heavy, or it cannot show a flip or a mirror")
```

(`test_mark_paint.gd` already declares `const MarkPaintScript := preload("res://systems/mark_paint.gd")`; check that it does before adding, and add the line if it does not.)

Append to `game/test/test_cutie_mark.gd`:

```gdscript
## THE 2026-08-31 PLAYTEST BUG. A Decal samples its albedo across its own local XZ plane
## with V = 0 at the TOP of the image, so the drawing's own "up" is the decal's MINUS Z
## axis. The shipped basis passed +Y as that column, which pointed image up at world DOWN,
## and it was left handed besides, which mirrored the drawing. A flip plus a mirror is a
## half turn, and a half turn is why a heart drawn point down came back point up.
func test_the_drawing_lands_right_way_up_on_both_flanks() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	var decals: Array[Decal] = CutieMarkScript.decals_of(_model)
	assert_eq(decals.size(), 2)
	for decal in decals:
		assert_gt(CutieMarkScript.image_up(decal).dot(Vector3.UP), 0.99,
			"the top of the canvas must point at the sky on %s" % decal.name)


func test_neither_flank_mirrors_the_drawing() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	for decal in CutieMarkScript.decals_of(_model):
		assert_false(CutieMarkScript.is_mirrored(decal),
			"%s is showing the drawing back to front" % decal.name)


func test_the_projection_runs_from_the_flank_into_the_pony() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	for decal in CutieMarkScript.decals_of(_model):
		var out_local: Vector3 = _model.global_transform.basis.inverse() \
			* CutieMarkScript.image_out(decal)
		var side: float = signf(_model.to_local(decal.global_position).x)
		assert_gt(out_local.x * side, 0.99,
			"%s must face out of the flank it is on, so it projects inward" % decal.name)


func test_the_top_of_the_canvas_sits_higher_on_the_barrel_than_the_bottom() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	for decal in CutieMarkScript.decals_of(_model):
		var top: Vector3 = CutieMarkScript.image_point_to_world(decal, 0.5, 0.0)
		var bottom: Vector3 = CutieMarkScript.image_point_to_world(decal, 0.5, 1.0)
		assert_gt(top.y, bottom.y, "%s has the canvas upside down" % decal.name)
		assert_almost_eq(top.y - bottom.y, decal.size.z, 0.001,
			"the canvas spans the decal's own depth along the barrel")


## THE RIGHT FLANK REPEATS THE DRAWING RATHER THAN MIRRORING IT, and that is a decision
## rather than an accident: a mark you cannot read from one side is not a cutie mark. So
## the same image coordinate lands on the same side of the pony's own body on neither
## flank, and on the same side of the VIEWER on both, which is what is_mirrored() asks.
func test_the_two_flanks_read_the_same_way_round_from_outside() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	var decals: Array[Decal] = CutieMarkScript.decals_of(_model)
	assert_eq(decals.size(), 2)
	for decal in decals:
		var left_edge: Vector3 = CutieMarkScript.image_point_to_world(decal, 0.0, 0.5)
		var offset: Vector3 = left_edge - decal.global_position
		assert_lt(offset.dot(CutieMarkScript.image_right(decal)), 0.0,
			"the left of the canvas is on the left as seen from outside %s" % decal.name)
```

Add `const MarkPaintScript := preload("res://systems/mark_paint.gd")` to `test_cutie_mark.gd` if it is not already there (it is, at the top of the file).

- [ ] **Step 2: Run them to make sure they fail**

Run:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_cutie_mark.gd -gtest=res://test/test_mark_paint.gd -gexit
```
Expected: FAIL. `test_mark_paint.gd` fails with a nonexistent function `orientation_probe`; `test_cutie_mark.gd` fails the same way at first, and once `orientation_probe()` exists it fails on `image_up`. Both are the "the function does not exist yet" shape, which is the correct first red.

- [ ] **Step 3: Add the probe to `game/systems/mark_paint.gd`**

Add after `stroke()`:

```gdscript
## AN ASYMMETRIC FIGURE, FOR PROVING WHICH WAY UP A FLANK IS. Not a stamp, and never
## offered to the player: game/systems/mark_stamps.gd holds the shapes she may start from.
## This one exists so that game/test/test_cutie_mark.gd, scenes/test/creation_test.gd and
## the model gallery's --mark row all check the SAME drawing, and so that a person looking
## at a rendered flank can say "that is an F" or "that is not one".
##
## AN F, AND AN F ON PURPOSE. It has no symmetry of any kind: turn it upside down and it
## stops being an F, mirror it and it stops being an F, and turn it half way round (which
## is what a flip plus a mirror is, and what the 2026-08-31 playtest actually saw) and it
## stops being an F. A heart or a star would have survived at least one of those three.
static func orientation_probe(colour := Color(0.10, 0.10, 0.12, 1.0)) -> Image:
	var image: Image = blank()
	# The spine, down the LEFT of the canvas; y grows downward, so 8 is near the top.
	stroke(image, Vector2i(18, 8), Vector2i(18, 56), colour, 3)
	# The long top arm and the short middle one, both reaching RIGHT.
	stroke(image, Vector2i(18, 11), Vector2i(50, 11), colour, 3)
	stroke(image, Vector2i(18, 30), Vector2i(40, 30), colour, 3)
	return image
```

- [ ] **Step 4: Fix the basis and add the readers in `game/systems/cutie_mark.gd`**

Replace the whole of `_flank_transform()` and add the five readers after it:

```gdscript
## HOW A DECAL'S TEXTURE IS ORIENTED, and the bug this block exists to close.
##
## A Decal projects along its own local minus Y and samples its albedo across the local XZ
## plane: the sampled U runs with local plus X and the sampled V runs with local plus Z,
## and V = 0 is the TOP row of the image. So the world direction the drawing's own "up"
## points in is the decal's MINUS Z axis, and the direction its "right" points in is the
## PLUS X axis. IMAGE_UP_AXIS and IMAGE_RIGHT_AXIS below are that convention written down
## once, and image_up()/image_right() are the only two places it is applied.
##
## WHAT WENT WRONG. This file used to pass Vector3(0, 1, 0) as the local Z column, with the
## comment "local Z runs up the barrel". That is the barrel's up, not the image's: it put
## image up at world DOWN. The same basis also came out LEFT HANDED (determinant minus one
## on both flanks), which mirrors the drawing. A vertical flip plus a mirror is a half
## turn, which is exactly what the 2026-08-31 playtest screenshot shows: a heart drawn
## point down rendered point up. Passing Vector3(0, -1, 0) instead fixes both halves in one
## column, because it puts image up at world up AND makes the basis right handed.
const IMAGE_UP_AXIS := Vector3(0.0, 0.0, -1.0)
const IMAGE_RIGHT_AXIS := Vector3(1.0, 0.0, 0.0)


## The world transform of one flank's decal. Its local minus Y is the projection axis, so
## it is aimed INWARD along the barrel: for the plus X flank that is minus X, and the
## reverse for the other.
##
## THE RIGHT FLANK REPEATS THE DRAWING RATHER THAN MIRRORING IT, and that is the decision,
## not an accident of the arithmetic. Image right lands on world minus Z on the plus X
## flank and on world plus Z on the minus X flank, and a viewer standing outside either one
## has that direction on her own right; so a letter reads as a letter and a heart reads as
## a heart from both sides. The cost is that an asymmetric mark is not the same paint seen
## from two angles, which is the correct trade for a mark the player drew herself and has
## to be able to recognise.
static func _flank_transform(model: Node3D, side: float) -> Transform3D:
	var basis := Basis(
		Vector3(0.0, 0.0, -side),   # local X: image RIGHT, running along the pony
		Vector3(side, 0.0, 0.0),    # local Y: outward, so the projection down minus Y goes in
		Vector3(0.0, -1.0, 0.0))    # local Z: image DOWN, so image up is world up
	var where := Vector3(FLANK.x * side, FLANK.y, FLANK.z)
	return model.global_transform * Transform3D(basis, where)


## The world direction the TOP of the drawing points in. See the convention block above.
static func image_up(decal: Decal) -> Vector3:
	if decal == null:
		return Vector3.ZERO
	return (decal.global_transform.basis * IMAGE_UP_AXIS).normalized()


## The world direction the RIGHT of the drawing points in.
static func image_right(decal: Decal) -> Vector3:
	if decal == null:
		return Vector3.ZERO
	return (decal.global_transform.basis * IMAGE_RIGHT_AXIS).normalized()


## The way the decal faces: out of the flank, back along the projection.
static func image_out(decal: Decal) -> Vector3:
	if decal == null:
		return Vector3.ZERO
	return decal.global_transform.basis.y.normalized()


## Is the drawing MIRRORED as seen by somebody standing outside this flank? right cross up
## points at that viewer for an un mirrored image and away from her for a mirrored one, so
## this one dot product answers the question without caring which flank it is or how the
## model happens to be turned.
static func is_mirrored(decal: Decal) -> bool:
	if decal == null:
		return false
	return image_right(decal).cross(image_up(decal)).dot(image_out(decal)) < 0.0


## Where the pixel at image coordinate (u, v), both in [0, 1] with (0, 0) at the TOP LEFT
## of the canvas, lands in world space on the flank. The one function a headless test can
## use to ask where a drawn pixel actually goes, since a headless run renders nothing.
static func image_point_to_world(decal: Decal, u: float, v: float) -> Vector3:
	if decal == null:
		return Vector3.ZERO
	return decal.global_transform * Vector3(
		(u - 0.5) * decal.size.x, 0.0, (v - 0.5) * decal.size.z)
```

Also amend the class comment's placement paragraph so it no longer says local Z runs up the barrel: replace the sentence "THE PLACEMENT IS COMPUTED IN MODEL SPACE AND CONVERTED." paragraph's final line with a pointer to the new convention block. Concretely, add this line at the end of that paragraph:

```gdscript
## Which way up the drawing then lands is a separate question, answered by the UV
## convention block above _flank_transform().
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_cutie_mark.gd -gtest=res://test/test_mark_paint.gd -gexit
```
Expected: PASS, every test in both files. If `test_the_projection_runs_from_the_flank_into_the_pony` fails, the sign convention on the Y column is wrong and the mark is being projected out into the air instead of into the barrel; do not "fix" it by widening the tolerance.

- [ ] **Step 6: Add the human checkable render note to the model gallery**

In `game/scenes/test/model_gallery.gd`, add `--mark` beside the existing `--stock` branch in `_ready()`:

```gdscript
    if "--mark" in OS.get_cmdline_user_args():
        _build_mark_row()
        return
```

and add the mode itself at the end of the file (this file is space indented; keep it that way):

```gdscript
## THREE COPIES OF THE BASE MODEL WEARING THE ORIENTATION PROBE, turned to show the left
## flank, the front and the right flank. The one question no assertion in this project can
## answer: whether the F on her side reads as an F to a person looking at her.
##
## WHAT TO LOOK FOR, and it is the whole point of this mode:
##   * the F is the right way up on BOTH flanks (its long arm at the TOP, not the bottom);
##   * the F is not back to front on either flank (its spine on the LEFT as you look at it);
##   * the two flanks read the SAME, because the right flank repeats the drawing rather
##     than mirroring it (see game/systems/cutie_mark.gd's own note on that decision).
## A half turned F, which is what a flip plus a mirror produces, is the 2026-08-31 bug.
func _build_mark_row() -> void:
    var registry := PonyRegistryScript.new()
    registry.load_all("res://data/ponies")
    var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
    var probe: Image = MarkPaintScript.orientation_probe()
    var built := 0
    for turn in [PI * 0.5, PI, PI * 1.5]:
        var body: Node3D = PonyVisualsScript.build(data)
        if body == null:
            continue
        body.position = Vector3(built * 3.0, 0.0, 0.0)
        body.rotate_y(turn)
        add_child(body)
        # apply() reads the model's global_transform, so it has to run after add_child().
        CutieMarkScript.apply(body, probe)
        built += 1
    print("GALLERY MARK: left flank, front, right flank. The F must read as an F on both flanks.")
    print("GALLERY_MARK_OK count=", built)
    if DisplayServer.get_name() == "headless":
        get_tree().quit(0 if built == 3 else 1)
```

Add `const MarkPaintScript := preload("res://systems/mark_paint.gd")` to the gallery's preload block (it already preloads `CutieMarkScript`, `PonyVisualsScript`, `PonyRegistryScript` and `StockPaletteScript`).

- [ ] **Step 7: Run the gallery mode and look at it**

Headless first, to prove it stands three ponies up:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/model_gallery.tscn -- --mark
echo "exit $?"
```
Expected: `GALLERY_MARK_OK count=3` and exit 0.

Then, on a machine with a display, drop `--headless` and look at her. The middle pony is facing you; the left and right ones show you a flank each. If either F is upside down or back to front, the basis is still wrong and the unit tests above are asserting the wrong convention; go back to Step 4 rather than adjusting the test.

- [ ] **Step 8: Add the orientation checks to the creation gate**

In `game/scenes/test/creation_test.gd`, inside the block that already runs `if decals.size() == 2:` (just after the `print("CREATION decals local_a=... local_b=...")` line), add:

```gdscript
			for decal: Decal in decals:
				var flank: String = "left" if String(decal.name) == \
					String(CutieMarkScript.LEFT_NAME) else "right"
				_set_check("the mark's top points at the sky on the %s flank" % flank,
					CutieMarkScript.image_up(decal).dot(Vector3.UP) > 0.99)
				_set_check("the mark is not mirrored on the %s flank" % flank,
					not CutieMarkScript.is_mirrored(decal))
				print("CREATION mark flank=%s up=%s right=%s mirrored=%s"
					% [flank, CutieMarkScript.image_up(decal),
						CutieMarkScript.image_right(decal),
						CutieMarkScript.is_mirrored(decal)])
```

Four new labels, all distinct, so the gate's duplicate label guard stays quiet.

- [ ] **Step 9: Run the creation gate and the whole suite**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/creation_test.tscn
echo "exit $?"
bash tools/run_tests.sh
```
Expected: `CREATION_OK checks=93` (89 plus the four new ones) and exit 0; the suite green. Read the number the gate actually prints and keep it; Task 9 writes it into `docs/testing.md`.

- [ ] **Step 10: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'fix: the cutie mark lands right way up on both flanks\n\nA Decal samples its albedo across its own local XZ plane with V = 0 at the top\nof the image, so the drawing s up is the decal s MINUS Z axis. _flank_transform()\npassed +Y as that column, which put image up at world down, and the resulting\nbasis was left handed besides, which mirrored the drawing. A flip plus a mirror\nis a half turn, which is why a heart drawn point down came back point up in the\n2026-08-31 playtest screenshot. One column changes and both halves are fixed.\n\nThe convention is now written down once (IMAGE_UP_AXIS, IMAGE_RIGHT_AXIS) and\nread by image_up(), image_right(), image_out(), is_mirrored() and\nimage_point_to_world(), which is what lets a headless test ask where a drawn\npixel actually goes. MarkPaint.orientation_probe() draws an F, which survives\nneither a flip nor a mirror nor a half turn, and the same F is used by the unit\ntests, by the creation gate and by the gallery s new --mark row.\n\nThe right flank REPEATS the drawing rather than mirroring it, documented in\ncutie_mark.gd: a mark you cannot read from one side is not a cutie mark.\n' > /tmp/mark-commit.txt
git add game/systems/cutie_mark.gd game/systems/cutie_mark.gd.uid \
  game/systems/mark_paint.gd game/test/test_cutie_mark.gd game/test/test_mark_paint.gd \
  game/scenes/test/model_gallery.gd game/scenes/test/creation_test.gd
git commit -F /tmp/mark-commit.txt
```

---

### Task 2: One interaction resolver, and a prompt that says what E will do

**Files:**
- Create: `game/world/interaction.gd`, `game/test/test_interaction.gd`
- Modify: `game/ui/hud.gd`, `game/ui/hud.tscn`, `game/world/ranch.gd`
- Test: `game/test/test_interaction.gd`, `game/test/test_hud.gd`

**Interfaces:**
- Consumes: `PlotSlot.is_empty() -> bool`, `PlotSlot.get_built() -> Node`, `PlotSlot.is_on_footprint(at: Vector3, radius: float) -> bool`, `Pen.is_full() -> bool`, `Storage.peek() -> PonyInstance`, `PonyInstance.display_name() -> String`, `ranch.casino_can_enter() -> bool`, `ranch._no_other_menu_open() -> bool`, `ranch._move_pony_into_pen(slot: PlotSlot) -> bool`, `InputDevice` does NOT exist yet (Task 4 adds it; this task's prompt takes the key glyph as an argument so Task 4 only has to change one call site).
- Produces:
  - `class_name Interaction extends RefCounted`, static only.
    - `enum Kind { NONE, PLOT_BUILD, PEN_MOVE_IN, MARKET, BOARD, DEPOT, PALACE }`
    - `const PRIORITY: Array[int]`
    - `static func candidate(kind: int, distance: float, subject: String = "") -> Dictionary`
    - `static func rank_of(kind: int) -> int`
    - `static func resolve(candidates: Array[Dictionary]) -> Dictionary`
    - `static func prompt_for(action: Dictionary, key: String) -> String`
  - `HUD.set_prompt(text: String) -> void`, `HUD.clear_prompt() -> void`, `HUD.prompt_text() -> String`.
  - `ranch.interaction_candidates() -> Array[Dictionary]`, `ranch.current_interaction() -> Dictionary`, `ranch.perform_interaction(action: Dictionary) -> bool`.

**The report, and what is actually broken.** "pressing e to build a new paddock doesnt always work; gets confused if you got ponies". Three separate defects add up to it. First, `_prompt_slot` is the de facto mutex for the whole interact verb: four of the five handlers refuse to act unless it is null, and `_update_plot_interaction()` returns BEFORE assigning it whenever any menu is open, so it holds a stale value while a menu is up and the very next E press after closing a menu can land on the wrong handler. Second, standing on a plot that already carries a pen turns E into "move a pony in", and with an empty saddlebag that path answers with a toast and nothing else, which reads as E not working. Third, and worst, nothing on screen ever says which of the six things E is currently bound to: the prompt is a toast that fires once on entering a radius and has faded three seconds later.

**The fix is one resolver and one persistent prompt.** `interaction.gd` is pure: it takes candidate dictionaries and answers with exactly one winner, chosen by a stated priority order, then by distance, then by kind index, so the same standing position always produces the same answer. `ranch.gd` gathers the candidates from the world, asks the resolver, pushes the winner's prompt into a persistent HUD label every frame, and performs exactly that one action on `interact`. All six latches and all five handlers go away. `_update_gate_prompt()` stays exactly as it is: a locked fence claims no button, so it is not a candidate and cannot steal one.

**The priority order, and why it is this one.** `PLOT_BUILD`, `PEN_MOVE_IN`, `MARKET`, `BOARD`, `DEPOT`, `PALACE`. Ground you are STANDING ON beats ground you are standing NEAR, which is why the two plot kinds lead; a slot's trigger box is a place the player deliberately walked into. The Market keeps its win over the Board because the two are five metres apart with overlapping radii and the Market is the busier of them, which is the rule `is_near_board()` already hard codes and which now lives in one list instead of inside a predicate. The Depot and the Palace have never overlapped anything on this map and are last because they are the two biggest buildings with the widest radii, so if a future map ever does overlap them with something smaller, the smaller thing wins, which is the answer a player expects.

- [ ] **Step 1: Write the failing test**

`game/test/test_interaction.gd`:

```gdscript
extends GutTest
## THE ONE INTERACT RESOLVER. Exactly one candidate wins per frame, the order is stated
## rather than emergent, and the prompt always names what E is about to do.
##
## This file drives no scene and touches no node: the resolver takes dictionaries and
## answers with one, which is the whole reason it was pulled out of ranch.gd.

const InteractionScript := preload("res://world/interaction.gd")


func test_nothing_in_range_resolves_to_nothing() -> void:
	var chosen: Dictionary = InteractionScript.resolve([])
	assert_true(chosen.is_empty(), "no candidate is not the same as a candidate of kind NONE")


func test_one_candidate_wins_on_its_own() -> void:
	var chosen: Dictionary = InteractionScript.resolve(
		[InteractionScript.candidate(InteractionScript.Kind.MARKET, 3.0)])
	assert_eq(int(chosen["kind"]), InteractionScript.Kind.MARKET)


## THE PRIORITY IS A LIST, NOT A DISTANCE. A plot slot the player is standing IN beats a
## Market she is standing nearer to, because she walked onto the plot on purpose.
func test_the_plot_she_stands_on_beats_the_market_she_stands_nearer_to() -> void:
	var chosen: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 0.5),
		InteractionScript.candidate(InteractionScript.Kind.PLOT_BUILD, 4.0),
	])
	assert_eq(int(chosen["kind"]), InteractionScript.Kind.PLOT_BUILD)


## THE OVERLAP THAT SHIPPED AS A HARD CODED CLAUSE INSIDE is_near_board(). The board stands
## five metres from the Market's origin and the two radii meet in the middle.
func test_the_market_beats_the_board_where_their_radii_meet() -> void:
	var chosen: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.BOARD, 1.0),
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 4.4),
	])
	assert_eq(int(chosen["kind"]), InteractionScript.Kind.MARKET,
		"the Market is the older and the busier of the two and keeps the ground")


func test_the_depot_and_the_palace_lose_to_everything_and_the_depot_beats_the_palace() -> void:
	for other: int in [InteractionScript.Kind.PLOT_BUILD, InteractionScript.Kind.PEN_MOVE_IN,
			InteractionScript.Kind.MARKET, InteractionScript.Kind.BOARD]:
		var chosen: Dictionary = InteractionScript.resolve([
			InteractionScript.candidate(InteractionScript.Kind.DEPOT, 0.1),
			InteractionScript.candidate(other, 9.0),
		])
		assert_eq(int(chosen["kind"]), other, "kind %d must outrank the Depot" % other)
	var pair: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.PALACE, 0.1),
		InteractionScript.candidate(InteractionScript.Kind.DEPOT, 4.9),
	])
	assert_eq(int(pair["kind"]), InteractionScript.Kind.DEPOT)


## TWO OF THE SAME KIND IS THE ONE PLACE DISTANCE DECIDES. Two plot slots whose trigger
## boxes overlap is a map edit away, and "whichever one came first in get_children()" is
## not an answer a player can predict.
func test_two_candidates_of_the_same_kind_are_settled_by_distance() -> void:
	var chosen: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.PLOT_BUILD, 3.0, "far"),
		InteractionScript.candidate(InteractionScript.Kind.PLOT_BUILD, 1.0, "near"),
	])
	assert_eq(String(chosen["subject"]), "near")


func test_the_same_candidates_in_any_order_resolve_the_same_way() -> void:
	var a: Array[Dictionary] = [
		InteractionScript.candidate(InteractionScript.Kind.PALACE, 1.0),
		InteractionScript.candidate(InteractionScript.Kind.PEN_MOVE_IN, 2.0, "Buttercup"),
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 0.2),
	]
	var b: Array[Dictionary] = [a[2], a[0], a[1]]
	assert_eq(InteractionScript.resolve(a), InteractionScript.resolve(b),
		"a resolver that depends on the order it was handed is not deterministic")


func test_every_kind_has_a_place_in_the_priority_list() -> void:
	for kind: int in [InteractionScript.Kind.PLOT_BUILD, InteractionScript.Kind.PEN_MOVE_IN,
			InteractionScript.Kind.MARKET, InteractionScript.Kind.BOARD,
			InteractionScript.Kind.DEPOT, InteractionScript.Kind.PALACE]:
		assert_gte(InteractionScript.rank_of(kind), 0,
			"kind %d is not in PRIORITY, so it can never win a tie" % kind)
	assert_lt(InteractionScript.rank_of(InteractionScript.Kind.NONE), 0)


# --- what the prompt says -------------------------------------------------------------------

func test_the_prompt_names_the_verb_for_every_kind() -> void:
	var expected := {
		InteractionScript.Kind.PLOT_BUILD: "E: build here",
		InteractionScript.Kind.MARKET: "E: Market, sell gems",
		InteractionScript.Kind.BOARD: "E: read the board",
		InteractionScript.Kind.DEPOT: "E: Depot, deliver and pay",
		InteractionScript.Kind.PALACE: "E: Spectra Palace",
	}
	for kind: int in expected:
		assert_eq(InteractionScript.prompt_for(
			InteractionScript.candidate(kind, 1.0), "E"), String(expected[kind]))


func test_the_pen_prompt_names_the_pony_who_is_about_to_go_in() -> void:
	assert_eq(InteractionScript.prompt_for(InteractionScript.candidate(
		InteractionScript.Kind.PEN_MOVE_IN, 1.0, "Buttercup"), "E"),
		"E: move Buttercup in")


func test_an_empty_saddlebag_still_holds_the_ground_and_says_why() -> void:
	var line: String = InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.PEN_MOVE_IN, 1.0), "E")
	assert_true(line.contains("saddlebag"),
		"the pen keeps the ground so nothing else steals E there, and it explains itself: %s"
			% line)


func test_the_prompt_uses_the_key_it_is_handed() -> void:
	assert_eq(InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 1.0), "X"),
		"X: Market, sell gems")


func test_nothing_resolves_to_an_empty_prompt() -> void:
	assert_eq(InteractionScript.prompt_for({}, "E"), "")


func test_nothing_the_resolver_says_carries_a_dash() -> void:
	for kind: int in [InteractionScript.Kind.PLOT_BUILD, InteractionScript.Kind.PEN_MOVE_IN,
			InteractionScript.Kind.MARKET, InteractionScript.Kind.BOARD,
			InteractionScript.Kind.DEPOT, InteractionScript.Kind.PALACE]:
		for subject: String in ["", "Buttercup"]:
			var line: String = InteractionScript.prompt_for(
				InteractionScript.candidate(kind, 1.0, subject), "E")
			assert_false(line.contains("--") or line.contains("—"), line)
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_interaction.gd -gexit`

Expected: FAIL; GUT reports the script was ignored because `res://world/interaction.gd` does not exist.

- [ ] **Step 3: Write `game/world/interaction.gd`**

```gdscript
class_name Interaction
extends RefCounted
## WHAT THE E KEY DOES, RIGHT HERE, RIGHT NOW. Exactly one answer per frame, chosen by a
## stated order rather than by whichever handler happened to be called first.
##
## THE BUG THIS REPLACES. game/world/ranch.gd used to run five _update_*_interaction()
## functions in sequence, each with its own "fire once per approach" latch, and four of the
## five additionally refused to act unless _prompt_slot was null. _prompt_slot is written
## by the plot handler, which returns BEFORE writing it whenever any menu is open, so it
## went stale while a menu was up and the next E press after closing one could land on the
## wrong handler. Add to that a prompt that was a fading toast rather than a line on the
## screen, and "pressing e to build a new paddock doesnt always work; gets confused if you
## got ponies" is the report you get (owner, 2026-08-31).
##
## PURE, AND THAT IS THE POINT. Nothing here reads Input, touches a node, opens a menu or
## knows what a Pen is. ranch.gd gathers candidates out of the world and performs the
## winner; this file only decides which one wins and what the prompt says. That is what
## makes the priority order a thing a test can pin, which it could not be while it was an
## emergent property of the order of five function calls.
##
## Static only, no state. Preload by path.

## The verbs E can carry. NONE is the absence of a candidate and never appears in PRIORITY.
enum Kind { NONE, PLOT_BUILD, PEN_MOVE_IN, MARKET, BOARD, DEPOT, PALACE }

## THE ORDER, HIGHEST FIRST, and every one of these positions is a decision.
##
## GROUND YOU ARE STANDING ON BEATS GROUND YOU ARE STANDING NEAR. The two plot kinds lead
## because a slot's trigger box is a square the player deliberately walked into, and a
## building's radius is a circle she walked past.
##
## THE MARKET BEATS THE BOARD, which is the rule ranch.gd's is_near_board() used to carry
## as a hard coded "and not is_near_market()" clause. The board stands five metres from the
## Market's origin and the two radii meet in the middle; the Market is the older and the
## busier of the two and keeps the ground. Now it is one line in one list instead of a
## clause hidden inside a predicate.
##
## THE DEPOT AND THE PALACE ARE LAST because they are the two biggest buildings with the
## two widest radii (4.0 m and 5.0 m), so if a future map ever does overlap one of them
## with something smaller, the smaller thing wins, which is the answer a player expects
## from a big building with a small thing in front of it.
const PRIORITY: Array[int] = [Kind.PLOT_BUILD, Kind.PEN_MOVE_IN, Kind.MARKET, Kind.BOARD,
	Kind.DEPOT, Kind.PALACE]

## What the pen prompt says when the saddlebag is empty. THE PEN STILL WINS THE GROUND in
## that state, deliberately: a pen that dropped out of the running with an empty bag would
## hand E to whatever building is next nearest, so the player standing in her own paddock
## would press E and open the Market. She keeps the ground and the prompt says why.
const EMPTY_BAG := "your saddlebag is empty"


## One candidate, as ranch.gd hands them over. `distance` is metres in the XZ plane and is
## only ever used to settle two candidates of the SAME kind. `subject` is whatever the
## prompt needs to name: the pony at the top of the saddlebag, or a slot's name for a test.
static func candidate(kind: int, distance: float, subject: String = "") -> Dictionary:
	return {"kind": kind, "distance": distance, "subject": subject}


## Where `kind` sits in PRIORITY, or minus one for a kind that is not in it at all. A kind
## outside the list can never win, which is the correct answer for Kind.NONE and a loud one
## for a kind somebody adds to the enum and forgets to rank.
static func rank_of(kind: int) -> int:
	return PRIORITY.find(kind)


## THE ONE WINNER. Ranked by PRIORITY first, then by the shorter distance, then by the kind
## itself, so the answer is a function of the candidates and of nothing else: handing the
## same set in a different order gives the same winner. An empty array answers an empty
## dictionary, which is not the same thing as a candidate of Kind.NONE.
static func resolve(candidates: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_rank := -1
	for entry: Dictionary in candidates:
		var rank: int = rank_of(int(entry.get("kind", Kind.NONE)))
		if rank < 0:
			continue
		if best.is_empty():
			best = entry
			best_rank = rank
			continue
		if rank < best_rank:
			best = entry
			best_rank = rank
			continue
		if rank > best_rank:
			continue
		var d: float = float(entry.get("distance", 0.0))
		var best_d: float = float(best.get("distance", 0.0))
		if d < best_d:
			best = entry
	return best


## THE LINE ON THE SCREEN, and it always names the verb rather than the place. "E: Market"
## tells a player where she is; "E: Market, sell gems" tells her what pressing it does,
## which is the question she actually has in the first ten minutes.
##
## `key` is the glyph for the device in her hands, handed in rather than looked up, so this
## file stays pure and Task 4's device tracker has exactly one call site to change.
static func prompt_for(action: Dictionary, key: String) -> String:
	if action.is_empty():
		return ""
	var subject: String = String(action.get("subject", ""))
	match int(action.get("kind", Kind.NONE)):
		Kind.PLOT_BUILD:
			return "%s: build here" % key
		Kind.PEN_MOVE_IN:
			if subject.is_empty():
				return "%s: the pen is here, %s" % [key, EMPTY_BAG]
			return "%s: move %s in" % [key, subject]
		Kind.MARKET:
			return "%s: Market, sell gems" % key
		Kind.BOARD:
			return "%s: read the board" % key
		Kind.DEPOT:
			return "%s: Depot, deliver and pay" % key
		Kind.PALACE:
			return "%s: Spectra Palace" % key
	return ""
```

- [ ] **Step 4: Run the resolver's tests to verify they pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_interaction.gd -gexit`

Expected: PASS, 13 tests.

- [ ] **Step 5: Give the HUD a persistent prompt**

In `game/ui/hud.tscn`, add a `Prompt` Label as a child of the `HUD` CanvasLayer, immediately after the `Crosshair` node:

```
[node name="Prompt" type="Label" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -420.0
offset_top = 58.0
offset_right = 420.0
offset_bottom = 106.0
grow_horizontal = 2
grow_vertical = 2
horizontal_alignment = 1
mouse_filter = 2
```

In `game/ui/hud.gd`, add the colour constant next to `COLOR_WORLD_LINE`:

```gdscript
## The interaction prompt, sitting just under the reticle. Gold, like every other
## "you may act on this" cue in the game (the menus' COLOR_VALUE is the same number), and
## deliberately NOT the toast's white: a toast is something that happened, a prompt is
## something you can do.
const COLOR_PROMPT := Color(1.00, 0.86, 0.42, 1.0)
```

add the node handle next to the others:

```gdscript
@onready var _prompt: Label = $Prompt
```

style it in `_ready()` alongside the existing label styling (find the `_style_label(_world_line, ...)` call and add this immediately after it):

```gdscript
	_style_label(_prompt, 26, COLOR_PROMPT)
	_prompt.text = ""
```

and add the three methods next to `set_world_line()`:

```gdscript
## WHAT THE INTERACT KEY WILL DO IF YOU PRESS IT NOW. Pushed every physics frame by
## game/world/ranch.gd's resolver and cleared the moment nothing is in range.
##
## A PERSISTENT LABEL, NOT A TOAST, and that is the whole fix. Every one of these lines
## used to go through toast(), which holds for TOAST_HOLD and fades over TOAST_FADE: a
## player standing on a plot saw "Press E / X to build here." once, three seconds later saw
## nothing, and had no way at all to find out what E was currently bound to. A prompt is
## the state of the world, so it is drawn for as long as the state holds.
##
## SET UNCONDITIONALLY RATHER THAN ONLY ON CHANGE. Assigning the same string to a Label is
## free, and the "only on change" version of this is exactly the latch bookkeeping that
## went stale in ranch.gd and caused the bug this replaces.
func set_prompt(text: String) -> void:
	if _prompt != null:
		_prompt.text = text


func clear_prompt() -> void:
	set_prompt("")


func prompt_text() -> String:
	return _prompt.text if _prompt != null else ""
```

- [ ] **Step 6: Test the HUD prompt**

Append to `game/test/test_hud.gd`:

```gdscript
func test_the_prompt_starts_empty_and_holds_what_it_is_given() -> void:
	assert_eq(_hud.prompt_text(), "", "nothing is in range at boot")
	_hud.set_prompt("E: build here")
	assert_eq(_hud.prompt_text(), "E: build here")


func test_clearing_the_prompt_leaves_nothing_on_the_screen() -> void:
	_hud.set_prompt("E: Market, sell gems")
	_hud.clear_prompt()
	assert_eq(_hud.prompt_text(), "")


## THE PROMPT IS NOT THE TOAST, and the two must not be able to overwrite each other: a
## toast is something that happened, a prompt is something you can do, and the whole reason
## the prompt exists is that the toast fades.
func test_the_prompt_and_the_toast_are_two_different_lines() -> void:
	_hud.set_prompt("E: build here")
	_hud.toast("Ranch saved")
	assert_eq(_hud.prompt_text(), "E: build here")
	assert_eq(_hud.toast_text(), "Ranch saved")
```

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_hud.gd -gexit`

Expected: PASS.

- [ ] **Step 7: Rewire `game/world/ranch.gd` onto the resolver**

Add the preload beside the others near the top of the file:

```gdscript
const InteractionScript := preload("res://world/interaction.gd")
```

Delete these six member variables and every remaining reference to them: `_prompt_slot`, `_market_prompted`, `_board_prompted`, `_depot_prompted`, `_palace_prompted`. (`_gate_prompted` STAYS: the locked fence prompt claims no button and is not part of this.)

Delete `_update_plot_interaction()`, `_update_market_interaction()`, `_update_board_interaction()`, `_update_depot_interaction()` and `_update_palace_interaction()` entirely.

Remove the hard coded clause from `is_near_board()`, whose whole job is now PRIORITY's:

```gdscript
## Is the player standing at the request board?
##
## THE OVERLAP WITH THE MARKET IS NOT SETTLED HERE ANY MORE. This used to end with
## "and not is_near_market()", because the board stands five metres from the Market's
## origin and the two radii meet in the middle. That rule now lives in one place, as one
## line of game/world/interaction.gd's PRIORITY list, with every other precedence in the
## game beside it; a predicate that answers "am I at the board" should answer that and not
## also arbitrate.
func is_near_board() -> bool:
	var board := get_node_or_null(^"Buildings/Board") as Node3D
	if board == null:
		return false
	var gap := Vector2(player.global_position.x - board.global_position.x,
		player.global_position.z - board.global_position.z).length()
	return gap <= BOARD_RADIUS
```

Add the three new public methods next to `_move_pony_into_pen()`:

```gdscript
## EVERYTHING E COULD MEAN WHERE THE PLAYER IS STANDING, unranked. The world half of the
## resolver: this file knows what a plot slot and a Pen and a saddlebag are, and
## game/world/interaction.gd knows which of them wins. Public so a gate or a test can ask
## "what is offered here" without an Input event and without a frame.
##
## A PEN IS ALWAYS A CANDIDATE, even with an empty bag or a full pen, so that standing in
## your own paddock and pressing E can never open the Market instead. What the prompt says
## in that state is Interaction.prompt_for()'s business.
func interaction_candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null:
		return out
	var at: Vector3 = player.global_position
	for slot in _plot_slots():
		if not (player in slot.get_overlapping_bodies()):
			continue
		var gap: float = Vector2(at.x - slot.global_position.x,
			at.z - slot.global_position.z).length()
		if slot.is_empty():
			out.append(InteractionScript.candidate(
				InteractionScript.Kind.PLOT_BUILD, gap, String(slot.name)))
		else:
			out.append(InteractionScript.candidate(
				InteractionScript.Kind.PEN_MOVE_IN, gap, _next_in_the_bag()))
	if is_near_market():
		out.append(InteractionScript.candidate(
			InteractionScript.Kind.MARKET, _flat_gap_to(^"Buildings/Market")))
	if is_near_board():
		out.append(InteractionScript.candidate(
			InteractionScript.Kind.BOARD, _flat_gap_to(^"Buildings/Board")))
	if is_near_depot():
		out.append(InteractionScript.candidate(
			InteractionScript.Kind.DEPOT, _flat_gap_to(^"Buildings/Depot")))
	# THE BAN CLOSES THE DOOR RATHER THAN GREYING IT OUT. The shipped code showed no prompt
	# under a ban but still let the press through to casino_menu.open(), which then refused
	# on its own can_open; a player got a silent nothing. A banned Palace is simply not
	# offered, so the prompt and the button agree.
	if is_near_palace() and casino_can_enter():
		out.append(InteractionScript.candidate(
			InteractionScript.Kind.PALACE, _flat_gap_to(^"Buildings/Palace")))
	return out


## Whoever is at the top of the saddlebag, by name, or "" for an empty bag. Only the prompt
## reads this; _move_pony_into_pen() asks the Storage itself when the key is actually
## pressed, so a pony beamed in between the prompt and the press is still the one who goes
## into the pen.
func _next_in_the_bag() -> String:
	if player == null:
		return ""
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		return ""
	var storage: Storage = beam.get_storage()
	if storage == null:
		return ""
	var next: PonyInstance = storage.peek()
	return next.display_name() if next != null else ""


func _flat_gap_to(path: NodePath) -> float:
	var node := get_node_or_null(path) as Node3D
	if node == null or player == null:
		return 0.0
	return Vector2(player.global_position.x - node.global_position.x,
		player.global_position.z - node.global_position.z).length()


## THE ONE THING E WILL DO, or an empty dictionary. Public for the same reason
## interaction_candidates() is.
func current_interaction() -> Dictionary:
	if not _no_other_menu_open():
		return {}
	return InteractionScript.resolve(interaction_candidates())


## DO IT. Returns whether anything actually happened. Public and Input free, so a gate can
## drive the verb the player presses instead of reaching past it (scenes/test/
## collection_test.gd's own note explains why it had to reach past the old one).
func perform_interaction(action: Dictionary) -> bool:
	if action.is_empty():
		return false
	match int(action.get("kind", InteractionScript.Kind.NONE)):
		InteractionScript.Kind.PLOT_BUILD:
			var slot: PlotSlot = _slot_named(String(action.get("subject", "")))
			if slot == null:
				return false
			# Told BEFORE the menu rather than after she has picked something: being made
			# to choose a pen and only then being sent to stand somewhere else is a worse
			# version of the same refusal.
			if _player_stands_on_footprint(slot):
				_toast("Step outside the plot markers to build here.")
				return false
			if build_menu == null or not build_menu.has_method("open"):
				return false
			return bool(build_menu.open(slot))
		InteractionScript.Kind.PEN_MOVE_IN:
			var pen_slot: PlotSlot = _nearest_occupied_slot()
			return _move_pony_into_pen(pen_slot) if pen_slot != null else false
		InteractionScript.Kind.MARKET:
			if market_menu == null or not market_menu.has_method("open"):
				return false
			return bool(market_menu.open())
		InteractionScript.Kind.BOARD:
			_open_request_page()
			return true
		InteractionScript.Kind.DEPOT:
			if depot_menu == null or not depot_menu.has_method("open"):
				return false
			return bool(depot_menu.open())
		InteractionScript.Kind.PALACE:
			if casino_menu == null or not casino_menu.has_method("open"):
				return false
			return bool(casino_menu.open())
	return false


## The plot slot called `slot_name`, or null. The PLOT_BUILD candidate carries the slot's
## own node name as its subject precisely so this lookup is a name and not an index into a
## list that may have been rebuilt since the candidate was made.
func _slot_named(slot_name: String) -> PlotSlot:
	for slot in _plot_slots():
		if String(slot.name) == slot_name:
			return slot
	return null


## The nearest built slot the player is actually standing in. The PEN_MOVE_IN candidate
## carries the pony's name as its subject (that is what the prompt needs), so the slot is
## found again here rather than carried; the resolver already guaranteed she is standing in
## exactly one, and "nearest" settles a map edit that ever overlapped two.
func _nearest_occupied_slot() -> PlotSlot:
	var best: PlotSlot = null
	var best_gap := INF
	for slot in _plot_slots():
		if slot.is_empty() or not (player in slot.get_overlapping_bodies()):
			continue
		var gap: float = Vector2(player.global_position.x - slot.global_position.x,
			player.global_position.z - slot.global_position.z).length()
		if gap < best_gap:
			best_gap = gap
			best = slot
	return best


## THE WHOLE INTERACT VERB, ONCE A FRAME. Ask the world what is on offer, ask the resolver
## which one wins, say so on the HUD, and act on exactly that one if the key went down.
##
## NO LATCHES. The five handlers this replaces kept six of them between them, each
## implementing "fire once per approach" a slightly different way, and one of them
## (_prompt_slot) doubled as the mutex the other four consulted. The prompt is a persistent
## label now, so there is nothing to fire once and nothing to go stale.
func _update_interaction() -> void:
	var action: Dictionary = current_interaction()
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("set_prompt"):
		hud.set_prompt(InteractionScript.prompt_for(action, INTERACT_KEY))
	if action.is_empty() or not Input.is_action_just_pressed(&"interact"):
		return
	perform_interaction(action)
```

Add the key glyph constant next to `PALACE_RADIUS`:

```gdscript
## The glyph the interact prompt prints. A constant here and a lookup in Task 4's device
## tracker after that; stated as one name so there is one call site to change.
const INTERACT_KEY := "E"
```

Replace the five calls in `_physics_process` with the one:

```gdscript
	spawner.tick_stock(delta)
	_update_interaction()
	# AFTER the interaction pass, so a ban that landed this frame shuts a door the resolver
	# would otherwise have just opened. See enforce_casino_ban().
	enforce_casino_ban()
	_update_gate_prompt()
```

- [ ] **Step 8: Run the whole suite and every gate**

```bash
bash tools/run_tests.sh
for scene in market_test region_test world_test collection_test ledger_test depot_test creation_test casino_test; do
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" >/dev/null 2>&1
  echo "$scene exit $?"
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```

Expected: the suite green, every gate exit 0, and `RANCH_OK ponies=49 props=60 assets=present`. Any test that referenced one of the five deleted handlers or one of the deleted latches fails here; rewrite it against `interaction_candidates()` / `current_interaction()` / `perform_interaction()`, which is a strictly better thing for it to have been asserting in the first place.

- [ ] **Step 9: Prove the fix by hand**

On a machine with a display:
```bash
tools/bin/godot --path game world/ranch.tscn
```
Walk onto an empty plot: the line under the reticle reads `E: build here` and stays there. Build a pen, catch a pony, walk back in: it reads `E: move <her name> in`. Empty the bag and stand there: it reads `E: the pen is here, your saddlebag is empty` and E does nothing else. Walk to the Market: `E: Market, sell gems`. Stand between the Market and the board: still the Market, and E opens the Market. This is the report closed.

- [ ] **Step 10: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'fix: one interact resolver, and a prompt that says what E will do\n\nThe owner, 2026-08-31: "pressing e to build a new paddock doesnt always work;\ngets confused if you got ponies". Three defects added up to it. _prompt_slot was\nthe de facto mutex for the whole verb and went stale whenever a menu was open,\nbecause the plot handler returns before assigning it. Standing on a built plot\nturned E into "move a pony in", which with an empty bag answered with a toast\nand nothing else. And nothing on screen ever said which of six things E was\nbound to, because the prompt was a toast that faded after 3.1 seconds.\n\ngame/world/interaction.gd is now the one resolver: candidates in, exactly one\nwinner out, ranked by a stated PRIORITY list and then by distance, so the same\nstanding position always gives the same answer and the order is a thing a test\ncan pin. is_near_board() no longer arbitrates its own overlap with the Market;\nthat rule is one line of PRIORITY beside every other precedence in the game.\n\nThe HUD grows a persistent Prompt label under the reticle. Five handlers, six\nlatches and five separate Input reads become one _update_interaction().\nperform_interaction() is public and Input free, so a gate can drive the verb the\nplayer presses instead of reaching past it.\n\nA banned Palace is no longer offered at all: the prompt and the button agree.\n' > /tmp/interact-commit.txt
git add game/world/interaction.gd game/world/interaction.gd.uid game/world/ranch.gd \
  game/ui/hud.gd game/ui/hud.tscn game/test/test_interaction.gd game/test/test_hud.gd
git commit -F /tmp/interact-commit.txt
```

---

### Task 3: The Palace stands on solid ground, and its sign fits on a board

**Files:**
- Modify: `game/world/building.gd`, `game/world/strip.gd`, `game/systems/casino_sign.gd`, `game/world/ranch.gd`
- Test: `game/test/test_strip.gd`, `game/test/test_casino_sign.gd`, and a new `game/test/test_building_base.gd`

**Interfaces:**
- Consumes: `Building.width`, `Building.depth`, `Building.wall_height`, `Building.ridge_height`, `Building.eave_overhang`, `Props.SINK_BIAS` (0.05), `Terrain.height_at(x: float, z: float) -> float`, `Strip.configure(region: RegionData, ground_sampler: Callable) -> void`, `Strip.avoid_footprint(centre_xz: Vector2, half_extents: Vector2) -> void`, `Strip.build() -> void`, `CasinoSign.HEADLINE`, `CasinoSign.SPONSOR`, `CasinoSign.MARQUEE`.
- Produces:
  - `Building.FLOOR_TOP` (0.75), `Building.SKIRT_DEPTH` (1.20), `Building.floor_top_y() -> float`, `Building.skirt_bottom_y() -> float`.
  - `CasinoSign.marquee_headline() -> String`, `CasinoSign.marquee_sponsor() -> String`.
  - `Strip.mount_marquee(front_centre: Vector3, half_extents: Vector2, ridge_y: float) -> void`, `Strip.marquee_board_size() -> Vector2`, `Strip.marquee_board_centre() -> Vector3`, `Strip.marquee_top_y() -> float`, `Strip.marquee_lines() -> Array[String]` (replaces `marquee_text()`).

**Report 3, and the measurement behind it.** `Building.build()` lays a `Floor` slab 0.14 m thick whose bottom face sits at exactly local y = 0, and `Props.seat()` drops the building until the bottom of its world AABB is 0.05 m below the terrain height at ONE point. `ranch.gd`'s own `PALACE_MAX_RELIEF` records that the ground under the Palace's 14 by 9 m footprint has 0.633 m of relief, the flattest such rectangle anywhere on the Strip. Terrain 0.633 m tall crossing a floor 0.14 m thick is two nearly coplanar surfaces fighting over the same pixels, which is the flickering skirt. Nothing is wrong with the seating; the floor is simply far too thin for the building standing on it.

**The fix, and the invariant that keeps it fixed.** The floor becomes a plinth: its TOP rises to `FLOOR_TOP` (0.75 m), comfortably above the 0.633 m of relief, and its BOTTOM drops to `SKIRT_DEPTH` (1.20 m) below the origin, comfortably below it, so the terrain surface passes through the SIDE of a solid box rather than grazing a horizontal face. Neither face is ever near coplanar with the ground and no daylight ever shows under an uphill corner. The new test then asserts the real invariant for EVERY building in `ranch.tscn`, not just the Palace: sample the terrain at the four footprint corners and the centre, and require the plinth's top above all of them and its bottom below all of them, both with margin. That is the check that answers "verify no other building shows it".

**Report 4, and the geometry.** The marquee is a bare `Label3D` at `(-10, 5.4, 56.2)` with no width limit, rendering roughly 18 m of text across a 14 m building whose ridge is 4.6 m: it overruns both edges, and at 5.4 m it crosses the roof silhouette from the approach. It is rebuilt as a fitted sign: a backing board mounted from the Palace's OWN measurements, headline text sized to the board, and the sponsor line under it at 55 per cent of the headline's height. Everything about where it goes is derived from the building rather than typed, so the two can never drift again, and the test asserts the two properties the report names: the board's top is below the ridge, and the board is not wider than the building.

- [ ] **Step 1: Write the failing tests**

`game/test/test_building_base.gd`:

```gdscript
extends GutTest
## THE PLINTH UNDER EVERY BUILDING ON THE MAP, against the real terrain.
##
## THE BUG: the shipped Floor slab was 0.14 m thick with its bottom face at exactly local
## y = 0, and Props.seat() drops a building by the ground height at ONE point. The terrain
## under Buildings/Palace has 0.633 m of relief across its 14 by 9 m footprint (measured;
## see ranch.gd's PALACE_MAX_RELIEF), so the ground crossed that 0.14 m floor and the two
## surfaces fought for the same pixels. The owner, 2026-08-31: "z fighting at the palace
## base, a flickering skirt where the building meets terrain".
##
## THE INVARIANT WITH TEETH is stated per building rather than for the Palace alone: the
## plinth's top must clear the HIGHEST ground under the footprint and its bottom must sit
## below the LOWEST, both with margin. A building that satisfies that cannot fight the
## terrain no matter what relief it is standing on.

const BuildingScript := preload("res://world/building.gd")
const TerrainScript := preload("res://world/terrain.gd")
const RanchScene := preload("res://world/ranch.tscn")

## Metres of clear air demanded on each side of the ground, on top of the relief itself.
## Bigger than Props.SINK_BIAS (0.05) so a passing check is a real gap rather than a
## rounding accident.
const MARGIN := 0.15


func test_the_plinth_is_thicker_than_the_worst_relief_on_the_map() -> void:
	assert_gt(BuildingScript.FLOOR_TOP, 0.633 + MARGIN,
		"the plinth top must clear the 0.633 m measured under the Palace")
	assert_gt(BuildingScript.SKIRT_DEPTH, BuildingScript.FLOOR_TOP,
		"the plinth reaches further below the origin than above it, or an uphill corner "
		+ "shows daylight underneath")


func test_a_built_shell_has_its_floor_where_the_constants_say() -> void:
	var b: Building = BuildingScript.new()
	b.width = 6.0
	b.depth = 4.0
	add_child_autofree(b)
	b.build()
	var floor_node := b.get_node_or_null(^"Floor") as MeshInstance3D
	assert_not_null(floor_node, "every building lays a Floor slab")
	var box: BoxMesh = floor_node.mesh
	assert_almost_eq(floor_node.position.y + box.size.y * 0.5, BuildingScript.FLOOR_TOP,
		0.0001, "the top of the plinth is FLOOR_TOP above the origin")
	assert_almost_eq(floor_node.position.y - box.size.y * 0.5, -BuildingScript.SKIRT_DEPTH,
		0.0001, "and the bottom is SKIRT_DEPTH below it")


## EVERY BUILDING IN ranch.tscn, ON THE REAL TERRAIN, at the four corners of its own
## footprint and at its centre. This is the check that answers "does any other building
## show it", which no amount of staring at the Palace can.
func test_no_building_on_the_shipped_map_can_fight_the_ground() -> void:
	var ranch: Node3D = RanchScene.instantiate()
	add_child_autofree(ranch)
	await get_tree().process_frame
	var terrain := ranch.get_node_or_null(^"Terrain") as Terrain
	var buildings := ranch.get_node_or_null(^"Buildings") as Node3D
	assert_not_null(terrain)
	assert_not_null(buildings)
	for child in buildings.get_children():
		var b := child as Building
		if b == null:
			continue
		var origin: Vector3 = b.global_position
		var half := Vector2(b.width * 0.5, b.depth * 0.5)
		var lowest := INF
		var highest := -INF
		for dx: float in [-half.x, 0.0, half.x]:
			for dz: float in [-half.y, 0.0, half.y]:
				# The footprint is turned with the building, so the corner offsets go
				# through its own basis rather than being added in world axes.
				var corner: Vector3 = origin + b.global_transform.basis * Vector3(dx, 0.0, dz)
				var h: float = terrain.height_at(corner.x, corner.z)
				lowest = minf(lowest, h)
				highest = maxf(highest, h)
		var top: float = origin.y + BuildingScript.FLOOR_TOP
		var bottom: float = origin.y - BuildingScript.SKIRT_DEPTH
		assert_gt(top, highest + MARGIN,
			"%s: the plinth top (%.3f) does not clear the highest ground under it (%.3f)"
				% [b.name, top, highest])
		assert_lt(bottom, lowest - MARGIN,
			"%s: the plinth bottom (%.3f) does not reach below the lowest ground (%.3f)"
				% [b.name, bottom, lowest])
```

Append to `game/test/test_strip.gd`:

```gdscript
## THE MARQUEE, AFTER 2026-08-31. It was a bare Label3D with no width limit carrying a 66
## character line at 0.0086 m per pixel: about 18 m of text across a 14 m building, at 5.4 m
## on a building whose ridge is 4.6 m. The owner: "marquee is unreadable and clips the
## roof". It is a fitted board now, and both of those are properties a test can hold.
func test_the_marquee_board_is_narrower_than_the_building_it_advertises() -> void:
	var strip: Strip = _built_strip()
	var size: Vector2 = strip.marquee_board_size()
	assert_gt(size.x, 0.0, "there is a board")
	assert_lt(size.x, PALACE_WIDTH,
		"a sign wider than its own building is the thing that was wrong")


func test_the_marquee_is_mounted_clear_of_the_roofline() -> void:
	var strip: Strip = _built_strip()
	assert_lt(strip.marquee_top_y(), PALACE_RIDGE_Y,
		"the top of the board must sit below the ridge, or it crosses the roof")


func test_the_marquee_hangs_in_front_of_the_wall_rather_than_inside_it() -> void:
	var strip: Strip = _built_strip()
	var centre: Vector3 = strip.marquee_board_centre()
	assert_lt(centre.z, PALACE_FRONT_Z,
		"the board stands on the approach side of the front wall")
	assert_gt(PALACE_FRONT_Z - centre.z, 0.2,
		"and far enough off it not to fight the wall for pixels")


func test_the_marquee_says_the_headline_and_the_sponsor_and_nothing_else() -> void:
	var strip: Strip = _built_strip()
	var lines: Array[String] = strip.marquee_lines()
	assert_eq(lines.size(), 2, "a headline and a sponsor line, in that order")
	assert_eq(lines[0], CasinoSignScript.HEADLINE)
	assert_eq(lines[1], CasinoSignScript.SPONSOR)
	for line in lines:
		assert_false(line.contains("--") or line.contains("—"), line)
```

with these helpers and constants at the top of `test_strip.gd` (add `const CasinoSignScript := preload("res://systems/casino_sign.gd")` if it is not already there):

```gdscript
## Buildings/Palace as ranch.tscn stands it: origin (-10, 0, 61.6), turned a half turn, so
## its door faces the approach from the south. Repeated here rather than read off the scene
## because this test builds a Strip on its own and hands it the same numbers ranch.gd does.
const PALACE_ORIGIN := Vector3(-10.0, 0.0, 61.6)
const PALACE_WIDTH := 14.0
const PALACE_DEPTH := 9.0
const PALACE_RIDGE_Y := 4.6
const PALACE_FRONT_Z := PALACE_ORIGIN.z - PALACE_DEPTH * 0.5


func _built_strip() -> Strip:
	var strip: Strip = StripScript.new()
	add_child_autofree(strip)
	var region: RegionData = RegionRegistryScript.new_loaded().by_id(StripScript.REGION_ID) \
		if false else _strip_region()
	strip.configure(region, func(_x: float, _z: float) -> float: return 0.0)
	strip.mount_marquee(
		Vector3(PALACE_ORIGIN.x, PALACE_ORIGIN.y, PALACE_FRONT_Z),
		Vector2(PALACE_WIDTH * 0.5, PALACE_DEPTH * 0.5),
		PALACE_ORIGIN.y + PALACE_RIDGE_Y)
	strip.build()
	return strip
```

(`test_strip.gd` already has a way of getting the Strip's `RegionData`; use whatever it already calls and name the helper `_strip_region()`. If it does not, add `func _strip_region() -> RegionData: return load(StripScript.REGION_PATH) as RegionData` and add `const REGION_PATH := "res://data/regions/strip.tres"` to `strip.gd` beside `REGION_ID`. Drop the dead `if false else` above once you have wired `_strip_region()`.)

- [ ] **Step 2: Run them to make sure they fail**

Run:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_building_base.gd -gtest=res://test/test_strip.gd -gexit
```
Expected: FAIL. `test_building_base.gd` fails on the nonexistent `Building.FLOOR_TOP`; `test_strip.gd` fails on the nonexistent `mount_marquee`.

- [ ] **Step 3: Give `game/world/building.gd` a plinth**

Add the two constants after `MIN_DOOR_CLEARANCE`:

```gdscript
## HOW FAR THE FLOOR SLAB REACHES ABOVE AND BELOW THE BUILDING'S OWN ORIGIN.
##
## THE BUG THESE CLOSE. The slab used to be 0.14 m thick with its bottom face at exactly
## local y = 0, and Props.seat() drops a building until the bottom of its world AABB is
## SINK_BIAS (0.05 m) under the ground height at ONE point. The ground under
## Buildings/Palace has 0.633 m of relief across its 14 by 9 m footprint, measured, and
## that is the FLATTEST such rectangle anywhere on the Strip (see ranch.gd's
## PALACE_MAX_RELIEF). Ground that tall crossing a floor that thin is two nearly coplanar
## surfaces fighting for the same pixels: the owner's "z fighting at the palace base, a
## flickering skirt where the building meets terrain", 2026-08-31.
##
## SO THE FLOOR BECOMES A PLINTH. FLOOR_TOP is above the worst relief on the map with room
## to spare, so no corner of terrain ever pokes through the boards; SKIRT_DEPTH is below
## it, so no uphill corner ever shows daylight underneath either. The ground therefore
## always passes through the SIDE of a solid box, which is a hard edge rather than a
## contested plane, and neither horizontal face is ever anywhere near the terrain.
##
## THE STEP UP IS INTENTIONAL AND READS AS ONE. 0.75 m is a stride, not a wall, and a
## building that sits on a plinth reads as built rather than as dropped on the grass.
const FLOOR_TOP := 0.75
const SKIRT_DEPTH := 1.20
```

Replace the floor slab in `build()`:

```gdscript
	# --- plinth ------------------------------------------------------------------
	# A boarded floor on a deep skirt rather than grass showing through the doorway,
	# and deep enough that the terrain crosses its SIDE rather than its faces. See
	# FLOOR_TOP and SKIRT_DEPTH for the measurement this is sized from.
	var plinth: float = FLOOR_TOP + SKIRT_DEPTH
	_slab("Floor", Vector3(width, plinth, depth),
		Vector3(0.0, FLOOR_TOP - plinth * 0.5, 0.0), trim_mat)
```

Everything else in `build()` measures from local y = 0 and is unchanged, so the walls now stand ON the plinth with their feet 0.75 m inside it, which is what a plinth is for. Add the two readers next to `build()`:

```gdscript
## The top of the plinth and the bottom of the skirt, in this building's own parent space.
## For the test that walks every building on the map and asks whether the ground under its
## own footprint can reach either one.
func floor_top_y() -> float:
	return position.y + FLOOR_TOP


func skirt_bottom_y() -> float:
	return position.y - SKIRT_DEPTH
```

- [ ] **Step 4: Split the marquee copy in `game/systems/casino_sign.gd`**

Add next to `MARQUEE` (which stays, because `CasinoSign.lines()` and the lobby still use it):

```gdscript
## THE MARQUEE, AS TWO LINES RATHER THAN ONE. MARQUEE above is the whole sentence, and it
## is still what the lobby sign and the toast say; the board outside is a headline with the
## sponsor under it in smaller letters, because 66 characters on one line across a 14 metre
## building is exactly the sign the owner could not read (2026-08-31).
static func marquee_headline() -> String:
	return HEADLINE


static func marquee_sponsor() -> String:
	return SPONSOR
```

- [ ] **Step 5: Rebuild the marquee in `game/world/strip.gd`**

Delete `MARQUEE_AT`, `MARQUEE_SIZE` and `marquee_text()`, and replace `_marquee()`. Add these constants:

```gdscript
## THE MARQUEE BOARD, sized and placed from the PALACE'S OWN MEASUREMENTS rather than typed
## as world coordinates. mount_marquee() is handed the front face of the building, its half
## extents and its ridge height by ranch.gd, off the live node; every number below is a
## fraction or an offset applied to those. The pair could drift before, and did: a hand
## typed MARQUEE_AT sat at y = 5.4 on a building whose ridge is at 4.6.
##
## WIDTH is a fraction of the building's own width, so the board is always visibly narrower
## than the wall behind it. TOP_GAP is how far its top edge stays UNDER the ridge, which is
## the "mounted clear of the roofline" the report asked for. STANDOFF is how far in front of
## the wall it hangs, far enough that the two never fight for pixels.
const MARQUEE_WIDTH_FRACTION := 0.62
const MARQUEE_HEIGHT := 1.60
const MARQUEE_TOP_GAP := 0.35
const MARQUEE_STANDOFF := 0.55
const MARQUEE_BOARD_COLOR := Color(0.16, 0.07, 0.20)
const MARQUEE_TRIM_COLOR := Color(0.98, 0.86, 0.45)
const MARQUEE_TRIM := 0.10

## The headline fills this much of the board's height; the sponsor line under it is
## SPONSOR_SCALE of that. Both are a FRACTION OF THE BOARD, which is what "fitted text"
## means: change the board and the letters follow it.
const MARQUEE_HEADLINE_FRACTION := 0.34
const MARQUEE_SPONSOR_SCALE := 0.55

## Font size the Label3Ds are rasterised at. Only the ratio font_size * pixel_size is a
## physical size; this is picked high so the glyphs stay crisp on a board a player walks up
## to, and pixel_size is then derived from it.
const MARQUEE_FONT_SIZE := 96
```

Add the members:

```gdscript
var _marquee_centre := Vector3.ZERO
var _marquee_size := Vector2.ZERO
var _marquee_ceiling := 0.0
var _has_marquee := false
```

Add the mounting call and the readers:

```gdscript
## WHERE THE SIGN GOES, in the building's own terms. `front_centre` is the middle of the
## Palace's front wall in world space, `half_extents` its half width and half depth, and
## `ridge_y` the world height of its ridge. Call before build(), same contract as
## configure() and avoid_footprint(); an unmounted Strip simply stands no marquee, which is
## a Strip with no building on it.
##
## KEPT AS PLAIN NUMBERS rather than as a Building reference, for the reason
## avoid_footprint() gives: this file does not have to know what a Building is, and
## ranch.gd reads the live node's own width, depth and ridge_height so a re sited or
## re proportioned Palace moves its own sign.
func mount_marquee(front_centre: Vector3, half_extents: Vector2, ridge_y: float) -> void:
	var board_width: float = half_extents.x * 2.0 * MARQUEE_WIDTH_FRACTION
	_marquee_size = Vector2(board_width, MARQUEE_HEIGHT)
	_marquee_ceiling = ridge_y - MARQUEE_TOP_GAP
	_marquee_centre = Vector3(front_centre.x,
		_marquee_ceiling - MARQUEE_HEIGHT * 0.5,
		front_centre.z - MARQUEE_STANDOFF)
	_has_marquee = true


func marquee_board_size() -> Vector2:
	return _marquee_size


func marquee_board_centre() -> Vector3:
	return _marquee_centre


func marquee_top_y() -> float:
	return _marquee_centre.y + _marquee_size.y * 0.5


## What the board says, top line first. Read out of CasinoSign so the sign outside cannot
## drift from the sign in the lobby.
func marquee_lines() -> Array[String]:
	return [CasinoSignScript.marquee_headline(), CasinoSignScript.marquee_sponsor()]
```

and replace `_marquee()` itself:

```gdscript
## THE SIGN YOU READ ON THE WAY IN: a backing board with a trim edge, the headline fitted
## across it, and the sponsor line under it in smaller letters.
##
## FITTED MEANS THE TEXT IS TOLD HOW WIDE IT MAY BE. Label3D.width is a wrapping width in
## the same pixel units font_size is in, so setting it to the board's width in pixels and
## turning autowrap on is what actually stops a long line running off the edge; the old
## marquee set neither and rendered about 18 m of text across a 14 m building. pixel_size
## is then the board's real width divided by that same pixel width, so one number converts
## the whole thing and the letters cannot end up a different size from the board.
func _marquee() -> void:
	if not _has_marquee:
		return
	var board := MeshInstance3D.new()
	board.name = "MarqueeBoard"
	var box := BoxMesh.new()
	box.size = Vector3(_marquee_size.x, _marquee_size.y, 0.12)
	box.material = _flat_material(MARQUEE_BOARD_COLOR)
	board.mesh = box
	add_child(board)
	board.global_position = _marquee_centre

	var trim := MeshInstance3D.new()
	trim.name = "MarqueeTrim"
	var trim_box := BoxMesh.new()
	trim_box.size = Vector3(_marquee_size.x + MARQUEE_TRIM * 2.0,
		_marquee_size.y + MARQUEE_TRIM * 2.0, 0.08)
	trim_box.material = _flat_material(MARQUEE_TRIM_COLOR)
	trim.mesh = trim_box
	add_child(trim)
	trim.global_position = _marquee_centre + Vector3(0.0, 0.0, -0.03)

	var lines: Array[String] = marquee_lines()
	var headline_height: float = _marquee_size.y * MARQUEE_HEADLINE_FRACTION
	_marquee_label("MarqueeHeadline", lines[0], headline_height,
		_marquee_centre + Vector3(0.0, _marquee_size.y * 0.20, -0.09))
	_marquee_label("MarqueeSponsor", lines[1],
		headline_height * MARQUEE_SPONSOR_SCALE,
		_marquee_centre + Vector3(0.0, -_marquee_size.y * 0.24, -0.09))


## One line of the sign, `cap_height` metres tall, fitted to the board's width and hung at
## `at`. Faces the walk up from the homestead, which comes from Z below the building, so it
## turns a half turn to meet her: Label3D's own text faces plus Z.
func _marquee_label(label_name: String, text: String, cap_height: float,
		at: Vector3) -> void:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.font_size = MARQUEE_FONT_SIZE
	var pixel: float = cap_height / float(MARQUEE_FONT_SIZE)
	label.pixel_size = pixel
	# The width the text may occupy, in the same pixel units font_size is in. Set together
	# with the wrap mode; either one alone does nothing.
	label.width = _marquee_size.x / pixel
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = MARQUEE_COLOR
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.shaded = false
	label.no_depth_test = false
	add_child(label)
	label.global_position = at
	label.rotation.y = PI


func _flat_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat
```

- [ ] **Step 6: Hand the Palace's own measurements over in `ranch.gd`**

In `_ready()`, inside the `if strip != null` block that already reads `palace_building`, add the mount right after the existing `strip.avoid_footprint(...)` call and before `strip.build()`:

```gdscript
		if palace_building != null:
			strip.avoid_footprint(
				Vector2(palace_building.global_position.x, palace_building.global_position.z),
				Vector2(palace_building.width * 0.5, palace_building.depth * 0.5))
			# THE SIGN IS SIZED AND PLACED FROM THE BUILDING, off the live node, for the
			# reason avoid_footprint() is: a hand typed world position for the marquee is
			# what put a 66 character line at y = 5.4 on a building whose ridge is at 4.6.
			# The Palace is turned a half turn in ranch.tscn, so its door and its front face
			# are on the LOW Z side; the front centre is therefore its origin minus half its
			# depth along Z.
			strip.mount_marquee(
				palace_building.global_position
					- Vector3(0.0, 0.0, palace_building.depth * 0.5),
				Vector2(palace_building.width * 0.5, palace_building.depth * 0.5),
				palace_building.global_position.y + palace_building.ridge_height)
		strip.build()
```

Then grep for the old reader and fix its one caller:
```bash
grep -rn "marquee_text" game/ docs/
```
Every hit becomes `marquee_lines()`; where a single string is wanted, join with `", "` or use `CasinoSignScript.MARQUEE`, which is unchanged.

- [ ] **Step 7: Run the tests to verify they pass**

Run:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_building_base.gd -gtest=res://test/test_strip.gd \
  -gtest=res://test/test_casino_sign.gd -gexit
bash tools/run_tests.sh
```
Expected: PASS. If `test_no_building_on_the_shipped_map_can_fight_the_ground` fails for a building other than the Palace, that building is standing on worse relief than the Palace is and `FLOOR_TOP` has to rise to clear it; the message names the building and prints both numbers. Do NOT lower `MARGIN` to make it green.

- [ ] **Step 8: Look at it**

```bash
tools/bin/godot --path game world/ranch.tscn
```
Walk to the Strip. The base of the Palace is a solid step, not a flicker; walk right around it and watch the corners, which is where the relief is worst. The sign in front of the door reads `Spectra Palace` with `proudly sponsored by Cloudsdale Weather Corporation` under it, both inside a lit board, with the roof clearly above it.

- [ ] **Step 9: Run every gate**

```bash
for scene in market_test region_test world_test collection_test ledger_test depot_test creation_test casino_test; do
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" >/dev/null 2>&1
  echo "$scene exit $?"
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```
Expected: every gate exit 0; `RANCH_OK ponies=49 props=60 assets=present`. The plinth adds no node and no prop: it is the same `Floor` slab at a different size.

- [ ] **Step 10: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'fix: a plinth under every building, and a marquee that fits its own board\n\nTwo reports from 2026-08-31. "z fighting at the palace base, a flickering skirt\nwhere the building meets terrain": Building.build() laid a Floor slab 0.14 m\nthick with its bottom face at local y = 0, and the ground under the Palace has\n0.633 m of relief across its 14 by 9 m footprint (already measured, see\nPALACE_MAX_RELIEF). The floor is a plinth now, FLOOR_TOP 0.75 above the origin\nand SKIRT_DEPTH 1.20 below it, so the terrain crosses the SIDE of a solid box\nrather than grazing a horizontal face. test_building_base.gd asserts that for\nEVERY building in ranch.tscn at its own four corners, which is the only way to\nanswer "does any other one show it".\n\n"marquee is unreadable and clips the roof": a bare Label3D with no width limit\ncarrying a 66 character line at 0.0086 m per pixel, about 18 m of text across a\n14 m building, hung at y 5.4 on a building whose ridge is 4.6. It is a fitted\nsign now: a backing board and trim sized from the Palace s own width, a headline\nfilling a third of the board height, the sponsor line under it at 55 per cent of\nthat, both with Label3D.width and AUTOWRAP_WORD actually set. Every number comes\nfrom the live building through Strip.mount_marquee(), so the sign cannot drift\nfrom the building again.\n' > /tmp/palace-commit.txt
git add game/world/building.gd game/world/strip.gd game/world/ranch.gd \
  game/systems/casino_sign.gd game/test/test_building_base.gd game/test/test_strip.gd \
  game/test/test_casino_sign.gd
git commit -F /tmp/palace-commit.txt
```

---

### Task 4: One menu style, and hints for the device in your hands

**Files:**
- Create: `game/systems/input_device.gd`, `game/ui/menu_style.gd`, `game/test/test_input_device.gd`, `game/test/test_menu_style.gd`
- Modify: `game/project.godot` (the `[autoload]` block), `game/ui/table_menu.gd`, `game/ui/casino_menu.gd`, `game/ui/build_menu.gd`, `game/ui/market_menu.gd`, `game/ui/depot_menu.gd`, `game/ui/pause_menu.gd`, `game/ui/hud.gd`, `game/world/ranch.gd` (`INTERACT_KEY`)
- Test: `game/test/test_input_device.gd`, `game/test/test_menu_style.gd`, `game/test/test_hud.gd`

**Interfaces:**
- Consumes: `Interaction.prompt_for(action: Dictionary, key: String) -> String` (Task 2), `InputMap.has_action(action: StringName) -> bool`, `InputMap.action_get_events(action: StringName) -> Array[InputEvent]`.
- Produces:
  - `class_name InputDevice extends Node`, registered as the autoload `InputDevice`.
    - `enum Kind { KEYBOARD, GAMEPAD }`, `const STICK_DEADZONE := 0.5`
    - `const GLYPHS: Dictionary`, `const ACTION_GLYPHS: Array[StringName]`
    - `static func note(event: InputEvent) -> void`, `static func last() -> int`, `static func using_gamepad() -> bool`, `static func hint(action: StringName) -> String`, `static func reset() -> void`
  - `class_name MenuStyle extends RefCounted`, static only.
    - colours `COLOR_TITLE`, `COLOR_NAME`, `COLOR_DIM`, `COLOR_VALUE`, `COLOR_UNAFFORDABLE`, `COLOR_TAB_ON`, `COLOR_TAB_OFF`, `ROW_SELECTED_BG`, `ROW_SELECTED_BORDER`, `ROW_IDLE_BG`, `ROW_IDLE_BORDER`
    - sizes `TITLE_SIZE` (30), `ROW_SIZE` (22), `FOOTER_SIZE` (20); `CARET` (`"> "`), `NO_CARET` (`"  "`)
    - `static func style_label(label: Label, size: int, colour: Color) -> void`
    - `static func caret(picked: bool) -> String`
    - `static func tab_strip(names: Array[String], active: int) -> String`
    - `static func footer(pairs: Array) -> String`
    - `static func footer_tabs_and_rows(verb: String, leave: String) -> String`
    - `static func footer_rows(verb: String, leave: String) -> String`
    - `static func footer_reading(leave: String) -> String`

**The report.** "Menu polish pass across ALL CanvasLayer menus: one shared visual style, and device aware input hints; show keyboard hints XOR gamepad hints based on the last input device used, not both at once." Three different footers ship today and every one of them prints both schemes on one line, which is how `"  ← → / D-pad  tab      ↑ ↓  choose      Enter / A  confirm      Esc / B  back"` happened. Six files each declare their own copy of the same four or five colours.

**What is deliberately NOT done here.** No menu's logic changes, no signal changes, no provider Callable changes, and every menu keeps its own `drawn_lines()` and its own `_unhandled_input()`. This task swaps constants for shared ones and footers for a builder. `game/ui/creation_screen.gd` is left alone: it is a Button and LineEdit screen, not a caret and row list, and restyling it belongs with a redesign rather than with a polish pass.

**Why the tracker is an autoload with static state.** The reader has to work from a `RefCounted` static helper (`MenuStyle`) with no node to hand, so the STATE is `static var` on the script and every reader gets at it through a plain preload. The WRITER has to see every event in the game including while the tree is paused, which is exactly when a menu is up, so it needs a node with `_input()` and `PROCESS_MODE_ALWAYS`. One script does both: the autoload instance writes, the statics read, and a test can drive `note()` directly with no autoload at all.

- [ ] **Step 1: Write the failing tests**

`game/test/test_input_device.gd`:

```gdscript
extends GutTest
## WHICH THING IS IN THE PLAYER'S HANDS, and the glyphs the menus print because of it.
##
## The state is static, so every test here resets it first: a leaked GAMEPAD from one case
## would make the next one pass for the wrong reason.

const InputDeviceScript := preload("res://systems/input_device.gd")


func before_each() -> void:
	InputDeviceScript.reset()


func test_it_starts_on_the_keyboard() -> void:
	assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD,
		"somebody at a keyboard must not have to press a key to be recognised")
	assert_false(InputDeviceScript.using_gamepad())


func test_a_key_press_is_the_keyboard() -> void:
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	InputDeviceScript.note(pad)
	var key := InputEventKey.new()
	key.keycode = KEY_E
	InputDeviceScript.note(key)
	assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD)


func test_a_mouse_click_and_a_mouse_move_are_both_the_keyboard() -> void:
	for event: InputEvent in [InputEventMouseButton.new(), InputEventMouseMotion.new()]:
		var pad := InputEventJoypadButton.new()
		InputDeviceScript.note(pad)
		InputDeviceScript.note(event)
		assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD,
			"a mouse is part of the keyboard scheme, not a third one")


func test_a_pad_button_is_the_gamepad() -> void:
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	InputDeviceScript.note(pad)
	assert_true(InputDeviceScript.using_gamepad())


## AN IDLE STICK DRIFTS. Without the deadzone the whole HUD would flip to gamepad hints
## while the controller sat on the table, and flip back the moment the mouse moved.
func test_a_stick_inside_the_deadzone_changes_nothing() -> void:
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = InputDeviceScript.STICK_DEADZONE - 0.01
	InputDeviceScript.note(drift)
	assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD)


func test_a_stick_pushed_past_the_deadzone_is_the_gamepad_in_both_directions() -> void:
	for value: float in [InputDeviceScript.STICK_DEADZONE, -1.0]:
		InputDeviceScript.reset()
		var push := InputEventJoypadMotion.new()
		push.axis = JOY_AXIS_LEFT_Y
		push.axis_value = value
		InputDeviceScript.note(push)
		assert_true(InputDeviceScript.using_gamepad(), "axis_value %.2f" % value)


func test_an_event_of_no_interest_leaves_the_answer_where_it_was() -> void:
	var pad := InputEventJoypadButton.new()
	InputDeviceScript.note(pad)
	InputDeviceScript.note(InputEventAction.new())
	assert_true(InputDeviceScript.using_gamepad(),
		"a synthetic action event says nothing about who sent it")


func test_null_is_survivable() -> void:
	InputDeviceScript.note(null)
	assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD)


# --- the glyphs -----------------------------------------------------------------------------

func test_the_hint_follows_the_device() -> void:
	assert_eq(InputDeviceScript.hint(&"interact"), "E")
	var pad := InputEventJoypadButton.new()
	InputDeviceScript.note(pad)
	assert_eq(InputDeviceScript.hint(&"interact"), "X")


func test_an_unknown_action_answers_an_empty_string_rather_than_erroring() -> void:
	assert_eq(InputDeviceScript.hint(&"no_such_action_anywhere"), "")


## THE CARD THAT LIES. Every glyph in ACTION_GLYPHS names a real action in
## game/project.godot, and every one of those actions really does carry both a keyboard
## style event and a joypad event; a binding that is removed there and not here is a hint
## that tells the player to press a key that does nothing.
func test_every_named_action_exists_and_is_bound_on_both_schemes() -> void:
	for action: StringName in InputDeviceScript.ACTION_GLYPHS:
		assert_true(InputMap.has_action(action), "%s is not an action at all" % action)
		var keyboard := false
		var gamepad := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				keyboard = true
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				gamepad = true
		assert_true(keyboard, "%s has no keyboard binding but the hints promise one" % action)
		assert_true(gamepad, "%s has no gamepad binding but the hints promise one" % action)


func test_no_glyph_carries_a_dash() -> void:
	for key: StringName in InputDeviceScript.GLYPHS:
		for glyph: String in InputDeviceScript.GLYPHS[key]:
			assert_false(glyph.contains("--") or glyph.contains("—"), glyph)
```

`game/test/test_menu_style.gd`:

```gdscript
extends GutTest
## ONE LOOK FOR EVERY PANEL, and one place the keys at the bottom of it are written.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")


func before_each() -> void:
	InputDeviceScript.reset()


func test_the_caret_marks_the_row_and_pads_the_others_to_the_same_width() -> void:
	assert_eq(MenuStyleScript.caret(true).length(), MenuStyleScript.caret(false).length(),
		"a caret that is wider than the padding makes every row jump when it is selected")
	assert_ne(MenuStyleScript.caret(true), MenuStyleScript.caret(false))


func test_the_tab_strip_brackets_exactly_one_tab() -> void:
	var strip: String = MenuStyleScript.tab_strip(["Cage", "House", "Games"], 1)
	assert_true(strip.contains("[House]"))
	assert_false(strip.contains("[Cage]"))
	assert_false(strip.contains("[Games]"))


func test_a_tab_index_out_of_range_brackets_nothing_rather_than_erroring() -> void:
	var strip: String = MenuStyleScript.tab_strip(["Cage", "House"], 9)
	assert_false(strip.contains("["))


## THE REPORT: "show keyboard hints XOR gamepad hints based on the last input device used,
## not both at once". Every shipped footer printed both, on one line, forever.
func test_the_footer_shows_one_scheme_and_never_both() -> void:
	var keyboard: String = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	assert_true(keyboard.contains("Enter"))
	assert_false(keyboard.contains("A  confirm"),
		"the gamepad glyph must not be on the keyboard footer")
	var pad := InputEventJoypadButton.new()
	InputDeviceScript.note(pad)
	var gamepad: String = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	assert_false(gamepad.contains("Enter"),
		"the keyboard glyph must not be on the gamepad footer")
	assert_true(gamepad.contains("A"))


func test_the_footer_names_the_verb_it_is_given() -> void:
	assert_true(MenuStyleScript.footer_rows("build", "back").contains("build"))
	assert_true(MenuStyleScript.footer_rows("build", "back").contains("back"))


func test_the_reading_footer_offers_only_a_way_out() -> void:
	var line: String = MenuStyleScript.footer_reading("back")
	assert_true(line.contains("back"))
	assert_false(line.contains("confirm"),
		"a page with nothing to confirm must not offer to confirm it")


func test_every_footer_starts_with_the_same_indent() -> void:
	for line: String in [MenuStyleScript.footer_tabs_and_rows("confirm", "leave"),
			MenuStyleScript.footer_rows("build", "back"),
			MenuStyleScript.footer_reading("back")]:
		assert_true(line.begins_with(MenuStyleScript.NO_CARET),
			"footers line up under the rows: %s" % line)


func test_nothing_the_style_prints_carries_a_dash() -> void:
	var lines: Array[String] = [
		MenuStyleScript.footer_tabs_and_rows("confirm", "leave"),
		MenuStyleScript.footer_rows("sell", "back"),
		MenuStyleScript.footer_reading("back"),
		MenuStyleScript.tab_strip(["Deliver", "Pay", "Statement"], 0),
	]
	var pad := InputEventJoypadButton.new()
	InputDeviceScript.note(pad)
	lines.append(MenuStyleScript.footer_tabs_and_rows("confirm", "leave"))
	for line in lines:
		assert_false(line.contains("--") or line.contains("—"), line)


func test_styling_a_label_sets_a_size_and_a_colour_that_can_be_read_back() -> void:
	var label := Label.new()
	add_child_autofree(label)
	MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_VALUE)
	assert_eq(label.get_theme_font_size("font_size"), MenuStyleScript.ROW_SIZE)
	assert_eq(label.get_theme_color("font_color"), MenuStyleScript.COLOR_VALUE)
```

- [ ] **Step 2: Run them to make sure they fail**

Run:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_input_device.gd -gtest=res://test/test_menu_style.gd -gexit
```
Expected: FAIL, both scripts ignored because neither `res://systems/input_device.gd` nor `res://ui/menu_style.gd` exists.

- [ ] **Step 3: Write `game/systems/input_device.gd`**

```gdscript
class_name InputDevice
extends Node
## WHICH THING IS IN THE PLAYER'S HANDS RIGHT NOW, so a panel can print one set of hints
## instead of both. The owner, 2026-08-31: "show keyboard hints XOR gamepad hints based on
## the last input device used, not both at once". Every shipped footer printed both on one
## line, which is how a menu ends up saying "Enter / A  confirm      Esc / B  leave".
##
## ONE SCRIPT, TWO HALVES, AND THE SPLIT IS THE WHOLE DESIGN. The READERS are static
## (last(), using_gamepad(), hint()), because game/ui/menu_style.gd is a RefCounted helper
## with no node to reach a singleton through, and because a test can then drive the whole
## thing with note() and no autoload at all. The WRITER is a node, because seeing every
## event in the game needs _input(), and it is registered as an autoload in
## game/project.godot beside AudioSafety and GameState.
##
## PROCESS_MODE_ALWAYS, AND IT IS NOT OPTIONAL. Every menu in this game pauses the tree
## while it is up (game/world/ranch.gd owns that), which is exactly when the hints are on
## screen being read. A tracker that stopped with the tree would freeze on whichever device
## closed the last menu and never move again.
##
## A STICK IS ONLY A STICK PAST THE DEADZONE. An idle thumbstick drifts and emits
## InputEventJoypadMotion forever; a tracker that believed all of them would flip the whole
## HUD to gamepad hints while the controller sat on the table.
##
## Readers preload this by path, like everything else in this project.

enum Kind { KEYBOARD, GAMEPAD }

## How far a stick has to be pushed before it counts as somebody using it.
const STICK_DEADZONE := 0.5

## WHAT EACH THING IS CALLED ON EACH DEVICE, keyboard first, gamepad second.
##
## The first five keys are real actions in game/project.godot's [input] block and
## test_input_device.gd walks the live InputMap to prove each one is really bound on both
## schemes; a binding removed there and not here is a hint that tells the player to press
## something that does nothing.
##
## The last two are COMPOSITES and are deliberately not actions. A footer says "the two
## keys that change row", and spelling that as two separate entries doubles the length of
## every footer in the game to say one thing twice. ACTION_GLYPHS below is the subset that
## is checked against the InputMap.
const GLYPHS := {
	&"interact": ["E", "X"],
	&"ui_accept": ["Enter", "A"],
	&"ui_cancel": ["Esc", "B"],
	&"pause": ["Esc", "Start"],
	&"toggle_hints": ["H", "Back"],
	&"menu_rows": ["Up Down", "D-pad up down"],
	&"menu_tabs": ["Left Right", "D-pad left right"],
}

## The subset of GLYPHS that names a real action. See GLYPHS.
const ACTION_GLYPHS: Array[StringName] = [&"interact", &"ui_accept", &"ui_cancel",
	&"pause", &"toggle_hints"]

## Static, so a reader needs no node. Starts on the keyboard: somebody sitting at one must
## not have to press a key before the game will admit she is there.
static var _last: int = Kind.KEYBOARD


func _ready() -> void:
	# See the class comment: the menus that read this are on screen precisely when the tree
	# is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	note(event)


## Record what sent `event`. Anything that is not one of the five interesting classes
## leaves the answer exactly where it was, which is the right answer for a synthetic
## InputEventAction: it says nothing about who sent it.
static func note(event: InputEvent) -> void:
	if event == null:
		return
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventMouseMotion:
		_last = Kind.KEYBOARD
	elif event is InputEventJoypadButton:
		_last = Kind.GAMEPAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= STICK_DEADZONE:
			_last = Kind.GAMEPAD


static func last() -> int:
	return _last


static func using_gamepad() -> bool:
	return _last == Kind.GAMEPAD


## What to print for `action` on the device she is holding. An unknown action answers the
## empty string rather than erroring: a footer with a gap in it is a cosmetic fault and a
## crashed menu is not.
static func hint(action: StringName) -> String:
	if not GLYPHS.has(action):
		return ""
	var pair: Array = GLYPHS[action]
	return String(pair[1] if using_gamepad() else pair[0])


## Back to the keyboard. For the tests, which share one static and would otherwise leak a
## GAMEPAD from one case into the next.
static func reset() -> void:
	_last = Kind.KEYBOARD
```

- [ ] **Step 4: Register the autoload**

In `game/project.godot`, extend the `[autoload]` block:

```
[autoload]

AudioSafety="*res://systems/audio_safety.gd"
GameState="*res://systems/game_state.gd"
InputDevice="*res://systems/input_device.gd"
```

- [ ] **Step 5: Write `game/ui/menu_style.gd`**

```gdscript
class_name MenuStyle
extends RefCounted
## ONE LOOK FOR EVERY PANEL IN THE GAME, and one place the keys at the bottom of one are
## written. The owner, 2026-08-31: "menu polish pass across ALL CanvasLayer menus: one
## shared visual style (consistent title bar, row height, selected row treatment, footer)".
##
## WHAT WAS ACTUALLY WRONG. Six menu scripts each declared their own copy of the same four
## or five colours, and three different footers shipped: the market, depot and pause line,
## the build line, and the casino suite's line, each describing the same two keys in
## different words. A player reads that as three different games.
##
## THIS FILE CHANGES NO MENU'S LOGIC. Every menu keeps its own drawn_lines(), its own
## row_count(), its own signals and its own _unhandled_input(); they draw and ranch.gd
## transacts, exactly as before. What they stop doing is each inventing a palette and a
## footer.
##
## Static only, no state, no scene. Preload by path.

const InputDeviceScript := preload("res://systems/input_device.gd")

# --- the palette ----------------------------------------------------------------------------
# Lifted verbatim from game/ui/pause_menu.gd and game/ui/market_menu.gd, which agreed with
# each other; the casino suite's slightly different numbers are the ones that move.

const COLOR_TITLE := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_VALUE := Color(1.00, 0.80, 0.25, 1.0)
const COLOR_UNAFFORDABLE := Color(1.0, 0.45, 0.42, 0.85)
const COLOR_TAB_ON := Color(1.0, 0.86, 0.55, 1.0)
const COLOR_TAB_OFF := Color(1.0, 1.0, 1.0, 0.40)
const ROW_SELECTED_BG := Color(1.0, 0.86, 0.55, 0.16)
const ROW_SELECTED_BORDER := Color(1.0, 0.86, 0.55, 0.75)
const ROW_IDLE_BG := Color(1.0, 1.0, 1.0, 0.04)
const ROW_IDLE_BORDER := Color(1.0, 1.0, 1.0, 0.10)

## Title, row and footer, in 1920x1080 base pixels (game/project.godot stretches
## canvas_items against that viewport, so these are the same size on every screen).
const TITLE_SIZE := 30
const ROW_SIZE := 22
const FOOTER_SIZE := 20

## THE CARET AND ITS PADDING ARE THE SAME WIDTH ON PURPOSE. A marker wider than the space
## that replaces it makes every row shift sideways as the cursor passes over it.
const CARET := "> "
const NO_CARET := "  "


static func style_label(label: Label, size: int, colour: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)


static func caret(picked: bool) -> String:
	return CARET if picked else NO_CARET


## The tab strip every multi tab panel prints: the active one in brackets, the rest in the
## same width of space, so the strip does not shuffle as the tab changes. An index outside
## the list brackets nothing, which is what a panel with no tab selected should look like.
static func tab_strip(names: Array[String], active: int) -> String:
	var out: Array[String] = []
	for i in names.size():
		out.append("[%s]" % names[i] if i == active else " %s " % names[i])
	return "   ".join(out)


## A FOOTER, IN THE GLYPHS OF THE DEVICE SHE IS ACTUALLY HOLDING. `pairs` is an array of
## two element arrays: the action (or composite) name, and the verb it performs.
##
## ONE SCHEME, NEVER BOTH. That is the whole point of this function and of
## game/systems/input_device.gd behind it.
static func footer(pairs: Array) -> String:
	var out: Array[String] = []
	for pair: Array in pairs:
		var glyph: String = InputDeviceScript.hint(StringName(pair[0]))
		if glyph.is_empty():
			continue
		out.append("%s  %s" % [glyph, String(pair[1])])
	return NO_CARET + "      ".join(out)


## The footer for a panel with tabs AND rows: the Market, the Depot, the casino lobby and
## every table in it.
static func footer_tabs_and_rows(verb: String, leave: String) -> String:
	return footer([[&"menu_rows", "choose"], [&"menu_tabs", "tab"],
		[&"ui_accept", verb], [&"ui_cancel", leave]])


## The footer for a single list: the build menu, the pause menu's main page.
static func footer_rows(verb: String, leave: String) -> String:
	return footer([[&"menu_rows", "choose"], [&"ui_accept", verb], [&"ui_cancel", leave]])


## The footer for a page that is reading matter: the compendium, the house rules, the
## statement. It offers no confirm, because there is nothing to confirm.
static func footer_reading(leave: String) -> String:
	return footer([[&"menu_rows", "scroll"], [&"ui_cancel", leave]])
```

- [ ] **Step 6: Run the two new test files to verify they pass**

Run:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_input_device.gd -gtest=res://test/test_menu_style.gd -gexit
```
Expected: PASS. If `test_every_named_action_exists_and_is_bound_on_both_schemes` fails, `game/project.godot` really is missing a binding the hints promise; fix the binding, not the table.

- [ ] **Step 7: Move every menu onto the shared style**

The same five edits in each file. Do them one file at a time and run that file's own test between each.

In each of `game/ui/table_menu.gd`, `casino_menu.gd`, `build_menu.gd`, `market_menu.gd`, `depot_menu.gd` and `pause_menu.gd`:

1. Add `const MenuStyleScript := preload("res://ui/menu_style.gd")` to the preload block.
2. Delete that file's own `COLOR_*` / `ROW_*` constants and replace every use with `MenuStyleScript.<same name>`. Every name matches; the values in `market_menu.gd` and `pause_menu.gd` are already identical, and `table_menu.gd`'s and `casino_menu.gd`'s three (`COLOR_NAME`, `COLOR_VALUE`, `COLOR_DIM`) are too.
3. Delete that file's `FOOTER` / `FOOTER_DEFAULT` / `RACE_FOOTER` / `FOOTER_MAIN` and friends, and set the footer text from the builder at the top of the function that already redraws:

| File | Old constant | New call |
|---|---|---|
| `table_menu.gd` | `FOOTER` | `MenuStyleScript.footer_tabs_and_rows("confirm", "leave")` |
| `casino_menu.gd` | `FOOTER` | `MenuStyleScript.footer_tabs_and_rows("confirm", "leave")` |
| `build_menu.gd` | the two inline literals | `MenuStyleScript.footer_rows("build", "back")` |
| `market_menu.gd` | `FOOTER_DEFAULT` | `MenuStyleScript.footer_tabs_and_rows("confirm", "back")` |
| `depot_menu.gd` | `FOOTER` | `MenuStyleScript.footer_tabs_and_rows("confirm", "leave")` |
| `pause_menu.gd` | `FOOTER_MAIN` | `MenuStyleScript.footer_rows("select", "resume")` |
| `pause_menu.gd` | `FOOTER_SETTINGS` | `MenuStyleScript.footer([[&"menu_rows", "choose"], [&"menu_tabs", "adjust"], [&"ui_cancel", "back"]])` |
| `pause_menu.gd` | `FOOTER_COMPENDIUM` | `MenuStyleScript.footer_reading("back")` |
| `pause_menu.gd` | `FOOTER_LEDGER` | `MenuStyleScript.footer_reading("back")` |
| `pause_menu.gd` | `FOOTER_REQUESTS` | `MenuStyleScript.footer_reading("back") + "      Finish one to get a new one."` |

4. Replace each file's own `_style_label()` with `MenuStyleScript.style_label()` and delete the private copy.
5. **Rebuild the footer on every redraw, not only in `_ready()`.** This is what makes the hints follow the device without a signal: `refresh()` already runs on `open()` and on every navigation press, so the first press after unplugging a controller repaints the footer. Concretely, add this as the first thing each file's `refresh()` (or `_redraw()` / `_show_page()`) does:

```gdscript
	_footer.text = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
```

(with that file's own verb and leave word from the table above; `pause_menu.gd` sets it per page in the five `_show_*()` functions it already has, and `market_menu.gd` keeps its "cannot afford" override, which simply replaces the text afterwards as it already does).

6. Replace each file's hand written tab strip with `MenuStyleScript.tab_strip(...)`. `casino_menu.gd`'s current strip uses `TAB_NAMES.find(t)` inside a lambda, which is wrong the moment two tabs are named the same; the shared one indexes properly.

7. Replace every `("> " if picked else "  ")` with `MenuStyleScript.caret(picked)`.

- [ ] **Step 8: Make the HUD hints card device aware too**

The card is the biggest offender: three columns, keyboard and gamepad side by side, permanently. In `game/ui/hud.gd`, replace the `HINTS` constant and `_build_hints()`:

```gdscript
## THE CONTROL CARD, IN THE GLYPHS OF ONE DEVICE. Every row here mirrors an action in
## game/project.godot's [input] block; a binding that changes there and not here is a hint
## card that lies.
##
## IT USED TO PRINT BOTH SCHEMES SIDE BY SIDE, on the stated grounds that "the build is
## handed to two people and only one of them is going to be at the keyboard". That is still
## true and it is now answered by showing the scheme in use rather than both at once
## (owner, 2026-08-31); game/systems/input_device.gd is what knows which.
##
## A GridContainer of Labels rather than one pre-aligned block of text: Godot's default UI
## font is proportional, so space-padded columns line up in the source file and nowhere
## else. Two columns now, not three.
##
## RUNNING IS THE DEFAULT AND SHIFT SLOWS YOU DOWN, which is the opposite of what every
## other game trains a player to expect, so the card says what the slow gait BUYS on its
## own continuation line.
const HINTS := [
	["MOVE (run)", "W A S D", "Left stick"],
	["WALK / SNEAK", "Shift (hold)", "LB (hold)"],
	["", "creep quietly, and ponies notice you from half as far", ""],
	["JUMP", "Space", "A"],
	["INTERACT", "E", "X"],
	["", "the line under the crosshair says what it will do", ""],
	["LOOK", "Mouse", "Right stick"],
	["ZOOM", "Scroll / = -", "D-pad up down"],
	["MAGIC BEAM", "Right mouse (hold)", "Right trigger (hold)"],
	["", "hold until the OUTER PINK ring fills, then let go to stow her", ""],
	["", "the INNER AMBER ring is her fight. Let it empty and she wriggles free", ""],
	["SELL GEMS", "E at the Market", "X at the Market"],
	["PAUSE", "Esc", "Start"],
	["THIS CARD", "H", "Back"],
]


func _build_hints() -> void:
	_hints_grid.columns = 2
	for child in _hints_grid.get_children():
		child.queue_free()
	var column: int = 2 if InputDeviceScript.using_gamepad() else 1
	for row: Array in HINTS:
		var label_text := String(row[0])
		var note: bool = label_text == ""
		for pair: Array in [[label_text, 0.60], [String(row[column if not note else 1]), 0.92]]:
			var label := Label.new()
			label.text = String(pair[0])
			_style_label(label, 20, Color(1.0, 1.0, 1.0, float(pair[1])))
			_hints_grid.add_child(label)
	_hints_device = InputDeviceScript.last()
```

with the preload and the member added:

```gdscript
const InputDeviceScript := preload("res://systems/input_device.gd")
```
```gdscript
## Which device the card was last built for, so _process() can rebuild it when she puts one
## down and picks the other up. Cheap: fourteen Labels, and only on an actual change.
var _hints_device: int = -1
```

and this at the top of `_process()`:

```gdscript
	if _hints_device != InputDeviceScript.last():
		_build_hints()
```

- [ ] **Step 9: Make the interaction prompt device aware**

In `game/world/ranch.gd`, delete the `INTERACT_KEY` constant Task 2 added and read the glyph instead. Add the preload:

```gdscript
const InputDeviceScript := preload("res://systems/input_device.gd")
```

and change the one line in `_update_interaction()`:

```gdscript
		hud.set_prompt(InteractionScript.prompt_for(action,
			InputDeviceScript.hint(&"interact")))
```

- [ ] **Step 10: Run everything**

```bash
bash tools/run_tests.sh
for scene in market_test region_test world_test collection_test ledger_test depot_test creation_test casino_test; do
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" >/dev/null 2>&1
  echo "$scene exit $?"
done
```
Expected: green, and every gate exit 0. Several menu tests assert footer text (`test_the_footer_documents_where_the_stake_actually_lives` in `test_race_menu.gd` is one); update each to ask the shared builder for the string it expects rather than pinning a literal, which is the assertion they should have been making. Any test asserting a menu's own `COLOR_*` constant now reads `MenuStyleScript`'s.

- [ ] **Step 11: Look at it**

```bash
tools/bin/godot --path game world/ranch.tscn
```
Open the build menu, the Market, the Depot, the pause menu and the casino lobby in one run: same title, same row height, same gold on the selected row, same footer shape. Press a key and every footer reads `Enter  confirm`; push a gamepad stick and the next redraw reads `A  confirm`, and the HUD's hint card flips with it.

- [ ] **Step 12: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'feat: one menu style, and hints for the device in your hands\n\nThe owner, 2026-08-31: one shared visual style across every CanvasLayer menu,\nand keyboard hints XOR gamepad hints rather than both at once. Three different\nfooters shipped and every one of them printed both schemes on one line; six menu\nscripts each declared their own copy of the same colours.\n\ngame/systems/input_device.gd is one script with two halves: static readers, so\ngame/ui/menu_style.gd (a RefCounted with no node) can ask, and a node writer\nregistered as an autoload so _input() sees everything. PROCESS_MODE_ALWAYS,\nbecause every menu pauses the tree and that is exactly when the hints are being\nread. A stick only counts past STICK_DEADZONE, or an idle controller on a table\nwould hold the whole HUD in gamepad glyphs.\n\ngame/ui/menu_style.gd carries the palette, the sizes, the caret, the tab strip\nand the footer builder. No menu logic changed: they still draw and emit and\nranch.gd still transacts. The HUD hint card drops from three columns to two and\nrebuilds itself when the device changes.\n' > /tmp/style-commit.txt
git add game/systems/input_device.gd game/systems/input_device.gd.uid \
  game/ui/menu_style.gd game/ui/menu_style.gd.uid game/project.godot \
  game/ui/table_menu.gd game/ui/casino_menu.gd game/ui/build_menu.gd \
  game/ui/market_menu.gd game/ui/depot_menu.gd game/ui/pause_menu.gd game/ui/hud.gd \
  game/world/ranch.gd game/test/test_input_device.gd game/test/test_menu_style.gd \
  game/test/test_hud.gd
git add -u game/test
git commit -F /tmp/style-commit.txt
```

---

### Task 5: The Palace explains itself

**Files:**
- Modify: `game/ui/casino_menu.gd`, `game/ui/table_menu.gd`, `game/ui/slots_menu.gd`, `game/ui/wheel_menu.gd`, `game/ui/blackjack_menu.gd`, `game/systems/casino_sign.gd`, `game/world/ranch.gd`
- Test: `game/test/test_casino_menu.gd`, `game/test/test_slots_menu.gd`, `game/test/test_wheel_menu.gd`, `game/test/test_blackjack_menu.gd`, `game/test/test_casino_sign.gd`

**Interfaces:**
- Consumes: `MenuStyle.*` (Task 4), `CasinoMenu.buy_amounts() -> Array[int]`, `CasinoMenu.cash_amounts() -> Array[int]`, `TableMenu.stakes() -> Array[int]`, `TableMenu.selected_stake() -> int`, `TableMenu.show_result(lines: Array[String]) -> void`, `Casino.CHIP_RATE` (1), `Slots.house_edge()`, `Wheel.house_edge()`, `Blackjack.house_edge()`, `RaceCard.TAKEOUT`.
- Produces:
  - `CasinoMenu.Row` enum: `enum Row { CAGE, SLOTS, WHEEL, BLACKJACK, RACING, RULES }` and `const LOBBY_ROWS: Array[String]`.
  - `CasinoMenu` signal `room_requested(row: int)` replacing `game_requested(game: int)`; `cage_requested()`; `Tab` reduced to `enum Tab { LOBBY, CAGE, RULES }`.
  - `CasinoSign.cage_explainer() -> Array[String]`.
  - `TableMenu.chips_line() -> String`, `TableMenu.keys_line() -> String`, `TableMenu.result_block() -> Array[String]`.
  - `ranch._on_room_requested(row: int) -> void`.

**The report.** "Casino usability: rework the casino flow so it is playable without reading docs. Entering the Palace opens ONE lobby screen with big obvious rows (Cage / Slots / Wheel / Blackjack / Racing / House rules), each table screen shows your chips, the stake picker, and what keys do what, results render prominently (win/lose line with numbers), and the cage explains itself." Today the lobby opens on a `CAGE` tab whose rows are bare amounts, the games live behind a third tab a player has to find with left and right, and a table's result is two lines pushed into the same list as its rows with nothing marking them as the result.

**This is a UI and copy rework, not new game logic.** No paytable, no edge, no settle and no `Casino` method changes. The injected Callable architecture stays exactly as it is: `can_open`, `bits_provider`, `chips_provider`, `sign_provider`, three signals out, and `ranch.gd` doing every transaction.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_casino_menu.gd` (which already builds the menu with four lambdas in `before_each`; keep that):

```gdscript
## THE REPORT: "entering the Palace opens ONE lobby screen with big obvious rows".
func test_it_opens_on_the_lobby_with_one_row_per_room() -> void:
	assert_eq(_menu.tab(), CasinoMenu.Tab.LOBBY)
	var drawn: Array[String] = _menu.drawn_lines()
	assert_eq(drawn.size(), CasinoMenu.LOBBY_ROWS.size())
	for wanted: String in ["Cage", "Slots", "Wheel", "Blackjack", "Racing", "House rules"]:
		assert_true("\n".join(drawn).contains(wanted), "the lobby must offer %s" % wanted)


func test_every_lobby_row_says_what_it_is_for() -> void:
	for line: String in _menu.drawn_lines():
		assert_gt(line.length(), 12,
			"a bare noun is not a row a new player can choose from: %s" % line)


func test_the_lobby_shows_what_she_is_holding_in_both_currencies() -> void:
	var header: String = _menu.header_line()
	assert_true(header.contains(str(_bits)), "her bits: %s" % header)
	assert_true(header.contains(str(_chips)), "her chips: %s" % header)


func test_choosing_a_game_row_asks_for_that_room() -> void:
	watch_signals(_menu)
	_menu.move_selection(CasinoMenu.Row.WHEEL)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "room_requested", [CasinoMenu.Row.WHEEL])


func test_choosing_the_cage_row_opens_the_cage_rather_than_a_table() -> void:
	watch_signals(_menu)
	_menu.move_selection(CasinoMenu.Row.CAGE)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "room_requested", [CasinoMenu.Row.CAGE])
	_menu.set_tab(CasinoMenu.Tab.CAGE)
	assert_eq(_menu.tab(), CasinoMenu.Tab.CAGE)


## THE REPORT: "the cage explains itself (bits to chips, one to one, both ways)".
func test_the_cage_explains_itself_before_it_offers_a_single_amount() -> void:
	_menu.set_tab(CasinoMenu.Tab.CAGE)
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.to_lower().contains("one for one"), drawn)
	assert_true(drawn.to_lower().contains("both ways"), drawn)


func test_the_cage_still_offers_only_what_she_can_cover_in_both_directions() -> void:
	_bits = 250
	_chips = 0
	_menu.set_tab(CasinoMenu.Tab.CAGE)
	_menu.refresh()
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains("Buy"))
	assert_false(drawn.contains("Cash out"), "there is nothing to cash out")


func test_the_house_rules_tab_carries_every_game_s_real_edge() -> void:
	_menu.set_tab(CasinoMenu.Tab.RULES)
	var drawn: String = "\n".join(_menu.drawn_lines())
	for edge: float in [SlotsScript.house_edge(), WheelScript.house_edge(),
			BlackjackScript.house_edge(), RaceCardScript.TAKEOUT]:
		assert_true(drawn.contains("%.1f" % (edge * 100.0)),
			"the published edge %.1f is missing from the rules page" % (edge * 100.0))


func test_nothing_the_lobby_draws_carries_a_dash() -> void:
	for tab: int in [CasinoMenu.Tab.LOBBY, CasinoMenu.Tab.CAGE, CasinoMenu.Tab.RULES]:
		_menu.set_tab(tab)
		for line: String in _menu.drawn_lines() + [_menu.header_line()]:
			assert_false(line.contains("--") or line.contains("—"), line)
```

(add `const SlotsScript`, `WheelScript`, `BlackjackScript` and `RaceCardScript` preloads to the file if they are not already there, and a `func header_line() -> String` expectation is satisfied in Step 3.)

Append to `game/test/test_slots_menu.gd` (and repeat the same three cases, adjusted only in their preload and menu scene, in `test_wheel_menu.gd` and `test_blackjack_menu.gd`):

```gdscript
## THE REPORT: "each table screen shows your chips, the stake picker, and what keys do
## what". A table that only says "Stake: [10 chips]" leaves a player who has not read a
## document with no way to find out what Enter does here.
func test_the_table_says_what_she_is_holding() -> void:
	assert_true(_menu.chips_line().contains(str(_chips)),
		"her chips must be on the screen she is betting them on: %s" % _menu.chips_line())


func test_the_table_says_what_the_keys_do_on_this_table() -> void:
	var keys: String = _menu.keys_line()
	assert_false(keys.is_empty())
	assert_true(keys.to_lower().contains("stake"),
		"the stake picker is the control a new player cannot guess: %s" % keys)


## THE REPORT: "results render prominently (win/lose line with numbers)".
func test_a_settled_result_renders_as_its_own_block_with_the_numbers_in_it() -> void:
	_menu.show_result(["You win 40 chips!", "Two cherries and a bell."])
	var block: Array[String] = _menu.result_block()
	assert_gt(block.size(), 0, "a settled bet must leave something on the screen")
	assert_true("\n".join(block).contains("40"),
		"the number is the whole point of the line")
	assert_true("\n".join(_menu.drawn_lines()).contains("40"),
		"and it is drawn, not merely stored")
```

- [ ] **Step 2: Run them to make sure they fail**

Run:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_casino_menu.gd -gtest=res://test/test_slots_menu.gd \
  -gtest=res://test/test_wheel_menu.gd -gtest=res://test/test_blackjack_menu.gd -gexit
```
Expected: FAIL on `CasinoMenu.Tab.LOBBY`, `CasinoMenu.Row`, `header_line()`, `chips_line()`, `keys_line()` and `result_block()`, none of which exist.

- [ ] **Step 3: Rework `game/ui/casino_menu.gd` into a lobby**

Replace the enums, the constants, `drawn_lines()`, `confirm()`, `_row_count()` and `refresh()`:

```gdscript
## ONE SCREEN YOU WALK INTO, with one row per thing you can do in the building. The owner,
## 2026-08-31: "rework the casino flow so it is playable without reading docs. Entering the
## Palace opens ONE lobby screen with big obvious rows".
##
## WHAT WAS WRONG. The lobby opened on the CAGE tab, whose rows were bare amounts with no
## explanation of what a chip was; the four games lived behind a third tab reachable only
## by pressing left or right, which nothing on the screen said; and the house edge sat on a
## tab in between. A player who had not read the design document could open this menu and
## not find the slot machine.
##
## THE CAGE AND THE RULES ARE STILL TABS, because they are pages rather than rooms and a
## player who picks them from the lobby ends up on them. Everything else about the split is
## unchanged: this file never touches Economy, Casino, GameState or a pony, it is handed
## four Callables and it hands back three signals, and ranch.gd does every transaction.

enum Tab { LOBBY, CAGE, RULES }

## The rows in the lobby, in order. The enum and LOBBY_ROWS are indexed together.
enum Row { CAGE, SLOTS, WHEEL, BLACKJACK, RACING, RULES }

## ONE LINE PER ROOM, AND EVERY ONE OF THEM SAYS WHAT IT IS FOR. "Slots" is a noun a player
## already knows; "Wheel" is not, and neither is "Cage". The second half of each row is the
## whole of the onboarding this building needs.
const LOBBY_ROWS: Array[String] = [
	"Cage            turn bits into chips, and chips back into bits",
	"Slots           three reels, one lever, the fast one",
	"The Wheel       back a colour or back a number",
	"Blackjack       get closer to 21 than the dealer, without going over",
	"Racing          enter one of your own ponies and back her to win",
	"House rules     exactly how much we keep, printed by us",
]

const TAB_NAMES: Array[String] = ["Lobby", "Cage", "House rules"]
const TITLE := "Spectra Palace"

## The amounts the cage offers before they are cut down to what she is holding.
const CAGE_STEPS: Array[int] = [100, 500, 2000, 10000]

signal opened()
signal closed()
signal buy_chips_requested(bits: int)
signal cash_out_requested(chips: int)
signal room_requested(row: int)
```

Delete `GAME_NAMES`, `Game`, `game_requested` and the file's own `COLOR_*` and `FOOTER` (Task 4 removed the latter two already). Then:

```gdscript
## WHAT SHE IS HOLDING, ON EVERY PAGE OF THE BUILDING. Bits and chips together, because
## the one thing a player in a casino needs continuously is her own balance, and because
## seeing them side by side is what makes "one for one" mean something.
func header_line() -> String:
	var bits: int = int(bits_provider.call()) if bits_provider.is_valid() else 0
	var chips: int = int(chips_provider.call()) if chips_provider.is_valid() else 0
	return "You have %d bits and %d chips." % [bits, chips]


func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.LOBBY:
			for row in LOBBY_ROWS:
				lines.append(row)
		Tab.CAGE:
			for line in CasinoSignScript.cage_explainer():
				lines.append(line)
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			if buys.is_empty() and cashes.is_empty():
				lines.append("Come back when you have something to play with.")
			for amount in buys:
				lines.append("Buy %d chips for %d bits" % [amount, amount])
			for amount in cashes:
				lines.append("Cash out %d chips for %d bits" % [amount, amount])
		Tab.RULES:
			if sign_provider.is_valid():
				for line in sign_provider.call():
					lines.append(String(line))
	return lines


## WHICH DRAWN LINE ROW ZERO IS, the same question game/ui/table_menu.gd answers for its own
## tables: the CAGE page prints the explainer above its first choosable row, so the caret
## has to be offset by exactly that many lines or it highlights a sentence.
func first_row_line_index() -> int:
	return CasinoSignScript.cage_explainer().size() if _tab == Tab.CAGE else 0


func confirm() -> bool:
	match _tab:
		Tab.LOBBY:
			if _selected < 0 or _selected >= LOBBY_ROWS.size():
				return false
			room_requested.emit(_selected)
			return true
		Tab.CAGE:
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			if _selected < 0:
				return false
			if _selected < buys.size():
				buy_chips_requested.emit(buys[_selected])
				return true
			var index: int = _selected - buys.size()
			if index < cashes.size():
				cash_out_requested.emit(cashes[index])
				return true
			return false
	return false


func _row_count() -> int:
	match _tab:
		Tab.LOBBY:
			return LOBBY_ROWS.size()
		Tab.CAGE:
			return buy_amounts().size() + cash_amounts().size()
	return 0
```

`refresh()` gains the header and the shared style, and `open()` opens on `Tab.LOBBY`:

```gdscript
func refresh() -> void:
	if not is_node_ready():
		return
	_footer.text = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_tabs.text = MenuStyleScript.tab_strip(TAB_NAMES, _tab) + "      " + header_line()
	for child in _rows.get_children():
		child.queue_free()
	var lines: Array[String] = drawn_lines()
	var caret: int = _selected + first_row_line_index()
	for i in lines.size():
		var label := Label.new()
		var picked: bool = i == caret and _row_count() > 0
		label.text = MenuStyleScript.caret(picked) + lines[i]
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE,
			MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
		_rows.add_child(label)
```

and in `open()` change `_tab = Tab.CAGE` to `_tab = Tab.LOBBY`.

Add `const CasinoSignScript := preload("res://systems/casino_sign.gd")` and `const MenuStyleScript := preload("res://ui/menu_style.gd")` to the preload block.

- [ ] **Step 4: Give the cage its explainer in `game/systems/casino_sign.gd`**

Replace `cage_lines()` with a version that says the one thing a new player needs, and keep the old name as well since the physical counter still prints it:

```gdscript
## WHAT IS WRITTEN ON THE CAGE COUNTER ITSELF.
static func cage_lines() -> Array[String]:
	return [
		"The cage: %d bit buys one chip, and one chip cashes out for %d bit."
			% [CasinoScript.CHIP_RATE, CasinoScript.CHIP_RATE],
		"We take nothing at this window. We take it at the tables,",
		"and we told you exactly how much on the way in.",
	]


## THE SAME THING, SHORT ENOUGH TO SIT ABOVE THE AMOUNTS ON THE CAGE PAGE. The owner,
## 2026-08-31: "the cage explains itself (bits to chips, one to one, both ways)". A page of
## bare amounts is a page a player leaves without knowing what a chip is.
##
## THREE LINES AND NOT FIVE, because the rows underneath are what she came for and a wall
## of text above them is the same problem in the other direction.
static func cage_explainer() -> Array[String]:
	return [
		"Bits buy chips one for one, and chips cash out one for one, both ways.",
		"The cage keeps nothing. The tables keep what the House rules page says.",
		"",
	]
```

- [ ] **Step 5: Give every table a chips line, a keys line and a result block**

In `game/ui/table_menu.gd`, add:

```gdscript
## Injected by ranch.gd alongside chips_provider, so a table can say what she is holding.
## Already present as chips_provider; this is only the sentence built from it.
##
## THE REPORT: "each table screen shows your chips, the stake picker, and what keys do
## what". A table that shows only a stake row is a table a player cannot tell she is broke
## at until a bet silently refuses.
func chips_line() -> String:
	var chips: int = int(chips_provider.call()) if chips_provider.is_valid() else 0
	if chips <= 0:
		return "You have no chips. The cage is in the lobby, and it is one for one."
	return "You have %d chips." % chips


## WHAT THE KEYS DO ON THIS TABLE, in the glyphs of the device in her hands. Distinct from
## the footer, which says how to move around a menu: this says what the CONTROLS OF THE GAME
## are, which on every table in this building is "the stake is on the last row".
func keys_line() -> String:
	return "Pick a stake on the stake row, then %s to play. %s leaves." % [
		InputDeviceScript.hint(&"ui_accept"), InputDeviceScript.hint(&"ui_cancel")]


## THE LAST HAND, AS ITS OWN BLOCK, with a rule above it so it does not read as another
## row. Empty until something has been settled, which is the correct state for a table
## nobody has played yet.
func result_block() -> Array[String]:
	if _result.is_empty():
		return []
	var out: Array[String] = ["", "= = = = = = = = = = = = = = = = = = = ="]
	for line in _result:
		out.append(line)
	out.append("= = = = = = = = = = = = = = = = = = = =")
	out.append("")
	return out
```

with `const InputDeviceScript := preload("res://systems/input_device.gd")` added to the preloads.

Then in each of `slots_menu.gd`, `wheel_menu.gd` and `blackjack_menu.gd`, put the three at the top of `drawn_lines()` in place of whatever each currently prints above its rows, and set `first_row_line_index()` to the number of lines they added, so the caret still lands on the row it names:

```gdscript
func drawn_lines() -> Array[String]:
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	lines.append_array(stake_lines())
	# ... this table's own rows, exactly as before ...
	return lines


func first_row_line_index() -> int:
	return 2 + result_block().size() + stake_lines().size()
```

- [ ] **Step 6: Rewire the lobby's signal in `game/world/ranch.gd`**

In `_bind_casino_menus()`, replace the `game_requested` connection with `room_requested`, and replace `_on_game_requested()` with:

```gdscript
## SHE PICKED A ROW IN THE LOBBY. The cage and the house rules are pages of the lobby menu
## itself, so those two turn a tab rather than opening anything; the four games each open
## their own panel, exactly as before.
func _on_room_requested(row: int) -> void:
	if casino_menu == null:
		return
	match row:
		CasinoMenuScript.Row.CAGE:
			casino_menu.call("set_tab", CasinoMenuScript.Tab.CAGE)
		CasinoMenuScript.Row.RULES:
			casino_menu.call("set_tab", CasinoMenuScript.Tab.RULES)
		CasinoMenuScript.Row.SLOTS:
			_open_table(slots_menu)
		CasinoMenuScript.Row.WHEEL:
			_open_table(wheel_menu)
		CasinoMenuScript.Row.BLACKJACK:
			_open_table(blackjack_menu)
		CasinoMenuScript.Row.RACING:
			_open_table(race_menu)


## Close the lobby and open one table over the top of it. Closing first, and not after, so
## _no_menu_but() is true by the time the table asks it: two open menus is the state that
## leaves the world unpaused under the one still on screen (see _no_menu_but()).
func _open_table(menu: CanvasLayer) -> void:
	if menu == null or not menu.has_method("open"):
		return
	if casino_menu != null and casino_menu.has_method("close"):
		casino_menu.close()
	menu.call("open")
```

Keep whatever the shipped `_on_game_requested()` did about closing the lobby; the block above states it explicitly.

- [ ] **Step 7: Run the casino tests and the gate**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_casino_menu.gd -gtest=res://test/test_slots_menu.gd \
  -gtest=res://test/test_wheel_menu.gd -gtest=res://test/test_blackjack_menu.gd \
  -gtest=res://test/test_casino_sign.gd -gexit
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn
echo "exit $?"
bash tools/run_tests.sh
```
Expected: PASS, `CASINO_OK checks=<n>` and exit 0, suite green. The gate's own menu seam checks reference `CasinoMenu.Tab.GAMES` and `game_requested`; move them to `Tab.LOBBY` and `room_requested` in the same edit. Note the number of checks the gate prints; Task 9 writes it into `docs/testing.md`.

- [ ] **Step 8: Play it**

```bash
tools/bin/godot --path game world/ranch.tscn
```
Walk into the Palace with no chips. The first screen names six things, each with a sentence saying what it is. Pick Cage: it tells you chips are one for one both ways before it offers you an amount. Buy some, pick Slots: the panel says how many chips you have, what the keys do, and where the stake lives. Spin: the result is a boxed block with the number in it, not another row.

- [ ] **Step 9: Commit**

```bash
printf 'feat: the Palace explains itself\n\nThe owner, 2026-08-31: the casino cannot be played without reading a document.\nThe lobby opened on the CAGE tab with bare amounts and no explanation of what a\nchip was; the four games were behind a third tab reachable only by pressing left\nor right, which nothing on the screen said.\n\nThe lobby is now one screen with six rows, each carrying a sentence saying what\nit is for, and the cage and the house rules are pages you reach from it rather\nthan tabs you have to find. The cage prints "bits buy chips one for one, and\nchips cash out one for one, both ways" above the first amount. Every table now\nshows what she is holding, what the keys do on THAT table, and the last result\nas its own boxed block instead of two more rows.\n\nNo paytable, no edge, no settle and no Casino method moved: this is copy and\nlayout. The injected Callable split is untouched and ranch.gd still does every\ntransaction.\n' > /tmp/casino-ux-commit.txt
git add game/ui/casino_menu.gd game/ui/table_menu.gd game/ui/slots_menu.gd \
  game/ui/wheel_menu.gd game/ui/blackjack_menu.gd game/systems/casino_sign.gd \
  game/world/ranch.gd game/scenes/test/casino_test.gd
git add -u game/test
git commit -F /tmp/casino-ux-commit.txt
```

---

### Task 6: Racing, redesigned: your pony IS your bet

**Files:**
- Modify: `game/ui/race_menu.gd`, `game/world/ranch.gd`, `game/scenes/test/casino_test.gd`
- Test: `game/test/test_race_menu.gd`, `game/test/test_ranch_race.gd`

**Interfaces:**
- Consumes: `RaceCard.build_field(entrant: Dictionary, runners: CompanyRunners) -> Array[Dictionary]`, `RaceCard.entrant_from(inst: PonyInstance) -> Dictionary`, `RaceCard.decimal_odds(field: Array[Dictionary], lane: int) -> float`, `RaceCard.odds_text(odds: float) -> String`, `RaceCard.payout(field, lane, stake, winner) -> int`, `RaceCard.PLAYER_LANE` (0), `RaceCard.LANES` (6), `RaceCard.TAKEOUT` (0.06), `CompanyRunners.load_shipped() -> CompanyRunners`, `MenuStyle.*` (Task 4), `TableMenu.stakes()/selected_stake()/set_stake_index()/stake_index()/stake_lines()/chips_line()/keys_line()/result_block()` (Tasks 4 and 5).
- Produces:
  - `RaceMenu.Tab` becomes `enum Tab { ENTER, CARD }`; `Tab.BET` is REMOVED.
  - `RaceMenu` signal `race_requested(uid: StringName, stake: int)`; `entrant_chosen` and `set_field()` are REMOVED.
  - `RaceMenu.selected_entrant_uid() -> StringName`, `RaceMenu.form_lines() -> Array[String]`.
  - `ranch.race_entrants() -> Array[Dictionary]` gains `"odds": float` and `"chance": float` per row.
  - `ranch.start_race(uid: StringName, stake: int) -> Dictionary` (the `lane` argument is REMOVED).

**The amended spec, verbatim.** "Your pony IS your bet: the enter screen lists every penned pony with her live odds (a form guide for your whole roster; her `base_speed`, `base_stamina`, `base_spirit` and current happiness make the race; these fields have existed since Phase 1 and nothing uses them yet), you pick one and a stake, and she runs against five Company owned runners. You can only back your own entrant; winning pays her odds. Side bets on other lanes are out (playtest verdict 2026-08-31: betting against your own pony felt wrong) and may return later as a casino perk."

**The arithmetic does not move, and that is what makes this a small change.** `RaceCard` already computes `win_chances()` exactly (the Gumbel max identity in its class comment) and `decimal_odds()` as `(1 - TAKEOUT) / chance`, so every lane on a card is worth exactly `1 - TAKEOUT` per chip and the takeout is unchanged whether or not other lanes are backable. A form guide is therefore priced by building the field she WOULD run in and reading `decimal_odds(field, PLAYER_LANE)`, which is by construction the same number the settle uses.

**Where the quoted card is kept.** The shipped code cached ONE priced field in `_priced_uid` / `_priced_field`, filled by `_on_entrant_chosen()`, because the panel had a two step flow. The form guide prices EVERY penned pony at once, so the cache becomes a dictionary keyed by uid, filled by `race_entrants()` itself and cleared with the rest of the bet. Same guarantee, wider: the field a race settles against is exactly the field whose odds were on the screen when she pressed the button.

- [ ] **Step 1: Write the failing test**

Replace `game/test/test_race_menu.gd` entirely:

```gdscript
extends GutTest
## THE FORM GUIDE. Every penned pony, her live odds, and a stake. There is no lane to pick:
## your pony IS your bet (spec, amended 2026-08-31, after the playtest verdict that backing
## a Company runner against your own pony felt wrong).
##
## The odds are PUSHED IN with the rows, not worked out here: ranch.gd builds each field and
## asks RaceCard for the price, so this file never sees a PonyInstance and cannot compute a
## number that disagrees with the one the race settles at.

const RaceMenuScene := preload("res://ui/race_menu.tscn")
const RaceCardScript := preload("res://systems/race_card.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")

var _menu: RaceMenu = null
var _chips := 500


func _entrants() -> Array[Dictionary]:
	return [
		{"uid": &"a#000001", "name": "Bramble", "happiness": 0.5,
			"odds": 7.25, "chance": 0.1297},
		{"uid": &"b#000002", "name": "Pip", "happiness": 0.9,
			"odds": 4.10, "chance": 0.2293},
	]


func before_each() -> void:
	InputDeviceScript.reset()
	_chips = 500
	_menu = RaceMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.entrants_provider = func() -> Array[Dictionary]: return _entrants()
	_menu.open()


func test_it_opens_on_the_form_guide() -> void:
	assert_eq(_menu.tab(), RaceMenu.Tab.ENTER)


func test_there_is_no_bet_tab_any_more() -> void:
	assert_false(RaceMenu.Tab.has("BET") if RaceMenu.Tab is Dictionary else false)
	# The enum is a plain int enum, so the real claim is about how many tabs there are and
	# what cycling through them reaches.
	var seen := {}
	for i in 6:
		seen[_menu.tab()] = true
		_menu.switch_tab(1)
	assert_eq(seen.size(), 2, "two tabs: the form guide and the card")


## THE SPEC: "the enter screen lists every penned pony with her live odds".
func test_the_form_guide_lists_every_penned_pony_with_her_price() -> void:
	var lines: Array[String] = _menu.form_lines()
	assert_eq(lines.size(), 2, "one row per pony in a pen, and no lanes at all")
	assert_true(lines[0].contains("Bramble"))
	assert_true(lines[0].contains(RaceCardScript.odds_text(7.25)),
		"her price has to be on her own row: %s" % lines[0])
	assert_true(lines[1].contains("Pip"))
	assert_true(lines[1].contains(RaceCardScript.odds_text(4.10)))


## Her happiness is the only thing about her the player can change before the off, so it is
## the only hint the guide carries.
func test_each_row_carries_a_happiness_hint() -> void:
	assert_true(_menu.form_lines()[1].contains("9"),
		"Pip is at 0.9 happiness and the row should say so")


func test_a_stake_row_sits_under_the_last_pony() -> void:
	var drawn: Array[String] = _menu.drawn_lines()
	assert_eq(_menu.row_count(), 3, "two ponies and the stake")
	assert_true(drawn[drawn.size() - 1].to_lower().contains("stake"),
		"the stake is the last row and it is drawn, so the caret can land on it")


func test_with_no_penned_ponies_it_says_so_and_enters_nobody() -> void:
	_menu.entrants_provider = func() -> Array[Dictionary]: return []
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "race_requested")
	assert_true("\n".join(_menu.drawn_lines()).contains("pen"))


func test_confirming_on_a_pony_backs_her_at_the_stake_on_the_screen() -> void:
	_menu.set_stake_index(1)
	_menu.move_selection(1)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "race_requested",
		[&"b#000002", _menu.stakes()[1]])
	assert_eq(_menu.selected_entrant_uid(), &"b#000002")


## THE STAKE ROW IS REACHABLE AND SELF EXPLANATORY. It was reachable before only by moving
## past the last lane with nothing drawn under the cursor, which nobody found.
func test_the_stake_row_can_be_moved_with_left_and_right_and_with_confirm() -> void:
	_menu.move_selection(2)
	assert_eq(_menu.selected_index(), 2, "one past the last pony is the stake row")
	assert_eq(_menu.stake_index(), 0)
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), RaceMenu.Tab.ENTER,
		"left and right adjust the stake while the cursor is on it")
	assert_eq(_menu.stake_index(), 1)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_eq(_menu.stake_index(), 2, "confirm on the stake row steps it too")
	assert_signal_not_emitted(_menu, "race_requested",
		"confirming the stake row must not place a bet")


func test_an_empty_purse_cannot_back_anybody() -> void:
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "race_requested")


func test_the_card_tab_explains_where_the_odds_come_from_and_that_she_backs_her_own() -> void:
	_menu.set_tab(RaceMenu.Tab.CARD)
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains("%.1f" % (RaceCardScript.TAKEOUT * 100.0)))
	assert_true(drawn.to_lower().contains("your own"),
		"the card has to say that the only pony you can back is yours")


func test_the_table_furniture_is_on_this_panel_too() -> void:
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains(str(_chips)), "her chips are on the screen")
	assert_true(drawn.to_lower().contains("stake"))


func test_nothing_it_draws_carries_a_dash() -> void:
	for tab: int in [RaceMenu.Tab.ENTER, RaceMenu.Tab.CARD]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)
```

Note: delete `test_there_is_no_bet_tab_any_more`'s first line (the `Tab is Dictionary` probe) if GDScript refuses it; the loop below it is the real assertion and stands on its own.

- [ ] **Step 2: Run it to make sure it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_race_menu.gd -gexit`

Expected: FAIL on `form_lines()` and on `race_requested` having the wrong arity.

- [ ] **Step 3: Rewrite `game/ui/race_menu.gd`**

```gdscript
class_name RaceMenu
extends "res://ui/table_menu.gd"
## THE FORM GUIDE. Every pony standing in one of your pens, her live price, and a stake.
##
## YOUR PONY IS YOUR BET. There is no lane to pick and no side bet to place: you enter one
## of your own and back her to win, and the card pays her odds if she takes it and nothing
## if she does not. The spec was amended to this on 2026-08-31 after the playtest verdict
## that backing a Company runner against your own pony felt wrong; the BET tab, and with it
## the whole "pick a lane" flow, is gone.
##
## THE ODDS ARE PUSHED IN WITH THE ROWS, NOT WORKED OUT HERE. ranch.gd builds the field each
## pony would run in, asks RaceCard.decimal_odds() for her price and hands the number over
## in her row; this file never sees a PonyInstance, never reads a pen, and cannot compute a
## price of its own that disagrees with the one the race settles at. Same split as every
## other menu in this project.
##
## THE STAKE IS A DRAWN ROW NOW, sitting under the last pony. It used to be a seventh
## cursor position past six lanes with nothing printed under it, which is a control nobody
## found; left and right move it while the cursor is on it, and so does confirm, because a
## player who presses the confirm key on a row called "Stake" should not get silence.

const RaceCardScript := preload("res://systems/race_card.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

const TITLE := "Racing"
const EMPTY_TEXT := "Nobody is standing in your pens. Catch a pony and move her in."

enum Tab { ENTER, CARD }

## Emitted when she backs one of her own. ranch.gd takes the stake, runs the card and
## settles at RaceCard.PLAYER_LANE, which is the only lane her bet can ever be on.
signal race_requested(uid: StringName, stake: int)

## Injected by ranch.gd: what is standing in the pens, as
## [{"uid", "name", "happiness", "odds", "chance"}].
var entrants_provider := Callable()

var _tab: int = Tab.ENTER
var _entrant: StringName = &""


func _ready() -> void:
	super._ready()


func title_text() -> String:
	return TITLE


func tabs_text() -> String:
	return MenuStyleScript.tab_strip(["Form guide", "The card"], _tab) \
		+ "      the house keeps %.1f bits of every 100" % (RaceCardScript.TAKEOUT * 100.0)


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.ENTER, Tab.CARD)
	_selected = 0
	refresh()


## Left and right switch tabs everywhere except on the stake row, where they move the
## stake. The footer says so, and the row itself says so.
func switch_tab(step: int) -> void:
	if _tab == Tab.ENTER and _on_stake_row():
		_step_stake(step)
		return
	set_tab(posmod(_tab + step, Tab.CARD + 1))


func entrants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not entrants_provider.is_valid():
		return out
	for entry in entrants_provider.call():
		out.append(entry as Dictionary)
	return out


func selected_entrant_uid() -> StringName:
	return _entrant


## ONE ROW PER PONY: her name, what she pays, and the only thing about her the player can
## change before the off. A hungry pony is a slow pony, and her spirits are the visible half
## of that.
func form_lines() -> Array[String]:
	var out: Array[String] = []
	for entry in entrants():
		out.append("%-16s pays %s   spirits %d of 10" % [
			String(entry.get("name", "Pony")),
			RaceCardScript.odds_text(float(entry.get("odds", 0.0))),
			roundi(float(entry.get("happiness", 0.0)) * 10.0)])
	return out


func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.ENTER:
			lines.append(chips_line())
			lines.append(keys_line())
			lines.append_array(result_block())
			var form: Array[String] = form_lines()
			if form.is_empty():
				lines.append(EMPTY_TEXT)
				return lines
			lines.append_array(form)
			lines.append_array(stake_lines())
		Tab.CARD:
			lines.append("Six lanes. Yours runs on the rail, lane %d, every time."
				% (RaceCardScript.PLAYER_LANE + 1))
			lines.append("The five others belong to Cloudsdale and are kept at")
			lines.append("exactly %d per cent morale. It is in the staff handbook."
				% roundi(RaceCardScript.COMPANY_HAPPINESS * 100.0))
			lines.append("")
			lines.append("You back your own pony and nobody else. She pays her")
			lines.append("odds if she takes it and nothing if she does not.")
			lines.append("")
			lines.append("Odds come from her speed, her stamina, her spirit and")
			lines.append("how happy she is. A hungry pony is a slow pony.")
			lines.append("The house keeps %.1f bits of every 100 wagered."
				% (RaceCardScript.TAKEOUT * 100.0))
	return lines


## The rows the cursor may sit on: one per pony, plus the stake under them. Zero when
## nobody is in a pen, so confirming an empty guide cannot reach a signal.
func row_count() -> int:
	if _tab != Tab.ENTER:
		return 0
	var n: int = entrants().size()
	return n + 1 if n > 0 else 0


## The drawn line row zero sits on: the chips line, the keys line and whatever the last
## result printed all come first. See TableMenu.first_row_line_index() for what goes wrong
## without this.
func first_row_line_index() -> int:
	return 2 + result_block().size()


func confirm() -> bool:
	if _tab != Tab.ENTER:
		return false
	var list: Array[Dictionary] = entrants()
	if list.is_empty():
		return false
	if _on_stake_row():
		_step_stake(1)
		return true
	if _selected < 0 or _selected >= list.size():
		return false
	if selected_stake() <= 0:
		return false
	_entrant = StringName(list[_selected]["uid"])
	race_requested.emit(_entrant, selected_stake())
	return true


func _on_stake_row() -> bool:
	var n: int = entrants().size()
	return n > 0 and _selected == n


func _step_stake(step: int) -> void:
	var available: Array[int] = stakes()
	if available.is_empty():
		return
	set_stake_index(posmod(stake_index() + step, available.size()))
```

Delete `set_field()`, `selected_lane()`, `entrant_chosen`, `_field`, `_odds`, `_bet_lane` and `RACE_FOOTER` (Task 4 already removed the last one).

- [ ] **Step 4: Price the whole roster in `game/world/ranch.gd`**

Replace `race_entrants()`, delete `_on_entrant_chosen()`, `_priced_uid` and `_priced_field`, and change `start_race()`'s signature:

```gdscript
## THE FORM GUIDE: everybody standing in a pen, with her live price.
##
## PRICED HERE AND NOWHERE ELSE. Each row's odds are read off the field that pony WOULD run
## in, through RaceCard.decimal_odds(field, PLAYER_LANE), so the number on the screen is by
## construction the number the settle uses; the panel has no way to price a lane itself and
## deliberately never gets one.
##
## THE QUOTED CARDS ARE KEPT, keyed by uid. The shipped code cached one field because the
## panel had a two step flow (pick a pony, then pick a lane); the guide prices everybody at
## once, so the cache is a dictionary and the guarantee is wider: the field a race settles
## against is exactly the field whose odds were on the screen when she pressed the button.
## _clear_race_bet() empties it with the rest of the bet.
func race_entrants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	_quoted_fields.clear()
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		for inst: PonyInstance in pen.ponies():
			var field: Array[Dictionary] = RaceCardScript.build_field(
				RaceCardScript.entrant_from(inst), runners)
			_quoted_fields[inst.uid] = field
			var chances: Array[float] = RaceCardScript.win_chances(field)
			out.append({
				"uid": inst.uid,
				"name": inst.display_name(),
				"happiness": inst.happiness,
				"odds": RaceCardScript.decimal_odds(field, RaceCardScript.PLAYER_LANE),
				"chance": chances[RaceCardScript.PLAYER_LANE] if not chances.is_empty() else 0.0,
			})
	return out
```

with the member declared beside `_race_field`:

```gdscript
## The card each penned pony was last quoted at, keyed by uid. Filled by race_entrants(),
## read by start_race(), emptied by _clear_race_bet().
var _quoted_fields: Dictionary = {}
```

and `start_race()` amended (only the signature, the field lookup and the settle lane change; everything else in that function, including the stake order, the unwind and the hidden pen body, stays exactly as it is):

```gdscript
## RUN A RACE. Returns {"ok": bool, "field": Array, "result": Dictionary, "odds": float}.
##
## YOUR PONY IS YOUR BET, so there is no lane argument: the entrant always runs on
## RaceCard.PLAYER_LANE and that is the only lane the stake can be on. The lane parameter
## this used to take let a caller back a Company runner, which is what the 2026-08-31
## playtest asked to have removed.
##
## WHAT DOES NOT HAPPEN HERE, and it is still the point of the whole thing: the entrant is
## not taken out of her pen, not handed to the track, not adopted by anything and not freed.
## Her pen body is hidden for the length of the race so the world does not show her twice,
## and _on_race_finished() shows it again.
##
## THE STAKE COMES OUT BEFORE THE FIELD IS DRAWN, the same order every table here uses.
func start_race(uid: StringName, stake: int) -> Dictionary:
	var refused := {"ok": false, "field": [], "result": {}, "odds": 0.0}
	if _game_state == null or race_track == null or race_track.call("is_running"):
		return refused
	if not casino_can_enter():
		return refused
	var found: Dictionary = _penned(uid)
	if found.is_empty():
		return refused
	if not _game_state.casino.can_stake(stake):
		return refused
	var inst: PonyInstance = found["inst"]
	# THE FIELD THE ODDS WERE QUOTED FROM, when there is one. A uid with no quote (a gate or
	# a save hook calling straight in without opening the panel) rebuilds, which is the same
	# field the guide would have shown had it been asked.
	var field: Array[Dictionary] = _quoted_fields.get(uid, []) as Array[Dictionary]
	if field.is_empty():
		field = RaceCardScript.build_field(
			RaceCardScript.entrant_from(inst), CompanyRunnersScript.load_shipped())
	if not _game_state.casino.remove_chips(stake):
		return refused
	# ... the rest of the shipped function is unchanged, with `lane` replaced by
	#     RaceCardScript.PLAYER_LANE in the two places it appears ...
	_race_entrant = uid
	_race_lane = RaceCardScript.PLAYER_LANE
	_race_stake = stake
	_race_field = field
	if race_menu != null and race_menu.has_method("close"):
		race_menu.close()
	_toast("They are under orders at the Spectra Palace!")
	return {"ok": true, "field": field, "result": result,
		"odds": RaceCardScript.decimal_odds(field, RaceCardScript.PLAYER_LANE)}
```

Amend `_on_race_requested()` to the two argument shape, and add the clear:

```gdscript
func _on_race_requested(uid: StringName, stake: int) -> void:
	start_race(uid, stake)
```

```gdscript
func _clear_race_bet() -> void:
	_race_entrant = &""
	_race_lane = -1
	_race_stake = 0
	_race_field = []
	_quoted_fields.clear()
```

In `_bind_casino_menus()`, drop the `entrant_chosen` connection; the pairs list becomes `[["opened", _on_menu_opened_any], ["closed", _on_menu_closed], ["race_requested", _on_race_requested]]`.

Amend the result toast in `_on_race_finished()` so a loss says which of your own ponies ran, which the old lane based line could not:

```gdscript
	if won > 0:
		_toast("%s takes it. You win %d chips!" % [winner_name, won])
	else:
		_toast("%s takes it. Your pony was not in front today." % winner_name)
```

- [ ] **Step 5: Move the gate and the ranch tests onto the new verb**

In `game/scenes/test/casino_test.gd`, change the one call and the checks around it:

```gdscript
	var race: Dictionary = ranch.start_race(racer.uid, 100)
```
```gdscript
	var expected_payout: int = RaceCardScript.payout(race["field"],
		RaceCardScript.PLAYER_LANE, 100, settled_winner)
```

and add two checks proving the new promise, next to the ones already there:

```gdscript
	var priced: Array[Dictionary] = ranch.race_entrants()
	var quoted := 0.0
	for entry in priced:
		if StringName(entry["uid"]) == racer.uid:
			quoted = float(entry["odds"])
	_set_check("the form guide prices her at the card's own odds",
		absf(quoted - RaceCardScript.decimal_odds(race["field"],
			RaceCardScript.PLAYER_LANE)) < 0.0001)
	_set_check("a losing race pays exactly nothing",
		settled_winner == RaceCardScript.PLAYER_LANE or settled_payout == 0)
```

In `game/test/test_ranch_race.gd`, replace every `start_race(uid, lane, stake)` with `start_race(uid, stake)` and delete any case that backed a lane other than `PLAYER_LANE`; add in its place:

```gdscript
func test_the_form_guide_prices_every_penned_pony_and_nobody_else() -> void:
	var rows: Array[Dictionary] = _ranch.race_entrants()
	assert_gt(rows.size(), 0, "there is a pony in a pen")
	for row in rows:
		assert_true(row.has("odds"), "every row carries her price")
		assert_gt(float(row["odds"]), 1.0,
			"an entrant who paid a chip or less for a chip would be a refund, not a bet")
		assert_between(float(row["chance"]), 0.0, 1.0)


func test_a_race_can_only_ever_be_backed_on_the_player_s_own_lane() -> void:
	var rows: Array[Dictionary] = _ranch.race_entrants()
	var race: Dictionary = _ranch.start_race(StringName(rows[0]["uid"]), 10)
	assert_true(bool(race["ok"]))
	assert_almost_eq(float(race["odds"]),
		RaceCardScript.decimal_odds(race["field"], RaceCardScript.PLAYER_LANE), 0.0001,
		"the quoted price and the settled price are the same number")
```

- [ ] **Step 6: Run the tests and the gate**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_race_menu.gd -gtest=res://test/test_ranch_race.gd -gexit
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn
echo "exit $?"
bash tools/run_tests.sh
```
Expected: PASS, `CASINO_OK checks=<n>` and exit 0, suite green. `test_published_payouts.gd` and `test_race_card.gd` must NOT change: no odds, no takeout and no settle arithmetic moved, and if either of those goes red something did.

- [ ] **Step 7: Play it**

```bash
tools/bin/godot --path game world/ranch.tscn
```
Catch two ponies, pen them, feed one, walk to the Palace and pick Racing. Both are listed with prices, and the one you fed is the shorter price. Move onto the stake row, raise it, move back onto a pony and press the confirm key: she goes to the gate and the race runs. If she wins, the toast pays her odds; if she does not, it pays nothing and says so.

- [ ] **Step 8: Commit**

```bash
printf 'feat: racing is a form guide, and your pony is your bet\n\nSpec amended 2026-08-31 after the playtest: "you can only back your own entrant;\nwinning pays her odds. Side bets on other lanes are out (betting against your\nown pony felt wrong)". The BET tab is gone and start_race() has lost its lane\nargument; the ENTER tab is a form guide listing every penned pony with her live\nodds and a happiness hint, with a drawn stake row under her.\n\nNo arithmetic moved. RaceCard.win_chances() and decimal_odds() are untouched and\nthe takeout is still 0.06 on a card where every lane is worth exactly 1 minus\nthe takeout, so a guide priced at decimal_odds(field, PLAYER_LANE) is by\nconstruction the price the settle uses. The single _priced_field cache becomes\n_quoted_fields keyed by uid, which widens the guarantee rather than narrowing\nit: the field a race settles against is the field whose odds were on screen.\n\nThe stake is a drawn row now. It used to be a seventh cursor position past six\nlanes with nothing printed under it.\n' > /tmp/racing-commit.txt
git add game/ui/race_menu.gd game/world/ranch.gd game/scenes/test/casino_test.gd \
  game/test/test_race_menu.gd game/test/test_ranch_race.gd
git commit -F /tmp/racing-commit.txt
```

---

### Task 7: The first two minutes: where bits come from

**Files:**
- Modify: `game/systems/letters.gd`, `game/systems/request_board.gd`, `game/ui/hud.gd`, `game/ui/hud.tscn`, `game/world/ranch.gd`, `game/world/interaction.gd`
- Test: `game/test/test_letters.gd`, `game/test/test_request_board.gd`, `game/test/test_hud.gd`, `game/test/test_interaction.gd`

**Interfaces:**
- Consumes: `Letters.render(id: int, params: Dictionary) -> Dictionary`, `Letters.LINE_WIDTH` (58), `Letters.MAX_NAME_LENGTH` (16), `RequestBoard.seed_tutorial() -> void`, `RequestBoard.requests() -> Array`, `RequestBoard.claim(id: String) -> Dictionary`, `MenuStyle.*`, `InputDevice.hint(action) -> String`.
- Produces:
  - `RequestBoard.TUTORIAL_IDS: Array[String]` and `RequestBoard.tutorial_rows() -> Array[Dictionary]` returning `[{"id": String, "text": String, "done": bool, "paid": bool, "reward_bits": int}]` in seeded order, for the three tutorial requests that have not been claimed.
  - `HUD.set_tasks(rows: Array[Dictionary]) -> void`, `HUD.task_lines() -> Array[String]`, `HUD.TASK_TITLE`.
  - `Interaction.prompt_for()` MARKET line already reads "Market, sell gems" from Task 2; no change here, and `test_interaction.gd` gains the assertion that it names selling.

**The report.** "Bits onboarding: the how do I earn money path must be legible in the first minutes: rework the WELCOME letter into a one screen explainer (catch, pen, gems, sell at the Market; quota and balance in one sentence each); pin the three tutorial requests on the HUD (small checklist) until claimed; the Market prompt says what it does. Letters stay dash free cheerful corporate."

**What is already there and only needs surfacing.** `RequestBoard.seed_tutorial()` hands out exactly `tutorial_catch` (20 bits), `tutorial_pen` (30) and `tutorial_sell` (50), in that order, with fixed text, and they are never refilled. Each carries `done` and `paid`. Today they are visible only on the pause menu's Requests page, which a new player has no reason to open. Pinning them on the HUD is reading a list that already exists; nothing about the board's draw, its seeding or its payouts changes.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_request_board.gd`:

```gdscript
## THE THREE PINNED ON THE HUD. They already existed and were only visible on a pause menu
## page a new player has no reason to open (owner, 2026-08-31: the how do I earn money path
## is not legible in the first minutes).
func test_the_tutorial_rows_are_the_three_seeded_ones_in_order() -> void:
	var board: RequestBoard = _board()
	board.seed_tutorial()
	var rows: Array[Dictionary] = board.tutorial_rows()
	assert_eq(rows.size(), 3)
	for i in rows.size():
		assert_eq(String(rows[i]["id"]), RequestBoardScript.TUTORIAL_IDS[i])
		assert_false(String(rows[i]["text"]).is_empty())
		assert_gt(int(rows[i]["reward_bits"]), 0)


func test_a_board_with_no_tutorial_seeded_pins_nothing() -> void:
	assert_eq(_board().tutorial_rows().size(), 0)


func test_a_finished_tutorial_row_says_so_but_stays_pinned_until_it_is_claimed() -> void:
	var board: RequestBoard = _board()
	board.seed_tutorial()
	board.on_caught(_any_data(), &"ranch")
	var rows: Array[Dictionary] = board.tutorial_rows()
	assert_eq(rows.size(), 3, "finishing one does not take it off the list")
	assert_true(bool(rows[0]["done"]), "catching a pony finishes the first one")
	assert_false(bool(rows[0]["paid"]))


func test_a_claimed_tutorial_row_comes_off_the_list() -> void:
	var board: RequestBoard = _board()
	board.seed_tutorial()
	board.on_caught(_any_data(), &"ranch")
	board.claim(RequestBoardScript.TUTORIAL_IDS[0])
	var rows: Array[Dictionary] = board.tutorial_rows()
	assert_eq(rows.size(), 2)
	assert_eq(String(rows[0]["id"]), RequestBoardScript.TUTORIAL_IDS[1])


func test_the_tutorial_ids_are_the_ids_seed_tutorial_actually_writes() -> void:
	var board: RequestBoard = _board()
	board.seed_tutorial()
	var seeded: Array[String] = []
	for r in board.requests():
		seeded.append(String((r as Dictionary)["id"]))
	assert_eq(seeded, RequestBoardScript.TUTORIAL_IDS,
		"a constant that has drifted from the seeder pins the wrong three")
```

(use whatever `test_request_board.gd` already has for `_board()` and a `PonyData`; if it has no `_any_data()` helper, add one returning the first record out of its existing fixture registry.)

Append to `game/test/test_hud.gd`:

```gdscript
func test_the_task_list_is_empty_until_it_is_given_rows() -> void:
	assert_eq(_hud.task_lines().size(), 0)


func test_the_task_list_ticks_what_is_done_and_leaves_the_rest_open() -> void:
	_hud.set_tasks([
		{"id": "tutorial_catch", "text": "Catch a pony with your magic beam.",
			"done": true, "paid": false, "reward_bits": 20},
		{"id": "tutorial_pen", "text": "Move a pony into a pen.",
			"done": false, "paid": false, "reward_bits": 30},
	])
	var lines: Array[String] = _hud.task_lines()
	assert_eq(lines.size(), 3, "a title and two rows")
	assert_eq(lines[0], HudScript.TASK_TITLE)
	assert_true(lines[1].contains("Catch a pony"))
	assert_true(lines[1].contains("20"), "the reward is the reason to do it")
	assert_ne(lines[1].substr(0, 2), lines[2].substr(0, 2),
		"a finished row and an open one must not look the same")


func test_an_empty_task_list_draws_no_title_either() -> void:
	_hud.set_tasks([{"id": "a", "text": "t", "done": false, "paid": false,
		"reward_bits": 1}])
	_hud.set_tasks([])
	assert_eq(_hud.task_lines().size(), 0,
		"once the three are claimed the checklist goes away entirely")


func test_nothing_the_task_list_draws_carries_a_dash() -> void:
	_hud.set_tasks([{"id": "tutorial_sell", "text": "Sell a gem at the market.",
		"done": false, "paid": false, "reward_bits": 50}])
	for line in _hud.task_lines():
		assert_false(line.contains("--") or line.contains("—"), line)
```

(add `const HudScript := preload("res://ui/hud.gd")` to `test_hud.gd` if it is not already there.)

Append to `game/test/test_letters.gd`:

```gdscript
## THE ONE SCREEN EXPLAINER. The owner, 2026-08-31: "rework the WELCOME letter into a one
## screen explainer (catch, pen, gems, sell at the Market; quota and balance in one
## sentence each)". The shipped welcome said "Catch ponies, keep them happy, and bring us
## stock", which names none of the four steps and neither of the two numbers.
func test_the_welcome_letter_names_every_step_of_the_money_loop() -> void:
	var letter: Dictionary = LettersScript.render(LettersScript.Id.WELCOME,
		{"name": "Twilight", "balance": 25000, "quota": 2})
	var body: String = "\n".join(letter["body"]).to_lower()
	for step: String in ["catch", "pen", "gem", "market"]:
		assert_true(body.contains(step), "the welcome must name '%s': %s" % [step, body])


func test_the_welcome_letter_states_the_balance_and_the_quota_once_each() -> void:
	var letter: Dictionary = LettersScript.render(LettersScript.Id.WELCOME,
		{"name": "Twilight", "balance": 25000, "quota": 2})
	var body: String = "\n".join(letter["body"])
	assert_true(body.contains("25000") or body.contains("25,000"), body)
	assert_true(body.contains("2 ponies") or body.contains("2 pony"), body)


func test_the_welcome_letter_still_fits_the_panel_at_the_longest_legal_name() -> void:
	var letter: Dictionary = LettersScript.render(LettersScript.Id.WELCOME,
		{"name": "M".repeat(LettersScript.MAX_NAME_LENGTH), "balance": 25000, "quota": 2})
	for line: String in letter["body"]:
		assert_lte(line.length(), LettersScript.LINE_WIDTH, line)
```

- [ ] **Step 2: Run them to make sure they fail**

Run:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_request_board.gd -gtest=res://test/test_hud.gd \
  -gtest=res://test/test_letters.gd -gexit
```
Expected: FAIL on `TUTORIAL_IDS`, `tutorial_rows()`, `set_tasks()` and the welcome letter's missing words.

- [ ] **Step 3: Name the tutorial three in `game/systems/request_board.gd`**

Add the constant beside `ACTIVE`, and rewrite `seed_tutorial()` to read it, so the two cannot drift:

```gdscript
## THE THREE THE HUD PINS, in the order seed_tutorial() hands them out. A constant rather
## than three literals in two places: the checklist on the screen and the requests on the
## board have to be the same three, and test_request_board.gd asserts that they are.
const TUTORIAL_IDS: Array[String] = ["tutorial_catch", "tutorial_pen", "tutorial_sell"]
const TUTORIAL_REWARDS: Array[int] = [20, 30, 50]
const TUTORIAL_TEXT: Array[String] = [
	"Catch a pony with your magic beam.",
	"Move a pony into a pen.",
	"Sell a gem at the market.",
]
const TUTORIAL_KINDS: Array[int] = [Kind.CATCH_ANY, Kind.PEN_ANY, Kind.SELL_ANY]


## Appends CATCH_ANY, PEN_ANY, SELL_ANY, in that exact order, with fixed text and fixed
## rewards. Does not consume the draw sequence and is not idempotent; call it once, at the
## start of a fresh ranch.
func seed_tutorial() -> void:
	for i in TUTORIAL_IDS.size():
		_requests.append(_tutorial_request(TUTORIAL_IDS[i], TUTORIAL_KINDS[i],
			TUTORIAL_REWARDS[i], TUTORIAL_TEXT[i]))


## THE CHECKLIST THE HUD PINS. The three tutorial requests that are on this board and have
## not been claimed, in seeded order, as flat rows.
##
## A FINISHED ONE STAYS PINNED UNTIL IT IS CLAIMED, deliberately: "done" is the thing the
## player did and "paid" is the bits arriving, and a row that vanished the moment it was
## satisfied would take the reward off the screen before she saw it land.
##
## AN EMPTY ANSWER IS THE NORMAL LATE GAME STATE, and the HUD draws nothing at all for it.
func tutorial_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in TUTORIAL_IDS:
		for r in _requests:
			var req: Dictionary = r
			if String(req.get("id", "")) != id or bool(req.get("paid", false)):
				continue
			out.append({
				"id": id,
				"text": String(req.get("text", "")),
				"done": bool(req.get("done", false)),
				"paid": bool(req.get("paid", false)),
				"reward_bits": int(req.get("reward_bits", 0)),
			})
	return out
```

- [ ] **Step 4: Rewrite the welcome letter in `game/systems/letters.gd`**

Replace the `Id.WELCOME` branch. `LINE_WIDTH` is 58 and the longest name is 16, so `"Dear %s," % who` is at most 22 characters and every other line below is counted to fit:

```gdscript
		Id.WELCOME:
			return _letter("Welcome to the family!", [
				"Dear %s," % who,
				"",
				"Congratulations on your new ranch! Here is how a",
				"partner turns a field of ponies into bits.",
				"",
				"1. CATCH a pony. Hold the beam on her until the",
				"   outer ring fills, then let go.",
				"2. PEN her. Build a paddock on a plot and walk her",
				"   in; a happy pony makes gems.",
				"3. COLLECT the gems she leaves in the pen.",
				"4. SELL them at the Market for bits.",
				"",
				"Your sponsorship balance stands at %d bits, and it" % balance,
				"grows on its own every collection day.",
				"We expect %d ponies delivered to the Depot each" % quota,
				"period. Bits do not settle that; ponies do.",
				"",
				"Together we make the weather!",
				"",
				"Warmly, Sponsorship Services",
			])
```

Both `balance` and `quota` are already unpacked at the top of `render()`; no new parameter is needed. Check the widest line by eye against `LINE_WIDTH`: the longest above is `"   outer ring fills, then let go."` plus the two format lines, all comfortably under 58.

- [ ] **Step 5: Pin the checklist on the HUD**

In `game/ui/hud.tscn`, add a `Tasks` VBoxContainer as a child of `HUD`, after `Bag`:

```
[node name="Tasks" type="VBoxContainer" parent="."]
anchors_preset = 0
offset_left = 44.0
offset_top = 44.0
offset_right = 620.0
offset_bottom = 220.0
theme_override_constants/separation = 4
mouse_filter = 2
```

In `game/ui/hud.gd`:

```gdscript
## THE THREE THINGS TO DO FIRST, pinned until they are claimed. The owner, 2026-08-31: the
## how do I earn money path is not legible in the first minutes. These three requests have
## existed since Phase 2 slice 5 and were reachable only through the pause menu's Requests
## page, which a new player has no reason to open.
##
## THEY GO AWAY ON THEIR OWN. Once all three are claimed, tutorial_rows() answers empty and
## this whole block, title and all, stops being drawn: a permanent checklist in the corner
## of an experienced player's screen is clutter, and the board is where requests live after
## the first ten minutes.
const TASK_TITLE := "Getting started"
const TASK_DONE := "[x] "
const TASK_OPEN := "[ ] "
const COLOR_TASK_DONE := Color(0.62, 0.86, 0.60, 0.92)
const COLOR_TASK_OPEN := Color(1.0, 1.0, 1.0, 0.88)
```

```gdscript
@onready var _tasks: VBoxContainer = $Tasks
```

```gdscript
var _task_lines: Array[String] = []
```

```gdscript
## Push the checklist. `rows` is RequestBoard.tutorial_rows()'s output; an empty array
## clears the block entirely.
func set_tasks(rows: Array[Dictionary]) -> void:
	_task_lines = []
	for child in _tasks.get_children():
		child.queue_free()
	if rows.is_empty():
		return
	_task_lines.append(TASK_TITLE)
	for row: Dictionary in rows:
		var done: bool = bool(row.get("done", false))
		_task_lines.append("%s%s  (%d bits)" % [TASK_DONE if done else TASK_OPEN,
			String(row.get("text", "")), int(row.get("reward_bits", 0))])
	for i in _task_lines.size():
		var label := Label.new()
		label.text = _task_lines[i]
		var colour: Color = COLOR_WORLD_LINE
		if i > 0:
			colour = COLOR_TASK_DONE if _task_lines[i].begins_with(TASK_DONE) \
				else COLOR_TASK_OPEN
		_style_label(label, 24 if i == 0 else 20, colour)
		_tasks.add_child(label)


## Every line the checklist is drawing, in order, title first. For the tests, which
## otherwise have no way to read it without walking Label nodes.
func task_lines() -> Array[String]:
	return _task_lines.duplicate()
```

- [ ] **Step 6: Push the checklist from `game/world/ranch.gd`**

The board changes on exactly three events, all of which already run through `_pay_out()` or `_rebuild_request_board()`. Add one push and call it from both:

```gdscript
## Repaint the HUD's starter checklist. Called wherever the board can have moved: after a
## payout, after a rebuild, and once at boot. Cheap (three rows, and nothing at all once
## they are claimed) and idempotent.
func _refresh_tasks() -> void:
	var hud := get_node_or_null(^"HUD")
	if hud == null or not hud.has_method("set_tasks"):
		return
	hud.set_tasks(_board.tutorial_rows() if _board != null else [] as Array[Dictionary])
```

Call `_refresh_tasks()` at the end of `_pay_out()`, at the end of `_rebuild_request_board()`, and once in `_ready()` immediately after the board is built.

- [ ] **Step 7: Confirm the Market prompt already says what it does**

Task 2 set it: `Interaction.prompt_for()` answers `"E: Market, sell gems"` for `Kind.MARKET`, and `test_interaction.gd` pins that string. Add one more assertion there so the intent is recorded rather than incidental:

```gdscript
## THE REPORT: "the Market prompt says what it does". "E: Market" tells a player where she
## is standing, which she can already see; the verb is the part she needs.
func test_the_market_prompt_names_the_verb_and_not_only_the_place() -> void:
	var line: String = InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 1.0), "E")
	assert_true(line.to_lower().contains("sell"), line)
	assert_true(line.to_lower().contains("gem"), line)
```

- [ ] **Step 8: Run the tests, the gates and the suite**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_request_board.gd -gtest=res://test/test_hud.gd \
  -gtest=res://test/test_letters.gd -gtest=res://test/test_interaction.gd -gexit
bash tools/run_tests.sh
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/collection_test.tscn
echo "collection exit $?"
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/creation_test.tscn
echo "creation exit $?"
```
Expected: PASS everywhere. `creation_test.gd` renders every letter template at the longest legal name and checks `LINE_WIDTH` and the copy rule; the rewritten welcome goes through that unchanged, and if it goes red a line is too long. `collection_test.gd` claims all three tutorial requests, so it is the gate that exercises the checklist emptying itself.

- [ ] **Step 9: Play the first two minutes**

Delete your save slot, or run with a scratch one, and start a new game:
```bash
tools/bin/godot --path game world/ranch.tscn
```
The welcome names catch, pen, gems and the Market, and states the balance and the quota in one sentence each. Three unticked boxes sit in the top left. Catching a pony ticks the first; the tick goes away when the board pays out. Walking to the Market reads `E: Market, sell gems`. Selling a gem clears the last box and the whole checklist disappears.

- [ ] **Step 10: Commit**

```bash
printf 'feat: the first two minutes say where bits come from\n\nThe owner, 2026-08-31: the how do I earn money path is not legible in the first\nminutes. The welcome letter said "Catch ponies, keep them happy, and bring us\nstock", which names none of the four steps and neither of the two numbers; the\nthree tutorial requests existed but were reachable only through a pause menu\npage a new player has no reason to open; and the Market prompt said where she\nwas standing rather than what pressing E would do.\n\nThe welcome is a one screen explainer now: catch, pen, collect, sell, then the\nbalance and the quota in a sentence each, still under Letters.LINE_WIDTH at the\nlongest legal name and still cheerful corporate. RequestBoard.TUTORIAL_IDS names\nthe three that seed_tutorial() writes, so the constant and the seeder cannot\ndrift, and tutorial_rows() hands the HUD a checklist that ticks what is done and\ndisappears entirely once all three are claimed.\n' > /tmp/onboarding-commit.txt
git add game/systems/letters.gd game/systems/request_board.gd game/ui/hud.gd \
  game/ui/hud.tscn game/world/ranch.gd game/test/test_letters.gd \
  game/test/test_request_board.gd game/test/test_hud.gd game/test/test_interaction.gd
git commit -F /tmp/onboarding-commit.txt
```

---

### Task 8: Manes from the pool, and two ponies behind counters

**Files:**
- Create: `game/world/attendant.gd`, `game/test/test_mane_pool.gd`, `game/test/test_attendant.gd`
- Modify: `game/systems/stock_palette.gd`, `game/systems/pony_instance.gd`, `game/actors/pony/pony_visuals.gd`, `game/actors/pony/pony.gd`, `game/actors/player/player.gd`, `game/ui/creation_screen.gd`, `game/ui/creation_screen.tscn`, `game/world/spawner.gd`, `game/world/race_runner.gd`, `game/world/ranch.gd`, `game/world/ranch.tscn`, `game/scenes/test/model_gallery.gd`
- Test: `game/test/test_mane_pool.gd`, `game/test/test_attendant.gd`, `game/test/test_stock_palette.gd`, `game/test/test_pony_instance.gd`, `game/test/test_creation_screen.gd`, `game/test/test_pony_visuals.gd`

**Interfaces:**
- Consumes: `StockTint.apply(model, palette, triple) -> int`, `StockTint.override_of(model, material_name) -> StandardMaterial3D`, `PonyVisuals.ANIMATION_PLAYER_PATH` (`^"AnimationPlayer"`), `PonyRegistry.by_id(id) -> PonyData`, `Props.world_aabb(node: Node3D) -> AABB`, `Props.seat(node: Node3D, ground: float) -> void`, `Terrain.height_at(x, z) -> float`, `CollisionLayers.PROPS`, `PlayerLook.mane_style` (already saved and restored, and read by nothing).
- Produces:
  - `StockPalette.MANE_STYLES: Array[String]` (six `res://` model paths), `static func mane_style_count() -> int`, `static func mane_style_path(index: int) -> String`, `static func mane_style_label(index: int) -> String`, `func draw_look(rng: RandomNumberGenerator) -> Dictionary` (replaces `draw_triple()`; returns `coat`, `mane`, `eyes`, `mane_style`).
  - `PonyVisuals.build(data: PonyData, model_path_override: String = "") -> Node3D`.
  - `PonyInstance.stock` may carry `"mane_style": int`, defaulted to 0 by `from_dict()`.
  - `Pony.set_stock(look: Dictionary)` unchanged in signature; `Spawner._spawn_one(data, marker, slot, look: Dictionary = {})` gains the fourth argument.
  - `Player._build_visuals(mane_style: int = 0) -> void`; `Player.apply_look(look)` rebuilds the body when the style changed.
  - `CreationScreen.cycle_mane_style(step: int) -> void`, `CreationScreen.MANE_STYLE_LABEL`.
  - `class_name Attendant extends StaticBody3D`: `func dress(data: PonyData, look: Dictionary, facing: Vector3) -> bool`, `func has_model() -> bool`, `func facing() -> Vector3`.
  - `ranch.attendant_count() -> int`; the ranch report prints `RANCH attendants=2`.

**Report 9.** "Stock ponies and character creation currently all use the pokeypierce.glb base, so every pony has the same mane. Add a small curated donor pool as alternative BASE MODELS: stock ponies draw a base at random, and creation gains a Mane style row that cycles the pool with the player's colours applied."

**The data path, chosen and stated.** The pool lives on `StockPalette` as script level constants, NOT on `PonyData` and NOT as new hidden `.tres` records. Three reasons. `PlayerLook.mane_style` already exists, is already written by `to_dict()`, is already restored and clamped by `from_dict()`, and is documented in its own file as "the field exists so a second sourced style is data rather than a schema change"; it is an index, and an index wants a list to index into. `StockPalette` is already the one place a look is turned from indices into things, already serves the player and the crowd from one pipeline, and already carries the static `IDS` list of hidden records, so a second static list beside it is the same shape. And a pool of `res://` paths is developer curation, not tuning data: it is the one thing in the look system that a `.tres` edit must never be able to point at a file that is not there. Adding hidden `.tres` records instead would triple the crowd's record count (three personalities times six models) for no gain, and putting a model list on `PonyData` would put it on all 43 named characters who each already have exactly one.

**The pool, and how it is verified.** Six unicorn or horn having ReVAmped rigs. `pokeypierce.glb` is index 0 and stays index 0, so every existing save, every hidden record and every default loads exactly the pony it loaded before. The other five are `lyra`, `minuette`, `starlightglimmer`, `sunsetshimmer` and `twilight`. There are no spare models on disk: all 43 converted `.glb` are already some named character's model, `pokeypierce.glb` included, so reuse is unavoidable and is already how the crowd works. `game/test/test_mane_pool.gd` puts every entry through the same four checks the base model passes, and Step 2 runs it before anything is built on top of it. **If any of the five fails, replace it with the next entry from this ordered fallback list and re run: `trixie`, `rarity`, `vinylscratch`, `shiningarmor`.** Do not carry a failing model and do not loosen a check.

**Report 10.** "A vendor pony at the Market and a teller at the casino cage: static dressed pony bodies (PonyVisuals.build + StockTint, like RaceRunner: plain Node3D, not Pony: nothing the beam can grab, no census impact: the ranch report must not count them as ponies; add them as props or a new report line). Facing the counter, idle. No dialogue (slice 4 brings the talk box)."

**Two resolutions recorded.** "Facing the counter" is resolved as standing AT the counter and facing OUT across it, toward whoever walks up, which is what a vendor does and what makes her legible from the approach. And the casino teller stands at the Palace door rather than at the `Cage` marker inside it: the cage is a menu the player opens from the door (`Kind.PALACE`, `PALACE_RADIUS` 5.0 m), and Task 3 raised the interior floor onto a 0.75 m plinth, so a body seated on the terrain inside the building would be knee deep in its own floor. She greets you under the marquee, which is where a greeter goes.

**The census.** Both stand under a new `Attendants` node in `ranch.tscn`, which is neither `Props` nor `Buildings`, so `prop_count = Props.expected_count() + buildings.get_child_count()` does not move and `RANCH_OK props=60` is unchanged. They are `StaticBody3D`, never `Pony`, so `spawner.get_spawned()` never sees them and `ponies=49` is unchanged. `MagicBeam._is_grabbable()` tests `body is PonyScript`, so the beam finds nothing to take. The report gains its own `RANCH attendants=2` line and a check saying all of that out loud.

- [ ] **Step 1: Write the pool's verification test**

`game/test/test_mane_pool.gd`:

```gdscript
extends GutTest
## THE CURATED DONOR POOL, checked one model at a time against everything the base model
## already promises. The owner, 2026-08-31: every pony has the same mane, because all three
## hidden stock records and the player all point at pokeypierce.glb.
##
## THIS FILE IS THE GATE ON THE POOL. There are no spare models on disk (all 43 converted
## .glb are some named character's), so a donor is always a rig somebody else also wears,
## and the only thing that makes one safe to draw at random is that it tints, animates and
## stands like the base. A model that fails any check below is removed from
## StockPalette.MANE_STYLES, not accommodated.
##
## Skips whole, not partly, on a checkout with no converted assets (docs/ci.md section 4).

const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PropsScript := preload("res://world/props.gd")

## Every clip the crowd and the player actually play. Gait picks between them by speed.
const REQUIRED_CLIPS: Array[StringName] = [&"idle", &"walk", &"gallop"]

## How far a donor's standing height may differ from the base model's, as a ratio. Tight
## enough to reject a filly rig or one carrying a hat, loose enough not to care about a
## mane a few centimetres taller.
const HEIGHT_BAND := 0.15

var _built: Array[Node3D] = []


func after_each() -> void:
	for node in _built:
		if is_instance_valid(node):
			node.free()
	_built = []


func _stock_record() -> PonyData:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	return registry.by_id(StockPaletteScript.IDS[0])


func _build(path: String) -> Node3D:
	var data: PonyData = _stock_record()
	if data == null or not ResourceLoader.exists(path):
		return null
	var node: Node3D = PonyVisualsScript.build(data, path)
	if node != null:
		_built.append(node)
	return node


func test_the_pool_has_a_few_styles_and_the_base_model_is_the_first_of_them() -> void:
	assert_gte(StockPaletteScript.mane_style_count(), 4, "a pool of one is what we had")
	assert_lte(StockPaletteScript.mane_style_count(), 6, "curated, not the whole roster")
	assert_eq(StockPaletteScript.mane_style_path(0),
		"res://assets/converted/ponies/pokeypierce.glb",
		"index 0 must stay the shipped base, or every existing save changes pony")


func test_an_index_out_of_range_wraps_like_every_other_palette_row() -> void:
	var n: int = StockPaletteScript.mane_style_count()
	assert_eq(StockPaletteScript.mane_style_path(n), StockPaletteScript.mane_style_path(0))
	assert_eq(StockPaletteScript.mane_style_path(-1),
		StockPaletteScript.mane_style_path(n - 1))


func test_every_style_has_a_label_a_person_can_read() -> void:
	for i in StockPaletteScript.mane_style_count():
		var label: String = StockPaletteScript.mane_style_label(i)
		assert_false(label.is_empty())
		assert_false(label.contains("--") or label.contains("—"), label)
		assert_false(label.contains("res://"), "a file path is not a label: %s" % label)


func test_every_model_in_the_pool_exists_and_builds() -> void:
	if _stock_record() == null or not ResourceLoader.exists(
			StockPaletteScript.mane_style_path(0)):
		pass_test("no converted assets on this machine")
		return
	for i in StockPaletteScript.mane_style_count():
		var path: String = StockPaletteScript.mane_style_path(i)
		assert_true(ResourceLoader.exists(path), "%s is not on disk" % path)
		assert_not_null(_build(path), "%s did not build" % path)


func test_every_model_in_the_pool_carries_the_clips_the_game_plays() -> void:
	if _stock_record() == null or not ResourceLoader.exists(
			StockPaletteScript.mane_style_path(0)):
		pass_test("no converted assets on this machine")
		return
	for i in StockPaletteScript.mane_style_count():
		var path: String = StockPaletteScript.mane_style_path(i)
		var node: Node3D = _build(path)
		if node == null:
			continue
		var anim := node.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) \
			as AnimationPlayer
		assert_not_null(anim, "%s has no AnimationPlayer" % path)
		for clip: StringName in REQUIRED_CLIPS:
			assert_true(anim.has_animation(clip), "%s has no '%s' clip" % [path, clip])


## THE CHECK THAT MADE THE POOL CURATED RATHER THAN "every model in the directory".
## StockTint matches SURFACE NAMES (body, hair, tail, eyeball_l, eyeball_r); a rig exported
## with different names recolours into nothing and stands in the field wearing somebody
## else's cutie mark.
func test_every_model_in_the_pool_takes_the_tint_on_every_surface_the_base_does() -> void:
	if _stock_record() == null or not ResourceLoader.exists(
			StockPaletteScript.mane_style_path(0)):
		pass_test("no converted assets on this machine")
		return
	for i in StockPaletteScript.mane_style_count():
		var path: String = StockPaletteScript.mane_style_path(i)
		var node: Node3D = _build(path)
		if node == null:
			continue
		var touched: int = StockTintScript.apply_colors(node,
			Color.RED, Color.BLUE, Color.GREEN)
		assert_gt(touched, 0, "%s: the tint reached no surface at all" % path)
		for surface: StringName in [&"body", &"hair", &"tail", &"eyeball_l"]:
			assert_not_null(StockTintScript.override_of(node, surface),
				"%s has no '%s' surface for the tint to land on" % [path, surface])


## A filly rig, or one carrying a hat or a cape, stands a different height, and a crowd of
## ponies at three different heights reads as a bug rather than as variety.
func test_every_model_in_the_pool_stands_about_as_tall_as_the_base() -> void:
	if _stock_record() == null or not ResourceLoader.exists(
			StockPaletteScript.mane_style_path(0)):
		pass_test("no converted assets on this machine")
		return
	var base: Node3D = _build(StockPaletteScript.mane_style_path(0))
	if base == null:
		pass_test("no converted assets on this machine")
		return
	add_child(base)
	var base_height: float = PropsScript.world_aabb(base).size.y
	assert_gt(base_height, 0.5, "sanity: the base model has a height")
	for i in range(1, StockPaletteScript.mane_style_count()):
		var path: String = StockPaletteScript.mane_style_path(i)
		var node: Node3D = _build(path)
		if node == null:
			continue
		add_child(node)
		var h: float = PropsScript.world_aabb(node).size.y
		assert_almost_eq(h / base_height, 1.0, HEIGHT_BAND,
			"%s stands %.3f m against the base's %.3f m" % [path, h, base_height])


func test_draw_look_stays_inside_the_pool_and_is_deterministic() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var a := RandomNumberGenerator.new()
	a.seed = 1234
	var b := RandomNumberGenerator.new()
	b.seed = 1234
	assert_eq(palette.draw_look(a), palette.draw_look(b), "same seed, same pony")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var seen := {}
	for i in 200:
		var look: Dictionary = palette.draw_look(rng)
		assert_between(int(look["mane_style"]), 0,
			StockPaletteScript.mane_style_count() - 1)
		seen[int(look["mane_style"])] = true
	assert_eq(seen.size(), StockPaletteScript.mane_style_count(),
		"two hundred draws must reach every style, or the crowd is still one mane")
```

- [ ] **Step 2: Add the pool to `game/systems/stock_palette.gd` and run the probe FIRST**

Add beside `IDS`:

```gdscript
## THE CURATED DONOR POOL: the base models a stock pony or the player's own pony may be
## built from. The owner, 2026-08-31: every pony has the same mane, because all three
## hidden records and the player point at pokeypierce.glb.
##
## SCRIPT CONSTANTS, NOT A .tres FIELD AND NOT MORE HIDDEN RECORDS. This is the one part of
## the look system that must never be able to name a file that is not there, so it is
## developer curation rather than tuning data; PlayerLook.mane_style is already an index and
## an index wants a list beside IDS to index into; and hidden records would multiply by six
## for nothing while a model list on PonyData would sit uselessly on all 43 named
## characters who each already have exactly one.
##
## INDEX 0 IS pokeypierce.glb AND MUST STAY THERE. Every existing save, every hidden record
## and PlayerLook's own default is index 0, so moving it would restyle every pony in every
## file in the game.
##
## THEY ARE ALL RIGS SOMEBODY ELSE WEARS, and that is unavoidable: all 43 converted models
## belong to a named character, pokeypierce.glb included, so there is no spare mesh to
## promote. What makes one safe to draw at random is that it tints, animates and stands like
## the base, and game/test/test_mane_pool.gd checks exactly that for every entry. A model
## that fails is removed here rather than accommodated anywhere else.
const MANE_STYLES: Array[String] = [
	"res://assets/converted/ponies/pokeypierce.glb",
	"res://assets/converted/ponies/lyra.glb",
	"res://assets/converted/ponies/minuette.glb",
	"res://assets/converted/ponies/starlightglimmer.glb",
	"res://assets/converted/ponies/sunsetshimmer.glb",
	"res://assets/converted/ponies/twilight.glb",
]

## WHAT THE CREATION SCREEN'S ROW CALLS THEM. Numbered rather than described, on purpose:
## a name like "Braided" that turns out not to match the mesh is worse than no name, and
## the player is looking at the pony on the turntable while she cycles this row.
static func mane_style_label(index: int) -> String:
	return "Style %d of %d" % [posmod(index, maxi(1, MANE_STYLES.size())) + 1,
		MANE_STYLES.size()]


static func mane_style_count() -> int:
	return MANE_STYLES.size()


## Wraps, like every other row here and for the same reason: a hand edited save or an off
## by one produces the wrong mane rather than an out of range read.
static func mane_style_path(index: int) -> String:
	if MANE_STYLES.is_empty():
		return ""
	return MANE_STYLES[posmod(index, MANE_STYLES.size())]
```

and replace `draw_triple()`:

```gdscript
## ONE PONY'S WHOLE LOOK, drawn off `rng`. Four numbers pulled in a fixed order, so the same
## seed always produces the same pony and a gate can pin one.
##
## RENAMED FROM draw_triple(), which it outgrew: the look is a colour triple plus a base
## model now, and a function called "triple" that answers four keys is a function whose name
## is lying. StockTint reads only the three colour keys and ignores the fourth.
func draw_look(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"coat": rng.randi_range(0, maxi(0, coats.size() - 1)),
		"mane": rng.randi_range(0, maxi(0, manes.size() - 1)),
		"eyes": rng.randi_range(0, maxi(0, eyes.size() - 1)),
		"mane_style": rng.randi_range(0, maxi(0, mane_style_count() - 1)),
	}
```

Then find and fix every caller before going further:
```bash
grep -rn "draw_triple" game/ docs/
```
The three are `game/world/spawner.gd:_spawn_stock`, `game/scenes/test/model_gallery.gd:_build_stock_row` and `game/test/test_stock_palette.gd`; rename each and move its assertions onto the four keys.

Now run the probe, before any of the rest of this task is built on it:
```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_mane_pool.gd -gexit
```
`test_every_model_in_the_pool_builds` will still fail (the override argument does not exist yet); the four that do not need it must pass. **If a model fails the clip, tint or height check, swap it out now for the next of `trixie`, `rarity`, `vinylscratch`, `shiningarmor` and run again**, and record which one you swapped and why in the commit message.

- [ ] **Step 3: Let `PonyVisuals.build()` take a model override**

In `game/actors/pony/pony_visuals.gd`:

```gdscript
## Build a ready-to-use instance of `data`: resolve and load its model, attach the
## mane/tail spring simulation via PonyRig, and hand back a Node3D whose AnimationPlayer is
## reachable at ANIMATION_PLAYER_PATH.
##
## `model_path_override` REPLACES data.model_path AND NOTHING ELSE. It exists because a
## stock pony's mane is a property of the INDIVIDUAL, not of the hidden record three
## thousand of them share (game/systems/stock_palette.gd MANE_STYLES); everything else about
## her, her personality, her stats, her name, still comes off the PonyData. Empty means "use
## the record's own model", which is what all 43 named characters pass and what every
## shipped call site did before this argument existed.
static func build(data: PonyData, model_path_override: String = "") -> Node3D:
	if data == null:
		push_error("PonyVisuals.build: data is null")
		return null

	var model_path: String = model_path_override if not model_path_override.is_empty() \
		else data.model_path
	if model_path.is_empty():
		push_error("PonyVisuals.build: pony '%s' has an empty model_path" % data.id)
		return null

	if not ResourceLoader.exists(model_path):
		push_error("PonyVisuals.build: pony '%s' model_path '%s' does not resolve to an existing resource" % [
			data.id, model_path
		])
		return null

	var scene: Resource = load(model_path)
	if scene == null or not (scene is PackedScene):
		push_error("PonyVisuals.build: pony '%s' model_path '%s' did not load as a PackedScene" % [
			data.id, model_path
		])
		return null
	# ... the rest of the shipped function is unchanged, with `data.model_path` replaced by
	#     `model_path` in the two remaining push_error() messages ...
```

Add to `game/test/test_pony_visuals.gd`:

```gdscript
func test_an_override_replaces_the_model_and_leaves_everything_else_alone() -> void:
	var data: PonyData = _any_record()
	if data == null or not ResourceLoader.exists(StockPaletteScript.mane_style_path(1)):
		pass_test("no converted assets on this machine")
		return
	var node: Node3D = PonyVisualsScript.build(data, StockPaletteScript.mane_style_path(1))
	assert_not_null(node)
	autofree(node)
	assert_not_null(node.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH),
		"an overridden model still has to satisfy the AnimationPlayer contract")


func test_an_override_that_is_not_on_disk_is_refused_rather_than_falling_back() -> void:
	var data: PonyData = _any_record()
	if data == null:
		pass_test("no roster on this machine")
		return
	assert_null(PonyVisualsScript.build(data, "res://assets/converted/ponies/nobody.glb"),
		"silently building the record's own model would hide the typo forever")
```

- [ ] **Step 4: Carry the style through the save and through every body**

`game/systems/pony_instance.gd`: amend the `stock` doc comment and `from_dict()`:

```gdscript
## HER LOOK, if she is one of the crowd: `{"coat": int, "mane": int, "eyes": int,
## "mane_style": int}`. The first three are indices into game/data/stock_palette.tres; the
## fourth is an index into StockPalette.MANE_STYLES, which base model she was built from.
## EMPTY for a named character, whose look is her model.
```
```gdscript
		if ok:
			inst.stock = {
				"coat": int(triple["coat"]),
				"mane": int(triple["mane"]),
				"eyes": int(triple["eyes"]),
				# OPTIONAL, AND ZERO IS THE SHIPPED BASE. Every save written before the
				# donor pool existed has no such key, and index 0 is pokeypierce.glb, so
				# those ponies load looking exactly as they did.
				"mane_style": maxi(0, int(triple.get("mane_style", 0))),
			}
```

`game/actors/pony/pony.gd`, `_apply_data()`:

```gdscript
	var body: Node3D = PonyVisualsScript.build(_data, _base_model_path())
```
and next to `_apply_stock_tint()`:

```gdscript
## Which base model this pony's body is built from: her own, off her stock look, or the
## record's for a named character. Empty means "the record's own", which is what
## PonyVisuals.build() wants for the 43 named ponies.
##
## READ BEFORE THE BODY IS BUILT, which is why set_stock() has always had to be called
## before setup() and now really needs to be: a tint can be re-applied to a body that
## already exists, a different mesh cannot.
func _base_model_path() -> String:
	if _stock.is_empty():
		return ""
	return StockPaletteScript.mane_style_path(int(_stock.get("mane_style", 0)))
```

`game/world/spawner.gd`: give `_spawn_one()` the look and set it before `setup()`:

```gdscript
func _spawn_one(data: PonyData, marker: ZoneMarker, slot: int,
		look: Dictionary = {}) -> CharacterBody3D:
	# ... unchanged down to and including `add_child(pony)` ...
	add_child(pony)
	# BEFORE setup(), and that ordering is now load bearing. setup() is what builds the
	# body, and which base model it builds is a property of her look; set_stock() after the
	# fact could only re-tint a body that had already been built from the wrong mesh. It is
	# a no op for a named pony, who passes an empty look.
	if not look.is_empty():
		pony.set_stock(look)
	pony.setup(data)
	pony_spawned.emit(pony)
	return pony
```

and `_spawn_stock()` hands it over instead of setting it afterwards:

```gdscript
	var look: Dictionary = _palette.draw_look(rng)
	var data: PonyData = _registry_for_stock().by_id(id)
	if data == null or data.model_path.is_empty() or not ResourceLoader.exists(data.model_path):
		return null
	return _spawn_one(data, marker, slot, look)
```

`game/world/race_runner.gd`, in `dress()`:

```gdscript
	var built: Node3D = PonyVisualsScript.build(data,
		StockPaletteScript.mane_style_path(int(triple.get("mane_style", 0))) \
			if not triple.is_empty() else "")
```

`game/actors/player/player.gd`:

```gdscript
## The mane style the body currently standing in Visuals was built from. apply_look()
## compares against it: a tint can be re-applied to a body that already exists, a different
## mesh cannot, so a change here means a rebuild.
var _mane_style_built := 0
```
```gdscript
func _build_visuals(mane_style: int = 0) -> void:
	# ... unchanged down to the by_id() lookup ...
	var pony: Node3D = PonyVisualsScript.build(data,
		StockPaletteScript.mane_style_path(mane_style))
	if pony == null:
		push_error("Player: PonyVisuals.build failed for '%s'" % pony_id)
		return
	_mane_style_built = mane_style
	# ... unchanged from visuals.add_child(pony) onwards; _place_beam_origin() measures the
	#     horn tip off whichever model was actually built, so a new mane moves the emitter
	#     with it and nothing here has to know that ...
```
```gdscript
func apply_look(look: PlayerLook) -> void:
	if look == null:
		return
	if look.mane_style != _mane_style_built:
		_rebuild_visuals(look.mane_style)
	if visuals.get_child_count() == 0:
		return
	var body: Node3D = visuals.get_child(0)
	StockTintScript.apply(body, StockPaletteScript.load_player(),
		{"coat": look.coat, "mane": look.mane, "eyes": look.eyes})
	CutieMarkScript.apply(body, look.mark())


## Swap the body for one built from a different base model. Freed outright rather than
## queue_free()'d, for game/world/race_runner.gd's reason: a queued node is still among
## get_children() until the end of the frame, so the "body is child 0 of Visuals"
## convention this whole file rests on would be false for a frame.
func _rebuild_visuals(mane_style: int) -> void:
	if visuals.get_child_count() > 0:
		var old: Node = visuals.get_child(0)
		visuals.remove_child(old)
		old.free()
	_anim = null
	_build_visuals(mane_style)
```

`game/actors/player/player.gd`'s `_ready()` already calls `_build_visuals()`; the default argument keeps that correct.

- [ ] **Step 5: Give the creation screen a Mane style row**

In `game/ui/creation_screen.tscn`, add a `ManeStyleRow` HBoxContainer under `Panel/Column` immediately after `ManeRow`, holding `PrevManeStyle` (a Button), `ManeStyleValue` (a Label) and `NextManeStyle` (a Button), copying the layout of the existing `ManeRow`; and a `ManeStyleLabel` Label above it, copying `ManeLabel`.

In `game/ui/creation_screen.gd`:

```gdscript
const MANE_STYLE_LABEL := "Mane style"
```
```gdscript
@onready var _mane_style_label: Label = $Panel/Column/ManeStyleLabel
@onready var _mane_style_value: Label = $Panel/Column/ManeStyleRow/ManeStyleValue
```
in `_ready()`, beside the other label assignments: `_mane_style_label.text = MANE_STYLE_LABEL`.

```gdscript
## CYCLE THE BASE MODEL. Unlike the three colour rows, this is not a tint: it is a
## different mesh, so the pony on the turntable is rebuilt and then restyled, which is why
## this is the one row that does not simply call _restyle().
func cycle_mane_style(step: int) -> void:
	_look.mane_style = posmod(_look.mane_style + step,
		maxi(1, StockPaletteScript.mane_style_count()))
	_build_model()
	_restyle()
	_refresh_swatches()
```

`_build_model()` uses the style:

```gdscript
	_model = PonyVisualsScript.build(data,
		StockPaletteScript.mane_style_path(_look.mane_style))
```

`_refresh_swatches()` gains one line:

```gdscript
	if _mane_style_value != null:
		_mane_style_value.text = StockPaletteScript.mane_style_label(_look.mane_style)
```

`drawn_lines()` gains the label and the current style, so the copy rule reaches them:

```gdscript
	var lines: Array[String] = [TITLE, NAME_LABEL, COAT_LABEL, MANE_LABEL, MANE_STYLE_LABEL,
		EYES_LABEL, MARK_LABEL, CONFIRM_LABEL, HINT]
	for i in StockPaletteScript.mane_style_count():
		lines.append(StockPaletteScript.mane_style_label(i))
```

`_wire_controls()` gains two connections:

```gdscript
	_connect(^"Panel/Column/ManeStyleRow/PrevManeStyle",
		func() -> void: cycle_mane_style(-1))
	_connect(^"Panel/Column/ManeStyleRow/NextManeStyle",
		func() -> void: cycle_mane_style(1))
```

Add to `game/test/test_creation_screen.gd`:

```gdscript
func test_cycling_the_mane_style_row_walks_the_pool_and_comes_back() -> void:
	var n: int = StockPaletteScript.mane_style_count()
	for i in n:
		assert_eq(_screen.look().mane_style, i)
		_screen.cycle_mane_style(1)
	assert_eq(_screen.look().mane_style, 0, "one full lap returns to the base model")


func test_cycling_backwards_from_zero_reaches_the_last_style() -> void:
	_screen.cycle_mane_style(-1)
	assert_eq(_screen.look().mane_style, StockPaletteScript.mane_style_count() - 1)


func test_the_mane_style_survives_confirm() -> void:
	_screen.cycle_mane_style(2)
	_screen.confirm()
	assert_eq(_screen.look().mane_style, 2)
```

- [ ] **Step 6: Run everything the variety half touches**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_mane_pool.gd -gtest=res://test/test_stock_palette.gd \
  -gtest=res://test/test_pony_instance.gd -gtest=res://test/test_pony_visuals.gd \
  -gtest=res://test/test_creation_screen.gd -gtest=res://test/test_spawner.gd \
  -gtest=res://test/test_player.gd -gexit
bash tools/run_tests.sh
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/model_gallery.tscn -- --stock
```
Expected: PASS, and the gallery's `--stock` row now prints eight looks whose `mane_style` values are not all zero. On a machine with a display, drop `--headless` from that last command and look at the eight: eight recoloured ponies with more than one mane between them.

- [ ] **Step 7: Write the attendant test**

`game/test/test_attendant.gd`:

```gdscript
extends GutTest
## THE VENDOR AND THE TELLER: dressed pony bodies standing at a counter, and deliberately
## not ponies. Same construction as game/world/race_runner.gd and for the same reason: the
## project rule is that only Pony._state_leaving may free a pony, so anything standing in
## the world that is not part of the herd must not be one.

const AttendantScript := preload("res://world/attendant.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const LayersScript := preload("res://world/collision_layers.gd")

const LOOK := {"coat": 2, "mane": 5, "eyes": 1, "mane_style": 1}

var _who: Attendant = null


func before_each() -> void:
	_who = AttendantScript.new()
	add_child_autofree(_who)


func _record() -> PonyData:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	return registry.by_id(StockPaletteScript.IDS[1])


func test_she_is_a_body_and_never_a_pony() -> void:
	assert_false(_who is PonyScript,
		"nothing standing at a counter may be something the herd counts or the beam takes")
	assert_true(_who is StaticBody3D)


func test_she_blocks_the_player_and_offers_the_beam_nothing() -> void:
	assert_eq(_who.collision_layer, LayersScript.PROPS,
		"she is scenery you cannot walk through, on the layer scenery lives on")
	assert_eq(_who.collision_mask, 0, "she is not looking for anything")


func test_dressing_her_builds_a_body_tinted_from_her_own_look() -> void:
	var data: PonyData = _record()
	if data == null or not ResourceLoader.exists(StockPaletteScript.mane_style_path(1)):
		pass_test("no converted assets on this machine")
		return
	assert_true(_who.dress(data, LOOK, Vector3.FORWARD))
	assert_true(_who.has_model())
	var body: Node3D = _who.get_child(0)
	assert_not_null(StockTintScript.override_of(body, &"body"),
		"she goes through the same one recolour pipeline the crowd does")


func test_dressing_her_twice_replaces_the_body_rather_than_stacking_two() -> void:
	var data: PonyData = _record()
	if data == null or not ResourceLoader.exists(StockPaletteScript.mane_style_path(1)):
		pass_test("no converted assets on this machine")
		return
	_who.dress(data, LOOK, Vector3.FORWARD)
	_who.dress(data, LOOK, Vector3.BACK)
	var bodies := 0
	for child in _who.get_children():
		if child is Node3D and not (child is CollisionShape3D):
			bodies += 1
	assert_eq(bodies, 1, "one attendant, one body")


func test_she_faces_where_she_is_told() -> void:
	var data: PonyData = _record()
	if data == null or not ResourceLoader.exists(StockPaletteScript.mane_style_path(1)):
		pass_test("no converted assets on this machine")
		return
	_who.dress(data, LOOK, Vector3(1.0, 0.0, 0.0))
	assert_almost_eq(_who.facing().dot(Vector3(1.0, 0.0, 0.0)), 1.0, 0.01)


func test_a_facing_of_nowhere_leaves_her_where_she_was_rather_than_erroring() -> void:
	var data: PonyData = _record()
	if data == null or not ResourceLoader.exists(StockPaletteScript.mane_style_path(1)):
		pass_test("no converted assets on this machine")
		return
	var before: float = _who.rotation.y
	_who.dress(data, LOOK, Vector3.ZERO)
	assert_almost_eq(_who.rotation.y, before, 0.0001)


func test_a_null_record_is_refused_and_leaves_no_body() -> void:
	assert_false(_who.dress(null, LOOK, Vector3.FORWARD))
	assert_false(_who.has_model())
```

- [ ] **Step 8: Write `game/world/attendant.gd`**

```gdscript
class_name Attendant
extends StaticBody3D
## SOMEBODY BEHIND THE COUNTER: the vendor at the Market and the teller at the Palace. A
## dressed pony body standing still, and deliberately NOT a Pony.
##
## WHY NOT A PONY. The project's hardest rule is that no pony ever dies and that only
## Pony._state_leaving may free one, and the whole census the ranch gate asserts on is
## "how many ponies are standing in the world". A shopkeeper who was a Pony would be in
## that count, would be something the magic beam could take out of her own shop, and would
## have a leash, a detection area and a state machine she has no use for. So she is built
## exactly the way game/world/race_runner.gd builds a lane: PonyVisuals.build() for the
## body, StockTint for the colours, the idle clip, and nothing else. MagicBeam._is_grabbable()
## tests `body is Pony`, so there is nothing here for the beam to take.
##
## SHE IS SOLID, THOUGH. A StaticBody3D on CollisionLayers.PROPS with no mask, like a lamp
## post or a building: the player bumps into her instead of walking through her, and she is
## looking for nothing.
##
## NO DIALOGUE. Phase 3 slice 4 brings the talk box and the town NPCs; until then she is a
## place that is staffed, which is the whole of what this task is for.
##
## SHE IS COUNTED SEPARATELY. ranch.gd stands her under an `Attendants` node that is neither
## `Props` nor `Buildings`, so neither of the two numbers the ranch gate prints moves, and
## the report prints its own `RANCH attendants=` line beside them.

const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const LayersScript := preload("res://world/collision_layers.gd")

## Her collider: roughly a pony, standing. Not measured off the model, deliberately, because
## a shopkeeper who is exactly her own silhouette is a shopkeeper the player gets wedged
## against; a simple capsule around her barrel is what a prop wants.
const BODY_RADIUS := 0.55
const BODY_HEIGHT := 1.60

var _model: Node3D = null
var _facing := Vector3.FORWARD


func _ready() -> void:
	collision_layer = LayersScript.PROPS
	collision_mask = 0
	_ensure_collider()


## Stand her up: `data` is the hidden record she is built from, `look` her palette indices
## and her base model (StockPalette.MANE_STYLES), and `facing` the direction she looks in.
## Returns whether a body was actually built; false on a checkout with no converted assets,
## which is a reported state and not an error (docs/ci.md section 4).
##
## Safe to call again: the previous body is replaced. Freed outright rather than
## queue_free()'d, for race_runner.gd's reason: a queued node is still among get_children()
## until the end of the frame, and "she has one body" would be false for that frame.
func dress(data: PonyData, look: Dictionary, facing: Vector3) -> bool:
	if _model != null and is_instance_valid(_model):
		remove_child(_model)
		_model.free()
		_model = null
	if data == null:
		return false
	var built: Node3D = PonyVisualsScript.build(data,
		StockPaletteScript.mane_style_path(int(look.get("mane_style", 0))))
	if built == null:
		return false
	_model = built
	add_child(_model)
	StockTintScript.apply(_model, StockPaletteScript.load_stock(), look)
	if facing.length_squared() > 0.0:
		_facing = facing.normalized()
		# The asset's forward is minus Z (baked in by tools/export_blend.py), the same
		# convention game/actors/pony/pony.gd and race_runner.gd turn by.
		rotation.y = atan2(-_facing.x, -_facing.z)
	var anim := _model.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) \
		as AnimationPlayer
	if anim != null and anim.has_animation(&"idle"):
		anim.play(&"idle")
	return true


func has_model() -> bool:
	return _model != null and is_instance_valid(_model)


func facing() -> Vector3:
	return _facing


func _ensure_collider() -> void:
	if get_node_or_null(^"Body") != null:
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var shape := CollisionShape3D.new()
	shape.name = "Body"
	shape.shape = capsule
	shape.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	add_child(shape)
```

- [ ] **Step 9: Stand them on the map**

In `game/world/ranch.tscn`, add an empty node as a child of `Ranch`, after `Buildings`:

```
[node name="Attendants" type="Node3D" parent="."]
```

In `game/world/ranch.gd`, add the preload and the handle:

```gdscript
const AttendantScript := preload("res://world/attendant.gd")
```
```gdscript
@onready var attendants: Node3D = $Attendants
```

Add the constants next to `PALACE_RADIUS`:

```gdscript
## THE TWO PONIES BEHIND COUNTERS, and where they stand.
##
## AT THE DOOR AND FACING OUT. "Facing the counter" is resolved as standing at the counter
## and looking out across it, toward whoever walks up, which is what a vendor does and what
## makes her legible from thirty metres away.
##
## OUTSIDE THE BUILDING, not inside it, and that is a consequence of Building's plinth (see
## Building.FLOOR_TOP): the interior floor stands 0.75 m above the ground the terrain
## reports, so a body seated on the terrain inside a building would be knee deep in its own
## boards. Both counters are things the player opens from the door anyway.
const ATTENDANT_STANDOFF := 1.8

## Their looks, pinned rather than drawn. A shopkeeper who is a different colour every boot
## is a shopkeeper nobody recognises, and a gate that screenshots the Market wants the same
## picture twice.
const VENDOR_LOOK := {"coat": 2, "mane": 5, "eyes": 1, "mane_style": 1}
const TELLER_LOOK := {"coat": 6, "mane": 0, "eyes": 3, "mane_style": 3}
```

Add the builder and call it from `_ready()` right after the buildings are seated:

```gdscript
## STAND THE VENDOR AND THE TELLER. Their positions come off the live building nodes rather
## than being typed as world coordinates, the same rule Strip.mount_marquee() follows: a
## Building's door is in its local plus Z gable end, so the spot in front of it is its own
## origin plus half its depth along that axis plus the standoff, whichever way the building
## has been turned in the scene.
##
## THEY ARE UNDER `Attendants`, WHICH IS NEITHER Props NOR Buildings, so neither number the
## ranch gate prints moves. See _report()'s own attendant checks.
func _stand_attendants() -> void:
	if attendants == null:
		return
	var registry := PonyRegistryScript.new()
	registry.load_all(spawner.pony_dir if spawner != null else "res://data/ponies")
	_stand_one(registry, "Vendor", ^"Buildings/Market", StockPaletteScript.IDS[1],
		VENDOR_LOOK)
	_stand_one(registry, "Teller", ^"Buildings/Palace", StockPaletteScript.IDS[2],
		TELLER_LOOK)


func _stand_one(registry: PonyRegistry, who: String, building_path: NodePath,
		record_id: StringName, look: Dictionary) -> void:
	var building := get_node_or_null(building_path) as Building
	if building == null:
		return
	var data: PonyData = registry.by_id(record_id)
	if data == null:
		return
	var out_dir: Vector3 = (building.global_transform.basis * Vector3(0.0, 0.0, 1.0))
	out_dir.y = 0.0
	if out_dir.length_squared() <= 0.0:
		return
	out_dir = out_dir.normalized()
	var at: Vector3 = building.global_position \
		+ out_dir * (building.depth * 0.5 + ATTENDANT_STANDOFF)
	var node: Attendant = AttendantScript.new()
	node.name = who
	attendants.add_child(node)
	node.global_position = Vector3(at.x, terrain.height_at(at.x, at.z), at.z)
	node.dress(data, look, out_dir)
	PropsScript.seat(node, terrain.height_at(at.x, at.z))


## How many attendants are standing. Printed by the report and asserted there; a public
## reader so a gate does not have to walk the tree.
func attendant_count() -> int:
	return attendants.get_child_count() if attendants != null else 0
```

- [ ] **Step 10: Say so in the report**

In `_report()`, next to the existing prop and pony checks, add:

```gdscript
	# --- the two ponies behind counters, and the census they must not touch ------------
	#
	# THEY ARE NOT PONIES AND THEY ARE NOT PROPS. `ponies=` counts spawner.get_spawned(),
	# which only ever holds Pony nodes; `props=` is Props.expected_count() plus the
	# Buildings children. The attendants are under `Attendants`, which is neither, so
	# neither number moves and this line is their own.
	var staff: int = attendant_count()
	_set_check("the vendor and the teller are both standing", staff == 2)
	var staff_are_bodies := true
	var staff_dressed := 0
	if attendants != null:
		for child in attendants.get_children():
			if child is PonyScript:
				staff_are_bodies = false
			elif child is AttendantScript and bool(child.call("has_model")):
				staff_dressed += 1
	_set_check("no attendant is a Pony, so the beam has nothing to take and the herd "
		+ "has nobody extra in it", staff_are_bodies)
	_set_check("every attendant is dressed, or the assets are absent",
		staff_dressed == staff or not ponies_present)
	var staff_in_herd := false
	for pony in ponies:
		if pony.get_parent() == attendants:
			staff_in_herd = true
	_set_check("no attendant is in the spawned herd", not staff_in_herd)
	print("RANCH attendants=%d dressed=%d" % [staff, staff_dressed])
```

- [ ] **Step 11: Run everything, twice**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_attendant.gd -gtest=res://test/test_mane_pool.gd -gexit
bash tools/run_tests.sh
for scene in market_test region_test world_test collection_test ledger_test depot_test creation_test casino_test; do
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" >/dev/null 2>&1
  echo "$scene exit $?"
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | grep -E "RANCH attendants|RANCH_OK|RANCH_FAILED"
```
Expected: suite green, every gate exit 0, and the ranch printing BOTH `RANCH attendants=2 dressed=2` and `RANCH_OK ponies=49 props=60 assets=present` with those two numbers UNCHANGED. If `ponies=` or `props=` moved, the attendants are parented wrong; fix the parent, never the expected number.

- [ ] **Step 12: Look at them**

```bash
tools/bin/godot --path game world/ranch.tscn
```
There is somebody standing outside the Market facing the yard, and somebody standing under the Palace marquee facing the walk up. Neither can be beamed. Walk into one: she is solid. The crowd in the fields is wearing more than one mane.

- [ ] **Step 13: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'feat: manes from a curated pool, and two ponies behind counters\n\nReport 9, 2026-08-31: every pony has the same mane, because all three hidden\nstock records and the player all point at pokeypierce.glb. There are no spare\nmodels on disk (all 43 converted .glb belong to a named character), so the pool\nis six unicorn rigs that already ship, with pokeypierce at index 0 so every\nexisting save loads the pony it loaded before. The pool is script constants on\nStockPalette, beside IDS: PlayerLook.mane_style has been saved, restored and\nread by nothing since slice 1, and an index wants a list to index into.\ntest_mane_pool.gd puts every entry through the clip, tint and height checks the\nbase model passes; a model that fails is removed, not accommodated.\n\nPonyVisuals.build() takes an optional model path override, which is the whole\nsurface: four call sites (Pony, Player, the creation turntable, RaceRunner).\nPonyInstance.stock carries mane_style, defaulted to 0, so old saves are\nunchanged. Spawner sets the look before setup() now, because setup() is what\nbuilds the body and a tint can be re-applied where a mesh cannot. The creation\nscreen gains a Mane style row that rebuilds the turntable.\n\nReport 10: game/world/attendant.gd stands a dressed body at a counter, built\nexactly as RaceRunner builds a lane. Not a Pony, so the beam finds nothing and\nthe herd counts nobody extra; under an Attendants node that is neither Props nor\nBuildings, so RANCH_OK ponies=49 props=60 does not move; and the report prints\nRANCH attendants=2 with four checks saying so.\n\nBoth stand OUTSIDE their door, facing out. Building s new plinth puts an\ninterior floor 0.75 m above the terrain, so a body seated inside would be knee\ndeep in its own boards, and both counters are opened from the door anyway.\n' > /tmp/variety-commit.txt
git add game/world/attendant.gd game/world/attendant.gd.uid game/systems/stock_palette.gd \
  game/systems/pony_instance.gd game/actors/pony/pony_visuals.gd game/actors/pony/pony.gd \
  game/actors/player/player.gd game/ui/creation_screen.gd game/ui/creation_screen.tscn \
  game/world/spawner.gd game/world/race_runner.gd game/world/ranch.gd game/world/ranch.tscn \
  game/scenes/test/model_gallery.gd game/test/test_mane_pool.gd game/test/test_attendant.gd
git add -u game/test
git commit -F /tmp/variety-commit.txt
```

---

### Task 9: Gates, docs and the floor

**Files:**
- Modify: `tools/run_tests.sh`, `docs/testing.md`
- Test: the whole suite and every gate

**Interfaces:**
- Consumes: everything the previous eight tasks produced.
- Produces: `MIN_TESTS` raised to the suite's real count, and `docs/testing.md` describing the two new gate modes, the four new check groups and every count that moved.

- [ ] **Step 1: Run every gate and the whole suite, clean**

```bash
bash tools/run_tests.sh 2>&1 | tail -20
for scene in market_test region_test world_test collection_test ledger_test depot_test creation_test casino_test; do
  echo "--- $scene"
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" 2>&1 | grep -E "_OK|_FAILED"
  echo "exit ${PIPESTATUS[0]}"
done
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/model_gallery.tscn -- --mark 2>&1 | tail -2
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | grep -E "RANCH attendants|RANCH_OK|RANCH_FAILED"
```

Write down, verbatim, the number each gate prints. Expected shapes: `MARKET_OK checks=69`, `REGION_OK checks=47`, `WORLD_OK checks=32`, `COLLECTION_OK checks=72`, `LEDGER_OK checks=87`, `DEPOT_OK checks=72`, `CREATION_OK checks=<93 or whatever Task 1 measured>`, `CASINO_OK checks=<what Tasks 5 and 6 measured>`, `GALLERY_MARK_OK count=3`, `RANCH attendants=2 dressed=2`, `RANCH_OK ponies=49 props=60 assets=present`.

- [ ] **Step 2: Prove two runs of the collection gate are still byte identical**

`docs/testing.md` promises this and it is the check that would catch a resolver or a spawner change that made the world non deterministic:

```bash
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/collection_test.tscn > /tmp/collection-a.txt 2>&1
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/collection_test.tscn > /tmp/collection-b.txt 2>&1
diff /tmp/collection-a.txt /tmp/collection-b.txt && echo "identical"
```
Expected: `identical`. If it is not, the mane style draw has been added to a generator whose stream something else depends on; `draw_look()` pulls its fourth number AFTER the three colours precisely so the first three are unchanged, so check that ordering first.

- [ ] **Step 3: Raise the floor**

`MIN_TESTS` in `tools/run_tests.sh` stands at 1020. This plan adds roughly 90 tests across four new files plus additions to a dozen existing ones, so expect a number near 1110. Do not guess it; read the `Tests` line.

```bash
tests=$(bash tools/run_tests.sh 2>&1 | grep -oP '^Tests\s+\K[0-9]+' | tail -1)
echo "suite reports $tests"
sed -i "s/MIN_TESTS=\"\${FILLY_MIN_TESTS:-1020}\"/MIN_TESTS=\"\${FILLY_MIN_TESTS:-$tests}\"/" tools/run_tests.sh
grep -n 'MIN_TESTS=' tools/run_tests.sh
```

Then prove the floor still bites:

```bash
FILLY_MIN_TESTS=99999 bash tools/run_tests.sh; echo "expected 1, got $?"
```

- [ ] **Step 4: Write the docs**

Four edits to `docs/testing.md`.

**a.** In the Files table, add two rows in the style of the ones around them:

```
| `game/scenes/test/model_gallery.gd` | The model gallery, and its `--stock` and `--mark` rows (see below) |
| `game/world/interaction.gd` | The interact resolver the gates drive through `ranch.perform_interaction()` |
```

**b.** In "The creation gate" section, after the paragraph beginning "In one run, on the real ranch:", add:

```markdown
**It now also asks which way up the mark landed.** A headless run renders nothing,
so the gate cannot look at a flank; what it can do is ask the decal where the top
of the canvas points and whether the drawing is mirrored as seen from outside.
`CutieMark.image_up()` must point at the sky and `CutieMark.is_mirrored()` must be
false on both flanks, and the gate prints
`CREATION mark flank=<left|right> up=... right=... mirrored=...` for each so a
regression is a readable line rather than only a red. The bug this pins shipped in
slice 1: a Decal samples its albedo across its own local XZ plane with V zero at
the TOP of the image, and the flank basis passed plus Y as its local Z column,
which put image up at world down and, being left handed besides, mirrored the
drawing as well. A flip plus a mirror is a half turn, which is why a heart drawn
point down rendered point up.

**And a person still has to look at one.** The numbers above cannot say whether an
F on a pony's side reads as an F.
`tools/bin/godot --path game scenes/test/model_gallery.tscn -- --mark` stands three
copies of the base model wearing `MarkPaint.orientation_probe()`, turned to show
the left flank, the front and the right flank. What to look for is printed by the
scene itself: the F right way up on both flanks, its spine on the left as you look
at it, and the two flanks reading the SAME, because the right flank repeats the
drawing rather than mirroring it (a mark you cannot read from one side is not a
cutie mark). Headless it prints `GALLERY_MARK_OK count=3` and the exit code is the
verdict.
```

**c.** In "The casino gate" section, replace the sentence describing the race half with:

```markdown
and one whole race with one of the player's own ponies in it, entered off the form
guide rather than backed on a lane. The 2026-08-31 spec amendment made your pony
your bet: there is no lane argument on `ranch.start_race()` any more, and the gate
checks that the price the form guide showed for her is the same number
`RaceCard.decimal_odds(field, PLAYER_LANE)` settles at, and that a race she does
not win pays exactly zero.
```

and add to its "things worth knowing" list:

```markdown
**Its menu seam checks moved with the flow.** They used to drive
`CasinoMenu.Tab.GAMES` and `game_requested`; the lobby is one screen of rows now
and emits `room_requested`, so that is what they drive. The point of those checks
is unchanged: a swap between a menu's own row order and the enum behind it must not
be able to silently open the wrong room, in the same way the wheel's felt tab order
must not be able to mispay a colour bet at number odds.
```

**d.** In the section describing `world/ranch.tscn`'s own report (the paragraph naming `RANCH_OK ponies=49 props=60 assets=present`), add:

```markdown
**`props` and `ponies` did NOT move when the Market got a vendor and the Palace got
a teller, and that is deliberate.** Both are `Attendant` nodes: `PonyVisuals.build`
plus `StockTint`, exactly what a race lane's runner is, standing under a new
`Attendants` node that is neither `Props` nor `Buildings`. `props` counts
`Props.expected_count()` plus the `Buildings` children and `ponies` counts
`spawner.get_spawned()`, which only ever holds `Pony` nodes, so neither can see
them. The report prints its own `RANCH attendants=2 dressed=2` line and carries
four checks: that both are standing, that neither is a `Pony` (which is exactly
what `MagicBeam._is_grabbable()` tests, so it is also the claim that the beam has
nothing there to take), that both are dressed unless the assets are absent, and
that neither is in the spawned herd.
```

- [ ] **Step 5: Sweep for the copy rule across everything this branch added**

```bash
git diff master...HEAD --name-only | grep -E '\.(gd|md)$' | while read -r f; do
  [ -f "$f" ] || continue
  git diff master...HEAD -- "$f" | grep -n '^+' | grep -E '\-\-|—' \
    | grep -v '^\+.*# ---' | grep -v '^\+.*--headless' | grep -v '^\+.*--audio-driver' \
    | grep -v '^\+.*--path' | grep -v '^\+.*--stock' | grep -v '^\+.*--mark' \
    | grep -v '^\+.*--import' | grep -v '^\+.*--check-only' | grep -v '^\+.*--script' \
    | sed "s|^|$f:|"
done
```
Expected: no output. Anything printed is a new em dash or double hyphen outside a banner or a CLI flag; fix it. Then the same sweep at run time, which catches a string built by interpolation rather than written as a literal:

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gdir=res://test -gexit 2>&1 | grep -E '\-\-|—' | grep -v 'gut_cmdln' || echo "clean"
```

- [ ] **Step 6: Final full run**

```bash
bash tools/run_tests.sh
for scene in market_test region_test world_test collection_test ledger_test depot_test creation_test casino_test; do
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" >/dev/null 2>&1
  echo "$scene exit $?"
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
bash tools/prove_atomic_save.sh
```
Expected: everything green, every gate exit 0, `RANCH_OK ponies=49 props=60 assets=present`, `ATOMIC_SAVE_PROOF_OK`.

- [ ] **Step 7: Commit**

```bash
printf 'docs: the playtest response, its gates and its floor\n\nEvery count this branch moved, written down where it is checked. The creation\ngate gained four mark orientation checks and prints the flank frame it measured;\nthe casino gate settles a race entered off the form guide rather than backed on\na lane, and its menu seam checks follow the lobby; the model gallery grew a\n--mark row that is the human half of the mark fix; and the ranch report prints\nRANCH attendants=2 beside ponies=49 props=60, neither of which moved, with four\nchecks saying why they could not.\n\nMIN_TESTS raised to the suite s reported count.\n' > /tmp/docs-commit.txt
git add tools/run_tests.sh docs/testing.md
git commit -F /tmp/docs-commit.txt
```

---

## Self review

Run against the owner's ten item list and the amended spec, with fresh eyes.

**1. Coverage.**

| Item | Task | Where |
|---|---|---|
| 1. Mark upside down | 1 | `_flank_transform()`'s local Z column, plus `image_up`/`is_mirrored`/`image_point_to_world`, five unit tests, four creation gate checks, and the `--mark` gallery row. The mirrored versus repeated decision is documented in `cutie_mark.gd` and asserted by `test_the_two_flanks_read_the_same_way_round_from_outside`. |
| 2. Flaky E | 2 | `game/world/interaction.gd`, one prioritized resolver, 13 unit tests covering the order, both overlaps and determinism under reordering; a persistent HUD prompt naming the verb; five handlers and six latches deleted. |
| 3. Palace z fighting | 3 | `Building.FLOOR_TOP` / `SKIRT_DEPTH`, and `test_no_building_on_the_shipped_map_can_fight_the_ground` walks every building in `ranch.tscn` at its own four corners, which is the "verify no other building shows it" half. |
| 4. Marquee | 3 | Board plus trim plus two fitted `Label3D`s with `width` and `AUTOWRAP_WORD` actually set, all sized from the live Palace through `Strip.mount_marquee()`; tests for narrower than the building, below the ridge, and in front of the wall. Copy is dash free and split headline plus sponsor. |
| 5. Menu polish and device hints | 4 | `MenuStyle` plus `InputDevice`; six menus and the HUD hint card moved; XOR asserted by `test_the_footer_shows_one_scheme_and_never_both`. Draw and emit untouched. |
| 6. Casino usability | 5 | One lobby screen, six explained rows, cage explainer, per table chips line, keys line and boxed result block. UI and copy only; injected Callables unchanged. |
| 7. Bits onboarding | 7 | One screen welcome naming catch, pen, gems, Market plus balance and quota; HUD checklist off `RequestBoard.tutorial_rows()`; Market prompt names the verb. |
| 8. Racing redesign | 6 | ENTER becomes the form guide with live odds; BET removed; `start_race()` loses `lane`; settle at `PLAYER_LANE`; `RaceCard` untouched; gate seam moved. |
| 9. Mane variety | 8 | `StockPalette.MANE_STYLES`, `PonyVisuals.build()` override, all four call sites, `PlayerLook.mane_style` finally read, creation row, save key. Compendium untouched: the pool adds no record and `PonyRegistry._hidden` is not touched. |
| 10. Vendor and teller | 8 | `Attendant`, `Attendants` node, pinned looks, four report checks and a `RANCH attendants=` line; `ponies=49 props=60` explicitly held. |

Spec side: the amended casino paragraph is implemented in full by Task 6 (form guide of every penned pony, live odds, no side bets, pays her odds or zero), the takeout is unchanged, and nothing in this plan touches the story, the ranks, the town or the Factory, which are later slices.

**2. Placeholder scan.** Every code step carries real GDScript. Three places name a decision rather than a literal and each states the exact procedure and the exact fallback: the donor pool's swap list (`trixie`, `rarity`, `vinylscratch`, `shiningarmor`, in that order, only on a named failing check), the gate check counts (read from the gate's own printed output in the task that moves them, never guessed), and `MIN_TESTS` (read from the suite's `Tests` line by the `sed` command given). Two steps say "the rest of the shipped function is unchanged" and both name exactly which lines change and to what.

**3. Type and name consistency, checked across tasks.**
- `Interaction.prompt_for(action, key)` is called in Task 2 with `INTERACT_KEY` and in Task 4 with `InputDeviceScript.hint(&"interact")`; Task 4 deletes the constant it replaces.
- `InputDevice.hint(action: StringName) -> String` is used by `MenuStyle.footer()`, by `TableMenu.keys_line()` and by `ranch._update_interaction()`; one signature everywhere.
- `MenuStyle.footer_tabs_and_rows(verb, leave)` is two arguments at every call site, including the tables' and the lobby's.
- `TableMenu.chips_line()/keys_line()/result_block()` are added in Task 5 and consumed by `RaceMenu.drawn_lines()` in Task 6; `first_row_line_index()` is overridden consistently as `2 + result_block().size()` in `RaceMenu` and `2 + result_block().size() + stake_lines().size()` in the three tables, matching what each actually prints.
- `race_requested(uid: StringName, stake: int)` matches `ranch._on_race_requested(uid, stake)` and `start_race(uid, stake)`; the casino gate and `test_ranch_race.gd` are both moved in the same task.
- `race_entrants()` rows carry `uid`, `name`, `happiness`, `odds`, `chance`; `RaceMenu.form_lines()` reads `name`, `odds`, `happiness` and `confirm()` reads `uid`; the test fixture supplies all five.
- `StockPalette.mane_style_path(index) -> String` is called by `Pony._base_model_path()`, `Player._build_visuals()`, `CreationScreen._build_model()`, `RaceRunner.dress()` and `Attendant.dress()`; `draw_look()` writes the key `mane_style` and `PonyInstance.from_dict()` reads exactly that key.
- `PonyVisuals.build(data, model_path_override := "")` keeps its one argument form working, which is what every named pony and every existing call site uses.
- `HUD.set_prompt/clear_prompt/prompt_text` (Task 2) and `HUD.set_tasks/task_lines/TASK_TITLE` (Task 7) are distinct names on distinct nodes and are asserted not to overwrite each other.
- `RequestBoard.TUTORIAL_IDS` is read by `seed_tutorial()`, by `tutorial_rows()` and by the test that proves the seeder writes exactly those ids.
