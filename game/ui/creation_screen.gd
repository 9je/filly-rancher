class_name CreationScreen
extends CanvasLayer
## WHERE A NEW GAME BEGINS: the player's own pony on a turntable, three rows of swatches, a
## name box, and a square of canvas she draws her cutie mark on.
##
## A CanvasLayer INSIDE ranch.tscn RATHER THAN A SCENE OF ITS OWN. The design doc says the
## screen comes up before the ranch loads. game/project.godot's main scene is
## world/ranch.tscn and every gate, the export smoke run and docs/ci.md are built on that,
## so a title flow that changed the main scene would be a far larger change than this slice
## can carry. The screen therefore opens OVER a paused ranch, with its own SubViewport, its
## own camera and its own dawn sky, so nothing of the ranch shows through and nothing here
## reaches into it. ranch.gd opens it only for an interactive session with no save, so no
## gate and no headless run ever sees it.
##
## THE WIDGET IS DRIVEN BY METHODS, NOT BY INPUT. cycle_coat(), set_name_text(), canvas()
## and confirm() are the whole of what the buttons do, which is what lets
## game/test/test_creation_screen.gd drive the entire screen with no mouse and no viewport.
##
## THE TINT ON THE TURNTABLE IS THE SAME StockTint THE CROWD GOES THROUGH. If the pony she
## is looking at were tinted by a second path, the pony she gets would not be the pony she
## chose.
##
## A STAGE, NOT A FRAME OF RAW WORLD. The owner's first full playtest saw the ranch behind
## this screen: a strip of unpaused map, the farmhouse clipping the edge of the panel, a
## camera pointed somewhere nobody meant it to be. Backdrop is opaque and full screen so
## nothing behind this CanvasLayer ever reaches the player's eye, and the turntable now
## fills a real share of the frame instead of a corner of it.

