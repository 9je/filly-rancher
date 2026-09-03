# Phase 3 Slice 3: Story, Paper. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Company a voice the player reads: a saved `Story` (chapter plus flags), authored `StoryBeat` letters as data, a mailbox by the ranch door with a visible unread signal, a drawn Mail page in the pause menu that renders letters as stationery rather than as text rows, the scripted Employee Appreciation Survey and its Priority Requisition, and Request Board wording that changes with the chapter.

**Architecture:** Spine first, content as data, exactly as slices 1 and 2. `game/systems/story.gd` is a pure `RefCounted` that holds the chapter, the flag set, four counters and the mail log, and knows nothing about a scene; `game/systems/story_beat.gd` is a `Resource` with one `.tres` per letter under `game/data/story/`; `game/systems/story_library.gd` loads that directory the way `RegionRegistry` loads regions and answers "which beats are due". `ranch.gd` is the only thing that advances the story, posts mail, pays the Survey bonus and walks the requisitioned pony; the Mail page draws and emits, like every other panel. The page is a drawn screen, not a list: `game/ui/paper_paint.gd` is a small stationery kit built on the existing `CasinoPaint` primitives (`rounded`, `text`, `focus_ring`) and `MenuStyle` chrome, and the pause menu gains one `Stage` `Control` painted by it, the same shape the polish slice gave every casino table.

**Tech Stack:** Godot 4.5.2, GDScript, GUT 9.5.0, the project's headless gate conventions (`RANCH_OK`, `STORY_OK`, `bash tools/run_tests.sh`).

**Spec:** `docs/superpowers/specs/2026-08-30-phase3-rainbow-factory-design.md`. Read it in full before Task 1, in particular "Story", "Pacing", "Data model changes", "Testing" and "Build order". Read "The insider and the fork" too, for boundary awareness only: none of it is built here.

## Scope ruling, carried from the brief

The spec says slice 3 leaves "the Company route complete except the tour", but ranks, perks and the fork are build order item 4. The resolution this plan is written to:

- **In this slice:** the `Story` system, `StoryBeat` resources, the mailbox and the Mail page, the Survey and Requisition chain, chapter keyed Request Board wording and the chapter keyed `PROCESSED` label, every letter through `WEATHER` fully authored, and the Company ladder's letters as authored **text data only**.
- **Two fields are authored and validated here and consumed later, on purpose.** `StoryBeat.reveals` (Compendium ids a letter relabels) and `StoryBeat.evidence` (the letters the Resistance route can carry to a town NPC) both exist, are saved in the `.tres` files, and are checked by `story_test` (every revealed id must be a character this build carries). Nothing in `SUNNY` or `WEATHER` reveals a name, because the letters that name somebody the player has not met are the fork's, so the relabelling those ids drive lands with slice 4 and the leak verb with slice 5. Building a reveal mechanism now would be a mechanism with no data behind it.
- **Not in this slice:** the fork, the `CONTACT` trigger mechanics, ranks, perks, heat, talk boxes, NPCs, the Town, the Factory interior. `Chapter.CONTACT`, `Chapter.COMPANY` and `Chapter.RESISTANCE` exist in the enum and the `COMPANY` letters exist as `.tres` files, and nothing in this slice can reach them: the ladder this slice ships climbs `SUNNY` to `WEATHER` and stops there. Slice 4 appends one row to `Story.LADDER` and the letters it needs are already written.

## Global Constraints

- **THE MATH DOES NOT CHANGE.** Nothing under `game/systems/` that computes money, odds or edges changes meaning. `Ledger`'s constants, `Economy.GEM_VALUE_BY_RARITY`, every casino payout and `RequestBoard`'s reward arithmetic and seeded draw are untouched. The Survey's 50 bits and its hay coupon flow through the transaction seams `ranch.gd` already has (`Economy.grant()`, `Inventory.add()`), and the Requisition's credit flows through `Ranch.deliver_pony()`, which is the one delivery path in the game.
- **NO PONY EVER DIES.** The word "killed" never appears anywhere in this slice: not in a letter, not in a comment, not in a test name. Ponies leave by the departure path and only `Pony._state_leaving` may free one. The Compendium says `PROCESSED`. The register is dark humour and never grim on screen: the Company is funny the way an HR poster is funny. Creative direction, standing: Slime Rancher plus Stardew Valley plus a bit of gambling, with dark humour elements.
- **No em dash and no double hyphen in ANY new line** of code, player facing text, data, comment or documentation. `# --- banner ---` comment banners and CLI flags (`--headless`, `--audio-driver`) are the only exemptions. Use ";" or ":" or a comma. The files being edited are full of pre existing ` -- ` in their own comments: leave those alone and do not copy the habit. The spec mandates a test that asserts no `StoryBeat` title or body carries one; Task 3 writes it.
- **Explicit type annotations wherever `:=` cannot infer the type.** Godot 4.5 promotes `INFERENCE_ON_VARIANT` to an error on the preload dependency compile path; GUT's loader does not catch it, `tools/run_tests.sh`'s parse sweep does. Every `Dictionary` read (`entry.get("read", false)`, `row["uid"]`) needs one.
- **Preload by `res://` path, never by the global `class_name`,** in production code AND in test code. Every construction, static call and constant read goes through a `const XScript := preload("res://...")` at the top of the file. A bare `class_name` may appear ONLY as a type annotation.
- **Every new `.gd` and every new `.tres` gets its `.uid` sidecar committed.** After creating files run `tools/bin/godot --headless --path game --import` once and `git add` the generated `game/**/*.uid`.
- **Menus draw and emit; `ranch.gd` transacts and owns pause.** Nothing under `game/ui/` may touch `Economy`, `GameState`, `Ledger` or `Story`. The Mail page is handed rendered rows through `Callable` providers and hands back two signals. No `RandomNumberGenerator` may be constructed anywhere under `game/ui/`, and no `randi`/`randf` call may appear there.
- **Input parity, and no `Button` nodes.** Keyboard and gamepad drive every screen: a `_selected` cursor on `ui_up`/`ui_down`, `ui_accept` to confirm, `ui_cancel` to go back, read in the panel's own `_unhandled_input()`. No mouse only affordance, no `grab_focus()`, no engine focus chain. Footers are built by `MenuStyle.footer*()` so they print the glyphs of the device actually in her hands.
- **It has to look built.** The Mail page clears the bar the casino stages cleared: drawn stationery, not a column of `Label`s. Letters render as a paper sheet with a Company letterhead plate, a sender line, a `MenuStyle.rule()` and the body; the list is envelope cards with a sender, a title and an unread marker; the Survey renders as a form whose picker rows carry the one focus treatment (`CasinoPaint.focus_ring`) every focusable thing in this game uses; the coupon is a drawn stamp. Chrome is `MenuStyle.panel_style()`, `MenuStyle.apply_title()`, `MenuStyle.rule()` and the shared palette: the same ten panels the polish slice restyled.
- **Mail arrival is an event, not a state.** The mailbox prop raises a flag readable at a distance (a mesh, no `Label3D`, no floating text anywhere), and arrival says so once through the HUD toast machinery `ranch.gd` already owns (`_toast`). No new HUD channel, no sound assets, no new fonts, no animation system beyond `Tween` on a `Control`.
- **Census is sacred.** `RANCH_OK` currently asserts `ponies=49 props=110` with assets present and `ponies=0 props=6` without. The mailbox is one more child of `$Buildings`, so `props=` becomes 111 and 7. The SAME commit that adds it updates every count consequence: the gate is derived (`Props.expected_count() + buildings.get_child_count()`, no literal to edit), and the documentation lines are listed in Task 5.
- **Test floor.** The suite stands at 1242 tests with `MIN_TESTS=1242` in `tools/run_tests.sh`. The final task raises `MIN_TESTS` to the number the suite actually reports and proves the floor still bites with a `FILLY_MIN_TESTS` override. Never guess the number; read it off the run.
- **Gates: marker after the verdict, exit code IS the verdict.** Command form: `tools/bin/godot --headless --audio-driver Dummy --path game <scene>`. This slice adds `game/scenes/test/story_test.tscn`, printing `STORY_OK checks=<n>` or `STORY_FAILED`.
- **Godot 4.5 traps this project has already paid for.** `assert_le` does not exist; use `assert_lte`. Never wait a fixed number of frames headless for a state to arrive; wait on the state with a hard frame cap. A duplicate `var` declaration is a silent parse failure that hangs a gate scene. A property `Tween` cannot address an `Array` element; use `tween_method`. `draw_*` calls are legal only inside a `NOTIFICATION_DRAW` context, which means inside the function connected to a `Control`'s `draw` signal.
- **A red intermediate state is never a resting state.** Every task ends with `bash tools/run_tests.sh` green, the ranch gate green, and a commit. Commit messages use conventional prefixes (`feat:`, `fix:`, `test:`, `docs:`).
- **Branch:** `phase3-story-paper`, cut from `master`.

---

## What is on master today

Verified at `618126d`. Read this before Task 1; every task below is written against it.

**Saving.** `SaveIO.FORMAT_VERSION` is **5**. `GameState` (autoload) owns `ponies`, `bits`, `plots`, `unlocks`, `world_seed`, `gems`, `inventory`, `world_time`, `compendium`, `requests`, `ledger`, `player`, `casino`, each behind a `KEY_*` constant, each written by hand in `to_dict()` and read with a default in `from_dict()`. **There is no `story` key.** Adding one does NOT bump the format version: a v5 save without it loads because `from_dict()` defaults it, and `SaveIO.migrate()`'s `from_version < 5` branch states the v5 shape explicitly, so `"story": {}` is added there beside `"ledger"`, `"player"` and `"casino"`.

**The clock and the cycle.** `WorldState` (`game/systems/world_state.gd`) emits `phase_changed` and `weather_changed`; `ranch.gd::_on_world_changed()` is the single handler for both (the reload probe in `_report()` asserts exactly one connection each, so a second listener is forbidden) and already calls `_maybe_run_collection_day()` and `_maybe_serve_collector()` from inside it. `WorldState.cycle_index()` is the cycle number; `Phase.DAWN` is the first phase of every cycle.

**Deliveries.** `Ranch.deliver_pony(uid)` is the ONE delivery path: it refuses a pony who is HELD or racing, releases her body from the pen, calls `body.leave_toward(crate_position())`, removes her record, calls `Ledger.credit_delivery(rarity, is_stock)`, marks a named pony `PROCESSED` in the Compendium, renders a receipt from `Letters` and toasts it. It returns `{"ok": bool, "credit": int, "named": bool, "name": String}`. `Ledger.shipments` counts every pony ever shipped and is saved.

**The Depot, the Market, the Board, the Palace, the pause menu** are `CanvasLayer` panels instanced in `game/world/ranch.tscn`, bound in `ranch.gd::_bind_*_menu()` by setting `Callable` providers and connecting signals, and all of them route pause through `_on_menu_opened_any()` / `_on_menu_closed()`. `_no_menu_but(menu)` is the one "is anything else up" predicate, and its list must gain nothing here (the Mail page is a page of the pause menu, not a new panel).

**`game/ui/pause_menu.gd`** has `enum Page { MAIN, SETTINGS, COMPENDIUM, REQUESTS, LEDGER }`, `enum Row { RESUME, COMPENDIUM, REQUESTS, LEDGER, SAVE, SETTINGS, QUIT }` and `const MAIN_ROWS` of seven strings. `open_page(page)` lands straight on a page and is how the Board's E prompt reaches `REQUESTS`; `ranch.gd::_pause_menu_page("REQUESTS")` reads the page number out of the script's own constant map so a page that does not exist yet answers `-1` rather than failing to compile. Its scene tree is `Dim`, `Centre/Panel/Margin/Column/{Title, Rows, Footer}`; there is **no `Stage` node**, and Task 4 adds one.

**`game/ui/letter_panel.gd`** (`LetterPanel`) is the read only letter reader: `open(letter: Dictionary) -> bool` where the dictionary is `{"sender", "title", "body": Array[String]}`, exactly what `Letters.render()` answers, plus `is_open()`, `close()`, `drawn_lines()`. Its own class comment says it is deliberately the reader the story slice's mail will be shown through. It is in `_no_menu_but()`'s list already.

**`game/systems/letters.gd`** (`Letters`) is the stub sender: `MAX_NAME_LENGTH` 16, `LINE_WIDTH` 58, `SENDER` "Cloudsdale Weather Corporation", six fixed templates, `ordinal(n)`. It stays exactly as it is; `StoryBeat` is the data driven sender beside it, and both reuse `LINE_WIDTH`.

**`game/systems/request_board.gd`** stores each request as a `Dictionary` with `id`, `kind`, `personality`, `zone`, `rarity`, `count`, `progress`, `character`, `reward_bits`, `reward_food`, `reward_food_count`, `done`, `paid`, `text`. Text is baked at draw time and saved. `to_array()`/`from_array()` round trip it with the seed and draw counter in element 0. Task 8 makes the TEXT a function of the chapter without touching a single reward, threshold or seeded draw.

**`game/ui/menu_style.gd`** (`MenuStyle`) has the palette, `TITLE_SIZE` 30, `ROW_SIZE` 22, `SUBTITLE_SIZE` 18, `FOOTER_SIZE` 20, `CARET`/`NO_CARET`, `style_label()`, `apply_title()`, `apply_panel()`, `panel_style()`, `row_box()`, `row_panel()`, `title_font()`, `numeral_font()`, `rule(ci, from, to)` and four footer builders. **`game/ui/casino_paint.gd`** (`CasinoPaint`) has `rounded(ci, rect, radius, fill, border, width)`, `text(ci, font, at, string, size, colour, align, max_width)` (outline pass then colour pass), `focus_ring(ci, rect, radius, t)`, `plate(ci, rect, font, title, body)`, `ellipse`, `chip`, `star_points(box)` and the glyph kit. Task 4 builds the stationery on those primitives rather than re-deriving them.

**The buildings and the census.** `$Buildings` holds six `StaticBody3D` children (`Barn`, `Farmhouse`, `Market`, `Board`, `Depot`, `Palace`), each running `game/world/building.gd`. `ranch.gd::_ready()` calls `node.build()` on every child and seats it with `Props.seat()`; `prop_count` is `props.build() + buildings.get_child_count()`; `_report()`'s expectation is `Props.expected_count() + buildings.get_child_count()`, so a seventh child moves both sides together. `_all_props()` walks props plus every `$Buildings` child, and the gate then checks each has a collision shape, is on the `PROPS` layer, and is seated within `SEATING_TOLERANCE` of `terrain.height_at(origin)` (for anything that is not a `Building`, which is the rule a custom node is measured by). `_interaction_doors()` lists the four building origins the interact verb measures from, with their radii. `Building.build()` `push_error`s when `door_height < MIN_DOOR_CLEARANCE` (2.25 m), which is why the mailbox is its own small node rather than a `Building` with silly numbers.

**`game/world/interaction.gd`** (`Interaction`) has `enum Kind { NONE, PLOT_BUILD, PEN_MOVE_IN, MARKET, BOARD, DEPOT, PALACE }`, `const PRIORITY`, `candidate(kind, distance, subject)`, `rank_of(kind)`, `resolve(candidates)` and `prompt_for(action, key)`. A kind missing from `PRIORITY` can never win, which is deliberate.

---

## Task 1: The `Story` system, saved

**Files:**
- Create: `game/systems/story.gd`
- Create: `game/test/test_story.gd`
- Modify: `game/systems/game_state.gd` (preload block, `KEY_*` block, the `story` var, `to_dict()`, `from_dict()`, `reset()`)
- Modify: `game/systems/save_io.gd` (the class comment's version 5 paragraph and `migrate()`'s `from_version < 5` branch)
- Test: `game/test/test_story.gd`, `game/test/test_game_state.gd`, `game/test/test_save_io.gd`

**Interfaces:**
- Consumes: nothing from a later task. `GameState`'s existing `to_dict()`/`from_dict()` shape.
- Produces:
  - `Story.Chapter { SUNNY, WEATHER, CONTACT, COMPANY, RESISTANCE }`, `Story.Trigger { CHAPTER, DELIVERIES, COLLECTION_DAYS, NAMED_DELIVERIES, SURVEY_DAYS }`
  - `Story.CHAPTER_NAMES: Array[String]`, `Story.TRIGGER_NAMES: Array[String]`, `Story.LADDER: Array[Dictionary]`
  - `Story.chapter_index(name: StringName) -> int`, `Story.trigger_index(name: StringName) -> int`, `Story.spectra_colour(data_id: StringName) -> String`
  - `Story.SURVEY_BONUS_BITS := 50`, `Story.SURVEY_COUPON_ITEM := &"hay"`, `Story.SURVEY_COUPON_COUNT := 3`
  - fields `chapter: int`, `flags: Dictionary`, `deliveries: int`, `named_deliveries: int`, `collection_days: int`, `survey_period: int`, `requisition_cycle: int`, `survey_choice: Dictionary`, `last_named: Dictionary`, `mail: Array`
  - `note_delivery(named: bool, display_name: String, data_id: StringName) -> void`, `note_collection_day() -> void`, `counter(kind: int) -> int`, `advance() -> bool`, `has_flag(key: String) -> bool`, `set_flag(key: String, value: bool = true) -> void`, `has_mail(id: StringName) -> bool`, `post(id: StringName) -> bool`, `mail_ids() -> Array[StringName]`, `unread_count() -> int`, `is_read(id: StringName) -> bool`, `mark_read(id: StringName) -> bool`, `replied_to(id: StringName) -> String`, `record_reply(id: StringName, reply: String) -> bool`, `answer_survey(choice: Dictionary) -> bool`, `survey_answered() -> bool`, `to_dict() -> Dictionary`, `Story.from_dict(d: Dictionary) -> Story`
  - signals `chapter_changed(chapter: int)`, `mail_posted(id: StringName)`
  - `GameState.story: Story`, `GameState.KEY_STORY := "story"`

- [ ] **Step 1: Write the failing test**

Create `game/test/test_story.gd`:

```gdscript
extends GutTest
## The saved story: a chapter, a flag set, four counters the game already emits, and the
## mail log. No scene, no clock, no RNG, so the whole of it runs in milliseconds.

const StoryScript := preload("res://systems/story.gd")


func test_a_new_story_starts_sunny_with_nothing_read() -> void:
	var story = StoryScript.new()
	assert_eq(story.chapter, StoryScript.Chapter.SUNNY)
	assert_eq(story.deliveries, 0)
	assert_eq(story.named_deliveries, 0)
	assert_eq(story.collection_days, 0)
	assert_eq(story.mail_ids().size(), 0)
	assert_eq(story.unread_count(), 0)
	assert_false(story.survey_answered())


func test_the_counters_are_the_ones_the_game_already_emits() -> void:
	var story = StoryScript.new()
	story.note_delivery(false, "Pony", &"")
	story.note_delivery(true, "Trixie", &"trixie")
	story.note_collection_day()
	assert_eq(story.counter(StoryScript.Trigger.DELIVERIES), 2)
	assert_eq(story.counter(StoryScript.Trigger.NAMED_DELIVERIES), 1)
	assert_eq(story.counter(StoryScript.Trigger.COLLECTION_DAYS), 1)
	assert_eq(story.counter(StoryScript.Trigger.CHAPTER), 0,
		"CHAPTER is the trigger that fires on arrival, so its counter is always met")


func test_a_named_delivery_is_remembered_for_the_receipt_that_names_her() -> void:
	var story = StoryScript.new()
	story.note_delivery(true, "Trixie", &"trixie")
	assert_eq(String(story.last_named.get("name", "")), "Trixie")
	assert_false(String(story.last_named.get("colour", "")).is_empty())


func test_the_spectra_colour_is_a_function_of_the_id_and_never_rolls() -> void:
	var first: String = StoryScript.spectra_colour(&"trixie")
	var again: String = StoryScript.spectra_colour(&"trixie")
	assert_eq(first, again, "the same pony is always the same colour on the receipt")
	assert_true(first in StoryScript.SPECTRA_COLOURS)


func test_the_ladder_climbs_sunny_to_weather_on_deliveries_and_stops_there() -> void:
	var story = StoryScript.new()
	var moved: Array[int] = []
	story.chapter_changed.connect(func(c: int) -> void: moved.append(c))
	for i in range(StoryScript.WEATHER_DELIVERIES - 1):
		story.note_delivery(false, "Pony", &"")
		assert_false(story.advance(), "not yet: %d deliveries" % story.deliveries)
	story.note_delivery(false, "Pony", &"")
	assert_true(story.advance(), "the third delivery turns the chapter")
	assert_eq(story.chapter, StoryScript.Chapter.WEATHER)
	assert_eq(moved, [StoryScript.Chapter.WEATHER] as Array[int])
	for i in range(40):
		story.note_delivery(true, "Trixie", &"trixie")
		story.note_collection_day()
	assert_false(story.advance(), "slice 3's ladder ends at WEATHER")
	assert_eq(story.chapter, StoryScript.Chapter.WEATHER)


func test_mail_is_posted_once_kept_forever_and_read_state_sticks() -> void:
	var story = StoryScript.new()
	assert_true(story.post(&"sunny_mailbox"))
	assert_false(story.post(&"sunny_mailbox"), "a beat is posted exactly once")
	assert_true(story.has_mail(&"sunny_mailbox"))
	assert_eq(story.unread_count(), 1)
	assert_true(story.mark_read(&"sunny_mailbox"))
	assert_false(story.mark_read(&"sunny_mailbox"), "reading twice changes nothing")
	assert_eq(story.unread_count(), 0)
	assert_true(story.is_read(&"sunny_mailbox"))
	assert_true(story.post(&"weather_survey"))
	assert_eq(story.mail_ids(), [&"sunny_mailbox", &"weather_survey"] as Array[StringName],
		"mail is kept forever, in the order it arrived")


func test_answering_the_survey_stamps_the_choice_and_the_period() -> void:
	var story = StoryScript.new()
	story.note_collection_day()
	story.post(&"weather_survey")
	assert_true(story.answer_survey({"uid": "u1", "data_id": "trixie", "name": "Trixie",
		"coat": ""}))
	assert_true(story.survey_answered())
	assert_eq(String(story.survey_choice.get("name", "")), "Trixie")
	assert_eq(story.survey_period, 1)
	assert_eq(story.counter(StoryScript.Trigger.SURVEY_DAYS), 0)
	story.note_collection_day()
	story.note_collection_day()
	assert_eq(story.counter(StoryScript.Trigger.SURVEY_DAYS), 2)
	assert_false(story.answer_survey({"uid": "u2", "data_id": "rarity", "name": "Rarity"}),
		"the survey is answered once")


func test_an_unanswered_survey_never_lets_the_requisition_come_due() -> void:
	var story = StoryScript.new()
	for i in range(20):
		story.note_collection_day()
	assert_eq(story.counter(StoryScript.Trigger.SURVEY_DAYS), -1,
		"SURVEY_DAYS is below every threshold until she answers")


func test_flags_are_plain_and_default_to_false() -> void:
	var story = StoryScript.new()
	assert_false(story.has_flag("requisition_served"))
	story.set_flag("requisition_served")
	assert_true(story.has_flag("requisition_served"))
	story.set_flag("requisition_served", false)
	assert_false(story.has_flag("requisition_served"))


func test_the_whole_story_round_trips_through_a_dictionary() -> void:
	var story = StoryScript.new()
	story.note_delivery(true, "Trixie", &"trixie")
	story.note_collection_day()
	story.advance()
	story.post(&"weather_survey")
	story.mark_read(&"weather_survey")
	story.answer_survey({"uid": "u1", "data_id": "trixie", "name": "Trixie", "coat": ""})
	story.record_reply(&"weather_survey", "u1")
	story.set_flag("requisition_posted")
	story.requisition_cycle = 4

	var back = StoryScript.from_dict(story.to_dict())
	assert_eq(back.chapter, story.chapter)
	assert_eq(back.deliveries, story.deliveries)
	assert_eq(back.named_deliveries, story.named_deliveries)
	assert_eq(back.collection_days, story.collection_days)
	assert_eq(back.survey_period, story.survey_period)
	assert_eq(back.requisition_cycle, 4)
	assert_true(back.has_flag("requisition_posted"))
	assert_true(back.is_read(&"weather_survey"))
	assert_eq(back.replied_to(&"weather_survey"), "u1")
	assert_eq(String(back.survey_choice.get("name", "")), "Trixie")
	assert_eq(String(back.last_named.get("name", "")), "Trixie")


func test_a_hand_edited_file_cannot_fabricate_a_chapter_this_build_does_not_have() -> void:
	var back = StoryScript.from_dict({"chapter": 99, "deliveries": -5, "mail": "not an array"})
	assert_eq(back.chapter, StoryScript.Chapter.RESISTANCE, "clamped, not trusted")
	assert_eq(back.deliveries, 0, "a negative counter is not a counter")
	assert_eq(back.mail_ids().size(), 0, "junk is dropped rather than kept")


func test_an_empty_dictionary_is_a_brand_new_story() -> void:
	var back = StoryScript.from_dict({})
	assert_eq(back.chapter, StoryScript.Chapter.SUNNY)
	assert_eq(back.mail_ids().size(), 0)
	assert_eq(back.survey_period, -1)


func test_the_names_and_the_enums_agree_in_both_directions() -> void:
	assert_eq(StoryScript.CHAPTER_NAMES.size(), StoryScript.Chapter.size())
	assert_eq(StoryScript.TRIGGER_NAMES.size(), StoryScript.Trigger.size())
	assert_eq(StoryScript.chapter_index(&"WEATHER"), StoryScript.Chapter.WEATHER)
	assert_eq(StoryScript.trigger_index(&"SURVEY_DAYS"), StoryScript.Trigger.SURVEY_DAYS)
	assert_eq(StoryScript.chapter_index(&"NOWHERE"), -1, "an unknown chapter is minus one")
	assert_eq(StoryScript.trigger_index(&"NOWHEN"), -1, "an unknown trigger is minus one")


func test_no_line_of_this_system_carries_a_dash() -> void:
	var source: String = FileAccess.get_file_as_string("res://systems/story.gd")
	for line in source.split("\n"):
		var text: String = String(line)
		if text.begins_with("# ---") or text.begins_with("## ---"):
			continue
		assert_false(text.contains("--"), "double hyphen: %s" % text)
		assert_false(text.contains(char(0x2014)), "em dash: %s" % text)
```

