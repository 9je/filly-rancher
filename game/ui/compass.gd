class_name Compass
extends Control
## THE COMPASS STRIP: a slim band across the top of the screen with an icon for each place
## that matters, slid left and right by where the camera faces (owner playtest 2026-10-25:
## "i cant find the market", "i dont like how hard it is to find the build area"). Icons, not
## words: the same painted icons the signs in the world carry (world/place_sign.gd), so a
## coin on the strip and a coin on the Market's sign are one idea. A place behind her slides
## off the strip's ends; one close by fades, since she can see it already.

const PlaceSignScript := preload("res://world/place_sign.gd")
const HouseStyleScript := preload("res://ui/house_style.gd")

## Degrees of view the strip spans, end to end.
const SPAN_DEGREES := 150.0
## A THIN STRIP OF ICONS, NOT A BAR OVER THE SCENE (Fable AAA review round 1, #3: "a compass
## bar"). It was a 46 px cream box across the top of the view; it is a hairline of gold on a
## plum band that fades to nothing at both ends, the icons riding it on small discs.
const WIDTH := 700.0
const HEIGHT := 40.0
const ICON := 28.0
const TOP := 16.0
## Closer than this a place's icon fades out: she is already there.
const NEAR_METRES := 9.0

## [{name, icon, node}]: what the strip points at. ranch.gd fills it.
var places: Array[Dictionary] = []
var camera_provider: Callable
var player: Node3D

var _icons: Array[TextureRect] = []
var _back: Panel
## THE GUIDE'S GOAL (game/systems/guide.gd): its own icon in a gold ring, never faded, and
## pinned to the strip's end when it is behind her, so the strip always says which way.
var _goal: Node3D
var _goal_mark: Control
var _goal_icon: TextureRect
var _goal_dist: Label
var _goal_chevron: Label
var _cardinals: Array[Label] = []
var _clock := 0.0

