extends GutTest
## THE CASINO'S DRAWING VOCABULARY, AS GEOMETRY. Every glyph in game/ui/casino_paint.gd is
## split into a pure *_points() half and a three line draw_* half, for exactly this reason:
## a headless gate has no GPU and cannot look at a picture, but it can assert that a star has
## ten points, that a hexagon has six, and that neither of them leaks outside the box it was
## handed. A glyph that draws off its own tile is the defect this catches, and it is the one
## that actually happens when a shape is authored by eye in normalised coordinates.
##
## IT ALSO CARRIES THE NO RIGGING RULE. See the last test in this file.
##
## Preloads by path rather than by class_name, per the convention at the top of
## game/scripts/pony_rig.gd (the global class cache lives in the gitignored game/.godot/ and
## a fresh clone has not built it yet).

const PaintScript := preload("res://ui/casino_paint.gd")
const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

## An off origin, non square box, deliberately. A glyph authored against a unit square at the
## origin passes a containment test at (0, 0, 1, 1) by accident.
const BOX := Rect2(37.0, 11.0, 88.0, 64.0)


func _all_inside(points: PackedVector2Array, box: Rect2, what: String) -> void:
	assert_gt(points.size(), 2, "%s must be a polygon, not a point" % what)
	for p: Vector2 in points:
		assert_true(box.has_point(p),
			"%s leaks outside its box: %s not in %s" % [what, p, box])


func test_a_star_has_ten_points_and_stays_in_its_box() -> void:
	var points: PackedVector2Array = PaintScript.star_points(BOX)
	assert_eq(points.size(), 10, "five outer and five inner")
	_all_inside(points, BOX, "star")


func test_a_hexagon_has_six_points_and_stays_in_its_box() -> void:
	var points: PackedVector2Array = PaintScript.hexagon_points(BOX)
	assert_eq(points.size(), 6)
	_all_inside(points, BOX, "hexagon")


func test_a_diamond_has_four_points_and_stays_in_its_box() -> void:
	var points: PackedVector2Array = PaintScript.diamond_points(BOX)
	assert_eq(points.size(), 4)
	_all_inside(points, BOX, "diamond")


func test_every_card_suit_stays_in_its_box() -> void:
	for pair: Array in [[PaintScript.heart_points(BOX), "heart"],
			[PaintScript.spade_points(BOX), "spade"],
			[PaintScript.club_points(BOX), "club"],
			[PaintScript.diamond_points(BOX), "diamond"]]:
		_all_inside(pair[0] as PackedVector2Array, BOX, String(pair[1]))


## An ellipse is a polygon here because Godot draws circles and not ellipses, and a chip seen
## at a slight angle is an ellipse.
func test_an_ellipse_is_a_closed_ring_of_points_around_its_centre() -> void:
	var points: PackedVector2Array = PaintScript.ellipse_points(Vector2(50.0, 50.0), 20.0, 8.0)
	assert_eq(points.size(), 28, "28 segments: smooth at a chip's size, cheap at a stack's")
	_all_inside(points, Rect2(29.9, 41.9, 40.2, 16.2), "ellipse")


## THE WHEEL'S POCKETS ARE THESE. An annular sector is two arcs and two radial edges; a
## sector whose points did not lie between the two radii would draw a pocket over the hub.
func test_an_annular_sector_stays_between_its_two_radii() -> void:
	var centre := Vector2(200.0, 200.0)
	var points: PackedVector2Array = PaintScript.sector_points(centre, 78.0, 236.0, 0.0, 0.4)
	assert_gt(points.size(), 3)
	for p: Vector2 in points:
		var r: float = centre.distance_to(p)
		assert_between(r, 77.9, 236.1, "a sector point sits between the inner and outer rim")


