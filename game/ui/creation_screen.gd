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
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const SwatchGridScript := preload("res://ui/swatch_grid.gd")

const TITLE := "Who are you?"
const NAME_LABEL := "Your name"
const COAT_LABEL := "Coat"
const MANE_LABEL := "Mane and tail"
const MANE_STYLE_LABEL := "Mane style"
const EYES_LABEL := "Eyes"
const MARK_LABEL := "Your cutie mark; draw it yourself"
const CONFIRM_LABEL := "This is me"
const HINT := "Left click to draw. Pick an ink and a shape to start from, or start with nothing."

enum Step { LOOK, MARK }

const STEP_LOOK_LABEL := "Your pony"
const STEP_MARK_LABEL := "Your cutie mark"

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

signal confirmed(look: PlayerLook)

var _look: PlayerLook = null
var _palette: StockPalette = null
var _model: Node3D = null
var _open := false
var _step: int = Step.LOOK
var _backdrop_only := false
var _drag_rest := 0.0

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
	_eyes_label.text = EYES_LABEL
	_mark_label.text = MARK_LABEL
	_hint_label.text = HINT
	_confirm.text = CONFIRM_LABEL
	_name_box.text_changed.connect(set_name_text)
	_confirm.pressed.connect(func() -> void: confirm())
	_canvas.changed.connect(func() -> void: _sync_mark())
	set_ink(0)
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_wire_controls()
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
		EYES_LABEL, MARK_LABEL, CONFIRM_LABEL, HINT, STEP_LOOK_LABEL, STEP_MARK_LABEL]
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
	_model = PonyVisualsScript.build(data,
		StockPaletteScript.mane_style_path(_look.mane_style))
	if _model != null:
		_model.rotate_y(PI)
		_turntable.add_child(_model)


func _restyle() -> void:
	if _model == null:
		return
	StockTintScript.apply(_model, _palette,
		{"coat": _look.coat, "mane": _look.mane, "eyes": _look.eyes})
	CutieMarkScript.apply(_model, _look.mark())


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
