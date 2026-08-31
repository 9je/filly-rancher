extends GutTest
## The painting widget, driven in canvas local coordinates rather than through a mouse.

const MarkCanvasScene := preload("res://ui/mark_canvas.tscn")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")

var _canvas: MarkCanvas = null


func before_each() -> void:
	_canvas = MarkCanvasScene.instantiate()
	add_child_autofree(_canvas)
	_canvas.size = Vector2(256.0, 256.0)


func test_a_fresh_canvas_is_blank() -> void:
	assert_true(MarkPaintScript.is_blank(_canvas.image()))


func test_painting_marks_the_image_and_announces_it() -> void:
	watch_signals(_canvas)
	_canvas.set_colour(Color.RED)
	_canvas.set_brush(2)
	_canvas.paint_at(Vector2(128.0, 128.0))
	assert_false(MarkPaintScript.is_blank(_canvas.image()))
	assert_signal_emitted(_canvas, "changed")


func test_a_drag_paints_a_line_rather_than_two_dots() -> void:
	_canvas.set_colour(Color.RED)
	_canvas.set_brush(1)
	_canvas.paint_at(Vector2(16.0, 128.0))
	_canvas.drag_to(Vector2(240.0, 128.0))
	var image: Image = _canvas.image()
	var y: int = 32
	var run := 0
	for x in MarkPaintScript.SIZE:
		if image.get_pixel(x, y).a > 0.0:
			run += 1
	assert_gt(run, 40, "the drag is a stroke, not its endpoints")


func test_the_eraser_takes_paint_off() -> void:
	_canvas.set_colour(Color.RED)
	_canvas.set_brush(4)
	_canvas.paint_at(Vector2(128.0, 128.0))
	_canvas.set_eraser(true)
	_canvas.paint_at(Vector2(128.0, 128.0))
	assert_true(MarkPaintScript.is_blank(_canvas.image()))


func test_undo_steps_back_one_stroke_at_a_time() -> void:
	_canvas.set_colour(Color.RED)
	_canvas.paint_at(Vector2(64.0, 64.0))
	var after_first: Image = _canvas.image()
	_canvas.paint_at(Vector2(192.0, 192.0))
	assert_false(MarkPaintScript.equal(_canvas.image(), after_first))
	assert_true(_canvas.undo())
	assert_true(MarkPaintScript.equal(_canvas.image(), after_first))
	assert_true(_canvas.undo())
	assert_true(MarkPaintScript.is_blank(_canvas.image()))
	assert_false(_canvas.undo(), "and there is nothing before the blank canvas")


func test_the_undo_stack_is_bounded() -> void:
	_canvas.set_colour(Color.RED)
	for i in MarkCanvas.UNDO_DEPTH + 20:
		_canvas.paint_at(Vector2(float(4 + i % 60) * 4.0, 128.0))
	var steps := 0
	while _canvas.undo():
		steps += 1
	assert_lte(steps, MarkCanvas.UNDO_DEPTH, "a long session must not grow without bound")


func test_clear_empties_it_and_is_itself_undoable() -> void:
	_canvas.set_colour(Color.RED)
	_canvas.paint_at(Vector2(128.0, 128.0))
	_canvas.clear_all()
	assert_true(MarkPaintScript.is_blank(_canvas.image()))
	assert_true(_canvas.undo())
	assert_false(MarkPaintScript.is_blank(_canvas.image()),
		"clearing by accident must not cost her the drawing")


func test_a_stamp_replaces_the_canvas_and_is_undoable() -> void:
	_canvas.set_colour(Color.BLUE)
	_canvas.stamp(MarkStampsScript.Stamp.APPLE)
	assert_false(MarkPaintScript.is_blank(_canvas.image()))
	assert_true(_canvas.undo())
	assert_true(MarkPaintScript.is_blank(_canvas.image()))


func test_an_image_set_from_a_save_reads_back_pixel_identical() -> void:
	var source: Image = MarkStampsScript.build(MarkStampsScript.Stamp.CLOUD, Color.GREEN)
	_canvas.set_image(source)
	assert_true(MarkPaintScript.equal(_canvas.image(), source))


func test_the_canvas_returns_a_copy_rather_than_its_own_pixels() -> void:
	var taken: Image = _canvas.image()
	MarkPaintScript.dot(taken, Vector2i(1, 1), Color.RED, 0)
	assert_true(MarkPaintScript.is_blank(_canvas.image()))
