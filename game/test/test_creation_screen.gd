extends GutTest
## The creation screen, driven through its own methods rather than through a mouse.

const CreationScreenScene := preload("res://ui/creation_screen.tscn")
const MarkLayoutScript := preload("res://systems/mark_layout.gd")
const PlayerLookScript := preload("res://systems/player_look.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")

## Matches test_letter_panel.gd's own VIEWPORT_HEIGHT: game/project.godot's base viewport,
## the size the LOOK step's column has to fit inside with margin (C1, final-review.md).
const VIEWPORT_HEIGHT := 1080.0

var _screen: CreationScreen = null


func before_each() -> void:
	_screen = CreationScreenScene.instantiate()
	add_child_autofree(_screen)
	_screen.open(PlayerLookScript.default_look())


func after_each() -> void:
	get_tree().paused = false


func test_it_opens_on_the_default_look() -> void:
	assert_true(_screen.is_open())
	assert_eq(_screen.look().player_name, PlayerLookScript.DEFAULT_NAME)


func test_cycling_a_swatch_row_wraps_and_stays_in_range() -> void:
	var palette: StockPalette = StockPaletteScript.load_player()
	for i in palette.coats.size() + 3:
		_screen.cycle_coat(1)
		assert_between(_screen.look().coat, 0, palette.coats.size() - 1)
	_screen.cycle_coat(-1)
	assert_between(_screen.look().coat, 0, palette.coats.size() - 1)


func test_every_row_can_be_cycled_independently() -> void:
	_screen.cycle_coat(1)
	_screen.cycle_mane(2)
	_screen.cycle_eyes(3)
	var look: PlayerLook = _screen.look()
	assert_ne(look.coat, look.mane, "three rows, three choices")


func test_a_typed_name_is_sanitised_into_the_look() -> void:
	_screen.set_name_text("  Moon--beam  ")
	assert_eq(_screen.look().player_name, "Moonbeam")


func test_a_drawn_mark_reaches_the_look_on_confirm() -> void:
	_screen.canvas().set_colour(Color(0.2, 0.6, 0.9))
	_screen.canvas().stamp(MarkStampsScript.Stamp.GEM)
	watch_signals(_screen)
	assert_true(_screen.confirm())
	assert_signal_emitted(_screen, "confirmed")
	var look: PlayerLook = _screen.look()
	assert_true(look.has_mark())
	assert_true(MarkPaintScript.equal(look.mark(), _screen.canvas().image()))


func test_confirming_closes_the_screen_and_unpauses_the_world() -> void:
	_screen.confirm()
	assert_false(_screen.is_open())
	assert_false(get_tree().paused)


func test_confirming_twice_emits_once() -> void:
	watch_signals(_screen)
	assert_true(_screen.confirm())
	assert_false(_screen.confirm())
	assert_signal_emit_count(_screen, "confirmed", 1)


func test_the_turntable_holds_a_tinted_pony() -> void:
	if _screen.model() == null:
		pass_test("no converted assets on this machine")
		return
	# v1: PonyPaint's toon materials. Headless runs skip the shader swap, so it is switched
	# on for this one check.
	var was := ToonStyler.shading_enabled
	ToonStyler.shading_enabled = true
	_screen.cycle_coat(2)
	var palette: StockPalette = StockPaletteScript.load_player()
	var found := false
	for node in _screen.model().find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			var src := mi.mesh.surface_get_material(i)
			if src != null and src.resource_name == "body" and mi.get_active_material(i) is ShaderMaterial:
				var m := mi.get_active_material(i) as ShaderMaterial
				assert_eq(m.get_shader_parameter(&"albedo"), palette.coat_at(_screen.look().coat),
					"the swatch she picked is the colour standing on the turntable")
				found = true
	ToonStyler.shading_enabled = was
	assert_true(found, "the turntable pony has a painted coat")


