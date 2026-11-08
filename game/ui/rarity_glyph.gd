class_name RarityGlyph
extends Control
## RARITY IS NOT COLOUR ALONE (FS8.3): a shape per rarity, drawn beside or inside whatever
## already tints by rarity, so it reads without telling the colours apart. Common a circle,
## uncommon a diamond, rare a star, legendary a crown. outline() is the shape's points, for
## any CanvasItem that wants to draw it itself (the HUD's saddlebag slots do).

const SHAPES := {
	PonyData.Rarity.COMMON: &"circle",
	PonyData.Rarity.UNCOMMON: &"diamond",
	PonyData.Rarity.RARE: &"star",
	PonyData.Rarity.LEGENDARY: &"crown",
}
const SIZE := 20.0

var rarity: int = PonyData.Rarity.COMMON:
	set(v):
		rarity = v
		queue_redraw()
var colour := Color(0.24, 0.17, 0.3)


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func shape() -> StringName:
	return shape_of(rarity)


static func shape_of(r: int) -> StringName:
	return SHAPES.get(r, &"circle")


## The shape for rarity `r` round `centre`, `radius` across, as a closed polygon.
static func outline(r: int, centre: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape_of(r):
		&"diamond":
			for a in [-PI * 0.5, 0.0, PI * 0.5, PI]:
				pts.append(centre + Vector2(cos(a), sin(a)) * radius)
		&"star":
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				pts.append(centre + Vector2(cos(a), sin(a)) * (radius if i % 2 == 0 else radius * 0.45))
		&"crown":
			var w := radius
			var b := centre.y + radius * 0.7
			var t := centre.y - radius * 0.8
			pts = PackedVector2Array([Vector2(centre.x - w, b), Vector2(centre.x - w, t),
				Vector2(centre.x - w * 0.5, centre.y - radius * 0.1), Vector2(centre.x, t),
				Vector2(centre.x + w * 0.5, centre.y - radius * 0.1), Vector2(centre.x + w, t),
				Vector2(centre.x + w, b)])
		_:
			for i in 16:
				var a := i * TAU / 16.0
				pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	return pts


func _draw() -> void:
	# The icon set's rarity pictures (P8 S5); the polygon stays for outline()'s callers.
	if CatchIcon.draw_from_set(self, "rarity_" + _NAMES.get(shape(), "common"), size):
		return
	draw_colored_polygon(outline(rarity, size * 0.5, minf(size.x, size.y) * 0.45), colour)


const _NAMES := {&"circle": "common", &"diamond": "uncommon", &"star": "rare", &"crown": "legendary"}
