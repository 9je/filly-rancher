class_name Cinematic
extends CanvasLayer
## THE ONE CINEMATIC PLAYER (P8 S9; docs/ideas-2026-11-08.md F, docs/aaa-review-2026-11-08.md
## 2.15; owner: "cut scenes and cinematics wanted"). Every moment the game stages on camera, a
## Bloom, the Collectors' cart, a Rainboom, Derpy coming down, a photo finish, plays through
## this, so each scene is data, not new code:
##
##   var c := Cinematic.shared(get_tree())
##   await c.play([{"from": a, "to": b, "look": p, "time": 3.0, "caption": "..."}, ...],
##       {"freeze": [player], "can_start": func(): return no_menu_open})
##
## A shot moves its own camera from `from` to `to` over `time` seconds (eased in and out) while
## it looks at `look` (a point, or `look_node`, a Node3D followed as it moves) and on to
## `look_to` if given; `fov` sets the lens; `caption` puts one line low in the frame, the way a
## title card does; `call` runs as the shot starts (start an actor's move, a sound, a burst).
## `from` may be "here" to start from wherever the game camera is, so the cut is a move.
##
## THE RULES (ideas doc F): short, letterboxed, always skippable (hold Skip, the hint says
## which key, for SKIP_HOLD seconds), never ambushing: `can_start` is polled until it says yes,
## so a scene raised while a menu is up waits for the menu to close. While it plays, the bodies
## in `freeze` stop processing input and physics and get them back after.

signal started
signal finished(skipped: bool)

const BAR_FRACTION := 0.11
const BAR_SECONDS := 0.35
const SKIP_HOLD := 0.6
const SKIP_ACTIONS: Array[StringName] = [&"ui_cancel", &"jump", &"interact"]

static var _shared: Cinematic

var playing := false
var _camera: Camera3D
var _was_current: Camera3D
var _top: ColorRect
var _bottom: ColorRect
var _caption: Label
var _skip_hint: Label
var _skip_held := 0.0
var _skip := false
var _frozen: Array[Node] = []


static func shared(tree: SceneTree) -> Cinematic:
	if _shared == null or not is_instance_valid(_shared):
		_shared = Cinematic.new()
		_shared.name = "Cinematic"
		tree.root.add_child(_shared)
	return _shared


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_top = _bar()
	_bottom = _bar()
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override(&"font", MenuStyle.title_font())
	_caption.add_theme_font_size_override(&"font_size", 34)
	_caption.add_theme_color_override(&"font_color", Color(1.0, 0.97, 0.9))
	_caption.add_theme_color_override(&"font_shadow_color", Color(0.1, 0.05, 0.15, 0.8))
	_caption.add_theme_constant_override(&"shadow_offset_y", 3)
	_caption.modulate.a = 0.0
	add_child(_caption)
	_skip_hint = Label.new()
	_skip_hint.add_theme_font_size_override(&"font_size", 20)
	_skip_hint.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.7))
	_skip_hint.visible = false
	add_child(_skip_hint)
	visible = false


func _bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.02, 0.05)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


## Play `shots`; resolves when the scene ends (or is skipped). See the class comment.
func play(shots: Array, opts: Dictionary = {}) -> bool:
	if playing:
		await finished
	var can_start: Callable = opts.get("can_start", Callable())
	while can_start.is_valid() and not bool(can_start.call()):
		await get_tree().process_frame
	playing = true
	_skip = false
	_skip_held = 0.0
	_freeze(opts.get("freeze", []))
	var vp := get_viewport()
	_was_current = vp.get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "CinematicCamera"
	var host: Node = opts.get("host", get_tree().current_scene)
	host.add_child(_camera)
	if _was_current != null:
		_camera.global_transform = _was_current.global_transform
		_camera.fov = _was_current.fov
	_camera.current = true
	visible = true
	_skip_hint.text = "Hold %s to skip" % InputDeviceScript.hint(&"ui_cancel")
	_skip_hint.visible = bool(opts.get("skippable", true))
	started.emit()
	await _bars(1.0)
	for shot: Dictionary in shots:
		if _skip:
			break
		await _shot(shot)
	_caption.modulate.a = 0.0
	await _bars(0.0)
	if _was_current != null and is_instance_valid(_was_current):
		_was_current.current = true
	_camera.queue_free()
	_camera = null
	visible = false
	_thaw()
	playing = false
	finished.emit(_skip)
	return _skip


const InputDeviceScript := preload("res://systems/input_device.gd")


func _shot(shot: Dictionary) -> void:
	var t := float(shot.get("time", 2.0))
	var from: Variant = shot.get("from", "here")
	var start: Vector3 = _camera.global_position if from is String else from as Vector3
	var end: Vector3 = shot.get("to", start)
	var look_node: Node3D = shot.get("look_node", null)
	var look_a: Vector3 = shot.get("look", start + Vector3.FORWARD)
	var look_b: Vector3 = shot.get("look_to", look_a)
	if shot.has("fov"):
		_camera.fov = float(shot.fov)
	var call: Callable = shot.get("call", Callable())
	if call.is_valid():
		call.call()
	var caption := String(shot.get("caption", ""))
	_caption.text = caption
	var cap_target := 1.0 if caption != "" else 0.0
	var e := 0.0
	while e < t and not _skip:
		var dt := get_process_delta_time()
		e += dt
		var k := smoothstep(0.0, 1.0, clampf(e / t, 0.0, 1.0))
		_camera.global_position = start.lerp(end, k)
		var at := look_node.global_position + Vector3(0, float(shot.get("look_height", 1.0)), 0) \
			if look_node != null and is_instance_valid(look_node) else look_a.lerp(look_b, k)
		if not _camera.global_position.is_equal_approx(at):
			_camera.look_at(at, Vector3.UP)
		_caption.modulate.a = move_toward(_caption.modulate.a, cap_target, dt * 3.0)
		await get_tree().process_frame


func _process(delta: float) -> void:
	if not playing or not _skip_hint.visible:
		return
	var held := false
	for a: StringName in SKIP_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			held = true
	_skip_held = _skip_held + delta if held else 0.0
	_skip_hint.modulate.a = 0.7 + 0.3 * clampf(_skip_held / SKIP_HOLD, 0.0, 1.0)
	if _skip_held >= SKIP_HOLD:
		_skip = true


func skip() -> void:
	_skip = true


func _bars(to: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var h := size.y * BAR_FRACTION
	_top.size = Vector2(size.x, h)
	_bottom.size = Vector2(size.x, h)
	_caption.position = Vector2(0, size.y - h - 70.0)
	_caption.size = Vector2(size.x, 60.0)
	_skip_hint.position = Vector2(size.x - 260.0, size.y - h * 0.5 - 14.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_top, "position:y", -h + h * to, BAR_SECONDS)
	tw.tween_property(_bottom, "position:y", size.y - h * to, BAR_SECONDS)
	await tw.finished


func _freeze(nodes: Array) -> void:
	_frozen.clear()
	for n: Node in nodes:
		if n != null and is_instance_valid(n) and n.process_mode != Node.PROCESS_MODE_DISABLED:
			n.set_meta(&"cine_mode", n.process_mode)
			n.process_mode = Node.PROCESS_MODE_DISABLED
			_frozen.append(n)


func _thaw() -> void:
	for n: Node in _frozen:
		if is_instance_valid(n):
			n.process_mode = n.get_meta(&"cine_mode", Node.PROCESS_MODE_INHERIT)
	_frozen.clear()
