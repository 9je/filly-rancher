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
const CARD_TOP := 176.0
const CARD_PITCH := 106.0
const STAKE_PITCH := 96.0
const CHIP_RADIUS := 30.0
const CARD_PAGE := Rect2(40.0, 20.0, 1040.0, 400.0)

## THE TRACK STRIP over the cards (Fable AAA round 5: "the race guide wants silks colours and
## a track strip with the runners' portraits"): the field loaded into a starting gate on the
## dirt, each runner's face over her stall door in her silks with her number, the rail and the
## finish post beyond.
const TRACK := Rect2(20.0, 8.0, 1080.0, 156.0)
const STALL_W := 118.0
const GATE_SHOWN := 6
## A runner's silks by her place on the card: the colour of her stall door, her saddle cloth
## and the stripe down her card.
const SILKS: Array[Color] = [Color(0.86, 0.20, 0.26), Color(0.22, 0.46, 0.90),
	Color(0.98, 0.78, 0.18), Color(0.22, 0.66, 0.40), Color(0.62, 0.30, 0.82),
	Color(0.96, 0.52, 0.18)]


static func silks_colour(index: int) -> Color:
	return SILKS[index % SILKS.size()]

## Where each thing on a card sits, measured from the card's own left edge (P8 S8 rebuild,
## after Inside Track's form board: her face, her name and form, her chance, her price).
const SILKS_X := 14.0
const PORTRAIT := 78.0
const NAME_X := 128.0
const SPIRITS_X := 128.0
const CHANCE_X := 560.0
const CHANCE_WIDTH := 240.0
const ODDS_X := 840.0
const ODDS_SIZE := Vector2(210.0, 64.0)

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


