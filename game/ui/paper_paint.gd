class_name PaperPaint
extends RefCounted
## THE STATIONERY KIT: paper, a letterhead, an envelope card, a rubber stamp and a coupon,
## drawn straight onto a CanvasItem. The casino got a felt and chip kit
## (game/ui/casino_paint.gd) and the mail gets this one, built ON that kit's primitives
## (rounded, text, ellipse, focus_ring) rather than beside them, so there is one rounded
## rectangle and one outlined string in the whole game.
##
## THE SPLIT IS THE SAME AS THE CASINO'S. Every shape is a pure *_points() function against
## a normalised box plus a three line draw_* half, so game/test/test_paper_paint.gd can
## assert that the Company's mark is closed and inside its box without a viewport.
##
## NOTHING HERE ROLLS ANYTHING, and nothing here reads game state: a kit that could produce
## two different pages from the same arguments is a kit no screenshot proves anything about.
##
## draw_* CALLS ARE LEGAL ONLY INSIDE A NOTIFICATION_DRAW CONTEXT, which in this project
## means inside the function connected to a Control's `draw` signal. Every function here
## takes that CanvasItem as its first argument for exactly that reason.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const PaintScript := preload("res://ui/casino_paint.gd")

## THE PAPER. Warm off white at full opacity, over the translucent navy panel every menu in
## the game sits on, so a letter reads as a sheet laid on the table rather than as a lighter
## patch of the table.
const PAPER := Color(0.96, 0.94, 0.88, 0.97)
const PAPER_EDGE := Color(0.72, 0.68, 0.58, 0.90)
const PAPER_SHADOW := Color(0.0, 0.0, 0.0, 0.28)

## THE INK. Dark, not black: printed text on cream is never pure black, and the difference
## is most of why a page reads as printed.
const INK := Color(0.13, 0.12, 0.15, 1.0)
const INK_DIM := Color(0.13, 0.12, 0.15, 0.62)

## THE COMPANY'S OWN COLOURS, taken from the Depot's walls in game/world/ranch.tscn
## (Color(0.62, 0.64, 0.68) over Color(0.3, 0.34, 0.4)) so the letterhead on the page and
## the building on the map are the same company.
const COMPANY_BAND := Color(0.20, 0.24, 0.34, 1.0)
const COMPANY_TRIM := Color(0.62, 0.64, 0.68, 1.0)

## The unread mark on an envelope card: a blob of sealing wax.
const WAX := Color(0.78, 0.20, 0.22, 1.0)

## The rubber stamp a letter carries once it has been answered, and the coupon's ink.
const STAMP_INK := Color(0.36, 0.16, 0.42, 0.85)

const SHEET_RADIUS := 10.0
const CARD_RADIUS := 8.0
const SHADOW_OFFSET := Vector2(3.0, 4.0)

## THE ENVELOPE FLAP'S APEX, as a fraction of the card's height. Confined to the top band
## deliberately: a card this wide (660 x 68 on the Mail page) reads the flap as a hairline
## through the sender line and the title the moment it reaches anywhere near either baseline
## (final review, IMPORTANT 2). Kept well clear of both by staying inside the top third.
const FLAP_APEX_FRACTION := 0.28

## The cloud in the Company's mark, as a closed polygon: three lobes over a flat base.
## Authored against the normalised box it is handed, so it works at 22 px on an envelope
## card and at 60 px on a letterhead.
const _CLOUD: Array[Vector2] = [
	Vector2(0.08, 0.72), Vector2(0.10, 0.52), Vector2(0.20, 0.42), Vector2(0.26, 0.26),
	Vector2(0.42, 0.18), Vector2(0.58, 0.24), Vector2(0.68, 0.16), Vector2(0.84, 0.26),
	Vector2(0.90, 0.44), Vector2(0.94, 0.60), Vector2(0.90, 0.72), Vector2(0.50, 0.76),
]

