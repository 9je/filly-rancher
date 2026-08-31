class_name BlackjackMenu
extends "res://ui/table_menu.gd"
## THE BLACKJACK TABLE. One tab to play at and one tab holding the placard, because the
## published edge is measured against the strategy card printed on it and a player who wants
## to check that should not have to leave the table to read it.
##
## THE HAND IS PLAYED IN ONE PRESS. The house strategy card is what the player is playing, so
## there is no hit or stand decision to make at the table: ranch.gd deals the whole hand
## through Blackjack.play_hand() and pushes back what happened. A table where the player
## makes the decisions is a bigger game than this slice, and the placard says so out loud.

const BlackjackScript := preload("res://systems/blackjack.gd")

const TITLE := "Blackjack"

enum Tab { TABLE, PLACARD }

signal deal_requested(stake: int)

var _tab: int = Tab.TABLE


func title_text() -> String:
	return TITLE


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.TABLE, Tab.PLACARD)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.PLACARD + 1))


func tabs_text() -> String:
	var left: String = "[Table]" if _tab == Tab.TABLE else " Table "
	var right: String = "[Placard]" if _tab == Tab.PLACARD else " Placard "
	return "%s   %s      the house keeps %.1f bits of every 100 against the card" \
		% [left, right, BlackjackScript.house_edge() * 100.0]


func drawn_lines() -> Array[String]:
	if _tab == Tab.PLACARD:
		var placard: Array[String] = []
		for line in BlackjackScript.placard_lines():
			placard.append(line)
		return placard
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	lines.append_array(stake_lines())
	if not stakes().is_empty():
		lines.append("Deal for %d chips" % selected_stake())
	return lines


func row_count() -> int:
	return stakes().size() if _tab == Tab.TABLE else 0


## The caret sits on the "Stake:" line; see SlotsMenu.first_row_line_index() for the whole
## of the reasoning and game/test/test_table_caret.gd for the pin. Zero on the placard,
## which draws no cursor at all.
func first_row_line_index() -> int:
	if _tab != Tab.TABLE:
		return 0
	return 2 + result_block().size()


func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		return
	set_stake_index(posmod(stake_index() + step, n))


func confirm() -> bool:
	if _tab != Tab.TABLE or selected_stake() <= 0:
		return false
	deal_requested.emit(selected_stake())
	return true