- [ ] **Step 2: Run it and watch it fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story.gd -gexit
```

Expected: every test errors because `res://systems/story.gd` does not exist.

- [ ] **Step 3: Write `game/systems/story.gd`**

```gdscript
class_name Story
extends RefCounted
## WHERE THE PLAYER IS IN THE ARC, AS SAVED STATE. A chapter, a flag set, four counters and
## the mail log; no scene, no clock, no RNG, so the whole of it is GUT testable in
## milliseconds (game/test/test_story.gd), the same discipline game/systems/ledger.gd and
## game/systems/compendium.gd are built under.
##
## --- THE COUNTERS ARE THINGS THE GAME ALREADY EMITS -----------------------------------
##
## The design doc: "Chapter advances on triggers the game already emits: deliveries made,
## collection days passed, named ponies delivered". So this object counts exactly those,
## told by game/world/ranch.gd at the moment each happens, rather than reaching into the
## Ledger for numbers that mean something slightly different. Ledger.shipments is the
## Company's count of stock received; `deliveries` here is the story's count of the same
## event, and keeping them separate is what lets a later slice change one without silently
## re-timing every letter in the game.
##
## SURVEY_DAYS IS THE ONE COUNTER THAT CAN BE UNDER ZERO. It is "collection days since she
## answered the Survey", and an unanswered Survey answers -1, which is below every
## threshold a beat can carry. That is the whole of "the letter can sit unanswered forever
## and the beat never fires", expressed as arithmetic rather than as a special case.
##
## --- THE LADDER STOPS AT WEATHER IN THIS SLICE ----------------------------------------
##
## CONTACT, COMPANY and RESISTANCE are in the enum because the save has to be able to hold
## them and because the authored COMPANY letters name them. Nothing here can reach them:
## LADDER has one row. Slice 4 appends CONTACT's row (the spec's CONTACT_DELIVERIES, 6,
## and a named delivery or three collection days) and the fork; no letter and no save
## written by this slice needs a migration when it does.
##
## NOTHING HERE EVER FREES, HARMS OR MOVES A PONY. It records that one left by the
## departure path and what the Company chose to call the colour on the receipt.

## Chapters, in order. The save holds the INDEX; the authored letters name the STRING, so a
## .tres that names a chapter this build does not have is a loud failure in story_test
## rather than a silent zero.
enum Chapter { SUNNY, WEATHER, CONTACT, COMPANY, RESISTANCE }

## The kinds of trigger a StoryBeat may carry. CHAPTER is "as soon as the chapter is
## reached", and its counter is always 0 so any threshold of 0 is met on arrival.
enum Trigger { CHAPTER, DELIVERIES, COLLECTION_DAYS, NAMED_DELIVERIES, SURVEY_DAYS }

const CHAPTER_NAMES: Array[String] = ["SUNNY", "WEATHER", "CONTACT", "COMPANY", "RESISTANCE"]
const TRIGGER_NAMES: Array[String] = ["CHAPTER", "DELIVERIES", "COLLECTION_DAYS",
	"NAMED_DELIVERIES", "SURVEY_DAYS"]

## Deliveries that turn SUNNY into WEATHER. Three, for a pacing reason with a test on it:
## the spec puts the first collection day one real hour in and the fork about three
## sessions in, so the letters have to start going strange while the player is still
## pleased with herself, not five sessions later.
const WEATHER_DELIVERIES := 3

## THE LADDER, one row per chapter change this build can make. See the class comment for
## why it is one row long.
const LADDER: Array[Dictionary] = [
	{"chapter": Chapter.WEATHER, "kind": Trigger.DELIVERIES, "threshold": WEATHER_DELIVERIES},
]

## What the Survey pays for answering, and what the coupon is worth. Paid by ranch.gd
## through Economy.grant() and Inventory.add(), which are the seams every other reward in
## the game already flows through; no money arithmetic lives here.
const SURVEY_BONUS_BITS := 50
const SURVEY_COUPON_ITEM := &"hay"
const SURVEY_COUPON_COUNT := 3

## The words the Company's receipts use for a colour. A fixed list indexed by a hash of the
## character's id: the same pony is always the same colour, on every machine and in every
## save, and nothing here ever rolls anything.
const SPECTRA_COLOURS: Array[String] = ["rose", "amber", "citrine", "viridian", "cobalt",
	"indigo", "violet"]

## Emitted when the chapter actually moves, with the chapter it moved TO. Not for an
## advance() that changed nothing, matching Compendium.changed's rule.
signal chapter_changed(chapter: int)

## Emitted once per beat actually posted, with its id, so a mailbox flag and a HUD line can
## hang off one event.
signal mail_posted(id: StringName)

var chapter: int = Chapter.SUNNY

## String keys, bool values. Plain and untyped for GameState.unlocks' reason: these are
## assigned dynamically from the ranch and from tests.
var flags: Dictionary = {}

var deliveries := 0
var named_deliveries := 0
var collection_days := 0

## `collection_days` at the moment she answered the Survey, or -1 while she has not.
var survey_period := -1

## The cycle the Priority Requisition was posted on, or -1. The collector calls at the first
## DAWN of a LATER cycle, exactly as Ledger.pending_punishment_cycle makes the collector's
## knock land a cycle after his letter; a requisition served in the same breath as its own
## letter is not the beat the spec describes.
var requisition_cycle := -1

## Who she named on the Survey: {"uid": String, "data_id": String, "name": String,
## "coat": String}. SAVED, because slices 4 and 6 read it: the fork's first raid can bring
## her home if the Requisition never fired, and the Factory's window is her.
var survey_choice: Dictionary = {}

## The last named pony delivered: {"name": String, "colour": String}. The receipt that
## lists her beside a colour is written months of play before anybody understands it, so
## the two strings it needs travel with the save rather than being recomputed from a world
## that no longer has her in it.
var last_named: Dictionary = {}

## The mail log, oldest first: [{"id": String, "read": bool, "reply": String}]. Letters are
## kept forever; re-reading old mail is the whole point of the paper channel.
var mail: Array = []


static func chapter_index(name: StringName) -> int:
	return CHAPTER_NAMES.find(String(name))


static func trigger_index(name: StringName) -> int:
	return TRIGGER_NAMES.find(String(name))


## The Company's word for her colour. Deterministic, and deliberately not a property of the
## pony: it is what the paperwork says, which is the joke.
static func spectra_colour(data_id: StringName) -> String:
	var key: String = String(data_id)
	if key.is_empty():
		return SPECTRA_COLOURS[0]
	return SPECTRA_COLOURS[absi(hash(key)) % SPECTRA_COLOURS.size()]


# --- the counters ------------------------------------------------------------------------

## One pony left by the departure path. `named` is false for the crowd, in which case the
## other two arguments are ignored.
func note_delivery(named: bool, display_name: String = "", data_id: StringName = &"") -> void:
	deliveries += 1
	if not named:
		return
	named_deliveries += 1
	last_named = {"name": display_name, "colour": spectra_colour(data_id)}


func note_collection_day() -> void:
	collection_days += 1


## The value a beat's threshold is measured against. See the class comment for why
## SURVEY_DAYS can answer -1.
func counter(kind: int) -> int:
	match kind:
		Trigger.CHAPTER:
			return 0
		Trigger.DELIVERIES:
			return deliveries
		Trigger.COLLECTION_DAYS:
			return collection_days
		Trigger.NAMED_DELIVERIES:
			return named_deliveries
		Trigger.SURVEY_DAYS:
			return -1 if survey_period < 0 else collection_days - survey_period
	return -1


## Climb the ladder if this build's next rung is met. Returns whether the chapter moved.
func advance() -> bool:
	var moved := false
	for rung: Dictionary in LADDER:
		var next: int = int(rung["chapter"])
		if chapter >= next:
			continue
		if counter(int(rung["kind"])) < int(rung["threshold"]):
			break
		chapter = next
		moved = true
		chapter_changed.emit(chapter)
	return moved


# --- flags -------------------------------------------------------------------------------

func has_flag(key: String) -> bool:
	return bool(flags.get(key, false))


func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value


# --- the mail log ------------------------------------------------------------------------

func has_mail(id: StringName) -> bool:
	return _entry(id) != null


## Post `id`, unread. Returns false, changing nothing, for a beat already in the log: a
## letter arrives exactly once.
func post(id: StringName) -> bool:
	if String(id).is_empty() or has_mail(id):
		return false
	mail.append({"id": String(id), "read": false, "reply": ""})
	mail_posted.emit(id)
	return true


func mail_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in mail:
		out.append(StringName(String((entry as Dictionary).get("id", ""))))
	return out


func unread_count() -> int:
	var n := 0
	for entry in mail:
		if not bool((entry as Dictionary).get("read", false)):
			n += 1
	return n


func is_read(id: StringName) -> bool:
	var entry: Variant = _entry(id)
	return entry != null and bool((entry as Dictionary).get("read", false))


## Returns whether THIS call is the one that marked it, so a caller can tell "she just
## opened it" from "she opened it last week" without a second lookup.
func mark_read(id: StringName) -> bool:
	var entry: Variant = _entry(id)
	if entry == null or bool((entry as Dictionary).get("read", false)):
		return false
	(entry as Dictionary)["read"] = true
	return true


## What she answered on `id`, or "" for a letter with no reply control or no answer yet.
func replied_to(id: StringName) -> String:
	var entry: Variant = _entry(id)
	return "" if entry == null else String((entry as Dictionary).get("reply", ""))


## Record an answer. Refuses an empty answer and refuses to overwrite one, because a reply
## control that could be answered twice is a bonus that could be paid twice.
func record_reply(id: StringName, reply: String) -> bool:
	if reply.is_empty():
		return false
	var entry: Variant = _entry(id)
	if entry == null or not String((entry as Dictionary).get("reply", "")).is_empty():
		return false
	(entry as Dictionary)["reply"] = reply
	return true


func _entry(id: StringName) -> Variant:
	var key: String = String(id)
	for entry in mail:
		if String((entry as Dictionary).get("id", "")) == key:
			return entry
	return null


# --- the Survey --------------------------------------------------------------------------

func survey_answered() -> bool:
	return survey_period >= 0


## She named a pony. `choice` carries "uid", "data_id", "name" and "coat", all Strings.
## Once only; the second call changes nothing and answers false.
func answer_survey(choice: Dictionary) -> bool:
	if survey_answered():
		return false
	survey_choice = {
		"uid": String(choice.get("uid", "")),
		"data_id": String(choice.get("data_id", "")),
		"name": String(choice.get("name", "")),
		"coat": String(choice.get("coat", "")),
	}
	survey_period = collection_days
	set_flag("survey_answered")
	return true


# --- serialisation -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	# NOT NAMED `log`: that is a GDScript built in (the logarithm) and shadowing it is a
	# warning this project treats as noise it does not want.
	var entries: Array = []
	for entry in mail:
		var row: Dictionary = entry
		entries.append({
			"id": String(row.get("id", "")),
			"read": bool(row.get("read", false)),
			"reply": String(row.get("reply", "")),
		})
	var saved_flags: Dictionary = {}
	for key in flags:
		saved_flags[String(key)] = bool(flags[key])
	return {
		"chapter": chapter,
		"flags": saved_flags,
		"deliveries": deliveries,
		"named_deliveries": named_deliveries,
		"collection_days": collection_days,
		"survey_period": survey_period,
		"requisition_cycle": requisition_cycle,
		"survey_choice": survey_choice.duplicate(true),
		"last_named": last_named.duplicate(true),
		"mail": entries,
	}


## Rebuild from to_dict()'s output, or from what JSON.parse_string hands back, which is the
## same thing with every number as a float. Every field is optional and falls back to a
## brand new story's value, which is what makes a save written before this key existed load
## without a migration step; and every field is CLAMPED rather than trusted, so a hand
## edited file cannot produce a chapter this build does not have or a negative counter.
static func from_dict(d: Dictionary) -> Story:
	var out := Story.new()
	out.chapter = clampi(int(d.get("chapter", Chapter.SUNNY)), Chapter.SUNNY,
		Chapter.RESISTANCE)
	out.deliveries = maxi(0, int(d.get("deliveries", 0)))
	out.named_deliveries = maxi(0, int(d.get("named_deliveries", 0)))
	out.collection_days = maxi(0, int(d.get("collection_days", 0)))
	out.survey_period = maxi(-1, int(d.get("survey_period", -1)))
	out.requisition_cycle = maxi(-1, int(d.get("requisition_cycle", -1)))

	var saved_flags: Variant = d.get("flags", {})
	if typeof(saved_flags) == TYPE_DICTIONARY:
		for key in (saved_flags as Dictionary):
			out.flags[String(key)] = bool((saved_flags as Dictionary)[key])

	out.survey_choice = _string_map(d.get("survey_choice", {}))
	out.last_named = _string_map(d.get("last_named", {}))

	var saved_mail: Variant = d.get("mail", [])
	if typeof(saved_mail) == TYPE_ARRAY:
		for entry in (saved_mail as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = entry
			var id: String = String(row.get("id", ""))
			if id.is_empty() or out.has_mail(StringName(id)):
				continue
			out.mail.append({
				"id": id,
				"read": bool(row.get("read", false)),
				"reply": String(row.get("reply", "")),
			})
	return out


static func _string_map(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	for key in (value as Dictionary):
		out[String(key)] = String((value as Dictionary)[key])
	return out
```

- [ ] **Step 4: Run the story tests and watch them pass**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story.gd -gexit
```

Expected: PASS, 14 tests.

- [ ] **Step 5: Hang the story off `GameState`**

In `game/systems/game_state.gd`, add the preload beside the others:

```gdscript
const StoryScript := preload("res://systems/story.gd")
```

Add the key beside `KEY_CASINO`:

```gdscript
const KEY_STORY := "story"
```

Add the field after `casino`:

```gdscript
## WHERE SHE IS IN THE ARC (game/systems/story.gd): the chapter, the flags, the counters the
## letters are timed off and the mail she has been sent. REPLACED, NOT MUTATED, by
## from_dict() and reset(), the same rule `gems`, `compendium`, `ledger`, `player` and
## `casino` follow: a listener holding the old object is holding the story of a ranch nobody
## is playing any more.
var story: Story = StoryScript.new()
```

Add to `to_dict()`'s returned dictionary, after `KEY_CASINO`:

```gdscript
		KEY_STORY: story.to_dict(),
```

Add to `from_dict()`, after the casino block and before `state_loaded.emit()`:

```gdscript
	var saved_story: Variant = data.get(KEY_STORY, {})
	story = StoryScript.from_dict(
		saved_story if typeof(saved_story) == TYPE_DICTIONARY else {})
```

Add to `reset()`, after `casino = CasinoScript.new()`:

```gdscript
	story = StoryScript.new()
```

- [ ] **Step 6: State the shape in `SaveIO`**

In `game/systems/save_io.gd`, extend the version 5 paragraph of the class comment:

```gdscript
## Version 5 (Phase 3 slice 1) adds "ledger" and "player"; ledger defaults to {} (a brand
## new sponsorship balance) and player defaults to {} (the name Twilight and the shipped
## look). Both are read through their own from_dict(), each of which fills every missing
## field from its own default, so a version 4 file needs nothing else. Slice 2 added
## "casino" and slice 3 "story" at the SAME version and for the same reason: a key whose
## absence is indistinguishable from its default is a key that needs no version bump. See
## migrate()'s from_version < 5 branch, which states the whole shape.
```

In `migrate()`, inside the `if from_version < 5:` branch, after the casino block:

```gdscript
			if not out.has("story"):
				# Story.from_dict({}) is chapter SUNNY with nothing counted and no mail, which
				# is exactly what a save from before the Company started writing should load
				# as. Stated here rather than left to that default so migrate()'s OUTPUT
				# states the whole version 5 shape.
				out["story"] = {}
```

- [ ] **Step 7: Add the round trip tests to the two suites that own them**

Append to `game/test/test_game_state.gd`:

```gdscript
func test_the_story_survives_a_round_trip_and_an_older_save_loads_at_sunny() -> void:
	var state = _state()
	state.story.note_delivery(true, "Trixie", &"trixie")
	state.story.note_collection_day()
	state.story.advance()
	state.story.post(&"weather_survey")
	var data: Dictionary = state.to_dict()
	assert_true(data.has("story"), "the story is written by hand like every other key")

	state.from_dict(data)
	assert_eq(state.story.deliveries, 1)
	assert_eq(state.story.collection_days, 1)
	assert_true(state.story.has_mail(&"weather_survey"))

	data.erase("story")
	state.from_dict(data)
	assert_eq(state.story.chapter, preload("res://systems/story.gd").Chapter.SUNNY,
		"a save written before the story existed opens on SUNNY with an empty mailbox")
	assert_eq(state.story.mail_ids().size(), 0)
```

If `test_game_state.gd` has no `_state()` helper, build the state the way its neighbouring tests do and keep the assertions identical.

Append to `game/test/test_save_io.gd`:

```gdscript
func test_migrate_states_the_story_key_in_the_version_five_shape() -> void:
	var migrated: Dictionary = SaveIOScript.migrate({"bits": 10}, 4)
	assert_true(migrated.has("story"), "migrate() states the whole v5 shape")
	assert_eq(migrated["story"], {})
```

Use whatever constant name that file already preloads `save_io.gd` under.

- [ ] **Step 8: Run the whole suite**

```bash
bash tools/run_tests.sh
```

Expected: green, with the test count up by 16 or so. Then the ranch gate, which must be untouched by this task:

```bash
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```

Expected: `RANCH_OK ponies=49 props=110 assets=present`, exit 0.

- [ ] **Step 9: Commit**

```bash
tools/bin/godot --headless --path game --import
git add game/systems/story.gd game/systems/story.gd.uid game/test/test_story.gd \
  game/test/test_story.gd.uid game/systems/game_state.gd game/systems/save_io.gd \
  game/test/test_game_state.gd game/test/test_save_io.gd
git commit -m "feat: the story is a chapter, a flag set, four counters and a mail log"
```

---

## Task 2: `StoryBeat` as a resource, and the library that loads them

**Files:**
- Create: `game/systems/story_beat.gd`
- Create: `game/systems/story_library.gd`
- Create: `game/data/story/sunny_mailbox.tres`
- Create: `game/test/test_story_beat.gd`
- Test: `game/test/test_story_beat.gd`

**Interfaces:**
- Consumes: `Story.Chapter`, `Story.Trigger`, `Story.chapter_index()`, `Story.trigger_index()`, `Story.counter()`, `Story.has_mail()`, `Story.chapter` (Task 1).
- Produces:
  - `StoryBeat.Reply { NONE, PICK_PONY, YES_NO }`, `StoryBeat.REPLY_NAMES: Array[String]`
  - exported fields `id: StringName`, `chapter: StringName`, `trigger: StringName`, `threshold: int`, `sender: String`, `title: String`, `body: PackedStringArray`, `reveals: PackedStringArray`, `evidence: bool`, `reply: StringName`
  - `StoryBeat.DEFAULTS: Dictionary`, `chapter_index() -> int`, `trigger_index() -> int`, `reply_index() -> int`, `render(params: Dictionary) -> Dictionary`, `body_lines() -> Array[String]`
  - `StoryLibrary.STORY_DIR := "res://data/story"`, `load_all(dir: String = STORY_DIR) -> Dictionary`, `all() -> Array[StoryBeat]`, `by_id(id: StringName) -> StoryBeat`, `due(story: Story) -> Array[StoryBeat]`

- [ ] **Step 1: Write the failing test**

Create `game/test/test_story_beat.gd`:

```gdscript
extends GutTest
## One letter, as data, and the directory that loads them. The corpus itself is checked by
## game/test/test_story_corpus.gd (Task 3) and by the story gate; this file is about the
## resource's own behaviour and the library's own contract.

const StoryScript := preload("res://systems/story.gd")
const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryLibraryScript := preload("res://systems/story_library.gd")


func _beat(id: String, chapter: String, trigger: String, threshold: int) -> StoryBeat:
	var beat: StoryBeat = StoryBeatScript.new()
	beat.id = StringName(id)
	beat.chapter = StringName(chapter)
	beat.trigger = StringName(trigger)
	beat.threshold = threshold
	beat.sender = "Cloudsdale Weather Corporation"
	beat.title = "A letter"
	beat.body = PackedStringArray(["Dear {name},", "", "Your {count} shipments."])
	return beat


func test_a_beat_resolves_its_chapter_trigger_and_reply_to_this_builds_enums() -> void:
	var beat: StoryBeat = _beat("t", "WEATHER", "DELIVERIES", 5)
	assert_eq(beat.chapter_index(), StoryScript.Chapter.WEATHER)
	assert_eq(beat.trigger_index(), StoryScript.Trigger.DELIVERIES)
	assert_eq(beat.reply_index(), StoryBeatScript.Reply.NONE)
	beat.reply = &"PICK_PONY"
	assert_eq(beat.reply_index(), StoryBeatScript.Reply.PICK_PONY)


func test_a_beat_naming_something_this_build_does_not_have_answers_minus_one() -> void:
	var beat: StoryBeat = _beat("t", "NOWHERE", "NOWHEN", 0)
	beat.reply = &"SEMAPHORE"
	assert_eq(beat.chapter_index(), -1)
	assert_eq(beat.trigger_index(), -1)
	assert_eq(beat.reply_index(), -1)


func test_render_fills_the_placeholders_and_answers_the_letter_panel_shape() -> void:
	var beat: StoryBeat = _beat("t", "SUNNY", "CHAPTER", 0)
	var letter: Dictionary = beat.render({"name": "Moonbeam", "count": 12})
	assert_eq(String(letter["sender"]), "Cloudsdale Weather Corporation")
	assert_eq(String(letter["title"]), "A letter")
	var body: Array = letter["body"]
	assert_eq(String(body[0]), "Dear Moonbeam,")
	assert_eq(String(body[2]), "Your 12 shipments.")


func test_a_missing_parameter_renders_a_default_rather_than_a_brace() -> void:
	var beat: StoryBeat = _beat("t", "SUNNY", "CHAPTER", 0)
	var letter: Dictionary = beat.render({})
	var joined: String = "\n".join(letter["body"])
	assert_false(joined.contains("{"), "an unfilled placeholder is a letter she never reads")
	assert_true(joined.contains(String(StoryBeatScript.DEFAULTS["name"])))


func test_the_library_loads_the_shipped_directory_and_indexes_it_by_id() -> void:
	var library = StoryLibraryScript.new()
	library.load_all()
	assert_gt(library.all().size(), 0, "game/data/story is not empty")
	var first: StoryBeat = library.all()[0]
	assert_eq(library.by_id(first.id), first)
	assert_null(library.by_id(&"no_such_beat"), "an unknown id is null, not a crash")


func test_the_library_orders_by_chapter_then_threshold_then_id() -> void:
	var library = StoryLibraryScript.new()
	library.load_all()
	var previous: Vector2i = Vector2i(-1, -1)
	for beat: StoryBeat in library.all():
		var here: Vector2i = Vector2i(beat.chapter_index(), beat.threshold)
		assert_true(here.x > previous.x or (here.x == previous.x and here.y >= previous.y),
			"beats come out in ladder order: %s" % String(beat.id))
		previous = here


func test_due_answers_only_beats_whose_chapter_is_reached_and_threshold_met() -> void:
	var library = StoryLibraryScript.new()
	library.load_all()
	var story = StoryScript.new()
	for beat: StoryBeat in library.due(story):
		assert_eq(beat.chapter_index(), StoryScript.Chapter.SUNNY,
			"a brand new story is only owed SUNNY letters")
		assert_lte(beat.threshold, 0, "and only the ones whose counter is already met")


func test_due_never_answers_a_beat_that_has_already_been_posted() -> void:
	var library = StoryLibraryScript.new()
	library.load_all()
	var story = StoryScript.new()
	var owed: Array[StoryBeat] = library.due(story)
	assert_gt(owed.size(), 0, "a new ranch is owed at least one letter")
	for beat: StoryBeat in owed:
		story.post(beat.id)
	assert_eq(library.due(story).size(), 0, "a posted letter is not owed twice")


func test_a_directory_that_is_not_there_is_reported_and_answers_empty() -> void:
	var library = StoryLibraryScript.new()
	library.load_all("res://data/no_such_directory")
	assert_eq(library.all().size(), 0)
```

- [ ] **Step 2: Run it and watch it fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story_beat.gd -gexit
```

Expected: failures because neither script exists.

- [ ] **Step 3: Write `game/systems/story_beat.gd`**

