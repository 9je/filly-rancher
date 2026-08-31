class_name WheelMenu
extends "res://ui/table_menu.gd"
## THE WHEEL'S FELT. Two tabs because there are two bets: back a colour or back a number.
## The guess is the highlighted row and the stake is the left and right of the stake line, so
## a whole bet is three key presses and never a typed number.
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

enum Tab { COLOUR, NUMBER }

signal bet_requested(kind: int, guess: int, stake: int)

var _tab: int = Tab.COLOUR


func title_text() -> String:
	return TITLE


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.COLOUR, Tab.NUMBER)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.NUMBER + 1))


func tabs_text() -> String:
	var left: String = "[Colour]" if _tab == Tab.COLOUR else " Colour "
	var right: String = "[Number]" if _tab == Tab.NUMBER else " Number "
	return "%s   %s      the house keeps %.1f bits of every 100 on either" \
		% [left, right, WheelScript.house_edge() * 100.0]


## How many things she may back on this tab.
func guess_count() -> int:
	return WheelScript.NUMBERS if _tab == Tab.NUMBER else int(WheelScript.Colour.HOUSE)


## What the highlighted row means to Wheel.payout(): a Colour value on the colour tab, a
## pocket number from 1 up on the number tab.
func selected_guess() -> int:
	if _tab == Tab.NUMBER:
		return clampi(_selected, 0, guess_count() - 1) + 1
	return clampi(_selected, 0, guess_count() - 1)


func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	for line in result_lines():
		lines.append(line)
	if not result_lines().is_empty():
		lines.append("")
	if _tab == Tab.NUMBER:
		for pocket in range(1, WheelScript.NUMBERS + 1):
			lines.append("Back %d, %s at %d to 1"
				% [pocket, WheelScript.COLOUR_NAMES[WheelScript.colour_of(pocket)],
					WheelScript.NUMBER_PAYS_TO_ONE])
	else:
		for colour in guess_count():
			lines.append("Back %s at %d to 1"
				% [WheelScript.COLOUR_NAMES[colour], WheelScript.COLOUR_PAYS_TO_ONE])
	lines.append("")
	for line in stake_lines():
		lines.append(line)
	lines.append("")
	for line in WheelScript.rules_lines():
		lines.append(line)
	return lines


func row_count() -> int:
	return guess_count()


func confirm() -> bool:
	if selected_stake() <= 0:
		return false
	bet_requested.emit(_tab, selected_guess(), selected_stake())
	return true
