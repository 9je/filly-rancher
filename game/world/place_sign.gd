class_name PlaceSign
extends Node3D
## A PAINTED SHOP SIGN: a wooden board with an icon and the place's name, hung over a door or
## nailed to a signpost (owner playtest 2026-10-25: "i cant find the market", "i dont like how
## hard it is to find the build area"). Signs, not floating words: a board with a frame, a
## painted icon and lettering, lit by the same sun as the wall it hangs on.
##
## The icons are drawn here from shapes, once each, so a fresh checkout without the converted
## assets still has its signs.

const MenuStyleScript := preload("res://ui/menu_style.gd")

enum Icon { COIN, CRATE, HOUSE, SCROLL, FENCE, STAR, ARROW }

const WOOD := Color(0.55, 0.36, 0.22)
const WOOD_DARK := Color(0.33, 0.21, 0.13)
const PAPER := Color(0.97, 0.92, 0.8)
const INK := Color(0.24, 0.15, 0.3)
const ICON_COLOURS := {
	Icon.COIN: Color(0.98, 0.78, 0.2), Icon.CRATE: Color(0.78, 0.54, 0.3),
	Icon.HOUSE: Color(0.93, 0.45, 0.5), Icon.SCROLL: Color(0.55, 0.7, 0.95),
	Icon.FENCE: Color(0.5, 0.75, 0.38), Icon.STAR: Color(0.92, 0.5, 0.95),
	Icon.ARROW: Color(0.96, 0.7, 0.3),
}

## Each Icon's picture in the icon set (tools/make_icons.py).
const ICON_NAMES := {
	Icon.COIN: "coin", Icon.CRATE: "crate", Icon.HOUSE: "house", Icon.SCROLL: "letter",
	Icon.FENCE: "fence", Icon.STAR: "star", Icon.ARROW: "arrow",
}

## A SIGN STEPS ASIDE FOR THE LENS (overnight bot review, 2026-10-26: the board beside the
## Depot's door filled the screen whenever the third-person camera came up behind it). Solid
## past FAR_M from the camera, MAX_FADE see-through at NEAR_M and closer, measured to the
## nearest point of the board rather than its middle, so a wide board fades at its end too.
const NEAR_M := 1.2
const FAR_M := 3.0
const MAX_FADE := 0.92
## A board on the line from the lens to `subject` (the player; ranch.gd sets it) fades this
## far at any distance: half faded it was a grey sheet across the screen (feel pass
## 2026-10-26, the Pens board at the pen's gate).
const BLOCKING_FADE := 0.96
## At or past this fade the board is not drawn at all.
const HIDE_AT := 0.85
## SOLID OR GONE, WITH ROOM BETWEEN (PT7; playtest 2026-11-05: "basically all signs flicker").
## A half faded board showed its dark frame through its paper (the fingerpost's dark Home and
## Pens), and one on the edge of the fade flipped as the camera breathed. Now a board goes
## when the lens is within HIDE_M of it or it stands between the lens and her, and comes back
## only once the lens is past SHOW_M and it is out of the way.
## P8 (playtest 2026-11-08 item 43: "signs disappear at a right angle", "all signs do that"):
## the line test padded the board 15 cm all round, so a board seen side-on, covering a sliver
## of the screen, counted as in the way and vanished. Now only a board whose FACE the line
## crosses, seen at least FACE_ON off edge-on, gets out of her way; side-on it always stays.
## P9 item 67: a board at the very edge of the screen still filled a quarter of it at 1 m;
## it now steps aside within 1.3 m and comes back past 2.0.
const HIDE_M := 1.3
const SHOW_M := 2.0
## The sine of how far off edge-on the lens must look through a board before it counts as
## in the way (0.5: thirty degrees).
const FACE_ON := 0.5
const LayersScript := preload("res://world/collision_layers.gd")
static var subject: Node3D = null

var text := ""
var icon := Icon.COIN
var _half := Vector3(0.6, 0.3, 0.1)
var _fade := 0.0