func test_nothing_the_screen_draws_carries_a_dash() -> void:
	for line in _screen.drawn_lines():
		assert_false(line.contains("--"), "'%s' carries a double hyphen" % line)
		assert_false(line.contains(char(0x2014)), "'%s' carries an em dash" % line)


# --- the ink row --------------------------------------------------------------------------
##
## THE GAP THESE PIN. MarkCanvas.set_colour() shipped with the canvas and nothing ever
## called it, so every cutie mark in the game came out the one hard coded grey the widget
## opens on. The screen now has a row of ink buttons over it, and what matters is that
## PRESSING ONE reaches the canvas: an ink row that changes a swatch and not the ink is the
## same bug with a nicer face on it.

## The first non transparent pixel in `image`, or EMPTY if she drew nothing. Read this way
## rather than at a fixed coordinate because a headless Control has no layout, so the canvas
## maps every local point to the same pixel; WHERE the ink landed is not what is under test
## here, WHICH ink landed is.
func _first_ink(image: Image) -> Color:
	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0:
				return pixel
	return MarkPaintScript.EMPTY


## An 8-bit-per-channel image cannot store a float colour exactly, so this is the tolerance
## a round trip through Image.set_pixel/get_pixel actually needs (1/255 is about 0.004).
func _same_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func test_the_screen_offers_a_row_of_inks() -> void:
	assert_gt(CreationScreen.ink_count(), 1, "one ink is not a palette")
	assert_eq(CreationScreen.INK_NAMES.size(), CreationScreen.INK_COLOURS.size(),
		"every ink has a name and every name has an ink")


func test_the_ink_buttons_exist_and_are_wired_to_the_canvas() -> void:
	var canvas: MarkCanvas = _screen.canvas()
	for index in CreationScreen.ink_count():
		var button := _screen.get_node_or_null(
			NodePath("Layout/Panel/Margin/Column/InkRow/Ink%d" % index)) as BaseButton
		assert_not_null(button, "ink %d has no button to press" % index)
		if button == null:
			continue
		# A pot of the ink (Fable AAA round 4), its name as the pointer's tooltip.
		assert_eq((button as Button).tooltip_text, CreationScreen.ink_name(index),
			"the pot is named what the const says")
		button.pressed.emit()
		canvas.clear_all()
		canvas.paint_at(Vector2.ZERO)
		assert_true(_same_colour(_first_ink(canvas.image()), CreationScreen.ink_at(index)),
			"pressing ink %d has to reach the canvas, not only the swatch" % index)


func test_two_different_inks_leave_two_different_colours() -> void:
	var canvas: MarkCanvas = _screen.canvas()
	_screen.set_ink(0)
	canvas.clear_all()
	canvas.paint_at(Vector2.ZERO)
	var first: Color = _first_ink(canvas.image())
	_screen.set_ink(1)
	canvas.clear_all()
	canvas.paint_at(Vector2.ZERO)
	var second: Color = _first_ink(canvas.image())
	assert_false(_same_colour(first, second),
		"two inks that paint the same colour are one ink and a lie")


func test_picking_an_ink_turns_the_eraser_off() -> void:
	var canvas: MarkCanvas = _screen.canvas()
	canvas.set_eraser(true)
	assert_true(canvas.is_erasing())
	_screen.set_ink(2)
	assert_false(canvas.is_erasing(), "asking for a colour is asking to draw with it")


func test_the_ink_names_are_part_of_what_the_screen_draws() -> void:
	var drawn: Array[String] = _screen.drawn_lines()
	for index in CreationScreen.ink_count():
		assert_true(drawn.has(CreationScreen.ink_name(index)),
			"ink '%s' is on a button, so the copy rule applies to it"
				% CreationScreen.ink_name(index))


func test_cycling_the_mane_style_row_walks_the_pool_and_comes_back() -> void:
	# v1: the pool is her race's donor bodies (PlayerLook.styles_for), not the old four.
	var n: int = PlayerLookScript.style_count(_screen.look().race)
	for i in n:
		assert_eq(_screen.look().mane_style, i)
		_screen.cycle_mane_style(1)
	assert_eq(_screen.look().mane_style, 0, "one full lap returns to the base model")


