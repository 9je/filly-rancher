class_name MarkComposer
extends RefCounted
## DRAWS A GENERATED CUTIE MARK. A mark is a talent (what she Blooms into) plus an
## arrangement (`motif`: one big shape, a pair, or a trio) and two colors. Shapes are
## signed distance functions in a unit square, so they come out anti-aliased at any size;
## each is filled with color `a`, detailed with `b`, and ringed with a thin darker line so
## it reads on any coat, the way the show's marks do.
##
## Results are cached by the mark's contents: a pony re-built from a save draws nothing.

const SIZE := 128

## talent -> [shape, detail shape or "", display name]. Detail draws on top in color b.
const TALENTS := {
	&"baking": ["cupcake", "cherry", "Baking"],
	&"music": ["note", "", "Music"],
	&"gardening": ["flower", "dot", "Gardening"],
	&"weather": ["cloud", "bolt", "Weather"],
	&"stargazing": ["star", "", "Stargazing"],
	&"healing": ["heart", "cross", "Healing"],
	&"orchards": ["apple", "leaf_small", "Orchards"],
	&"gemcutting": ["gem", "gem_facet", "Gem cutting"],
	&"sewing": ["button", "button_holes", "Sewing"],
	&"reading": ["book", "book_line", "Reading"],
	&"painting": ["drop", "", "Painting"],
	&"speed": ["bolt", "", "Speed"],
	&"swimming": ["wave", "", "Swimming"],
	&"sweets": ["candy", "candy_swirl", "Sweets"],
	&"sunshine": ["sun", "dot", "Sunshine"],
	&"moonlight": ["moon", "", "Moonlight"],
	&"luck": ["clover", "", "Luck"],
	&"carrots": ["carrot", "carrot_top", "Carrots"],
	&"kindness": ["butterfly", "butterfly_body", "Kindness"],
	&"lanterns": ["flame", "flame_core", "Lanterns"],
	&"bells": ["bell", "dot", "Bells"],
	&"forestry": ["leaf", "leaf_vein", "Forestry"],
	&"bubbles": ["bubbles", "bubble_shine", "Bubbles"],
	&"snow": ["snowflake", "", "Snow"],
}

## EVERY SYMBOL'S OWN COLOURS (Fable AAA round 3, #6: the creator's stamps were black
## silhouettes). A mark in the show is coloured the way the thing is: a red apple with a green
## leaf, a gold shoe, a pink butterfly with a teal body. [fill, detail], by shape name; the
## stamp gallery shows and lays a symbol in these, and an ink recolours its fill after.
const PALETTE := {
	"cupcake": [Color(0.97, 0.64, 0.80), Color(0.86, 0.18, 0.26)],
	"note": [Color(0.56, 0.42, 0.86), Color(1.0, 0.86, 0.42)],
	"flower": [Color(0.98, 0.60, 0.76), Color(1.0, 0.84, 0.30)],
	"cloud": [Color(0.95, 0.96, 1.0), Color(1.0, 0.82, 0.25)],
	"star": [Color(1.0, 0.80, 0.28), Color(1.0, 0.95, 0.70)],
	"heart": [Color(0.96, 0.46, 0.60), Color(1.0, 1.0, 1.0)],
	"apple": [Color(0.88, 0.22, 0.24), Color(0.46, 0.76, 0.34)],
	"gem": [Color(0.46, 0.66, 0.98), Color(0.80, 0.90, 1.0)],
	"button": [Color(0.55, 0.78, 0.96), Color(0.24, 0.36, 0.62)],
	"book": [Color(0.58, 0.36, 0.76), Color(1.0, 0.84, 0.40)],
	"drop": [Color(0.34, 0.60, 0.96), Color(0.92, 0.96, 1.0)],
	"bolt": [Color(1.0, 0.82, 0.25), Color(1.0, 0.95, 0.70)],
	"wave": [Color(0.30, 0.64, 0.92), Color(0.85, 0.95, 1.0)],
	"candy": [Color(0.98, 0.55, 0.76), Color(1.0, 1.0, 1.0)],
	"sun": [Color(1.0, 0.76, 0.26), Color(0.98, 0.52, 0.20)],
	"moon": [Color(0.40, 0.44, 0.84), Color(0.85, 0.88, 1.0)],
	"clover": [Color(0.36, 0.72, 0.40), Color(0.75, 0.92, 0.55)],
	# The carrot's detail is its root, so the fill is the leafy top.
	"carrot": [Color(0.42, 0.74, 0.32), Color(0.98, 0.56, 0.20)],
	"butterfly": [Color(0.98, 0.62, 0.80), Color(0.36, 0.78, 0.82)],
	"flame": [Color(0.98, 0.56, 0.20), Color(1.0, 0.90, 0.40)],
	"bell": [Color(0.96, 0.76, 0.30), Color(0.72, 0.42, 0.18)],
	"leaf": [Color(0.40, 0.72, 0.36), Color(0.78, 0.94, 0.58)],
	"bubbles": [Color(0.62, 0.84, 1.0), Color(1.0, 1.0, 1.0)],
	"snowflake": [Color(0.66, 0.86, 1.0), Color(1.0, 1.0, 1.0)],
	"horseshoe": [Color(0.96, 0.76, 0.30), Color(0.50, 0.32, 0.16)],
	"sparkle": [Color(0.90, 0.32, 0.62), Color(1.0, 1.0, 1.0)],
	"balloons": [Color(0.40, 0.70, 0.96), Color(1.0, 0.86, 0.30)],
	"crown": [Color(1.0, 0.80, 0.30), Color(0.94, 0.38, 0.60)],
	"quill": [Color(0.97, 0.96, 1.0), Color(0.52, 0.42, 0.66)],
	"hourglass": [Color(0.74, 0.50, 0.30), Color(1.0, 0.86, 0.50)],
	"cherries": [Color(0.88, 0.18, 0.28), Color(0.42, 0.74, 0.32)],
	"shooting_star": [Color(1.0, 0.82, 0.28), Color(0.62, 0.48, 0.92)],
}


