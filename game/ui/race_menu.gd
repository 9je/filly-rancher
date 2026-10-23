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

## PaintScript is NOT re-declared here: table_menu.gd already carries it and GDScript
## refuses a const that shadows one declared on the parent class. Same reason
## WHEEL_FOOTER had to have a distinct name from TableMenu's own FOOTER.

# --- the form guide, in stage local pixels -----------------------------------------------------
## Five cards at a time. A pen holds more than five ponies, so the window scrolls with the
## cursor rather than the stage growing without limit down past the bottom of the screen.
const CARDS_VISIBLE := 5
const CARD_SIZE := Vector2(1080.0, 96.0)
const CARD_LEFT := 20.0
const CARD_TOP := 10.0
const CARD_PITCH := 106.0
const STAKE_PITCH := 96.0
const CHIP_RADIUS := 30.0
const CARD_PAGE := Rect2(40.0, 20.0, 1040.0, 400.0)

## Where each thing on a card sits, measured from the card's own left edge.
const SILKS_X := 18.0
const NAME_X := 130.0
const ODDS_X := 560.0
const SPIRITS_X := 660.0
const CHANCE_X := 830.0
const CHANCE_WIDTH := 220.0

## A pony with no coat in her row. See ranch.gd's NAMED_COAT for why a named character has no
## colour to read; this is also what a gate that builds a bare entrant dictionary gets.
const FALLBACK_COAT := Color(0.70, 0.70, 0.74)
const FALLBACK_MANE := Color(0.52, 0.52, 0.58)

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


## I5, final-review.md I3: the bracket text itself is now MouseRows.tab_strip()'s job (see
## table_menu.gd's refresh()); this is only the note beside it.
func tab_names() -> Array[String]:
	return ["Form guide", "The card"]


