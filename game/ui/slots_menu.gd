class_name SlotsMenu
extends "res://ui/table_menu.gd"
## THE SLOT MACHINE. A cabinet with three reel windows, a payline, a lever and a paytable,
## and it spins nothing: ranch.gd rolls the seeded generator, settles the chips and pushes
## the outcome back through show_spin(). The tween's target is the value Slots.spin() already
## produced; there is no path by which anything on this screen can influence it, because the
## outcome arrives AFTER the chips have already moved.
##
## THE INPUT MODEL IS UNCHANGED IN EVERY PARTICULAR. row_count() is still stakes().size(),
## move_selection() still moves the stake index, confirm() still emits spin_requested().
##
## WHAT MOVED IS WHERE THE WORDS ARE. drawn_lines() still returns all fifteen lines, because
## it is the semantic model of the screen and game/test/test_published_payouts.gd parses the
## price back out of the eight paytable strings. printed_lines() drops eleven of them onto
## the stage, so the column under the cabinet is two lines instead of fifteen.
##
## Extended by path rather than by the global class_name, for the reason every preload in
## this project is by path: the class cache lives in the gitignored game/.godot/.

const SlotsScript := preload("res://systems/slots.gd")

const TITLE := "Slots"

# --- the cabinet, in stage local pixels ------------------------------------------------------
const STAGE_HEIGHT := 480.0
const CABINET := Rect2(0.0, 0.0, 700.0, 420.0)
const PAYTABLE := Rect2(720.0, 0.0, 400.0, 420.0)
const HEADBOARD := Rect2(24.0, 14.0, 652.0, 52.0)
const REEL_SIZE_PX := Vector2(180.0, 300.0)
const REEL_TOP := 86.0
const REEL_LEFT := 40.0
const REEL_PITCH := 216.0
const CELL_HEIGHT := 96.0
const LEVER_X := 676.0
const STAKE_ROW_Y := 452.0
const STAKE_PITCH := 96.0
const CHIP_RADIUS := 30.0

## Nine bulbs whose alpha chases left to right on this loop. The ONLY thing that moves while
## nothing is happening, which is what makes the cabinet read as a machine that is switched on
## rather than as a picture of one.
const BULBS := 9
const BULB_CHASE_SECONDS := 1.2

# --- the spin, and every one of these is a CONSTANT ------------------------------------------
# A spin whose length varied would be a generator living under game/ui/, which is the one
# thing this file may not have. See game/test/test_casino_paint.gd's last test.
const LEVER_DROP_SECONDS := 0.12
const LEVER_RISE_SECONDS := 0.35
const SPIN_UP_SECONDS := 0.15
const REEL_SPEED := 22.0
const LAND_FIRST := 0.60
const LAND_STAGGER := 0.35
const LAND_SECONDS := 0.45
const WIN_FLASH_SECONDS := 0.6
const COUNTER_SECONDS := 0.5

## Whole strip turns a reel makes before it lands, so the ribbon has visibly run rather than
## jumped. Landing i begins at LAND_FIRST + i * LAND_STAGGER, so the three settle left to
## right at 0.60, 0.95 and 1.30 seconds and the whole spin is 1.75.
const SPIN_TURNS := 3

signal spin_requested(stake: int)

var _reel_offset: Array[float] = [0.0, 0.0, 0.0]
var _lever := 0.0
var _flash := 0.0
var _shown_chips := 0.0
var _spinning := false
var _tween: Tween = null


func title_text() -> String:
	return TITLE


func tabs_text() -> String:
	return "Pull the lever. The house keeps %.1f bits of every 100." \
		% (SlotsScript.house_edge() * 100.0)


func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


func drawn_lines() -> Array[String]:
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	lines.append_array(stake_lines())
	if not stakes().is_empty():
		lines.append("Spin for %d chips" % selected_stake())
	lines.append("")
	for line in SlotsScript.paytable_lines():
		lines.append(line)
	return lines


## THE STAKE ROW, THE SPIN LINE AND THE WHOLE PAYTABLE ARE ON THE CABINET NOW. What is left in
## the column is the two lines that are not pictures: what she is holding, and what the keys
## do. The last result stays too, because a player who looked away wants the sentence.
func printed_lines() -> Array[String]:
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	return lines


