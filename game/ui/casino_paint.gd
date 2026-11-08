class_name CasinoPaint
extends RefCounted
## THE CASINO'S OWN DRAWING VOCABULARY. game/ui/menu_style.gd owns the panel chrome every
## menu in the game shares; this file owns the felt, the chips, the cards and the glyphs that
## only the Palace has. Static only, no state, no scene, preloaded by path.
##
## THERE ARE NO 2D ART ASSETS IN THIS PROJECT AND THIS FILE ACQUIRES NONE. Everything below
## is a polygon, an arc, a StyleBoxFlat or a string. If it cannot be one of those four it is
## not in this slice: no texture, no Gradient resource on disk, no nine patch, no atlas.
##
## EVERY GLYPH IS SPLIT IN TWO, and the split is the whole reason drawn art can ship in a
## project whose CI has no GPU. The *_points() half is pure geometry with no CanvasItem in
## sight, so game/test/test_casino_paint.gd can assert that a star has ten points and that
## none of them leaks outside the box it was handed. The draw_* half is three lines feeding
## those points to draw_colored_polygon.
##
## THE PALETTE IS THE PALACE'S OWN. PLUM and GOLD are Buildings/Palace's wall_color and
## trim_color read straight out of game/world/ranch.tscn, so the building and its interior
## agree with each other by construction rather than by taste.
##
## NOTHING HERE ROLLS ANYTHING. See test_casino_paint.gd's last test.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const SlotsScript := preload("res://systems/slots.gd")

# --- the palette ----------------------------------------------------------------------------

const FELT := Color(0.09, 0.32, 0.20)
const FELT_DARK := Color(0.05, 0.20, 0.13)
const FELT_LINE := Color(1.00, 0.94, 0.72, 0.22)
const PLUM := Color(0.36, 0.16, 0.42)
const PLUM_DARK := Color(0.22, 0.09, 0.27)
const GOLD := Color(0.98, 0.86, 0.45)
const GOLD_DIM := Color(0.62, 0.53, 0.28)
const CARD_FACE := Color(0.97, 0.96, 0.93)
const CARD_RED := Color(0.78, 0.16, 0.20)
const CARD_INK := Color(0.11, 0.10, 0.14)

## The Cloudsdale pocket, which no bet may name. Pale enough that it reads as absent from the
## rainbow rather than as a seventh colour somebody forgot to let you back.
const HOUSE_SILVER := Color(0.80, 0.84, 0.90)

## ONE PER TableMenu.STAKES ENTRY, in ascending order, the way a real cage stacks them:
## white for the small one, green for the middle, black and gold for the big one.
const CHIP_COLORS: Array[Color] = [
	Color(0.90, 0.90, 0.92),
	Color(0.16, 0.52, 0.30),
	Color(0.13, 0.12, 0.16),
]

## SIX COLOURS, THREE PLACES, ONE RAINBOW. Indexed by Wheel.Colour, and the same six are the
## wheel's bands, the six race lanes and the slot machine's RAINBOW symbol, so the building
## reads as one building rather than as three screens that happened to be written together.
const BAND_COLORS: Array[Color] = [
	Color(0.85, 0.24, 0.26),
	Color(0.93, 0.55, 0.20),
	Color(0.95, 0.82, 0.28),
	Color(0.33, 0.68, 0.36),
	Color(0.27, 0.52, 0.86),
	Color(0.60, 0.38, 0.82),
]

## THE BIG WHEEL'S FIVE TIER COLOURS, indexed by Wheel.Tier (1x, 3x, 5x, 10x, 20x), the way
## the Rust wheel colours its own: the common tier a warm gold, the jackpot a red you can see
## across the room. Here rather than on the wheel's felt so the lobby tile paints the same
## wheel the table does.
const TIER_COLOURS: Array[Color] = [
	Color(0.96, 0.78, 0.26),
	Color(0.30, 0.72, 0.42),
	Color(0.27, 0.55, 0.92),
	Color(0.63, 0.38, 0.88),
	Color(0.92, 0.24, 0.30),
]

## Hearts, diamonds, spades, clubs, in the order Blackjack's own card index implies:
## card / Blackjack.RANKS. See game/ui/blackjack_menu.gd on why that is presentation only.
const SUIT_COLORS: Array[Color] = [CARD_RED, CARD_RED, CARD_INK, CARD_INK]

## Segments in a drawn ellipse. 28 is smooth at a 34 px chip and still cheap at a stack of
## eight; a circle would be draw_circle's job, and Godot has no ellipse call at all.
const ELLIPSE_SEGMENTS := 28

