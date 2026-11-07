extends GutTest
## THE STAMP EDITOR ON THE CANVAS (PS7, playtest 2026-11-05 item 3: "Better cutie mark
## creation"). A symbol is stamped on, selected; dragged by its body it moves, by its corner it
## grows, by its top handle it turns; an ink recolours the selected stamp; drawing away from
## the stamps still paints, under them; undo steps back through all of it.

const CanvasScene := preload("res://ui/mark_canvas.tscn")
const LayoutScript := preload("res://systems/mark_layout.gd")

var _canvas: Control


func before_each() -> void:
	_canvas = CanvasScene.instantiate()
	add_child_autofree(_canvas)
	_canvas.size = Vector2(256, 256)
	_canvas.set_colour(Color(0.9, 0.2, 0.25))


func _drag(from: Vector2, to: Vector2) -> void:
	_canvas.press_at(from)
	for i in range(1, 9):
		_canvas.drag_to(from.lerp(to, float(i) / 8.0))
	_canvas.end_stroke()


func test_a_stamp_lands_selected_and_undo_takes_it_off() -> void:
	assert_true(_canvas.add_stamp(&"talent:music"))
	assert_eq(_canvas.stamps().size(), 1)
	assert_eq(_canvas.selected(), 0)
	assert_gt(_canvas.image().get_pixel(32, 32).a + _canvas.image().get_pixel(30, 34).a, 0.0, "it shows")
	assert_true(_canvas.undo())
	assert_eq(_canvas.stamps().size(), 0)


func test_dragging_the_body_moves_it() -> void:
	_canvas.add_stamp(&"shape:circle")
	_drag(Vector2(128, 128), Vector2(80, 170))
	var at: Vector2 = _canvas.stamps()[0].at
	assert_almost_eq(at.x, 80.0 / 256.0, 0.03)
	assert_almost_eq(at.y, 170.0 / 256.0, 0.03)


func test_dragging_the_corner_grows_it_and_the_top_handle_turns_it() -> void:
	_canvas.add_stamp(&"shape:square")
	var before: float = _canvas.stamps()[0].scale
	var corner: Vector2 = _canvas.handle_points(0).scale
	_drag(corner, corner + Vector2(30, 30))
	assert_gt(float(_canvas.stamps()[0].scale), before + 0.1, "grew")
	var top: Vector2 = _canvas.handle_points(0).rotate
	var centre: Vector2 = (_canvas.stamps()[0].at as Vector2) * 256.0
	_drag(top, centre + Vector2(80, 0))
	assert_almost_eq(float(_canvas.stamps()[0].rot), PI * 0.5, 0.2, "turned a quarter")


func test_an_ink_recolours_the_selected_stamp_and_otherwise_inks_the_brush() -> void:
	_canvas.add_stamp(&"shape:circle")
	_canvas.set_colour(Color(0.1, 0.3, 0.95))
	assert_gt((_canvas.stamps()[0].a as Color).b, 0.8, "the stamp took the ink")
	_canvas.press_at(Vector2(4, 4))
	_canvas.end_stroke()
	assert_eq(_canvas.selected(), -1, "clicking away deselects")


func test_drawing_away_from_the_stamps_paints_under_them() -> void:
	_canvas.add_stamp(&"shape:circle")
	_drag(Vector2(10, 240), Vector2(40, 240))
	assert_gt(_canvas.image().get_pixel(5, 60).a, 0.5, "the stroke is on the canvas")
	assert_eq(_canvas.stamps().size(), 1, "and the stamp stayed")


func test_remove_and_the_limit_of_three() -> void:
	for i in 4:
		_canvas.add_stamp(&"shape:star")
	assert_eq(_canvas.stamps().size(), LayoutScript.MAX_STAMPS)
	assert_false(_canvas.add_stamp(&"shape:star"), "a fourth is refused")
	assert_true(_canvas.remove_selected())
	assert_eq(_canvas.stamps().size(), 2)


## A HOLLOW STAMP IS STILL GRABBED IN ITS MIDDLE: a press in a crescent's empty centre used to
## miss it and paint a stroke instead (render, 2026-11-07).
func test_a_press_in_a_hollow_stamps_middle_moves_it_and_paints_nothing() -> void:
	_canvas.add_stamp(&"shape:ring")
	var before: Image = _canvas.image()
	_drag(Vector2(128, 128), Vector2(150, 150))
	assert_gt(float((_canvas.stamps()[0].at as Vector2).x), 0.55, "the ring moved")
	_canvas.remove_selected()
	assert_true(_canvas.image().get_pixel(32, 32).a < 0.1, "and no stroke was left behind")