## Every printed line is above the cursor, and the cursor is not in the column at all any
## more: it is on a drawn chip. Zero, so refresh() marks nothing.
func first_row_line_index() -> int:
	return printed_lines().size()


func row_count() -> int:
	return stakes().size()


func move_selection(step: int) -> void:
	if _spinning:
		return
	var n: int = row_count()
	if n <= 0:
		return
	set_stake_index(posmod(stake_index() + step, n))


func confirm() -> bool:
	if _spinning or selected_stake() <= 0:
		return false
	spin_requested.emit(selected_stake())
	return true


func animating() -> bool:
	return _spinning


func reel_offset(index: int) -> float:
	return _reel_offset[clampi(index, 0, SlotsScript.REELS - 1)]


# --- the layout, pure, and the same numbers paint() draws with -------------------------------

func cabinet_rect() -> Rect2:
	return CABINET


func paytable_rect() -> Rect2:
	return PAYTABLE


func reel_rect(index: int) -> Rect2:
	return Rect2(Vector2(REEL_LEFT + REEL_PITCH * float(index), REEL_TOP), REEL_SIZE_PX)


func payline_y() -> float:
	return REEL_TOP + REEL_SIZE_PX.y * 0.5


func stake_chip_rect(index: int) -> Rect2:
	var centre := Vector2(REEL_LEFT + CHIP_RADIUS + STAKE_PITCH * float(index),
		STAKE_ROW_Y - (8.0 if index == stake_index() else 0.0))
	return Rect2(centre - Vector2(CHIP_RADIUS, CHIP_RADIUS) * 1.1,
		Vector2(CHIP_RADIUS, CHIP_RADIUS) * 2.2)


func focus_rect() -> Rect2:
	if stakes().is_empty():
		return Rect2()
	return to_viewport(stake_chip_rect(clampi(stake_index(), 0, stakes().size() - 1)))


func focused_id() -> StringName:
	if stakes().is_empty():
		return &""
	return StringName("stake:%d" % clampi(stake_index(), 0, stakes().size() - 1))


# --- the spin ---------------------------------------------------------------------------------

## TOLD, NEVER ASKED. ranch.gd's play_slots() has already taken the stake, rolled
## Slots.spin() and settled the win by the time this is called; `reels` is that roll. See
## ranch.gd's own comment on the order, which is the safety property this whole casino shares.
##
## A REEL VALUE THAT IS NOT ON THE STRIP IS A STILL FRAME. This arrives over a dynamic call()
## from ranch.gd, so nothing type checks it at the call site.
func show_spin(reels: Array[int], won: int, stake: int) -> void:
	if reels.size() != SlotsScript.REELS:
		return
	for symbol: int in reels:
		if symbol < 0 or symbol >= SlotsScript.SYMBOL_NAMES.size():
			return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_spinning = true
	_flash = 0.0
	var strip: Array[int] = SlotsScript.strip()
	# The tween runs on the menu node, which is process_mode 3 (PROCESS_MODE_ALWAYS) in every
	# menu .tscn, so it keeps running while get_tree().paused is true.
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "_lever", 1.0, LEVER_DROP_SECONDS)
	_tween.tween_property(self, "_lever", 0.0, LEVER_RISE_SECONDS) \
		.set_delay(LEVER_DROP_SECONDS)
	for reel: int in SlotsScript.REELS:
		var target: float = float(_first_position(strip, reels[reel]))
		var landing: float = LAND_FIRST + LAND_STAGGER * float(reel)
		# Where the ribbon has to be when the landing tween takes over, so the reel appears to
		# have been running at REEL_SPEED the whole time rather than teleporting into its
		# landing. Whole turns plus the target, so the arithmetic is exact.
		var run_to: float = _reel_offset[reel] + float(SPIN_TURNS * SlotsScript.REEL_SIZE)
		# tween_method(), NOT tween_property() ON "_reel_offset:%d". A NodePath subname
		# only resolves into a Vector's or a Resource's own NAMED sub properties (".x",
		# an exported field); an Array element has no such name, so a property tweener
		# built on one silently fails to bind and every reel stays at 0. A per reel
		# setter closure is the same animation with a target Array.set() can actually
		# reach.
		var set_offset: Callable = (func(v: float) -> void: _reel_offset[reel] = v)
		_tween.tween_method(set_offset, _reel_offset[reel], run_to, landing) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		# TRANS_BACK overshoots by about a third of a symbol and settles back, which is what
		# makes a reel feel like a physical object rather than a list that stopped.
		var settle: float = run_to + float(SlotsScript.REEL_SIZE) \
			- posmod(run_to - target, float(SlotsScript.REEL_SIZE))
		_tween.tween_method(set_offset, run_to, settle, LAND_SECONDS) \
			.set_delay(landing).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var total: float = LAND_FIRST + LAND_STAGGER * float(SlotsScript.REELS - 1) + LAND_SECONDS
	if won > 0:
		# A WIN FLASHES AND A LOSS IS QUIET. A machine that celebrates a loss is a machine
		# that is lying, and this one publishes its own house edge on the wall outside.
		_tween.tween_property(self, "_flash", 1.0, WIN_FLASH_SECONDS).set_delay(total)
		_tween.tween_property(self, "_flash", 0.0, 0.01) \
			.set_delay(total + WIN_FLASH_SECONDS)
	# NO .set_delay() HERE. set_parallel(false) already makes this callback its own
	# sequential step, which starts the moment every Tweener in the parallel group above
	# it has finished -- that IS total (plus the flash, when there is one). A set_delay()
	# on top of that waits the same span again on top of the wait sequencing already gives
	# it for free, which is the bug that used to leave a losing spin animating() for 3.5
	# real seconds when the constants above only promise 1.75.
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void: _spinning = false)


