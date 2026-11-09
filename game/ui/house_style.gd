extends RefCounted
## THE HOUSE STYLE, OUT OF THE PALACE AND ONTO EVERY SCREEN (Fable AAA review round 1,
## 2026-11-09: "the casino tables are the house style for every menu"). The tables were the one
## part of the 2D the reviewer and the owner both liked: one plum, gold and felt palette, chips
## you can read at a glance, painted panels. game/ui/casino_paint.gd owns the felt's own
## vocabulary; this file lends the same palette and the same three surfaces to the HUD, the
## title, the letters and the counters in town, so they read as one family:
##
##   PILL   plum, a gold hairline, a soft drop. Everything on the HUD that floats over the world.
##   PLATE  the felt, framed in dim gold: a reading surface (rules, quotas, notes).
##   KEY    a cream keycap with a plum lip: a control drawn, never typed ("E: talk" is a glyph).
##
## Static only, preloaded by path (no class_name: the global class cache is not rebuilt by a
## headless checkout, and every caller already preloads its helpers).

const PaintScript := preload("res://ui/casino_paint.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

const PLUM := PaintScript.PLUM
const PLUM_DARK := PaintScript.PLUM_DARK
const GOLD := PaintScript.GOLD
const GOLD_DIM := PaintScript.GOLD_DIM
const FELT := PaintScript.FELT
const FELT_DARK := PaintScript.FELT_DARK
## The words on a plum surface: warm cream, never pure white.
const CREAM := Color(1.0, 0.96, 0.86)
const CREAM_DIM := Color(1.0, 0.96, 0.86, 0.7)
## The ink on a cream surface (a keycap, a disc): the darkest plum.
const INK := Color(0.2, 0.09, 0.24)
const KEY_FACE := Color(1.0, 0.97, 0.9)
const KEY_LIP := Color(0.55, 0.42, 0.6)
const TICK_GREEN := Color(0.42, 0.78, 0.42)


## THE PILL: the HUD's one surface. `alpha` lets a quiet piece (the compass) sit lighter than
## a loud one (a toast).
static func pill_box(radius := 22, alpha := 0.9, margin := Vector2(18, 8)) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(PLUM_DARK, alpha)
	b.border_color = Color(GOLD_DIM, minf(1.0, alpha + 0.1))
	b.set_border_width_all(2)
	b.set_corner_radius_all(radius)
	b.content_margin_left = margin.x
	b.content_margin_right = margin.x
	b.content_margin_top = margin.y
	b.content_margin_bottom = margin.y
	b.shadow_color = Color(0.05, 0.0, 0.08, 0.35 * alpha)
	b.shadow_size = 8
	b.shadow_offset = Vector2(0, 4)
	b.anti_aliasing = true
	return b


## THE PLATE: dark felt in a dim gold frame, the race card's and the rules' surface.
static func plate_box(radius := 14, margin := 16.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(FELT_DARK, 0.94)
	b.border_color = GOLD_DIM
	b.set_border_width_all(2)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	b.anti_aliasing = true
	return b


## A gold-ringed disc carrying a picture, `size` across: the casino's chip, as a frame.
static func disc_box(size: float, fill: Color = PLUM, ring: Color = GOLD, ring_width := 3) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = ring
	b.set_border_width_all(ring_width)
	b.set_corner_radius_all(int(size * 0.5) + 2)
	b.anti_aliasing = true
	return b


## Dress `label` for a plum surface: cream (or `colour`), the display face, no outline.
static func ink_label(label: Label, size: int, colour: Color = CREAM, display := true) -> void:
	MenuStyleScript.style_label(label, size, colour)
	label.add_theme_constant_override(&"outline_size", 0)
	if display:
		label.add_theme_font_override(&"font", MenuStyleScript.title_font())


## A number that has to be read across the room (bits, counts): gold numerals with a plum
## outline thick enough to stand on grass or sky.
static func numeral_label(label: Label, size: int, colour: Color = GOLD) -> void:
	MenuStyleScript.style_label(label, size, colour)
	label.add_theme_font_override(&"font", MenuStyleScript.numeral_font())
	label.add_theme_constant_override(&"outline_size", 8)
	label.add_theme_color_override(&"font_outline_color", PLUM_DARK)


# --- the key glyph -------------------------------------------------------------------------

## THE MOUSE BUTTONS ARE DRAWN AS A MOUSE. "Right Mouse" in a keycap is still typed text; a
## mouse with its right button lit is the glyph every PC game teaches with.
const MOUSE_KEYS := {"Right Mouse": 1, "Left Click": -1, "Middle Mouse": 0}


## Whether `key` is drawn as a mouse rather than a keycap.
static func is_mouse_key(key: String) -> bool:
	return MOUSE_KEYS.has(key)


## The width the glyph for `key` takes at height `h`.
static func glyph_width(key: String, h: float, font: Font = null) -> float:
	if is_mouse_key(key):
		return h * 0.8
	var f: Font = font if font != null else MenuStyleScript.title_font()
	var px := int(h * 0.5)
	return maxf(h, f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + h * 0.55)


## Draw the glyph for `key` into `rect` on `ci`: a mouse for a mouse button, a keycap for
## anything else. The keycap is a cream face standing on a plum lip, so it reads as a thing
## you press.
static func draw_glyph(ci: CanvasItem, rect: Rect2, key: String) -> void:
	if is_mouse_key(key):
		_draw_mouse(ci, rect, int(MOUSE_KEYS[key]))
		return
	var lip := 0.14 * rect.size.y
	var body := Rect2(rect.position, Vector2(rect.size.x, rect.size.y - lip))
	PaintScript.rounded(ci, Rect2(rect.position + Vector2(0, lip), body.size), rect.size.y * 0.24,
		KEY_LIP, PLUM_DARK, 2.0)
	PaintScript.rounded(ci, body, rect.size.y * 0.24, KEY_FACE, PLUM_DARK, 2.0)
	var font := MenuStyleScript.title_font()
	PaintScript.label(ci, font, body.grow(-3.0), key, int(rect.size.y * 0.5), INK)


## A mouse, its `button` lit gold: -1 the left, 1 the right, 0 the wheel.
static func _draw_mouse(ci: CanvasItem, rect: Rect2, button: int) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var body := Rect2(rect.position + Vector2(w * 0.08, 0), Vector2(w * 0.84, h))
	PaintScript.rounded(ci, body, w * 0.42, KEY_FACE, PLUM_DARK, 2.0)
	var mid_x := body.position.x + body.size.x * 0.5
	var split_y := body.position.y + h * 0.44
	# The lit button: a gold quarter of the body above the split.
	if button != 0:
		var left := button < 0
		var r := body.size.x * 0.5
		var c := Vector2(mid_x, body.position.y + r)
		var steps := 10
		# The button's quarter of the dome, closed along the split.
		var poly := PackedVector2Array()
		if left:
			poly.append(Vector2(c.x - r + 2.0, split_y))
			for i in steps + 1:
				var a := lerpf(PI, PI * 1.5, float(i) / steps)
				poly.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
			poly.append(Vector2(mid_x, split_y))
		else:
			poly.append(Vector2(mid_x, split_y))
			for i in steps + 1:
				var a := lerpf(PI * 1.5, TAU, float(i) / steps)
				poly.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
			poly.append(Vector2(c.x + r - 2.0, split_y))
		ci.draw_colored_polygon(poly, GOLD)
	ci.draw_line(Vector2(body.position.x + 2.0, split_y), Vector2(body.end.x - 2.0, split_y),
		PLUM_DARK, 2.0, true)
	ci.draw_line(Vector2(mid_x, body.position.y + 2.0), Vector2(mid_x, split_y), PLUM_DARK, 2.0, true)
	# The wheel.
	var wheel := Rect2(Vector2(mid_x - w * 0.07, body.position.y + h * 0.13), Vector2(w * 0.14, h * 0.2))
	PaintScript.rounded(ci, wheel, w * 0.07, GOLD if button == 0 else KEY_LIP, PLUM_DARK, 1.5)


## A control that draws one key glyph, sized to its key. `key` is what InputDevice.hint()
## names ("E", "Right Mouse", "X").
class KeyGlyph extends Control:
	const HouseStyleScript := preload("res://ui/house_style.gd")
	var key := "":
		set(value):
			key = value
			_resize()
	var glyph_height := 34.0:
		set(value):
			glyph_height = value
			_resize()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _resize() -> void:
		custom_minimum_size = Vector2(HouseStyleScript.glyph_width(key, glyph_height), glyph_height)
		size = custom_minimum_size
		queue_redraw()

	func _draw() -> void:
		if key.is_empty():
			return
		HouseStyleScript.draw_glyph(self, Rect2(Vector2.ZERO, custom_minimum_size), key)


## A LINE WITH A KEY IN IT: `text` split round the first appearance of any of `keys` (as a
## whole word), as [before, key, after]. No key found answers [text, "", ""]. Pure, so the
## suite can ask it what a tip will draw.
static func split_on_key(text: String, keys: Array) -> Array:
	var best := -1
	var best_key := ""
	for k in keys:
		var key := String(k)
		if key.is_empty():
			continue
		var at := 0
		while true:
			var i := text.find(key, at)
			if i < 0:
				break
			var before_ok := i == 0 or text[i - 1] == " "
			var end := i + key.length()
			var after_ok := end >= text.length() or text[end] in [" ", ":", ",", "."]
			if before_ok and after_ok:
				if best < 0 or i < best:
					best = i
					best_key = key
				break
			at = i + 1
	if best < 0:
		return [text, "", ""]
	var after := text.substr(best + best_key.length())
	if after.begins_with(":"):
		after = after.substr(1)
	return [text.substr(0, best).strip_edges(), best_key, after.strip_edges()]


## Build (or rebuild) the children of `row` (an HBoxContainer) to draw `parts` from
## split_on_key(): words, a glyph, words. The first word after a leading glyph is capitalised
## ("E: talk to Tumble" draws as [E] Talk to Tumble).
static func fill_glyph_row(row: HBoxContainer, parts: Array, size: int, colour: Color = CREAM,
		glyph_h := 34.0) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var before := String(parts[0])
	var key := String(parts[1])
	var after := String(parts[2])
	if key.is_empty():
		row.add_child(_word(before, size, colour))
		return
	if before.is_empty() and not after.is_empty():
		after = after[0].to_upper() + after.substr(1)
	if not before.is_empty():
		row.add_child(_word(before, size, colour))
	var g := KeyGlyph.new()
	g.glyph_height = glyph_h
	g.key = key
	row.add_child(g)
	if not after.is_empty():
		row.add_child(_word(after, size, colour))


static func _word(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ink_label(l, size, colour)
	return l
