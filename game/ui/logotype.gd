extends Control
## THE GAME'S NAME, DRAWN (Fable AAA review round 1, #9: "no logotype"). The title used to be a
## Label in the menu's heading size. A logotype is a piece of art: big display type stacked on
## two lines and a lucky horseshoe with a star riding in it beside "Filly", the way the show's
## own title cards dress a name. Drawn from the project's own face (Fredoka) and polygons: no
## image asset.
##
## THE NAME IS AN OBJECT, NOT INK (Fable AAA round 6: "the logo is flat, no outline or depth,
## on a flat plum sky"). Its plum outline vanished into the dusk behind it, so each word is now
## built like a sticker on a toy box, back to front: a soft drop shadow; a cream rim round the
## whole silhouette, which is what makes it stand off a dark sky; the plum outline; a solid
## extruded side under the letters (the depth); then the face, a lit edge along the top and
## left of every letter, a shade toward the foot of each line and a gloss band across the top,
## all clipped to the letters (`Face` draws them, clip_children); last a star catch-light
## glinting on the F and on the R.
##
## Shared by the title screen and the loading screen, so the name looks the same in both.

const PaintScript := preload("res://ui/casino_paint.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

const PLUM_DARK := Color(0.2, 0.07, 0.24)
const GOLD := Color(0.99, 0.84, 0.36)
const GOLD_DEEP := Color(0.86, 0.6, 0.16)
const CREAM := Color(1.0, 0.96, 0.88)
const RIM := Color(1.0, 0.95, 0.84)
const PINK := Color(0.98, 0.62, 0.84)

## The size the art is authored at; `scale_to` draws it at any width.
const BASE := Vector2(700, 300)
const LINE_PX := 124
## How deep the letters are extruded, in authored pixels, and in how many slices.
const DEPTH := 11.0
const DEPTH_STEPS := 8

## Each line: its word, its baseline, its face colour, its lit edge, its side (the extrusion).
const LINES := [
	{"word": "Filly", "at": Vector2(18, LINE_PX * 0.98), "face": CREAM,
		"lit": Color(1, 1, 1), "side": Color(0.78, 0.55, 0.42)},
	{"word": "Rancher", "at": Vector2(70, LINE_PX * 1.98), "face": GOLD,
		"lit": Color(1.0, 0.95, 0.7), "side": Color(0.72, 0.38, 0.12)},
]

var _t := 0.0
var _font: FontVariation
var _face: Control
var _shading: Control
var _glints: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BASE


func _ready() -> void:
	_font = FontVariation.new()
	_font.base_font = MenuStyleScript.title_font().base_font
	# Heavier than the menus' titles: the name is the loudest word in the game.
	_font.variation_opentype = {2003265652: 700}
	_font.spacing_glyph = 2
	# The face and what is clipped to it, then the glints over everything.
	_face = _layer("Face")
	_face.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_face.draw.connect(_draw_face)
	add_child(_face)
	_shading = _layer("Shading")
	_shading.draw.connect(_draw_shading)
	_face.add_child(_shading)
	_glints = _layer("Glints")
	_glints.draw.connect(_draw_glints)
	add_child(_glints)


func _layer(n: String) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _glints != null:
		_glints.queue_redraw()


## The authored art's transform into this control's rect, on `ci`.
func _fit(ci: CanvasItem) -> void:
	var k := minf(size.x / BASE.x, size.y / BASE.y)
	ci.draw_set_transform(Vector2((size.x - BASE.x * k) * 0.5, 0.0), 0.0, Vector2(k, k))


## The back of each word: shadow, cream rim, plum outline, the extruded side.
func _draw() -> void:
	if _font == null:
		return
	_fit(self)
	var px := LINE_PX
	for line: Dictionary in LINES:
		var at: Vector2 = line.at
		var word: String = line.word
		draw_string_outline(_font, at + Vector2(3, DEPTH + px * 0.08), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.36), Color(0.05, 0.02, 0.08, 0.5))
		draw_string_outline(_font, at + Vector2(0, DEPTH * 0.5), word, HORIZONTAL_ALIGNMENT_LEFT,
			-1, px, int(px * 0.36), RIM)
		draw_string_outline(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.36),
			RIM)
		draw_string_outline(_font, at + Vector2(0, DEPTH), word, HORIZONTAL_ALIGNMENT_LEFT, -1,
			px, int(px * 0.2), PLUM_DARK)
		draw_string_outline(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.2),
			PLUM_DARK)
		# The side: the letters stacked down DEPTH, darkest at the back.
		var side: Color = line.side
		for i in range(DEPTH_STEPS, 0, -1):
			var f := float(i) / float(DEPTH_STEPS)
			var c := side.darkened(0.25 * f)
			draw_string(_font, at + Vector2(0, DEPTH * f), word, HORIZONTAL_ALIGNMENT_LEFT, -1,
				px, c)
			draw_string_outline(_font, at + Vector2(0, DEPTH * f), word,
				HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.03), c)
	var filly_w := _font.get_string_size("Filly", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_horseshoe(Vector2(18.0 + filly_w + 92.0, px * 0.6), 54.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The front of each word in its lit colour: the mask everything in Shading is clipped to.
func _draw_face() -> void:
	if _font == null:
		return
	_fit(_face)
	for line: Dictionary in LINES:
		_face.draw_string(_font, line.at, line.word, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX,
			line.lit)
	_face.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Inside the letters: the face colour laid over the lit colour a few pixels down and right,
## so a lit edge is left along every letter's top and left (the bevel); a shade rising from
## the foot of each line; a gloss band across the top.
func _draw_shading() -> void:
	if _font == null:
		return
	_fit(_shading)
	var px := LINE_PX
	var ascent := _font.get_ascent(px)
	for line: Dictionary in LINES:
		var at: Vector2 = line.at
		var face: Color = line.face
		_shading.draw_string(_font, at + Vector2(2.5, 4.0), line.word, HORIZONTAL_ALIGNMENT_LEFT,
			-1, px, face)
		var w := _font.get_string_size(line.word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var top := at.y - ascent * 0.8
		var foot := at.y + px * 0.25
		var shade := Color(line.side, 0.0)
		var deep := Color(line.side, 0.55)
		_shading.draw_polygon(PackedVector2Array([Vector2(at.x - 10, top + (foot - top) * 0.45),
			Vector2(at.x + w + 10, top + (foot - top) * 0.45), Vector2(at.x + w + 10, foot),
			Vector2(at.x - 10, foot)]), PackedColorArray([shade, shade, deep, deep]))
		# The gloss: a soft band over the upper letters, its lower edge a gentle curve.
		var gloss := PackedVector2Array()
		var g_top := top - 6.0
		var g_mid := top + (at.y - top) * 0.42
		var n := 16
		gloss.append(Vector2(at.x - 10, g_top))
		gloss.append(Vector2(at.x + w + 10, g_top))
		for i in n + 1:
			var x := at.x + w + 10 - (w + 20) * float(i) / float(n)
			gloss.append(Vector2(x, g_mid + sin(float(i) / float(n) * PI) * 6.0))
		_shading.draw_colored_polygon(gloss, Color(1, 1, 1, 0.28))
	_shading.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The catch-lights: a four point star glinting on the F's shoulder and on the R's, breathing
## out of step, and two small sparkles in the air.
func _draw_glints() -> void:
	if _font == null:
		return
	_fit(_glints)
	var px := LINE_PX
	var ascent := _font.get_ascent(px)
	var f_at: Vector2 = LINES[0].at
	var r_at: Vector2 = LINES[1].at
	_glint(f_at + Vector2(22.0, -ascent * 0.66), 22.0 + 5.0 * sin(_t * 2.6))
	_glint(r_at + Vector2(24.0, -ascent * 0.62), 17.0 + 4.0 * sin(_t * 2.1 + 1.3))
	var filly_w := _font.get_string_size("Filly", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_sparkle(Vector2(f_at.x + filly_w + 190.0, px * 0.22), 13.0 + 3.0 * sin(_t * 3.0))
	_sparkle(Vector2(8, px * 1.5), 9.0 + 2.5 * sin(_t * 2.3 + 1.7))
	_glints.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _glint(at: Vector2, s: float) -> void:
	_glints.draw_circle(at, s * 0.55, Color(1, 1, 1, 0.25))
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI * 0.25
		pts.append(at + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.18))
	_glints.draw_colored_polygon(pts, Color(1, 1, 1, 0.95))


## A lucky horseshoe, open side up, with a star riding in its arch, rimmed in cream like the
## words so it stands off the sky too.
func _horseshoe(centre: Vector2, r: float) -> void:
	var from := PI * 0.12
	# Open at the top: the arc runs round the bottom, a little past level at each side.
	for pass_i in 5:
		var w: float = [r * 0.66, r * 0.66, r * 0.48, r * 0.32, r * 0.18][pass_i]
		var c: Color = [Color(0.05, 0.02, 0.08, 0.45), RIM, PLUM_DARK, GOLD,
			Color(1.0, 0.95, 0.7)][pass_i]
		var off := Vector2(0, r * 0.14) if pass_i == 0 else Vector2.ZERO
		if pass_i == 4:
			# The lit face of the shoe, a little up and in.
			draw_arc(centre + Vector2(-1, -3), r, PI * 0.55, PI + from * 0.6, 24, c, w, true)
			continue
		draw_arc(centre + off, r, -from, PI + from, 40, c, w, true)
	# The heels, at the two tips of the arch.
	for a: float in [-from, PI + from]:
		draw_circle(centre + Vector2(cos(a), sin(a)) * r, r * 0.17, GOLD_DEEP)
	# Nail holes along the shoe.
	for i in 5:
		var a := lerpf(PI * 0.02, PI * 0.98, float(i) / 4.0)
		draw_circle(centre + Vector2(cos(a), sin(a)) * r, r * 0.055, PLUM_DARK)
	# The star in the arch, slowly turning a few degrees either way.
	var star_box := Rect2(centre + Vector2(-r * 0.5, -r * 0.82), Vector2(r * 1.0, r * 1.0))
	var tilt := 0.12 * sin(_t * 1.4)
	var pts := PaintScript.star_points(star_box)
	var c2 := star_box.get_center()
	var turned := PackedVector2Array()
	for p in pts:
		turned.append(c2 + (p - c2).rotated(tilt))
	var outline := turned.duplicate()
	outline.append(turned[0])
	var rim := PackedVector2Array()
	var grown := PackedVector2Array()
	for p in turned:
		rim.append(c2 + (p - c2) * 1.34)
		grown.append(c2 + (p - c2) * 1.18)
	draw_colored_polygon(rim, RIM)
	draw_colored_polygon(grown, PLUM_DARK)
	draw_colored_polygon(turned, PINK)
	draw_polyline(outline, CREAM, 3.0, true)


func _sparkle(at: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(at + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.28))
	_glints.draw_colored_polygon(pts, CREAM)
