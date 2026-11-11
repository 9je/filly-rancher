class_name FactoryPoster
extends Node3D
## THE WELCOME HALL'S POSTERS HAVE SOMETHING ON THEM (playtest 2026-11-10 item 8: Marigold says
## "Read the posters, they're all true!" over blank cream frames). Each is a little picture and
## a slogan, painted once into a SubViewport and laid on the poster's face. Cheerful words; the
## unease is in what they cheer (memory: story cracks are emphasised, never said).
##
## Add as a child of an fx_poster piece (its face is local +Z, 1.4 x 2.0 m).

const MenuStyleScript := preload("res://ui/menu_style.gd")

const DESIGNS := [
	{"words": "Every pony has a color!", "art": "rainbow_pony", "bg": Color(0.99, 0.95, 0.86)},
	{"words": "Happy ponies make the brightest colors", "art": "sun", "bg": Color(0.93, 0.96, 1.0)},
	{"words": "Find your talent today!", "art": "blank_marks", "bg": Color(1.0, 0.93, 0.95)},
	{"words": "Thank you for your color", "art": "heart", "bg": Color(0.95, 0.99, 0.93)},
	{"words": "Where does a rainbow come from?", "art": "flow", "bg": Color(0.99, 0.97, 0.9)},
	{"words": "UP  rainbow   DOWN  off", "art": "lever_dial", "bg": Color(0.2, 0.18, 0.24)},
	{"words": "STAFF ONLY", "art": "no_entry", "bg": Color(0.98, 0.95, 0.88)},
]
const RAINBOW := [Color(0.93, 0.36, 0.4), Color(0.98, 0.62, 0.3), Color(0.98, 0.86, 0.36),
	Color(0.45, 0.78, 0.45), Color(0.38, 0.62, 0.9), Color(0.62, 0.46, 0.82)]
const PX := Vector2i(280, 400)

var design := 0


func _ready() -> void:
	var d: Dictionary = DESIGNS[posmod(design, DESIGNS.size())]
	var vp := SubViewport.new()
	vp.size = PX
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var art := _Art.new()
	art.kind = String(d.art)
	art.bg = d.bg
	art.size = Vector2(PX)
	vp.add_child(art)
	var words := Label.new()
	words.text = String(d.words)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.position = Vector2(18, 284)
	words.size = Vector2(PX.x - 36, 120)
	words.add_theme_font_override(&"font", MenuStyleScript.title_font())
	words.add_theme_font_size_override(&"font_size", 34)
	words.add_theme_color_override(&"font_color", Color(0.3, 0.16, 0.36) if d.bg.get_luminance() > 0.5 else Color(1.0, 0.94, 0.8))
	vp.add_child(words)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.36, 1.94)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material_override = mat
	quad.position = Vector3(0, 0, 0.075)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)


class _Art:
	extends Control
	var kind := ""
	var bg := Color.WHITE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), bg)
		var c := Vector2(size.x * 0.5, 150)
		match kind:
			"rainbow_pony":
				for i in RAINBOW.size():
					draw_arc(c + Vector2(0, 40), 120 - i * 11, PI, TAU, 48, RAINBOW[i], 11.0)
				_pony(c + Vector2(0, 70), 1.0)
			"sun":
				for i in 12:
					var a := TAU * i / 12.0
					draw_line(c + Vector2.from_angle(a) * 70, c + Vector2.from_angle(a) * 112,
						RAINBOW[i % RAINBOW.size()], 10.0)
				draw_circle(c, 62, Color(0.99, 0.84, 0.35))
				draw_arc(c + Vector2(0, 8), 26, 0.3, PI - 0.3, 16, Color(0.4, 0.22, 0.3), 5.0)
				draw_circle(c + Vector2(-20, -14), 6, Color(0.4, 0.22, 0.3))
				draw_circle(c + Vector2(20, -14), 6, Color(0.4, 0.22, 0.3))
			"blank_marks":
				for i in 3:
					var p := c + Vector2(-78 + i * 78, (i % 2) * 34 - 10)
					draw_circle(p, 34, Color(1, 1, 1))
					draw_arc(p, 34, 0, TAU, 32, Color(0.62, 0.52, 0.66), 4.0)
					draw_arc(p, 20, 0, TAU, 24, Color(0.85, 0.8, 0.88), 3.0)
				for i in RAINBOW.size():
					draw_rect(Rect2(40 + i * 34, 222, 30, 10), RAINBOW[i])
			"heart":
				for i in RAINBOW.size():
					var s := 1.0 - i * 0.13
					_heart(c, 100 * s, RAINBOW[i])
			"no_entry":
				draw_circle(c + Vector2(0, 20), 100, Color(0.85, 0.22, 0.25))
				draw_rect(Rect2(c + Vector2(-70, 4), Vector2(140, 32)), Color(1, 1, 1))
			"lever_dial":
				# Up, the spectrum fanning out; down, a dark disc. The arrow between.
				for i in RAINBOW.size():
					draw_arc(Vector2(size.x * 0.5, 120), 96 - i * 10, PI, TAU, 40, RAINBOW[i], 10.0)
				draw_circle(Vector2(size.x * 0.5, 215), 34, Color(0.08, 0.07, 0.1))
				draw_arc(Vector2(size.x * 0.5, 215), 34, 0, TAU, 32, Color(0.6, 0.6, 0.66), 3.0)
				draw_line(Vector2(size.x * 0.5, 60), Vector2(size.x * 0.5, 250), Color(0.95, 0.85, 0.5), 6.0)
				draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5 - 14, 66), Vector2(size.x * 0.5, 42),
					Vector2(size.x * 0.5 + 14, 66)]), Color(0.95, 0.85, 0.5))
				draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5 - 14, 244), Vector2(size.x * 0.5, 268),
					Vector2(size.x * 0.5 + 14, 244)]), Color(0.95, 0.85, 0.5))
			"flow":
				_pony(Vector2(70, 170), 0.7)
				draw_line(Vector2(120, 150), Vector2(165, 150), Color(0.45, 0.38, 0.5), 8.0)
				draw_colored_polygon(PackedVector2Array([Vector2(165, 136), Vector2(185, 150), Vector2(165, 164)]),
					Color(0.45, 0.38, 0.5))
				for i in RAINBOW.size():
					draw_arc(Vector2(230, 190), 52 - i * 7, PI, TAU, 24, RAINBOW[i], 7.0)

	func _pony(at: Vector2, s: float) -> void:
		var coat := Color(0.97, 0.97, 1.0)
		var ink := Color(0.4, 0.3, 0.45)
		draw_circle(at + Vector2(0, 30) * s, 46 * s, coat)
		draw_circle(at + Vector2(-8, -34) * s, 34 * s, coat)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-26, -58) * s, at + Vector2(-34, -86) * s,
			at + Vector2(-12, -64) * s]), coat)
		draw_circle(at + Vector2(-16, -38) * s, 6 * s, ink)
		draw_arc(at + Vector2(-6, -22) * s, 9 * s, 0.4, PI - 0.4, 10, ink, 3.0 * s)
		draw_arc(at + Vector2(0, 30) * s, 46 * s, 0, TAU, 32, ink, 3.0 * s)
		draw_arc(at + Vector2(-8, -34) * s, 34 * s, 0, TAU, 32, ink, 3.0 * s)

	func _heart(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 48:
			var t := TAU * i / 48.0
			var x := 16 * pow(sin(t), 3)
			var y := -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
			pts.append(c + Vector2(x, y) * r / 17.0)
		draw_colored_polygon(pts, col)
