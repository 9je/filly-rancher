class_name StyleIconTint
extends RefCounted
## THE CREATOR'S PICTURE CARDS IN HER OWN COLOURS (Fable AAA round 2: "the option thumbnails
## on Markings, Eye shape and Wear show a brown pony rather than the player's colours").
## game/scenes/test/style_icons.gd bakes each card on a pony with two key colours, a ginger
## coat and a green mane, tail and second mane colour, that nothing else on a card uses; this
## swaps each key for her pick, keeping the bake's light and shade (the key's brightness at
## each pixel scales her colour), and leaves the eyes, the markings, the worn pieces and the
## paper behind alone.
##
## Static only. Preload by path.

const KEY_COAT := Color(0.55, 0.36, 0.24)
const KEY_MANE := Color(0.22, 0.78, 0.30)
## How far in hue (0..1 round the wheel) a pixel may sit from a key and still be that key,
## fully inside HUE_IN and fading out to HUE_OUT; and how grey it may be (saturation floor).
const COAT_HUE_IN := 0.025
const COAT_HUE_OUT := 0.05
const MANE_HUE_IN := 0.06
const MANE_HUE_OUT := 0.11
const SAT_FLOOR := 0.28

static var _cache := {}


## `source` recoloured for `coat` and `mane`; cached per picture and pair of colours.
static func tinted(source: Texture2D, coat: Color, mane: Color) -> Texture2D:
	if source == null:
		return null
	var key := "%s|%s|%s" % [source.resource_path, coat.to_html(false), mane.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var img := source.get_image()
	if img == null:
		return source
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	recolour(img, coat, mane)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Recolour `img` in place.
static func recolour(img: Image, coat: Color, mane: Color) -> void:
	var coat_v := KEY_COAT.v
	var mane_v := KEY_MANE.v
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.02 or c.s < SAT_FLOOR * 0.6:
				continue
			var wc := _weight(c, KEY_COAT.h, COAT_HUE_IN, COAT_HUE_OUT)
			var wm := _weight(c, KEY_MANE.h, MANE_HUE_IN, MANE_HUE_OUT)
			if wc <= 0.0 and wm <= 0.0:
				continue
			var target := coat if wc >= wm else mane
			var w := maxf(wc, wm)
			var shade := clampf(c.v / (coat_v if wc >= wm else mane_v), 0.0, 1.6)
			var lit := Color(target.r * shade, target.g * shade, target.b * shade, c.a)
			# Light parts of a pale coat must not blow out to white blocks: past the key's own
			# brightness the shade lifts her colour toward white instead of multiplying it.
			if shade > 1.0:
				lit = target.lerp(Color(1, 1, 1), (shade - 1.0) * 0.5)
				lit.a = c.a
			img.set_pixel(x, y, c.lerp(lit, w))


static func _weight(c: Color, hue: float, inner: float, outer: float) -> float:
	var d := absf(c.h - hue)
	d = minf(d, 1.0 - d)
	var by_hue := 1.0 - clampf((d - inner) / (outer - inner), 0.0, 1.0)
	var by_sat := clampf((c.s - SAT_FLOOR * 0.6) / (SAT_FLOOR * 0.4), 0.0, 1.0)
	return by_hue * by_sat