## [letter, world direction]: north is minus Z on this map (Happenings' old compass words
## used the same convention).
const CARDINALS := [["N", Vector3(0, 0, -1)], ["E", Vector3(1, 0, 0)], ["S", Vector3(0, 0, 1)],
	["W", Vector3(-1, 0, 0)], ["NE", Vector3(1, 0, -1)], ["SE", Vector3(1, 0, 1)],
	["SW", Vector3(-1, 0, 1)], ["NW", Vector3(-1, 0, -1)]]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	_back = Panel.new()
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_back.draw.connect(_draw_band)
	add_child(_back)
	# The facing mark: a small gold pointer under the strip's middle.
	var tick := ColorRect.new()
	tick.name = "Tick"
	tick.color = Color(0, 0, 0, 0)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.draw.connect(func() -> void:
		var w := tick.size.x
		tick.draw_colored_polygon(PackedVector2Array([Vector2(0, tick.size.y), Vector2(w, tick.size.y),
			Vector2(w * 0.5, 0)]), HouseStyleScript.GOLD)
		tick.draw_polyline(PackedVector2Array([Vector2(0, tick.size.y), Vector2(w * 0.5, 0),
			Vector2(w, tick.size.y)]), HouseStyleScript.PLUM_DARK, 1.5, true))
	add_child(tick)
	_goal_mark = Control.new()
	_goal_mark.name = "Goal"
	_goal_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_mark.size = Vector2(ICON + 12.0, ICON + 12.0)
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rb := HouseStyleScript.disc_box(ICON + 12.0, HouseStyleScript.KEY_FACE, HouseStyleScript.GOLD, 3)
	rb.shadow_color = Color(1.0, 0.8, 0.3, 0.6)
	rb.shadow_size = 6
	ring.add_theme_stylebox_override("panel", rb)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goal_mark.add_child(ring)
	_goal_icon = TextureRect.new()
	_goal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_goal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_goal_icon.position = Vector2(6, 6)
	_goal_icon.size = Vector2(ICON, ICON)
	_goal_mark.add_child(_goal_icon)
	_goal_mark.visible = false
	add_child(_goal_mark)
	# HOW FAR, AND WHICH WAY ROUND (PT8: "needs a bit more"): the goal's distance in a small pill
	# under its ring, and a chevron beside it when it is behind her and pinned to an end.
	_goal_dist = Label.new()
	_goal_dist.name = "GoalDistance"
	HouseStyleScript.ink_label(_goal_dist, 15, HouseStyleScript.GOLD)
	_goal_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_dist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_dist.add_theme_stylebox_override("normal", HouseStyleScript.pill_box(9, 0.88,
		Vector2(7, 0)))
	_goal_dist.visible = false
	add_child(_goal_dist)
	_goal_chevron = Label.new()
	_goal_chevron.name = "GoalChevron"
	HouseStyleScript.ink_label(_goal_chevron, 26, HouseStyleScript.GOLD)
	_goal_chevron.add_theme_constant_override(&"outline_size", 6)
	_goal_chevron.add_theme_color_override(&"font_outline_color", HouseStyleScript.PLUM_DARK)
	_goal_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_chevron.visible = false
	add_child(_goal_chevron)
	# NORTH, EAST, SOUTH, WEST (PT8: Tumble's "north-east" meant nothing with no N anywhere).
	for c: Array in CARDINALS:
		var l := Label.new()
		l.name = "Cardinal" + String(c[0])
		l.text = String(c[0])
		# On the band itself, in gold: the cardinal letters are the strip's own ticks. Read at a
		# glance at 720 p (Fable AAA round 2, #9: "SE S SW" were 8 px): the four big and gold,
		# the four between in cream, all with a plum outline so they hold on sky or grass.
		var major := String(c[0]).length() == 1
		HouseStyleScript.ink_label(l, 28 if major else 21,
			HouseStyleScript.GOLD if major else HouseStyleScript.CREAM)
		l.add_theme_constant_override(&"outline_size", 7)
		l.add_theme_color_override(&"font_outline_color", HouseStyleScript.PLUM_DARK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.size = Vector2(44, HEIGHT)
		add_child(l)
		_cardinals.append(l)


## Light `node` as the goal with place icon `icon` (PlaceSign.Icon), or none for null.
func set_goal(node: Node3D, icon: int) -> void:
	_goal = node
	if node != null:
		_goal_icon.texture = PlaceSignScript.icon_texture(icon)


## The goal marker as drawn now: {visible, x}. For the suite.
func goal_state() -> Dictionary:
	return {"visible": _goal_mark.visible,
		"x": _goal_mark.position.x + _goal_mark.size.x * 0.5 - _left()}


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
		# A MAP BADGE, NOT A STICKER (PT8; playtest 2026-11-05: "the icons suck"): each place
		# sits on a cream disc ringed in its own colour, drawn behind the painted icon.
		var badge := Panel.new()
		badge.name = "Badge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.show_behind_parent = true
		var bb := HouseStyleScript.disc_box(ICON + 8.0, HouseStyleScript.KEY_FACE,
			PlaceSignScript.ICON_COLOURS.get(int(p.get("icon", 0)), HouseStyleScript.GOLD_DIM), 2)
		bb.shadow_color = Color(0, 0, 0, 0.25)
		bb.shadow_size = 3
		badge.add_theme_stylebox_override("panel", bb)
		badge.position = Vector2(-4, -4)
		badge.size = Vector2(ICON + 8.0, ICON + 8.0)
		r.add_child(badge)
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
	# A place the guide has lit is drawn as the gold goal ring instead of its own icon.
	if i < places.size() and places[i].get("node") == _goal and _goal_mark.visible:
		var g := goal_state()
		return {"visible": true, "x": g.x, "alpha": 1.0}
	var r := _icons[i]
	return {"visible": r.visible, "x": r.position.x + ICON * 0.5 - _left(), "alpha": r.modulate.a}


func _left() -> float:
	return (get_viewport_rect().size.x - WIDTH) * 0.5


func _process(delta: float) -> void:
	_clock += delta
	var cam: Camera3D = camera_provider.call() if camera_provider.is_valid() else get_viewport().get_camera_3d()
	var vw := get_viewport_rect().size.x
	var left := (vw - WIDTH) * 0.5
	_back.position = Vector2(left, TOP)
	_back.size = Vector2(WIDTH, HEIGHT)
	var tick := get_node(^"Tick") as ColorRect
	tick.position = Vector2(vw * 0.5 - 6.0, TOP + HEIGHT + 1.0)
	tick.size = Vector2(12.0, 8.0)
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
		if node == _goal:
			r.visible = false
	_goal_mark.visible = _goal != null and is_instance_valid(_goal)
	if _goal_mark.visible:
		var gto := _goal.global_position - from
		var gu := clampf(strip_position(bearing(forward, gto)), 0.05, 0.95)
		var pulse := 1.0 + 0.08 * sin(_clock * 4.0)
		_goal_mark.pivot_offset = _goal_mark.size * 0.5
		_goal_mark.scale = Vector2.ONE * pulse
		_goal_mark.position = Vector2(left + gu * WIDTH - _goal_mark.size.x * 0.5,
			TOP + (HEIGHT - _goal_mark.size.y) * 0.5)
		var metres := Vector2(gto.x, gto.z).length()
		_goal_dist.visible = metres > NEAR_METRES * 0.5
		_goal_dist.text = "%d m" % int(round(metres))
		_goal_dist.size = _goal_dist.get_combined_minimum_size()
		_goal_dist.position = Vector2(left + gu * WIDTH - _goal_dist.size.x * 0.5, TOP + HEIGHT + 4.0)
		var raw := strip_position(bearing(forward, gto))
		_goal_chevron.visible = raw < 0.05 or raw > 0.95
		_goal_chevron.text = "<" if raw < 0.5 else ">"
		_goal_chevron.size = _goal_chevron.get_combined_minimum_size()
		var side := -_goal_chevron.size.x - 4.0 if raw < 0.5 else _goal_mark.size.x + 4.0
		_goal_chevron.position = Vector2(_goal_mark.position.x + side,
			TOP + (HEIGHT - _goal_chevron.size.y) * 0.5)
	else:
		_goal_dist.visible = false
		_goal_chevron.visible = false
	_unstack(from)
	_place_cardinals(forward, left)


## NO TWO MARKS ON ONE SPOT (review 2026-11-11: the Depot's crate badge sat half under the
## goal's star). A place badge that would overlap the goal ring gives way to it; of two
## badges that overlap, the nearer place keeps the spot.
func _unstack(from: Vector3) -> void:
	var gap := ICON * 0.85
	var goal_x := INF
	if _goal_mark.visible:
		goal_x = _goal_mark.position.x + _goal_mark.size.x * 0.5
	var shown: Array[int] = []
	for i in _icons.size():
		var r := _icons[i]
		if not r.visible:
			continue
		var cx := r.position.x + ICON * 0.5
		if absf(cx - goal_x) < gap:
			r.visible = false
			continue
		shown.append(i)
	shown.sort_custom(func(a: int, b: int) -> bool:
		var na := places[a].get("node") as Node3D
		var nb := places[b].get("node") as Node3D
		return na.global_position.distance_to(from) < nb.global_position.distance_to(from))
	var kept: Array[float] = []
	for i in shown:
		var cx := _icons[i].position.x + ICON * 0.5
		var clash := false
		for k in kept:
			if absf(cx - k) < gap:
				clash = true
				break
		if clash:
			_icons[i].visible = false
		else:
			kept.append(cx)


## THE LETTERS GIVE WAY TO THE BADGES (Fable AAA round 4: "W" and "SE" hidden under waypoint
## icons). Each letter rides the band where its bearing lands, and fades out as a place's
## badge (or the goal ring) slides over it, coming back as the badge moves on, so a letter is
## either readable or gone, never half covered.
## Air, in pixels, between a letter's ink and a badge's rim for the letter to show in full; it
## is gone by the time the two touch.
const LETTER_AIR := 10.0


func _place_cardinals(forward: Vector3, left: float) -> void:
	var covers: Array[float] = []
	for r: TextureRect in _icons:
		if r.visible and r.modulate.a > 0.2:
			covers.append(r.position.x + ICON * 0.5)
	if _goal_mark.visible:
		covers.append(_goal_mark.position.x + _goal_mark.size.x * 0.5)
	for k in _cardinals.size():
		var cu := strip_position(bearing(forward, CARDINALS[k][1]))
		var cl := _cardinals[k]
		cl.visible = cu > 0.04 and cu < 0.96
		# On the band, between the badges.
		var cx: float = left + cu * WIDTH
		cl.position = Vector2(cx - cl.size.x * 0.5, TOP)
		var font := cl.get_theme_font(&"font")
		var half: float = font.get_string_size(cl.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			cl.get_theme_font_size(&"font_size")).x * 0.5 if font != null else 12.0
		var touch: float = half + ICON * 0.5 + 4.0
		var clear := 1.0
		for x: float in covers:
			clear = minf(clear, clampf((absf(x - cx) - touch) / LETTER_AIR, 0.0, 1.0))
		cl.modulate.a = clampf(minf(cu - 0.04, 0.96 - cu) / 0.1, 0.0, 1.0) \
			* (1.0 if k < 4 else 0.85) * clear


## THE BAND: plum, fading to nothing at both ends, with a gold hairline along its middle that
## fades with it. Drawn rather than boxed, so the strip has no corners to sit over the scene.
func _draw_band() -> void:
	var w := _back.size.x
	var h := _back.size.y
	var fade := w * 0.16
	var deep := Color(HouseStyleScript.PLUM_DARK, 0.62)
	var clear := Color(HouseStyleScript.PLUM_DARK, 0.0)
	var xs := [0.0, fade, w - fade, w]
	var cs := [clear, deep, deep, clear]
	for i in 3:
		_back.draw_polygon(PackedVector2Array([Vector2(xs[i], 0), Vector2(xs[i + 1], 0),
			Vector2(xs[i + 1], h), Vector2(xs[i], h)]),
			PackedColorArray([cs[i], cs[i + 1], cs[i + 1], cs[i]]))
	var gold := Color(HouseStyleScript.GOLD, 0.85)
	for edge_y: float in [0.5, h - 0.5]:
		_back.draw_line(Vector2(fade, edge_y), Vector2(w - fade, edge_y), gold, 1.5)
		# draw_line takes one colour: the fades are drawn as short graded steps.
		for k in 12:
			var t0 := float(k) / 12.0
			var t1 := float(k + 1) / 12.0
			_back.draw_line(Vector2(fade * t0, edge_y), Vector2(fade * t1, edge_y),
				Color(gold, t1 * gold.a), 1.5)
			_back.draw_line(Vector2(w - fade * t1, edge_y), Vector2(w - fade * t0, edge_y),
				Color(gold, t1 * gold.a), 1.5)