```gdscript
class_name StoryBeat
extends Resource
## ONE LETTER, AS DATA. Everything the player reads from the Company is one of these: an id,
## the chapter it belongs to, the trigger that brings it, who signed it, a title, a body, an
## optional list of Compendium ids it relabels, whether it is evidence, and whether it
## carries a reply control. One .tres per letter under game/data/story/, so writing more
## story is adding files (the spec's approach: spine first, content as data).
##
## THE CHAPTER, THE TRIGGER AND THE REPLY ARE NAMES, NOT NUMBERS. A .tres carrying
## `chapter = 1` is unreadable and unreviewable, and a typo in it is a silent zero. A .tres
## carrying `chapter = &"WEATHER"` says what it means, and a chapter this build does not
## have resolves to -1, which game/scenes/test/story_test.gd fails the gate on. The spec
## asks for exactly that check: "every StoryBeat has a chapter that exists, a trigger the
## game can emit".
##
## RENDERING ANSWERS THE SHAPE game/ui/letter_panel.gd ALREADY TAKES: {"sender", "title",
## "body": Array[String]}, identical to game/systems/letters.gd's render(). One reader, two
## senders; the stub sender keeps the six letters slice 1 needs and this is the data driven
## one beside it.
##
## PLACEHOLDERS ARE {name} STYLE and filled by String.format, because "%s" positional
## formatting in authored data is how a letter comes to say the wrong number when somebody
## reorders a line. A parameter the caller did not supply falls back to DEFAULTS rather than
## rendering a brace, for game/systems/letters.gd's reason: a letter that fails to render is
## a letter the player never sees and never knows she missed.

const StoryScript := preload("res://systems/story.gd")

## The reply control a letter may carry. PICK_PONY is the Survey's picker over the ponies
## she owns; YES_NO is the two row question a later slice's letters use.
enum Reply { NONE, PICK_PONY, YES_NO }

const REPLY_NAMES: Array[String] = ["NONE", "PICK_PONY", "YES_NO"]

## What every placeholder renders as when the caller supplied nothing. Never a brace, never
## an empty string: a letter reads as a letter even in a test that handed it no world.
const DEFAULTS := {
	"name": "Valued Partner",
	"pony": "your pony",
	"colour": "a colour",
	"count": 1,
	"quota": 2,
	"balance": 0,
}

@export var id: StringName = &""

## A name from Story.CHAPTER_NAMES.
@export var chapter: StringName = &"SUNNY"

## A name from Story.TRIGGER_NAMES, and the value that counter must reach.
@export var trigger: StringName = &"CHAPTER"
@export var threshold: int = 0

@export var sender: String = "Cloudsdale Weather Corporation"
@export var title: String = ""
@export var body: PackedStringArray = PackedStringArray()

## Compendium ids this letter relabels when it lands. Empty for every letter in this slice;
## the field exists because the spec's data model names it and because story_test checks
## that every id in it is a character this build actually carries.
@export var reveals: PackedStringArray = PackedStringArray()

## Whether this is one of the letters the Resistance route can carry to a town NPC. Authored
## now, read in slice 5.
@export var evidence: bool = false

## A name from REPLY_NAMES.
@export var reply: StringName = &"NONE"


func chapter_index() -> int:
	return StoryScript.chapter_index(chapter)


func trigger_index() -> int:
	return StoryScript.trigger_index(trigger)


func reply_index() -> int:
	return REPLY_NAMES.find(String(reply))


func body_lines() -> Array[String]:
	var out: Array[String] = []
	for line in body:
		out.append(String(line))
	return out


## The letter, in game/ui/letter_panel.gd's shape. `params` may carry any of DEFAULTS' keys;
## anything missing falls back to its default.
func render(params: Dictionary) -> Dictionary:
	var filled: Dictionary = DEFAULTS.duplicate()
	for key in params:
		filled[String(key)] = params[key]
	var lines: Array[String] = []
	for line: String in body_lines():
		lines.append(line.format(filled))
	return {"sender": sender, "title": title.format(filled), "body": lines}
```

- [ ] **Step 4: Write `game/systems/story_library.gd`**

```gdscript
class_name StoryLibrary
extends RefCounted
## EVERY AUTHORED LETTER, LOADED OFF DISK AND INDEXED BY ID. Mirrors
## game/systems/region_registry.gd exactly, including the .tres/.tres.remap resolution in
## _resource_path(): Godot's exporter converts text resources to binary by default, so an
## exported .pck carries `foo.tres.remap` stubs rather than bare `.tres` files, and the path
## to actually load is the original name with the `.remap` suffix stripped. PonyRegistry's
## much longer comment on that bug is worth reading; it shipped once and emptied the whole
## roster in a build that still printed a green marker.
##
## WHAT IS OWED, AND NOTHING ELSE. due() is the whole of "which letters should be in her
## mailbox now": a beat whose chapter the story has reached, whose counter has met its
## threshold, and which has not already been posted. Ordering is the ladder's, so a session
## that crosses two thresholds at once posts them in the order they were written rather than
## in whatever order the directory listing produced.
##
## Instance based and constructible with a plain .new(), so a test and a gate each get their
## own; nothing here is a singleton and nothing here caches across processes.

const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryScript := preload("res://systems/story.gd")

## The directory the shipped letters live in. Committed, unlike game/assets/converted/, so
## it is present on every machine and in every export (docs/ci.md section 4).
const STORY_DIR := "res://data/story"

var _by_id: Dictionary = {}
var _ordered: Array[StoryBeat] = []


func load_all(dir: String = STORY_DIR) -> Dictionary:
	_by_id.clear()
	_ordered.clear()
	var da := DirAccess.open(dir)
	if da == null:
		push_error("StoryLibrary.load_all: cannot open directory '%s' (%s)" % [
			dir, error_string(DirAccess.get_open_error())])
		return _by_id

	da.list_dir_begin()
	var seen := {}
	var file_name := da.get_next()
	while file_name != "":
		if not da.current_is_dir():
			var path := _resource_path(dir, file_name)
			if path != "" and not seen.has(path):
				seen[path] = true
				_load_one(path)
		file_name = da.get_next()
	da.list_dir_end()

	_rebuild_order()
	return _by_id


func _resource_path(dir: String, file_name: String) -> String:
	var entry := file_name
	if entry.get_extension() == "remap":
		entry = entry.get_basename()
	var ext := entry.get_extension()
	if ext == "tres" or ext == "res":
		return dir.path_join(entry)
	return ""


func _load_one(path: String) -> void:
	var res: Resource = load(path)
	if res == null or not (res is StoryBeatScript):
		push_error("StoryLibrary.load_all: '%s' did not load as a StoryBeat resource" % path)
		return
	var beat: StoryBeat = res
	if String(beat.id).is_empty():
		push_error("StoryLibrary.load_all: '%s' has an empty id" % path)
		return
	if _by_id.has(beat.id):
		push_error("StoryLibrary.load_all: duplicate id '%s' in '%s'" % [beat.id, path])
		return
	_by_id[beat.id] = beat


## Chapter first, then threshold, then id. The id is the tie break so the order is TOTAL:
## two letters at the same threshold would otherwise be at the mercy of the directory
## listing, and "which arrived first" is a thing the player reads.
func _rebuild_order() -> void:
	var list: Array[StoryBeat] = []
	for key in _by_id:
		list.append(_by_id[key])
	list.sort_custom(func(a: StoryBeat, b: StoryBeat) -> bool:
		if a.chapter_index() != b.chapter_index():
			return a.chapter_index() < b.chapter_index()
		if a.threshold != b.threshold:
			return a.threshold < b.threshold
		return String(a.id) < String(b.id))
	_ordered = list


func all() -> Array[StoryBeat]:
	return _ordered.duplicate()


## The beat under `id`, or NULL. Null is a supported answer: a save naming a letter this
## build no longer carries must not take the load down. See ShopRegistry.by_id().
func by_id(id: StringName) -> StoryBeat:
	return _by_id.get(id, null)


## Every letter `story` is owed right now, in ladder order. A beat whose chapter or trigger
## this build does not have is skipped here and failed loudly by the story gate, rather than
## being posted as a letter nobody can read.
func due(story: Story) -> Array[StoryBeat]:
	var out: Array[StoryBeat] = []
	if story == null:
		return out
	for beat: StoryBeat in _ordered:
		var chapter: int = beat.chapter_index()
		var kind: int = beat.trigger_index()
		if chapter < 0 or kind < 0:
			continue
		if chapter > story.chapter:
			continue
		if story.has_mail(beat.id):
			continue
		if story.counter(kind) < beat.threshold:
			continue
		out.append(beat)
	return out
```

- [ ] **Step 5: Author one letter so the library has something to load**

Create `game/data/story/sunny_mailbox.tres`:

```
[gd_resource type="Resource" script_class="StoryBeat" load_steps=2 format=3]

[ext_resource type="Script" path="res://systems/story_beat.gd" id="1_beat"]

[resource]
script = ExtResource("1_beat")
id = &"sunny_mailbox"
chapter = &"SUNNY"
trigger = &"CHAPTER"
threshold = 0
sender = "Cloudsdale Weather Corporation"
title = "Your mailbox is installed"
body = PackedStringArray("Dear {name},", "", "Your ranch now has a Company mailbox by the", "door. Everything we send lands in it: receipts,", "notices, and the occasional questionnaire.", "", "The flag goes up when something is waiting.", "Do read them. We put a lot of care into them!", "", "Warmly, Sponsorship Services")
reveals = PackedStringArray()
evidence = false
reply = &"NONE"
```

- [ ] **Step 6: Import, run the tests, watch them pass**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story_beat.gd -gexit
```

Expected: PASS, 9 tests. `test_a_directory_that_is_not_there_is_reported_and_answers_empty` prints one expected engine error; GUT counts it, and if the run fails on an unexpected error, wrap that one call with GUT's error trapping the way the neighbouring suites do.

- [ ] **Step 7: Whole suite and the ranch gate**

```bash
bash tools/run_tests.sh
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```

Expected: suite green; `RANCH_OK ponies=49 props=110 assets=present`.

- [ ] **Step 8: Commit**

```bash
git add game/systems/story_beat.gd game/systems/story_beat.gd.uid \
  game/systems/story_library.gd game/systems/story_library.gd.uid \
  game/data/story/sunny_mailbox.tres game/data/story/sunny_mailbox.tres.uid \
  game/test/test_story_beat.gd game/test/test_story_beat.gd.uid
git commit -m "feat: a letter is a resource and the library says which are owed"
```

---

## Task 3: The corpus. SUNNY and WEATHER in full, plus the Company ladder's letters

**Files:**
- Create: `game/data/story/sunny_first_receipt.tres`, `sunny_quota_note.tres`, `sunny_named_thanks.tres`
- Create: `game/data/story/weather_survey.tres`, `weather_yield.tres`, `weather_colour_receipt.tres`, `weather_requisition.tres`, `weather_quota_notice.tres`, `weather_wellbeing.tres`, `weather_top_partner.tres`
- Create: `game/data/story/company_promotion.tres`, `company_grade_two.tres`, `company_grade_three.tres`, `company_tour_invite.tres`
- Create: `game/test/test_story_corpus.gd`
- Test: `game/test/test_story_corpus.gd`

**Interfaces:**
- Consumes: `StoryBeat` fields and `render()`, `StoryLibrary.load_all()/all()/due()`, `Story` counters and `Chapter`/`Trigger` (Tasks 1 and 2). `Letters.LINE_WIDTH` (58) and `Letters.MAX_NAME_LENGTH` (16) from `game/systems/letters.gd`.
- Produces: the shipped letter corpus. Ids other tasks name by hand: `sunny_mailbox`, `weather_survey`, `weather_requisition`.

### Pacing, which is a requirement and not a preference

The spec's Pacing section puts the first collection day one real hour in (three cycles), the first named pony minutes in, and the fork three to five sessions in. The thresholds below are chosen so a normal player gets **at least one new letter every session for the first five sessions**, and so **no chapter turns silently**: `SUNNY` opens with `sunny_mailbox` and `WEATHER` opens with `weather_survey`, both on the `CHAPTER` trigger, so arriving in a chapter always puts something in the mailbox.

| id | chapter | trigger | threshold | when a normal player sees it |
|---|---|---|---|---|
| `sunny_mailbox` | SUNNY | CHAPTER | 0 | first boot |
| `sunny_first_receipt` | SUNNY | DELIVERIES | 1 | first delivery, session 1 |
| `sunny_named_thanks` | SUNNY | NAMED_DELIVERIES | 1 | first named delivery |
| `sunny_quota_note` | SUNNY | COLLECTION_DAYS | 1 | end of session 1 |
| `weather_survey` | WEATHER | CHAPTER | 0 | third delivery, session 2 |
| `weather_yield` | WEATHER | DELIVERIES | 5 | session 2 or 3 |
| `weather_colour_receipt` | WEATHER | NAMED_DELIVERIES | 2 | second named delivery |
| `weather_requisition` | WEATHER | SURVEY_DAYS | 2 | two collection days after she answers |
| `weather_quota_notice` | WEATHER | COLLECTION_DAYS | 3 | session 3 |
| `weather_wellbeing` | WEATHER | COLLECTION_DAYS | 4 | session 4 |
| `weather_top_partner` | WEATHER | NAMED_DELIVERIES | 3 | session 5 |
| `company_promotion` | COMPANY | CHAPTER | 0 | slice 4 |
| `company_grade_two` | COMPANY | DELIVERIES | 12 | slice 4 |
| `company_grade_three` | COMPANY | DELIVERIES | 20 | slice 4 |
| `company_tour_invite` | COMPANY | DELIVERIES | 30 | slice 4 and 6 |

- [ ] **Step 1: Write the failing test**

Create `game/test/test_story_corpus.gd`:

```gdscript
extends GutTest
## THE SHIPPED LETTERS THEMSELVES. Everything in game/data/story/ is checked here as a body
## of writing: it fits the panel, it names a chapter and a trigger this build has, it never
## says the word this project does not use, and it never carries a dash. The gate
## (game/scenes/test/story_test.gd) repeats the structural half against the real ranch; this
## is the fast one that runs on every commit.

const StoryScript := preload("res://systems/story.gd")
const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryLibraryScript := preload("res://systems/story_library.gd")
const LettersScript := preload("res://systems/letters.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")

const PONY_DIR := "res://data/ponies"

var _library: StoryLibrary


func before_each() -> void:
	_library = StoryLibraryScript.new()
	_library.load_all()


## The widest name the creation screen accepts, in the widest glyph, and the longest pony
## name a receipt can carry. Every letter has to fit with both in it.
func _worst_params() -> Dictionary:
	return {
		"name": "W".repeat(LettersScript.MAX_NAME_LENGTH),
		"pony": "Wwwwwwwwwwwwwwww",
		"colour": "viridian",
		"count": 999,
		"quota": 12,
		"balance": 40000,
	}


func test_the_corpus_is_not_empty_and_every_id_is_unique() -> void:
	var beats: Array[StoryBeat] = _library.all()
	assert_gt(beats.size(), 12, "SUNNY, WEATHER and the Company ladder are all authored")
	var seen := {}
	for beat: StoryBeat in beats:
		assert_false(seen.has(beat.id), "duplicate id %s" % String(beat.id))
		seen[beat.id] = true


func test_every_beat_names_a_chapter_a_trigger_and_a_reply_this_build_has() -> void:
	for beat: StoryBeat in _library.all():
		assert_gte(beat.chapter_index(), 0, "%s: unknown chapter %s" % [beat.id, beat.chapter])
		assert_gte(beat.trigger_index(), 0, "%s: unknown trigger %s" % [beat.id, beat.trigger])
		assert_gte(beat.reply_index(), 0, "%s: unknown reply %s" % [beat.id, beat.reply])
		assert_gte(beat.threshold, 0, "%s: a negative threshold can never be met" % beat.id)


func test_every_beat_has_a_sender_a_title_and_a_body() -> void:
	for beat: StoryBeat in _library.all():
		assert_false(beat.sender.is_empty(), "%s has no sender" % beat.id)
		assert_false(beat.title.is_empty(), "%s has no title" % beat.id)
		assert_gt(beat.body_lines().size(), 2, "%s is not a letter" % beat.id)


func test_no_beat_carries_an_em_dash_or_a_double_hyphen() -> void:
	for beat: StoryBeat in _library.all():
		var letter: Dictionary = beat.render(_worst_params())
		var joined: String = String(letter["title"]) + "\n" + "\n".join(letter["body"])
		assert_false(joined.contains("--"), "%s carries a double hyphen" % beat.id)
		assert_false(joined.contains(char(0x2014)), "%s carries an em dash" % beat.id)


func test_no_beat_uses_the_word_this_project_does_not_use() -> void:
	for beat: StoryBeat in _library.all():
		var letter: Dictionary = beat.render(_worst_params())
		var joined: String = (String(letter["title"]) + "\n"
			+ "\n".join(letter["body"])).to_lower()
		assert_false(joined.contains("killed"), "%s says it out loud" % beat.id)
		assert_false(joined.contains("kill"), "%s says it out loud" % beat.id)
		assert_false(joined.contains("dead"), "%s says it out loud" % beat.id)


func test_every_letter_fits_the_panel_with_the_longest_legal_name_in_it() -> void:
	for beat: StoryBeat in _library.all():
		var letter: Dictionary = beat.render(_worst_params())
		for line in letter["body"]:
			assert_lte(String(line).length(), LettersScript.LINE_WIDTH,
				"%s overflows on '%s'" % [beat.id, line])


func test_no_letter_renders_an_unfilled_placeholder() -> void:
	for beat: StoryBeat in _library.all():
		var letter: Dictionary = beat.render({})
		var joined: String = String(letter["title"]) + "\n" + "\n".join(letter["body"])
		assert_false(joined.contains("{"), "%s has a placeholder nothing fills" % beat.id)


func test_every_revealed_id_is_a_character_this_build_carries() -> void:
	var registry = PonyRegistryScript.new()
	registry.load_all(PONY_DIR)
	for beat: StoryBeat in _library.all():
		for revealed in beat.reveals:
			assert_not_null(registry.by_id(StringName(String(revealed))),
				"%s reveals '%s', who is not on the roster" % [beat.id, revealed])


func test_each_chapter_opens_with_something_to_read() -> void:
	var openers := {}
	for beat: StoryBeat in _library.all():
		if beat.trigger_index() == StoryScript.Trigger.CHAPTER and beat.threshold == 0:
			openers[beat.chapter_index()] = true
	assert_true(openers.has(StoryScript.Chapter.SUNNY), "SUNNY opens with a letter")
	assert_true(openers.has(StoryScript.Chapter.WEATHER), "WEATHER opens with a letter")


func test_a_fresh_ranch_is_owed_exactly_the_opening_letter() -> void:
	var story = StoryScript.new()
	var owed: Array[StoryBeat] = _library.due(story)
	assert_eq(owed.size(), 1, "one letter on the doormat, not five")
	assert_eq(owed[0].id, &"sunny_mailbox")


func test_the_first_five_sessions_each_bring_at_least_one_letter() -> void:
	# A session, per the spec's Pacing section: three cycles, one collection day, a handful
	# of deliveries, one of them named every other session.
	var story = StoryScript.new()
	for beat: StoryBeat in _library.due(story):
		story.post(beat.id)
	for session in range(1, 6):
		story.note_delivery(false, "Pony", &"")
		story.note_delivery(session % 2 == 1, "Trixie", &"trixie")
		story.note_collection_day()
		story.advance()
		var owed: Array[StoryBeat] = _library.due(story)
		assert_gt(owed.size(), 0, "session %d brought no post at all" % session)
		for beat: StoryBeat in owed:
			story.post(beat.id)


func test_the_survey_is_the_first_thing_weather_puts_in_the_mailbox() -> void:
	var story = StoryScript.new()
	for i in range(StoryScript.WEATHER_DELIVERIES):
		story.note_delivery(false, "Pony", &"")
	assert_true(story.advance())
	var owed: Array[StoryBeat] = _library.due(story)
	var ids: Array[StringName] = []
	for beat: StoryBeat in owed:
		ids.append(beat.id)
	assert_true(&"weather_survey" in ids, "the chapter that starts the crack starts it")


func test_the_requisition_never_comes_due_until_the_survey_is_answered() -> void:
	var story = StoryScript.new()
	for i in range(StoryScript.WEATHER_DELIVERIES):
		story.note_delivery(false, "Pony", &"")
	story.advance()
	for i in range(20):
		story.note_collection_day()
		for beat: StoryBeat in _library.due(story):
			assert_ne(beat.id, &"weather_requisition",
				"an unanswered Survey never fires the beat")
			story.post(beat.id)


func test_answering_the_survey_brings_the_requisition_two_collection_days_later() -> void:
	var story = StoryScript.new()
	for i in range(StoryScript.WEATHER_DELIVERIES):
		story.note_delivery(false, "Pony", &"")
	story.advance()
	for beat: StoryBeat in _library.due(story):
		story.post(beat.id)
	story.answer_survey({"uid": "u1", "data_id": "trixie", "name": "Trixie", "coat": ""})
	story.note_collection_day()
	var ids_after_one: Array[StringName] = []
	for beat: StoryBeat in _library.due(story):
		ids_after_one.append(beat.id)
	assert_false(&"weather_requisition" in ids_after_one, "not the very next morning")
	story.note_collection_day()
	var ids_after_two: Array[StringName] = []
	for beat: StoryBeat in _library.due(story):
		ids_after_two.append(beat.id)
	assert_true(&"weather_requisition" in ids_after_two, "some collection days later")


func test_the_survey_is_the_only_letter_in_this_slice_that_asks_for_an_answer() -> void:
	for beat: StoryBeat in _library.all():
		if beat.chapter_index() > StoryScript.Chapter.WEATHER:
			continue
		if beat.reply_index() == StoryBeatScript.Reply.NONE:
			continue
		assert_eq(beat.id, &"weather_survey",
			"%s asks a question nothing in this slice can answer" % beat.id)
		assert_eq(beat.reply_index(), StoryBeatScript.Reply.PICK_PONY)


func test_the_requisition_and_the_colour_receipt_name_the_pony_they_are_about() -> void:
	var requisition: StoryBeat = _library.by_id(&"weather_requisition")
	assert_not_null(requisition)
	assert_true("\n".join(requisition.body_lines()).contains("{pony}"))
	var receipt: StoryBeat = _library.by_id(&"weather_colour_receipt")
	assert_not_null(receipt)
	var receipt_body: String = "\n".join(receipt.body_lines())
	assert_true(receipt_body.contains("{pony}"))
	assert_true(receipt_body.contains("{colour}"),
		"the receipt that lists her beside a colour")


func test_the_company_ladder_is_authored_and_unreachable_in_this_slice() -> void:
	var story = StoryScript.new()
	for i in range(200):
		story.note_delivery(true, "Trixie", &"trixie")
		story.note_collection_day()
		story.advance()
	assert_eq(story.chapter, StoryScript.Chapter.WEATHER, "the ladder stops here for now")
	for beat: StoryBeat in _library.due(story):
		assert_lte(beat.chapter_index(), StoryScript.Chapter.WEATHER)
	var ladder := 0
	for beat: StoryBeat in _library.all():
		if beat.chapter_index() == StoryScript.Chapter.COMPANY:
			ladder += 1
	assert_gte(ladder, 4, "the Company's letters are written and waiting for slice 4")
```

- [ ] **Step 2: Run it and watch it fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story_corpus.gd -gexit
```

Expected: failures on corpus size, on the missing ids, and on pacing.

- [ ] **Step 3: Author the thirteen letters**

Every file below is a complete `.tres`. **Each one begins with these three lines**, then the `[resource]` block given for it:

```
[gd_resource type="Resource" script_class="StoryBeat" load_steps=2 format=3]

[ext_resource type="Script" path="res://systems/story_beat.gd" id="1_beat"]
```

`game/data/story/sunny_first_receipt.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"sunny_first_receipt"
chapter = &"SUNNY"
trigger = &"DELIVERIES"
threshold = 1
sender = "Cloudsdale Weather Corporation"
title = "Thank you for your first shipment"
body = PackedStringArray("Dear {name},", "", "Your first shipment arrived safe and sound.", "Condition on arrival: excellent.", "Processing: routine.", "", "Credit has been applied to your balance, and a", "little note has been made in your file.", "", "Partners who ship early ship often!", "", "Warmly, Intake")
reveals = PackedStringArray()
evidence = false
reply = &"NONE"
```

`game/data/story/sunny_named_thanks.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"sunny_named_thanks"
chapter = &"SUNNY"
trigger = &"NAMED_DELIVERIES"
threshold = 1
sender = "Cloudsdale Weather Corporation"
title = "A registered arrival, and our thanks"
body = PackedStringArray("Dear {name},", "", "{pony} arrived this morning and was logged as a", "registered arrival. What a find!", "", "Shipment quality: excellent.", "Registered arrivals are worth a great deal more", "to us than unregistered stock, as your balance", "will already have noticed.", "", "Do keep an eye out for more like her.", "", "Warmly, Intake")
reveals = PackedStringArray()
evidence = false
reply = &"NONE"
```

`game/data/story/sunny_quota_note.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"sunny_quota_note"
chapter = &"SUNNY"
trigger = &"COLLECTION_DAYS"
threshold = 1
sender = "Cloudsdale Weather Corporation"
title = "Your first collection day"
body = PackedStringArray("Dear {name},", "", "Collection day has come and gone, and we have", "added this period's upkeep to your account.", "", "We expect {quota} ponies each period. Bits settle the", "service charges; the principal is settled in", "stock. It is all in the statement at the Depot.", "", "No pressure at all. Partners who meet quota", "sleep so much better!", "", "Yours in weather, Sponsorship Services")
reveals = PackedStringArray()
evidence = false
reply = &"NONE"
```

`game/data/story/weather_survey.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"weather_survey"
chapter = &"WEATHER"
trigger = &"CHAPTER"
threshold = 0
sender = "Cloudsdale Weather Corporation"
title = "Employee Appreciation Survey"
body = PackedStringArray("Dear {name},", "", "You work so hard, and we do notice.", "One question, and it is not a difficult one.", "", "Which of your ponies is most special to you?", "", "Answer below and we will add 50 bits to your", "account, with a coupon for three bales of hay", "by way of thanks.", "", "Answering is entirely optional.", "", "With appreciation, Partner Wellbeing")
reveals = PackedStringArray()
evidence = false
reply = &"PICK_PONY"
```

`game/data/story/weather_yield.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"weather_yield"
chapter = &"WEATHER"
trigger = &"DELIVERIES"
threshold = 5
sender = "Cloudsdale Weather Corporation"
title = "Your quarterly performance summary"
body = PackedStringArray("Dear {name},", "", "Shipments received from your ranch: {count}.", "Yield: 94%. Spectra grade: A.", "Loss: negligible and within guidance.", "", "We are not able to explain the yield figure in", "writing, but you may take it as a compliment.", "", "Weather across the region has never looked", "better, and a good deal of that is yours.", "", "Warmly, Yield Assurance")
reveals = PackedStringArray()
evidence = true
reply = &"NONE"
```

`game/data/story/weather_colour_receipt.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"weather_colour_receipt"
chapter = &"WEATHER"
trigger = &"NAMED_DELIVERIES"
threshold = 2
sender = "Cloudsdale Weather Corporation"
title = "Receipt: registered arrival"
body = PackedStringArray("Dear {name},", "", "Received, processed and filed, with thanks:", "", "   {pony} ............ {colour}", "", "Credit has been applied to your balance.", "Our floor supervisor says she came out", "beautifully, which is high praise from him.", "", "Warmly, Intake")
reveals = PackedStringArray()
evidence = true
reply = &"NONE"
```

`game/data/story/weather_requisition.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"weather_requisition"
chapter = &"WEATHER"
trigger = &"SURVEY_DAYS"
threshold = 2
sender = "Cloudsdale Weather Corporation"
title = "Priority Requisition"
body = PackedStringArray("Dear {name},", "", "Thank you for your survey response!", "", "Following it, {pony} has been selected for", "priority handling. A collector will call at dawn", "and walk her over himself.", "", "The bonus schedule is attached and is generous.", "No action is required from you at all.", "", "Yours in weather, Logistics")
reveals = PackedStringArray()
evidence = true
reply = &"NONE"
```

