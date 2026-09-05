# R1 UI Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Filly Rancher one real Godot `Theme`, full mouse support on every screen without losing a single keyboard binding, a full-screen industry-standard character creator that opens before any frame of raw world, a title screen, a crafted letter panel with rewritten copy read at the mailbox, and the parked sound-mix knob turns.

**Architecture:** `game/ui/menu_style.gd` stays the single source of truth for the look; a committed, re-runnable generator (`game/scripts/make_theme.gd`, driven by `tools/make_theme.sh`) reads its constants and writes `game/ui/theme/filly_theme.tres`, which `project.godot` installs as the project-wide GUI theme. A new static kit, `game/ui/mouse_rows.gd`, arms the row `PanelContainer`s that every menu already builds with hover and click handlers, so thirteen hand-drawn screens gain the mouse through one recipe instead of thirteen inventions. Keyboard stays exactly as it is: every control the mouse kit adds sets `focus_mode = FOCUS_NONE`, so the existing `_unhandled_input()` cursor model is never competed with. Boot order changes through a new static latch (`game/world/boot_intent.gd`) that a new title screen sets and `ranch.gd` consumes.

**Tech Stack:** Godot 4.5.2, GDScript. Engine binary `tools/bin/godot`. Project dir `game/`. Tests: GUT 9.5.0 via `bash tools/run_tests.sh`. Gates: `game/scenes/test/*.tscn`. Sound pipeline: `tools/sound_manifest.txt` + `tools/fetch_sounds.sh`.

**Spec:** `docs/superpowers/specs/2026-09-04-presentation-redesign-design.md` (sections 1, 2, 4, 6 final bullet, 7, 8, 10).

## Global Constraints

- `game/systems/` is READ-ONLY for this slice, with exactly two exemptions: `settings.gd` default values (Task 12, plus any new UI setting), and nothing else. THE MATH DOES NOT CHANGE. The fifteen authored letters live in `game/data/story/*.tres` (data, not `systems/`) and are rewritten in Task 11; `game/systems/story_library.gd` itself is not edited.
- NO PONY EVER DIES. No rigging the casino. No new realistic pony vocalizations; `Sound.GAG_ID` stays exactly as shipped and the no-pony-voice corpus sweep and its gag exemption are untouchable.
- Keyboard must remain FULLY functional on every screen. Mouse is ADDED, never traded. Footer key hints stay. Every `Control` this slice adds sets `focus_mode = Control.FOCUS_NONE` unless a task says otherwise, so Godot's own focus walk never fights the existing `_unhandled_input()` cursors.
- No em dashes anywhere: code, comments, player-facing copy, docs. The house dash is `" -- "`. Player-facing letter copy carries no dash of either kind at all (`game/test/test_story_corpus.gd` enforces it).
- `.gd.uid` sidecars ARE committed. `.tscn.uid` files are NOT. If Godot writes a `.tres.uid`, do not commit it either.
- Inside a `const` declaration use a plain array literal, never `PackedStringArray(...)` (parse bug on this build). `.tres` resource files are unaffected and keep `PackedStringArray(...)`.
- A bare autoload identifier (`Sound.play(...)`) fails `tools/run_tests.sh`'s check-only parse sweep. UI scripts reach the Sound autoload only through the existing `MenuStyle` forwarders (`tick_move`, `tick_confirm`, `tick_back`, `tick_open`, `tick_denied`, `tick_page`) or the `get_node_or_null(^"/root/Sound")` shadow pattern already in `table_menu.gd`. `game/ui/menu_style.gd` is the ONLY file under `game/ui/` allowed to name a sound id; `game/test/test_menu_sound.gd` scans for violations.
- No random number generator may live under `game/ui/` (`test_menu_sound.gd` scans for `RandomNumberGenerator`, `randi(`, `randf(`, `randi_range(`, `randf_range(`, `randomize()`, `.pick_random()`, `.shuffle()`).
- Every gate and test invocation must carry `FILLY_TEST_SAVE_DIR=<tmpdir>` (the interface slice R0 ships: `SaveIO` redirects its save directory at static init when that env var is set), so a sweep never touches the owner's live `user://saves`.
- Gates run `--headless`. The sound gate NEVER runs under xvfb. The gallery gate runs under xvfb with `--props`.
- The suite is green at every commit. `MIN_TESTS` in `tools/run_tests.sh` is bumped to the exact new count at slice end (Task 12) and proved in both directions with `FILLY_MIN_TESTS`.
- GUT idioms: every test asserts something (a zero-assert test is reported "Risky"); sweep-style tests carry a controller anchor such as `assert_gt(checked, 0, "...")`; expected `push_error`s are wrapped in `assert_push_error`; any node a test instantiates detached is freed by that test (orphan discipline).
- Commit style: lowercase imperative, e.g. `feat: the menus learn the mouse`.

**On numbers in this plan.** Prose says "the current floor" because slice R0 may bump `MIN_TESTS` before this slice starts. Commands carry the concrete number that was true when this plan was written (`1412`) and every such command is marked `RECONCILE:` so the implementer checks the live value in `tools/run_tests.sh` first. Gate check counts (`STORY_OK checks=55`, `SOUND_OK ids=37`, `CREATION_OK checks=93`, `GALLERY_OK count=35`, `RANCH_OK ponies=49 props=111`) are likewise the values in `docs/testing.md` today.

**Batching note for the dispatcher.** Tasks 3 and 4 are the same shape (both apply the identical `MouseRows` row-arming recipe to a family of hand-drawn list screens) and can go to one implementer in a single dispatch. Every other task is its own dispatch.

---

## File structure

| Path | Created / Modified | Responsibility |
|---|---|---|
| `game/ui/menu_style.gd` | Modify | Still the single source of the look. Gains the paper/wood palette and the StyleBox factories the generator reads. |
| `game/scripts/make_theme.gd` | Create | The generator. Reads `MenuStyle`, writes the Theme resource. Never loaded by the game. |
| `tools/make_theme.sh` | Create | Shell entry point for the generator, mirroring `tools/prove_atomic_save.sh`. |
| `game/ui/theme/filly_theme.tres` | Create | The generated Theme. Installed project-wide in `project.godot`. |
| `game/ui/mouse_rows.gd` | Create | The mouse kit: arm a row, build an armed row, build a close button, hit-test a list of rects. |
| `game/ui/swatch_grid.gd` | Create | The creation screen's swatch / card grid widget. |
| `game/ui/creation_backdrop.gd` | Create | The opaque drawn sky-and-clouds stage behind character creation. |
| `game/ui/title_screen.gd` / `.tscn` | Create | The main menu: New game, Continue, Settings, Quit. |
| `game/world/boot_intent.gd` | Create | The static latch the title screen sets and `ranch.gd` consumes. |
| `game/ui/table_menu.gd` and the four tables | Modify | Rows and stages take the mouse. |
| `game/ui/market_menu.gd`, `depot_menu.gd`, `build_menu.gd`, `casino_menu.gd` | Modify | Same. |
| `game/ui/pause_menu.gd` | Modify | Mouse, `Save game` / `Load game`, `Saddlebag copies`. |
| `game/ui/letter_panel.gd` / `.tscn` | Modify | Stationery restyle, mouse close. |
| `game/ui/hud.gd` | Modify | Card hides under overlays; the toast queue keeps up. |
| `game/ui/creation_screen.gd` / `.tscn` | Modify | Rebuilt full-screen. |
| `game/world/ranch.gd` | Modify | Boot veil, load handler, mailbox reading, HUD overlay calls. |
| `game/data/story/*.tres` | Modify | The fifteen rewritten letters. |
| `game/systems/settings.gd` | Modify | The Ambient default only. |
| `tools/sound_manifest.txt` | Modify | The knob turns. |

---

### Task 1: The Theme, generated from menu_style.gd

**Files:**
- Modify: `game/ui/menu_style.gd:130` (insert a new section immediately above the `## A fourth size, for the tile descriptions` block, i.e. before `const SUBTITLE_SIZE`), and `game/ui/menu_style.gd:246` (immediately above the `# --- the menu tick kit` banner) for the factories
- Create: `game/scripts/make_theme.gd`
- Create: `tools/make_theme.sh`
- Create: `game/ui/theme/filly_theme.tres` (generated, committed)
- Modify: `game/project.godot` (add a `[gui]` section)
- Test: `game/test/test_theme.gd`

**Interfaces:**
- Consumes: nothing (first task).
- Produces, on `MenuStyle` (all static, preloaded as `res://ui/menu_style.gd`):
  - `const THEME_PATH := "res://ui/theme/filly_theme.tres"`
  - `const COLOR_PAPER: Color`, `COLOR_PAPER_EDGE: Color`, `COLOR_INK: Color`, `COLOR_WOOD: Color`, `COLOR_WOOD_LIT: Color`, `COLOR_HOVER_BG: Color`, `COLOR_HOVER_BORDER: Color`
  - `const BUTTON_RADIUS: int`, `const FRAME_WIDTH: int`
  - `static func button_box(state: StringName) -> StyleBoxFlat` (states `&"normal"`, `&"hover"`, `&"pressed"`, `&"focus"`, `&"disabled"`)
  - `static func tab_box(state: StringName) -> StyleBoxFlat` (states `&"selected"`, `&"unselected"`, `&"hovered"`)
  - `static func field_box(focused: bool) -> StyleBoxFlat`
  - `static func slider_box(filled: bool) -> StyleBoxFlat`
  - `static func paper_box() -> StyleBoxFlat`
  - `static func frame_box() -> StyleBoxFlat`
  - `static func row_box_hover() -> StyleBoxFlat`
  - `static func theme_resource() -> Theme` (cached `load()` of `THEME_PATH`, or `null` if it is absent)
- Produces, as a file: `res://ui/theme/filly_theme.tres`, installed as `gui/theme/custom` so every `Control` in every scene inherits it.

- [ ] **Step 1: Write the failing test**

Create `game/test/test_theme.gd`:

```gdscript
extends GutTest
## THE THEME IS GENERATED, AND THIS IS WHAT KEEPS IT HONEST. game/scripts/make_theme.gd
## reads game/ui/menu_style.gd and writes game/ui/theme/filly_theme.tres. Two files that
## agree today and drift tomorrow is the exact failure this project already had once: ten
## .tscn files each carrying their own copy of one StyleBoxFlat. So the resource on disk is
## compared against the constants it was generated from, every run.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const PaperPaintScript := preload("res://ui/paper_paint.gd")


func test_the_theme_resource_is_on_disk_and_loads() -> void:
	assert_true(ResourceLoader.exists(MenuStyleScript.THEME_PATH),
		"run bash tools/make_theme.sh")
	var theme: Theme = MenuStyleScript.theme_resource()
	assert_not_null(theme, "the generated theme has to load as a Theme")


func test_the_project_installs_the_theme_for_every_control() -> void:
	assert_eq(String(ProjectSettings.get_setting("gui/theme/custom", "")),
		MenuStyleScript.THEME_PATH,
		"project.godot must install the theme, or nothing inherits it")


func test_every_button_state_is_styled_and_they_are_not_the_same_box() -> void:
	var theme: Theme = MenuStyleScript.theme_resource()
	var seen: Array[Color] = []
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var box: StyleBox = theme.get_stylebox(state, &"Button")
		assert_true(box is StyleBoxFlat, "Button/%s is not a StyleBoxFlat" % state)
		seen.append((box as StyleBoxFlat).bg_color)
	assert_eq(seen.size(), 4)
	for i in range(1, seen.size()):
		assert_ne(seen[i], seen[0], "a hover state that looks like normal is not a state")


func test_the_slider_and_the_tab_bar_are_styled() -> void:
	var theme: Theme = MenuStyleScript.theme_resource()
	for pair: Array in [["slider", "HSlider"], ["grabber_area", "HSlider"],
			["tab_selected", "TabBar"], ["tab_unselected", "TabBar"],
			["tab_hovered", "TabBar"]]:
		assert_true(theme.get_stylebox(StringName(pair[0]), StringName(pair[1]))
			is StyleBoxFlat, "%s/%s is unstyled" % [pair[1], pair[0]])


func test_the_panel_in_the_theme_is_the_panel_menu_style_hands_out() -> void:
	var theme: Theme = MenuStyleScript.theme_resource()
	var box: StyleBoxFlat = theme.get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	assert_not_null(box)
	assert_eq(box.bg_color, MenuStyleScript.panel_style().bg_color,
		"the theme and menu_style.gd have drifted; re-run bash tools/make_theme.sh")
	assert_eq(box.border_color, MenuStyleScript.panel_style().border_color)


func test_the_row_boxes_ride_along_so_a_drawn_row_and_a_themed_row_match() -> void:
	var theme: Theme = MenuStyleScript.theme_resource()
	for pair: Array in [[&"FillyRow", MenuStyleScript.row_box(false)],
			[&"FillyRowSelected", MenuStyleScript.row_box(true)],
			[&"FillyRowHover", MenuStyleScript.row_box_hover()]]:
		var box: StyleBoxFlat = theme.get_stylebox(&"panel", pair[0]) as StyleBoxFlat
		assert_not_null(box, "%s is missing from the theme" % pair[0])
		assert_eq(box.bg_color, (pair[1] as StyleBoxFlat).bg_color, String(pair[0]))


func test_the_paper_menu_style_names_is_the_paper_the_stationery_kit_draws() -> void:
	# ONE PAPER, TWO READERS. paper_paint.gd draws letters by hand and the theme styles the
	# panel behind them; if these two ever disagree the letter sits on a sheet of a slightly
	# different white and every screenshot shows it.
	assert_eq(MenuStyleScript.COLOR_PAPER, PaperPaintScript.PAPER)
	assert_eq(MenuStyleScript.COLOR_PAPER_EDGE, PaperPaintScript.PAPER_EDGE)
	assert_eq(MenuStyleScript.COLOR_INK, PaperPaintScript.INK)


func test_the_wooden_frame_is_a_real_border_and_not_a_hairline() -> void:
	var frame: StyleBoxFlat = MenuStyleScript.frame_box()
	assert_eq(frame.border_width_left, MenuStyleScript.FRAME_WIDTH)
	assert_eq(frame.border_color, MenuStyleScript.COLOR_WOOD_LIT)
	assert_eq(frame.bg_color, MenuStyleScript.COLOR_WOOD)
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_theme.gd -gexit
```
Expected: failures naming `THEME_PATH` / `theme_resource` as unknown identifiers on `MenuStyle`.

- [ ] **Step 3: Add the palette to menu_style.gd**

Insert immediately above `## A fourth size, for the tile descriptions and the COLOR_DIM second lines the casino's` (currently `game/ui/menu_style.gd:121`):

```gdscript
## THE PAPER AND THE WOOD. The palette above is the dark navy panel this game has always
## drawn; these are the two materials the redesign adds, and they are the ones the generated
## Theme is built out of. The paper numbers are game/ui/paper_paint.gd's own, copied rather
## than imported so a const can hold them, and game/test/test_theme.gd asserts the two
## copies agree so they cannot drift apart in silence.
const COLOR_PAPER := Color(0.96, 0.94, 0.88, 0.97)
const COLOR_PAPER_EDGE := Color(0.72, 0.68, 0.58, 0.90)
const COLOR_INK := Color(0.13, 0.12, 0.15, 1.0)

## The frame around a panel: a dark stained board with a lit edge, which is what reads as
## wood at this size without a texture anywhere near it.
const COLOR_WOOD := Color(0.31, 0.20, 0.13, 1.0)
const COLOR_WOOD_LIT := Color(0.49, 0.33, 0.20, 1.0)

## HOVER IS ITS OWN STATE AND IT IS NOT SELECTION. A pointer resting on a row has to say
## "this is what you would take" without claiming "this is what is taken": weaker than
## ROW_SELECTED_BG, stronger than ROW_IDLE_BG, and the same hue as both.
const COLOR_HOVER_BG := Color(1.0, 0.86, 0.55, 0.09)
const COLOR_HOVER_BORDER := Color(1.0, 0.86, 0.55, 0.40)

## Where the generated Theme lives. Written by game/scripts/make_theme.gd, installed by
## game/project.godot's gui/theme/custom, read back by theme_resource() below.
const THEME_PATH := "res://ui/theme/filly_theme.tres"

const BUTTON_RADIUS := 8
const FRAME_WIDTH := 3
```

- [ ] **Step 4: Add the StyleBox factories to menu_style.gd**

Insert immediately above the `# --- the menu tick kit` banner (currently `game/ui/menu_style.gd:248`):

```gdscript
# --- the boxes the generated Theme is made of ---------------------------------------------
#
# ONE SOURCE, TWO CONSUMERS. Every function below is called twice: once by
# game/scripts/make_theme.gd when it writes game/ui/theme/filly_theme.tres, and once by
# game/test/test_theme.gd when it checks that the file on disk still says what these say.
# Nothing here caches, because each of them is called a handful of times per build and a
# cached StyleBox handed to a Theme and then to a Control is a box three owners can edit.


static func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 7.0
	box.content_margin_bottom = 7.0
	return box


## A BUTTON, IN FIVE STATES, AND THEY LOOK DIFFERENT ON PURPOSE. An unknown state name
## answers normal rather than null: a Theme entry that came back null would style nothing
## and say nothing about why.
static func button_box(state: StringName) -> StyleBoxFlat:
	match state:
		&"hover":
			return _box(COLOR_HOVER_BG, COLOR_HOVER_BORDER, 2, BUTTON_RADIUS)
		&"pressed":
			return _box(ROW_SELECTED_BG, ROW_SELECTED_BORDER, 2, BUTTON_RADIUS)
		&"focus":
			return _box(Color(0, 0, 0, 0), COLOR_TAB_ON, 2, BUTTON_RADIUS)
		&"disabled":
			return _box(Color(1.0, 1.0, 1.0, 0.02), Color(1.0, 1.0, 1.0, 0.06), 1,
				BUTTON_RADIUS)
	return _box(ROW_IDLE_BG, ROW_IDLE_BORDER, 1, BUTTON_RADIUS)


static func tab_box(state: StringName) -> StyleBoxFlat:
	match state:
		&"selected":
			return _box(ROW_SELECTED_BG, ROW_SELECTED_BORDER, 2, BUTTON_RADIUS)
		&"hovered":
			return _box(COLOR_HOVER_BG, COLOR_HOVER_BORDER, 2, BUTTON_RADIUS)
	return _box(Color(0, 0, 0, 0), COLOR_TAB_OFF, 1, BUTTON_RADIUS)


## THE NAME BOX. Ink on paper, because it is the one control in this game somebody types
## into and dark text on a light field is what a person expects to type into.
static func field_box(focused: bool) -> StyleBoxFlat:
	return _box(COLOR_PAPER, COLOR_TAB_ON if focused else COLOR_PAPER_EDGE,
		2 if focused else 1, 6)


static func slider_box(filled: bool) -> StyleBoxFlat:
	var box := _box(COLOR_VALUE if filled else ROW_IDLE_BG,
		ROW_SELECTED_BORDER if filled else ROW_IDLE_BORDER, 1, 4)
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


## WARM PAPER, FOR THE PANELS THAT ARE PAGES: the letter, the statement, the house rules.
static func paper_box() -> StyleBoxFlat:
	var box := _box(COLOR_PAPER, COLOR_PAPER_EDGE, 1, 10)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	box.shadow_size = 8
	box.shadow_offset = Vector2(3.0, 4.0)
	return box


## THE WOODEN FRAME. Used around the turntable and the cutie mark canvas, which are the two
## things on screen that are pictures rather than text.
static func frame_box() -> StyleBoxFlat:
	var box := _box(COLOR_WOOD, COLOR_WOOD_LIT, FRAME_WIDTH, 10)
	box.content_margin_left = float(FRAME_WIDTH) * 2.0
	box.content_margin_right = float(FRAME_WIDTH) * 2.0
	box.content_margin_top = float(FRAME_WIDTH) * 2.0
	box.content_margin_bottom = float(FRAME_WIDTH) * 2.0
	return box


## THE THIRD ROW STATE. row_box() answers idle and selected; a pointer needs a third, and it
## is built here rather than inside row_box() so that function's two cached boxes stay two.
static func row_box_hover() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_HOVER_BG
	box.border_color = COLOR_HOVER_BORDER
	box.set_border_width_all(0)
	box.border_width_left = 2
	box.set_corner_radius_all(ROW_RADIUS)
	box.content_margin_left = float(ROW_INSET_LEFT)
	box.content_margin_top = 2.0
	box.content_margin_right = 6.0
	box.content_margin_bottom = 2.0
	return box


static var _theme: Theme = null


## The generated Theme, or NULL on a checkout where it has not been generated yet. Null is a
## supported answer for the reason PonyRegistry.by_id()'s is: a missing resource must not
## take a boot down, and project.godot installs this file itself, so a screen that asks for
## it here is asking only so that it can style something by hand.
static func theme_resource() -> Theme:
	if _theme != null:
		return _theme
	if not ResourceLoader.exists(THEME_PATH):
		return null
	_theme = load(THEME_PATH) as Theme
	return _theme
```

- [ ] **Step 5: Write the generator**

Create `game/scripts/make_theme.gd`:

```gdscript
extends SceneTree
## THE THEME IS GENERATED AND NEVER HAND EDITED. Driven by `bash tools/make_theme.sh`; not
## part of the game and never loaded by it, exactly like game/scripts/prove_atomic_save.gd.
##
## WHY A GENERATOR RATHER THAN A CHECKED IN .tres SOMEBODY EDITS. game/ui/menu_style.gd has
## been this project's style layer since the menu polish pass, every drawn panel in the game
## reads its constants directly, and a Theme resource maintained beside it by hand would be
## a second palette that agrees on the day it is written and on no day after. So the file on
## disk is output: edit menu_style.gd, run this, commit both.
##
## THE OUTPUT IS COMMITTED even though it is generated, because game/project.godot installs
## it as gui/theme/custom and a checkout that had not run this script would boot unstyled.

const MenuStyleScript := preload("res://ui/menu_style.gd")

const OUT_DIR := "res://ui/theme"
const OUT_PATH := "res://ui/theme/filly_theme.tres"


func _init() -> void:
	var theme := Theme.new()
	theme.default_font_size = MenuStyleScript.ROW_SIZE

	theme.set_stylebox(&"panel", &"PanelContainer", MenuStyleScript.panel_style())

	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		theme.set_stylebox(state, &"Button", MenuStyleScript.button_box(state))
	theme.set_color(&"font_color", &"Button", MenuStyleScript.COLOR_NAME)
	theme.set_color(&"font_hover_color", &"Button", MenuStyleScript.COLOR_TITLE)
	theme.set_color(&"font_pressed_color", &"Button", MenuStyleScript.COLOR_VALUE)
	theme.set_color(&"font_disabled_color", &"Button", MenuStyleScript.COLOR_TAB_OFF)
	theme.set_color(&"font_outline_color", &"Button", MenuStyleScript.OUTLINE_COLOR)
	theme.set_constant(&"outline_size", &"Button", MenuStyleScript.OUTLINE_SIZE)
	theme.set_font_size(&"font_size", &"Button", MenuStyleScript.ROW_SIZE)

	theme.set_color(&"font_color", &"Label", MenuStyleScript.COLOR_NAME)
	theme.set_color(&"font_outline_color", &"Label", MenuStyleScript.OUTLINE_COLOR)
	theme.set_constant(&"outline_size", &"Label", MenuStyleScript.OUTLINE_SIZE)

	theme.set_stylebox(&"normal", &"LineEdit", MenuStyleScript.field_box(false))
	theme.set_stylebox(&"focus", &"LineEdit", MenuStyleScript.field_box(true))
	theme.set_color(&"font_color", &"LineEdit", MenuStyleScript.COLOR_INK)
	theme.set_color(&"caret_color", &"LineEdit", MenuStyleScript.COLOR_INK)
	theme.set_font_size(&"font_size", &"LineEdit", MenuStyleScript.ROW_SIZE)

	theme.set_stylebox(&"slider", &"HSlider", MenuStyleScript.slider_box(false))
	theme.set_stylebox(&"grabber_area", &"HSlider", MenuStyleScript.slider_box(true))
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider",
		MenuStyleScript.slider_box(true))

	theme.set_stylebox(&"tab_selected", &"TabBar", MenuStyleScript.tab_box(&"selected"))
	theme.set_stylebox(&"tab_unselected", &"TabBar", MenuStyleScript.tab_box(&"unselected"))
	theme.set_stylebox(&"tab_hovered", &"TabBar", MenuStyleScript.tab_box(&"hovered"))
	theme.set_color(&"font_selected_color", &"TabBar", MenuStyleScript.COLOR_TAB_ON)
	theme.set_color(&"font_unselected_color", &"TabBar", MenuStyleScript.COLOR_TAB_OFF)
	theme.set_color(&"font_hovered_color", &"TabBar", MenuStyleScript.COLOR_TITLE)

	# THE THREE ROW BOXES AND THE TWO MATERIALS, under type names nothing in Godot owns, so a
	# menu can ask the Theme for the same box game/ui/menu_style.gd hands its drawn rows.
	theme.set_stylebox(&"panel", &"FillyRow", MenuStyleScript.row_box(false))
	theme.set_stylebox(&"panel", &"FillyRowSelected", MenuStyleScript.row_box(true))
	theme.set_stylebox(&"panel", &"FillyRowHover", MenuStyleScript.row_box_hover())
	theme.set_stylebox(&"panel", &"FillyPaper", MenuStyleScript.paper_box())
	theme.set_stylebox(&"panel", &"FillyFrame", MenuStyleScript.frame_box())

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUT_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var err: int = ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		push_error("make_theme: could not write %s (%s)" % [OUT_PATH, error_string(err)])
		quit(1)
		return
	print("THEME_WRITTEN %s" % OUT_PATH)
	quit(0)
```

- [ ] **Step 6: Write the shell entry point**

Create `tools/make_theme.sh`:

```bash
#!/usr/bin/env bash
# Regenerate game/ui/theme/filly_theme.tres from game/ui/menu_style.gd's constants.
# The Theme is OUTPUT: edit menu_style.gd, run this, commit both files.
# --audio-driver Dummy on principle; every scripted invocation of this game is silent.
set -uo pipefail
cd "$(dirname "$0")/.."

tools/bin/godot --headless --audio-driver Dummy --path game -s scripts/make_theme.gd
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: the theme generator exited $rc" >&2
  exit 1
fi
echo "OK: game/ui/theme/filly_theme.tres regenerated"
```

Then `chmod +x tools/make_theme.sh`.