const PlayerLookScript := preload("res://systems/player_look.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkComposerScript := preload("res://systems/mark_composer.gd")
const MarkLayoutScript := preload("res://systems/mark_layout.gd")
const PonySurpriseScript := preload("res://systems/pony_surprise.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const SwatchGridScript := preload("res://ui/swatch_grid.gd")

const TITLE := "Who are you?"
const NAME_LABEL := "Your name"
const COAT_LABEL := "Coat"
const MANE_LABEL := "Mane"
const RACE_LABEL := "Kind of pony"
const MANE2_LABEL := "Mane streak"
const TAIL_LABEL := "Tail"
## The first cell of the streak and tail rows: no colour of its own, the mane's.
const SAME_AS_MANE := "="
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const MANE_STYLE_LABEL := "Mane style"
const EYES_LABEL := "Eyes"
const MARK_LABEL := "Your cutie mark; draw it yourself"
const CONFIRM_LABEL := "This is me"
const HINT := "Left click to draw. Click a symbol to stamp it, up to three: drag it to move it, its corner to size it, its top knob to turn it; an ink recolours it."

## HAIR is appended (not inserted) so LOOK and MARK keep their values; the tabs show it
## between them: Your pony, Mane and tail, Your cutie mark.
enum Step { LOOK, MARK, HAIR }

const STEP_LOOK_LABEL := "Your pony"
const STEP_MARK_LABEL := "Your cutie mark"
const STEP_HAIR_LABEL := "Mane and tail"

## Radians the turntable turns per pixel of horizontal drag, and how long after she lets go
## before the auto spin picks up again. The auto spin is what shows both flanks to a player
## who touches nothing; the drag is what a player who wants to look at the front expects.
const DRAG_RADIANS_PER_PIXEL := 0.008
const AUTOSPIN_RESUME_SECONDS := 2.0

## THE INKS SHE MAY DRAW HER MARK IN, as a row of named buttons over the canvas. The canvas
## has always been able to take a colour (MarkCanvas.set_colour); until this row existed
## nothing ever called it, so every cutie mark in the game came out the one hard coded grey
## that widget happens to start on, which is not a cutie mark, it is a smudge.
##
## SIX, NAMED, AND FEW ON PURPOSE. This is a sixty four pixel square drawn with a mouse in
## the first two minutes of a new game, not an art package; six inks that read clearly
## against a coat beat a colour wheel nobody wants to fight at that moment. INK_COLOURS[0]
## is the grey the canvas already opens on, so the row includes the state it starts in
## rather than leaving one unnamed colour off the end of it.
##
## NAMES AND COLOURS AS TWO PARALLEL ARRAYS rather than one array of dictionaries: a typed
## Array[Color] is what set_colour() wants and a typed Array[String] is what drawn_lines()
## (and therefore the copy rule test) wants, and neither has to unpack anything to get it.
## They are indexed together; ink_at() and ink_name() are the only two readers.
const INK_NAMES: Array[String] = ["Charcoal", "Rose", "Sunshine", "Meadow", "Sky", "Plum"]
const INK_COLOURS: Array[Color] = [
	Color(0.20, 0.20, 0.24, 1.0),
	Color(0.88, 0.32, 0.42, 1.0),
	Color(0.98, 0.78, 0.24, 1.0),
	Color(0.36, 0.72, 0.42, 1.0),
	Color(0.28, 0.56, 0.88, 1.0),
	Color(0.60, 0.36, 0.78, 1.0),
]

## Degrees per second the turntable turns. Slow enough to read, fast enough to see both
## flanks (and both cutie marks) inside a few seconds.
const TURN_DEGREES_PER_SECOND := 24.0

## THE KEYBOARD'S OWN CURSOR, RUN BY THIS FILE, THE SAME IDIOM game/ui/build_menu.gd's
## move_selection()/confirm() USE. Godot's own focus walk is never turned on anywhere in
## this screen (every Button on it, and every SwatchGrid cell, is FOCUS_NONE) -- a Tab
## walking real engine focus onto a Button would be a second, uncoordinated cursor racing
## this one. Every region below is instead a plain list of BaseButtons this file already
## knows how to press, so _unhandled_input() below never invents behaviour a mouse click
## does not already have a wire for; it only chooses which wire to pull.
##
## ui_focus_next/ui_focus_prev (Tab / Shift+Tab) MOVE BETWEEN REGIONS; ui_left/ui_right/
## ui_up/ui_down MOVE THE HIGHLIGHT INSIDE ONE. A region's "columns" is a SwatchGrid's own
## column count for a grid, or its own button count for a plain row (which makes ui_up/
## ui_down a no-op there: posmod(index + count, count) is index again), so one pair of
## helpers below drives a two column stepper and a six column swatch grid the same way.
const LOOK_REGIONS: Array[StringName] = [&"name", &"step", &"race", &"coat", &"eyes",
	&"confirm"]
## MANE STYLE LIVES WITH THE MANE (PT11; playtest 2026-11-05: "mane style isnt under mane and
## tail").
const HAIR_REGIONS: Array[StringName] = [&"step", &"mane_style", &"mane", &"mane2", &"tail",
	&"confirm"]
const MARK_REGIONS: Array[StringName] = [&"step", &"ink", &"stamp", &"tool", &"action",
	&"confirm"]

signal confirmed(look: PlayerLook)

var _look: PlayerLook = null
var _palette: StockPalette = null
var _model: Node3D = null
var _open := false
var _step: int = Step.LOOK
var _backdrop_only := false
var _drag_rest := 0.0

## Which region has the keyboard cursor, and where inside it. `_kb_region` indexes
## `_regions()`; `_kb_item` indexes that region's own `_region_buttons()`.
var _kb_region := 0
var _kb_item := 0

## The one Control currently drawn as the keyboard cursor's target, so the next move can
## clear exactly that highlight rather than walking every region hunting for one.
var _kb_grid: SwatchGrid = null
var _kb_button: BaseButton = null
var _kb_on_name := false

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
@onready var _race_grid: SwatchGrid = get_node_or_null(^"Layout/Panel/Margin/Column/RaceGrid")
@onready var _mane2_grid: SwatchGrid = get_node_or_null(^"Layout/Panel/Margin/Column/Mane2Grid")
@onready var _tail_grid: SwatchGrid = get_node_or_null(^"Layout/Panel/Margin/Column/TailGrid")

## The ink she is drawing in right now, shown beside the ink buttons the same way each
## colour row shows its own pick. The canvas is the authority on which ink is loaded; this
## is only how it is read back without drawing a test stroke to find out.
@onready var _ink_swatch: ColorRect = get_node_or_null(
	^"Layout/Panel/Margin/Column/InkRow/InkSwatch")

## The screen's own Labels, assigned their text from the consts above in _ready() rather
## than authored a second time as literals in creation_screen.tscn -- the .tscn used to
## carry its own copy of every one of these strings, which is a second place the copy rule
## (and a retitled label) could drift from what test_nothing_the_screen_draws_carries_a_dash
## actually checks. The .gd consts are now the only place any of this text is written.
@onready var _title_label: Label = get_node_or_null(^"Layout/Panel/Margin/Column/Title")
@onready var _name_label: Label = get_node_or_null(^"Layout/Panel/Margin/Column/NameLabel")
@onready var _coat_label: Label = get_node_or_null(^"Layout/Panel/Margin/Column/CoatLabel")
@onready var _mane_label: Label = get_node_or_null(^"Layout/Panel/Margin/Column/ManeLabel")
@onready var _mane_style_label: Label = get_node_or_null(
	^"Layout/Panel/Margin/Column/ManeStyleLabel")
@onready var _eyes_label: Label = get_node_or_null(^"Layout/Panel/Margin/Column/EyesLabel")
@onready var _mark_label: Label = get_node_or_null(^"Layout/Panel/Margin/Column/MarkLabel")
@onready var _hint_label: Label = get_node_or_null(^"Layout/Panel/Margin/Column/HintLabel")


func _ready() -> void:
	visible = false
	_palette = StockPaletteScript.load_player()
	_name_box.max_length = PlayerLookScript.MAX_NAME_LENGTH
	_title_label.text = TITLE
	_name_label.text = NAME_LABEL
	_coat_label.text = COAT_LABEL
	_mane_label.text = MANE_LABEL
	_mane_style_label.text = MANE_STYLE_LABEL
	for pair in [["RaceLabel", RACE_LABEL], ["Mane2Label", MANE2_LABEL], ["TailLabel", TAIL_LABEL]]:
		var l := get_node_or_null(NodePath("Layout/Panel/Margin/Column/" + pair[0])) as Label
		if l != null:
			l.text = pair[1]
	_eyes_label.text = EYES_LABEL
	_mark_label.text = MARK_LABEL
	_hint_label.text = HINT
	_confirm.text = CONFIRM_LABEL
	_name_box.text_changed.connect(set_name_text)
	# ENTER SUBMITS AND RELEASES. A LineEdit with focus consumes ui_accept itself (that is
	# what text_submitted IS), so this is the one region where _unhandled_input below never
	# sees the key at all; it still has to give the focus back afterward, or Tab/the arrow
	# keys would keep typing into the name instead of moving the cursor.
	_name_box.text_submitted.connect(func(_text: String) -> void: _name_box.release_focus())
	_name_box.focus_exited.connect(func() -> void: _apply_kb_highlight())
	_confirm.pressed.connect(func() -> void: confirm())
	_canvas.changed.connect(func() -> void: _sync_mark())
	set_ink(0)
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_stand_stage()
	_wire_controls()
	MenuStyleScript.apply_panel_box(get_node_or_null(^"Layout/Panel") as PanelContainer,
		MenuStyleScript.paper_box())
	MenuStyleScript.apply_panel_box(get_node_or_null(^"Layout/Stage") as PanelContainer,
		MenuStyleScript.frame_box())
	_style_paper()
	_build_grids()
	_build_talent_gallery()
	_build_surprise_button()
	# Mane style first on the hair step, the first thing you pick about a mane.
	var col := get_node_or_null(^"Layout/Panel/Margin/Column") as VBoxContainer
	var mane_label := get_node_or_null(^"Layout/Panel/Margin/Column/ManeLabel") as Control
	if col != null and mane_label != null:
		for n: String in ["ManeStyleLabel", "StyleRow"]:
			var node := col.get_node_or_null(n) as Control
			if node != null:
				col.move_child(node, mane_label.get_index())
	_wire_steps()
	var prev := get_node_or_null(^"Layout/Panel/Margin/Column/StyleRow/StylePrev") as Button
	var nxt := get_node_or_null(^"Layout/Panel/Margin/Column/StyleRow/StyleNext") as Button
	if prev != null and nxt != null:
		prev.focus_mode = Control.FOCUS_NONE
		nxt.focus_mode = Control.FOCUS_NONE
		prev.pressed.connect(func() -> void: cycle_mane_style(-1))
		nxt.pressed.connect(func() -> void: cycle_mane_style(1))
		var sn := get_node_or_null(^"Layout/Panel/Margin/Column/StyleRow/StyleName") as Label
		if sn != null:
			MenuStyleScript.style_label(sn, 24, Color(0.24, 0.17, 0.3))
			sn.add_theme_constant_override(&"outline_size", 0)
	if _viewport != null:
		_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
		_viewport.focus_mode = Control.FOCUS_NONE
		_viewport.gui_input.connect(_on_stage_input)
	_confirm.focus_mode = Control.FOCUS_NONE
	set_step(Step.LOOK)


## I3, final-review.md I1: THE PAPER WITH THE INK, NOT THE DARK THEME'S WHITE ON IT. The
## panel took `paper_box()` in `_ready()` above, but nothing ever told the eight Labels or
## any Button on it to stop inheriting the project Theme's dark-panel palette (near-white
## text, a 5 px black outline) -- on cream that reads as the exact "floating text / roblox"
## register the owner already rejected once (see menu_style.gd's own COLOR_INK comment).
## Fix: every Label reads ink, no outline, through the same `style_label()` every other
## paper page (letter_panel.gd's own footer) already uses; every Button on the panel takes
## `field_box()` -- the Task 1 factory built for the one other paper control on this screen,
## the NameBox -- as its chrome, and ink text to match.
const _PAPER_LABEL_PATHS: Array[NodePath] = [^"Layout/Panel/Margin/Column/Title",
	^"Layout/Panel/Margin/Column/NameLabel", ^"Layout/Panel/Margin/Column/CoatLabel",
	^"Layout/Panel/Margin/Column/ManeLabel", ^"Layout/Panel/Margin/Column/ManeStyleLabel",
	^"Layout/Panel/Margin/Column/EyesLabel", ^"Layout/Panel/Margin/Column/MarkLabel",
	^"Layout/Panel/Margin/Column/HintLabel", ^"Layout/Panel/Margin/Column/RaceLabel",
	^"Layout/Panel/Margin/Column/Mane2Label", ^"Layout/Panel/Margin/Column/TailLabel"]

const _PAPER_BUTTON_PATHS: Array[NodePath] = [
	^"Layout/Panel/Margin/Column/StepRow/StepLook",
	^"Layout/Panel/Margin/Column/StepRow/StepHair",
	^"Layout/Panel/Margin/Column/StepRow/StepMark",
	^"Layout/Panel/Margin/Column/InkRow/Ink0", ^"Layout/Panel/Margin/Column/InkRow/Ink1",
	^"Layout/Panel/Margin/Column/InkRow/Ink2", ^"Layout/Panel/Margin/Column/InkRow/Ink3",
	^"Layout/Panel/Margin/Column/InkRow/Ink4", ^"Layout/Panel/Margin/Column/InkRow/Ink5",
	^"Layout/Panel/Margin/Column/StampRow/Stamp0",
	^"Layout/Panel/Margin/Column/StampRow/Stamp1",
	^"Layout/Panel/Margin/Column/StampRow/Stamp2",
	^"Layout/Panel/Margin/Column/StampRow/Stamp3",
	^"Layout/Panel/Margin/Column/StampRow/Stamp4",
	^"Layout/Panel/Margin/Column/StampRow/Stamp5",
	^"Layout/Panel/Margin/Column/ToolRow/Brush1",
	^"Layout/Panel/Margin/Column/ToolRow/Brush2",
	^"Layout/Panel/Margin/Column/ToolRow/Brush4",
	^"Layout/Panel/Margin/Column/ToolRow/Brush8",
	^"Layout/Panel/Margin/Column/ToolRow/Eraser",
	^"Layout/Panel/Margin/Column/ActionRow/Undo",
	^"Layout/Panel/Margin/Column/ActionRow/Clear",
	^"Layout/Panel/Margin/Column/Confirm"]


## Paper chrome on a button built in code (the gallery's, Surprise me).
static func _paper_button(button: Button) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, MenuStyleScript.field_box(
			state == &"hover" or state == &"pressed" or state == &"focus"))
	button.add_theme_color_override("font_color", MenuStyleScript.COLOR_INK)
	button.add_theme_color_override("font_hover_color", MenuStyleScript.COLOR_INK)
	button.add_theme_color_override("font_pressed_color", MenuStyleScript.COLOR_INK)
	button.add_theme_constant_override("outline_size", 0)


func _style_paper() -> void:
	for path: NodePath in _PAPER_LABEL_PATHS:
		var label := get_node_or_null(path) as Label
		if label == null:
			continue
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_INK)
		label.add_theme_constant_override(&"outline_size", 0)
	_title_label.add_theme_font_size_override("font_size", MenuStyle.font_px(MenuStyleScript.TITLE_SIZE))
	for path: NodePath in _PAPER_BUTTON_PATHS:
		var button := get_node_or_null(path) as Button
		if button == null:
			continue
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			button.add_theme_stylebox_override(state, MenuStyleScript.field_box(
				state == &"hover" or state == &"pressed" or state == &"focus"))
		button.add_theme_color_override("font_color", MenuStyleScript.COLOR_INK)
		button.add_theme_color_override("font_hover_color", MenuStyleScript.COLOR_INK)
		button.add_theme_color_override("font_pressed_color", MenuStyleScript.COLOR_INK)
		button.add_theme_color_override("font_focus_color", MenuStyleScript.COLOR_INK)
		button.add_theme_color_override("font_outline_color", MenuStyleScript.OUTLINE_COLOR)
		button.add_theme_constant_override("outline_size", 0)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if _name_box != null and _name_box.has_focus():
		# WHILE SHE IS TYPING, THIS FILE TOUCHES NOTHING ELSE. Every printable key and the
		# LineEdit's own arrow-key text-cursor movement is already consumed by its _gui_input
		# before an unhandled_input ever fires, so the only key that reaches here at all is
		# one the LineEdit itself does not handle -- Escape -- and that is the one that gives
		# the highlight back without typing anything.
		if event.is_action_pressed(&"ui_cancel"):
			release_name_edit()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_left"):
		move_highlight(-1)
	elif event.is_action_pressed(&"ui_right"):
		move_highlight(1)
	elif event.is_action_pressed(&"ui_up"):
		move_highlight(-_region_columns(_regions()[_kb_region]))
	elif event.is_action_pressed(&"ui_down"):
		move_highlight(_region_columns(_regions()[_kb_region]))
	elif event.is_action_pressed(&"ui_focus_next"):
		switch_region(1)
	elif event.is_action_pressed(&"ui_focus_prev"):
		switch_region(-1)
	elif event.is_action_pressed(&"ui_accept"):
		activate_highlight()
	else:
		return
	get_viewport().set_input_as_handled()