`game/data/story/weather_quota_notice.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"weather_quota_notice"
chapter = &"WEATHER"
trigger = &"COLLECTION_DAYS"
threshold = 3
sender = "Cloudsdale Weather Corporation"
title = "A friendly reminder"
body = PackedStringArray("Dear {name},", "", "Ponies expected this period: {quota}.", "Ponies received this period: 0.", "Ponies processed this period: 3.", "", "Our figures balance, so there is nothing at all", "for you to do about this notice.", "", "Thank you for choosing Cloudsdale!", "", "Yours in weather, Sponsorship Services")
reveals = PackedStringArray()
evidence = true
reply = &"NONE"
```

`game/data/story/weather_wellbeing.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"weather_wellbeing"
chapter = &"WEATHER"
trigger = &"COLLECTION_DAYS"
threshold = 4
sender = "Cloudsdale Weather Corporation"
title = "Looking after yourself"
body = PackedStringArray("Dear {name},", "", "A note from Partner Wellbeing.", "", "Some partners tell us they think about where", "the shipments go. We understand completely.", "", "The answer is: weather. Rain for the orchards,", "storms for the reservoirs, and rainbows for", "everypony. That is the whole of it.", "", "Sleep well. You have earned it.", "", "With appreciation, Partner Wellbeing")
reveals = PackedStringArray()
evidence = true
reply = &"NONE"
```

`game/data/story/weather_top_partner.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"weather_top_partner"
chapter = &"WEATHER"
trigger = &"NAMED_DELIVERIES"
threshold = 3
sender = "Cloudsdale Weather Corporation"
title = "Top of the board"
body = PackedStringArray("Dear {name},", "", "Three registered arrivals from one ranch!", "", "You are on the regional board this period, in", "gold lettering, above a photograph of the", "intake floor that we have cropped rather", "carefully.", "", "Keep going. The weather has never been better.", "", "Warmly, Sponsorship Services")
reveals = PackedStringArray()
evidence = true
reply = &"NONE"
```

`game/data/story/company_promotion.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"company_promotion"
chapter = &"COMPANY"
trigger = &"CHAPTER"
threshold = 0
sender = "Cloudsdale Weather Corporation"
title = "A promotion, and our thanks"
body = PackedStringArray("Dear {name},", "", "Thank you for your report. The irregular", "employee has been processed and her access has", "been withdrawn.", "", "Please accept the enclosed promotion. Yield is", "up across the region this month, and we both", "know who to thank for it.", "", "Warmly, Sponsorship Services")
reveals = PackedStringArray()
evidence = false
reply = &"NONE"
```

`game/data/story/company_grade_two.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"company_grade_two"
chapter = &"COMPANY"
trigger = &"DELIVERIES"
threshold = 12
sender = "Cloudsdale Weather Corporation"
title = "Grade two, and a warmer welcome"
body = PackedStringArray("Dear {name},", "", "Your account has been raised to grade two.", "Yield attributable to your ranch: 6%.", "", "Market discounts apply from today, and the", "Palace has been told to look after you.", "", "You are one of our very favourite partners.", "", "Warmly, Sponsorship Services")
reveals = PackedStringArray()
evidence = false
reply = &"NONE"
```

`game/data/story/company_grade_three.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"company_grade_three"
chapter = &"COMPANY"
trigger = &"DELIVERIES"
threshold = 20
sender = "Cloudsdale Weather Corporation"
title = "Grade three, and a bounty list"
body = PackedStringArray("Dear {name},", "", "Grade three. Yield attributable: 11%.", "", "Enclosed: comps at the Palace, and a list of", "registered arrivals we would particularly like", "to see. The bonuses on it are not small.", "", "We think of you as family, and we mean that in", "the way you would prefer.", "", "Warmly, Sponsorship Services")
reveals = PackedStringArray()
evidence = false
reply = &"NONE"
```

`game/data/story/company_tour_invite.tres`:

```
[resource]
script = ExtResource("1_beat")
id = &"company_tour_invite"
chapter = &"COMPANY"
trigger = &"DELIVERIES"
threshold = 30
sender = "Cloudsdale Weather Corporation"
title = "An invitation to the facility"
body = PackedStringArray("Dear {name},", "", "Grade four opens a door most partners never", "see. We would like to show you the facility.", "", "A guide will meet you at the Depot. The tour", "takes an hour and covers every room.", "", "Wear something warm; the intake floor runs", "cool, for reasons the guide will explain.", "", "Warmly, Sponsorship Services")
reveals = PackedStringArray()
evidence = false
reply = &"NONE"
```

- [ ] **Step 4: Import and run the corpus tests**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story_corpus.gd -gexit
```

Expected: PASS, 17 tests. If a line overflows `LINE_WIDTH` 58, shorten that line in the `.tres`; do not raise the constant, and do not let a body line run past the panel.

- [ ] **Step 5: Whole suite and the ranch gate**

```bash
bash tools/run_tests.sh
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```

- [ ] **Step 6: Commit**

```bash
git add game/data/story game/test/test_story_corpus.gd game/test/test_story_corpus.gd.uid
git commit -m "feat: the Company's post, SUNNY through WEATHER, with the ladder written ahead"
```

---

## Task 4: The Mail page, drawn as stationery

**Files:**
- Create: `game/ui/paper_paint.gd`
- Create: `game/test/test_paper_paint.gd`
- Modify: `game/ui/pause_menu.tscn` (one new `Stage` `Control` in `Column`, between `Title` and `Rows`)
- Modify: `game/ui/pause_menu.gd` (`Page`, `Row`, `MAIN_ROWS`, providers, signals, the MAIL page, the stage)
- Test: `game/test/test_paper_paint.gd`, `game/test/test_pause_menu.gd`

**Interfaces:**
- Consumes: `MenuStyle` (`panel_style`, `apply_panel`, `apply_title`, `style_label`, `rule`, `title_font`, `numeral_font`, `footer*`, the palette, `TITLE_SIZE`/`ROW_SIZE`/`SUBTITLE_SIZE`/`FOOTER_SIZE`), `CasinoPaint` (`rounded`, `text`, `ellipse`, `focus_ring`, `star_points`), `StoryBeat.Reply` (Task 2), which the page preloads by path for the enum alone.
- Produces:
  - `PaperPaint.PAPER/PAPER_EDGE/INK/INK_DIM/COMPANY_BAND/COMPANY_TRIM/WAX/STAMP_INK: Color`
  - `PaperPaint.logo_points(box: Rect2) -> PackedVector2Array`, `bolt_points(box: Rect2) -> PackedVector2Array`
  - `PaperPaint.sheet(ci, rect)`, `letterhead(ci, rect, font, sender)`, `envelope(ci, rect, font, sender, title, unread, picked, t)`, `stamp(ci, rect, font, word)`, `coupon(ci, rect, font, line)`
  - `PauseMenu.Page.MAIL`, `PauseMenu.Row.MAIL`, `mail_provider`, `mail_ponies_provider`, signals `mail_opened(id: StringName)` and `mail_reply(id: StringName, choice: String)`
  - `PauseMenu.mail_rows() -> Array[Dictionary]`, `open_letter(id: StringName) -> bool`, `close_letter() -> void`, `open_letter_id() -> StringName`, `letter_lines() -> Array[String]`, `reply_rows() -> Array[Dictionary]`, `mail_lines() -> Array[String]`
- Row shape the provider must answer (built by `ranch.gd` in Task 6): `{"id": String, "sender": String, "title": String, "body": Array[String], "read": bool, "replied": String, "reply": int}` where `reply` is a `StoryBeat.Reply` value. Picker shape: `{"uid": String, "name": String, "coat": String}`.

- [ ] **Step 1: Write the failing tests for the kit**

Create `game/test/test_paper_paint.gd`:

```gdscript
extends GutTest
## THE STATIONERY KIT. Every shape is a pure *_points() function with a three line draw_*
## half, the same split game/ui/casino_paint.gd is built on and for the same reason: drawn
## art is only testable headlessly if the geometry can be asked for without a canvas.

const PaperPaintScript := preload("res://ui/paper_paint.gd")

const BOX := Rect2(0.0, 0.0, 100.0, 60.0)


func test_the_company_mark_is_a_closed_cloud_inside_its_box() -> void:
	var points: PackedVector2Array = PaperPaintScript.logo_points(BOX)
	assert_gt(points.size(), 8, "a cloud is not a triangle")
	for p: Vector2 in points:
		assert_true(BOX.has_point(p), "the mark stays inside the box it was handed: %s" % p)


func test_the_bolt_is_a_polygon_inside_its_box() -> void:
	var points: PackedVector2Array = PaperPaintScript.bolt_points(BOX)
	assert_gte(points.size(), 6)
	for p: Vector2 in points:
		assert_true(BOX.has_point(p))


func test_the_mark_scales_with_its_box_rather_than_assuming_one() -> void:
	var small: PackedVector2Array = PaperPaintScript.logo_points(Rect2(0, 0, 10, 6))
	var large: PackedVector2Array = PaperPaintScript.logo_points(Rect2(0, 0, 100, 60))
	assert_eq(small.size(), large.size())
	for i in small.size():
		assert_almost_eq(large[i].x, small[i].x * 10.0, 0.001)
		assert_almost_eq(large[i].y, small[i].y * 10.0, 0.001)


func test_the_palette_reads_as_paper_and_not_as_felt() -> void:
	assert_gt(PaperPaintScript.PAPER.get_luminance(), 0.7, "paper is pale")
	assert_lt(PaperPaintScript.INK.get_luminance(), 0.2, "ink is dark")
	assert_gt(PaperPaintScript.PAPER.a, 0.9, "a letter is opaque; the panel behind it is not")


func test_nothing_in_the_kit_rolls_anything() -> void:
	var source: String = FileAccess.get_file_as_string("res://ui/paper_paint.gd")
	assert_false(source.contains("RandomNumberGenerator"), "no RNG under game/ui/")
	assert_false(source.contains("randi"), "no RNG under game/ui/")
	assert_false(source.contains("randf"), "no RNG under game/ui/")


func test_no_line_of_the_kit_carries_a_dash() -> void:
	var source: String = FileAccess.get_file_as_string("res://ui/paper_paint.gd")
	for line in source.split("\n"):
		var text: String = String(line)
		if text.begins_with("# ---") or text.begins_with("## ---"):
			continue
		assert_false(text.contains("--"), "double hyphen: %s" % text)
		assert_false(text.contains(char(0x2014)), "em dash: %s" % text)
```

- [ ] **Step 2: Run it and watch it fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_paper_paint.gd -gexit
```

Expected: failures, the script does not exist.

- [ ] **Step 3: Write `game/ui/paper_paint.gd`**

```gdscript
class_name PaperPaint
extends RefCounted
## THE STATIONERY KIT: paper, a letterhead, an envelope card, a rubber stamp and a coupon,
## drawn straight onto a CanvasItem. The casino got a felt and chip kit
## (game/ui/casino_paint.gd) and the mail gets this one, built ON that kit's primitives
## (rounded, text, ellipse, focus_ring) rather than beside them, so there is one rounded
## rectangle and one outlined string in the whole game.
##
## THE SPLIT IS THE SAME AS THE CASINO'S. Every shape is a pure *_points() function against
## a normalised box plus a three line draw_* half, so game/test/test_paper_paint.gd can
## assert that the Company's mark is closed and inside its box without a viewport.
##
## NOTHING HERE ROLLS ANYTHING, and nothing here reads game state: a kit that could produce
## two different pages from the same arguments is a kit no screenshot proves anything about.
##
## draw_* CALLS ARE LEGAL ONLY INSIDE A NOTIFICATION_DRAW CONTEXT, which in this project
## means inside the function connected to a Control's `draw` signal. Every function here
## takes that CanvasItem as its first argument for exactly that reason.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const PaintScript := preload("res://ui/casino_paint.gd")

## THE PAPER. Warm off white at full opacity, over the translucent navy panel every menu in
## the game sits on, so a letter reads as a sheet laid on the table rather than as a lighter
## patch of the table.
const PAPER := Color(0.96, 0.94, 0.88, 0.97)
const PAPER_EDGE := Color(0.72, 0.68, 0.58, 0.90)
const PAPER_SHADOW := Color(0.0, 0.0, 0.0, 0.28)

## THE INK. Dark, not black: printed text on cream is never pure black, and the difference
## is most of why a page reads as printed.
const INK := Color(0.13, 0.12, 0.15, 1.0)
const INK_DIM := Color(0.13, 0.12, 0.15, 0.62)

## THE COMPANY'S OWN COLOURS, taken from the Depot's walls in game/world/ranch.tscn
## (Color(0.62, 0.64, 0.68) over Color(0.3, 0.34, 0.4)) so the letterhead on the page and
## the building on the map are the same company.
const COMPANY_BAND := Color(0.20, 0.24, 0.34, 1.0)
const COMPANY_TRIM := Color(0.62, 0.64, 0.68, 1.0)

## The unread mark on an envelope card: a blob of sealing wax.
const WAX := Color(0.78, 0.20, 0.22, 1.0)

## The rubber stamp a letter carries once it has been answered, and the coupon's ink.
const STAMP_INK := Color(0.36, 0.16, 0.42, 0.85)

const SHEET_RADIUS := 10.0
const CARD_RADIUS := 8.0
const SHADOW_OFFSET := Vector2(3.0, 4.0)

## The cloud in the Company's mark, as a closed polygon: three lobes over a flat base.
## Authored against the normalised box it is handed, so it works at 22 px on an envelope
## card and at 60 px on a letterhead.
const _CLOUD: Array[Vector2] = [
	Vector2(0.08, 0.72), Vector2(0.10, 0.52), Vector2(0.20, 0.42), Vector2(0.26, 0.26),
	Vector2(0.42, 0.18), Vector2(0.58, 0.24), Vector2(0.68, 0.16), Vector2(0.84, 0.26),
	Vector2(0.90, 0.44), Vector2(0.94, 0.60), Vector2(0.90, 0.72), Vector2(0.50, 0.76),
]

## The bolt under it. Two strokes of a zigzag, closed.
const _BOLT: Array[Vector2] = [
	Vector2(0.52, 0.60), Vector2(0.40, 0.92), Vector2(0.50, 0.88), Vector2(0.44, 0.98),
	Vector2(0.62, 0.74), Vector2(0.52, 0.76),
]


static func _at(box: Rect2, point: Vector2) -> Vector2:
	return box.position + Vector2(box.size.x * point.x, box.size.y * point.y)


static func logo_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point: Vector2 in _CLOUD:
		out.append(_at(box, point))
	return out


static func bolt_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point: Vector2 in _BOLT:
		out.append(_at(box, point))
	return out


## The Company's mark: cloud, bolt, no words. The building on the map wears the same one.
static func logo_mark(ci: CanvasItem, box: Rect2, cloud: Color, bolt: Color) -> void:
	ci.draw_colored_polygon(logo_points(box), cloud)
	ci.draw_colored_polygon(bolt_points(box), bolt)


## A SHEET OF PAPER: a soft drop shadow, the paper, and a hairline edge. The shadow is what
## makes it a sheet ON something rather than a rectangle IN something, and it is one extra
## rounded rectangle.
static func sheet(ci: CanvasItem, rect: Rect2) -> void:
	PaintScript.rounded(ci, Rect2(rect.position + SHADOW_OFFSET, rect.size), SHEET_RADIUS,
		PAPER_SHADOW, Color(0, 0, 0, 0), 0.0)
	PaintScript.rounded(ci, rect, SHEET_RADIUS, PAPER, PAPER_EDGE, 1.0)


## THE LETTERHEAD: a band across the top of a sheet, the mark at its left, the sender's name
## beside it, and a trim line under it. This is the one piece that says "the Company wrote
## this" before a word of the body is read.
static func letterhead(ci: CanvasItem, rect: Rect2, font: Font, sender: String) -> void:
	var band := Rect2(rect.position, Vector2(rect.size.x, 54.0))
	PaintScript.rounded(ci, band, SHEET_RADIUS, COMPANY_BAND, COMPANY_TRIM, 1.0)
	logo_mark(ci, Rect2(band.position + Vector2(14.0, 10.0), Vector2(34.0, 34.0)),
		COMPANY_TRIM, Color(0.98, 0.86, 0.45, 1.0))
	PaintScript.text(ci, font, band.position + Vector2(60.0, 36.0), sender,
		MenuStyleScript.SUBTITLE_SIZE, Color(0.94, 0.95, 0.98, 1.0),
		HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 76.0)


## ONE ENVELOPE IN THE LIST: a card, the sender in small dim type, the title in ink, a blob
## of wax while it is unread, and the one focus treatment this game uses when the cursor is
## on it. `t` is the stage's animation phase, so the ring breathes exactly as it does on
## every casino screen.
static func envelope(ci: CanvasItem, rect: Rect2, font: Font, sender: String, title: String,
		unread: bool, picked: bool, t: float) -> void:
	PaintScript.rounded(ci, rect, CARD_RADIUS, PAPER if unread else Color(PAPER, 0.82),
		PAPER_EDGE, 1.0)
	# THE FLAP. Two lines from the top corners to the middle of the top edge: the whole
	# reason a card reads as an envelope rather than as a button.
	var left: Vector2 = rect.position + Vector2(10.0, 2.0)
	var right: Vector2 = rect.position + Vector2(rect.size.x - 10.0, 2.0)
	var point: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.52)
	ci.draw_line(left, point, PAPER_EDGE, 1.0, true)
	ci.draw_line(right, point, PAPER_EDGE, 1.0, true)
	PaintScript.text(ci, font, rect.position + Vector2(16.0, 26.0), sender,
		MenuStyleScript.SUBTITLE_SIZE, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 70.0)
	PaintScript.text(ci, font, rect.position + Vector2(16.0, 52.0), title,
		MenuStyleScript.ROW_SIZE, INK, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 70.0)
	if unread:
		PaintScript.ellipse(ci, rect.position + Vector2(rect.size.x - 28.0, 30.0), 11.0, 11.0,
			WAX, Color(WAX.darkened(0.3), 0.9))
	if picked:
		PaintScript.focus_ring(ci, rect, CARD_RADIUS, t)


## A RUBBER STAMP, for a letter that has been answered. A double border at a slight offset
## and a word inside it, in the ink a stamp pad actually leaves.
static func stamp(ci: CanvasItem, rect: Rect2, font: Font, word: String) -> void:
	PaintScript.rounded(ci, rect, 4.0, Color(STAMP_INK, 0.10), STAMP_INK, 3.0)
	PaintScript.rounded(ci, rect.grow(-5.0), 2.0, Color(0, 0, 0, 0.0), Color(STAMP_INK, 0.7),
		1.0)
	PaintScript.text(ci, font, rect.position + Vector2(0.0, rect.size.y * 0.68), word,
		MenuStyleScript.SUBTITLE_SIZE, STAMP_INK, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


## A COUPON: a ticket with a notch bitten out of each end and one line of text on it. The
## notches are drawn in `behind`, the colour of whatever the coupon is lying on, which is
## how a ticket gets its shape without a second polygon.
static func coupon(ci: CanvasItem, rect: Rect2, font: Font, line: String,
		behind: Color) -> void:
	PaintScript.rounded(ci, rect, 6.0, Color(0.99, 0.97, 0.86, 1.0), STAMP_INK, 2.0)
	var r: float = rect.size.y * 0.22
	PaintScript.ellipse(ci, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5),
		r, r, behind, behind)
	PaintScript.ellipse(ci,
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y * 0.5),
		r, r, behind, behind)
	PaintScript.text(ci, font, rect.position + Vector2(0.0, rect.size.y * 0.66), line,
		MenuStyleScript.SUBTITLE_SIZE, STAMP_INK, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
```

- [ ] **Step 4: Run the kit's tests and watch them pass**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_paper_paint.gd -gexit
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Give the pause menu a stage to draw on**

In `game/ui/pause_menu.tscn`, add one node between `Title` and `Rows` inside `Column`. The whole node block, pasted after the `Title` block:

```
[node name="Stage" type="Control" parent="Centre/Panel/Margin/Column"]
layout_mode = 2
mouse_filter = 2
```

The node order inside `Column` must end up `Title`, `Stage`, `Rows`, `Footer`.

- [ ] **Step 6: Write the failing tests for the page**

Append to `game/test/test_pause_menu.gd`:

```gdscript
# --- the Mail page ---------------------------------------------------------------------

## The rows ranch.gd hands the page, in exactly the shape it builds them in (Task 6's
## Ranch.mail_rows()), so this file tests the page against the contract rather than against
## a story it built for itself.
func _wire_mail() -> void:
	var rows: Array[Dictionary] = [
		{"id": "sunny_mailbox", "sender": "Cloudsdale Weather Corporation",
			"title": "Your mailbox is installed",
			"body": ["Dear Moonbeam,", "", "The flag goes up when something is waiting."],
			"read": true, "replied": "", "reply": 0},
		{"id": "weather_survey", "sender": "Cloudsdale Weather Corporation",
			"title": "Employee Appreciation Survey",
			"body": ["Dear Moonbeam,", "", "Which of your ponies is most special to you?"],
			"read": false, "replied": "", "reply": 1},
	]
	_menu.mail_provider = func() -> Array[Dictionary]: return rows
	_menu.mail_ponies_provider = func() -> Array[Dictionary]:
		return [{"uid": "u1", "name": "Trixie", "coat": ""},
			{"uid": "u2", "name": "Pony", "coat": "Butter"}]


func test_the_mail_page_lists_the_newest_letter_first() -> void:
	_wire_mail()
	_menu.open()
	assert_true(_menu.open_page(PauseMenu.Page.MAIL))
	var rows: Array[Dictionary] = _menu.mail_rows()
	assert_eq(rows.size(), 2)
	assert_eq(String(rows[0]["id"]), "weather_survey", "newest first")
	assert_false(bool(rows[0]["read"]))


func test_a_bare_mail_page_says_so_rather_than_drawing_nothing() -> void:
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	assert_eq(_menu.mail_rows().size(), 0)
	assert_true(PauseMenu.EMPTY_TEXT in _menu.mail_lines())


func test_confirming_on_an_envelope_opens_it_and_says_it_was_opened() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_eq(_menu.open_letter_id(), &"weather_survey")
	assert_signal_emitted_with_parameters(_menu, "mail_opened", [&"weather_survey"])
	var lines: Array[String] = _menu.letter_lines()
	assert_true("Which of your ponies is most special to you?" in lines)


func test_cancel_walks_back_out_of_a_letter_and_then_out_of_the_page() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	_menu.confirm()
	assert_eq(_menu.open_letter_id(), &"weather_survey")
	_menu.back()
	assert_eq(_menu.open_letter_id(), &"", "back closes the letter, not the page")
	assert_eq(_menu.page(), PauseMenu.Page.MAIL)
	_menu.back()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_eq(_menu.selected_index(), PauseMenu.Row.MAIL, "the cursor lands on its own row")


func test_a_letter_with_a_picker_offers_every_pony_she_owns() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	_menu.confirm()
	var rows: Array[Dictionary] = _menu.reply_rows()
	assert_eq(rows.size(), 2)
	assert_eq(String(rows[0]["label"]), "Trixie")
	assert_eq(String(rows[1]["label"]), "Butter Pony", "the crowd share a name; the coat sorts them")
	assert_eq(String(rows[1]["choice"]), "u2")


func test_answering_the_picker_emits_the_choice_once_and_leaves_the_letter() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	_menu.confirm()
	watch_signals(_menu)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "mail_reply", [&"weather_survey", "u2"])
	assert_eq(_menu.open_letter_id(), &"", "answering hands the page back to the list")


func test_a_letter_with_no_reply_control_has_no_rows_to_sit_on() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_eq(_menu.open_letter_id(), &"sunny_mailbox")
	assert_eq(_menu.reply_rows().size(), 0)
	assert_false(_menu.confirm(), "there is nothing on this page to confirm")


func test_the_mail_row_on_main_opens_the_page() -> void:
	_wire_mail()
	_menu.open()
	for i in range(PauseMenu.Row.MAIL):
		_menu.move_selection(1)
	assert_eq(_menu.selected_index(), PauseMenu.Row.MAIL)
	assert_true(_menu.confirm())
	assert_eq(_menu.page(), PauseMenu.Page.MAIL)


func test_nothing_the_mail_page_draws_carries_a_dash() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	var lines: Array[String] = _menu.mail_lines()
	_menu.confirm()
	lines.append_array(_menu.letter_lines())
	for row: Dictionary in _menu.reply_rows():
		lines.append(String(row["label"]))
	for line: String in lines:
		assert_false(line.contains("--"), "double hyphen: %s" % line)
		assert_false(line.contains(char(0x2014)), "em dash: %s" % line)
```

Also fix the existing expectation of seven main rows: `MAIN_ROWS` becomes eight entries. Search `test_pause_menu.gd` for `MAIN_ROWS` and for any literal `7` describing it and update to the new size, keeping the assertions about `Row.RESUME` and `Row.QUIT` as they are.

- [ ] **Step 7: Run it and watch it fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_pause_menu.gd -gexit
```

Expected: failures on `Page.MAIL` not existing.

- [ ] **Step 8: Build the page in `game/ui/pause_menu.gd`**

Add the preloads beside the others:

```gdscript
const PaperPaintScript := preload("res://ui/paper_paint.gd")
const PaintScript := preload("res://ui/casino_paint.gd")
# THE RESOURCE'S OWN ENUM, so reply_rows() matches on a name rather than on the numbers 1
# and 2. This is a data resource, not game state: the page still never learns what a Story
# is, exactly as it preloads CompendiumScript for State without ever owning a Compendium.
const StoryBeatScript := preload("res://systems/story_beat.gd")
```

Replace the two enums and `MAIN_ROWS`:

```gdscript
enum Page { MAIN, SETTINGS, COMPENDIUM, REQUESTS, MAIL, LEDGER }
enum Row { RESUME, COMPENDIUM, REQUESTS, MAIL, LEDGER, SAVE, SETTINGS, QUIT }
enum SettingRow { VOLUME, SENSITIVITY, INVERT }

const MAIN_ROWS := ["Resume", "Compendium", "Requests", "Mail", "The ledger",
	"Save the ranch", "Settings", "Quit to desktop"]
