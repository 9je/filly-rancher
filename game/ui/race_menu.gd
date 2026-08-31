class_name RaceMenu
extends "res://ui/table_menu.gd"
## THE FORM GUIDE. Every pony standing in one of your pens, her live price, and a stake.
##
## YOUR PONY IS YOUR BET. There is no lane to pick and no side bet to place: you enter one
## of your own and back her to win, and the card pays her odds if she takes it and nothing
## if she does not. The spec was amended to this on 2026-08-31 after the playtest verdict
## that backing a Company runner against your own pony felt wrong; the BET tab, and with it
## the whole "pick a lane" flow, is gone.
##
## THE ODDS ARE PUSHED IN WITH THE ROWS, NOT WORKED OUT HERE. ranch.gd builds the field each
## pony would run in, asks RaceCard.decimal_odds() for her price and hands the number over
## in her row; this file never sees a PonyInstance, never reads a pen, and cannot compute a
## price of its own that disagrees with the one the race settles at. Same split as every
## other menu in this project.
##
## THE STAKE IS A DRAWN ROW NOW, sitting under the last pony. It used to be a seventh
## cursor position past six lanes with nothing printed under it, which is a control nobody
## found; left and right move it while the cursor is on it, and so does confirm, because a
## player who presses the confirm key on a row called "Stake" should not get silence.

const RaceCardScript := preload("res://systems/race_card.gd")

const TITLE := "Racing"
const EMPTY_TEXT := "Nobody is standing in your pens. Catch a pony and move her in."

enum Tab { ENTER, CARD }

## Emitted when she backs one of her own. ranch.gd takes the stake, runs the card and
## settles at RaceCard.PLAYER_LANE, which is the only lane her bet can ever be on.
signal race_requested(uid: StringName, stake: int)

## Injected by ranch.gd: what is standing in the pens, as
## [{"uid", "name", "happiness", "odds", "chance"}].
var entrants_provider := Callable()

var _tab: int = Tab.ENTER
var _entrant: StringName = &""


func _ready() -> void:
	super._ready()


func title_text() -> String:
	return TITLE


func tabs_text() -> String:
	return MenuStyleScript.tab_strip(["Form guide", "The card"], _tab) \
		+ "      the house keeps %.1f bits of every 100" % (RaceCardScript.TAKEOUT * 100.0)


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.ENTER, Tab.CARD)
	_selected = 0
	refresh()


## Left and right switch tabs everywhere except on the stake row, where they move the
## stake. The footer says so, and the row itself says so.
func switch_tab(step: int) -> void:
	if _tab == Tab.ENTER and _on_stake_row():
		_step_stake(step)
		return
	set_tab(posmod(_tab + step, Tab.CARD + 1))


func entrants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not entrants_provider.is_valid():
		return out
	for entry in entrants_provider.call():
		out.append(entry as Dictionary)
	return out


func selected_entrant_uid() -> StringName:
	return _entrant


## ONE ROW PER PONY: her name, what she pays, and the only thing about her the player can
## change before the off. A hungry pony is a slow pony, and her spirits are the visible half
## of that.
func form_lines() -> Array[String]:
	var out: Array[String] = []
	for entry in entrants():
		out.append("%-16s pays %s   spirits %d of 10" % [
			String(entry.get("name", "Pony")),
			RaceCardScript.odds_text(float(entry.get("odds", 0.0))),
			roundi(float(entry.get("happiness", 0.0)) * 10.0)])
	return out


func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.ENTER:
			lines.append(chips_line())
			lines.append(keys_line())
			lines.append_array(result_block())
			var form: Array[String] = form_lines()
			if form.is_empty():
				lines.append(EMPTY_TEXT)
				return lines
			lines.append_array(form)
			lines.append_array(stake_lines())
		Tab.CARD:
			lines.append("Six lanes. Yours runs on the rail, lane %d, every time."
				% (RaceCardScript.PLAYER_LANE + 1))
			lines.append("The five others belong to Cloudsdale and are kept at")
			lines.append("exactly %d per cent morale. It is in the staff handbook."
				% roundi(RaceCardScript.COMPANY_HAPPINESS * 100.0))
			lines.append("")
			lines.append("You back your own pony and nobody else. She pays her")
			lines.append("odds if she takes it and nothing if she does not.")
			lines.append("")
			lines.append("Odds come from her speed, her stamina, her spirit and")
			lines.append("how happy she is. A hungry pony is a slow pony.")
			lines.append("The house keeps %.1f bits of every 100 wagered."
				% (RaceCardScript.TAKEOUT * 100.0))
	return lines


## The rows the cursor may sit on: one per pony, plus the stake under them. Zero when
## nobody is in a pen, so confirming an empty guide cannot reach a signal.
func row_count() -> int:
	if _tab != Tab.ENTER:
		return 0
	var n: int = entrants().size()
	return n + 1 if n > 0 else 0


## The drawn line row zero sits on: the chips line, the keys line and whatever the last
## result printed all come first. See TableMenu.first_row_line_index() for what goes wrong
## without this.
func first_row_line_index() -> int:
	return 2 + result_block().size()


func confirm() -> bool:
	if _tab != Tab.ENTER:
		return false
	var list: Array[Dictionary] = entrants()
	if list.is_empty():
		return false
	if _on_stake_row():
		_step_stake(1)
		return true
	if _selected < 0 or _selected >= list.size():
		return false
	if selected_stake() <= 0:
		return false
	_entrant = StringName(list[_selected]["uid"])
	race_requested.emit(_entrant, selected_stake())
	return true


func _on_stake_row() -> bool:
	var n: int = entrants().size()
	return n > 0 and _selected == n


func _step_stake(step: int) -> void:
	var available: Array[int] = stakes()
	if available.is_empty():
		return
	set_stake_index(posmod(stake_index() + step, available.size()))