## Show the screen on `look` and pause the world behind it.
func open(look: PlayerLook) -> void:
	_look = look if look != null else PlayerLookScript.default_look()
	_open = true
	visible = true
	_backdrop_only = false
	if _layout != null:
		_layout.visible = true
	_drag_rest = 0.0
	set_step(Step.LOOK)
	get_tree().paused = true
	_name_box.text = _look.player_name
	_canvas.set_image(_look.mark())
	_build_model()
	_restyle()
	_refresh_swatches()
	_retint_mane_style_grid()
	_enter_kb_region(0)


func is_open() -> bool:
	return _open


func look() -> PlayerLook:
	return _look


## The pony standing on the turntable, or null on an assetless checkout.
func model() -> Node3D:
	return _model


func canvas() -> MarkCanvas:
	return _canvas


func set_name_text(text: String) -> void:
	_look.player_name = PlayerLookScript.sanitize_name(text)


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
		_retint_mane_style_grid()
		_mane_style_grid.picked.connect(set_mane_style)
	if _race_grid != null:
		var race_swatches: Array[Color] = [Color(0.98, 0.84, 0.62), Color(0.74, 0.86, 1.0),
			Color(0.88, 0.78, 1.0)]
		var race_labels: Array[String] = []
		race_labels.assign(PlayerLookScript.RACE_LABELS)
		_race_grid.set_swatches(race_swatches, race_labels)
		_race_grid.picked.connect(set_race)
	for grid: SwatchGrid in [_mane2_grid, _tail_grid]:
		if grid == null:
			continue
		var sw: Array[Color] = [Color(0.95, 0.93, 0.9)]
		sw.append_array(_palette.manes)
		var lab: Array[String] = [SAME_AS_MANE]
		for i in _palette.manes.size():
			lab.append("")
		grid.set_swatches(sw, lab)
	if _mane2_grid != null:
		_mane2_grid.picked.connect(func(i: int) -> void: set_mane2(i - 1))
	if _tail_grid != null:
		_tail_grid.picked.connect(func(i: int) -> void: set_tail(i - 1))