- [ ] **Step 7: Generate the theme and install it**

```bash
cd /home/admin/Documents/filly-rancher
bash tools/make_theme.sh
```
Expected: `THEME_WRITTEN res://ui/theme/filly_theme.tres` then `OK: game/ui/theme/filly_theme.tres regenerated`.

Then add to `game/project.godot`, as a new section placed alphabetically after `[global_group]` (or after `[display]` if there is no `[global_group]`):

```
[gui]

theme/custom="res://ui/theme/filly_theme.tres"
```

- [ ] **Step 8: Run the theme test to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_theme.gd -gexit
```
Expected: `8/8 passed.` and `---- All tests passed! ----`.

- [ ] **Step 9: Prove the generator is re-runnable and idempotent**

```bash
cd /home/admin/Documents/filly-rancher
cp game/ui/theme/filly_theme.tres /tmp/theme_a.tres
bash tools/make_theme.sh
diff -q /tmp/theme_a.tres game/ui/theme/filly_theme.tres && echo "IDEMPOTENT"
```
Expected: `IDEMPOTENT`. If the files differ only in a `uid=` header line, that is acceptable; record it in the commit message. Any other difference means a factory in `menu_style.gd` is returning something unstable and must be fixed before continuing.

- [ ] **Step 10: Run the full suite (the theme now styles every Control in every scene)**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
```
Expected: `---- All tests passed! ----`, `Scripts` equal to the number of `game/test/test_*.gd` files, and a `Tests` count at or above the current floor. RECONCILE: the floor was `1412` when this plan was written; read the live `MIN_TESTS` out of `tools/run_tests.sh` before judging.

If a gate-adjacent unit test now fails on geometry (a row height, a focus rect), the cause is the theme's content margins reaching a control that used to have none. Fix it by narrowing the offending Theme entry, never by removing the theme.

- [ ] **Step 11: Run the ranch and the story gates, which draw the most Controls**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/story_test.tscn
```
Expected: `RANCH_OK ponies=49 props=111 assets=present` and `STORY_OK checks=55`. RECONCILE against `docs/testing.md` for the live numbers.

- [ ] **Step 12: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/ui/menu_style.gd game/scripts/make_theme.gd game/scripts/make_theme.gd.uid \
  tools/make_theme.sh game/ui/theme/filly_theme.tres game/project.godot \
  game/test/test_theme.gd
git status --short   # confirm no .tscn.uid and no .tres.uid are staged
git commit -m "feat: one theme, generated from the style layer"
```

---

### Task 2: The mouse kit

**Files:**
- Create: `game/ui/mouse_rows.gd`
- Test: `game/test/test_mouse_rows.gd`

**Interfaces:**
- Consumes: `MenuStyle.row_box(picked)`, `MenuStyle.row_box_hover()`, `MenuStyle.COLOR_DIM`, `MenuStyle.FOOTER_SIZE`, `MenuStyle.style_label()` (Task 1).
- Produces, on `MouseRows` (static only, preloaded as `res://ui/mouse_rows.gd`):
  - `const ROW_INDEX_META := &"filly_row_index"`
  - `static func arm(holder: Control, index: int, on_hover: Callable, on_click: Callable) -> void`
  - `static func row(index: int, picked: bool, hovered: bool, on_hover: Callable, on_click: Callable) -> PanelContainer`
  - `static func row_index(holder: Control) -> int` (returns `-1` when the holder is not armed)
  - `static func close_button(label: String, on_click: Callable) -> Button`
  - `static func hit(rects: Array[Rect2], point: Vector2) -> int` (returns `-1` on a miss)
  - `static func is_left_click(event: InputEvent) -> bool`

- [ ] **Step 1: Write the failing test**

Create `game/test/test_mouse_rows.gd`:

```gdscript
extends GutTest
## THE MOUSE KIT, WHICH IS THE WHOLE OF HOW THIRTEEN HAND DRAWN SCREENS LEARNED THE POINTER.
##
## Every menu in this game builds its rows the same way: a PanelContainer carrying the shared
## StyleBoxFlat, with a Label inside it. So the pointer is taught once, here, and every menu
## swaps one call in its refresh(). The alternative was thirteen scripts each inventing a hit
## test, which is how the palette drifted before menu_style.gd existed.
##
## THE KEYBOARD IS NOT TRADED. Every Control this kit builds sets FOCUS_NONE, so Godot's own
## focus walk never takes the arrow keys away from the _unhandled_input() cursor each menu
## already runs. That is the single most important claim in this file and it is asserted.

const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

var _hovered: Array[int] = []
var _clicked: Array[int] = []


func before_each() -> void:
	_hovered = []
	_clicked = []


func _hover(index: int) -> void:
	_hovered.append(index)


func _click(index: int) -> void:
	_clicked.append(index)


func test_an_armed_row_reports_its_index_and_stops_the_mouse() -> void:
	var holder := PanelContainer.new()
	MouseRowsScript.arm(holder, 3, _hover, _click)
	assert_eq(MouseRowsScript.row_index(holder), 3)
	assert_eq(holder.mouse_filter, Control.MOUSE_FILTER_STOP,
		"a row that ignores the mouse cannot be clicked")
	holder.free()


func test_an_unarmed_control_reports_minus_one_rather_than_crashing() -> void:
	var holder := PanelContainer.new()
	assert_eq(MouseRowsScript.row_index(holder), -1)
	holder.free()


func test_hovering_an_armed_row_calls_back_with_its_index() -> void:
	var holder := PanelContainer.new()
	MouseRowsScript.arm(holder, 2, _hover, _click)
	holder.mouse_entered.emit()
	assert_eq(_hovered, [2] as Array[int])
	assert_eq(_clicked, [] as Array[int], "hovering is not choosing")
	holder.free()


func test_a_left_click_on_an_armed_row_calls_back_with_its_index() -> void:
	var holder := PanelContainer.new()
	MouseRowsScript.arm(holder, 5, _hover, _click)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	holder.gui_input.emit(event)
	assert_eq(_clicked, [5] as Array[int])
	holder.free()


func test_a_right_click_and_a_release_do_nothing() -> void:
	var holder := PanelContainer.new()
	MouseRowsScript.arm(holder, 5, _hover, _click)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	holder.gui_input.emit(right)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	holder.gui_input.emit(release)
	assert_eq(_clicked, [] as Array[int], "only a left press takes a row")
	holder.free()


func test_row_builds_the_holder_the_menus_already_draw() -> void:
	var idle: PanelContainer = MouseRowsScript.row(0, false, false, _hover, _click)
	var picked: PanelContainer = MouseRowsScript.row(1, true, false, _hover, _click)
	var hovered: PanelContainer = MouseRowsScript.row(2, false, true, _hover, _click)
	assert_eq(idle.get_theme_stylebox(&"panel"), MenuStyleScript.row_box(false))
	assert_eq(picked.get_theme_stylebox(&"panel"), MenuStyleScript.row_box(true))
	var hover_box: StyleBoxFlat = hovered.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(hover_box.bg_color, MenuStyleScript.row_box_hover().bg_color)
	assert_eq(MouseRowsScript.row_index(hovered), 2)
	for holder: PanelContainer in [idle, picked, hovered]:
		holder.free()


func test_selection_beats_hover_when_a_row_is_both() -> void:
	var both: PanelContainer = MouseRowsScript.row(0, true, true, _hover, _click)
	assert_eq(both.get_theme_stylebox(&"panel"), MenuStyleScript.row_box(true),
		"the row she is on is the row she is on, pointer or no pointer")
	both.free()


func test_nothing_the_kit_builds_takes_keyboard_focus() -> void:
	var holder: PanelContainer = MouseRowsScript.row(0, false, false, _hover, _click)
	var button: Button = MouseRowsScript.close_button("Close", _click)
	assert_eq(holder.focus_mode, Control.FOCUS_NONE,
		"a focusable row would steal the arrow keys from the menu cursor")
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	holder.free()
	button.free()


func test_the_close_button_says_what_it_does_and_calls_back() -> void:
	var button: Button = MouseRowsScript.close_button("Close", _click)
	assert_eq(button.text, "Close")
	button.pressed.emit()
	assert_eq(_clicked.size(), 1, "the close button has to actually close")
	button.free()


func test_hit_finds_the_rect_under_the_point_and_answers_minus_one_outside() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10), Rect2(20, 0, 10, 10),
		Rect2(40, 0, 10, 10)]
	assert_eq(MouseRowsScript.hit(rects, Vector2(5, 5)), 0)
	assert_eq(MouseRowsScript.hit(rects, Vector2(25, 5)), 1)
	assert_eq(MouseRowsScript.hit(rects, Vector2(45, 9)), 2)
	assert_eq(MouseRowsScript.hit(rects, Vector2(15, 5)), -1, "the gap between rows")
	assert_eq(MouseRowsScript.hit(rects, Vector2(5, 50)), -1, "below every row")


func test_hit_on_an_empty_list_is_a_miss_and_not_an_error() -> void:
	assert_eq(MouseRowsScript.hit([] as Array[Rect2], Vector2.ZERO), -1)


func test_is_left_click_reads_only_a_left_press() -> void:
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	assert_true(MouseRowsScript.is_left_click(left))
	var motion := InputEventMouseMotion.new()
	assert_false(MouseRowsScript.is_left_click(motion))
	var key := InputEventKey.new()
	key.pressed = true
	assert_false(MouseRowsScript.is_left_click(key))
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_mouse_rows.gd -gexit
```
Expected: GUT reports the script ignored or every test failing, because `res://ui/mouse_rows.gd` does not exist.

- [ ] **Step 3: Write the kit**

Create `game/ui/mouse_rows.gd`:

```gdscript
class_name MouseRows
extends RefCounted
## THE POINTER, TAUGHT ONCE. The owner's first full playtest, 2026-09-04: "all ui being
## keyboard only is tough". Every menu in this game already builds its rows the same way, a
## PanelContainer carrying the shared StyleBoxFlat with a Label inside it, so this file arms
## that holder with hover and click and every menu changes one line of its refresh().
##
## THE KEYBOARD IS ADDED TO, NEVER TRADED. Every Control built here sets FOCUS_NONE. Godot's
## own focus walk would otherwise take ui_up and ui_down off the _unhandled_input() cursor
## each menu runs, which would be removing the keyboard in the act of adding the mouse. The
## footers keep printing their key hints for the same reason.
##
## THE CALLBACKS TAKE AN INDEX AND NOTHING ELSE. A menu knows what its own row 3 means; this
## file must not, or it becomes a second place row order is decided.
##
## Static only, no state, no scene. Preload by path.

const MenuStyleScript := preload("res://ui/menu_style.gd")

## Stamped on every armed holder so a test, and a menu rebuilding its column, can ask a
## Control which row it is without keeping a parallel array beside the VBox.
const ROW_INDEX_META := &"filly_row_index"

const CLOSE_TEXT := "Close"


## Whether `event` is the one gesture this kit acts on: a LEFT button going DOWN. A release
## is deliberately not a click here, because every menu below this pauses the tree and a
## press that opened a menu must not have its release taken as a choice inside it.
static func is_left_click(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	return button != null and button.pressed \
		and button.button_index == MOUSE_BUTTON_LEFT


## Make `holder` answer the pointer as row `index`. Safe to call on a Control already in a
## tree and on one that is not; safe with invalid callables, which simply arm nothing.
static func arm(holder: Control, index: int, on_hover: Callable,
		on_click: Callable) -> void:
	if holder == null:
		return
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.focus_mode = Control.FOCUS_NONE
	holder.set_meta(ROW_INDEX_META, index)
	if on_hover.is_valid():
		holder.mouse_entered.connect(func() -> void: on_hover.call(index))
	if on_click.is_valid():
		holder.gui_input.connect(func(event: InputEvent) -> void:
			if is_left_click(event):
				on_click.call(index)
				holder.accept_event())


## Which row `holder` is, or -1 if nothing armed it.
static func row_index(holder: Control) -> int:
	if holder == null or not holder.has_meta(ROW_INDEX_META):
		return -1
	return int(holder.get_meta(ROW_INDEX_META))


## THE ROW EVERY MENU NOW BUILDS. Replaces MenuStyle.row_panel(picked), which stays for the
## two panels that draw rows nobody may pick.
##
## SELECTION BEATS HOVER. A row that is both is drawn selected: the pointer says what you
## would take and the cursor says what is taken, and when they are the same row there is
## only one thing to say.
static func row(index: int, picked: bool, hovered: bool, on_hover: Callable,
		on_click: Callable) -> PanelContainer:
	var holder := PanelContainer.new()
	var box: StyleBoxFlat = MenuStyleScript.row_box(true) if picked \
		else (MenuStyleScript.row_box_hover() if hovered else MenuStyleScript.row_box(false))
	holder.add_theme_stylebox_override(&"panel", box)
	arm(holder, index, on_hover, on_click)
	return holder


## THE POINTER USABLE WAY OUT OF EVERY SCREEN. The spec asks for one on every panel, and a
## player who reached a menu with the mouse must be able to leave it with the mouse.
static func close_button(label: String, on_click: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	if on_click.is_valid():
		button.pressed.connect(func() -> void: on_click.call(-1))
	return button


## WHICH RECT THE POINTER IS IN, for the screens that paint their rows instead of stacking
## them: the casino felt, the mail stationery. Returns the FIRST hit, so a caller with
## overlapping rects gets the one it listed first rather than an arbitrary one.
static func hit(rects: Array[Rect2], point: Vector2) -> int:
	for i in rects.size():
		if rects[i].has_point(point):
			return i
	return -1
```

- [ ] **Step 4: Run the test to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_mouse_rows.gd -gexit
```
Expected: `12/12 passed.` and `---- All tests passed! ----`.

- [ ] **Step 5: Run the suite (the corpus sweeps in test_menu_sound.gd now see a new file under game/ui/)**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
```
Expected: `---- All tests passed! ----`. `test_menu_sound.gd`'s `test_no_menu_names_a_ui_sound_id_behind_the_kit` and `test_no_menu_constructs_a_generator` both walk `res://ui/` and now include `mouse_rows.gd`; it names no sound id and builds no generator, so both stay green.

- [ ] **Step 6: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/ui/mouse_rows.gd game/ui/mouse_rows.gd.uid game/test/test_mouse_rows.gd
git commit -m "feat: a mouse kit the menus can all share"
```

---

### Task 3: The casino tables learn the mouse

> **Batchable with Task 4.** Both apply the identical `MouseRows` recipe to a family of hand-drawn list screens; one implementer can take both in a single dispatch.

**Files:**
- Modify: `game/ui/table_menu.gd:80-89` (`_ready`), `:221-249` (`refresh`), `:382-399` (`_unhandled_input`), and append new methods at the end
- Modify: `game/ui/slots_menu.gd`, `game/ui/wheel_menu.gd`, `game/ui/blackjack_menu.gd`, `game/ui/race_menu.gd` (each: one `stage_hit_rects()` override)
- Modify: `game/ui/slots_menu.tscn`, `game/ui/wheel_menu.tscn`, `game/ui/blackjack_menu.tscn`, `game/ui/race_menu.tscn` (the `Dim` node's `mouse_filter`)
- Test: `game/test/test_table_mouse.gd`

**Interfaces:**
- Consumes: `MouseRows.row(index, picked, hovered, on_hover, on_click)`, `MouseRows.close_button(label, on_click)`, `MouseRows.hit(rects, point)`, `MouseRows.is_left_click(event)`, `MouseRows.row_index(holder)` (Task 2).
- Produces, on `TableMenu` (inherited by `SlotsMenu`, `WheelMenu`, `BlackjackMenu`, `RaceMenu`):
  - `func hovered_index() -> int` (the row the pointer is on, or `-1`)
  - `func point_at_row(index: int) -> void` (move the cursor there and tick, exactly as `move_selection` does)
  - `func take_row(index: int) -> void` (point at it, then `confirm()`)
  - `func stage_hit_rects() -> Array[Rect2]` (stage-local rects a click may take; the base answers empty)
  - `func on_stage_hit(_index: int) -> void` (what a stage hit does; the base does nothing)
  - `func close_button_node() -> Button` (the pointer-usable close affordance, added by `_ready()`)

- [ ] **Step 1: Write the failing test**

Create `game/test/test_table_mouse.gd`:

```gdscript
extends GutTest
## THE FOUR TABLES, AND THE POINTER. The owner's playtest called the casino the one bright
## spot and also said every menu was keyboard only; this file is the claim that both are now
## true of it. Acceptance item 13: "Casino UI keeps its crown and gains mouse play."
##
## IT DRIVES THE HOLDERS THE MENU ACTUALLY BUILT, not a rect computed here. A test that
## measured its own idea of where row 2 is would go green on a menu that drew row 2 somewhere
## else, which is the defect game/test/test_table_caret.gd already exists for.

const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const SlotsScript := preload("res://ui/slots_menu.gd")

var _menu: SlotsMenu


func before_each() -> void:
	_menu = preload("res://ui/slots_menu.tscn").instantiate()
	add_child_autofree(_menu)
	_menu.chips_provider = func() -> int: return 5000
	_menu.can_open = func() -> bool: return true
	_menu.open()


func _row_holders() -> Array[PanelContainer]:
	var out: Array[PanelContainer] = []
	for child in _menu.get_node("Centre/Panel/Margin/Column/Rows").get_children():
		var panel := child as PanelContainer
		if panel != null and MouseRowsScript.row_index(panel) >= 0:
			out.append(panel)
	return out


func test_every_selectable_row_is_armed_and_no_unselectable_line_is() -> void:
	var armed: Array[PanelContainer] = _row_holders()
	assert_eq(armed.size(), _menu.row_count(),
		"exactly the rows the keyboard can reach are the rows the mouse can reach")
	var seen: Array[int] = []
	for holder: PanelContainer in armed:
		seen.append(MouseRowsScript.row_index(holder))
	seen.sort()
	assert_eq(seen, range(_menu.row_count()) as Array[int])


func test_pointing_at_a_row_moves_the_keyboard_cursor_to_it() -> void:
	_menu.point_at_row(1)
	assert_eq(_menu.selected_index(), 1, "one cursor, two ways to move it")
	assert_eq(_menu.hovered_index(), 1)


func test_the_arrow_keys_still_move_the_cursor_after_the_mouse_has_touched_it() -> void:
	_menu.point_at_row(1)
	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), 2 % _menu.row_count(),
		"the mouse must never take the keyboard away")


func test_clicking_a_row_takes_it() -> void:
	watch_signals(_menu)
	_menu.take_row(_menu.row_count() - 1)
	assert_eq(_menu.selected_index(), _menu.row_count() - 1)
	assert_gt(_menu.result_lines().size() + get_signal_emit_count(_menu, "spin_requested"),
		0, "a click on a row has to actually do the thing the row says")


func test_a_left_click_on_a_row_holder_reaches_take_row() -> void:
	var holders: Array[PanelContainer] = _row_holders()
	assert_gt(holders.size(), 1, "the slot machine has rows")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	holders[1].gui_input.emit(event)
	assert_eq(_menu.selected_index(), MouseRowsScript.row_index(holders[1]))


func test_the_close_button_exists_says_close_and_closes() -> void:
	var button: Button = _menu.close_button_node()
	assert_not_null(button, "every screen gets a pointer usable way out")
	assert_eq(button.text, MouseRowsScript.CLOSE_TEXT)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	button.pressed.emit()
	assert_false(_menu.is_open())


func test_the_dim_behind_the_panel_swallows_clicks_meant_for_nothing() -> void:
	var dim := _menu.get_node("Dim") as Control
	assert_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP,
		"a click beside the panel must not reach the world behind it")


func test_the_stage_answers_the_pointer_and_the_base_offers_no_hits() -> void:
	var stage := _menu.get_node("Centre/Panel/Margin/Column/Stage") as Control
	assert_eq(stage.mouse_filter, Control.MOUSE_FILTER_STOP,
		"a felt nothing can click is a felt with no mouse play on it")
	assert_gt(_menu.stage_hit_rects().size(), 0,
		"the slot machine paints something worth clicking")
	for rect: Rect2 in _menu.stage_hit_rects():
		assert_gt(rect.size.x * rect.size.y, 0.0, "an empty hit rect can never be hit")


func test_the_footer_still_prints_the_keys() -> void:
	var footer := _menu.get_node("Centre/Panel/Margin/Column/Footer") as Label
	assert_false(footer.text.strip_edges().is_empty(),
		"the key hints stay; the mouse was added, not traded")
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_table_mouse.gd -gexit
```
Expected: failures on `hovered_index`, `point_at_row`, `take_row`, `close_button_node`, `stage_hit_rects` being unknown methods.

- [ ] **Step 3: Teach TableMenu the pointer**

In `game/ui/table_menu.gd`, add the preload beside the existing ones at the top (after `const PaintScript := preload("res://ui/casino_paint.gd")`):

```gdscript
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
```

Add these fields beside `var _anim_t := 0.0`:

```gdscript
## The row the pointer is resting on, or -1. Distinct from _selected: the cursor is where
## she IS, this is where the pointer merely is, and a screenshot has to be able to show both.
var _hovered := -1

## The close button _ready() appends under the footer. Kept so a test and a subclass can
## reach it without walking the column.
var _close: Button = null
```

Replace `_ready()` (`game/ui/table_menu.gd:80-88`) with:

```gdscript
func _ready() -> void:
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	visible = false
	_title.text = title_text()
	# THE DIM IS A SHUTTER, NOT A DECORATION. It used to ignore the mouse, so a click beside
	# the panel fell through to the paused world behind it.
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if _stage != null:
		# STOP, not IGNORE: this is the felt, and the felt is where the game is.
		_stage.mouse_filter = Control.MOUSE_FILTER_STOP
		_stage.focus_mode = Control.FOCUS_NONE
		_stage.custom_minimum_size = stage_size()
		_stage.draw.connect(_paint_stage)
		_stage.gui_input.connect(_on_stage_input)
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
	$Centre/Panel/Margin/Column.add_child(_close)
	set_process(false)
```

Replace the row-building loop inside `refresh()` (`game/ui/table_menu.gd:234-249`) with:

```gdscript
	var lines: Array[String] = printed_lines()
	var caret: int = _selected + first_row_line_index()
	for i in lines.size():
		var picked: bool = i == caret and row_count() > 0
		var row: int = _row_at_line(i)
		var label := Label.new()
		label.text = MenuStyleScript.caret(picked) + lines[i]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# style_label() AND NOT A BARE font_color OVERRIDE. This line used to set the colour
		# alone, so every row on every table in the Palace shipped with no outline, over a
		# translucent panel, over a bright green field: exactly the readability failure
		# MenuStyle.OUTLINE_COLOR's own comment exists to prevent.
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE,
			MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
		var holder: PanelContainer
		if row >= 0:
			holder = MouseRowsScript.row(row, picked, row == _hovered,
				point_at_row, take_row)
		else:
			# A PRINTED LINE THAT IS NOT A ROW. The result block and the chips line are text
			# the panel prints above its rows; nothing may pick them, so nothing arms them.
			holder = MenuStyleScript.row_panel(picked)
		holder.add_child(label)
		_rows.add_child(holder)
```

Append at the end of `game/ui/table_menu.gd`:

```gdscript
# --- the pointer ----------------------------------------------------------------------------
#
# ONE CURSOR, TWO WAYS TO MOVE IT. point_at_row() is move_selection() with an absolute
# destination instead of a step, and it makes the same sound, because a player who moves the
# cursor with the mouse and a player who moves it with the arrow keys have done the same
# thing and should hear the same thing.


## Which drawn line is selectable row `index`, or -1 for a line nothing may pick. The
## printed column and the selectable rows are not the same list; see first_row_line_index().
func _row_at_line(line: int) -> int:
	var index: int = line - first_row_line_index()
	return index if index >= 0 and index < row_count() else -1


func hovered_index() -> int:
	return _hovered


func close_button_node() -> Button:
	return _close


## Put the cursor on `index`. Refuses while an animation is running, exactly as
## move_selection() is refused by every table that overrides it, so a spinning reel cannot be
## re staked with the pointer either.
func point_at_row(index: int) -> void:
	if not _open or animating():
		return
	if index < 0 or index >= row_count():
		return
	if index == _selected and index == _hovered:
		return
	_hovered = index
	if index != _selected:
		_selected = index
		MenuStyleScript.tick_move()
	refresh()


func take_row(index: int) -> void:
	point_at_row(index)
	if _selected == index:
		confirm()


## THE STAGE'S OWN CLICKABLE RECTS, in stage local coordinates. Empty on the base, which is
## the right answer for a table that paints nothing worth pointing at.
func stage_hit_rects() -> Array[Rect2]:
	return []


## What a click on stage rect `_index` does. Overridden by the tables that have one.
func on_stage_hit(_index: int) -> void:
	pass


func _on_stage_input(event: InputEvent) -> void:
	if not _open or _stage == null or not MouseRowsScript.is_left_click(event):
		return
	var button := event as InputEventMouseButton
	var index: int = MouseRowsScript.hit(stage_hit_rects(), button.position)
	if index < 0:
		return
	on_stage_hit(index)
	_stage.accept_event()
```

- [ ] **Step 4: Clear the hover when the panel closes**

In `close()` (`game/ui/table_menu.gd:109-116`), add `_hovered = -1` immediately after `_open = false`. In `open()` (`:91-106`), add `_hovered = -1` immediately after `_selected = 0`. A stale hover would draw a highlight on a row the pointer left while the panel was shut.

- [ ] **Step 5: Give each table its stage hits**

In `game/ui/slots_menu.gd`, append:

```gdscript
## THE LEVER AND THE THREE REELS. Clicking the lever is spinning; clicking a reel is the
## same, because a player who clicks the machine means play. The rects are the ones paint()
## already draws into, taken from the same constants, so the drawing and the hit test cannot
## disagree.
func stage_hit_rects() -> Array[Rect2]:
	return [LEVER_RECT, REEL_BAND]


func on_stage_hit(_index: int) -> void:
	take_row(row_count() - 1)
```

If `slots_menu.gd` does not already declare `LEVER_RECT` and `REEL_BAND`, add them beside its other stage constants, giving them the rects its `paint()` uses for the lever and for the band of three reels. Read `paint()` first and reuse its numbers verbatim; do not invent a second set.

In `game/ui/wheel_menu.gd`, append:

```gdscript
## THE FELT'S BETTING BOXES, one per row of the panel and in the panel's own row order, so
## clicking red on the felt and pressing confirm on the red row are the same act. The order
## mattering is the point: game/scenes/test/casino_test.gd already drives one wheel bet end
## to end through the felt precisely because a swap between the felt's order and Wheel.Bet's
## would silently mispay a colour bet at number odds.
func stage_hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in row_count():
		out.append(bet_rect(i))
	return out


