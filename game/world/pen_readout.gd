class_name PenReadout
extends Node3D
## WHAT A PEN SAYS ABOUT ITSELF, IN THE WORLD (P8; playtest 2026-11-08 items 2, 9, 10, 76).
## Bloom was invisible: four Drifters took 25 minutes with nothing on screen to say what was
## wrong, her favourite food was nowhere, Drifters looked like everypony else, and "pen full"
## was only a toast. So each Drifter gets a meter over her head, coloured by the one thing
## holding her back, the Drifter nearest the player says it in words with her favourite food
## (and whether the pantry has any), and the gate gets a count that turns into "Pen full".
##
## A SIMPLE READOUT, AND ONLY THAT (the art pass reskins it): every word and number comes from
## Pen.bloom_status(), which is the data; this file only draws it. Shown only to a camera
## within SHOW_RANGE of the pen, so the valley is not a field of floating labels. A pen of
## eight has eight meters and ONE pair of lines: the first render put words over every pony
## and they piled into an unreadable heap. Screen-sized (fixed_size), so a meter reads the
## same from the gate as from inside.

const BloomScript := preload("res://systems/bloom.gd")
const PonyTraitsScript := preload("res://systems/pony_traits.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

## Metres from the pen's middle to the camera inside which the readout shows.
const SHOW_RANGE := 17.0
## How often the words and meters are redrawn (they move slowly: minutes, not frames).
const REFRESH_SECONDS := 0.25
## Over her head: a pony is 2.14 m to the horn tip.
const TAG_HEIGHT := 2.45
const BAR_PX := Vector2i(160, 26)
## Screen-sized, so these are metres at one metre from the lens.
const BAR_PIXEL := 0.0008
const TEXT_PIXEL := 0.0007
const GATE_PIXEL := 0.0007
const INK := Color(0.2, 0.12, 0.26)
const PAPER := Color(1.0, 0.98, 0.93)
const FILL := Color(0.98, 0.52, 0.78)
const FILL_FULL := Color(1.0, 0.8, 0.25)
const STOPPED := Color(0.85, 0.3, 0.3)
const FULL_INK := Color(0.85, 0.2, 0.25)
## The meter's colour says why she is slow before any words do.
const REASON_COLOURS := {
	&"hungry": Color(0.85, 0.3, 0.3),
	&"wrong_food": Color(0.98, 0.6, 0.2),
	&"crowded": Color(0.62, 0.45, 0.85),
	&"bored": Color(0.4, 0.62, 0.95),
}

var pen: Pen
## uid -> {root: Node3D, bar: Sprite3D, image: Image, texture: ImageTexture, words: Label3D}
var _tags: Dictionary = {}
var _gate_sign: Label3D
var _t := 0.0


func _ready() -> void:
	_gate_sign = _label(64)
	_gate_sign.name = "GateSign"
	_gate_sign.pixel_size = GATE_PIXEL
	add_child(_gate_sign)
	refresh()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH_SECONDS
	refresh()


## Whether the camera is near enough for the readout to be up.
func in_range() -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or pen == null:
		return true
	return cam.global_position.distance_to(pen.global_position) <= SHOW_RANGE


## Redraw everything from the pen's own data. Public for the probes and tests.
func refresh() -> void:
	if pen == null:
		return
	var shown := in_range()
	visible = shown
	_place_gate_sign()
	var seen := {}
	var talker := _nearest_drifter_to_player()
	for inst: PonyInstance in pen.ponies():
		var body := pen.body_for(inst.uid)
		var status := pen.bloom_status(inst)
		if body == null or status.is_empty() or not bool(status["drifter"]):
			continue
		seen[inst.uid] = true
		var tag: Dictionary = _tags.get(inst.uid, {})
		if tag.is_empty():
			tag = _make_tag()
			_tags[inst.uid] = tag
		var root: Node3D = tag["root"]
		root.global_position = body.global_position + Vector3.UP * TAG_HEIGHT
		if shown:
			_draw_tag(tag, status, inst.uid == talker)
	for uid in _tags.keys():
		if not seen.has(uid):
			(_tags[uid]["root"] as Node).queue_free()
			_tags.erase(uid)


## The gate sign's words now: "3 / 8" or "Pen full".
func gate_text() -> String:
	if pen == null:
		return ""
	return "Pen full" if pen.is_full() else "%d / %d" % [pen.count(), pen.capacity]


## The words on `uid`'s tag ("" when she has none or they are not hers to show).
func tag_words(uid: StringName) -> String:
	var tag: Dictionary = _tags.get(uid, {})
	if tag.is_empty() or not (tag["words"] as Label3D).visible:
		return ""
	return (tag["words"] as Label3D).text


func tag_count() -> int:
	return _tags.size()


## Her two lines: what she is (a Drifter, Blooming or held back by what) and her favourite,
## with whether the pantry has any.
static func words_for(status: Dictionary) -> String:
	var fav: String = PonyTraitsScript.FOOD_PLURAL.get(status.get("favorite", &"hay"), "hay")
	var line := "Drifter: Blooming"
	var reason: StringName = status.get("reason", &"")
	if reason != &"":
		line = "Drifter: %s" % String(status.get("words", ""))
	var food := "Loves %s" % fav
	food += ", in the pantry" if bool(status.get("favorite_stocked", false)) else ", none in the pantry"
	return "%s\n%s" % [line, food]


## The Drifter of this pen nearest the player, who carries the words; &"" for none.
func _nearest_drifter_to_player() -> StringName:
	var player: Node3D = null
	if is_inside_tree():
		player = get_tree().get_first_node_in_group(&"player") as Node3D
	var best: StringName = &""
	var best_d := INF
	for inst: PonyInstance in pen.ponies():
		if not inst.is_stock() or inst.is_marked():
			continue
		var body := pen.body_for(inst.uid)
		if body == null:
			continue
		var d := body.global_position.distance_to(player.global_position) if player != null else 0.0
		if d < best_d:
			best_d = d
			best = inst.uid
	return best


func _draw_tag(tag: Dictionary, status: Dictionary, with_words: bool) -> void:
	var progress := clampf(float(status.get("progress", 0.0)), 0.0, 1.0)
	var stopped := not is_finite(float(status.get("seconds_left", INF)))
	var img: Image = tag["image"]
	img.fill(INK)
	var inner := Rect2i(3, 3, BAR_PX.x - 6, BAR_PX.y - 6)
	var colour: Color = REASON_COLOURS.get(status.get("reason", &""), FILL.lerp(FILL_FULL, progress))
	# The empty part is the reason's colour washed out, so even a fresh Drifter's meter
	# already says which colour (which trouble) she is.
	img.fill_rect(inner, PAPER.lerp(colour, 0.35))
	var w := int(round(float(inner.size.x) * progress))
	# At least a sliver, so a fresh Drifter's meter already says which colour she is.
	w = maxi(w, 8)
	img.fill_rect(Rect2i(inner.position, Vector2i(w, inner.size.y)), colour)
	(tag["texture"] as ImageTexture).update(img)
	var words := tag["words"] as Label3D
	words.visible = with_words
	words.text = words_for(status)
	words.modulate = STOPPED.darkened(0.2) if stopped else INK


func _make_tag() -> Dictionary:
	var root := Node3D.new()
	root.name = "BloomTag"
	add_child(root)
	var img := Image.create(BAR_PX.x, BAR_PX.y, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	var bar := Sprite3D.new()
	bar.texture = tex
	bar.pixel_size = BAR_PIXEL
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.shaded = false
	bar.fixed_size = true
	bar.no_depth_test = true
	bar.render_priority = 1
	bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bar)
	var words := _label(48)
	words.offset = Vector2(0.0, 70.0)
	words.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(words)
	return {"root": root, "bar": bar, "image": img, "texture": tex, "words": words}


func _label(size: int) -> Label3D:
	var l := Label3D.new()
	l.font = MenuStyleScript.title_font()
	l.font_size = size
	l.outline_size = int(size / 4)
	l.outline_modulate = PAPER
	l.modulate = INK
	l.pixel_size = TEXT_PIXEL
	l.shaded = false
	l.fixed_size = true
	l.no_depth_test = true
	l.render_priority = 2
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


func _place_gate_sign() -> void:
	if _gate_sign == null:
		return
	var side: int = posmod(int(round(pen.gate_yaw_degrees / 90.0)), 4)
	var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
	_gate_sign.position = outward * (Pen.HALF_EXTENT + 0.2) + Vector3.UP * (Pen.FENCE_HEIGHT + 0.35)
	_gate_sign.text = gate_text()
	_gate_sign.modulate = FULL_INK if pen.is_full() else INK
	_gate_sign.pixel_size = GATE_PIXEL * (1.3 if pen.is_full() else 1.0)
