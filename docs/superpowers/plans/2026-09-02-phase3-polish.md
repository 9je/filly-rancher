# Phase 3 Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the four casino games into drawn games instead of columns of text, get every piece of floating text out of the world except the two that belong on the Palace's boards, put one shared chrome over every menu in the game so the non casino panels come along for free, and give the map a look that is lit, graded, shadowed and textured rather than "default Godot cube on default Godot grass".

**Architecture:** Nothing here invents an engine. Every drawn thing is a `Control._draw()` callback through Godot's own `draw_*` calls, a `StyleBoxFlat`, a `Tween` and a `FontVariation`; there are no 2D art assets in this project and this slice acquires none. The casino gets one shared static drawing kit (`game/ui/casino_paint.gd`) split so that every glyph is a pure `*_points()` geometry function plus a three line `draw_*` half, which is what makes drawn art testable in a headless gate. Each menu gains ONE new scene node, a bare `Control` named `Stage`, painted by a `paint()` virtual on `table_menu.gd`; `drawn_lines()` survives untouched as every menu's semantic model, and the drawing is added BESIDE it rather than instead of it. Outcomes reach a stage by a push from `ranch.gd` beside the `show_result()` call it already makes, so the menu is still told what happened by the only thing allowed to decide it. On the world side the changes are Environment fields, light properties, material roughness, one small terrain shader and one node swap; no new node reaches the census.

**Tech Stack:** Godot 4.5.2, GDScript, GUT 9.5.0, Godot shading language (spatial), the project's headless gate conventions (`RANCH_OK`, `CASINO_OK`, `tools/run_tests.sh`).

**Spec:** `docs/superpowers/specs/2026-09-02-phase3-polish-design.md`. Read it in full before Task 1; it carries the survey this plan argues from and the seven decisions parked for the owner. The owner's directive it is held to, 2026-09-01: "i want a good polish update. I want the UI to be good. If theres not actual casino games in the UI i dont want it no text only bs. The floating text in game looks bad and graphics are lacking. I want strong polish and make the game actually look good rather than roblox".

## Global Constraints

- **No em dash and no double hyphen in any new line.** Not in a player facing string, not in code, not in a comment, not in a doc. CLI flags (`--headless`, `--screenshot-dir`, `--phase`) and `# --- banner ---` lines are exempt. Use ";" or ":" or commas. The files being edited are full of pre existing ` -- ` in their own comments: leave those alone and do not copy the habit into a line you write.
- **The menus draw and emit; `game/world/ranch.gd` transacts and owns pause.** Nothing under `game/ui/` may touch `Economy`, `Casino` or `GameState`. A stage may be TOLD an outcome; it may never compute one. Every new value a stage needs arrives through a `Callable` provider set by `ranch.gd` or through a push method `ranch.gd` calls, never through a lookup. `_on_menu_opened()` / `_on_menu_closed()` stay the one place `get_tree().paused` and the mouse cursor are toggled.
- **The math does not change. No rigging.** `Slots.STRIP_COUNTS`, `Slots.TRIPLE_PAYS`, `Wheel.NUMBER_PAYS_TO_ONE`, `Wheel.COLOUR_PAYS_TO_ONE`, `Blackjack.PUBLISHED_EDGE` and `RaceCard.TAKEOUT` do not move. Every published edge and every payout stays exactly as measured. `payout()` keeps its contract (chips handed back, THE STAKE INCLUDED, 0 for a loss). No `RandomNumberGenerator` may be constructed anywhere under `game/ui/`, and no `randi`/`randf` call may appear there; Task 1 adds the test that enforces it. Animation timings are constants, never rolled.
- **`drawn_lines()` survives as each menu's semantic model.** It is what `game/test/test_published_payouts.gd` parses the price back out of and what six menu test files read. A stage adds `printed_lines()` beside it to say which of those lines the `Rows` column still prints; it never replaces it.
- **Input parity.** Keyboard and gamepad drive every screen. A `_selected` cursor moved by `ui_up`/`ui_down`, tabs on `ui_left`/`ui_right`, `ui_accept` to confirm, `ui_cancel` to leave, all read in each menu's own `_unhandled_input()`. No mouse only affordance anywhere, no `grab_focus()`, no engine focus chain, and NO `Button` NODES. A drawn control is focusable only if the cursor can reach it.
- **The headless gates stay green.** `game/world/ranch.gd` prints `RANCH_OK ponies=49 props=110 assets=present` or `RANCH_FAILED`; `game/scenes/test/casino_test.gd` prints `CASINO_OK checks=<n>`. **`props=110`, not 60: the dressing slice merges to master before this branch is cut** (`docs/superpowers/plans/2026-09-01-phase3-dressing.md` Task 5 moves 94 to 110). Read the live number off the gate rather than trusting this line. Nothing in this slice may add a node that needs a GPU to exist, and every stage must instantiate and refresh in a headless run without drawing.
- **NO PONY EVER DIES.** Only `Pony._state_leaving` may call `queue_free()` on a pony. Nothing here frees, harms, moves or removes one. The race still runs `RaceRunner` stand ins and the entrant's pen body is still only hidden.
- **The census is untouched.** `ponies=` counts `spawner.get_spawned()`; `props=` is `Props.expected_count()` plus `$Buildings`'s child count. This slice adds nothing under `$Props` and nothing under `$Buildings`. The one node it replaces, `Buildings/Palace/Sign`, is a child of an existing building and moves neither number.
- **Preload by `res://` path, never by the global `class_name`,** in production code AND in test code. Every construction, static call and constant read goes through a `const XScript := preload("res://...")` at the top of the file. A bare `class_name` may appear ONLY as a type annotation.
- **Explicit type annotations wherever `:=` cannot infer the type.** Godot 4.5 promotes `INFERENCE_ON_VARIANT` to an error on the preload dependency compile path; GUT's loader does not catch it, `tools/run_tests.sh`'s parse sweep does. Every `Dictionary` read (`hand["player"]`, `entry.get("coat", ...)`) needs one.
- **Every new `.gd` gets its `.uid` sidecar committed.** After creating a script run `tools/bin/godot --headless --path game --import` once and `git add` the generated `game/**/*.gd.uid`.
- **Commit after every task with `git commit -F <file>`;** conventional prefixes (`feat:`, `fix:`, `test:`, `docs:`). Run `bash tools/run_tests.sh` (no `FILLY_SKIP_SWEEP`) before calling any task finished.
- **`MIN_TESTS` in `tools/run_tests.sh` is raised in the final task to the number the suite actually reports.** Never guess it. It stands today at whatever the dressing slice raised it to; read it off the suite's own `Tests` line with the `sed` given in Task 9.
- **Branch: `phase3-polish`,** cut from `master` after the dressing slice has merged.

---

## What is on master today

Read this before starting. Everything below was verified on `master` at `618126d`, with the dressing slice's own changes noted where they overlap.

**The menus.** Six `CanvasLayer` menus instanced into `game/world/ranch.tscn` and held by `@onready` vars on `ranch.gd`. `game/ui/table_menu.gd` (`class_name TableMenu extends CanvasLayer`, 256 lines) is the shared base for `slots_menu.gd`, `wheel_menu.gd` and `blackjack_menu.gd`, each of which `extends "res://ui/table_menu.gd"` by path. `race_menu.gd` is also a `TableMenu`; `casino_menu.gd` is not, but has the identical tree and the identical `refresh()` shape. That tree, verified identical in every table `.tscn`:

```
CanvasLayer (layer 2, process_mode 3 = PROCESS_MODE_ALWAYS)
  Dim            ColorRect, full rect, Color(0, 0, 0, 0.42), mouse_filter 2
  Centre         CenterContainer, full rect
    Panel        PanelContainer, custom_minimum_size Vector2(860, 0),
                 theme_override_styles/panel = StyleBoxFlat "MenuPanel"
      Margin     MarginContainer, 30 / 24 / 30 / 22
        Column   VBoxContainer, separation 10
          Title  Label
          Tabs   Label
          Rows   VBoxContainer, separation 8
          Footer Label
```

`TableMenu.refresh()` builds one bare `Label` per line of `drawn_lines()`, marks the caret line with `MenuStyle.CARET` (`"> "`) and swaps its colour from `COLOR_NAME` to `COLOR_VALUE`. There is no panel behind a row, no highlight and no geometry of any kind anywhere in the casino.

**`MenuPanel` is copy pasted into TEN `.tscn` files, not seven.** The spec says seven; `grep -l MenuPanel game/ui/*.tscn` finds `blackjack_menu`, `build_menu`, `casino_menu`, `depot_menu`, `letter_panel`, `market_menu`, `pause_menu`, `race_menu`, `slots_menu` and `wheel_menu`. Task 2 is written against the measured ten.

**`game/ui/menu_style.gd`** (118 lines, `class_name MenuStyle extends RefCounted`, static only) holds eleven colour constants, `TITLE_SIZE` 30, `ROW_SIZE` 22, `FOOTER_SIZE` 20, `CARET`/`NO_CARET`, `OUTLINE_COLOR` `Color(0, 0, 0, 0.75)` at `OUTLINE_SIZE` 5, `style_label()`, `caret()`, `tab_strip()` and four footer builders. `ROW_SELECTED_BG`, `ROW_SELECTED_BORDER`, `ROW_IDLE_BG` and `ROW_IDLE_BORDER` are declared and nothing reads them; that is defect two from the spec's survey.

**A third defect, found while planning and not in the spec.** `CasinoMenu.refresh()` styles its rows through `MenuStyle.style_label()` and therefore outlines them; `TableMenu.refresh()` only calls `add_theme_color_override("font_color", ...)`, so **every row on every table in the Palace ships with no outline at all**, over a translucent panel, which is exactly the readability failure `MenuStyle.OUTLINE_COLOR`'s own comment exists to prevent. `game/test/test_menu_style.gd`'s `test_a_real_panel_draws_its_rows_with_the_outline()` did not catch it because it opens `CasinoMenu`, the one panel that was doing it right. Task 2 fixes it and widens that test to a table.

**`WheelMenu.WHEEL_FOOTER`** is set in `_ready()` after `super._ready()` and overwritten by `refresh()` on every call, so it has never rendered. It hard codes `"Enter / A  confirm      Esc / B  leave"`, both input schemes at once, which is what `MenuStyle.footer()` exists to prevent. Defect one from the spec's survey; Task 5 deletes it.

**The systems, which do not move.** `Slots`: `Symbol { APPLE, HORSESHOE, BELL, GEM, STAR, RAINBOW }`, `REELS` 3, `REEL_SIZE` 16, `STRIP_COUNTS [5, 4, 3, 2, 1, 1]`, `strip() -> Array[int]` (16 entries, built from the counts), `paytable_lines()` (8 lines), `line_text(reels)`. `Wheel`: `Colour { RED, ORANGE, YELLOW, GREEN, BLUE, VIOLET, HOUSE }`, `NUMBERS` 24, `COLOUR_RUN` 4, `HOUSE_POCKET` 0, `POCKETS` 25, `colour_of(pocket)`, `COLOUR_NAMES`, `rules_lines()` (4 lines), `pocket_text(pocket)`. `Blackjack`: `RANKS` 13, `DECK_SIZE` 52, cards numbered 0 to 51, `card % RANKS` is the rank, rank 0 is an Ace, `RANK_NAMES`, `hand_total(cards)`, `play_hand(rng)` returning `{"player": Array[int], "dealer": Array[int], "outcome": int}`, `outcome_text(hand)`, `placard_lines()` (7 lines), `STRATEGY_DRAWS_BELOW` 17, `DEALER_STANDS_ON` 17. **`Blackjack` never names a suit.** `RaceCard`: `LANES` 6, `PLAYER_LANE` 0, `TAKEOUT` 0.06, `odds_text(odds)`.

**`Ranch`'s transactions,** all in `game/world/ranch.gd`: `play_slots(stake)` returns `{"ok", "reels": Array[int], "won", "stake"}`, `play_wheel(kind, guess, stake)` returns `{"ok", "pocket", "won", "stake"}`, `play_blackjack(stake)` returns `{"ok", "hand": Dictionary, "won", "stake"}`. Each takes the chips FIRST, settles, then calls `menu.call("show_result", lines)` behind a `has_method()` guard. `race_entrants()` builds `{"uid", "name", "happiness", "odds", "chance"}` per penned pony. `_bind_casino_menus()` sets every provider and connects every signal.

**The world.** `ranch.tscn` holds the `Environment` as `sub_resource id="Env"` (background sky, ambient from sky at 0.32 energy and 0.35 sky contribution, `tonemap_mode = 3` ACES, `tonemap_white = 3.0`, fog on at density 0.0011): glow, SSAO, SSIL, SDFGI, volumetric fog, SSR and the whole `adjustment_*` block are all off at their engine defaults. `$Sun` is a `DirectionalLight3D` with `light_energy = 1.15`, `shadow_bias = 0.05` and `directional_shadow_max_distance = 240.0` over a 220 m map, everything else default, which means `light_angular_distance = 0.0`: perfectly hard shadow edges everywhere.

**`game/world/sky_rig.gd`** drives `Sun.rotation_degrees`, `light_energy`, `light_color`, `ambient_light_energy`, `ambient_light_color`, `fog_density`, `fog_light_color` and all four `ProceduralSkyMaterial` colours per (phase, weather). **Every field this plan adds to the Environment is one the rig does not write,** so there is no conflict and `game/test/test_sky_rig.gd`'s orderings are untouched.

**`game/world/terrain.gd`** builds one `ArrayMesh` (`HALF` 110.0, `CELL` 2.0) coloured entirely by per vertex `grass_at()`, which lerps `GRASS_LOW` `Color(0.239, 0.408, 0.196)` to `GRASS_HIGH` `Color(0.443, 0.541, 0.271)`. Its material in `_build_mesh()` is a `StandardMaterial3D` with `vertex_color_use_as_albedo = true`, `vertex_color_is_srgb = true`, `roughness = 0.95`, `specular_mode = SPECULAR_DISABLED`. The comment above `vertex_color_is_srgb` records the bug it exists for: "the first render of this terrain was a pale mint sheet, not grass". UVs are `Vector2(x, z) * 0.25` and nothing samples them.

**`game/world/building.gd`** has one `_material(colour)` at roughness 0.9 with specular disabled, called three times in `build()` for `wall_color`, `roof_color` and `trim_color`. Its plinth runs from local `y = 0` down to `-SKIRT_DEPTH` (1.20), so the underside of a `Building`'s world AABB is 1.20 m below its own local origin. Nothing in the world has a specular highlight; the Palace's gold trim cannot glint.

**The floating text, all four sites.** `Buildings/Palace/Sign` is a `Label3D` authored in `ranch.tscn` at local `(0, 2.1, -4.1)`, `pixel_size` 0.0032, `font_size` 48, whose eleven lines are written at runtime in `ranch.gd._ready()` (the block commented "THE SIGN READS ITSELF OUT OF THE GAMES", immediately above `var prop_count := props.build() + buildings.get_child_count()`). `MarqueeHeadline` and `MarqueeSponsor` are built by `Strip._marquee_label()`, backed by `MarqueeBoard` and `MarqueeTrim`, fitted to the board width, already correct. `Nameplate` is built per lane by `RaceRunner._ensure_plate()`, six of them, `BILLBOARD_ENABLED`.

**Two spec line references that are stale, and the anchors to use instead.** The spec says the sign is written by `Ranch._build_world()`; there is no `_build_world()` on `ranch.gd`, the write is inside `_ready()`. And `strip.mount_marquee()` is called from `_ready()` too, about a hundred lines above it. Anchor by those two blocks, not by line number: **the dressing slice rewrote `_report()`'s prop block, added `_frame_on()` and five screenshots, and touched `props.gd`, so no line number in either file is stable.** `ranch.tscn`'s `Environment`, `$Sun`, `Buildings/Palace` and the menu instances are untouched by dressing and are safe.

---

## The three calls this plan makes on top of the spec

### Task 8 splits into a world text task and a look task. It is the right split.

The spec flags its own Task 8 as possibly wanting a split and this plan takes it, into **Task 8 (the world text: sections B.1, B.2, B.3)** and **Task 9 (the look: section C, plus the renders, the docs and the floor)**.

Three reasons, in the order they matter.

1. **A reviewer must be able to reject the terrain shader without rejecting the sign.** The shader is the single highest risk item in the slice: it is the only new language in the branch, it carries the sRGB trap the spec calls out twice, and its failure mode (a parse error at load) is invisible to a gate that only checks `RANCH_OK`. Bundled with a node swap and a nameplate removal, a reviewer who wants the shader reworked has to send back three unrelated pieces of finished work.
2. **The two halves have disjoint test surfaces.** The world text half moves `game/scenes/test/casino_test.gd`'s sign block and `game/test/test_race_runner.gd`'s child count, and adds `game/test/test_lobby_sign.gd`. The look half moves `game/test/test_terrain.gd` and nothing else. Neither half's tests can go red for the other's reason, which is the definition of a task boundary.
3. **The final task should own the floor and the docs,** and the look pass is where every number that moved gets written down: the render checklist, the gate counts and `MIN_TESTS`. Putting the sign in there would mean a task whose commit message has to explain a `Label3D` and a tonemapper in the same breath.

### The row treatment applies to menus that draw a cursor, not to reading matter

Section D.2 says "every menu's `refresh()` wraps its row `Label` in a `PanelContainer`". Taken literally that includes `game/ui/letter_panel.gd`, which draws prose with no cursor at all, and `game/test/test_letter_panel.gd` casts `Rows`'s children straight to `Label` in two tests. A selection box behind a paragraph of a letter is not polish; it is a menu pretending to be a menu it is not.

**So `MenuStyle.row_panel()` is applied by the panels that draw a cursor over their rows: the five casino menus, the market, the depot, the build menu and the pause menu.** `letter_panel.gd` is untouched and its two tests stay green. The placard, house rules and race card pages, which are reading matter inside a cursor driven menu, draw on a `CasinoPaint.plate()` rather than in row boxes, which is section A's answer for exactly that content.

### Blackjack's suits are derived in the stage and cannot reach a number

`Blackjack` numbers cards 0 to 51 and reads `card % RANKS` for the rank. It never names a suit. The stage derives `card / Blackjack.RANKS` (0 to 3) and draws hearts, diamonds, spades and clubs, with 0 and 1 in `CARD_RED`. **This is a pure presentation choice that no payout, no total and no edge can see**, because `card_value()`, `hand_total()` and `payout()` all read the rank alone. It is written into `blackjack_menu.gd`'s own comment in Task 6, because the next reader will wonder whether the casino just grew a suit that means something.

---

## File structure

**New:**

| File | Responsibility |
|---|---|
| `game/ui/casino_paint.gd` | The casino's drawing vocabulary. Static only: palette, primitives, and every glyph split into a pure `*_points()` half and a `draw_*` half. |
| `game/test/test_casino_paint.gd` | The kit as geometry: every glyph's points inside its box, the right count of them, and the standing proof that no generator lives under `game/ui/`. |
| `game/world/lobby_sign.gd` | The physical board that replaces the eleven line `Label3D` outside the Palace: board, trim, and two fitted `Label3D` lines sized off the Palace's own width. |
| `game/test/test_lobby_sign.gd` | That board as data: the labels are fitted to the board rather than free floating, and neither line carries a dash. |
| `game/world/terrain.gdshader` | The ground: sRGB decode of the vertex colour, two octaves of hash noise, a slope mask to dirt, a ridge lift and a distance fade. |
| `game/test/test_casino_stages.gd` | Every stage's pure layout: rects inside the stage, no two overlapping, `focus_rect()` agreeing with `focused_id()` on every row of every tab, and a push method with an out of range value degrading to a still frame. |

**Modified:** `game/ui/menu_style.gd`, `game/ui/table_menu.gd`, `game/ui/slots_menu.gd`, `game/ui/wheel_menu.gd`, `game/ui/blackjack_menu.gd`, `game/ui/race_menu.gd`, `game/ui/casino_menu.gd`, `game/ui/hud.gd`, ten menu `.tscn` files, `game/world/ranch.gd`, `game/world/ranch.tscn`, `game/world/terrain.gd`, `game/world/building.gd`, `game/world/strip.gd`, `game/world/race_runner.gd`, `game/world/race_track.gd`, `game/scenes/test/casino_test.gd`, `game/test/test_menu_style.gd`, `game/test/test_table_caret.gd`, `game/test/test_race_runner.gd`, `game/test/test_terrain.gd`, `tools/run_tests.sh`, `docs/testing.md`.

**Why this order.** The drawing kit is first because everything in section A spends it and because it is the one piece that can be finished and proved with no scene at all. The chrome pass is second because it is the single task after which every menu in the game looks better and no casino work has started, so a reviewer sees value before risk. The stage plumbing is third, alone, because it is the load bearing change to `table_menu.gd` and a reviewer must be able to reject it without rejecting a slot machine. The four game tasks follow, each one shippable on its own. The world text and the look pass come last because they are the only parts a picture rather than an assertion can judge.

---

### Task 1: `casino_paint.gd`, the drawing vocabulary

**Files:**
- Create: `game/ui/casino_paint.gd`, `game/test/test_casino_paint.gd`
- Test: `game/test/test_casino_paint.gd`

**Interfaces:**
- Consumes: `game/ui/menu_style.gd`'s `OUTLINE_COLOR` and `OUTLINE_SIZE`; `game/systems/slots.gd`'s `Symbol` enum; `game/systems/wheel.gd`'s `Colour` enum; `game/systems/blackjack.gd`'s `RANKS`; `game/ui/casino_menu.gd`'s `Row` enum. Every one by preload path.
- Produces, all `static`, all on `class_name CasinoPaint extends RefCounted`:
  - Colours: `FELT`, `FELT_DARK`, `FELT_LINE`, `PLUM`, `PLUM_DARK`, `GOLD`, `GOLD_DIM`, `CARD_FACE`, `CARD_RED`, `CARD_INK`, `CHIP_COLORS: Array[Color]` (3, one per `TableMenu.STAKES` entry), `BAND_COLORS: Array[Color]` (6, indexed by `Wheel.Colour`), `HOUSE_SILVER`.
  - `rounded(ci: CanvasItem, rect: Rect2, radius: float, fill: Color, border: Color, border_width: float) -> void`
  - `ellipse_points(centre: Vector2, rx: float, ry: float) -> PackedVector2Array`
  - `ellipse(ci: CanvasItem, centre: Vector2, rx: float, ry: float, fill: Color, rim: Color) -> void`
  - `sector_points(centre: Vector2, inner: float, outer: float, from_angle: float, to_angle: float) -> PackedVector2Array`
  - `chip(ci: CanvasItem, centre: Vector2, radius: float, colour: Color, edge_marks: bool) -> void`
  - `chip_stack(ci: CanvasItem, base: Vector2, count: int, colour: Color, step: float) -> void`
  - `plate(ci: CanvasItem, rect: Rect2, font: Font, title: String, body: Array[String]) -> void`
  - `text(ci: CanvasItem, font: Font, at: Vector2, string: String, size: int, colour: Color, align: int, max_width: float) -> void`
  - `focus_ring(ci: CanvasItem, rect: Rect2, radius: float, t: float) -> void`
  - Glyph geometry: `star_points(box: Rect2) -> PackedVector2Array` (10 points), `hexagon_points(box: Rect2) -> PackedVector2Array` (6), `heart_points`, `diamond_points` (4), `spade_points`, `club_points`, `card_pip_points(rect: Rect2, rank: int) -> PackedVector2Array`.
  - Glyph drawing: `draw_symbol(ci: CanvasItem, box: Rect2, symbol: int) -> void` (one per `Slots.Symbol`), `draw_suit(ci: CanvasItem, box: Rect2, suit: int) -> void`, `draw_card(ci: CanvasItem, rect: Rect2, font: Font, card: int, face_up: bool) -> void`, `draw_room(ci: CanvasItem, box: Rect2, row: int) -> void` (one per `CasinoMenu.Row`), `draw_bit(ci: CanvasItem, box: Rect2) -> void`, `draw_chip_icon(ci: CanvasItem, box: Rect2) -> void`.
  - `SUIT_COLORS: Array[Color]` (4, hearts and diamonds `CARD_RED`, spades and clubs `CARD_INK`).

**Why every glyph is split in two.** The `*_points()` half is pure geometry with no `CanvasItem` in sight, so a headless test can assert that a star has ten points, that a hexagon has six, that every point sits inside the box it was handed and that no glyph is empty. The `draw_*` half is three lines feeding those points to `draw_colored_polygon`. Nothing about a drawn shape is unverifiable, and that is what makes drawn art shippable in a project whose CI has no GPU.

- [ ] **Step 1: Write the failing test**

Create `game/test/test_casino_paint.gd`:

```gdscript
extends GutTest
## THE CASINO'S DRAWING VOCABULARY, AS GEOMETRY. Every glyph in game/ui/casino_paint.gd is
## split into a pure *_points() half and a three line draw_* half, for exactly this reason:
## a headless gate has no GPU and cannot look at a picture, but it can assert that a star has
## ten points, that a hexagon has six, and that neither of them leaks outside the box it was
## handed. A glyph that draws off its own tile is the defect this catches, and it is the one
## that actually happens when a shape is authored by eye in normalised coordinates.
##
## IT ALSO CARRIES THE NO RIGGING RULE. See the last test in this file.
##
## Preloads by path rather than by class_name, per the convention at the top of
## game/scripts/pony_rig.gd (the global class cache lives in the gitignored game/.godot/ and
## a fresh clone has not built it yet).

const PaintScript := preload("res://ui/casino_paint.gd")
const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")

## An off origin, non square box, deliberately. A glyph authored against a unit square at the
## origin passes a containment test at (0, 0, 1, 1) by accident.
const BOX := Rect2(37.0, 11.0, 88.0, 64.0)


func _all_inside(points: PackedVector2Array, box: Rect2, what: String) -> void:
	assert_gt(points.size(), 2, "%s must be a polygon, not a point" % what)
	for p: Vector2 in points:
		assert_true(box.has_point(p),
			"%s leaks outside its box: %s not in %s" % [what, p, box])


func test_a_star_has_ten_points_and_stays_in_its_box() -> void:
	var points: PackedVector2Array = PaintScript.star_points(BOX)
	assert_eq(points.size(), 10, "five outer and five inner")
	_all_inside(points, BOX, "star")


func test_a_hexagon_has_six_points_and_stays_in_its_box() -> void:
	var points: PackedVector2Array = PaintScript.hexagon_points(BOX)
	assert_eq(points.size(), 6)
	_all_inside(points, BOX, "hexagon")


func test_a_diamond_has_four_points_and_stays_in_its_box() -> void:
	var points: PackedVector2Array = PaintScript.diamond_points(BOX)
	assert_eq(points.size(), 4)
	_all_inside(points, BOX, "diamond")


func test_every_card_suit_stays_in_its_box() -> void:
	for pair: Array in [[PaintScript.heart_points(BOX), "heart"],
			[PaintScript.spade_points(BOX), "spade"],
			[PaintScript.club_points(BOX), "club"],
			[PaintScript.diamond_points(BOX), "diamond"]]:
		_all_inside(pair[0] as PackedVector2Array, BOX, String(pair[1]))


## An ellipse is a polygon here because Godot draws circles and not ellipses, and a chip seen
## at a slight angle is an ellipse.
func test_an_ellipse_is_a_closed_ring_of_points_around_its_centre() -> void:
	var points: PackedVector2Array = PaintScript.ellipse_points(Vector2(50.0, 50.0), 20.0, 8.0)
	assert_eq(points.size(), 28, "28 segments: smooth at a chip's size, cheap at a stack's")
	_all_inside(points, Rect2(29.9, 41.9, 40.2, 16.2), "ellipse")


## THE WHEEL'S POCKETS ARE THESE. An annular sector is two arcs and two radial edges; a
## sector whose points did not lie between the two radii would draw a pocket over the hub.
func test_an_annular_sector_stays_between_its_two_radii() -> void:
	var centre := Vector2(200.0, 200.0)
	var points: PackedVector2Array = PaintScript.sector_points(centre, 78.0, 236.0, 0.0, 0.4)
	assert_gt(points.size(), 3)
	for p: Vector2 in points:
		var r: float = centre.distance_to(p)
		assert_between(r, 77.9, 236.1, "a sector point sits between the inner and outer rim")


## SIX SYMBOLS, SIX ROOMS, FOUR SUITS: every enum the kit draws for has a glyph, so a stage
## can never ask for one that is not there. Asked of the enums themselves rather than of a
## number, so adding a seventh slot symbol fails here rather than drawing nothing.
func test_every_slot_symbol_and_every_lobby_room_has_a_glyph() -> void:
	var control := Control.new()
	add_child_autofree(control)
	for symbol: int in range(SlotsScript.SYMBOL_NAMES.size()):
		PaintScript.draw_symbol(control, BOX, symbol)
	for row: int in range(6):
		PaintScript.draw_room(control, BOX, row)
	for suit: int in range(4):
		PaintScript.draw_suit(control, BOX, suit)
	assert_eq(PaintScript.SUIT_COLORS.size(), 4)
	pass_test("every glyph the enums name drew without erroring")


## ONE RAINBOW, THREE PLACES. The wheel's bands, the six race lanes and the slots RAINBOW
## symbol are the same six colours in the same order, so the building reads as one building.
func test_the_band_colours_are_one_per_wheel_colour_in_rainbow_order() -> void:
	assert_eq(PaintScript.BAND_COLORS.size(), int(WheelScript.Colour.HOUSE),
		"one band per colour a bet may name, and none for the house pocket")


## THE CHIP COLOURS AND THE STAKES ARE THE SAME LIST. A fourth stake with no chip colour
## would draw a black token; a fourth colour with no stake is a colour nobody sees.
func test_there_is_one_chip_colour_per_stake() -> void:
	var stakes: Array = load("res://ui/table_menu.gd").STAKES
	assert_eq(PaintScript.CHIP_COLORS.size(), stakes.size())


## NO RIGGING, AND IT IS CHECKED RATHER THAN REMEMBERED. game/systems/ owns every outcome in
## this casino; game/ui/ draws what it is told. A generator constructed under game/ui/ is the
## one change that could quietly make a stage decide something, so the source is swept for it.
## Source text rather than behaviour, deliberately: behaviour can only catch the rigging that
## already shipped, and this catches the line that would have made it possible.
func test_no_random_generator_lives_anywhere_under_game_ui() -> void:
	var offenders: Array[String] = []
	for file: String in DirAccess.get_files_at("res://ui"):
		if not file.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string("res://ui/".path_join(file))
		for banned: String in ["RandomNumberGenerator", "randi(", "randf(", "randi_range",
				"randf_range", "rand_from_seed"]:
			if text.contains(banned):
				offenders.append("%s carries %s" % [file, banned])
	assert_eq(offenders, [] as Array[String],
		"the menus draw and emit; nothing under game/ui/ may roll anything")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_casino_paint.gd -gexit 2>&1 | tail -20
```
Expected: FAIL. GUT reports that `res://ui/casino_paint.gd` could not be loaded, so every test in the file errors.

- [ ] **Step 3: Write the palette and the primitives**

Create `game/ui/casino_paint.gd`:

