class_name PenReadout
extends Node3D
## ONE BADGE PER PEN (P9, playtest 2026-11-10 item 32, reported three times in one session).
## The P8 readout put a meter over every Drifter, two lines of words over the nearest one and
## "3 / 8" or a big red "Pen full" over the gate: at a pen of eight that was eight bars, two
## lines and a sign, all floating, all no-depth-test, piled on each other, on the price signs
## and on the objective banner. The house rule is no floating text in the world.
##
## So a pen shows one small badge over its gate post and nothing else:
##   [ mood icon in a Bloom ring | 3/8 ]
##   - THE MOOD ICON is what holds her Drifters back, the most pressing first (hungry: hay on a
##     red ring; wants her favourite: that food; crowded: the full-pen icon; bored: the friends
##     icon), or the Bloom flower when nothing does. No Drifters, no icon.
##   - THE RING around it fills with the furthest-along Drifter's Bloom.
##   - THE COUNT is residents over room. A full pen turns the whole badge gold: "full" is a
##     colour, not a word.
## Every number and reason still comes from Pen.bloom_status(), which is the data; this file
## only draws it. Shown only to a camera within SHOW_RANGE, and never in the top band of the
## screen where the compass and the objective banner live.

const BloomScript := preload("res://systems/bloom.gd")
const PonyTraitsScript := preload("res://systems/pony_traits.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const IconSetScript := preload("res://ui/icon_set.gd")

## Metres from the pen's middle to the camera inside which the badge shows.
const SHOW_RANGE := 17.0
## How often the badge is re-read (Bloom moves in minutes, not frames).
const REFRESH_SECONDS := 0.25
## The badge is hidden while its centre sits above this fraction of the screen height (the
## compass and the objective banner's band).
const TOP_BAND := 0.2
## The badge's texture, in pixels, and its size on screen (fixed_size: metres at 1 m).
const TEX := Vector2i(232, 96)
const BADGE_PIXEL := 0.00075
## Over the gate post: the fence is 1.1 m, the badge floats a little over it.
const LIFT := 0.75

const PLUM := Color(0.22, 0.12, 0.28, 0.94)
const EDGE := Color(0.88, 0.72, 0.42)
const CREAM := Color(1.0, 0.96, 0.86)
const GOLD := Color(1.0, 0.8, 0.28)
const INK := Color(0.2, 0.12, 0.26)
const RING_EMPTY := Color(1.0, 1.0, 1.0, 0.18)
const BLOOM_PINK := Color(0.98, 0.52, 0.78)
## The ring's colour says why she is slow before the icon is even read.
const REASON_COLOURS := {
	&"hungry": Color(0.92, 0.32, 0.3),
	&"wrong_food": Color(0.98, 0.6, 0.2),
	&"crowded": Color(0.66, 0.5, 0.9),
	&"bored": Color(0.42, 0.66, 0.98),
}
## Which trouble is named first when the Drifters disagree: the one to fix first.
const REASON_ORDER: Array[StringName] = [&"hungry", &"wrong_food", &"crowded", &"bored"]
const REASON_ICONS := {&"hungry": "hay", &"crowded": "full", &"bored": "social"}

var pen: Pen
var _viewport: SubViewport
var _face: Control
var _sprite: Sprite3D
var _state: Dictionary = {}
var _t := 0.0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "BadgeViewport"
	_viewport.size = TEX
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_face = BadgeFace.new()
	_face.size = Vector2(TEX)
	_viewport.add_child(_face)
	_sprite = Sprite3D.new()
	_sprite.name = "Badge"
	_sprite.texture = _viewport.get_texture()
	_sprite.pixel_size = BADGE_PIXEL
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.fixed_size = true
	_sprite.no_depth_test = true
	_sprite.render_priority = 1
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)
	refresh()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH_SECONDS
	refresh()


## Whether the camera is near enough for the badge to be up.
func in_range() -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or pen == null:
		return true
	return cam.global_position.distance_to(pen.global_position) <= SHOW_RANGE


## Re-read the pen and redraw the badge if anything on it changed. Public for probes and tests.
func refresh() -> void:
	if pen == null:
		return
	_place()
	var shown := in_range() and not _in_top_band()
	if _sprite != null:
		_sprite.visible = shown
	var state := badge_state(pen)
	if state != _state and _face != null:
		_state = state
		_face.set("state", state)
		_face.queue_redraw()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## EVERYTHING THE BADGE SAYS, as data: count, capacity, full, drifters (how many), reason (the
## most pressing trouble, &"" for none), food (her favourite, for wrong_food), progress (the
## furthest-along Drifter's Bloom, 0..1).
static func badge_state(p: Pen) -> Dictionary:
	var out := {"count": p.count(), "capacity": p.capacity, "full": p.is_full(),
		"drifters": 0, "reason": &"", "food": &"", "progress": 0.0}
	var worst := REASON_ORDER.size()
	for inst: PonyInstance in p.ponies():
		var status := p.bloom_status(inst)
		if status.is_empty() or not bool(status.get("drifter", false)):
			continue
		out["drifters"] = int(out["drifters"]) + 1
		out["progress"] = maxf(float(out["progress"]), clampf(float(status.get("progress", 0.0)), 0.0, 1.0))
		var at := REASON_ORDER.find(status.get("reason", &""))
		if at >= 0 and at < worst:
			worst = at
			out["reason"] = REASON_ORDER[at]
			out["food"] = status.get("favorite", &"hay")
	# Snapped, so a meter creeping by a hair does not redraw the badge four times a second.
	out["progress"] = snappedf(float(out["progress"]), 0.02)
	return out


