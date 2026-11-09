extends Control
## THE GAME'S NAME, DRAWN (Fable AAA review round 1, #9: "no logotype"). The title used to be a
## Label in the menu's heading size. A logotype is a piece of art: big display type stacked on
## two lines, a thick plum outline with a gold rim inside it and a drop shadow under it, and a
## lucky horseshoe with a star riding in it beside "Filly", the way the show's own title cards
## dress a name. Drawn from the project's own face (Fredoka) and polygons: no image asset.
##
## Shared by the title screen and the loading screen, so the name looks the same in both.

const PaintScript := preload("res://ui/casino_paint.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

const PLUM_DARK := Color(0.2, 0.07, 0.24)
const GOLD := Color(0.99, 0.84, 0.36)
const GOLD_DEEP := Color(0.86, 0.6, 0.16)
const CREAM := Color(1.0, 0.96, 0.88)
const PINK := Color(0.98, 0.62, 0.84)

## The size the art is authored at; `scale_to` draws it at any width.
const BASE := Vector2(700, 300)
const LINE_PX := 124

var _t := 0.0
var _font: FontVariation


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BASE


func _ready() -> void:
	_font = FontVariation.new()
	_font.base_font = MenuStyleScript.title_font().base_font
	# Heavier than the menus' titles: the name is the loudest word in the game.
	_font.variation_opentype = {2003265652: 700}
	_font.spacing_glyph = 2


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## One line of the name, in four passes: the shadow, the plum outline, the rim, the fill.
func _word(at: Vector2, word: String, px: int, fill: Color, rim: Color) -> void:
	var shadow := at + Vector2(0, px * 0.09)
	draw_string_outline(_font, shadow, word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.24),
		Color(PLUM_DARK, 0.45))
	draw_string_outline(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.2), PLUM_DARK)
	draw_string_outline(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.08), rim)
	draw_string(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fill)
	# A gloss along the top of the letters: the fill again, lighter, nudged up a hair and
	# drawn thin, which reads as light on a rounded face.
	draw_string(_font, at + Vector2(0, -px * 0.025), word, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
		Color(1, 1, 1, 0.18))


func _draw() -> void:
	if _font == null:
		return
	var k := minf(size.x / BASE.x, size.y / BASE.y)
	draw_set_transform(Vector2((size.x - BASE.x * k) * 0.5, 0.0), 0.0, Vector2(k, k))
	var px := LINE_PX
	var filly_at := Vector2(18, px * 0.98)
	_word(filly_at, "Filly", px, CREAM, GOLD)
	var filly_w := _font.get_string_size("Filly", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_word(Vector2(70, px * 1.98), "Rancher", px, GOLD, CREAM)
	_horseshoe(Vector2(filly_at.x + filly_w + 92.0, px * 0.6), 54.0)
	# Two small sparkles, twinkling out of step.
	_sparkle(Vector2(filly_at.x + filly_w + 190.0, px * 0.22), 13.0 + 3.0 * sin(_t * 3.0))
	_sparkle(Vector2(12, px * 1.5), 9.0 + 2.5 * sin(_t * 2.3 + 1.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A lucky horseshoe, open side up, with a star riding in its arch.
func _horseshoe(centre: Vector2, r: float) -> void:
	var from := PI * 0.12
	# Open at the top: the arc runs round the bottom, a little past level at each side.
	for pass_i in 3:
		var w: float = [r * 0.62, r * 0.48, r * 0.3][pass_i]
		var c: Color = [Color(PLUM_DARK, 0.45), PLUM_DARK, GOLD][pass_i]
		var off := Vector2(0, r * 0.12) if pass_i == 0 else Vector2.ZERO
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
	var grown := PackedVector2Array()
	for p in turned:
		grown.append(c2 + (p - c2) * 1.18)
	draw_colored_polygon(grown, PLUM_DARK)
	draw_colored_polygon(turned, PINK)
	draw_polyline(outline, CREAM, 3.0, true)


func _sparkle(at: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(at + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.28))
	draw_colored_polygon(pts, CREAM)