## Segments per annular sector arc. The wheel has 25 of them, so this is 25 * 2 * 6 points.
const SECTOR_SEGMENTS := 6

## The one focus treatment in the whole casino, so "where am I" is answered identically on
## every screen. Alpha breathes between these two on the phase the stage advances.
const FOCUS_WIDTH := 3.0
const FOCUS_INSET := 2.0
const FOCUS_ALPHA_LOW := 0.72
const FOCUS_ALPHA_HIGH := 1.0


## A filled, bordered, rounded rectangle: the single most used call in the slice.
##
## BUILT ON A StyleBoxFlat RATHER THAN ON GENERATED POLYGONS, and drawn straight onto an
## arbitrary CanvasItem through StyleBox.draw(). A StyleBoxFlat already has per corner radii,
## a border and an anti aliased edge; hand rolling that as a polygon is fifty lines that draw
## a worse rectangle.
static func rounded(ci: CanvasItem, rect: Rect2, radius: float, fill: Color,
		border: Color, border_width: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(radius))
	box.set_border_width_all(int(border_width))
	box.border_color = border
	box.anti_aliasing = true
	box.draw(ci.get_canvas_item(), rect)


## The points of an ellipse centred at `centre`. Godot has draw_circle and no ellipse call,
## and a chip seen at a slight angle is an ellipse.
static func ellipse_points(centre: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in ELLIPSE_SEGMENTS:
		var a: float = TAU * float(i) / float(ELLIPSE_SEGMENTS)
		out.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func ellipse(ci: CanvasItem, centre: Vector2, rx: float, ry: float,
		fill: Color, rim: Color) -> void:
	var points: PackedVector2Array = ellipse_points(centre, rx, ry)
	ci.draw_colored_polygon(points, fill)
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, rim, 2.0, true)


