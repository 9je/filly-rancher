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


func _ready() -> void:
	# Above every other layer: the HUD, the talk box and the menus all sit under it.
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = _veil_color()
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y -= 56
	MenuStyleScript.style_label(_hint, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_hint.text = "click or press any key"
	_hint.modulate.a = 0.0
	add_child(_hint)
	_build_letter()
	_build_credits()
	_fly()
	var t := create_tween()
	t.tween_property(_veil, "color:a", 0.18, 2.5)
	t.parallel().tween_property(_title, "modulate:a", 1.0, 2.5)
	t.tween_property(_hint, "modulate:a", 1.0, 1.0)


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
	_orbit(_t)
	if _credits.visible:
		_credits.position.y -= delta * 46.0
		if _credits.position.y + _credits.size.y < 0:
			_finish()


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	advance()


## Title, then the letter, then the credits, then done.
func advance() -> void:
	_stage += 1
	match _stage:
		1:
			var t := create_tween()
			t.tween_property(_title, "modulate:a", 0.0, 0.6)
			_letter.visible = true
			_letter.modulate.a = 0.0
			t.tween_property(_letter, "modulate:a", 1.0, 0.8)
		2:
			var t2 := create_tween()
			t2.tween_property(_letter, "modulate:a", 0.0, 0.6)
			t2.parallel().tween_property(_veil, "color:a", 0.55, 0.6)
			_credits.visible = true
			_credits.position.y = get_viewport().get_visible_rect().size.y
		_:
			_finish()


func _finish() -> void:
	if _stage < 0:
		return
	_stage = -1
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	if _cam != null:
		_cam.queue_free()
	done.emit()
	queue_free()


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
	text.add_theme_font_size_override(&"font_size", 24)
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
