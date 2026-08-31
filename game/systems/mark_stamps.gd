class_name MarkStamps
extends RefCounted
## SOMETHING TO START FROM. Six shapes the creation screen offers as a starting point for a
## cutie mark, so a player who does not want to draw one from nothing still gets a mark she
## chose. Applied as a whole canvas, and undoable like any other stroke.
##
## DRAWN IN CODE, NOT SHIPPED AS PNGs. game/assets/converted/ is gitignored and regenerated
## per machine (docs/ci.md section 4), and a stamp sheet living there would be a creation
## screen that works on the author's machine and shows six blank buttons on a fresh clone.
## Each shape below is an implicit function evaluated per pixel, which is a dozen lines and
## no asset at all.
##
## Static only, no scene, and every shape is a pure function of (id, colour), so
## game/test/test_mark_stamps.gd can assert on the pixels.

enum Stamp { STAR, HEART, APPLE, CLOUD, FLOWER, GEM }

const NAMES: Array[String] = ["Star", "Heart", "Apple", "Cloud", "Flower", "Gem"]

const MarkPaintScript := preload("res://systems/mark_paint.gd")


static func ids() -> Array[int]:
	return [Stamp.STAR, Stamp.HEART, Stamp.APPLE, Stamp.CLOUD, Stamp.FLOWER, Stamp.GEM]


static func stamp_name(id: int) -> String:
	if id < 0 or id >= NAMES.size():
		return ""
	return NAMES[id]


## The stamp, drawn in `colour` on a transparent canvas. An unknown id answers a BLANK
## canvas rather than erroring: a stamp row that grew a button the shapes do not cover
## should produce an empty mark the player can see is empty, not a crash.
static func build(id: int, colour: Color) -> Image:
	var image: Image = MarkPaintScript.blank()
	if not id in ids():
		return image
	var half: float = float(MarkPaintScript.SIZE) * 0.5
	for py in MarkPaintScript.SIZE:
		for px in MarkPaintScript.SIZE:
			# Centred coordinates in [-1, 1], with +y UP, which is how the shapes below are
			# written; the image's own y runs downward.
			var x: float = (float(px) + 0.5 - half) / half
			var y: float = (half - float(py) - 0.5) / half
			if _inside(id, x, y):
				image.set_pixel(px, py, colour)
	return image


static func _inside(id: int, x: float, y: float) -> bool:
	match id:
		Stamp.STAR:
			return _star(x, y)
		Stamp.HEART:
			# The standard implicit heart, scaled to fill the canvas.
			var hx: float = x * 1.25
			var hy: float = y * 1.25 - 0.15
			var t: float = hx * hx + hy * hy - 0.42
			return t * t * t - hx * hx * hy * hy * hy <= 0.0
		Stamp.APPLE:
			# A round body with a bite out of the left and a stalk on top.
			var body: bool = (x * x) / 0.52 + ((y + 0.08) * (y + 0.08)) / 0.60 <= 1.0
			var stalk: bool = absf(x) <= 0.06 and y > 0.62 and y < 0.92
			var bite: bool = (x + 0.66) * (x + 0.66) + (y - 0.05) * (y - 0.05) <= 0.10
			return (body and not bite) or stalk
		Stamp.CLOUD:
			# Three overlapping discs on a flat base.
			if y < -0.42 or y > 0.55:
				return false
			var a: bool = (x + 0.36) * (x + 0.36) + (y + 0.10) * (y + 0.10) <= 0.13
			var b: bool = x * x + (y - 0.12) * (y - 0.12) <= 0.20
			var c: bool = (x - 0.38) * (x - 0.38) + (y + 0.06) * (y + 0.06) <= 0.15
			var base: bool = absf(x) <= 0.72 and y <= -0.10 and y >= -0.42
			return a or b or c or base
		Stamp.FLOWER:
			# Five petals on a polar rose, plus a centre.
			var r: float = sqrt(x * x + y * y)
			if r <= 0.16:
				return true
			return r <= 0.30 + 0.55 * absf(cos(2.5 * atan2(y, x)))
		Stamp.GEM:
			# A cut stone: a wide table over a point.
			if y > 0.30:
				return absf(x) <= 0.62 and y <= 0.62
			return absf(x) <= 0.62 * (1.0 - (0.30 - y) / 1.15) and y >= -0.85
	return false


## A five pointed star, as a polar radius test.
static func _star(x: float, y: float) -> bool:
	var r: float = sqrt(x * x + y * y)
	if r <= 0.001:
		return true
	var angle: float = atan2(y, x) - PI * 0.5
	var spoke: float = fposmod(angle, TAU / 5.0) - PI / 5.0
	# 0.38 is the inner radius and 0.92 the outer one, so the star fills the canvas without
	# clipping its points on the corners.
	return r <= 0.38 + (0.92 - 0.38) * (1.0 - absf(spoke) / (PI / 5.0))
