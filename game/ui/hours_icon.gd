class_name HoursIcon
extends Control
## THE HOURS A PONY KEEPS, DRAWN (PS9 item 55): a sun for day, a moon for night, a sun on
## the horizon for dawn or dusk, one mark per phase she keeps, or a sun and a moon together
## for any time. Beside her name on a permit's preview, so "when" reads without words.

const SIZE := 20.0
const SUN := Color(1.0, 0.82, 0.35)
const MOON := Color(0.78, 0.84, 1.0)
const HORIZON := Color(1.0, 0.62, 0.42)

## WorldState.Phase values (DAWN 0, DAY 1, DUSK 2, NIGHT 3); empty is any time.
var phases: Array[int] = []:
	set(v):
		phases = v
		_fit()


func _ready() -> void:
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()


func marks() -> Array[StringName]:
	if phases.is_empty():
		return [&"sun", &"moon"]
	var out: Array[StringName] = []
	for p in phases:
		match p:
			0, 2:
				if not &"horizon" in out:
					out.append(&"horizon")
			1:
				out.append(&"sun")
			3:
				out.append(&"moon")
	return out


func _fit() -> void:
	custom_minimum_size = Vector2(SIZE * maxi(1, marks().size()) + 2.0 * (marks().size() - 1), SIZE)
	queue_redraw()


func _draw() -> void:
	var r := SIZE * 0.32
	var x := SIZE * 0.5
	for m in marks():
		var c := Vector2(x, SIZE * 0.5)
		match m:
			&"sun":
				draw_circle(c, r, SUN)
				for i in 8:
					var a := TAU * i / 8.0
					var d := Vector2(cos(a), sin(a))
					draw_line(c + d * (r + 1.5), c + d * (r + 4.0), SUN, 1.6, true)
			&"moon":
				draw_circle(c, r + 1.0, MOON)
				draw_circle(c + Vector2(r * 0.6, -r * 0.35), r * 0.9, Color(0.22, 0.09, 0.27))
			&"horizon":
				var base := c + Vector2(0, r * 0.6)
				draw_arc(base, r + 0.5, PI, TAU, 16, HORIZON, r, true)
				draw_line(base + Vector2(-SIZE * 0.45, 0), base + Vector2(SIZE * 0.45, 0), HORIZON, 1.6, true)
		x += SIZE + 2.0