```gdscript
class_name CasinoPaint
extends RefCounted
## THE CASINO'S OWN DRAWING VOCABULARY. game/ui/menu_style.gd owns the panel chrome every
## menu in the game shares; this file owns the felt, the chips, the cards and the glyphs that
## only the Palace has. Static only, no state, no scene, preloaded by path.
##
## THERE ARE NO 2D ART ASSETS IN THIS PROJECT AND THIS FILE ACQUIRES NONE. Everything below
## is a polygon, an arc, a StyleBoxFlat or a string. If it cannot be one of those four it is
## not in this slice: no texture, no Gradient resource on disk, no nine patch, no atlas.
##
## EVERY GLYPH IS SPLIT IN TWO, and the split is the whole reason drawn art can ship in a
## project whose CI has no GPU. The *_points() half is pure geometry with no CanvasItem in
## sight, so game/test/test_casino_paint.gd can assert that a star has ten points and that
## none of them leaks outside the box it was handed. The draw_* half is three lines feeding
## those points to draw_colored_polygon.
##
## THE PALETTE IS THE PALACE'S OWN. PLUM and GOLD are Buildings/Palace's wall_color and
## trim_color read straight out of game/world/ranch.tscn, so the building and its interior
## agree with each other by construction rather than by taste.
##
## NOTHING HERE ROLLS ANYTHING. See test_casino_paint.gd's last test.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const SlotsScript := preload("res://systems/slots.gd")

# --- the palette ----------------------------------------------------------------------------

const FELT := Color(0.09, 0.32, 0.20)
const FELT_DARK := Color(0.05, 0.20, 0.13)
const FELT_LINE := Color(1.00, 0.94, 0.72, 0.22)
const PLUM := Color(0.36, 0.16, 0.42)
const PLUM_DARK := Color(0.22, 0.09, 0.27)
const GOLD := Color(0.98, 0.86, 0.45)
const GOLD_DIM := Color(0.62, 0.53, 0.28)
const CARD_FACE := Color(0.97, 0.96, 0.93)
const CARD_RED := Color(0.78, 0.16, 0.20)
const CARD_INK := Color(0.11, 0.10, 0.14)

## The Cloudsdale pocket, which no bet may name. Pale enough that it reads as absent from the
## rainbow rather than as a seventh colour somebody forgot to let you back.
const HOUSE_SILVER := Color(0.80, 0.84, 0.90)

## ONE PER TableMenu.STAKES ENTRY, in ascending order, the way a real cage stacks them:
## white for the small one, green for the middle, black and gold for the big one.
const CHIP_COLORS: Array[Color] = [
	Color(0.90, 0.90, 0.92),
	Color(0.16, 0.52, 0.30),
	Color(0.13, 0.12, 0.16),
]

## SIX COLOURS, THREE PLACES, ONE RAINBOW. Indexed by Wheel.Colour, and the same six are the
## wheel's bands, the six race lanes and the slot machine's RAINBOW symbol, so the building
## reads as one building rather than as three screens that happened to be written together.
const BAND_COLORS: Array[Color] = [
	Color(0.85, 0.24, 0.26),
	Color(0.93, 0.55, 0.20),
	Color(0.95, 0.82, 0.28),
	Color(0.33, 0.68, 0.36),
	Color(0.27, 0.52, 0.86),
	Color(0.60, 0.38, 0.82),
]

## Hearts, diamonds, spades, clubs, in the order Blackjack's own card index implies:
## card / Blackjack.RANKS. See game/ui/blackjack_menu.gd on why that is presentation only.
const SUIT_COLORS: Array[Color] = [CARD_RED, CARD_RED, CARD_INK, CARD_INK]

## Segments in a drawn ellipse. 28 is smooth at a 34 px chip and still cheap at a stack of
## eight; a circle would be draw_circle's job, and Godot has no ellipse call at all.
const ELLIPSE_SEGMENTS := 28

## Segments per annular sector arc. The wheel has 25 of them, so this is 25 * 2 * 6 points.
const SECTOR_SEGMENTS := 6

## The one focus treatment in the whole casino, so "where am I" is answered identically on
## every screen. Alpha breathes between these two on the phase the stage advances.
const FOCUS_WIDTH := 3.0
const FOCUS_INSET := 2.0
const FOCUS_ALPHA_LOW := 0.72
const FOCUS_ALPHA_HIGH := 1.0


## A filled, bordered, rounded rectangle: the single most used call in the slice.
##
## BUILT ON A StyleBoxFlat RATHER THAN ON GENERATED POLYGONS, and drawn straight onto an
## arbitrary CanvasItem through StyleBox.draw(). A StyleBoxFlat already has per corner radii,
## a border and an anti aliased edge; hand rolling that as a polygon is fifty lines that draw
## a worse rectangle.
static func rounded(ci: CanvasItem, rect: Rect2, radius: float, fill: Color,
		border: Color, border_width: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(radius))
	box.set_border_width_all(int(border_width))
	box.border_color = border
	box.anti_aliasing = true
	box.draw(ci.get_canvas_item(), rect)


## The points of an ellipse centred at `centre`. Godot has draw_circle and no ellipse call,
## and a chip seen at a slight angle is an ellipse.
static func ellipse_points(centre: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in ELLIPSE_SEGMENTS:
		var a: float = TAU * float(i) / float(ELLIPSE_SEGMENTS)
		out.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func ellipse(ci: CanvasItem, centre: Vector2, rx: float, ry: float,
		fill: Color, rim: Color) -> void:
	var points: PackedVector2Array = ellipse_points(centre, rx, ry)
	ci.draw_colored_polygon(points, fill)
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, rim, 2.0, true)


## ONE POCKET OF THE WHEEL: the ring between `inner` and `outer` from `from_angle` to
## `to_angle`, as a closed polygon. Out along the near arc and back along the far one, so the
## winding is consistent and draw_colored_polygon fills it rather than bowtieing it.
static func sector_points(centre: Vector2, inner: float, outer: float,
		from_angle: float, to_angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in SECTOR_SEGMENTS + 1:
		var a: float = lerpf(from_angle, to_angle, float(i) / float(SECTOR_SEGMENTS))
		out.append(centre + Vector2(cos(a), sin(a)) * outer)
	for i: int in SECTOR_SEGMENTS + 1:
		var a: float = lerpf(to_angle, from_angle, float(i) / float(SECTOR_SEGMENTS))
		out.append(centre + Vector2(cos(a), sin(a)) * inner)
	return out


## A CASINO CHIP. A filled ellipse, an inset lighter ring at 0.68 of the radius, six white
## edge dashes and a gold rim. `edge_marks` off gives the flat token used at small sizes,
## where six dashes are three pixels of noise rather than a chip.
static func chip(ci: CanvasItem, centre: Vector2, radius: float, colour: Color,
		edge_marks: bool) -> void:
	var ry: float = radius * 0.82
	ellipse(ci, centre, radius, ry, colour, GOLD_DIM)
	ellipse(ci, centre, radius * 0.68, ry * 0.68, colour.lightened(0.18),
		Color(colour.lightened(0.35), 0.6))
	if not edge_marks:
		return
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		var inner: Vector2 = centre + Vector2(cos(a) * radius * 0.80, sin(a) * ry * 0.80)
		var outer: Vector2 = centre + Vector2(cos(a) * radius * 0.97, sin(a) * ry * 0.97)
		ci.draw_line(inner, outer, Color(1.0, 1.0, 1.0, 0.85), 3.0, true)


## A STACK READS AS A STACK: `count` chips bottom up, the top one full and the rest showing
## only their rim. Caps at CHIP_STACK_MAX drawn chips with a small "x N" beside it, because a
## stack of forty chips is a column of mush and a number is what the player actually wants.
const CHIP_STACK_MAX := 8


static func chip_stack(ci: CanvasItem, base: Vector2, count: int, colour: Color,
		step: float) -> void:
	var drawn: int = mini(count, CHIP_STACK_MAX)
	for i: int in drawn:
		var at: Vector2 = base - Vector2(0.0, step * float(i))
		var top: bool = i == drawn - 1
		chip(ci, at, step * 2.6, colour, top)


## THE READING PLATE: a gold trimmed panel carrying a title and a body, so the two "reading
## matter" tabs in this building (the wheel's rules, blackjack's placard, the race card) stop
## being loose Labels in a column and start being a page.
static func plate(ci: CanvasItem, rect: Rect2, font: Font, title: String,
		body: Array[String]) -> void:
	rounded(ci, rect, 12.0, Color(FELT_DARK, 0.92), GOLD_DIM, 2.0)
	var y: float = rect.position.y + 34.0
	if not title.is_empty():
		text(ci, font, Vector2(rect.position.x + 22.0, y), title,
			MenuStyleScript.TITLE_SIZE, GOLD, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 44.0)
		y += 34.0
	for line: String in body:
		text(ci, font, Vector2(rect.position.x + 22.0, y), line,
			MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_NAME,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 44.0)
		y += 28.0


## OUTLINE PASS THEN COLOUR PASS, the same two pass discipline game/ui/hud.gd's _ring() uses
## and for the same reason: this game draws over a bright green field under a bright sky, and
## unoutlined text on that is genuinely unreadable. Every string the casino draws goes through
## here so no stage can forget it.
static func text(ci: CanvasItem, font: Font, at: Vector2, string: String, size: int,
		colour: Color, align: int, max_width: float) -> void:
	if font == null or string.is_empty():
		return
	ci.draw_string_outline(font, at, string, align, max_width, size,
		MenuStyleScript.OUTLINE_SIZE, MenuStyleScript.OUTLINE_COLOR)
	ci.draw_string(font, at, string, align, max_width, size, colour)


## THE ONE FOCUS TREATMENT IN THE WHOLE CASINO. Every focusable thing on every screen gets
## this and nothing else does, so a player who has learned it once has learned it everywhere.
## `t` is a phase in seconds the stage advances; the alpha breathes so a still screenshot and
## a live screen say the same thing.
static func focus_ring(ci: CanvasItem, rect: Rect2, radius: float, t: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	var alpha: float = lerpf(FOCUS_ALPHA_LOW, FOCUS_ALPHA_HIGH, pulse)
	rounded(ci, rect.grow(-FOCUS_INSET), radius, Color(0, 0, 0, 0.0),
		Color(GOLD, alpha), FOCUS_WIDTH)
```

- [ ] **Step 4: Write the glyphs**

Append to `game/ui/casino_paint.gd`:

```gdscript
# --- the glyphs -----------------------------------------------------------------------------
# Every one is authored against the normalised box it is handed, so any glyph can be swapped
# for any other and each works at 34 px on a paytable row, at 60 px on a lobby tile and at
# 300 px as a table's own headboard. `box` is always the whole tile; the shapes inset
# themselves rather than assuming a margin was already applied.


## `f` of the way across `box` and `g` of the way down it. The one place normalised glyph
## coordinates become pixels, so a glyph cannot half apply the box.
static func _at(box: Rect2, f: float, g: float) -> Vector2:
	return box.position + Vector2(box.size.x * f, box.size.y * g)


## Ten points: five outer at `outer` of the half diagonal and five inner at `inner`, starting
## at twelve o'clock so the star stands up rather than leaning.
static func star_points(box: Rect2) -> PackedVector2Array:
	var centre: Vector2 = box.position + box.size * 0.5
	var rx: float = box.size.x * 0.5
	var ry: float = box.size.y * 0.5
	var out := PackedVector2Array()
	for i: int in 10:
		var a: float = -PI * 0.5 + TAU * float(i) / 10.0
		var f: float = 1.0 if i % 2 == 0 else 0.42
		out.append(centre + Vector2(cos(a) * rx * f, sin(a) * ry * f))
	return out


static func hexagon_points(box: Rect2) -> PackedVector2Array:
	var centre: Vector2 = box.position + box.size * 0.5
	var out := PackedVector2Array()
	for i: int in 6:
		var a: float = -PI * 0.5 + TAU * float(i) / 6.0
		out.append(centre + Vector2(cos(a) * box.size.x * 0.5, sin(a) * box.size.y * 0.5))
	return out


static func diamond_points(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([_at(box, 0.5, 0.0), _at(box, 1.0, 0.5),
		_at(box, 0.5, 1.0), _at(box, 0.0, 0.5)])


## A heart as a polygon rather than as two circles plus a triangle: circles cannot be asserted
## inside a box by the same test the other three suits use, and a suit that is tested a
## different way is a suit whose bug is found a different day.
static func heart_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in 24:
		var t: float = TAU * float(i) / 24.0
		var x: float = pow(sin(t), 3.0)
		var y: float = -(0.8125 * cos(t) - 0.3125 * cos(2.0 * t)
			- 0.125 * cos(3.0 * t) - 0.0625 * cos(4.0 * t))
		out.append(_at(box, 0.5 + x * 0.5, 0.5 + y * 0.52))
	return out


static func spade_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in 24:
		var t: float = TAU * float(i) / 24.0
		var x: float = pow(sin(t), 3.0)
		var y: float = 0.8125 * cos(t) - 0.3125 * cos(2.0 * t) \
			- 0.125 * cos(3.0 * t) - 0.0625 * cos(4.0 * t)
		out.append(_at(box, 0.5 + x * 0.5, 0.44 + y * 0.44))
	out.append(_at(box, 0.42, 0.86))
	out.append(_at(box, 0.58, 0.86))
	return out


static func club_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for lobe: Array in [[0.5, 0.26, 0.24], [0.28, 0.54, 0.24], [0.72, 0.54, 0.24]]:
		for i: int in 10:
			var a: float = TAU * float(i) / 10.0
			out.append(_at(box, float(lobe[0]) + cos(a) * float(lobe[2]) * 0.5,
				float(lobe[1]) + sin(a) * float(lobe[2]) * 0.5))
	out.append(_at(box, 0.44, 0.94))
	out.append(_at(box, 0.56, 0.94))
	return out


## WHERE THE PIPS GO ON A CARD FACE, in the traditional arrangement. Rank 0 (an Ace) gets one
## centred pip; ranks 1 to 8 (Two through Nine) get their own layout; ranks 9 to 12 get none,
## because a Ten is drawn as ten pips and a court card is drawn as a monogram panel, both of
## which draw_card() handles rather than this table.
static func card_pip_points(rect: Rect2, rank: int) -> PackedVector2Array:
	var cols: Array[float] = [0.30, 0.50, 0.70]
	var rows: Array[float] = [0.26, 0.38, 0.50, 0.62, 0.74]
	var layout: Array = []
	match rank:
		0: layout = [[1, 2]]
		1: layout = [[1, 0], [1, 4]]
		2: layout = [[1, 0], [1, 2], [1, 4]]
		3: layout = [[0, 0], [2, 0], [0, 4], [2, 4]]
		4: layout = [[0, 0], [2, 0], [1, 2], [0, 4], [2, 4]]
		5: layout = [[0, 0], [2, 0], [0, 2], [2, 2], [0, 4], [2, 4]]
		6: layout = [[0, 0], [2, 0], [0, 2], [2, 2], [1, 1], [0, 4], [2, 4]]
		7: layout = [[0, 0], [2, 0], [0, 2], [2, 2], [1, 1], [1, 3], [0, 4], [2, 4]]
		8: layout = [[0, 0], [2, 0], [0, 1], [2, 1], [0, 3], [2, 3], [1, 2],
			[0, 4], [2, 4]]
		9: layout = [[0, 0], [2, 0], [0, 1], [2, 1], [1, 1], [0, 3], [2, 3], [1, 3],
			[0, 4], [2, 4]]
	var out := PackedVector2Array()
	for cell: Array in layout:
		out.append(_at(rect, cols[int(cell[0])], rows[int(cell[1])]))
	return out


## One per Slots.Symbol, in enum order: APPLE, HORSESHOE, BELL, GEM, STAR, RAINBOW.
static func draw_symbol(ci: CanvasItem, box: Rect2, symbol: int) -> void:
	match symbol:
		SlotsScript.Symbol.APPLE:
			ci.draw_circle(_at(box, 0.5, 0.60), box.size.y * 0.32, Color(0.85, 0.20, 0.22))
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.52, 0.24),
				_at(box, 0.82, 0.16), _at(box, 0.58, 0.34)]), Color(0.32, 0.62, 0.28))
			ci.draw_line(_at(box, 0.50, 0.30), _at(box, 0.50, 0.12),
				Color(0.38, 0.26, 0.16), 3.0, true)
		SlotsScript.Symbol.HORSESHOE:
			var centre: Vector2 = _at(box, 0.5, 0.46)
			ci.draw_arc(centre, box.size.y * 0.34, PI * 0.10, PI * 0.90,
				24, GOLD, box.size.y * 0.18, true)
			for f: float in [0.20, 0.80]:
				ci.draw_rect(Rect2(_at(box, f - 0.07, 0.62),
					Vector2(box.size.x * 0.14, box.size.y * 0.14)), GOLD_DIM)
			for f: float in [0.28, 0.42, 0.58, 0.72]:
				ci.draw_circle(_at(box, f, 0.30), box.size.y * 0.035, PLUM_DARK)
		SlotsScript.Symbol.BELL:
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.30, 0.70),
				_at(box, 0.38, 0.24), _at(box, 0.62, 0.24), _at(box, 0.70, 0.70)]),
				Color(0.93, 0.76, 0.30))
			ci.draw_rect(Rect2(_at(box, 0.24, 0.70),
				Vector2(box.size.x * 0.52, box.size.y * 0.09)), GOLD_DIM)
			ci.draw_circle(_at(box, 0.5, 0.86), box.size.y * 0.07, GOLD_DIM)
		SlotsScript.Symbol.GEM:
			ci.draw_colored_polygon(hexagon_points(box), Color(0.42, 0.76, 0.86))
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.5, 0.0),
				_at(box, 0.5, 0.5), _at(box, 0.06, 0.25)]), Color(0.66, 0.90, 0.96))
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.5, 0.0),
				_at(box, 0.5, 0.5), _at(box, 0.94, 0.25)]), Color(0.30, 0.62, 0.76))
		SlotsScript.Symbol.STAR:
			ci.draw_colored_polygon(star_points(box), GOLD)
		SlotsScript.Symbol.RAINBOW:
			var arc_centre: Vector2 = _at(box, 0.5, 0.86)
			for band: int in BAND_COLORS.size():
				var r: float = box.size.y * (0.72 - 0.10 * float(band))
				ci.draw_arc(arc_centre, r, PI, TAU, 20, BAND_COLORS[band],
					box.size.y * 0.09, true)


static func draw_suit(ci: CanvasItem, box: Rect2, suit: int) -> void:
	var colour: Color = SUIT_COLORS[clampi(suit, 0, SUIT_COLORS.size() - 1)]
	match clampi(suit, 0, 3):
		0: ci.draw_colored_polygon(heart_points(box), colour)
		1: ci.draw_colored_polygon(diamond_points(box), colour)
		2: ci.draw_colored_polygon(spade_points(box), colour)
		3: ci.draw_colored_polygon(club_points(box), colour)


## ONE PLAYING CARD. `card` is Blackjack's own 0 to 51 index; the rank is card % RANKS and the
## suit is card / RANKS. See game/ui/blackjack_menu.gd for why deriving a suit here cannot
## touch a payout. An out of range card draws a back, which is what a stage handed a bad push
## should show rather than an error.
const CARD_RANK_LETTERS: Array[String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9",
	"10", "J", "Q", "K"]


static func draw_card(ci: CanvasItem, rect: Rect2, font: Font, card: int,
		face_up: bool) -> void:
	if not face_up or card < 0 or card >= 52:
		rounded(ci, rect, 8.0, PLUM, GOLD, 2.0)
		var step: float = rect.size.x * 0.22
		var x: float = rect.position.x - rect.size.y
		while x < rect.position.x + rect.size.x + rect.size.y:
			ci.draw_line(Vector2(x, rect.position.y + rect.size.y),
				Vector2(x + rect.size.y, rect.position.y), Color(GOLD_DIM, 0.55), 1.5, true)
			x += step
		return
	var rank: int = card % 13
	var suit: int = card / 13
	rounded(ci, rect, 8.0, CARD_FACE, CARD_INK, 1.0)
	var letter: String = CARD_RANK_LETTERS[rank]
	var colour: Color = SUIT_COLORS[suit]
	text(ci, font, rect.position + Vector2(7.0, 24.0), letter, 20, colour,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	text(ci, font, rect.position + rect.size - Vector2(7.0, 7.0), letter, 20, colour,
		HORIZONTAL_ALIGNMENT_RIGHT, -1.0)
	var corner := Rect2(rect.position + Vector2(6.0, 26.0), Vector2(14.0, 14.0))
	draw_suit(ci, corner, suit)
	if rank >= 10:
		var panel := Rect2(rect.position + rect.size * Vector2(0.22, 0.26),
			rect.size * Vector2(0.56, 0.48))
		rounded(ci, panel, 4.0, Color(GOLD_DIM, 0.35), GOLD_DIM, 1.0)
		text(ci, font, panel.position + Vector2(panel.size.x * 0.5, panel.size.y * 0.72),
			letter, 30, colour, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		return
	var pip_size: float = rect.size.x * (0.30 if rank == 0 else 0.16)
	for p: Vector2 in card_pip_points(rect, rank):
		draw_suit(ci, Rect2(p - Vector2(pip_size, pip_size) * 0.5,
			Vector2(pip_size, pip_size)), suit)


## ONE PER CasinoMenu.Row: CAGE, SLOTS, WHEEL, BLACKJACK, RACING, RULES. Works at 60 px on a
## lobby tile and at 300 px as a table's own headboard, so the picker and the room agree with
## each other by construction rather than by somebody remembering to update both.
static func draw_room(ci: CanvasItem, box: Rect2, row: int) -> void:
	match row:
		0:
			ci.draw_arc(_at(box, 0.5, 0.72), box.size.y * 0.36, PI, TAU, 24, GOLD_DIM,
				6.0, true)
			chip_stack(ci, _at(box, 0.5, 0.80), 4, CHIP_COLORS[1], box.size.y * 0.06)
		1:
			rounded(ci, Rect2(_at(box, 0.14, 0.10),
				box.size * Vector2(0.72, 0.80)), 8.0, PLUM, GOLD, 2.0)
			for i: int in 3:
				var window := Rect2(_at(box, 0.20 + 0.20 * float(i), 0.30),
					box.size * Vector2(0.16, 0.28))
				rounded(ci, window, 4.0, Color(0.06, 0.05, 0.09), GOLD_DIM, 1.0)
				draw_symbol(ci, window.grow(-2.0), i + 1)
		2:
			for band: int in BAND_COLORS.size():
				var from_angle: float = TAU * float(band) / float(BAND_COLORS.size())
				var to_angle: float = TAU * float(band + 1) / float(BAND_COLORS.size())
				ci.draw_colored_polygon(sector_points(_at(box, 0.5, 0.5),
					box.size.y * 0.16, box.size.y * 0.44, from_angle, to_angle),
					BAND_COLORS[band])
			ci.draw_circle(_at(box, 0.5, 0.5), box.size.y * 0.14, GOLD)
		3:
			for i: int in 3:
				var card := Rect2(_at(box, 0.22 + 0.16 * float(i), 0.22),
					box.size * Vector2(0.26, 0.56))
				rounded(ci, card, 6.0, CARD_FACE, CARD_INK, 1.0)
				draw_suit(ci, card.grow(-card.size.x * 0.28), i)
		4:
			ci.draw_line(_at(box, 0.05, 0.74), _at(box, 0.95, 0.74), GOLD_DIM, 4.0, true)
			ci.draw_line(_at(box, 0.86, 0.74), _at(box, 0.86, 0.22), GOLD, 5.0, true)
			for part: Array in [[0.24, 0.50, 0.26, 0.14], [0.30, 0.64, 0.08, 0.14],
					[0.44, 0.64, 0.08, 0.14]]:
				rounded(ci, Rect2(_at(box, float(part[0]), float(part[1])),
					box.size * Vector2(float(part[2]), float(part[3]))),
					4.0, BAND_COLORS[0], BAND_COLORS[0], 0.0)
		5:
			rounded(ci, Rect2(_at(box, 0.16, 0.14), box.size * Vector2(0.68, 0.72)),
				6.0, FELT_DARK, GOLD, 2.0)
			for i: int in 4:
				ci.draw_line(_at(box, 0.24, 0.30 + 0.14 * float(i)),
					_at(box, 0.76, 0.30 + 0.14 * float(i)), Color(GOLD_DIM, 0.8), 2.0, true)


## The wallet icons: a bit is a gold coin with a notch cut out of its rim, a chip is a chip.
static func draw_bit(ci: CanvasItem, box: Rect2) -> void:
	var centre: Vector2 = box.position + box.size * 0.5
	var r: float = minf(box.size.x, box.size.y) * 0.5
	ci.draw_circle(centre, r, GOLD)
	ci.draw_circle(centre, r * 0.72, GOLD_DIM)
	ci.draw_line(centre + Vector2(r * 0.30, -r * 0.30), centre + Vector2(r, -r),
		Color(0, 0, 0, 0.0), 1.0, true)


static func draw_chip_icon(ci: CanvasItem, box: Rect2) -> void:
	var centre: Vector2 = box.position + box.size * 0.5
	chip(ci, centre, minf(box.size.x, box.size.y) * 0.5, CHIP_COLORS[1], true)
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_casino_paint.gd -gexit 2>&1 | tail -12
```
Expected: `Tests 10`, `Passing 10`, `Failing 0`.

If `test_no_random_generator_lives_anywhere_under_game_ui` fails, do NOT relax it: something under `game/ui/` is rolling a number, which is the one thing this slice may not add.

- [ ] **Step 6: Run the whole suite**

```bash
bash tools/run_tests.sh 2>&1 | tail -12
```
Expected: green, with the test count up by 10.

- [ ] **Step 7: Commit**

```bash
printf 'feat: the casino gets a drawing vocabulary\n\ngame/ui/casino_paint.gd is menu_style.gd s sibling: menu_style owns the panel\nchrome every menu in the game shares, casino_paint owns the felt, the chips,\nthe cards and the glyphs only the Palace has. Static only, no state, no scene,\nand no asset: everything in it is a polygon, an arc, a StyleBoxFlat or a\nstring.\n\nEvery glyph is split into a pure *_points() geometry half and a three line\ndraw_* half, which is what makes drawn art shippable in a project whose CI has\nno GPU: the test asserts a star has ten points, a hexagon six, and that no\nglyph leaks outside the box it was handed.\n\nThe palette is the Palace s own. PLUM and GOLD are Buildings/Palace s\nwall_color and trim_color read out of ranch.tscn, so the building and its\ninterior agree by construction. BAND_COLORS is one rainbow in three places:\nthe wheel s bands, the six race lanes and the slots RAINBOW symbol.\n\nThe no rigging rule is now checked rather than remembered. The last test sweeps\nevery script under game/ui/ for a RandomNumberGenerator or a rand call and\nfails on one, because a generator under game/ui/ is the single change that\ncould let a stage decide an outcome.\n' > /tmp/polish-task1.txt
git add game/ui/casino_paint.gd game/ui/casino_paint.gd.uid \
  game/test/test_casino_paint.gd game/test/test_casino_paint.gd.uid
git commit -F /tmp/polish-task1.txt
```

---

### Task 2: The chrome pass, and every panel in the game is better

**Files:**
- Modify: `game/ui/menu_style.gd`, `game/ui/table_menu.gd`, `game/ui/casino_menu.gd`, `game/ui/depot_menu.gd`, `game/ui/pause_menu.gd`, `game/ui/hud.gd`, and the ten `.tscn` files carrying a `MenuPanel` `StyleBoxFlat`
- Test: `game/test/test_menu_style.gd`

**Interfaces:**
- Consumes: `MenuStyle.ROW_SELECTED_BG`, `ROW_SELECTED_BORDER`, `ROW_IDLE_BG`, `ROW_IDLE_BORDER`, `OUTLINE_COLOR`, `OUTLINE_SIZE`, `TITLE_SIZE`, `ROW_SIZE`, `FOOTER_SIZE`, `CARET`, `NO_CARET` (all already declared).
- Produces, on `MenuStyle`:
  - `SUBTITLE_SIZE := 18`
  - `panel_style() -> StyleBoxFlat` (one cached instance)
  - `apply_panel(panel: PanelContainer) -> void`
  - `row_box(picked: bool) -> StyleBoxFlat` (two cached instances)
  - `row_panel(picked: bool) -> PanelContainer` (a fresh `PanelContainer` carrying `row_box(picked)`)
  - `title_font() -> FontVariation`, `numeral_font() -> FontVariation` (cached)
  - `apply_title(label: Label) -> void`
  - `rule(ci: CanvasItem, from: Vector2, to: Vector2) -> void`
- Produces, on `TableMenu` and `CasinoMenu`: rows are now `PanelContainer` wrapping a `Label`, and the row `Label` carries `style_label()`'s outline.

**The three defects this task closes.** `WheelMenu.WHEEL_FOOTER` is deleted in Task 5, where the file is being rewritten anyway. The other two are here: `MenuStyle`'s four `ROW_*` constants become real, and `TableMenu.refresh()` starts outlining its rows, which it has never done (see the survey above; `CasinoMenu` does, which is why the existing test missed it).

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_menu_style.gd`:

```gdscript
## ONE PANEL STYLE, NOT TEN COPIES. The MenuPanel StyleBoxFlat was duplicated verbatim into
## every menu .tscn in the game, so "change the look of a panel" meant editing ten scene
## files and getting one of them wrong.
func test_the_panel_style_is_one_shared_instance_with_the_shipped_numbers() -> void:
	var a: StyleBoxFlat = MenuStyleScript.panel_style()
	var b: StyleBoxFlat = MenuStyleScript.panel_style()
	assert_eq(a, b, "cached: every panel in the game points at the same box")
	assert_eq(a.bg_color, Color(0.0392157, 0.0470588, 0.0784314, 0.88))
	assert_eq(a.border_color, Color(1, 0.858824, 0.552941, 0.32))
	assert_eq(a.corner_radius_top_left, 12)
	assert_eq(a.border_width_top, 1)


## THE ROW TREATMENT THE STYLE FILE ALREADY INTENDED. These four constants shipped declared
## and unread, because every row in the game was a bare Label with a two character caret.
func test_the_row_box_uses_the_declared_row_colours_and_differs_when_picked() -> void:
	var picked: StyleBoxFlat = MenuStyleScript.row_box(true)
	var idle: StyleBoxFlat = MenuStyleScript.row_box(false)
	assert_eq(picked.bg_color, MenuStyleScript.ROW_SELECTED_BG)
	assert_eq(picked.border_color, MenuStyleScript.ROW_SELECTED_BORDER)
	assert_eq(idle.bg_color, MenuStyleScript.ROW_IDLE_BG)
	assert_eq(idle.border_color, MenuStyleScript.ROW_IDLE_BORDER)
	assert_ne(picked.bg_color, idle.bg_color,
		"a highlight nobody can see is not a highlight")


## A WEIGHT HIERARCHY FOR ZERO ASSETS. There is no .ttf in this project and this slice does
## not add one; a FontVariation over the engine default is constructed in code, ships no file
## and needs no import.
func test_the_title_font_is_bolder_than_the_engine_default_and_is_cached() -> void:
	var font: FontVariation = MenuStyleScript.title_font()
	assert_eq(font, MenuStyleScript.title_font(), "cached")
	assert_gt(font.variation_embolden, 0.0)
	assert_gt(MenuStyleScript.title_font().variation_embolden,
		MenuStyleScript.numeral_font().variation_embolden,
		"a title is heavier than a number, and a number is heavier than prose")


func test_the_subtitle_size_sits_under_the_row_size() -> void:
	assert_lt(MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.ROW_SIZE)


## THE PANELS THEMSELVES. This existing test opened the ONE menu that was already outlining
## its rows, which is why every table in the Palace shipped with unoutlined rows over a
## translucent panel for a whole phase. It now asks a table as well.
func test_a_table_draws_its_rows_with_the_outline_and_in_a_row_box() -> void:
	var menu: CanvasLayer = load("res://ui/slots_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.set("can_open", func() -> bool: return true)
	menu.set("chips_provider", func() -> int: return 500)
	assert_true(bool(menu.call("open")))
	var rows := menu.get_node(^"Centre/Panel/Margin/Column/Rows") as VBoxContainer
	assert_gt(rows.get_child_count(), 0, "the table drew rows to check")
	var holder := rows.get_child(0) as PanelContainer
	assert_not_null(holder, "every cursor driven row sits in a PanelContainer now")
	var label := holder.get_child(0) as Label
	assert_not_null(label)
	assert_eq(label.get_theme_constant("outline_size"), MenuStyleScript.OUTLINE_SIZE)
```

Then FIX the existing `test_a_real_panel_draws_its_rows_with_the_outline()` in the same file, whose last three lines currently cast `rows.get_child(0)` straight to a `Label`:

```gdscript
	var rows := menu.get_node(^"Centre/Panel/Margin/Column/Rows") as VBoxContainer
	assert_gt(rows.get_child_count(), 0, "the lobby drew rows to check")
	var holder := rows.get_child(0) as PanelContainer
	assert_not_null(holder)
	var row := holder.get_child(0) as Label
	assert_eq(row.get_theme_constant("outline_size"), MenuStyleScript.OUTLINE_SIZE)
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_menu_style.gd -gexit 2>&1 | tail -20
```
Expected: five failures, the first reporting `Invalid call. Nonexistent function 'panel_style'`.

- [ ] **Step 3: Add the shared chrome to `menu_style.gd`**

Append to `game/ui/menu_style.gd`:

```gdscript
## A fourth size, for the tile descriptions and the COLOR_DIM second lines the casino's
## drawn screens carry. TITLE_SIZE, ROW_SIZE and FOOTER_SIZE are unchanged.
const SUBTITLE_SIZE := 18

## The rounded box's radius and its left inset, in 1920x1080 base pixels. The inset is what
## makes a selected row read as stepping forward out of the column rather than as a rectangle
## somebody painted behind it.
const ROW_RADIUS := 6
const ROW_INSET_LEFT := 4

## Cached so every panel in the game points at ONE StyleBox rather than at its own copy: this
## is the whole point of the function, and a fresh instance per call would be ten copies again
## with extra steps.
static var _panel_style: StyleBoxFlat = null
static var _row_boxes: Array[StyleBoxFlat] = []
static var _title_font: FontVariation = null
static var _numeral_font: FontVariation = null


## THE PANEL BEHIND EVERY MENU IN THE GAME, and until this function existed it was a
## StyleBoxFlat copy pasted verbatim into ten .tscn files. The numbers below are those
## copies, byte for byte, so this is a refactor and not a redesign: dark navy at 88 per cent,
## a one pixel warm gold border at 32 per cent, twelve pixel corners, no content margin
## (the Margin node owns that).
static func panel_style() -> StyleBoxFlat:
	if _panel_style != null:
		return _panel_style
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0392157, 0.0470588, 0.0784314, 0.88)
	box.set_border_width_all(1)
	box.border_color = Color(1, 0.858824, 0.552941, 0.32)
	box.set_corner_radius_all(12)
	box.content_margin_left = 0.0
	box.content_margin_top = 0.0
	box.content_margin_right = 0.0
	box.content_margin_bottom = 0.0
	_panel_style = box
	return _panel_style


static func apply_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override(&"panel", panel_style())


## THE ROW TREATMENT THIS FILE ALREADY SPECIFIED AND NOTHING DREW. ROW_SELECTED_BG,
## ROW_SELECTED_BORDER, ROW_IDLE_BG and ROW_IDLE_BORDER shipped declared and unread, because
## every row in the game was a bare Label carrying a two character caret and a colour swap.
##
## THE CARET STAYS. game/test/test_table_caret.gd and this file's own test read it, and a
## caret plus a highlight is more legible than either alone: the caret survives a screenshot
## at any size and reads for a player who cannot separate the two backgrounds by hue.
static func row_box(picked: bool) -> StyleBoxFlat:
	if _row_boxes.is_empty():
		for is_picked: bool in [false, true]:
			var box := StyleBoxFlat.new()
			box.bg_color = ROW_SELECTED_BG if is_picked else ROW_IDLE_BG
			box.border_color = ROW_SELECTED_BORDER if is_picked else ROW_IDLE_BORDER
			box.set_border_width_all(0)
			box.border_width_left = 3 if is_picked else 1
			box.set_corner_radius_all(ROW_RADIUS)
			box.content_margin_left = float(ROW_INSET_LEFT)
			box.content_margin_top = 2.0
			box.content_margin_right = 6.0
			box.content_margin_bottom = 2.0
			_row_boxes.append(box)
	return _row_boxes[1 if picked else 0]


## A fresh container carrying the shared box. The BOX is cached; the CONTAINER cannot be,
## because a Control lives in exactly one place in one tree.
static func row_panel(picked: bool) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_stylebox_override(&"panel", row_box(picked))
	return holder


## A REAL WEIGHT HIERARCHY FOR ZERO ASSETS. There is no .ttf anywhere in this project, no
## Theme resource, and this slice does not add either; every Label in the game renders in
## Godot's built in default font. A FontVariation is constructed in code over that default,
## ships no file and needs no import pass, so a title can be heavier than a row without any
## of the licence, size and import questions a display font brings with it.
static func title_font() -> FontVariation:
	if _title_font != null:
		return _title_font
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.55
	font.spacing_glyph = 2
	_title_font = font
	return _title_font


## For amounts: chips, bits, odds and stakes. Lighter than a title, heavier than prose, so a
## number reads as a number without shouting.
static func numeral_font() -> FontVariation:
	if _numeral_font != null:
		return _numeral_font
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.3
	_numeral_font = font
	return _numeral_font


static func apply_title(label: Label) -> void:
	if label == null:
		return
	style_label(label, TITLE_SIZE, COLOR_TITLE)
	label.add_theme_font_override(&"font", title_font())


## THE LINE UNDER A TITLE. Two pixels of gold fading to nothing at both ends, drawn as three
## segments because Godot's draw_line takes one colour: it is one piece of geometry and it
## does more for "this looks designed" than anything else on a text panel.
static func rule(ci: CanvasItem, from: Vector2, to: Vector2) -> void:
	var mid_a: Vector2 = from.lerp(to, 0.18)
	var mid_b: Vector2 = from.lerp(to, 0.82)
	var bright := Color(1.0, 0.86, 0.55, 0.85)
	var faded := Color(1.0, 0.86, 0.55, 0.0)
	ci.draw_line(from, mid_a, faded, 2.0, true)
	ci.draw_line(mid_a, mid_b, bright, 2.0, true)
	ci.draw_line(mid_b, to, faded, 2.0, true)
