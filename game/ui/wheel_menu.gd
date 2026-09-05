class_name WheelMenu
extends "res://ui/table_menu.gd"
## THE WHEEL'S FELT. Two tabs because there are two bets: back a colour or back a number.
## The guess is the highlighted row and the stake is one row past the last guess, so a whole
## bet is a few key presses and never a typed number.
##
## WHERE THE STAKE ACTUALLY LIVES, and why it is not simply "left and right". Left and right
## already switch the felt's two tabs, and up and down already pick the guess, so on four
## directional buttons there is no fifth direction left for a third independent control. The
## fix is RaceMenu's, and it is deliberately the same one so the two tables read alike: the
## cursor gets ONE position past the last guess (row_count() is guess_count() + 1), and on
## that row left and right move the stake instead of the tab. The hint beside the stake chips
## says so now, drawn on the stage itself rather than buried in a footer nobody ever saw (see
## paint()'s own comment on the stake row).
##
## This file used to override neither move_selection() nor the stake half of switch_tab(),
## so `_stake_index` sat at zero for the whole life of the panel and the class comment's own
## promise was unreachable by any key on the keyboard.
##
## THE HOUSE POCKET IS NOT ON THE FELT. It is on the wheel, and the rules say so, but there
## is no row to back it with, which is what makes it the house's.
##
## THE TAB VALUE IS NOT A Wheel.Bet VALUE. This tab is COLOUR-first because that is the felt's
## own reading order; Wheel.Bet is NUMBER-first (game/systems/wheel.gd). bet_requested carries
## whichever tab is highlighted, so this file never has to know about Wheel.Bet at all, which
## is the class comment's own reason nothing under game/ui/ touches a systems class. ranch.gd's
## _on_wheel_bet_requested() is the one place that translates a Tab into a Bet before it ever
## reaches Wheel.payout().

const WheelScript := preload("res://systems/wheel.gd")

const TITLE := "The Wheel"

## PaintScript is NOT re-declared here: table_menu.gd already carries it and GDScript
## refuses a const that shadows one declared on the parent class. Same reason
## WHEEL_FOOTER had to have a distinct name from TableMenu's own FOOTER.

# --- the felt, in stage local pixels ---------------------------------------------------------
const STAGE_HEIGHT := 580.0
const WHEEL_CENTRE := Vector2(240.0, 230.0)
const WHEEL_OUTER := 200.0
const WHEEL_INNER := 66.0
const HUB_RADIUS := 58.0
const NUMBER_RADIUS := 140.0
const RULES := Rect2(20.0, 440.0, 440.0, 130.0)
const FELT := Rect2(500.0, 0.0, 620.0, 470.0)

## The colour felt: six pads in a 3 by 2 grid. The number felt: twenty four in a 6 by 4.
const COLOUR_PAD := Vector2(180.0, 120.0)
const COLOUR_ORIGIN := Vector2(520.0, 60.0)
const COLOUR_PITCH := Vector2(196.0, 136.0)
const NUMBER_PAD := Vector2(88.0, 74.0)
const NUMBER_ORIGIN := Vector2(516.0, 60.0)
const NUMBER_PITCH := Vector2(100.0, 86.0)
const NUMBER_COLUMNS := 6

const STAKE_ROW := Vector2(560.0, 440.0)
const STAKE_PITCH := 96.0
const CHIP_RADIUS := 30.0

# --- the spin, and every one of these is a CONSTANT ------------------------------------------
## FIVE FULL TURNS, ALWAYS. A spin whose length varied would be a generator living under
## game/ui/, which is the one thing this file may not have. TRANS_CUBIC with EASE_OUT is a
## friction curve, which is what a wheel slowing down actually is.
const SPIN_TURNS := 5
const SPIN_SECONDS := 3.2
const LANDED_GLOW_SECONDS := 0.8
const SETTLE_SECONDS := 0.4

## The pointer's ratchet: it kicks back this far each time a new pocket passes under it and
## springs home over RATCHET_SECONDS. On a fast spin that is a flutter; as the wheel slows it
## becomes individual clicks, which is the entire reason a real wheel feels like it is
## slowing down rather than simply moving less.
const RATCHET_DEGREES := 8.0
const RATCHET_SECONDS := 0.09

var _angle := 0.0
var _spinning := false
var _landed := -1
var _glow := 0.0
var _ratchet := 0.0
var _last_pocket := -1
var _tween: Tween = null