## ONE POCKET OF THE WHEEL: the ring between `inner` and `outer` from `from_angle` to
## `to_angle`, as a closed polygon. Out along the near arc and back along the far one, so the
## winding is consistent and draw_colored_polygon fills it rather than bowtieing it.
static func sector_points(centre: Vector2, inner: float, outer: float,
		from_angle: float, to_angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in SECTOR_SEGMENTS + 1:
		var a: float = lerpf(from_angle, to_angle, float(i) / float(SECTOR_SEGMENTS))
		out.append(centre + Vector2(cos(a), sin(a)) * outer)
	for i: int in SECTOR_SEGMENTS + 1:
		var a: float = lerpf(to_angle, from_angle, float(i) / float(SECTOR_SEGMENTS))
		out.append(centre + Vector2(cos(a), sin(a)) * inner)
	return out


## A CASINO CHIP. A filled ellipse, an inset lighter ring at 0.68 of the radius, six white
## edge dashes and a gold rim. `edge_marks` off gives the flat token used at small sizes,
## where six dashes are three pixels of noise rather than a chip.
static func chip(ci: CanvasItem, centre: Vector2, radius: float, colour: Color,
		edge_marks: bool) -> void:
	var ry: float = radius * 0.82
	ellipse(ci, centre, radius, ry, colour, GOLD_DIM)
	ellipse(ci, centre, radius * 0.68, ry * 0.68, colour.lightened(0.18),
		Color(colour.lightened(0.35), 0.6))
	if not edge_marks:
		return
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		var inner: Vector2 = centre + Vector2(cos(a) * radius * 0.80, sin(a) * ry * 0.80)
		var outer: Vector2 = centre + Vector2(cos(a) * radius * 0.97, sin(a) * ry * 0.97)
		ci.draw_line(inner, outer, Color(1.0, 1.0, 1.0, 0.85), 3.0, true)


## A STACK READS AS A STACK: `count` chips bottom up, the top one full and the rest showing
## only their rim. Caps at CHIP_STACK_MAX drawn chips with a small "x N" beside it, because a
## stack of forty chips is a column of mush and a number is what the player actually wants.
const CHIP_STACK_MAX := 8


static func chip_stack(ci: CanvasItem, base: Vector2, count: int, colour: Color,
		step: float) -> void:
	var drawn: int = mini(count, CHIP_STACK_MAX)
	for i: int in drawn:
		var at: Vector2 = base - Vector2(0.0, step * float(i))
		var top: bool = i == drawn - 1
		chip(ci, at, step * 2.6, colour, top)


## THE READING PLATE: a gold trimmed panel carrying a title and a body, so the two "reading
## matter" tabs in this building (the wheel's rules, blackjack's placard, the race card) stop
## being loose Labels in a column and start being a page.
static func plate(ci: CanvasItem, rect: Rect2, font: Font, title: String,
		body: Array[String]) -> void:
	rounded(ci, rect, 12.0, Color(FELT_DARK, 0.92), GOLD_DIM, 2.0)
	var y: float = rect.position.y + 34.0
	if not title.is_empty():
		text(ci, font, Vector2(rect.position.x + 22.0, y), title,
			MenuStyleScript.TITLE_SIZE, GOLD, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 44.0)
		y += 34.0
	for line: String in body:
		text(ci, font, Vector2(rect.position.x + 22.0, y), line,
			MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_NAME,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 44.0)
		y += 28.0


## OUTLINE PASS THEN COLOUR PASS, the same two pass discipline game/ui/hud.gd's _ring() uses
## and for the same reason: this game draws over a bright green field under a bright sky, and
## unoutlined text on that is genuinely unreadable. Every string the casino draws goes through
## here so no stage can forget it.
static func text(ci: CanvasItem, font: Font, at: Vector2, string: String, size: int,
		colour: Color, align: int, max_width: float) -> void:
	if font == null or string.is_empty():
		return
	ci.draw_string_outline(font, at, string, align, max_width, size,
		MenuStyleScript.OUTLINE_SIZE, MenuStyleScript.OUTLINE_COLOR)
	ci.draw_string(font, at, string, align, max_width, size, colour)


## THE TEXT SIZE SETTING REACHES THE FELT, AND NOTHING SPILLS (2026-11-05). The owner's
## playtest saw a rules box cut off on the right and a banner whose words ran out of their
## plate: draw_string() with a max width CLIPS, silently. So every drawn label on a casino
## stage now goes through fit_size(): the size the player asked for (Settings.text_size, via
## MenuStyle.font_px()), shrunk a pixel at a time until the string fits the width it was given.
## A label can get smaller to fit its box; it can never get out of it.
const MIN_FIT_PX := 9


static func fit_size(font: Font, string: String, size: int, max_width: float) -> int:
	var px: int = MenuStyleScript.font_px(size)
	if font == null or max_width <= 0.0:
		return px
	while px > MIN_FIT_PX and font.get_string_size(string, HORIZONTAL_ALIGNMENT_LEFT, -1,
			px).x > max_width:
		px -= 1
	return px


## The same, bounded in height too, for a label that has a box rather than a line.
static func fit_box_size(font: Font, string: String, size: int, box: Vector2) -> int:
	var px: int = fit_size(font, string, size, box.x)
	while px > MIN_FIT_PX and font.get_height(px) > box.y:
		px -= 1
	return px


## ONE LABEL, CENTRED IN ITS BOX VERTICALLY, aligned in it horizontally, fitted to it in both
## directions. The workhorse of every drawn screen in the Palace since the rebuild.
static func label(ci: CanvasItem, font: Font, box: Rect2, string: String, size: int,
		colour: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	if font == null or string.is_empty():
		return
	var px: int = fit_box_size(font, string, size, box.size)
	var ascent: float = font.get_ascent(px)
	var height: float = ascent + font.get_descent(px)
	var baseline: float = box.position.y + (box.size.y - height) * 0.5 + ascent
	ci.draw_string(font, Vector2(box.position.x, baseline), string, align, box.size.x, px,
		colour)


## THE SIZE A WRAPPED BLOCK OF LINES IS DRAWN AT so that all of it fits `box`: each line
## wraps at the box's width, and the whole block shrinks until its height fits too. Pure, so
## test_casino_paint.gd can ask it at every text size the settings offer.
const PARAGRAPH_GAP := 0.45


static func paragraph_size(font: Font, lines: Array[String], size: int, box: Vector2) -> int:
	var px: int = MenuStyleScript.font_px(size)
	while px > MIN_FIT_PX and paragraph_height(font, lines, px, box.x) > box.y:
		px -= 1
	return px


static func paragraph_height(font: Font, lines: Array[String], px: int, width: float) -> float:
	var total := 0.0
	for i: int in lines.size():
		total += font.get_multiline_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, width,
			px).y
		if i < lines.size() - 1:
			total += float(px) * PARAGRAPH_GAP
	return total


## A wrapped block of lines, top left at `box.position`, never wider or taller than `box`.
## Returns the pixel size it settled on.
static func paragraph(ci: CanvasItem, font: Font, box: Rect2, lines: Array[String],
		size: int, colour: Color) -> int:
	if font == null or lines.is_empty():
		return 0
	var px: int = paragraph_size(font, lines, size, box.size)
	var y: float = box.position.y + font.get_ascent(px)
	for line: String in lines:
		ci.draw_multiline_string(font, Vector2(box.position.x, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x, px, -1, colour)
		y += font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, box.size.x,
			px).y + float(px) * PARAGRAPH_GAP
	return px


## A PRESSABLE BUTTON ON THE FELT: a glossy pill with its caption fitted inside. `lit` is the
## hover or focus state, `enabled` false greys it out. The focus ring is drawn by the caller
## with focus_ring(), the one focus treatment, so this never draws a second one.
static func button(ci: CanvasItem, rect: Rect2, caption: String, fill: Color, enabled: bool,
		lit: bool, press: float = 0.0) -> void:
	var body: Rect2 = rect
	if press > 0.0:
		body = Rect2(rect.position + Vector2(0.0, 3.0 * press), rect.size)
	var colour: Color = fill if enabled else Color(0.32, 0.30, 0.34)
	if lit and enabled:
		colour = colour.lightened(0.12)
	var radius: float = minf(body.size.y * 0.5, 22.0)
	# A drop under the pill, then the pill, then a gloss band on its top half: three rects,
	# and it reads as a thing that goes down when pressed.
	rounded(ci, Rect2(body.position + Vector2(0.0, 5.0), body.size), radius,
		Color(0.0, 0.0, 0.0, 0.35), Color(0, 0, 0, 0), 0.0)
	rounded(ci, body, radius, colour, colour.darkened(0.35) if enabled else GOLD_DIM.darkened(0.4),
		2.0)
	rounded(ci, Rect2(body.position + Vector2(6.0, 4.0),
		Vector2(body.size.x - 12.0, body.size.y * 0.42)), radius * 0.8,
		Color(1.0, 1.0, 1.0, 0.16 if enabled else 0.05), Color(0, 0, 0, 0), 0.0)
	var ink: Color = CARD_INK if colour.get_luminance() > 0.55 else Color(1.0, 0.98, 0.92)
	if not enabled:
		ink = Color(1.0, 1.0, 1.0, 0.40)
	label(ci, MenuStyleScript.title_font(), body.grow_individual(-14.0, -6.0, -14.0, -6.0),
		caption, 28, ink)


## THE ONE FOCUS TREATMENT IN THE WHOLE CASINO. Every focusable thing on every screen gets
## this and nothing else does, so a player who has learned it once has learned it everywhere.
## `t` is a phase in seconds the stage advances; the alpha breathes so a still screenshot and
## a live screen say the same thing.
static func focus_ring(ci: CanvasItem, rect: Rect2, radius: float, t: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	var alpha: float = lerpf(FOCUS_ALPHA_LOW, FOCUS_ALPHA_HIGH, pulse)
	rounded(ci, rect.grow(-FOCUS_INSET), radius, Color(0, 0, 0, 0.0),
		Color(GOLD, alpha), FOCUS_WIDTH)

# --- the glyphs -----------------------------------------------------------------------------
# Every one is authored against the normalised box it is handed, so any glyph can be swapped
# for any other and each works at 34 px on a paytable row, at 60 px on a lobby tile and at
# 300 px as a table's own headboard. `box` is always the whole tile; the shapes inset
# themselves rather than assuming a margin was already applied.


## `f` of the way across `box` and `g` of the way down it. The one place normalised glyph
## coordinates become pixels, so a glyph cannot half apply the box.
static func _at(box: Rect2, f: float, g: float) -> Vector2:
	return box.position + Vector2(box.size.x * f, box.size.y * g)


## Ten points: five outer at `outer` of the half diagonal and five inner at `inner`, starting
## at twelve o'clock so the star stands up rather than leaning.
static func star_points(box: Rect2) -> PackedVector2Array:
	var centre: Vector2 = box.position + box.size * 0.5
	var rx: float = box.size.x * 0.5
	var ry: float = box.size.y * 0.5
	var out := PackedVector2Array()
	for i: int in 10:
		var a: float = -PI * 0.5 + TAU * float(i) / 10.0
		var f: float = 1.0 if i % 2 == 0 else 0.42
		out.append(centre + Vector2(cos(a) * rx * f, sin(a) * ry * f))
	return out


## Radius held at 0.499 of the half box rather than 0.5: a hexagon's flat top and bottom
## vertices land exactly at TAU/4, which is exactly the far edge Rect2.has_point() excludes.
## A whisker under 0.5 keeps every vertex inside without a visible change of size.
static func hexagon_points(box: Rect2) -> PackedVector2Array:
	var centre: Vector2 = box.position + box.size * 0.5
	var out := PackedVector2Array()
	for i: int in 6:
		var a: float = -PI * 0.5 + TAU * float(i) / 6.0
		out.append(centre + Vector2(cos(a) * box.size.x * 0.499, sin(a) * box.size.y * 0.499))
	return out


## The four points sit a whisker inside 0.0 and 1.0 rather than exactly on them, for the same
## reason hexagon_points backs off 0.5: Rect2.has_point() excludes the box's own far edge, and
## a diamond authored to touch it exactly fails containment by one rounding step.
static func diamond_points(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([_at(box, 0.5, 0.002), _at(box, 0.998, 0.5),
		_at(box, 0.5, 0.998), _at(box, 0.002, 0.5)])


## A heart as a polygon rather than as two circles plus a triangle: circles cannot be asserted
## inside a box by the same test the other three suits use, and a suit that is tested a
## different way is a suit whose bug is found a different day.
##
## THE SCALE FACTORS ARE 0.499 AND 0.46, NOT 0.5 AND 0.52. This parametric curve's x reaches
## exactly +-1 (touching the box's far edge, which Rect2.has_point() excludes) and its y
## reaches 1.0625, not 1.0 (the curve's lower lobes overshoot a plain +-1 bound). 0.499 and
## 0.46 are the largest round numbers that keep every one of the 24 sampled points inside.
static func heart_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in 24:
		var t: float = TAU * float(i) / 24.0
		var x: float = pow(sin(t), 3.0)
		var y: float = -(0.8125 * cos(t) - 0.3125 * cos(2.0 * t)
			- 0.125 * cos(3.0 * t) - 0.0625 * cos(4.0 * t))
		out.append(_at(box, 0.5 + x * 0.499, 0.5 + y * 0.46))
	return out


## Same curve as heart_points, upside down, plus a stem. See heart_points on why the scale is
## 0.499 and not 0.5; the vertical offset and scale here are 0.44 and 0.39 rather than 0.44 and
## 0.44 for the matching reason: the curve's upper lobes reach 1.0625, and 0.44 + 1.0625 * 0.44
## clears the box's top edge going the other way.
static func spade_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in 24:
		var t: float = TAU * float(i) / 24.0
		var x: float = pow(sin(t), 3.0)
		var y: float = 0.8125 * cos(t) - 0.3125 * cos(2.0 * t) \
			- 0.125 * cos(3.0 * t) - 0.0625 * cos(4.0 * t)
		out.append(_at(box, 0.5 + x * 0.499, 0.44 + y * 0.39))
	out.append(_at(box, 0.42, 0.86))
	out.append(_at(box, 0.58, 0.86))
	return out


static func club_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for lobe: Array in [[0.5, 0.26, 0.24], [0.28, 0.54, 0.24], [0.72, 0.54, 0.24]]:
		for i: int in 10:
			var a: float = TAU * float(i) / 10.0
			out.append(_at(box, float(lobe[0]) + cos(a) * float(lobe[2]) * 0.5,
				float(lobe[1]) + sin(a) * float(lobe[2]) * 0.5))
	out.append(_at(box, 0.44, 0.94))
	out.append(_at(box, 0.56, 0.94))
	return out


## WHERE THE PIPS GO ON A CARD FACE, in the traditional arrangement. Rank 0 (an Ace) gets one
## centred pip; ranks 1 to 8 (Two through Nine) get their own layout; ranks 9 to 12 get none,
## because a Ten is drawn as ten pips and a court card is drawn as a monogram panel, both of
## which draw_card() handles rather than this table.
static func card_pip_points(rect: Rect2, rank: int) -> PackedVector2Array:
	var cols: Array[float] = [0.30, 0.50, 0.70]
	var rows: Array[float] = [0.26, 0.38, 0.50, 0.62, 0.74]
	var layout: Array = []
	match rank:
		0: layout = [[1, 2]]
		1: layout = [[1, 0], [1, 4]]
		2: layout = [[1, 0], [1, 2], [1, 4]]
		3: layout = [[0, 0], [2, 0], [0, 4], [2, 4]]
		4: layout = [[0, 0], [2, 0], [1, 2], [0, 4], [2, 4]]
		5: layout = [[0, 0], [2, 0], [0, 2], [2, 2], [0, 4], [2, 4]]
		6: layout = [[0, 0], [2, 0], [0, 2], [2, 2], [1, 1], [0, 4], [2, 4]]
		7: layout = [[0, 0], [2, 0], [0, 2], [2, 2], [1, 1], [1, 3], [0, 4], [2, 4]]
		8: layout = [[0, 0], [2, 0], [0, 1], [2, 1], [0, 3], [2, 3], [1, 2],
			[0, 4], [2, 4]]
		9: layout = [[0, 0], [2, 0], [0, 1], [2, 1], [1, 1], [0, 3], [2, 3], [1, 3],
			[0, 4], [2, 4]]
	var out := PackedVector2Array()
	for cell: Array in layout:
		out.append(_at(rect, cols[int(cell[0])], rows[int(cell[1])]))
	return out


## The icon set's picture per Slots.Symbol and per suit (hearts, diamonds, spades, clubs).
const SYMBOL_ICONS: Array[String] = ["reel_apple", "reel_horseshoe", "reel_bell", "reel_gem",
	"reel_star", "reel_rainbow"]
const SUIT_ICONS: Array[String] = ["suit_hearts", "suit_diamonds", "suit_spades", "suit_clubs"]


## One per Slots.Symbol, in enum order: APPLE, HORSESHOE, BELL, GEM, STAR, RAINBOW.
static func draw_symbol(ci: CanvasItem, box: Rect2, symbol: int) -> void:
	# The icon set's reel pictures (P8 S8; playtest 2026-11-08 item 60: "flat clip-art").
	if IconSet.draw(ci, SYMBOL_ICONS[clampi(symbol, 0, SYMBOL_ICONS.size() - 1)], box):
		return
	match symbol:
		SlotsScript.Symbol.APPLE:
			ci.draw_circle(_at(box, 0.5, 0.60), box.size.y * 0.32, Color(0.85, 0.20, 0.22))
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.52, 0.24),
				_at(box, 0.82, 0.16), _at(box, 0.58, 0.34)]), Color(0.32, 0.62, 0.28))
			ci.draw_line(_at(box, 0.50, 0.30), _at(box, 0.50, 0.12),
				Color(0.38, 0.26, 0.16), 3.0, true)
		SlotsScript.Symbol.HORSESHOE:
			# A lucky horseshoe, open side down: a thick arc over the top, the two heels as
			# blocks, and the nail holes along the arc so it cannot read as a smile.
			var centre: Vector2 = _at(box, 0.5, 0.56)
			var r: float = box.size.y * 0.30
			var w: float = box.size.y * 0.15
			ci.draw_arc(centre, r, PI * 0.82, PI * 2.18, 28, GOLD_DIM.darkened(0.2), w + 4.0, true)
			ci.draw_arc(centre, r, PI * 0.82, PI * 2.18, 28, GOLD, w, true)
			for end: float in [PI * 0.82, PI * 2.18]:
				var heel: Vector2 = centre + Vector2(cos(end), sin(end)) * r
				ci.draw_rect(Rect2(heel - Vector2(w * 0.6, 0.0), Vector2(w * 1.2, w * 0.8)),
					GOLD_DIM)
			for k: int in 6:
				var a: float = lerpf(PI * 0.98, PI * 2.02, float(k) / 5.0)
				ci.draw_circle(centre + Vector2(cos(a), sin(a)) * r, box.size.y * 0.025,
					PLUM_DARK)
		SlotsScript.Symbol.BELL:
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.30, 0.70),
				_at(box, 0.38, 0.24), _at(box, 0.62, 0.24), _at(box, 0.70, 0.70)]),
				Color(0.93, 0.76, 0.30))
			ci.draw_rect(Rect2(_at(box, 0.24, 0.70),
				Vector2(box.size.x * 0.52, box.size.y * 0.09)), GOLD_DIM)
			ci.draw_circle(_at(box, 0.5, 0.86), box.size.y * 0.07, GOLD_DIM)
		SlotsScript.Symbol.GEM:
			ci.draw_colored_polygon(hexagon_points(box), Color(0.42, 0.76, 0.86))
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.5, 0.0),
				_at(box, 0.5, 0.5), _at(box, 0.06, 0.25)]), Color(0.66, 0.90, 0.96))
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.5, 0.0),
				_at(box, 0.5, 0.5), _at(box, 0.94, 0.25)]), Color(0.30, 0.62, 0.76))
		SlotsScript.Symbol.STAR:
			ci.draw_colored_polygon(star_points(box), GOLD)
		SlotsScript.Symbol.RAINBOW:
			# Six bands inside the box: the outer radius is half the box's narrower side, so a
			# rainbow never spills into the next tile on a paytable row.
			var arc_centre: Vector2 = _at(box, 0.5, 0.80)
			var outer: float = minf(box.size.x * 0.48, box.size.y * 0.66)
			var band_w: float = outer * 0.11
			for band: int in BAND_COLORS.size():
				var r: float = outer - band_w * 0.5 - band_w * float(band)
				ci.draw_arc(arc_centre, r, PI, TAU, 24, BAND_COLORS[band], band_w + 0.5, true)