```

- [ ] **Step 4: Draw the rows in row boxes**

In `game/ui/table_menu.gd`, replace the row building loop at the bottom of `refresh()`:

```gdscript
	var lines: Array[String] = drawn_lines()
	var caret: int = _selected + first_row_line_index()
	for i in lines.size():
		var label := Label.new()
		var picked: bool = i == caret and row_count() > 0
		label.text = MenuStyleScript.caret(picked) + lines[i]
		label.add_theme_color_override("font_color",
			MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
		_rows.add_child(label)
```

with:

```gdscript
	MenuStyleScript.apply_title(_title)
	var lines: Array[String] = drawn_lines()
	var caret: int = _selected + first_row_line_index()
	for i in lines.size():
		var picked: bool = i == caret and row_count() > 0
		var label := Label.new()
		label.text = MenuStyleScript.caret(picked) + lines[i]
		# style_label() AND NOT A BARE font_color OVERRIDE. This line used to set the colour
		# alone, so every row on every table in the Palace shipped with no outline, over a
		# translucent panel, over a bright green field: exactly the readability failure
		# MenuStyle.OUTLINE_COLOR's own comment exists to prevent. CasinoMenu was already
		# doing it correctly, which is why the shared test never caught this one.
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE,
			MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
		var holder: PanelContainer = MenuStyleScript.row_panel(picked)
		holder.add_child(label)
		_rows.add_child(holder)
```

and add one line at the top of `_ready()`, above `visible = false`:

```gdscript
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
```

- [ ] **Step 5: Do the same in the other four cursor driven panels**

`game/ui/casino_menu.gd`: in `refresh()`, wrap its `label` in `MenuStyleScript.row_panel(picked)` exactly as above (its `style_label()` call is already correct, so only the wrapping and the `apply_title(_title)` line change), and add `MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)` to `_ready()`.

`game/ui/depot_menu.gd` and `game/ui/pause_menu.gd`: same two changes at their own `_rows.add_child(label)` sites.

`game/ui/market_menu.gd` and `game/ui/build_menu.gd` already build a `VBoxContainer` per row; wrap THAT container rather than a `Label`:

```gdscript
	var holder: PanelContainer = MenuStyleScript.row_panel(picked)
	holder.add_child(row)
	_rows.add_child(holder)
```

`game/ui/letter_panel.gd` is NOT touched: it draws prose with no cursor, and a selection box behind a paragraph of a letter is a menu pretending to be a menu it is not. See "The three calls this plan makes" above.

- [ ] **Step 6: Drop the ten copied `StyleBoxFlat`s**

For each of the ten `.tscn` files, delete the whole `[sub_resource type="StyleBoxFlat" id="MenuPanel"]` block and the `theme_override_styles/panel = SubResource("MenuPanel")` line on its `Panel` node, and drop `load_steps` by one.

```bash
for f in blackjack_menu build_menu casino_menu depot_menu letter_panel market_menu \
         pause_menu race_menu slots_menu wheel_menu; do
  python3 - "game/ui/$f.tscn" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