## [fill, detail] for a shape, or a rose and gold pair for one without its own.
static func palette(shape_name: String) -> Array:
	return PALETTE.get(shape_name, [Color(0.9, 0.3, 0.4), Color(1.0, 0.9, 0.5)])

## motif 0: one, 1: a pair (offset diagonal), 2: a trio (triangle). [centers, scale].
const ARRANGE := [
	[[Vector2(0.5, 0.5)], 0.92],
	[[Vector2(0.36, 0.40), Vector2(0.64, 0.62)], 0.56],
	[[Vector2(0.5, 0.30), Vector2(0.29, 0.66), Vector2(0.71, 0.66)], 0.46],
]

static var _cache: Dictionary = {}


static func talent_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in TALENTS:
		out.append(k)
	return out


static func talent_name(talent: StringName) -> String:
	return String((TALENTS.get(talent, ["", "", "Mystery"]) as Array)[2])


static func compose(mark: Dictionary) -> Image:
	var talent := StringName(str(mark.get("talent", "")))
	if not TALENTS.has(talent):
		return null
	var motif: int = clampi(int(mark.get("motif", 0)), 0, ARRANGE.size() - 1)
	var a: Color = mark.get("a", Color(0.9, 0.3, 0.4))
	var b: Color = mark.get("b", Color(1.0, 0.9, 0.5))
	var key := "%s|%d|%s|%s" % [talent, motif, a.to_html(), b.to_html()]
	if _cache.has(key):
		return _cache[key]
	var spec: Array = TALENTS[talent]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var line := Color(a.r * 0.42, a.g * 0.42, a.b * 0.45, 1.0)
	var arrange: Array = ARRANGE[motif]
	var centers: Array = arrange[0]
	var s: float = arrange[1]
	var px := 1.0 / float(SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var p := Vector2((x + 0.5) * px, (y + 0.5) * px)
			var out := Color(0, 0, 0, 0)
			for c: Vector2 in centers:
				var q := (p - c) / s + Vector2(0.5, 0.5)
				var d: float = shape(String(spec[0]), q) * s
				if d > 0.03:
					continue
				var edge: float = clampf(0.5 - d / px, 0.0, 1.0)
				var ring: float = clampf(0.5 - (d + 0.022 * s) / px, 0.0, 1.0)
				var col := line.lerp(a, ring)
				if String(spec[1]) != "":
					var dd: float = shape(String(spec[1]), q) * s
					col = col.lerp(b, clampf(0.5 - dd / px, 0.0, 1.0) * ring)
				col.a = edge
				out = _over(col, out)
			img.set_pixel(x, y, out)
	_cache[key] = img
	return img


static func image_from_png64(b64: String) -> Image:
	if b64.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) != OK:
		return null
	return img


