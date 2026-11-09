class_name IconSet
extends RefCounted
## THE ONE ICON SET (P8 S5; docs/aaa-review-2026-11-08.md section 3). Every icon in the game is
## an SVG drawn by tools/make_icons.py in one style, rasterised here at the size it is shown,
## so a 32 px compass marker and a 128 px sign are both crisp. The raw .svg files ship with the
## game (export_presets.cfg include_filter) because Godot's importer would bake one size.
##
## `name` is the file's base name (coin, crate, fence, ...); `plate` false takes the plate-less
## variant for places that draw their own backing.

const DIR := "res://assets/ui/icons/"

static var _cache := {}


static func texture(name: String, px: int = 64, plate: bool = true) -> ImageTexture:
	var key := "%s/%d/%s" % [name, px, plate]
	if _cache.has(key):
		return _cache[key]
	var file := DIR + name + ("" if plate else "_bare") + ".svg"
	var src := FileAccess.get_file_as_string(file)
	var img := Image.new()
	if src.is_empty() or img.load_svg_from_string(src, px / 64.0) != OK:
		push_warning("IconSet: no icon %s" % file)
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
	# Mipmapped, so a world sprite drawn smaller than its size (the news bubble) filters smoothly.
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func has(name: String) -> bool:
	return FileAccess.file_exists(DIR + name + ".svg")


## Draw icon `name` (plate-less) into `rect` on `ci`, square and centred, rasterised at twice
## its drawn size in 16 px steps so it stays crisp under the UI scale. False if the set lacks it.
static func draw(ci: CanvasItem, name: String, rect: Rect2) -> bool:
	if not has(name):
		return false
	var side: float = minf(rect.size.x, rect.size.y)
	var px := clampi(int(ceil(side * 2.0 / 16.0)) * 16, 32, 256)
	ci.draw_texture_rect(texture(name, px, false),
		Rect2(rect.position + (rect.size - Vector2(side, side)) * 0.5, Vector2(side, side)), false)
	return true
