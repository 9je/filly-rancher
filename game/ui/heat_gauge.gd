extends Control
## THE HEAT GAUGE (playtest 2026-11-10 items 21 and 22: "heat 0? whats that", Heat 9 from one
## corral gate, 0 while cutting pylons in front of the guards). Heat was a number in toasts.
## Now it is a pill in the top right on the Rescue path: "Heat", a bar from cool to hot, and
## three ticks where a collection day starts to cost (a fine, a padlock, a pony taken). The
## bar eases to a new value and the pill pulses when it moves.

const HouseStyleScript := preload("res://ui/house_style.gd")
const PathRulesScript := preload("res://systems/path_rules.gd")

const BAR := Vector2(126, 12)
var value := 0
var _shown := 0.0
var _pulse := 0.0
var _panel: Panel
var _fill: ColorRect
var _lamp: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -250.0
	offset_right = -20.0
	offset_top = 22.0
	offset_bottom = 62.0
	_panel = Panel.new()
	_panel.add_theme_stylebox_override(&"panel", HouseStyleScript.pill_box(20, 0.88, Vector2.ZERO))
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_lamp = ColorRect.new()
	_lamp.size = Vector2(12, 12)
	_lamp.position = Vector2(14, 14)
	_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lamp)
	var label := Label.new()
	HouseStyleScript.ink_label(label, 18, HouseStyleScript.CREAM)
	label.text = "Heat"
	label.position = Vector2(32, 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var bar_at := Vector2(230 - BAR.x - 14, 14)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.07, 0.15, 0.9)
	bg.position = bar_at
	bg.size = BAR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_fill = ColorRect.new()
	_fill.position = bar_at
	_fill.size = Vector2(0, BAR.y)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)
	for at in [PathRulesScript.FINE_AT, PathRulesScript.PADLOCK_AT, PathRulesScript.TAKE_AT]:
		var tick := ColorRect.new()
		tick.color = HouseStyleScript.CREAM
		tick.size = Vector2(2, BAR.y + 6)
		tick.position = bar_at + Vector2(BAR.x * float(at) / float(PathRulesScript.HEAT_MAX) - 1, -3)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tick)


func set_heat(h: int) -> void:
	if h != value:
		_pulse = 1.0
	value = h


func _process(delta: float) -> void:
	_shown = lerpf(_shown, float(value), 1.0 - exp(-4.0 * delta))
	_pulse = maxf(0.0, _pulse - delta * 1.5)
	var hot := clampf(_shown / float(PathRulesScript.HEAT_MAX), 0.0, 1.0)
	var c := Color(1.0, 0.85 - 0.6 * hot, 0.3 - 0.2 * hot)
	_fill.size.x = BAR.x * hot
	_fill.color = c
	_lamp.color = c.lightened(0.4 * _pulse)
	scale = Vector2.ONE * (1.0 + 0.08 * _pulse)
	pivot_offset = size * 0.5
