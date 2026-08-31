extends GutTest
## The pixels under the cutie mark canvas. No Control, no mouse, no scene.

const MarkPaintScript := preload("res://systems/mark_paint.gd")


func test_a_blank_mark_is_sixty_four_square_and_fully_transparent() -> void:
	var image: Image = MarkPaintScript.blank()
	assert_eq(image.get_width(), MarkPaintScript.SIZE)
	assert_eq(image.get_height(), MarkPaintScript.SIZE)
	assert_eq(image.get_format(), MarkPaintScript.FORMAT)
	assert_true(MarkPaintScript.is_blank(image))
	assert_eq(image.get_pixel(0, 0).a, 0.0)


func test_a_dot_lands_where_it_is_put_and_nowhere_else() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.dot(image, Vector2i(32, 32), Color.RED, 2)
	assert_eq(image.get_pixel(32, 32), Color.RED)
	assert_eq(image.get_pixel(32, 34), Color.RED, "the radius is inclusive")
	assert_eq(image.get_pixel(32, 36).a, 0.0, "and it stops")
	assert_false(MarkPaintScript.is_blank(image))


func test_a_dot_at_the_edge_is_clipped_rather_than_wrapped() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.dot(image, Vector2i(0, 0), Color.BLUE, 4)
	assert_eq(image.get_pixel(0, 0), Color.BLUE)
	assert_eq(image.get_pixel(MarkPaintScript.SIZE - 1, MarkPaintScript.SIZE - 1).a, 0.0,
		"a brush off the left edge must not appear on the right one")


func test_a_dot_entirely_outside_the_canvas_changes_nothing() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.dot(image, Vector2i(-40, 200), Color.BLUE, 2)
	assert_true(MarkPaintScript.is_blank(image))


func test_a_stroke_paints_every_pixel_between_its_ends() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.stroke(image, Vector2i(10, 10), Vector2i(50, 10), Color.GREEN, 1)
	for x in range(10, 51):
		assert_eq(image.get_pixel(x, 10), Color.GREEN, "gap at x=%d" % x)
	# Not x=9: a radius-1 brush at the (10, 10) endpoint is inclusive, per
	# test_a_dot_lands_where_it_is_put_and_nowhere_else, and legitimately spills onto x=9.
	# x=8 is the first column the stroke cannot reach.
	assert_eq(image.get_pixel(8, 10).a, 0.0)


func test_a_diagonal_stroke_leaves_no_gaps() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.stroke(image, Vector2i(4, 4), Vector2i(60, 40), Color.BLACK, 1)
	var painted := 0
	for y in MarkPaintScript.SIZE:
		var row := false
		for x in MarkPaintScript.SIZE:
			if image.get_pixel(x, y).a > 0.0:
				row = true
		if row:
			painted += 1
	assert_eq(painted, 39, "every row the line crosses has ink in it")


func test_the_eraser_is_a_stroke_of_full_transparency() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.dot(image, Vector2i(32, 32), Color.RED, 4)
	MarkPaintScript.dot(image, Vector2i(32, 32), Color(0, 0, 0, 0), 4)
	assert_true(MarkPaintScript.is_blank(image))


func test_clear_empties_the_whole_canvas() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.stroke(image, Vector2i(0, 0), Vector2i(63, 63), Color.RED, 8)
	MarkPaintScript.clear(image)
	assert_true(MarkPaintScript.is_blank(image))


func test_two_images_compare_pixel_by_pixel() -> void:
	var a: Image = MarkPaintScript.blank()
	var b: Image = MarkPaintScript.blank()
	assert_true(MarkPaintScript.equal(a, b))
	MarkPaintScript.dot(b, Vector2i(1, 1), Color.RED, 0)
	assert_false(MarkPaintScript.equal(a, b))
	assert_false(MarkPaintScript.equal(a, null))


func test_a_copy_is_independent_of_its_original() -> void:
	var a: Image = MarkPaintScript.blank()
	var b: Image = MarkPaintScript.copy_of(a)
	MarkPaintScript.dot(b, Vector2i(5, 5), Color.RED, 1)
	assert_true(MarkPaintScript.is_blank(a), "the undo stack must not share pixels with the canvas")


func test_the_orientation_probe_is_not_blank_and_is_asymmetric() -> void:
	var probe: Image = MarkPaintScript.orientation_probe()
	assert_false(MarkPaintScript.is_blank(probe), "the probe has to be visible to prove anything")
	var top_left := 0
	var bottom_right := 0
	for y in MarkPaintScript.SIZE:
		for x in MarkPaintScript.SIZE:
			if probe.get_pixel(x, y).a <= 0.0:
				continue
			if x < MarkPaintScript.SIZE / 2 and y < MarkPaintScript.SIZE / 2:
				top_left += 1
			elif x >= MarkPaintScript.SIZE / 2 and y >= MarkPaintScript.SIZE / 2:
				bottom_right += 1
	assert_gt(top_left, bottom_right * 2,
		"the probe must be top heavy and left heavy, or it cannot show a flip or a mirror")