## The bolt under it. Two strokes of a zigzag, closed.
const _BOLT: Array[Vector2] = [
	Vector2(0.52, 0.60), Vector2(0.40, 0.92), Vector2(0.50, 0.88), Vector2(0.44, 0.98),
	Vector2(0.62, 0.74), Vector2(0.52, 0.76),
]


static func _at(box: Rect2, point: Vector2) -> Vector2:
	return box.position + Vector2(box.size.x * point.x, box.size.y * point.y)


static func logo_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point: Vector2 in _CLOUD:
		out.append(_at(box, point))
	return out


static func bolt_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point: Vector2 in _BOLT:
		out.append(_at(box, point))
	return out


## THE ENVELOPE FLAP: a triangle from the card's top corners down to a single apex, confined
## to FLAP_APEX_FRACTION of the box's height. Pure and box relative, like logo_points() and
## bolt_points() above, so test_paper_paint.gd can pin the shape without a viewport.
static func flap_points(box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(box.position + Vector2(10.0, 2.0))
	out.append(box.position + Vector2(box.size.x - 10.0, 2.0))
	out.append(box.position + Vector2(box.size.x * 0.5, box.size.y * FLAP_APEX_FRACTION))
	return out


## The Company's mark: cloud, bolt, no words. The building on the map wears the same one.
static func logo_mark(ci: CanvasItem, box: Rect2, cloud: Color, bolt: Color) -> void:
	ci.draw_colored_polygon(logo_points(box), cloud)
	ci.draw_colored_polygon(bolt_points(box), bolt)


## A SHEET OF PAPER: a soft drop shadow, the paper, and a hairline edge. The shadow is what
## makes it a sheet ON something rather than a rectangle IN something, and it is one extra
## rounded rectangle.
static func sheet(ci: CanvasItem, rect: Rect2) -> void:
	PaintScript.rounded(ci, Rect2(rect.position + SHADOW_OFFSET, rect.size), SHEET_RADIUS,
		PAPER_SHADOW, Color(0, 0, 0, 0), 0.0)
	PaintScript.rounded(ci, rect, SHEET_RADIUS, PAPER, PAPER_EDGE, 1.0)
	# Stationery, not a form: a gold hairline frame inset from the edge, the way good
	# notepaper is printed (Fable AAA review round 1, #8: "word-processor letters").
	if rect.size.y > 120.0:
		PaintScript.rounded(ci, rect.grow(-12.0), SHEET_RADIUS * 0.6, Color(0, 0, 0, 0),
			Color(PaintScript.GOLD_DIM, 0.55), 1.5)


## THE LETTERHEAD: a band across the top of a sheet, the mark at its left, the sender's name
## beside it, and a trim line under it. This is the one piece that says "the Company wrote
## this" before a word of the body is read.
##
## NO CORPORATE NAVY BAND (Fable AAA review round 1, #8; Animal Crossing's letters): the sender
## signs the top of the page in a slanted display hand in plum ink, a small postage stamp
## carrying the Company's mark sits in the corner, and a gold and plum double rule closes the
## head. The name is still the first thing read, and still the sender's own words.
static func letterhead(ci: CanvasItem, rect: Rect2, _font: Font, sender: String) -> void:
	var stamp_box := Rect2(Vector2(rect.end.x - 52.0, rect.position.y + 2.0), Vector2(50.0, 56.0))
	postage(ci, stamp_box)
	var hand := hand_font()
	var px := 34
	while px > 18 and hand.get_string_size(sender, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x \
			> rect.size.x - 76.0:
		px -= 1
	ci.draw_string(hand, rect.position + Vector2(2.0, 40.0), sender, HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 76.0, px, HAND_INK)
	var y := rect.position.y + 58.0
	ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x - 60.0, y),
		Color(PaintScript.GOLD_DIM, 0.9), 2.0, true)
	ci.draw_line(Vector2(rect.position.x, y + 4.0), Vector2(rect.end.x - 60.0, y + 4.0),
		Color(HAND_INK, 0.35), 1.0, true)


