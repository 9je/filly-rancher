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
const HouseStyleScript := preload("res://ui/house_style.gd")
const PaintScript := preload("res://ui/casino_paint.gd")
const LogotypeScript := preload("res://ui/logotype.gd")

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
	settings.apply_text()
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
	_dress_as_title()
	_refresh()
	_dress_with_key_art()
	if not is_interactive():
		# STRAIGHT TO THE RANCH, and deliberately WITHOUT setting the boot latch, so the run
		# reads the save slot exactly as a bare boot of ranch.tscn always has. call_deferred
		# because a scene change inside _ready() is a change out from under the tree that is
		# still building this node.
		call_deferred("_enter_world")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## THE KEY ART BEHIND THE TITLE (P8 S10; the loading screen's picture, LoadingScreen.ART): the
## valley itself at the end of the day, drifting in slowly, with the menu on the left over a
## soft dark band, the way Hades' and Cult of the Lamb's titles put their art first. Without the
## picture the drawn backdrop stays.
var _art: TextureRect
var _art_t := 0.0
## The evening's first stars: (x, y) as fractions of the screen, z the radius. Fixed, not
## rolled (nothing under game/ui/ draws a random number); kept to the right of the name.
const FIRST_STARS: Array[Vector3] = [Vector3(0.56, 0.05, 1.6), Vector3(0.63, 0.12, 1.2),
	Vector3(0.71, 0.04, 2.0), Vector3(0.78, 0.15, 1.3), Vector3(0.86, 0.07, 1.7),
	Vector3(0.93, 0.13, 1.1), Vector3(0.67, 0.21, 1.0), Vector3(0.97, 0.03, 1.4),
	Vector3(0.52, 0.17, 1.0), Vector3(0.82, 0.24, 0.9)]