enum Tab { COLOUR, NUMBER }

signal bet_requested(kind: int, guess: int, stake: int)

var _tab: int = Tab.COLOUR

## The row the bet is actually backing. Tracked separately from `_selected` for RaceMenu's
## reason: `_selected` also has to reach the stake row past the last guess, and a bet must
## keep pointing at whichever guess was last actually highlighted rather than at wherever
## the cursor happens to be sitting once it has moved on to adjust the stake.
var _guess_row := 0


func title_text() -> String:
	return TITLE


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.COLOUR, Tab.NUMBER)
	_selected = 0
	_guess_row = 0
	refresh()


## Left and right switch the felt's two tabs everywhere except one place: sitting on the
## stake row, one past the last guess, where they move the stake instead. See the class
## comment for why that row exists at all.
func switch_tab(step: int) -> void:
	if _selected == guess_count():
		var available: Array[int] = stakes()
		if not available.is_empty():
			set_stake_index(posmod(stake_index() + step, available.size()))
		MenuStyleScript.tick_page()
		return
	set_tab(posmod(_tab + step, Tab.NUMBER + 1))
	MenuStyleScript.tick_page()


## Cycles the guesses and, right after the last one, one more position: the stake. Only
## `_guess_row` is updated while the cursor is actually over a guess, so wrapping straight
## past every guess onto the stake row can never silently change what a bet lands on.
func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		_selected = 0
		return
	_selected = posmod(_selected + step, n)
	if _selected < guess_count():
		_guess_row = _selected
	refresh()
	MenuStyleScript.tick_move()


func tabs_text() -> String:
	var left: String = "[Colour]" if _tab == Tab.COLOUR else " Colour "
	var right: String = "[Number]" if _tab == Tab.NUMBER else " Number "
	return "%s   %s      the house keeps %.1f bits of every 100 on either" \
		% [left, right, WheelScript.house_edge() * 100.0]


## How many things she may back on this tab.
func guess_count() -> int:
	return WheelScript.NUMBERS if _tab == Tab.NUMBER else int(WheelScript.Colour.HOUSE)


## What the backed row means to Wheel.payout(): a Colour value on the colour tab, a pocket
## number from 1 up on the number tab. Reads `_guess_row` rather than the raw cursor, so a
## bet placed while the cursor sits on the stake row still lands on the guess that was
## actually highlighted.
func selected_guess() -> int:
	if _tab == Tab.NUMBER:
		return clampi(_guess_row, 0, guess_count() - 1) + 1
	return clampi(_guess_row, 0, guess_count() - 1)


func drawn_lines() -> Array[String]:
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	if _tab == Tab.NUMBER:
		for pocket in range(1, WheelScript.NUMBERS + 1):
			lines.append("Back %d, %s at %d to 1"
				% [pocket, WheelScript.COLOUR_NAMES[WheelScript.colour_of(pocket)],
					WheelScript.NUMBER_PAYS_TO_ONE])
	else:
		for colour in guess_count():
			lines.append("Back %s at %d to 1"
				% [WheelScript.COLOUR_NAMES[colour], WheelScript.COLOUR_PAYS_TO_ONE])
	# NO BLANK BETWEEN THE LAST GUESS AND THE STAKE, deliberately: the stake is a ROW the
	# cursor sits on (row index guess_count()), so the line it is drawn on has to be the one
	# right after the last guess or the caret would point at the gap instead.
	for line in stake_lines():
		lines.append(line)
	lines.append("")
	for line in WheelScript.rules_lines():
		lines.append(line)
	return lines


## The guesses, plus one more position past the last of them: the stake. See the class
## comment.
func row_count() -> int:
	return guess_count() + 1


func confirm() -> bool:
	if selected_stake() <= 0:
		return false
	MenuStyleScript.tick_confirm()
	_sound_call(&"play", [&"chip_clink"])
	bet_requested.emit(_tab, selected_guess(), selected_stake())
	return true


func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


func wheel_centre() -> Vector2:
	return WHEEL_CENTRE


func wheel_outer() -> float:
	return WHEEL_OUTER


func wheel_inner() -> float:
	return WHEEL_INNER


func wheel_angle() -> float:
	return _angle


func rules_rect() -> Rect2:
	return RULES