## The sender's hand: the display face, slanted and heavy, in plum ink. Not a script font (the
## project ships none), but a signature's lean and weight on paper.
const HAND_INK := Color(0.32, 0.12, 0.38)
static var _hand: FontVariation = null


static func hand_font() -> FontVariation:
	if _hand == null:
		_hand = FontVariation.new()
		_hand.base_font = MenuStyleScript.title_font().base_font
		_hand.variation_opentype = {2003265652: 600}
		_hand.variation_transform = Transform2D(0.0, Vector2.ONE, -0.3, Vector2.ZERO)
		_hand.spacing_glyph = 1
	return _hand


## A postage stamp: a perforated white edge, a plum face and the Company's mark on it.
static func postage(ci: CanvasItem, box: Rect2) -> void:
	PaintScript.rounded(ci, Rect2(box.position + Vector2(2, 3), box.size), 2.0,
		Color(0, 0, 0, 0.18), Color(0, 0, 0, 0), 0.0)
	PaintScript.rounded(ci, box, 2.0, Color(1, 1, 1), PAPER_EDGE, 1.0)
	# The perforation: paper-coloured bites along every edge.
	var bite := 3.0
	var n := 6
	for i in n + 1:
		var fx := box.position.x + box.size.x * float(i) / float(n)
		ci.draw_circle(Vector2(fx, box.position.y), bite, PAPER)
		ci.draw_circle(Vector2(fx, box.end.y), bite, PAPER)
		var fy := box.position.y + box.size.y * float(i) / float(n)
		ci.draw_circle(Vector2(box.position.x, fy), bite, PAPER)
		ci.draw_circle(Vector2(box.end.x, fy), bite, PAPER)
	var face := box.grow(-6.0)
	PaintScript.rounded(ci, face, 1.0, PaintScript.PLUM, PaintScript.GOLD_DIM, 1.0)
	logo_mark(ci, face.grow(-5.0), Color(1, 1, 1, 0.9), PaintScript.GOLD)


## A WAX SEAL: a puddle of wax with a soft uneven edge, a pressed ring and the sender's mark
## embossed in it, two ribbon tails under it. `mark` false leaves the face plain.
static func wax_seal(ci: CanvasItem, centre: Vector2, r: float, mark := true) -> void:
	# The ribbon tails, behind.
	for side: float in [-1.0, 1.0]:
		var base := centre + Vector2(side * r * 0.35, r * 0.4)
		ci.draw_colored_polygon(PackedVector2Array([base, base + Vector2(side * r * 0.25, 0),
			base + Vector2(side * r * 0.55, r * 1.05), base + Vector2(side * r * 0.3, r * 0.85),
			base + Vector2(side * r * 0.05, r * 1.1)]), PaintScript.PLUM)
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		var wob := 1.0 + 0.06 * sin(a * 5.0 + 0.7) + 0.035 * sin(a * 11.0)
		pts.append(centre + Vector2(cos(a), sin(a)) * r * wob)
	ci.draw_colored_polygon(pts, WAX.darkened(0.25))
	ci.draw_circle(centre + Vector2(-r * 0.04, -r * 0.05), r * 0.86, WAX)
	ci.draw_arc(centre, r * 0.66, 0.0, TAU, 32, WAX.darkened(0.3), 2.0, true)
	ci.draw_arc(centre + Vector2(-1, -1), r * 0.66, PI * 1.0, PI * 1.6, 12, WAX.lightened(0.35), 1.5, true)
	if mark:
		var m := Rect2(centre - Vector2(r, r) * 0.42, Vector2(r, r) * 0.84)
		logo_mark(ci, Rect2(m.position + Vector2(1, 1.5), m.size), WAX.darkened(0.4), WAX.darkened(0.4))
		logo_mark(ci, m, WAX.lightened(0.28), Color(1.0, 0.85, 0.55, 0.9))
	# A gloss on the wax.
	ci.draw_circle(centre + Vector2(-r * 0.42, -r * 0.45), r * 0.12, Color(1, 1, 1, 0.35))