static func _over(top: Color, under: Color) -> Color:
	var a := top.a + under.a * (1.0 - top.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Color(top.r, top.g, top.b) * top.a + Color(under.r, under.g, under.b) * under.a * (1.0 - top.a)) / a
	return Color(rgb.r, rgb.g, rgb.b, a)


# --- shapes: signed distance in the unit square, negative inside -------------------------

static func shape(name: String, p: Vector2) -> float:
	var q := p - Vector2(0.5, 0.5)
	match name:
		# The plain shapes the stamp editor offers beside the talents (systems/mark_layout.gd).
		"circle":
			return _circle(q, 0.4)
		"square":
			return _box(q, Vector2(0.36, 0.36))
		"diamond":
			return (absf(q.x) + absf(q.y) - 0.44) * 0.7071
		"triangle":
			return _poly(q, [Vector2(0.0, -0.42), Vector2(0.42, 0.34), Vector2(-0.42, 0.34)])
		"dot":
			return _circle(q - Vector2(0.0, 0.0), 0.08)
		"heart":
			return _heart(q * Vector2(1.0, -1.0) + Vector2(0.0, 0.05), 0.42)
		"star":
			return _star(q, 0.42, 0.19)
		"cloud":
			return minf(minf(_circle(q - Vector2(-0.16, 0.05), 0.18), _circle(q - Vector2(0.14, 0.06), 0.2)),
				minf(_circle(q - Vector2(0.0, -0.1), 0.22), _box(q - Vector2(0.0, 0.14), Vector2(0.3, 0.09))))
		"bolt":
			return _poly(q, [Vector2(0.06, -0.42), Vector2(-0.2, 0.04), Vector2(-0.02, 0.04),
				Vector2(-0.1, 0.42), Vector2(0.2, -0.08), Vector2(0.02, -0.08)])
		"cross":
			return minf(_box(q - Vector2(0, -0.04), Vector2(0.055, 0.16)), _box(q - Vector2(0, -0.04), Vector2(0.16, 0.055)))
		"apple":
			var body := minf(_circle(q - Vector2(-0.11, 0.08), 0.26), _circle(q - Vector2(0.11, 0.08), 0.26))
			var stem := _box(_rot(q - Vector2(0.0, -0.24), -0.25), Vector2(0.025, 0.08))
			var leaf := _vesica(_rot(q - Vector2(0.12, -0.27), 1.1), 0.12, 0.055)
			return minf(body, minf(stem, leaf))
		"leaf_small":
			return _vesica(_rot(q - Vector2(0.12, -0.27), 1.1), 0.1, 0.035)
		"leaf":
			return _vesica(_rot(q, 0.6), 0.4, 0.17)
		"leaf_vein":
			return _box(_rot(q, 0.6), Vector2(0.012, 0.3))
		"gem":
			return _poly(q, [Vector2(-0.3, -0.12), Vector2(-0.16, -0.3), Vector2(0.16, -0.3),
				Vector2(0.3, -0.12), Vector2(0.0, 0.38)])
		"gem_facet":
			return _poly(q, [Vector2(-0.14, -0.12), Vector2(0.14, -0.12), Vector2(0.0, 0.2)])
		"button":
			return _circle(q, 0.36)
		"button_holes":
			return minf(minf(_circle(q - Vector2(-0.09, -0.09), 0.045), _circle(q - Vector2(0.09, -0.09), 0.045)),
				minf(_circle(q - Vector2(-0.09, 0.09), 0.045), _circle(q - Vector2(0.09, 0.09), 0.045)))
		"book":
			return _box(_rot(q, -0.15), Vector2(0.34, 0.24))
		"book_line":
			return _box(_rot(q, -0.15), Vector2(0.015, 0.22))
		"drop":
			return _drop(q * Vector2(1.0, -1.0), 0.3)
		"wave":
			var w := q.y - 0.07 * sin(q.x * 18.0)
			return maxf(absf(w) - 0.09, _box(q, Vector2(0.4, 0.3)))
		"candy":
			return minf(_circle(q, 0.24), minf(_poly(q, [Vector2(0.2, 0), Vector2(0.42, -0.14), Vector2(0.42, 0.14)]),
				_poly(q, [Vector2(-0.2, 0), Vector2(-0.42, 0.14), Vector2(-0.42, -0.14)])))
		"candy_swirl":
			var ang := atan2(q.y, q.x)
			var r := q.length()
			return maxf(absf(fposmod(r * 30.0 - ang * 1.6, TAU) - PI) * 0.02 - 0.02, r - 0.2)
		"sun":
			var a2 := atan2(q.y, q.x)
			var rays := q.length() - (0.3 + 0.08 * maxf(0.0, cos(a2 * 8.0)))
			return minf(_circle(q, 0.23), rays + 0.02)
		"moon":
			return maxf(_circle(q, 0.36), -_circle(q - Vector2(0.17, -0.1), 0.3))
		"clover":
			# Three heart-shaped leaves whose points meet at the centre, and a stem.
			var c := q - Vector2(0.0, -0.04)
			var best3 := _box(_rot(c - Vector2(0.07, 0.2), 0.4), Vector2(0.028, 0.16))
			for i in range(3):
				var lq := c.rotated(-float(i) * TAU / 3.0)
				best3 = minf(best3, _heart(lq * Vector2(1, -1), 0.24))
			return best3
		"carrot":
			var root := _poly(q, [Vector2(-0.17, -0.14), Vector2(0.17, -0.14), Vector2(0.0, 0.44)])
			var tops := minf(minf(_vesica(_rot(q - Vector2(-0.08, -0.28), -0.45), 0.14, 0.045),
				_vesica(_rot(q - Vector2(0.08, -0.28), 0.45), 0.14, 0.045)),
				_vesica(q - Vector2(0.0, -0.31), 0.15, 0.045))
			return minf(root, tops)
		"carrot_top":
			return maxf(shape("carrot", p), -(q.y + 0.15))
		"flame":
			return _drop(q + Vector2(0.0, -0.06), 0.3)
		"flame_core":
			return _drop(q + Vector2(0.0, -0.14), 0.15)
		"bell":
			# A domed bell with a flared lip and a knob on top (it was a cone, and read as one).
			var dome := _circle(q - Vector2(0.0, -0.1), 0.2)
			var skirt := _poly(q, [Vector2(-0.2, -0.1), Vector2(0.2, -0.1), Vector2(0.24, 0.1),
				Vector2(0.33, 0.2), Vector2(-0.33, 0.2), Vector2(-0.24, 0.1)])
			return minf(minf(dome, skirt), minf(_circle(q - Vector2(0.0, -0.33), 0.06),
				_circle(q - Vector2(0.0, 0.25), 0.07)))
		"ring":
			return minf(absf(_circle(q - Vector2(-0.08, 0.06), 0.26)) - 0.045,
				absf(_circle(q - Vector2(0.24, -0.24), 0.1)) - 0.03)
		# Fable AAA round 3, #6: the old Bubbles ring with its small ring read as a gender
		# symbol. Three whole bubbles, each with a shine.
		"bubbles":
			return minf(_circle(q - Vector2(-0.11, 0.09), 0.23),
				minf(_circle(q - Vector2(0.21, -0.19), 0.13), _circle(q - Vector2(0.24, 0.21), 0.085)))
		"bubble_shine":
			return minf(_circle(q - Vector2(-0.2, -0.01), 0.06),
				minf(_circle(q - Vector2(0.16, -0.24), 0.035), _circle(q - Vector2(0.21, 0.18), 0.022)))
		"butterfly":
			var wings := minf(minf(_circle(q - Vector2(-0.17, -0.11), 0.17), _circle(q - Vector2(0.17, -0.11), 0.17)),
				minf(_circle(q - Vector2(-0.13, 0.15), 0.12), _circle(q - Vector2(0.13, 0.15), 0.12)))
			return minf(wings, shape("butterfly_body", p))
		"butterfly_body":
			var fly_body := _segment(q, Vector2(0.0, -0.2), Vector2(0.0, 0.26), 0.04)
			return minf(fly_body, minf(_circle(q - Vector2(-0.19, -0.13), 0.06), _circle(q - Vector2(0.19, -0.13), 0.06)))
		"horseshoe":
			var hr := 0.24
			var hw := 0.085
			var arc := maxf(absf(q.length() - hr) - hw, q.y)
			var legs := minf(_box(q - Vector2(-hr, 0.13), Vector2(hw, 0.13)), _box(q - Vector2(hr, 0.13), Vector2(hw, 0.13)))
			var heels := minf(_box(q - Vector2(-hr, 0.27), Vector2(hw + 0.025, 0.035)),
				_box(q - Vector2(hr, 0.27), Vector2(hw + 0.025, 0.035)))
			return minf(arc, minf(legs, heels))
		"horseshoe_nails":
			var nails := 1.0
			for deg: float in [-160.0, -120.0, -60.0, -20.0]:
				nails = minf(nails, _circle(q - Vector2(0.24, 0.0).rotated(deg_to_rad(deg)), 0.026))
			return minf(nails, minf(_circle(q - Vector2(-0.24, 0.12), 0.026), _circle(q - Vector2(0.24, 0.12), 0.026)))
		"sparkle":
			return _star_n(q, 0.44, 0.2, 6)
		"sparkle_core":
			return _star_n(q, 0.15, 0.07, 6)
		"balloons":
			var strings := minf(_segment(q, Vector2(-0.15, 0.0), Vector2(0.0, 0.42), 0.014),
				minf(_segment(q, Vector2(0.15, -0.04), Vector2(0.0, 0.42), 0.014),
				_segment(q, Vector2(0.0, 0.12), Vector2(0.0, 0.42), 0.014)))
			return minf(strings, minf(minf(_ellipse(q - Vector2(-0.16, -0.16), Vector2(0.14, 0.17)),
				_ellipse(q - Vector2(0.0, -0.03), Vector2(0.14, 0.17))), shape("balloon_b", p)))
		"balloon_b":
			return _ellipse(q - Vector2(0.17, -0.2), Vector2(0.14, 0.17))
		"crown":
			var band := _box(q - Vector2(0.0, 0.17), Vector2(0.33, 0.08))
			var points := _poly(q, [Vector2(-0.33, 0.12), Vector2(-0.33, -0.22), Vector2(-0.16, -0.02),
				Vector2(0.0, -0.3), Vector2(0.16, -0.02), Vector2(0.33, -0.22), Vector2(0.33, 0.12)])
			return minf(minf(band, points), minf(minf(_circle(q - Vector2(-0.33, -0.25), 0.05),
				_circle(q - Vector2(0.33, -0.25), 0.05)), _circle(q - Vector2(0.0, -0.33), 0.05)))
		"crown_gems":
			return minf(_circle(q - Vector2(0.0, 0.17), 0.05),
				minf(_circle(q - Vector2(-0.19, 0.17), 0.04), _circle(q - Vector2(0.19, 0.17), 0.04)))
		"quill":
			var vane := _vesica(_rot(q - Vector2(0.06, -0.08), 0.62), 0.34, 0.13)
			return minf(vane, _segment(q, Vector2(-0.3, 0.36), Vector2(0.0, -0.0), 0.025))
		"quill_shaft":
			return _segment(q, Vector2(-0.3, 0.36), Vector2(0.24, -0.36), 0.016)
		"hourglass":
			var glass := _poly(q, [Vector2(-0.2, -0.29), Vector2(0.2, -0.29), Vector2(0.04, 0.0),
				Vector2(0.2, 0.29), Vector2(-0.2, 0.29), Vector2(-0.04, 0.0)])
			var bars := minf(_box(q - Vector2(0.0, -0.33), Vector2(0.27, 0.05)),
				_box(q - Vector2(0.0, 0.33), Vector2(0.27, 0.05)))
			return minf(glass, bars)
		"hourglass_sand":
			return minf(_poly(q, [Vector2(-0.15, 0.27), Vector2(0.15, 0.27), Vector2(0.0, 0.1)]),
				_poly(q, [Vector2(-0.11, -0.17), Vector2(0.11, -0.17), Vector2(0.0, -0.04)]))
		"cherries":
			return minf(minf(_circle(q - Vector2(-0.15, 0.19), 0.15), _circle(q - Vector2(0.16, 0.21), 0.14)),
				shape("cherry_stems", p))
		"cherry_stems":
			var stems := minf(_segment(q, Vector2(-0.14, 0.06), Vector2(0.05, -0.3), 0.025),
				_segment(q, Vector2(0.15, 0.09), Vector2(0.05, -0.3), 0.025))
			return minf(stems, _vesica(_rot(q - Vector2(0.18, -0.3), 1.2), 0.13, 0.06))
		"shooting_star":
			return minf(_star(q - Vector2(0.13, -0.12), 0.27, 0.12), shape("star_tail", p))
		"star_tail":
			return minf(_segment(q, Vector2(-0.38, 0.36), Vector2(0.02, -0.02), 0.05),
				minf(_segment(q, Vector2(-0.4, 0.14), Vector2(-0.06, -0.06), 0.035),
				_segment(q, Vector2(-0.16, 0.4), Vector2(0.06, 0.06), 0.035)))
		"snowflake":
			var best := 1.0
			for i in range(3):
				best = minf(best, _box(_rot(q, float(i) * PI / 3.0), Vector2(0.04, 0.4)))
			return minf(best, _circle(q, 0.08))
		"note":
			return minf(minf(_circle(q - Vector2(-0.1, 0.22), 0.14), _box(q - Vector2(0.02, -0.06), Vector2(0.035, 0.3))),
				_poly(q, [Vector2(0.02, -0.36), Vector2(0.24, -0.22), Vector2(0.24, -0.1), Vector2(0.02, -0.22)]))
		"flower":
			var best2 := _circle(q, 0.12)
			for i in range(5):
				var off := Vector2(0.0, -0.22).rotated(float(i) * TAU / 5.0)
				best2 = minf(best2, _circle(q - off, 0.15))
			return best2
		"cupcake":
			return minf(minf(_poly(q, [Vector2(-0.24, 0.02), Vector2(0.24, 0.02), Vector2(0.16, 0.36), Vector2(-0.16, 0.36)]),
				minf(_circle(q - Vector2(-0.12, -0.06), 0.15), minf(_circle(q - Vector2(0.12, -0.06), 0.15), _circle(q - Vector2(0, -0.18), 0.15)))),
				_circle(q - Vector2(0.0, -0.36), 0.075))
		"cherry":
			return _circle(q - Vector2(0.0, -0.36), 0.07)
	return 1.0


