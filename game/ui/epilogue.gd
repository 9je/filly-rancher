class_name Epilogue
extends CanvasLayer
## AN ENDING'S EPILOGUE (STORY.md section 6): a slow camera over the valley under the
## ending's final grade, the title, the last letter on paper, then the credits. Any key or
## click moves it on; at the end it hands the world back (post-game) and emits `done`.
##
## Built by ranch.gd's play_ending(); `lines` carries what this save earned (the names you
## could not reach, how many you saved, your rank).

signal done

const MenuStyleScript := preload("res://ui/menu_style.gd")
const EndingsScript := preload("res://systems/endings.gd")
const ORBIT_SECONDS := 90.0

var ending: StringName = &""
var player_name := "friend"
var lines: Dictionary = {}

var _cam: Camera3D
var _prev_cam: Camera3D
var _t := 0.0
var _stage := 0
var _veil: ColorRect
var _title: Label
var _letter: PanelContainer
var _credits: VBoxContainer
var _hint: Label
var _sub: Label
var _results: PanelContainer
## SECONDS EACH STAGE STAYS BEFORE A PRESS MOVES IT ON (item 24: a key still held from the
## lever, or the move keys, skipped the whole ending in a blink). Only the confirm keys count.
const STAGE_MIN_SECONDS := 2.5
var _stage_t := 0.0
## The one tween at a time: a quick reader's clicks cannot leave two fighting one property.
var _tw: Tween
var _prev_mouse := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	# Above every other layer: the HUD, the talk box and the menus all sit under it.
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = _veil_color()
	# The veil takes no clicks of its own: every click reaches _input below.
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	MenuStyleScript.style_label(_title, 72, MenuStyleScript.COLOR_TITLE)
	_title.text = EndingsScript.title(ending)
	_title.modulate.a = 0.0
	add_child(_title)
	_sub = Label.new()
	_sub.set_anchors_preset(Control.PRESET_CENTER)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub.position.y += 70
	MenuStyleScript.style_label(_sub, 30, MenuStyleScript.COLOR_NAME)
	var res := EndingsScript.results(ending, lines.get("input", {}), int(lines.get("seen", 1)))
	_sub.text = "The End  -  " + res[0]
	for lab in [_title, _sub]:
		lab.add_theme_color_override(&"font_outline_color", Color(0.17, 0.09, 0.2, 0.95))
		lab.add_theme_constant_override(&"outline_size", 14 if lab == _title else 9)
	_sub.modulate.a = 0.0
	add_child(_sub)
	# On paper, like the letter: never bare words over the valley.
	_results = PanelContainer.new()
	_results.add_theme_stylebox_override(&"panel", _paper())
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results.custom_minimum_size = Vector2(620, 0)
	var rl := Label.new()
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.add_theme_color_override(&"font_color", MenuStyleScript.COLOR_INK)
	rl.add_theme_font_size_override(&"font_size", MenuStyle.font_px(26))
	rl.text = "\n".join(res)
	_results.add_child(rl)
	_results.visible = false
	add_child(_results)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y -= 56
	MenuStyleScript.style_label(_hint, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_hint.text = "click to continue"
	_hint.modulate.a = 0.0
	add_child(_hint)
	_build_letter()
	_build_credits()
	_fly()
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var t := _tween()
	t.tween_property(_veil, "color:a", 0.5, 2.5)
	t.parallel().tween_property(_title, "modulate:a", 1.0, 2.5)
	t.parallel().tween_property(_sub, "modulate:a", 1.0, 2.5)
	t.tween_property(_hint, "modulate:a", 1.0, 1.0)


func _tween() -> Tween:
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	return _tw


func is_open() -> bool:
	return _stage >= 0


func _veil_color() -> Color:
	var tone := EndingsScript.tone(ending)
	if ending == EndingsScript.PLACEMENT:
		return Color(1, 1, 1, 1)
	return Color(0.05, 0.05, 0.08, 1.0) if not bool(tone.free) else Color(1.0, 0.92, 0.8, 1.0)


## The camera goes up over the valley and turns slowly around it.
func _fly() -> void:
	var vp := get_viewport()
	_prev_cam = vp.get_camera_3d() if vp != null else null
	var world := get_parent() as Node3D
	if world == null:
		return
	_cam = Camera3D.new()
	_cam.fov = 55
	world.add_child(_cam)
	_cam.make_current()
	_orbit(0.0)


func _orbit(t: float) -> void:
	if _cam == null:
		return
	var a := t / ORBIT_SECONDS * TAU
	_cam.global_position = Vector3(cos(a) * 70.0, 34.0, sin(a) * 70.0)
	_cam.look_at(Vector3(0, 4, 0))


func _process(delta: float) -> void:
	_t += delta
	_stage_t += delta
	_orbit(_t)
	if _credits.visible:
		_credits.position.y -= delta * 46.0
		if _credits.position.y + _credits.size.y < 0:
			_finish()


## _input, not _unhandled_input: the epilogue is over everything, so nothing under it (the
## pause key, a pen's click) gets a press first.
func _input(event: InputEvent) -> void:
	if _stage < 0:
		return
	get_viewport().set_input_as_handled()
	if event.is_echo() or not event.is_pressed():
		return
	var confirm: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact") \
		or event.is_action_pressed(&"ui_cancel")
	if not confirm or _stage_t < STAGE_MIN_SECONDS:
		return
	advance()


## Title, then the letter, then the credits, then done.
func advance() -> void:
	if _stage < 0:
		return
	_stage += 1
	_stage_t = 0.0
	match _stage:
		1:
			var t := _tween()
			t.tween_property(_title, "modulate:a", 0.0, 0.6)
			t.parallel().tween_property(_sub, "modulate:a", 0.0, 0.6)
			_letter.visible = true
			_letter.modulate.a = 0.0
			t.tween_property(_letter, "modulate:a", 1.0, 0.8)
		2:
			var tr := _tween()
			tr.tween_property(_letter, "modulate:a", 0.0, 0.6)
			_results.visible = true
			_results.modulate.a = 0.0
			tr.tween_property(_results, "modulate:a", 1.0, 0.8)
		3:
			var t2 := _tween()
			t2.tween_property(_results, "modulate:a", 0.0, 0.6)
			t2.parallel().tween_property(_veil, "color:a", 0.55, 0.6)
			_credits.visible = true
			_credits.position.y = get_viewport().get_visible_rect().size.y
		_:
			_finish()


func _finish() -> void:
	if _stage < 0:
		return
	_stage = -1
	if _tw != null:
		_tw.kill()
	Input.mouse_mode = _prev_mouse
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	if _cam != null:
		_cam.queue_free()
	done.emit()
	queue_free()


func _paper() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = MenuStyleScript.COLOR_PAPER
	box.border_color = MenuStyleScript.COLOR_PAPER_EDGE
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 36
	box.content_margin_bottom = 36
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 18
	return box


func _build_letter() -> void:
	_letter = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = MenuStyleScript.COLOR_PAPER
	box.border_color = MenuStyleScript.COLOR_PAPER_EDGE
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 40
	box.content_margin_bottom = 40
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 18
	_letter.add_theme_stylebox_override(&"panel", box)
	_letter.set_anchors_preset(Control.PRESET_CENTER)
	_letter.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_letter.grow_vertical = Control.GROW_DIRECTION_BOTH
	_letter.custom_minimum_size = Vector2(760, 0)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(664, 0)
	text.add_theme_color_override(&"font_color", MenuStyleScript.COLOR_INK)
	text.add_theme_font_size_override(&"font_size", MenuStyle.font_px(24))
	text.text = letter_text(ending, player_name, lines)
	_letter.add_child(text)
	_letter.visible = false
	add_child(_letter)


## The closing letter (STORY.md section 6), filled with this save's own numbers.
static func letter_text(e: StringName, who: String, l: Dictionary) -> String:
	var lost: Array = l.get("lost", [])
	match e:
		EndingsScript.BRIGHTEST_RAINBOW:
			return ("Dear Regional Director %s,\n\nCongratulations on a record Jubilee. Your pension " +
				"plan is enclosed. Equestria has never seen a rainbow like it.\n\nThe valley is very " +
				"quiet now. Tumble sits on the porch and faces the Works.\n\nCloudsdale Weather Corporation") % who
		EndingsScript.GRAY_GOLD:
			return ("Dear %s,\n\nA routine audit has found a small discrepancy: %d ponies the ranch " +
				"received were never delivered. We are sure there is an explanation.\n\nIn the " +
				"Thornwood, something with a cutie mark is eating clover.\n\nCloudsdale Audit Office") % [who, int(l.get("rescued", 0))]
		EndingsScript.LIGHTS_OUT:
			return ("Dear %s,\n\nIt's Pip. This is just a letter. Nothing in it is about yield or " +
				"quota or color. Fennel and Clover say hello. The sky is only sky this morning, and " +
				"it is so blue.\n\nCome to the square later. Everypony will be there.\n\nPip") % who
		EndingsScript.HALF_LIGHT:
			var names := ", ".join(lost) if not lost.is_empty() else "the ones before you knew"
			return ("Dear %s,\n\nThe Works is dark. The rainbow is gone. You saved %d of them.\n\n" +
				"Fennel's postcards are still on the wall. These are the names we could not reach: " +
				"%s.\n\nStatic") % [who, int(l.get("rescued", 0)), names]
		EndingsScript.PLACEMENT:
			return ("Dear Tumble,\n\nI am having a wonderful time at the Factory! Everypony is so " +
				"kind. The rainbows are beautiful.\n\nYour friend,\n%s") % who
	return ""


func _build_credits() -> void:
	_credits = VBoxContainer.new()
	_credits.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_credits.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_credits.custom_minimum_size = Vector2(900, 0)
	_credits.add_theme_constant_override(&"separation", 14)
	for row in credit_rows():
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var heading := str(row).begins_with("#")
		MenuStyleScript.style_label(lab, 34 if heading else 22,
			MenuStyleScript.COLOR_TAB_ON if heading else MenuStyleScript.COLOR_NAME)
		lab.text = str(row).trim_prefix("# ")
		_credits.add_child(lab)
	_credits.visible = false
	add_child(_credits)


static func credit_rows() -> Array[String]:
	return ["# Filly Rancher", "", "# Made by", "Jordan Eldridge", "with Claude", "",
		"# My Little Pony: Friendship is Magic", "Hasbro, DHX Media, Lauren Faust", "",
		"# Rainbow Factory", "after the fan story by Aurora Dawn", "",
		"# Pony models", "the PonySFM community", "",
		"# Music", "Kevin MacLeod (incompetech.com), CC BY 4.0", "",
		"# Sound", "Freesound contributors, CC0 and CC BY (see CREDITS.md)", "",
		"# Font", "Fredoka, SIL Open Font License", "",
		"# Engine", "Godot Engine", "", "", "Thank you for playing."]