```

Add the page's own constants under `EMPTY_TEXT`:

```gdscript
## THE MAIL PAGE IS DRAWN, NOT PRINTED. The stage is 660 wide: the Panel's 720 minus the
## Margin node's 30 either side, the same arithmetic TableMenu.STAGE_WIDTH does for the
## casino's 1180 wide panels. Every rect on this page is laid out against these numbers.
const MAIL_STAGE_WIDTH := 660.0
const ENVELOPE_HEIGHT := 68.0
const ENVELOPE_GAP := 10.0
const ENVELOPES_ON_SCREEN := 5
const LETTER_LINE_HEIGHT := 26.0
const REPLY_ROW_HEIGHT := 34.0
const REPLY_ROW_GAP := 6.0

## What the Mail page says with nothing in the mailbox yet.
const MAIL_EMPTY_TEXT := "Nothing in the mailbox yet."
```

Add the providers and signals beside the existing ones:

```gdscript
## THE MAIL PAGE'S TWO PROVIDERS, injected by ranch.gd exactly as the five above are. This
## menu never loads a StoryBeat, never renders one and never learns what a Story is: it is
## handed rendered rows and the ponies she owns, and it hands back "she opened this" and
## "she answered this". Same split as every other panel in the game.
var mail_provider := Callable()
var mail_ponies_provider := Callable()

signal mail_opened(id: StringName)
signal mail_reply(id: StringName, choice: String)
```

Add the page's state beside `_scroll`:

```gdscript
## The letter currently open on the MAIL page, or &"" while the list is showing.
var _letter_id: StringName = &""

## Seconds since this menu opened, advanced in _process while it is up. Read by the stage
## for the focus ring's breath, the same field and the same purpose as TableMenu._anim_t.
var _anim_t := 0.0
```

Add the stage handle beside the other `@onready`s:

```gdscript
@onready var _stage: Control = get_node_or_null(^"Centre/Panel/Margin/Column/Stage")
```

In `_ready()`, after `MenuStyleScript.apply_panel(...)`:

```gdscript
	if _stage != null:
		_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.draw.connect(_paint_stage)
	set_process(false)
```

In `open()`, before `_refresh()`, add `_letter_id = &""`, `_anim_t = 0.0` and `set_process(true)`; in `close()`, add `set_process(false)`. In `open_page()`, add `_letter_id = &""` beside `_scroll = 0`.

Add the frame hook:

```gdscript
## THE BREATH ON THE FOCUS RING, and nothing else. The stage is redrawn only while the MAIL
## page is actually up, so a paused ranch with the compendium open costs nothing.
func _process(delta: float) -> void:
	_anim_t += delta
	if _open and _page == Page.MAIL and _stage != null:
		_stage.queue_redraw()
```

Add the page's model, above `# --- drawing`:

```gdscript
# --- the mailbox ---------------------------------------------------------------------------

## Every letter she has been sent, NEWEST FIRST. The provider hands them over oldest first
## (Story.mail is a log), and the list shows the new one at the top, because that is the one
## she came to read. Nothing is ever removed: re-reading old mail is the whole point of the
## paper channel.
func mail_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not mail_provider.is_valid():
		return out
	for entry in mail_provider.call():
		out.append((entry as Dictionary).duplicate(true))
	out.reverse()
	return out


func open_letter_id() -> StringName:
	return _letter_id


## Open the letter with this id. Says so with `mail_opened`, which is how ranch.gd marks it
## read; the menu does not own read state any more than it owns bits.
func open_letter(id: StringName) -> bool:
	for row: Dictionary in mail_rows():
		if StringName(String(row.get("id", ""))) == id:
			_letter_id = id
			_selected = 0
			mail_opened.emit(id)
			_refresh()
			return true
	return false


func close_letter() -> void:
	_letter_id = &""
	_selected = 0
	_refresh()


## The open letter's row, or an empty dictionary.
func _open_row() -> Dictionary:
	for row: Dictionary in mail_rows():
		if StringName(String(row.get("id", ""))) == _letter_id:
			return row
	return {}


## The body of the open letter, line by line. Empty when the list is showing.
func letter_lines() -> Array[String]:
	var row: Dictionary = _open_row()
	if row.is_empty():
		return []
	var out: Array[String] = []
	for line in row.get("body", []):
		out.append(String(line))
	return out


## The rows a reply control offers: {"label": String, "choice": String}. Empty for a letter
## with no reply control, and empty for one already answered, so a bonus cannot be claimed
## twice from the menu side either.
func reply_rows() -> Array[Dictionary]:
	var row: Dictionary = _open_row()
	if row.is_empty():
		return []
	if not String(row.get("replied", "")).is_empty():
		return []
	var out: Array[Dictionary] = []
	match int(row.get("reply", 0)):
		StoryBeatScript.Reply.PICK_PONY:
			if not mail_ponies_provider.is_valid():
				return out
			for entry in mail_ponies_provider.call():
				var pony: Dictionary = entry
				var coat: String = String(pony.get("coat", ""))
				var who: String = String(pony.get("name", ""))
				out.append({
					"label": "%s %s" % [coat, who] if not coat.is_empty() else who,
					"choice": String(pony.get("uid", "")),
				})
		StoryBeatScript.Reply.YES_NO:
			out.append({"label": "Yes", "choice": "yes"})
			out.append({"label": "No", "choice": "no"})
	return out


## THE PAGE'S SEMANTIC MODEL, which survives the drawing rather than being replaced by it.
## The stage paints; this says what is on the page, so a test can sweep it for a dash and a
## stage that failed to instantiate still has something to print. Same rule the casino's
## drawn_lines() follows.
func mail_lines() -> Array[String]:
	if not _letter_id.is_empty():
		var row: Dictionary = _open_row()
		var out: Array[String] = [String(row.get("sender", "")), String(row.get("title", ""))]
		out.append_array(letter_lines())
		for reply: Dictionary in reply_rows():
			out.append(String(reply["label"]))
		return out
	var rows: Array[Dictionary] = mail_rows()
	if rows.is_empty():
		return [EMPTY_TEXT, MAIL_EMPTY_TEXT]
	var lines: Array[String] = []
	for row: Dictionary in rows:
		lines.append("%s   %s" % [String(row.get("title", "")),
			"new" if not bool(row.get("read", false)) else ""])
	return lines
```

Wire the page into `_row_count()`, `confirm()`, `back()` and `_refresh()`:

```gdscript
		Page.MAIL:
			# On the list, one row per envelope. Inside a letter, one row per reply option,
			# and a letter with no reply control has exactly one cursor position: nowhere.
			if _letter_id.is_empty():
				return maxi(1, mail_rows().size())
			return maxi(1, reply_rows().size())
```

in `_row_count()`'s `match`;

```gdscript
	if _page == Page.MAIL:
		if _letter_id.is_empty():
			var rows: Array[Dictionary] = mail_rows()
			if _selected < 0 or _selected >= rows.size():
				return false
			return open_letter(StringName(String(rows[_selected].get("id", ""))))
		var replies: Array[Dictionary] = reply_rows()
		if _selected < 0 or _selected >= replies.size():
			return false
		var answered: StringName = _letter_id
		var choice: String = String(replies[_selected]["choice"])
		close_letter()
		mail_reply.emit(answered, choice)
		return true
```

at the very top of `confirm()`, above the `if _page == Page.SETTINGS:` branch. It returns on its own for every MAIL case, so the existing read only guard (`if _page == Page.COMPENDIUM or _page == Page.REQUESTS or _page == Page.LEDGER: return false`) is left exactly as it is: `Page.MAIL` is deliberately not in it, because the Mail page is the one reading page with something to press;

```gdscript
		Page.MAIL:
			if not _letter_id.is_empty():
				close_letter()
			else:
				_return_to_main(Row.MAIL)
```

in `back()`'s `match`; and in `_refresh()`'s `match`:

```gdscript
			Page.MAIL:
				_draw_mail()
```

and immediately ABOVE that `match`, so the stage takes no room in the column on the five
pages that do not use it:

```gdscript
	# THE STAGE IS THE MAIL PAGE'S AND NOBODY ELSE'S. A Control left visible with a minimum
	# size on the compendium would be a blank band above the roster.
	if _stage != null:
		_stage.visible = _page == Page.MAIL
		if _page != Page.MAIL:
			_stage.custom_minimum_size = Vector2.ZERO
```

- [ ] **Step 9: Paint it**

Add to `game/ui/pause_menu.gd`, at the end of the drawing section:

```gdscript
## THE MAIL PAGE IS THE STAGE. The Rows column prints nothing while a stage is present: the
## page IS the drawing, the way the casino's tables are. A menu instantiated without the
## Stage node (an older scene, a test tree built by hand) falls back to printing
## mail_lines(), so the page is never blank and never a lie about what is in the mailbox.
func _draw_mail() -> void:
	_title.text = "MAIL"
	MenuStyleScript.apply_title(_title)
	_footer.text = _mail_footer()
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	if _stage == null:
		for line in mail_lines():
			_add_note(line)
		return
	_stage.custom_minimum_size = Vector2(MAIL_STAGE_WIDTH, _mail_stage_height())
	_stage.queue_redraw()


func _mail_footer() -> String:
	if _letter_id.is_empty():
		return MenuStyleScript.footer([[&"menu_rows", "choose"], [&"ui_accept", "read"],
			[&"ui_cancel", "back"]])
	if reply_rows().is_empty():
		return MenuStyleScript.footer_reading("back")
	return MenuStyleScript.footer([[&"menu_rows", "choose"], [&"ui_accept", "answer"],
		[&"ui_cancel", "back"]])


func _mail_stage_height() -> float:
	if _letter_id.is_empty():
		var count: int = maxi(1, mini(mail_rows().size(), ENVELOPES_ON_SCREEN))
		return float(count) * (ENVELOPE_HEIGHT + ENVELOPE_GAP) + 12.0
	var lines: int = letter_lines().size()
	var replies: int = reply_rows().size()
	return 96.0 + float(lines) * LETTER_LINE_HEIGHT \
		+ float(replies) * (REPLY_ROW_HEIGHT + REPLY_ROW_GAP) + 40.0


## THE ONLY draw_* CONTEXT IN THIS FILE. Connected to the Stage Control's `draw` signal in
## _ready(), which is what makes these calls legal at all.
func _paint_stage() -> void:
	if _stage == null or _page != Page.MAIL:
		return
	var font: Font = MenuStyleScript.title_font()
	var box := Rect2(Vector2.ZERO, _stage.size)
	if _letter_id.is_empty():
		_paint_envelopes(font, box)
	else:
		_paint_letter(font, box)


func _paint_envelopes(font: Font, box: Rect2) -> void:
	var rows: Array[Dictionary] = mail_rows()
	if rows.is_empty():
		PaperPaintScript.sheet(_stage, Rect2(box.position, Vector2(box.size.x, 84.0)))
		PaintScript.text(_stage, font, box.position + Vector2(24.0, 50.0), MAIL_EMPTY_TEXT,
			MenuStyleScript.ROW_SIZE, PaperPaintScript.INK_DIM, HORIZONTAL_ALIGNMENT_LEFT,
			box.size.x - 48.0)
		return
	# A WINDOW OVER THE LIST, not the whole of it: the mailbox fills up forever and the panel
	# does not. Follows the cursor exactly as the compendium's window does.
	var first: int = clampi(_selected - ENVELOPES_ON_SCREEN + 1, 0,
		maxi(0, rows.size() - ENVELOPES_ON_SCREEN))
	if _selected < first:
		first = _selected
	var y: float = box.position.y + 6.0
	for i in range(first, mini(rows.size(), first + ENVELOPES_ON_SCREEN)):
		var row: Dictionary = rows[i]
		PaperPaintScript.envelope(_stage,
			Rect2(Vector2(box.position.x, y), Vector2(box.size.x, ENVELOPE_HEIGHT)), font,
			String(row.get("sender", "")), String(row.get("title", "")),
			not bool(row.get("read", false)), i == _selected, _anim_t)
		y += ENVELOPE_HEIGHT + ENVELOPE_GAP


func _paint_letter(font: Font, box: Rect2) -> void:
	var row: Dictionary = _open_row()
	PaperPaintScript.sheet(_stage, box)
	PaperPaintScript.letterhead(_stage, box, font, String(row.get("sender", "")))
	var x: float = box.position.x + 28.0
	var width: float = box.size.x - 56.0
	var y: float = box.position.y + 88.0
	PaintScript.text(_stage, font, Vector2(x, y), String(row.get("title", "")),
		MenuStyleScript.TITLE_SIZE, PaperPaintScript.INK, HORIZONTAL_ALIGNMENT_LEFT, width)
	y += 12.0
	MenuStyleScript.rule(_stage, Vector2(x, y), Vector2(x + width, y))
	y += 26.0
	for line: String in letter_lines():
		PaintScript.text(_stage, font, Vector2(x, y), line, MenuStyleScript.ROW_SIZE,
			PaperPaintScript.INK, HORIZONTAL_ALIGNMENT_LEFT, width)
		y += LETTER_LINE_HEIGHT
	var replies: Array[Dictionary] = reply_rows()
	if not replies.is_empty():
		y += 8.0
		# Where the picker starts, kept so the coupon can sit BESIDE it rather than at a
		# typed in height that would slide under a long title.
		var reply_top: float = y
		for i in replies.size():
			var pick := Rect2(Vector2(x, y), Vector2(width * 0.62, REPLY_ROW_HEIGHT))
			PaintScript.rounded(_stage, pick, 6.0, Color(PaperPaintScript.STAMP_INK, 0.08),
				Color(PaperPaintScript.STAMP_INK, 0.55), 1.0)
			PaintScript.text(_stage, font, pick.position + Vector2(14.0, 24.0),
				String(replies[i]["label"]), MenuStyleScript.ROW_SIZE, PaperPaintScript.INK,
				HORIZONTAL_ALIGNMENT_LEFT, pick.size.x - 28.0)
			if i == _selected:
				PaintScript.focus_ring(_stage, pick, 6.0, _anim_t)
			y += REPLY_ROW_HEIGHT + REPLY_ROW_GAP
		# The coupon, drawn on the paper beside the picker, so the thing she is being paid
		# is a thing on the page rather than a sentence about a thing.
		PaperPaintScript.coupon(_stage,
			Rect2(Vector2(x + width * 0.66, reply_top),
				Vector2(width * 0.34, 46.0)), font, "HAY COUPON", PaperPaintScript.PAPER)
	elif not String(row.get("replied", "")).is_empty():
		PaperPaintScript.stamp(_stage,
			Rect2(Vector2(x + width * 0.60, y + 6.0), Vector2(width * 0.36, 44.0)), font,
			"ANSWERED")
```

- [ ] **Step 10: Run the page's tests, then the suite and the gate**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_pause_menu.gd -gexit
bash tools/run_tests.sh
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
```

Expected: PASS everywhere; `RANCH_OK ponies=49 props=110 assets=present`, since nothing in this task touches the world.

- [ ] **Step 11: Look at it**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/visual_review.tscn 2>&1 | tail -5
```

If `visual_review.tscn` takes a panel argument, point it at the pause menu; otherwise run the game windowed, press Escape, open Mail, and read the page. The bar: a sheet with a letterhead, a rule under the title, envelope cards with wax on the unread ones, and a breathing gold ring on the focused card. If it reads as a list of labels, it is not done.

- [ ] **Step 12: Commit**

```bash
git add game/ui/paper_paint.gd game/ui/paper_paint.gd.uid game/ui/pause_menu.gd \
  game/ui/pause_menu.tscn game/test/test_paper_paint.gd game/test/test_paper_paint.gd.uid \
  game/test/test_pause_menu.gd
git commit -m "feat: the Mail page is drawn stationery, not a column of labels"
```

---

## Task 5: The mailbox by the ranch door, and the census that follows it

**Files:**
- Create: `game/world/mailbox.gd`
- Create: `game/test/test_mailbox.gd`
- Modify: `game/world/ranch.tscn` (one new child of `Buildings`)
- Modify: `game/world/interaction.gd` (`Kind`, `PRIORITY`, `prompt_for`)
- Modify: `game/world/ranch.gd` (preload, `MAILBOX_RADIUS`, `is_near_mailbox()`, `interaction_candidates()`, `perform_interaction()`, `_interaction_doors()`, `open_mail_page()`, `_refresh_mailbox_flag()`)
- Modify: `docs/ci.md`, `docs/testing.md`, `docs/pipeline.md`, `docs/distribution.md`
- Test: `game/test/test_mailbox.gd`, `game/test/test_interaction.gd`

**Interfaces:**
- Consumes: `Story.unread_count()` (Task 1), `PauseMenu.Page.MAIL` (Task 4), `CollisionLayers.PROPS`, `Props.seat()`.
- Produces:
  - `Mailbox.POST_HEIGHT/BOX_SIZE/FLAG_SIZE`, `Mailbox.build() -> void`, `Mailbox.set_flag_up(up: bool) -> void`, `Mailbox.is_flag_up() -> bool`
  - `Interaction.Kind.MAILBOX`, and its place in `PRIORITY`
  - `Ranch.MAILBOX_RADIUS := 2.6`, `Ranch.is_near_mailbox() -> bool`, `Ranch.open_mail_page() -> void`, `Ranch.get_mailbox() -> Mailbox`, `Ranch._refresh_mailbox_flag() -> void`
  - the census: `props=111` with assets present, `props=7` without

- [ ] **Step 1: Write the failing tests**

Create `game/test/test_mailbox.gd`:

```gdscript
extends GutTest
## The Company's mailbox: a post, a box and a flag that goes up when something is waiting.
## It is a child of $Buildings so it rides the same build-and-seat loop the six buildings
## do, but it is NOT a Building: game/world/building.gd would push_error on a doorway this
## small, and a mailbox has no doorway at all.

const MailboxScript := preload("res://world/mailbox.gd")
const LayersScript := preload("res://world/collision_layers.gd")


func _built() -> Mailbox:
	var box: Mailbox = MailboxScript.new()
	add_child_autofree(box)
	box.build()
	return box


func test_it_builds_a_post_a_box_and_a_flag() -> void:
	var box: Mailbox = _built()
	assert_not_null(box.get_node_or_null("Post"))
	assert_not_null(box.get_node_or_null("Box"))
	assert_not_null(box.get_node_or_null("Flag"))


func test_building_twice_does_not_build_it_twice() -> void:
	var box: Mailbox = _built()
	var before: int = box.get_child_count()
	box.build()
	assert_eq(box.get_child_count(), before, "build() is idempotent, like Building.build()")


func test_it_is_solid_and_on_the_props_layer_like_every_other_prop() -> void:
	var box: Mailbox = _built()
	assert_gt(box.find_children("*", "CollisionShape3D", true, false).size(), 0,
		"the gate fails a prop with no collision shape")
	assert_eq(box.collision_layer, LayersScript.PROPS)
	assert_eq(box.collision_mask, 0)


func test_it_stands_high_enough_to_see_and_low_enough_to_be_a_mailbox() -> void:
	var box: Mailbox = _built()
	assert_gt(MailboxScript.POST_HEIGHT, 0.8, "a mailbox on the floor is not readable")
	assert_lt(MailboxScript.POST_HEIGHT, 1.6, "a mailbox is not a signpost")


func test_the_flag_starts_down_and_goes_up_when_something_is_waiting() -> void:
	var box: Mailbox = _built()
	assert_false(box.is_flag_up())
	box.set_flag_up(true)
	assert_true(box.is_flag_up())
	var flag := box.get_node("Flag") as Node3D
	assert_almost_eq(flag.rotation_degrees.z, MailboxScript.FLAG_UP_DEGREES, 0.01)
	box.set_flag_up(false)
	assert_false(box.is_flag_up())
	assert_almost_eq(flag.rotation_degrees.z, 0.0, 0.01)


func test_the_flag_is_a_mesh_and_never_a_label() -> void:
	var source: String = FileAccess.get_file_as_string("res://world/mailbox.gd")
	assert_false(source.contains("Label3D"), "no floating text anywhere in the world")


func test_no_line_of_it_carries_a_dash() -> void:
	var source: String = FileAccess.get_file_as_string("res://world/mailbox.gd")
	for line in source.split("\n"):
		var text: String = String(line)
		if text.begins_with("# ---") or text.begins_with("## ---"):
			continue
		assert_false(text.contains("--"), "double hyphen: %s" % text)
		assert_false(text.contains(char(0x2014)), "em dash: %s" % text)
```

Append to `game/test/test_interaction.gd`:

```gdscript
func test_the_mailbox_is_ranked_and_beats_the_depot_when_both_are_in_reach() -> void:
	var mailbox: Dictionary = InteractionScript.candidate(
		InteractionScript.Kind.MAILBOX, 2.0)
	var depot: Dictionary = InteractionScript.candidate(InteractionScript.Kind.DEPOT, 1.0)
	assert_gte(InteractionScript.rank_of(InteractionScript.Kind.MAILBOX), 0,
		"a kind outside PRIORITY can never win")
	var winner: Dictionary = InteractionScript.resolve([depot, mailbox] as Array[Dictionary])
	assert_eq(int(winner["kind"]), InteractionScript.Kind.MAILBOX,
		"a small thing in front of a big building wins the ground")


func test_the_mailbox_prompt_names_the_verb_and_carries_no_dash() -> void:
	var prompt: String = InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.MAILBOX, 1.0), "E")
	assert_true(prompt.contains("mail"))
	assert_false(prompt.contains("--"))
	assert_false(prompt.contains(char(0x2014)))
```

Use whatever constant name `test_interaction.gd` already preloads `interaction.gd` under.

- [ ] **Step 2: Run them and watch them fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_mailbox.gd -gexit
```

- [ ] **Step 3: Write `game/world/mailbox.gd`**

```gdscript
class_name Mailbox
extends StaticBody3D
## THE COMPANY'S MAILBOX, BY THE RANCH DOOR. A post, a box on top of it, and a flag that
## goes up when there is something in it. Assembled from primitives at load time, like
## game/world/building.gd, for the two reasons that file gives: it is IN GIT, so it exists
## on a CI checkout and in a fresh clone where game/assets/converted/ does not, and it is
## sized from a measurement rather than from whatever a converted mesh happened to be.
##
## NOT A Building, DELIBERATELY. Building.build() push_errors when door_height is under
## MIN_DOOR_CLEARANCE (2.25 m, a pony's horn tip), which is the right rule for a thing with
## a doorway and a silly one for a thing 1.15 m tall with no door at all. So this is its own
## small node, a child of $Buildings so it rides the same build-and-seat loop and is counted
## by the same census, and ranch.gd's gate measures it by the rule it measures every non
## Building prop by: seated against terrain.height_at() under its own origin.
##
## THE FLAG IS THE UNREAD SIGNAL, AND IT IS A MESH. The owner's standing note on the look:
## no floating text in the world. So "you have post" is a red flag standing up off the side
## of the box, readable across the yard, and one HUD toast when it lands; there is no
## Label3D here and there never will be.

const LayersScript := preload("res://world/collision_layers.gd")

## How high the post stands, in metres. Measured against the pony: 1.163 m at the withers
## (docs/pipeline.md section 3), so a box whose lid is a little under that is a box a pony
## can reach into, and a post any taller reads as a signpost.
const POST_HEIGHT := 1.05
const POST_THICKNESS := 0.10

## The box on top: wider than it is tall, deeper than it is wide, like every mailbox.
const BOX_SIZE := Vector3(0.34, 0.26, 0.52)

## The flag on its side.
const FLAG_SIZE := Vector3(0.04, 0.24, 0.03)

## How far the flag turns when it goes up. Ninety degrees about Z takes it from lying flat
## along the box to standing off its side, which is the shape everybody reads instantly.
const FLAG_UP_DEGREES := 90.0

## The Company's own colours, the Depot's walls and roof from game/world/ranch.tscn, so the
## box at the door and the building across the yard are the same company.
const BOX_COLOR := Color(0.62, 0.64, 0.68)
const POST_COLOR := Color(0.36, 0.30, 0.24)
const FLAG_COLOR := Color(0.78, 0.20, 0.22)

var _built := false
var _flag_up := false
var _flag: Node3D = null


func _ready() -> void:
	collision_layer = LayersScript.PROPS
	collision_mask = 0


## Assemble it. Idempotent, and called by ranch.gd's build-and-seat loop over $Buildings'
## children, which is why this is a method rather than work done in _ready().
func build() -> void:
	if _built:
		return
	_built = true
	_slab("Post", Vector3(POST_THICKNESS, POST_HEIGHT, POST_THICKNESS),
		Vector3(0.0, POST_HEIGHT * 0.5, 0.0), POST_COLOR)
	_slab("Box", BOX_SIZE, Vector3(0.0, POST_HEIGHT + BOX_SIZE.y * 0.5, 0.0), BOX_COLOR)
	_flag = _slab("Flag", FLAG_SIZE,
		Vector3(BOX_SIZE.x * 0.5 + FLAG_SIZE.x, POST_HEIGHT + BOX_SIZE.y * 0.5
			+ FLAG_SIZE.y * 0.5, 0.0), FLAG_COLOR)
	_apply_flag()


## Something is waiting, or is not. A no op when the flag is already where it should be, so
## a caller may push this every frame without churning a transform.
func set_flag_up(up: bool) -> void:
	if _flag_up == up:
		return
	_flag_up = up
	_apply_flag()


func is_flag_up() -> bool:
	return _flag_up


func _apply_flag() -> void:
	if _flag == null:
		return
	_flag.rotation_degrees.z = FLAG_UP_DEGREES if _flag_up else 0.0


## One box: a mesh, a matching collision shape, and a material. Returns the node so the flag
## can be kept and turned. The collision is on THIS body, which is what makes the whole
## assembly one solid thing on the PROPS layer, the way a Building is.
func _slab(part_name: String, size: Vector3, at: Vector3, colour: Color) -> Node3D:
	var holder := Node3D.new()
	holder.name = part_name
	holder.position = at
	add_child(holder)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.material_override = material
	holder.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = at
	add_child(shape)
	return holder
