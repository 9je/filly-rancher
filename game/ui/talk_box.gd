class_name TalkBox
extends CanvasLayer
## THE SPEECH BUBBLE. A rounded cream bubble with a thick outline in the speaker's own coat
## color and a name tab, anchored over her head in screen space, with the line revealed a
## letter at a time and up to two choices as rounded buttons. Mouse, keyboard and
## controller all work: click, the interact key or ui_accept advances (finishing the reveal
## first); choices take a click, the arrow keys / d-pad and accept, or the number keys.
##
## Pure presentation: game/world/people.gd owns the DialogueRunner and calls show_line().

signal advanced
signal chose(index: int)

const REVEAL_CPS := 46.0
const MAX_WIDTH := 620.0

var anchor: Node3D
var camera: Camera3D
var outline := Color(0.55, 0.4, 0.75)
var _panel: PanelContainer
var _name_tab: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label
var _shown := 0.0
var _total := 0
var _selected := 0
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360, 0)
	root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(320, 0)
	_text.add_theme_font_size_override("normal_font_size", 26)
	_text.add_theme_color_override("default_color", Color(0.22, 0.17, 0.25))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	v.add_child(_choices)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.45, 0.38, 0.5))
	v.add_child(_hint)
	_name_tab = PanelContainer.new()
	root.add_child(_name_tab)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_tab.add_child(_name_label)
	_panel.gui_input.connect(_on_panel_input)
	visible = false


func is_open() -> bool:
	return visible


func is_revealing() -> bool:
	return int(_shown) < _total


## Show `line` ({who_name, text, choices}) over `speaker`, outlined in `color`.
func show_line(line: Dictionary, speaker: Node3D, color: Color) -> void:
	anchor = speaker
	outline = color
	_style()
	_name_label.text = str(line.get("who_name", ""))
	_text.text = str(line.get("text", ""))
	_total = _text.get_total_character_count()
	_shown = 0.0
	_text.visible_characters = 0
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	var choices: Array = line.get("choices", [])
	for i in range(choices.size()):
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, choices[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 23)
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_entered.connect(func() -> void: _select(i))
		b.pressed.connect(func() -> void: _pick(i))
		_style_button(b)
		_choices.add_child(b)
		_buttons.append(b)
	_choices.visible = false
	_selected = 0
	_hint.text = ""
	visible = true


func close() -> void:
	visible = false
	anchor = null


func _style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.98, 0.93)
	sb.border_color = outline
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", sb)
	var tab := StyleBoxFlat.new()
	tab.bg_color = outline
	tab.set_corner_radius_all(16)
	tab.content_margin_left = 16
	tab.content_margin_right = 16
	tab.content_margin_top = 4
	tab.content_margin_bottom = 6
	_name_tab.add_theme_stylebox_override("panel", tab)


func _style_button(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		var hot: bool = state != "normal"
		sb.bg_color = outline.lightened(0.55) if hot else Color(0.98, 0.95, 0.9)
		sb.border_color = outline
		sb.set_border_width_all(3 if hot else 2)
		sb.set_corner_radius_all(18)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(0.22, 0.17, 0.25))
	b.add_theme_color_override("font_hover_color", Color(0.15, 0.1, 0.2))
	b.add_theme_color_override("font_focus_color", Color(0.15, 0.1, 0.2))


func _process(delta: float) -> void:
	if not visible:
		return
	if is_revealing():
		_shown = minf(_shown + REVEAL_CPS * delta, float(_total))
		_text.visible_characters = int(_shown)
		if not is_revealing():
			_on_revealed()
	_place()


func _on_revealed() -> void:
	_text.visible_characters = -1
	if not _buttons.is_empty():
		_choices.visible = true
		_select(0)
		_hint.text = ""
	else:
		_hint.text = "click or E  ▸"


func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	var size := _panel.get_combined_minimum_size()
	size.x = clampf(size.x, 360.0, MAX_WIDTH)
	_panel.size = size
	var at := Vector2(vp.x * 0.5, vp.y * 0.2)
	if anchor != null and is_instance_valid(anchor) and camera != null:
		var head := anchor.global_position + Vector3(0, 2.3, 0)
		if not camera.is_position_behind(head):
			at = camera.unproject_position(head)
	var pos := at - Vector2(size.x * 0.5, size.y + 24.0)
	pos.x = clampf(pos.x, 24.0, vp.x - size.x - 24.0)
	pos.y = clampf(pos.y, 70.0, vp.y - size.y - 40.0)
	_panel.position = pos
	_name_tab.position = pos + Vector2(26, -_name_tab.get_combined_minimum_size().y * 0.6)


func _select(i: int) -> void:
	if _buttons.is_empty():
		return
	_selected = clampi(i, 0, _buttons.size() - 1)
	_buttons[_selected].grab_focus()


func _pick(i: int) -> void:
	if is_revealing():
		return
	chose.emit(i)


func _on_panel_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_accept()


func _accept() -> void:
	if is_revealing():
		_shown = float(_total)
		_text.visible_characters = -1
		_on_revealed()
		return
	if _buttons.is_empty():
		advanced.emit()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed(&"interact") or (e.is_action_pressed(&"ui_accept") and _buttons.is_empty()):
		_accept()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and _choices.visible:
		var k := (e as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < _buttons.size():
			_pick(k - KEY_1)
			get_viewport().set_input_as_handled()