func on_stage_hit(index: int) -> void:
	take_row(index)
```

If `wheel_menu.gd` has no `bet_rect(index)`, add one that returns the rect `paint()` already computes for betting box `index`, factored out of `paint()` so both call it.

In `game/ui/blackjack_menu.gd` and `game/ui/race_menu.gd`, append the same shape, one rect per selectable row, taken from the rects their own `paint()` computes:

```gdscript
func stage_hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in row_count():
		out.append(row_rect(i))
	return out


func on_stage_hit(index: int) -> void:
	take_row(index)
```

Add `row_rect(index)` to each, factored out of that file's `paint()`. If a table's `paint()` genuinely draws nothing per row (a placard tab, a form guide read-out), have `stage_hit_rects()` return `[]` on that tab and say so in a comment; the rows in the column are still clickable.

- [ ] **Step 6: Open the Dim in the four scenes**

In `game/ui/slots_menu.tscn`, `wheel_menu.tscn`, `blackjack_menu.tscn` and `race_menu.tscn`, find the `[node name="Dim" ...]` block and change its `mouse_filter = 2` to `mouse_filter = 0`. Leave every other `mouse_filter = 2` in those files alone: the Labels inside a row holder must keep ignoring the mouse or they would eat the holder's click.

(`_ready()` also sets this at run time, so the scene edit is belt and braces for anything that reads the file rather than the tree.)

- [ ] **Step 7: Run the table test to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_table_mouse.gd -gexit
```
Expected: `9/9 passed.`

- [ ] **Step 8: Run the suite and the casino gate**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/casino_test.tscn
```
Expected: `---- All tests passed! ----` and `CASINO_OK checks=76`. RECONCILE the check count against `docs/testing.md`.

If `test_table_caret.gd` fails on `focus_rect()`, the cause is a row holder that is now armed and no longer the one carrying the caret Label; `focus_rect()` walks the holders looking for a Label whose text begins with `MenuStyle.CARET`, which is unchanged, so investigate before touching it.

- [ ] **Step 9: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/ui/table_menu.gd game/ui/slots_menu.gd game/ui/wheel_menu.gd \
  game/ui/blackjack_menu.gd game/ui/race_menu.gd game/ui/slots_menu.tscn \
  game/ui/wheel_menu.tscn game/ui/blackjack_menu.tscn game/ui/race_menu.tscn \
  game/test/test_table_mouse.gd
git commit -m "feat: the tables in the palace take the mouse"
```

---

### Task 4: The list menus learn the mouse

> **Batchable with Task 3.**

**Files:**
- Modify: `game/ui/market_menu.gd:282-364` (`refresh`, `_add_row`), `:60-81` (`_ready`)
- Modify: `game/ui/depot_menu.gd` (its `refresh`/`_add_row`/`_ready` equivalents)
- Modify: `game/ui/build_menu.gd` (same)
- Modify: `game/ui/casino_menu.gd:125-134` (`_ready`), `:297-338` (`refresh`, `_row_count`), and append the stage hits
- Modify: `game/ui/market_menu.tscn`, `depot_menu.tscn`, `build_menu.tscn`, `casino_menu.tscn` (the `Dim` node's `mouse_filter`)
- Test: `game/test/test_list_menu_mouse.gd`

**Interfaces:**
- Consumes: `MouseRows.row(...)`, `MouseRows.close_button(...)`, `MouseRows.hit(...)`, `MouseRows.is_left_click(...)`, `MouseRows.row_index(...)`, `MouseRows.CLOSE_TEXT` (Task 2).
- Produces, on each of `MarketMenu`, `DepotMenu`, `BuildMenu`, `CasinoMenu`, with identical names and signatures so a test can drive all four through one loop:
  - `func hovered_index() -> int`
  - `func point_at_row(index: int) -> void`
  - `func take_row(index: int) -> void`
  - `func close_button_node() -> Button`
- Produces, on `CasinoMenu` only: `func stage_hit_rects() -> Array[Rect2]` and `func on_stage_hit(index: int) -> void`, using its existing `tile_rect(index)` and `cage_row_rect(index)`.

- [ ] **Step 1: Write the failing test**

Create `game/test/test_list_menu_mouse.gd`:

```gdscript
extends GutTest
## THE FOUR LIST SCREENS, AND THE POINTER. Acceptance item 5: "Every menu usable by mouse
## alone and keyboard alone."
##
## ONE LOOP OVER FOUR MENUS, on purpose. These four grew up separately and were folded onto
## menu_style.gd's look but not onto its behaviour; a test that drove them one at a time is a
## test that would let the fourth one quietly not have been done. The names in the loop are
## the contract: hovered_index(), point_at_row(), take_row(), close_button_node().

const MouseRowsScript := preload("res://ui/mouse_rows.gd")

const SCENES: Array[String] = ["res://ui/market_menu.tscn", "res://ui/depot_menu.tscn",
	"res://ui/build_menu.tscn", "res://ui/casino_menu.tscn"]


func _armed_rows(menu: CanvasLayer) -> Array[PanelContainer]:
	var out: Array[PanelContainer] = []
	var column := menu.get_node_or_null(^"Centre/Panel/Margin/Column/Rows")
	if column == null:
		return out
	for child in column.get_children():
		var panel := child as PanelContainer
		if panel != null and MouseRowsScript.row_index(panel) >= 0:
			out.append(panel)
	return out


func test_every_list_menu_offers_the_same_four_pointer_methods() -> void:
	var checked := 0
	for path: String in SCENES:
		var menu: CanvasLayer = load(path).instantiate()
		add_child_autofree(menu)
		for method: String in ["hovered_index", "point_at_row", "take_row",
				"close_button_node"]:
			assert_true(menu.has_method(method), "%s has no %s()" % [path, method])
		checked += 1
	assert_eq(checked, SCENES.size(), "all four were actually reached")


func test_every_list_menu_gives_the_pointer_a_way_out() -> void:
	var checked := 0
	for path: String in SCENES:
		var menu: CanvasLayer = load(path).instantiate()
		add_child_autofree(menu)
		var button: Button = menu.close_button_node()
		assert_not_null(button, "%s has no close button" % path)
		assert_eq(button.text, MouseRowsScript.CLOSE_TEXT, path)
		assert_eq(button.focus_mode, Control.FOCUS_NONE, path)
		checked += 1
	assert_eq(checked, SCENES.size())


func test_every_list_menu_stops_the_mouse_at_its_dim() -> void:
	var checked := 0
	for path: String in SCENES:
		var menu: CanvasLayer = load(path).instantiate()
		add_child_autofree(menu)
		var dim := menu.get_node_or_null(^"Dim") as Control
		assert_not_null(dim, "%s has no Dim" % path)
		assert_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP, path)
		checked += 1
	assert_eq(checked, SCENES.size())


func test_the_market_arms_exactly_the_rows_the_keyboard_can_reach() -> void:
	var menu: MarketMenu = preload("res://ui/market_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.can_open = func() -> bool: return true
	menu.open()
	var armed: Array[PanelContainer] = _armed_rows(menu)
	var seen: Array[int] = []
	for holder: PanelContainer in armed:
		seen.append(MouseRowsScript.row_index(holder))
	seen.sort()
	assert_eq(seen, range(armed.size()) as Array[int], "row indices are dense from zero")
	assert_gt(armed.size(), 0, "the Market draws rows")


func test_pointing_moves_the_cursor_and_the_keys_still_work_afterwards() -> void:
	var menu: MarketMenu = preload("res://ui/market_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.can_open = func() -> bool: return true
	menu.open()
	menu.point_at_row(0)
	assert_eq(menu.selected_index(), 0)
	assert_eq(menu.hovered_index(), 0)
	menu.move_selection(1)
	assert_eq(menu.selected_index(), 1, "the mouse must never take the keyboard away")


func test_the_casino_lobby_tiles_are_clickable_and_map_to_its_rows() -> void:
	var menu: CasinoMenu = preload("res://ui/casino_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.can_open = func() -> bool: return true
	menu.open()
	menu.set_tab(CasinoMenu.Tab.LOBBY)
	var rects: Array[Rect2] = menu.stage_hit_rects()
	assert_gt(rects.size(), 0, "the lobby paints tiles worth clicking")
	watch_signals(menu)
	menu.on_stage_hit(0)
	assert_eq(menu.selected_index(), 0, "a click on a tile is a click on its row")


func test_a_left_click_on_a_row_holder_reaches_take_row() -> void:
	var menu: MarketMenu = preload("res://ui/market_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.can_open = func() -> bool: return true
	menu.open()
	var armed: Array[PanelContainer] = _armed_rows(menu)
	assert_gt(armed.size(), 1)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	armed[1].gui_input.emit(event)
	assert_eq(menu.selected_index(), MouseRowsScript.row_index(armed[1]))


func test_every_list_menu_still_prints_its_footer_keys() -> void:
	var checked := 0
	for path: String in SCENES:
		var menu: CanvasLayer = load(path).instantiate()
		add_child_autofree(menu)
		var footer := menu.get_node_or_null(^"Centre/Panel/Margin/Column/Footer") as Label
		assert_not_null(footer, "%s has no footer" % path)
		checked += 1
	assert_eq(checked, SCENES.size())
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_list_menu_mouse.gd -gexit
```
Expected: failures naming `hovered_index`, `point_at_row`, `take_row`, `close_button_node` as missing.

- [ ] **Step 3: Apply the recipe to market_menu.gd**

Add the preload beside the other consts at the top of `game/ui/market_menu.gd`:

```gdscript
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
```

Add beside the other `var` declarations:

```gdscript
## Where the pointer is resting, or -1. Not the cursor: see game/ui/table_menu.gd's own
## comment on the same pair of fields.
var _hovered := -1
var _close: Button = null
```

In `_ready()`, after the existing `MenuStyleScript.apply_panel(...)` line, add:

```gdscript
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
	$Centre/Panel/Margin/Column.add_child(_close)
```

In `_add_row()` (`game/ui/market_menu.gd:330`), replace the line that constructs the holder `PanelContainer` and applies `_row_style(...)` with:

```gdscript
	var row := MouseRowsScript.row(index, index == _selected, index == _hovered,
		point_at_row, take_row)
```

and delete the following `row.add_theme_stylebox_override(&"panel", _row_style(...))` line, since `MouseRows.row()` already applies the box. Every `Label` and `MarginContainer` created inside `_add_row()` gets `mouse_filter = Control.MOUSE_FILTER_IGNORE` so the holder keeps the click.

In `open()`, set `_hovered = -1` beside the existing selection reset; in `close()`, set `_hovered = -1`.

Append at the end of `game/ui/market_menu.gd`:

```gdscript
# --- the pointer ----------------------------------------------------------------------------


func hovered_index() -> int:
	return _hovered


func close_button_node() -> Button:
	return _close


## ONE CURSOR, TWO WAYS TO MOVE IT. Absolute where move_selection() is relative, and it makes
## the same sound, because both are the player choosing a row.
func point_at_row(index: int) -> void:
	if index < 0 or index >= _row_count():
		return
	if index == _selected and index == _hovered:
		return
	_hovered = index
	if index != _selected:
		_selected = index
		MenuStyleScript.tick_move()
	refresh()


func take_row(index: int) -> void:
	point_at_row(index)
	if _selected == index:
		confirm()
```

- [ ] **Step 4: Apply the same recipe to depot_menu.gd and build_menu.gd**

Both files carry the same `_ready()`, `_add_row()`, `_row_count()`, `move_selection()`, `confirm()` shape as `market_menu.gd`. Make the identical five edits in each:

1. add `const MouseRowsScript := preload("res://ui/mouse_rows.gd")`
2. add `var _hovered := -1` and `var _close: Button = null`
3. in `_ready()`, stop the `Dim`, build the close button, add it to the Column
4. in the row builder, swap the hand-built `PanelContainer` plus `_row_style()` for `MouseRowsScript.row(index, index == _selected, index == _hovered, point_at_row, take_row)`, and set `MOUSE_FILTER_IGNORE` on every child Control it makes
5. append the identical four-method pointer block, with `_row_count()` named exactly as that file names it

Reset `_hovered = -1` in each file's `open()` and `close()`.

- [ ] **Step 5: Apply the recipe to casino_menu.gd, plus its tiles**

Make the same five edits in `game/ui/casino_menu.gd` (its `refresh()` at `:297` builds the rows; its row count is `_row_count()` at `:322`). Then replace the `_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE` line at `game/ui/casino_menu.gd:130` with:

```gdscript
		_stage.mouse_filter = Control.MOUSE_FILTER_STOP
		_stage.focus_mode = Control.FOCUS_NONE
		_stage.gui_input.connect(_on_stage_input)
```

and append:

```gdscript
# --- the felt, under the pointer ------------------------------------------------------------
#
## THE LOBBY'S TILES AND THE CAGE'S ROWS ARE ALREADY RECTS. tile_rect() and cage_row_rect()
## are what paint() draws into, so the hit test asks the drawing where things are rather than
## computing a second opinion. The house rules page is reading matter and offers no hits,
## which is the correct answer for a page with nothing on it to choose.


func stage_hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	match tab():
		Tab.LOBBY:
			for i in _row_count():
				out.append(tile_rect(i))
		Tab.CAGE:
			for i in _row_count():
				out.append(cage_row_rect(i))
	return out


func on_stage_hit(index: int) -> void:
	take_row(index)


func _on_stage_input(event: InputEvent) -> void:
	if not is_open() or _stage == null or not MouseRowsScript.is_left_click(event):
		return
	var button := event as InputEventMouseButton
	var index: int = MouseRowsScript.hit(stage_hit_rects(), button.position)
	if index < 0:
		return
	on_stage_hit(index)
	_stage.accept_event()
```

- [ ] **Step 6: Open the Dim in the four scenes**

In `game/ui/market_menu.tscn`, `depot_menu.tscn`, `build_menu.tscn` and `casino_menu.tscn`, change the `[node name="Dim" ...]` block's `mouse_filter = 2` to `mouse_filter = 0`. Change nothing else.

- [ ] **Step 7: Run the list test to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_list_menu_mouse.gd -gexit
```
Expected: `8/8 passed.`

- [ ] **Step 8: Run the suite and the market, depot and casino gates**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
for gate in market depot casino; do
  FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
    --path game "scenes/test/${gate}_test.tscn"
done
```
Expected: `---- All tests passed! ----`, then `MARKET_OK checks=69`, `DEPOT_OK checks=72`, `CASINO_OK checks=76`. RECONCILE against `docs/testing.md`.

- [ ] **Step 9: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/ui/market_menu.gd game/ui/depot_menu.gd game/ui/build_menu.gd \
  game/ui/casino_menu.gd game/ui/market_menu.tscn game/ui/depot_menu.tscn \
  game/ui/build_menu.tscn game/ui/casino_menu.tscn game/test/test_list_menu_mouse.gd
git commit -m "feat: the market, the depot, the build picker and the lobby take the mouse"
```

---

### Task 5: The pause menu takes the mouse and says "Save game"

**Files:**
- Modify: `game/ui/pause_menu.gd:54-59` (the `Row` enum and `MAIN_ROWS`), `:107-111` (signals), `:175-193` (`_ready`), `:349-425` (`confirm`), `:946-984` (`_add_row`, `_row_style`), `:1021-1055` (`_paint_stage`, `_paint_envelopes`), and append the pointer block
- Modify: `game/ui/pause_menu.tscn` (the `Dim` node's `mouse_filter`)
- Modify: `game/world/ranch.gd:2043` (the pause menu signal wiring) and append `_on_load_requested()`
- Test: `game/test/test_pause_menu.gd` (extend), `game/test/test_ranch_load.gd` (create)

**Interfaces:**
- Consumes: `MouseRows.row(...)`, `MouseRows.close_button(...)`, `MouseRows.hit(...)`, `MouseRows.is_left_click(...)`, `MouseRows.row_index(...)`, `MouseRows.CLOSE_TEXT` (Task 2).
- Produces, on `PauseMenu`:
  - `enum Row { RESUME, COMPENDIUM, REQUESTS, MAIL, LEDGER, SAVE, LOAD, SETTINGS, QUIT }` (`LOAD` inserted after `SAVE`)
  - `const MAIN_ROWS` reworded (below)
  - `signal load_requested()`
  - `var has_save_provider := Callable()` (returns `bool`; a menu with no provider treats the slot as present)
  - `func hovered_index() -> int`, `func point_at_row(index: int) -> void`, `func take_row(index: int) -> void`, `func close_button_node() -> Button`
  - `func stage_hit_rects() -> Array[Rect2]`, `func on_stage_hit(index: int) -> void` (the Mail page's envelopes)
- Produces, on `Ranch`: `func _on_load_requested() -> void` (private; wired from `_bind_pause_menu()`)

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_pause_menu.gd`:

```gdscript
# --- the pointer, and the copy ---------------------------------------------------------

## THE OWNER MISREAD "Save the ranch" AS SOMETHING THAT HAPPENED TO THE RANCH rather than as
## a file operation. This is the copy fix, pinned so it cannot drift back.
func test_the_main_page_says_save_game_and_load_game() -> void:
	assert_eq(PauseMenu.MAIN_ROWS[PauseMenu.Row.SAVE], "Save game")
	assert_eq(PauseMenu.MAIN_ROWS[PauseMenu.Row.LOAD], "Load game")
	assert_eq(PauseMenu.MAIN_ROWS[PauseMenu.Row.MAIL], "Saddlebag copies")
	assert_eq(PauseMenu.MAIN_ROWS.size(), PauseMenu.Row.size())


func test_no_row_or_footer_on_this_menu_carries_a_dash() -> void:
	var checked := 0
	for text: String in PauseMenu.MAIN_ROWS:
		assert_false(text.contains("--"), text)
		assert_false(text.contains(char(0x2014)), text)
		checked += 1
	assert_gt(checked, 0, "the row list was actually walked")


func test_load_game_asks_the_ranch_to_load_and_only_when_there_is_a_save() -> void:
	_menu.has_save_provider = func() -> bool: return true
	_menu.open()
	watch_signals(_menu)
	_menu.take_row(PauseMenu.Row.LOAD)
	assert_signal_emitted(_menu, "load_requested")


func test_load_game_refuses_when_no_save_exists() -> void:
	_menu.has_save_provider = func() -> bool: return false
	_menu.open()
	watch_signals(_menu)
	_menu.take_row(PauseMenu.Row.LOAD)
	assert_signal_not_emitted(_menu, "load_requested",
		"a Load row on a machine with no save is a row that must refuse")


func test_pointing_moves_the_cursor_and_the_keys_still_work() -> void:
	_menu.open()
	_menu.point_at_row(PauseMenu.Row.SETTINGS)
	assert_eq(_menu.selected_index(), PauseMenu.Row.SETTINGS)
	assert_eq(_menu.hovered_index(), PauseMenu.Row.SETTINGS)
	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), PauseMenu.Row.QUIT,
		"the mouse must never take the keyboard away")


func test_the_pause_menu_offers_the_pointer_a_way_out() -> void:
	var button: Button = _menu.close_button_node()
	assert_not_null(button)
	assert_eq(button.text, preload("res://ui/mouse_rows.gd").CLOSE_TEXT)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)


func test_the_mail_envelopes_are_clickable_and_open_the_letter_they_name() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	var rects: Array[Rect2] = _menu.stage_hit_rects()
	assert_eq(rects.size(), _menu.mail_rows().size(),
		"one hit rect per envelope on the page")
	_menu.on_stage_hit(0)
	assert_eq(_menu.open_letter_id(), &"weather_survey", "the newest envelope is the top one")
```

Create `game/test/test_ranch_load.gd`:

```gdscript
extends GutTest
## THE LOAD ROW, AT THE RANCH END. game/ui/pause_menu.gd emits load_requested; this is the
## claim that ranch.gd hears it, and that it refuses when there is nothing on disk to load.
##
## IT NEVER RELOADS THE SCENE HERE. reload_current_scene() on a Ranch built by a test would
## take the GUT runner's own tree with it, so the handler is split: _can_load() is the
## decision and _on_load_requested() is the act, and this file drives the decision.

const RanchScript := preload("res://world/ranch.gd")


func test_a_ranch_with_no_game_state_cannot_load() -> void:
	var ranch: Ranch = RanchScript.new()
	assert_false(ranch._can_load(), "no state, no load")
	ranch.free()
```

- [ ] **Step 2: Run them and watch them fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_pause_menu.gd -gexit
```
Expected: failures on `Row.LOAD`, `has_save_provider`, `point_at_row`, `stage_hit_rects` being unknown.

- [ ] **Step 3: The enum and the copy**

Replace `game/ui/pause_menu.gd:55-59` with:

```gdscript
enum Row { RESUME, COMPENDIUM, REQUESTS, MAIL, LEDGER, SAVE, LOAD, SETTINGS, QUIT }
enum SettingRow { VOLUME, AMBIENT, EFFECTS, SENSITIVITY, INVERT }

## THE ROWS, IN THE ENUM'S OWN ORDER, and the words on them.
##
## "Save the ranch" IS GONE. The owner read it, on her first full playtest, as something the
## game was proposing to do to the ranch rather than as a file operation, and she is right:
## every other game in the world calls this Save game. Load game is beside it now, which is
## the row that was missing rather than mislabelled.
##
## "Mail" IS "Saddlebag copies". The letters are read at the mailbox by the door from this
## slice on; this page is the archive of what has already come, and calling it Mail is what
## made the owner ask why her mail was in a menu when the letter said it was by her house.
const MAIN_ROWS := ["Resume", "Compendium", "Requests", "Saddlebag copies", "The ledger",
	"Save game", "Load game", "Settings", "Quit to desktop"]
```

Add beside the other signals (`game/ui/pause_menu.gd:107-111`):

```gdscript
signal load_requested()
```

Add beside the other injected callables (near `var can_open := Callable()`):

```gdscript
## Whether there is a save on disk to load. Injected by ranch.gd, like every other provider
## on this menu: game/ui/ may not reach SaveIO any more than it may reach Economy. A menu
## with no provider assumes there is one, which is the answer a test fixture wants.
var has_save_provider := Callable()
```

- [ ] **Step 4: The pointer**

Add the preload at the top of `game/ui/pause_menu.gd`:

```gdscript
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
```

Add beside the other `var` fields:

```gdscript
var _hovered := -1
var _close: Button = null
```

In `_ready()` (`:175`), after the existing panel styling, add:

```gdscript
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if _stage != null:
		_stage.mouse_filter = Control.MOUSE_FILTER_STOP
		_stage.focus_mode = Control.FOCUS_NONE
		_stage.gui_input.connect(_on_stage_input)
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
	$Centre/Panel/Margin/Column.add_child(_close)
```

In `_add_row()` (`:946`), replace the first two lines

```gdscript
	var row := PanelContainer.new()
	row.add_theme_stylebox_override(&"panel", _row_style(index == _selected))
```

with

```gdscript
	var row: PanelContainer = MouseRowsScript.row(index, index == _selected,
		index == _hovered, point_at_row, take_row)
```

and set `mouse_filter = Control.MOUSE_FILTER_IGNORE` on the `MarginContainer`, the `HBoxContainer` and both `Label`s it builds. `_row_style()` stays: `_add_note()` still uses it and the settings page's compact rows read it.

In `open()` and `close()`, set `_hovered = -1`.

Append at the end of `game/ui/pause_menu.gd`:

```gdscript
# --- the pointer ----------------------------------------------------------------------------


func hovered_index() -> int:
	return _hovered


func close_button_node() -> Button:
	return _close


func point_at_row(index: int) -> void:
	if index < 0 or index >= _row_count():
		return
	if index == _selected and index == _hovered:
		return
	_hovered = index
	if index != _selected:
		_selected = index
		MenuStyleScript.tick_move()
	_refresh()


func take_row(index: int) -> void:
	point_at_row(index)
	if _selected == index:
		confirm()


## THE MAIL PAGE IS A DRAWING, so its rows are rects rather than PanelContainers. The
## envelope rects are the ones _paint_envelopes() lays out, computed here from the same
## constants so the drawing and the hit test cannot disagree.
func stage_hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _page != Page.MAIL or not _letter_id.is_empty():
		return out
	var rows: Array[Dictionary] = mail_rows()
	var shown: int = mini(rows.size(), ENVELOPES_ON_SCREEN)
	for i in shown:
		out.append(Rect2(0.0, float(i) * (ENVELOPE_HEIGHT + ENVELOPE_GAP),
			MAIL_STAGE_WIDTH, ENVELOPE_HEIGHT))
	return out


func on_stage_hit(index: int) -> void:
	if _page != Page.MAIL:
		return
	var rows: Array[Dictionary] = mail_rows()
	if index < 0 or index >= rows.size():
		return
	_selected = index + _scroll
	open_letter(StringName(String(rows[index + _scroll]["id"])))


func _on_stage_input(event: InputEvent) -> void:
	if not _open or _stage == null or not MouseRowsScript.is_left_click(event):
		return
	var button := event as InputEventMouseButton
	var index: int = MouseRowsScript.hit(stage_hit_rects(), button.position)
	if index < 0:
		return
	on_stage_hit(index)
	_stage.accept_event()
```

If `_paint_envelopes()` lays its envelopes out at a different origin or pitch than the block above, fix the block to match the drawing, never the drawing to match the block; add a short comment naming the constant they share.

- [ ] **Step 5: Wire Load into confirm()**

In `confirm()` (`game/ui/pause_menu.gd:349`), beside the existing `Row.SAVE` branch, add:

```gdscript
		Row.LOAD:
			# A LOAD ROW ON A MACHINE WITH NO SAVE MUST REFUSE, and say so the way every
			# other refusal in this game says so: one soft tick, no signal, nothing moves.
			var has_save: bool = true
			if has_save_provider.is_valid():
				has_save = bool(has_save_provider.call())
			if not has_save:
				MenuStyleScript.tick_denied()
				return false
			MenuStyleScript.tick_confirm()
			load_requested.emit()
			return true
```

- [ ] **Step 6: Open the Dim in the scene**

In `game/ui/pause_menu.tscn`, change the `[node name="Dim" ...]` block's `mouse_filter = 2` to `mouse_filter = 0`.

- [ ] **Step 7: Wire the ranch end**

In `game/world/ranch.gd`, extend the pause menu wiring at `:2043` so the pair list also carries `["load_requested", _on_load_requested]`, and set the provider immediately after the connects:

```gdscript
	pause_menu.set("has_save_provider", func() -> bool: return _can_load())
```

Append to `game/world/ranch.gd`:

```gdscript
## IS THERE ANYTHING ON DISK TO GO BACK TO? Split out of _on_load_requested() so a test can
## drive the decision without a scene reload taking the test runner's own tree with it.
func _can_load() -> bool:
	return _game_state != null and _game_state.has_save()


## LOAD GAME. The whole world is rebuilt rather than patched, because a ranch is terrain, a
## herd, a set of pens and a clock, and half of that being from the save while the other half
## is from the session is the class of bug that eats an afternoon. reload_current_scene()
## re-runs _ready(), whose _bind_game_state() reads the slot exactly as a fresh boot does.
##
## THE TREE IS UNPAUSED FIRST. The pause menu paused it; a scene reloaded into a paused tree
## comes back frozen, with nothing left on screen able to unfreeze it.
func _on_load_requested() -> void:
	if not _interactive or not _can_load():
		return
	if pause_menu != null and pause_menu.has_method("close"):
		pause_menu.call("close")
	get_tree().paused = false
	_set_cursor_captured(true)
	get_tree().reload_current_scene()
```

- [ ] **Step 8: Run the tests to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_pause_menu.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_ranch_load.gd -gexit
```
Expected: `---- All tests passed! ----` on both.

- [ ] **Step 9: Run the suite and the gates that open this menu**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
for gate in market collection story depot; do
  FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
    --path game "scenes/test/${gate}_test.tscn"
done
```
Expected: `---- All tests passed! ----`, `MARKET_OK checks=69`, `COLLECTION_OK checks=73`, `STORY_OK checks=55`, `DEPOT_OK checks=72`. RECONCILE against `docs/testing.md`.

Any gate that indexes `PauseMenu.Row` by number rather than by name will move under the inserted `LOAD`; fix such a call site to name the enum member, never to hard-code the new index.

- [ ] **Step 10: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/ui/pause_menu.gd game/ui/pause_menu.tscn game/world/ranch.gd \
  game/test/test_pause_menu.gd game/test/test_ranch_load.gd
git commit -m "feat: the pause menu takes the mouse and says save game"
```

---

### Task 6: The letter panel is crafted, and takes the mouse

**Files:**
- Modify: `game/ui/letter_panel.gd` (whole file: the stationery restyle, the close button, the mouse)
- Modify: `game/ui/letter_panel.tscn` (a `Stage` Control for the drawn sheet, the `Dim` filter)
- Test: `game/test/test_letter_panel.gd` (extend)

**Interfaces:**
- Consumes: `MouseRows.close_button(...)`, `MouseRows.is_left_click(...)`, `MouseRows.CLOSE_TEXT` (Task 2); `MenuStyle.paper_box()`, `MenuStyle.COLOR_INK`, `MenuStyle.THEME_PATH` (Task 1); `PaperPaint.sheet()`, `PaperPaint.letterhead()`, `PaperPaint.logo_mark()` (existing).
- Produces, on `LetterPanel`:
  - `func close_button_node() -> Button`
  - `func stage_size() -> Vector2`
  - `func paint(ci: Control) -> void`
  - `const SHEET_WIDTH := 860.0`, `const LINE_HEIGHT := 26.0`, `const SHEET_MARGIN := 44.0`
  - `opened` and `closed` signals unchanged, so `ranch.gd`'s existing wiring is untouched

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_letter_panel.gd`:

```gdscript
# --- the crafted sheet ------------------------------------------------------------------

## THE OWNER CALLED THE LETTER UI "week". This is what crafted means, measured: the page is
## drawn on the stationery kit the Mail page already uses, it is a real sheet with a real
## margin rather than a translucent list of Labels, and it can be closed with the pointer.

const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const PaperPaintScript := preload("res://ui/paper_paint.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")


func _letter() -> Dictionary:
	return {"sender": "Cloudsdale Weather Corporation", "title": "Your mailbox is installed",
		"body": ["Dear Moonbeam,", "", "The flag goes up when something is waiting.",
			"", "Warmly, Sponsorship Services"]}


func test_the_panel_reserves_a_sheet_tall_enough_for_the_letter_it_holds() -> void:
	_panel.open(_letter())
	var size: Vector2 = _panel.stage_size()
	assert_eq(size.x, LetterPanel.SHEET_WIDTH)
	assert_gte(size.y, 5.0 * LetterPanel.LINE_HEIGHT,
		"five lines of body need five lines of room")


func test_a_longer_letter_reserves_a_taller_sheet() -> void:
	_panel.open(_letter())
	var short_height: float = _panel.stage_size().y
	_panel.close()
	var long_letter: Dictionary = _letter()
	for i in 10:
		(long_letter["body"] as Array).append("Another line entirely.")
	_panel.open(long_letter)
	assert_gt(_panel.stage_size().y, short_height,
		"the sheet grows with the letter rather than clipping it")


func test_the_panel_wears_the_paper_box_rather_than_the_navy_one() -> void:
	var panel := _panel.get_node("Centre/Panel") as PanelContainer
	var box: StyleBoxFlat = panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(box.bg_color, MenuStyleScript.COLOR_PAPER,
		"a letter is paper, not a menu panel")


func test_painting_the_sheet_reaches_the_stationery_kit_without_an_error() -> void:
	_panel.open(_letter())
	var probe := Control.new()
	probe.size = _panel.stage_size()
	add_child_autofree(probe)
	_panel.paint(probe)
	assert_true(true, "paint() ran over a real Control with no error")


func test_the_letter_offers_the_pointer_a_way_out() -> void:
	var button: Button = _panel.close_button_node()
	assert_not_null(button)
	assert_eq(button.text, MouseRowsScript.CLOSE_TEXT)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	_panel.open(_letter())
	button.pressed.emit()
	assert_false(_panel.is_open())


func test_the_dim_behind_the_letter_swallows_stray_clicks() -> void:
	var dim := _panel.get_node("Dim") as Control
	assert_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_the_key_that_closed_it_still_closes_it() -> void:
	_panel.open(_letter())
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_panel._unhandled_input(event)
	assert_false(_panel.is_open(), "the mouse was added, the key was not taken")
```

If `game/test/test_letter_panel.gd` has no `_panel` fixture, add a `before_each()` that instantiates `res://ui/letter_panel.tscn` through `add_child_autofree()` and assigns it.

- [ ] **Step 2: Run them and watch them fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_letter_panel.gd -gexit
```
Expected: failures on `SHEET_WIDTH`, `stage_size`, `paint`, `close_button_node`.

- [ ] **Step 3: Give the scene a stage**

In `game/ui/letter_panel.tscn`, change the `Dim` node's `mouse_filter = 2` to `mouse_filter = 0`, and insert a `Stage` Control as the FIRST child of `Centre/Panel/Margin/Column`:

```
[node name="Stage" type="Control" parent="Centre/Panel/Margin/Column"]
layout_mode = 2
mouse_filter = 2
```

(The script sets its real filter and minimum size at run time; `2` in the file is only the inert default.)

- [ ] **Step 4: Restyle and rewire letter_panel.gd**

Add the preloads at the top of `game/ui/letter_panel.gd`:

```gdscript
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const PaperPaintScript := preload("res://ui/paper_paint.gd")
```

Add the constants below them:

```gdscript
## THE SHEET, IN 1920x1080 BASE PIXELS. The width is the Panel's existing 860 so nothing
## about where the letter sits on screen moves; the rest is what turns a column of Labels
## into a page: a margin the text does not touch, and a line height a letter breathes at.
const SHEET_WIDTH := 860.0
const LINE_HEIGHT := 26.0
const SHEET_MARGIN := 44.0

## The letterhead band at the top of the sheet, and the wax seal at the bottom of it.
const HEAD_HEIGHT := 76.0
const SEAL_SIZE := 46.0
```

Add the fields:

```gdscript
var _close: Button = null

@onready var _stage: Control = get_node_or_null(^"Centre/Panel/Margin/Column/Stage")
```

Replace `_ready()`:

```gdscript
func _ready() -> void:
	# THE PANEL IS PAPER NOW, NOT A MENU. MenuStyle.apply_panel() put the dark navy box
	# behind it, which is right for a list and wrong for a letter; the owner's word for the
	# result was "week". paper_box() is the same warm sheet game/ui/paper_paint.gd draws the
	# Mail page's stationery on, so the reader and the archive are made of one material.
	var panel := $Centre/Panel as PanelContainer
	panel.add_theme_stylebox_override(&"panel", MenuStyleScript.paper_box())
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if _stage != null:
		_stage.mouse_filter = Control.MOUSE_FILTER_STOP
		_stage.focus_mode = Control.FOCUS_NONE
		_stage.draw.connect(func() -> void: paint(_stage))
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
	$Centre/Panel/Margin/Column.add_child(_close)
	visible = false


func close_button_node() -> Button:
	return _close
```

Replace `refresh()`'s body with a version that keeps the Labels for the tests that read them but draws the page on the stage, and moves every text colour onto ink:

```gdscript
func refresh() -> void:
	if not is_node_ready():
		return
	_title.text = title_text()
	MenuStyleScript.style_label(_title, MenuStyleScript.TITLE_SIZE,
		MenuStyleScript.COLOR_INK)
	_title.add_theme_constant_override(&"outline_size", 0)
	_sender.text = sender_text()
	MenuStyleScript.style_label(_sender, MenuStyleScript.ROW_SIZE,
		MenuStyleScript.COLOR_INK)
	_sender.add_theme_constant_override(&"outline_size", 0)
	# THE FOOTER STILL PRINTS THE KEY. The mouse was added; the key hint stays, and it now
	# names the pointer's way out beside it.
	_footer.text = MenuStyleScript.footer([[&"ui_accept", "close"]])
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE,
		MenuStyleScript.COLOR_INK)
	_footer.add_theme_constant_override(&"outline_size", 0)
	for child in _rows.get_children():
		child.queue_free()
	for line in drawn_lines():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A BLANK LINE IS A BLANK LINE. Letters use them to break the body into paragraphs,
		# and a Label with an empty string collapses to nothing, which would close the gaps
		# the letter was written with. One space keeps the row at its font's height.
		label.text = line if not line.is_empty() else " "
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE,
			MenuStyleScript.COLOR_INK)
		label.add_theme_constant_override(&"outline_size", 0)
		_rows.add_child(label)
	if _stage != null:
		_stage.custom_minimum_size = stage_size()
		_stage.queue_redraw()