## THE CLUB IS FOUR POLYGONS, NOT ONE. club_points() is three disjoint circular lobes plus a
## stem, concatenated into a single array for the containment test; fed to draw_colored_polygon
## as one shape it is not a simple polygon (three separate loops in one boundary) and Godot's
## triangulator refuses it outright. Slicing the same points into their four independent loops
## draws the identical club without asking the triangulator to close a shape that never was one.
static func draw_suit(ci: CanvasItem, box: Rect2, suit: int) -> void:
	# The icon set's suits (P8 S8; item 59: the clubs drew as broken dots).
	if IconSet.draw(ci, SUIT_ICONS[clampi(suit, 0, 3)], box):
		return
	var colour: Color = SUIT_COLORS[clampi(suit, 0, SUIT_COLORS.size() - 1)]
	match clampi(suit, 0, 3):
		0: ci.draw_colored_polygon(heart_points(box), colour)
		1: ci.draw_colored_polygon(diamond_points(box), colour)
		2: ci.draw_colored_polygon(spade_points(box), colour)
		3:
			var pts: PackedVector2Array = club_points(box)
			ci.draw_colored_polygon(pts.slice(0, 10), colour)
			ci.draw_colored_polygon(pts.slice(10, 20), colour)
			ci.draw_colored_polygon(pts.slice(20, 30), colour)
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.46, 0.60),
				_at(box, 0.54, 0.60), pts[31], pts[30]]), colour)