## THE CARDS ARE TINTED BY THE MANE COLOUR SHE IS ON, so they read as manes rather than as
## four identical grey buttons with words on them -- called from _build_grids() (before
## _look exists; mane index 0 stands in) and again every time set_mane()/cycle_mane() change
## which mane she is on, so the cards never fall out of step with her actual pick.
##
## A FULL REBUILD, NOT A RECOLOUR IN PLACE. SwatchGrid has no per cell "just change the
## colour" entry point and does not need one for four cards picked a few times a session;
## set_swatches() replaces the Buttons but leaves the grid's own _selected/_highlighted and
## its `picked` connection untouched, so nothing above this has to rewire afterward.
func _retint_mane_style_grid() -> void:
	if _mane_style_grid == null:
		return
	var swatches: Array[Color] = []
	var labels: Array[String] = []
	var mane_index: int = _look.mane if _look != null else 0
	var race: int = _look.race if _look != null else PlayerLookScript.RACE_UNICORN
	var count := PlayerLookScript.style_count(race)
	for i in count:
		swatches.append(_palette.mane_at(mane_index))
		labels.append(str(i + 1))
	_mane_style_grid.set_swatches(swatches, labels)


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
	_retint_mane_style_grid()


func set_eyes(index: int) -> void:
	_look.eyes = posmod(index, maxi(1, _palette.eyes.size()))
	_restyle()
	_refresh_swatches()


## THE ONE ROW THAT IS NOT A TINT: a different mesh, so the pony on the turntable is rebuilt.
func set_mane_style(index: int) -> void:
	_look.mane_style = posmod(index, PlayerLookScript.style_count(_look.race))
	_build_model()
	_show_streak()
	_restyle()
	_refresh_swatches()


## Earth pony, pegasus or unicorn: a different set of bodies, so the style resets to the
## first of that kind and the turntable pony is rebuilt.
func set_race(index: int) -> void:
	_look.race = clampi(index, PlayerLookScript.RACE_EARTH, PlayerLookScript.RACE_UNICORN)
	_look.mane_style = 0
	_retint_mane_style_grid()
	_build_model()
	_restyle()
	_refresh_swatches()


## -1 is "same as the mane".
func set_mane2(index: int) -> void:
	_look.mane2 = clampi(index, -1, _palette.manes.size() - 1)
	_restyle()
	_refresh_swatches()


func set_tail(index: int) -> void:
	_look.tail = clampi(index, -1, _palette.manes.size() - 1)
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


func stamp(id: int) -> void:
	_canvas.stamp(id)


## How many inks the row offers.
static func ink_count() -> int:
	return INK_NAMES.size()


## Ink `index`'s colour. Wraps, like every StockPalette row does and for the same reason: an
## off by one in a caller produces the wrong ink rather than an out of range read.
static func ink_at(index: int) -> Color:
	if INK_COLOURS.is_empty():
		return Color.BLACK
	return INK_COLOURS[posmod(index, INK_COLOURS.size())]


## Ink `index`'s name, as the button says it and as drawn_lines() reports it.
static func ink_name(index: int) -> String:
	if INK_NAMES.is_empty():
		return ""
	return INK_NAMES[posmod(index, INK_NAMES.size())]


## PICK AN INK. Everything the ink buttons do, and the one call anything else needs: the
## canvas holds the colour (and turns the eraser off when it takes one), this only chooses
## which and keeps the swatch in step.
func set_ink(index: int) -> void:
	_canvas.set_colour(ink_at(index))
	if _ink_swatch != null:
		_ink_swatch.color = ink_at(index)
	if not _talent_buttons.is_empty():
		_refresh_talent_thumbs()