```

- [ ] **Step 4: Stand it in the yard**

In `game/world/ranch.tscn`, add an `ext_resource` for the script (give it a fresh unused id, e.g. `id="20"`):

```
[ext_resource type="Script" path="res://world/mailbox.gd" id="20"]
```

and add this node inside `Buildings`, after the `Palace` block and its `Cage` child:

```
[node name="Mailbox" type="StaticBody3D" parent="Buildings"]
transform = Transform3D(-0.9063078, 0, -0.42261824, 0, 1, 0, 0.42261824, 0, -0.9063078, 8, 0, -2.5)
script = ExtResource("20")
```

**Where that position comes from, and what to do if the gate argues.** The Farmhouse stands at `(9, -7)` turned 25 degrees, and `Building` cuts its doorway in the `+Z` gable end, so its door faces roughly `(0.42, 0.91)`: out into the yard, toward the Depot. `(8, 0, -2.5)` is beside that door on the yard side, on the path the player already walks from the spawn at `(4, 0.3, 10)` to the house. It clears: the Farmhouse origin by 4.6 m (its own half diagonal is 4.33 m), the Depot origin by 6.8 m (`DEPOT_RADIUS` 4.0 plus this radius), the Board by 5.2 m (`BOARD_RADIUS` 3.0 plus this radius), the Market by 10.5 m, and every MLP prop on the map by more than 9 m. If `_report()` prints a `prop doors` intrusion or a seating error naming `Mailbox`, move it along the arc around the Farmhouse door rather than shrinking `MAILBOX_RADIUS`, and re-run; the numbers above are what the new position has to keep.

- [ ] **Step 5: Give E something to do at it**

In `game/world/interaction.gd`, extend the enum and the priority list:

```gdscript
enum Kind { NONE, PLOT_BUILD, PEN_MOVE_IN, MARKET, BOARD, MAILBOX, DEPOT, PALACE }
```

```gdscript
## THE MAILBOX SITS ABOVE THE DEPOT for the reason the note below already gives: the Depot
## and the Palace are last because they are the two biggest buildings with the two widest
## radii, so a smaller thing standing in front of one of them wins the ground. A mailbox is
## the smallest thing on the map.
const PRIORITY: Array[int] = [Kind.PLOT_BUILD, Kind.PEN_MOVE_IN, Kind.MARKET, Kind.BOARD,
	Kind.MAILBOX, Kind.DEPOT, Kind.PALACE]
```

and add the prompt to `prompt_for()`'s `match`, above `Kind.DEPOT`:

```gdscript
			Kind.MAILBOX:
				return "%s: read your mail" % key
```

- [ ] **Step 6: Wire it into `ranch.gd`**

Add the preload beside the others:

```gdscript
const MailboxScript := preload("res://world/mailbox.gd")
```

Add the radius beside `DEPOT_RADIUS`:

```gdscript
## How close to the mailbox E opens the Mail page from. Narrower than the Depot's, because a
## mailbox is a small thing on a post and a wide radius would put its prompt on top of the
## farmhouse door the player walks past to reach it.
const MAILBOX_RADIUS := 2.6
```

Add the accessors, next to `is_near_depot()`:

```gdscript
func get_mailbox() -> Mailbox:
	return get_node_or_null(^"Buildings/Mailbox") as MailboxScript


## Is the player standing at the mailbox?
func is_near_mailbox() -> bool:
	var box: Node3D = get_mailbox()
	if box == null or player == null:
		return false
	var gap := Vector2(player.global_position.x - box.global_position.x,
		player.global_position.z - box.global_position.z).length()
	return gap <= MAILBOX_RADIUS


## THE FLAG SAYS WHETHER ANYTHING IS WAITING, and it is the only thing in the world that
## says so. Pushed from here rather than pulled by the mailbox, because game/world/ is not
## allowed to reach into GameState any more than game/ui/ is.
func _refresh_mailbox_flag() -> void:
	var box: Mailbox = get_mailbox()
	if box == null or _game_state == null:
		return
	box.set_flag_up(_game_state.story.unread_count() > 0)


## OPEN THE MAIL, the same way the request board opens its own page: the page number is
## fetched out of PauseMenu's own constant map rather than written here, so a build whose
## pause menu has no MAIL page opens the pause menu itself rather than failing to compile.
func open_mail_page() -> void:
	if pause_menu == null or not pause_menu.has_method("open"):
		return
	var page_id := _pause_menu_page("MAIL")
	if page_id >= 0 and pause_menu.has_method("open_page"):
		pause_menu.call("open_page", page_id)
		return
	pause_menu.open()
```

Add the candidate, in `interaction_candidates()`, after the `is_near_board()` block:

```gdscript
	if is_near_mailbox():
		out.append(InteractionScript.candidate(
			InteractionScript.Kind.MAILBOX, _flat_gap_to(^"Buildings/Mailbox")))
```

Add the verb, in `perform_interaction()`'s `match`, after the `Kind.BOARD` branch:

```gdscript
			InteractionScript.Kind.MAILBOX:
				open_mail_page()
				return true
```

Add the door, in `_interaction_doors()`'s `radii` dictionary:

```gdscript
		"Buildings/Mailbox": MAILBOX_RADIUS,
```

And call the flag refresh once at boot: in `_ready()`, immediately after the `_bind_build_menu()` call and before `await _report(...)`:

```gdscript
	_refresh_mailbox_flag()
```

- [ ] **Step 7: Run the gate and read the numbers**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -6
```

Expected: `RANCH_OK ponies=49 props=111 assets=present`, exit 0. If a check fails, the gate prints a `ranch: FAILED check` line naming the exact claim that broke; fix the cause (usually the position, see Step 4), never the check.

- [ ] **Step 8: Update every count consequence, in this same commit**

```bash
grep -rn "props=110\|props=6" docs/ game/world/ranch.gd
```

Update these to `props=111` / `props=7`:

- `docs/ci.md` line ~259: `RANCH_OK ponies=0 props=6 assets=absent` becomes `props=7`, and the sentence above it that explains the degraded count stays as it is.
- `docs/testing.md` line ~526: `RANCH_OK ponies=49 props=110 assets=present` becomes `props=111`, and extend the note under it: "Both counts moved once more in Phase 3 slice 1 ... " gains "and the Company's mailbox by the ranch door is one more in slice 3."
- `docs/pipeline.md` line ~1339: the `# -> RANCH_OK ponies=49 props=110 assets=present   exit 0` expectation becomes `props=111`, and the note under it gains the mailbox.
- `docs/distribution.md` lines ~37 and ~70: both `props=110` become `props=111`.
- `game/world/ranch.gd` line ~4901: the comment quoting `RANCH_OK ponies=0 props=6 assets=absent` becomes `props=7`.

**Leave two lines alone, on purpose:** `docs/pipeline.md` line ~1547 and `docs/windows-testing.md` line ~269 are verbatim captured output from dated runs of an older build, not statements of today's expectation. Editing a transcript would make it a fabrication. If either sits under prose that reads as a current expectation, add one sentence beside it naming the run's date and the count it was taken at.

- [ ] **Step 9: Suite, gate, and a look at it**

```bash
bash tools/run_tests.sh
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/depot_test.tscn 2>&1 | tail -2
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/collection_test.tscn 2>&1 | tail -2
```

Expected: suite green, `RANCH_OK ... props=111`, `DEPOT_OK`, `COLLECTION_OK`.

- [ ] **Step 10: Commit**

```bash
tools/bin/godot --headless --path game --import
git add game/world/mailbox.gd game/world/mailbox.gd.uid game/world/ranch.tscn \
  game/world/ranch.gd game/world/interaction.gd game/test/test_mailbox.gd \
  game/test/test_mailbox.gd.uid game/test/test_interaction.gd docs/
git commit -m "feat: a mailbox by the ranch door, with a flag for what is waiting"
```

---

## Task 6: The wire. The story advances, the post arrives, the Survey pays

**Files:**
- Modify: `game/world/ranch.gd` (preloads, the library handle, `_advance_story()`, `_post_due_mail()`, `_story_params()`, `_mail_rows()`, `_owned_rows()`, `_on_mail_opened()`, `_on_mail_reply()`, `_bind_pause_menu()`, `_on_world_changed()`, `run_collection_day()`, `deliver_pony()`, `_ready()`)
- Create: `game/test/test_ranch_mail.gd`
- Test: `game/test/test_ranch_mail.gd`

**Interfaces:**
- Consumes: `Story` (Task 1), `StoryBeat.render()` and `StoryLibrary.due()/by_id()/load_all()` (Task 2), the shipped corpus (Task 3), `PauseMenu.mail_provider`/`mail_ponies_provider`/`mail_opened`/`mail_reply` (Task 4), `Ranch.open_mail_page()`/`_refresh_mailbox_flag()` (Task 5). Existing: `Economy.grant()`, `Ranch._current_inventory()`, `Ranch._toast()`, `Ranch._player_name()`, `Ranch.deliver_pony()`, `Ranch.run_collection_day()`, `Ledger.quota`, `Ledger.shipments`, `Ranch._coat_word()`.
- Produces:
  - `Ranch.story_library() -> StoryLibrary`, `Ranch.advance_story() -> int` (how many letters it posted), `Ranch.mail_rows() -> Array[Dictionary]`, `Ranch.owned_rows() -> Array[Dictionary]`, `Ranch.answer_mail(id: StringName, choice: String) -> bool`
  - the toast text constant `Ranch.MAIL_ARRIVED := "Post! The flag is up on your mailbox."`

- [ ] **Step 1: Write the failing test**

Create `game/test/test_ranch_mail.gd`:

```gdscript
extends GutTest
## THE WIRE BETWEEN THE STORY AND THE RANCH, tested against a real Ranch node in a bare
## tree: the story advances on the events the game already emits, the post lands in the
## mailbox, the flag goes up, and answering the Survey pays exactly once. The gate
## (game/scenes/test/story_test.gd) does the same against the whole world with a real pen
## and a real walk; this is the fast half.

const RanchScene := preload("res://world/ranch.tscn")
const StoryScript := preload("res://systems/story.gd")
const StoryBeatScript := preload("res://systems/story_beat.gd")
const PauseMenuScript := preload("res://ui/pause_menu.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")

var _ranch: Ranch
var _state: Node


func before_each() -> void:
	_state = get_node("/root/GameState")
	_state.reset()
	_ranch = RanchScene.instantiate()
	add_child_autofree(_ranch)
	await wait_for_signal(_ranch.gate_report_finished, 120.0)


func test_a_fresh_ranch_puts_the_opening_letter_in_the_mailbox_and_raises_the_flag() -> void:
	assert_true(_state.story.has_mail(&"sunny_mailbox"))
	assert_eq(_state.story.unread_count(), 1)
	assert_true(_ranch.get_mailbox().is_flag_up())


func test_reading_a_letter_lowers_the_flag_and_the_letter_stays_forever() -> void:
	_ranch._on_mail_opened(&"sunny_mailbox")
	assert_true(_state.story.is_read(&"sunny_mailbox"))
	assert_false(_ranch.get_mailbox().is_flag_up())
	assert_true(_state.story.has_mail(&"sunny_mailbox"), "nothing is ever thrown away")


func test_a_delivery_is_counted_by_the_story_and_brings_the_receipt() -> void:
	_state.story.note_delivery(false, "Pony", &"")
	assert_gt(_ranch.advance_story(), 0, "the first shipment brings a letter")
	assert_true(_state.story.has_mail(&"sunny_first_receipt"))


func test_three_deliveries_turn_the_chapter_and_the_survey_lands_the_same_moment() -> void:
	for i in range(StoryScript.WEATHER_DELIVERIES):
		_state.story.note_delivery(false, "Pony", &"")
	_ranch.advance_story()
	assert_eq(_state.story.chapter, StoryScript.Chapter.WEATHER)
	assert_true(_state.story.has_mail(&"weather_survey"),
		"a chapter never turns with nothing to read")


func test_the_rendered_rows_carry_the_players_name_and_the_letter_panel_shape() -> void:
	var rows: Array[Dictionary] = _ranch.mail_rows()
	assert_eq(rows.size(), 1)
	var row: Dictionary = rows[0]
	assert_eq(String(row["id"]), "sunny_mailbox")
	assert_false(String(row["sender"]).is_empty())
	assert_false(String(row["title"]).is_empty())
	assert_gt((row["body"] as Array).size(), 2)
	assert_eq(int(row["reply"]), StoryBeatScript.Reply.NONE)
	assert_true("\n".join(row["body"]).contains(_ranch._player_name()))


func test_answering_the_survey_pays_the_bonus_and_the_coupon_exactly_once() -> void:
	for i in range(StoryScript.WEATHER_DELIVERIES):
		_state.story.note_delivery(false, "Pony", &"")
	_ranch.advance_story()
	var owned: Array[Dictionary] = _ranch.owned_rows()
	assert_eq(owned.size(), 0, "a ranch with no ponies has nobody to name")

	# create(), not new(): PonyInstance.create() is what mints the uid, and every other
	# system in the game addresses her by it.
	var instance = PonyInstanceScript.create(&"trixie")
	_state.add_pony(instance)
	owned = _ranch.owned_rows()
	assert_eq(owned.size(), 1)
	var uid: String = String(owned[0]["uid"])

	var bits_before: int = _ranch.get_economy().bits
	var hay_before: int = _ranch._current_inventory().count(StoryScript.SURVEY_COUPON_ITEM)
	assert_true(_ranch.answer_mail(&"weather_survey", uid))
	assert_eq(_ranch.get_economy().bits, bits_before + StoryScript.SURVEY_BONUS_BITS)
	assert_eq(_ranch._current_inventory().count(StoryScript.SURVEY_COUPON_ITEM),
		hay_before + StoryScript.SURVEY_COUPON_COUNT)
	assert_true(_state.story.survey_answered())
	assert_eq(String(_state.story.survey_choice["uid"]), uid)

	assert_false(_ranch.answer_mail(&"weather_survey", uid), "answered once, paid once")
	assert_eq(_ranch.get_economy().bits, bits_before + StoryScript.SURVEY_BONUS_BITS)


func test_an_answer_naming_a_pony_she_does_not_own_is_refused_and_pays_nothing() -> void:
	for i in range(StoryScript.WEATHER_DELIVERIES):
		_state.story.note_delivery(false, "Pony", &"")
	_ranch.advance_story()
	var bits_before: int = _ranch.get_economy().bits
	assert_false(_ranch.answer_mail(&"weather_survey", "not_a_uid"))
	assert_eq(_ranch.get_economy().bits, bits_before)
	assert_false(_state.story.survey_answered())


func test_a_letter_with_no_reply_control_cannot_be_answered_at_all() -> void:
	var bits_before: int = _ranch.get_economy().bits
	assert_false(_ranch.answer_mail(&"sunny_mailbox", "anything"))
	assert_eq(_ranch.get_economy().bits, bits_before)


func test_the_pause_menu_is_handed_the_mail_and_the_picker() -> void:
	var menu = _ranch.get_pause_menu()
	assert_true(menu.mail_provider.is_valid(), "ranch.gd injects the rows")
	assert_true(menu.mail_ponies_provider.is_valid(), "and the ponies she owns")
	assert_eq((menu.mail_provider.call() as Array).size(), 1)


func test_the_mail_page_is_reachable_by_the_verb_at_the_mailbox() -> void:
	var box = _ranch.get_mailbox()
	_ranch.player.global_position = box.global_position + Vector3(1.0, 0.0, 0.0)
	_ranch.player.global_position.y = _ranch.terrain.height_at(
		_ranch.player.global_position.x, _ranch.player.global_position.z) + 0.15
	assert_true(_ranch.is_near_mailbox())
	var action: Dictionary = _ranch.current_interaction()
	assert_eq(int(action.get("kind", -1)),
		preload("res://world/interaction.gd").Kind.MAILBOX)
	assert_true(_ranch.perform_interaction(action))
	var menu = _ranch.get_pause_menu()
	assert_true(menu.is_open())
	assert_eq(menu.page(), PauseMenuScript.Page.MAIL)
	menu.close()
```

- [ ] **Step 2: Run it and watch it fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_ranch_mail.gd -gexit
```

- [ ] **Step 3: Give `ranch.gd` the library and the story's own section**

Add the preloads beside the others:

```gdscript
const StoryScript := preload("res://systems/story.gd")
const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryLibraryScript := preload("res://systems/story_library.gd")
```

Add the toast text beside the other player facing constants:

```gdscript
## WHAT ARRIVAL SOUNDS LIKE, and it is said once per batch rather than once per letter: two
## letters landing on the same collection day are one trip to the mailbox. The flag on the
## box is the state; this is the moment.
const MAIL_ARRIVED := "Post! The flag is up on your mailbox."
```

Add the handle beside `_board`:

```gdscript
## The authored letters, loaded once for the life of the process (they are identical on
## every machine, like the pony roster and the region catalogue).
var _story_library: StoryLibrary = null
```

Add the section, next to the compendium and board section:

```gdscript
# --- the story, the post, and the survey -------------------------------------------------

func story_library() -> StoryLibrary:
	if _story_library == null:
		_story_library = StoryLibraryScript.new()
		_story_library.load_all()
	return _story_library


## The player's story, or null when there is no GameState. Read off the state rather than
## cached here, for rebind_economy()'s reason: a load replaces it.
func get_story() -> Story:
	return _game_state.story if _game_state != null else null


## THE CHAPTER, THEN THE POST. Called at boot, at every phase change, after a delivery and
## after a collection day: the four moments any of the story's counters can have moved.
## Returns how many letters actually landed, so a gate can assert on the number rather than
## on a toast.
func advance_story() -> int:
	var story: Story = get_story()
	if story == null:
		return 0
	story.advance()
	return _post_due_mail()


## Post everything the library says is owed, oldest rung first. One toast for the batch, the
## flag up, and the pause menu re-drawn if she happens to be looking at the page.
func _post_due_mail() -> int:
	var story: Story = get_story()
	if story == null:
		return 0
	var posted := 0
	for beat: StoryBeat in story_library().due(story):
		if not story.post(beat.id):
			continue
		posted += 1
		if beat.id == &"weather_requisition":
			# ARMED HERE, SERVED AT A LATER DAWN. The cycle is written down for the same
			# reason Ledger.pending_punishment_cycle is: the letter has to land before the
			# knock, and a collector who called in the same frame as his own notice is not
			# the beat the spec describes.
			story.set_flag("requisition_posted")
			story.requisition_cycle = _world.cycle_index() if _world != null else 0
	if posted > 0:
		_toast(MAIL_ARRIVED)
	_refresh_mailbox_flag()
	# A LETTER THAT LANDS WHILE SHE IS LOOKING AT THE PAGE APPEARS ON IT. The page draws from
	# a provider, so it only needs telling to draw again; the push is ranch.gd's, the same way
	# the Depot's refresh() is.
	if pause_menu != null and pause_menu.has_method("refresh_page"):
		pause_menu.call("refresh_page")
	return posted


## WHAT A LETTER IS RENDERED AGAINST. Every placeholder any authored letter may carry, in
## one dictionary, so a beat written next year cannot find a parameter missing. The pony and
## the colour come off the story rather than out of the world, because the pony a receipt
## names left by the departure path some sessions ago and is not in the world to ask.
func _story_params() -> Dictionary:
	var story: Story = get_story()
	var chosen: String = ""
	var named: String = ""
	var colour: String = ""
	if story != null:
		chosen = String(story.survey_choice.get("name", ""))
		named = String(story.last_named.get("name", ""))
		colour = String(story.last_named.get("colour", ""))
	var pony: String = chosen if not chosen.is_empty() else named
	return {
		"name": _player_name(),
		"pony": pony if not pony.is_empty() else StoryBeatScript.DEFAULTS["pony"],
		"colour": colour if not colour.is_empty() else StoryBeatScript.DEFAULTS["colour"],
		"count": _game_state.ledger.shipments if _game_state != null else 0,
		"quota": _game_state.ledger.quota if _game_state != null else 0,
		"balance": _game_state.ledger.balance if _game_state != null else 0,
	}


## THE MAILBOX, RENDERED. Oldest first, which is the order Story.mail keeps; the page turns
## it round for display. A posted id the library no longer carries is SKIPPED rather than
## drawn as a blank: a letter this build cannot render is not a letter, and dropping her
## whole mailbox over one of them would be worse.
func mail_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var story: Story = get_story()
	if story == null:
		return out
	var params: Dictionary = _story_params()
	for id: StringName in story.mail_ids():
		var beat: StoryBeat = story_library().by_id(id)
		if beat == null:
			continue
		var letter: Dictionary = beat.render(params)
		out.append({
			"id": String(id),
			"sender": String(letter["sender"]),
			"title": String(letter["title"]),
			"body": letter["body"],
			"read": story.is_read(id),
			"replied": story.replied_to(id),
			"reply": beat.reply_index(),
		})
	return out


## EVERY PONY SHE OWNS, for the Survey's picker: the ones in pens, the ones in the
## saddlebag, all of them, because the question is "which of your ponies", not "which of the
## ponies you happen to have penned".
func owned_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _game_state == null:
		return out
	for inst: PonyInstance in _game_state.get_ponies():
		out.append({
			"uid": String(inst.uid),
			"name": inst.display_name(),
			"coat": _coat_word(inst),
		})
	return out


func _on_mail_opened(id: StringName) -> void:
	var story: Story = get_story()
	if story == null:
		return
	if story.mark_read(id):
		_refresh_mailbox_flag()


## SHE ANSWERED A LETTER. Returns whether anything happened. The menu emitted the choice;
## this is the only place it becomes bits, hay and a line in the save.
##
## THE ORDER IS THE SAFETY. The answer is recorded FIRST and the reward paid second, and
## record_reply() refuses a letter that already carries an answer, so there is no ordering
## in which the bonus is paid twice. Answering is optional forever: nothing here fires
## unless she presses the key.
func answer_mail(id: StringName, choice: String) -> bool:
	var story: Story = get_story()
	if story == null or choice.is_empty():
		return false
	var beat: StoryBeat = story_library().by_id(id)
	if beat == null or beat.reply_index() == StoryBeatScript.Reply.NONE:
		return false
	if beat.reply_index() == StoryBeatScript.Reply.PICK_PONY:
		var picked: PonyInstance = _game_state.find_pony(StringName(choice)) \
			if _game_state != null else null
		if picked == null:
			return false
		if not story.record_reply(id, choice):
			return false
		story.answer_survey({
			"uid": choice,
			"data_id": String(picked.data_id),
			"name": picked.display_name(),
			"coat": _coat_word(picked),
		})
		_pay_survey(picked.display_name())
		save_game()
		return true
	if not story.record_reply(id, choice):
		return false
	save_game()
	return true


## THE SURVEY'S THANK YOU, through the seams every other reward in the game uses:
## Economy.grant() for the bits and Inventory.add() for the hay. No arithmetic of its own,
## and nothing under game/systems/ that computes money is touched.
func _pay_survey(who: String) -> void:
	if _economy != null:
		_economy.grant(StoryScript.SURVEY_BONUS_BITS)
	var bag: Inventory = _current_inventory()
	if bag != null:
		bag.add(StoryScript.SURVEY_COUPON_ITEM, StoryScript.SURVEY_COUPON_COUNT)
	_toast("Thank you for naming %s! %d bits and a hay coupon, with our appreciation."
		% [who, StoryScript.SURVEY_BONUS_BITS])
```

`_post_due_mail()` calls `refresh_page()` on the pause menu, so add that method to `game/ui/pause_menu.gd`:

```gdscript
## Redraw whatever page is up. ranch.gd calls this when something the open page is drawing
## has changed under it (a letter arriving while the Mail page is open), which is the same
## push the Depot's refresh() takes.
func refresh_page() -> void:
	if _open:
		_refresh()
```

- [ ] **Step 4: Hook the four moments**

In `_ready()`, replace the `_refresh_mailbox_flag()` line Task 5 added with:

```gdscript
	# THE FIRST POST, before the gate reports. A brand new ranch has a letter waiting in the
	# mailbox by the time the player takes her first step, which is what makes the flag mean
	# something on the very first frame.
	advance_story()
```

In `_on_world_changed()`, after `_maybe_run_collection_day()` and before `_maybe_serve_collector()`:

```gdscript
	advance_story()
```

In `run_collection_day()`, immediately after `var summary: Dictionary = ledger.run_collection_day(...)`:

```gdscript
	if _game_state != null:
		_game_state.story.note_collection_day()
```

In `deliver_pony()`, immediately after `_game_state.compendium.mark_processed(inst.data_id)`'s `if named:` block and before the receipt is rendered:

```gdscript
	# THE STORY COUNTS HER TOO, and it counts her by the same event the Company's receipt
	# does. A named pony's display name and her character id travel into the story here
	# because the letter that lists her beside a colour is written long after she has gone.
	_game_state.story.note_delivery(named, inst.display_name(), inst.data_id)
```

and at the very end of `deliver_pony()`, immediately before `return {"ok": true, ...}`:

```gdscript
	advance_story()
```

- [ ] **Step 5: Inject the two providers and connect the two signals**

In `_bind_pause_menu()`, inside the `inject_pages` lambda, after the `statement_provider` line:

```gdscript
		pause_menu.set("mail_provider", func() -> Array[Dictionary]: return mail_rows())
		pause_menu.set("mail_ponies_provider",
			func() -> Array[Dictionary]: return owned_rows())
```

and extend the connection loop's pair list:

```gdscript
	for pair in [["opened", _on_pause_opened], ["closed", _on_menu_closed],
			["save_requested", _on_pause_save], ["quit_requested", _on_pause_quit],
			["settings_changed", _on_settings_changed],
			["mail_opened", _on_mail_opened], ["mail_reply", _on_mail_reply]]:
```

and add the nullary adapter beside `_on_mail_opened`:

```gdscript
func _on_mail_reply(id: StringName, choice: String) -> void:
	answer_mail(id, choice)
```

- [ ] **Step 6: Run the wire's tests, then everything**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_ranch_mail.gd -gexit
bash tools/run_tests.sh
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/depot_test.tscn 2>&1 | tail -2
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/ledger_test.tscn 2>&1 | tail -2
```

Expected: PASS, `RANCH_OK ... props=111`, `DEPOT_OK`, `LEDGER_OK`.

- [ ] **Step 7: Commit**

```bash
git add game/world/ranch.gd game/ui/pause_menu.gd game/test/test_ranch_mail.gd \
  game/test/test_ranch_mail.gd.uid
git commit -m "feat: the post arrives on the events the game already emits"
```

---

## Task 7: The Priority Requisition, and what the Compendium calls her afterwards

