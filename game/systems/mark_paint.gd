class_name MarkPaint
extends RefCounted
## THE PIXELS UNDER THE CUTIE MARK CANVAS. Every operation the painting widget performs,
## as static functions on a plain Image, so the whole of "does the brush work" is GUT
## testable in milliseconds without a Control, a mouse or a viewport
## (game/test/test_mark_paint.gd). game/ui/mark_canvas.gd is the widget; it owns the undo
## stack, the tool state and the input, and it does no pixel arithmetic of its own.
##
## SIXTY FOUR SQUARE, RGBA8, TRANSPARENT WHERE SHE HAS NOT PAINTED. Small enough that the
## whole drawing is a few kilobytes of PNG inside one JSON save
## (game/systems/player_look.gd), large enough to draw a recognisable apple. Transparency is
## load bearing rather than cosmetic: the mark is projected onto the coat as a decal, and
## the coat has to show through everywhere she did not draw.
##
## EVERY WRITE IS CLIPPED. A brush half off the edge paints the half that is on it; a brush
## entirely off the canvas paints nothing. Nothing here ever wraps, because a stroke that
## reappeared on the far side would be a drawing tool that lies about where the ink went.

const SIZE := 64
const FORMAT := Image.FORMAT_RGBA8

## Brush radii, in pixels, that the widget offers. A radius of 0 is one pixel.
const BRUSHES: Array[int] = [1, 2, 4, 8]

## Fully transparent, which is also "she has not drawn anything yet".
const EMPTY := Color(0.0, 0.0, 0.0, 0.0)


static func blank() -> Image:
	var image: Image = Image.create_empty(SIZE, SIZE, false, FORMAT)
	image.fill(EMPTY)
	return image


static func copy_of(image: Image) -> Image:
	if image == null:
		return blank()
	return Image.create_from_data(image.get_width(), image.get_height(), false,
		image.get_format(), image.get_data())


static func clear(image: Image) -> void:
	if image != null:
		image.fill(EMPTY)


## A filled square brush of half width `radius`. SQUARE RATHER THAN ROUND on purpose: at
## these radii a circle is a lumpy square anyway, and a square brush makes a hand drawn
## sixty four pixel mark read as pixel art rather than as a failed attempt at smooth.
static func dot(image: Image, at: Vector2i, colour: Color, radius: int) -> void:
	if image == null:
		return
	var r: int = maxi(0, radius)
	for y in range(at.y - r, at.y + r + 1):
		if y < 0 or y >= image.get_height():
			continue
		for x in range(at.x - r, at.x + r + 1):
			if x < 0 or x >= image.get_width():
				continue
			image.set_pixel(x, y, colour)


## A line of dots from `from` to `to`, stepped one pixel at a time along the longer axis, so
## a fast drag leaves a stroke rather than two dots with a hole between them.
static func stroke(image: Image, from: Vector2i, to: Vector2i, colour: Color,
		radius: int) -> void:
	if image == null:
		return
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	if steps <= 0:
		dot(image, from, colour, radius)
		return
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		dot(image, Vector2i(
			int(round(lerpf(float(from.x), float(to.x), t))),
			int(round(lerpf(float(from.y), float(to.y), t)))), colour, radius)


static func is_blank(image: Image) -> bool:
	if image == null:
		return true
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				return false
	return true


## Pixel for pixel, which is what "round trips pixel identical" means in the save test.
## Compares the raw buffers rather than pixel by pixel: a PNG round trip preserves bytes,
## and a byte comparison is the strongest statement available.
static func equal(a: Image, b: Image) -> bool:
	if a == null or b == null:
		return false
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return false
	if a.get_format() != b.get_format():
		return false
	return a.get_data() == b.get_data()
