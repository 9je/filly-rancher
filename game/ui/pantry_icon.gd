extends Control
## THE PANTRY ROW'S PICTURES (PS9 item 64): a hay bale for the food in stock, a sad face for
## the hungry. Drawn, like the rest of the HUD, so they read without words.

const SIZE := 24.0
const STRAW := Color(0.96, 0.8, 0.38)
const STRAW_DARK := Color(0.72, 0.52, 0.2)
const FACE := Color(1.0, 0.86, 0.6)
const INK := Color(0.24, 0.15, 0.3)

var kind: StringName = &"bale":
	set(v):
		kind = v
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := Vector2(SIZE, SIZE) * 0.5
	if kind == &"hungry":
		draw_circle(c, SIZE * 0.42, FACE)
		draw_circle(c + Vector2(-4, -2), 1.8, INK)
		draw_circle(c + Vector2(4, -2), 1.8, INK)
		draw_arc(c + Vector2(0, 7), 4.5, PI + 0.5, TAU - 0.5, 10, INK, 1.8, true)
		return
	var r := Rect2(Vector2(2, 6), Vector2(SIZE - 4, SIZE - 10))
	draw_rect(r, STRAW)
	for x in [r.position.x + r.size.x * 0.33, r.position.x + r.size.x * 0.66]:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), STRAW_DARK, 2.0)
	draw_rect(r, STRAW_DARK, false, 1.5)