**Files:**
- Create: `game/systems/story_wording.gd`
- Create: `game/test/test_story_wording.gd`
- Modify: `game/world/ranch.gd` (`serve_requisition()`, `_maybe_serve_requisition()`, `_on_world_changed()`, `_bind_pause_menu()`)
- Modify: `game/ui/pause_menu.gd` (`story_chapter`, `employees_choice`, `_entry_value()`)
- Test: `game/test/test_story_wording.gd`, `game/test/test_ranch_mail.gd`, `game/test/test_pause_menu.gd`

**Interfaces:**
- Consumes: `Story.Chapter`, `Story.survey_choice`, `Story.requisition_cycle`, `Story.has_flag()/set_flag()` (Task 1), `Ranch.deliver_pony()`, `Ranch._penned()`, `WorldState.phase()/cycle_index()`, `Compendium.State`.
- Produces:
  - `StoryWording.PROCESSED_LABELS: Array[String]`, `StoryWording.EMPLOYEES_CHOICE := "Employee's Choice"`, `StoryWording.processed_label(chapter: int) -> String`, `StoryWording.processed_value(chapter: int, employees_choice: bool) -> String`
  - `Ranch.serve_requisition() -> Dictionary` returning `{"served": bool, "name": String, "credit": int}`
  - `PauseMenu.story_chapter: int`, `PauseMenu.employees_choice: StringName`

- [ ] **Step 1: Write the failing tests**

Create `game/test/test_story_wording.gd`:

```gdscript
extends GutTest
## THE WORDS THAT CHANGE WITH THE CHAPTER. One state in the Compendium (PROCESSED) and one
## board, read differently as the player learns what she has been doing. The spec: "The same
## state; only the words change with the chapter."

const StoryScript := preload("res://systems/story.gd")
const WordingScript := preload("res://systems/story_wording.gd")


func test_every_chapter_has_a_word_for_a_delivered_pony() -> void:
	assert_eq(WordingScript.PROCESSED_LABELS.size(), StoryScript.Chapter.size())
	for chapter in range(StoryScript.Chapter.size()):
		assert_false(WordingScript.processed_label(chapter).is_empty(),
			"chapter %d has no word for it" % chapter)


func test_the_early_chapters_are_cheerful_and_never_grim() -> void:
	var early: String = WordingScript.processed_label(StoryScript.Chapter.SUNNY)
	assert_true(early.contains("Delivered"), "before she knows, it is a delivery")
	for chapter in range(StoryScript.Chapter.size()):
		var label: String = WordingScript.processed_label(chapter).to_lower()
		assert_false(label.contains("kill"))
		assert_false(label.contains("dead"))


func test_a_chapter_this_build_does_not_have_falls_back_rather_than_crashing() -> void:
	assert_eq(WordingScript.processed_label(-1),
		WordingScript.processed_label(StoryScript.Chapter.SUNNY))
	assert_eq(WordingScript.processed_label(99),
		WordingScript.processed_label(StoryScript.Chapter.RESISTANCE))


func test_the_pony_she_named_carries_her_star() -> void:
	var plain: String = WordingScript.processed_value(StoryScript.Chapter.WEATHER, false)
	var starred: String = WordingScript.processed_value(StoryScript.Chapter.WEATHER, true)
	assert_false(plain.contains(WordingScript.EMPLOYEES_CHOICE))
	assert_true(starred.contains(WordingScript.EMPLOYEES_CHOICE))
	assert_true(starred.begins_with(plain), "the star is added, never a replacement")


func test_no_wording_carries_a_dash() -> void:
	for chapter in range(StoryScript.Chapter.size()):
		for starred: bool in [false, true]:
			var line: String = WordingScript.processed_value(chapter, starred)
			assert_false(line.contains("--"))
			assert_false(line.contains(char(0x2014)))
```

Append to `game/test/test_ranch_mail.gd`:

```gdscript
func test_the_requisition_does_nothing_at_all_until_it_has_been_posted() -> void:
	var result: Dictionary = _ranch.serve_requisition()
	assert_false(bool(result["served"]))
	assert_false(_state.story.has_flag("requisition_served"))


func test_a_requisition_for_a_pony_she_no_longer_has_closes_itself_quietly() -> void:
	_state.story.set_flag("requisition_posted")
	_state.story.requisition_cycle = -1
	_state.story.survey_choice = {"uid": "gone", "data_id": "trixie", "name": "Trixie",
		"coat": ""}
	var result: Dictionary = _ranch.serve_requisition()
	assert_false(bool(result["served"]), "there was nobody to walk over")
	assert_true(_state.story.has_flag("requisition_served"),
		"and it does not sit armed forever waiting for a pony who is not coming back")


func test_a_requisition_waits_for_a_pony_who_is_in_the_saddlebag_rather_than_a_pen() -> void:
	var instance = PonyInstanceScript.create(&"trixie")
	_state.add_pony(instance)
	_state.story.set_flag("requisition_posted")
	_state.story.requisition_cycle = -1
	_state.story.survey_choice = {"uid": String(instance.uid), "data_id": "trixie",
		"name": "Trixie", "coat": ""}
	var result: Dictionary = _ranch.serve_requisition()
	assert_false(bool(result["served"]))
	assert_false(_state.story.has_flag("requisition_served"),
		"she is still hers; the collector calls again when she is in a pen")
```

Append to `game/test/test_pause_menu.gd`:

```gdscript
func test_a_delivered_pony_reads_in_the_words_of_the_chapter_she_was_delivered_in() -> void:
	_wire_book()
	var wording = preload("res://systems/story_wording.gd")
	var story = preload("res://systems/story.gd")
	var first: PonyData = _menu.roster()[0]
	_compendium.mark_processed(first.id)
	_menu.story_chapter = story.Chapter.SUNNY
	_menu.open()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	var rows: Array[String] = _menu.compendium_rows()
	assert_true(rows[0].contains(wording.processed_label(story.Chapter.SUNNY)))


func test_the_pony_she_named_on_the_survey_carries_her_star_in_the_book() -> void:
	_wire_book()
	var wording = preload("res://systems/story_wording.gd")
	var first: PonyData = _menu.roster()[0]
	_compendium.mark_processed(first.id)
	_menu.employees_choice = first.id
	_menu.open()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	assert_true(_menu.compendium_rows()[0].contains(wording.EMPLOYEES_CHOICE))
```

- [ ] **Step 2: Run them and watch them fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story_wording.gd -gexit
```

- [ ] **Step 3: Write `game/systems/story_wording.gd`**

```gdscript
class_name StoryWording
extends RefCounted
## THE WORDS THAT CHANGE WITH THE CHAPTER, and nothing else. The spec, on the Compendium's
## PROCESSED state: "Before the fork it renders as 'Delivered' with a smiley. The same
## state; only the words change with the chapter." So the state stays one state, the page
## stays one page, and the wording is a table.
##
## Static only, no state, no scene. Preload by path.
##
## THE REGISTER: cheerful corporate, and it curdles by degrees rather than by an announcement.
## SUNNY is a delivery with a smiley. WEATHER files it. The Company chapter is proud of the
## number. The Resistance chapter says the only honest thing anybody says about it. Nothing
## here is ever grim on screen and no word in it is the word this project does not use.

const StoryScript := preload("res://systems/story.gd")

## Indexed by Story.Chapter. One entry per chapter, checked by the test rather than trusted.
const PROCESSED_LABELS: Array[String] = [
	"Delivered :)",
	"Delivered, and filed",
	"Delivered, and filed",
	"Processed. Yield 94%",
	"Taken",
]

## The star on the pony the player named on the Employee Appreciation Survey. It reads as a
## commendation, which is the joke, and it is the same phrase the Requisition used.
const EMPLOYEES_CHOICE := "Employee's Choice"


static func processed_label(chapter: int) -> String:
	return PROCESSED_LABELS[clampi(chapter, 0, PROCESSED_LABELS.size() - 1)]


## The whole of what a PROCESSED row says: the chapter's word for it, plus the star when she
## is the one the player named. The star is APPENDED rather than substituted, so a reader
## who has learned what the first half means does not lose it.
static func processed_value(chapter: int, employees_choice: bool) -> String:
	var label: String = processed_label(chapter)
	return "%s   %s" % [label, EMPLOYEES_CHOICE] if employees_choice else label
```

- [ ] **Step 4: Let the Compendium page say it**

In `game/ui/pause_menu.gd`, add the preload:

```gdscript
const StoryWordingScript := preload("res://systems/story_wording.gd")
```

Add the two injected fields beside `statement_provider`:

```gdscript
## WHICH CHAPTER THE BOOK IS BEING READ IN, and who the player named on the Survey. Both are
## pushed by ranch.gd exactly as the five sources above are, and both are allowed to stay at
## their defaults forever: a menu with no ranch behind it reads the book in SUNNY's words,
## which is the state a new game is in anyway.
var story_chapter: int = 0
var employees_choice: StringName = &""
```

Replace the `PROCESSED` branch of `_entry_value()`:

```gdscript
	if compendium.state_of(data.id) == CompendiumScript.State.PROCESSED:
		# The Company's word for it, in the Company's tone, and the tone moves with the
		# chapter. See game/systems/story_wording.gd; game/systems/compendium.gd's class
		# comment has said this is how it would read since the state was added.
		return StoryWordingScript.processed_value(story_chapter,
			data.id == employees_choice)
```

In `game/world/ranch.gd`'s `_bind_pause_menu()`, inside the `inject_pages` lambda, after the two mail providers:

```gdscript
		pause_menu.set("story_chapter",
			_game_state.story.chapter if _game_state != null else 0)
		pause_menu.set("employees_choice", StringName(
			String(_game_state.story.survey_choice.get("data_id", ""))
			if _game_state != null else ""))
```

and re-push them when the chapter turns: at the end of `advance_story()`, before `return`:

```gdscript
	# THE BOOK IS READ IN THE CURRENT CHAPTER'S WORDS. inject_pages() is re-run on a load;
	# a chapter that turns mid session has to push the same two fields itself.
	if pause_menu != null:
		pause_menu.set("story_chapter", story.chapter)
		pause_menu.set("employees_choice",
			StringName(String(story.survey_choice.get("data_id", ""))))
```

which means `advance_story()` keeps its posted count in a local: `var posted: int = _post_due_mail()`, then the block above, then `return posted`.

- [ ] **Step 5: The collector calls at dawn**

Add to `game/world/ranch.gd`, in the story section:

```gdscript
## THE PRIORITY REQUISITION, SERVED. A collector calls at the first DAWN of a cycle LATER
## than the one the letter landed on, walks the pony the player named from her pen, and she
## leaves by the departure path into the crate: the SAME path a Depot delivery uses, because
## it is the only path a pony ever leaves the ranch by. Returns
## {"served": bool, "name": String, "credit": int} so a gate can assert on what happened
## rather than on a toast.
##
## THIS IS THE ONE PLACE BEFORE THE FORK WHERE THE COMPANY REACHES INTO A PEN, and the spec
## names it as the single scripted exception (see "The ledger": "No pony is ever taken from a
## pen by a collector before the fork, with one scripted exception, the Survey's Priority
## Requisition"). Nothing about it is a new transaction: deliver_pony() applies the credit,
## counts the quota, marks the Compendium and posts the receipt, exactly as the counter does.
##
## THREE ENDINGS, and each is deliberate:
##   she is in a pen        she walks, and the requisition is served.
##   she is not owned at all she has already gone (delivered, or never kept); the
##                          requisition closes itself so it cannot sit armed forever.
##   she is owned but not penned  nothing happens and it stays armed: she is in the
##                          saddlebag, and a collector does not take a pony out of a pocket.
func serve_requisition() -> Dictionary:
	var refused := {"served": false, "name": "", "credit": 0}
	var story: Story = get_story()
	if story == null or _game_state == null:
		return refused
	if not story.has_flag("requisition_posted") or story.has_flag("requisition_served"):
		return refused
	var uid := StringName(String(story.survey_choice.get("uid", "")))
	if String(uid).is_empty():
		story.set_flag("requisition_served")
		return refused
	if _game_state.find_pony(uid) == null:
		# She is not on the ranch any more. Close it quietly: there is nobody to walk over
		# and nothing to say that would not be worse than saying nothing.
		story.set_flag("requisition_served")
		return refused
	if _penned(uid).is_empty():
		return refused

	var who: String = String(story.survey_choice.get("name", ""))
	var result: Dictionary = deliver_pony(uid)
	if not bool(result.get("ok", false)):
		return refused
	story.set_flag("requisition_served")
	_toast("An associate called for %s and walked her over himself. Most efficient!" % who)
	_refresh_mailbox_flag()
	save_game()
	return {"served": true, "name": String(result.get("name", who)),
		"credit": int(result.get("credit", 0))}


## THE KNOCK, ONE FULL CYCLE AFTER THE LETTER, and only ever at DAWN. Same shape as
## _maybe_serve_collector(), and the arming cycle lives on the story so it travels with the
## save: quitting between the Requisition and the dawn comes back owing the same visit.
func _maybe_serve_requisition() -> void:
	if _world == null or _world.phase() != WorldStateScript.Phase.DAWN:
		return
	var story: Story = get_story()
	if story == null or not story.has_flag("requisition_posted"):
		return
	if story.has_flag("requisition_served"):
		return
	if _world.cycle_index() <= story.requisition_cycle:
		return
	serve_requisition()
```

and call it from `_on_world_changed()`, immediately after `advance_story()` and before `_maybe_serve_collector()`:

```gdscript
	_maybe_serve_requisition()
```

- [ ] **Step 6: Run everything**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story_wording.gd -gexit
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_ranch_mail.gd -gexit
bash tools/run_tests.sh
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/depot_test.tscn 2>&1 | tail -2
```

- [ ] **Step 7: Commit**

```bash
git add game/systems/story_wording.gd game/systems/story_wording.gd.uid \
  game/test/test_story_wording.gd game/test/test_story_wording.gd.uid \
  game/world/ranch.gd game/ui/pause_menu.gd game/test/test_ranch_mail.gd \
  game/test/test_pause_menu.gd
git commit -m "feat: the requisition walks her over, and the book learns a new word"
```

---

## Task 8: The Request Board reads differently in a different chapter

**Files:**
- Modify: `game/systems/story_wording.gd` (board templates and notes)
- Modify: `game/systems/request_board.gd` (`chapter`, `set_chapter()`, the `subject` field, `_worded()`, `note()`)
- Modify: `game/world/ranch.gd` (`_rebuild_request_board()`, `advance_story()`)
- Modify: `game/ui/pause_menu.gd` (`_draw_requests()`)
- Test: `game/test/test_story_wording.gd`, `game/test/test_request_board.gd`, `game/test/test_pause_menu.gd`

**Interfaces:**
- Consumes: `Story.Chapter` (Task 1), `StoryWording` (Task 7), `RequestBoard.Kind` and the request dictionary shape.
- Produces:
  - `StoryWording.BOARD_TEMPLATES: Dictionary`, `StoryWording.BOARD_NOTES: Array[String]`, `StoryWording.board_text(kind: int, chapter: int, subject: String, count: int) -> String`, `StoryWording.board_note(chapter: int) -> String`
  - `RequestBoard.chapter: int`, `RequestBoard.set_chapter(value: int) -> void`, `RequestBoard.note() -> String`, and a `"subject": String` field on every drawn request

**The rule this task is held to:** `SUNNY`'s wording is byte identical to what the board prints today, so no reward, no threshold, no seeded draw and no existing expectation moves. Only the sentence changes, and only in a chapter this slice cannot reach except by turning to `WEATHER`.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_story_wording.gd`:

```gdscript
func test_the_sunny_board_says_exactly_what_it_has_always_said() -> void:
	var board = preload("res://systems/request_board.gd")
	var story = preload("res://systems/story.gd")
	assert_eq(WordingScript.board_text(board.Kind.CATCH_ANY, story.Chapter.SUNNY, "", 1),
		"Catch a pony with your magic beam.")
	assert_eq(WordingScript.board_text(board.Kind.PEN_ANY, story.Chapter.SUNNY, "", 1),
		"Move a pony into a pen.")
	assert_eq(WordingScript.board_text(board.Kind.SELL_ANY, story.Chapter.SUNNY, "", 1),
		"Sell a gem at the market.")
	assert_eq(WordingScript.board_text(board.Kind.BRING_PERSONALITY_FROM_ZONE,
		story.Chapter.SUNNY, "shy pony from The Orchard", 1),
		"Bring a shy pony from The Orchard.")
	assert_eq(WordingScript.board_text(board.Kind.SELL_GEMS_OF_RARITY,
		story.Chapter.SUNNY, "common gems", 4), "Sell 4 common gems.")
	assert_eq(WordingScript.board_text(board.Kind.SEE_CHARACTER, story.Chapter.SUNNY,
		"Trixie", 1), "Find Trixie and get a good look at her.")


func test_every_kind_has_a_line_in_every_chapter_and_none_of_them_carries_a_dash() -> void:
	var board = preload("res://systems/request_board.gd")
	var story = preload("res://systems/story.gd")
	for kind in board.Kind.values():
		for chapter in range(story.Chapter.size()):
			var line: String = WordingScript.board_text(kind, chapter, "a shy pony", 3)
			assert_false(line.is_empty(), "kind %d has nothing to say in chapter %d"
				% [kind, chapter])
			assert_false(line.contains("{"), "an unfilled placeholder: %s" % line)
			assert_false(line.contains("--"))
			assert_false(line.contains(char(0x2014)))
			assert_false(line.to_lower().contains("kill"))


func test_the_same_request_reads_differently_once_the_weather_turns() -> void:
	var board = preload("res://systems/request_board.gd")
	var story = preload("res://systems/story.gd")
	var sunny: String = WordingScript.board_text(board.Kind.SEE_CHARACTER,
		story.Chapter.SUNNY, "Trixie", 1)
	var weather: String = WordingScript.board_text(board.Kind.SEE_CHARACTER,
		story.Chapter.WEATHER, "Trixie", 1)
	assert_ne(sunny, weather, "the board is chapter keyed or it is not")


func test_every_chapter_has_a_note_at_the_top_of_the_board() -> void:
	var story = preload("res://systems/story.gd")
	assert_eq(WordingScript.BOARD_NOTES.size(), story.Chapter.size())
	for chapter in range(story.Chapter.size()):
		assert_false(WordingScript.board_note(chapter).is_empty())
		assert_false(WordingScript.board_note(chapter).contains("--"))
```

Append to `game/test/test_request_board.gd`:

```gdscript
func test_the_board_words_itself_in_the_chapter_it_is_read_in() -> void:
	var wording = preload("res://systems/story_wording.gd")
	var story = preload("res://systems/story.gd")
	var board = _board()
	board.seed_tutorial()
	assert_eq(String(board.requests()[0]["text"]),
		wording.board_text(BoardScript.Kind.CATCH_ANY, story.Chapter.SUNNY, "", 1))
	board.set_chapter(story.Chapter.WEATHER)
	assert_eq(String(board.requests()[0]["text"]),
		wording.board_text(BoardScript.Kind.CATCH_ANY, story.Chapter.WEATHER, "", 1),
		"an EXISTING request rereads in the new chapter; it is not reworded only at draw")


func test_the_chapter_changes_the_words_and_never_the_rewards_or_the_draw() -> void:
	var story = preload("res://systems/story.gd")
	var sunny = _board()
	sunny.seed_tutorial()
	sunny.fill([])
	var weather = _board()
	weather.set_chapter(story.Chapter.WEATHER)
	weather.seed_tutorial()
	weather.fill([])
	var a: Array = sunny.requests()
	var b: Array = weather.requests()
	assert_eq(a.size(), b.size(), "the same board, drawn the same way")
	for i in a.size():
		var one: Dictionary = a[i]
		var two: Dictionary = b[i]
		assert_eq(String(one["id"]), String(two["id"]), "the seeded draw is untouched")
		assert_eq(int(one["kind"]), int(two["kind"]))
		assert_eq(int(one["count"]), int(two["count"]))
		assert_eq(int(one["reward_bits"]), int(two["reward_bits"]), "THE MATH DOES NOT CHANGE")
		assert_eq(int(one["reward_food_count"]), int(two["reward_food_count"]))


func test_a_saved_board_from_before_the_subject_field_keeps_its_own_words() -> void:
	var board = _board()
	board.seed_tutorial()
	var saved: Array = board.to_array()
	for i in range(1, saved.size()):
		(saved[i] as Dictionary).erase("subject")
		(saved[i] as Dictionary)["text"] = "An older sentence."
	var back = BoardScript.from_array(saved, _registry(), _regions())
	assert_eq(String(back.requests()[0]["text"]), "An older sentence.",
		"a request with no subject to reword from keeps the text it was saved with")


func test_the_board_carries_a_note_for_the_chapter_it_is_in() -> void:
	var wording = preload("res://systems/story_wording.gd")
	var story = preload("res://systems/story.gd")
	var board = _board()
	assert_eq(board.note(), wording.board_note(story.Chapter.SUNNY))
	board.set_chapter(story.Chapter.WEATHER)
	assert_eq(board.note(), wording.board_note(story.Chapter.WEATHER))
```

Use whatever helpers `test_request_board.gd` already has for building a board, a registry and a region list; if it builds them inline, do the same rather than adding helpers.

Append to `game/test/test_pause_menu.gd`:

```gdscript
func test_the_requests_page_carries_the_boards_note_for_this_chapter() -> void:
	_wire_book()
	var wording = preload("res://systems/story_wording.gd")
	var story = preload("res://systems/story.gd")
	_board.set_chapter(story.Chapter.WEATHER)
	_menu.open()
	_menu.open_page(PauseMenu.Page.REQUESTS)
	assert_eq(_menu.board_note(), wording.board_note(story.Chapter.WEATHER))
```

- [ ] **Step 2: Run them and watch them fail**

```bash
tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/test_story_wording.gd -gexit
```

- [ ] **Step 3: Add the board's words to `game/systems/story_wording.gd`**

```gdscript
const RequestBoardScript := preload("res://systems/request_board.gd")

## THE BOARD, CHAPTER BY CHAPTER. Keyed by RequestBoard.Kind, five entries each, in
## Story.Chapter order. The SUNNY column is byte identical to the sentences the board has
## printed since phase 2 slice 5: the wording moves, the board does not, and
## test_story_wording.gd pins the SUNNY column so a rewrite cannot drift the shipped one.
##
## {subject} is what the request is ABOUT (a personality and a region, a rarity of gem, a
## character's name), built by the board when it draws the request; {count} is how many.
## The frame around them is what the chapter changes: the ranch asks in SUNNY, the Company
## requisitions in COMPANY, and the town asks in RESISTANCE.
const BOARD_TEMPLATES := {
	RequestBoardScript.Kind.CATCH_ANY: [
		"Catch a pony with your magic beam.",
		"Catch a pony with your magic beam.",
		"Catch a pony. You are good at this now.",
		"Acquire one pony. Method at your discretion.",
		"Catch a pony. She stays caught, and she stays here.",
	],
	RequestBoardScript.Kind.PEN_ANY: [
		"Move a pony into a pen.",
		"Move a pony into a pen.",
		"Move a pony into a pen and see that she settles.",
		"House one pony pending collection.",
		"Move a pony into a pen. She is staying.",
	],
	RequestBoardScript.Kind.SELL_ANY: [
		"Sell a gem at the market.",
		"Sell a gem at the market.",
		"Sell a gem. The service charge will not pay itself.",
		"Liquidate one gem against your account.",
		"Sell a gem. The town needs the bits more than we do.",
	],
	RequestBoardScript.Kind.BRING_PERSONALITY_FROM_ZONE: [
		"Bring a {subject}.",
		"Bring a {subject}.",
		"Somepony is asking for a {subject}.",
		"Requisition: one {subject}.",
		"Bring a {subject} home, and keep her.",
	],
	RequestBoardScript.Kind.SELL_GEMS_OF_RARITY: [
		"Sell {count} {subject}.",
		"Sell {count} {subject}.",
		"Sell {count} {subject} while the price holds.",
		"Liquidate {count} {subject} against your account.",
		"Sell {count} {subject}. The town is buying.",
	],
	RequestBoardScript.Kind.SEE_CHARACTER: [
		"Find {subject} and get a good look at her.",
		"Locate {subject}. Description on file.",
		"Somepony is looking for {subject}.",
		"Locate {subject}. Registered arrival, bonus applies.",
		"Find {subject}, and do not tell anybody where she is.",
	],
}

## The line at the top of the board, in Story.Chapter order. One sentence that says whose
## board it is this week.
const BOARD_NOTES: Array[String] = [
	"Finish one to get a new one.",
	"Finish one to get a new one. Notices are filed weekly.",
	"Finish one to get a new one. Somepony has been reading these.",
	"Cloudsdale Weather Corporation, Partner Requisitions.",
	"Pinned over the Company's notices, in somepony else's hoofwriting.",
]


## What a request of `kind` says in `chapter`. A kind or chapter this build does not have
## falls back rather than answering an empty string, because a request with no text is a row
## the player cannot read.
static func board_text(kind: int, chapter: int, subject: String, count: int) -> String:
	var lines: Variant = BOARD_TEMPLATES.get(kind, null)
	if lines == null:
		return ""
	var list: Array = lines
	var template: String = String(list[clampi(chapter, 0, list.size() - 1)])
	return template.format({"subject": subject, "count": count})


static func board_note(chapter: int) -> String:
	return BOARD_NOTES[clampi(chapter, 0, BOARD_NOTES.size() - 1)]
```

- [ ] **Step 4: Teach the board to reread itself**

In `game/systems/request_board.gd`, add the preload and the field:

```gdscript
const StoryWordingScript := preload("res://systems/story_wording.gd")
```

```gdscript
## WHICH CHAPTER THIS BOARD IS BEING READ IN. Set by ranch.gd from the story; a board nobody
## has told reads in SUNNY, which is where every board starts.
##
## THE TEXT IS A FUNCTION OF THIS, NOT A THING STORED AGAINST THE REQUEST. The spec: "the
## same request reads differently in SUNNY and in COMPANY". A sentence baked in at draw time
## could only ever say what the board thought a year ago, so requests() and active() word
## each row as they hand it over, from the request's own `subject` and `count`. The stored
## `text` survives as the fallback for a save written before `subject` existed.
##
## NOTHING ELSE ABOUT A REQUEST MOVES: not its id, kind, count, progress, rewards or the
## seeded draw that produced it. test_request_board.gd asserts exactly that.
var chapter: int = 0


func set_chapter(value: int) -> void:
	chapter = maxi(0, value)


## The line at the top of the board, for the page that draws it.
func note() -> String:
	return StoryWordingScript.board_note(chapter)
```