## ONE ENVELOPE IN THE LIST: a card, the sender in small dim type, the title in ink, a blob
## of wax while it is unread, and the one focus treatment this game uses when the cursor is
## on it. `t` is the stage's animation phase, so the ring breathes exactly as it does on
## every casino screen.
static func envelope(ci: CanvasItem, rect: Rect2, font: Font, sender: String, title: String,
		unread: bool, picked: bool, t: float) -> void:
	PaintScript.rounded(ci, rect, CARD_RADIUS, PAPER if unread else Color(PAPER, 0.82),
		PAPER_EDGE, 1.0)
	# THE FLAP. A filled triangle over the top band, not two lines crossing the whole card:
	# on a card this wide a pair of near horizontal strokes read as a scratch through the
	# sender line and the title rather than as a flap (final review, IMPORTANT 2). A fill
	# reads as a shape at a glance regardless of how shallow the angle a card this shape can
	# afford actually is; the two edge strokes are kept on top of it for definition.
	var flap: PackedVector2Array = flap_points(rect)
	ci.draw_colored_polygon(flap, Color(PAPER_EDGE, 0.25))
	ci.draw_line(flap[0], flap[2], PAPER_EDGE, 1.0, true)
	ci.draw_line(flap[1], flap[2], PAPER_EDGE, 1.0, true)
	PaintScript.text(ci, font, rect.position + Vector2(16.0, 36.0), sender,
		MenuStyleScript.SUBTITLE_SIZE, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 70.0)
	PaintScript.text(ci, font, rect.position + Vector2(16.0, 58.0), title,
		MenuStyleScript.ROW_SIZE, INK, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 70.0)
	if unread:
		PaintScript.ellipse(ci, rect.position + Vector2(rect.size.x - 28.0, 30.0), 11.0, 11.0,
			WAX, Color(WAX.darkened(0.3), 0.9))
	if picked:
		PaintScript.focus_ring(ci, rect, CARD_RADIUS, t)


## A RUBBER STAMP, for a letter that has been answered. A double border at a slight offset
## and a word inside it, in the ink a stamp pad actually leaves.
static func stamp(ci: CanvasItem, rect: Rect2, font: Font, word: String) -> void:
	PaintScript.rounded(ci, rect, 4.0, Color(STAMP_INK, 0.10), STAMP_INK, 3.0)
	PaintScript.rounded(ci, rect.grow(-5.0), 2.0, Color(0, 0, 0, 0.0), Color(STAMP_INK, 0.7),
		1.0)
	PaintScript.text(ci, font, rect.position + Vector2(0.0, rect.size.y * 0.68), word,
		MenuStyleScript.SUBTITLE_SIZE, STAMP_INK, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


## A COUPON: a ticket with a notch bitten out of each end and one line of text on it. The
## notches are drawn in `behind`, the colour of whatever the coupon is lying on, which is
## how a ticket gets its shape without a second polygon.
static func coupon(ci: CanvasItem, rect: Rect2, font: Font, line: String,
		behind: Color) -> void:
	PaintScript.rounded(ci, rect, 6.0, Color(0.99, 0.97, 0.86, 1.0), STAMP_INK, 2.0)
	var r: float = rect.size.y * 0.22
	PaintScript.ellipse(ci, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5),
		r, r, behind, behind)
	PaintScript.ellipse(ci,
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y * 0.5),
		r, r, behind, behind)
	PaintScript.text(ci, font, rect.position + Vector2(0.0, rect.size.y * 0.66), line,
		MenuStyleScript.SUBTITLE_SIZE, STAMP_INK, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
