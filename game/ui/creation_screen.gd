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

const PlayerLookScript := preload("res://systems/player_look.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")

const TITLE := "Who are you?"
const NAME_LABEL := "Your name"
const COAT_LABEL := "Coat"
const MANE_LABEL := "Mane and tail"
const EYES_LABEL := "Eyes"
const MARK_LABEL := "Your cutie mark; draw it yourself"
const CONFIRM_LABEL := "This is me"
const HINT := "Left click to draw. Pick a shape to start from, or start with nothing."

## Degrees per second the turntable turns. Slow enough to read, fast enough to see both
## flanks (and both cutie marks) inside a few seconds.
const TURN_DEGREES_PER_SECOND := 24.0

signal confirmed(look: PlayerLook)

var _look: PlayerLook = null
var _palette: StockPalette = null
var _model: Node3D = null
var _open := false

@onready var _turntable: Node3D = $Viewport/SubViewport/Turntable
@onready var _name_box: LineEdit = $Panel/Column/NameBox
@onready var _canvas: MarkCanvas = $Panel/Column/MarkCanvas
@onready var _confirm: Button = $Panel/Column/Confirm

## The camera and the three swatch previews, kept only for the human-playable polish below
## (_wire_controls()/_refresh_swatches()) -- no test reaches through these.
@onready var _camera: Camera3D = $Viewport/SubViewport/Camera3D
@onready var _coat_swatch: ColorRect = $Panel/Column/CoatRow/CoatSwatch
@onready var _mane_swatch: ColorRect = $Panel/Column/ManeRow/ManeSwatch
@onready var _eyes_swatch: ColorRect = $Panel/Column/EyesRow/EyesSwatch


func _ready() -> void:
	visible = false
	_palette = StockPaletteScript.load_player()
	_name_box.max_length = PlayerLookScript.MAX_NAME_LENGTH
	_confirm.text = CONFIRM_LABEL
	_name_box.text_changed.connect(set_name_text)
	_confirm.pressed.connect(func() -> void: confirm())
	_canvas.changed.connect(func() -> void: _sync_mark())
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_wire_controls()


## Show the screen on `look` and pause the world behind it.
func open(look: PlayerLook) -> void:
	_look = look if look != null else PlayerLookScript.default_look()
	_open = true
	visible = true
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


func cycle_coat(step: int) -> void:
	_look.coat = posmod(_look.coat + step, maxi(1, _palette.coats.size()))
	_restyle()
	_refresh_swatches()


func cycle_mane(step: int) -> void:
	_look.mane = posmod(_look.mane + step, maxi(1, _palette.manes.size()))
	_restyle()
	_refresh_swatches()


func cycle_eyes(step: int) -> void:
	_look.eyes = posmod(_look.eyes + step, maxi(1, _palette.eyes.size()))
	_restyle()
	_refresh_swatches()


func stamp(id: int) -> void:
	_canvas.stamp(id)


## Take the look as it stands and hand it over. Returns whether anything happened; a second
## call does nothing, so a double click on the button cannot start two ranches.
func confirm() -> bool:
	if not _open:
		return false
	_sync_mark()
	set_name_text(_name_box.text)
	_open = false
	visible = false
	get_tree().paused = false
	confirmed.emit(_look)
	return true


## Every string this screen draws, for the copy rule test.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = [TITLE, NAME_LABEL, COAT_LABEL, MANE_LABEL, EYES_LABEL,
		MARK_LABEL, CONFIRM_LABEL, HINT]
	for id: int in MarkStampsScript.ids():
		lines.append(MarkStampsScript.stamp_name(id))
	return lines


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
	_model = PonyVisualsScript.build(data)
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
	if _open and _turntable != null:
		_turntable.rotate_y(deg_to_rad(TURN_DEGREES_PER_SECOND) * delta)


# --- human-playable polish, wiring the scene's buttons onto the methods above ------------
##
## NONE OF THIS IS ON THE TESTED CONTRACT. game/test/test_creation_screen.gd drives
## cycle_coat()/cycle_mane()/cycle_eyes()/canvas()/confirm() directly -- see the class
## comment -- so a mouse click just has to reach one of those same public methods. This
## section is what makes Step 9 ("look at her") a screen a person can actually click
## through rather than only a screen a test can drive.

func _wire_controls() -> void:
	_connect(^"Panel/Column/CoatRow/PrevCoat", func() -> void: cycle_coat(-1))
	_connect(^"Panel/Column/CoatRow/NextCoat", func() -> void: cycle_coat(1))
	_connect(^"Panel/Column/ManeRow/PrevMane", func() -> void: cycle_mane(-1))
	_connect(^"Panel/Column/ManeRow/NextMane", func() -> void: cycle_mane(1))
	_connect(^"Panel/Column/EyesRow/PrevEyes", func() -> void: cycle_eyes(-1))
	_connect(^"Panel/Column/EyesRow/NextEyes", func() -> void: cycle_eyes(1))

	for id: int in MarkStampsScript.ids():
		_connect(NodePath("Panel/Column/StampRow/Stamp%d" % id), func() -> void: stamp(id))

	for radius: int in MarkPaintScript.BRUSHES:
		_connect(NodePath("Panel/Column/ToolRow/Brush%d" % radius),
			func() -> void: _canvas.set_brush(radius))
	# Toggled rather than pressed: a colour brush pressed while erasing has to be able to
	# turn the eraser back off, and this button is the only control that does.
	_connect(^"Panel/Column/ToolRow/Eraser", func() -> void: _canvas.set_eraser(
		not _canvas.is_erasing()))

	_connect(^"Panel/Column/ActionRow/Undo", func() -> void: _canvas.undo())
	_connect(^"Panel/Column/ActionRow/Clear", func() -> void: _canvas.clear_all())


func _connect(path: NodePath, action: Callable) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null:
		button.pressed.connect(action)


## The current pick on each row, shown as a plain colour swatch beside its prev/next
## buttons -- the turntable already shows the whole pony, this is just for reading a choice
## before it is made without having to watch the pony spin round to check.
func _refresh_swatches() -> void:
	if _coat_swatch != null:
		_coat_swatch.color = _palette.coat_at(_look.coat)
	if _mane_swatch != null:
		_mane_swatch.color = _palette.mane_at(_look.mane)
	if _eyes_swatch != null:
		_eyes_swatch.color = _palette.eye_at(_look.eyes)