## The icon the badge shows for `state` ("" for none).
static func icon_for(state: Dictionary) -> String:
	if int(state.get("drifters", 0)) <= 0:
		return ""
	var reason: StringName = state.get("reason", &"")
	if reason == &"wrong_food":
		return String(state.get("food", &"hay"))
	if reason == &"":
		return "bloom"
	return String(REASON_ICONS.get(reason, "bloom"))


## What the count says: "3/8". The words "Pen full" are gone from the world (item 32).
func gate_text() -> String:
	if pen == null:
		return ""
	return "%d/%d" % [pen.count(), pen.capacity]


## A Drifter's trouble in words, for places that are allowed words (the pen prompt, tests).
static func words_for(status: Dictionary) -> String:
	var fav: String = PonyTraitsScript.FOOD_PLURAL.get(status.get("favorite", &"hay"), "hay")
	var line := "Drifter: Blooming"
	var reason: StringName = status.get("reason", &"")
	if reason != &"":
		line = "Drifter: %s" % String(status.get("words", ""))
	var food := "Loves %s" % fav
	food += ", in the pantry" if bool(status.get("favorite_stocked", false)) else ", none in the pantry"
	return "%s\n%s" % [line, food]


## The badge sprite, for probes and tests.
func badge() -> Sprite3D:
	return _sprite


## No more per-pony tags: kept so older probes still run.
func tag_count() -> int:
	return 0


func tag_words(_uid: StringName) -> String:
	return ""


func _place() -> void:
	if _sprite == null:
		return
	var side: int = posmod(int(round(pen.gate_yaw_degrees / 90.0)), 4)
	var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
	_sprite.position = outward * (Pen.HALF_EXTENT + 0.1) + Vector3.UP * (Pen.FENCE_HEIGHT + LIFT)


func _in_top_band() -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or _sprite == null:
		return false
	var at := _sprite.global_position
	if cam.is_position_behind(at):
		return true
	var h := get_viewport().get_visible_rect().size.y
	return cam.unproject_position(at).y < h * TOP_BAND


## THE DRAWING: a plum pill, the mood icon in its ring on the left, the count on the right.
class BadgeFace extends Control:
	var state: Dictionary = {}

	func _draw() -> void:
		if state.is_empty():
			return
		var full := bool(state.get("full", false))
		var icon := PenReadout.icon_for(state)
		var font: Font = MenuStyleScript.numeral_font()
		var fs := 46
		var text := "%d/%d" % [int(state.get("count", 0)), int(state.get("capacity", 0))]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var h := 84.0
		var ring := 72.0
		var w := tw + 44.0 + (ring + 10.0 if icon != "" else 0.0)
		var x0 := (size.x - w) * 0.5
		var box := StyleBoxFlat.new()
		box.bg_color = PenReadout.GOLD if full else PenReadout.PLUM
		box.border_color = PenReadout.CREAM if full else PenReadout.EDGE
		box.set_border_width_all(4)
		box.set_corner_radius_all(int(h * 0.5))
		box.anti_aliasing = true
		box.shadow_color = Color(0, 0, 0, 0.25)
		box.shadow_size = 3
		draw_style_box(box, Rect2(x0, (size.y - h) * 0.5, w, h))
		var tx := x0 + 22.0
		if icon != "":
			var c := Vector2(x0 + 6.0 + ring * 0.5, size.y * 0.5)
			var reason: StringName = state.get("reason", &"")
			var col: Color = PenReadout.REASON_COLOURS.get(reason, PenReadout.BLOOM_PINK)
			draw_circle(c, ring * 0.5, PenReadout.PLUM.darkened(0.2))
			draw_circle(c, ring * 0.5 - 8.0, PenReadout.CREAM)
			draw_arc(c, ring * 0.5 - 4.0, 0.0, TAU, 48, PenReadout.RING_EMPTY, 7.0, true)
			var p := clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
			# Never empty: even a fresh Drifter's ring shows its colour (its trouble).
			p = maxf(p, 0.06)
			draw_arc(c, ring * 0.5 - 4.0, -PI * 0.5, -PI * 0.5 + TAU * p, 48, col, 7.0, true)
			var r := ring * 0.5 - 11.0
			IconSetScript.draw(self, icon, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
			tx = x0 + 6.0 + ring + 12.0
		var ink := PenReadout.INK if full else PenReadout.CREAM
		var base := size.y * 0.5 + font.get_ascent(fs) * 0.5 - font.get_descent(fs) * 0.35
		draw_string(font, Vector2(tx, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