```

Append the drawing:

```gdscript
# --- the sheet ------------------------------------------------------------------------------
#
## THE PAGE IS DRAWN AND THE TEXT IS LAID OVER IT. game/ui/paper_paint.gd already knows how to
## draw a sheet with a drop shadow, a letterhead with the Company's cloud and bolt, and a wax
## seal; the Mail page in the pause menu has used it since the story slice. This is the same
## kit under the reader, so the letter she opens at the mailbox and the copy she re reads in
## the archive are made of the same paper.


## How tall a sheet this letter needs. Grows with the body rather than clipping it, which is
## the whole difference between a page and a text box.
func stage_size() -> Vector2:
	var lines: int = maxi(drawn_lines().size(), 1)
	return Vector2(SHEET_WIDTH,
		HEAD_HEIGHT + SHEET_MARGIN + float(lines) * LINE_HEIGHT + SEAL_SIZE + SHEET_MARGIN)


func paint(ci: Control) -> void:
	if ci == null:
		return
	var box := Rect2(Vector2.ZERO, ci.size)
	PaperPaintScript.sheet(ci, box)
	var font: Font = ThemeDB.fallback_font
	PaperPaintScript.letterhead(ci, Rect2(box.position.x + SHEET_MARGIN,
		box.position.y + SHEET_MARGIN * 0.4, box.size.x - SHEET_MARGIN * 2.0, HEAD_HEIGHT),
		font, sender_text())
	# THE SEAL SITS UNDER THE SIGN OFF, bottom right, where a seal goes.
	var seal := Rect2(box.size.x - SHEET_MARGIN - SEAL_SIZE,
		box.size.y - SHEET_MARGIN - SEAL_SIZE, SEAL_SIZE, SEAL_SIZE)
	ci.draw_circle(seal.get_center(), SEAL_SIZE * 0.5, PaperPaintScript.WAX)
	PaperPaintScript.logo_mark(ci, seal.grow(-SEAL_SIZE * 0.24),
		Color(1.0, 1.0, 1.0, 0.85), Color(1.0, 0.92, 0.55, 0.95))
```

- [ ] **Step 5: Add a mouse close to `_unhandled_input`**

Replace `_unhandled_input()` in `game/ui/letter_panel.gd` with:

```gdscript
## CONFIRM AND CANCEL BOTH CLOSE IT, and that is not laziness. There is nothing on this page
## to confirm, so a player who presses the confirm key on a letter she has finished reading
## means "done"; a page that answered that with silence would be the same class of dead
## control the race panel's old stake row was.
##
## AND SO DOES A CLICK ANYWHERE OFF THE SHEET, which is what a person does with a letter she
## has read. The Close button under the footer is the discoverable version of the same act.
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if MouseRowsScript.is_left_click(event):
		close()
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed():
		return
	if event.is_action(&"ui_accept") or event.is_action(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 6: Run the tests to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_letter_panel.gd -gexit
```
Expected: `---- All tests passed! ----`.

- [ ] **Step 7: Run the suite and the story and creation gates**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/story_test.tscn
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/creation_test.tscn
```
Expected: `---- All tests passed! ----`, `STORY_OK checks=55`, `CREATION_OK checks=93`.

- [ ] **Step 8: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/ui/letter_panel.gd game/ui/letter_panel.tscn game/test/test_letter_panel.gd
git commit -m "feat: the letter is a page on real paper"
```

---

### Task 7: The HUD card hides under overlays, and the toasts keep up

**Files:**
- Modify: `game/ui/hud.gd:174-176` (the toast constants), `:214-216` (the queue fields), `:266-276` (`_process`), `:290-293` (`_unhandled_input`), `:296-320` (`toast`, `_show_toast`), and append `set_overlay_open()`
- Modify: `game/world/ranch.gd:1326-1333` (`_on_menu_opened` / `_on_menu_closed`) and the letter panel wiring
- Test: `game/test/test_hud.gd` (extend)

**Interfaces:**
- Consumes: nothing from earlier tasks (this task is independent of the mouse kit and the theme).
- Produces, on `Hud`:
  - `const TOAST_HOLD_BUSY := 0.6`
  - `const TOAST_QUEUE_MAX := 3`
  - `func set_overlay_open(open: bool) -> void`
  - `func hints_visible() -> bool`
  - `func overlay_open() -> bool`
- Produces, on `Ranch`: `_on_menu_opened()` and `_on_menu_closed()` now call `hud.set_overlay_open(true/false)`; the letter panel's `opened` / `closed` reach the same pair.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_hud.gd`:

```gdscript
# --- the card, and the queue ------------------------------------------------------------

## THE BLEED THROUGH. The owner, on her first full playtest: the H control card showed
## through the letter she was reading. It is a PanelContainer on the HUD's own CanvasLayer,
## so anything drawn over the world is drawn over it too, and the fix is that the card is not
## on screen while an overlay is.
##
## HER TOGGLE IS REMEMBERED. A player who had the card up before opening a menu gets it back
## when she closes the menu; a player who had it down does not suddenly get it.

func test_an_overlay_hides_the_card_and_closing_the_overlay_gives_it_back() -> void:
	_hud.set_overlay_open(false)
	_hud._unhandled_input(_hints_key())
	assert_true(_hud.hints_visible(), "she asked for the card")
	_hud.set_overlay_open(true)
	assert_false(_hud.hints_visible(), "and it is gone while she reads a letter")
	assert_true(_hud.overlay_open())
	_hud.set_overlay_open(false)
	assert_true(_hud.hints_visible(), "and it comes back, because she had asked for it")


func test_an_overlay_does_not_conjure_a_card_she_never_asked_for() -> void:
	_hud.set_overlay_open(false)
	assert_false(_hud.hints_visible())
	_hud.set_overlay_open(true)
	_hud.set_overlay_open(false)
	assert_false(_hud.hints_visible())


func test_the_card_key_does_nothing_while_an_overlay_is_up() -> void:
	_hud.set_overlay_open(true)
	_hud._unhandled_input(_hints_key())
	assert_false(_hud.hints_visible(),
		"H under a letter would put the card straight back over it")


func _hints_key() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = Hud.HINTS_ACTION
	event.pressed = true
	return event


## THE TOAST LAG. The owner: "text on top lags behind". Three quick actions used to queue
## three full TOAST_HOLDs, so the third line arrived nine seconds after the thing it was
## about. A backed up queue now runs short.

func test_a_single_toast_gets_its_full_time() -> void:
	_hud.toast("Caught somebody!")
	_hud._process(0.0)
	assert_almost_eq(_hud.toast_seconds_left(), Hud.TOAST_HOLD + Hud.TOAST_FADE, 0.001)


func test_a_backed_up_toast_runs_short_so_the_queue_keeps_up() -> void:
	_hud.toast("one")
	_hud.toast("two")
	_hud._process(0.0)
	assert_lte(_hud.toast_seconds_left(), Hud.TOAST_HOLD_BUSY + Hud.TOAST_FADE,
		"a toast with somebody waiting behind it does not hold the full time")
	assert_eq(_hud.pending_toasts(), ["two"] as Array[String])


func test_the_queue_never_grows_past_its_cap_and_keeps_the_newest() -> void:
	for i in range(Hud.TOAST_QUEUE_MAX + 4):
		_hud.toast("line %d" % i)
	assert_lte(_hud.pending_toasts().size(), Hud.TOAST_QUEUE_MAX,
		"rapid play must not build a backlog nobody will read")
	assert_eq(_hud.pending_toasts().back(),
		"line %d" % (Hud.TOAST_QUEUE_MAX + 3),
		"the newest line is the one that matters")


func test_the_queue_drains_and_the_last_line_still_gets_shown() -> void:
	_hud.toast("one")
	_hud.toast("two")
	for i in range(200):
		_hud._process(0.05)
	assert_eq(_hud.pending_toasts(), [] as Array[String], "the queue emptied")
	assert_eq(_hud.toast_text(), "two", "and the last line was actually shown")
```

If `test_hud.gd` has no `_hud` fixture, add a `before_each()` that instantiates `res://ui/hud.tscn` through `add_child_autofree()`.

- [ ] **Step 2: Run them and watch them fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_hud.gd -gexit
```
Expected: failures on `set_overlay_open`, `hints_visible`, `overlay_open`, `toast_seconds_left`, `TOAST_HOLD_BUSY`, `TOAST_QUEUE_MAX`.

- [ ] **Step 3: The toast constants and fields**

In `game/ui/hud.gd`, replace the block at `:174-176` with:

```gdscript
## Seconds a toast holds at full opacity, and seconds it then takes to fade out.
const TOAST_HOLD := 2.4
const TOAST_FADE := 0.7

## WHAT A TOAST GETS WHEN SOMEBODY IS WAITING BEHIND IT. The owner, on the first full
## playtest: "text on top lags behind". Three quick actions queued three full holds, so the
## line about the third one arrived nine seconds after the thing it described and read as a
## bug in the game rather than in the overlay. A queue with anything in it now runs the
## current line short instead, so the text keeps pace with the play.
const TOAST_HOLD_BUSY := 0.6

## And a ceiling on the backlog itself. Past this the OLDEST waiting line is dropped, not the
## newest: nine seconds of stale news is worse than a line nobody read.
const TOAST_QUEUE_MAX := 3
```

Add beside `var _toast_queue: Array[String] = []`:

```gdscript
## Whether a letter or a menu is on screen right now, and whether the player had asked for
## the control card before one appeared. See set_overlay_open().
var _overlay_open := false
var _hints_wanted := false
```

- [ ] **Step 4: The toast behaviour**

In `_process()` (`game/ui/hud.gd:269-275`), replace the toast block with:

```gdscript
	if _toast_left > 0.0:
		# A LINE WITH SOMEBODY BEHIND IT RUNS SHORT. Applied here rather than in toast(),
		# because the queue can grow after the current line has already started, and the
		# player who just did three things quickly is the player this is for.
		if not _toast_queue.is_empty():
			_toast_left = minf(_toast_left, TOAST_HOLD_BUSY + TOAST_FADE)
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / TOAST_FADE, 0.0, 1.0)
		# The queue is drained here rather than on a timer, so a toast raised while the
		# world is paused still waits its turn rather than being written over.
		if _toast_left <= 0.0 and not _toast_queue.is_empty():
			_show_toast(_toast_queue.pop_front())
```

Replace `toast()` (`:310-314`) with:

```gdscript
func toast(text: String) -> void:
	if _toast_left > 0.0:
		_toast_queue.append(text)
		while _toast_queue.size() > TOAST_QUEUE_MAX:
			_toast_queue.pop_front()
		return
	_show_toast(text)
```

Append beside `toast_text()`:

```gdscript
## How long the line on screen has left, holding and fading together. For the tests, which
## otherwise have to infer the timer from an alpha.
func toast_seconds_left() -> float:
	return _toast_left
```

- [ ] **Step 5: The card**

Replace `_unhandled_input()` (`game/ui/hud.gd:290-293`) with:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(HINTS_ACTION):
		# H UNDER A LETTER WOULD PUT THE CARD STRAIGHT BACK OVER IT. The overlay owns the
		# screen while it is up; the key is remembered rather than refused, so the card she
		# asks for arrives the moment the letter closes.
		_hints_wanted = not _hints_wanted
		if not _overlay_open:
			_hints.visible = _hints_wanted
		get_viewport().set_input_as_handled()
```

Append beside the other public HUD methods:

```gdscript
## A LETTER OR A MENU IS ON SCREEN, OR IT IS NOT. The owner's playtest, on the welcome
## letter: the H control card bled through it. Every panel in this game is a CanvasLayer over
## the world and so is this overlay, so "over the world" was never going to be enough; the
## card has to be told.
##
## HER OWN TOGGLE IS REMEMBERED ACROSS THE OVERLAY. A player who had the card up gets it back
## when the letter closes; a player who did not is not handed one she never asked for.
func set_overlay_open(open: bool) -> void:
	_overlay_open = open
	if _hints != null:
		_hints.visible = _hints_wanted and not _overlay_open


func overlay_open() -> bool:
	return _overlay_open


func hints_visible() -> bool:
	return _hints != null and _hints.visible
```

In `_ready()`, after `_build_hints()`, add `_hints.visible = false` and `_hints_wanted = false` so the card's start state and the flag agree.

- [ ] **Step 6: Tell the HUD from the ranch**

In `game/world/ranch.gd`, replace `_on_menu_opened()` / `_on_menu_closed()` (`:1326-1333`) with:

```gdscript
func _on_menu_opened(_slot: PlotSlot) -> void:
	get_tree().paused = true
	_set_cursor_captured(false)
	_set_hud_overlay(true)


func _on_menu_closed() -> void:
	get_tree().paused = false
	_set_cursor_captured(true)
	_set_hud_overlay(false)


## THE CONTROL CARD IS NOT ON SCREEN WHILE ANYTHING IS OVER THE WORLD. See game/ui/hud.gd's
## set_overlay_open(). Guarded by has_method() like every other reach into a menu from here:
## a HUD whose script failed to parse is a FAILED check in _report(), not a crash on the
## first menu somebody opens.
func _set_hud_overlay(open: bool) -> void:
	var overlay := get_node_or_null(^"HUD")
	if overlay != null and overlay.has_method("set_overlay_open"):
		overlay.call("set_overlay_open", open)
```

The letter panel already emits `opened` and `closed` into `ranch.gd`'s shared handlers (see `letter_panel.gd`'s class comment); confirm that wiring routes to `_on_menu_opened_any` / `_on_menu_closed`, and if the letter panel is wired anywhere that bypasses them, route it through them so the card hides for a letter too. That bypass is the actual bug the owner saw.

- [ ] **Step 7: Run the tests to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_hud.gd -gexit
```
Expected: `---- All tests passed! ----`.

- [ ] **Step 8: Run the suite and the collection gate (it drives toasts hard)**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/collection_test.tscn
```
Expected: `---- All tests passed! ----` and `COLLECTION_OK checks=73`.

- [ ] **Step 9: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/ui/hud.gd game/world/ranch.gd game/test/test_hud.gd
git commit -m "fix: the control card stays out of the letter and the toasts keep up"
```

---

### Task 8: Character creation, rebuilt full-screen

**Files:**
- Create: `game/ui/swatch_grid.gd`
- Create: `game/ui/creation_backdrop.gd`
- Modify: `game/ui/creation_screen.gd` (whole file)
- Modify: `game/ui/creation_screen.tscn` (whole layout)
- Test: `game/test/test_swatch_grid.gd` (create), `game/test/test_creation_screen.gd` (extend)

**Interfaces:**
- Consumes: `MenuStyle.frame_box()`, `MenuStyle.paper_box()`, `MenuStyle.COLOR_TAB_ON`, `MenuStyle.COLOR_HOVER_BORDER` (Task 1); `MouseRows.close_button(...)`, `MouseRows.is_left_click(...)` (Task 2).
- Produces, on `SwatchGrid` (`class_name SwatchGrid extends GridContainer`, `res://ui/swatch_grid.gd`):
  - `signal picked(index: int)`
  - `func set_swatches(colours: Array[Color], labels: Array[String]) -> void` (an empty `labels` gives bare colour cells; a non-empty one gives labelled cards and must be the same length as `colours`)
  - `func set_selected(index: int) -> void`
  - `func selected() -> int`
  - `func cell(index: int) -> Button` (`null` out of range)
  - `func cell_count() -> int`
  - `const CELL_SIZE := Vector2(72.0, 72.0)`, `const CARD_SIZE := Vector2(168.0, 96.0)`
- Produces, on `CreationBackdrop` (`class_name CreationBackdrop extends Control`, `res://ui/creation_backdrop.gd`):
  - `const SKY_TOP: Color`, `const SKY_BOTTOM: Color`, `const CLOUD: Color`
  - `const CLOUDS: Array[Vector3]` (x fraction, y fraction, radius fraction, one entry per puff)
  - it paints itself in `_draw()`; nothing calls it