## Take the look as it stands and hand it over. Returns whether anything happened; a second
## call does nothing, so a double click on the button cannot start two ranches.
func confirm() -> bool:
	if not _open:
		return false
	_sync_mark()
	set_name_text(_name_box.text)
	_open = false
	visible = false
	_backdrop_only = false
	get_tree().paused = false
	confirmed.emit(_look)
	return true


## Every string this screen draws, for the copy rule test.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = [TITLE, NAME_LABEL, COAT_LABEL, MANE_LABEL, MANE_STYLE_LABEL,
		EYES_LABEL, MARK_LABEL, CONFIRM_LABEL, HINT, STEP_LOOK_LABEL, STEP_MARK_LABEL,
		STEP_HAIR_LABEL, RACE_LABEL, MANE2_LABEL, TAIL_LABEL, SAME_AS_MANE]
	for i in StockPaletteScript.mane_style_count():
		lines.append(StockPaletteScript.mane_style_label(i))
	for id: int in MarkStampsScript.ids():
		lines.append(MarkStampsScript.stamp_name(id))
	# The ink buttons say these, so the copy rule applies to them like everything else.
	for ink: String in INK_NAMES:
		lines.append(ink)
	return lines


func step() -> int:
	return _step


## TWO STEPS, NOT ONE WALL OF CONTROLS. The old screen put a name box, four rows of steppers,
## a canvas, six inks, six stamps, four brushes and four buttons on one column, and the owner
## read that as cheap. Meeting the pony is one job; drawing her mark is another.
func set_step(value: int) -> void:
	_step = clampi(value, Step.LOOK, Step.HAIR)
	var shown: Dictionary = {
		Step.LOOK: ["NameLabel", "NameBox", "RaceLabel", "RaceGrid", "CoatLabel", "CoatGrid",
			"EyesLabel", "EyesGrid"],
		Step.HAIR: ["ManeStyleLabel", "StyleRow", "ManeLabel", "ManeGrid", "Mane2Label",
			"Mane2Grid", "TailLabel", "TailGrid"],
		Step.MARK: ["MarkLabel", "MarkCanvas", "HintLabel", "InkRow", "TalentLabel", "TalentGrid",
			"ShapeGrid", "ToolRow", "ActionRow"],
	}
	for step: int in shown:
		for n: String in shown[step]:
			var node := get_node_or_null(NodePath("Layout/Panel/Margin/Column/" + n)) as Control
			if node != null:
				node.visible = step == _step
	_show_streak()
	MenuStyleScript.tick_page()
	# THE CURSOR MOVES WITH THE STEP. The two steps do not share a region list (MARK has no
	# name field or colour grids; LOOK has no ink/stamp/tool/action rows), so a cursor left
	# on the last step's region index would either point at a hidden control or an unrelated
	# one now sitting at that index.
	_enter_kb_region(0)


func _wire_steps() -> void:
	for pair: Array in [[^"Layout/Panel/Margin/Column/StepRow/StepLook", Step.LOOK,
			STEP_LOOK_LABEL],
			[^"Layout/Panel/Margin/Column/StepRow/StepHair", Step.HAIR, STEP_HAIR_LABEL],
			[^"Layout/Panel/Margin/Column/StepRow/StepMark", Step.MARK, STEP_MARK_LABEL]]:
		var button := get_node_or_null(pair[0] as NodePath) as Button
		if button == null:
			continue
		button.text = String(pair[2])
		button.focus_mode = Control.FOCUS_NONE
		var target: int = int(pair[1])
		button.pressed.connect(func() -> void: set_step(target))


# --- the keyboard's own cursor -----------------------------------------------------------
##
## CHARACTER CREATION IS FINISHABLE WITH ZERO MOUSE. Every Button on this screen, and every
## SwatchGrid cell, sets FOCUS_NONE (see swatch_grid.gd's own class comment); this section
## is the compensating cursor that FOCUS_NONE always implies is somebody else's job to
## build, the same way build_menu.gd's move_selection()/confirm() are. It never invents an
## action a mouse click could not already reach -- every branch below ends in either
## `.pressed.emit()` on a Button this file already wired, or `_name_box.grab_focus()`.

func _regions() -> Array[StringName]:
	match _step:
		Step.MARK:
			return MARK_REGIONS
		Step.HAIR:
			return HAIR_REGIONS
	return LOOK_REGIONS


func _region_grid(region: StringName) -> SwatchGrid:
	match region:
		&"coat":
			return _coat_grid
		&"mane":
			return _mane_grid
		&"eyes":
			return _eyes_grid
		&"race":
			return _race_grid
		&"mane2":
			return _mane2_grid
		&"tail":
			return _tail_grid
	return null


## Every BaseButton `region` offers the cursor, in the order the cursor visits them. A grid
## region's buttons are its cells, read straight off the SwatchGrid so this never keeps a
## second list a rebuilt grid (see _retint_mane_style_grid()) could fall out of step with.
func _region_buttons(region: StringName) -> Array[BaseButton]:
	var grid := _region_grid(region)
	if grid != null:
		var cells: Array[BaseButton] = []
		for i in grid.cell_count():
			cells.append(grid.cell(i))
		return cells
	var paths: Array[NodePath] = []
	match region:
		&"step":
			paths = [^"Layout/Panel/Margin/Column/StepRow/StepLook",
				^"Layout/Panel/Margin/Column/StepRow/StepHair",
				^"Layout/Panel/Margin/Column/StepRow/StepMark"]
		&"ink":
			for i in ink_count():
				paths.append(NodePath("Layout/Panel/Margin/Column/InkRow/Ink%d" % i))
		&"stamp":
			for id: int in MarkStampsScript.ids():
				paths.append(NodePath("Layout/Panel/Margin/Column/StampRow/Stamp%d" % id))
		&"tool":
			for radius: int in MarkPaintScript.BRUSHES:
				paths.append(NodePath("Layout/Panel/Margin/Column/ToolRow/Brush%d" % radius))
			paths.append(^"Layout/Panel/Margin/Column/ToolRow/Eraser")
		&"action":
			paths = [^"Layout/Panel/Margin/Column/ActionRow/Undo",
				^"Layout/Panel/Margin/Column/ActionRow/Clear"]
		&"mane_style":
			paths = [^"Layout/Panel/Margin/Column/StyleRow/StylePrev",
				^"Layout/Panel/Margin/Column/StyleRow/StyleNext"]
		&"confirm":
			paths = [^"Layout/Panel/Margin/Column/Confirm"]
	var out: Array[BaseButton] = []
	for path: NodePath in paths:
		var button := get_node_or_null(path) as BaseButton
		if button != null:
			out.append(button)
	return out