text = re.sub(r'\[sub_resource type="StyleBoxFlat" id="MenuPanel"\][^\[]*\n\n', '', text)
text = text.replace('theme_override_styles/panel = SubResource("MenuPanel")\n', '')
text = re.sub(r'load_steps=(\d+)', lambda m: 'load_steps=%d' % (int(m.group(1)) - 1), text, count=1)
open(path, 'w').write(text)
PY
done
grep -c MenuPanel game/ui/*.tscn
```
Expected: every count 0.

`letter_panel.tscn` loses its copy too, and `letter_panel.gd` gains the one `apply_panel()` line in `_ready()` so its panel keeps its look; that is the only change that file gets.

- [ ] **Step 7: Fold the HUD's duplicate styler onto the shared one**

In `game/ui/hud.gd`, delete `_style_label()` and its two line comment, add `const MenuStyleScript := preload("res://ui/menu_style.gd")` to the preloads at the top, and replace every `_style_label(` call site with `MenuStyleScript.style_label(`.

```bash
grep -c "_style_label(" game/ui/hud.gd     # 10 call sites plus the definition
sed -i 's/\b_style_label(/MenuStyleScript.style_label(/g' game/ui/hud.gd
```

Then remove the now orphaned definition by hand (the `sed` above renamed it too; delete the whole function). The HUD keeps its own colour constants and its own layout: only the duplicated styling function goes. **The outline size moves from 6 to 5,** which is `MenuStyle.OUTLINE_SIZE` and therefore what every other label in the game already uses; that is the point of folding them.

- [ ] **Step 8: Run the tests**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_menu_style.gd -gexit 2>&1 | tail -12
bash tools/run_tests.sh 2>&1 | tail -12
```
Expected: `test_menu_style.gd` all green, and the whole suite green. `test_letter_panel.gd`'s two `Rows`-walking tests must still pass, which is the check that the letter panel really was left alone.

- [ ] **Step 9: Run every gate**

```bash
for scene in market_test region_test world_test collection_test ledger_test depot_test \
             creation_test casino_test; do
  echo "--- $scene"
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" 2>&1 \
    | grep -E "_OK|_FAILED"
  echo "exit ${PIPESTATUS[0]}"
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```
Expected: every gate `_OK`, exit 0, and `RANCH_OK ponies=49 props=110 assets=present`.

- [ ] **Step 10: Commit**

```bash
printf 'feat: one chrome over every panel in the game\n\nThe MenuPanel StyleBoxFlat was copy pasted verbatim into ten menu scene files,\nso changing the look of a panel meant editing ten of them and getting one\nwrong. MenuStyle.panel_style() is now the one instance and every menu calls\napply_panel() in _ready().\n\nThe row treatment this style file already specified is real. ROW_SELECTED_BG,\nROW_SELECTED_BORDER, ROW_IDLE_BG and ROW_IDLE_BORDER shipped declared and read\nby nothing; row_box() builds them into a six pixel box with a left inset and\nevery cursor driven panel wraps its row in one. The caret stays: a caret plus a\nhighlight is more legible than either alone, and it survives a screenshot.\n\nA weight hierarchy for zero assets. There is no font file in this project and\nthis slice adds none; title_font() and numeral_font() are FontVariations over\nthe engine default, constructed in code, shipping no file and needing no\nimport.\n\nAnd a defect the shared test could not see: TableMenu.refresh() set a row s\nfont_color and nothing else, so every row on every table in the Palace shipped\nwith no outline over a translucent panel. CasinoMenu was doing it correctly,\nwhich is the only panel the old test opened. It now opens a table too.\n\nhud.gd s own _style_label() is folded onto MenuStyle.style_label(); the HUD\nkeeps its colours and its layout and loses the duplicate.\n' > /tmp/polish-task2.txt
git add game/ui/menu_style.gd game/ui/table_menu.gd game/ui/casino_menu.gd \
  game/ui/depot_menu.gd game/ui/pause_menu.gd game/ui/market_menu.gd \
  game/ui/build_menu.gd game/ui/letter_panel.gd game/ui/hud.gd \
  game/ui/*.tscn game/test/test_menu_style.gd
git commit -F /tmp/polish-task2.txt
```

---

### Task 3: The stage plumbing

**Files:**
- Modify: `game/ui/table_menu.gd`, `game/ui/casino_menu.gd`, `game/ui/slots_menu.tscn`, `game/ui/wheel_menu.tscn`, `game/ui/blackjack_menu.tscn`, `game/ui/race_menu.tscn`, `game/ui/casino_menu.tscn`, `game/scenes/test/casino_test.gd`
- Create: `game/test/test_casino_stages.gd`
- Test: `game/test/test_table_caret.gd` (rewritten), `game/test/test_casino_stages.gd` (new)

**Interfaces:**
- Consumes: `MenuStyle.row_panel()` and `apply_panel()` (Task 2); `CasinoPaint.focus_ring()` (Task 1).
- Produces, on `TableMenu` and mirrored verbatim on `CasinoMenu`:
  - `const STAGE_WIDTH := 1120.0`
  - `@onready var _stage: Control = $Centre/Panel/Margin/Column/Stage`
  - `paint(ci: Control) -> void` (the base paints nothing)
  - `printed_lines() -> Array[String]` (the base returns `drawn_lines()`)
  - `focus_rect() -> Rect2` in VIEWPORT coordinates
  - `focused_id() -> StringName`
  - `anim_time() -> float`
  - `animating() -> bool` (the base returns `false`)
  - `stage_size() -> Vector2`

**Why `printed_lines()` exists beside `drawn_lines()`.** `drawn_lines()` is the semantic model of the screen: `game/test/test_published_payouts.gd` parses the price back out of the English it returns, six menu test files read it, and the no dash sweeps walk it. It must not shrink when the paytable moves onto a drawn panel. So a table whose stage already SHOWS a line overrides `printed_lines()` to leave it out of the `Rows` column, and the panel stops saying the same thing twice while the model keeps saying all of it.

**Why `focus_rect()` is in viewport coordinates.** A stage reports a rect it computed in its own local space; the `Rows` column reports a `PanelContainer`'s rect in the column's space. Those are two different origins, and a gate that had to know which one it was looking at would be a gate that could be wrong. Everything is converted to the viewport before it leaves the menu, and the per stage `*_rect(i)` layout functions the later tasks add stay explicitly stage local for the pure geometry tests. **Layout is only valid after a frame:** every test below awaits one after `open()`.

- [ ] **Step 1: Rewrite the caret test onto the drawing**

Replace `game/test/test_table_caret.gd` in full:

```gdscript
extends GutTest
## WHERE THE CARET POINTS, at all three tables in the Palace.
##
## THE BUG THIS PINS. TableMenu.refresh() drew the "> " marker on drawn line number
## `_selected`, and `_selected` counts SELECTABLE ROWS while drawn_lines() counts PRINTED
## LINES. Those two agree exactly until the first spin, hand or bet, after which every table
## prints the last result above its rows: two result lines and a blank. From then on the
## caret sat three lines above the row it was actually on, so the slot machine highlighted
## the words "Apple Apple Apple" while the player was adjusting her stake.
##
## READ OFF THE DRAWING, NOT OFF A NUMBER, and that rule survived the stage. The whole defect
## lived in the gap between the number and the drawing, and a test that asked the menu where
## it THOUGHT the caret was would have agreed with the bug. So this file asks two things that
## are both downstream of the paint: the text of the row the marker was actually drawn on,
## and focus_rect(), which is where the focus ring was actually put.
##
## Nodes already queue_free()d are skipped: refresh() frees the previous row of holders and
## builds new ones in the same call, and a freed child is still among get_children() until
## the next idle frame.

const SlotsMenuScene := preload("res://ui/slots_menu.tscn")
const WheelMenuScene := preload("res://ui/wheel_menu.tscn")
const BlackjackMenuScene := preload("res://ui/blackjack_menu.tscn")
const WheelScript := preload("res://systems/wheel.gd")

const CHIPS := 500


## The line the caret is actually drawn on, marker stripped, or "" if nothing is marked.
## Every cursor driven row is a Label inside a PanelContainer since the chrome pass.
func _caret_line(menu: CanvasLayer) -> String:
	for holder in menu._rows.get_children():
		if holder.is_queued_for_deletion():
			continue
		for child in holder.get_children():
			var label := child as Label
			if label != null and label.text.begins_with("> "):
				return label.text.substr(2)
	return ""


func _open(scene: PackedScene) -> CanvasLayer:
	var menu: CanvasLayer = scene.instantiate()
	add_child_autofree(menu)
	menu.set("can_open", func() -> bool: return true)
	menu.set("chips_provider", func() -> int: return CHIPS)
	menu.call("open")
	await get_tree().process_frame
	return menu


func test_the_slot_machine_marks_the_stake_row_before_and_after_a_spin() -> void:
	var menu: CanvasLayer = await _open(SlotsMenuScene)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"before any spin the caret is on the stake row: '%s'" % _caret_line(menu))
	var spun: Array[String] = ["Apple Apple Apple", "You win 40 chips."]
	menu.call("show_result", spun)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"after a spin the caret must still be on the stake row, not up in the result: '%s'"
			% _caret_line(menu))


func test_the_blackjack_table_marks_the_stake_row_before_and_after_a_hand() -> void:
	var menu: CanvasLayer = await _open(BlackjackMenuScene)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"before any hand the caret is on the stake row: '%s'" % _caret_line(menu))
	var dealt: Array[String] = ["You: Ace, King", "Dealer: Nine, Seven", "Blackjack."]
	menu.call("show_result", dealt)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"after a hand the caret must still be on the stake row: '%s'" % _caret_line(menu))


func test_the_wheel_marks_the_guess_it_is_backing_before_and_after_a_spin() -> void:
	var menu: CanvasLayer = await _open(WheelMenuScene)
	assert_eq(String(menu.call("focused_id")), "guess:0",
		"before any spin the focus is on the first bet")
	var spun: Array[String] = [WheelScript.pocket_text(7), "The house takes that one."]
	menu.call("show_result", spun)
	assert_eq(String(menu.call("focused_id")), "guess:0",
		"after a spin the focus must still be on the bet, not up in the result")


## And it follows the cursor all the way onto the stake row, which is the row that only
## exists because of the other half of this fix. See test_wheel_menu.gd.
func test_the_wheel_s_caret_follows_the_cursor_onto_the_stake_row() -> void:
	var menu: CanvasLayer = await _open(WheelMenuScene)
	var spun: Array[String] = [WheelScript.pocket_text(7), "The house takes that one."]
	menu.call("show_result", spun)
	menu.call("move_selection", int(menu.call("guess_count")))
	assert_eq(String(menu.call("focused_id")), "stake:0",
		"one press past the last colour is the stake row")


## THE RING IS SOMEWHERE, and it is somewhere on the panel. A focus_rect() of zero size is a
## menu that thinks it has a cursor and paints none, which is the same class of defect as the
## caret pointing at the wrong line: the number says one thing and the drawing says nothing.
func test_every_table_paints_its_focus_ring_somewhere_real() -> void:
	for scene: PackedScene in [SlotsMenuScene, WheelMenuScene, BlackjackMenuScene]:
		var menu: CanvasLayer = await _open(scene)
		var rect: Rect2 = menu.call("focus_rect")
		assert_gt(rect.size.x, 0.0, "%s painted a zero width focus" % scene.resource_path)
		assert_gt(rect.size.y, 0.0, "%s painted a zero height focus" % scene.resource_path)
		assert_ne(String(menu.call("focused_id")), "",
			"%s knows what it is focused on" % scene.resource_path)
```

- [ ] **Step 2: Write the shared stage contract test**

Create `game/test/test_casino_stages.gd`:

```gdscript
extends GutTest
## THE CONTRACT EVERY DRAWN CASINO SCREEN HOLDS, asked of all five of them by one loop.
##
## WHY THIS FILE IS NOT FIVE FILES. These are not five assertions about five screens; they
## are one assertion about the stage mechanism, and a per screen copy of it would drift. The
## screen specific geometry (a reel window is 180 by 300, a lobby tile is 340 by 200) is
## asserted in each screen's own test file by its own *_rect() function.
##
## LAYOUT IS ONLY VALID AFTER A FRAME. A Control's rect is whatever it was before the
## container has run, so every helper below awaits one after open().

const MenuScenes: Array[String] = [
	"res://ui/slots_menu.tscn",
	"res://ui/wheel_menu.tscn",
	"res://ui/blackjack_menu.tscn",
	"res://ui/race_menu.tscn",
	"res://ui/casino_menu.tscn",
]

const CHIPS := 500
const BITS := 500


func _open(path: String) -> CanvasLayer:
	var menu: CanvasLayer = (load(path) as PackedScene).instantiate()
	add_child_autofree(menu)
	menu.set("can_open", func() -> bool: return true)
	menu.set("chips_provider", func() -> int: return CHIPS)
	if menu.has_method("header_line"):
		menu.set("bits_provider", func() -> int: return BITS)
		menu.set("sign_provider", func() -> Array[String]:
			return ["House rules", "Every edge we keep."] as Array[String])
	if "entrants_provider" in menu:
		menu.set("entrants_provider", func() -> Array[Dictionary]: return [
			{"uid": &"a", "name": "Mote", "happiness": 0.8, "odds": 3.5, "chance": 0.28},
			{"uid": &"b", "name": "Pip", "happiness": 0.4, "odds": 7.0, "chance": 0.14},
		] as Array[Dictionary])
	assert_true(bool(menu.call("open")), "%s opened" % path)
	await get_tree().process_frame
	return menu


## EVERY SCREEN HAS A STAGE, AND IT IS THE WIDTH THE PANEL WAS WIDENED TO. A stage that
## instantiated at zero size draws nothing and would pass every geometry test in the branch.
func test_every_casino_screen_has_a_stage_of_the_shared_width() -> void:
	for path: String in MenuScenes:
		var menu: CanvasLayer = await _open(path)
		var size: Vector2 = menu.call("stage_size")
		assert_almost_eq(size.x, 1120.0, 1.0, "%s stage width" % path)
		assert_gt(size.y, 100.0, "%s stage height" % path)


## THE MODEL KEEPS SAYING EVERYTHING. printed_lines() is what the Rows column still prints;
## drawn_lines() is the whole text model and is what test_published_payouts.gd parses. A
## printed line that is not in the model would be a sentence no test can see.
func test_every_printed_line_is_still_in_the_text_model() -> void:
	for path: String in MenuScenes:
		var menu: CanvasLayer = await _open(path)
		var model: Array[String] = menu.call("drawn_lines")
		var printed: Array[String] = menu.call("printed_lines")
		assert_le(printed.size(), model.size(), "%s prints no more than it models" % path)
		for line: String in printed:
			assert_true(model.has(line), "%s printed a line the model does not carry: '%s'"
				% [path, line])


## THE RING GOES WHERE THE CURSOR IS, on every row of every tab, on every screen. This is the
## whole reason focus_rect() and focused_id() exist rather than a bare index: the defect
## test_table_caret.gd was written for lived entirely in the gap between the two.
func test_the_focus_follows_the_cursor_across_every_row_of_every_tab() -> void:
	for path: String in MenuScenes:
		var menu: CanvasLayer = await _open(path)
		var tabs: int = 3 if menu.has_method("header_line") else 2
		for tab: int in tabs:
			if menu.has_method("set_tab"):
				menu.call("set_tab", tab)
				await get_tree().process_frame
			var seen: Dictionary = {}
			var rows: int = int(menu.call("row_count")) if menu.has_method("row_count") \
				else int(menu.call("_row_count"))
			for row: int in rows:
				menu.call("move_selection", 1 if row > 0 else 0)
				await get_tree().process_frame
				var id: StringName = menu.call("focused_id")
				assert_ne(String(id), "", "%s tab %d row %d has no focus id"
					% [path, tab, row])
				assert_false(seen.has(id),
					"%s tab %d gave two rows the same focus id: %s" % [path, tab, id])
				seen[id] = true
				var rect: Rect2 = menu.call("focus_rect")
				assert_gt(rect.size.x * rect.size.y, 0.0,
					"%s tab %d row %d painted an empty focus" % [path, tab, row])


## A PUSH WITH A VALUE FROM OUTSIDE THE GAME MUST DEGRADE TO A STILL FRAME. These arrive over
## a dynamic call() from ranch.gd, so nothing type checks them at the call site; a gate
## calling play_wheel() directly can hand a menu a pocket that does not exist, and the answer
## to that is a screen that shows nothing rather than a screen that takes the game down.
func test_an_out_of_range_push_degrades_to_a_still_frame() -> void:
	var slots: CanvasLayer = await _open("res://ui/slots_menu.tscn")
	slots.call("show_spin", [] as Array[int], 0, 10)
	slots.call("show_spin", [99, -1, 400] as Array[int], 0, 10)
	var wheel: CanvasLayer = await _open("res://ui/wheel_menu.tscn")
	wheel.call("show_spin", 99, 0, 10)
	wheel.call("show_spin", -7, 0, 10)
	var blackjack: CanvasLayer = await _open("res://ui/blackjack_menu.tscn")
	blackjack.call("show_hand", {} as Dictionary, 0, 10)
	blackjack.call("show_hand",
		{"player": [300, -4] as Array[int], "dealer": [] as Array[int], "outcome": 9}, 0, 10)
	await get_tree().process_frame
	pass_test("four bad pushes and the screens are still standing")
```

Steps 3 and 4 below make these pass; the `show_spin`/`show_hand` calls above land on the no op stubs added in step 4 until Tasks 4, 5 and 6 give them real animations, which is why this test can be written now and never has to be written again.

- [ ] **Step 3: Run both tests to verify they fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_table_caret.gd -gexit 2>&1 | tail -8
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_casino_stages.gd -gexit 2>&1 | tail -8
```
Expected: both red, reporting `Nonexistent function 'focused_id'` and `Nonexistent function 'stage_size'`.

- [ ] **Step 4: Add the stage to `table_menu.gd`**

In `game/ui/table_menu.gd`, add the preload, the constant and the two vars at the top:

```gdscript
## DECLARED HERE AND NOWHERE ELSE ON A TABLE. The base itself paints nothing, but every table
## that extends this one paints through the kit, and GDScript refuses a const that shadows one
## declared on the parent class (the same rule WHEEL_FOOTER's own comment records). So
## slots_menu.gd, wheel_menu.gd, blackjack_menu.gd and race_menu.gd inherit this and must not
## re-declare it; casino_menu.gd is not a TableMenu and declares its own.
const PaintScript := preload("res://ui/casino_paint.gd")

## The stage's width in 1920x1080 base pixels: the Panel's 1180 minus the Margin node's
## 30 either side. Every drawn screen in the building is laid out against this one number, so
## a rect computed on the slot machine and a rect computed on the wheel mean the same thing.
const STAGE_WIDTH := 1120.0

## Seconds since this menu opened, advanced in _process while it is up. Read by paint() for
## the focus ring's breath and by every stage's own animation. NOT a clock: it is reset on
## open() so a screen looks the same the second time you walk up to it.
var _anim_t := 0.0
```

and the stage handle beside the other `@onready`s:

```gdscript
@onready var _stage: Control = get_node_or_null(^"Centre/Panel/Margin/Column/Stage")
```

`get_node_or_null` and not `$`: `TableMenu` is also the base of panels that may not have grown a stage yet, and a missing node must be a screen that draws no stage rather than a boot that dies.

In `_ready()`, after the `apply_panel()` line from Task 2:

```gdscript
	if _stage != null:
		_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.custom_minimum_size = stage_size()
		_stage.draw.connect(_paint_stage)
	set_process(false)
```

In `open()`, after `_result = []`:

```gdscript
	_anim_t = 0.0
	set_process(true)
```

In `close()`, after `visible = false`:

```gdscript
	set_process(false)
```

Then add the new members at the bottom of the "what a table fills in" block:

```gdscript
# --- the stage ------------------------------------------------------------------------------

## THE MENU REDRAWS WHILE IT IS OPEN AND NEVER WHILE IT IS SHUT. Every casino screen has at
## least one thing moving on it the whole time it is up (the focus ring breathes, so a still
## screenshot and a live screen say the same thing about where the cursor is), and the world
## is paused behind it, so "while open" IS the window in which an animation is live. Closed,
## set_process(false) stops it dead: a menu nobody is looking at must cost nothing, which is
## the same discipline SkyRig._needs_ticks() follows.
func _process(delta: float) -> void:
	if not _open or _stage == null:
		return
	_anim_t += delta
	_stage.queue_redraw()


func _paint_stage() -> void:
	if _stage != null:
		paint(_stage)


func anim_time() -> float:
	return _anim_t


## What this table paints. Overridden by each table; the base paints nothing, which is the
## right answer for a table that has no stage yet.
func paint(_ci: Control) -> void:
	pass


## THE SIZE THE STAGE NODE RESERVES. Overridden per table; a table with no stage reserves
## nothing and its column closes over the gap.
func stage_size() -> Vector2:
	return Vector2.ZERO


## Whether an animation is running RIGHT NOW, as opposed to the idle breath. While this is
## true confirm() refuses and move_selection() is ignored, so a spin cannot be started twice
## or re staked halfway through; ui_cancel still closes, because a player who wants out of a
## spinning reel gets out.
func animating() -> bool:
	return false


## THE LINES THE Rows VBOX ACTUALLY PRINTS. drawn_lines() stays the whole text model of the
## screen and is what the tests and game/test/test_published_payouts.gd read; a table whose
## stage already SHOWS a line overrides this to leave it out of the column, so the panel does
## not say the same thing twice.
func printed_lines() -> Array[String]:
	return drawn_lines()


## WHERE THE FOCUS RING WAS LAST ACTUALLY PAINTED, in VIEWPORT coordinates, and what it was
## painted on. For the caret test, which must keep asking the DRAWING where the cursor is
## rather than asking the number; see game/test/test_table_caret.gd for the defect that rule
## exists for.
##
## VIEWPORT AND NOT STAGE LOCAL, because the answer can come from either of two coordinate
## spaces: a stage computes its rects in its own, and a table with no stage yet reports the
## row PanelContainer refresh() marked, which is in the Rows column's. A caller that had to
## know which one it was looking at is a caller that can be wrong.
func focus_rect() -> Rect2:
	for holder in _rows.get_children():
		if holder.is_queued_for_deletion():
			continue
		var panel := holder as PanelContainer
		if panel == null:
			continue
		for child in panel.get_children():
			var label := child as Label
			if label != null and label.text.begins_with(MenuStyleScript.CARET):
				return panel.get_global_rect()
	return Rect2()


func focused_id() -> StringName:
	return StringName("row:%d" % _selected) if row_count() > 0 else &""


## The stage's own rect in viewport coordinates, so a stage can hand a local rect back out
## through focus_rect() without every stage repeating the conversion.
func to_viewport(local: Rect2) -> Rect2:
	if _stage == null:
		return Rect2()
	return Rect2(_stage.get_global_rect().position + local.position, local.size)
```

Finally, in `refresh()`, change three lines: iterate `printed_lines()` instead of `drawn_lines()`, and redraw the stage.

```gdscript
	if _stage != null:
		_stage.custom_minimum_size = stage_size()
		_stage.queue_redraw()
	var lines: Array[String] = printed_lines()
```

`first_row_line_index()` keeps its meaning and now indexes into `printed_lines()`; every table's override is adjusted in its own task.

- [ ] **Step 5: Mirror the same members onto `casino_menu.gd`**

`CasinoMenu` is not a `TableMenu` (it is its own `CanvasLayer` with the same tree), so it gets the same block: the `PaintScript` preload, `STAGE_WIDTH`, `_anim_t`, the `_stage` `@onready`, the `_ready()` wiring, `set_process(true)` in `open()` and `false` in `close()`, `_process()`, `_paint_stage()`, `anim_time()`, `paint()`, `stage_size()`, `animating()`, `printed_lines()`, `focus_rect()`, `focused_id()`, `to_viewport()`, and `refresh()` iterating `printed_lines()`. Copy them verbatim; the only difference is that `focused_id()` reads `_row_count()` rather than `row_count()`.

This is a deliberate duplication rather than a new shared base class. `CasinoMenu` and `TableMenu` differ in their signals, their tabs, their row semantics and their providers; the only thing they share is a scene tree, and hoisting a base class for twelve members would put the lobby and the tables on one inheritance chain for the rest of the project's life to save forty lines once.

- [ ] **Step 6: Add the `Stage` node to the five scenes**

In each of `slots_menu.tscn`, `wheel_menu.tscn`, `blackjack_menu.tscn`, `race_menu.tscn` and `casino_menu.tscn`: widen the panel and insert one node between `Tabs` and `Rows`.

```bash
for f in slots_menu wheel_menu blackjack_menu race_menu casino_menu; do
  python3 - "game/ui/$f.tscn" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
text = text.replace('custom_minimum_size = Vector2(860, 0)',
                    'custom_minimum_size = Vector2(1180, 0)')
stage = ('[node name="Stage" type="Control" parent="Centre/Panel/Margin/Column"]\n'
         'layout_mode = 2\n'
         'mouse_filter = 2\n\n')
anchor = '[node name="Rows" type="VBoxContainer" parent="Centre/Panel/Margin/Column"]'
assert anchor in text, path
text = text.replace(anchor, stage + anchor, 1)
open(path, 'w').write(text)
PY
done
grep -n "Stage\|custom_minimum_size" game/ui/slots_menu.tscn
```
Expected: `custom_minimum_size = Vector2(1180, 0)` on the `Panel`, and a `Stage` node declared immediately above `Rows`.

**1180 fits.** The project's base viewport is 1920 by 1080 with `canvas_items` stretch, so a 1180 wide panel leaves 370 px of margin either side.

- [ ] **Step 7: Add the stage block to the casino gate**

In `game/scenes/test/casino_test.gd`, in the hosted half, after the block that opens the lobby and checks `can_open` (the `_set_check("the lobby refuses to open over another menu, ...")` line), add:

```gdscript
	# --- the drawn stages --------------------------------------------------------------------
	# THE CASINO'S SCREENS CANNOT BE SCREENSHOTTED. ranch.tscn's render pass drives a
	# Camera3D through the world; a CanvasLayer menu is not on that path and never appears in
	# a shot, so the only judgement these five screens can get from a gate is their GEOMETRY.
	# That is what the *_rect() layout functions on each stage are for: they are pure, they
	# are the same numbers paint() draws with, and a rect that has walked off its own stage is
	# the failure that actually happens when a screen is laid out by eye.
	var stages_ok := true
	var stage_focus_ok := true
	for row: int in [CasinoMenuScript.Row.SLOTS, CasinoMenuScript.Row.WHEEL,
			CasinoMenuScript.Row.BLACKJACK, CasinoMenuScript.Row.RACING]:
		var table: CanvasLayer = ranch.get_table_menu(row)
		if table == null:
			stages_ok = false
			continue
		table.call("open")
		await get_tree().process_frame
		var size: Vector2 = table.call("stage_size")
		if size.x <= 0.0 or size.y <= 0.0:
			stages_ok = false
			push_error("casino: %s reserved no stage" % table.name)
		var rect: Rect2 = table.call("focus_rect")
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			stage_focus_ok = false
			push_error("casino: %s painted no focus ring" % table.name)
		print("CASINO stage %-14s size=(%.0f, %.0f) focus=(%.0f, %.0f) id=%s"
			% [table.name, size.x, size.y, rect.size.x, rect.size.y,
				String(table.call("focused_id"))])
		table.call("close")
		await get_tree().process_frame
	_set_check("every table reserves a drawn stage", stages_ok)
	_set_check("every table paints its focus ring somewhere real", stage_focus_ok)
```

- [ ] **Step 8: Run the tests and the gate**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_table_caret.gd -gexit 2>&1 | tail -8
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_casino_stages.gd -gexit 2>&1 | tail -8
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn 2>&1 \
  | grep -E "CASINO stage|CASINO_OK|CASINO_FAILED"
bash tools/run_tests.sh 2>&1 | tail -12
```
Expected: both test files green, four `CASINO stage` lines each reporting `size=(1120, ...)` and a non zero focus, `CASINO_OK checks=<n>` with two more checks than before, and the whole suite green.

- [ ] **Step 9: Commit**

```bash
printf 'feat: every casino screen gets a stage to draw on\n\nOne new node per menu: Stage, a bare Control between Tabs and Rows, painted\nthrough a paint() virtual on table_menu.gd. The panel widens from 860 to 1180,\nwhich leaves 370 pixels of margin either side of the 1920 base viewport.\n\ndrawn_lines() is untouched on every menu and stays the whole text model of the\nscreen: it is what test_published_payouts.gd parses the price back out of and\nwhat the no dash sweeps walk. printed_lines() is new and says which of those\nlines the Rows column still prints, so a table whose stage already shows the\npaytable stops saying it twice.\n\nfocus_rect() and focused_id() report where the ring was ACTUALLY painted, in\nviewport coordinates. test_table_caret.gd is rewritten onto them and keeps its\nspirit exactly: it asks the drawing rather than the number, because the whole\ndefect it was written for lived in the gap between the two.\n\nThe casino gate grew a stage block. These five screens are CanvasLayer menus\nand can never appear in a screenshot, so their geometry is the only judgement a\ngate can give them: the stage is the shared width, and the ring is somewhere\nreal.\n' > /tmp/polish-task3.txt
git add game/ui/table_menu.gd game/ui/casino_menu.gd game/ui/slots_menu.tscn \
  game/ui/wheel_menu.tscn game/ui/blackjack_menu.tscn game/ui/race_menu.tscn \
  game/ui/casino_menu.tscn game/scenes/test/casino_test.gd \
  game/test/test_table_caret.gd game/test/test_casino_stages.gd \
  game/test/test_casino_stages.gd.uid
git commit -F /tmp/polish-task3.txt
```

---

### Task 4: The slot machine

**Files:**
- Modify: `game/ui/slots_menu.gd`, `game/world/ranch.gd` (one added block in `play_slots()`), `game/test/test_slots_menu.gd`
- Test: `game/test/test_slots_menu.gd`

**Interfaces:**
- Consumes: `CasinoPaint.rounded/chip/focus_ring/text/draw_symbol` (Task 1); `TableMenu.STAGE_WIDTH`, `paint()`, `printed_lines()`, `focus_rect()`, `focused_id()`, `stage_size()`, `animating()`, `anim_time()`, `to_viewport()` (Task 3); `Slots.strip()`, `Slots.REEL_SIZE`, `Slots.SYMBOL_NAMES`, `Slots.paytable_lines()`, `Slots.TRIPLE_PAYS`.
- Produces, on `SlotsMenu`:
  - `show_spin(reels: Array[int], won: int, stake: int) -> void`
  - `cabinet_rect() -> Rect2`, `reel_rect(i: int) -> Rect2`, `paytable_rect() -> Rect2`, `stake_chip_rect(i: int) -> Rect2`, `payline_y() -> float`, all stage local
  - `reel_offset(i: int) -> float` (the live scroll position of reel `i`, in strip positions)
- Produces, on `Ranch`: `play_slots()` also calls `slots_menu.call("show_spin", reels, won, stake)`.

**The input model does not change in any particular.** `row_count()` is still `stakes().size()`, `move_selection()` still moves the stake index, `confirm()` still emits `spin_requested(selected_stake())`. What changes is that `printed_lines()` drops eleven of the fifteen lines onto the stage.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_slots_menu.gd`:

```gdscript
const PaintScript := preload("res://ui/casino_paint.gd")


## THE CABINET AND THE PAYTABLE DIVIDE THE STAGE AND NEITHER LEAVES IT. Laid out by eye, a
## panel that is 20 px too wide looks fine on the machine it was authored on and clips on the
## next one, because every 2D size in this project is in 1920x1080 base pixels and the window
## is 1600x900.
func test_every_drawn_region_sits_inside_the_stage() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	for pair: Array in [[_menu.cabinet_rect(), "cabinet"],
			[_menu.paytable_rect(), "paytable"]]:
		assert_true(stage.encloses(pair[0] as Rect2),
			"the %s leaves the stage: %s" % [pair[1], pair[0]])
	for i: int in 3:
		assert_true(_menu.cabinet_rect().encloses(_menu.reel_rect(i)),
			"reel window %d leaves the cabinet" % i)


## THREE WINDOWS, NO OVERLAP, IN ORDER. Reels drawn on top of each other are the failure a
## rect test catches and a screenshot does not, because two reels landing on the same symbol
## look correct.
func test_the_three_reel_windows_are_separate_and_left_to_right() -> void:
	for i: int in 2:
		var here: Rect2 = _menu.reel_rect(i)
		var next: Rect2 = _menu.reel_rect(i + 1)
		assert_lt(here.position.x + here.size.x, next.position.x,
			"reel %d overlaps reel %d" % [i, i + 1])


## THE PAYLINE IS THE MIDDLE ROW OF EVERY WINDOW, and the player has to be able to see which
## row counts BEFORE she spins.
func test_the_payline_crosses_the_middle_of_every_reel_window() -> void:
	for i: int in 3:
		var window: Rect2 = _menu.reel_rect(i)
		assert_almost_eq(_menu.payline_y(), window.position.y + window.size.y * 0.5, 1.0)


## THE PAYTABLE MOVED TO THE STAGE AND THE MODEL STILL CARRIES IT. This is the whole reason
## printed_lines() exists beside drawn_lines(): test_published_payouts.gd parses the price out
## of these eight strings and a menu that stopped returning them would take that guard with
## it silently.
func test_the_paytable_leaves_the_column_and_stays_in_the_model() -> void:
	var model: Array[String] = _menu.drawn_lines()
	var printed: Array[String] = _menu.printed_lines()
	for line: String in SlotsScript.paytable_lines():
		assert_true(model.has(line), "the model still carries '%s'" % line)
		assert_false(printed.has(line), "the column stopped printing '%s'" % line)


## A SPIN LANDS ON THE VALUE ranch.gd ALREADY ROLLED, and nothing here rolls anything. The
## stage is TOLD the reels; the tween's target is that value and no other.
func test_a_pushed_spin_lands_every_reel_on_the_symbol_it_was_handed() -> void:
	var reels: Array[int] = [2, 5, 0]
	_menu.show_spin(reels, 0, 10)
	assert_true(_menu.animating(), "the reels are running")
	# Run the tween out rather than waiting on wall clock: SPIN_SECONDS is a constant.
	for i: int in 130:
		await get_tree().process_frame
	assert_false(_menu.animating(), "the reels have settled")
	var strip: Array[int] = SlotsScript.strip()
	for reel: int in 3:
		var landed: int = strip[posmod(roundi(_menu.reel_offset(reel)),
			SlotsScript.REEL_SIZE)]
		assert_eq(landed, reels[reel],
			"reel %d settled on %s and was handed %s" % [reel,
				SlotsScript.SYMBOL_NAMES[landed], SlotsScript.SYMBOL_NAMES[reels[reel]]])


## AN EMPTY OR OUT OF RANGE PUSH IS A STILL FRAME, not an error. These arrive over a dynamic
## call() and a gate calling ranch.play_slots() directly can produce one.
func test_a_bad_push_leaves_the_reels_where_they_were() -> void:
	var before: float = _menu.reel_offset(0)
	_menu.show_spin([] as Array[int], 0, 10)
	assert_false(_menu.animating(), "an empty reel array starts no spin")
	assert_eq(_menu.reel_offset(0), before)
	_menu.show_spin([99, -3, 7] as Array[int], 0, 10)
	assert_false(_menu.animating(), "a symbol that is not on the strip starts no spin")


## THE STAKE IS STILL THE ONLY THING THE CURSOR MOVES.
func test_the_focus_id_names_the_stake_the_cursor_is_on() -> void:
	assert_eq(String(_menu.focused_id()), "stake:0")
	_menu.move_selection(1)
	assert_eq(String(_menu.focused_id()), "stake:1")
```

The file's existing `_menu` fixture opens a `SlotsMenu` with a chips provider; if it does not yet await a frame after `open()`, add one, because `focus_rect()` needs layout.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_slots_menu.gd -gexit 2>&1 | tail -10
```
Expected: seven failures, the first `Nonexistent function 'cabinet_rect'`.

- [ ] **Step 3: Write the machine**

Replace `game/ui/slots_menu.gd` in full:

```gdscript
class_name SlotsMenu
extends "res://ui/table_menu.gd"
## THE SLOT MACHINE. A cabinet with three reel windows, a payline, a lever and a paytable,
## and it spins nothing: ranch.gd rolls the seeded generator, settles the chips and pushes
## the outcome back through show_spin(). The tween's target is the value Slots.spin() already
## produced; there is no path by which anything on this screen can influence it, because the
## outcome arrives AFTER the chips have already moved.
##
## THE INPUT MODEL IS UNCHANGED IN EVERY PARTICULAR. row_count() is still stakes().size(),
## move_selection() still moves the stake index, confirm() still emits spin_requested().
##
## WHAT MOVED IS WHERE THE WORDS ARE. drawn_lines() still returns all fifteen lines, because
## it is the semantic model of the screen and game/test/test_published_payouts.gd parses the
## price back out of the eight paytable strings. printed_lines() drops eleven of them onto
## the stage, so the column under the cabinet is two lines instead of fifteen.
##
## Extended by path rather than by the global class_name, for the reason every preload in
## this project is by path: the class cache lives in the gitignored game/.godot/.

const SlotsScript := preload("res://systems/slots.gd")

const TITLE := "Slots"

# --- the cabinet, in stage local pixels ------------------------------------------------------
const STAGE_HEIGHT := 480.0
const CABINET := Rect2(0.0, 0.0, 700.0, 420.0)
const PAYTABLE := Rect2(720.0, 0.0, 400.0, 420.0)
const HEADBOARD := Rect2(24.0, 14.0, 652.0, 52.0)
const REEL_SIZE_PX := Vector2(180.0, 300.0)
const REEL_TOP := 86.0
const REEL_LEFT := 40.0
const REEL_PITCH := 216.0
const CELL_HEIGHT := 96.0
const LEVER_X := 676.0
const STAKE_ROW_Y := 452.0
const STAKE_PITCH := 96.0
const CHIP_RADIUS := 30.0

## Nine bulbs whose alpha chases left to right on this loop. The ONLY thing that moves while
## nothing is happening, which is what makes the cabinet read as a machine that is switched on
## rather than as a picture of one.
const BULBS := 9
const BULB_CHASE_SECONDS := 1.2

# --- the spin, and every one of these is a CONSTANT ------------------------------------------
# A spin whose length varied would be a generator living under game/ui/, which is the one
# thing this file may not have. See game/test/test_casino_paint.gd's last test.
const LEVER_DROP_SECONDS := 0.12
const LEVER_RISE_SECONDS := 0.35
const SPIN_UP_SECONDS := 0.15
const REEL_SPEED := 22.0
const LAND_FIRST := 0.60
const LAND_STAGGER := 0.35
const LAND_SECONDS := 0.45
const WIN_FLASH_SECONDS := 0.6
const COUNTER_SECONDS := 0.5

## Whole strip turns a reel makes before it lands, so the ribbon has visibly run rather than
## jumped. Landing i begins at LAND_FIRST + i * LAND_STAGGER, so the three settle left to
## right at 0.60, 0.95 and 1.30 seconds and the whole spin is 1.75.
const SPIN_TURNS := 3

signal spin_requested(stake: int)

var _reel_offset: Array[float] = [0.0, 0.0, 0.0]
var _lever := 0.0
var _flash := 0.0
var _shown_chips := 0.0
var _spinning := false
var _tween: Tween = null


func title_text() -> String:
	return TITLE


func tabs_text() -> String:
	return "Pull the lever. The house keeps %.1f bits of every 100." \
		% (SlotsScript.house_edge() * 100.0)


func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


func drawn_lines() -> Array[String]:
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	lines.append_array(stake_lines())
	if not stakes().is_empty():
		lines.append("Spin for %d chips" % selected_stake())
	lines.append("")
	for line in SlotsScript.paytable_lines():
		lines.append(line)
	return lines


## THE STAKE ROW, THE SPIN LINE AND THE WHOLE PAYTABLE ARE ON THE CABINET NOW. What is left in
## the column is the two lines that are not pictures: what she is holding, and what the keys
## do. The last result stays too, because a player who looked away wants the sentence.
func printed_lines() -> Array[String]:
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	return lines


## Every printed line is above the cursor, and the cursor is not in the column at all any
## more: it is on a drawn chip. Zero, so refresh() marks nothing.
func first_row_line_index() -> int:
	return printed_lines().size()


func row_count() -> int:
	return stakes().size()


func move_selection(step: int) -> void:
	if _spinning:
		return
	var n: int = row_count()
	if n <= 0:
		return
	set_stake_index(posmod(stake_index() + step, n))


func confirm() -> bool:
	if _spinning or selected_stake() <= 0:
		return false
	spin_requested.emit(selected_stake())
	return true


func animating() -> bool:
	return _spinning


func reel_offset(index: int) -> float:
	return _reel_offset[clampi(index, 0, SlotsScript.REELS - 1)]


# --- the layout, pure, and the same numbers paint() draws with -------------------------------

func cabinet_rect() -> Rect2:
	return CABINET


func paytable_rect() -> Rect2:
	return PAYTABLE


func reel_rect(index: int) -> Rect2:
	return Rect2(Vector2(REEL_LEFT + REEL_PITCH * float(index), REEL_TOP), REEL_SIZE_PX)


func payline_y() -> float:
	return REEL_TOP + REEL_SIZE_PX.y * 0.5


func stake_chip_rect(index: int) -> Rect2:
	var centre := Vector2(REEL_LEFT + CHIP_RADIUS + STAKE_PITCH * float(index),
		STAKE_ROW_Y - (8.0 if index == stake_index() else 0.0))
	return Rect2(centre - Vector2(CHIP_RADIUS, CHIP_RADIUS) * 1.1,
		Vector2(CHIP_RADIUS, CHIP_RADIUS) * 2.2)


func focus_rect() -> Rect2:
	if stakes().is_empty():
		return Rect2()
	return to_viewport(stake_chip_rect(clampi(stake_index(), 0, stakes().size() - 1)))


func focused_id() -> StringName:
	if stakes().is_empty():
		return &""
	return StringName("stake:%d" % clampi(stake_index(), 0, stakes().size() - 1))


# --- the spin ---------------------------------------------------------------------------------

## TOLD, NEVER ASKED. ranch.gd's play_slots() has already taken the stake, rolled
## Slots.spin() and settled the win by the time this is called; `reels` is that roll. See
## ranch.gd's own comment on the order, which is the safety property this whole casino shares.
##
## A REEL VALUE THAT IS NOT ON THE STRIP IS A STILL FRAME. This arrives over a dynamic call()
## from ranch.gd, so nothing type checks it at the call site.
func show_spin(reels: Array[int], won: int, stake: int) -> void:
	if reels.size() != SlotsScript.REELS:
		return
	for symbol: int in reels:
		if symbol < 0 or symbol >= SlotsScript.SYMBOL_NAMES.size():
			return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_spinning = true
	_flash = 0.0
	var strip: Array[int] = SlotsScript.strip()
	# The tween runs on the menu node, which is process_mode 3 (PROCESS_MODE_ALWAYS) in every
	# menu .tscn, so it keeps running while get_tree().paused is true.
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "_lever", 1.0, LEVER_DROP_SECONDS)
	_tween.tween_property(self, "_lever", 0.0, LEVER_RISE_SECONDS) \
		.set_delay(LEVER_DROP_SECONDS)
	for reel: int in SlotsScript.REELS:
		var target: float = float(_first_position(strip, reels[reel]))
		var landing: float = LAND_FIRST + LAND_STAGGER * float(reel)
		# Where the ribbon has to be when the landing tween takes over, so the reel appears to
		# have been running at REEL_SPEED the whole time rather than teleporting into its
		# landing. Whole turns plus the target, so the arithmetic is exact.
		var run_to: float = _reel_offset[reel] + float(SPIN_TURNS * SlotsScript.REEL_SIZE)
		_tween.tween_property(self, "_reel_offset:%d" % reel, run_to, landing) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		# TRANS_BACK overshoots by about a third of a symbol and settles back, which is what
		# makes a reel feel like a physical object rather than a list that stopped.
		var settle: float = run_to + float(SlotsScript.REEL_SIZE) \
			- posmod(run_to - target, float(SlotsScript.REEL_SIZE))
		_tween.tween_property(self, "_reel_offset:%d" % reel, settle, LAND_SECONDS) \
			.set_delay(landing).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var total: float = LAND_FIRST + LAND_STAGGER * float(SlotsScript.REELS - 1) + LAND_SECONDS
	if won > 0:
		# A WIN FLASHES AND A LOSS IS QUIET. A machine that celebrates a loss is a machine
		# that is lying, and this one publishes its own house edge on the wall outside.
		_tween.tween_property(self, "_flash", 1.0, WIN_FLASH_SECONDS).set_delay(total)
		_tween.tween_property(self, "_flash", 0.0, 0.01) \
			.set_delay(total + WIN_FLASH_SECONDS)
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void: _spinning = false) \
		.set_delay(total + (WIN_FLASH_SECONDS if won > 0 else 0.0))


## The first strip position carrying `symbol`. Any position carrying it would do; the first is
## chosen so the landing is a function of the value and nothing else.
func _first_position(strip: Array[int], symbol: int) -> int:
	for i: int in strip.size():
		if strip[i] == symbol:
			return i
	return 0
```

- [ ] **Step 4: Write `paint()`**

Append to `game/ui/slots_menu.gd`:

```gdscript
func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()

	# --- the cabinet -------------------------------------------------------------------------
	PaintScript.rounded(ci, CABINET.grow(-2.0), 16.0, PaintScript.PLUM,
		PaintScript.GOLD, 4.0)
	PaintScript.rounded(ci, HEADBOARD, 10.0, PaintScript.GOLD_DIM, PaintScript.GOLD, 2.0)
	PaintScript.text(ci, MenuStyleScript.title_font(),
		HEADBOARD.position + Vector2(HEADBOARD.size.x * 0.5, 38.0), "SPECTRA SLOTS",
		MenuStyleScript.TITLE_SIZE, PaintScript.PLUM_DARK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
	for bulb: int in BULBS:
		var phase: float = fposmod(t / BULB_CHASE_SECONDS - float(bulb) / float(BULBS), 1.0)
		var lit: float = 0.35 + 0.65 * maxf(0.0, 1.0 - phase * 4.0)
		ci.draw_circle(Vector2(HEADBOARD.position.x + 30.0
			+ (HEADBOARD.size.x - 60.0) * float(bulb) / float(BULBS - 1), 8.0),
			5.0, Color(PaintScript.GOLD, lit))

	# --- the three windows -------------------------------------------------------------------
	var strip: Array[int] = SlotsScript.strip()
	for reel: int in SlotsScript.REELS:
		var window: Rect2 = reel_rect(reel)
		PaintScript.rounded(ci, window, 10.0, Color(0.06, 0.05, 0.09),
			PaintScript.GOLD_DIM, 3.0)
		# The ribbon: the REAL strip, at this reel's scroll offset, wrapped. Three cells are
		# visible and the middle one is the payline.
		var offset: float = _reel_offset[reel]
		var top_index: int = floori(offset) - 1
		var slide: float = (offset - floor(offset)) * CELL_HEIGHT
		for cell: int in 4:
			var symbol: int = strip[posmod(top_index + cell, SlotsScript.REEL_SIZE)]
			var y: float = window.position.y + CELL_HEIGHT * float(cell) - slide
				- (CELL_HEIGHT - window.size.y * 0.5) * 0.0
			var box := Rect2(Vector2(window.position.x + 26.0, y - CELL_HEIGHT * 0.5),
				Vector2(window.size.x - 52.0, CELL_HEIGHT - 12.0))
			if box.position.y + box.size.y < window.position.y:
				continue
			if box.position.y > window.position.y + window.size.y:
				continue
			PaintScript.draw_symbol(ci, box, symbol)
		# The cylinder shading: two flat bands top and bottom, so the ribbon reads as a drum
		# rather than as a list somebody is scrolling.
		ci.draw_rect(Rect2(window.position, Vector2(window.size.x, 48.0)),
			Color(0.02, 0.02, 0.04, 0.55))
		ci.draw_rect(Rect2(window.position + Vector2(0.0, window.size.y - 48.0),
			Vector2(window.size.x, 48.0)), Color(0.02, 0.02, 0.04, 0.55))

	# --- the payline, always on, so she knows which row counts before she spins ---------------
	var flash_colour: Color = PaintScript.GOLD if _flash <= 0.0 \
		else PaintScript.BAND_COLORS[int(t * 8.0) % PaintScript.BAND_COLORS.size()]
	ci.draw_line(Vector2(reel_rect(0).position.x - 8.0, payline_y()),
		Vector2(reel_rect(2).position.x + REEL_SIZE_PX.x + 8.0, payline_y()),
		Color(flash_colour, 0.5 + 0.5 * _flash), 2.0 + 2.0 * _flash, true)

	# --- the lever, purely cosmetic; the spin is on ui_accept ---------------------------------
	var pivot := Vector2(LEVER_X, 120.0)
	var swing: float = deg_to_rad(35.0) * _lever
	var ball: Vector2 = pivot + Vector2(sin(swing), cos(swing)) * 90.0
	ci.draw_line(pivot, ball, PaintScript.GOLD_DIM, 8.0, true)
	ci.draw_circle(ball, 16.0, Color(0.82, 0.18, 0.20))

	# --- the stake, as drawn chips -----------------------------------------------------------
	var available: Array[int] = stakes()
	for i: int in available.size():
		var box: Rect2 = stake_chip_rect(i)
		PaintScript.chip(ci, box.position + box.size * 0.5, CHIP_RADIUS,
			PaintScript.CHIP_COLORS[i % PaintScript.CHIP_COLORS.size()], true)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			box.position + Vector2(box.size.x * 0.5, box.size.y * 0.62),
			str(available[i]), 20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		if i == stake_index():
			PaintScript.focus_ring(ci, box.grow(6.0), 40.0, t)

	# --- the chip counter, tweening toward what she is actually holding -----------------------
	var chips: float = float(chips_provider.call()) if chips_provider.is_valid() else 0.0
	_shown_chips = lerpf(_shown_chips, chips, 1.0 - pow(0.001, get_process_delta_time()))
	PaintScript.draw_chip_icon(ci, Rect2(CABINET.size.x - 150.0, 386.0, 24.0, 24.0))
	PaintScript.text(ci, MenuStyleScript.numeral_font(), Vector2(CABINET.size.x - 118.0, 406.0),
		"%d" % roundi(_shown_chips), 24, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)

	# --- the paytable ------------------------------------------------------------------------
	PaintScript.rounded(ci, PAYTABLE, 12.0, Color(PaintScript.FELT_DARK, 0.9),
		PaintScript.GOLD_DIM, 2.0)
	var lines: Array[String] = SlotsScript.paytable_lines()
	for i: int in lines.size():
		var y: float = PAYTABLE.position.y + 46.0 + 46.0 * float(i)
		if i < SlotsScript.SYMBOL_NAMES.size():
			for pip: int in 3:
				PaintScript.draw_symbol(ci, Rect2(PAYTABLE.position.x + 16.0 + 36.0 * float(pip),
					y - 26.0, 32.0, 32.0), i)
			PaintScript.text(ci, MenuStyleScript.numeral_font(),
				Vector2(PAYTABLE.position.x + 140.0, y), "%d for 1" % SlotsScript.TRIPLE_PAYS[i],
				MenuStyleScript.ROW_SIZE, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		else:
			PaintScript.text(ci, font, Vector2(PAYTABLE.position.x + 16.0, y), lines[i],
				MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM,
				HORIZONTAL_ALIGNMENT_LEFT, PAYTABLE.size.x - 32.0)
```

- [ ] **Step 5: Tell the machine what happened, from `ranch.gd`**

In `game/world/ranch.gd`'s `play_slots()`, directly after the existing `slots_menu.call("show_result", lines)` block and before `_refresh_casino_menus()`:

```gdscript
	# THE STAGE IS TOLD, NEVER ASKED, and it is told LAST. Everything above this line has
	# already happened: the stake came out, Slots.spin() rolled and the win was settled. So
	# there is no path by which the drawing can influence the outcome, because the outcome is
	# a value that arrives after the chips have already moved. Same has_method() guard as
	# show_result() above, so a menu whose script failed to parse is a FAILED check in
	# _report() rather than a crash mid bet.
	if slots_menu != null and slots_menu.has_method("show_spin"):
		slots_menu.call("show_spin", reels, won, stake)
```

- [ ] **Step 6: Run the tests**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_slots_menu.gd -gexit 2>&1 | tail -10
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_published_payouts.gd -gexit 2>&1 | tail -6
bash tools/run_tests.sh 2>&1 | tail -12
```
Expected: all three green. `test_published_payouts.gd` is the one that proves `drawn_lines()` really did survive.

- [ ] **Step 7: Run the casino gate**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn 2>&1 \
  | grep -E "CASINO stage|CASINO_OK|CASINO_FAILED"
echo "exit ${PIPESTATUS[0]}"
```
Expected: `CASINO stage SlotsMenu     size=(1120, 480) focus=(66, 66) id=stake:0`, `CASINO_OK`, exit 0. The measured edge checks are untouched: nothing in this task went near `game/systems/slots.gd`.

- [ ] **Step 8: Commit**

```bash
printf 'feat: the slot machine is a slot machine\n\nA cabinet in the Palace s own purple with a gold trim, a headboard whose nine\nbulbs chase left to right so the machine reads as switched on, three reel\nwindows showing the REAL Slots.strip() as a wrapped ribbon of symbol cells, a\npayline that is visible before she spins, a lever, drawn stake chips and a\npaytable panel with three glyphs and a multiplier per row.\n\nNothing here rolls anything. ranch.gd takes the stake, rolls Slots.spin() and\nsettles the win, and only then calls show_spin() with the reels it already got.\nThe tween s target is that value; every timing is a constant, because a spin\nwhose length varied would be a generator living under game/ui/.\n\nA loss is quiet. The payline flashes on a win and does nothing on a loss: a\nmachine that celebrates a loss is a machine that is lying, and this one\npublishes its own house edge on the wall outside.\n\ndrawn_lines() is unchanged and still returns all fifteen lines, so\ntest_published_payouts.gd keeps parsing the price out of the same eight\npaytable strings. printed_lines() drops eleven of them onto the cabinet, so the\ncolumn is two lines instead of fifteen.\n' > /tmp/polish-task4.txt
git add game/ui/slots_menu.gd game/world/ranch.gd game/test/test_slots_menu.gd
git commit -F /tmp/polish-task4.txt
```

---

### Task 5: The wheel, and the footer that never rendered

**Files:**
- Modify: `game/ui/wheel_menu.gd`, `game/world/ranch.gd` (one added block in `play_wheel()`), `game/test/test_wheel_menu.gd`
- Test: `game/test/test_wheel_menu.gd`

**Interfaces:**
- Consumes: `CasinoPaint.sector_points/rounded/chip/chip_stack/plate/focus_ring/text` (Task 1); the stage members (Task 3); `Wheel.POCKETS`, `Wheel.NUMBERS`, `Wheel.COLOUR_RUN`, `Wheel.HOUSE_POCKET`, `Wheel.colour_of()`, `Wheel.COLOUR_NAMES`, `Wheel.NUMBER_PAYS_TO_ONE`, `Wheel.COLOUR_PAYS_TO_ONE`, `Wheel.rules_lines()`.
- Produces, on `WheelMenu`:
  - `show_spin(pocket: int, won: int, stake: int) -> void`
  - `wheel_centre() -> Vector2`, `wheel_outer() -> float`, `wheel_inner() -> float`, `pad_rect(index: int) -> Rect2`, `stake_chip_rect(index: int) -> Rect2`, `rules_rect() -> Rect2`, all stage local
  - `wheel_angle() -> float` (the live rotation, radians)
- Produces, on `Ranch`: `play_wheel()` also calls `wheel_menu.call("show_spin", pocket, won, stake)`.
- **Deletes:** `WheelMenu.WHEEL_FOOTER` and the `_ready()` override that assigned it.

**The defect this carries.** `WHEEL_FOOTER` is set in `_ready()` after `super._ready()` and overwritten by `refresh()` on the very next call, and `open()` calls `refresh()`, so the player has never seen it. It hard codes `"Enter / A  confirm      Esc / B  leave"`, both input schemes at once, which is exactly what `MenuStyle.footer()` and `game/systems/input_device.gd` exist to prevent. The consequence is that this file's own class comment promises "The footer says so" about the stake sitting on the last row, and the footer does not say so, because the line that said it never rendered. **The hint it was trying to give is drawn on the stake row itself instead,** as a small `GOLD_DIM` `menu_tabs` glyph beside the chips, which is where the player is actually looking.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_wheel_menu.gd`:

```gdscript
const PaintScript := preload("res://ui/casino_paint.gd")
## The file already preloads the SCENE as WheelMenuScene; the SCRIPT is what carries the Tab
## enum and the new constants, and a preload by path is how this project reaches either.
const WheelMenuScript := preload("res://ui/wheel_menu.gd")


## THE DEAD FOOTER IS GONE. It was assigned in _ready() and overwritten by refresh() before
## any player could see it, and it hard coded both input schemes at once, which is precisely
## what MenuStyle.footer() exists to prevent.
func test_the_wheel_has_no_footer_of_its_own_and_shows_one_scheme() -> void:
	assert_false("WHEEL_FOOTER" in _menu, "the dead constant is deleted, not left lying")
	var footer := _menu.get_node(^"Centre/Panel/Margin/Column/Footer") as Label
	assert_false(footer.text.contains("Enter / A"),
		"one scheme, never both: the footer comes from MenuStyle now")
	assert_false(footer.text.contains("Esc / B"))


## TWENTY FIVE POCKETS ON THE WHEEL AND TWENTY FOUR PADS ON THE FELT. The house pocket is on
## the wheel and not on the felt, which is what makes it the house's.
func test_the_number_felt_has_a_pad_per_number_and_none_for_the_house() -> void:
	_menu.set_tab(WheelMenuScript.Tab.NUMBER)
	assert_eq(_menu.guess_count(), WheelScript.NUMBERS)
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	for i: int in WheelScript.NUMBERS:
		assert_true(stage.encloses(_menu.pad_rect(i)),
			"number pad %d leaves the stage: %s" % [i, _menu.pad_rect(i)])


func test_the_colour_felt_has_a_pad_per_colour_and_none_overlaps() -> void:
	_menu.set_tab(WheelMenuScript.Tab.COLOUR)
	assert_eq(_menu.guess_count(), int(WheelScript.Colour.HOUSE))
	for a: int in _menu.guess_count():
		for b: int in _menu.guess_count():
			if a >= b:
				continue
			assert_false(_menu.pad_rect(a).intersects(_menu.pad_rect(b)),
				"colour pads %d and %d overlap" % [a, b])


## THE WHEEL AND THE FELT DO NOT SIT ON TOP OF EACH OTHER, and neither leaves the stage.
func test_the_wheel_and_the_rules_plate_stay_inside_the_stage() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	var centre: Vector2 = _menu.wheel_centre()
	var r: float = _menu.wheel_outer()
	assert_true(stage.encloses(Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0)),
		"the wheel leaves the stage")
	assert_true(stage.encloses(_menu.rules_rect()), "the rules plate leaves the stage")
	assert_gt(_menu.wheel_outer(), _menu.wheel_inner(), "the ring has a width")


## A SPIN STOPS WITH THE PUSHED POCKET UNDER THE POINTER, and the number of turns is a
## constant. A spin whose length varied would be a generator under game/ui/.
func test_a_pushed_spin_stops_with_that_pocket_under_the_pointer() -> void:
	_menu.show_spin(13, 0, 10)
	assert_true(_menu.animating())
	for i: int in 260:
		await get_tree().process_frame
	assert_false(_menu.animating(), "the wheel has stopped")
	assert_eq(_menu.pocket_under_pointer(), 13,
		"the wheel stopped on the pocket ranch.gd already spun")


func test_an_impossible_pocket_starts_no_spin() -> void:
	var before: float = _menu.wheel_angle()
	_menu.show_spin(99, 0, 10)
	assert_false(_menu.animating())
	assert_eq(_menu.wheel_angle(), before)
	_menu.show_spin(-2, 0, 10)
	assert_false(_menu.animating())


## THE CURSOR MODEL IS UNCHANGED: the guesses, then one more position which is the stake.
func test_the_focus_walks_the_guesses_and_then_the_stake() -> void:
	_menu.set_tab(WheelMenuScript.Tab.COLOUR)
	assert_eq(String(_menu.focused_id()), "guess:0")
	_menu.move_selection(int(WheelScript.Colour.HOUSE))
	assert_eq(String(_menu.focused_id()), "stake:%d" % _menu.stake_index())
	assert_eq(_menu.row_count(), _menu.guess_count() + 1)
```

The file's `_menu` fixture needs `await get_tree().process_frame` after `open()`; add it if it is not there.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_wheel_menu.gd -gexit 2>&1 | tail -10
```
Expected: red, the first failure reporting that `WHEEL_FOOTER` is still declared.

- [ ] **Step 3: Delete the dead footer and add the layout**

In `game/ui/wheel_menu.gd`, delete the `WHEEL_FOOTER` constant, its three line comment and the whole `_ready()` override:

```gdscript
func _ready() -> void:
	super._ready()
	_footer.text = WHEEL_FOOTER
```

Then add, after the `TITLE` constant:

```gdscript
## PaintScript is NOT re-declared here: table_menu.gd already carries it and GDScript
## refuses a const that shadows one declared on the parent class. Same reason
## WHEEL_FOOTER had to have a distinct name from TableMenu's own FOOTER.

# --- the felt, in stage local pixels ---------------------------------------------------------
const STAGE_HEIGHT := 580.0
const WHEEL_CENTRE := Vector2(240.0, 230.0)
const WHEEL_OUTER := 200.0
const WHEEL_INNER := 66.0
const HUB_RADIUS := 58.0
const NUMBER_RADIUS := 140.0
const RULES := Rect2(20.0, 440.0, 440.0, 130.0)
const FELT := Rect2(500.0, 0.0, 620.0, 470.0)

## The colour felt: six pads in a 3 by 2 grid. The number felt: twenty four in a 6 by 4.
const COLOUR_PAD := Vector2(180.0, 120.0)
const COLOUR_ORIGIN := Vector2(520.0, 60.0)
const COLOUR_PITCH := Vector2(196.0, 136.0)
const NUMBER_PAD := Vector2(88.0, 74.0)
const NUMBER_ORIGIN := Vector2(516.0, 60.0)
const NUMBER_PITCH := Vector2(100.0, 86.0)
const NUMBER_COLUMNS := 6

const STAKE_ROW := Vector2(560.0, 440.0)
const STAKE_PITCH := 96.0
const CHIP_RADIUS := 30.0

# --- the spin, and every one of these is a CONSTANT ------------------------------------------
## FIVE FULL TURNS, ALWAYS. A spin whose length varied would be a generator living under
## game/ui/, which is the one thing this file may not have. TRANS_CUBIC with EASE_OUT is a
## friction curve, which is what a wheel slowing down actually is.
const SPIN_TURNS := 5
const SPIN_SECONDS := 3.2
const LANDED_GLOW_SECONDS := 0.8
const SETTLE_SECONDS := 0.4

## The pointer's ratchet: it kicks back this far each time a new pocket passes under it and
## springs home over RATCHET_SECONDS. On a fast spin that is a flutter; as the wheel slows it
## becomes individual clicks, which is the entire reason a real wheel feels like it is
## slowing down rather than simply moving less.
const RATCHET_DEGREES := 8.0
const RATCHET_SECONDS := 0.09

var _angle := 0.0
var _spinning := false
var _landed := -1
var _glow := 0.0
var _ratchet := 0.0
var _last_pocket := -1
var _tween: Tween = null
```

- [ ] **Step 4: Add the pure layout, the push and `paint()`**

Append to `game/ui/wheel_menu.gd`:

```gdscript
func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


func wheel_centre() -> Vector2:
	return WHEEL_CENTRE


func wheel_outer() -> float:
	return WHEEL_OUTER


func wheel_inner() -> float:
	return WHEEL_INNER


func wheel_angle() -> float:
	return _angle


func rules_rect() -> Rect2:
	return RULES


## The pad for guess row `index` on whichever tab is up. One function and not two, because
## `_selected` and `_guess_row` index the same list on both tabs and a caller that had to
## know which tab it was on is a caller that can be wrong.
func pad_rect(index: int) -> Rect2:
	if _tab == Tab.NUMBER:
		return Rect2(NUMBER_ORIGIN + Vector2(
			NUMBER_PITCH.x * float(index % NUMBER_COLUMNS),
			NUMBER_PITCH.y * float(index / NUMBER_COLUMNS)), NUMBER_PAD)
	return Rect2(COLOUR_ORIGIN + Vector2(
		COLOUR_PITCH.x * float(index % 3), COLOUR_PITCH.y * float(index / 3)), COLOUR_PAD)


func stake_chip_rect(index: int) -> Rect2:
	var centre := Vector2(STAKE_ROW.x + STAKE_PITCH * float(index),
		STAKE_ROW.y - (8.0 if index == stake_index() else 0.0))
	return Rect2(centre - Vector2(CHIP_RADIUS, CHIP_RADIUS) * 1.1,
		Vector2(CHIP_RADIUS, CHIP_RADIUS) * 2.2)


## WHICH POCKET IS UNDER THE POINTER RIGHT NOW, derived from the live angle rather than
## remembered from the push, so the test that asks it is asking the drawing.
func pocket_under_pointer() -> int:
	var per: float = TAU / float(WheelScript.POCKETS)
	# The pointer is at twelve o'clock, which is minus a quarter turn in screen radians.
	var at: float = fposmod(-PI * 0.5 - _angle, TAU)
	return posmod(roundi(at / per), WheelScript.POCKETS)


func focus_rect() -> Rect2:
	if _selected == guess_count():
		if stakes().is_empty():
			return Rect2()
		return to_viewport(stake_chip_rect(clampi(stake_index(), 0, stakes().size() - 1)))
	return to_viewport(pad_rect(clampi(_selected, 0, guess_count() - 1)))


func focused_id() -> StringName:
	if _selected == guess_count():
		return StringName("stake:%d" % stake_index())
	return StringName("guess:%d" % clampi(_selected, 0, guess_count() - 1))


func animating() -> bool:
	return _spinning


## The whole text model stays; the felt already shows every guess, so the column keeps only
## the two lines that are not pictures plus the last spin.
func printed_lines() -> Array[String]:
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	return lines


func first_row_line_index() -> int:
	return printed_lines().size()


## TOLD, NEVER ASKED. ranch.gd's play_wheel() has taken the stake, spun Wheel.spin() and
## settled by the time this is called. A pocket that is not on the wheel is a still frame:
## this arrives over a dynamic call() and nothing type checks it at the call site.
func show_spin(pocket: int, won: int, stake: int) -> void:
	if pocket < 0 or pocket >= WheelScript.POCKETS:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_spinning = true
	_landed = pocket
	_glow = 0.0
	var per: float = TAU / float(WheelScript.POCKETS)
	# Where the wheel must end up for `pocket` to sit under the twelve o'clock pointer, plus
	# five whole turns past wherever it is now. Whole turns, so the arithmetic is exact and
	# the landing is a function of the value and nothing else.
	var target: float = -PI * 0.5 - per * float(pocket)
	while target < _angle + TAU * float(SPIN_TURNS):
		target += TAU
	_tween = create_tween()
	_tween.tween_property(self, "_angle", target, SPIN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_glow", 1.0, 0.12)
	_tween.tween_property(self, "_glow", 0.0, LANDED_GLOW_SECONDS)
	_tween.tween_callback(func() -> void: _spinning = false)
	# `won` and `stake` are not used to decide anything; they are here so a later slice can
	# slide the winning chips to the player without changing this call's shape, and so the
	# signature matches SlotsMenu.show_spin()'s.
	if won < 0 or stake < 0:
		return


func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()
	var per: float = TAU / float(WheelScript.POCKETS)

	# --- the wheel ---------------------------------------------------------------------------
	for pocket: int in WheelScript.POCKETS:
		var from_angle: float = _angle + per * float(pocket) - per * 0.5
		var to_angle: float = from_angle + per
		var colour: Color = PaintScript.HOUSE_SILVER
		if pocket != WheelScript.HOUSE_POCKET:
			colour = PaintScript.BAND_COLORS[WheelScript.colour_of(pocket)]
		if pocket == _landed and _glow > 0.0:
			colour = colour.lightened(0.35 * _glow)
		ci.draw_colored_polygon(PaintScript.sector_points(WHEEL_CENTRE,
			WHEEL_INNER, WHEEL_OUTER, from_angle, to_angle), colour)
		if pocket == WheelScript.HOUSE_POCKET:
			# No number on the house pocket, because no bet may name it. A small cloud
			# instead, which is whose pocket it is.
			var mid: float = from_angle + per * 0.5
			var at: Vector2 = WHEEL_CENTRE + Vector2(cos(mid), sin(mid)) * NUMBER_RADIUS
			for lobe: Vector2 in [Vector2(-8.0, 2.0), Vector2(0.0, -4.0), Vector2(8.0, 2.0)]:
				ci.draw_circle(at + lobe, 7.0, Color(1.0, 1.0, 1.0, 0.9))
			continue
		var mid_angle: float = from_angle + per * 0.5
		var label_at: Vector2 = WHEEL_CENTRE \
			+ Vector2(cos(mid_angle), sin(mid_angle)) * NUMBER_RADIUS
		PaintScript.text(ci, MenuStyleScript.numeral_font(), label_at + Vector2(-9.0, 7.0),
			str(pocket), 20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	ci.draw_circle(WHEEL_CENTRE, HUB_RADIUS, PaintScript.GOLD)
	for spoke: int in 6:
		var a: float = _angle + TAU * float(spoke) / 6.0
		ci.draw_line(WHEEL_CENTRE, WHEEL_CENTRE + Vector2(cos(a), sin(a)) * HUB_RADIUS,
			PaintScript.GOLD_DIM, 3.0, true)
	ci.draw_arc(WHEEL_CENTRE, WHEEL_OUTER, 0.0, TAU, 96, PaintScript.GOLD_DIM, 5.0, true)

	# --- the pointer, ratcheting -------------------------------------------------------------
	var now: int = pocket_under_pointer()
	if now != _last_pocket:
		_last_pocket = now
		_ratchet = 1.0
	_ratchet = maxf(0.0, _ratchet - get_process_delta_time() / RATCHET_SECONDS)
	var kick: float = deg_to_rad(RATCHET_DEGREES) * _ratchet
	var tip: Vector2 = WHEEL_CENTRE + Vector2(sin(kick), -cos(kick)) * (WHEEL_OUTER - 6.0)
	var base: Vector2 = WHEEL_CENTRE + Vector2(sin(kick), -cos(kick)) * (WHEEL_OUTER + 26.0)
	var side := Vector2(-(base - tip).y, (base - tip).x).normalized() * 12.0
	ci.draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]),
		PaintScript.GOLD)

	# --- the rules plate under the wheel -----------------------------------------------------
	var rules: Array[String] = []
	for line in WheelScript.rules_lines():
		rules.append(line)
	PaintScript.plate(ci, RULES, font, "", rules)

	# --- the felt ----------------------------------------------------------------------------
	PaintScript.rounded(ci, FELT, 14.0, PaintScript.FELT, PaintScript.GOLD_DIM, 2.0)
	for i: int in 4:
		var y: float = FELT.position.y + 24.0 + 108.0 * float(i)
		ci.draw_line(Vector2(FELT.position.x + 12.0, y),
			Vector2(FELT.position.x + FELT.size.x - 12.0, y), PaintScript.FELT_LINE, 1.0, true)
	if _tab == Tab.NUMBER:
		PaintScript.text(ci, font, Vector2(FELT.position.x + 16.0, 38.0),
			"A number pays %d to 1" % WheelScript.NUMBER_PAYS_TO_ONE,
			MenuStyleScript.ROW_SIZE, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	for guess: int in guess_count():
		var pad: Rect2 = pad_rect(guess)
		var colour: Color = PaintScript.BAND_COLORS[guess] if _tab == Tab.COLOUR \
			else PaintScript.BAND_COLORS[WheelScript.colour_of(guess + 1)]
		PaintScript.rounded(ci, pad, 8.0, Color(colour, 0.85), colour.darkened(0.3), 2.0)
		if _tab == Tab.COLOUR:
			PaintScript.text(ci, font, pad.position + Vector2(14.0, 44.0),
				WheelScript.COLOUR_NAMES[guess], MenuStyleScript.ROW_SIZE,
				PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_LEFT, pad.size.x - 28.0)
			PaintScript.text(ci, font, pad.position + Vector2(14.0, 82.0),
				"pays %d to 1" % WheelScript.COLOUR_PAYS_TO_ONE,
				MenuStyleScript.SUBTITLE_SIZE, PaintScript.CARD_INK,
				HORIZONTAL_ALIGNMENT_LEFT, pad.size.x - 28.0)
		else:
			PaintScript.text(ci, MenuStyleScript.numeral_font(),
				pad.position + Vector2(pad.size.x * 0.5, 48.0), str(guess + 1),
				MenuStyleScript.ROW_SIZE, PaintScript.CARD_INK,
				HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		# HER BET IS A THING ON THE TABLE, not a caret next to a sentence. The pad _guess_row
		# names carries a stack of the current stake, so "my bet is on green" is visible.
		if guess == _guess_row and selected_stake() > 0:
			PaintScript.chip_stack(ci, pad.position + Vector2(pad.size.x - 26.0,
				pad.size.y - 12.0), 4,
				PaintScript.CHIP_COLORS[stake_index() % PaintScript.CHIP_COLORS.size()], 7.0)

	# --- the stake row, one press past the last guess -----------------------------------------
	var available: Array[int] = stakes()
	for i: int in available.size():
		var box: Rect2 = stake_chip_rect(i)
		PaintScript.chip(ci, box.position + box.size * 0.5, CHIP_RADIUS,
			PaintScript.CHIP_COLORS[i % PaintScript.CHIP_COLORS.size()], true)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			box.position + Vector2(box.size.x * 0.5, box.size.y * 0.62), str(available[i]),
			20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
	# THE HINT THE DEAD FOOTER WAS TRYING TO GIVE, put where the player is actually looking.
	# InputDevice.hint() answers in the glyphs of the device in her hands, so this is one
	# scheme and never both, which is the whole reason WHEEL_FOOTER had to go.
	PaintScript.text(ci, font, Vector2(STAKE_ROW.x - 40.0, STAKE_ROW.y + 58.0),
		"%s moves the stake" % InputDeviceScript.hint(&"menu_tabs"),
		MenuStyleScript.SUBTITLE_SIZE, PaintScript.GOLD_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1.0)

	# --- the focus ring, the one focus treatment in the building -------------------------------
	if _selected == guess_count():
		if not available.is_empty():
			PaintScript.focus_ring(ci, stake_chip_rect(
				clampi(stake_index(), 0, available.size() - 1)).grow(6.0), 40.0, t)
	else:
		PaintScript.focus_ring(ci, pad_rect(clampi(_selected, 0, guess_count() - 1)), 8.0, t)
```

- [ ] **Step 5: Tell the wheel what happened, from `ranch.gd`**

In `play_wheel()`, directly after the existing `wheel_menu.call("show_result", lines)` block:

```gdscript
	if wheel_menu != null and wheel_menu.has_method("show_spin"):
		wheel_menu.call("show_spin", pocket, won, stake)
```

- [ ] **Step 6: Run the tests and the gates**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_wheel_menu.gd -gexit 2>&1 | tail -10
bash tools/run_tests.sh 2>&1 | tail -12
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn 2>&1 \
  | grep -E "CASINO stage|CASINO_OK|CASINO_FAILED"
```
Expected: green throughout, and `CASINO stage WheelMenu size=(1120, 580)`.

- [ ] **Step 7: Commit**

```bash
printf 'feat: the wheel is a wheel\n\nTwenty five annular sectors, six bands of four in rainbow order plus the\nCloudsdale pocket in pale silver with a cloud on it and no number, because no\nbet may name it. A gold hub with six spokes, a pointer at twelve o clock that\nratchets: it kicks back eight degrees each time a new pocket passes under it\nand springs home over ninety milliseconds, so a fast spin flutters and a slow\none clicks. That ratchet is the entire reason a real wheel feels like it is\nslowing down.\n\nThe felt is pads, not sentences. Six colour pads on one tab, twenty four number\npads on the other, and the pad the cursor is backing carries a drawn stack of\nthe current stake, so "my bet is on green" is a thing on the table.\n\nFive full turns, always, over 3.2 seconds on a cubic ease out, which is a\nfriction curve. The turn count is a constant: a spin whose length varied would\nbe a generator living under game/ui/.\n\nAnd WHEEL_FOOTER is deleted. It was assigned in _ready() and overwritten by\nrefresh() before any player could see it, and it hard coded both input schemes\nat once, which is what MenuStyle.footer() exists to prevent. The hint it was\ntrying to give is drawn beside the stake chips instead, in the glyphs of the\ndevice she is actually holding.\n\nThe input model is unchanged in every particular: row_count() is still\nguess_count() plus one, switch_tab() still moves the stake on the last row, and\n_guess_row still tracks the last actually highlighted guess.\n' > /tmp/polish-task5.txt
git add game/ui/wheel_menu.gd game/world/ranch.gd game/test/test_wheel_menu.gd
git commit -F /tmp/polish-task5.txt
```

---

### Task 6: Blackjack, and the strategy card played in the open

**Files:**
- Modify: `game/ui/blackjack_menu.gd`, `game/world/ranch.gd` (one added block in `play_blackjack()`), `game/test/test_blackjack_menu.gd`
- Test: `game/test/test_blackjack_menu.gd`

**Interfaces:**
- Consumes: `CasinoPaint.draw_card/rounded/chip_stack/plate/focus_ring/text/CARD_FACE/CARD_INK/SUIT_COLORS` (Task 1); the stage members (Task 3); `Blackjack.RANKS`, `Blackjack.hand_total()`, `Blackjack.outcome_text()`, `Blackjack.placard_lines()`, `Blackjack.STRATEGY_DRAWS_BELOW`, `Blackjack.DEALER_STANDS_ON`.
- Produces, on `BlackjackMenu`:
  - `show_hand(hand: Dictionary, won: int, stake: int) -> void`
  - `card_rect(side: int, index: int) -> Rect2` (side 0 the player, 1 the dealer), `shoe_rect() -> Rect2`, `stake_rect() -> Rect2`, `outcome_rect() -> Rect2`, `placard_rect() -> Rect2`, all stage local
  - `cards_dealt() -> int` (how many of the settled hand have landed so far)
- Produces, on `Ranch`: `play_blackjack()` also calls `blackjack_menu.call("show_hand", hand, won, stake)`.

**What this task deliberately does NOT build: hit, stand and double.** `Blackjack.play_hand(rng)` deals and plays the whole hand in one call against the strategy card, and `Blackjack.PUBLISHED_EDGE = 0.0520` is MEASURED against that card by `measure_edge(REFERENCE_SEED, REFERENCE_HANDS)` over 100,000 hands, re measured by `game/test/test_blackjack.gd` on every suite run, and printed on the lobby sign by `CasinoSign.edge_line()`. An interactive hand means a hand state machine in `game/systems/blackjack.gd`, a double down that takes chips mid transaction (breaking the "stake comes out first" invariant every table in the building shares), a re measured edge, a new number on the sign and a rewritten placard. That is a slice, not a task, and the spec parks it for the owner with that cost attached. **What this task does instead is the second best thing: the table is real, the cards are real, the deal is real, and the strategy card plays out visibly in front of the player.**

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_blackjack_menu.gd`:

```gdscript
const PaintScript := preload("res://ui/casino_paint.gd")
## The file already preloads the SCENE as BlackjackMenuScene; the SCRIPT is what carries the
## Tab enum this file now reads.
const BlackjackMenuScript := preload("res://ui/blackjack_menu.gd")


## THE FELT, THE SHOE, THE STAKE AND BOTH HANDS ALL STAY ON THE STAGE, and neither hand is
## drawn on top of the other. Two hands sharing a row is the failure that looks correct in a
## screenshot of a two card push and wrong the first time somebody draws three.
func test_both_hands_stay_on_the_stage_and_never_overlap_each_other() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	assert_true(stage.encloses(_menu.shoe_rect()), "the shoe leaves the stage")
	assert_true(stage.encloses(_menu.stake_rect()), "the stake leaves the stage")
	for index: int in 8:
		var player: Rect2 = _menu.card_rect(0, index)
		var dealer: Rect2 = _menu.card_rect(1, index)
		assert_true(stage.encloses(player), "player card %d leaves the stage" % index)
		assert_true(stage.encloses(dealer), "dealer card %d leaves the stage" % index)
		assert_false(player.intersects(dealer),
			"the player's card %d is drawn over the dealer's" % index)


## A SUIT IS PRESENTATION AND CANNOT REACH A NUMBER. Blackjack numbers cards 0 to 51 and never
## names a suit at all; the stage derives one from card / RANKS. This test is the written
## proof that the derivation is one way: two cards of the same rank in different suits are
## worth the same, so a suit cannot move a total, a payout or the published edge.
func test_the_suit_the_stage_derives_cannot_change_a_hand_total() -> void:
	for rank: int in BlackjackScript.RANKS:
		var totals: Array[int] = []
		for suit: int in 4:
			totals.append(BlackjackScript.hand_total([rank + suit * BlackjackScript.RANKS]))
		for total: int in totals:
			assert_eq(total, totals[0],
				"rank %d is worth the same in every suit" % rank)


## THE PLACARD IS READING MATTER AND IS DRAWN AS A PLATE. Its seven lines are unchanged and
## are still what drawn_lines() returns on that tab, because test_published_payouts.gd parses
## the three to two out of them.
func test_the_placard_tab_still_returns_every_placard_line() -> void:
	_menu.set_tab(BlackjackMenuScript.Tab.PLACARD)
	var model: Array[String] = _menu.drawn_lines()
	for line: String in BlackjackScript.placard_lines():
		assert_true(model.has(line), "the model still carries '%s'" % line)
	assert_eq(_menu.row_count(), 0, "the placard is unselectable, as it always was")


## THE PUSHED HAND IS THE HAND THAT LANDS, in the order the strategy card played it.
func test_a_pushed_hand_deals_every_card_it_was_handed() -> void:
	var hand: Dictionary = {
		"player": [0, 12, 25] as Array[int],
		"dealer": [7, 20] as Array[int],
		"outcome": BlackjackScript.Outcome.PLAYER_WIN,
	}
	_menu.show_hand(hand, 20, 10)
	assert_true(_menu.animating(), "the deal is running")
	for i: int in 200:
		await get_tree().process_frame
	assert_false(_menu.animating(), "the deal has finished")
	assert_eq(_menu.cards_dealt(), 5, "three to the player and two to the dealer")


## A HAND WITH NO CARDS IN IT IS A STILL FRAME. This arrives over a dynamic call() from
## ranch.gd and a gate calling play_blackjack() directly can produce one.
func test_an_empty_or_broken_hand_starts_no_deal() -> void:
	_menu.show_hand({} as Dictionary, 0, 10)
	assert_false(_menu.animating())
	_menu.show_hand({"player": [] as Array[int], "dealer": [] as Array[int], "outcome": 0},
		0, 10)
	assert_false(_menu.animating())


func test_the_focus_id_names_the_stake_on_the_table_tab_and_nothing_on_the_placard() -> void:
	_menu.set_tab(BlackjackMenuScript.Tab.TABLE)
	assert_eq(String(_menu.focused_id()), "stake:0")
	_menu.set_tab(BlackjackMenuScript.Tab.PLACARD)
	assert_eq(String(_menu.focused_id()), "", "reading matter has no cursor")
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_blackjack_menu.gd -gexit 2>&1 | tail -10
```
Expected: red, the first failure `Nonexistent function 'shoe_rect'`.

- [ ] **Step 3: Write the table**

Add to `game/ui/blackjack_menu.gd`, after the `TITLE` constant, and extend the class comment with the suit note:

```gdscript
## PaintScript is NOT re-declared here: table_menu.gd already carries it and GDScript
## refuses a const that shadows one declared on the parent class. Same reason
## WHEEL_FOOTER had to have a distinct name from TableMenu's own FOOTER.

# --- the felt, in stage local pixels ---------------------------------------------------------
const STAGE_HEIGHT := 470.0
const CARD_SIZE := Vector2(76.0, 106.0)
const CARD_PITCH := 96.0
const ROW_LEFT := 340.0
const DEALER_ROW_Y := 34.0
const PLAYER_ROW_Y := 296.0
const ARC_LIFT := 5.0
const CARDS_DRAWN_MAX := 8
const SHOE := Rect2(1000.0, 20.0, 90.0, 124.0)
const STAKE := Rect2(60.0, 300.0, 140.0, 130.0)
const OUTCOME := Rect2(300.0, 186.0, 520.0, 78.0)
const PLACARD := Rect2(60.0, 20.0, 1000.0, 420.0)

# --- the deal, and every one of these is a CONSTANT -------------------------------------------
## The hand is ALREADY SETTLED when it arrives; the pacing below is presentation only and
## cannot change a single card. About 1.4 s for a two card push, about 2.4 s for a hand with
## three draws on each side.
const CARD_SLIDE_SECONDS := 0.18
const CARD_GAP_SECONDS := 0.12
const FLIP_SECONDS := 0.16
const STAMP_SECONDS := 0.5
const OUTCOME_RISE_SECONDS := 0.25

var _hand: Dictionary = {}
var _dealt := 0
var _stamp := 0.0
var _stamp_side := 0
var _stamp_text := ""
var _outcome_rise := 0.0
var _dealing := false
var _tween: Tween = null
```

Then add the members:

```gdscript
func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


## `side` is 0 for the player and 1 for the dealer. The dealer's row arcs gently upward across
## the top and the player's dips downward across the bottom, which is what a real table's felt
## does and what stops eight cards reading as a spreadsheet row.
func card_rect(side: int, index: int) -> Rect2:
	var slot: int = clampi(index, 0, CARDS_DRAWN_MAX - 1)
	var bow: float = ARC_LIFT * float(2 - absi(slot - 2))
	var y: float = (DEALER_ROW_Y - bow) if side == 1 else (PLAYER_ROW_Y + bow)
	return Rect2(Vector2(ROW_LEFT + CARD_PITCH * float(slot), y), CARD_SIZE)


func shoe_rect() -> Rect2:
	return SHOE


func stake_rect() -> Rect2:
	return STAKE


func outcome_rect() -> Rect2:
	return OUTCOME


func placard_rect() -> Rect2:
	return PLACARD


func cards_dealt() -> int:
	return _dealt


func animating() -> bool:
	return _dealing


func printed_lines() -> Array[String]:
	if _tab == Tab.PLACARD:
		return [] as Array[String]
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	return lines


func first_row_line_index() -> int:
	return printed_lines().size()


func focus_rect() -> Rect2:
	if _tab != Tab.TABLE or stakes().is_empty():
		return Rect2()
	return to_viewport(_stake_chip_rect(clampi(stake_index(), 0, stakes().size() - 1)))


func focused_id() -> StringName:
	if _tab != Tab.TABLE or stakes().is_empty():
		return &""
	return StringName("stake:%d" % clampi(stake_index(), 0, stakes().size() - 1))


func _stake_chip_rect(index: int) -> Rect2:
	var centre := Vector2(STAKE.position.x + 34.0 + 78.0 * float(index),
		STAKE.position.y + STAKE.size.y - 30.0 - (8.0 if index == stake_index() else 0.0))
	return Rect2(centre - Vector2(30.0, 30.0) * 1.1, Vector2(30.0, 30.0) * 2.2)


## TOLD, NEVER ASKED. ranch.gd's play_blackjack() has taken the stake, run
## Blackjack.play_hand() and settled by the time this is called. The hand is a finished thing;
## everything below is pacing.
##
## A HAND WITH NO CARDS IN IT IS A STILL FRAME: this arrives over a dynamic call() and nothing
## type checks it at the call site.
func show_hand(hand: Dictionary, won: int, stake: int) -> void:
	var player: Array = hand.get("player", []) as Array
	var dealer: Array = hand.get("dealer", []) as Array
	if player.is_empty() or dealer.is_empty():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_hand = hand.duplicate(true)
	_dealt = 0
	_outcome_rise = 0.0
	_dealing = true
	# THE ORDER IS THE ORDER A DEALER USES: player, dealer, player, dealer, then the player's
	# draws in order, then the dealer's. Blackjack.play_hand() built the arrays in exactly
	# that order, so walking them is walking the hand.
	var order: Array[int] = []
	for i: int in 2:
		order.append(0)
		order.append(1)
	for i: int in maxi(0, player.size() - 2):
		order.append(0)
	for i: int in maxi(0, dealer.size() - 2):
		order.append(1)
	_tween = create_tween()
	var elapsed := 0.0
	for step: int in order.size():
		var side: int = order[step]
		_tween.tween_callback(func() -> void:
			_dealt = step + 1
			# THE CARD IS PLAYED IN THE OPEN. Every card past the first four is a decision the
			# strategy card made on her behalf, so it is stamped as one: the player watches
			# the placard's own rules being executed rather than reading three lines
			# afterwards saying what happened. Blackjack.STRATEGY_DRAWS_BELOW is 17 for the
			# player and DEALER_STANDS_ON is 17 for the dealer.
			if step >= 4:
				_stamp = 1.0
				_stamp_side = side
				_stamp_text = "HIT"
		).set_delay(CARD_GAP_SECONDS if step > 0 else 0.0)
		_tween.tween_interval(CARD_SLIDE_SECONDS)
		elapsed += CARD_SLIDE_SECONDS + (CARD_GAP_SECONDS if step > 0 else 0.0)
	for side: int in 2:
		_tween.tween_callback(func() -> void:
			_stamp = 1.0
			_stamp_side = side
			_stamp_text = "STAND")
		_tween.tween_interval(STAMP_SECONDS)
	_tween.tween_property(self, "_outcome_rise", 1.0, OUTCOME_RISE_SECONDS)
	_tween.tween_callback(func() -> void: _dealing = false)
	if won < 0 or stake < 0:
		return
```

- [ ] **Step 4: Write `paint()`**

Append to `game/ui/blackjack_menu.gd`:

```gdscript
func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()

	if _tab == Tab.PLACARD:
		var placard: Array[String] = []
		for line in BlackjackScript.placard_lines():
			placard.append(line)
		PaintScript.plate(ci, PLACARD, font, "House rules", placard)
		return

	# --- the felt ----------------------------------------------------------------------------
	PaintScript.rounded(ci, Rect2(0.0, 0.0, STAGE_WIDTH, STAGE_HEIGHT), 18.0,
		PaintScript.FELT, PaintScript.FELT_DARK, 6.0)
	for row: float in [DEALER_ROW_Y + CARD_SIZE.y + 26.0, PLAYER_ROW_Y - 26.0]:
		ci.draw_arc(Vector2(STAGE_WIDTH * 0.5, row), 560.0, PI * 0.86, PI * 1.14, 48,
			PaintScript.FELT_LINE, 2.0, true)

	# --- the shoe ----------------------------------------------------------------------------
	PaintScript.rounded(ci, SHOE, 8.0, PaintScript.PLUM_DARK, PaintScript.GOLD_DIM, 2.0)
	PaintScript.draw_card(ci, Rect2(SHOE.position + Vector2(7.0, 10.0), CARD_SIZE * 0.72),
		font, -1, false)

	# --- both hands --------------------------------------------------------------------------
	var player: Array = _hand.get("player", []) as Array
	var dealer: Array = _hand.get("dealer", []) as Array
	var landed_player: int = 0
	var landed_dealer: int = 0
	for step: int in _dealt:
		# Reconstructs the same deal order show_hand() built, so paint() and the tween agree
		# without the tween having to write a second array for paint() to read.
		var side: int = (step % 2) if step < 4 \
			else (0 if step - 4 < maxi(0, player.size() - 2) else 1)
		if side == 0:
			landed_player += 1
		else:
			landed_dealer += 1
	for i: int in mini(landed_player, player.size()):
		PaintScript.draw_card(ci, card_rect(0, i), font, int(player[i]), true)
	for i: int in mini(landed_dealer, dealer.size()):
		PaintScript.draw_card(ci, card_rect(1, i), font, int(dealer[i]), true)

	# --- the totals, in a small gold pill beside each hand -------------------------------------
	for pair: Array in [[0, player, landed_player], [1, dealer, landed_dealer]]:
		var side: int = int(pair[0])
		var cards: Array = pair[1] as Array
		var shown: int = mini(int(pair[2]), cards.size())
		if shown <= 0:
			continue
		var visible: Array[int] = []
		for i: int in shown:
			visible.append(int(cards[i]))
		var total: int = BlackjackScript.hand_total(visible)
		var pill := Rect2(card_rect(side, 0).position - Vector2(96.0, 0.0),
			Vector2(78.0, 40.0))
		PaintScript.rounded(ci, pill, 20.0, Color(PaintScript.GOLD, 0.9),
			PaintScript.GOLD_DIM, 2.0)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			pill.position + Vector2(pill.size.x * 0.5, 29.0),
			("BUST" if total > 21 else str(total)), 22, PaintScript.CARD_INK,
			HORIZONTAL_ALIGNMENT_CENTER, -1.0)

	# --- the stamp: the strategy card, executed in the open ------------------------------------
	if _stamp > 0.0:
		_stamp = maxf(0.0, _stamp - get_process_delta_time() / STAMP_SECONDS)
		var at: Rect2 = card_rect(_stamp_side, 0)
		var stamp := Rect2(at.position + Vector2(0.0, -46.0), Vector2(88.0, 34.0))
		PaintScript.rounded(ci, stamp, 17.0, Color(PaintScript.GOLD, _stamp),
			Color(PaintScript.GOLD_DIM, _stamp), 2.0)
		PaintScript.text(ci, MenuStyleScript.title_font(),
			stamp.position + Vector2(stamp.size.x * 0.5, 25.0), _stamp_text, 20,
			Color(PaintScript.CARD_INK, _stamp), HORIZONTAL_ALIGNMENT_CENTER, -1.0)

	# --- the stake, in front of the player -----------------------------------------------------
	var available: Array[int] = stakes()
	for i: int in available.size():
		var box: Rect2 = _stake_chip_rect(i)
		PaintScript.chip(ci, box.position + box.size * 0.5, 30.0,
			PaintScript.CHIP_COLORS[i % PaintScript.CHIP_COLORS.size()], true)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			box.position + Vector2(box.size.x * 0.5, box.size.y * 0.62), str(available[i]),
			20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		if i == stake_index():
			PaintScript.focus_ring(ci, box.grow(6.0), 40.0, t)

	# --- the outcome plate, rising out of the felt ---------------------------------------------
	if _outcome_rise > 0.0 and not _hand.is_empty():
		var rect := Rect2(OUTCOME.position + Vector2(0.0, 30.0 * (1.0 - _outcome_rise)),
			OUTCOME.size)
		PaintScript.rounded(ci, rect, 12.0,
			Color(PaintScript.FELT_DARK, 0.94 * _outcome_rise),
			Color(PaintScript.GOLD, _outcome_rise), 2.0)
		PaintScript.text(ci, MenuStyleScript.title_font(),
			rect.position + Vector2(rect.size.x * 0.5, 50.0),
			BlackjackScript.outcome_text(_hand), MenuStyleScript.TITLE_SIZE,
			Color(PaintScript.GOLD, _outcome_rise), HORIZONTAL_ALIGNMENT_CENTER, -1.0)
```

And extend the class comment at the top of the file with:

```gdscript
## THE SUIT ON A CARD IS DRAWN HERE AND MEANS NOTHING. game/systems/blackjack.gd numbers cards
## 0 to 51 and reads card % RANKS for the rank; it never names a suit at all. This stage
## derives one as card / RANKS so a face is a face, and that derivation is one way: card_value(),
## hand_total() and payout() all read the rank alone, so two cards of the same rank in different
## suits are worth the same chip. game/test/test_blackjack_menu.gd asserts exactly that, because
## the next reader of this file will wonder whether the casino just grew a fifth thing that
## can move a number.
```

- [ ] **Step 5: Tell the table what happened, from `ranch.gd`**

In `play_blackjack()`, directly after the existing `blackjack_menu.call("show_result", lines)` block:

```gdscript
	if blackjack_menu != null and blackjack_menu.has_method("show_hand"):
		blackjack_menu.call("show_hand", hand, won, stake)
```

- [ ] **Step 6: Run the tests and the gates**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_blackjack_menu.gd -gexit 2>&1 | tail -10
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_blackjack.gd -gexit 2>&1 | tail -6
bash tools/run_tests.sh 2>&1 | tail -12
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn 2>&1 \
  | grep -E "CASINO stage|CASINO_OK|CASINO_FAILED"
```
Expected: green throughout. `test_blackjack.gd` re measures `PUBLISHED_EDGE` over 100,000 hands on every run; if it moved, something in this task touched `game/systems/blackjack.gd`, which nothing in it is allowed to do.

- [ ] **Step 7: Commit**

```bash
printf 'feat: blackjack gets a felt, cards and a dealer who shows her work\n\nA felt arc with the dealer along the top and the player along the bottom, a\nshoe at the top right, drawn cards at 76 by 106 with real pip layouts for two\nthrough ten, a single large pip for an Ace and a monogram panel for the court\ncards, a total in a gold pill beside each hand and a BUST stamp over 21.\n\nTHE CARD IS PLAYED IN THE OPEN. Every card past the first four is a decision\nthe strategy card made on her behalf, so it is stamped HIT as it lands, and\nSTAND lands over a hand that stops drawing. Blackjack.STRATEGY_DRAWS_BELOW is\n17 for the player and DEALER_STANDS_ON is 17 for the dealer; the player watches\nthe placard s own rules being executed instead of reading three lines\nafterwards saying what happened. That is the whole of what makes a one press\nhand feel like a hand, and it costs no logic change at all.\n\nThe suit is drawn here and means nothing. blackjack.gd numbers cards 0 to 51\nand never names a suit; this stage derives one as card / RANKS, and the test\nasserts that two cards of the same rank in different suits are worth the same\nchip, because the next reader will wonder.\n\nNo hit, no stand, no double. PUBLISHED_EDGE is measured against the strategy\ncard over a hundred thousand hands and printed on the sign; an interactive hand\nis a state machine, a double that takes chips mid transaction, a re measured\nedge and a rewritten placard. The spec parks it for the owner with that cost\nattached.\n' > /tmp/polish-task6.txt
git add game/ui/blackjack_menu.gd game/world/ranch.gd game/test/test_blackjack_menu.gd
git commit -F /tmp/polish-task6.txt
```

---

### Task 7: The lobby floor plan and the form guide

**Files:**
- Modify: `game/ui/casino_menu.gd`, `game/ui/race_menu.gd`, `game/world/ranch.gd` (two new keys on `race_entrants()`, two new constants), `game/test/test_casino_menu.gd`, `game/test/test_race_menu.gd`, `game/scenes/test/casino_test.gd`
- Test: `game/test/test_casino_menu.gd`, `game/test/test_race_menu.gd`

**Interfaces:**
- Consumes: `CasinoPaint.draw_room/rounded/chip/chip_stack/plate/focus_ring/text/draw_bit/draw_chip_icon/BAND_COLORS` (Task 1); the stage members mirrored onto `CasinoMenu` (Task 3); `CasinoSign.lines()`, `CasinoSign.cage_explainer()`, `Casino.CHIP_RATE`, `RaceCard.odds_text()`, `RaceCard.PLAYER_LANE`.
- Produces, on `CasinoMenu`: `tile_rect(index: int) -> Rect2`, `wallet_rect() -> Rect2`, `cage_row_rect(index: int) -> Rect2`, `rules_rect() -> Rect2`.
- Produces, on `RaceMenu`: `card_rect(index: int) -> Rect2`, `stake_chip_rect(index: int) -> Rect2`, `card_page_rect() -> Rect2`, `first_visible_card() -> int`, `CARDS_VISIBLE := 5`.
- Produces, on `Ranch`: `race_entrants()` entries gain `"coat": Color` and `"mane": Color`; `NAMED_COAT` and `NAMED_MANE` constants.

**The one provider change, and it belongs to `ranch.gd`.** The menu cannot draw a coat swatch out of `{"uid", "name", "happiness", "odds", "chance"}`. `race_entrants()` gains two keys read off the instance's own `stock` triple through `StockPalette`. **The menu still never sees a `PonyInstance`, never reads a pen and cannot compute anything**, which is exactly the split `race_menu.gd`'s class comment already insists on. `form_lines()` is unchanged so `game/test/test_race_menu.gd` stays green, and the swatch falls back to a neutral grey when the keys are absent, so a gate building a bare entrant dictionary still works.

**`game/systems/pony_data.gd` carries no colour at all,** so a NAMED pony has no coat to read: her look is her model and her skin texture, and there is no `Color` anywhere on her record. She runs in the Palace's own two colours instead of in a guess, which is honest and which the constants below say out loud.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_casino_menu.gd`:

```gdscript
const PaintScript := preload("res://ui/casino_paint.gd")
## The file already preloads the SCENE as CasinoMenuScene; the SCRIPT is what carries
## LOBBY_ROWS and the Tab enum.
const CasinoMenuScript := preload("res://ui/casino_menu.gd")


## SIX TILES IN A 3 BY 2 GRID, none overlapping, none off the stage. The lobby is the first
## screen a player sees in this building and it used to be six sentences in a column.
func test_the_six_lobby_tiles_tile_the_stage_without_overlapping() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	for i: int in CasinoMenuScript.LOBBY_ROWS.size():
		assert_true(stage.encloses(_menu.tile_rect(i)), "tile %d leaves the stage" % i)
		for j: int in CasinoMenuScript.LOBBY_ROWS.size():
			if i >= j:
				continue
			assert_false(_menu.tile_rect(i).intersects(_menu.tile_rect(j)),
				"tiles %d and %d overlap" % [i, j])


## LOBBY_ROWS IS NOT REWRITTEN. The six strings are what the tiles are TITLED and DESCRIBED
## from, split at their own colon, and the wording is already good.
func test_the_lobby_rows_are_unchanged_and_every_one_splits_at_a_colon() -> void:
	assert_eq(CasinoMenuScript.LOBBY_ROWS.size(), 6)
	assert_eq(CasinoMenuScript.LOBBY_ROWS[1], "Slots: three reels, one lever, the fast one")
	for row: String in CasinoMenuScript.LOBBY_ROWS:
		assert_true(row.contains(": "), "'%s' has no title and description to split" % row)
		assert_false(row.contains("--"), "'%s' carries a dash" % row)


## THE HOUSE RULES PAGE IS WHERE THE PUBLISHED EDGES LIVE NOW. This is the surface the sign
## outside used to be, and it is reachable from the lobby's own picker.
func test_the_rules_tab_still_returns_every_line_the_sign_publishes() -> void:
	_menu.set_tab(CasinoMenuScript.Tab.RULES)
	var model: Array[String] = _menu.drawn_lines()
	assert_eq(model.size(), CasinoSignScript.lines().size())
	for line: String in CasinoSignScript.lines():
		assert_true(model.has(line), "the rules page still carries '%s'" % line)


func test_the_focus_id_names_the_tile_the_cursor_is_on() -> void:
	_menu.set_tab(CasinoMenuScript.Tab.LOBBY)
	assert_eq(String(_menu.focused_id()), "tile:0")
	_menu.move_selection(2)
	assert_eq(String(_menu.focused_id()), "tile:2")
```

Append to `game/test/test_race_menu.gd`:

```gdscript
const PaintScript := preload("res://ui/casino_paint.gd")
## The file already preloads the SCENE as RaceMenuScene; the SCRIPT is what carries
## CARDS_VISIBLE and the Tab enum.
const RaceMenuScript := preload("res://ui/race_menu.gd")


## ONE CARD PER ENTRANT, STACKED, NONE OVERLAPPING, NONE OFF THE STAGE.
func test_the_form_cards_stack_without_overlapping() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	for i: int in mini(_menu.entrants().size(), RaceMenuScript.CARDS_VISIBLE):
		assert_true(stage.encloses(_menu.card_rect(i)), "card %d leaves the stage" % i)
		if i == 0:
			continue
		assert_false(_menu.card_rect(i - 1).intersects(_menu.card_rect(i)),
			"cards %d and %d overlap" % [i - 1, i])


## THE WINDOW FOLLOWS THE CURSOR. More ponies than CARDS_VISIBLE is an ordinary state (a pen
## holds more than five), and a cursor that walked off the bottom of a fixed window would be a
## cursor the player cannot see.
func test_the_visible_window_keeps_the_focused_card_on_screen() -> void:
	var many: Array[Dictionary] = []
	for i: int in 9:
		many.append({"uid": StringName("p%d" % i), "name": "Pony %d" % i,
			"happiness": 0.5, "odds": 4.0, "chance": 0.2})
	_menu.entrants_provider = func() -> Array[Dictionary]: return many
	_menu.refresh()
	for row: int in 9:
		_menu.move_selection(1 if row > 0 else 0)
		var first: int = _menu.first_visible_card()
		assert_between(_menu.selected_index() - first, 0,
			RaceMenuScript.CARDS_VISIBLE - 1,
			"row %d is outside the visible window starting at %d" % [row, first])


## form_lines() IS UNCHANGED, and that is what keeps this file's older tests and the odds
## parser green. The swatch is drawn from two NEW keys and nothing else moved.
func test_the_form_lines_are_unchanged_and_a_missing_swatch_falls_back() -> void:
	var lines: Array[String] = _menu.form_lines()
	assert_gt(lines.size(), 0)
	for line: String in lines:
		assert_true(line.contains(" pays "), "'%s' still reads as the shipped sentence" % line)
		assert_true(line.contains("spirits"))
	# The fixture's entrants carry no coat or mane; the card still draws.
	_menu.refresh()
	assert_ne(String(_menu.focused_id()), "", "a colourless entrant still gets a card")


func test_the_focus_walks_the_cards_and_then_the_stake() -> void:
	assert_eq(String(_menu.focused_id()), "entrant:0")
	_menu.move_selection(_menu.entrants().size())
	assert_eq(String(_menu.focused_id()), "stake:%d" % _menu.stake_index())
```

- [ ] **Step 2: Run both to verify they fail**

```bash
for f in test_casino_menu test_race_menu; do
  tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
    -gtest=res://test/$f.gd -gexit 2>&1 | tail -6
done
```
Expected: both red, on `Nonexistent function 'tile_rect'` and `'card_rect'`.

- [ ] **Step 3: Draw the lobby**

Add to `game/ui/casino_menu.gd`, after `CAGE_STEPS`:

```gdscript
const PaintScript := preload("res://ui/casino_paint.gd")
const CasinoScript := preload("res://systems/casino.gd")

# --- the floor plan, in stage local pixels ----------------------------------------------------
const STAGE_HEIGHT := 510.0
const WALLET := Rect2(20.0, 8.0, 1080.0, 54.0)
const TILE_SIZE := Vector2(340.0, 200.0)
const TILE_ORIGIN := Vector2(30.0, 80.0)
const TILE_PITCH := Vector2(360.0, 216.0)
const TILE_ART_HEIGHT := 120.0
const RULES_PAGE := Rect2(40.0, 80.0, 1040.0, 410.0)
const EXCHANGE := Rect2(40.0, 80.0, 1040.0, 130.0)
const CAGE_ROW_ORIGIN := Vector2(60.0, 240.0)
const CAGE_ROW_SIZE := Vector2(500.0, 52.0)
const CAGE_ROW_PITCH := 60.0
const CAGE_ROWS_PER_COLUMN := 4
```

and the members:

```gdscript
func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


func tile_rect(index: int) -> Rect2:
	var lift: float = 6.0 if (index == _selected and _tab == Tab.LOBBY) else 0.0
	return Rect2(TILE_ORIGIN + Vector2(TILE_PITCH.x * float(index % 3),
		TILE_PITCH.y * float(index / 3)) - Vector2(0.0, lift), TILE_SIZE)


func wallet_rect() -> Rect2:
	return WALLET


func rules_rect() -> Rect2:
	return RULES_PAGE


## The cage's rows are the buys followed by the cashes, drawn as one list in two columns
## because the player is standing at one window. confirm()'s index arithmetic is unchanged.
func cage_row_rect(index: int) -> Rect2:
	return Rect2(CAGE_ROW_ORIGIN + Vector2(
		(CAGE_ROW_SIZE.x + 20.0) * float(index / CAGE_ROWS_PER_COLUMN),
		CAGE_ROW_PITCH * float(index % CAGE_ROWS_PER_COLUMN)), CAGE_ROW_SIZE)


## THE STAGE SHOWS EVERY LOBBY ROW AND EVERY CAGE ROW, so the column under it keeps only the
## cage's three line explainer. drawn_lines() is unchanged and still returns all of it.
func printed_lines() -> Array[String]:
	if _tab != Tab.CAGE:
		return [] as Array[String]
	var lines: Array[String] = []
	for line in CasinoSignScript.cage_explainer():
		lines.append(line)
	return lines


func focus_rect() -> Rect2:
	match _tab:
		Tab.LOBBY:
			return to_viewport(tile_rect(clampi(_selected, 0, LOBBY_ROWS.size() - 1)))
		Tab.CAGE:
			if _row_count() <= 0:
				return Rect2()
			return to_viewport(cage_row_rect(clampi(_selected, 0, _row_count() - 1)))
	return Rect2()


func focused_id() -> StringName:
	match _tab:
		Tab.LOBBY:
			return StringName("tile:%d" % clampi(_selected, 0, LOBBY_ROWS.size() - 1))
		Tab.CAGE:
			if _row_count() <= 0:
				return &""
			return StringName("cage:%d" % clampi(_selected, 0, _row_count() - 1))
	return &""


func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()

	# --- the wallet strip, on every page of the building ---------------------------------------
	# What she is holding, continuously, and the two side by side is what makes "one for one"
	# mean something. header_line() keeps returning its sentence for drawn_lines().
	PaintScript.rounded(ci, WALLET, 12.0, Color(PaintScript.PLUM_DARK, 0.9),
		PaintScript.GOLD_DIM, 2.0)
	var bits: int = int(bits_provider.call()) if bits_provider.is_valid() else 0
	var chips: int = int(chips_provider.call()) if chips_provider.is_valid() else 0
	PaintScript.draw_bit(ci, Rect2(WALLET.position + Vector2(18.0, 15.0), Vector2(24.0, 24.0)))
	PaintScript.text(ci, MenuStyleScript.numeral_font(),
		WALLET.position + Vector2(52.0, 37.0), "%d bits" % bits, MenuStyleScript.ROW_SIZE,
		PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	PaintScript.draw_chip_icon(ci,
		Rect2(WALLET.position + Vector2(200.0, 15.0), Vector2(24.0, 24.0)))
	PaintScript.text(ci, MenuStyleScript.numeral_font(),
		WALLET.position + Vector2(234.0, 37.0), "%d chips" % chips, MenuStyleScript.ROW_SIZE,
		PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	PaintScript.text(ci, font, WALLET.position + Vector2(400.0, 37.0),
		"one for one at the cage", MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	MenuStyleScript.rule(ci, Vector2(20.0, 70.0), Vector2(STAGE_WIDTH - 20.0, 70.0))

	match _tab:
		Tab.LOBBY:
			for i: int in LOBBY_ROWS.size():
				var tile: Rect2 = tile_rect(i)
				var picked: bool = i == _selected
				PaintScript.rounded(ci, tile, 14.0,
					Color(PaintScript.PLUM_DARK, 1.0 if picked else 0.74),
					PaintScript.GOLD if picked else PaintScript.GOLD_DIM, 2.0)
				PaintScript.draw_room(ci, Rect2(tile.position + Vector2(16.0, 10.0),
					Vector2(tile.size.x - 32.0, TILE_ART_HEIGHT)), i)
				# SPLIT AT THE COLON OF ITS OWN LOBBY_ROWS ENTRY. The six strings are not
				# rewritten: game/test/test_casino_menu.gd and the no dash sweeps read them,
				# and the wording is already good.
				var halves: PackedStringArray = LOBBY_ROWS[i].split(": ", true, 1)
				PaintScript.text(ci, MenuStyleScript.title_font(),
					tile.position + Vector2(18.0, TILE_ART_HEIGHT + 44.0), halves[0], 26,
					MenuStyleScript.COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT, tile.size.x - 36.0)
				if halves.size() > 1:
					PaintScript.text(ci, font,
						tile.position + Vector2(18.0, TILE_ART_HEIGHT + 72.0), halves[1],
						MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM,
						HORIZONTAL_ALIGNMENT_LEFT, tile.size.x - 36.0)
				if picked:
					PaintScript.focus_ring(ci, tile, 14.0, t)
		Tab.CAGE:
			PaintScript.rounded(ci, EXCHANGE, 12.0, Color(PaintScript.FELT_DARK, 0.85),
				PaintScript.GOLD_DIM, 2.0)
			PaintScript.chip_stack(ci, EXCHANGE.position + Vector2(140.0, 104.0), 5,
				PaintScript.GOLD, 9.0)
			PaintScript.chip_stack(ci, EXCHANGE.position + Vector2(900.0, 104.0), 5,
				PaintScript.CHIP_COLORS[1], 9.0)
			for direction: float in [-1.0, 1.0]:
				var y: float = EXCHANGE.position.y + 62.0
				ci.draw_line(Vector2(EXCHANGE.position.x + 240.0, y),
					Vector2(EXCHANGE.position.x + 800.0, y), PaintScript.GOLD, 3.0, true)
				var tip_x: float = EXCHANGE.position.x + (800.0 if direction > 0.0 else 240.0)
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(tip_x + 18.0 * direction, y),
					Vector2(tip_x, y - 12.0), Vector2(tip_x, y + 12.0)]), PaintScript.GOLD)
			PaintScript.text(ci, MenuStyleScript.numeral_font(),
				EXCHANGE.position + Vector2(520.0, 48.0),
				"%d for %d" % [CasinoScript.CHIP_RATE, CasinoScript.CHIP_RATE],
				MenuStyleScript.ROW_SIZE, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			var index := 0
			for amount: int in buys:
				_paint_cage_row(ci, font, index, "Buy %d chips for %d bits" % [amount, amount],
					PaintScript.CHIP_COLORS[1], t)
				index += 1
			for amount: int in cashes:
				_paint_cage_row(ci, font, index,
					"Cash out %d chips for %d bits" % [amount, amount], PaintScript.GOLD, t)
				index += 1
			if buys.is_empty() and cashes.is_empty():
				PaintScript.text(ci, font, CAGE_ROW_ORIGIN + Vector2(0.0, 34.0),
					"Come back when you have something to play with.",
					MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		Tab.RULES:
			# THE PUBLISHED EDGES LIVE HERE NOW. sign_provider is ranch.gd's own lambda over
			# CasinoSign.lines(), which asks each game for its real number; nothing about that
			# promise changed when the board outside stopped being a paragraph in the air.
			var rules: Array[String] = []
			if sign_provider.is_valid():
				for line in sign_provider.call():
					rules.append(String(line))
			PaintScript.plate(ci, RULES_PAGE, font, "", rules)


func _paint_cage_row(ci: Control, font: Font, index: int, label: String, colour: Color,
		t: float) -> void:
	var rect: Rect2 = cage_row_rect(index)
	var picked: bool = index == _selected
	PaintScript.rounded(ci, rect, 8.0, Color(PaintScript.FELT_DARK, 0.8),
		PaintScript.GOLD_DIM, 1.0)
	PaintScript.chip(ci, rect.position + Vector2(30.0, rect.size.y * 0.5), 18.0, colour, false)
	PaintScript.text(ci, font, rect.position + Vector2(62.0, 34.0), label,
		MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_NAME, HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 80.0)
	if picked:
		PaintScript.focus_ring(ci, rect, 8.0, t)
```

- [ ] **Step 4: Draw the form guide**

Add to `game/ui/race_menu.gd`, after `EMPTY_TEXT`:

```gdscript
## PaintScript is NOT re-declared here: table_menu.gd already carries it and GDScript
## refuses a const that shadows one declared on the parent class. Same reason
## WHEEL_FOOTER had to have a distinct name from TableMenu's own FOOTER.

# --- the form guide, in stage local pixels -----------------------------------------------------
## Five cards at a time. A pen holds more than five ponies, so the window scrolls with the
## cursor rather than the stage growing without limit down past the bottom of the screen.
const CARDS_VISIBLE := 5
const CARD_SIZE := Vector2(1080.0, 96.0)
const CARD_LEFT := 20.0
const CARD_TOP := 10.0
const CARD_PITCH := 106.0
const STAKE_PITCH := 96.0
const CHIP_RADIUS := 30.0
const CARD_PAGE := Rect2(40.0, 20.0, 1040.0, 400.0)

## Where each thing on a card sits, measured from the card's own left edge.
const SILKS_X := 18.0
const NAME_X := 130.0
const ODDS_X := 560.0
const SPIRITS_X := 660.0
const CHANCE_X := 830.0
const CHANCE_WIDTH := 220.0

## A pony with no coat in her row. See ranch.gd's NAMED_COAT for why a named character has no
## colour to read; this is also what a gate that builds a bare entrant dictionary gets.
const FALLBACK_COAT := Color(0.70, 0.70, 0.74)
const FALLBACK_MANE := Color(0.52, 0.52, 0.58)
```

and the members:

```gdscript
func stage_size() -> Vector2:
	if _tab == Tab.CARD:
		return Vector2(STAGE_WIDTH, 440.0)
	var shown: int = mini(entrants().size(), CARDS_VISIBLE)
	return Vector2(STAGE_WIDTH, CARD_TOP + CARD_PITCH * float(maxi(shown, 1)) + 96.0)


## The first entrant the window is showing. Scrolls only as far as it must to keep the cursor
## on screen, so a short field never scrolls at all.
func first_visible_card() -> int:
	var total: int = entrants().size()
	if total <= CARDS_VISIBLE:
		return 0
	var row: int = clampi(_selected, 0, total - 1)
	return clampi(row - CARDS_VISIBLE + 1, 0, total - CARDS_VISIBLE)


## `index` is an ABSOLUTE entrant index; the window is subtracted here so every caller can
## think in entrants rather than in scroll positions.
func card_rect(index: int) -> Rect2:
	var slot: int = index - first_visible_card()
	var lift: float = 6.0 if index == _selected else 0.0
	return Rect2(Vector2(CARD_LEFT, CARD_TOP + CARD_PITCH * float(slot) - lift), CARD_SIZE)


func stake_chip_rect(index: int) -> Rect2:
	var shown: int = mini(entrants().size(), CARDS_VISIBLE)
	var y: float = CARD_TOP + CARD_PITCH * float(shown) + 40.0
	var centre := Vector2(CARD_LEFT + CHIP_RADIUS + STAKE_PITCH * float(index),
		y - (8.0 if index == stake_index() else 0.0))
	return Rect2(centre - Vector2(CHIP_RADIUS, CHIP_RADIUS) * 1.1,
		Vector2(CHIP_RADIUS, CHIP_RADIUS) * 2.2)


func card_page_rect() -> Rect2:
	return CARD_PAGE


## Every card and the whole card page are on the stage; the column keeps the two lines that
## are not pictures plus the last result.
func printed_lines() -> Array[String]:
	if _tab != Tab.ENTER:
		return [] as Array[String]
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	return lines


func first_row_line_index() -> int:
	return printed_lines().size()


func focus_rect() -> Rect2:
	if _tab != Tab.ENTER or entrants().is_empty():
		return Rect2()
	if _on_stake_row():
		if stakes().is_empty():
			return Rect2()
		return to_viewport(stake_chip_rect(clampi(stake_index(), 0, stakes().size() - 1)))
	return to_viewport(card_rect(clampi(_selected, 0, entrants().size() - 1)))


func focused_id() -> StringName:
	if _tab != Tab.ENTER or entrants().is_empty():
		return &""
	if _on_stake_row():
		return StringName("stake:%d" % stake_index())
	return StringName("entrant:%d" % clampi(_selected, 0, entrants().size() - 1))


func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()

	if _tab == Tab.CARD:
		var page: Array[String] = drawn_lines()
		PaintScript.plate(ci, CARD_PAGE, font, "", page)
		return

	var field: Array[Dictionary] = entrants()
	if field.is_empty():
		# THE EMPTY STATE IS A PICTURE PLUS THE SENTENCE, not the sentence alone. A player who
		# has caught nothing yet is the player who most needs to be told what to do next.
		PaintScript.draw_room(ci, Rect2(STAGE_WIDTH * 0.5 - 110.0, 20.0, 220.0, 150.0), 4)
		PaintScript.text(ci, font, Vector2(STAGE_WIDTH * 0.5, 214.0), EMPTY_TEXT,
			MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM,
			HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		return

	var first: int = first_visible_card()
	for index: int in range(first, mini(first + CARDS_VISIBLE, field.size())):
		var entry: Dictionary = field[index]
		var card: Rect2 = card_rect(index)
		var picked: bool = index == _selected
		PaintScript.rounded(ci, card, 12.0, Color(PaintScript.FELT, 1.0 if picked else 0.72),
			PaintScript.GOLD_DIM, 2.0)

		# Her silks: coat behind, mane in front, plus a lane flash in BAND_COLORS[0] because
		# RaceCard.PLAYER_LANE is 0 and the pony you back always runs on the rail.
		var coat: Color = entry.get("coat", FALLBACK_COAT)
		var mane: Color = entry.get("mane", FALLBACK_MANE)
		PaintScript.rounded(ci, Rect2(card.position + Vector2(SILKS_X, 20.0),
			Vector2(58.0, 58.0)), 8.0, coat, coat.darkened(0.25), 2.0)
		PaintScript.rounded(ci, Rect2(card.position + Vector2(SILKS_X + 26.0, 34.0),
			Vector2(42.0, 44.0)), 6.0, mane, mane.darkened(0.25), 2.0)
		ci.draw_rect(Rect2(card.position + Vector2(SILKS_X, 82.0), Vector2(58.0, 6.0)),
			PaintScript.BAND_COLORS[0])

		PaintScript.text(ci, MenuStyleScript.title_font(),
			card.position + Vector2(NAME_X, 58.0), String(entry.get("name", "Pony")), 26,
			MenuStyleScript.COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT, 400.0)

		# The odds on a chip, in RaceCard.odds_text()'s own wording, which is what
		# game/test/test_published_payouts.gd parses. Drawn on a chip instead of printed in a
		# sentence; the string is byte for byte the same string.
		var odds_at: Vector2 = card.position + Vector2(ODDS_X, card.size.y * 0.5)
		PaintScript.chip(ci, odds_at, 34.0, PaintScript.GOLD, false)
		PaintScript.text(ci, MenuStyleScript.numeral_font(), odds_at + Vector2(0.0, 6.0),
			RaceCardScript.odds_text(float(entry.get("odds", 0.0))), 16,
			PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)

		# Ten pips, the same number form_lines() prints. A hungry pony is a slow pony.
		var spirits: int = roundi(float(entry.get("happiness", 0.0)) * 10.0)
		for pip: int in 10:
			var at: Vector2 = card.position + Vector2(SPIRITS_X + 16.0 * float(pip), 48.0)
			if pip < spirits:
				ci.draw_circle(at, 6.0, PaintScript.GOLD)
			else:
				ci.draw_arc(at, 6.0, 0.0, TAU, 12, PaintScript.GOLD_DIM, 1.5, true)

		# The win chance the odds are BUILT FROM. Showing it is what makes the odds legible:
		# a price with no probability beside it is a number a player has to take on trust.
		var track := Rect2(card.position + Vector2(CHANCE_X, 40.0),
			Vector2(CHANCE_WIDTH, 16.0))
		PaintScript.rounded(ci, track, 8.0, PaintScript.FELT_DARK, PaintScript.GOLD_DIM, 1.0)
		var chance: float = clampf(float(entry.get("chance", 0.0)), 0.0, 1.0)
		PaintScript.rounded(ci, Rect2(track.position,
			Vector2(track.size.x * chance, track.size.y)), 8.0,
			PaintScript.BAND_COLORS[3], PaintScript.BAND_COLORS[3], 0.0)
		PaintScript.text(ci, font, card.position + Vector2(CHANCE_X, 80.0),
			"%d in 100 by the card" % roundi(chance * 100.0),
			MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM,
			HORIZONTAL_ALIGNMENT_LEFT, CHANCE_WIDTH)

		if picked:
			PaintScript.focus_ring(ci, card, 12.0, t)

	var available: Array[int] = stakes()
	for i: int in available.size():
		var box: Rect2 = stake_chip_rect(i)
		PaintScript.chip(ci, box.position + box.size * 0.5, CHIP_RADIUS,
			PaintScript.CHIP_COLORS[i % PaintScript.CHIP_COLORS.size()], true)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			box.position + Vector2(box.size.x * 0.5, box.size.y * 0.62), str(available[i]),
			20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		if _on_stake_row() and i == stake_index():
			PaintScript.focus_ring(ci, box.grow(6.0), 40.0, t)
```

- [ ] **Step 5: Add the two colour keys to `ranch.gd`**

Beside the other casino constants on `game/world/ranch.gd`:

```gdscript
## THE SILKS A NAMED PONY RUNS IN. game/systems/pony_data.gd carries no coat and no mane
## colour: a named character's look is her MODEL and her skin texture, and there is no Color
## anywhere on her record to read. A stock pony has three palette indices and therefore two
## real colours; a named one has none, so she runs in the Palace's own two rather than in a
## colour somebody guessed for her. She is also the pony the form guide can already tell
## apart, because she has a name and a stock pony does not.
const NAMED_COAT := Color(0.86, 0.84, 0.90)
const NAMED_MANE := Color(0.36, 0.16, 0.42)
```

In `race_entrants()`, inside the `for inst: PonyInstance in pen.ponies():` loop, immediately before `out.append({`:

```gdscript
		# HER COLOURS, FOR THE FORM GUIDE'S SILKS SWATCH, AND NOTHING ELSE. Resolved here and
		# not in the menu, for the reason race_menu.gd's class comment gives: the menu never
		# sees a PonyInstance, never reads a pen and cannot compute anything. Two Colors in a
		# row dictionary is data, the same way "odds" and "chance" already are.
		var coat: Color = NAMED_COAT
		var mane: Color = NAMED_MANE
		if inst.is_stock():
			if _stock_palette == null:
				_stock_palette = StockPaletteScript.load_stock()
			coat = _stock_palette.coat_at(int(inst.stock.get("coat", 0)))
			mane = _stock_palette.mane_at(int(inst.stock.get("mane", 0)))
```

and add the two keys to the dictionary literal:

```gdscript
				"coat": coat,
				"mane": mane,
```

- [ ] **Step 6: Retarget the lobby's own gate check**

In `game/scenes/test/casino_test.gd`, inside the stage block from Task 3, add the lobby to the loop by checking it separately after the four tables:

```gdscript
	var lobby_stage: CanvasLayer = ranch.get_casino_menu()
	if lobby_stage != null:
		lobby_stage.call("open")
		await get_tree().process_frame
		var lobby_size: Vector2 = lobby_stage.call("stage_size")
		_set_check("the lobby draws a floor plan rather than a list",
			lobby_size.x > 0.0 and lobby_size.y > 0.0
				and String(lobby_stage.call("focused_id")) == "tile:0")
		lobby_stage.call("close")
		await get_tree().process_frame
```

- [ ] **Step 7: Run everything**

```bash
for f in test_casino_menu test_race_menu test_casino_stages test_published_payouts; do
  tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
    -gtest=res://test/$f.gd -gexit 2>&1 | tail -5
done
bash tools/run_tests.sh 2>&1 | tail -12
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn 2>&1 \
  | grep -E "CASINO stage|CASINO_OK|CASINO_FAILED"
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```
Expected: all green, `CASINO_OK`, `RANCH_OK ponies=49 props=110 assets=present`.

- [ ] **Step 8: Commit**

```bash
printf 'feat: the lobby is a floor plan and the form guide is a form guide\n\nSix tiles in a three by two grid, each with the room s own illustration filling\nits top and its words underneath, split at the colon of its own LOBBY_ROWS\nentry. LOBBY_ROWS is not rewritten: the six strings are read by the tests and\nthe no dash sweeps, and the wording was already good. The wallet strip runs\nacross the top of every page, the cage gains a drawn exchange with a pile of\nbits, an arrow and a pile of chips, and the house rules page is a plate\ncarrying the eleven lines CasinoSign.lines() returns.\n\nOne card per entrant on the racing screen: her silks as two overlapping\nswatches with a lane flash, her name in the title weight, her price on a drawn\nchip in RaceCard.odds_text() s own unchanged wording, ten spirit pips, and a\nwin chance bar. The chance is the number the odds are built from, and showing\nit is what makes a price legible rather than something to take on trust. Five\ncards at a time with a window that follows the cursor, because a pen holds more\nthan five ponies.\n\nranch.gd s entrants_provider gains coat and mane. Resolved there and not in the\nmenu, for the reason race_menu.gd s class comment gives: the menu never sees a\nPonyInstance and cannot compute anything. pony_data.gd carries no colour at\nall, so a named character runs in the Palace s own two rather than in a guess,\nand the constant says so.\n\nform_lines() and drawn_lines() are unchanged on both menus.\n' > /tmp/polish-task7.txt
git add game/ui/casino_menu.gd game/ui/race_menu.gd game/world/ranch.gd \
  game/scenes/test/casino_test.gd game/test/test_casino_menu.gd game/test/test_race_menu.gd
git commit -F /tmp/polish-task7.txt
```

---

### Task 8: The world text, all four sites decided

**Files:**
- Create: `game/world/lobby_sign.gd`, `game/test/test_lobby_sign.gd`
- Modify: `game/world/ranch.tscn` (delete one node), `game/world/ranch.gd` (the sign block in `_ready()`), `game/world/strip.gd`, `game/world/race_runner.gd`, `game/world/race_track.gd`, `game/scenes/test/casino_test.gd`, `game/test/test_race_runner.gd`, `game/test/test_strip.gd`
- Test: `game/test/test_lobby_sign.gd`, `game/test/test_race_runner.gd`, `game/test/test_strip.gd`, `game/scenes/test/casino_test.gd`

**Interfaces:**
- Consumes: `Building`'s `width`, `depth`, `door_height`, `ridge_height` exports; `Strip.MARQUEE_TRIM_COLOR`, `Strip.LAMP_COLOR`, `Strip.LIGHT_COUNT`, `Strip.light_count()`; `CasinoPaint.BAND_COLORS` (Task 1); `RaceCard.PLAYER_LANE`.
- Produces:
  - `LobbySign` (`class_name LobbySign extends Node3D`) with `build(board_width: float, board_height: float, facing: Vector3, headline: String, subline: String) -> void`, `board_size() -> Vector2`, `lines() -> Array[String]`, and constants `HEADLINE := "House rules"`, `SUBLINE := "every edge we keep, printed inside"`.
  - `Strip.marquee_bulb_count() -> int` (10) and a `MarqueeBulbs` `MultiMeshInstance3D` plus a `MarqueeWash` `SpotLight3D` under the marquee assembly.
  - `RaceRunner.dress(data: PonyData, triple: Dictionary, display: String, lane := -1) -> bool`, `RaceRunner.lane() -> int`, and the `Saddlecloth` / `Chevron` node names.
  - `RaceTrack` gains six `GatePost<lane>` posts in their lane's colour.
- **Removes:** `Buildings/Palace/Sign` (a `Label3D`) and `RaceRunner._ensure_plate()` with its `Nameplate`.

**The census does not move, and here is why.** `Sign` is a child of `Buildings/Palace`, not a child of `Buildings`, and `prop_count` is `Props.expected_count() + buildings.get_child_count()`. `LobbySign` replaces it in the same place, so `props=110` is unchanged. The marquee bulbs go under the marquee assembly and NOT into `Strip._lights`, so `light_count()` still answers 9 and the strip gate's "the lamps are standing, minus the one skipped clear of the Palace" check is unaffected. The gate posts are children of `RaceTrack`, which is neither a prop nor a building.

**One measurement this task must not break.** `ranch.gd`'s seating check reads `Props.world_aabb(prop)` over every `MeshInstance3D` under a `Building` and compares its BOTTOM against `Building.seat_ground()`. The Palace's plinth already runs to local `y = -SKIRT_DEPTH` (1.20 m below its origin), and `LobbySign` mounts on the wall with its lowest point at local `y = 0` or above, so the Palace's AABB bottom is unchanged and `seat_error` stays where it is. The old `Sign` was a `Label3D` and never entered that AABB at all, so this is the one number to read off the gate in step 8 rather than assume.

- [ ] **Step 1: Write the failing sign test**

Create `game/test/test_lobby_sign.gd`:

```gdscript
extends GutTest
## THE BOARD THAT REPLACED THE PARAGRAPH IN THE AIR.
##
## WHAT WAS THERE. Buildings/Palace/Sign was a Label3D carrying eleven lines of published
## house edges at pixel_size 0.0032 and font_size 48, which is a cap height of about 0.15 m
## per line and roughly 1.7 m of unbacked text stack hanging 2.1 m up and 4.1 m out from the
## Palace. The owner, 2026-09-01: "the note on the casino looks very poor". It was also a
## paragraph nobody can read from a distance and nobody needs to read while standing outside
## a door.
##
## WHAT IS THERE NOW. A board with a trim, sized off the Palace's own width, carrying two
## FITTED lines: a headline and one sentence pointing inside. The eleven lines live on the
## casino lobby's House rules page, which is one of the six things the player sees the moment
## she walks in; game/scenes/test/casino_test.gd asserts them there.
##
## FITTED IS THE WHOLE POINT and it is what this file checks. game/world/strip.gd's
## _marquee_label() sizes a Label3D's width in the same pixel units its font_size is in, and
## sets the wrap mode with it, because either one alone does nothing. A label whose width was
## left at zero is a label that ignores its board, which is the defect that put a 66 character
## marquee across a 14 metre building in the first place.

const LobbySignScript := preload("res://world/lobby_sign.gd")

const BOARD_WIDTH := 3.6
const BOARD_HEIGHT := 1.1


func _built() -> LobbySign:
	var sign_node: LobbySign = LobbySignScript.new()
	add_child_autofree(sign_node)
	sign_node.build(BOARD_WIDTH, BOARD_HEIGHT, Vector3(0.0, 0.0, 1.0),
		LobbySignScript.HEADLINE, LobbySignScript.SUBLINE)
	return sign_node


func test_the_board_and_its_trim_are_standing_behind_the_letters() -> void:
	var sign_node: LobbySign = _built()
	assert_not_null(sign_node.get_node_or_null(^"Board"),
		"unbacked letters in the air is the thing this replaced")
	assert_not_null(sign_node.get_node_or_null(^"Trim"))
	assert_eq(sign_node.board_size(), Vector2(BOARD_WIDTH, BOARD_HEIGHT))


func test_both_lines_are_fitted_to_the_board_rather_than_free_floating() -> void:
	var sign_node: LobbySign = _built()
	for path: NodePath in [^"Headline", ^"Subline"]:
		var label := sign_node.get_node_or_null(path) as Label3D
		assert_not_null(label, "%s is missing" % path)
		assert_gt(label.pixel_size, 0.0)
		assert_almost_eq(label.width * label.pixel_size, BOARD_WIDTH, 0.001,
			"%s is not fitted to the board's width" % path)
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD,
			"a width with no wrap mode does nothing")
		assert_eq(label.billboard, BaseMaterial3D.BILLBOARD_DISABLED,
			"a sign on a board does not turn to face you")


## NOTHING ON THIS BOARD SITS BELOW ITS OWN ORIGIN. ranch.gd's seating check measures the
## BOTTOM of the world AABB of every MeshInstance3D under a building against the height the
## building was seated at, so a sign hanging below the Palace's local y = 0 would drag that
## bottom down and fail the gate on a correctly placed building.
func test_nothing_on_the_board_hangs_below_the_signs_own_origin() -> void:
	var sign_node: LobbySign = _built()
	for child in sign_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box: AABB = mesh.get_aabb()
		assert_gte(mesh.position.y + box.position.y, -0.001,
			"%s hangs below the sign's origin" % mesh.name)


func test_neither_line_carries_a_dash() -> void:
	for line: String in LobbySignScript.lines():
		assert_false(line.contains("--"), "'%s' carries a double hyphen" % line)
		assert_false(line.contains("—"), "'%s' carries an em dash" % line)
		assert_false(line.is_empty())
```

- [ ] **Step 2: Run it to verify it fails**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_lobby_sign.gd -gexit 2>&1 | tail -8
```
Expected: FAIL, `res://world/lobby_sign.gd` does not exist.

- [ ] **Step 3: Write the sign**

Create `game/world/lobby_sign.gd`:

```gdscript
class_name LobbySign
extends Node3D
## THE BOARD BESIDE THE PALACE DOOR, and the thing it replaced.
##
## WHAT IT REPLACED. Buildings/Palace/Sign was a Label3D carrying all eleven lines of
## CasinoSign.lines() at pixel_size 0.0032 and font_size 48: a cap height of about 0.15 m per
## line, roughly 1.7 m of unbacked text hanging in the air 2.1 m up and 4.1 m out from the
## Palace's local origin. It was the single worst piece of floating text in the game and it is
## the one the owner named: "the note on the casino looks very poor".
##
## WHERE THE ELEVEN LINES WENT, AND WHY THE PROMISE IS KEPT. game/systems/casino_sign.gd's
## whole ethical position is that the odds on the sign are the real ones and that it ASKS EACH
## GAME what its edge is. None of that changed: CasinoSign.lines() is untouched, it still
## derives all four numbers from Slots.house_edge(), Wheel.house_edge(), Blackjack.house_edge()
## and RaceCard.TAKEOUT, and CasinoMenu's sign_provider still calls it. The eleven lines are
## drawn on the lobby's House rules page, reachable from the picker the player sees the moment
## she walks in. THE EDGES BECAME MORE VISIBLE, NOT LESS: they were a distant paragraph
## outside a door and they are now a page inside the building that the lobby points at.
##
## FITTED, THE SAME WAY THE MARQUEE IS. game/world/strip.gd's _marquee_label() is the method
## this copies: the label's width is set in the same pixel units its font_size is in, together
## with the wrap mode, because either one alone does nothing, and the yaw comes from the
## facing rather than from a hard coded half turn that reads correctly only for a building
## standing the way ranch.tscn happens to stand this one.
##
## NOTHING HERE HANGS BELOW LOCAL y = 0. ranch.gd's seating check measures the bottom of every
## MeshInstance3D under a building; a board reaching below the Palace's origin would drag that
## bottom down and fail the gate on a correctly placed building.

const HEADLINE := "House rules"
const SUBLINE := "every edge we keep, printed inside"

## Board and trim colours, lifted from game/world/strip.gd's marquee so the two signs on this
## one building are obviously the same signwriter's work.
const BOARD_COLOR := Color(0.16, 0.07, 0.20)
const TRIM_COLOR := Color(0.98, 0.86, 0.45)
const TEXT_COLOR := Color(1.0, 0.92, 0.62)
const TRIM := 0.08
const THICKNESS := 0.10

## The headline's cap height as a fraction of the board, and the subline's as a fraction of
## the headline. Strip.MARQUEE_HEADLINE_FRACTION's and MARQUEE_SPONSOR_SCALE's numbers, for
## the same reason: they were arrived at by looking at a rendered board.
const HEADLINE_FRACTION := 0.34
const SUBLINE_SCALE := 0.55
const FONT_SIZE := 96

var _size := Vector2.ZERO
var _facing := Vector3(0.0, 0.0, 1.0)


static func lines() -> Array[String]:
	return [HEADLINE, SUBLINE]


func board_size() -> Vector2:
	return _size


## Stand the board. `facing` is the direction the letters look, normally the building's own
## outward axis; `board_width` and `board_height` are metres.
func build(board_width: float, board_height: float, facing: Vector3,
		headline: String, subline: String) -> void:
	_size = Vector2(board_width, board_height)
	var flat := Vector3(facing.x, 0.0, facing.z)
	_facing = flat.normalized() if flat.length_squared() > 0.0 else Vector3(0.0, 0.0, 1.0)

	_slab("Trim", Vector3(board_width + TRIM * 2.0, board_height + TRIM * 2.0, THICKNESS),
		Vector3(0.0, board_height * 0.5, 0.0), TRIM_COLOR)
	_slab("Board", Vector3(board_width, board_height, THICKNESS * 0.6),
		Vector3(0.0, board_height * 0.5, 0.0) + _facing * 0.03, BOARD_COLOR)

	var headline_height: float = board_height * HEADLINE_FRACTION
	_label("Headline", headline, headline_height,
		Vector3(0.0, board_height * 0.68, 0.0) + _facing * 0.07)
	_label("Subline", subline, headline_height * SUBLINE_SCALE,
		Vector3(0.0, board_height * 0.30, 0.0) + _facing * 0.07)


func _slab(slab_name: String, size: Vector3, at: Vector3, colour: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = slab_name
	mesh.mesh = box
	add_child(mesh)
	mesh.position = at
	mesh.rotation.y = atan2(_facing.x, _facing.z)


## One line, `cap_height` metres tall, FITTED to the board's width. Label3D's own text faces
## its local plus Z, so the yaw that points that at `_facing` is atan2(x, z) of the facing.
func _label(label_name: String, text: String, cap_height: float, at: Vector3) -> void:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.font_size = FONT_SIZE
	var pixel: float = cap_height / float(FONT_SIZE)
	label.pixel_size = pixel
	# Set together with the wrap mode; either one alone does nothing.
	label.width = _size.x / pixel
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = TEXT_COLOR
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.shaded = false
	add_child(label)
	label.position = at
	label.rotation.y = atan2(_facing.x, _facing.z)
```

- [ ] **Step 4: Swap the node in the scene and in `ranch.gd`**

Delete the whole `[node name="Sign" type="Label3D" parent="Buildings/Palace"]` block from `game/world/ranch.tscn`:

```bash
python3 - game/world/ranch.tscn <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
block = re.search(r'\[node name="Sign" type="Label3D" parent="Buildings/Palace"\](.|\n)*?\n\n',
                  text)
assert block, "the Sign node was not found; it may already be gone"
text = text[:block.start()] + text[block.end():]
open(path, 'w').write(text)
PY
grep -c 'name="Sign"' game/world/ranch.tscn
```
Expected: `0`.

Then in `game/world/ranch.gd`'s `_ready()`, replace the whole `lobby_sign` block (the one whose comment begins "THE SIGN READS ITSELF OUT OF THE GAMES", immediately above `var prop_count := props.build() + ...`) with:

```gdscript
	# THE PUBLISHED EDGES MOVED INSIDE, AND THE PROMISE CAME WITH THEM. This used to write all
	# eleven lines of CasinoSign.lines() into a Label3D hanging unbacked in the air outside the
	# door: about 1.7 m of text stack at a cap height of 0.15 m per line, which is what the
	# owner saw and called "very poor". The eleven lines are now the casino lobby's House rules
	# page, drawn as a plate and reachable from the picker she walks into, and CasinoMenu's
	# sign_provider is still CasinoSign.lines(), so the numbers still come from the games
	# themselves. What stands outside is a board with two fitted lines pointing at them.
	#
	# SIZED OFF THE PALACE'S OWN NUMBERS, the way strip.gd's mount_marquee() is, so a Palace
	# resized in ranch.tscn resizes its own signage instead of leaving a board floating beside
	# a building that moved.
	var palace_for_sign := get_node_or_null(^"Buildings/Palace") as Building
	if palace_for_sign != null:
		var sign_out: Vector3 = palace_for_sign.global_transform.basis * Vector3(0.0, 0.0, 1.0)
		sign_out.y = 0.0
		sign_out = sign_out.normalized() if sign_out.length_squared() > 0.0 \
			else Vector3(0.0, 0.0, 1.0)
		var lobby_sign := LobbySignScript.new()
		lobby_sign.name = "LobbySign"
		palace_for_sign.add_child(lobby_sign)
		# Beside the door rather than in front of it: a quarter of the building's width along
		# its own side axis, and clear of the door apron the vendor and the player walk up.
		var side: Vector3 = palace_for_sign.global_transform.basis * Vector3(1.0, 0.0, 0.0)
		lobby_sign.position = Vector3(0.0, LOBBY_SIGN_BASE, 0.0) \
			+ palace_for_sign.to_local(palace_for_sign.global_position
				+ side * (palace_for_sign.width * 0.28)
				+ sign_out * (palace_for_sign.depth * 0.5 + LOBBY_SIGN_STANDOFF))
		lobby_sign.build(palace_for_sign.width * LOBBY_SIGN_WIDTH_FRACTION,
			LOBBY_SIGN_HEIGHT, sign_out, LobbySignScript.HEADLINE, LobbySignScript.SUBLINE)
```

with the preload beside the other world preloads:

```gdscript
const LobbySignScript := preload("res://world/lobby_sign.gd")
```

and four constants beside the other Palace constants:

```gdscript
## THE BOARD BESIDE THE PALACE DOOR. Its width is a fraction of the building's own, its base
## sits ABOVE the Palace's local y = 0 (which is its plinth top, not the ground) so nothing on
## it drags the building's world AABB down past what ranch.gd's own seating check expects, and
## the standoff clears the wall by more than the trim's own thickness.
const LOBBY_SIGN_WIDTH_FRACTION := 0.26
const LOBBY_SIGN_HEIGHT := 1.10
const LOBBY_SIGN_BASE := 1.05
const LOBBY_SIGN_STANDOFF := 0.30
```

- [ ] **Step 5: Light the marquee**

In `game/world/strip.gd`, add two constants beside the marquee block:

```gdscript
## TEN BULBS ROUND THE MARQUEE TRIM, as ONE MultiMeshInstance3D: ten instances and one draw
## call. With glow on (the Environment gains it in the look pass) they bloom gently at dusk
## and night, which is the whole point of a marquee.
##
## NOT IN _lights, DELIBERATELY. Strip.light_count() answers how many LAMP POSTS are standing
## on the ring, the strip gate asserts it is LIGHT_COUNT minus the one skipped clear of the
## Palace, and a bulb rail counted among them would break that check for a reason that has
## nothing to do with lamp posts.
const MARQUEE_BULBS := 10
const MARQUEE_BULB_RADIUS := 0.055

## One soft wash on the board's own face. shadow_enabled off for the reason this file already
## gives about its lamp ring: a light out in the open has nothing to leak through, and a
## shadow map on it is a cost with no picture attached.
const MARQUEE_WASH_ENERGY := 2.4
const MARQUEE_WASH_ANGLE := 38.0
const MARQUEE_WASH_RANGE := 6.0
```

and, at the end of `_marquee()` after the two label calls:

```gdscript
	_marquee_bulbs()
	_marquee_wash()
```

with the two builders:

```gdscript
func marquee_bulb_count() -> int:
	return MARQUEE_BULBS


## Ten emissive spheres spaced round the trim's perimeter, built as one MultiMesh so the whole
## rail is one draw call.
func _marquee_bulbs() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = MARQUEE_BULB_RADIUS
	sphere.height = MARQUEE_BULB_RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MARQUEE_TRIM_COLOR
	mat.emission_enabled = true
	mat.emission = MARQUEE_TRIM_COLOR
	mat.emission_energy_multiplier = 2.2
	sphere.material = mat

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = sphere
	multi.instance_count = MARQUEE_BULBS

	var half := Vector2(_marquee_size.x * 0.5 + MARQUEE_TRIM * 0.5,
		_marquee_size.y * 0.5 + MARQUEE_TRIM * 0.5)
	var right := Vector3(-_marquee_facing.z, 0.0, _marquee_facing.x)
	for i in MARQUEE_BULBS:
		# Round the rim: five across the top and five across the bottom, which is the shape a
		# marquee's bulb rail actually has.
		var across: float = -1.0 + 2.0 * (float(i % 5) / 4.0)
		var up: float = 1.0 if i < 5 else -1.0
		var at: Vector3 = _marquee_centre + right * (half.x * across) \
			+ Vector3(0.0, half.y * up, 0.0) + _marquee_facing * 0.06
		multi.set_instance_transform(i, Transform3D(Basis(), at))

	var node := MultiMeshInstance3D.new()
	node.name = "MarqueeBulbs"
	node.multimesh = multi
	add_child(node)


func _marquee_wash() -> void:
	var light := SpotLight3D.new()
	light.name = "MarqueeWash"
	light.light_color = LAMP_COLOR
	light.light_energy = MARQUEE_WASH_ENERGY
	light.spot_range = MARQUEE_WASH_RANGE
	light.spot_angle = MARQUEE_WASH_ANGLE
	light.shadow_enabled = false
	add_child(light)
	light.global_position = _marquee_centre + _marquee_facing * 2.2 + Vector3(0.0, 1.1, 0.0)
	light.look_at(_marquee_centre, Vector3.UP)
```

Then add one test to `game/test/test_strip.gd`:

```gdscript
## THE BULB RAIL IS NOT A LAMP POST. light_count() answers how many lamp posts are standing on
## the ring; this file already pins that at LIGHT_COUNT minus the one skipped clear of the
## Palace, and a bulb rail counted among them would break that check for a reason that has
## nothing to do with lamp posts.
func test_the_marquee_bulbs_and_wash_are_not_counted_among_the_lamp_posts() -> void:
	var strip: Strip = _built_strip()
	assert_not_null(strip.get_node_or_null(^"MarqueeBulbs"))
	assert_not_null(strip.get_node_or_null(^"MarqueeWash"))
	assert_eq(strip.marquee_bulb_count(), StripScript.MARQUEE_BULBS)
	# _built_strip() calls no avoid_footprint(), so all ten ring positions stand: the claim
	# here is only that ten bulbs did not become twenty lamps. The shipped Palace's own
	# "LIGHT_COUNT minus one" case is pinned by this file's existing avoidance tests, which
	# are untouched.
	assert_eq(strip.light_count(), StripScript.LIGHT_COUNT,
		"a bulb rail is not a lamp post and must not be counted as one")
```

`_built_strip()` is the file's own existing helper, which builds a `Strip` with a region and mounts the marquee; nothing new is needed to reach the bulbs.

- [ ] **Step 6: Replace the six nameplates with colour**

In `game/world/race_runner.gd`: delete `_ensure_plate()`, the `_plate` var, `NAMEPLATE_HEIGHT`, `NAMEPLATE_SIZE`, and the two `_ensure_plate()` / `_plate.text = display` lines at the top of `dress()`. Add the preloads and constants:

```gdscript
const PaintScript := preload("res://ui/casino_paint.gd")
const RaceCardScript := preload("res://systems/race_card.gd")

## THE SIX NAMES ARE GONE AND THEIR INFORMATION IS IN GEOMETRY. They existed for a real
## reason, stated here before: "so the player can tell six recoloured ponies apart from the
## rail". Six billboarded names bobbing over six galloping ponies is also the most Roblox
## looking thing in a 3D scene, and the two questions they answered ("which one is which" and
## "which one is mine") are both better answered by colour.
##
## ONE RAINBOW, THREE PLACES. CasinoPaint.BAND_COLORS is the wheel's six bands, the six race
## lanes and the slot machine's RAINBOW symbol. The preload is CONSTANT ONLY and one
## directional: game/world/ reads the palette, and nothing under game/ui/ has ever read
## anything under game/world/.
const SADDLECLOTH_SIZE := Vector3(0.62, 0.02, 0.52)
const SADDLECLOTH_HEIGHT := 1.02

## A gold chevron over the pony the player has money on, and over nobody else. Geometry, not
## text, bobbing on a sine so it reads at a distance without turning to face the camera.
const CHEVRON_HEIGHT := 2.4
const CHEVRON_BOB := 0.12
const CHEVRON_PERIOD := 1.6
const CHEVRON_SIZE := 0.28

var _lane := -1
var _chevron: MeshInstance3D = null
```

Change `dress()`'s signature and add the two builders at the end of it:

```gdscript
## `lane` is the lane this runner is standing in, or -1 for a runner not on the card (a
## gallery, a unit test). A lane gives her a saddlecloth in that lane's colour; RaceCard's own
## PLAYER_LANE also gets the chevron, because that is the only lane a player's bet can be on.
func dress(data: PonyData, triple: Dictionary, display: String, lane := -1) -> bool:
	_runner_name = display
	_lane = lane
	...
	# at the very end, after rest():
	_dress_lane()
	return true


func lane() -> int:
	return _lane


func _dress_lane() -> void:
	if _lane < 0 or _lane >= PaintScript.BAND_COLORS.size():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PaintScript.BAND_COLORS[_lane]
	mat.roughness = 0.8
	var box := BoxMesh.new()
	box.size = SADDLECLOTH_SIZE
	box.material = mat
	var cloth := MeshInstance3D.new()
	cloth.name = "Saddlecloth"
	cloth.mesh = box
	cloth.position = Vector3(0.0, SADDLECLOTH_HEIGHT, 0.0)
	add_child(cloth)
	if _lane != RaceCardScript.PLAYER_LANE:
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = CHEVRON_SIZE
	cone.height = CHEVRON_SIZE * 1.4
	var gold := StandardMaterial3D.new()
	gold.albedo_color = PaintScript.GOLD
	gold.emission_enabled = true
	gold.emission = PaintScript.GOLD
	gold.emission_energy_multiplier = 1.4
	cone.material = gold
	_chevron = MeshInstance3D.new()
	_chevron.name = "Chevron"
	_chevron.mesh = cone
	# Point down at her, which is the whole message: this one is yours.
	_chevron.rotation.z = PI
	_chevron.position = Vector3(0.0, CHEVRON_HEIGHT, 0.0)
	add_child(_chevron)


func _process(_delta: float) -> void:
	if _chevron == null or not is_instance_valid(_chevron):
		return
	_chevron.position.y = CHEVRON_HEIGHT \
		+ sin(Time.get_ticks_msec() / 1000.0 * TAU / CHEVRON_PERIOD) * CHEVRON_BOB
```

In `game/world/race_track.gd`'s `dress()`, pass the lane:

```gdscript
		if body.dress(data, entry["stock"] as Dictionary, String(entry["name"]), lane):
```

(use whatever the loop's lane variable is named; if the loop is `for lane in LANES` the name is already there).

And add the six coloured gate posts, called from `build()` after `_wire()`:

```gdscript
## SIX STARTING POSTS, ONE PER LANE, EACH IN ITS LANE'S COLOUR. The colour on the pony matches
## the colour on the gate she left and the colour on her card in the form guide, which is the
## whole of what the six removed nameplates were carrying. See game/world/race_runner.gd.
const GATE_POST_SIZE := Vector3(0.18, 1.6, 0.18)
const GATE_POST_OFFSET := 0.9


func _gate_posts() -> void:
	# One body for the six, the same shape _rail() and _wire() have: a StaticBody3D on the
	# PROPS layer with mask 0, so the player leans on a gate post rather than walking through
	# it and nothing detects anything with it.
	var body := StaticBody3D.new()
	body.name = "GatePosts"
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	add_child(body)
	for lane in LANES:
		var z: float = lane_z(lane)
		var x: float = START_X - GATE_POST_OFFSET
		_slab(body, "GatePost%d" % lane, GATE_POST_SIZE,
			Vector3(x, _y(x, z) + GATE_POST_SIZE.y * 0.5, z),
			PaintScript.BAND_COLORS[lane])
```

with `const PaintScript := preload("res://ui/casino_paint.gd")` at the top. `RaceTrack` is a `Node3D`, not a body; `_slab()`'s first argument is the `StaticBody3D` to parent to, which is why this builds its own exactly as `_rail()` and `_wire()` do.

- [ ] **Step 7: Update the two tests the removal touches**

In `game/test/test_race_runner.gd`, replace the model counting loop (the one that reads `if child is Node3D and not (child is Label3D)`):

```gdscript
	var models: int = 0
	for child in _runner.get_children():
		# The saddlecloth and the chevron are dressing this runner OWNS, not models it was
		# built from; excluded by name because the nameplate they replaced was excluded by
		# type and there is no type that separates a box from a pony.
		if String(child.name) in ["Saddlecloth", "Chevron"]:
			continue
		if child is Node3D:
			models += 1
	assert_eq(models, 1, "the old model is replaced, not stacked")
```

and add the kit's preload beside the file's existing ones, then one test:

```gdscript
const PaintScript := preload("res://ui/casino_paint.gd")


## THE SIX NAMES ARE GONE AND THE COLOUR IS THERE INSTEAD.
func test_a_lane_gets_a_saddlecloth_in_its_colour_and_no_nameplate() -> void:
	var data: PonyData = _stock_data()
	if data == null or not ResourceLoader.exists(data.model_path):
		pass_test("no converted assets on this machine; nothing to dress")
		return
	_runner.dress(data, {"coat": 0, "mane": 0, "eyes": 0}, "Third", 3)
	assert_eq(_runner.lane(), 3)
	var cloth := _runner.get_node_or_null(^"Saddlecloth") as MeshInstance3D
	assert_not_null(cloth)
	var mat := (cloth.mesh as BoxMesh).material as StandardMaterial3D
	assert_eq(mat.albedo_color, PaintScript.BAND_COLORS[3])
	assert_null(_runner.get_node_or_null(^"Nameplate"),
		"the last billboarded text in the game is gone")
	assert_null(_runner.get_node_or_null(^"Chevron"),
		"only the player's own lane gets a chevron")
```

- [ ] **Step 8: Retarget the casino gate's sign block**

In `game/scenes/test/casino_test.gd`, replace the whole block from `var lobby_sign := ranch.get_node_or_null(^"Buildings/Palace/Sign") as Label3D` down to the `_set_check("nothing on the sign carries a dash", sign_clean)` line with:

```gdscript
	# THE PUBLISHED EDGES MOVED FROM A LABEL IN THE AIR TO A PAGE INSIDE THE BUILDING, and this
	# check moved with them. It is strictly better than the one it replaces: it now asserts the
	# surface a PLAYER ACTUALLY READS rather than a node that happened to hold a string, and it
	# reads it through CasinoMenu.drawn_lines(), which is the same model the no dash sweeps and
	# test_casino_menu.gd walk.
	var lobby_board := ranch.get_node_or_null(^"Buildings/Palace/LobbySign") as Node3D
	_set_check("the lobby's board is standing beside the door", lobby_board != null)
	var board_clean := true
	if lobby_board != null:
		for label in lobby_board.find_children("*", "Label3D", true, false):
			var line: Label3D = label
			if line.text.contains("--") or line.text.contains("—"):
				board_clean = false
			if line.width <= 0.0:
				board_clean = false
				push_error("casino: %s is not fitted to its board" % line.name)
	_set_check("both lines on the board are fitted and carry no dash", board_clean)

	var rules_menu: CanvasLayer = ranch.get_casino_menu()
	var rules_lines: Array[String] = []
	if rules_menu != null:
		rules_menu.call("set_tab", CasinoMenuScript.Tab.RULES)
		rules_lines = rules_menu.call("drawn_lines")
	var rules_text: String = "\n".join(rules_lines)
	var publishes_everything := true
	for pair in [["Slots", SlotsScript.house_edge()], ["The Wheel", WheelScript.house_edge()],
			["Blackjack", BlackjackScript.house_edge()], ["Racing", RaceCardScript.TAKEOUT]]:
		if not rules_text.contains(CasinoSignScript.edge_line(String(pair[0]),
				float(pair[1]))):
			publishes_everything = false
			push_error("casino: the house rules page does not publish %s" % pair[0])
	print("CASINO sign lines=%d" % rules_lines.size())
	_set_check("the house rules page publishes every game's real house edge",
		publishes_everything)
	var sign_clean := true
	for line: String in rules_lines:
		if line.contains("--") or line.contains("—"):
			sign_clean = false
	_set_check("nothing on the house rules page carries a dash", sign_clean)
```

`print("CASINO sign lines=%d")` keeps printing, counting the rules page's lines instead of the old label's.

- [ ] **Step 9: Import, run everything**

```bash
tools/bin/godot --headless --path game --import
for f in test_lobby_sign test_race_runner test_strip; do
  tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
    -gtest=res://test/$f.gd -gexit 2>&1 | tail -5
done
bash tools/run_tests.sh 2>&1 | tail -12
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn 2>&1 \
  | grep -E "CASINO sign|CASINO_OK|CASINO_FAILED"
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 \
  | grep -E "RANCH prop Palace|RANCH_OK|RANCH_FAILED|FAILED check"
```
Expected: everything green, `CASINO sign lines=11`, `RANCH_OK ponies=49 props=110 assets=present`.

**Read the `RANCH prop Palace` line specifically.** Its `seat_error` must be within `SEATING_TOLERANCE` of what it was before this task. If it moved, `LobbySign` has a mesh hanging below the Palace's local `y = 0`: raise `LOBBY_SIGN_BASE`, do not widen the tolerance, because the tolerance is what the check means.

- [ ] **Step 10: Sweep for the copy rule**

```bash
git diff master...HEAD --name-only | grep -E '\.(gd|md|tscn|gdshader)$' | while read -r f; do
  [ -f "$f" ] || continue
  git diff master...HEAD -- "$f" | grep -n '^+' | grep -E '\-\-|—' \
    | grep -v '^\+.*# ---' | grep -v '^\+.*--headless' | grep -v '^\+.*--audio-driver' \
    | grep -v '^\+.*--path' | grep -v '^\+.*--import' | grep -v '^\+.*--screenshot-dir' \
    | grep -v '^\+.*--phase' | grep -v '^\+.*--weather' | grep -v '^\+.*-gtest' \
    | grep -v '^\+.*u2014' \
    | sed "s|^|$f:|"
done
```
Expected: no output.

- [ ] **Step 11: Commit**

```bash
printf 'feat: the floating text leaves the world\n\nAll four Label3D sites decided.\n\nThe Palace sign is gone. It was eleven lines of published house edges hanging\nunbacked in the air at a cap height of about 0.15 metres per line, which is\nwhat the owner saw and called very poor. A board with a trim and two fitted\nlines stands beside the door instead, sized off the Palace own width the way\nstrip.gd sizes the marquee, and the eleven lines are the lobby House rules\npage. The promise is kept and arguably strengthened: casino_sign.gd is\nuntouched and still asks each game for its own number, and the edges went from\na distant paragraph outside a door to a page the lobby picker points at. The\ngate moved with them and now asserts the surface a player actually reads.\n\nThe marquee stays and gets lit. Ten bulbs round the trim as one MultiMesh and\none shadowless wash on the board face. They are not lamp posts and are not in\n_lights, so light_count() still answers nine.\n\nThe six nameplates are gone. A saddlecloth in the lane colour on each runner, a\ncoloured starting post per lane so the colour on the pony matches the colour on\nthe gate she left, and a gold chevron over lane zero, which is the only lane a\nplayer bet can be on. One rainbow: the wheel bands, the six lanes and the slots\nRAINBOW symbol are the same six colours.\n\nAfter this the world contains exactly two pieces of 3D text, both on the\nPalace, both on physical boards, both fitted to their board width.\n\nThe census does not move: Sign was a child of Buildings/Palace and so is\nLobbySign, the bulbs hang off the marquee assembly, and the gate posts belong\nto the track.\n' > /tmp/polish-task8.txt
git add game/world/lobby_sign.gd game/world/lobby_sign.gd.uid game/world/ranch.gd \
  game/world/ranch.tscn game/world/strip.gd game/world/race_runner.gd \
  game/world/race_track.gd game/scenes/test/casino_test.gd \
  game/test/test_lobby_sign.gd game/test/test_lobby_sign.gd.uid \
  game/test/test_race_runner.gd game/test/test_strip.gd
git commit -F /tmp/polish-task8.txt
```

---

### Task 9: The look pass, the renders, the docs and the floor

**Files:**
- Create: `game/world/terrain.gdshader`
- Modify: `game/world/terrain.gd`, `game/world/ranch.tscn` (the `Env` sub resource, `$Sun`, `Buildings/Palace`), `game/world/building.gd`, `game/world/ranch.gd` (four screenshots), `game/test/test_terrain.gd`, `tools/run_tests.sh`, `docs/testing.md`
- Test: `game/test/test_terrain.gd`, the whole suite, every gate, and a render pass

**Interfaces:**
- Consumes: `Terrain.GRASS_LOW`, `Terrain.GRASS_HIGH`, `Terrain.grass_at()`, `Terrain.height_at()` (all unchanged); `Building`'s `wall_color`, `roof_color`, `trim_color`; `ranch.gd`'s `_frame_on(at: Vector2, offset: Vector3, look_height: float, shot_name: String)` and `_capture(shot_name)`, both added by the dressing slice.
- Produces: `game/world/terrain.gdshader`; `Terrain.DIRT := Color(0.36, 0.28, 0.19)`; `Building._material(colour, roughness, metallic)`; `Building.trim_metallic` (`@export`, default 0.0); four new screenshots (`18_palace_lobby_sign`, `19_marquee_at_dusk`, `20_ground_slope_and_dirt`, `21_race_lane_colours`); `MIN_TESTS` at the suite's reported number.

**Nothing here touches `sky_rig.gd`.** Every Environment field added below is one `SkyRig._write_to_scene()` does not write: it drives `ambient_light_energy`, `ambient_light_color`, `fog_density`, `fog_light_color` and the four sky colours, and this task adds tonemapping, adjustment, glow, SSAO and `fog_aerial_perspective`. `game/test/test_sky_rig.gd`'s orderings are untouched, and so are `PHASE_LIGHT_ENERGY`, `PHASE_AMBIENT_ENERGY` and `NIGHT_WEATHER_FLOOR`.

- [ ] **Step 1: Write the failing terrain test**

Append to `game/test/test_terrain.gd`:

```gdscript
## THE GROUND IS A SHADER NOW, AND THE ONE FAILURE MODE THAT MATTERS IS INVISIBLE OTHERWISE.
## Godot compiles shaders lazily and the headless renderer never rasterises, so a
## ShaderMaterial on a mesh in a headless run is inert: a shader that fails to PARSE prints an
## error at load and every gate that only checks RANCH_OK still goes green. So the mesh is
## asked what material it is actually wearing.
func test_the_ground_wears_a_shader_with_code_in_it() -> void:
	var terrain: Terrain = _bare_terrain()
	var mesh := terrain.get_node(^"Mesh") as MeshInstance3D
	var mat := mesh.mesh.surface_get_material(0) as ShaderMaterial
	assert_not_null(mat, "surface 0 is a ShaderMaterial")
	assert_not_null(mat.shader, "the ShaderMaterial carries a shader")
	assert_gt(mat.shader.code.length(), 0, "the shader has code in it")


## THE sRGB TRAP, PINNED BY NAME. vertex_color_is_srgb is a StandardMaterial3D flag with NO
## shader equivalent: the shader has to do the conversion itself or Godot treats the vertex
## colours as already linear and the ground comes out roughly twice as bright as authored.
## terrain.gd's own comment records what that looked like the first time: "a pale mint sheet,
## not grass". This is the one trap in the whole slice most likely to be missed, so it is
## asserted by name rather than left to whoever looks at the next render.
func test_the_shader_converts_its_vertex_colour_out_of_srgb() -> void:
	var terrain: Terrain = _bare_terrain()
	var mesh := terrain.get_node(^"Mesh") as MeshInstance3D
	var mat := mesh.mesh.surface_get_material(0) as ShaderMaterial
	assert_true(mat.shader.code.contains("srgb_to_linear"),
		"drop this and the ground renders as a pale mint sheet")
	assert_true(mat.shader.code.contains("COLOR"),
		"grass_at() and the region palettes stay the single authority on ground colour")


## THE HEIGHTFIELD IS UNTOUCHED. Moving CELL, HALF, FLAT_RADIUS or height_at() would move the
## mesh, the collider, the props, the pens, the spawner and every gate that reads them, and
## the look pass has no business anywhere near any of that.
func test_the_heightfield_is_exactly_what_it_was() -> void:
	assert_eq(TerrainScript.HALF, 110.0)
	assert_eq(TerrainScript.CELL, 2.0)
	assert_eq(TerrainScript.FLAT_RADIUS, 30.0)
	assert_eq(TerrainScript.GRASS_LOW, Color(0.239, 0.408, 0.196))
	assert_eq(TerrainScript.GRASS_HIGH, Color(0.443, 0.541, 0.271))
```

`^"Mesh"` is the right path: `terrain.gd` names its `MeshInstance3D` with `_mesh_instance.name = "Mesh"`.

- [ ] **Step 2: Run it to verify it fails**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_terrain.gd -gexit 2>&1 | tail -8
```
Expected: two failures, `surface 0 is a ShaderMaterial` (it is a `StandardMaterial3D`).

- [ ] **Step 3: Write the shader**

Create `game/world/terrain.gdshader`:

```glsl
shader_type spatial;
render_mode cull_back, diffuse_burley;

// THE GROUND. The mesh, the vertex colours, grass_at(), height_at(), the regions and the
// collider are all untouched by this file: game/world/terrain.gd stays the single authority
// on what colour the ground is at a point, and this adds the high frequency break up, the
// slope treatment and the ridge lift that a smooth two colour gradient cannot have.
//
// WHY THE GROUND NEEDED THIS. The shipped terrain is a smooth lerp between two greens at 2 m
// resolution, which is subtly WORSE than one flat colour for the "roblox" read, because it is
// smooth and featureless at every scale the player actually sees. No texture, no break up, no
// slope treatment, no dirt anywhere.
//
// SPECULAR IS KILLED IN THE FRAGMENT AND NOT BY A RENDER MODE, deliberately: SPECULAR = 0.0
// is a fragment output that has meant the same thing in every Godot 4 release, and it says
// the same thing the StandardMaterial3D's specular_mode = SPECULAR_DISABLED said.

// Terrain.GRASS_HIGH and Terrain.DIRT, pushed in by terrain.gd so the two colours a human
// picked by eye live in ONE place. Plain uniforms and not source_color hints: the conversion
// out of sRGB happens once, below, for the vertex colour and for these, through the same
// function, so there is exactly one code path and no question about who converted what.
uniform vec4 grass_high = vec4(0.443, 0.541, 0.271, 1.0);
uniform vec4 dirt_color = vec4(0.36, 0.28, 0.19, 1.0);

uniform float fine_metres = 0.9;
uniform float coarse_metres = 4.5;
uniform float fine_amount = 0.055;
uniform float coarse_amount = 0.030;
uniform float slope_low = 0.30;
uniform float slope_high = 0.68;
uniform float ridge_lift = 0.06;
uniform float ridge_low = -6.0;
uniform float ridge_high = 6.0;
uniform float fade_near = 30.0;
uniform float fade_far = 70.0;
uniform float ground_roughness = 0.95;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

// NOT OPTIONAL, AND THIS IS THE ONE TRAP IN THE WHOLE SLICE. Godot renders in linear space
// and treats vertex colours as ALREADY linear unless told otherwise. StandardMaterial3D said
// so with vertex_color_is_srgb = true; a ShaderMaterial has NO equivalent flag, so the shader
// has to do it. terrain.gd's own comment records what dropping it looks like: "the first
// render of this terrain was a pale mint sheet, not grass". Every colour a human picks by eye
// is an sRGB colour, so this is what makes GRASS_LOW and GRASS_HIGH mean what they say.
// This is Godot's own conversion, cut and dried.
vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)),
		c * (1.0 / 12.92),
		lessThan(c, vec3(0.04045)));
}

// A 2D integer hash plus smoothstep interpolation: twelve lines of value noise and no
// texture, which is what keeps this slice assetless.
float hash21(vec2 p) {
	vec2 q = fract(p * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	// World space, taken here rather than in the fragment: NORMAL is VIEW space in a Godot
	// fragment shader, and a slope mask built on a view space normal changes as the camera
	// turns, which would make the hillsides slide around under a moving player.
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = srgb_to_linear(COLOR.rgb);
	vec3 high = srgb_to_linear(grass_high.rgb);
	vec3 dirt = srgb_to_linear(dirt_color.rgb);

	// THE FINE OCTAVE FADES OUT WITH DISTANCE. VERTEX in a fragment shader is the view space
	// position, so its length is the view distance. Without this fade the 0.9 m noise buys
	// aliasing instead of detail: it shimmers in the middle distance under a moving camera,
	// which is worse than the flat gradient it replaced.
	float fine_fade = 1.0 - smoothstep(fade_near, fade_far, length(VERTEX));
	float fine = (value_noise(v_world_pos.xz / fine_metres) - 0.5) * 2.0;
	float coarse = value_noise(v_world_pos.xz / coarse_metres);

	base *= 1.0 + fine * fine_amount * fine_fade;
	base = mix(base, high, coarse * coarse_amount);

	// A SLOPE YOU CAN SEE IS A SLOPE YOU CAN PLAN A WALK AROUND. Hillsides and the lake basin
	// walls become earth, which is both more believable and free relief reading.
	float slope = 1.0 - clamp(v_world_normal.y, 0.0, 1.0);
	float earth = smoothstep(slope_low, slope_high, slope);
	base = mix(base, dirt, earth);

	// The ridge lift is small on purpose: grass_at() already does some of this per vertex, and
	// this version is continuous where that one is stepped at 2 m.
	float ridge = smoothstep(ridge_low, ridge_high, v_world_pos.y);
	base = mix(base, high, ridge * ridge_lift * (1.0 - earth));

	ALBEDO = base;
	ROUGHNESS = ground_roughness;
	SPECULAR = 0.0;
}
```

- [ ] **Step 4: Wear it**

In `game/world/terrain.gd`, add the preload and the one new colour beside `GRASS_HIGH`:

```gdscript
const GroundShader := preload("res://world/terrain.gdshader")

## What a hillside is made of. Turned earth, and deliberately not any green: the point of the
## slope mask is that a slope reads as a different SURFACE rather than as darker grass.
const DIRT := Color(0.36, 0.28, 0.19)
```

and replace the material block at the end of `_build_mesh()`:

```gdscript
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.surface_set_material(0, mat)
```

with:

```gdscript
	# THE GROUND WEARS A SHADER, AND THE VERTEX COLOURS STILL DECIDE ITS COLOUR. grass_at() and
	# every region palette are unchanged and are still the single authority on what colour the
	# ground is at a point; world/terrain.gdshader adds the break up, the slope mask and the
	# ridge lift on top of what this mesh already carries.
	#
	# vertex_color_is_srgb HAS NO SHADER EQUIVALENT, so the conversion moved INTO the shader.
	# See its srgb_to_linear() and the comment above it; game/test/test_terrain.gd asserts the
	# function is in there by name, because dropping it renders a pale mint sheet and nothing
	# headless can see that.
	var mat := ShaderMaterial.new()
	mat.shader = GroundShader
	mat.set_shader_parameter(&"grass_high", GRASS_HIGH)
	mat.set_shader_parameter(&"dirt_color", DIRT)
	mesh.surface_set_material(0, mat)
```

The collider is unaffected: `create_trimesh_shape()` is taken from the mesh before any material matters.

- [ ] **Step 5: Run the terrain tests**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_terrain.gd -gexit 2>&1 | tail -8
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_ranch_world.gd -gexit 2>&1 | tail -6
```
Expected: both green. Watch stderr for any `SHADER ERROR`: a parse failure prints there and nowhere else.

- [ ] **Step 6: Grade, glow and shadow the scene**

In `game/world/ranch.tscn`, extend the `[sub_resource type="Environment" id="Env"]` block with everything below. All of it is engine default today.

```
tonemap_white = 1.8
ssao_enabled = true
ssao_radius = 0.9
ssao_intensity = 1.35
ssao_power = 1.5
ssao_detail = 0.5
ssao_horizon = 0.06
ssao_sharpness = 0.98
ssao_light_affect = 0.15
ssao_ao_channel_affect = 0.0
glow_enabled = true
glow_levels/2 = 0.0
glow_levels/3 = 0.55
glow_levels/4 = 0.85
glow_levels/5 = 0.45
glow_intensity = 0.55
glow_strength = 1.0
glow_bloom = 0.03
glow_blend_mode = 0
glow_hdr_threshold = 1.05
glow_hdr_scale = 2.0
fog_aerial_perspective = 0.35
adjustment_enabled = true
adjustment_brightness = 1.0
adjustment_contrast = 1.05
adjustment_saturation = 1.14
```

`tonemap_white` replaces the existing `tonemap_white = 3.0` line rather than being added beside it, and `tonemap_mode = 3` (ACES) STAYS. AgX is the fashionable answer and it is the wrong one here: it deliberately desaturates as values rise, which is correct for photographic realism and directly against a bright saturated Slime Rancher palette. At 3.0 nothing on this map reached the curve's shoulder, so the mapper was doing nothing but a slight midtone desaturation; at 1.8 the sky, the gold trim and the lamp cores actually roll off, which is what gives a scene the feeling of light rather than the feeling of paint.

Then the `[node name="Sun" type="DirectionalLight3D" parent="."]` block:

```
shadow_bias = 0.02
shadow_normal_bias = 1.2
shadow_blur = 1.1
light_angular_distance = 0.9
directional_shadow_max_distance = 85.0
directional_shadow_split_1 = 0.06
directional_shadow_split_2 = 0.17
directional_shadow_split_3 = 0.42
directional_shadow_blend_splits = true
directional_shadow_fade_start = 0.92
```

`shadow_bias = 0.05` and `directional_shadow_max_distance = 240.0` are REPLACED; the rest are added.

**85 m rather than 240 m is the change that matters.** The camera rig pulls out to `SPRING_MAX` 6.5 m behind the player and nothing beyond about 80 m is legible as a shadow anyway, so cutting the range by nearly three times gives every cascade nearly three times the texel density for free. `blend_splits` on removes the hard cascade seam that appears once the splits are tight, and `light_angular_distance` 0.9 degrees is a real penumbra: it does more to separate a lit 3D scene from a 3D scene with shadows in it than any other single property, and it is what `0.0` (perfectly hard edges everywhere) was costing.

**SSIL, SDFGI, SSR and volumetric fog stay off.** SSIL is roughly the cost of SSAO again and has almost nothing to bounce on a world of flat single colour boxes; SDFGI needs a static world this does not have and the scene is already lit 35 per cent from sky ambient; `SkyRig`'s density fog already carries the weather. That is a YAGNI, recorded here so it stays one.

- [ ] **Step 7: Let the Palace's gold catch the light**

In `game/world/building.gd`, replace `_material()`:

```gdscript
## THREE SURFACES, THREE ROUGHNESSES, and the whole difference is one exported float.
##
## Every surface of every building shipped at roughness 0.9 with specular disabled, so nothing
## in the world had a highlight and the Palace's gold trim could not glint. A roof slightly
## less rough than its wall reads as a different material without a texture, which is the
## cheapest material variation there is.
##
## trim_metallic IS OPT IN AND DEFAULTS TO ZERO, so every building except the one that asks
## renders byte for byte as it does today. Only Buildings/Palace asks (ranch.tscn sets 0.45),
## and the result is that the casino's gold catches the sun and the marquee bulbs and nothing
## else in the game changes at all.
func _material(colour: Color, surface_roughness := 0.88, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = surface_roughness
	mat.metallic = metallic
	if metallic <= 0.0:
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat
```

and the three call sites in `build()`:

```gdscript
	var wall_mat := _material(wall_color, WALL_ROUGHNESS)
	var roof_mat := _material(roof_color, ROOF_ROUGHNESS)
	var trim_mat := _material(trim_color, TRIM_ROUGHNESS, trim_metallic)
```

The gable at the other call site keeps the wall's numbers: `_material(wall_color, WALL_ROUGHNESS)`.

Add the export and three constants:

```gdscript
## How metallic this building's TRIM is. Zero for every building on the map except the Palace,
## which ranch.tscn sets to 0.45. A lot of "this building is special" for one exported float.
@export_range(0.0, 1.0) var trim_metallic := 0.0

const WALL_ROUGHNESS := 0.88
const ROOF_ROUGHNESS := 0.70
const TRIM_ROUGHNESS := 0.45
```

and in `game/world/ranch.tscn`, on the `Buildings/Palace` node, beside its `trim_color` line:

```
trim_metallic = 0.45
```

`game/world/pen.gd._material_static()` (0.92), `game/world/race_track.gd._slab()` (0.85) and `game/world/strip.gd._flat_material()` (0.85) are LEFT ALONE, and `game/world/props.gd` belongs to the dressing slice and is not touched.

- [ ] **Step 8: Add the four screenshots**

At the end of `_capture_all()` in `game/world/ranch.gd`, after `await _capture_props()`:

```gdscript
	await _capture_look()
```

and next to `_capture_props()`:

```gdscript
## 18 to 21: THE FOUR THINGS THE LOOK PASS CHANGED THAT NO ASSERTION CAN JUDGE.
##
## Screenshot runs only, like everything below the headless quit. A gate can say the terrain
## wears a ShaderMaterial and that the shader has srgb_to_linear() in it; it cannot say whether
## the ground reads as grass, whether a penumbra at 0.9 degrees is soft or mushy, whether the
## Palace's gold glints or smears, or whether a lane colour on a saddlecloth is legible from
## the rail. These are what a person looks at.
func _capture_look() -> void:
	await _frame_on(Vector2(-10.0, 61.6), Vector3(0.0, 3.0, -11.0), 2.2,
		"18_palace_lobby_sign")
	await _frame_on(Vector2(-10.0, 61.6), Vector3(0.0, 6.0, -22.0), 4.0,
		"19_marquee_and_gold_trim")
	await _frame_on(Vector2(58.0, -46.0), Vector3(-16.0, 12.0, -18.0), 2.0,
		"20_ground_slope_and_dirt")
	await _frame_on(Vector2(0.0, 80.0), Vector3(-24.0, 6.0, -14.0), 1.6,
		"21_race_lane_colours")
```

`_frame_on()` is the dressing slice's helper: `_frame_on(at: Vector2, offset: Vector3, look_height: float, shot_name: String)`, which stands the capture camera `offset` from `at`, `offset.y` above the ground under the eye, aiming `look_height` above the ground under the target. Shot 20 is aimed at the lake basin wall, which is the steepest ground on the map and therefore where the slope mask has the most to show.

- [ ] **Step 9: Run every gate and read every count**

```bash
bash tools/run_tests.sh 2>&1 | tail -20
for scene in market_test region_test world_test collection_test ledger_test depot_test \
             creation_test casino_test; do
  echo "--- $scene"
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" 2>&1 \
    | grep -E "_OK|_FAILED"
  echo "exit ${PIPESTATUS[0]}"
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -4
```

Write down, verbatim, the number each gate prints. Nothing in this slice touches a market, a ledger, a region, a depot or a collection, so those counts are expected to be unchanged; the two that move are `CASINO_OK checks=<n>` (three new checks in Tasks 3 and 7, two moved in Task 8) and the suite's own `Tests` line. **`RANCH_OK ponies=49 props=110 assets=present` must be unchanged**, which is the whole census argument in this plan made concrete.

- [ ] **Step 10: Take the renders and look at them**

```bash
DAY="${TMPDIR:-/tmp}/polish-shots-day"
DUSK="${TMPDIR:-/tmp}/polish-shots-dusk"
rm -rf "$DAY" "$DUSK" && mkdir -p "$DAY" "$DUSK"
xvfb-run -a tools/bin/godot --audio-driver Dummy --path game world/ranch.tscn \
  -- "--screenshot-dir=$DAY" --phase=day --weather=clear 2>&1 \
  | grep -E "SCREENSHOT_SAVED|RANCH_OK|RANCH_FAILED"
xvfb-run -a tools/bin/godot --audio-driver Dummy --path game world/ranch.tscn \
  -- "--screenshot-dir=$DUSK" --phase=dusk --weather=clear 2>&1 \
  | grep -E "SCREENSHOT_SAVED|RANCH_OK|RANCH_FAILED"
ls "$DAY" "$DUSK"
```
Expected: every existing shot plus `18_palace_lobby_sign.png`, `19_marquee_and_gold_trim.png`, `20_ground_slope_and_dirt.png` and `21_race_lane_colours.png` in each directory. **Not `--headless`:** a headless run rasterises nothing and would write four black frames.

Then look at all eight, because this is the half of the slice no gate covers. What each one is asked:

| Shot | The question |
|---|---|
| `18_palace_lobby_sign` (day) | Does the board read as a sign on a building, at a size somebody walking up can read? Is it beside the door rather than in it, and is it clear of the door apron? |
| `19_marquee_and_gold_trim` (day) | Does the Palace's gold trim catch the sun now, or has `trim_metallic` made it look like plastic? Are the ten bulbs visible as bulbs at this distance? |
| `19_marquee_and_gold_trim` (dusk) | Do the bulbs and the marquee letters bloom, or smear? Is `glow_hdr_threshold` 1.05 high enough that ONLY the sign and the lamps are blooming and not every bright edge on the map? |
| `20_ground_slope_and_dirt` (day) | Does the basin wall read as earth and the flat as grass, with a believable transition, or as a green thing with a brown stripe painted on it? Is the fine noise visible up close and gone in the middle distance, or is it shimmering? |
| `20_ground_slope_and_dirt` (dusk) | Does the ground still read as grass at low sun, or has the noise turned into contouring? |
| `21_race_lane_colours` (day) | Can you tell six recoloured ponies apart from the rail by saddlecloth alone, which is the whole job the six nameplates used to do? Does the gold chevron pick out lane zero without being the loudest thing in the shot? |
| `18_palace_lobby_sign` (dusk) | Does the shadow penumbra at `light_angular_distance` 0.9 read as soft contact shadow, or as a blur? Look at the sign's own shadow on the wall. |
| Any shot, both phases | Is `adjustment_saturation` 1.14 cute or garish? This is the single cheapest change in the slice and the easiest one to overshoot; if it is garish, lower it here rather than compensating elsewhere. |

- [ ] **Step 11: Raise the floor**

`MIN_TESTS` in `tools/run_tests.sh` stands at whatever the dressing slice raised it to. This plan adds roughly 45 tests across `test_casino_paint.gd`, `test_casino_stages.gd`, `test_lobby_sign.gd`, `test_menu_style.gd`, `test_slots_menu.gd`, `test_wheel_menu.gd`, `test_blackjack_menu.gd`, `test_casino_menu.gd`, `test_race_menu.gd`, `test_race_runner.gd`, `test_strip.gd` and `test_terrain.gd`. **Do not guess the total; read it off the suite's own `Tests` line.**

```bash
current=$(grep -oP 'MIN_TESTS="\$\{FILLY_MIN_TESTS:-\K[0-9]+' tools/run_tests.sh)
echo "floor stands at $current"
tests=$(bash tools/run_tests.sh 2>&1 | grep -oP '^Tests\s+\K[0-9]+' | tail -1)
echo "suite reports $tests"
sed -i "s/MIN_TESTS=\"\${FILLY_MIN_TESTS:-$current}\"/MIN_TESTS=\"\${FILLY_MIN_TESTS:-$tests}\"/" \
  tools/run_tests.sh
grep -n 'MIN_TESTS=' tools/run_tests.sh
```

Then prove the floor still bites:

```bash
FILLY_MIN_TESTS=99999 bash tools/run_tests.sh; echo "expected 1, got $?"
```

- [ ] **Step 12: Write the docs**

Three edits to `docs/testing.md`.

**a.** In the Files table, add four rows:

```
| `game/test/test_casino_paint.gd` | The casino's drawing kit as geometry: every glyph inside its box, and the sweep that keeps a random generator out of `game/ui/` |
| `game/test/test_casino_stages.gd` | The contract every drawn casino screen holds: a stage of the shared width, a printed line that is still in the model, and the focus following the cursor across every row of every tab |
| `game/test/test_lobby_sign.gd` | The board that replaced the eleven line label outside the Palace: fitted lines, nothing hanging below its own origin, no dash |
| `game/world/terrain.gdshader` | The ground: sRGB decode, two octaves of hash noise, a slope mask to dirt, a ridge lift and a distance fade |
```

**b.** In the section describing the casino gate, after the paragraph naming `CASINO_OK`, add:

```markdown
**The sign checks moved, and they are strictly better than the ones they replaced.**

`Buildings/Palace/Sign` was a `Label3D` holding eleven lines of published house
edges, and the gate asserted on its `.text`. The label is gone; a `LobbySign`
board with two fitted lines stands beside the door and the eleven lines are the
casino lobby's House rules page. So the gate now asserts:

* **"the lobby's board is standing beside the door"** and **"both lines on the
  board are fitted and carry no dash"**, which is what stops a sign quietly
  going back to being unbacked letters in the air.
* **"the house rules page publishes every game's real house edge"**, read off
  `CasinoMenu.drawn_lines()` on `Tab.RULES`. This is the surface a player
  actually reads, and it is the same model the no dash sweeps walk.

`CASINO sign lines=<n>` keeps printing and now counts the rules page's lines.
`CasinoSign.lines()` is untouched and still asks each game for its own number,
so the promise the sign was making is unchanged; only where it is kept moved.

**Two stage checks landed with the drawn screens.** `CASINO stage <menu>
size=(w, h) focus=(w, h) id=<id>` prints one line per table. These five screens
are `CanvasLayer` menus and can never appear in a screenshot, so their geometry
is the only judgement a gate can give them: every table reserves a stage of the
shared 1120 px width, and every one paints its focus ring somewhere real.
```

**c.** In the terrain section, add:

```markdown
**The ground wears a shader, and one assertion is doing all the work.**

Godot compiles shaders lazily and the headless renderer never rasterises, so a
`ShaderMaterial` on a mesh in a headless run is inert. The one real risk is a
shader that fails to PARSE: that prints an error at load and is invisible to a
gate checking only `RANCH_OK`. So `game/test/test_terrain.gd` asks the built
mesh what material it is actually wearing, that the shader is non null, that
its code is non empty, and that the code contains `srgb_to_linear` by name.

That last one is the trap. `vertex_color_is_srgb` is a `StandardMaterial3D`
flag with no shader equivalent; drop the conversion and Godot treats the vertex
colours as already linear, and the ground comes out roughly twice as bright as
authored. `terrain.gd`'s own comment records what that looked like the first
time: "a pale mint sheet, not grass".
```

- [ ] **Step 13: Final full run**

```bash
bash tools/run_tests.sh
for scene in market_test region_test world_test collection_test ledger_test depot_test \
             creation_test casino_test; do
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" \
    >/dev/null 2>&1
  echo "$scene exit $?"
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
bash tools/prove_atomic_save.sh
git diff master...HEAD --name-only | grep -E '\.(gd|gdshader|md|tscn|sh)$' | while read -r f; do
  [ -f "$f" ] || continue
  git diff master...HEAD -- "$f" | grep -n '^+' | grep -E '\-\-|—' \
    | grep -v '^\+.*# ---' | grep -v '^\+.*//' | grep -v '^\+.*--headless' \
    | grep -v '^\+.*--audio-driver' | grep -v '^\+.*--path' | grep -v '^\+.*--import' \
    | grep -v '^\+.*--screenshot-dir' | grep -v '^\+.*--phase' | grep -v '^\+.*--weather' \
    | grep -v '^\+.*-gtest' | grep -v '^\+.*FILLY_MIN_TESTS' \
    | sed "s|^|$f:|"
