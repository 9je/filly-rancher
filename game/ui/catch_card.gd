class_name CatchCard
extends Control
## THE CARD THAT SLIDES IN WHEN YOU CATCH A PONY. Owner playtest 2026-10-25: "i think the
## text and traits on catch can be better maybe icons and stuff instead of basic text on the
## top". The catch used to be one toast line at the top of the screen ("Caught Fluttershy!
## Skittish, loves apples."), the same pill every other passing remark uses, for the one
## moment in the loop that is a reward.
##
## WHAT IT SHOWS, all of it pictures first and a word second:
##   - HER PORTRAIT, rendered from her own body in a little SubViewport of its own (the
##     same model, paint and toon shading she wears in the field), in a round frame ringed
##     in her coat colour. Not a swatch standing in for her: her.
##   - HER NAME, in the display face.
##   - HER RARITY as stars (one to four), gold on the card, with the tier's word beside them.
##   - HER TRAITS as chips: an icon drawn here from simple shapes and a word or two. Her
##     race, her quirk (game/systems/pony_traits.gd), her favourite food, and how she holds
##     in the Scoop (magic_beam.gd's grade).
##
## A CATCH IS A MOMENT FIRST (Fable AAA round 1: "keep the data; make it a full-screen moment
## rather than a toast", after Legends Arceus' caught card). The card bursts in large at the
## centre of the screen over a dimmed backdrop with turning rays, a shock ring and sparkles in
## her rarity's colour, her stars pop in one at a time, and after MOMENT seconds it flies to its
## corner. Any click skips straight to the corner, so the moment never holds up play.
##
## WHERE IT SETTLES: the top right corner, which nothing else on the HUD uses. Never over the
## crosshair (centre) or the saddlebag (bottom left); game/test_input/test_catch_card.gd
## measures both once it has settled. It holds there, then slides back out. A second catch
## while it is up replaces it rather than queueing behind it: the newest pony is news.
##
## Built in code, like the rest of the HUD's v1 dressing (hud.gd _restyle()), so there is no
## scene to keep in step with this file. No external art: every icon is drawn by CatchIcon.

