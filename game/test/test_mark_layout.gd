extends GutTest
## A CUTIE MARK MADE OF STAMPS (PS7, playtest 2026-11-05 item 3: "Better cutie mark creation").
## Up to three symbols, from the 24 talents and 8 Equestrian symbols, each placed, sized, turned and
## coloured; composed into the mark image the flank wears. The pure half: no canvas, no mouse.

const LayoutScript := preload("res://systems/mark_layout.gd")
const ComposerScript := preload("res://systems/mark_composer.gd")

const RED := Color(0.9, 0.2, 0.25)
const BLUE := Color(0.2, 0.35, 0.9)


func _filled(img: Image) -> Array:
	# [count of opaque pixels, their centroid]
	var n := 0
	var sum := Vector2.ZERO
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
				sum += Vector2(x, y)
	return [n, sum / maxf(1.0, float(n))]


func test_there_are_thirty_two_symbols_and_each_draws() -> void:
	var kinds: Array = LayoutScript.kinds()
	assert_eq(kinds.size(), 32, "24 talents and 8 Equestrian symbols")
	for k: StringName in kinds:
		var img: Image = LayoutScript.compose([LayoutScript.new_stamp(k, RED, BLUE)], 64)
		assert_gt(int(_filled(img)[0]), 60, "%s draws something" % k)


func test_a_stamp_at_the_centre_draws_there_and_leaves_the_corners_clear() -> void:
	var img: Image = LayoutScript.compose([LayoutScript.new_stamp(&"shape:circle", RED, BLUE)], 64)
	assert_gt(img.get_pixel(32, 32).a, 0.5)
	assert_eq(img.get_pixel(1, 1).a, 0.0)
	var f: Array = _filled(img)
	assert_almost_eq((f[1] as Vector2).x, 31.5, 1.0)


func test_moving_scaling_turning_and_recolouring_a_stamp() -> void:
	var s: Dictionary = LayoutScript.new_stamp(&"shape:triangle", RED, BLUE)
	var base: Array = _filled(LayoutScript.compose([s], 64))
	var moved := s.duplicate()
	moved.at = Vector2(0.3, 0.7)
	var mv: Array = _filled(LayoutScript.compose([moved], 64))
	assert_lt((mv[1] as Vector2).x, (base[1] as Vector2).x - 8.0, "moved left")
	assert_gt((mv[1] as Vector2).y, (base[1] as Vector2).y + 8.0, "and down")
	var big := s.duplicate()
	big.scale = float(s.scale) * 1.5
	assert_almost_eq(float(_filled(LayoutScript.compose([big], 64))[0]) / float(base[0]), 2.25, 0.4,
		"one and a half times as big covers about twice the area")
	var turned := s.duplicate()
	turned.rot = PI
	var tn: Array = _filled(LayoutScript.compose([turned], 64))
	assert_almost_eq(float(tn[0]), float(base[0]), float(base[0]) * 0.1, "turning keeps its size")
	assert_gt(absf((tn[1] as Vector2).y - (base[1] as Vector2).y), 1.5, "a triangle upside down sits differently")
	var blue := s.duplicate()
	blue.a = BLUE
	var px: Color = LayoutScript.compose([blue], 64).get_pixel(32, 36)
	assert_gt(px.b, px.r, "recoloured")


func test_at_most_three_and_the_top_one_is_hit_first() -> void:
	var stamps: Array = []
	for i in 4:
		stamps = LayoutScript.added(stamps, LayoutScript.new_stamp(&"shape:square", RED, BLUE))
	assert_eq(stamps.size(), LayoutScript.MAX_STAMPS)
	assert_eq(LayoutScript.hit(stamps, Vector2(0.5, 0.5)), 2, "the last one laid is on top")
	assert_eq(LayoutScript.hit(stamps, Vector2(0.02, 0.02)), -1, "nothing in the corner")


## Fable AAA round 3, #6: the gallery is Equestrian and coloured. No plain geometry on offer
## (the old ring with its small ring read as a gender symbol), and every symbol offered has
## colours of its own.
func test_the_offered_symbols_are_equestrian_and_coloured() -> void:
	for s: StringName in [&"circle", &"square", &"cross", &"ring", &"triangle", &"diamond"]:
		assert_does_not_have(LayoutScript.SHAPES, s)
	var seen := {}
	for k: StringName in LayoutScript.kinds():
		var parts: Array = LayoutScript.parts(k)
		assert_ne(String(parts[0]), "ring", "%s is not the ring" % k)
		assert_true(ComposerScript.PALETTE.has(String(parts[0])), "%s has its own colours" % k)
		seen[(LayoutScript.palette(k)[0] as Color).to_html()] = true
	assert_gt(seen.size(), 12, "and they are not all one colour")
