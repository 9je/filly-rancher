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
## that row left and right move the stake instead of the tab. The footer says so.
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

## Amended from TableMenu's own FOOTER, the way RaceMenu amends it and for the same reason
## (a distinct name: GDScript refuses a const that shadows one already declared on the
## parent class). See the class comment on where the stake lives.
const WHEEL_FOOTER := "  up down  choose      left right  tab (stake on the last row)      " \
	+ "Enter / A  confirm      Esc / B  leave"

enum Tab { COLOUR, NUMBER }

signal bet_requested(kind: int, guess: int, stake: int)

var _tab: int = Tab.COLOUR

## The row the bet is actually backing. Tracked separately from `_selected` for RaceMenu's
## reason: `_selected` also has to reach the stake row past the last guess, and a bet must
## keep pointing at whichever guess was last actually highlighted rather than at wherever
## the cursor happens to be sitting once it has moved on to adjust the stake.
var _guess_row := 0


func _ready() -> void:
	super._ready()
	_footer.text = WHEEL_FOOTER


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
		return
	set_tab(posmod(_tab + step, Tab.NUMBER + 1))


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


## The chips line, the keys line and the last spin are all printed above the first guess, so
## the caret has to come down past them; see SlotsMenu.first_row_line_index() for the whole
## of the reasoning. See TableMenu.result_block() for what replaced the raw result lines
## this offset used to count.
func first_row_line_index() -> int:
	return 2 + result_block().size()


func confirm() -> bool:
	if selected_stake() <= 0:
		return false
	bet_requested.emit(_tab, selected_guess(), selected_stake())
	return true
