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
##
## THE SUIT ON A CARD IS DRAWN HERE AND MEANS NOTHING. game/systems/blackjack.gd numbers cards
## 0 to 51 and reads card % RANKS for the rank; it never names a suit at all. This stage
## derives one as card / RANKS so a face is a face, and that derivation is one way: card_value(),
## hand_total() and payout() all read the rank alone, so two cards of the same rank in different
## suits are worth the same chip. game/test/test_blackjack_menu.gd asserts exactly that, because
## the next reader of this file will wonder whether the casino just grew a fifth thing that
## can move a number.

const BlackjackScript := preload("res://systems/blackjack.gd")

## PaintScript is NOT re-declared here: table_menu.gd already carries it and GDScript
## refuses a const that shadows one declared on the parent class. Same reason
## WHEEL_FOOTER had to have a distinct name from TableMenu's own FOOTER.

const TITLE := "Blackjack"

# --- the felt, in stage local pixels ---------------------------------------------------------
const STAGE_HEIGHT := 470.0
const CARD_SIZE := Vector2(76.0, 106.0)
const CARD_PITCH := 96.0
const ROW_LEFT := 340.0
const DEALER_ROW_Y := 34.0
const PLAYER_ROW_Y := 296.0
const ARC_LIFT := 5.0
const CARDS_DRAWN_MAX := 8
const SHOE := Rect2(1000.0, 20.0, 90.0, 124.0)
const STAKE := Rect2(60.0, 300.0, 140.0, 130.0)
const OUTCOME := Rect2(300.0, 186.0, 520.0, 78.0)
const PLACARD := Rect2(60.0, 20.0, 1000.0, 420.0)

# --- the deal, and every one of these is a CONSTANT -------------------------------------------
## The hand is ALREADY SETTLED when it arrives; the pacing below is presentation only and
## cannot change a single card. About 1.4 s for a two card push, about 2.4 s for a hand with
## three draws on each side.
const CARD_SLIDE_SECONDS := 0.18
const CARD_GAP_SECONDS := 0.12
const FLIP_SECONDS := 0.16
const STAMP_SECONDS := 0.5
const OUTCOME_RISE_SECONDS := 0.25

var _hand: Dictionary = {}
var _dealt := 0
var _stamp := 0.0
var _stamp_side := 0
var _stamp_text := ""
var _outcome_rise := 0.0
var _dealing := false
var _tween: Tween = null

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
	MenuStyleScript.tick_page()


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


## ROW AND STAKE ARE THE SAME NUMBER AT THIS TABLE: see slots_menu.gd's own comment on the
## identical pair of overrides, which this mirrors for exactly the same reason.
func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		return
	set_stake_index(posmod(stake_index() + step, n))
	_selected = stake_index()
	MenuStyleScript.tick_move()


func point_at_row(index: int) -> void:
	super.point_at_row(index)
	_stake_index = _selected


func confirm() -> bool:
	if _tab != Tab.TABLE or selected_stake() <= 0:
		return false
	MenuStyleScript.tick_confirm()
	_sound_call(&"play", [&"chip_clink"])
	deal_requested.emit(selected_stake())
	return true


func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


## `side` is 0 for the player and 1 for the dealer. The dealer's row arcs gently upward across
## the top and the player's dips downward across the bottom, which is what a real table's felt
## does and what stops eight cards reading as a spreadsheet row.
func card_rect(side: int, index: int) -> Rect2:
	var slot: int = clampi(index, 0, CARDS_DRAWN_MAX - 1)
	var bow: float = ARC_LIFT * float(2 - absi(slot - 2))
	var y: float = (DEALER_ROW_Y - bow) if side == 1 else (PLAYER_ROW_Y + bow)
	return Rect2(Vector2(ROW_LEFT + CARD_PITCH * float(slot), y), CARD_SIZE)


func shoe_rect() -> Rect2:
	return SHOE


func stake_rect() -> Rect2:
	return STAKE


func outcome_rect() -> Rect2:
	return OUTCOME


func placard_rect() -> Rect2:
	return PLACARD


func cards_dealt() -> int:
	return _dealt


func animating() -> bool:
	return _dealing


func printed_lines() -> Array[String]:
	if _tab == Tab.PLACARD:
		return [] as Array[String]
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	return lines


func first_row_line_index() -> int:
	return printed_lines().size()


func focus_rect() -> Rect2:
	if _tab != Tab.TABLE or stakes().is_empty():
		return Rect2()
	return to_viewport(_stake_chip_rect(clampi(stake_index(), 0, stakes().size() - 1)))


func focused_id() -> StringName:
	if _tab != Tab.TABLE or stakes().is_empty():
		return &""
	return StringName("stake:%d" % clampi(stake_index(), 0, stakes().size() - 1))