- Produces, on `CreationScreen` (all existing public methods kept exactly: `open`, `is_open`, `look`, `model`, `canvas`, `set_name_text`, `cycle_coat`, `cycle_mane`, `cycle_eyes`, `cycle_mane_style`, `stamp`, `set_ink`, `confirm`, `drawn_lines`, `ink_count`, `ink_at`, `ink_name`), plus:
  - `enum Step { LOOK, MARK }`
  - `func step() -> int`, `func set_step(value: int) -> void`
  - `func set_coat(index: int) -> void`, `func set_mane(index: int) -> void`, `func set_eyes(index: int) -> void`, `func set_mane_style(index: int) -> void`
  - `func raise_backdrop() -> void` (consumed by Task 9)
  - `func backdrop_only() -> bool`
  - `const DRAG_RADIANS_PER_PIXEL := 0.008`, `const AUTOSPIN_RESUME_SECONDS := 2.0`

- [ ] **Step 1: Write the failing swatch grid test**

Create `game/test/test_swatch_grid.gd`:

```gdscript
extends GutTest
## THE SWATCH GRID. The owner, on the old creation screen: "not industry standard ... for
## character creation". The tiny prev/next steppers are what she meant; this is what replaces
## them, and it is one widget used three times for colour and once for mane style cards.

const SwatchGridScript := preload("res://ui/swatch_grid.gd")

var _picked: Array[int] = []


func before_each() -> void:
	_picked = []


func _on_picked(index: int) -> void:
	_picked.append(index)


func _grid(colours: Array[Color], labels: Array[String] = [] as Array[String]) -> SwatchGrid:
	var grid: SwatchGrid = SwatchGridScript.new()
	add_child_autofree(grid)
	grid.picked.connect(_on_picked)
	grid.set_swatches(colours, labels)
	return grid


func test_a_grid_builds_one_cell_per_colour() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	assert_eq(grid.cell_count(), 3)
	for i in 3:
		assert_not_null(grid.cell(i), "cell %d" % i)
	assert_null(grid.cell(3), "out of range is null, not a crash")


func test_a_cell_is_a_real_button_that_never_takes_keyboard_focus() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN])
	assert_eq(grid.cell(0).focus_mode, Control.FOCUS_NONE,
		"the arrow keys belong to the creation screen's own cursor")


func test_clicking_a_cell_emits_its_index() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	grid.cell(2).pressed.emit()
	assert_eq(_picked, [2] as Array[int])


func test_the_selected_cell_is_outlined_and_the_others_are_not() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	grid.set_selected(1)
	assert_eq(grid.selected(), 1)
	var chosen: StyleBoxFlat = grid.cell(1).get_theme_stylebox(&"normal") as StyleBoxFlat
	var other: StyleBoxFlat = grid.cell(0).get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_gt(chosen.border_width_top, other.border_width_top,
		"a selected swatch has to be visibly selected")


func test_a_cell_carries_the_colour_it_stands_for() -> void:
	var grid: SwatchGrid = _grid([Color(0.2, 0.4, 0.6), Color(0.9, 0.1, 0.1)])
	var box: StyleBoxFlat = grid.cell(0).get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_eq(box.bg_color, Color(0.2, 0.4, 0.6),
		"a swatch that does not show its colour is a grey square")


func test_labels_turn_the_grid_into_cards_and_the_labels_are_the_button_text() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN],
		["Straight", "Curly"] as Array[String])
	assert_eq(grid.cell(0).text, "Straight")
	assert_eq(grid.cell(1).text, "Curly")
	assert_eq(grid.cell(0).custom_minimum_size, SwatchGridScript.CARD_SIZE)


func test_a_bare_grid_uses_the_swatch_size_and_carries_no_text() -> void:
	var grid: SwatchGrid = _grid([Color.RED])
	assert_eq(grid.cell(0).text, "")
	assert_eq(grid.cell(0).custom_minimum_size, SwatchGridScript.CELL_SIZE)


func test_rebuilding_a_grid_replaces_its_cells_rather_than_stacking_them() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	grid.set_swatches([Color.BLACK] as Array[Color], [] as Array[String])
	assert_eq(grid.cell_count(), 1, "a rebuilt grid is the new grid, not both")


func test_a_selection_out_of_range_wraps_rather_than_reading_off_the_end() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	grid.set_selected(4)
	assert_eq(grid.selected(), 1, "the palettes wrap and so does this")
	grid.set_selected(-1)
	assert_eq(grid.selected(), 2)


func test_an_empty_grid_is_empty_and_not_an_error() -> void:
	var grid: SwatchGrid = _grid([] as Array[Color])
	assert_eq(grid.cell_count(), 0)
	assert_eq(grid.selected(), 0)
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_swatch_grid.gd -gexit
```
Expected: the script is ignored or every test fails, because `res://ui/swatch_grid.gd` does not exist.

- [ ] **Step 3: Write the swatch grid**

Create `game/ui/swatch_grid.gd`:

```gdscript
class_name SwatchGrid
extends GridContainer
## THE ROW OF BIG SWATCHES THAT REPLACED THE TINY ARROWS. The owner, on the first full
## playtest: the creation screen is "not industry standard". The `<` and `>` steppers are the
## thing she meant. Every character creator worth the name shows the whole palette at once
## and lets a pointer land on the colour it wants.
##
## ONE WIDGET, TWO SHAPES. With no labels it is a grid of colour swatches (coat, mane, eyes);
## with labels it is a grid of cards (mane style). Two widgets that differed by whether a
## Button carried text would be one widget with extra steps.
##
## NOTHING HERE TAKES KEYBOARD FOCUS. game/ui/creation_screen.gd runs its own cursor over
## these rows, exactly as every menu in this game does, and a focusable Button would take the
## arrow keys off it. The mouse is added; the keyboard is not traded.
##
## NO RANDOMNESS ANYWHERE. game/test/test_menu_sound.gd sweeps game/ui/ for a generator and
## this file has none: the order of the cells is the order of the palette it was handed.

const MenuStyleScript := preload("res://ui/menu_style.gd")

signal picked(index: int)

## In 1920x1080 base pixels, the size the project's canvas_items stretch is measured against.
const CELL_SIZE := Vector2(72.0, 72.0)
const CARD_SIZE := Vector2(168.0, 96.0)

const CELL_RADIUS := 8
const IDLE_BORDER := 2
const CHOSEN_BORDER := 5

const DEFAULT_COLUMNS := 6

var _colours: Array[Color] = []
var _labels: Array[String] = []
var _cells: Array[Button] = []
var _selected := 0


func _ready() -> void:
	if columns <= 0:
		columns = DEFAULT_COLUMNS


## Rebuild the grid on `colours`. `labels` is either empty (bare swatches) or the same length
## as `colours` (cards). A mismatched length is treated as empty rather than as an error: a
## palette and a label list of different sizes is a caller bug, and a half labelled grid is a
## worse way to find out about it than an unlabelled one.
func set_swatches(colours: Array[Color], labels: Array[String]) -> void:
	_colours = colours.duplicate()
	_labels = labels.duplicate() if labels.size() == colours.size() else [] as Array[String]
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cells = []
	for i in _colours.size():
		var cell := Button.new()
		cell.focus_mode = Control.FOCUS_NONE
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.custom_minimum_size = CARD_SIZE if not _labels.is_empty() else CELL_SIZE
		cell.text = _labels[i] if not _labels.is_empty() else ""
		cell.clip_text = true
		var index := i
		cell.pressed.connect(func() -> void: picked.emit(index))
		_cells.append(cell)
		add_child(cell)
	_restyle()


func cell_count() -> int:
	return _cells.size()


func cell(index: int) -> Button:
	if index < 0 or index >= _cells.size():
		return null
	return _cells[index]


## Which cell is chosen. Wraps, exactly as StockPalette's own rows do and for the same
## reason: an off by one in a caller produces the wrong swatch rather than a read off the end.
func set_selected(index: int) -> void:
	if _colours.is_empty():
		_selected = 0
		return
	_selected = posmod(index, _colours.size())
	_restyle()


func selected() -> int:
	return _selected


## THE SWATCH IS ITS OWN COLOUR IN EVERY STATE, and the STATE is the border. A hover that
## changed the fill would change the colour the player is trying to judge, which is the one
## thing a swatch may never do.
func _restyle() -> void:
	for i in _cells.size():
		var chosen: bool = i == _selected
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = _colours[i]
			box.set_corner_radius_all(CELL_RADIUS)
			var border: int = CHOSEN_BORDER if chosen else IDLE_BORDER
			if state == &"hover" or state == &"pressed":
				border = maxi(border, CHOSEN_BORDER - 1)
			box.set_border_width_all(border)
			box.border_color = MenuStyleScript.COLOR_TAB_ON if chosen \
				else (MenuStyleScript.COLOR_HOVER_BORDER if state == &"hover" \
					else MenuStyleScript.ROW_IDLE_BORDER)
			_cells[i].add_theme_stylebox_override(state, box)
		MenuStyleScript.style_label_button(_cells[i])
```

Add the one helper this needs to `game/ui/menu_style.gd`, immediately above the `# --- the menu tick kit` banner:

```gdscript
## A BUTTON'S TEXT, OUTLINED THE WAY EVERY LABEL IN THIS GAME IS OUTLINED. The generated
## Theme sets this for every Button in the project; a Button carrying per state StyleBox
## overrides keeps the Theme's font settings, so this is belt and braces for the ones built
## in code before the tree hands them a theme.
static func style_label_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", ROW_SIZE)
	button.add_theme_color_override("font_color", COLOR_NAME)
	button.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	button.add_theme_constant_override("outline_size", OUTLINE_SIZE)
```

- [ ] **Step 4: Run the swatch grid test to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_swatch_grid.gd -gexit
```
Expected: `10/10 passed.`

- [ ] **Step 5: Write the backdrop**

Create `game/ui/creation_backdrop.gd`:

```gdscript
class_name CreationBackdrop
extends Control
## THE SKY BEHIND THE PONY, AND IT IS OPAQUE ON PURPOSE. The owner's first full playtest saw
## the ranch through the creation screen: a frame of raw map, the farmhouse clipping, a camera
## somewhere it should not have been. The screen is a stage now, and this is its backcloth.
##
## DRAWN RATHER THAN SOURCED. The MLP cloud sprites in assets-inbox are Source engine .vtf
## files and are not in game/assets/converted/; converting a sprite pack is R2's business, not
## R1's, and a full screen wash of sky with soft puffs on it is four draw calls. If R2 lands
## the cloud sprites, this Control is where they replace the puffs, and nothing above it moves.
##
## THE PUFFS ARE A CONSTANT TABLE, NOT A ROLL. No random number generator may live under
## game/ui/ (game/test/test_menu_sound.gd sweeps for one), and a backdrop that looked
## different every boot would be a backdrop nobody could screenshot twice.

const SKY_TOP := Color(0.38, 0.68, 0.95, 1.0)
const SKY_BOTTOM := Color(0.82, 0.92, 0.99, 1.0)
const GROUND := Color(0.52, 0.78, 0.44, 1.0)
const CLOUD := Color(1.0, 1.0, 1.0, 0.92)
const CLOUD_SHADE := Color(0.86, 0.91, 0.97, 0.92)

## Where the horizon sits, as a fraction of the height.
const HORIZON := 0.78

## One puff each: x fraction, y fraction, radius as a fraction of the WIDTH. Hand placed so
## the clusters read as three clouds rather than as nine circles.
const CLOUDS: Array[Vector3] = [
	Vector3(0.13, 0.18, 0.055), Vector3(0.18, 0.16, 0.070), Vector3(0.24, 0.19, 0.048),
	Vector3(0.62, 0.11, 0.046), Vector3(0.67, 0.09, 0.062), Vector3(0.72, 0.12, 0.040),
	Vector3(0.86, 0.31, 0.038), Vector3(0.90, 0.29, 0.052), Vector3(0.95, 0.32, 0.034),
]