done
```
Expected: everything green, every gate exit 0, `RANCH_OK ponies=49 props=110 assets=present`, `ATOMIC_SAVE_PROOF_OK`, and no output at all from the dash sweep.

- [ ] **Step 14: Commit**

```bash
printf 'feat: the look pass, the renders, the docs and the floor\n\nThe ground is a shader. The mesh, the vertex colours, grass_at(), height_at(),\nthe regions and the collider are all untouched; world/terrain.gdshader adds two\noctaves of hash value noise so the ground stops being smooth at every scale, a\nslope mask that turns hillsides and the lake basin walls to earth, a small\ncontinuous ridge lift, and a distance fade on the fine octave so the noise buys\ndetail rather than shimmer. No texture, no splat map, no assets.\n\nThe sRGB conversion moved INTO the shader, because vertex_color_is_srgb is a\nStandardMaterial3D flag with no shader equivalent. Drop it and the ground\nrenders as a pale mint sheet, which terrain.gd s own comment records from the\nfirst time. test_terrain.gd asserts srgb_to_linear by name, because a shader\nthat fails to parse is invisible to a gate that only checks RANCH_OK.\n\nThe scene is graded, lit and shadowed. ACES stays and AgX is rejected: it\ndesaturates as values rise, which is right for photographic realism and\ndirectly against a bright saturated palette. tonemap_white drops from 3.0 to\n1.8 so the sky, the gold and the lamp cores actually roll off. The adjustment\nblock comes on at 1.14 saturation and 1.05 contrast. Glow comes on above a 1.05\nHDR threshold on levels three to five, so a lit sign at night blooms and\nnothing else does. Shadow distance falls from 240 metres to 85 over a 220 metre\nmap, which buys every cascade nearly three times the texel density for free,\nand light_angular_distance goes from 0 to 0.9 degrees, which is the first real\npenumbra this game has had. SSIL, SDFGI, SSR and volumetric fog stay off and\nthe reasons are written down.\n\nsky_rig.gd is untouched. Every field added here is one the rig does not drive.\n\nBuilding materials split three ways, and trim_metallic is an opt in float that\nonly the Palace sets. Every other building renders byte for byte as it did.\n\nFour renders, in day and at dusk, with the questions each one is asked written\nout, because none of the above can be judged by an assertion. MIN_TESTS raised\nto the suite s own reported count.\n' > /tmp/polish-task9.txt
git add game/world/terrain.gdshader game/world/terrain.gd game/world/ranch.tscn \
  game/world/building.gd game/world/ranch.gd game/test/test_terrain.gd \
  tools/run_tests.sh docs/testing.md
