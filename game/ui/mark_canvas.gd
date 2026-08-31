class_name MarkCanvas
extends Control
## THE CUTIE MARK THE PLAYER DRAWS. A sixty four pixel square she paints on with a colour,
## four brush sizes, an eraser, undo, clear, and six shapes to start from
## (game/systems/mark_stamps.gd).
##
## THE PIXELS ARE game/systems/mark_paint.gd's; the tools, the undo stack and the input are
## this file's. That split is what lets the drawing be tested without a mouse: every
## operation this widget performs is reachable through paint_at()/drag_to()/undo()/stamp()
## in CANVAS LOCAL coordinates, and _gui_input() does nothing but convert a mouse position
## into one of those calls.
##
## UNDO IS A BOUNDED STACK OF SNAPSHOTS, not a list of operations. A sixty four square RGBA
## image is sixteen kilobytes, so twenty four of them is under half a megabyte and the
## whole of "undo" is one assignment. An operation log would be smaller and would have to be
## right about the inverse of every tool, including clear and stamp; this cannot be wrong.
##
## CLEAR AND STAMP ARE UNDOABLE, deliberately: both throw the whole drawing away, and a
## player who hits one by accident must not lose the thing she has been working on.

const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")

## Snapshots kept. See the class comment for the arithmetic.
const UNDO_DEPTH := 24

signal changed()

var _image: Image = null
var _texture: ImageTexture = null
var _undo: Array[Image] = []
var _colour := Color(0.20, 0.20, 0.24, 1.0)
var _radius: int = MarkPaintScript.BRUSHES[1]
var _eraser := false
var _last := Vector2i(-1, -1)

@onready var _surface: TextureRect = $Surface


func _ready() -> void:
	_image = MarkPaintScript.blank()
	_texture = ImageTexture.create_from_image(_image)
	_surface.texture = _texture


## A COPY, always. The undo stack and the save both hold the pixels this returns, and either
## of them sharing the live image would mean painting one more stroke silently rewrote the
## history and the save with it.
func image() -> Image:
	return MarkPaintScript.copy_of(_image)


## Load a drawing (from a save, or from the creation screen restoring one). Does NOT push an
## undo entry: this is not something the player did.
func set_image(source: Image) -> void:
	_image = MarkPaintScript.copy_of(source)
	_undo.clear()
	_refresh()


func set_colour(colour: Color) -> void:
	_colour = colour
	_eraser = false


func set_brush(radius: int) -> void:
	_radius = clampi(radius, 0, MarkPaintScript.BRUSHES[MarkPaintScript.BRUSHES.size() - 1])


func set_eraser(on: bool) -> void:
	_eraser = on


func is_erasing() -> bool:
	return _eraser


## Begin a stroke at `point`, in this control's local coordinates.
func paint_at(point: Vector2) -> void:
	_push_undo()
	var at: Vector2i = _to_pixels(point)
	MarkPaintScript.dot(_image, at, _ink(), _radius)
	_last = at
	_refresh()
	changed.emit()


## Continue the stroke begun by paint_at(). No undo entry: one drag is one undoable action.
func drag_to(point: Vector2) -> void:
	var at: Vector2i = _to_pixels(point)
	if _last.x < 0:
		_last = at
	MarkPaintScript.stroke(_image, _last, at, _ink(), _radius)
	_last = at
	_refresh()
	changed.emit()


func end_stroke() -> void:
	_last = Vector2i(-1, -1)


func stamp(id: int) -> void:
	_push_undo()
	_image = MarkStampsScript.build(id, _colour)
	_refresh()
	changed.emit()


func clear_all() -> void:
	_push_undo()
	MarkPaintScript.clear(_image)
	_refresh()
	changed.emit()


## Step back one action. Returns whether there was anything to step back to.
func undo() -> bool:
	if _undo.is_empty():
		return false
	_image = _undo.pop_back()
	_refresh()
	changed.emit()
	return true


func _ink() -> Color:
	return MarkPaintScript.EMPTY if _eraser else _colour


func _push_undo() -> void:
	_undo.append(MarkPaintScript.copy_of(_image))
	while _undo.size() > UNDO_DEPTH:
		_undo.remove_at(0)


## Local pixels to canvas pixels. The control is square in the creation screen's layout, and
## a zero sized control (a widget that has not been laid out yet) maps everything to the top
## left rather than dividing by zero.
func _to_pixels(point: Vector2) -> Vector2i:
	var box: Vector2 = size
	if box.x <= 0.0 or box.y <= 0.0:
		return Vector2i.ZERO
	return Vector2i(
		clampi(int(point.x / box.x * float(MarkPaintScript.SIZE)), 0, MarkPaintScript.SIZE - 1),
		clampi(int(point.y / box.y * float(MarkPaintScript.SIZE)), 0, MarkPaintScript.SIZE - 1))


func _refresh() -> void:
	_texture = ImageTexture.create_from_image(_image)
	if _surface != null:
		_surface.texture = _texture


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			paint_at(button.position)
		else:
			end_stroke()
		accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			drag_to(motion.position)
			accept_event()
