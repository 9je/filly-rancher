class_name RaceMenu
extends "res://ui/table_menu.gd"
## THE RACE PANEL. Three tabs because a bet on a race is three decisions: which of your
## ponies runs, which lane you back, and for how much.
##
## THE ODDS ARE PUSHED IN, NOT WORKED OUT HERE. Choosing an entrant emits `entrant_chosen`;
## ranch.gd builds the field, asks RaceCard for the chances and the odds, and pushes both
## back through set_field(). So this file never sees a PonyInstance, never reads a pen, and
## cannot compute a price of its own that disagrees with the one the race settles at. Same
## split as every other menu in this project.
##
## YOUR PONY IS ALWAYS ON THE RAIL, lane RaceCard.PLAYER_LANE, and the card tab says so. You
## are free to back a Company runner instead, and sometimes that is the right bet.

const RaceCardScript := preload("res://systems/race_card.gd")

const TITLE := "Racing"

## Amended from TableMenu's own FOOTER (a distinct name: GDScript refuses a const that
## shadows one already declared on the parent class): the BET tab has one more thing to
## reach than up, down, left and right can each cover on their own (a lane, a tab and a
## stake), so the stake is reached by carrying on past the last lane rather than through a
## fifth button. See move_selection()/switch_tab().
const RACE_FOOTER := "  up down  choose      left right  tab (stake on the last row)      " \
	+ "Enter / A  confirm      Esc / B  leave"

enum Tab { ENTER, BET, CARD }

signal entrant_chosen(uid: StringName)
signal race_requested(uid: StringName, lane: int, stake: int)

## Injected by ranch.gd: what is standing in the pens, as [{"uid", "name", "happiness"}].
var entrants_provider := Callable()

var _tab: int = Tab.ENTER
var _entrant: StringName = &""
var _field: Array[Dictionary] = []
var _odds: Array[float] = []

## The lane the BET tab is actually backing. Tracked separately from `_selected`, because
## `_selected` also has to reach the stake row past the last lane (see row_count()), and a
## bet must keep pointing at whichever lane was last actually highlighted, not wherever the
## cursor happens to be sitting once it has moved on to adjust the stake.
var _bet_lane := 0


func _ready() -> void:
	super._ready()
	_footer.text = RACE_FOOTER


func title_text() -> String:
	return TITLE


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.ENTER, Tab.CARD)
	_selected = 0
	_bet_lane = 0
	refresh()


## Left and right switch the casino's own tabs everywhere on this panel except one place:
## sitting on the BET tab's stake row (row_count() - 1, one past the last lane), where the
## only room left among four directional buttons for a third independent control (which
## lane, which tab, how much) is to repurpose this one. The footer says so.
func switch_tab(step: int) -> void:
	if _tab == Tab.BET and not _field.is_empty() and _selected == _field.size():
		var available: Array[int] = stakes()
		if not available.is_empty():
			set_stake_index(posmod(stake_index() + step, available.size()))
		return
	set_tab(posmod(_tab + step, Tab.CARD + 1))


## Cycles the six lanes and, right after the last one, a seventh position: the stake. Only
## `_bet_lane` is updated while the cursor is actually over a lane, so wrapping straight
## past every lane onto the stake row (an UP press from lane one, say) can never silently
## change which lane a bet lands on.
func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		_selected = 0
		return
	_selected = posmod(_selected + step, n)
	if _tab == Tab.BET and _selected < _field.size():
		_bet_lane = _selected
	refresh()