## A board `width` by `height` m facing local +Z, its icon on the left and `label` beside it.
## `point` > 0 cuts the right end into an arrow head (a signpost finger).
func build(label: String, icon_kind: int, width: float, height: float, point: float = 0.0,
		two_sided: bool = false) -> void:
	text = label
	icon = icon_kind
	_half = Vector3((width + 0.16) * 0.5 + point, (height + 0.16) * 0.5, 0.1)
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(width + 0.16, height + 0.16, 0.08)
	frame.mesh = fm
	frame.material_override = _mat(WOOD_DARK)
	add_child(frame)
	# SOLID (item 43: "you walk through them"): the board stops her and the herd like any prop.
	var body := StaticBody3D.new()
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 0.16 + point, height + 0.16, 0.14)
	shape.shape = box
	shape.position = Vector3(point * 0.5, 0.0, 0.0)
	body.add_child(shape)
	add_child(body)
	var face := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, height, 0.12)
	face.mesh = bm
	# THE PAPER IS ALWAYS READABLE (PT7): lit like the wood, a board turned from the sun or
	# out in a storm went grey brown and its lettering went with it ("signs dont have white
	# bg"). Painted, unlit, a little under white so it does not glow at night.
	var paper := _mat(PAPER.darkened(0.06))
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face.material_override = paper
	add_child(face)
	if point > 0.0:
		var tip := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(height + 0.16, point, 0.08)
		tip.mesh = pm
		tip.material_override = _mat(WOOD_DARK)
		tip.rotation_degrees = Vector3(0, 0, -90)
		tip.position = Vector3(width * 0.5 + 0.08 + point * 0.5, 0, 0)
		add_child(tip)
	_paint_face(label, icon_kind, width, height, false)
	if two_sided:
		_paint_face(label, icon_kind, width, height, true)


## The icon and the lettering on one face; `back` paints the -Z face, turned to read.
func _paint_face(label: String, icon_kind: int, width: float, height: float, back: bool) -> void:
	var holder := Node3D.new()
	add_child(holder)
	if back:
		holder.rotation_degrees = Vector3(0, 180, 0)
	var s := height * 0.78
	var ic := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	ic.mesh = q
	var im := StandardMaterial3D.new()
	im.albedo_texture = icon_texture(icon_kind)
	im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	im.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ic.material_override = im
	ic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# CLEAR OF THE PAPER (PT7): 6 mm off a 60 mm face z-fought at a distance, the white
	# flickering through the letters; the icon and the letters now stand 18 and 20 mm off it.
	ic.position = Vector3(-width * 0.5 + height * 0.55, 0, 0.078)
	holder.add_child(ic)
	var l := Label3D.new()
	l.text = label
	l.font = MenuStyleScript.title_font()
	l.font_size = 128
	l.outline_size = 0
	l.modulate = INK
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sized to fill the board's height, then narrowed if the name is long.
	var px := height * 0.95 / 128.0
	var room := width - height * 1.25
	var est := float(label.length()) * 128.0 * 0.58 * px
	if est > room and est > 0.0:
		px *= room / est
	l.pixel_size = px
	# Centred in the room right of the icon.
	l.position = Vector3(height * 0.55, 0, 0.08)
	holder.add_child(l)


## 0.0 while the board is drawn, 1.0 while it is stood aside for the lens.
func fade() -> float:
	return _fade


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		update_fade(cam)


func update_fade(cam: Camera3D) -> void:
	var local := to_local(cam.global_position)
	var nearest := local.clamp(-_half, _half)
	var d := local.distance_to(nearest)
	var blocking := false
	if subject != null and is_instance_valid(subject) and subject.is_inside_tree():
		var aim := to_local(subject.global_position + Vector3(0, 1.0, 0))
		var through := (aim - local).normalized()
		blocking = absf(through.z) >= FACE_ON and _segment_hits_box(local, aim,
			Vector3(_half.x + 0.05, _half.y + 0.05, _half.z))
	var gone := _fade >= 1.0
	if blocking or d < HIDE_M:
		gone = true
	elif d > SHOW_M - 0.001:
		gone = false
	var f := 1.0 if gone else 0.0
	if f == _fade:
		return
	_fade = f
	for g: Node in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).transparency = 0.0
		(g as GeometryInstance3D).visible = not gone


## Does the segment a..b pass through the box of half extents `h` at the origin? (Slabs.)
static func _segment_hits_box(a: Vector3, b: Vector3, h: Vector3) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for i in 3:
		if absf(d[i]) < 0.00001:
			if a[i] < -h[i] or a[i] > h[i]:
				return false
			continue
		var u := (-h[i] - a[i]) / d[i]
		var v := (h[i] - a[i]) / d[i]
		if u > v:
			var w := u
			u = v
			v = w
		t0 = maxf(t0, u)
		t1 = minf(t1, v)
		if t0 > t1:
			return false
	return true


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


## The icon for `kind`, from the icon set.
static func icon_texture(kind: int) -> ImageTexture:
	# The one icon set (P8 S5, game/ui/icon_set.gd) replaces the per-pixel drawing that was here.
	return IconSet.texture(ICON_NAMES.get(kind, "star"), 128)
