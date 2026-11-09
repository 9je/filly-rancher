extends RefCounted
## A CUTIE MARK MADE OF STAMPS (PS7, playtest 2026-11-05 item 3: "Better cutie mark creation").
## Up to MAX_STAMPS symbols, each one of the 24 talents (MarkComposer.TALENTS, its shape and its
## detail) or one of the 8 Equestrian SHAPES, with a place, a size, a turn and two colours. Composed
## with MarkComposer's own shapes and its fill, detail and outline, so a stamped mark is drawn
## exactly like the valley's own marks.
##
## A stamp is a Dictionary: {kind: StringName ("talent:<id>" or "shape:<name>"), at: Vector2
## (its centre, 0 to 1 across the mark), scale: float (its width as a fraction of the mark),
## rot: float (radians), a: Color (fill), b: Color (detail)}.
##
## Preloaded by path, never by a class_name (the class cache lives in the gitignored .godot/).

const MarkComposerScript := preload("res://systems/mark_composer.gd")

const MAX_STAMPS := 3
## How far the shadow's copy of a stamp is nudged (stamp space, up and left).
const SHADE_NUDGE := Vector2(0.07, 0.07)
## How much every stamp's shape is grown (stamp space), so line-like symbols have a body.
const FATTEN := 0.035
const SCALE_RANGE := Vector2(0.18, 1.0)
## THE EQUESTRIAN SYMBOLS beside the talents (Fable AAA round 3, #6: the old twelve were
## geometry, a circle, a square, a cross, and a ring that read as a gender symbol). Each is a
## thing a pony in the valley might be marked with, with its detail drawn in a second colour.
## The plain shapes still draw (MarkComposer.shape), they are only no longer offered.
const SHAPES: Array[StringName] = [&"horseshoe", &"sparkle", &"balloons", &"crown", &"quill",
	&"hourglass", &"cherries", &"shooting_star"]
const SHAPE_DETAIL := {
	&"horseshoe": "horseshoe_nails", &"sparkle": "sparkle_core", &"balloons": "balloon_b",
	&"crown": "crown_gems", &"quill": "quill_shaft", &"hourglass": "hourglass_sand",
	&"cherries": "cherry_stems", &"shooting_star": "star_tail",
}


## Every symbol a stamp can be: the talents first, then the shapes.
static func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for t: StringName in MarkComposerScript.talent_ids():
		out.append(StringName("talent:" + String(t)))
	for s: StringName in SHAPES:
		out.append(StringName("shape:" + String(s)))
	return out


## [main shape, detail shape or ""] for a kind.
static func parts(kind: StringName) -> Array:
	var k := String(kind)
	if k.begins_with("talent:"):
		var spec: Array = MarkComposerScript.TALENTS.get(StringName(k.substr(7)), ["dot", "", ""])
		return [String(spec[0]), String(spec[1])]
	return [k.substr(6), String(SHAPE_DETAIL.get(StringName(k.substr(6)), ""))]


## The colours a kind is laid in until an ink recolours it: its own (MarkComposer.PALETTE).
static func palette(kind: StringName) -> Array:
	return MarkComposerScript.palette(String(parts(kind)[0]))


static func new_stamp(kind: StringName, a: Color, b: Color) -> Dictionary:
	return {"kind": kind, "at": Vector2(0.5, 0.5), "scale": 0.6, "rot": 0.0, "a": a, "b": b}


## `stamps` with `stamp` laid on top, unless there are MAX_STAMPS already. A new array.
static func added(stamps: Array, stamp: Dictionary) -> Array:
	var out := stamps.duplicate(true)
	if out.size() < MAX_STAMPS:
		out.append(stamp)
	return out


## Where `point` (0 to 1 across the mark) falls in a stamp's own unit square.
static func to_stamp(stamp: Dictionary, point: Vector2) -> Vector2:
	var s: float = maxf(float(stamp.get("scale", 0.6)), 0.01)
	var d: Vector2 = (point - (stamp.get("at", Vector2(0.5, 0.5)) as Vector2)).rotated(-float(stamp.get("rot", 0.0)))
	return d / s + Vector2(0.5, 0.5)


## The topmost stamp whose box (its own square, turned with it) covers `point`, or -1. The box
## and not the shape: a crescent or a ring is hollow in the middle, and a press there missed
## the stamp and painted a stroke (render, 2026-11-07).
static func hit(stamps: Array, point: Vector2) -> int:
	for i in range(stamps.size() - 1, -1, -1):
		var q := to_stamp(stamps[i], point)
		if q.x >= 0.08 and q.y >= 0.08 and q.x <= 0.92 and q.y <= 0.92:
			return i
	return -1


## The stamps drawn over a transparent mark `size` pixels square, the last on top.
static func compose(stamps: Array, size: int = 64) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	draw_over(img, stamps)
	return img


## Draw `stamps` over `img` in place (the painted layer under them stays).
static func draw_over(img: Image, stamps: Array) -> void:
	var size := img.get_width()
	var px := 1.0 / float(size)
	for stamp: Dictionary in stamps:
		var p2: Array = parts(stamp.kind)
		var main := String(p2[0])
		var detail := String(p2[1])
		var s: float = maxf(float(stamp.get("scale", 0.6)), 0.01)
		var a: Color = stamp.get("a", Color.WHITE)
		var b: Color = stamp.get("b", Color.WHITE)
		var line := Color(a.r * 0.42, a.g * 0.42, a.b * 0.45, 1.0)
		var at: Vector2 = stamp.get("at", Vector2(0.5, 0.5))
		var reach := s * 0.75
		var x0 := clampi(int((at.x - reach) * size), 0, size - 1)
		var x1 := clampi(int((at.x + reach) * size) + 1, 0, size - 1)
		var y0 := clampi(int((at.y - reach) * size), 0, size - 1)
		var y1 := clampi(int((at.y + reach) * size) + 1, 0, size - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var q := to_stamp(stamp, Vector2((x + 0.5) * px, (y + 0.5) * px))
				# Fattened a touch, so the thin symbols (a wave, a bolt, a cross) read at flank size.
				var d: float = (MarkComposerScript.shape(main, q) - FATTEN) * s
				if d > 0.03:
					continue
				var edge: float = clampf(0.5 - d / px, 0.0, 1.0)
				# THE ICON SET'S HAND (P8, playtest 2026-11-08 item 41: "many stamp icons still
				# look bad"): a bolder outline in the fill's own darker hue, and a hard shadow
				# crescent on the lower right (the shape again, nudged up and left; where it no
				# longer covers is shade), the way every icon in tools/make_icons.py is drawn.
				var ring: float = clampf(0.5 - (d + 0.045 * s) / px, 0.0, 1.0)
				var shifted: float = (MarkComposerScript.shape(main, q + SHADE_NUDGE) - FATTEN) * s
				var shade: float = clampf(0.5 + shifted / px, 0.0, 1.0)
				var body := a.lerp(Color(a.r * 0.78, a.g * 0.74, a.b * 0.82, a.a), shade)
				var col := line.lerp(body, ring)
				if detail != "":
					var dd: float = MarkComposerScript.shape(detail, q) * s
					col = col.lerp(b, clampf(0.5 - dd / px, 0.0, 1.0) * ring)
				col.a = edge
				img.set_pixel(x, y, MarkComposerScript._over(col, img.get_pixel(x, y)))