func tabs_text() -> String:
	var names: Array[String] = ["Enter", "Bet", "Card"]
	var out: Array[String] = []
	for i in names.size():
		out.append("[%s]" % names[i] if i == _tab else " %s " % names[i])
	var line: String = "   ".join(out) + "      the house keeps %.1f bits of every 100" \
		% (RaceCardScript.TAKEOUT * 100.0)
	# THE STAKE READS HERE TOO, NOT ONLY ON ITS OWN ROW. row_count() gives the BET tab a
	# seventh position past the six lanes for a cursor to reach and adjust it (see
	# move_selection()/switch_tab()), but a strict "one row per lane" contract elsewhere in
	# this project depends on drawn_lines() reporting exactly LANES lines for a dressed
	# field, so the current stake is always readable in the tab strip as well, whether or
	# not the cursor happens to be sitting on that seventh row right now.
	if _tab == Tab.BET and not _field.is_empty():
		line += "      " + "  ".join(stake_lines())
	return line


func entrants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not entrants_provider.is_valid():
		return out
	for entry in entrants_provider.call():
		out.append(entry as Dictionary)
	return out


func selected_entrant_uid() -> StringName:
	return _entrant


## Which lane the BET tab is backing. Meaningless until a field has been pushed. Reads
## `_bet_lane` rather than the raw cursor, so a bet placed while the cursor sits on the
## stake row still lands on the lane that was actually highlighted.
func selected_lane() -> int:
	return clampi(_bet_lane, 0, maxi(_field.size() - 1, 0))


## ranch.gd hands back the six lanes and the price of each. Replaces whatever was here, so
## the panel can never show last entrant's prices.
func set_field(field: Array[Dictionary], odds: Array[float]) -> void:
	_field = field.duplicate()
	_odds = odds.duplicate()
	refresh()


func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.ENTER:
			var list: Array[Dictionary] = entrants()
			if list.is_empty():
				lines.append("Nobody in your pen is ready to run today.")
				return lines
			for entry in list:
				lines.append("%s   spirits %d of 10"
					% [String(entry["name"]), roundi(float(entry["happiness"]) * 10.0)])
		Tab.BET:
			if _field.is_empty():
				lines.append("Enter one of your ponies first, over on the Enter tab.")
				return lines
			for i in _field.size():
				var entry: Dictionary = _field[i]
				var mine: String = "your pony" if bool(entry["player"]) else "Cloudsdale"
				lines.append("Lane %d   %s (%s)   pays %s"
					% [i + 1, String(entry["name"]), mine,
						RaceCardScript.odds_text(_odds[i] if i < _odds.size() else 0.0)])
		Tab.CARD:
			lines.append("Six lanes. Yours runs on the rail, lane %d, every time."
				% (RaceCardScript.PLAYER_LANE + 1))
			lines.append("The five others belong to Cloudsdale and are kept at")
			lines.append("exactly %d per cent morale. It is in the staff handbook."
				% roundi(RaceCardScript.COMPANY_HAPPINESS * 100.0))
			lines.append("")
			lines.append("Odds come from her speed, her stamina, her spirit and")
			lines.append("how happy she is. A hungry pony is a slow pony.")
			lines.append("The house keeps %.1f bits of every 100 wagered, on every"
				% (RaceCardScript.TAKEOUT * 100.0))
			lines.append("lane on the card. You may back any of them.")
	return lines


## Only the ENTER and BET tabs have rows worth sitting on; the card is reading matter. The
## BET tab's rows are the six lanes plus one more once a field is up: the stake, sitting
## right after the last lane, where left and right move it instead of the tab (see
## switch_tab()).
func row_count() -> int:
	match _tab:
		Tab.ENTER:
			return entrants().size()
		Tab.BET:
			return _field.size() + 1 if not _field.is_empty() else 0
	return 0


func confirm() -> bool:
	match _tab:
		Tab.ENTER:
			var list: Array[Dictionary] = entrants()
			if _selected < 0 or _selected >= list.size():
				return false
			_entrant = StringName(list[_selected]["uid"])
			entrant_chosen.emit(_entrant)
			return true
		Tab.BET:
			if _field.is_empty() or _entrant.is_empty() or selected_stake() <= 0:
				return false
			race_requested.emit(_entrant, selected_lane(), selected_stake())
			return true
	return false
