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
const LoadingScreenScript := preload("res://ui/loading_screen.gd")
const SettingsMenuScene := preload("res://ui/settings_menu.tscn")

enum Row { NEW_GAME, CONTINUE, SETTINGS, QUIT }

const ROWS: Array[String] = ["New game", "Continue", "Settings", "Quit"]

const TITLE := "Filly Rancher"
const SETTINGS_TITLE := "Settings"
const NO_SAVE_NOTE := "No saved ranch on this machine yet."

## C2, final-review.md: New game is one Enter away from `_game_state.reset()` with no way
## back, on a screen that used to default its cursor to it. This is the second confirm the
## armed row asks for -- printed where the footer already lives, since that is the one line
## on this screen that is always on screen and always read before a key is pressed.
const NEW_GAME_CONFIRM_TEXT := "Really start over? Enter again to confirm"

## SETTINGS IS ONE MENU WITH TWO DOORS: this row and the pause menu's both open
## game/ui/settings_menu.tscn over themselves (the playtest note "Settings UI is awful and
## hard to navigate", docs/playtest_fixes/settings.md).
var _settings_menu: SettingsMenu = null

const WORLD_SCENE := "res://world/ranch.tscn"

## Injected by a test. Unset, the screen asks SaveIO itself, which is what the real boot does.
var has_save_provider := Callable()

var settings: Settings = null

var _selected := 0
var _hovered := -1
var _return_row := 0

## C2: whether the New game row's first confirm has been taken and is waiting on a second
## one. Only ever true while `_selected == Row.NEW_GAME` and Settings is not open; every path
## that leaves that state -- moving the cursor, opening Settings, Escape, a second confirm
## itself -- clears it.
var _new_game_armed := false

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
	# C2: THE CURSOR STARTS ON CONTINUE WHENEVER THERE IS SOMETHING TO CONTINUE. Before this
	# the cursor defaulted to row 0, New game, one Enter away from `_game_state.reset()` with
	# no confirmation -- the exact keypress a returning player makes out of habit on every
	# other prompt this game has ever shown her. `can_continue()` asks the same question
	# Row.CONTINUE's own confirm() branch asks, so the two can never disagree.
	_selected = Row.CONTINUE if can_continue() else Row.NEW_GAME
	# DRAWN EVEN ON A NON-INTERACTIVE BOOT. Nothing below reads a save or sets the boot latch,
	# and a GUT test instantiates this scene under exactly the same headless conditions a real
	# non-interactive boot runs under -- test_every_row_is_armed_for_the_pointer and
	# test_the_footer_still_prints_the_keys check the rows and the footer with no row taken
	# first, so this has to have already run by the time _ready() returns either way.
	_refresh()
	if not is_interactive():
		# STRAIGHT TO THE RANCH, and deliberately WITHOUT setting the boot latch, so the run
		# reads the save slot exactly as a bare boot of ranch.tscn always has. call_deferred
		# because a scene change inside _ready() is a change out from under the tree that is
		# still building this node.
		call_deferred("_enter_world")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func row_count() -> int:
	return ROWS.size()


func selected_index() -> int:
	return _selected


func on_settings_page() -> bool:
	return _settings_menu != null and _settings_menu.is_open()


func settings_menu() -> SettingsMenu:
	return _settings_menu


func hovered_index() -> int:
	return _hovered


## Whether there is a ranch on disk to go back to.
func can_continue() -> bool:
	if has_save_provider.is_valid():
		return bool(has_save_provider.call())
	return SaveIOScript.has_slot(0)


func drawn_lines() -> Array[String]:
	var out: Array[String] = [TITLE, SETTINGS_TITLE, NO_SAVE_NOTE, NEW_GAME_CONFIRM_TEXT]
	out.append_array(ROWS)
	return out


func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		return
	_disarm_new_game()
	_selected = posmod(_selected + step, n)
	MenuStyleScript.tick_move()
	_refresh()


func point_at_row(index: int) -> void:
	if index < 0 or index >= row_count():
		return
	if index == _selected and index == _hovered:
		return
	if index != _selected:
		_disarm_new_game()
	_hovered = index
	if index != _selected:
		_selected = index
		MenuStyleScript.tick_move()
	_refresh()


func take_row(index: int) -> void:
	point_at_row(index)
	if _selected != index:
		return
	confirm()


func confirm() -> bool:
	if on_settings_page():
		return false
	if _selected != Row.NEW_GAME:
		_disarm_new_game()
	match _selected:
		Row.NEW_GAME:
			# C2: THE SECOND CONFIRM. can_continue() is exactly the condition under which
			# this row can destroy something -- a fresh machine has nothing to lose and
			# starts on the first press, same as before this fix.
			if can_continue() and not _new_game_armed:
				_new_game_armed = true
				MenuStyleScript.tick_page()
				_refresh()
				return true
			_new_game_armed = false
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
			_open_settings()
			return true
		Row.QUIT:
			MenuStyleScript.tick_back()
			get_tree().quit()
			return true
	return false


