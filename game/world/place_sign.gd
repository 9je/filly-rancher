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

static var _icon_cache: Dictionary = {}

## A SIGN STEPS ASIDE FOR THE LENS (overnight bot review, 2026-10-26: the board beside the
## Depot's door filled the screen whenever the third-person camera came up behind it). Solid
## past FAR_M from the camera, MAX_FADE see-through at NEAR_M and closer, measured to the
## nearest point of the board rather than its middle, so a wide board fades at its end too.
const NEAR_M := 1.2
const FAR_M := 3.0
const MAX_FADE := 0.92

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
	var face := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, height, 0.12)
	face.mesh = bm
	face.material_override = _mat(PAPER)
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
	ic.position = Vector3(-width * 0.5 + height * 0.55, 0, 0.065)
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
	l.position = Vector3(height * 0.55, 0, 0.066)
	holder.add_child(l)


## How see-through the board is right now, 0 solid to MAX_FADE.
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
	var f := MAX_FADE * smoothstep(FAR_M, NEAR_M, d)
	if absf(f - _fade) < 0.005:
		return
	_fade = f
	for g: Node in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).transparency = f


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


## The painted icon for `kind`, drawn once.
static func icon_texture(kind: int) -> ImageTexture:
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Color = ICON_COLOURS.get(kind, Color.WHITE)
	var dark := c.darkened(0.45)
	var mid := Vector2(64, 64)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			match kind:
				Icon.COIN:
					var d := p.distance_to(mid)
					if d < 54:
						col = dark
					if d < 48:
						col = c
					if d < 36 and d > 30:
						col = dark
					# a "b" for bits: stem and bowl
					if (absf(x - 52.0) < 5 and y > 38 and y < 90) or (absf(p.distance_to(Vector2(64, 74)) - 13.0) < 4.5 and x > 50):
						col = dark
				Icon.CRATE:
					if x > 14 and x < 114 and y > 22 and y < 110:
						col = dark
						if x > 22 and x < 106 and y > 30 and y < 102:
							col = c
							if absf(y - 66.0) < 4 or absf((x - 22.0) - (y - 30.0)) < 5:
								col = dark
				Icon.HOUSE:
					var roof := y > 14 and y < 62 and absf(x - 64.0) < (y - 14.0) * 1.15
					var body := x > 28 and x < 100 and y >= 58 and y < 112
					if roof:
						col = dark
					if body:
						col = c
					if x > 54 and x < 74 and y > 80 and y < 112:
						col = dark
				Icon.SCROLL:
					if x > 26 and x < 102 and y > 18 and y < 110:
						col = c
						if (y > 40 and y < 46) or (y > 58 and y < 64) or (y > 76 and y < 82):
							if x > 38 and x < 90:
								col = dark
					if (y > 12 and y < 26 or y > 102 and y < 116) and x > 20 and x < 108:
						col = dark
				Icon.FENCE:
					for post in [24, 64, 104]:
						if absf(x - post) < 8 and y > 20 and y < 112:
							col = c
							if absf(x - post) >= 5:
								col = dark
					if (absf(y - 48.0) < 6 or absf(y - 84.0) < 6) and x > 16 and x < 112:
						col = dark
				Icon.STAR:
					var a := atan2(p.y - 64.0, p.x - 64.0)
					var r := p.distance_to(mid)
					var lim := 26.0 + 30.0 * pow(absf(cos(a * 2.5 + PI * 0.25)), 3.0)
					if r < lim:
						col = c if r < lim - 6 else dark
				Icon.ARROW:
					if (y > 50 and y < 78 and x > 14 and x < 80) or (x >= 74 and x < 116 and absf(y - 64.0) < (116.0 - x) * 0.85):
						col = c
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[kind] = tex
	return tex
