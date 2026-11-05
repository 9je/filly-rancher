class_name ObjectiveCard
extends Control
## THE STORY'S NEXT STEP, ALWAYS IN VIEW (owner playtest 2026-10-25: "idk what to do
## anymore"). A small card under the compass: the goal's place icon in the guide's gold ring,
## a few words (game/systems/objective.gd) and how far it is. It slides in when the step
## changes and is hidden when there is none. Drawn like the compass strip, so the two read as
## one piece of HUD.

const ICON := 30.0
const TOP := 68.0
const HERE_METRES := 4.0
const SLIDE_SECONDS := 0.35

var _panel: PanelContainer
var _icon: TextureRect
var _words: Label
var _distance: Label
var _id: StringName = &""
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.84, 0.86)
	sb.border_color = Color(0.45, 0.3, 0.55, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 8
	sb.content_margin_right = 16
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	# The goal's icon in the gold ring the compass gives the goal.
	var ring := PanelContainer.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rb := StyleBoxFlat.new()
	rb.bg_color = Color(1.0, 0.95, 0.75, 0.95)
	rb.border_color = Color(0.95, 0.72, 0.2)
	rb.set_border_width_all(3)
	rb.set_corner_radius_all(int(ICON * 0.5 + 5.0))
	rb.set_content_margin_all(5)
	ring.add_theme_stylebox_override("panel", rb)
	row.add_child(ring)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON, ICON)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(_icon)
	_words = Label.new()
	MenuStyle.style_label(_words, 22, Color(0.25, 0.18, 0.3))
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_words)
	_distance = Label.new()
	MenuStyle.style_label(_distance, 18, Color(0.55, 0.42, 0.18))
	_distance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_distance)
	visible = false


## Show objective `o` (Objective.current) `distance_m` away, or below zero for no place.
func show_objective(o: Dictionary, distance_m: float) -> void:
	if o.is_empty():
		visible = false
		_id = &""
		return
	_words.text = String(o.get("words", ""))
	_icon.texture = PlaceSign.icon_texture(int(o.get("icon", 0)))
	if distance_m < 0.0:
		_distance.text = ""
	elif distance_m <= HERE_METRES:
		_distance.text = "here"
	else:
		_distance.text = "%d m" % int(round(distance_m))
	var id := StringName(o.get("id", &""))
	visible = true
	if id != _id:
		_id = id
		_slide_in()
	_layout()


func words() -> String:
	return _words.text


func distance_text() -> String:
	return _distance.text


func _layout() -> void:
	var s := _panel.get_combined_minimum_size()
	_panel.size = s
	_panel.position = Vector2(-s.x * 0.5, TOP)


func _slide_in() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	position.y = -12.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, ^"modulate:a", 1.0, SLIDE_SECONDS)
	_tween.tween_property(self, ^"position:y", 0.0, SLIDE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
