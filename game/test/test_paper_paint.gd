extends GutTest
## THE STATIONERY KIT. Every shape is a pure *_points() function with a three line draw_*
## half, the same split game/ui/casino_paint.gd is built on and for the same reason: drawn
## art is only testable headlessly if the geometry can be asked for without a canvas.

const PaperPaintScript := preload("res://ui/paper_paint.gd")

const BOX := Rect2(0.0, 0.0, 100.0, 60.0)


func test_the_company_mark_is_a_closed_cloud_inside_its_box() -> void:
	var points: PackedVector2Array = PaperPaintScript.logo_points(BOX)
	assert_gt(points.size(), 8, "a cloud is not a triangle")
	for p: Vector2 in points:
		assert_true(BOX.has_point(p), "the mark stays inside the box it was handed: %s" % p)


func test_the_bolt_is_a_polygon_inside_its_box() -> void:
	var points: PackedVector2Array = PaperPaintScript.bolt_points(BOX)
	assert_gte(points.size(), 6)
	for p: Vector2 in points:
		assert_true(BOX.has_point(p))


func test_the_mark_scales_with_its_box_rather_than_assuming_one() -> void:
	var small: PackedVector2Array = PaperPaintScript.logo_points(Rect2(0, 0, 10, 6))
	var large: PackedVector2Array = PaperPaintScript.logo_points(Rect2(0, 0, 100, 60))
	assert_eq(small.size(), large.size())
	for i in small.size():
		assert_almost_eq(large[i].x, small[i].x * 10.0, 0.001)
		assert_almost_eq(large[i].y, small[i].y * 10.0, 0.001)


func test_the_palette_reads_as_paper_and_not_as_felt() -> void:
	assert_gt(PaperPaintScript.PAPER.get_luminance(), 0.7, "paper is pale")
	assert_lt(PaperPaintScript.INK.get_luminance(), 0.2, "ink is dark")
	assert_gt(PaperPaintScript.PAPER.a, 0.9, "a letter is opaque; the panel behind it is not")


func test_nothing_in_the_kit_rolls_anything() -> void:
	var source: String = FileAccess.get_file_as_string("res://ui/paper_paint.gd")
	assert_false(source.contains("RandomNumberGenerator"), "no RNG under game/ui/")
	assert_false(source.contains("randi"), "no RNG under game/ui/")
	assert_false(source.contains("randf"), "no RNG under game/ui/")


func test_no_line_of_the_kit_carries_a_dash() -> void:
	var source: String = FileAccess.get_file_as_string("res://ui/paper_paint.gd")
	for line in source.split("\n"):
		var text: String = String(line)
		if text.begins_with("# ---") or text.begins_with("## ---"):
			continue
		assert_false(text.contains("--"), "double hyphen: %s" % text)
		assert_false(text.contains(char(0x2014)), "em dash: %s" % text)
