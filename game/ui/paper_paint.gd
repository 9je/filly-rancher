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


## THE LETTERHEAD: a band across the top of a sheet, the mark at its left, the sender's name
## beside it, and a trim line under it. This is the one piece that says "the Company wrote
## this" before a word of the body is read.
static func letterhead(ci: CanvasItem, rect: Rect2, font: Font, sender: String) -> void:
	var band := Rect2(rect.position, Vector2(rect.size.x, 54.0))
	PaintScript.rounded(ci, band, SHEET_RADIUS, COMPANY_BAND, COMPANY_TRIM, 1.0)
	logo_mark(ci, Rect2(band.position + Vector2(14.0, 10.0), Vector2(34.0, 34.0)),
		COMPANY_TRIM, Color(0.98, 0.86, 0.45, 1.0))
	PaintScript.text(ci, font, band.position + Vector2(60.0, 36.0), sender,
		MenuStyleScript.SUBTITLE_SIZE, Color(0.94, 0.95, 0.98, 1.0),
		HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 76.0)


## ONE ENVELOPE IN THE LIST: a card, the sender in small dim type, the title in ink, a blob
## of wax while it is unread, and the one focus treatment this game uses when the cursor is
## on it. `t` is the stage's animation phase, so the ring breathes exactly as it does on
## every casino screen.
static func envelope(ci: CanvasItem, rect: Rect2, font: Font, sender: String, title: String,
		unread: bool, picked: bool, t: float) -> void:
	PaintScript.rounded(ci, rect, CARD_RADIUS, PAPER if unread else Color(PAPER, 0.82),
		PAPER_EDGE, 1.0)
	# THE FLAP. Two lines from the top corners to the middle of the top edge: the whole
	# reason a card reads as an envelope rather than as a button.
	var left: Vector2 = rect.position + Vector2(10.0, 2.0)
	var right: Vector2 = rect.position + Vector2(rect.size.x - 10.0, 2.0)
	var point: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.52)
	ci.draw_line(left, point, PAPER_EDGE, 1.0, true)
	ci.draw_line(right, point, PAPER_EDGE, 1.0, true)
	PaintScript.text(ci, font, rect.position + Vector2(16.0, 26.0), sender,
		MenuStyleScript.SUBTITLE_SIZE, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 70.0)
	PaintScript.text(ci, font, rect.position + Vector2(16.0, 52.0), title,
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