## The first strip position carrying `symbol`. Any position carrying it would do; the first is
## chosen so the landing is a function of the value and nothing else.
func _first_position(strip: Array[int], symbol: int) -> int:
	for i: int in strip.size():
		if strip[i] == symbol:
			return i
	return 0


func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()

	# --- the cabinet -------------------------------------------------------------------------
	PaintScript.rounded(ci, CABINET.grow(-2.0), 16.0, PaintScript.PLUM,
		PaintScript.GOLD, 4.0)
	PaintScript.rounded(ci, HEADBOARD, 10.0, PaintScript.GOLD_DIM, PaintScript.GOLD, 2.0)
	PaintScript.text(ci, MenuStyleScript.title_font(),
		HEADBOARD.position + Vector2(HEADBOARD.size.x * 0.5, 38.0), "SPECTRA SLOTS",
		MenuStyleScript.TITLE_SIZE, PaintScript.PLUM_DARK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
	for bulb: int in BULBS:
		var phase: float = fposmod(t / BULB_CHASE_SECONDS - float(bulb) / float(BULBS), 1.0)
		var lit: float = 0.35 + 0.65 * maxf(0.0, 1.0 - phase * 4.0)
		ci.draw_circle(Vector2(HEADBOARD.position.x + 30.0
			+ (HEADBOARD.size.x - 60.0) * float(bulb) / float(BULBS - 1), 8.0),
			5.0, Color(PaintScript.GOLD, lit))

	# --- the three windows -------------------------------------------------------------------
	var strip: Array[int] = SlotsScript.strip()
	for reel: int in SlotsScript.REELS:
		var window: Rect2 = reel_rect(reel)
		PaintScript.rounded(ci, window, 10.0, Color(0.06, 0.05, 0.09),
			PaintScript.GOLD_DIM, 3.0)
		# The ribbon: the REAL strip, at this reel's scroll offset, wrapped. Three cells are
		# visible and the middle one is the payline.
		var offset: float = _reel_offset[reel]
		var top_index: int = floori(offset) - 1
		var slide: float = (offset - floor(offset)) * CELL_HEIGHT
		for cell: int in 4:
			var symbol: int = strip[posmod(top_index + cell, SlotsScript.REEL_SIZE)]
			var y: float = window.position.y + CELL_HEIGHT * float(cell) - slide \
				- (CELL_HEIGHT - window.size.y * 0.5) * 0.0
			var box := Rect2(Vector2(window.position.x + 26.0, y - CELL_HEIGHT * 0.5),
				Vector2(window.size.x - 52.0, CELL_HEIGHT - 12.0))
			if box.position.y + box.size.y < window.position.y:
				continue
			if box.position.y > window.position.y + window.size.y:
				continue
			PaintScript.draw_symbol(ci, box, symbol)
		# The cylinder shading: two flat bands top and bottom, so the ribbon reads as a drum
		# rather than as a list somebody is scrolling.
		ci.draw_rect(Rect2(window.position, Vector2(window.size.x, 48.0)),
			Color(0.02, 0.02, 0.04, 0.55))
		ci.draw_rect(Rect2(window.position + Vector2(0.0, window.size.y - 48.0),
			Vector2(window.size.x, 48.0)), Color(0.02, 0.02, 0.04, 0.55))

	# --- the payline, always on, so she knows which row counts before she spins ---------------
	var flash_colour: Color = PaintScript.GOLD if _flash <= 0.0 \
		else PaintScript.BAND_COLORS[int(t * 8.0) % PaintScript.BAND_COLORS.size()]
	ci.draw_line(Vector2(reel_rect(0).position.x - 8.0, payline_y()),
		Vector2(reel_rect(2).position.x + REEL_SIZE_PX.x + 8.0, payline_y()),
		Color(flash_colour, 0.5 + 0.5 * _flash), 2.0 + 2.0 * _flash, true)

	# --- the lever, purely cosmetic; the spin is on ui_accept ---------------------------------
	var pivot := Vector2(LEVER_X, 120.0)
	var swing: float = deg_to_rad(35.0) * _lever
	var ball: Vector2 = pivot + Vector2(sin(swing), cos(swing)) * 90.0
	ci.draw_line(pivot, ball, PaintScript.GOLD_DIM, 8.0, true)
	ci.draw_circle(ball, 16.0, Color(0.82, 0.18, 0.20))

	# --- the stake, as drawn chips -----------------------------------------------------------
	var available: Array[int] = stakes()
	for i: int in available.size():
		var box: Rect2 = stake_chip_rect(i)
		PaintScript.chip(ci, box.position + box.size * 0.5, CHIP_RADIUS,
			PaintScript.CHIP_COLORS[i % PaintScript.CHIP_COLORS.size()], true)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			box.position + Vector2(box.size.x * 0.5, box.size.y * 0.62),
			str(available[i]), 20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		if i == stake_index():
			PaintScript.focus_ring(ci, box.grow(6.0), 40.0, t)

	# --- the chip counter, tweening toward what she is actually holding -----------------------
	var chips: float = float(chips_provider.call()) if chips_provider.is_valid() else 0.0
	_shown_chips = lerpf(_shown_chips, chips, 1.0 - pow(0.001, get_process_delta_time()))
	PaintScript.draw_chip_icon(ci, Rect2(CABINET.size.x - 150.0, 386.0, 24.0, 24.0))
	PaintScript.text(ci, MenuStyleScript.numeral_font(), Vector2(CABINET.size.x - 118.0, 406.0),
		"%d" % roundi(_shown_chips), 24, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)

	# --- the paytable ------------------------------------------------------------------------
	PaintScript.rounded(ci, PAYTABLE, 12.0, Color(PaintScript.FELT_DARK, 0.9),
		PaintScript.GOLD_DIM, 2.0)
	var lines: Array[String] = SlotsScript.paytable_lines()
	for i: int in lines.size():
		var y: float = PAYTABLE.position.y + 46.0 + 46.0 * float(i)
		if i < SlotsScript.SYMBOL_NAMES.size():
			for pip: int in 3:
				PaintScript.draw_symbol(ci, Rect2(PAYTABLE.position.x + 16.0 + 36.0 * float(pip),
					y - 26.0, 32.0, 32.0), i)
			PaintScript.text(ci, MenuStyleScript.numeral_font(),
				Vector2(PAYTABLE.position.x + 140.0, y), "%d for 1" % SlotsScript.TRIPLE_PAYS[i],
				MenuStyleScript.ROW_SIZE, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		else:
			PaintScript.text(ci, font, Vector2(PAYTABLE.position.x + 16.0, y), lines[i],
				MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM,
				HORIZONTAL_ALIGNMENT_LEFT, PAYTABLE.size.x - 32.0)