## The pad for guess row `index` on whichever tab is up. One function and not two, because
## `_selected` and `_guess_row` index the same list on both tabs and a caller that had to
## know which tab it was on is a caller that can be wrong.
func pad_rect(index: int) -> Rect2:
	if _tab == Tab.NUMBER:
		return Rect2(NUMBER_ORIGIN + Vector2(
			NUMBER_PITCH.x * float(index % NUMBER_COLUMNS),
			NUMBER_PITCH.y * float(index / NUMBER_COLUMNS)), NUMBER_PAD)
	return Rect2(COLOUR_ORIGIN + Vector2(
		COLOUR_PITCH.x * float(index % 3), COLOUR_PITCH.y * float(index / 3)), COLOUR_PAD)


func stake_chip_rect(index: int) -> Rect2:
	var centre := Vector2(STAKE_ROW.x + STAKE_PITCH * float(index),
		STAKE_ROW.y - (8.0 if index == stake_index() else 0.0))
	return Rect2(centre - Vector2(CHIP_RADIUS, CHIP_RADIUS) * 1.1,
		Vector2(CHIP_RADIUS, CHIP_RADIUS) * 2.2)


## THE FELT'S BETTING BOX FOR ROW `index`: a guess pad for every guess, and the whole stake
## row for the one position past the last guess (row_count() is guess_count() + 1; see the
## class comment on where the stake actually lives). Same list stage_hit_rects() walks, in
## the same order, so a click on the felt and a keyboard confirm at that row are the same act.
func bet_rect(index: int) -> Rect2:
	if index < guess_count():
		return pad_rect(index)
	var available: Array[int] = stakes()
	if available.is_empty():
		return Rect2()
	return stake_chip_rect(0).merge(stake_chip_rect(available.size() - 1))


## WHICH POCKET IS UNDER THE POINTER RIGHT NOW, derived from the live angle rather than
## remembered from the push, so the test that asks it is asking the drawing.
func pocket_under_pointer() -> int:
	var per: float = TAU / float(WheelScript.POCKETS)
	# The pointer is at twelve o'clock, which is minus a quarter turn in screen radians.
	var at: float = fposmod(-PI * 0.5 - _angle, TAU)
	return posmod(roundi(at / per), WheelScript.POCKETS)


func focus_rect() -> Rect2:
	if _selected == guess_count():
		if stakes().is_empty():
			return Rect2()
		return to_viewport(stake_chip_rect(clampi(stake_index(), 0, stakes().size() - 1)))
	return to_viewport(pad_rect(clampi(_selected, 0, guess_count() - 1)))


func focused_id() -> StringName:
	if _selected == guess_count():
		return StringName("stake:%d" % stake_index())
	return StringName("guess:%d" % clampi(_selected, 0, guess_count() - 1))


func animating() -> bool:
	return _spinning


## The whole text model stays; the felt already shows every guess, so the column keeps only
## the two lines that are not pictures plus the last spin.
func printed_lines() -> Array[String]:
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	return lines


func first_row_line_index() -> int:
	return printed_lines().size()


