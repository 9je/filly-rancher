class_name CatchIcon
extends Control
## ONE LITTLE PICTURE ON THE CATCH CARD (game/ui/catch_card.gd), drawn from simple shapes:
## no image files, no font glyphs. `kind` names what to draw:
##   races     unicorn, pegasus, earth
##   quirks    the ids in game/systems/pony_traits.gd QUIRKS
##   foods     hay, carrot, apple, daisy, daffodil
##   holds     hold_0 (easy), hold_1 (tricky), hold_2 (tough), a three bar meter
## Each one is a flat, outlined shape in the show's register, sized to its Control (drawn on
## a 30 x 30 design grid and scaled), so a chip can make it bigger without new art.

var kind: StringName = &"":
	set(value):
		kind = value
		queue_redraw()

const OUTLINE := Color(0.24, 0.17, 0.3, 0.85)


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 30.0
	draw_set_transform(Vector2((size.x - 30.0 * s) * 0.5, (size.y - 30.0 * s) * 0.5),
		0.0, Vector2(s, s))
	var c := Vector2(15, 15)
	match kind:
		&"unicorn":
			var horn := PackedVector2Array([Vector2(10, 27), Vector2(20, 27), Vector2(17, 3)])
			_poly(horn, Color(1.0, 0.78, 0.92))
			for i in 3:
				var y := 22.0 - i * 6.0
				draw_line(Vector2(11.5 + i * 1.6, y), Vector2(19.5 - i * 0.6, y - 3.0), OUTLINE, 1.6, true)
		&"pegasus":
			var wing := PackedVector2Array([Vector2(4, 20), Vector2(8, 9), Vector2(16, 5),
				Vector2(27, 4), Vector2(23, 10), Vector2(26, 12), Vector2(21, 16), Vector2(23, 19),
				Vector2(14, 23)])
			_poly(wing, Color(0.68, 0.84, 1.0))
			draw_line(Vector2(9, 18), Vector2(19, 9), OUTLINE, 1.4, true)
		&"earth":
			horseshoe(self, c, 10.0, Color(0.55, 0.42, 0.30))
		&"hay":
			_poly(PackedVector2Array([Vector2(7, 26), Vector2(23, 26), Vector2(26, 6),
				Vector2(4, 6)]), Color(0.96, 0.82, 0.38))
			for x in [9.0, 13.0, 17.0, 21.0]:
				draw_line(Vector2(x, 8), Vector2(x + (x - 15.0) * 0.08, 24), Color(0.78, 0.6, 0.2), 1.3, true)
			draw_rect(Rect2(5, 14, 20, 4), Color(0.62, 0.38, 0.2))
		&"carrot":
			_poly(PackedVector2Array([Vector2(6, 27), Vector2(13, 9), Vector2(21, 14)]),
				Color(1.0, 0.55, 0.15))
			for a in [-0.6, 0.0, 0.6]:
				var tip := Vector2(17, 11) + Vector2(cos(-PI * 0.3 + a), sin(-PI * 0.3 + a)) * 10.0
				draw_line(Vector2(17, 11), tip, Color(0.3, 0.65, 0.25), 3.0, true)
		&"apple":
			_circle(Vector2(15, 17), 9.5, Color(0.90, 0.22, 0.25))
			draw_line(Vector2(15, 8), Vector2(16.5, 3), Color(0.45, 0.28, 0.15), 2.2, true)
			_poly(PackedVector2Array([Vector2(17, 6), Vector2(24, 3), Vector2(21, 8)]),
				Color(0.35, 0.7, 0.3))
		&"daisy":
			for i in 8:
				var a := TAU * i / 8.0
				_circle(c + Vector2(cos(a), sin(a)) * 8.0, 4.4, Color(1, 1, 1))
			_circle(c, 4.6, Color(1.0, 0.82, 0.2))
		&"daffodil":
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				_circle(c + Vector2(cos(a), sin(a)) * 7.5, 5.2, Color(1.0, 0.92, 0.35))
			_circle(c, 5.4, Color(1.0, 0.6, 0.12))
			draw_arc(c, 3.0, 0, TAU, 16, Color(0.85, 0.42, 0.05), 1.4, true)
		&"glutton":
			_circle(Vector2(10, 12), 3.5, Color(0.9, 0.22, 0.25))
			_circle(Vector2(16, 10), 3.5, Color(1.0, 0.55, 0.15))
			_circle(Vector2(21, 12.5), 3.5, Color(0.35, 0.7, 0.3))
			var bowl := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				bowl.append(Vector2(15, 14) + Vector2(cos(a) * 12.0, sin(a) * 11.0))
			_poly(bowl, Color(0.72, 0.5, 0.32))
		&"night_owl":
			var moon := PackedVector2Array()
			for i in 17:
				var a := -PI * 0.5 + PI * i / 16.0
				moon.append(c + Vector2(cos(a), sin(a)) * 11.0)
			for i in 17:
				var a := PI * 0.5 - PI * i / 16.0
				moon.append(c + Vector2(-4.0, 0) + Vector2(cos(a) * 7.0, sin(a) * 11.0))
			_poly(moon, Color(1.0, 0.86, 0.35))
		&"social":
			heart(self, Vector2(11, 14), 6.5, Color(1.0, 0.45, 0.62))
			heart(self, Vector2(20, 17), 6.0, Color(0.98, 0.62, 0.78))
		&"loner":
			draw_arc(c, 11.0, 0, TAU, 28, Color(0.55, 0.5, 0.75), 2.2, true)
			heart(self, c, 6.0, Color(0.62, 0.55, 0.85))
		&"sparkler":
			sparkle(self, Vector2(13, 16), 11.0, Color(0.62, 0.92, 1.0))
			sparkle(self, Vector2(24, 7), 5.0, Color(1.0, 0.9, 0.5))
		&"skittish":
			_poly(PackedVector2Array([Vector2(15, 3), Vector2(28, 26), Vector2(2, 26)]),
				Color(1.0, 0.82, 0.25))
			draw_line(Vector2(15, 10), Vector2(15, 18), OUTLINE, 3.0, true)
			_circle(Vector2(15, 22.5), 1.8, OUTLINE)
		&"escapee":
			for x in [6.0, 24.0]:
				draw_rect(Rect2(x - 1.5, 14, 3, 14), Color(0.55, 0.38, 0.25))
			draw_rect(Rect2(4, 18, 22, 2.5), Color(0.7, 0.5, 0.32))
			draw_rect(Rect2(4, 23, 22, 2.5), Color(0.7, 0.5, 0.32))
			draw_arc(Vector2(15, 14), 10.0, PI * 1.05, PI * 1.95, 14, Color(0.4, 0.62, 0.95), 2.6, true)
			_poly(PackedVector2Array([Vector2(25.5, 10), Vector2(27, 16), Vector2(22, 14)]),
				Color(0.4, 0.62, 0.95))
		&"sleepy":
			_zed(Vector2(5, 14), 9.0)
			_zed(Vector2(17, 6), 7.0)
			_zed(Vector2(18, 20), 6.0)
		&"showoff":
			_poly(PackedVector2Array([Vector2(7, 4), Vector2(23, 4), Vector2(21, 14),
				Vector2(15, 18), Vector2(9, 14)]), Color(1.0, 0.78, 0.2))
			draw_rect(Rect2(13.5, 17, 3, 6), Color(0.85, 0.6, 0.1))
			_poly(PackedVector2Array([Vector2(9, 27), Vector2(21, 27), Vector2(19, 23),
				Vector2(11, 23)]), Color(0.85, 0.6, 0.1))
		&"hold_0", &"hold_1", &"hold_2":
			var level: int = int(String(kind).right(1)) + 1
			var tint: Color = [Color(0.40, 0.75, 0.40), Color(1.0, 0.68, 0.2), Color(0.92, 0.32, 0.3)][level - 1]
			for i in 3:
				var h := 7.0 + i * 7.0
				var r := Rect2(5 + i * 7.5, 26 - h, 5.5, h)
				draw_rect(r, tint if i < level else Color(0.84, 0.80, 0.86))
				draw_rect(r, OUTLINE, false, 1.2)
		_:
			_circle(c, 6.0, Color(0.8, 0.75, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _poly(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, OUTLINE, 1.5, true)


func _circle(at: Vector2, r: float, fill: Color) -> void:
	draw_circle(at, r, fill)
	draw_arc(at, r, 0, TAU, 20, OUTLINE, 1.3, true)


func _zed(at: Vector2, w: float) -> void:
	var pts := PackedVector2Array([at, at + Vector2(w, 0), at + Vector2(0, w), at + Vector2(w, w)])
	draw_polyline(pts, Color(0.35, 0.45, 0.85), 2.4, true)


# --- shapes the card itself borrows ---------------------------------------------------------

static func star(ci: CanvasItem, at: Vector2, r: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * i / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, edge, 1.6, true)


static func heart(ci: CanvasItem, at: Vector2, r: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(at + Vector2(x, y) * (r / 16.0))
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, 1.3, true)


static func sparkle(ci: CanvasItem, at: Vector2, r: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := -PI * 0.5 + PI * i / 4.0
		var rr := r if i % 2 == 0 else r * 0.28
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, 1.3, true)


static func horseshoe(ci: CanvasItem, at: Vector2, r: float, fill: Color) -> void:
	ci.draw_arc(at + Vector2(0, -r * 0.1), r, PI * 0.82, PI * 2.18, 24, fill, r * 0.45, true)
	for side in [-1.0, 1.0]:
		var p: Vector2 = at + Vector2(side * r * 0.62, r * 0.55)
		ci.draw_circle(p, r * 0.06 + 0.8, Color(1, 1, 1, 0.8))