## A grid's own column count for a grid region; the region's whole button count for a row
## (StepRow, InkRow, and the rest are all one row wide), which is what makes ui_up/ui_down a
## no-op on a row region: posmod(index +/- count, count) always answers index back.
func _region_columns(region: StringName) -> int:
	var grid := _region_grid(region)
	if grid != null:
		return maxi(1, grid.columns)
	return maxi(1, _region_buttons(region).size())


## Which region the cursor is on ("name", "step", "coat", ...; see LOOK_REGIONS/MARK_REGIONS).
func kb_region() -> StringName:
	var regions := _regions()
	if _kb_region < 0 or _kb_region >= regions.size():
		return &""
	return regions[_kb_region]


## Which item inside that region the cursor is on.
func kb_item() -> int:
	return _kb_item


## Whether the name field currently holds real engine keyboard focus. Typing in it is the
## one thing on this screen that is NOT driven through a Button; a test that wants to prove
## the cursor never steals a letter checks this rather than reading LineEdit internals.
func is_editing_name() -> bool:
	return _name_box != null and _name_box.has_focus()


## ESCAPE, WHILE TYPING. Hands the highlight back to the name region without touching what
## she has typed so far -- the same "give up the field, keep the cursor here" contract the
## coordinator's ruling asked for. A no-op if nothing has focus, so a stray call is cheap.
func release_name_edit() -> void:
	if _name_box != null:
		_name_box.release_focus()


## TAB / SHIFT+TAB. Move to the region `delta` steps away (wraps), and put the item cursor
## somewhere sensible inside it: a grid's own current pick, so pressing Enter right after
## switching in re-confirms what she already chose rather than landing on cell zero.
func switch_region(delta: int) -> void:
	if is_editing_name():
		return
	var regions := _regions()
	if regions.is_empty():
		return
	_enter_kb_region(_kb_region + delta)


func _enter_kb_region(index: int) -> void:
	var regions := _regions()
	if regions.is_empty():
		_kb_region = 0
		_kb_item = 0
		_apply_kb_highlight()
		return
	_kb_region = posmod(index, regions.size())
	var grid := _region_grid(regions[_kb_region])
	_kb_item = grid.selected() if grid != null and grid.cell_count() > 0 else 0
	_apply_kb_highlight()


## THE ARROW KEYS. `delta` is +/-1 from ui_left/ui_right, or +/- the region's own column
## count from ui_up/ui_down -- see _unhandled_input(). The name region has no items to move
## across (there is exactly one field, and Enter is how she gets into it), so this is a
## deliberate no-op there rather than a special case the caller has to know about.
func move_highlight(delta: int) -> void:
	if is_editing_name():
		return
	var region := kb_region()
	if region == &"" or region == &"name":
		return
	var buttons := _region_buttons(region)
	if buttons.is_empty():
		return
	_kb_item = posmod(_kb_item + delta, buttons.size())
	_apply_kb_highlight()
	# M12, final-review.md M4: THE STANDARD MenuStyle TICKS. Every other screen ticks on
	# hover-move, on confirm and on a step switch (set_step() already does, above); this
	# screen shipped silent on the two the arrow keys and Enter drive.
	MenuStyleScript.tick_move()


## ENTER. Presses whatever the cursor is on -- literally: `.pressed.emit()` on the same
## Button a click would fire, which is what lets every region below reuse the wiring
## _wire_controls()/_wire_steps()/_build_grids() already built rather than duplicating it.
## The name region is the one exception, because there is no Button behind it to press.
func activate_highlight() -> void:
	if is_editing_name():
		return
	var region := kb_region()
	if region == &"name":
		_name_box.grab_focus()
		_apply_kb_highlight()
		MenuStyleScript.tick_confirm()
		return
	# M12, final-review.md M4: TICK_CONFIRM(), NOT ON THE STEP REGION. set_step() already
	# ticks tick_page() (every other menu's own "a page turned inside a panel that was
	# already open" tick), and ticking here too would make one Enter press fire two sounds --
	# the same double tick casino_menu.gd's own confirm() takes care not to make on the rows
	# that open a table, which already ticks tick_open() on its own.
	if region != &"step":
		MenuStyleScript.tick_confirm()
	var buttons := _region_buttons(region)
	if _kb_item >= 0 and _kb_item < buttons.size():
		buttons[_kb_item].pressed.emit()


## REDRAW THE CURSOR. Clears whatever was highlighted before (a grid's border, a button's
## override, or the name field's) and marks the new one -- at most one Control is ever
## highlighted at a time, so clearing is always exactly the three lines below rather than a
## walk over every region hunting for a stale mark.
func _apply_kb_highlight() -> void:
	if _kb_grid != null:
		_kb_grid.set_highlighted(-1)
		_kb_grid = null
	if _kb_button != null:
		_kb_button.remove_theme_stylebox_override(&"normal")
		_kb_button = null
	if _kb_on_name and _name_box != null:
		_name_box.remove_theme_stylebox_override(&"normal")
	_kb_on_name = false
	if not _open:
		return
	var region := kb_region()
	if region == &"name":
		if _name_box != null and not _name_box.has_focus():
			_name_box.add_theme_stylebox_override(&"normal", MenuStyleScript.field_box(true))
			_kb_on_name = true
		return
	var grid := _region_grid(region)
	if grid != null:
		grid.set_highlighted(_kb_item)
		_kb_grid = grid
		return
	var buttons := _region_buttons(region)
	if _kb_item >= 0 and _kb_item < buttons.size():
		buttons[_kb_item].add_theme_stylebox_override(&"normal",
			MenuStyleScript.button_box(&"hover"))
		_kb_button = buttons[_kb_item]


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
	# THE VEIL IS NOT AN OPEN SCREEN. Raising it says nothing about a look, builds no model
	# and pauses nothing; whatever state _open was already in, this call puts the screen
	# back to "not opened yet" so is_open() answers honestly until open() actually runs.
	_open = false
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