const PonyTraitsScript := preload("res://systems/pony_traits.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const CatchIconScript := preload("res://ui/catch_icon.gd")

## 1920x1080 base units, like everything else on the HUD.
const CARD_WIDTH := 600.0
const MARGIN := 44.0
const TOP := 44.0
const PORTRAIT := 168.0
const RING := 6.0

const SLIDE_IN := 0.38
const HOLD := 4.6
const SLIDE_OUT := 0.32

## THE CENTRE MOMENT: the card swells in over POP_IN, holds at MOMENT_SCALE until MOMENT, then
## flies to its corner over FLY. The stars pop STAR_GAP apart from STAR_FIRST.
const POP_IN := 0.32
const MOMENT := 1.5
const FLY := 0.42
const MOMENT_SCALE := 1.6
const STAR_FIRST := 0.30
const STAR_GAP := 0.17
const STAR_POP := 0.28
const DIM := Color(0.08, 0.03, 0.12, 0.72)
const RAY_GOLD := Color(1.0, 0.80, 0.26)
const RAY_CREAM := Color(1.0, 0.95, 0.78)
const RAY_WARM := Color(1.0, 0.91, 0.62)
const RAYS := 18
## The burst's colour per rarity: warm gold for the common run, her tier's own hue above it.
const BURST := {
	PonyDataScript.Rarity.COMMON: Color(1.0, 0.86, 0.48),
	PonyDataScript.Rarity.UNCOMMON: Color(0.62, 0.92, 0.55),
	PonyDataScript.Rarity.RARE: Color(0.55, 0.75, 1.0),
	PonyDataScript.Rarity.LEGENDARY: Color(1.0, 0.78, 0.22),
}

## The HUD's own paper and ink (hud.gd CARD_FILL / INK), restated so this file stands alone.
const FILL := Color(1.0, 0.97, 0.91, 0.96)
const LINE := Color(0.47, 0.31, 0.64)
const INK := Color(0.24, 0.17, 0.3)
const INK_SOFT := Color(0.42, 0.34, 0.48)
const RIBBON := Color(0.55, 0.36, 0.74)
const STAR_ON := Color(1.0, 0.76, 0.18)
const STAR_OFF := Color(0.86, 0.80, 0.86)

const RARITY_WORDS := {
	PonyDataScript.Rarity.COMMON: "Common",
	PonyDataScript.Rarity.UNCOMMON: "Uncommon",
	PonyDataScript.Rarity.RARE: "Rare",
	PonyDataScript.Rarity.LEGENDARY: "Legendary",
}
const RARITY_INK := {
	PonyDataScript.Rarity.COMMON: Color(0.45, 0.50, 0.45),
	PonyDataScript.Rarity.UNCOMMON: Color(0.24, 0.55, 0.26),
	PonyDataScript.Rarity.RARE: Color(0.20, 0.42, 0.78),
	PonyDataScript.Rarity.LEGENDARY: Color(0.78, 0.52, 0.04),
}
## Chip tints: a pale wash of the icon's own family, so the row reads as a set of badges.
const CHIP_TINT := {
	&"race": Color(0.90, 0.88, 0.98),
	&"quirk": Color(0.98, 0.90, 0.94),
	&"food": Color(0.93, 0.97, 0.88),
	&"hold": Color(0.97, 0.94, 0.86),
}
const HOLD_WORDS := ["Easy hold", "Tricky hold", "Tough hold"]
const NAMED_COAT := Color(0.86, 0.84, 0.90)

var _panel: PanelContainer
var _ring: Panel
var _portrait_clip: Panel
var _portrait: TextureRect
var _fallback: Control
var _ribbon: Label
var _stars: Control
var _rarity_word: Label
var _name: Label
var _chips: HFlowContainer
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _tween: Tween
var _showing := false
var _rarity := 0
var _spin := 0.0
var _shown_name := ""
var _shown_traits: Array[String] = []
## The full-screen layer behind the card during the moment, its strength, and the moment's clock.
var _burst: Control
var _burst_a := 0.0
var _moment_t := 99.0
var _in_moment := false


func _ready() -> void:
	name = "CatchCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -CARD_WIDTH - MARGIN
	offset_right = -MARGIN
	offset_top = TOP
	offset_bottom = TOP + 260.0
	_build()
	visible = false


# --- public --------------------------------------------------------------------------------

## Slide the card in for `instance`. `body` is her live body if there still is one this
## frame (MagicBeam.last_captured_body()); it is only read, to take her portrait, and never
## kept. Without one the frame shows a drawn medallion in her coat colour instead.
func show_catch(instance: PonyInstance, body: Node3D = null) -> void:
	if instance == null:
		return
	var data: PonyData = instance.data()
	var who := instance.display_name()
	if who.is_empty():
		who = "A new pony"
	_shown_name = who
	_name.text = who
	_rarity = int(data.rarity) if data != null else 0
	_rarity_word.text = String(RARITY_WORDS.get(_rarity, "Common"))
	# A Drifter is a Drifter, not "Common" (P8 item 9): the word says what she is to the ranch.
	if instance.is_stock():
		_rarity_word.text = "Bloomed Drifter" if instance.is_marked() else "Drifter"
	_rarity_word.add_theme_color_override("font_color", RARITY_INK.get(_rarity, INK_SOFT))
	_stars.queue_redraw()

	var coat := _coat_of(instance, body)
	var ring_box := StyleBoxFlat.new()
	ring_box.bg_color = coat.darkened(0.35)
	ring_box.set_corner_radius_all(int(PORTRAIT * 0.5 + RING))
	_ring.add_theme_stylebox_override(&"panel", ring_box)
	var clip_box := StyleBoxFlat.new()
	# The backdrop behind her: a pale, sky-ish wash of her own coat so a white pony and a
	# black one both stand out of it.
	clip_box.bg_color = coat.lightened(0.55).lerp(Color(0.80, 0.90, 1.0), 0.45)
	clip_box.set_corner_radius_all(int(PORTRAIT * 0.5))
	_portrait_clip.add_theme_stylebox_override(&"panel", clip_box)
	var backdrop := _portrait_clip.get_node(^"Backdrop") as Control
	backdrop.set_meta(&"coat", coat)
	backdrop.queue_redraw()
	# A gold line inside the coat ring, the card's own trim.
	ring_box.border_color = Color(1.0, 0.82, 0.36)
	ring_box.set_border_width_all(2)

	_fill_chips(instance, data)
	var has_portrait := _take_portrait(body)
	_portrait.visible = has_portrait
	_fallback.visible = not has_portrait
	_fallback.set_meta(&"coat", coat)
	_fallback.queue_redraw()

	_panel.reset_size()
	_panel.size.x = CARD_WIDTH
	# THE WORLD'S BEAT FIRST (Fable AAA round 4, #7: "no in-world beat"; an in-game strip
	# showed the sunburst landing the frame after the catch, over her flight into the Scoop,
	# the burst and the squash). The portrait is taken above, now, while her body exists; the
	# card waits until she is in the Scoop.
	_entrance_token += 1
	var token := _entrance_token
	if entrance_delay > 0.0 and is_inside_tree():
		await get_tree().create_timer(entrance_delay).timeout
		if token != _entrance_token:
			return
	_slide()


## Seconds between the catch and the card: the beam's ghost flight (MagicBeam.GHOST_SECONDS)
## and the pop after it. Tests set 0.
static var default_entrance_delay := 0.65
var entrance_delay := default_entrance_delay
var _entrance_token := 0


func is_showing() -> bool:
	return _showing and visible


## True while the card is the big centre moment rather than the corner card.
func in_moment() -> bool:
	return _in_moment and visible


## Cut the centre moment short: the card flies straight to its corner. Any click does this.
func skip_moment() -> void:
	if not in_moment():
		return
	_moment_t = 99.0
	_stars.queue_redraw()
	_settle(FLY * 0.6)


## The card's rectangle on screen, in the HUD's canvas units, at its resting place (not
## mid slide). For the test that keeps it off the crosshair and the saddlebag.
func resting_rect() -> Rect2:
	return Rect2(global_position, Vector2(CARD_WIDTH, _panel.size.y))


func shown_name() -> String:
	return _shown_name


## The chip words, in order. For the tests: what the icons are labelled.
func shown_traits() -> Array[String]:
	return _shown_traits.duplicate()


func shown_rarity() -> int:
	return _rarity


func has_portrait() -> bool:
	return _portrait.visible and _stage != null and _stage.get_child_count() > 0


# --- building ------------------------------------------------------------------------------

func _build() -> void:
	# The burst sits under the card: a full-screen layer drawn in screen space (see _process).
	_burst = Control.new()
	_burst.name = "Burst"
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst.draw.connect(_draw_burst)
	add_child(_burst)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = FILL
	box.border_color = LINE
	box.set_border_width_all(4)
	box.set_corner_radius_all(26)
	box.content_margin_left = 18
	box.content_margin_right = 22
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	box.shadow_color = Color(0.15, 0.05, 0.2, 0.28)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override(&"panel", box)
	_panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 20)
	_panel.add_child(row)

	# The portrait: a ring in her coat colour, and inside it a clipped disc she stands in.
	_ring = Panel.new()
	_ring.name = "Ring"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.custom_minimum_size = Vector2(PORTRAIT + RING * 2.0, PORTRAIT + RING * 2.0)
	_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ring)
	_portrait_clip = Panel.new()
	_portrait_clip.name = "Clip"
	_portrait_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_portrait_clip.position = Vector2(RING, RING)
	_portrait_clip.size = Vector2(PORTRAIT, PORTRAIT)
	_ring.add_child(_portrait_clip)
	# Behind her, a soft pool of light in her own coat's colours, so the disc reads as a lit
	# portrait rather than an empty plate round a cut-out.
	var backdrop := Control.new()
	backdrop.name = "Backdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.size = Vector2(PORTRAIT, PORTRAIT)
	backdrop.draw.connect(func() -> void:
		var coat: Color = backdrop.get_meta(&"coat", NAMED_COAT)
		var edge := coat.lightened(0.25).lerp(Color(0.62, 0.78, 0.95), 0.5)
		var mid := Vector2(PORTRAIT, PORTRAIT) * 0.5
		backdrop.draw_circle(mid, PORTRAIT * 0.5, edge)
		for k in 14:
			var t := float(k) / 14.0
			backdrop.draw_circle(mid + Vector2(0.0, -PORTRAIT * 0.08 * t),
				PORTRAIT * (0.5 - 0.3 * t), Color(edge.lerp(Color(1.0, 0.98, 0.9), t), 0.35)))
	_portrait_clip.add_child(backdrop)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.size = Vector2(PORTRAIT, PORTRAIT)
	_portrait_clip.add_child(_portrait)
	_fallback = Control.new()
	_fallback.name = "Medallion"
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback.size = Vector2(PORTRAIT, PORTRAIT)
	_fallback.draw.connect(_draw_medallion)
	_portrait_clip.add_child(_fallback)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 6)
	row.add_child(col)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override(&"separation", 12)
	col.add_child(top)
	_ribbon = Label.new()
	_ribbon.text = "CAUGHT!"
	var rb := StyleBoxFlat.new()
	rb.bg_color = RIBBON
	rb.set_corner_radius_all(14)
	rb.content_margin_left = 12
	rb.content_margin_right = 12
	rb.content_margin_top = 2
	rb.content_margin_bottom = 2
	_ribbon.add_theme_stylebox_override(&"normal", rb)
	_ribbon.add_theme_font_override(&"font", MenuStyleScript.title_font())
	_ribbon.add_theme_font_size_override(&"font_size", MenuStyle.font_px(18))
	_ribbon.add_theme_color_override(&"font_color", Color(1, 1, 1))
	_ribbon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_ribbon)
	_stars = Control.new()
	_stars.name = "Stars"
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.custom_minimum_size = Vector2(4 * 28.0, 28.0)
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stars.draw.connect(_draw_stars)
	top.add_child(_stars)
	_rarity_word = Label.new()
	_rarity_word.add_theme_font_override(&"font", MenuStyleScript.title_font())
	_rarity_word.add_theme_font_size_override(&"font_size", MenuStyle.font_px(19))
	_rarity_word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_rarity_word)

	_name = Label.new()
	_name.name = "Name"
	_name.add_theme_font_override(&"font", MenuStyleScript.title_font())
	_name.add_theme_font_size_override(&"font_size", MenuStyle.font_px(40))
	_name.add_theme_color_override(&"font_color", INK)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	col.add_child(_name)

	_chips = HFlowContainer.new()
	_chips.name = "Chips"
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.add_theme_constant_override(&"h_separation", 8)
	_chips.add_theme_constant_override(&"v_separation", 8)
	col.add_child(_chips)


