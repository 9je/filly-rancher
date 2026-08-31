extends GutTest

const MarkStampsScript := preload("res://systems/mark_stamps.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")


func test_every_stamp_draws_something_and_is_the_canvas_size() -> void:
	for id: int in MarkStampsScript.ids():
		var image: Image = MarkStampsScript.build(id, Color.RED)
		assert_eq(image.get_width(), MarkPaintScript.SIZE, "stamp %d" % id)
		assert_false(MarkPaintScript.is_blank(image), "stamp %d drew nothing" % id)


func test_every_stamp_has_a_name_with_no_dash_in_it() -> void:
	for id: int in MarkStampsScript.ids():
		var text: String = MarkStampsScript.stamp_name(id)
		assert_false(text.is_empty())
		assert_false(text.contains("--"))
		assert_false(text.contains(char(0x2014)))


func test_a_stamp_is_drawn_in_the_colour_it_is_asked_for() -> void:
	var image: Image = MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.BLUE)
	var found := false
	for y in MarkPaintScript.SIZE:
		for x in MarkPaintScript.SIZE:
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0:
				assert_eq(pixel, Color.BLUE)
				found = true
	assert_true(found)


func test_stamps_differ_from_one_another() -> void:
	var star: Image = MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.RED)
	var heart: Image = MarkStampsScript.build(MarkStampsScript.Stamp.HEART, Color.RED)
	assert_false(MarkPaintScript.equal(star, heart))


func test_an_unknown_stamp_answers_a_blank_canvas_rather_than_crashing() -> void:
	assert_true(MarkPaintScript.is_blank(MarkStampsScript.build(99, Color.RED)))
