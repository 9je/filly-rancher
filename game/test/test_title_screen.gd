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
	# C2's default-row fix reads can_continue() in _ready(), before a test gets a chance to
	# set has_save_provider on the instance -- so this has to be set before the node enters
	# the tree, not after. false keeps every pre-existing test's assumption that the cursor
	# starts on row 0 (New game) true; tests that care about the other branch build their own
	# TitleScreen through _new_title() below instead of reaching for this shared one.
	_title.has_save_provider = func() -> bool: return false
	add_child_autofree(_title)


## A TitleScreen with its own has_save_provider, set before it ever enters the tree, so
## _ready()'s can_continue() read (C2's default-row pick) sees exactly what this test wants.
func _new_title(has_save: bool) -> TitleScreen:
	var title: TitleScreen = preload("res://ui/title_screen.tscn").instantiate()
	title.has_save_provider = func() -> bool: return has_save
	add_child_autofree(title)
	return title


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


func test_every_row_is_armed_for_the_pointer() -> void:
	var armed := 0
	for child in _title.get_node("Centre/Panel/Margin/Column/Rows").get_children():
		if MouseRowsScript.row_index(child as Control) >= 0:
			armed += 1
	assert_eq(armed, _title.row_count(),
		"every row the keyboard reaches, the mouse reaches")


func test_no_key_hints_are_shown() -> void:
	var footer := _title.get_node("Centre/Panel/Margin/Column/Footer") as Label
	assert_false(footer.visible, "PT5: no row of key hints")


# --- C2: the default row, and the second confirm on New game ------------------------------

func test_the_default_row_is_new_game_when_there_is_no_save() -> void:
	var title := _new_title(false)
	assert_eq(title.selected_index(), TitleScreen.Row.NEW_GAME,
		"nothing to lose, so New game starts selected, exactly as before this fix")


func test_the_default_row_is_continue_when_a_save_exists() -> void:
	var title := _new_title(true)
	assert_eq(title.selected_index(), TitleScreen.Row.CONTINUE,
		"a returning player must not land one Enter away from erasing her ranch")


func test_a_single_press_on_new_game_does_not_latch_when_a_save_exists() -> void:
	var title := _new_title(true)
	title.point_at_row(TitleScreen.Row.NEW_GAME)
	assert_true(title.confirm(), "the first press is not a refusal, it is an arm")
	assert_false(BootIntentScript.peek_new_game(),
		"one press must not be enough to destroy the owner's save")


func test_a_double_press_on_new_game_latches_when_a_save_exists() -> void:
	var title := _new_title(true)
	title.point_at_row(TitleScreen.Row.NEW_GAME)
	title.confirm()
	assert_true(title.confirm(), "the second press is the real confirm")
	assert_true(BootIntentScript.peek_new_game())


func test_a_single_press_on_new_game_still_latches_with_no_save_to_lose() -> void:
	var title := _new_title(false)
	title.point_at_row(TitleScreen.Row.NEW_GAME)
	assert_true(title.confirm())
	assert_true(BootIntentScript.peek_new_game(),
		"a fresh machine has nothing to arm a confirmation over")


func test_moving_off_new_game_disarms_the_second_confirm() -> void:
	var title := _new_title(true)
	title.point_at_row(TitleScreen.Row.NEW_GAME)
	title.confirm()
	title.move_selection(1)
	title.point_at_row(TitleScreen.Row.NEW_GAME)
	assert_true(title.confirm(), "moving away and back must ask for a fresh second press")
	assert_false(BootIntentScript.peek_new_game())


func test_escape_disarms_new_game_instead_of_quitting() -> void:
	var title := _new_title(true)
	title.point_at_row(TitleScreen.Row.NEW_GAME)
	title.confirm()
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	title._unhandled_input(escape)
	title.point_at_row(TitleScreen.Row.NEW_GAME)
	assert_true(title.confirm(), "escape must clear the arm, not spend the second press")
	assert_false(BootIntentScript.peek_new_game())


# --- Settings: one shared tabbed menu (docs/playtest_fixes/settings.md) ----------------


func test_the_settings_row_opens_the_shared_settings_menu_and_gives_the_cursor_back() -> void:
	_title.point_at_row(TitleScreen.Row.SETTINGS)
	_title.confirm()
	assert_true(_title.on_settings_page())
	assert_eq(_title.settings_menu().settings, _title.settings)
	_title.back()
	assert_false(_title.on_settings_page())
	assert_eq(_title.selected_index(), TitleScreen.Row.SETTINGS,
		"leaving Settings puts the cursor back on the row that opened it")