static func _circle(q: Vector2, r: float) -> float:
	return q.length() - r


static func _box(q: Vector2, half: Vector2) -> float:
	var d := q.abs() - half
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)


static func _rot(q: Vector2, a: float) -> Vector2:
	return q.rotated(-a)


## A capsule: the segment from `a` to `b`, `r` thick either side.
static func _segment(q: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var ab := b - a
	var t := clampf((q - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return (q - a - ab * t).length() - r


## An ellipse with half axes `radii` (an approximation, close enough at mark sizes).
static func _ellipse(q: Vector2, radii: Vector2) -> float:
	return (q / radii).length() * minf(radii.x, radii.y) - minf(radii.x, radii.y)


## An n pointed star.
static func _star_n(q: Vector2, ro: float, ri: float, n: int) -> float:
	var pts: Array[Vector2] = []
	for i in range(n * 2):
		pts.append(Vector2(0.0, -(ro if i % 2 == 0 else ri)).rotated(float(i) * PI / float(n)))
	return _poly(q, pts)


static func _vesica(q: Vector2, h: float, w: float) -> float:
	# A leaf: the intersection of two circles, long axis on y.
	var r := (h * h + w * w) / (2.0 * w)
	var d := r - w
	var aq := q.abs()
	return maxf(Vector2(aq.x + d, aq.y).length() - r, aq.y - h)


static func _heart(q: Vector2, s: float) -> float:
	var p := q / s
	p.x = absf(p.x)
	var d: float
	if p.y + p.x > 1.0:
		d = (p - Vector2(0.25, 0.75)).length() - sqrt(2.0) / 4.0
	else:
		var a := (p - Vector2(0.0, 1.0)).length_squared()
		var t := maxf(p.x + p.y, 0.0) * 0.5
		var b := (p - Vector2(t, t)).length_squared()
		d = sqrt(minf(a, b)) * signf(p.x - p.y)
	return d * s


static func _star(q: Vector2, ro: float, ri: float) -> float:
	var pts: Array[Vector2] = []
	for i in range(10):
		var r := ro if i % 2 == 0 else ri
		pts.append(Vector2(0.0, -r).rotated(float(i) * PI / 5.0))
	return _poly(q, pts)


static func _drop(q: Vector2, r: float) -> float:
	# A teardrop pointing up (-y).
	var body := _circle(q - Vector2(0.0, 0.08), r * 0.8)
	var tip := _poly(q, [Vector2(0.0, -r * 1.35), Vector2(r * 0.72, -0.02), Vector2(-r * 0.72, -0.02)])
	return minf(body, tip)


static func _poly(q: Vector2, v: Array) -> float:
	var n := v.size()
	var d: float = (q - (v[0] as Vector2)).length_squared()
	var s := 1.0
	var j := n - 1
	for i in range(n):
		var vi: Vector2 = v[i]
		var vj: Vector2 = v[j]
		var e := vj - vi
		var w := q - vi
		var b := w - e * clampf(w.dot(e) / e.dot(e), 0.0, 1.0)
		d = minf(d, b.length_squared())
		var c1 := q.y >= vi.y
		var c2 := q.y < vj.y
		var c3 := e.x * w.y > e.y * w.x
		if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
			s = -s
		j = i
	return s * sqrt(d)