## SIX SYMBOLS, SIX ROOMS, FOUR SUITS: every enum the kit draws for has a glyph, so a stage
## can never ask for one that is not there. Asked of the enums themselves rather than of a
## number, so adding a seventh slot symbol fails here rather than drawing nothing.
##
## THE CALLS HAPPEN INSIDE THE CONTROL'S OWN "draw" SIGNAL, not directly in this function body.
## Every draw_* call in casino_paint.gd ends in a CanvasItem draw_* call, and Godot's engine
## enforces (even headless) that those may only run while the item is actually processing
## NOTIFICATION_DRAW; called any other time, they log an engine error, and GUT fails a test
## that logs one. queue_redraw() plus two awaited process frames is what actually gets there.
func test_every_slot_symbol_and_every_lobby_room_has_a_glyph() -> void:
	var control := Control.new()
	add_child_autofree(control)
	control.draw.connect(func() -> void:
		for symbol: int in range(SlotsScript.SYMBOL_NAMES.size()):
			PaintScript.draw_symbol(control, BOX, symbol)
		for row: int in range(6):
			PaintScript.draw_room(control, BOX, row)
		for suit: int in range(4):
			PaintScript.draw_suit(control, BOX, suit))
	control.queue_redraw()
	await wait_process_frames(2)
	assert_eq(PaintScript.SUIT_COLORS.size(), 4)
	pass_test("every glyph the enums name drew without erroring")


## ONE RAINBOW, TWO PLACES. The six race lanes and the slots RAINBOW symbol are the same six
## colours in the same order, so the building reads as one building; the wheel has its own
## five tier colours, one per tier.
func test_the_band_colours_are_a_rainbow_and_the_tiers_have_one_colour_each() -> void:
	assert_eq(PaintScript.BAND_COLORS.size(), 6)
	assert_eq(PaintScript.TIER_COLOURS.size(), WheelScript.TIERS)


## NOTHING DRAWN SPILLS, AT ANY TEXT SIZE (playtest 2026-11-05: a rules box cut off on the
## right, a banner's words out of their plate). fit_size() and paragraph_size() are what every
## casino stage sizes its words with; both must land inside the box at 100, 125 and 150.
func test_fitted_text_and_wrapped_paragraphs_stay_in_their_boxes_at_every_text_size() -> void:
	var font: Font = MenuStyleScript.title_font()
	var lines: Array[String] = WheelScript.rules_lines()
	for scale: float in [1.0, 1.25, 1.5]:
		MenuStyleScript.text_scale = scale
		var px: int = PaintScript.fit_size(font, "Dealer busts", 44, 300.0)
		assert_lte(font.get_string_size("Dealer busts", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x,
			300.0, "scale %.2f" % scale)
		var box := Vector2(420.0, 300.0)
		var para: int = PaintScript.paragraph_size(font, lines, 22, box)
		assert_lte(PaintScript.paragraph_height(font, lines, para, box.x), box.y,
			"scale %.2f: the rules fit their card" % scale)
		assert_gte(para, PaintScript.MIN_FIT_PX)
	MenuStyleScript.text_scale = 1.0


func test_a_bigger_text_size_draws_bigger_where_there_is_room() -> void:
	var font: Font = MenuStyleScript.title_font()
	MenuStyleScript.text_scale = 1.0
	var small: int = PaintScript.fit_size(font, "Hit", 28, 400.0)
	MenuStyleScript.text_scale = 1.5
	var big: int = PaintScript.fit_size(font, "Hit", 28, 400.0)
	MenuStyleScript.text_scale = 1.0
	assert_gt(big, small, "the setting reaches the felt")


## THE CHIP COLOURS AND THE STAKES ARE THE SAME LIST. A fourth stake with no chip colour
## would draw a black token; a fourth colour with no stake is a colour nobody sees.
func test_there_is_one_chip_colour_per_stake() -> void:
	var stakes: Array = load("res://ui/table_menu.gd").STAKES
	assert_eq(PaintScript.CHIP_COLORS.size(), stakes.size())


## NO RIGGING, AND IT IS CHECKED RATHER THAN REMEMBERED. game/systems/ owns every outcome in
## this casino; game/ui/ draws what it is told. A generator constructed under game/ui/ is the
## one change that could quietly make a stage decide something, so the source is swept for it.
## Source text rather than behaviour, deliberately: behaviour can only catch the rigging that
## already shipped, and this catches the line that would have made it possible.
func test_no_random_generator_lives_anywhere_under_game_ui() -> void:
	var offenders: Array[String] = []
	for file: String in DirAccess.get_files_at("res://ui"):
		if not file.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string("res://ui/".path_join(file))
		for banned: String in ["RandomNumberGenerator", "randi(", "randf(", "randi_range",
				"randf_range", "rand_from_seed"]:
			if text.contains(banned):
				offenders.append("%s carries %s" % [file, banned])
	assert_eq(offenders, [] as Array[String],
		"the menus draw and emit; nothing under game/ui/ may roll anything")