func tabs_text() -> String:
	return "the house keeps %.1f bits of every 100" % (RaceCardScript.TAKEOUT * 100.0)


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
		# tick_move(), not tick_page(): a stake nudge is the same gesture confirm() ticks
		# below, and the same one move_selection() ticks on every other table
		# (slots_menu.gd, wheel_menu.gd, blackjack_menu.gd). This is not a page turn.
		MenuStyleScript.tick_move()
		return
	set_tab(posmod(_tab + step, Tab.CARD + 1))
	MenuStyleScript.tick_page()


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
##
## ONE SPACE, NOT A PADDED COLUMN (Ruling 26). This line shipped as "%-16s pays %s   spirits
## %d of 10", which pads the name to sixteen CHARACTERS and then claims a column. The panel
## draws in a proportional font, so sixteen characters is a different width on every row and
## the "column" is ragged wherever two names differ in shape. A comma reads as a sentence,
## costs no alignment that was ever really there, and leaves a short name a short row.
func form_lines() -> Array[String]:
	var out: Array[String] = []
	for entry in entrants():
		out.append("%s pays %s, spirits %d of 10" % [
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


func stage_size() -> Vector2:
	if _tab == Tab.CARD:
		return Vector2(STAGE_WIDTH, 440.0)
	var shown: int = mini(entrants().size(), CARDS_VISIBLE)
	return Vector2(STAGE_WIDTH, CARD_TOP + CARD_PITCH * float(maxi(shown, 1)) + 96.0)


## The first entrant the window is showing. Scrolls only as far as it must to keep the cursor
## on screen, so a short field never scrolls at all.
func first_visible_card() -> int:
	var total: int = entrants().size()
	if total <= CARDS_VISIBLE:
		return 0
	var row: int = clampi(_selected, 0, total - 1)
	return clampi(row - CARDS_VISIBLE + 1, 0, total - CARDS_VISIBLE)


## `index` is an ABSOLUTE entrant index; the window is subtracted here so every caller can
## think in entrants rather than in scroll positions.
func card_rect(index: int) -> Rect2:
	var slot: int = index - first_visible_card()
	var lift: float = 6.0 if index == _selected else 0.0
	return Rect2(Vector2(CARD_LEFT, CARD_TOP + CARD_PITCH * float(slot) - lift), CARD_SIZE)


func stake_chip_rect(index: int) -> Rect2:
	var shown: int = mini(entrants().size(), CARDS_VISIBLE)
	var y: float = CARD_TOP + CARD_PITCH * float(shown) + 40.0
	var centre := Vector2(CARD_LEFT + CHIP_RADIUS + STAKE_PITCH * float(index),
		y - (8.0 if index == stake_index() else 0.0))
	return Rect2(centre - Vector2(CHIP_RADIUS, CHIP_RADIUS) * 1.1,
		Vector2(CHIP_RADIUS, CHIP_RADIUS) * 2.2)


func card_page_rect() -> Rect2:
	return CARD_PAGE


## THE ROW FOR SELECTABLE POSITION `index`: an entrant's card, or the whole stake row for the
## one position past the last entrant (row_count() is entrants().size() + 1 whenever the pens
## are not empty; see _on_stake_row()). Same list stage_hit_rects() walks, in the same order.
func row_rect(index: int) -> Rect2:
	var total: int = entrants().size()
	if index < total:
		return card_rect(index)
	var available: Array[int] = stakes()
	if available.is_empty():
		return Rect2()
	return stake_chip_rect(0).merge(stake_chip_rect(available.size() - 1))


## Every card and the whole card page are on the stage; the column keeps the two lines that
## are not pictures plus the last result.
func printed_lines() -> Array[String]:
	if _tab != Tab.ENTER:
		return [] as Array[String]
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	return lines


## The drawn line row zero sits on: the chips line, the keys line and whatever the last
## result printed all come first. See TableMenu.first_row_line_index() for what goes wrong
## without this.
func first_row_line_index() -> int:
	return printed_lines().size()


func focus_rect() -> Rect2:
	if _tab != Tab.ENTER or entrants().is_empty():
		return Rect2()
	if _on_stake_row():
		if stakes().is_empty():
			return Rect2()
		return to_viewport(stake_chip_rect(clampi(stake_index(), 0, stakes().size() - 1)))
	return to_viewport(card_rect(clampi(_selected, 0, entrants().size() - 1)))


func focused_id() -> StringName:
	if _tab != Tab.ENTER or entrants().is_empty():
		return &""
	if _on_stake_row():
		return StringName("stake:%d" % stake_index())
	return StringName("entrant:%d" % clampi(_selected, 0, entrants().size() - 1))


func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()

	if _tab == Tab.CARD:
		var page: Array[String] = drawn_lines()
		PaintScript.plate(ci, CARD_PAGE, font, "", page)
		return

	var field: Array[Dictionary] = entrants()
	if field.is_empty():
		# THE EMPTY STATE IS A PICTURE PLUS THE SENTENCE, not the sentence alone. A player who
		# has caught nothing yet is the player who most needs to be told what to do next.
		PaintScript.draw_room(ci, Rect2(STAGE_WIDTH * 0.5 - 110.0, 20.0, 220.0, 150.0), 4)
		PaintScript.text(ci, font, Vector2(STAGE_WIDTH * 0.5, 214.0), EMPTY_TEXT,
			MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM,
			HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		return

	var first: int = first_visible_card()
	for index: int in range(first, mini(first + CARDS_VISIBLE, field.size())):
		var entry: Dictionary = field[index]
		var card: Rect2 = card_rect(index)
		var picked: bool = index == _selected
		PaintScript.rounded(ci, card, 12.0, Color(PaintScript.FELT, 1.0 if picked else 0.72),
			PaintScript.GOLD_DIM, 2.0)

		# Her silks: coat behind, mane in front, plus a lane flash in BAND_COLORS[0] because
		# RaceCard.PLAYER_LANE is 0 and the pony you back always runs on the rail.
		var coat: Color = entry.get("coat", FALLBACK_COAT)
		var mane: Color = entry.get("mane", FALLBACK_MANE)
		PaintScript.rounded(ci, Rect2(card.position + Vector2(SILKS_X, 20.0),
			Vector2(58.0, 58.0)), 8.0, coat, coat.darkened(0.25), 2.0)
		PaintScript.rounded(ci, Rect2(card.position + Vector2(SILKS_X + 26.0, 34.0),
			Vector2(42.0, 44.0)), 6.0, mane, mane.darkened(0.25), 2.0)
		ci.draw_rect(Rect2(card.position + Vector2(SILKS_X, 82.0), Vector2(58.0, 6.0)),
			PaintScript.BAND_COLORS[0])

		PaintScript.text(ci, MenuStyleScript.title_font(),
			card.position + Vector2(NAME_X, 58.0), String(entry.get("name", "Pony")), 26,
			MenuStyleScript.COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT, 400.0)

		# The odds on a chip, in RaceCard.odds_text()'s own wording, which is what
		# game/test/test_published_payouts.gd parses. Drawn on a chip instead of printed in a
		# sentence; the string is byte for byte the same string.
		var odds_at: Vector2 = card.position + Vector2(ODDS_X, card.size.y * 0.5)
		PaintScript.chip(ci, odds_at, 34.0, PaintScript.GOLD, false)
		PaintScript.text(ci, MenuStyleScript.numeral_font(), odds_at + Vector2(0.0, 6.0),
			RaceCardScript.odds_text(float(entry.get("odds", 0.0))), 16,
			PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)

		# Ten pips, the same number form_lines() prints. A hungry pony is a slow pony.
		var spirits: int = roundi(float(entry.get("happiness", 0.0)) * 10.0)
		for pip: int in 10:
			var at: Vector2 = card.position + Vector2(SPIRITS_X + 16.0 * float(pip), 48.0)
			if pip < spirits:
				ci.draw_circle(at, 6.0, PaintScript.GOLD)
			else:
				ci.draw_arc(at, 6.0, 0.0, TAU, 12, PaintScript.GOLD_DIM, 1.5, true)

		# The win chance the odds are BUILT FROM. Showing it is what makes the odds legible:
		# a price with no probability beside it is a number a player has to take on trust.
		var track := Rect2(card.position + Vector2(CHANCE_X, 40.0),
			Vector2(CHANCE_WIDTH, 16.0))
		PaintScript.rounded(ci, track, 8.0, PaintScript.FELT_DARK, PaintScript.GOLD_DIM, 1.0)
		var chance: float = clampf(float(entry.get("chance", 0.0)), 0.0, 1.0)
		PaintScript.rounded(ci, Rect2(track.position,
			Vector2(track.size.x * chance, track.size.y)), 8.0,
			PaintScript.BAND_COLORS[3], PaintScript.BAND_COLORS[3], 0.0)
		PaintScript.text(ci, font, card.position + Vector2(CHANCE_X, 80.0),
			"%d in 100 by the card" % roundi(chance * 100.0),
			MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM,
			HORIZONTAL_ALIGNMENT_LEFT, CHANCE_WIDTH)

		if picked:
			PaintScript.focus_ring(ci, card, 12.0, t)

	var available: Array[int] = stakes()
	for i: int in available.size():
		var box: Rect2 = stake_chip_rect(i)
		PaintScript.chip(ci, box.position + box.size * 0.5, CHIP_RADIUS,
			PaintScript.CHIP_COLORS[i % PaintScript.CHIP_COLORS.size()], true)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			box.position + Vector2(box.size.x * 0.5, box.size.y * 0.62), str(available[i]),
			20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		if _on_stake_row() and i == stake_index():
			PaintScript.focus_ring(ci, box.grow(6.0), 40.0, t)


func confirm() -> bool:
	if _tab != Tab.ENTER:
		return false
	var list: Array[Dictionary] = entrants()
	if list.is_empty():
		return false
	if _on_stake_row():
		_step_stake(1)
		# A stake nudge, not a bet: the same tick a stake shift makes everywhere else on
		# this table (see switch_tab() and move_selection() on the other tables).
		MenuStyleScript.tick_move()
		return true
	if _selected < 0 or _selected >= list.size():
		return false
	if selected_stake() <= 0:
		return false
	_entrant = StringName(list[_selected]["uid"])
	MenuStyleScript.tick_confirm()
	_sound_call(&"play", [&"chip_clink"])
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


## THE CARD TAB IS READING MATTER: row_count() already answers 0 there, so this returns empty
## on its own with no special case.
func stage_hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in row_count():
		out.append(row_rect(i))
	return out


func on_stage_hit(index: int) -> void:
	take_row(index)