func _ready() -> void:
	# OPAQUE AND FULL SCREEN. Nothing behind this may reach the player's eye.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var horizon: float = box.size.y * HORIZON
	# THE SKY, AS A VERTICAL GRADIENT, drawn as one polygon with per vertex colours rather
	# than as a stack of rectangles: one call, no banding.
	draw_polygon(
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(box.size.x, 0.0),
			Vector2(box.size.x, horizon), Vector2(0.0, horizon)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	draw_rect(Rect2(0.0, horizon, box.size.x, box.size.y - horizon), GROUND)
	for puff: Vector3 in CLOUDS:
		var centre := Vector2(puff.x * box.size.x, puff.y * box.size.y)
		var radius: float = puff.z * box.size.x
		draw_circle(centre + Vector2(0.0, radius * 0.18), radius, CLOUD_SHADE)
		draw_circle(centre, radius, CLOUD)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
```

- [ ] **Step 6: Write the failing creation screen tests**

Append to `game/test/test_creation_screen.gd`:

```gdscript
# --- the rebuilt screen -----------------------------------------------------------------

## THE OWNER'S TWO COMPLAINTS, PINNED. Acceptance item 1: "New save: no frame of raw world,
## CC full-screen, pony clearly visible." Acceptance item 2: "CC layout reads industry
## standard, mouse-driven."

const SwatchGridScript := preload("res://ui/swatch_grid.gd")
const CreationBackdropScript := preload("res://ui/creation_backdrop.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")


func test_the_backdrop_is_opaque_and_covers_the_whole_screen() -> void:
	var backdrop := _screen.get_node("Backdrop") as Control
	assert_true(backdrop is CreationBackdrop,
		"a Panel with a colour is not a show style stage")
	assert_eq(backdrop.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(backdrop.anchor_right, 1.0)
	assert_eq(backdrop.anchor_bottom, 1.0)


func test_the_backdrop_can_be_raised_before_the_rest_of_the_screen_exists() -> void:
	_screen.raise_backdrop()
	assert_true(_screen.visible, "the veil is up")
	assert_true(_screen.backdrop_only(), "and nothing else is showing yet")
	assert_false(_screen.is_open(), "raising the veil is not opening the screen")


func test_opening_over_a_raised_backdrop_shows_the_whole_screen() -> void:
	_screen.raise_backdrop()
	_screen.open(null)
	assert_true(_screen.is_open())
	assert_false(_screen.backdrop_only())


func test_the_turntable_fills_a_real_share_of_the_screen() -> void:
	var viewport := _screen.get_node("Layout/Stage/Viewport") as SubViewportContainer
	assert_gte(viewport.size_flags_stretch_ratio, 1.0,
		"the pony is the point of this screen and has to be big enough to see")


func test_the_three_colour_rows_are_swatch_grids_and_not_steppers() -> void:
	var checked := 0
	for name: String in ["CoatGrid", "ManeGrid", "EyesGrid"]:
		var grid := _screen.find_child(name, true, false)
		assert_true(grid is SwatchGrid, "%s is not a SwatchGrid" % name)
		assert_gt((grid as SwatchGrid).cell_count(), 1, "%s has a palette in it" % name)
		checked += 1
	assert_eq(checked, 3)


func test_the_mane_style_row_is_a_card_grid_carrying_the_style_names() -> void:
	var grid := _screen.find_child("ManeStyleGrid", true, false) as SwatchGrid
	assert_not_null(grid)
	assert_eq(grid.cell_count(), StockPalette.mane_style_count())
	assert_eq(grid.cell(0).text, StockPalette.mane_style_label(0))


func test_clicking_a_coat_swatch_sets_that_coat_on_the_look() -> void:
	var grid := _screen.find_child("CoatGrid", true, false) as SwatchGrid
	grid.cell(2).pressed.emit()
	assert_eq(_screen.look().coat, 2, "the swatch she clicked is the coat she gets")


func test_set_coat_and_cycle_coat_agree_so_the_gate_keeps_working() -> void:
	_screen.set_coat(0)
	_screen.cycle_coat(1)
	assert_eq(_screen.look().coat, 1,
		"scenes/test/creation_test.gd drives cycle_coat and must keep working")


func test_the_mark_canvas_is_its_own_step() -> void:
	assert_eq(_screen.step(), CreationScreen.Step.LOOK, "she meets her pony first")
	_screen.set_step(CreationScreen.Step.MARK)
	assert_eq(_screen.step(), CreationScreen.Step.MARK)
	assert_true(_screen.canvas().visible, "the canvas is on screen on its own step")


func test_dragging_the_turntable_turns_the_pony() -> void:
	_screen.open(null)
	var turntable := _screen.get_node("Layout/Stage/Viewport/SubViewport/Turntable") as Node3D
	var before: float = turntable.rotation.y
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(40.0, 0.0)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	_screen._on_stage_input(drag)
	assert_ne(turntable.rotation.y, before, "drag to rotate, on top of the auto spin")


func test_the_screen_offers_a_pointer_usable_confirm_and_close() -> void:
	assert_eq(_screen._confirm.focus_mode, Control.FOCUS_NONE)
	assert_false(_screen._confirm.text.is_empty())


func test_every_string_the_screen_draws_is_still_in_drawn_lines() -> void:
	var lines: Array[String] = _screen.drawn_lines()
	for text: String in [CreationScreen.TITLE, CreationScreen.NAME_LABEL,
			CreationScreen.COAT_LABEL, CreationScreen.MANE_LABEL,
			CreationScreen.MANE_STYLE_LABEL, CreationScreen.EYES_LABEL,
			CreationScreen.MARK_LABEL, CreationScreen.CONFIRM_LABEL,
			CreationScreen.STEP_LOOK_LABEL, CreationScreen.STEP_MARK_LABEL]:
		assert_true(text in lines, "'%s' is drawn but not declared" % text)


func test_nothing_the_rebuilt_screen_draws_carries_a_dash() -> void:
	var checked := 0
	for line: String in _screen.drawn_lines():
		assert_false(line.contains("--"), line)
		assert_false(line.contains(char(0x2014)), line)
		checked += 1
	assert_gt(checked, 0, "the copy list was actually walked")
```

- [ ] **Step 7: Rebuild the scene**

Rewrite `game/ui/creation_screen.tscn` around this tree. Keep the node names the tests and `creation_screen.gd` name; keep the `MarkCanvas` instance and the `SubViewport` contents (`WorldEnvironment`, `DirectionalLight3D`, `Camera3D`, `Turntable`) exactly as they are today, only reparented.

```
CreationScreen            CanvasLayer, layer 4, process_mode 3, script creation_screen.gd
  Backdrop                Control, script creation_backdrop.gd, anchors_preset 15
  Layout                  HBoxContainer, anchors_preset 15,
                          theme_override_constants/separation = 36
    Stage                 PanelContainer, size_flags_horizontal 3,
                          size_flags_stretch_ratio 1.0
      Viewport            SubViewportContainer, stretch = true,
                          size_flags_vertical 3, size_flags_stretch_ratio 1.0
        SubViewport       (moved unchanged, with WorldEnvironment,
                           DirectionalLight3D, Camera3D, Turntable)
    Panel                 PanelContainer, size_flags_horizontal 3,
                          size_flags_stretch_ratio 1.0
      Margin              MarginContainer, margins 30
        Column            VBoxContainer, separation 14
          Title           Label
          StepRow         HBoxContainer
            StepLook      Button
            StepMark      Button
          NameLabel       Label
          NameBox         LineEdit
          CoatLabel       Label
          CoatGrid        GridContainer, script swatch_grid.gd, columns 6
          ManeLabel       Label
          ManeGrid        GridContainer, script swatch_grid.gd, columns 6
          EyesLabel       Label
          EyesGrid        GridContainer, script swatch_grid.gd, columns 6
          ManeStyleLabel  Label
          ManeStyleGrid   GridContainer, script swatch_grid.gd, columns 3
          MarkLabel       Label
          MarkCanvas      (the existing instance, moved)
          HintLabel       Label
          InkRow          HBoxContainer with InkSwatch + Ink0..Ink5 (moved unchanged)
          StampRow        HBoxContainer with Stamp0..Stamp5 (moved unchanged)
          ToolRow         HBoxContainer with Brush1/2/4/8 + Eraser (moved unchanged)
          ActionRow       HBoxContainer with Undo + Clear (moved unchanged)
          Confirm         Button
```

`Stage` and `Panel` both take `size_flags_stretch_ratio = 1.0`, which is what makes the turntable fill the left half. Give `Stage` the wooden frame at run time (`MenuStyle.frame_box()`), `Panel` the paper box.

Delete `CoatRow`, `ManeRow`, `ManeStyleRow` and `EyesRow` and their eight `Prev*` / `Next*` Buttons: they are the steppers the redesign is removing. `_wire_controls()` loses those eight `_connect()` calls in the next step.

- [ ] **Step 8: Rewrite creation_screen.gd**

Make these changes to `game/ui/creation_screen.gd`:

1. Add the preloads:

```gdscript
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const SwatchGridScript := preload("res://ui/swatch_grid.gd")
```

2. Add the new copy and constants beside the existing ones:

```gdscript
enum Step { LOOK, MARK }

const STEP_LOOK_LABEL := "Your pony"
const STEP_MARK_LABEL := "Your cutie mark"

## Radians the turntable turns per pixel of horizontal drag, and how long after she lets go
## before the auto spin picks up again. The auto spin is what shows both flanks to a player
## who touches nothing; the drag is what a player who wants to look at the front expects.
const DRAG_RADIANS_PER_PIXEL := 0.008
const AUTOSPIN_RESUME_SECONDS := 2.0
```

3. Replace the `@onready` block's swatch and stepper references with the grids, and add the new nodes, all through `get_node_or_null` so a scene built by hand in a test is tolerated:

```gdscript
@onready var _backdrop: Control = get_node_or_null(^"Backdrop")
@onready var _layout: Control = get_node_or_null(^"Layout")
@onready var _turntable: Node3D = get_node_or_null(^"Layout/Stage/Viewport/SubViewport/Turntable")
@onready var _camera: Camera3D = get_node_or_null(^"Layout/Stage/Viewport/SubViewport/Camera3D")
@onready var _viewport: SubViewportContainer = get_node_or_null(^"Layout/Stage/Viewport")
@onready var _name_box: LineEdit = get_node_or_null(^"Layout/Panel/Margin/Column/NameBox")
@onready var _canvas: MarkCanvas = get_node_or_null(^"Layout/Panel/Margin/Column/MarkCanvas")
@onready var _confirm: Button = get_node_or_null(^"Layout/Panel/Margin/Column/Confirm")
@onready var _coat_grid: SwatchGrid = get_node_or_null(^"Layout/Panel/Margin/Column/CoatGrid")
@onready var _mane_grid: SwatchGrid = get_node_or_null(^"Layout/Panel/Margin/Column/ManeGrid")
@onready var _eyes_grid: SwatchGrid = get_node_or_null(^"Layout/Panel/Margin/Column/EyesGrid")
@onready var _mane_style_grid: SwatchGrid = get_node_or_null(
	^"Layout/Panel/Margin/Column/ManeStyleGrid")
```

Update every remaining `@onready` Label path from `Panel/Column/...` to `Layout/Panel/Margin/Column/...`, and update the `_wire_controls()` NodePaths (the ink, stamp, tool and action rows) the same way.

4. In `_ready()`, after the existing label assignments, add:

```gdscript
	MenuStyleScript.apply_panel_box(get_node_or_null(^"Layout/Panel") as PanelContainer,
		MenuStyleScript.paper_box())
	MenuStyleScript.apply_panel_box(get_node_or_null(^"Layout/Stage") as PanelContainer,
		MenuStyleScript.frame_box())
	_build_grids()
	_wire_steps()
	if _viewport != null:
		_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
		_viewport.focus_mode = Control.FOCUS_NONE
		_viewport.gui_input.connect(_on_stage_input)
	_confirm.focus_mode = Control.FOCUS_NONE
	set_step(Step.LOOK)
```

Add the one helper to `game/ui/menu_style.gd`, beside `apply_panel()`:

```gdscript
## apply_panel() with the box named rather than assumed. The letter and the creation screen
## are paper and wood; every list in the game is still the navy panel apply_panel() applies.
static func apply_panel_box(panel: PanelContainer, box: StyleBoxFlat) -> void:
	if panel == null or box == null:
		return
	panel.add_theme_stylebox_override(&"panel", box)
```

5. Add the grid construction and the absolute setters:

```gdscript
## THE PALETTE, ALL OF IT, ON SCREEN AT ONCE. This is the whole of what "industry standard"
## meant in the owner's note: she wants to see the colours, not click an arrow eleven times to
## find out what the eleventh one was.
func _build_grids() -> void:
	if _coat_grid != null:
		_coat_grid.set_swatches(_palette.coats, [] as Array[String])
		_coat_grid.picked.connect(set_coat)
	if _mane_grid != null:
		_mane_grid.set_swatches(_palette.manes, [] as Array[String])
		_mane_grid.picked.connect(set_mane)
	if _eyes_grid != null:
		_eyes_grid.set_swatches(_palette.eyes, [] as Array[String])
		_eyes_grid.picked.connect(set_eyes)
	if _mane_style_grid != null:
		var swatches: Array[Color] = []
		var labels: Array[String] = []
		for i in StockPaletteScript.mane_style_count():
			# THE CARD IS TINTED BY THE MANE COLOUR SHE IS ON, so the cards read as manes
			# rather than as four identical grey buttons with words on them.
			swatches.append(_palette.mane_at(_look.mane if _look != null else 0))
			labels.append(StockPaletteScript.mane_style_label(i))
		_mane_style_grid.set_swatches(swatches, labels)
		_mane_style_grid.picked.connect(set_mane_style)


## THE FOUR ABSOLUTE SETTERS THE GRIDS CALL. cycle_*() stays and is now written in terms of
## these: game/scenes/test/creation_test.gd and game/test/test_creation_screen.gd both drive
## the cycles, and this slice does not get to break the gate that proves a swatch on the
## screen lands the colour StockPalette says it should.
func set_coat(index: int) -> void:
	_look.coat = posmod(index, maxi(1, _palette.coats.size()))
	_restyle()
	_refresh_swatches()


func set_mane(index: int) -> void:
	_look.mane = posmod(index, maxi(1, _palette.manes.size()))
	_restyle()
	_refresh_swatches()


func set_eyes(index: int) -> void:
	_look.eyes = posmod(index, maxi(1, _palette.eyes.size()))
	_restyle()
	_refresh_swatches()


## THE ONE ROW THAT IS NOT A TINT: a different mesh, so the pony on the turntable is rebuilt.
func set_mane_style(index: int) -> void:
	_look.mane_style = posmod(index, maxi(1, StockPaletteScript.mane_style_count()))
	_build_model()
	_restyle()
	_refresh_swatches()


func cycle_coat(step: int) -> void:
	set_coat(_look.coat + step)


func cycle_mane(step: int) -> void:
	set_mane(_look.mane + step)


func cycle_eyes(step: int) -> void:
	set_eyes(_look.eyes + step)


func cycle_mane_style(step: int) -> void:
	set_mane_style(_look.mane_style + step)
```

6. Replace `_refresh_swatches()` with a version that pushes the selection into the grids:

```gdscript
## The current pick on each row, shown as the outlined cell in its own grid. The turntable
## already shows the whole pony; this is how a choice reads before the pony has turned round.
func _refresh_swatches() -> void:
	if _coat_grid != null:
		_coat_grid.set_selected(_look.coat)
	if _mane_grid != null:
		_mane_grid.set_selected(_look.mane)
	if _eyes_grid != null:
		_eyes_grid.set_selected(_look.eyes)
	if _mane_style_grid != null:
		_mane_style_grid.set_selected(_look.mane_style)
```

7. Add the steps, the veil and the drag:

```gdscript
var _step: int = Step.LOOK
var _backdrop_only := false
var _drag_rest := 0.0


func _wire_steps() -> void:
	for pair: Array in [[^"Layout/Panel/Margin/Column/StepRow/StepLook", Step.LOOK,
			STEP_LOOK_LABEL],
			[^"Layout/Panel/Margin/Column/StepRow/StepMark", Step.MARK, STEP_MARK_LABEL]]:
		var button := get_node_or_null(pair[0] as NodePath) as Button
		if button == null:
			continue
		button.text = String(pair[2])
		button.focus_mode = Control.FOCUS_NONE
		var target: int = int(pair[1])
		button.pressed.connect(func() -> void: set_step(target))


func step() -> int:
	return _step


## TWO STEPS, NOT ONE WALL OF CONTROLS. The old screen put a name box, four rows of steppers,
## a canvas, six inks, six stamps, four brushes and four buttons on one column, and the owner
## read that as cheap. Meeting the pony is one job; drawing her mark is another.
func set_step(value: int) -> void:
	_step = clampi(value, Step.LOOK, Step.MARK)
	var on_look: bool = _step == Step.LOOK
	for path: NodePath in [^"Layout/Panel/Margin/Column/CoatLabel",
			^"Layout/Panel/Margin/Column/CoatGrid",
			^"Layout/Panel/Margin/Column/ManeLabel",
			^"Layout/Panel/Margin/Column/ManeGrid",
			^"Layout/Panel/Margin/Column/EyesLabel",
			^"Layout/Panel/Margin/Column/EyesGrid",
			^"Layout/Panel/Margin/Column/ManeStyleLabel",
			^"Layout/Panel/Margin/Column/ManeStyleGrid",
			^"Layout/Panel/Margin/Column/NameLabel",
			^"Layout/Panel/Margin/Column/NameBox"]:
		var node := get_node_or_null(path) as Control
		if node != null:
			node.visible = on_look
	for path: NodePath in [^"Layout/Panel/Margin/Column/MarkLabel",
			^"Layout/Panel/Margin/Column/MarkCanvas",
			^"Layout/Panel/Margin/Column/HintLabel",
			^"Layout/Panel/Margin/Column/InkRow",
			^"Layout/Panel/Margin/Column/StampRow",
			^"Layout/Panel/Margin/Column/ToolRow",
			^"Layout/Panel/Margin/Column/ActionRow"]:
		var node := get_node_or_null(path) as Control
		if node != null:
			node.visible = not on_look
	MenuStyleScript.tick_page()


## THE VEIL, RAISED BEFORE THE WORLD HAS FINISHED BUILDING. Acceptance item 1: "New save: no
## frame of raw world". game/world/ranch.gd calls this at the top of its boot, long before
## open(); the sky goes up and the ranch builds behind it, invisibly.
##
## THE TREE IS NOT PAUSED HERE. Boot awaits physics frames (the warmup, the settle, the pen
## containment probe), and a paused tree never delivers one, so pausing here would hang the
## boot at the veil. open() pauses, exactly as it always has.
func raise_backdrop() -> void:
	visible = true
	_backdrop_only = true
	if _layout != null:
		_layout.visible = false
	if _backdrop != null:
		_backdrop.visible = true


func backdrop_only() -> bool:
	return _backdrop_only


## DRAG TO ROTATE, ON TOP OF THE AUTO SPIN. The pony keeps turning on her own so a player who
## touches nothing still sees both flanks and both cutie marks; a hand on her stops that for a
## couple of seconds so she can be held still and looked at.
func _on_stage_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or _turntable == null:
		return
	if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	_turntable.rotate_y(-motion.relative.x * DRAG_RADIANS_PER_PIXEL)
	_drag_rest = AUTOSPIN_RESUME_SECONDS
	if _viewport != null:
		_viewport.accept_event()
```

8. Replace `_process()`:

```gdscript
func _process(delta: float) -> void:
	if not _open or _turntable == null:
		return
	if _drag_rest > 0.0:
		_drag_rest -= delta
		return
	_turntable.rotate_y(deg_to_rad(TURN_DEGREES_PER_SECOND) * delta)
```

9. In `open()`, add after `visible = true`:

```gdscript
	_backdrop_only = false
	if _layout != null:
		_layout.visible = true
	_drag_rest = 0.0
	set_step(Step.LOOK)
```

and in `confirm()`, add `_backdrop_only = false` beside `visible = false`.

10. Extend `drawn_lines()` so the two step labels are declared:

```gdscript
	var lines: Array[String] = [TITLE, NAME_LABEL, COAT_LABEL, MANE_LABEL, MANE_STYLE_LABEL,
		EYES_LABEL, MARK_LABEL, CONFIRM_LABEL, HINT, STEP_LOOK_LABEL, STEP_MARK_LABEL]
```

11. Delete the eight `_connect()` calls for `PrevCoat`, `NextCoat`, `PrevMane`, `NextMane`, `PrevManeStyle`, `NextManeStyle`, `PrevEyes`, `NextEyes` from `_wire_controls()`. Keep every other `_connect()`, with its NodePath updated to the new `Layout/Panel/Margin/Column/...` prefix.

- [ ] **Step 9: Run the creation tests to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_creation_screen.gd -gexit
```
Expected: `---- All tests passed! ----`.

- [ ] **Step 10: Run the creation gate, which is the one that matters here**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/creation_test.tscn
```
Expected: `CREATION_OK checks=93`. RECONCILE against `docs/testing.md`.

The gate cycles each swatch row all the way round comparing the model's overrides against `StockTint.override_of()`; `cycle_*()` is now `set_*()` with a step added, so the arithmetic is unchanged. If the gate fails on the turntable holding no model, the `SubViewport` did not come across intact in Step 7.

- [ ] **Step 11: Look at it, because a number cannot say whether it reads as a stage**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" xvfb-run -a tools/bin/godot --path game \
  --audio-driver Dummy world/ranch.tscn --screenshot-dir=build/r1_shots
```
Then open `build/r1_shots/`. What to look for: the sky and clouds fill the frame with no ranch showing anywhere, the pony fills roughly the left half at a flattering angle, the palettes read as palettes, and the panel is warm paper inside a wooden frame. `build/` is gitignored; nothing here is committed.

Note: a screenshot run sets `_screenshot_dir`, so `_interactive` is false and `_maybe_open_creation()` does not fire. To see the screen, temporarily call `creation_screen.open(_game_state.player)` from a scratch edit, take the shot, and revert it before committing.

- [ ] **Step 12: Run the full suite**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
```
Expected: `---- All tests passed! ----`.

- [ ] **Step 13: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/ui/swatch_grid.gd game/ui/swatch_grid.gd.uid \
  game/ui/creation_backdrop.gd game/ui/creation_backdrop.gd.uid \
  game/ui/creation_screen.gd game/ui/creation_screen.tscn \
  game/ui/menu_style.gd game/test/test_swatch_grid.gd game/test/test_creation_screen.gd
git commit -m "feat: character creation is a stage with the whole palette on it"
```

---

### Task 9: The title screen, and a new game that never shows raw world

**Files:**
- Create: `game/world/boot_intent.gd`
- Create: `game/ui/title_screen.gd`, `game/ui/title_screen.tscn`
- Modify: `game/project.godot` (`run/main_scene`)
- Modify: `game/world/ranch.gd:885` (consume the latch, raise the veil) and `:1057-1080` (`_bind_game_state`)
- Modify: `docs/testing.md`, `docs/ci.md`
- Test: `game/test/test_boot_intent.gd` (create), `game/test/test_title_screen.gd` (create)

**Interfaces:**
- Consumes: `MouseRows.row(...)`, `MouseRows.CLOSE_TEXT` (Task 2); `MenuStyle.footer_rows(...)`, `MenuStyle.apply_title(...)`, `MenuStyle.tick_move/confirm/back/denied` (existing); `CreationScreen.raise_backdrop()` and `CreationScreen.backdrop_only()` (Task 8).
- Produces, on `BootIntent` (`class_name BootIntent extends RefCounted`, `res://world/boot_intent.gd`, static only):
  - `static func request_new_game() -> void`
  - `static func peek_new_game() -> bool`
  - `static func consume_new_game() -> bool`
  - `static func clear() -> void`
- Produces, on `TitleScreen` (`class_name TitleScreen extends Control`, `res://ui/title_screen.tscn`):
  - `enum Row { NEW_GAME, CONTINUE, SETTINGS, QUIT }`
  - `const ROWS: Array[String] = ["New game", "Continue", "Settings", "Quit"]`
  - `const WORLD_SCENE := "res://world/ranch.tscn"`
  - `func row_count() -> int`, `func selected_index() -> int`, `func move_selection(step: int) -> void`, `func confirm() -> bool`, `func point_at_row(index: int) -> void`, `func take_row(index: int) -> void`
  - `func can_continue() -> bool`
  - `func drawn_lines() -> Array[String]`
  - `static func is_interactive() -> bool`
- Produces, on `Ranch`: `func is_new_game() -> bool`

- [ ] **Step 1: Write the failing tests**

Create `game/test/test_boot_intent.gd`:

```gdscript
extends GutTest
## THE LATCH BETWEEN THE TITLE SCREEN AND THE RANCH. There is no field on GameState for this
## and there must not be: game/systems/ is read only for the whole presentation phase. A
## static on a script under game/world/ survives a change_scene_to_file() the same way, costs
## nothing, and is consumed exactly once.

const BootIntentScript := preload("res://world/boot_intent.gd")


func before_each() -> void:
	BootIntentScript.clear()


func after_each() -> void:
	BootIntentScript.clear()


func test_a_fresh_process_intends_nothing() -> void:
	assert_false(BootIntentScript.peek_new_game(),
		"a bare boot of ranch.tscn must behave exactly as it always has")


func test_requesting_a_new_game_is_visible_to_a_peek() -> void:
	BootIntentScript.request_new_game()
	assert_true(BootIntentScript.peek_new_game())
	assert_true(BootIntentScript.peek_new_game(), "peeking does not consume")


func test_consuming_answers_once_and_then_stops() -> void:
	BootIntentScript.request_new_game()
	assert_true(BootIntentScript.consume_new_game())
	assert_false(BootIntentScript.consume_new_game(),
		"a reloaded scene must not start a second new game")
	assert_false(BootIntentScript.peek_new_game())


func test_clear_forgets_a_request_nobody_consumed() -> void:
	BootIntentScript.request_new_game()
	BootIntentScript.clear()
	assert_false(BootIntentScript.peek_new_game())
```

Create `game/test/test_title_screen.gd`:

```gdscript
extends GutTest
## THE MAIN MENU. Spec section 10: a title screen was the one open question parked for the
## owner, assumed in scope unless vetoed. It is cheap once the Theme exists and it is where
## Continue and Quit belong.
##
## IT MUST NOT GET IN FRONT OF A GATE. Every gate in this project names its own scene on the
## command line, so only the default boot path moves; but the CI smoke run and the Windows
## export smoke run boot the binary with NO scene argument and expect RANCH_OK. So the title
## screen hands straight off to the ranch on any run that is not a person at a keyboard, and
## that is the single most load bearing claim in this file.

const TitleScreenScript := preload("res://ui/title_screen.gd")
const BootIntentScript := preload("res://world/boot_intent.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")

var _title: TitleScreen


func before_each() -> void:
	BootIntentScript.clear()
	_title = preload("res://ui/title_screen.tscn").instantiate()
	add_child_autofree(_title)


func after_each() -> void:
	BootIntentScript.clear()


func test_a_headless_run_is_not_interactive_and_so_never_sees_this_screen() -> void:
	assert_false(TitleScreenScript.is_interactive(),
		"the suite runs headless; a title screen in front of a gate is a hung gate")


func test_the_four_rows_are_the_four_rows() -> void:
	assert_eq(TitleScreen.ROWS, ["New game", "Continue", "Settings", "Quit"])
	assert_eq(TitleScreen.ROWS.size(), TitleScreen.Row.size())
	assert_eq(_title.row_count(), TitleScreen.ROWS.size())


func test_nothing_this_screen_draws_carries_a_dash() -> void:
	var checked := 0
	for line: String in _title.drawn_lines():
		assert_false(line.contains("--"), line)
		assert_false(line.contains(char(0x2014)), line)
		checked += 1
	assert_gt(checked, 0, "the copy list was actually walked")


func test_the_keyboard_walks_the_rows_and_wraps() -> void:
	_title.move_selection(1)
	assert_eq(_title.selected_index(), 1)
	_title.move_selection(-1)
	assert_eq(_title.selected_index(), 0)
	_title.move_selection(-1)
	assert_eq(_title.selected_index(), TitleScreen.ROWS.size() - 1, "it wraps")


func test_the_pointer_moves_the_same_cursor() -> void:
	_title.point_at_row(TitleScreen.Row.SETTINGS)
	assert_eq(_title.selected_index(), TitleScreen.Row.SETTINGS)
	_title.move_selection(1)
	assert_eq(_title.selected_index(), TitleScreen.Row.QUIT,
		"the mouse must never take the keyboard away")


func test_new_game_sets_the_latch() -> void:
	_title.point_at_row(TitleScreen.Row.NEW_GAME)
	_title.confirm()
	assert_true(BootIntentScript.peek_new_game(),
		"the ranch has to be told not to read the save")


func test_continue_is_refused_when_there_is_no_save_and_sets_no_latch() -> void:
	_title.has_save_provider = func() -> bool: return false
	assert_false(_title.can_continue())
	_title.point_at_row(TitleScreen.Row.CONTINUE)
	assert_false(_title.confirm(), "a Continue with nothing to continue must refuse")
	assert_false(BootIntentScript.peek_new_game(),
		"a refused Continue is not a new game")


func test_continue_is_offered_when_a_save_exists() -> void:
	_title.has_save_provider = func() -> bool: return true
	assert_true(_title.can_continue())


func test_the_settings_page_opens_and_leaves_again() -> void:
	_title.point_at_row(TitleScreen.Row.SETTINGS)
	_title.confirm()
	assert_true(_title.on_settings_page())
	_title.back()
	assert_false(_title.on_settings_page())
	assert_eq(_title.selected_index(), TitleScreen.Row.SETTINGS,
		"leaving a page puts the cursor back on the row that opened it")


func test_every_row_is_armed_for_the_pointer() -> void:
	var armed := 0
	for child in _title.get_node("Centre/Panel/Margin/Column/Rows").get_children():
		if MouseRowsScript.row_index(child as Control) >= 0:
			armed += 1
	assert_eq(armed, _title.row_count(),
		"every row the keyboard reaches, the mouse reaches")


func test_the_footer_still_prints_the_keys() -> void:
	var footer := _title.get_node("Centre/Panel/Margin/Column/Footer") as Label
	assert_false(footer.text.strip_edges().is_empty())
```

- [ ] **Step 2: Run them and watch them fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gdir=res://test -gprefix=test_boot -gexit
```
Expected: both scripts ignored or failing, because neither file exists.

- [ ] **Step 3: Write the latch**

Create `game/world/boot_intent.gd`:

```gdscript
class_name BootIntent
extends RefCounted
## WHAT THE TITLE SCREEN TOLD THE RANCH, AND NOTHING ELSE. A change_scene_to_file() hands the
## next scene nothing, and the obvious place for "she picked New game" is a field on the
## GameState autoload, which this phase may not touch: game/systems/ is read only for the
## whole presentation redesign except the two exemptions the spec names. A static var on a
## script under game/world/ lives exactly as long as the process, which is exactly as long as
## the handoff needs, and it is not in the save file, which is correct: an intent is about
## this launch, not about this ranch.
##
## FALSE IS THE DEFAULT AND THAT IS THE WHOLE SAFETY PROPERTY. Every gate, every screenshot
## run and every export smoke boots world/ranch.tscn directly and never touches this file, so
## they consume `false` and load the save exactly as they always have.
##
## CONSUMED ONCE. ranch.gd's _bind_game_state() takes it, and a reload_current_scene() (the
## pause menu's Load game row) must not then start a second new game on top of the load.
##
## Static only, no state beyond the latch, no scene. Preload by path.

static var _new_game := false


static func request_new_game() -> void:
	_new_game = true


## Is a new game intended, without taking the intent? For the boot veil, which has to know
## before _bind_game_state() has run.
static func peek_new_game() -> bool:
	return _new_game


static func consume_new_game() -> bool:
	var was: bool = _new_game
	_new_game = false
	return was


static func clear() -> void:
	_new_game = false
```

- [ ] **Step 4: Write the title screen scene**

Create `game/ui/title_screen.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://ui/title_screen.gd" id="1"]
[ext_resource type="Script" path="res://ui/creation_backdrop.gd" id="2"]

[node name="TitleScreen" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="Backdrop" type="Control" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("2")

[node name="Centre" type="CenterContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Panel" type="PanelContainer" parent="Centre"]
custom_minimum_size = Vector2(680, 0)
layout_mode = 2

[node name="Margin" type="MarginContainer" parent="Centre/Panel"]
layout_mode = 2
theme_override_constants/margin_left = 40
theme_override_constants/margin_top = 34
theme_override_constants/margin_right = 40
theme_override_constants/margin_bottom = 30

[node name="Column" type="VBoxContainer" parent="Centre/Panel/Margin"]
layout_mode = 2
theme_override_constants/separation = 14

[node name="Title" type="Label" parent="Centre/Panel/Margin/Column"]
layout_mode = 2

[node name="Rows" type="VBoxContainer" parent="Centre/Panel/Margin/Column"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Footer" type="Label" parent="Centre/Panel/Margin/Column"]
layout_mode = 2
```

Reusing `CreationBackdrop` here is deliberate: the title screen and the creation screen are the same stage, so the game opens on one sky and stays on it until the ranch is revealed.

- [ ] **Step 5: Write the title screen script**

Create `game/ui/title_screen.gd`:

```gdscript
class_name TitleScreen
extends Control
## WHERE THE GAME NOW OPENS. Spec section 10 parked this as an open question and assumed it in
## scope: the game booted straight into the world, which is not what any player expects and
## which left Continue and Quit with nowhere to live.
##
## IT MUST NEVER GET IN FRONT OF AN AUTOMATED RUN, AND THIS IS HOW. Every gate in this project
## names its own scene on the command line (docs/testing.md: `--path game
## scenes/test/<gate>.tscn`), so a changed main scene cannot reach them. What CAN reach them
## is the CI smoke run and the Windows export smoke run, which boot the binary with no scene
## argument at all and require a RANCH_OK line (.github/workflows/smoke_run.sh). So this
## screen asks the same question game/world/ranch.gd's own `_interactive` asks and, on any
## answer but "a person at a keyboard", changes straight to the ranch without touching the
## boot latch, which is byte for byte the behaviour those runs had before this slice.
##
## THE ROWS ARE DRAWN THE WAY EVERY LIST IN THIS GAME IS DRAWN: a caret, a highlight, and a
## footer that names the keys, with game/ui/mouse_rows.gd arming each row for the pointer.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const BootIntentScript := preload("res://world/boot_intent.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const SettingsScript := preload("res://systems/settings.gd")

enum Row { NEW_GAME, CONTINUE, SETTINGS, QUIT }

const ROWS: Array[String] = ["New game", "Continue", "Settings", "Quit"]

const TITLE := "Filly Rancher"
const SETTINGS_TITLE := "Settings"
const NO_SAVE_NOTE := "No saved ranch on this machine yet."

## The five settings rows, in SettingRow order. Same five the pause menu edits, because there
## is one Settings object and two doors into it.
enum SettingRow { VOLUME, AMBIENT, EFFECTS, SENSITIVITY, INVERT }

const SETTING_ROWS: Array[String] = ["Master volume", "Ambience", "Effects",
	"Mouse sensitivity", "Invert look"]

const WORLD_SCENE := "res://world/ranch.tscn"

## Injected by a test. Unset, the screen asks SaveIO itself, which is what the real boot does.
var has_save_provider := Callable()

var settings: Settings = null

var _selected := 0
var _hovered := -1
var _on_settings := false
var _return_row := 0

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


## The same question game/world/ranch.gd asks itself at boot, and it has to stay the same
## question: a headless run, or an offscreen capture run, is not a person choosing a menu row.
static func is_interactive() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot"):
			return false
	return true


func _ready() -> void:
	settings = SettingsScript.new()
	settings.load_from()
	settings.apply_audio()
	if not is_interactive():
		# STRAIGHT TO THE RANCH, and deliberately WITHOUT setting the boot latch, so the run
		# reads the save slot exactly as a bare boot of ranch.tscn always has. call_deferred
		# because a scene change inside _ready() is a change out from under the tree that is
		# still building this node.
		call_deferred("_enter_world")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func row_count() -> int:
	return SETTING_ROWS.size() if _on_settings else ROWS.size()


func selected_index() -> int:
	return _selected


func on_settings_page() -> bool:
	return _on_settings


func hovered_index() -> int:
	return _hovered


## Whether there is a ranch on disk to go back to.
func can_continue() -> bool:
	if has_save_provider.is_valid():
		return bool(has_save_provider.call())
	return SaveIOScript.has_slot(0)


func drawn_lines() -> Array[String]:
	var out: Array[String] = [TITLE, SETTINGS_TITLE, NO_SAVE_NOTE]
	out.append_array(ROWS)
	out.append_array(SETTING_ROWS)
	return out


func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		return
	_selected = posmod(_selected + step, n)
	MenuStyleScript.tick_move()
	_refresh()


func point_at_row(index: int) -> void:
	if index < 0 or index >= row_count():
		return
	if index == _selected and index == _hovered:
		return
	_hovered = index
	if index != _selected:
		_selected = index
		MenuStyleScript.tick_move()
	_refresh()


func take_row(index: int) -> void:
	point_at_row(index)
	if _selected == index:
		confirm()


func confirm() -> bool:
	if _on_settings:
		# Every settings row is adjusted with left and right, exactly as the pause menu's is;
		# confirm on one is a page turn back, which is what a player pressing Enter on a
		# slider means.
		back()
		return true
	match _selected:
		Row.NEW_GAME:
			MenuStyleScript.tick_confirm()
			BootIntentScript.request_new_game()
			_enter_world()
			return true
		Row.CONTINUE:
			if not can_continue():
				MenuStyleScript.tick_denied()
				return false
			MenuStyleScript.tick_confirm()
			_enter_world()
			return true
		Row.SETTINGS:
			MenuStyleScript.tick_page()
			_return_row = _selected
			_on_settings = true
			_selected = 0
			_refresh()
			return true
		Row.QUIT:
			MenuStyleScript.tick_back()
			get_tree().quit()
			return true
	return false


func back() -> void:
	if not _on_settings:
		return
	MenuStyleScript.tick_back()
	_on_settings = false
	_selected = _return_row
	_hovered = -1
	settings.save_to()
	_refresh()


## Left and right on a settings row, exactly as the pause menu does it, through the same
## Settings object's own step methods so there is one place a volume step is decided.
func adjust(direction: int) -> void:
	if not _on_settings or settings == null:
		return
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
	settings.apply_audio()
	MenuStyleScript.tick_move()
	_refresh()


func _enter_world() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _setting_value(index: int) -> String:
	if settings == null:
		return ""
	match index:
		SettingRow.VOLUME:
			return "%d%%" % roundi(settings.master_volume * 100.0)
		SettingRow.AMBIENT:
			return "%d%%" % roundi(settings.ambient_volume * 100.0)
		SettingRow.EFFECTS:
			return "%d%%" % roundi(settings.effects_volume * 100.0)
		SettingRow.SENSITIVITY:
			return "%.4f" % settings.mouse_sensitivity
		SettingRow.INVERT:
			return "on" if settings.invert_look else "off"
	return ""


func _refresh() -> void:
	if not is_node_ready():
		return
	_title.text = SETTINGS_TITLE if _on_settings else TITLE
	MenuStyleScript.apply_title(_title)
	_footer.text = MenuStyleScript.footer_rows("choose", "back") if _on_settings \
		else MenuStyleScript.footer_rows("choose", "quit")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE,
		MenuStyleScript.COLOR_DIM)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var names: Array[String] = SETTING_ROWS if _on_settings else ROWS
	for i in names.size():
		var picked: bool = i == _selected
		var holder: PanelContainer = MouseRowsScript.row(i, picked, i == _hovered,
			point_at_row, take_row)
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = MenuStyleScript.caret(picked) + names[i]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# A CONTINUE WITH NOTHING TO CONTINUE READS AS UNAVAILABLE rather than as broken.
		var dimmed: bool = not _on_settings and i == Row.CONTINUE and not can_continue()
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE,
			MenuStyleScript.COLOR_UNAFFORDABLE if dimmed \
				else (MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME))
		line.add_child(label)
		var value: String = _setting_value(i) if _on_settings \
			else (NO_SAVE_NOTE if dimmed else "")
		if not value.is_empty():
			var val := Label.new()
			val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			val.text = value
			MenuStyleScript.style_label(val, MenuStyleScript.SUBTITLE_SIZE,
				MenuStyleScript.COLOR_DIM)
			line.add_child(val)
		holder.add_child(line)
		_rows.add_child(holder)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event.is_action(&"ui_up"):
		move_selection(-1)
	elif event.is_action(&"ui_down"):
		move_selection(1)
	elif event.is_action(&"ui_left"):
		adjust(-1)
	elif event.is_action(&"ui_right"):
		adjust(1)
	elif event.is_action(&"ui_accept"):
		confirm()
	elif event.is_action(&"ui_cancel"):
		if _on_settings:
			back()
		else:
			get_tree().quit()
	else:
		return
	get_viewport().set_input_as_handled()
```

- [ ] **Step 6: Make it the boot scene**

In `game/project.godot`, change:

```
run/main_scene="res://world/ranch.tscn"
```

to:

```
run/main_scene="res://ui/title_screen.tscn"
```

- [ ] **Step 7: Consume the latch and raise the veil in ranch.gd**

In `game/world/ranch.gd`, add the preload beside the other consts at the top:

```gdscript
const BootIntentScript := preload("res://world/boot_intent.gd")
```

Add the field beside `_save_loaded`:

```gdscript
## Whether the title screen asked for a NEW game rather than a continued one. Consumed once,
## in _bind_game_state(). False for every gate, every screenshot run and every export smoke,
## because none of them goes through the title screen; see game/world/boot_intent.gd.
var _new_game := false
```

In `_bind_game_state()` (`game/world/ranch.gd:1069-1076`), replace the hosted branch with:

```gdscript
	# A HOSTED RANCH NEVER READS THE PLAYER'S SAVE. A gate has to reach the same verdict on
	# every machine, and whatever slot 0 happens to hold on this one is not that; nor is a
	# gate entitled to a real save file. Nothing is written back either: autosave is off for
	# every non-interactive run (see _interactive below).
	#
	# AND NEITHER DOES A NEW GAME. The title screen's New game row latches BootIntent, which
	# is consumed exactly here, so the creation screen opens over an empty ranch rather than
	# over the ranch she was already playing.
	_new_game = BootIntentScript.consume_new_game()
	if _hosted or _new_game:
		_game_state.reset()
		_save_loaded = false
	else:
		_save_loaded = _game_state.load_from_slot()
```

Immediately after the `_bind_game_state()` call in `_ready()` (`game/world/ranch.gd:885`), add:

```gdscript
	# NO FRAME OF RAW WORLD ON A NEW GAME. Acceptance item 1. Boot takes about two and a half
	# seconds from here (the physics warmup, the settle frames, the pen containment probe) and
	# every one of those frames used to be a frame of the map, the farmhouse and whatever the
	# camera happened to be inside. The creation screen's opaque backdrop goes up FIRST and
	# the world builds behind it; _maybe_open_creation() at the end of _ready() then fills in
	# the pony and the panel over a sky that has been there since the first frame.
	#
	# THE TREE IS NOT PAUSED HERE. The awaits below need physics frames and a paused tree
	# never delivers one. CreationScreen.open() pauses, as it always has.
	if _new_game and _interactive and creation_screen != null \
			and creation_screen.has_method("raise_backdrop"):
		creation_screen.call("raise_backdrop")
```

Append the reader:

```gdscript
## Whether this boot came through the title screen's New game row. For the gates and for
## game/test/test_ranch_creation.gd, which otherwise cannot tell a new ranch from a loaded one
## without reading a private field.
func is_new_game() -> bool:
	return _new_game
```

- [ ] **Step 8: Run the tests to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_boot_intent.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_title_screen.gd -gexit
```
Expected: `---- All tests passed! ----` on both.

- [ ] **Step 9: Prove the automated boot path is unchanged (the load bearing check)**

```bash
cd /home/admin/Documents/filly-rancher
# A bare boot, exactly as CI smoke and the Windows export smoke do it: no scene argument.
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --quit-after 600 --path game
```
Expected: `RANCH_OK ponies=49 props=111 assets=present` and exit 0, exactly as before this task. If the run hangs or prints nothing, `TitleScreen.is_interactive()` is answering wrongly under `--headless` and must be fixed before continuing; nothing else in this slice matters more.

Then prove every gate still names its own scene and so is untouched:

```bash
cd /home/admin/Documents/filly-rancher
for gate in market region world collection ledger depot creation casino story; do
  FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
    --path game "scenes/test/${gate}_test.tscn" | tail -1
done
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/sound_test.tscn | tail -1
```
Expected, one line each: `MARKET_OK checks=69`, `REGION_OK checks=49`, `WORLD_OK checks=32`, `COLLECTION_OK checks=73`, `LEDGER_OK checks=87`, `DEPOT_OK checks=72`, `CREATION_OK checks=93`, `CASINO_OK checks=76`, `STORY_OK checks=55`, `SOUND_OK ids=37`. RECONCILE against `docs/testing.md`.

- [ ] **Step 10: Write down what moved**

In `docs/testing.md`, add a section after "Running the suite":

```markdown
## The boot path, and why a title screen does not get in front of a gate

`game/project.godot`'s `run/main_scene` is `res://ui/title_screen.tscn` from R1 on.
Nothing about how gates are run changed, and it cannot have: **every gate names its
own scene on the command line**, for instance

```
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/story_test.tscn
```

so the main scene is never consulted for any of them. The pinned-hour and screenshot
runs name `world/ranch.tscn` explicitly for the same reason.

The one path that DOES consult it is a bare boot with no scene argument, which is what
`.github/workflows/smoke_run.sh` and the Windows export smoke do, and both require a
`RANCH_OK` line. `game/ui/title_screen.gd`'s `is_interactive()` asks exactly the
question `game/world/ranch.gd`'s own `_interactive` asks (not headless, and no
`--screenshot*` user arg) and, on any answer but "a person at a keyboard", changes
straight to `world/ranch.tscn` without setting the boot latch. So a bare headless boot
still prints `RANCH_OK`, and a bare interactive boot opens the main menu.

Prove it with:

```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --quit-after 600 --path game
```
```

In `docs/ci.md`, update the paragraph at section "and requires both" that says `RANCH_OK` is printed by "the main scene since Phase 1A Task 7": it is now printed by the scene the title screen hands off to on a non-interactive boot. Keep `MARKERS='RANCH_OK'` exactly as it is; the marker is unchanged and that is the point.

- [ ] **Step 11: Run the full suite**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
```
Expected: `---- All tests passed! ----`.

- [ ] **Step 12: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/world/boot_intent.gd game/world/boot_intent.gd.uid \
  game/ui/title_screen.gd game/ui/title_screen.gd.uid game/ui/title_screen.tscn \
  game/project.godot game/world/ranch.gd docs/testing.md docs/ci.md \
  game/test/test_boot_intent.gd game/test/test_title_screen.gd
git status --short   # confirm no title_screen.tscn.uid is staged
git commit -m "feat: the game opens on a title screen and never flashes the map"
```

---

### Task 10: Mail is read at the mailbox; the pause page is the archive

**Files:**
- Modify: `game/world/ranch.gd:1976-1988` (`open_mail_page`), `:4073-4075` (the `MAILBOX` branch of `perform_interaction`), and append `open_mailbox_letter()`
- Modify: `game/ui/pause_menu.gd:986-1008` (`_draw_mail`, `_mail_footer`) for the archive note
- Modify: `game/scenes/test/story_test.gd:315-340` (the mailbox checks)
- Modify: `docs/testing.md` (the story gate's check count)
- Test: `game/test/test_ranch_mail.gd` (extend)

**Interfaces:**
- Consumes: `LetterPanel.open(letter)`, `LetterPanel.is_open()` (Task 6); `PauseMenu.MAIN_ROWS[Row.MAIL] == "Saddlebag copies"` (Task 5).
- Produces, on `Ranch`:
  - `func open_mailbox_letter() -> bool` (the mailbox verb; opens the letter panel on the newest unread letter, falls back to the newest letter, routes a letter that asks a question to the archive page, toasts when the box is empty)
  - `func newest_unread_row() -> Dictionary` (the row `open_mailbox_letter()` chose, or `{}`)
  - `const MAILBOX_EMPTY_TOAST := "Nothing in the mailbox yet."`
- Produces, on `PauseMenu`: `const MAIL_ARCHIVE_NOTE: String`, printed at the top of the page.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_ranch_mail.gd`:

```gdscript
# --- the mailbox is where mail is read --------------------------------------------------

## THE OWNER, ON HER FIRST FULL PLAYTEST: "it says it's by my house but it's in the pause
## menu". The letter told her where her mailbox was and then the verb at the mailbox opened a
## menu page. The fiction is consistent from here: the mailbox opens the letter, and the pause
## page is the archive of what has already come.

func test_the_mailbox_opens_the_newest_unread_letter_in_the_reader() -> void:
	var row: Dictionary = _ranch.newest_unread_row()
	assert_false(row.is_empty(), "a fresh ranch has a letter waiting")
	assert_true(_ranch.open_mailbox_letter())
	assert_true(_ranch.letter_panel.is_open(), "the reader, not the menu page")
	assert_eq(_ranch.letter_panel.title_text(), String(row["title"]))


func test_reading_at_the_mailbox_marks_the_letter_read() -> void:
	var row: Dictionary = _ranch.newest_unread_row()
	_ranch.open_mailbox_letter()
	assert_true(_state.story.is_read(StringName(String(row["id"]))),
		"she read it; the flag comes down")


func test_a_second_visit_with_nothing_unread_re_reads_the_newest() -> void:
	_ranch.open_mailbox_letter()
	_ranch.letter_panel.close()
	assert_true(_ranch.newest_unread_row().is_empty(), "nothing unread now")
	assert_true(_ranch.open_mailbox_letter(),
		"a mailbox with post in it is never a dead key")
	assert_true(_ranch.letter_panel.is_open())


func test_an_empty_mailbox_says_so_rather_than_doing_nothing() -> void:
	_state.story.mail.clear()
	assert_false(_ranch.open_mailbox_letter())
	assert_false(_ranch.letter_panel.is_open())


func test_a_letter_that_asks_a_question_goes_to_the_page_that_can_answer_it() -> void:
	# The Survey carries a PICK_PONY reply control, and the reader is read only by design
	# (letter_panel.gd's class comment). So the one letter with a question in it opens where
	# the picker lives, and the fiction holds because that page is still her own mailbox.
	_state.story.post(&"weather_survey")
	_ranch.open_mailbox_letter()
	assert_true(_ranch.get_pause_menu().is_open(),
		"a letter with a reply opens the page that can take one")
	assert_eq(_ranch.get_pause_menu().open_letter_id(), &"weather_survey")


func test_the_archive_page_says_what_it_is() -> void:
	assert_eq(PauseMenu.MAIN_ROWS[PauseMenu.Row.MAIL], "Saddlebag copies")
	assert_false(PauseMenu.MAIL_ARCHIVE_NOTE.is_empty())
	assert_false(PauseMenu.MAIL_ARCHIVE_NOTE.contains("--"))
	assert_false(PauseMenu.MAIL_ARCHIVE_NOTE.contains(char(0x2014)))
```

- [ ] **Step 2: Run them and watch them fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_ranch_mail.gd -gexit
```
Expected: failures on `open_mailbox_letter`, `newest_unread_row`, `MAIL_ARCHIVE_NOTE`.

- [ ] **Step 3: Open the letter at the mailbox**

In `game/world/ranch.gd`, add the constant beside the other mailbox constants (near `const MAILBOX_RADIUS := 2.6`):

```gdscript
## What the mailbox says when there is genuinely nothing in it. A verb that does nothing at
## all reads as a broken key, which is the same defect the race panel's dead stake row was.
const MAILBOX_EMPTY_TOAST := "Nothing in the mailbox yet."
```

Replace the `MAILBOX` branch of `perform_interaction()` (`game/world/ranch.gd:4073-4075`) with:

```gdscript
		InteractionScript.Kind.MAILBOX:
			return open_mailbox_letter()
```

Append beside `open_mail_page()`:

```gdscript
## THE NEWEST LETTER SHE HAS NOT READ, or {} when she has read them all. mail_rows() is
## oldest first, so this walks backwards.
func newest_unread_row() -> Dictionary:
	var rows: Array[Dictionary] = mail_rows()
	for i in range(rows.size() - 1, -1, -1):
		if not bool(rows[i].get("read", false)):
			return rows[i]
	return {}


## E AT THE MAILBOX OPENS THE LETTER. The owner, on her first full playtest: "it says it's by
## my house but it's in the pause menu". The letter told her where her mailbox was and the
## verb at the mailbox then opened a menu, which is the whole of the confusion; the pause
## page is the archive now ("Saddlebag copies") and this is the mailbox.
##
## THE NEWEST UNREAD ONE, AND THE NEWEST ONE OTHERWISE. A mailbox with post in it is never a
## dead key: a player who has read everything and walks back to it gets the last letter again,
## which is what opening a real mailbox with a letter still in it does.
##
## A LETTER THAT ASKS A QUESTION GOES TO THE PAGE THAT CAN ANSWER IT. game/ui/letter_panel.gd
## is read only by design and says so at length in its own class comment; the Employee
## Appreciation Survey needs the PICK_PONY picker, which lives on the archive page. That page
## is still her own mailbox, so the fiction holds, and this slice does not rebuild the reader
## into a form that transacts.
func open_mailbox_letter() -> bool:
	var rows: Array[Dictionary] = mail_rows()
	if rows.is_empty():
		_toast(MAILBOX_EMPTY_TOAST)
		return false
	var row: Dictionary = newest_unread_row()
	if row.is_empty():
		row = rows[rows.size() - 1]
	var id := StringName(String(row.get("id", "")))
	if int(row.get("reply", 0)) != StoryBeatScript.Reply.NONE:
		open_mail_page()
		if pause_menu != null and pause_menu.has_method("open_letter"):
			pause_menu.call("open_letter", id)
		return true
	if letter_panel == null or not letter_panel.has_method("open"):
		return false
	var letter := {"sender": String(row.get("sender", "")),
		"title": String(row.get("title", "")), "body": row.get("body", [])}
	if not bool(letter_panel.call("open", letter)):
		return false
	_on_mail_opened(id)
	return true
```

If `ranch.gd` has no `_toast(text)` helper, use whatever it already calls to raise a toast (search for `hud.toast` and follow that call site); do not add a second path to the HUD.

- [ ] **Step 4: Label the archive**

In `game/ui/pause_menu.gd`, add beside `const MAIL_EMPTY_TEXT`:

```gdscript
## THE PAGE IS THE ARCHIVE NOW, AND IT SAYS SO. The originals are read at the mailbox by the
## door from R1 on; this is the drawer she keeps the copies in, which is why the row that
## opens it says "Saddlebag copies" rather than "Mail".
const MAIL_ARCHIVE_NOTE := "Copies of everything the Company has sent you. The originals are in the mailbox by your door."
```

In `_draw_mail()` (`game/ui/pause_menu.gd:986`), change the title line and add the note above the stage:

```gdscript
	_title.text = "SADDLEBAG COPIES"
	MenuStyleScript.apply_title(_title)
	_add_note(MAIL_ARCHIVE_NOTE)
```

`_add_note()` already exists and already prints into the Rows column above the stage; if the mail page currently clears that column, print the note first and then the stage, so the note is not lost.

- [ ] **Step 5: Update the story gate**

In `game/scenes/test/story_test.gd`, replace the two checks at `:326-329`:

```gdscript
	var action: Dictionary = ranch.current_interaction()
	_set_check("the verb at the mailbox is the mail",
		int(action.get("kind", -1)) == InteractionScript.Kind.MAILBOX)
	_set_check("pressing it opens the page", ranch.perform_interaction(action))
	_set_check("and the page is MAIL", menu.is_open() and menu.page() == PauseMenuScript.Page.MAIL)
```

with:

```gdscript
	var action: Dictionary = ranch.current_interaction()
	_set_check("the verb at the mailbox is the mail",
		int(action.get("kind", -1)) == InteractionScript.Kind.MAILBOX)
	var unread: Dictionary = ranch.newest_unread_row()
	_set_check("pressing it opens something", ranch.perform_interaction(action))
	# THE LETTER OPENS AT THE MAILBOX, NOT IN A MENU. The owner read "it says it's by my
	# house but it's in the pause menu" as a bug, and it was one.
	_set_check("and what opened is the reader",
		ranch.letter_panel != null and bool(ranch.letter_panel.call("is_open")))
	_set_check("holding the newest letter she had not read",
		unread.is_empty()
			or String(ranch.letter_panel.call("title_text")) == String(unread["title"]))
	_set_check("and reading it took the flag down",
		unread.is_empty() or state.story.is_read(StringName(String(unread["id"]))))
	ranch.letter_panel.call("close")
	# THE ARCHIVE IS STILL THERE AND STILL HOLDS EVERYTHING.
	ranch.open_mail_page()
	_set_check("the archive page is the pause menu's own",
		menu.is_open() and menu.page() == PauseMenuScript.Page.MAIL)
```

The gate gains three checks, so its marker moves from `checks=55` to `checks=58`. Update the expected number in `docs/testing.md`'s story gate section in this same commit.

Every line added to `story_test.gd` is swept for a dash by `game/test/test_story_corpus.gd`'s `test_no_line_of_the_gate_itself_carries_a_dash`, so use no `--` and no em dash in the new comments there.

- [ ] **Step 6: Run the tests and the story gate**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_ranch_mail.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/story_test.tscn
```
Expected: `---- All tests passed! ----` and `STORY_OK checks=58`.

- [ ] **Step 7: Run the full suite**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
```
Expected: `---- All tests passed! ----`.

- [ ] **Step 8: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/world/ranch.gd game/ui/pause_menu.gd game/scenes/test/story_test.gd \
  docs/testing.md game/test/test_ranch_mail.gd
git commit -m "feat: the mail is read at the mailbox and the menu keeps the copies"
```

---

### Task 11: The fifteen letters, rewritten

**Files:**
- Modify: all fifteen files in `game/data/story/`
- Test: `game/test/test_story_corpus.gd` (extend)

**Interfaces:**
- Consumes: nothing from earlier tasks. This task is independent and can run at any point after Task 10 (which changes where letters are read, not what they say).
- Produces: no new symbols. The fifteen `StoryBeat` resources keep their `id`, `chapter`, `trigger`, `threshold`, `sender`, `reveals`, `evidence` and `reply` fields exactly as they are; only `title` and `body` change.

**The checks that hold this copy, found in the source before writing a word.** There is no byte-identity assertion on any letter body anywhere in the suite. What there IS, and what this task must keep green, is:

| Check | Where | What it demands |
|---|---|---|
| `test_every_letter_fits_the_panel_with_the_longest_legal_name_in_it` | `game/test/test_story_corpus.gd` | Every rendered body line is at most `Letters.LINE_WIDTH` (58) with `{name}` at 16 W's, `{pony}`/`{chosen}` at 16 characters, `{colour}` = "viridian", `{count}` = 999, `{quota}` = 12, `{balance}` = 40000 |
| `test_no_beat_carries_an_em_dash_or_a_double_hyphen` | same | No `--` and no em dash in title or body |
| `test_no_beat_uses_the_word_this_project_does_not_use` | same | No "kill", "killed" or "dead" anywhere, case insensitive |
| `test_no_letter_renders_an_unfilled_placeholder` | same | Rendered with `{}`, no brace survives, so only `StoryBeat.DEFAULTS` keys (`name`, `pony`, `chosen`, `colour`, `count`, `quota`, `balance`) may appear |
| `test_every_beat_has_a_sender_a_title_and_a_body` | same | Sender and title non-empty, more than two body lines |
| `test_the_requisition_names_who_she_chose_and_the_receipts_name_who_was_delivered` | same | `weather_requisition` contains `{chosen}` and NOT `{pony}`; `weather_colour_receipt` and `sunny_named_thanks` contain `{pony}`; `weather_colour_receipt` contains `{colour}` |
| `test_the_corpus_is_not_empty_and_every_id_is_unique` | same | More than twelve beats, unique ids |
| The same structural half | `game/scenes/test/story_test.gd:110-120` | Repeats the fit, dash and roster checks against the real ranch |
| `_wire_mail()` fixtures | `game/test/test_pause_menu.gd:536-547` | Uses its OWN invented letter text, not the shipped copy, so it is unaffected |

Every replacement below was checked against all of those before being written into this plan.

- [ ] **Step 1: Write the failing test**

Append to `game/test/test_story_corpus.gd`:

```gdscript
## THE REWRITE, PINNED. The owner, on her first full playtest, called the letters' language
## "a bit weird". The register did not change (dark corporate cheer, an HR poster with the
## wrong number on it); the phrasing did. These are the lines that had to go, so that a later
## edit cannot quietly bring the clunky ones back.
func test_the_letters_no_longer_carry_the_phrasings_the_owner_flagged() -> void:
	# Every entry is a phrase that was actually in game/data/story/ before this task, checked
	# against the old files rather than guessed at, so this test failed before the rewrite and
	# passes after it.
	var banned: Array[String] = ["We put a lot of care into them",
		"as your balance will already have noticed", "ponies each period",
		"No action is required from you at all", "which is high praise from him",
		"and it is not a difficult one", "The bonuses on it are not small",
		"they think about where", "negligible and within", "from one ranch!"]
	var checked := 0
	for beat: StoryBeat in _library.all():
		var joined: String = "\n".join(beat.body_lines())
		for phrase: String in banned:
			assert_false(joined.contains(phrase),
				"%s still carries '%s'" % [beat.id, phrase])
		checked += 1
	assert_eq(checked, 15, "all fifteen letters were actually swept")


## EVERY LETTER IS SIGNED, and by a department rather than by a person. The joke only works
## if the Company is an organisation nobody in it is responsible to.
func test_every_letter_is_signed_off_by_a_department() -> void:
	var senders: Array[String] = ["Sponsorship Services", "Intake", "Partner Wellbeing",
		"Logistics", "Yield Assurance"]
	var checked := 0
	for beat: StoryBeat in _library.all():
		var last: String = beat.body_lines()[beat.body_lines().size() - 1]
		var signed := false
		for department: String in senders:
			if last.ends_with(department):
				signed = true
		assert_true(signed, "%s ends on '%s', which signs nothing" % [beat.id, last])
		checked += 1
	assert_eq(checked, 15)
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story_corpus.gd -gexit
```
Expected: `test_the_letters_no_longer_carry_the_phrasings_the_owner_flagged` fails naming several beats.

- [ ] **Step 3: Rewrite the SUNNY chapter, four letters**

In each file, replace ONLY the `title =` and `body =` lines. Leave `id`, `chapter`, `trigger`, `threshold`, `sender`, `reveals`, `evidence` and `reply` exactly as they are.

`game/data/story/sunny_mailbox.tres`:

```
title = "Your mailbox is installed"
body = PackedStringArray("Dear {name},", "", "Your ranch has a Company mailbox now, right by the", "door. Everything we send you lands in it: receipts,", "notices, and the odd questionnaire.", "", "The flag goes up when something is waiting. Do read", "them. We put a great deal of care into them.", "", "Warmly, Sponsorship Services")
```

`game/data/story/sunny_first_receipt.tres`:

```
title = "Thank you for your first shipment"
body = PackedStringArray("Dear {name},", "", "Your first shipment arrived safe and sound.", "Condition on arrival: excellent. Processing: routine.", "", "The credit is already on your balance, and we have", "made a small note in your file. A good one.", "", "Partners who ship early ship often.", "", "Warmly, Intake")
```

`game/data/story/sunny_named_thanks.tres`:

```
title = "A registered arrival, and our thanks"
body = PackedStringArray("Dear {name},", "", "{pony} arrived this morning and was logged", "as a registered arrival. What a find.", "", "Quality on arrival: excellent. A registered pony is", "worth a great deal more to us than unregistered", "stock, as your balance will have noticed.", "", "Do keep an eye out for more like her.", "", "Warmly, Intake")
```

`game/data/story/sunny_quota_note.tres`:

```
title = "Your first collection day"
body = PackedStringArray("Dear {name},", "", "Collection day has been and gone, and this period's", "upkeep is on your account.", "", "We expect {quota} ponies a period. Bits settle the", "service charges; the principal is settled in stock.", "It is all set out in the statement at the Depot.", "", "No pressure at all. Partners who meet quota sleep so", "much better.", "", "Yours in weather, Sponsorship Services")
```

- [ ] **Step 4: Rewrite the WEATHER chapter, seven letters**

`game/data/story/weather_survey.tres`:

```
title = "Employee Appreciation Survey"
body = PackedStringArray("Dear {name},", "", "You work very hard, and we do notice.", "", "One question, and it is not a hard one. Which of", "your ponies is the most special to you?", "", "Answer below and we will put 50 bits on your", "account, with a coupon for three bales of hay by way", "of thanks.", "", "Answering is entirely optional.", "", "With appreciation, Partner Wellbeing")
```

`game/data/story/weather_colour_receipt.tres`:

```
title = "Receipt: registered arrival"
body = PackedStringArray("Dear {name},", "", "Received, processed and filed, with thanks:", "", "   {pony} ...... {colour}", "", "The credit is on your balance. Our floor supervisor", "says she came out beautifully, which from him is", "high praise.", "", "Warmly, Intake")
```

`game/data/story/weather_quota_notice.tres`:

```
title = "A friendly reminder"
body = PackedStringArray("Dear {name},", "", "Ponies expected this period: {quota}.", "Ponies received this period: 0.", "Ponies processed this period: 3.", "", "Our figures balance, so there is nothing at all for", "you to do about this notice.", "", "Thank you for choosing Cloudsdale.", "", "Yours in weather, Sponsorship Services")
```

`game/data/story/weather_requisition.tres`:

```
title = "Priority Requisition"
body = PackedStringArray("Dear {name},", "", "Thank you for your survey response.", "", "{chosen} has been selected for priority", "handling. A collector will call at dawn and walk her", "over himself.", "", "The bonus schedule is attached, and it is generous.", "Nothing is required from you at all.", "", "Yours in weather, Logistics")
```

`game/data/story/weather_top_partner.tres`:

```
title = "Top of the board"
body = PackedStringArray("Dear {name},", "", "Three registered arrivals from one ranch.", "", "You are on the regional board this period, in gold", "lettering, above a photograph of the intake floor", "that we have cropped rather carefully.", "", "Keep going. The weather has never been better.", "", "Warmly, Sponsorship Services")
```

`game/data/story/weather_yield.tres`:

```
title = "Your quarterly performance summary"
body = PackedStringArray("Dear {name},", "", "Shipments received from your ranch: {count}.", "Yield: 94%. Spectra grade: A.", "Loss: negligible, and within guidance.", "", "We are not able to explain the yield figure in", "writing, but you may take it as a compliment.", "", "Weather across the region has never looked better,", "and a good deal of that is yours.", "", "Warmly, Yield Assurance")
```

`game/data/story/weather_wellbeing.tres`:

```
title = "Looking after yourself"
body = PackedStringArray("Dear {name},", "", "A note from Partner Wellbeing.", "", "Some partners tell us they wonder where the", "shipments go. We understand completely.", "", "The answer is weather. Rain for the orchards, storms", "for the reservoirs, rainbows for everypony. That is", "the whole of it.", "", "Sleep well. You have earned it.", "", "With appreciation, Partner Wellbeing")
```

- [ ] **Step 5: Rewrite the COMPANY chapter, four letters**

`game/data/story/company_promotion.tres`:

```
title = "A promotion, and our thanks"
body = PackedStringArray("Dear {name},", "", "Thank you for your report. The irregular employee", "has been processed and her access has been", "withdrawn.", "", "Please accept the enclosed promotion. Yield is up", "across the region this month, and we both know who", "to thank for that.", "", "Warmly, Sponsorship Services")
```

`game/data/story/company_grade_two.tres`:

```
title = "Grade two, and a warmer welcome"
body = PackedStringArray("Dear {name},", "", "Your account has been raised to grade two. Yield", "attributable to your ranch: 6%.", "", "Market discounts apply from today, and the Palace", "has been told to look after you.", "", "You are one of our very favourite partners.", "", "Warmly, Sponsorship Services")
```

`game/data/story/company_grade_three.tres`:

```
title = "Grade three, and a bounty list"
body = PackedStringArray("Dear {name},", "", "Grade three. Yield attributable: 11%.", "", "Enclosed: comps at the Palace, and a list of", "registered arrivals we would particularly like to", "see. The bonuses beside them are not small.", "", "We think of you as family, and we mean that in the", "way you would prefer.", "", "Warmly, Sponsorship Services")
```

`game/data/story/company_tour_invite.tres`:

```
title = "An invitation to the facility"
body = PackedStringArray("Dear {name},", "", "Grade four opens a door most partners never see. We", "would like to show you the facility.", "", "A guide will meet you at the Depot. The tour takes", "an hour and covers every room.", "", "Wear something warm. The intake floor runs cool, for", "reasons the guide will be happy to explain.", "", "Warmly, Sponsorship Services")
```

- [ ] **Step 6: Run the corpus test to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story_corpus.gd -gexit
```
Expected: `---- All tests passed! ----`. In particular `test_every_letter_fits_the_panel_with_the_longest_legal_name_in_it` must pass: the widest line above is `"Condition on arrival: excellent. Processing: routine."` at 52 characters, and the widest AFTER substitution is `"{pony} arrived this morning and was logged"` at 51.

- [ ] **Step 7: Run the story and creation gates**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/story_test.tscn
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/creation_test.tscn
```
Expected: `STORY_OK checks=58` (Task 10 raised it from 55) and `CREATION_OK checks=93`. The creation gate renders every `Letters` template at `PlayerLook.MAX_NAME_LENGTH` and checks the width, which is the same claim from the other side.

- [ ] **Step 8: Run the full suite**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh
```
Expected: `---- All tests passed! ----`.

- [ ] **Step 9: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git add game/data/story game/test/test_story_corpus.gd
git commit -m "feat: the company writes better letters"
```

---

### Task 12: The sound mix knobs, and the slice closed out

Spec section 6's final bullet rides in R1 because these are manifest edits and a default value, not code. `game/systems/sound.gd`'s logic is NOT touched: no `LIBRARY` entry is added, removed or re-pathed, no bed table is edited, `Sound.GAG_ID` is untouched, and no pony vocalization is introduced. Only `tools/sound_manifest.txt` recipe strings and one `settings.gd` default value change.

**Files:**
- Modify: `game/systems/settings.gd:22-28` (the Ambient default only)
- Modify: `tools/sound_manifest.txt` (nine recipe rows)
- Modify: `game/test/test_settings.gd:80` (the default the test asserts)
- Modify: `tools/run_tests.sh:186` (`MIN_TESTS`)
- Modify: `docs/testing.md` (the floor, and the gate check counts this slice moved)
- Test: `game/test/test_settings.gd` (extend)

**Interfaces:**
- Consumes: nothing. This task is independent of every other task in the slice and can be dispatched in parallel with any of them, except that its final steps (the gate sweep and the floor bump) must run last.
- Produces, on `Settings`: `const AMBIENT_DEFAULT := 0.5` and `var ambient_volume := AMBIENT_DEFAULT`.

- [ ] **Step 1: Write the failing test**

Append to `game/test/test_settings.gd`:

```gdscript
## THE AMBIENCE STARTS UNDER THE MIX. The owner, on her first full playtest: the beds are too
## loud. Spec section 6: "ambient beds down (start -6 dB on the Ambient bus default)".
##
## A DEFAULT, NOT A CEILING. The slider still reaches 100%; this is only where it starts, so a
## player who wants the dawn chorus at full can still have it and a player who never opens the
## settings page is not shouted at.
func test_the_ambient_bus_starts_six_decibels_down() -> void:
	var s: Settings = SettingsScript.new()
	assert_almost_eq(s.ambient_volume, Settings.AMBIENT_DEFAULT, 0.0001)
	assert_almost_eq(linear_to_db(Settings.AMBIENT_DEFAULT), -6.0, 0.1,
		"the default is six decibels down, measured rather than asserted")


func test_the_other_sliders_still_start_open() -> void:
	var s: Settings = SettingsScript.new()
	assert_almost_eq(s.master_volume, 1.0, 0.0001,
		"only the ambience moved; the master and the effects did not")
	assert_almost_eq(s.effects_volume, 1.0, 0.0001)


func test_a_saved_ambient_setting_still_wins_over_the_new_default() -> void:
	var path := "user://test_settings_ambient.cfg"
	var s: Settings = SettingsScript.new()
	s.ambient_volume = 1.0
	assert_true(s.save_to(path))
	var back: Settings = SettingsScript.new()
	back.load_from(path)
	assert_almost_eq(back.ambient_volume, 1.0, 0.0001,
		"a player who already turned it up keeps it turned up")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
```

Change the existing assertion at `game/test/test_settings.gd:80` from `assert_almost_eq(s.ambient_volume, 1.0, 0.0001)` to `assert_almost_eq(s.ambient_volume, Settings.AMBIENT_DEFAULT, 0.0001)`.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_settings.gd -gexit
```
Expected: failure on `AMBIENT_DEFAULT` being an unknown constant.

- [ ] **Step 3: Move the Ambient default**

In `game/systems/settings.gd`, replace lines 22-26 with:

```gdscript
var master_volume := 1.0

## THE AMBIENCE STARTS SIX DECIBELS DOWN. The owner, on the first full playtest: the beds sit
## on top of everything. linear_to_db(0.5) is -6.02, which is the number spec section 6 asks
## for, expressed as the linear the slider and the bus actually take.
##
## A DEFAULT AND NOT A CEILING: step_ambient() still walks the whole 0 to 1 range, and a
## settings.cfg that already carries a value keeps it, because load_from() defaults to the
## field rather than overwriting it.
const AMBIENT_DEFAULT := 0.5

## The two sub mixes, on the Ambient and Effects buses. The UI bus rides effects_volume:
## a fourth slider is knob clutter for a channel nobody wants louder than its own game.
var ambient_volume := AMBIENT_DEFAULT
var effects_volume := 1.0
```

- [ ] **Step 4: Run the settings test to green**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_SKIP_SWEEP=1 tools/bin/godot --headless \
  --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_settings.gd -gexit
```
Expected: `---- All tests passed! ----`.

- [ ] **Step 5: Soften the hoofsteps in the manifest**

The grass set is the loud one: `gain_db=20`, `21`, `13`, `13` on four turf strikes, with a 0.09 s tail. That is what "terrible footsteps" was. The takes themselves are the two softest turf recordings the archive has and their own comment names the only alternate as a troop of horses galloping, which is not a walk, so the fix is level and tail rather than a new source.

In `tools/sound_manifest.txt`, replace the four grass rows with:

```
world/hoofsteps_grass_1.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07024157.wav|rate=44100,mono,pick=4@-25:0.08,fade=0.003:0.14,gain_db=6
world/hoofsteps_grass_2.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07024157.wav|rate=44100,mono,pick=13@-25:0.08,fade=0.003:0.14,gain_db=7
world/hoofsteps_grass_3.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07024158.wav|rate=44100,mono,pick=4@-25:0.08,fade=0.003:0.14,gain_db=-1
world/hoofsteps_grass_4.wav|https://sound-effects-media.bbcrewind.co.uk/wav/07024158.wav|rate=44100,mono,pick=7@-25:0.08,fade=0.003:0.14,gain_db=-1
```

and append to the comment block above them:

```
# R1, 2026-09-04, owner's ear pass: "terrible footsteps". Every strike came down 14 dB
# (20/21/13/13 to 6/7/-1/-1, the relative balance between the four kept exactly) and the
# tail went from 0.09 to 0.14 s, which is what turns a click into a hoof on turf. The
# sources did not move: 07024157 and 07024158 are the two softest turf walks in the
# archive, and this row's own alternate, 07039304, is a troop of horses galloping, which
# is not a walk and is not softer.
```

Do the same 14 dB reduction on the hard set only if the owner also flags it; spec section 6 names grass and dirt, and the cobblestone set is already at `-8/13/6/-3`, which straddles zero.

- [ ] **Step 6: Turn the four parked knobs**

In `tools/sound_manifest.txt`:

**mail_open, up.** Change `gain_db=3` to `gain_db=4` on `world/mail_open.wav` and append to its comment:

```
# R1: walked one more step to 4. The row's own note above records +6 measuring TP=+0.4,
# well over the -1.5 dBTP ceiling, so 4 is the last step this near 0dBFS attack has. If
# the report FAILs on true peak at 4, put it back to 3 and take the balance out of
# mail_arrive instead, which is 15 LU above it and is the reason this one reads as quiet.
```

**mail_arrive, down, so the pair balances.** Change `gain_db=12` to `gain_db=7` on `world/mail_arrive.wav` and append to its comment:

```
# R1: down 5 dB. mail_open cannot come up past the true peak ceiling, so the 15 LU gap
# between the two is closed from this end. They are the same event a second apart.
```

**race_cheer, shorter.** Change the `world/race_cheer.wav` recipe from `rate=44100,mono,pick=1,fade=0.05:0.60,gain=-18` to `rate=44100,mono,trim=0-5.5,pick=1,fade=0.05:0.60,gain=-18` and append to its comment:

```
# R1: trimmed to the first 5.5 s of the take. The whole 12.8 s cheer outlasts the race it
# celebrates by about eight seconds, which is what made it read as a loop rather than as a
# result. trim runs before pick in the script's fixed order, so pick=1 now takes the first
# non silent segment inside that window.
```

**capture_charge, down.** Change `gain=-18` to `gain=-21` on `world/capture_charge.ogg` and append to its comment:

```
# R1: down 3 LU. This is a held loop under the beam rather than a one shot, so it sits
# under everything else in the world for as long as a capture takes; -18 put a generator
# hum on top of the game for four seconds at a time.
```

**The three casino pick floors.** Change `@-36` to `@-30` on `casino/reel_tick.wav`, `casino/reel_stop.wav` and `casino/wheel_ratchet.wav`. Raising the floor merges the quietest material into silence, which means the SEGMENT NUMBERING CHANGES and the existing deep indices (17, 112, 137) no longer name the same strikes. Re-derive each one:

1. Run the row with `--only` and read the segment count `tools/fetch_sounds.sh` reports for it.
2. Pick the index at the same fraction through the take the old index was: `new = roundi(old * new_count / old_count)`, clamped to at least 1.
3. Check the resulting duration in `game/assets/audio/sound_report.txt`. A segment under 0.03 s is a click, not a strike; step the index by one and try again.
4. If three tries do not land a segment between 0.03 s and 0.5 s that PASSes the report, put that row's floor back to `-36` with its original index and record in the comment that the knob was tried and reverted.

Append to each of those three rows' comments:

```
# R1: pick floor from -36 to -30. At -36 the detector was cutting on room tone, so the
# indices were deep into a list of near silent fragments; at -30 it cuts on real gaps
# between strikes. The index below was re-derived after the change, not carried over.
```

- [ ] **Step 7: Re-fetch exactly the rows that changed, and read the report**

```bash
cd /home/admin/Documents/filly-rancher
for dest in world/hoofsteps_grass_1.wav world/hoofsteps_grass_2.wav \
    world/hoofsteps_grass_3.wav world/hoofsteps_grass_4.wav \
    world/mail_open.wav world/mail_arrive.wav world/capture_charge.ogg \
    casino/race_cheer.wav casino/reel_tick.wav casino/reel_stop.wav \
    casino/wheel_ratchet.wav; do
  bash tools/fetch_sounds.sh --only "$dest" || echo "FAILED: $dest"
done
grep -E "hoofsteps_grass|mail_open|mail_arrive|capture_charge|race_cheer|reel_|wheel_ratchet" \
  game/assets/audio/sound_report.txt
```
Expected: every listed row reads `PASS`. A `FAIL` row exits the fetch script non zero and `game/test/test_sound_library.gd` asserts that every file the game plays appears in that report with `PASS`, so a `FAIL` must be resolved by moving the number, never by editing the report.

- [ ] **Step 8: Run the sound gate, and NEVER under xvfb**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/sound_test.tscn
```
Expected: `SOUND_OK ids=37`. The id count must not move: this task adds no `LIBRARY` entry and removes none. If it has moved, `sound.gd` was edited and must be reverted.

- [ ] **Step 9: Listen to it, because the gate cannot**

```bash
cd /home/admin/Documents/filly-rancher
ls -la game/assets/audio/world/hoofsteps_grass_*.wav game/assets/audio/casino/race_cheer.wav
```
Then play the four grass strikes and the cheer in whatever the machine has. What to listen for: a hoof on turf rather than a snap, four strikes that sit at the same level as each other, and a cheer that ends rather than fades out over the next race. This is the owner's ear pass; if a file still reads wrong, move its number in the manifest and re-run Step 7, never a number in `sound.gd`.

- [ ] **Step 10: Commit the sound work**

```bash
cd /home/admin/Documents/filly-rancher
git add game/systems/settings.gd tools/sound_manifest.txt game/test/test_settings.gd \
  game/assets/audio game/assets/audio/sound_report.txt
git commit -m "feat: the ambience sits down and the hoofsteps stop clicking"
```

- [ ] **Step 11: The whole gate sweep**

Every gate, in one pass, each with its own scratch save directory. The sound gate is deliberately NOT under xvfb; the gallery gate deliberately IS.

```bash
cd /home/admin/Documents/filly-rancher
set -e
for gate in market region world collection ledger depot creation casino story sound; do
  echo "== $gate =="
  FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
    --path game "scenes/test/${gate}_test.tscn" | tail -2
done
echo "== gallery (props) =="
FILLY_TEST_SAVE_DIR="$(mktemp -d)" xvfb-run -a tools/bin/godot --path game \
  --audio-driver Dummy scenes/test/model_gallery.tscn -- --props | tail -2
echo "== gallery (mark) =="
FILLY_TEST_SAVE_DIR="$(mktemp -d)" xvfb-run -a tools/bin/godot --path game \
  --audio-driver Dummy scenes/test/model_gallery.tscn -- --mark | tail -2
echo "== ranch census =="
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn | tail -2
echo "== bare boot, the CI smoke path =="
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy \
  --quit-after 600 --path game | grep RANCH_OK
```
Expected markers: `MARKET_OK checks=69`, `REGION_OK checks=49`, `WORLD_OK checks=32`, `COLLECTION_OK checks=73`, `LEDGER_OK checks=87`, `DEPOT_OK checks=72`, `CREATION_OK checks=93`, `CASINO_OK checks=76`, `STORY_OK checks=58` (raised from 55 by Task 10), `SOUND_OK ids=37`, `GALLERY_OK count=35`, `GALLERY_MARK_OK count=3`, `RANCH_OK ponies=49 props=111 assets=present`. RECONCILE every number against `docs/testing.md` first; only `STORY_OK` is expected to have moved in this slice.

- [ ] **Step 12: Prove the live saves were never touched**

```bash
cd /home/admin/Documents/filly-rancher
ls -la "$HOME/.local/share/godot/app_userdata/Filly Rancher/saves/" 2>/dev/null \
  | tee /tmp/saves_before.txt
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh >/dev/null
ls -la "$HOME/.local/share/godot/app_userdata/Filly Rancher/saves/" 2>/dev/null \
  | tee /tmp/saves_after.txt
diff /tmp/saves_before.txt /tmp/saves_after.txt && echo "SAVES UNTOUCHED"
```
Expected: `SAVES UNTOUCHED`. This is slice R0's interface doing its job; if the listings differ, stop and report it rather than continuing, because a gate in this slice is writing the owner's ranch.

- [ ] **Step 13: Bump the floor to the exact new count**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh 2>&1 | tee /tmp/suite.txt
grep -E "^Tests +[0-9]+" /tmp/suite.txt
```
Read the exact count off that line and set `MIN_TESTS` in `tools/run_tests.sh:186` to it:

```bash
MIN_TESTS="${FILLY_MIN_TESTS:-<the exact count>}"
```

RECONCILE: the value before this slice was `1412`. It must go UP, never down; if the number you read is lower than the value already in the file, tests have gone missing and that is the thing to fix.

- [ ] **Step 14: Prove the floor in both directions**

```bash
cd /home/admin/Documents/filly-rancher
# It passes at the new floor.
FILLY_TEST_SAVE_DIR="$(mktemp -d)" bash tools/run_tests.sh >/dev/null && echo "FLOOR HOLDS"
# And it genuinely fails one above it.
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_MIN_TESTS=99999 bash tools/run_tests.sh \
  >/dev/null 2>&1 || echo "FLOOR BITES"
```
Expected: `FLOOR HOLDS` then `FLOOR BITES`. A guard that only ever passes is not a guard; `docs/testing.md` records that both directions are proved whenever the floor moves.

- [ ] **Step 15: Update the docs**

In `docs/testing.md`:

- change the story gate section's `Expect STORY_OK checks=55` to `checks=58`, and add one sentence naming what the three new checks are (the letter opens in the reader at the mailbox, it is the newest unread one, and reading it takes the flag down)
- update the `MIN_TESTS` figure in the "And a floor on the test count" paragraph to the new value, and note in the same paragraph that it was raised by slice R1 and proved both ways
- add a line to the Files table for `game/ui/mouse_rows.gd` ("the mouse kit every menu's rows are armed through"), `game/ui/theme/filly_theme.tres` ("the generated Theme; regenerate with `bash tools/make_theme.sh`") and `game/scripts/make_theme.gd`

- [ ] **Step 16: Commit the close-out**

```bash
cd /home/admin/Documents/filly-rancher
git add tools/run_tests.sh docs/testing.md
git commit -m "chore: raise the test floor and record what r1 moved"
```

---

## Self-review

### Spec coverage

Spec section 8's acceptance list, item by item, against the task that answers it.

| # | Acceptance item | Task |
|---|---|---|
| 1 | New save: no frame of raw world, CC full-screen, pony clearly visible | 8 (full-screen rebuild, opaque backdrop, turntable at half the screen) + 9 (`BootIntent`, the veil raised before the world builds) |
| 2 | CC layout reads industry standard, mouse-driven | 8 (`SwatchGrid` palettes, mane style cards, two steps, drag to rotate, the steppers deleted) |
| 3 | Letter UI feels crafted; language natural; no card bleed-through | 6 (stationery sheet, wax seal, paper box) + 11 (the fifteen rewrites) + 7 (`Hud.set_overlay_open()`) |
| 5 | Every menu usable by mouse alone and keyboard alone | 2 (the kit) + 3 (four tables) + 4 (market, depot, build, lobby) + 5 (pause) + 6 (letter) + 8 (creation) + 9 (title) |
| 6 | Ambience sits under the mix, footsteps pleasant | 12 (Ambient default `-6.02 dB`, grass strikes down 14 dB with longer tails) |
| 7 (partial) | GUI reads crafted | 1 (one generated Theme installed project-wide, warm paper, wooden frames, hover/focus/pressed on Button, HSlider, TabBar and list rows). The world half of item 7 is R2's. |
| 10 | Mail read at the mailbox; pause page is the archive; "Save game" | 10 (`open_mailbox_letter()`, the archive note) + 5 (`Save game`, `Load game`, `Saddlebag copies`) |
| 11 | Toasts keep up with rapid play | 7 (`TOAST_HOLD_BUSY`, `TOAST_QUEUE_MAX`) |
| 13 | Casino UI keeps its crown and gains mouse play | 3 (rows armed, felt hit-tested, `CASINO_OK` held at its published count) |

Items 4, 8, 9 and 12 are R3 and R2 and are correctly absent. Spec section 10's parked title-screen question is answered by Task 9, which also documents why a changed `run/main_scene` cannot reach a gate. Spec section 4.1's "`mouse_filter = IGNORE` removed game-wide" is answered narrowly and deliberately: the `Dim` and `Stage` Controls that were swallowing clicks become `STOP` (Tasks 3, 4, 5, 6), row holders become `STOP` through `MouseRows.arm()`, and the Labels INSIDE those holders keep `IGNORE` because a Label that stopped the mouse would eat its own row's click. Spec 4.1's "the pause menu releases the mouse" was already true (`ranch.gd:1326-1333` frees the cursor on every menu open) and Task 5's test does not claim credit for it.

### Placeholder scan

No step says "TBD", "similar to Task N", "add appropriate X", "handle edge cases" or "write tests for the above". Every code step carries the code. Three steps deliberately instruct the implementer to READ before writing, and each names the exact function to read and forbids inventing a second copy of its numbers: Task 3 Step 5 (`LEVER_RECT`, `REEL_BAND`, `bet_rect()`, `row_rect()` must come out of each table's own `paint()`), Task 5 Step 4 (the envelope rects must match `_paint_envelopes()`), Task 10 Step 3 (`ranch.gd`'s existing toast call site). Task 12 Step 6's three casino floors carry a derivation procedure and an explicit revert condition rather than a guessed index, because the index genuinely cannot be known before the detector is re-run.

### Interface name consistency

Checked across tasks:

- `MouseRows.row(index, picked, hovered, on_hover, on_click)` is called with five arguments in Tasks 3, 4, 5 and 9, and is defined that way in Task 2.
- `MouseRows.close_button(label, on_click)` takes a `Callable` receiving an int; every call site passes `func(_index: int) -> void: close()`. `MouseRows.CLOSE_TEXT` is the label in Tasks 3, 4, 5, 6 and in the tests.
- `hovered_index()`, `point_at_row(index)`, `take_row(index)`, `close_button_node()` are the same four names on `TableMenu` (3), the four list menus (4), `PauseMenu` (5) and `TitleScreen` (9).
- `stage_hit_rects()` / `on_stage_hit(index)` is the same pair on `TableMenu` (3), `CasinoMenu` (4) and `PauseMenu` (5).
- `MenuStyle.paper_box()` and `MenuStyle.frame_box()` are defined in Task 1 and consumed in Tasks 6 and 8. `MenuStyle.apply_panel_box(panel, box)` and `MenuStyle.style_label_button(button)` are both defined in Task 8 at their first use.
- `CreationScreen.raise_backdrop()` and `backdrop_only()` are produced in Task 8 and consumed in Task 9.
- `BootIntent.request_new_game()` is called in Task 9's title screen; `BootIntent.consume_new_game()` in Task 9's `ranch.gd` edit; `peek_new_game()` and `clear()` only in the tests.
- `Ranch.newest_unread_row()` and `Ranch.open_mailbox_letter()` are produced in Task 10 and consumed by Task 10's own gate edit.
- `PauseMenu.Row.LOAD` and `has_save_provider` are produced in Task 5 and consumed by Task 5's `ranch.gd` edit; `TitleScreen.has_save_provider` is a separate field on a separate class with the same shape, which is deliberate.
- `Settings.AMBIENT_DEFAULT` is produced in Task 12 and consumed only there.
- `Hud.set_overlay_open(bool)` is produced in Task 7 and called from `Ranch._set_hud_overlay()` in the same task.

### Spec ambiguities resolved in this plan

1. **"The 15 authored letters in `story_library.gd`."** The letters are `.tres` `StoryBeat` resources under `game/data/story/` (there are exactly fifteen); `story_library.gd` only loads them. The rewrite therefore touches data, not `game/systems/`, and the read-only rule is kept intact. `game/systems/letters.gd`'s six stub templates (the welcome letter, the receipts, the quota reminder) are NOT rewritten this slice: they live in `game/systems/`, which is read-only.
2. **"STORY_OK's byte-identity checks."** There are none. What exists is a set of structural and placeholder checks, enumerated in Task 11's table with their file and function names, and they are what the rewrite is held to.
3. **"Save the ranch becomes Save game (and Load game)."** `Load game` needed a behaviour as well as a label; the pause menu emits `load_requested` and `ranch.gd` answers it with `reload_current_scene()` after unpausing, which re-runs the same `_bind_game_state()` a fresh boot runs. The row refuses with a soft tick when no save exists.
4. **The title screen versus the CI smoke run.** `.github/workflows/smoke_run.sh` and the Windows export smoke boot the binary with NO scene argument and require `RANCH_OK`, so a naive `run/main_scene` change would have failed CI silently at the first merge. `TitleScreen.is_interactive()` answers the same question `ranch.gd`'s `_interactive` answers and hands straight off to the ranch on any non-interactive boot, without setting the boot latch.
5. **The new-game latch.** `GameState` would be the natural home for "she picked New game" and `game/systems/` is read-only, so the latch is a static on a new `game/world/boot_intent.gd`, consumed exactly once, defaulting to false so no gate or screenshot run is affected.
6. **A letter that asks a question.** The letter panel is read-only by design; the Survey needs the `PICK_PONY` picker, which lives on the archive page. The mailbox verb therefore routes a letter with a non-`NONE` reply to that page and every other letter to the reader.
7. **The MLP cloud sprites for the creation backdrop.** They are Source engine `.vtf` files in `assets-inbox/` and are not in `game/assets/converted/`; converting a sprite pack is R2's work. Task 8 draws the sky and clouds instead, in a `Control` whose puff table is the single place R2 can swap in real sprites.
8. **"Footsteps replaced with softer grass/dirt samples."** No new BBC id is invented anywhere in this plan. The two turf takes already in the manifest are the softest walks the archive offers and the row's own recorded alternate is a troop of horses galloping, so the softening is done with level, tail and pick on the sourced takes, with the sources unchanged and the reasoning written into the manifest comment.
9. **`mouse_filter = IGNORE` removed "game-wide".** Read as "removed wherever it is what stops a click reaching a control": the `Dim` and `Stage` Controls and the row holders. Labels inside a row keep `IGNORE`, because a Label that stopped the mouse would swallow its own row's click, which would be the opposite of the spec's intent.