func _sync_mark() -> void:
	_look.set_mark(_canvas.image())
	if _model != null:
		CutieMarkScript.apply(_model, _look.mark())


## The grassy hillock she stands on (Blender-built, tools/blender_props/build_props.py), so
## the turntable pony is on the ground of a little world rather than floating in a void.
## Static: only the pony on the turntable turns.
func _stand_stage() -> void:
	var path := "res://assets/models/creator_stage.glb"
	if _turntable == null or not ResourceLoader.exists(path):
		return
	var stage: Node3D = (load(path) as PackedScene).instantiate()
	stage.name = "Stage"
	_turntable.get_parent().add_child(stage)
	stage.position = _turntable.position
	ToonStyler.style(stage, &"prop", {})


## THE STREAK ROW ONLY WHERE THERE IS A STREAK (PT11; playtest 2026-11-05: "mane streak is
## visible always when its like never used"): shown on the hair step for a mane style whose
## donor carries second-colour locks, hidden otherwise.
func _show_streak() -> void:
	var on := _step == Step.HAIR and style_has_streak()
	for n: String in ["Mane2Label", "Mane2Grid"]:
		var node := get_node_or_null(NodePath("Layout/Panel/Margin/Column/" + n)) as Control
		if node != null:
			node.visible = on


func style_has_streak() -> bool:
	var donor: StringName = _look.to_pony_look(_palette).donor
	if donor == &"":
		return false
	var entry: Dictionary = DonorTableScript.load_table().find(donor)
	return not (entry.get("mane2", PackedStringArray()) as PackedStringArray).is_empty()


## SURPRISE ME (PT11; playtest 2026-11-05: "maybe random on pony creation?"): a whole new pony,
## kind, coat, eyes, mane style and colours, and a generated cutie mark; her name is kept.
func surprise(seed_value: int = -1) -> void:
	var r: Dictionary = PonySurpriseScript.roll(seed_value, _palette.coats.size(),
		_palette.manes.size(), _palette.eyes.size(), ink_count())
	_look.race = int(r.race)
	_look.mane_style = int(r.mane_style)
	_look.coat = int(r.coat)
	_look.mane = int(r.mane)
	_look.eyes = int(r.eyes)
	_look.mane2 = int(r.mane2)
	_look.tail = int(r.tail)
	_motif = int(r.motif)
	set_ink(int(r.ink))
	use_talent(StringName(r.talent))
	_build_model()
	_retint_mane_style_grid()
	_restyle()
	_show_streak()


## A GALLERY OF REAL MARKS TO START FROM (PT11; playtest 2026-11-05: "cutie mark creation has to
## be better"). The 24 talents the valley's own ponies Bloom into (MarkComposer), drawn in her
## chosen ink with a gold accent, alone, in a pair or in three: click one and it lands on the
## canvas, ready to draw over.
var _motif := 0
var _talent_buttons: Array[TextureButton] = []
var _shape_buttons: Array[TextureButton] = []
const ACCENT := Color(1.0, 0.86, 0.42)
const TALENT_THUMB := 44


func _build_talent_gallery() -> void:
	var column := get_node_or_null(^"Layout/Panel/Margin/Column") as VBoxContainer
	var stamps := get_node_or_null(^"Layout/Panel/Margin/Column/StampRow") as Control
	if column == null or stamps == null:
		return
	var label := Label.new()
	label.name = "TalentLabel"
	label.text = "Stamp a symbol, up to three"
	MenuStyleScript.style_label(label, 20, MenuStyleScript.COLOR_INK)
	column.add_child(label)
	column.move_child(label, stamps.get_index())
	var grid := GridContainer.new()
	grid.name = "TalentGrid"
	grid.columns = 12
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	column.add_child(grid)
	column.move_child(grid, stamps.get_index())
	for t: StringName in MarkComposerScript.talent_ids():
		var b := TextureButton.new()
		b.name = "Talent_" + String(t)
		b.custom_minimum_size = Vector2(TALENT_THUMB, TALENT_THUMB)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.tooltip_text = MarkComposerScript.talent_name(t)
		b.focus_mode = Control.FOCUS_NONE
		var talent := t
		# STAMPED, NOT PASTED (PS7 item 3): the talent lands as a stamp she can move, size, turn
		# and recolour, over whatever she has drawn.
		b.pressed.connect(func() -> void: stamp_symbol(StringName("talent:" + String(talent))))
		grid.add_child(b)
		_talent_buttons.append(b)
	# THE TWELVE PLAIN SHAPES beside the talents (MarkLayout.SHAPES). The old one, pair and three
	# arrangements and the six whole-canvas stamps are gone: a stamp is placed by hand now.
	var shapes := GridContainer.new()
	shapes.name = "ShapeGrid"
	shapes.columns = 12
	shapes.add_theme_constant_override(&"h_separation", 6)
	column.add_child(shapes)
	column.move_child(shapes, stamps.get_index())
	for sh: StringName in MarkLayoutScript.SHAPES:
		var b := TextureButton.new()
		b.name = "Shape_" + String(sh)
		b.custom_minimum_size = Vector2(TALENT_THUMB, TALENT_THUMB)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.tooltip_text = String(sh).capitalize()
		b.focus_mode = Control.FOCUS_NONE
		var kind := StringName("shape:" + String(sh))
		b.pressed.connect(func() -> void: stamp_symbol(kind))
		shapes.add_child(b)
		_shape_buttons.append(b)
	stamps.visible = false
	var actions := get_node_or_null(^"Layout/Panel/Margin/Column/ActionRow") as HBoxContainer
	if actions != null and actions.get_node_or_null(^"Remove") == null:
		var rm := Button.new()
		rm.name = "Remove"
		rm.text = "Remove stamp"
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(func() -> void:
			if _canvas != null:
				_canvas.remove_selected())
		_paper_button(rm)
		actions.add_child(rm)
	_refresh_talent_thumbs()