## ONE PLAYING CARD. `card` is Blackjack's own 0 to 51 index; the rank is card % RANKS and the
## suit is card / RANKS. See game/ui/blackjack_menu.gd for why deriving a suit here cannot
## touch a payout. An out of range card draws a back, which is what a stage handed a bad push
## should show rather than an error.
const CARD_RANK_LETTERS: Array[String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9",
	"10", "J", "Q", "K"]


static func draw_card(ci: CanvasItem, rect: Rect2, font: Font, card: int,
		face_up: bool) -> void:
	if not face_up or card < 0 or card >= 52:
		rounded(ci, rect, 8.0, PLUM, GOLD, 2.0)
		# THE HATCH STAYS ON THE CARD (2026-11-05 render: it ran off both sides onto the felt).
		# Each 45 degree line is cut to the inset back's own left and right edges.
		var back: Rect2 = rect.grow(-5.0)
		var h: float = back.size.y
		var step: float = rect.size.x * 0.22
		var x: float = back.position.x - h
		while x < back.end.x:
			var t0: float = clampf((back.position.x - x) / h, 0.0, 1.0)
			var t1: float = clampf((back.end.x - x) / h, 0.0, 1.0)
			if t1 > t0:
				ci.draw_line(Vector2(x + h * t0, back.end.y - h * t0),
					Vector2(x + h * t1, back.end.y - h * t1), Color(GOLD_DIM, 0.55), 1.5, true)
			x += step
		return
	var rank: int = card % 13
	var suit: int = card / 13
	rounded(ci, rect, 8.0, CARD_FACE, CARD_INK, 1.0)
	var letter: String = CARD_RANK_LETTERS[rank]
	var colour: Color = SUIT_COLORS[suit]
	# THE INDEX SITS IN FROM THE EDGE (item 59: "corner numbers touch the edge"): a tenth of
	# the card's width in, as a printed card's is, with its suit under it at both ends.
	var inset: float = maxf(8.0, rect.size.x * 0.1)
	text(ci, font, rect.position + Vector2(inset, inset + 18.0), letter, 20, colour,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	text(ci, font, rect.position + rect.size - Vector2(inset, inset + 14.0), letter, 20, colour,
		HORIZONTAL_ALIGNMENT_RIGHT, -1.0)
	draw_suit(ci, Rect2(rect.position + Vector2(inset - 1.0, inset + 22.0), Vector2(16.0, 16.0)), suit)
	draw_suit(ci, Rect2(rect.position + rect.size - Vector2(inset + 15.0, inset + 12.0),
		Vector2(16.0, 16.0)), suit)
	if rank >= 10:
		var panel := Rect2(rect.position + rect.size * Vector2(0.22, 0.26),
			rect.size * Vector2(0.56, 0.48))
		rounded(ci, panel, 4.0, Color(GOLD_DIM, 0.35), GOLD_DIM, 1.0)
		text(ci, font, panel.position + Vector2(panel.size.x * 0.5, panel.size.y * 0.72),
			letter, 30, colour, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		return
	var pip_size: float = rect.size.x * (0.34 if rank == 0 else 0.19)
	for p: Vector2 in card_pip_points(rect, rank):
		draw_suit(ci, Rect2(p - Vector2(pip_size, pip_size) * 0.5,
			Vector2(pip_size, pip_size)), suit)


## ONE PER CasinoMenu.Row: CAGE, SLOTS, WHEEL, BLACKJACK, RACING, RULES. Works at 60 px on a
## lobby tile and at 300 px as a table's own headboard, so the picker and the room agree with
## each other by construction rather than by somebody remembering to update both.
static func draw_room(ci: CanvasItem, box: Rect2, row: int) -> void:
	match row:
		0:
			ci.draw_arc(_at(box, 0.5, 0.72), box.size.y * 0.36, PI, TAU, 24, GOLD_DIM,
				6.0, true)
			chip_stack(ci, _at(box, 0.5, 0.80), 4, CHIP_COLORS[1], box.size.y * 0.06)
		1:
			rounded(ci, Rect2(_at(box, 0.14, 0.10),
				box.size * Vector2(0.72, 0.80)), 8.0, PLUM, GOLD, 2.0)
			for i: int in 3:
				var window := Rect2(_at(box, 0.20 + 0.20 * float(i), 0.30),
					box.size * Vector2(0.16, 0.28))
				rounded(ci, window, 4.0, Color(0.06, 0.05, 0.09), GOLD_DIM, 1.0)
				draw_symbol(ci, window.grow(-2.0), i + 1)
		2:
			# The big wheel in miniature: fifteen slices in the tier colours, a third of the
			# real wheel's forty five, in the same proportions near enough.
			var slices: Array[int] = [4, 0, 1, 0, 2, 0, 3, 0, 1, 0, 2, 0, 1, 0, 3]
			ci.draw_circle(_at(box, 0.5, 0.5), box.size.y * 0.47, GOLD_DIM)
			for i: int in slices.size():
				var from_angle: float = TAU * float(i) / float(slices.size()) - PI * 0.5
				var to_angle: float = TAU * float(i + 1) / float(slices.size()) - PI * 0.5
				ci.draw_colored_polygon(sector_points(_at(box, 0.5, 0.5),
					box.size.y * 0.14, box.size.y * 0.44, from_angle, to_angle),
					TIER_COLOURS[slices[i]])
			ci.draw_circle(_at(box, 0.5, 0.5), box.size.y * 0.14, GOLD)
			ci.draw_colored_polygon(PackedVector2Array([_at(box, 0.44, 0.0),
				_at(box, 0.56, 0.0), _at(box, 0.5, 0.14)]), GOLD)
		3:
			for i: int in 3:
				var card := Rect2(_at(box, 0.22 + 0.16 * float(i), 0.22),
					box.size * Vector2(0.26, 0.56))
				rounded(ci, card, 6.0, CARD_FACE, CARD_INK, 1.0)
				draw_suit(ci, card.grow(-card.size.x * 0.28), i)
		4:
			ci.draw_line(_at(box, 0.05, 0.74), _at(box, 0.95, 0.74), GOLD_DIM, 4.0, true)
			ci.draw_line(_at(box, 0.86, 0.74), _at(box, 0.86, 0.22), GOLD, 5.0, true)
			for part: Array in [[0.24, 0.50, 0.26, 0.14], [0.30, 0.64, 0.08, 0.14],
					[0.44, 0.64, 0.08, 0.14]]:
				rounded(ci, Rect2(_at(box, float(part[0]), float(part[1])),
					box.size * Vector2(float(part[2]), float(part[3]))),
					4.0, BAND_COLORS[0], BAND_COLORS[0], 0.0)
		5:
			rounded(ci, Rect2(_at(box, 0.16, 0.14), box.size * Vector2(0.68, 0.72)),
				6.0, FELT_DARK, GOLD, 2.0)
			for i: int in 4:
				ci.draw_line(_at(box, 0.24, 0.30 + 0.14 * float(i)),
					_at(box, 0.76, 0.30 + 0.14 * float(i)), Color(GOLD_DIM, 0.8), 2.0, true)


## The wallet icons: a bit is a gold coin with a notch cut out of its rim, a chip is a chip.
static func draw_bit(ci: CanvasItem, box: Rect2) -> void:
	var centre: Vector2 = box.position + box.size * 0.5
	var r: float = minf(box.size.x, box.size.y) * 0.5
	ci.draw_circle(centre, r, GOLD)
	ci.draw_circle(centre, r * 0.72, GOLD_DIM)
	ci.draw_line(centre + Vector2(r * 0.30, -r * 0.30), centre + Vector2(r, -r),
		Color(0, 0, 0, 0.0), 1.0, true)


static func draw_chip_icon(ci: CanvasItem, box: Rect2) -> void:
	var centre: Vector2 = box.position + box.size * 0.5
	chip(ci, centre, minf(box.size.x, box.size.y) * 0.5, CHIP_COLORS[1], true)