## TOLD, NEVER ASKED. ranch.gd's play_wheel() has taken the stake, spun Wheel.spin() and
## settled by the time this is called. A pocket that is not on the wheel is a still frame:
## this arrives over a dynamic call() and nothing type checks it at the call site.
func show_spin(pocket: int, won: int, stake: int) -> void:
	if pocket < 0 or pocket >= WheelScript.POCKETS:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_spinning = true
	_landed = pocket
	_glow = 0.0
	var per: float = TAU / float(WheelScript.POCKETS)
	# Where the wheel must end up for `pocket` to sit under the twelve o'clock pointer, plus
	# five whole turns past wherever it is now. Whole turns, so the arithmetic is exact and
	# the landing is a function of the value and nothing else.
	var target: float = -PI * 0.5 - per * float(pocket)
	while target < _angle + TAU * float(SPIN_TURNS):
		target += TAU
	_tween = create_tween()
	_tween.tween_property(self, "_angle", target, SPIN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_glow", 1.0, 0.12)
	_tween.tween_property(self, "_glow", 0.0, LANDED_GLOW_SECONDS)
	_tween.tween_callback(func() -> void:
		_spinning = false
		_sound_call(&"play", [&"wheel_settle"]))
	# `won` and `stake` are not used to decide anything; they are here so a later slice can
	# slide the winning chips to the player without changing this call's shape, and so the
	# signature matches SlotsMenu.show_spin()'s.
	if won < 0 or stake < 0:
		return


## super(delta) FIRST, ALWAYS: see slots_menu.gd's own comment on the same line, which this
## mirrors. TableMenu's _process is what advances anim_time() and queues the stage redraw.
##
## THE RATCHET STATE LIVES HERE, NOT IN paint(). A _draw pass is not a frame tick: it runs
## only when something queues a redraw, and paint() used to detect the pocket crossing and
## fire wheel_ratchet itself, which meant the ratchet stopped ticking whenever the stage
## was not being redrawn. Detection and the sound trigger move here, driven once per
## physics-independent process frame exactly like _sound_reels() on the slots cabinet;
## paint() below only reads _last_pocket and _ratchet to draw the kick.
func _process(delta: float) -> void:
	super(delta)
	var now: int = pocket_under_pointer()
	if now != _last_pocket:
		_last_pocket = now
		_ratchet = 1.0
		if _spinning:
			_sound_call(&"play", [&"wheel_ratchet"])
	_ratchet = maxf(0.0, _ratchet - delta / RATCHET_SECONDS)


func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()
	var per: float = TAU / float(WheelScript.POCKETS)

	# --- the wheel ---------------------------------------------------------------------------
	for pocket: int in WheelScript.POCKETS:
		var from_angle: float = _angle + per * float(pocket) - per * 0.5
		var to_angle: float = from_angle + per
		var colour: Color = PaintScript.HOUSE_SILVER
		if pocket != WheelScript.HOUSE_POCKET:
			colour = PaintScript.BAND_COLORS[WheelScript.colour_of(pocket)]
		if pocket == _landed and _glow > 0.0:
			colour = colour.lightened(0.35 * _glow)
		ci.draw_colored_polygon(PaintScript.sector_points(WHEEL_CENTRE,
			WHEEL_INNER, WHEEL_OUTER, from_angle, to_angle), colour)
		if pocket == WheelScript.HOUSE_POCKET:
			# No number on the house pocket, because no bet may name it. A small cloud
			# instead, which is whose pocket it is.
			var mid: float = from_angle + per * 0.5
			var at: Vector2 = WHEEL_CENTRE + Vector2(cos(mid), sin(mid)) * NUMBER_RADIUS
			for lobe: Vector2 in [Vector2(-8.0, 2.0), Vector2(0.0, -4.0), Vector2(8.0, 2.0)]:
				ci.draw_circle(at + lobe, 7.0, Color(1.0, 1.0, 1.0, 0.9))
			continue
		var mid_angle: float = from_angle + per * 0.5
		var label_at: Vector2 = WHEEL_CENTRE \
			+ Vector2(cos(mid_angle), sin(mid_angle)) * NUMBER_RADIUS
		PaintScript.text(ci, MenuStyleScript.numeral_font(), label_at + Vector2(-9.0, 7.0),
			str(pocket), 20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	ci.draw_circle(WHEEL_CENTRE, HUB_RADIUS, PaintScript.GOLD)
	for spoke: int in 6:
		var a: float = _angle + TAU * float(spoke) / 6.0
		ci.draw_line(WHEEL_CENTRE, WHEEL_CENTRE + Vector2(cos(a), sin(a)) * HUB_RADIUS,
			PaintScript.GOLD_DIM, 3.0, true)
	ci.draw_arc(WHEEL_CENTRE, WHEEL_OUTER, 0.0, TAU, 96, PaintScript.GOLD_DIM, 5.0, true)

	# --- the pointer, ratcheting -------------------------------------------------------------
	# _last_pocket and _ratchet are read only here; _process() above owns writing both, so
	# a redraw draws whatever the last process frame decided rather than deciding it itself.
	var kick: float = deg_to_rad(RATCHET_DEGREES) * _ratchet
	var tip: Vector2 = WHEEL_CENTRE + Vector2(sin(kick), -cos(kick)) * (WHEEL_OUTER - 6.0)
	var base: Vector2 = WHEEL_CENTRE + Vector2(sin(kick), -cos(kick)) * (WHEEL_OUTER + 26.0)
	var side := Vector2(-(base - tip).y, (base - tip).x).normalized() * 12.0
	ci.draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]),
		PaintScript.GOLD)

	# --- the rules plate under the wheel -----------------------------------------------------
	var rules: Array[String] = []
	for line in WheelScript.rules_lines():
		rules.append(line)
	PaintScript.plate(ci, RULES, font, "", rules)

	# --- the felt ----------------------------------------------------------------------------
	PaintScript.rounded(ci, FELT, 14.0, PaintScript.FELT, PaintScript.GOLD_DIM, 2.0)
	for i: int in 4:
		var y: float = FELT.position.y + 24.0 + 108.0 * float(i)
		ci.draw_line(Vector2(FELT.position.x + 12.0, y),
			Vector2(FELT.position.x + FELT.size.x - 12.0, y), PaintScript.FELT_LINE, 1.0, true)
	if _tab == Tab.NUMBER:
		PaintScript.text(ci, font, Vector2(FELT.position.x + 16.0, 38.0),
			"A number pays %d to 1" % WheelScript.NUMBER_PAYS_TO_ONE,
			MenuStyleScript.ROW_SIZE, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	for guess: int in guess_count():
		var pad: Rect2 = pad_rect(guess)
		var colour: Color = PaintScript.BAND_COLORS[guess] if _tab == Tab.COLOUR \
			else PaintScript.BAND_COLORS[WheelScript.colour_of(guess + 1)]
		PaintScript.rounded(ci, pad, 8.0, Color(colour, 0.85), colour.darkened(0.3), 2.0)
		if _tab == Tab.COLOUR:
			PaintScript.text(ci, font, pad.position + Vector2(14.0, 44.0),
				WheelScript.COLOUR_NAMES[guess], MenuStyleScript.ROW_SIZE,
				PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_LEFT, pad.size.x - 28.0)
			PaintScript.text(ci, font, pad.position + Vector2(14.0, 82.0),
				"pays %d to 1" % WheelScript.COLOUR_PAYS_TO_ONE,
				MenuStyleScript.SUBTITLE_SIZE, PaintScript.CARD_INK,
				HORIZONTAL_ALIGNMENT_LEFT, pad.size.x - 28.0)
		else:
			PaintScript.text(ci, MenuStyleScript.numeral_font(),
				pad.position + Vector2(pad.size.x * 0.5, 48.0), str(guess + 1),
				MenuStyleScript.ROW_SIZE, PaintScript.CARD_INK,
				HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		# HER BET IS A THING ON THE TABLE, not a caret next to a sentence. The pad _guess_row
		# names carries a stack of the current stake, so "my bet is on green" is visible.
		if guess == _guess_row and selected_stake() > 0:
			PaintScript.chip_stack(ci, pad.position + Vector2(pad.size.x - 26.0,
				pad.size.y - 12.0), 4,
				PaintScript.CHIP_COLORS[stake_index() % PaintScript.CHIP_COLORS.size()], 7.0)

	# --- the stake row, one press past the last guess -----------------------------------------
	var available: Array[int] = stakes()
	for i: int in available.size():
		var box: Rect2 = stake_chip_rect(i)
		PaintScript.chip(ci, box.position + box.size * 0.5, CHIP_RADIUS,
			PaintScript.CHIP_COLORS[i % PaintScript.CHIP_COLORS.size()], true)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			box.position + Vector2(box.size.x * 0.5, box.size.y * 0.62), str(available[i]),
			20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
	# THE HINT THE DEAD FOOTER WAS TRYING TO GIVE, put where the player is actually looking.
	# InputDevice.hint() answers in the glyphs of the device in her hands, so this is one
	# scheme and never both, which is the whole reason WHEEL_FOOTER had to go.
	PaintScript.text(ci, font, Vector2(STAKE_ROW.x - 40.0, STAKE_ROW.y + 58.0),
		"%s moves the stake" % InputDeviceScript.hint(&"menu_tabs"),
		MenuStyleScript.SUBTITLE_SIZE, PaintScript.GOLD_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1.0)

	# --- the focus ring, the one focus treatment in the building -------------------------------
	if _selected == guess_count():
		if not available.is_empty():
			PaintScript.focus_ring(ci, stake_chip_rect(
				clampi(stake_index(), 0, available.size() - 1)).grow(6.0), 40.0, t)
	else:
		PaintScript.focus_ring(ci, pad_rect(clampi(_selected, 0, guess_count() - 1)), 8.0, t)


## THE FELT'S BETTING BOXES, one per row of the panel and in the panel's own row order, so
## clicking red on the felt and pressing confirm on the red row are the same act. The order
## mattering is the point: game/scenes/test/casino_test.gd already drives one wheel bet end
## to end through the felt precisely because a swap between the felt's order and Wheel.Bet's
## would silently mispay a colour bet at number odds.
func stage_hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in row_count():
		out.append(bet_rect(i))
	return out


func on_stage_hit(index: int) -> void:
	take_row(index)
