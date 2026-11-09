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
const LayoutScript := preload("res://systems/mark_layout.gd")
## A stamp's detail colour: the show's gold accent, the same the talent gallery draws with.
const ACCENT := Color(1.0, 0.86, 0.42)
## How near a handle a press has to land to take it, in local pixels.
const HANDLE_REACH := 16.0

## Snapshots kept. See the class comment for the arithmetic.
const UNDO_DEPTH := 24

signal changed()

var _image: Image = null
var _texture: ImageTexture = null
## Snapshots of {paint, stamps, selected}: one undo covers the drawing and the stamps.
var _undo: Array[Dictionary] = []
## THE STAMPS (PS7, playtest 2026-11-05 item 3): up to three symbols laid over the drawing,
## each moved, sized, turned and coloured (systems/mark_layout.gd). `_sel` is the one the
## handles are on, or -1.
var _stamps: Array = []
var _sel := -1
var _mode := ""
var _grab := {}
var _handles: Control = null
var _colour := Color(0.20, 0.20, 0.24, 1.0)
var _radius: int = MarkPaintScript.BRUSHES[1]
var _eraser := false
var _last := Vector2i(-1, -1)

@onready var _surface: TextureRect = $Surface


func _ready() -> void:
	_image = MarkPaintScript.blank()
	_texture = ImageTexture.create_from_image(_image)
	_surface.texture = _texture
	_handles = Control.new()
	_handles.name = "Handles"
	_handles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handles.set_anchors_preset(Control.PRESET_FULL_RECT)
	_handles.draw.connect(_draw_handles)
	add_child(_handles)


## A COPY, always. The undo stack and the save both hold the pixels this returns, and either
## of them sharing the live image would mean painting one more stroke silently rewrote the
## history and the save with it.
func image() -> Image:
	var out := MarkPaintScript.copy_of(_image)
	LayoutScript.draw_over(out, _stamps)
	return out


## Load a drawing (from a save, or from the creation screen restoring one). Does NOT push an
## undo entry: this is not something the player did.
func set_image(source: Image) -> void:
	_image = MarkPaintScript.copy_of(source)
	_stamps = []
	_sel = -1
	_undo.clear()
	_refresh()


## The ink for the brush, and for the selected stamp if there is one (it is recoloured).
func set_colour(colour: Color) -> void:
	_colour = colour
	_eraser = false
	if _sel >= 0 and _sel < _stamps.size():
		_push_undo()
		_stamps[_sel].a = colour
		_refresh()
		changed.emit()


# --- stamps -----------------------------------------------------------------------------------

func stamps() -> Array:
	return _stamps.duplicate(true)


func selected() -> int:
	return _sel


## Lay a symbol (a MarkLayout kind) in the middle of the mark, selected: in `colours` ([fill,
## detail], the symbol's own from the gallery) or, without them, the current ink and gold.
## False when MAX_STAMPS are already down.
func add_stamp(kind: StringName, colours: Array = []) -> bool:
	if _stamps.size() >= LayoutScript.MAX_STAMPS:
		return false
	_push_undo()
	var a: Color = colours[0] if colours.size() > 0 else _colour
	var b: Color = colours[1] if colours.size() > 1 else ACCENT
	_stamps = LayoutScript.added(_stamps, LayoutScript.new_stamp(kind, a, b))
	_sel = _stamps.size() - 1
	_refresh()
	changed.emit()
	return true


func remove_selected() -> bool:
	if _sel < 0 or _sel >= _stamps.size():
		return false
	_push_undo()
	_stamps.remove_at(_sel)
	_sel = -1
	_refresh()
	changed.emit()
	return true


## Where the selected-stamp handles are, in local pixels: {"scale": its corner, "rotate": the
## knob over its top}.
func handle_points(i: int) -> Dictionary:
	if i < 0 or i >= _stamps.size():
		return {}
	var st: Dictionary = _stamps[i]
	var box := size.x
	var c: Vector2 = (st.at as Vector2) * box
	var half: float = float(st.scale) * box * 0.5
	var rot: float = float(st.rot)
	return {"scale": c + Vector2(half, half).rotated(rot),
		"rotate": c + Vector2(0.0, -half - 18.0).rotated(rot), "centre": c}


## A press: a handle of the selected stamp, else a stamp's body, else the brush.
func press_at(point: Vector2) -> void:
	_mode = ""
	if _sel >= 0:
		var h := handle_points(_sel)
		if point.distance_to(h.scale) <= HANDLE_REACH:
			_push_undo()
			_mode = "scale"
			_grab = {"scale": float(_stamps[_sel].scale), "dist": maxf(1.0, point.distance_to(h.centre)),
				"centre": h.centre}
			return
		if point.distance_to(h.rotate) <= HANDLE_REACH:
			_push_undo()
			_mode = "rotate"
			_grab = {"rot": float(_stamps[_sel].rot), "angle": (point - h.centre).angle(), "centre": h.centre}
			return
	var u := point / maxf(1.0, size.x)
	var i := LayoutScript.hit(_stamps, u)
	if i >= 0:
		_push_undo()
		_sel = i
		_mode = "move"
		_grab = {"offset": (_stamps[i].at as Vector2) - u}
		_refresh()
		return
	_sel = -1
	_mode = "paint"
	paint_at(point)


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