func _stake_chip_rect(index: int) -> Rect2:
	var centre := Vector2(STAKE.position.x + 34.0 + 78.0 * float(index),
		STAKE.position.y + STAKE.size.y - 30.0 - (8.0 if index == stake_index() else 0.0))
	return Rect2(centre - Vector2(30.0, 30.0) * 1.1, Vector2(30.0, 30.0) * 2.2)


## THE ONE ROW ON THIS TABLE THE POINTER CAN TAKE: the stake she is about to deal for. Not a
## new rect: _stake_chip_rect() is what paint() and focus_rect() already draw and highlight,
## given a public name so the pointer kit can share it.
func row_rect(index: int) -> Rect2:
	return _stake_chip_rect(index)


## TOLD, NEVER ASKED. ranch.gd's play_blackjack() has taken the stake, run
## Blackjack.play_hand() and settled by the time this is called. The hand is a finished thing;
## everything below is pacing.
##
## A HAND WITH NO CARDS IN IT IS A STILL FRAME: this arrives over a dynamic call() and nothing
## type checks it at the call site.
func show_hand(hand: Dictionary, won: int, stake: int) -> void:
	var player: Array = hand.get("player", []) as Array
	var dealer: Array = hand.get("dealer", []) as Array
	if player.is_empty() or dealer.is_empty():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_hand = hand.duplicate(true)
	_dealt = 0
	_outcome_rise = 0.0
	_dealing = true
	# THE ORDER IS THE ORDER A DEALER USES: player, dealer, player, dealer, then the player's
	# draws in order, then the dealer's. Blackjack.play_hand() built the arrays in exactly
	# that order, so walking them is walking the hand.
	var order: Array[int] = []
	for i: int in 2:
		order.append(0)
		order.append(1)
	for i: int in maxi(0, player.size() - 2):
		order.append(0)
	for i: int in maxi(0, dealer.size() - 2):
		order.append(1)
	_tween = create_tween()
	var elapsed := 0.0
	for step: int in order.size():
		var side: int = order[step]
		_tween.tween_callback(func() -> void:
			_dealt = step + 1
			# The first four cards are the deal; everything past them is a card turned over
			# in the open, which is a different gesture and a different sound.
			_sound_call(&"play", [&"card_slide" if step < 4 else &"card_flip"])
			# THE CARD IS PLAYED IN THE OPEN. Every card past the first four is a decision the
			# strategy card made on her behalf, so it is stamped as one: the player watches
			# the placard's own rules being executed rather than reading three lines
			# afterwards saying what happened. Blackjack.STRATEGY_DRAWS_BELOW is 17 for the
			# player and DEALER_STANDS_ON is 17 for the dealer.
			if step >= 4:
				_stamp = 1.0
				_stamp_side = side
				_stamp_text = "HIT"
		).set_delay(CARD_GAP_SECONDS if step > 0 else 0.0)
		_tween.tween_interval(CARD_SLIDE_SECONDS)
		elapsed += CARD_SLIDE_SECONDS + (CARD_GAP_SECONDS if step > 0 else 0.0)
	for side: int in 2:
		_tween.tween_callback(func() -> void:
			_stamp = 1.0
			_stamp_side = side
			_stamp_text = "STAND")
		_tween.tween_interval(STAMP_SECONDS)
	_tween.tween_property(self, "_outcome_rise", 1.0, OUTCOME_RISE_SECONDS)
	_tween.tween_callback(func() -> void: _dealing = false)
	if won < 0 or stake < 0:
		return