func test_cycling_backwards_from_zero_reaches_the_last_style() -> void:
	_screen.cycle_mane_style(-1)
	assert_eq(_screen.look().mane_style, PlayerLookScript.style_count(_screen.look().race) - 1)


func test_the_mane_style_survives_confirm() -> void:
	_screen.cycle_mane_style(2)
	_screen.confirm()
	assert_eq(_screen.look().mane_style, 2)


# --- the rebuilt screen -----------------------------------------------------------------

## THE OWNER'S TWO COMPLAINTS, PINNED. Acceptance item 1: "New save: no frame of raw world,
## CC full-screen, pony clearly visible." Acceptance item 2: "CC layout reads industry
## standard, mouse-driven."

const SwatchGridScript := preload("res://ui/swatch_grid.gd")
const CreationBackdropScript := preload("res://ui/creation_backdrop.gd")


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


## C1, final-review.md: the LOOK step's four grids at 72 px cells and 6/3 columns put the
## column at 1281 px in a 1080 px viewport -- off screen, no scrollbar, no wheel handler.
##
## MEASURES THE COLUMN'S OWN MINIMUM SIZE, NOT A LIVE Panel.size. The report's own
## reproduction did the same ("column_min = (512.0, 1281.0)", instantiating the screen and
## reading get_combined_minimum_size() on Layout/Panel/Margin/Column) rather than reading a
## laid-out Panel.size the way test_letter_panel.gd's own viewport test does -- and for a
## reason specific to this screen: Layout is a full-rect HBoxContainer, not letter_panel.gd's
## CenterContainer, so a live Panel.size here is however much of the ACTUAL window the
## engine's "expand" stretch mode hands the layout, which is not 1920x1080 under every
## headless test runner's own default window shape. The column's intrinsic minimum size is
## content driven and answers the same question ("does this fit 1080 with margin") without
## depending on what shape window happens to be running the test.
func test_the_look_and_mark_steps_both_fit_the_1080_viewport() -> void:
	for step: int in [CreationScreen.Step.LOOK, CreationScreen.Step.MARK]:
		_screen.set_step(step)
		await get_tree().process_frame
		await get_tree().process_frame
		var column := _screen.get_node("Layout/Panel/Margin/Column") as VBoxContainer
		var column_min: Vector2 = column.get_combined_minimum_size()
		assert_lte(column_min.y, VIEWPORT_HEIGHT,
			"step %d's column must leave its confirm button on screen, got %f"
				% [step, column_min.y])


## The regression C1 pins directly: the LOOK column's OWN minimum height (not the panel it
## sits in, which a MarginContainer can clip) has to be comfortably under the viewport so a
## palette entry added later has headroom before it reproduces C1.
func test_the_look_columns_minimum_height_leaves_margin_under_1080() -> void:
	_screen.set_step(CreationScreen.Step.LOOK)
	await get_tree().process_frame
	await get_tree().process_frame
	var column := _screen.get_node("Layout/Panel/Margin/Column") as VBoxContainer
	var column_min: Vector2 = column.get_combined_minimum_size()
	assert_lt(column_min.y, 1000.0,
		"the LOOK column's real minimum height must clear the 1080 viewport with margin, got %f"
			% column_min.y)


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
	assert_eq(grid.cell_count(), PlayerLookScript.style_count(_screen.look().race))
	# Pictures of each style, in her colours, named in a tooltip (Fable AAA round 4).
	assert_not_null(grid.cell(0).icon, "a style card is a picture of the style")
	assert_eq(grid.cell(0).tooltip_text, "Style 1")


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