## Continue the stroke begun by paint_at(), or the stamp drag begun by press_at(). No undo
## entry: one drag is one undoable action.
func drag_to(point: Vector2) -> void:
	if _mode in ["move", "scale", "rotate"] and _sel >= 0 and _sel < _stamps.size():
		match _mode:
			"move":
				var u := point / maxf(1.0, size.x) + (_grab.offset as Vector2)
				_stamps[_sel].at = Vector2(clampf(u.x, 0.0, 1.0), clampf(u.y, 0.0, 1.0))
			"scale":
				var d: float = point.distance_to(_grab.centre)
				_stamps[_sel].scale = clampf(float(_grab.scale) * d / float(_grab.dist),
					LayoutScript.SCALE_RANGE.x, LayoutScript.SCALE_RANGE.y)
			"rotate":
				var a: float = (point - (_grab.centre as Vector2)).angle()
				_stamps[_sel].rot = wrapf(float(_grab.rot) + a - float(_grab.angle), -PI, PI)
		_refresh()
		changed.emit()
		return
	var at: Vector2i = _to_pixels(point)
	if _last.x < 0:
		_last = at
	MarkPaintScript.stroke(_image, _last, at, _ink(), _radius)
	_last = at
	_refresh()
	changed.emit()


func end_stroke() -> void:
	_last = Vector2i(-1, -1)
	_mode = ""


func stamp(id: int) -> void:
	_push_undo()
	_image = MarkStampsScript.build(id, _colour)
	_refresh()
	changed.emit()


func clear_all() -> void:
	_push_undo()
	MarkPaintScript.clear(_image)
	_stamps = []
	_sel = -1
	_refresh()
	changed.emit()


## Step back one action. Returns whether there was anything to step back to.
func undo() -> bool:
	if _undo.is_empty():
		return false
	var snap: Dictionary = _undo.pop_back()
	_image = snap.paint
	_stamps = snap.stamps
	_sel = int(snap.sel)
	_refresh()
	changed.emit()
	return true


func _ink() -> Color:
	return MarkPaintScript.EMPTY if _eraser else _colour


func _push_undo() -> void:
	_undo.append({"paint": MarkPaintScript.copy_of(_image), "stamps": _stamps.duplicate(true), "sel": _sel})
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


## THE CANVAS SHOWS THE STAMPS CRISP (Fable AAA round 3, #6). The mark itself is SIZE pixels
## (what the flank wears and the save keeps); the canvas is four times that across, where a
## stamp drawn at SIZE and blown up read as a block of pixels. So the canvas draws its own
## picture: the painted layer, smoothed, and the stamps drawn again at DISPLAY_SIZE over it.
const DISPLAY_SIZE := 128


func display_image() -> Image:
	var out := MarkPaintScript.copy_of(_image)
	out.resize(DISPLAY_SIZE, DISPLAY_SIZE, Image.INTERPOLATE_BILINEAR)
	LayoutScript.draw_over(out, _stamps)
	return out


func _refresh() -> void:
	_texture = ImageTexture.create_from_image(display_image())
	if _surface != null:
		_surface.texture = _texture
	if _handles != null:
		_handles.queue_redraw()


## The selected stamp's box, its corner knob (size) and its top knob (turn).
func _draw_handles() -> void:
	if _sel < 0 or _sel >= _stamps.size():
		return
	var h := handle_points(_sel)
	var st: Dictionary = _stamps[_sel]
	var half: float = float(st.scale) * size.x * 0.5
	var rot: float = float(st.rot)
	var c: Vector2 = h.centre
	var pts := PackedVector2Array()
	for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		pts.append(c + (k * half).rotated(rot))
	_handles.draw_polyline(pts, Color(1.0, 0.86, 0.42), 2.0, true)
	_handles.draw_line(c + Vector2(0.0, -half).rotated(rot), h.rotate, Color(1.0, 0.86, 0.42), 2.0, true)
	for knob: Vector2 in [h.scale, h.rotate]:
		_handles.draw_circle(knob, 8.0, Color(1.0, 0.86, 0.42))
		_handles.draw_circle(knob, 5.0, Color(0.24, 0.15, 0.3))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			press_at(button.position)
		else:
			end_stroke()
		accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			drag_to(motion.position)
			accept_event()