func _refresh_talent_thumbs() -> void:
	var ink: Color = _canvas.get("_colour") if _canvas != null and _canvas.get("_colour") is Color else ink_at(0)
	var talents := MarkComposerScript.talent_ids()
	for i in mini(_talent_buttons.size(), talents.size()):
		var img: Image = MarkComposerScript.compose({"talent": talents[i], "motif": 0, "a": ink, "b": ACCENT})
		if img != null:
			_talent_buttons[i].texture_normal = ImageTexture.create_from_image(img)
	for i in mini(_shape_buttons.size(), MarkLayoutScript.SHAPES.size()):
		var st: Dictionary = MarkLayoutScript.new_stamp(StringName("shape:" + String(MarkLayoutScript.SHAPES[i])), ink, ACCENT)
		st.scale = 0.9
		_shape_buttons[i].texture_normal = ImageTexture.create_from_image(MarkLayoutScript.compose([st], 64))


## Stamp a symbol (a MarkLayout kind) on her mark, selected and ready to move.
func stamp_symbol(kind: StringName) -> bool:
	if _canvas == null or not _canvas.add_stamp(kind):
		return false
	_sync_mark()
	return true


func use_talent(talent: StringName) -> void:
	var ink: Color = _canvas.get("_colour") if _canvas != null and _canvas.get("_colour") is Color else ink_at(0)
	var img: Image = MarkComposerScript.compose({"talent": talent, "motif": _motif, "a": ink, "b": ACCENT})
	if img == null or _canvas == null:
		return
	var sized := img.duplicate() as Image
	var current: Image = _canvas.image()
	if current != null and sized.get_size() != current.get_size():
		sized.resize(current.get_width(), current.get_height(), Image.INTERPOLATE_BILINEAR)
	_canvas.set_image(sized)
	_sync_mark()


func _build_surprise_button() -> void:
	var row := get_node_or_null(^"Layout/Panel/Margin/Column/StepRow") as HBoxContainer
	if row == null:
		return
	var b := Button.new()
	b.name = "Surprise"
	b.text = "Surprise me"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: surprise())
	_paper_button(b)
	b.add_theme_color_override("font_color", Color(0.55, 0.25, 0.62))
	row.add_child(b)


func _build_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
		_model = null
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
	if data == null or not ResourceLoader.exists(data.model_path):
		# The assetless checkout (docs/ci.md section 4). The swatches and the canvas still
		# work; there is simply nothing standing on the turntable to look at.
		return
	# The body her paint expects: her race's donor list (PlayerLook.styles_for), never the
	# old four-unicorn list, or past the fourth style the mane names miss and the mane keeps
	# the donor's own texture (owner playtest 2026-10-25, "cant customize my ponies hair").
	var donor: StringName = _look.to_pony_look(_palette).donor
	_model = PonyVisualsScript.build(data, DonorTableScript.model_path(donor) if donor != &"" \
		else StockPaletteScript.mane_style_path(_look.mane_style))
	if _model != null:
		_model.rotate_y(PI)
		_turntable.add_child(_model)
		# NO HAIR SPRINGS ON THE TURNTABLE (PT11; playtest 2026-11-05: "spinning the pony makes
		# it bug out", the mane flung spiky and the tail through her): a spin is the stand
		# turning, not her running, and the preview shows her hair as styled.
		for sim: SkeletonModifier3D in _model.find_children("*", "SpringBoneSimulator3D", true, false):
			sim.active = false


func _restyle() -> void:
	if _model == null:
		return
	# The same paint every pony in the game wears (game/systems/pony_paint.gd).
	PonyPaintScript.apply(_model, _look.to_pony_look(_palette))


func _process(delta: float) -> void:
	if not _open or _turntable == null:
		return
	if _drag_rest > 0.0:
		_drag_rest -= delta
		return
	_turntable.rotate_y(deg_to_rad(TURN_DEGREES_PER_SECOND) * delta)


# --- human-playable polish, wiring the scene's buttons onto the methods above ------------
##
## NONE OF THIS IS ON THE TESTED CONTRACT. game/test/test_creation_screen.gd drives
## cycle_coat()/cycle_mane()/cycle_eyes()/canvas()/confirm() directly -- see the class
## comment -- so a mouse click just has to reach one of those same public methods. This
## section is what makes Step 9 ("look at her") a screen a person can actually click
## through rather than only a screen a test can drive.

func _wire_controls() -> void:
	for id: int in MarkStampsScript.ids():
		_connect(NodePath("Layout/Panel/Margin/Column/StampRow/Stamp%d" % id),
			func() -> void: stamp(id))

	# The ink row. The buttons' labels are assigned from INK_NAMES here rather than authored
	# a second time in creation_screen.tscn, for the reason the Label block above gives: the
	# .gd consts are the only place any of this screen's text is written.
	for index: int in range(ink_count()):
		var ink := get_node_or_null(
			NodePath("Layout/Panel/Margin/Column/InkRow/Ink%d" % index)) as BaseButton
		if ink == null:
			continue
		if ink is Button:
			(ink as Button).text = ink_name(index)
		ink.pressed.connect(func() -> void: set_ink(index))

	for radius: int in MarkPaintScript.BRUSHES:
		_connect(NodePath("Layout/Panel/Margin/Column/ToolRow/Brush%d" % radius),
			func() -> void: _canvas.set_brush(radius))
	# Toggled rather than pressed: a colour brush pressed while erasing has to be able to
	# turn the eraser back off, and this button is the only control that does.
	_connect(^"Layout/Panel/Margin/Column/ToolRow/Eraser", func() -> void: _canvas.set_eraser(
		not _canvas.is_erasing()))

	_connect(^"Layout/Panel/Margin/Column/ActionRow/Undo", func() -> void: _canvas.undo())
	_connect(^"Layout/Panel/Margin/Column/ActionRow/Clear", func() -> void: _canvas.clear_all())


func _connect(path: NodePath, action: Callable) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null:
		button.pressed.connect(action)


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
	var style_name := get_node_or_null(^"Layout/Panel/Margin/Column/StyleRow/StyleName") as Label
	if style_name != null:
		style_name.text = "Style %d of %d" % [_look.mane_style + 1,
			PlayerLookScript.style_count(_look.race)]
	if _race_grid != null:
		_race_grid.set_selected(_look.race)
	if _mane2_grid != null:
		_mane2_grid.set_selected(_look.mane2 + 1)
	if _tail_grid != null:
		_tail_grid.set_selected(_look.tail + 1)