# --- the keyboard's own cursor, fix round 1 -----------------------------------------------
##
## CONTROLLER RULING: the spec's global "keyboard must remain FULLY functional on every
## screen" outranks task-8-brief.md's own Step 8.4, which left `_confirm`, the step buttons
## and every SwatchGrid cell FOCUS_NONE with nothing to compensate. Every test below drives
## the screen through the same small set of public methods _unhandled_input() itself calls
## (switch_region/move_highlight/activate_highlight/release_name_edit), never through a
## mouse position or a simulated InputEvent -- exactly test_build_menu.gd's own convention
## for move_selection()/confirm(), which the class comment on creation_screen.gd's cursor
## section names directly. Every one of these calls the pre fix-round build did not have at
## all: run against that build, the very first `_screen.kb_region()` below is a call to a
## method that does not exist, which GUT reports as an error and a failed test, not a
## silent pass -- this is what "must fail if the keyboard path breaks" means in practice.

## Walk Tab-equivalents (switch_region(1)) until the cursor reaches `region`, and fail
## loudly with a bounded loop rather than hanging if it never arrives -- a region that Tab
## cannot reach is exactly the bug finding 1 described.
func _goto_region(region: StringName) -> void:
	var guard := 0
	while _screen.kb_region() != region and guard < 20:
		_screen.switch_region(1)
		guard += 1
	assert_eq(_screen.kb_region(), region, "region '%s' reachable by Tab alone" % region)


func test_a_full_keyboard_walkthrough_can_finish_creation_with_no_mouse() -> void:
	_screen.open(PlayerLookScript.default_look())
	assert_eq(_screen.step(), CreationScreen.Step.LOOK, "she meets her pony first")
	assert_eq(_screen.kb_region(), &"name", "the cursor opens on the name field")

	# --- pick a coat, purely by keyboard ----------------------------------------------------
	# Pinned to a known starting swatch first: the cursor opens a grid region on its current
	# pick (see _enter_kb_region()'s own comment), and the default look's own coat index is
	# not necessarily 0, so "ui_right x2" only lands on index 2 from a known index 0.
	_screen.set_coat(0)
	_goto_region(&"coat")
	_screen.move_highlight(2)
	assert_eq(_screen.kb_item(), 2, "ui_right x2 moved the highlight, not the pick")
	_screen.activate_highlight()
	assert_eq(_screen.look().coat, 2, "ui_accept on the highlighted swatch is the coat she gets")

	# --- reach the MARK step, purely by keyboard --------------------------------------------
	# v1: three tabs, Your pony, Mane and tail, Your cutie mark; the mark is the third.
	_goto_region(&"step")
	_screen.move_highlight(2)
	_screen.activate_highlight()
	assert_eq(_screen.step(), CreationScreen.Step.MARK,
		"the step tabs are keyboard reachable")

	# --- stamp a shape, purely by keyboard ---------------------------------------------------
	_goto_region(&"stamp")
	assert_true(MarkPaintScript.is_blank(_screen.canvas().image()), "precondition: a clean canvas")
	_screen.activate_highlight()
	assert_false(MarkPaintScript.is_blank(_screen.canvas().image()),
		"a keyboard stamp actually reaches the canvas, not only the highlight")

	# --- confirm, purely by keyboard ---------------------------------------------------------
	_goto_region(&"confirm")
	watch_signals(_screen)
	_screen.activate_highlight()
	assert_false(_screen.is_open(), "confirm reached with no mouse click anywhere in this test")
	assert_signal_emitted(_screen, "confirmed")


func test_the_name_field_keeps_typing_and_the_cursor_leaves_it_alone() -> void:
	assert_eq(_screen.kb_region(), &"name")
	_screen.activate_highlight()
	assert_true(_screen.is_editing_name(), "ui_accept on the name region grabs real focus")
	# A stray nav call while she is typing must not release the field or move the cursor:
	# these are exactly the calls _unhandled_input() itself never makes while has_focus() is
	# true, exercised here directly so the guard is proven even if that early return breaks.
	_screen.move_highlight(1)
	_screen.switch_region(1)
	assert_true(_screen.is_editing_name(), "a nav call mid-edit must not release the field")
	assert_eq(_screen.kb_region(), &"name", "...nor move the region cursor")
	_screen.release_name_edit()
	assert_false(_screen.is_editing_name(), "Escape gives the field back")