func _dress_with_key_art() -> void:
	var path: String = LoadingScreenScript.ART.get(LoadingScreenScript.Look.RANCH, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	_art = TextureRect.new()
	_art.name = "KeyArt"
	_art.texture = load(path) as Texture2D
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	move_child(_art, 1)
	# A soft fall of shade from the left, never a hard edge across the picture.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.08, 0.04, 0.12, 0.62))
	grad.set_color(1, Color(0.08, 0.04, 0.12, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.anchor_right = 0.62
	add_child(shade)
	move_child(shade, 2)
	# THE SKY GOES TO EVENING OVER THE NAME (Fable AAA round 5: "a maroon cloud blob top-left
	# and a pink fog that kills the logo contrast"). A fall of deep dusk plum from the top of
	# the frame, gone by two fifths of the way down, so the cloud and the haze behind the name
	# sink into an evening sky while the valley below keeps its warm low sun; and a soft plum
	# pool behind the name itself, so the cream letters stand on dark, never on haze.
	var dusk := Gradient.new()
	dusk.offsets = PackedFloat32Array([0.0, 0.22, 0.42])
	dusk.colors = PackedColorArray([Color(0.13, 0.05, 0.20, 0.92), Color(0.16, 0.06, 0.22, 0.62),
		Color(0.16, 0.06, 0.22, 0.0)])
	var dusk_tex := GradientTexture2D.new()
	dusk_tex.gradient = dusk
	dusk_tex.fill_from = Vector2(0.5, 0.0)
	dusk_tex.fill_to = Vector2(0.5, 1.0)
	var sky := TextureRect.new()
	sky.name = "Dusk"
	sky.texture = dusk_tex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	move_child(sky, 3)
	var pool := Gradient.new()
	pool.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	pool.colors = PackedColorArray([Color(0.10, 0.04, 0.16, 0.7), Color(0.10, 0.04, 0.16, 0.38),
		Color(0.10, 0.04, 0.16, 0.0)])
	var pool_tex := GradientTexture2D.new()
	pool_tex.gradient = pool
	pool_tex.fill = GradientTexture2D.FILL_RADIAL
	pool_tex.fill_from = Vector2(0.5, 0.5)
	pool_tex.fill_to = Vector2(1.0, 0.5)
	var glow := TextureRect.new()
	glow.name = "NamePool"
	glow.texture = pool_tex
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.anchor_left = -0.06
	glow.anchor_right = 0.52
	glow.anchor_top = -0.08
	glow.anchor_bottom = 0.6
	add_child(glow)
	move_child(glow, 4)
	# A few first stars in the evening band, still and faint, so the dark reads as sky.
	var stars := Control.new()
	stars.name = "FirstStars"
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.draw.connect(func() -> void:
		var s := stars.size
		for p: Vector3 in FIRST_STARS:
			var at := Vector2(p.x * s.x, p.y * s.y)
			stars.draw_circle(at, p.z * 2.4, Color(1.0, 0.95, 0.85, 0.14))
			stars.draw_circle(at, p.z, Color(1.0, 0.97, 0.9, 0.85)))
	stars.resized.connect(stars.queue_redraw)
	add_child(stars)
	move_child(stars, 5)
	var backdrop := get_node_or_null(^"Backdrop") as Control
	if backdrop != null:
		backdrop.visible = false
	var centre := get_node_or_null(^"Centre") as Control
	if centre != null:
		centre.anchor_left = 0.04
		centre.anchor_right = 0.46
	_style_wordmark()


## The name was a Label in a heading size (Fable AAA review round 1, #9); it is a drawn
## logotype now (game/ui/logotype.gd), so the Label stays for its text and is not shown.
func _style_wordmark() -> void:
	if _title != null:
		_title.visible = false


## THE MENU IS THE ART'S, NOT A BOX'S (Fable AAA review round 1, #9; Hades, Cult of the Lamb):
## no panel behind the column, the logotype on top, and the rows as painted buttons with a
## picture each. Built once; _refresh() redraws the rows.
var _logo: Control


func _dress_as_title() -> void:
	var panel := get_node_or_null(^"Centre/Panel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		panel.custom_minimum_size = Vector2(640, 0)
	var column := get_node_or_null(^"Centre/Panel/Margin/Column") as VBoxContainer
	if column != null:
		column.add_theme_constant_override(&"separation", 26)
		_logo = LogotypeScript.new()
		_logo.name = "Logotype"
		_logo.custom_minimum_size = Vector2(640, 274)
		column.add_child(_logo)
		column.move_child(_logo, 0)
	if _rows != null:
		_rows.add_theme_constant_override(&"separation", 12)
		# THE MENU HAS A BACKING (Fable AAA round 3, #9: the key art's Pens signpost poked
		# through the Quit row): a deep plum velvet card under the four rows, a gold hairline
		# round it, wider than the rows, so nothing in the picture shows through or meets a
		# button. Drawn by the rows' box itself, under its children.
		_rows.draw.connect(func() -> void:
			_rows.draw_style_box(menu_backing_box(),
				Rect2(Vector2.ZERO, _rows.size).grow_individual(26.0, 22.0, 34.0, 24.0)))
		_rows.resized.connect(_rows.queue_redraw)


static func menu_backing_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(HouseStyleScript.PLUM_DARK.darkened(0.25), 0.94)
	b.border_color = Color(HouseStyleScript.GOLD_DIM, 0.75)
	b.set_border_width_all(2)
	b.set_corner_radius_all(44)
	b.shadow_color = Color(0.04, 0.0, 0.06, 0.5)
	b.shadow_size = 22
	b.anti_aliasing = true
	return b


## Each row's picture: a fresh start, home, the settings gear, the way out.
const ROW_ICONS: Array[String] = ["sparkler", "house", "", "arrow"]
const ROW_HEIGHT := 64.0


## A row as a painted button: plum, a gold edge, lit gold and slid a little right when it is the
## pick, the casino's own button language.
static func row_button_box(picked: bool, hovered: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = HouseStyleScript.PLUM.lightened(0.06) if picked else \
		(HouseStyleScript.PLUM if hovered else HouseStyleScript.PLUM_DARK)
	b.border_color = HouseStyleScript.GOLD if picked or hovered else Color(HouseStyleScript.GOLD_DIM, 0.8)
	b.set_border_width_all(3 if picked else 2)
	b.set_corner_radius_all(int(ROW_HEIGHT * 0.5))
	b.content_margin_left = 34.0 if picked else 14.0
	b.content_margin_right = 20.0
	b.content_margin_top = 6.0
	b.content_margin_bottom = 6.0
	b.shadow_color = Color(1.0, 0.8, 0.3, 0.45) if picked else Color(0.0, 0.0, 0.0, 0.35)
	b.shadow_size = 14 if picked else 6
	b.shadow_offset = Vector2.ZERO if picked else Vector2(0, 4)
	b.anti_aliasing = true
	return b


## The row's picture on a cream disc in a gold ring. Settings has no icon in the set, so its
## gear is drawn here.
func _row_icon(index: int, picked: bool) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(ROW_HEIGHT - 12.0, ROW_HEIGHT - 12.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_ := ROW_ICONS[index] if index < ROW_ICONS.size() else ""
	icon.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, icon.size)
		icon.draw_style_box(HouseStyleScript.disc_box(r.size.x, HouseStyleScript.KEY_FACE,
			HouseStyleScript.GOLD if picked else HouseStyleScript.GOLD_DIM, 3), r)
		if name_ != "":
			IconSet.draw(icon, name_, r.grow(-9.0))
		else:
			_draw_gear(icon, r.get_center(), r.size.x * 0.3))
	return icon


static func _draw_gear(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var teeth := 8
	for i in teeth * 4:
		var a := TAU * float(i) / float(teeth * 4)
		var out := (i % 4) < 2
		pts.append(c + Vector2(cos(a), sin(a)) * (r * (1.0 if out else 0.74)))
	ci.draw_colored_polygon(pts, HouseStyleScript.PLUM)
	ci.draw_circle(c, r * 0.32, HouseStyleScript.KEY_FACE)


func _process(delta: float) -> void:
	if _art == null:
		return
	_art_t += delta
	var k := 1.02 + 0.04 * (0.5 + 0.5 * sin(_art_t * 0.05))
	_art.pivot_offset = _art.size * 0.5
	_art.scale = Vector2(k, k)


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
		# THE LOADING CARD REPLACES THE MENU (Fable AAA review round 1, #9: two titles on the
		# loading screen): the column goes the moment the load starts, so nothing of the menu
		# shows through the card's fade.
		var centre := get_node_or_null(^"Centre") as CanvasItem
		if centre != null:
			centre.visible = false
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
	_style_wordmark()
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
		# A painted button, not a caret in a list (Fable AAA review round 1, #9: "a '> New
		# game' caret"): the pick is lit gold and slides right; the pointer lights a row too.
		var hovered: bool = i == _hovered
		holder.add_theme_stylebox_override(&"panel", row_button_box(picked, hovered))
		holder.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		if not picked:
			holder.mouse_entered.connect(func() -> void:
				holder.add_theme_stylebox_override(&"panel", row_button_box(false, true)))
			holder.mouse_exited.connect(func() -> void:
				holder.add_theme_stylebox_override(&"panel", row_button_box(false, false)))
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override(&"separation", 16)
		line.add_child(_row_icon(i, picked))
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = names[i]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# A CONTINUE WITH NOTHING TO CONTINUE READS AS UNAVAILABLE rather than as broken.
		var dimmed: bool = i == Row.CONTINUE and not can_continue()
		HouseStyleScript.ink_label(label, 30,
			Color(HouseStyleScript.CREAM, 0.4) if dimmed \
				else (HouseStyleScript.GOLD if picked else HouseStyleScript.CREAM))
		line.add_child(label)
		var value: String = NO_SAVE_NOTE if dimmed else ""
		if not value.is_empty():
			var val := Label.new()
			val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			val.text = value
			HouseStyleScript.ink_label(val, 16, HouseStyleScript.CREAM_DIM, false)
			val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