Give every request a subject. In `_blank_request()`, add the field beside `text`:

```gdscript
		"subject": "",
```

In `_draw_bring()`, set it before returning:

```gdscript
	r["subject"] = "%s pony from %s" % [personality_name, region_name]
```

In `_draw_sell_gems()`:

```gdscript
	r["subject"] = "%s gems" % rarity_name
```

In `_draw_see_character()`:

```gdscript
	r["subject"] = data.display_name
```

Add the wording step, and route the three readers through it:

```gdscript
## A COPY OF `req`, WORDED FOR THIS CHAPTER. A request whose kind has no template, or one
## restored from a save written before `subject` existed, keeps the text it was saved with:
## an old row that suddenly said "Bring a ." would be worse than an old row that says what
## it always said.
func _worded(req: Dictionary) -> Dictionary:
	var out: Dictionary = req.duplicate(true)
	# THE ABSENCE OF THE KEY IS THE TEST, not an empty string: a tutorial request HAS a
	# subject and it is empty, while a request restored from a save written before this field
	# existed has no key at all. Rewording the second one from a subject it does not carry is
	# how "Bring a shy pony from The Orchard." becomes "Bring a .".
	if not out.has("subject"):
		return out
	var line: String = StoryWordingScript.board_text(int(out.get("kind", -1)), chapter,
		String(out.get("subject", "")), int(out.get("count", 1)))
	if not line.is_empty():
		out["text"] = line
	return out
```

and in `requests()`, `active()` and `tutorial_rows()` replace each `duplicate(true)` of a request with `_worded(r)`; in `tutorial_rows()` the `"text"` field comes from `_worded(req)["text"]` rather than from `req.get("text", "")`.

A tutorial request has an empty `subject` and its templates carry no placeholder, so it words correctly with no special case. `from_array()` must NOT invent a `subject` for a record that has none: its absence is exactly what tells `_worded()` to leave that row's sentence alone.

- [ ] **Step 5: Tell the board which chapter it is in**

In `game/world/ranch.gd`'s `_rebuild_request_board()`, immediately after the board is constructed or restored (the line that assigns `_board`):

```gdscript
	if _board != null and _game_state != null:
		_board.set_chapter(_game_state.story.chapter)
```

and in `advance_story()`, in the same block that re-pushes `story_chapter` to the pause menu:

```gdscript
	if _board != null:
		_board.set_chapter(story.chapter)
```

- [ ] **Step 6: Draw the note**

In `game/ui/pause_menu.gd`, add the accessor beside `request_rows()`:

```gdscript
## The line at the top of the board, in the chapter it is being read in. Empty when no board
## was injected, which is the state a bare menu is in.
func board_note() -> String:
	return board.note() if board != null else ""
```

and replace `_draw_requests()`'s footer line and empty branch:

```gdscript
func _draw_requests() -> void:
	_title.text = "REQUESTS"
	_footer.text = MenuStyleScript.footer_reading("back")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	var note: String = board_note()
	if not note.is_empty():
		_add_note(note)
	var rows := request_rows()
	if rows.is_empty():
		_add_note(EMPTY_TEXT)
		return
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		_add_row(i, String(row.get("text", "")), String(row.get("value", "")))
```

The sentence "Finish one to get a new one." moves out of the footer and into `BOARD_NOTES[SUNNY]`, so it is still on the page and is now chapter keyed. Update any test that asserts the old footer string.

- [ ] **Step 7: Run everything**

```bash
tools/bin/godot --headless --path game --import
bash tools/run_tests.sh
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/collection_test.tscn 2>&1 | tail -2
```

- [ ] **Step 8: Commit**

```bash
git add game/systems/story_wording.gd game/systems/request_board.gd game/world/ranch.gd \
  game/ui/pause_menu.gd game/test/test_story_wording.gd game/test/test_request_board.gd \
  game/test/test_pause_menu.gd
git commit -m "feat: the board asks in the words of the chapter it is read in"
```

---

## Task 9: The story gate, the documentation, and the test floor

**Files:**
- Create: `game/scenes/test/story_test.gd`
- Create: `game/scenes/test/story_test.tscn`
- Modify: `docs/testing.md` (the gate list gains `story_test`)
- Modify: `tools/run_tests.sh` (`MIN_TESTS`)
- Test: the gate itself, plus the whole suite

**Interfaces:**
- Consumes: everything from Tasks 1 to 8: `Story`, `StoryBeat`, `StoryLibrary`, `StoryWording`, `Ranch.advance_story()/serve_requisition()/mail_rows()/owned_rows()/answer_mail()/get_mailbox()/is_near_mailbox()/open_mail_page()`, `PauseMenu.Page.MAIL`, `Pen.add_pony()`, `GameState.add_pony()`, `Compendium.State.PROCESSED`.
- Produces: the marker `STORY_OK checks=<n>` and exit code 0, or `STORY_FAILED` and exit 1.

- [ ] **Step 1: Write the gate scene**

Create `game/scenes/test/story_test.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/test/story_test.gd" id="1"]
[ext_resource type="PackedScene" path="res://world/ranch.tscn" id="2"]

[node name="StoryTest" type="Node"]
script = ExtResource("1")

[node name="Ranch" parent="." instance=ExtResource("2")]
```

- [ ] **Step 2: Write `game/scenes/test/story_test.gd`**

```gdscript
extends Node
## THE STORY GATE. The spec's story_test bullet, minus the halves that belong to slices 4
## and 5: the Survey chain fires only if answered, the Requisition takes EXACTLY the named
## pony and takes her by the departure path, every StoryBeat has a chapter that exists, a
## trigger the game can emit and no dash of either kind in its text, and the chapter ladder
## is walkable end to end by firing triggers (SUNNY to WEATHER, which is the whole of the
## ladder this slice ships).
##
## THE RANCH IS HOSTED HERE, not launched, the same way scenes/test/depot_test.gd's is; see
## that file's class comment for what _hosted changes and why this gate waits on
## gate_report_finished rather than polling for a symptom of it.
##
## THE REQUISITIONED PONY IS BUILT DIRECTLY INTO THE PEN with Pen.add_pony(), the way
## scenes/test/ledger_test.gd's resident is, and registered with GameState in the same
## breath, because that is what the ranch owns her by. She is not drawn from the roaming
## herd, so the census claim at the bottom of this file ("the world lost exactly the one
## pony who walked to the crate") has nothing to explain away.
##
## NOBODY DIES HERE. The one pony who leaves does it by Pony.leave_toward(), the same
## departure path a runaway and a Depot delivery use, and frees herself on arrival in
## Pony._state_leaving. There is no other exit from this world and this gate proves it by
## counting.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const StoryScript := preload("res://systems/story.gd")
const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryLibraryScript := preload("res://systems/story_library.gd")
const StoryWordingScript := preload("res://systems/story_wording.gd")
const LettersScript := preload("res://systems/letters.gd")
const CompendiumScript := preload("res://systems/compendium.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const InteractionScript := preload("res://world/interaction.gd")
const PauseMenuScript := preload("res://ui/pause_menu.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const SaveIOScript := preload("res://systems/save_io.gd")

const SLOT := 8  # a scratch slot; distinct from collection_test 5, ledger_test 6, depot_test 7

## The named pony the Survey is answered with. On the shipped roster
## (game/data/ponies/trixie.tres) and rare enough that delivering her is a real event.
const CHOSEN := &"trixie"

const SETTLE_FRAMES := 10

## Longest a requisition walk is given before it counts as a pony who never arrived. Taken
## from scenes/test/depot_test.gd's LEAVE_WAIT_FRAMES: the ceiling Pony.leave_toward()
## guarantees, plus a margin for the frame the timer is read on.
const LEAVE_WAIT_FRAMES := int(PonyScript.LEAVE_SECONDS * 60.0) + 60

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


func _set_check(label: String, ok: bool) -> void:
	if _checks.has(label):
		_duplicates.append(label)
		var suffix := 2
		while _checks.has("%s [dup %d]" % [label, suffix]):
			suffix += 1
		_checks["%s [dup %d]" % [label, suffix]] = ok
		return
	_checks[label] = ok


func _ready() -> void:
	GateWatchdogScript.arm(self, "STORY", 180.0)
	var ranch := $Ranch as Ranch

	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)

	var state = get_node("/root/GameState")
	var boot_population: int = ranch.spawner.get_spawned().size()

	# --- the corpus, structurally ----------------------------------------------------------
	var library = StoryLibraryScript.new()
	library.load_all()
	var beats: Array[StoryBeat] = library.all()
	_set_check("there are letters to read", beats.size() > 12)

	var registry = PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var params := {"name": "W".repeat(LettersScript.MAX_NAME_LENGTH),
		"pony": "Wwwwwwwwwwwwwwww", "colour": "viridian", "count": 999, "quota": 12,
		"balance": 40000}
	var chapters_ok := true
	var triggers_ok := true
	var dashes_ok := true
	var width_ok := true
	var reveals_ok := true
	for beat: StoryBeat in beats:
		if beat.chapter_index() < 0:
			chapters_ok = false
			push_error("story_test: %s names chapter '%s', which does not exist"
				% [beat.id, beat.chapter])
		if beat.trigger_index() < 0:
			triggers_ok = false
			push_error("story_test: %s names trigger '%s', which the game cannot emit"
				% [beat.id, beat.trigger])
		var letter: Dictionary = beat.render(params)
		var joined: String = String(letter["title"]) + "\n" + "\n".join(letter["body"])
		if joined.contains("--") or joined.contains(char(0x2014)):
			dashes_ok = false
			push_error("story_test: %s carries a dash" % beat.id)
		for line in letter["body"]:
			if String(line).length() > LettersScript.LINE_WIDTH:
				width_ok = false
				push_error("story_test: %s overflows on '%s'" % [beat.id, line])
		for revealed in beat.reveals:
			if registry.by_id(StringName(String(revealed))) == null:
				reveals_ok = false
				push_error("story_test: %s reveals '%s', who is not on the roster"
					% [beat.id, revealed])
	_set_check("every beat has a chapter that exists", chapters_ok)
	_set_check("every beat has a trigger the game can emit", triggers_ok)
	_set_check("no beat carries an em dash or a double hyphen", dashes_ok)
	_set_check("every letter fits the panel with the longest legal name in it", width_ok)
	_set_check("every revealed id is a character this build carries", reveals_ok)

	# --- the ladder, walked by firing triggers ----------------------------------------------
	var walked = StoryScript.new()
	var reached: Array[int] = [walked.chapter]
	for i in range(StoryScript.WEATHER_DELIVERIES):
		walked.note_delivery(false, "Pony", &"")
		if walked.advance():
			reached.append(walked.chapter)
	_set_check("the ladder walks SUNNY to WEATHER on deliveries alone",
		reached == [StoryScript.Chapter.SUNNY, StoryScript.Chapter.WEATHER] as Array[int])
	var opened_with := {}
	for beat: StoryBeat in library.due(walked):
		opened_with[beat.chapter_index()] = true
	_set_check("arriving in WEATHER puts something in the mailbox",
		opened_with.has(StoryScript.Chapter.WEATHER))

	# --- the Survey chain fires only if answered ---------------------------------------------
	var ignored = StoryScript.new()
	for i in range(StoryScript.WEATHER_DELIVERIES):
		ignored.note_delivery(false, "Pony", &"")
	ignored.advance()
	for beat: StoryBeat in library.due(ignored):
		ignored.post(beat.id)
	var requisitioned := false
	for i in range(30):
		ignored.note_collection_day()
		ignored.note_delivery(true, "Trixie", CHOSEN)
		ignored.advance()
		for beat: StoryBeat in library.due(ignored):
			ignored.post(beat.id)
			if beat.id == &"weather_requisition":
				requisitioned = true
	_set_check("an unanswered Survey never fires the Requisition, ever", not requisitioned)
	_set_check("and the letter is still sitting there unanswered",
		ignored.has_mail(&"weather_survey") and ignored.replied_to(&"weather_survey").is_empty())

	# --- the real ranch: a pen, a named pony, and the Survey answered ------------------------
	var slots: Array[PlotSlot] = ranch.plot_slots()
	var free_plot: PlotData = null
	for plot: PlotData in ranch.plots_catalogue().all():
		if plot.cost == 0:
			free_plot = plot
			break
	_set_check("there is an empty plot and a pen that costs nothing to put on it",
		slots.size() > 0 and slots[0].is_empty() and free_plot != null)
	if slots.is_empty() or free_plot == null:
		_finish()
		return
	_set_check("the pen goes up", slots[0].build(free_plot))
	var pen := slots[0].get_built() as Pen
	_set_check("the built slot is a real pen", pen != null)
	if pen == null:
		_finish()
		return

	var resident := PonyInstanceScript.create(CHOSEN)
	resident.happiness = 1.0
	_set_check("a named pony moves into the pen, off the roaming herd", pen.add_pony(resident))
	# AND THE RANCH OWNS HER. The pen holds her body; GameState holds the record every other
	# system addresses her by, and serve_requisition() refuses a pony the ranch does not own.
	_set_check("and the ranch owns her record", state.add_pony(resident))
	var chosen_uid: StringName = resident.uid

	await _frames(SETTLE_FRAMES)
	var before: Dictionary = _whole_world_refs(ranch, pen)
	_set_check("there is a census for the requisition to be measured against",
		before.size() > 1)

	# HER BODY, HELD AS A WEAK REFERENCE BEFORE ANYTHING TOUCHES HER. Pen.body_for() answers
	# null the moment release_body() clears her from the pen's books, which happens at the
	# START of the walk; so "did she walk" cannot be asked of the pen afterwards. It is asked
	# of the body itself: still alive right after the counter takes her (she is walking), gone
	# some seconds later (she freed herself on arrival, in Pony._state_leaving).
	var chosen_body: Node3D = pen.body_for(chosen_uid)
	_set_check("she has a body standing in the pen", chosen_body != null)
	var chosen_ref := weakref(chosen_body)

	# The chapter, the letters, and the picker, all through the ranch's own seams.
	for i in range(StoryScript.WEATHER_DELIVERIES):
		state.story.note_delivery(false, "Pony", &"")
	ranch.advance_story()
	_set_check("the ranch is in WEATHER", state.story.chapter == StoryScript.Chapter.WEATHER)
	_set_check("the Survey is in the mailbox", state.story.has_mail(&"weather_survey"))
	_set_check("the flag is up while something is unread", ranch.get_mailbox().is_flag_up())

	var picker: Array[Dictionary] = ranch.owned_rows()
	var offered := false
	for row: Dictionary in picker:
		if StringName(String(row["uid"])) == chosen_uid:
			offered = true
	_set_check("the picker offers the pony she owns", offered)

	var bits_before: int = ranch.get_economy().bits
	var hay_before: int = ranch._current_inventory().count(StoryScript.SURVEY_COUPON_ITEM)
	_set_check("she answers the Survey", ranch.answer_mail(&"weather_survey",
		String(chosen_uid)))
	_set_check("the bonus is exactly 50 bits",
		ranch.get_economy().bits == bits_before + StoryScript.SURVEY_BONUS_BITS)
	_set_check("and the coupon is hay",
		ranch._current_inventory().count(StoryScript.SURVEY_COUPON_ITEM)
			== hay_before + StoryScript.SURVEY_COUPON_COUNT)
	_set_check("answering twice pays nothing twice",
		not ranch.answer_mail(&"weather_survey", String(chosen_uid)))
	_set_check("the choice is saved for the slices that pay it off",
		String(state.story.survey_choice.get("data_id", "")) == String(CHOSEN))

	# --- the Requisition arrives, and the collector calls at dawn ----------------------------
	state.story.note_collection_day()
	state.story.note_collection_day()
	ranch.advance_story()
	_set_check("the Requisition arrives some collection days later",
		state.story.has_mail(&"weather_requisition"))
	_set_check("and it is armed rather than served on the spot",
		state.story.has_flag("requisition_posted")
			and not state.story.has_flag("requisition_served"))

	var quota_before: int = state.ledger.delivered_this_period
	var served: Dictionary = ranch.serve_requisition()
	_set_check("the collector takes her", bool(served["served"]))
	_set_check("and takes exactly the pony she named",
		String(served.get("name", "")) == resident.display_name())
	_set_check("she is out of the pen's own books", pen.find_pony(chosen_uid) == null)
	_set_check("and out of the ranch's", state.find_pony(chosen_uid) == null)
	_set_check("the delivery was counted like any other",
		state.ledger.delivered_this_period == quota_before + 1)
	_set_check("her entry reads PROCESSED",
		state.compendium.state_of(CHOSEN) == CompendiumScript.State.PROCESSED)
	_set_check("with the Employee's Choice star",
		StoryWordingScript.processed_value(state.story.chapter, true)
			.contains(StoryWordingScript.EMPLOYEES_CHOICE))
	_set_check("and it is served exactly once",
		not bool(ranch.serve_requisition()["served"]))

	# SHE LEAVES BY THE DEPARTURE PATH, which is two facts and not one: she is STILL THERE
	# when the counter has finished with her (nothing removed her; she is walking), and she is
	# gone some seconds later (she freed herself on arrival). Waited on as a STATE with a hard
	# frame cap, never as a fixed number of frames.
	_set_check("nothing removed her; she is on her hooves and walking",
		chosen_ref.get_ref() != null)
	var walking: Node3D = chosen_ref.get_ref() as Node3D
	_set_check("and the pony walking is the one the letter named",
		walking != null and walking.is_being_delivered())
	var arrived := false
	for i in range(LEAVE_WAIT_FRAMES):
		await get_tree().physics_frame
		if chosen_ref.get_ref() == null:
			arrived = true
			break
	_set_check("she walks to the crate and frees herself there", arrived)

	# --- nothing else in the world moved -------------------------------------------------------
	var survivors := 0
	for id in before:
		if before[id].get_ref() != null:
			survivors += 1
	_set_check("the world lost exactly the one pony who walked to the crate",
		survivors == before.size() - 1)
	var final_population: int = ranch.spawner.get_spawned().size()
	print("STORY population boot=%d final=%d" % [boot_population, final_population])
	_set_check("the roaming herd was never touched at all",
		final_population == boot_population)

	# --- the page she reads it all on ------------------------------------------------------
	var menu = ranch.get_pause_menu()
	var box: Node3D = ranch.get_mailbox()
	ranch.player.global_position = box.global_position + Vector3(1.2, 0.0, 0.0)
	ranch.player.global_position.y = ranch.terrain.height_at(
		ranch.player.global_position.x, ranch.player.global_position.z) + 0.15
	await _frames(SETTLE_FRAMES)
	_set_check("the player can stand at the mailbox", ranch.is_near_mailbox())
	var action: Dictionary = ranch.current_interaction()
	_set_check("the verb at the mailbox is the mail",
		int(action.get("kind", -1)) == InteractionScript.Kind.MAILBOX)
	_set_check("pressing it opens the page", ranch.perform_interaction(action))
	_set_check("and the page is MAIL", menu.is_open() and menu.page() == PauseMenuScript.Page.MAIL)
	var rows: Array[Dictionary] = menu.mail_rows()
	_set_check("the mailbox holds every letter she has ever been sent",
		rows.size() == state.story.mail_ids().size())
	_set_check("newest first", rows.size() > 1
		and String(rows[0]["id"]) == String(state.story.mail_ids()[rows.size() - 1]))
	var page_lines: Array[String] = menu.mail_lines()
	var page_clean := true
	for line: String in page_lines:
		if line.contains("--") or line.contains(char(0x2014)):
			page_clean = false
	_set_check("and nothing on the page carries a dash", page_clean)
	menu.close()

	var path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_finish()


## A WeakRef to every pony body standing in the world right now: the roaming herd and every
## resident of every built pen. Copied from scenes/test/depot_test.gd's own census.
func _whole_world_refs(ranch: Ranch, pen: Pen) -> Dictionary:
	var out := {}
	for pony: Pony in ranch.spawner.get_spawned():
		out[pony.get_instance_id()] = weakref(pony)
	for slot: PlotSlot in ranch.plot_slots():
		var built := slot.get_built() as Pen
		if built == null:
			continue
		for inst: PonyInstance in built.ponies():
			var body: Node3D = built.body_for(inst.uid)
			if body != null:
				out[body.get_instance_id()] = weakref(body)
	return out


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _finish() -> void:
	var all_ok := _duplicates.is_empty()
	for label in _checks:
		if not _checks[label]:
			push_error("story_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("story_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("STORY_OK " if all_ok else "STORY_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
```

- [ ] **Step 3: Run the gate**

```bash
tools/bin/godot --headless --path game --import
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/story_test.tscn
echo "exit: $?"
```

Expected: `STORY_OK checks=<n>` on the last line and exit 0. If a check fails, its label is printed by `push_error` above the marker; fix the cause. Two traps this gate is likely to hit first:

- **The walk never finishes.** The loop waits for `chosen_ref.get_ref()` to go null, which only happens in `Pony._state_leaving` when she reaches the crate. If it times out, print `walking.global_position` against `ranch.crate_position()` each frame: a pony who is not moving was never handed a destination, and a pony moving away from the crate is walking to the wrong marker.
- **`serve_requisition()` returns `{"served": false}`.** Print `state.story.survey_choice` and `ranch._penned(chosen_uid)`; the usual cause is the record not being registered with `GameState`, which the `state.add_pony(resident)` line above exists to prevent.

- [ ] **Step 4: Prove the gate can fail**

An assertion that has never failed is not an assertion. Temporarily edit one `.tres` body line to contain a double hyphen, re-run the gate, and confirm it prints `STORY_FAILED` and exits 1. Revert the edit and confirm green again.

```bash
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/story_test.tscn; echo "exit: $?"
```

- [ ] **Step 5: Write the gate up in `docs/testing.md`**

Add a section beside the `depot_test` and `casino_test` ones, in the same shape they use:

````markdown
### `story_test` (Phase 3 slice 3)

```
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/story_test.tscn
```

Prints `STORY_OK checks=<n>` and exits 0, or `STORY_FAILED` and exits 1. It hosts the real
ranch and proves the paper channel end to end:

* every `StoryBeat` in `game/data/story/` names a chapter that exists, a trigger the game
  can emit and a reply control this build has; every letter fits `Letters.LINE_WIDTH` with
  the longest legal player name in it; none of them carries an em dash or a double hyphen.
* the chapter ladder is walkable by firing triggers, and arriving in a chapter always puts
  something in the mailbox.
* the Employee Appreciation Survey fires the Priority Requisition **only if answered**: an
  ignored Survey is walked through thirty collection days and never produces one.
* answering it pays 50 bits and a hay coupon exactly once, and the choice is saved.
* the Requisition takes exactly the pony she named, by the departure path, and the world
  loses precisely that one pony and no other; her Compendium entry reads `PROCESSED`.
* the mailbox verb opens the Mail page, the page holds every letter ever sent, newest
  first, and nothing on it carries a dash.
````

Also add `story_test` to whatever gate list `docs/testing.md` keeps at the top, and to the
sweep in any script that runs every gate in turn.

- [ ] **Step 6: Raise the test floor, and prove the floor still bites**

```bash
bash tools/run_tests.sh 2>&1 | tee /tmp/story-suite.log | tail -20
grep -E "^Tests[[:space:]]" /tmp/story-suite.log
```

Read the number the suite actually reports and put exactly that number in
`tools/run_tests.sh`:

```bash
MIN_TESTS="${FILLY_MIN_TESTS:-<the number the run above printed>}"
```

Then prove the guard is real, both ways:

```bash
FILLY_MIN_TESTS=99999 bash tools/run_tests.sh; echo "expected non zero: $?"
bash tools/run_tests.sh; echo "expected 0: $?"
```

The first must fail with the "below this suite's floor" message; the second must pass.

- [ ] **Step 7: The whole board, green**

```bash
for scene in smoke camera walk world region market collection ledger depot creation casino story; do
  printf '%-12s ' "$scene"
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene""_test.tscn" 2>&1 \
    | grep -E "_OK|_FAILED" | tail -1
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -1
```

Adjust the scene names to the ones on disk (`scenes/test/smoke.tscn` has no `_test` suffix).
Every line must be an `_OK`, and the ranch must print `RANCH_OK ponies=49 props=111
assets=present`.

- [ ] **Step 8: Commit**

```bash
tools/bin/godot --headless --path game --import
git add game/scenes/test/story_test.gd game/scenes/test/story_test.gd.uid \
  game/scenes/test/story_test.tscn docs/testing.md tools/run_tests.sh
git commit -m "test: the story gate, and the floor raised to meet it"
```

---

## Done means

- `bash tools/run_tests.sh` green at the raised floor, and `FILLY_MIN_TESTS=99999` still red.
- `RANCH_OK ponies=49 props=111 assets=present`, and every other gate still `_OK`, including
  the new `STORY_OK`.
- A fresh ranch has a letter in the mailbox and the flag up before the player takes a step.
- The Mail page is a drawn sheet with a letterhead, envelope cards and a breathing focus
  ring, reachable from the mailbox with E and from the pause menu's Mail row, and driveable
  on a gamepad with no mouse.
- The Survey can be ignored forever. Answered, it pays 50 bits and a hay coupon once, and
  two collection days later a collector walks the named pony to the crate by the departure
  path while the Compendium files her under the Company's word for it.
- No em dash and no double hyphen in a single new line, and the word this project does not
  use appears nowhere.

## Parked for the owner

- **The `WEATHER` threshold is three deliveries.** It is a pacing guess held by a test
  (`test_the_first_five_sessions_each_bring_at_least_one_letter`), not a playtested number.
  If the owner's session is longer or shorter than the spec's model, `Story.WEATHER_DELIVERIES`
  is the one line to move.
- **The Requisition credits the delivery.** The spec says the Requisition arrives "with the
  bonus schedule attached", so the pony is walked through `deliver_pony()` and the balance is
  credited exactly as a counter delivery would be. If the owner would rather she was taken
  for nothing, that is a one line change and a different, colder joke.
- **`weather_wellbeing` is an extra letter this plan added** to keep session five fed. It is
  the most explicit letter in the slice ("The answer is: weather") and it is the one to cut
  first if the reveal should stay quieter for longer.