func test_the_mane_style_cards_retint_when_the_mane_changes() -> void:
	var grid := _screen.find_child("ManeStyleGrid", true, false) as SwatchGrid
	assert_not_null(grid)
	var palette: StockPalette = StockPaletteScript.load_player()
	# The cards are pictures in her colours (Fable AAA round 4): the picture is recoloured.
	_screen.set_mane(0)
	var before: Texture2D = grid.cell(0).icon
	assert_not_null(before, "the cards open as pictures")
	_screen.set_mane(1)
	var after: Texture2D = grid.cell(0).icon
	assert_ne(before, after, "picking a different mane has to retint the cards")
	assert_eq(after, _card(palette, 1), "...to the mane she actually picked")


func test_cycle_mane_also_retints_the_mane_style_cards() -> void:
	var grid := _screen.find_child("ManeStyleGrid", true, false) as SwatchGrid
	_screen.set_mane(0)
	_screen.cycle_mane(1)
	var palette: StockPalette = StockPaletteScript.load_player()
	assert_eq(grid.cell(0).icon, _card(palette, _screen.look().mane),
		"cycle_mane() is set_mane() with a step added; the retint has to come along with it")


## The first style card as the screen should show it for mane `mane` on her coat.
func _card(palette: StockPalette, mane: int) -> Texture2D:
	var path := "res://assets/ui/style_icons/mane_%d_0.png" % _screen.look().race
	return StyleIconTint.tinted(load(path) as Texture2D, palette.coat_at(_screen.look().coat),
		palette.mane_at(mane))


func test_the_kind_of_pony_row_changes_her_race_and_her_style_pool() -> void:
	_screen.set_race(PlayerLookScript.RACE_PEGASUS)
	assert_eq(_screen.look().race, PlayerLookScript.RACE_PEGASUS)
	assert_eq(_screen.look().mane_style, 0, "a new kind starts on its first style")
	var grid := _screen.find_child("ManeStyleGrid", true, false) as SwatchGrid
	assert_eq(grid.cell_count(), PlayerLookScript.style_count(PlayerLookScript.RACE_PEGASUS))
	assert_eq(StringName(DonorTable.load_table().find(
		_screen.look().to_pony_look(StockPalette.load_player()).donor).get("race", "")), &"pegasus")


func test_the_streak_and_tail_rows_default_to_the_mane_and_take_their_own_colour() -> void:
	var pal := StockPalette.load_player()
	assert_eq(_screen.look().to_pony_look(pal).tail, pal.mane_at(_screen.look().mane))
	_screen.set_tail(5)
	_screen.set_mane2(2)
	var l := _screen.look().to_pony_look(pal)
	assert_eq(l.tail, pal.mane_at(5))
	assert_eq(l.mane2, pal.mane_at(2))
	_screen.set_tail(-1)
	assert_eq(_screen.look().to_pony_look(pal).tail, pal.mane_at(_screen.look().mane), "-1 is the mane again")


func test_the_three_steps_fit_a_1080_screen() -> void:
	for step in [CreationScreen.Step.LOOK, CreationScreen.Step.HAIR, CreationScreen.Step.MARK]:
		_screen.set_step(step)
		await wait_frames(2)
		var col := _screen.find_child("Column", true, false) as Control
		assert_lt(col.get_combined_minimum_size().y, 1000.0, "step %d fits" % step)


