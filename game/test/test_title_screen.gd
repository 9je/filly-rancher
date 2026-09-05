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