func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()

	if _tab == Tab.PLACARD:
		var placard: Array[String] = []
		for line in BlackjackScript.placard_lines():
			placard.append(line)
		PaintScript.plate(ci, PLACARD, font, "House rules", placard)
		return

	# --- the felt ----------------------------------------------------------------------------
	PaintScript.rounded(ci, Rect2(0.0, 0.0, STAGE_WIDTH, STAGE_HEIGHT), 18.0,
		PaintScript.FELT, PaintScript.FELT_DARK, 6.0)
	for row: float in [DEALER_ROW_Y + CARD_SIZE.y + 26.0, PLAYER_ROW_Y - 26.0]:
		ci.draw_arc(Vector2(STAGE_WIDTH * 0.5, row), 560.0, PI * 0.86, PI * 1.14, 48,
			PaintScript.FELT_LINE, 2.0, true)

	# --- the shoe ----------------------------------------------------------------------------
	PaintScript.rounded(ci, SHOE, 8.0, PaintScript.PLUM_DARK, PaintScript.GOLD_DIM, 2.0)
	PaintScript.draw_card(ci, Rect2(SHOE.position + Vector2(7.0, 10.0), CARD_SIZE * 0.72),
		font, -1, false)

	# --- both hands --------------------------------------------------------------------------
	var player: Array = _hand.get("player", []) as Array
	var dealer: Array = _hand.get("dealer", []) as Array
	var landed_player: int = 0
	var landed_dealer: int = 0
	for step: int in _dealt:
		# Reconstructs the same deal order show_hand() built, so paint() and the tween agree
		# without the tween having to write a second array for paint() to read.
		var side: int = (step % 2) if step < 4 \
			else (0 if step - 4 < maxi(0, player.size() - 2) else 1)
		if side == 0:
			landed_player += 1
		else:
			landed_dealer += 1
	for i: int in mini(landed_player, player.size()):
		PaintScript.draw_card(ci, card_rect(0, i), font, int(player[i]), true)
	for i: int in mini(landed_dealer, dealer.size()):
		PaintScript.draw_card(ci, card_rect(1, i), font, int(dealer[i]), true)

	# --- the totals, in a small gold pill beside each hand -------------------------------------
	for pair: Array in [[0, player, landed_player], [1, dealer, landed_dealer]]:
		var side: int = int(pair[0])
		var cards: Array = pair[1] as Array
		var shown: int = mini(int(pair[2]), cards.size())
		if shown <= 0:
			continue
		var visible: Array[int] = []
		for i: int in shown:
			visible.append(int(cards[i]))
		var total: int = BlackjackScript.hand_total(visible)
		var pill := Rect2(card_rect(side, 0).position - Vector2(96.0, 0.0),
			Vector2(78.0, 40.0))
		PaintScript.rounded(ci, pill, 20.0, Color(PaintScript.GOLD, 0.9),
			PaintScript.GOLD_DIM, 2.0)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			pill.position + Vector2(pill.size.x * 0.5, 29.0),
			("BUST" if total > 21 else str(total)), 22, PaintScript.CARD_INK,
			HORIZONTAL_ALIGNMENT_CENTER, -1.0)

	# --- the stamp: the strategy card, executed in the open ------------------------------------
	if _stamp > 0.0:
		_stamp = maxf(0.0, _stamp - get_process_delta_time() / STAMP_SECONDS)
		var at: Rect2 = card_rect(_stamp_side, 0)
		var stamp := Rect2(at.position + Vector2(0.0, -46.0), Vector2(88.0, 34.0))
		PaintScript.rounded(ci, stamp, 17.0, Color(PaintScript.GOLD, _stamp),
			Color(PaintScript.GOLD_DIM, _stamp), 2.0)
		PaintScript.text(ci, MenuStyleScript.title_font(),
			stamp.position + Vector2(stamp.size.x * 0.5, 25.0), _stamp_text, 20,
			Color(PaintScript.CARD_INK, _stamp), HORIZONTAL_ALIGNMENT_CENTER, -1.0)

	# --- the stake, in front of the player -----------------------------------------------------
	var available: Array[int] = stakes()
	for i: int in available.size():
		var box: Rect2 = _stake_chip_rect(i)
		PaintScript.chip(ci, box.position + box.size * 0.5, 30.0,
			PaintScript.CHIP_COLORS[i % PaintScript.CHIP_COLORS.size()], true)
		PaintScript.text(ci, MenuStyleScript.numeral_font(),
			box.position + Vector2(box.size.x * 0.5, box.size.y * 0.62), str(available[i]),
			20, PaintScript.CARD_INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
		if i == stake_index():
			PaintScript.focus_ring(ci, box.grow(6.0), 40.0, t)

	# --- the outcome plate, rising out of the felt ---------------------------------------------
	if _outcome_rise > 0.0 and not _hand.is_empty():
		var rect := Rect2(OUTCOME.position + Vector2(0.0, 30.0 * (1.0 - _outcome_rise)),
			OUTCOME.size)
		PaintScript.rounded(ci, rect, 12.0,
			Color(PaintScript.FELT_DARK, 0.94 * _outcome_rise),
			Color(PaintScript.GOLD, _outcome_rise), 2.0)
		PaintScript.text(ci, MenuStyleScript.title_font(),
			rect.position + Vector2(rect.size.x * 0.5, 50.0),
			BlackjackScript.outcome_text(_hand), MenuStyleScript.TITLE_SIZE,
			Color(PaintScript.GOLD, _outcome_rise), HORIZONTAL_ALIGNMENT_CENTER, -1.0)


## ONE HIT PER STAKE CHIP. The placard tab has no row to click at all: row_count() already
## answers 0 there, so this returns empty on its own without a special case.
func stage_hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in row_count():
		out.append(row_rect(i))
	return out


func on_stage_hit(index: int) -> void:
	take_row(index)