## OWNER PLAYTEST 2026-10-25: "cant customize my ponies hair". The turntable pony was built
## from the old four-unicorn list while the paint used her race's donor list, so past the
## fourth style (and for every earth pony and pegasus) the mane names did not match and the
## mane kept the donor's own texture. Every style of every race must wear the picked mane.
func test_every_style_of_every_race_wears_the_picked_mane() -> void:
	if _screen.model() == null:
		pending("assetless checkout")
		return
	# The paint finds the mane by the donor row's surface names (PonyPaint.role_of), so the
	# body on the turntable must carry the surfaces that row names.
	var palette := StockPalette.load_player()
	var table := DonorTable.load_table()
	for race in [PlayerLookScript.RACE_EARTH, PlayerLookScript.RACE_PEGASUS,
			PlayerLookScript.RACE_UNICORN]:
		_screen.set_race(race)
		for style in PlayerLookScript.style_count(race):
			_screen.set_mane_style(style)
			var donor: StringName = _screen.look().to_pony_look(palette).donor
			var mane_names: PackedStringArray = table.find(donor).get("mane", PackedStringArray())
			var found := 0
			for mi: MeshInstance3D in _screen.model().find_children("*", "MeshInstance3D", true, false):
				if mi.mesh == null:
					continue
				for i in mi.mesh.get_surface_count():
					var m := mi.mesh.surface_get_material(i)
					if m != null and m.resource_name in mane_names:
						found += 1
			assert_gt(found, 0, "race %d style %d (%s): the turntable body has the mane the paint colours"
				% [race, style, donor])


## PT11 (playtest 2026-11-05: "maybe random on pony creation?", "cutie mark creation has to be
## better", "mane style isnt under mane and tail", "mane streak is visible always").
func test_surprise_me_makes_a_new_pony_and_a_mark() -> void:
	var before: Dictionary = _screen.look().to_dict()
	_screen.surprise(4242)
	var after: Dictionary = _screen.look().to_dict()
	assert_ne(JSON.stringify(after), JSON.stringify(before), "something about her changed")
	assert_eq(after.get("player_name", ""), before.get("player_name", ""), "her name is kept")


func test_a_talent_lands_on_the_canvas() -> void:
	_screen.set_step(CreationScreen.Step.MARK)
	_screen.canvas().clear_all()
	_screen.use_talent(&"music")
	var img: Image = _screen.canvas().image()
	var inked := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a > 0.5:
				inked += 1
	assert_gt(inked, 10, "the music note is on the canvas")


func test_mane_style_is_on_the_hair_step() -> void:
	assert_has(CreationScreen.HAIR_REGIONS, &"mane_style")
	assert_does_not_have(CreationScreen.LOOK_REGIONS, &"mane_style")


func test_the_streak_row_shows_only_for_a_style_with_a_streak() -> void:
	_screen.set_step(CreationScreen.Step.HAIR)
	var row := _screen.find_child("Mane2Grid", true, false) as Control
	assert_eq(row.visible, _screen.style_has_streak())


## Fable AAA round 3, #9: the sheet was wider on the cutie mark step, so the turntable jumped.
func test_the_sheet_is_one_width_on_every_step() -> void:
	var panel := _screen.get_node(^"Layout/Panel") as Control
	var widths: Array[float] = []
	for step: int in [CreationScreen.Step.LOOK, CreationScreen.Step.HAIR, CreationScreen.Step.MARK,
			CreationScreen.Step.STYLE]:
		_screen.set_step(step)
		widths.append(maxf(panel.custom_minimum_size.x, panel.get_combined_minimum_size().x))
	for w: float in widths:
		assert_almost_eq(w, widths[0], 0.5, "every step asks for the same sheet width")


## Fable AAA round 3, #6: a stamp lands in its own colours, not the ink's charcoal.
func test_a_stamp_lands_in_its_own_colours() -> void:
	_screen.set_step(CreationScreen.Step.MARK)
	assert_true(_screen.stamp_symbol(&"talent:orchards"))
	var laid: Dictionary = _screen.canvas().stamps()[0]
	assert_eq(laid.a, MarkLayoutScript.palette(&"talent:orchards")[0], "an apple is apple red")