## THE GUIDE IS AS TALL AS ITS CARDS (Fable AAA round 3, #9: "the race guide's lower 40% is
## empty purple"). TableMenu pads the Rows column with an empty hit holder per row for tables
## that draw their rows on the stage; the guide's cards and stake chips take their clicks on
## the stage itself (stage_hit_rects()), so those holders were only blank height under the
## stake row. Only the printed result lines stay.
func refresh() -> void:
	super.refresh()
	if _rows == null:
		return
	var keep: int = printed_lines().size()
	# The last refresh's holders are only queued for deletion: skip them, they go this frame.
	var kids: Array[Node] = []
	for child in _rows.get_children():
		if not child.is_queued_for_deletion():
			kids.append(child)
	for i in range(keep, kids.size()):
		_rows.remove_child(kids[i])
		kids[i].queue_free()
	_rows.visible = keep > 0


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
	var y: float = CARD_TOP + CARD_PITCH * float(shown) + 48.0
	var centre := Vector2(CARD_LEFT + 110.0 + CHIP_RADIUS + STAKE_PITCH * float(index), y)
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
	# The chips and the stake are drawn on the stage now (P8 item 61: a keyboard sentence and
	# an invisible stake row were the worst of the old screen); only the last result is words.
	var lines: Array[String] = []
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

	_paint_track(ci, field, t)
	var first: int = first_visible_card()
	for index: int in range(first, mini(first + CARDS_VISIBLE, field.size())):
		var entry: Dictionary = field[index]
		var card: Rect2 = card_rect(index)
		var picked: bool = index == _selected
		var silks: Color = silks_colour(index)
		PaintScript.rounded(ci, card, 14.0, Color(PaintScript.FELT, 1.0 if picked else 0.78),
			PaintScript.GOLD if picked else PaintScript.GOLD_DIM, 3.0 if picked else 2.0)
		# Her silks down the card's left edge, a stripe of her colour with a white pinstripe.
		PaintScript.rounded(ci, Rect2(card.position + Vector2(4.0, 4.0), Vector2(16.0, card.size.y - 8.0)),
			8.0, silks, silks.darkened(0.3), 1.0)
		ci.draw_line(card.position + Vector2(12.0, 10.0), card.position + Vector2(12.0, card.size.y - 10.0),
			Color(1.0, 1.0, 1.0, 0.6), 2.0, true)

		# HER FACE in a gold ring on a disc of her mane's colour (a coat-coloured disc lost a
		# white pony against it), her coat and mane as a swatch only until it is baked, and
		# her saddle cloth with her number at its foot.
		var coat: Color = entry.get("coat", FALLBACK_COAT)
		var mane: Color = entry.get("mane", FALLBACK_MANE)
		var centre: Vector2 = card.position + Vector2(SILKS_X + 14.0 + PORTRAIT * 0.5, card.size.y * 0.5)
		_paint_face(ci, centre, PORTRAIT * 0.44, entry, coat, mane)
		_saddle_cloth(ci, centre + Vector2(PORTRAIT * 0.34, PORTRAIT * 0.3), index, 15.0)

		PaintScript.text(ci, MenuStyleScript.title_font(),
			card.position + Vector2(NAME_X, 44.0), String(entry.get("name", "Pony")), 28,
			MenuStyleScript.COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT, 420.0)
		# Her spirits as five hearts (a hungry pony is a slow pony), labelled.
		var spirits: float = clampf(float(entry.get("happiness", 0.0)), 0.0, 1.0) * 5.0
		PaintScript.text(ci, font, card.position + Vector2(SPIRITS_X, 80.0), "Spirits",
			MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0)
		for h: int in 5:
			var at := Rect2(card.position + Vector2(SPIRITS_X + 78.0 + 26.0 * float(h), 60.0),
				Vector2(22.0, 22.0))
			if float(h) + 0.5 <= spirits:
				IconSet.draw(ci, "suit_hearts", at)
			else:
				ci.draw_arc(at.get_center(), 8.0, 0.0, TAU, 16, PaintScript.GOLD_DIM, 2.0, true)

		# HER CHANCE, AS A NUMBER AND A BAR: what the odds are built from.
		var chance: float = clampf(float(entry.get("chance", 0.0)), 0.0, 1.0)
		PaintScript.text(ci, font, card.position + Vector2(CHANCE_X, 32.0), "Chance to win",
			MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0)
		# Right-aligned text needs its box's width, or it starts at the point and runs on.
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			card.position + Vector2(CHANCE_X, 34.0), "%d%%" % roundi(chance * 100.0),
			26, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, CHANCE_WIDTH)
		var track := Rect2(card.position + Vector2(CHANCE_X, 52.0), Vector2(CHANCE_WIDTH, 16.0))
		PaintScript.rounded(ci, track, 8.0, PaintScript.FELT_DARK, PaintScript.GOLD_DIM, 1.0)
		PaintScript.rounded(ci, Rect2(track.position,
			Vector2(maxf(track.size.y, track.size.x * chance), track.size.y)), 8.0,
			PaintScript.BAND_COLORS[3], PaintScript.BAND_COLORS[3], 0.0)

		# HER PRICE ON A TICKET, wide enough for its words (the coin it sat on was not), in
		# RaceCard.odds_text()'s own wording, which test_published_payouts.gd parses.
		var ticket := Rect2(card.position + Vector2(ODDS_X, (card.size.y - ODDS_SIZE.y) * 0.5),
			ODDS_SIZE)
		PaintScript.rounded(ci, ticket, 10.0, PaintScript.GOLD, PaintScript.GOLD_DIM, 2.0)
		var odds := RaceCardScript.odds_text(float(entry.get("odds", 0.0)))
		PaintScript.label(ci, MenuStyleScript.numeral_font(), ticket.grow(-6.0), "pays " + odds,
			24, PaintScript.CARD_INK)

		if picked:
			PaintScript.focus_ring(ci, card, 14.0, t)

	# THE STAKE, OR WHERE TO GET ONE. A stake row nobody could see, under a sentence saying
	# there were no chips, was the old screen's whole failure (item 61).
	var shown: int = mini(field.size(), CARDS_VISIBLE)
	var row_y: float = CARD_TOP + CARD_PITCH * float(shown) + 6.0
	var available: Array[int] = stakes()
	var held: int = int(chips_provider.call()) if chips_provider.is_valid() else 0
	if available.is_empty():
		var note := Rect2(Vector2(CARD_LEFT, row_y), Vector2(CARD_SIZE.x, 72.0))
		PaintScript.rounded(ci, note, 14.0, Color(0.0, 0.0, 0.0, 0.3), PaintScript.GOLD_DIM, 2.0)
		IconSet.draw(ci, "coin", Rect2(note.position + Vector2(16.0, 10.0), Vector2(52.0, 52.0)))
		PaintScript.text(ci, MenuStyleScript.title_font(), note.position + Vector2(84.0, 46.0),
			"No chips yet: change bits for chips at the cage, by the door.", 24,
			MenuStyleScript.COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 100.0)
		return
	PaintScript.text(ci, MenuStyleScript.title_font(), Vector2(CARD_LEFT + 4.0, row_y + 52.0),
		"Stake", 26, MenuStyleScript.COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	for i: int in available.size():
		var box: Rect2 = stake_chip_rect(i)
		var on: bool = i == stake_index()
		var centre: Vector2 = box.get_center() - Vector2(0.0, 6.0 if on else 0.0)
		if on:
			ci.draw_arc(centre, CHIP_RADIUS + 6.0, 0.0, TAU, 40, PaintScript.GOLD, 4.0, true)
		PaintScript.chip(ci, centre, CHIP_RADIUS,
			PaintScript.CHIP_COLORS[i % PaintScript.CHIP_COLORS.size()], true)
		PaintScript.text(ci, MenuStyleScript.numeral_font(), centre + Vector2(0.0, 7.0),
			str(available[i]), 20, Color.WHITE if i == 2 else PaintScript.CARD_INK,
			HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		if _on_stake_row() and on:
			PaintScript.focus_ring(ci, box.grow(6.0), 40.0, t)
	# What she holds, and what pressing her card does, in one line under the chips' right.
	var who: String = String(field[clampi(_selected, 0, field.size() - 1)].get("name", "her"))
	PaintScript.text(ci, font, Vector2(CARD_LEFT, row_y + 40.0),
		"%d chips held" % held, MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM,
		HORIZONTAL_ALIGNMENT_RIGHT, CARD_SIZE.x)
	PaintScript.text(ci, MenuStyleScript.title_font(), Vector2(CARD_LEFT, row_y + 72.0),
		"Click her card to back %s for %d" % [who, selected_stake()], 22, PaintScript.GOLD,
		HORIZONTAL_ALIGNMENT_RIGHT, CARD_SIZE.x)


## Her face on a disc, or her coat and mane as two dots until the baker has her.
func _paint_face(ci: Control, centre: Vector2, radius: float, entry: Dictionary, coat: Color,
		mane: Color) -> void:
	var face: Texture2D = entry.get("portrait", null)
	var backdrop: Color = mane.darkened(0.25).lerp(PaintScript.FELT, 0.35)
	PaintScript.portrait_disc(ci, centre, radius, face, backdrop)
	if face == null:
		ci.draw_circle(centre + Vector2(-radius * 0.2, radius * 0.1), radius * 0.6, coat)
		ci.draw_circle(centre + Vector2(radius * 0.25, -radius * 0.2), radius * 0.45, mane)


## Her number on a square of her silks, white-edged, as a saddle cloth carries it.
func _saddle_cloth(ci: Control, centre: Vector2, index: int, half: float) -> void:
	var box := Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)
	PaintScript.rounded(ci, Rect2(box.position + Vector2(0.0, 2.0), box.size), 5.0,
		Color(0.0, 0.0, 0.0, 0.35), Color(0, 0, 0, 0), 0.0)
	PaintScript.rounded(ci, box, 5.0, silks_colour(index), Color.WHITE, 2.0)
	PaintScript.label(ci, MenuStyleScript.numeral_font(), box.grow(-2.0), str(index + 1),
		int(half * 1.3), Color.WHITE if index != 2 else PaintScript.CARD_INK)


## THE GATE ON THE DIRT: grass and a rail behind, raked dirt in front, the field in a row of
## stalls at the left (her face over her door, the door in her silks with her number, the
## picked runner's stall lit) and the finish post with its chequered flag at the far right.
func _paint_track(ci: Control, field: Array[Dictionary], t: float) -> void:
	var r := TRACK
	PaintScript.rounded(ci, Rect2(r.position + Vector2(0.0, 5.0), r.size), 16.0,
		Color(0.0, 0.0, 0.0, 0.3), Color(0, 0, 0, 0), 0.0)
	PaintScript.rounded(ci, r, 16.0, Color(0.30, 0.56, 0.32), PaintScript.GOLD_DIM, 3.0)
	var dirt := Rect2(r.position.x + 3.0, r.position.y + r.size.y * 0.42, r.size.x - 6.0,
		r.size.y * 0.58 - 3.0)
	PaintScript.rounded(ci, dirt, 12.0, Color(0.66, 0.45, 0.28), Color(0, 0, 0, 0), 0.0)
	# Rake lines in the dirt, and the far rail: white posts and a white top bar on the grass.
	var y := dirt.position.y + 14.0
	while y < dirt.end.y - 6.0:
		ci.draw_line(Vector2(dirt.position.x + 10.0, y), Vector2(dirt.end.x - 10.0, y),
			Color(0.5, 0.32, 0.18, 0.4), 2.0, true)
		y += 14.0
	var rail_y: float = dirt.position.y - 4.0
	var x := r.position.x + 18.0
	while x < r.end.x - 10.0:
		ci.draw_line(Vector2(x, rail_y - 18.0), Vector2(x, rail_y + 2.0), Color(0.96, 0.96, 0.94), 3.0, true)
		x += 44.0
	ci.draw_line(Vector2(r.position.x + 10.0, rail_y - 16.0), Vector2(r.end.x - 10.0, rail_y - 16.0),
		Color(0.98, 0.98, 0.96), 4.0, true)
	# Bunting in the field's silks strung along the rail, swaying a little.
	var bx: float = r.position.x + 30.0
	var k := 0
	while bx < r.end.x - 110.0:
		var sway: float = sin(t * 2.0 + float(k) * 0.7) * 1.5
		var top_y: float = rail_y - 16.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx, top_y), Vector2(bx + 22.0, top_y),
			Vector2(bx + 11.0 + sway, top_y + 20.0)]), silks_colour(k))
		bx += 26.0
		k += 1
	# The finish post, and its flag.
	var post := Vector2(r.end.x - 70.0, dirt.end.y - 8.0)
	ci.draw_line(post, post - Vector2(0.0, r.size.y * 0.86), Color(0.98, 0.98, 0.96), 6.0, true)
	ci.draw_circle(post - Vector2(0.0, r.size.y * 0.86), 12.0, Color(0.86, 0.20, 0.26))
	ci.draw_circle(post - Vector2(0.0, r.size.y * 0.86), 6.0, Color(0.98, 0.98, 0.96))
	var flag := Rect2(post + Vector2(8.0, -r.size.y * 0.8), Vector2(48.0, 32.0))
	var wave: float = sin(t * 3.0) * 2.0
	for i in 4:
		for j in 3:
			var cell := Rect2(flag.position + Vector2(12.0 * i, 10.67 * j + wave * float(i) * 0.4),
				Vector2(12.0, 10.67))
			ci.draw_rect(cell, Color(0.1, 0.1, 0.12) if (i + j) % 2 == 0 else Color(0.98, 0.98, 0.96))
	# The gate: a stall per runner, as many as fit.
	var shown: int = mini(field.size(), GATE_SHOWN)
	var gate_left: float = r.position.x + 22.0
	var top: float = r.position.y + 10.0
	PaintScript.rounded(ci, Rect2(gate_left - 8.0, top, STALL_W * shown + 16.0, 14.0), 6.0,
		Color(0.92, 0.92, 0.95), Color(0.55, 0.55, 0.62), 2.0)
	for i: int in shown:
		var entry: Dictionary = field[i]
		var sx: float = gate_left + STALL_W * float(i)
		var picked: bool = i == _selected
		var silks: Color = silks_colour(i)
		var stall := Rect2(sx, top + 12.0, STALL_W, r.end.y - top - 22.0)
		if picked:
			PaintScript.rounded(ci, stall.grow(2.0), 10.0, Color(PaintScript.GOLD, 0.25 + 0.1 * sin(t * 4.0)),
				Color(0, 0, 0, 0), 0.0)
		# Her face over the door, then the door in front of her.
		var coat: Color = entry.get("coat", FALLBACK_COAT)
		var mane: Color = entry.get("mane", FALLBACK_MANE)
		var face_at := Vector2(stall.get_center().x, stall.position.y + 46.0)
		_paint_face(ci, face_at, 38.0, entry, coat, mane)
		var door := Rect2(sx + 12.0, stall.position.y + 70.0, STALL_W - 24.0, stall.end.y - stall.position.y - 70.0)
		PaintScript.rounded(ci, door, 6.0, silks, silks.darkened(0.35), 2.0)
		ci.draw_line(door.position + Vector2(6.0, 10.0), Vector2(door.end.x - 6.0, door.position.y + 10.0),
			Color(1.0, 1.0, 1.0, 0.5), 2.0, true)
		_saddle_cloth(ci, door.get_center() + Vector2(0.0, 6.0), i, 16.0)
		# The stall's posts.
		for px: float in [sx, sx + STALL_W]:
			ci.draw_line(Vector2(px, top + 8.0), Vector2(px, stall.end.y + 4.0), Color(0.92, 0.92, 0.95), 6.0, true)
			ci.draw_line(Vector2(px + 2.0, top + 8.0), Vector2(px + 2.0, stall.end.y + 4.0), Color(0.6, 0.6, 0.68), 1.5, true)


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