git commit -F /tmp/polish-task9.txt
```

---

## Self review

Run against the spec's four sections and its own slice shape, with fresh eyes.

**1. Spec coverage.**

| Spec section | Task | Where |
|---|---|---|
| A.1 the shared drawing kit | 1 | `game/ui/casino_paint.gd`: palette, seven primitives, the `*_points()` / `draw_*` split, every `Slots.Symbol`, all four suits, all six `CasinoMenu.Row` illustrations, both wallet icons, `card_pip_points()`. `test_casino_paint.gd` asserts geometry and sweeps `game/ui/` for a generator. |
| A.2 the stage | 3 | `Stage` in five `.tscn`, `paint()`, `printed_lines()`, `focus_rect()`, `focused_id()`, `stage_size()`, `animating()`, the `queue_redraw()` discipline, `test_table_caret.gd` rewritten onto the drawing. |
| A.3 how an outcome reaches the stage | 4, 5, 6 | One `has_method()` guarded `call()` beside each existing `show_result()` in `play_slots()`, `play_wheel()` and `play_blackjack()`. No arithmetic, no ordering and no safety moves. |
| A.4 slots | 4 | Cabinet, headboard with a nine bulb chase, three windows over the real `Slots.strip()`, payline, lever, drawn stakes, tweening chip counter, paytable panel. All seven spin beats with the spec's own timings. |
| A.5 the wheel | 5 | 25 annular sectors, six bands of four, the silver house pocket with no number, hub and spokes, the ratcheting pointer, both felts, the stake row, the rules plate. Five turns over 3.2 s on a cubic ease out. `WHEEL_FOOTER` deleted. |
| A.6 blackjack | 6 | Felt arc, shoe, drawn cards with real pip layouts and monogram courts, totals in gold pills, BUST, the stake stack, the deal pacing, the HIT and STAND stamps, the outcome plate, the placard as a plate. No hit or stand, with the cost stated. |
| A.7 racing form guide | 7 | One card per entrant with silks, name, odds chip, spirit pips and a win chance bar; a scrolling window; the stake row; `Tab.CARD` as a plate; the drawn empty state. `entrants_provider` gains `coat` and `mane`. |
| A.8 the lobby | 7 | Six tiles in a 3 by 2 grid split at each `LOBBY_ROWS` colon, the wallet strip, the cage's exchange illustration and drawn rows, the rules plate. `Tab`, `Row`, `_row_count()`, `confirm()`, `first_row_line_index()`, `switch_tab()` and the three signals untouched. |
| B.1 the Palace sign | 8 | `LobbySign` replaces the `Label3D`; the eleven lines move to `Tab.RULES`; `casino_test.gd`'s block retargets onto that page plus the standing board. |
| B.2 the marquee | 8 | Kept. Ten bulbs as one `MultiMeshInstance3D`, one shadowless `SpotLight3D` wash, and glow (Task 9) is what makes them bloom. `light_count()` still answers 9. |
| B.3 the nameplates | 8 | Removed. Lane saddlecloths, six coloured gate posts, a gold chevron over `RaceCard.PLAYER_LANE`. `test_race_runner.gd` excludes by name. |
| C.1 tonemapping and grading | 9 | `tonemap_white` 3.0 to 1.8, ACES kept, AgX rejected with the reason, the adjustment block on at the spec's three numbers. |
| C.2 glow | 9 | All nine fields at the spec's values, additive, threshold above 1.0, levels 3 to 5. |
| C.3 shadows and fog | 9 | All ten `$Sun` fields, plus `fog_aerial_perspective` 0.35. SSAO on at the spec's eight values; SSIL off with the reason recorded. |
| C.4 the terrain | 9 | `terrain.gdshader` with all six numbered behaviours, the sRGB conversion present with the "pale mint sheet" comment naming the failure mode, and the `ShaderMaterial` assertion in `test_terrain.gd`. |
| C.5 building materials | 9 | `_material(colour, roughness, metallic)`, three roughnesses, `trim_metallic` exported and set to 0.45 on the Palace alone. Pen, track and strip left alone. |
| D.1 the panel style | 2 | `panel_style()`, `apply_panel()`, ten `.tscn` copies deleted. |
| D.2 the row treatment | 2 | `row_box()` and `row_panel()` over the four declared `ROW_*` constants; the caret stays; applied to the nine cursor driven panels and not to the letter panel. |
| D.3 the type hierarchy | 2 | `title_font()`, `numeral_font()`, `SUBTITLE_SIZE` 18; `TITLE_SIZE`, `ROW_SIZE`, `FOOTER_SIZE` unchanged; no font asset. |
| D.4 the title rule | 2, 7 | `MenuStyle.rule()`; drawn under the wallet strip on the lobby stage. |
| D.5 the footers | 5 | Unchanged, and `WHEEL_FOOTER` deleted. |
| D.6 the HUD's styler | 2 | `hud.gd._style_label()` folded onto `MenuStyle.style_label()`. |
| Testing: the six edited test files | 2, 3, 8, 9 | `test_menu_style.gd`, `test_table_caret.gd`, the four menu test files, `test_race_runner.gd`, `test_terrain.gd`, `casino_test.gd`. |
| Testing: the new tests | 1, 3, 8 | `test_casino_paint.gd`, `test_casino_stages.gd` (which carries the spec's "an out of range push degrades to a still frame" requirement for all three push methods), `test_lobby_sign.gd`. |
| `MIN_TESTS` | 9 | Read off the suite's own `Tests` line by the given `sed`; the current value is read out of the file rather than typed. |

Three things the spec asks for that this plan places differently, each on purpose and each argued above: **Task 8 splits into 8 and 9**; **the row box goes on cursor driven panels and not on the letter panel**; **`MenuPanel` lives in ten `.tscn` files and not seven**, which is what the repository actually contains.

**2. Placeholder scan.** Every code step carries the actual GDScript, GLSL, bash or Python. Four steps name a procedure rather than a literal and each says exactly how to get the number: the gate counts in Task 9 step 9 (read from each gate's own printed output); `MIN_TESTS` in step 11 (read off the `Tests` line, with the current value read out of the file by `grep -oP` rather than typed); the `RANCH prop Palace` seat error in Task 8 step 9 (read off the gate, with the fix stated if it moved); and the saturation judgement in the render checklist, which is a question for a person and says so. No step says "similar to Task N": the two menus that share the stage block (Task 3 step 5) are told to copy it verbatim and told why a shared base class is refused.

**3. Type and name consistency, checked across tasks.**

- `CasinoPaint` is preloaded as `PaintScript` in every consumer: `table_menu.gd`, all five menus, `race_runner.gd`, `race_track.gd`, and the four test files. One alias.
- `CasinoPaint.rounded(ci, rect, radius, fill, border, border_width)` is called with six arguments at every one of its ~30 call sites. `CasinoPaint.text(ci, font, at, string, size, colour, align, max_width)` with eight. `CasinoPaint.chip(ci, centre, radius, colour, edge_marks)` with five. `CasinoPaint.focus_ring(ci, rect, radius, t)` with four. `CasinoPaint.plate(ci, rect, font, title, body)` with five, and every caller passes `body` as an `Array[String]` built by a typed local, never as a bare literal.
- `CasinoPaint.chip_stack(ci, base, count, colour, step)` takes `step` and not `height_per_chip`; the spec's prose name is not a signature. Four call sites, all five arguments.
- `CasinoPaint.draw_room(ci, box, row)` is indexed by `CasinoMenu.Row` (0 to 5) in Task 1's test, in the lobby tiles (Task 7) and in the race menu's empty state (Task 7, row 4 = `RACING`). One indexing convention.
- `MenuStyle.row_panel(picked) -> PanelContainer` is what menus call; `MenuStyle.row_box(picked) -> StyleBoxFlat` is what `row_panel()` and the test call. Both defined in Task 2, and no menu calls `row_box()` directly.
- `stage_size()`, `paint()`, `printed_lines()`, `focus_rect()`, `focused_id()`, `animating()`, `anim_time()` and `to_viewport()` are defined once on `TableMenu` (Task 3), mirrored once on `CasinoMenu` (Task 3), and overridden with the same signatures in Tasks 4 through 7.
- `focused_id()`'s vocabulary is one scheme across all five screens and every test reads it: `stake:<n>` (slots, wheel, blackjack, race), `guess:<n>` (wheel), `entrant:<n>` (race), `tile:<n>` and `cage:<n>` (lobby), `row:<n>` (the `TableMenu` default). `test_casino_stages.gd` asserts they are unique per tab; `test_table_caret.gd`, `test_slots_menu.gd`, `test_wheel_menu.gd`, `test_blackjack_menu.gd`, `test_casino_menu.gd` and `test_race_menu.gd` each assert specific ones, and the spellings match.
- The three push methods: `SlotsMenu.show_spin(reels: Array[int], won: int, stake: int)`, `WheelMenu.show_spin(pocket: int, won: int, stake: int)`, `BlackjackMenu.show_hand(hand: Dictionary, won: int, stake: int)`. `ranch.gd`'s three call sites pass exactly those, in that order, from the local variables each transaction already has (`reels`/`pocket`/`hand`, `won`, `stake`), each behind `has_method()`. `RaceMenu` has none, because the race is 3D and already has `race_settled`.
- `RaceRunner.dress(data, triple, display, lane := -1)` gains its fourth parameter with a default, so `test_race_runner.gd`'s existing three argument calls stay valid and `race_track.dress()`'s call passes the lane it already has in hand.
- `race_entrants()`'s dictionary is `{"uid", "name", "happiness", "odds", "chance", "coat", "mane"}`; `race_menu.gd` reads `coat` and `mane` through `entry.get(key, FALLBACK)` and nothing else reads them, so a gate building the five key version still works.
- `Terrain.DIRT` is the GDScript constant and `dirt_color` is the shader uniform it is pushed into; `Terrain.GRASS_HIGH` and `grass_high` likewise. Two names for each because one is a Godot constant and one is a GLSL identifier, and `set_shader_parameter()` is the single place they meet.
- `LobbySign.HEADLINE` / `SUBLINE` are read by `ranch.gd`'s build call and by `test_lobby_sign.gd`; `LobbySign.lines()` is the static both the test and any future sweep reads.
- Screenshot names are used once each, in `_capture_look()` and in Task 9 step 10's table: `18_palace_lobby_sign`, `19_marquee_and_gold_trim`, `20_ground_slope_and_dirt`, `21_race_lane_colours`. They continue the dressing slice's 13 to 17 without colliding.

**4. Two things deliberately not done, recorded so they stay decisions.** There is no gate asserting that a stage's drawn output LOOKS like anything: geometry, focus and text model are what a gate can hold, and the eight renders in Task 9 are what a person looks at. And no sound: a reel click, a chip clink, a wheel ratchet and a card snap would each be worth more than any single visual item in section A, and every one of them is an asset acquisition question. The spec parks it and this plan leaves it parked.