## The settings menu, over this screen. It edits `settings` and writes settings.cfg itself
## on Apply; this screen only gets its cursor back when it closes.
func _open_settings() -> void:
	_disarm_new_game()
	_return_row = _selected
	if _settings_menu == null:
		_settings_menu = SettingsMenuScene.instantiate()
		add_child(_settings_menu)
		_settings_menu.closed.connect(_on_settings_closed)
	_settings_menu.open(settings)
	_refresh()


func _on_settings_closed() -> void:
	_selected = _return_row
	_hovered = -1
	_refresh()


## Leave Settings (Esc there asks first if anything is not applied).
func back() -> void:
	if on_settings_page():
		_settings_menu.request_close()


## SCENE-TREE WIDE, AND GUARDED FOR EXACTLY THAT REASON. change_scene_to_file() replaces
## whatever the SceneTree calls its current scene, tree-wide, no matter who called it. A real
## boot's TitleScreen IS that current scene, so this is the hand-off Row.NEW_GAME/CONTINUE and
## the non-interactive early return in _ready() both mean to make. A GUT test's TitleScreen is
## a child of the test runner instead (see test_title_screen.gd's before_each), and firing this
## there would boot a second, real world/ranch.tscn inside the SAME process the whole suite is
## running in -- one that (game/world/ranch.gd's own _report(), non-interactive branch) ends by
## calling get_tree().quit() itself, which would kill the suite mid-run rather than this screen.
func _enter_world() -> void:
	if get_tree().current_scene != self:
		return
	# A person at the keyboard gets the loading screen (game/ui/loading_screen.gd): a threaded
	# load and a moving bar instead of a title frozen for the whole boot. An automated boot
	# changes scene exactly as it always has.
	if is_interactive():
		LoadingScreenScript.change_scene(get_tree(), WORLD_SCENE, LoadingScreenScript.Look.RANCH,
			"A new ranch" if BootIntentScript.peek_new_game() else "Back to the ranch")
		return
	get_tree().change_scene_to_file(WORLD_SCENE)


## C2: CLEAR THE ARMED ROW. Called from every path that is "some other input" once New game
## has taken its first confirm: the cursor moving (keyboard or mouse), a settings adjust, and
## the central catch-all in _unhandled_input for Escape. A no-op, and no redraw, when nothing
## was armed -- so calling it defensively costs nothing on the vastly more common path.
func _disarm_new_game() -> void:
	if not _new_game_armed:
		return
	_new_game_armed = false
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_title.text = TITLE
	MenuStyleScript.apply_title(_title)
	if _new_game_armed:
		_footer.text = MenuStyleScript.NO_CARET + NEW_GAME_CONFIRM_TEXT
	else:
		_footer.text = MenuStyleScript.footer_rows("choose", "quit")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE,
		MenuStyleScript.COLOR_DIM)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var names: Array[String] = ROWS
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
		var dimmed: bool = i == Row.CONTINUE and not can_continue()
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE,
			MenuStyleScript.COLOR_UNAFFORDABLE if dimmed \
				else (MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME))
		line.add_child(label)
		var value: String = NO_SAVE_NOTE if dimmed else ""
		if not value.is_empty():
			var val := Label.new()
			val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			val.text = value
			MenuStyleScript.style_label(val, MenuStyleScript.SUBTITLE_SIZE,
				MenuStyleScript.COLOR_DIM)
			line.add_child(val)
		holder.add_child(line)
		_rows.add_child(holder)


## M13: is_action_pressed(), NOT is_pressed() + is_action(). Every other menu in the game
## reads its keys this way (see creation_screen.gd's own _unhandled_input); is_action_pressed
## suppresses OS key-repeat echo by default (allow_echo defaults false) where is_pressed() +
## is_action() does not, which is why this screen used to run its cursor round the list at
## the OS repeat rate on a held key (M5, final-review.md) where no other menu in the project
## does.
func _unhandled_input(event: InputEvent) -> void:
	if on_settings_page():
		return
	if event.is_action_pressed(&"ui_up"):
		move_selection(-1)
	elif event.is_action_pressed(&"ui_down"):
		move_selection(1)
	elif event.is_action_pressed(&"ui_accept"):
		confirm()
	elif event.is_action_pressed(&"ui_cancel"):
		if _new_game_armed:
			# C2: Escape while the row is armed cancels the confirmation rather than
			# quitting the game out from under a player who only meant "not that".
			_disarm_new_game()
		else:
			get_tree().quit()
	else:
		return
	get_viewport().set_input_as_handled()