func _fill_chips(instance: PonyInstance, data: PonyData) -> void:
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	_shown_traits.clear()
	var race: StringName = PonyTraitsScript.race_of(instance)
	_chip(&"race", race, String(race).capitalize())
	var quirk: StringName = PonyTraitsScript.quirk_of(instance)
	if quirk != &"":
		_chip(&"quirk", quirk, PonyTraitsScript.quirk_name(quirk))
	var food: StringName = PonyTraitsScript.favorite_of(instance)
	_chip(&"food", food, "Loves %s" % String(PonyTraitsScript.FOOD_PLURAL.get(food, "hay")))
	var personality: int = int(data.personality) if data != null \
		else PonyDataScript.Personality.BOLD
	var grade: int = MagicBeamScript.grade_for(personality)
	_chip(&"hold", StringName("hold_%d" % grade), HOLD_WORDS[clampi(grade, 0, 2)])


func _chip(family: StringName, icon: StringName, words: String) -> void:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = CHIP_TINT.get(family, Color(0.95, 0.93, 0.95))
	sb.border_color = Color(INK_SOFT, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 6
	sb.content_margin_right = 14
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	chip.add_theme_stylebox_override(&"panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override(&"separation", 6)
	chip.add_child(h)
	var ic: Control = CatchIconScript.new()
	ic.set("kind", icon)
	ic.custom_minimum_size = Vector2(30, 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := Label.new()
	l.text = words
	l.add_theme_font_override(&"font", MenuStyleScript.title_font())
	l.add_theme_font_size_override(&"font_size", MenuStyle.font_px(19))
	l.add_theme_color_override(&"font_color", INK)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	_chips.add_child(chip)
	_shown_traits.append(words)


# --- the portrait --------------------------------------------------------------------------

## Copy her body's visuals onto a little stage of its own and point a camera at her face.
## A COPY, not her: the body is freed at the end of the capture frame. Shares every mesh and
## material with the original, so this is a handful of nodes, not a model load.
func _take_portrait(body: Node3D) -> bool:
	_clear_stage()
	if body == null or not is_instance_valid(body):
		return false
	var vis := body.get("visuals") as Node3D
	if vis == null or vis.get_child_count() == 0:
		return false
	var source := vis.get_child(0) as Node3D
	if source == null:
		return false
	_ensure_viewport()
	var copy := source.duplicate(0) as Node3D
	if copy == null:
		return false
	copy.transform = Transform3D(Basis.from_scale(vis.scale), Vector3.ZERO)
	_stage.add_child(copy)
	# Standing, not mid-struggle: the body was copied in whatever pose the beam held her in.
	for sk in copy.find_children("*", "Skeleton3D", true, false):
		(sk as Skeleton3D).reset_bone_poses()
	var anim := copy.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation(&"idle"):
		anim.play(&"idle")
		anim.seek(0.4, true)
	_frame(copy)
	_spin = 0.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_portrait.texture = _viewport.get_texture()
	return true


func _ensure_viewport() -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.name = "PortraitViewport"
	_viewport.size = Vector2i(320, 320)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_stage = Node3D.new()
	_stage.name = "Stage"
	_viewport.add_child(_stage)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.current = true
	_viewport.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	sun.light_energy = 0.9
	_viewport.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.90, 1.0)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	_viewport.add_child(env)


## A HEAD-AND-SHOULDERS PORTRAIT, CENTRED IN THE RING (Fable AAA round 2, #10: "off-centre,
## the head cut by the ring and 60% of the circle empty"). Aimed at her head bone where the rig
## has one (her eyes are a little above it), else at the top front of her bounds; the lens
## stands in front of her and a little to her side (the models face -Z), at a distance that
## fits her head, mane and withers inside the disc whatever her size.
const HEAD_BONES := ["DEF_Head", "Head", "head", "DEF-head"]


func _frame(model: Node3D) -> void:
	var box := AABB()
	var first := true
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var b: AABB = model.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		box = AABB(Vector3(-0.5, 0.0, -0.8), Vector3(1.0, 2.0, 1.6))
	var height := box.size.y
	var head := Vector3(box.get_center().x, box.position.y + height * 0.72,
		box.position.z + box.size.z * 0.12)
	var bone := head_point(model)
	if bone != Vector3.INF:
		head = bone + Vector3.UP * height * 0.06
	# The picture's centre sits a touch under the eyes, so the ears and mane top clear the
	# ring and the withers fill its lower edge.
	var aim := head - Vector3.UP * height * 0.07
	var dist := height * 1.5
	var from := aim + Vector3(0.45, 0.1, -0.89).normalized() * dist
	_camera.look_at_from_position(from, aim, Vector3.UP)
	_camera.set_meta(&"head", aim)


## Her head bone's position in `model`'s space, or Vector3.INF on a rig without one.
static func head_point(model: Node3D) -> Vector3:
	for n in model.find_children("*", "Skeleton3D", true, false):
		var sk := n as Skeleton3D
		for name: String in HEAD_BONES:
			var i := sk.find_bone(name)
			if i >= 0:
				var world: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
				return model.global_transform.affine_inverse() * world
	return Vector3.INF


func _clear_stage() -> void:
	if _stage == null:
		return
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _coat_of(instance: PonyInstance, body: Node3D) -> Color:
	if instance.is_stock():
		var look: PonyLook = PonyLookScript.from_stock(instance.stock)
		if look != null:
			return look.coat
	if body != null and is_instance_valid(body):
		var vis := body.get("visuals") as Node3D
		if vis != null and vis.get_child_count() > 0:
			return ToonStyler.coat_color(vis.get_child(0))
	return NAMED_COAT


# --- motion --------------------------------------------------------------------------------

func _slide() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	_showing = true
	_in_moment = true
	# The big "Caught!" says it during the moment; the chip says it on the corner card
	# (Fable round 5: "the card says Caught! twice").
	_ribbon.visible = false
	_moment_t = 0.0
	modulate.a = 1.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.position = _centre_spot()
	_panel.scale = Vector2.ONE * MOMENT_SCALE * 0.55
	_panel.modulate.a = 0.0
	_burst_a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_panel, "scale", Vector2.ONE * MOMENT_SCALE, POP_IN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Opaque in a blink: the pop is the scale's (Fable round 8: a frame at 40% showed the
	# world through her name).
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.05)
	_tween.tween_property(self, "_burst_a", 1.0, 0.18)
	_tween.set_parallel(false)
	_tween.tween_interval(MOMENT - POP_IN)
	_tween.tween_callback(_settle.bind(FLY))


## Fly from wherever the card is now to its corner, then hold and slide out as it always has.
func _settle(seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_in_moment = false
	_ribbon.visible = true
	_panel.modulate.a = 1.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_panel, "position", Vector2.ZERO, seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_panel, "scale", Vector2.ONE, seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_burst_a", 0.0, seconds * 0.7)
	_tween.set_parallel(false)
	_tween.tween_interval(HOLD)
	_tween.tween_property(_panel, "position:x", CARD_WIDTH + MARGIN + 40.0, SLIDE_OUT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_hidden)


## Where the panel sits, in this control's own space, for its centre to be the screen's.
func _centre_spot() -> Vector2:
	var screen: Vector2 = get_viewport_rect().size
	var here: Vector2 = get_global_transform().affine_inverse() * (screen * 0.5)
	# A touch above centre, where the eye already is, with room for the stars' pop below.
	return here - _panel.size * 0.5 - Vector2(0.0, screen.y * 0.04)


## ANY CLICK SKIPS THE MOMENT, and that click is spent on the skip, not on the world behind.
func _input(event: InputEvent) -> void:
	if not in_moment():
		return
	var mouse := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if mouse or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		skip_moment()
		get_viewport().set_input_as_handled()


func _hidden() -> void:
	_showing = false
	_in_moment = false
	_ribbon.visible = true
	visible = false
	_burst_a = 0.0
	_clear_stage()


func _process(delta: float) -> void:
	if visible and _moment_t < 50.0:
		_moment_t += delta
		_stars.queue_redraw()
	if visible:
		# The burst covers the whole screen whatever corner this control is anchored to.
		var g: Vector2 = get_global_transform().origin
		_burst.position = -g
		_burst.size = get_viewport_rect().size
		_burst.visible = _burst_a > 0.001
		_burst.queue_redraw()
	if not visible or _camera == null or not _camera.has_meta(&"head"):
		return
	# A slow sway, so the portrait is alive rather than a pasted photo.
	_spin += delta
	if _stage != null and _stage.get_child_count() > 0:
		(_stage.get_child(0) as Node3D).rotation.y = sin(_spin * 1.3) * 0.09


# --- drawing -------------------------------------------------------------------------------

func _draw_stars() -> void:
	for i in 4:
		var c := Vector2(14.0 + i * 28.0, 14.0)
		var on := i <= _rarity
		# THE STARS POP IN ONE BY ONE during the moment: grey until their turn, then a gold
		# star that swells past its size and settles, with a ring flashing out from it.
		var k := star_pop(i)
		if on and k < 0.0:
			on = false
		var r := 12.5
		if on and k < 1.0:
			r *= 1.0 + 0.75 * sin(k * PI) * (1.0 - k * 0.5)
			_stars.draw_arc(c, 12.0 + 22.0 * k, 0.0, TAU, 24, Color(STAR_ON, 0.9 * (1.0 - k)),
				3.0 * (1.0 - k) + 0.5, true)
		# ONLY HER STARS ARE STARS (Fable AAA round 5: the same Common pony read as one star
		# on the big card and four on the small one, the three grey outlines counting as stars
		# at the corner card's size). A slot she has not earned is a small dot, never a star.
		if on:
			CatchIconScript.star(_stars, c, r, STAR_ON, Color(0.62, 0.42, 0.05))
		else:
			_stars.draw_circle(c, 3.5, Color(STAR_OFF, 0.9))


## How far star `i` is through its pop: below 0.0 not yet, 0.0 to 1.0 popping, 1.0 settled.
func star_pop(i: int) -> float:
	var k := (_moment_t - STAR_FIRST - STAR_GAP * float(i)) / STAR_POP
	return -1.0 if k < 0.0 else minf(k, 1.0)


## THE BURST BEHIND THE MOMENT, in screen space: the world dimmed, a glow, rays turning
## slowly out from behind the card, one shock ring and a ring of twinkling sparkles. Fixed
## patterns only: nothing under game/ui/ draws a random number.
func _draw_burst() -> void:
	if _burst_a <= 0.001:
		return
	var a := _burst_a
	var screen: Vector2 = _burst.size
	var c := screen * 0.5 - Vector2(0.0, screen.y * 0.04)
	var tint: Color = BURST.get(_rarity, BURST[PonyDataScript.Rarity.COMMON])
	_burst.draw_rect(Rect2(Vector2.ZERO, screen), Color(DIM, DIM.a * a))
	# THE VIGNETTE: the screen's edges sink further, so the eye has one place to go.
	var corner := screen.length() * 0.5
	for k in 10:
		var t := float(k) / 10.0
		var r_in := corner * (0.55 + 0.45 * t)
		_burst.draw_arc(c, r_in, 0.0, TAU, 72, Color(DIM, 0.07 * a), corner * 0.05 + 2.0, true)
	var reach := screen.length() * 0.6
	var turn: float = _moment_t * 0.22 if _moment_t < 50.0 else 0.0
	# THE RAYS, WITH PUNCH (Fable AAA round 2, #10: "near sky colour"): solid gold and cream
	# wedges, alternating, strong at the root and still there at the screen's edge, over a
	# dim deep enough that sky never shows through them.
	var warm := tint.lerp(Color(1.0, 0.95, 0.75), 0.25)
	for i in RAYS:
		var a0 := turn + TAU * float(i) / float(RAYS)
		var a1 := a0 + TAU / float(RAYS) * 0.5
		var ray: Color = RAY_GOLD if i % 2 == 0 else RAY_WARM
		var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * reach,
			c + Vector2(cos(a1), sin(a1)) * reach])
		_burst.draw_polygon(pts, PackedColorArray([Color(ray, 0.85 * a), Color(ray, 0.12 * a),
			Color(ray, 0.12 * a)]))
	# The glow: one smooth radial fan, bright behind the card and gone by the screen's edge.
	var glow := 560.0
	for i in 48:
		var b0 := TAU * float(i) / 48.0
		var b1 := TAU * float(i + 1) / 48.0
		_burst.draw_polygon(PackedVector2Array([c, c + Vector2(cos(b0), sin(b0)) * glow,
			c + Vector2(cos(b1), sin(b1)) * glow]), PackedColorArray([Color(RAY_CREAM, 0.55 * a),
			Color(warm, 0.0), Color(warm, 0.0)]))
	var ring_k := clampf(_moment_t / 0.55, 0.0, 1.0)
	if ring_k < 1.0:
		_burst.draw_arc(c, 160.0 + 720.0 * ring_k, 0.0, TAU, 96,
			Color(warm, 0.9 * (1.0 - ring_k) * a), 16.0 * (1.0 - ring_k) + 2.0, true)
	for i in 14:
		var ang := TAU * float(i) / 14.0 + 0.3 * float(i % 3)
		var dist := 470.0 + 90.0 * float((i * 7) % 5) + 30.0 * sin(_moment_t * 1.5 + float(i))
		var p := c + Vector2(cos(ang) * dist * 1.25, sin(ang) * dist * 0.7)
		var tw := 0.5 + 0.5 * sin(_moment_t * 7.0 + float(i) * 1.9)
		_sparkle(p, 9.0 + 9.0 * tw, Color(1.0, 0.95, 0.7, (0.4 + 0.6 * tw) * a))
	if _moment_t > 50.0:
		return
	# THE WORD: "Caught!" lands over the card. Her stars are the card's own, popping in one by
	# one at the card's moment size (round 2, #10: the stars were drawn twice, once on the
	# card and again as a big row under it).
	var half: float = _panel.size.y * _panel.scale.y * 0.5
	# This leaves faster than the rays, so nothing big lingers once the card has flown.
	a *= a
	var font: Font = MenuStyleScript.title_font()
	var land := clampf(_moment_t / 0.26, 0.0, 1.0)
	var px := int(round(96.0 * (1.0 + 0.5 * (1.0 - land) * (1.0 - land))))
	var word := "Caught!"
	var wsize: Vector2 = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var wat := Vector2(c.x - wsize.x * 0.5, c.y - half - 44.0)
	var wcol := Color(1.0, 0.86, 0.32, a * land)
	_burst.draw_string_outline(font, wat, word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 22,
		Color(0.25, 0.08, 0.3, a * land))
	_burst.draw_string(font, wat, word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, wcol)


func _sparkle(p: Vector2, r: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := -PI * 0.5 + TAU * float(i) / 8.0
		var rr := r if i % 2 == 0 else r * 0.26
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	_burst.draw_colored_polygon(pts, colour)


func _draw_medallion() -> void:
	var coat: Color = _fallback.get_meta(&"coat", NAMED_COAT)
	var c := _fallback.size * 0.5
	_fallback.draw_circle(c, PORTRAIT * 0.36, coat)
	CatchIconScript.horseshoe(_fallback, c, PORTRAIT * 0.2, coat.darkened(0.45))
