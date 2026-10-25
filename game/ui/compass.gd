class_name Compass
extends Control
## THE COMPASS STRIP: a slim band across the top of the screen with an icon for each place
## that matters, slid left and right by where the camera faces (owner playtest 2026-10-25:
## "i cant find the market", "i dont like how hard it is to find the build area"). Icons, not
## words: the same painted icons the signs in the world carry (world/place_sign.gd), so a
## coin on the strip and a coin on the Market's sign are one idea. A place behind her slides
## off the strip's ends; one close by fades, since she can see it already.

const PlaceSignScript := preload("res://world/place_sign.gd")

## Degrees of view the strip spans, end to end.
const SPAN_DEGREES := 150.0
const WIDTH := 620.0
const HEIGHT := 46.0
const ICON := 34.0
const TOP := 14.0
## Closer than this a place's icon fades out: she is already there.
const NEAR_METRES := 9.0

## [{name, icon, node}]: what the strip points at. ranch.gd fills it.
var places: Array[Dictionary] = []
var camera_provider: Callable
var player: Node3D

var _icons: Array[TextureRect] = []
var _back: Panel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	_back = Panel.new()
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.84, 0.72)
	sb.border_color = Color(0.45, 0.3, 0.55, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	_back.add_theme_stylebox_override("panel", sb)
	add_child(_back)
	var tick := ColorRect.new()
	tick.name = "Tick"
	tick.color = Color(0.45, 0.3, 0.55, 0.9)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tick)


func set_places(list: Array[Dictionary]) -> void:
	places = list
	for i in _icons:
		i.queue_free()
	_icons.clear()
	for p: Dictionary in places:
		var r := TextureRect.new()
		r.texture = PlaceSignScript.icon_texture(int(p.get("icon", 0)))
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(ICON, ICON)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.tooltip_text = String(p.get("name", ""))
		add_child(r)
		_icons.append(r)


## Where on the strip (0..1, or outside it) a bearing `deg` off the camera's facing lands.
static func strip_position(deg: float) -> float:
	return 0.5 + deg / SPAN_DEGREES


## The signed angle in degrees from the flat camera facing `forward` to the flat direction
## `to`, positive clockwise seen from above (to her right).
static func bearing(forward: Vector3, to: Vector3) -> float:
	var f := Vector2(forward.x, forward.z)
	var t := Vector2(to.x, to.z)
	if f.length_squared() < 0.000001 or t.length_squared() < 0.000001:
		return 0.0
	return rad_to_deg(f.angle_to(t))


## The icon for place `i` as drawn now: {visible, x, alpha}. For the suite.
func icon_state(i: int) -> Dictionary:
	if i < 0 or i >= _icons.size():
		return {}
	var r := _icons[i]
	return {"visible": r.visible, "x": r.position.x + ICON * 0.5 - _left(), "alpha": r.modulate.a}


func _left() -> float:
	return (get_viewport_rect().size.x - WIDTH) * 0.5


func _process(_delta: float) -> void:
	var cam: Camera3D = camera_provider.call() if camera_provider.is_valid() else get_viewport().get_camera_3d()
	var vw := get_viewport_rect().size.x
	var left := (vw - WIDTH) * 0.5
	_back.position = Vector2(left, TOP)
	_back.size = Vector2(WIDTH, HEIGHT)
	var tick := get_node(^"Tick") as ColorRect
	tick.position = Vector2(vw * 0.5 - 1.5, TOP + HEIGHT - 10.0)
	tick.size = Vector2(3.0, 8.0)
	if cam == null:
		return
	var forward := -cam.global_transform.basis.z
	var from: Vector3 = player.global_position if player != null and is_instance_valid(player) \
		else cam.global_position
	for i in places.size():
		var node := places[i].get("node") as Node3D
		var r := _icons[i]
		if node == null or not is_instance_valid(node):
			r.visible = false
			continue
		var to := node.global_position - from
		var dist := Vector2(to.x, to.z).length()
		var u := strip_position(bearing(forward, to))
		r.visible = u > 0.03 and u < 0.97
		r.position = Vector2(left + u * WIDTH - ICON * 0.5, TOP + (HEIGHT - ICON) * 0.5)
		var edge := clampf(minf(u - 0.03, 0.97 - u) / 0.12, 0.0, 1.0)
		var near := clampf((dist - NEAR_METRES * 0.5) / (NEAR_METRES * 0.5), 0.0, 1.0)
		r.modulate.a = edge * near
