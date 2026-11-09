class_name BlackjackMenu
extends "res://ui/casino_table.gd"
## THE BLACKJACK TABLE, where she plays her own hand. Stake chips and Deal before a hand; Hit,
## Stand and Double during one; the dealer's second card face down and his total a "?" until
## she is done; then the hole card turns, he draws to his rule, and a banner says what
## happened in a headline that fits its plate. A Rules tab carries the placard.
##
## THE OWNER'S PLAYTEST (2026-11-05): "why blackjack i cant make decisions? ui is fucked here
## too", a banner whose text ran out of its box, the "=====" log under the felt, and "dealer
## 'stand' after he bust". The hand used to be dealt and played to the end in one press by the
## house strategy card, with a STAND stamp put on both hands whatever had happened. Now the
## hand waits for her (game/systems/blackjack_round.gd), and the banner's wording comes from
## how the hand actually ended (BlackjackRound.headline()), so a dealer over 21 "busts".
##
## THE MENU STILL ONLY DRAWS AND EMITS. deal_requested(stake) asks ranch.gd for a hand,
## action_requested(action) for a Hit, Stand or Double; ranch.gd moves every chip and pushes
## the hand back through show_hand() after each step. The hole card is not in what it pushes
## until the hand is over, so nothing here can show it early.
##
## THE SUIT ON A CARD IS DRAWN HERE AND MEANS NOTHING: card / 13 picks a suit for the face,
## and hand_total() reads the rank alone.

const BlackjackScript := preload("res://systems/blackjack.gd")
const RoundScript := preload("res://systems/blackjack_round.gd")

const TITLE := "Blackjack"

# --- the felt, in stage local pixels ---------------------------------------------------------
const STAGE_HEIGHT := 560.0
const CARD_SIZE := Vector2(96.0, 134.0)
const CARD_PITCH := 110.0
const CARDS_LEFT := 290.0
const CARDS_RIGHT := 960.0
const DEALER_ROW_Y := 22.0
const PLAYER_ROW_Y := 304.0
const DEALER_BADGE := Rect2(40.0, 30.0, 190.0, 46.0)
const PLAYER_BADGE := Rect2(40.0, 312.0, 190.0, 46.0)
const SHOE := Rect2(990.0, 18.0, 104.0, 140.0)
const BANNER := Rect2(250.0, 168.0, 620.0, 122.0)
const BET_SPOT := Vector2(135.0, 470.0)
const CHIP_ROW_Y := 506.0
const CHIP_RADIUS := 32.0
const CHIP_PITCH := 74.0
const CHIPS_LEFT := 296.0
## CHIPS STACK ONTO THE BET (P8 S8; playtest 2026-11-08 item 58: "i hate i cant bet 100").
## A chip used to SET the stake to one of three values; now each press adds that chip to the
## bet on the spot, as at a real table, with Clear to take it back and Max to push the most
## the table allows. The bet stays out after a round, so "again" is one press of Deal.
const CHIPS: Array[int] = [10, 50, 100, 500]
const TABLE_MAX := 1000
const CLEAR := Rect2(604.0, 462.0, 90.0, 40.0)
const MAX := Rect2(604.0, 508.0, 90.0, 40.0)
const DEAL := Rect2(704.0, 462.0, 210.0, 86.0)
const HIT := Rect2(300.0, 462.0, 190.0, 86.0)
const STAND := Rect2(502.0, 462.0, 190.0, 86.0)
const DOUBLE := Rect2(704.0, 462.0, 190.0, 86.0)
## Split (PS5 item 48): a pair on her first two cards becomes two hands.
const SPLIT := Rect2(906.0, 462.0, 190.0, 86.0)
const COUNTER := Rect2(930.0, 476.0, 160.0, 58.0)
const RULES := Rect2(40.0, 20.0, 1040.0, 520.0)

# --- the pacing, every one a CONSTANT: presentation only, never a card -------------------------
const CARD_SECONDS := 0.32
const FLIP_SECONDS := 0.45
const DEALER_DRAW_SECONDS := 0.55
const BANNER_SECONDS := 0.30

enum Tab { TABLE, RULES }

## Injected by the ranch: the dealer's baked portrait, or null while it bakes (item 65).
var dealer_portrait := Callable()

signal deal_requested(stake: int)
signal action_requested(action: int)

var _tab: int = Tab.TABLE
var _stake := 1
var _bet := 0
var _view: Dictionary = {}
var _won := 0
var _shown_player := 0
var _shown_dealer := 0
var _hole_up := false
var _banner := 0.0
var _dealing := false
var _held_chips := -1
var _tween: Tween = null


func title_text() -> String:
	return TITLE


func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


func tab_names() -> Array[String]:
	return ["Table", "Rules"]


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.TABLE, Tab.RULES)
	_selected = maxi(0, button_index(_default_focus()))
	_hovered = -1
	refresh()


func point_at_tab(_index: int) -> void:
	pass


func initial_focus() -> StringName:
	return _default_focus()


func _default_focus() -> StringName:
	return &"hit" if hand_live() else &"deal"


func animating() -> bool:
	return _dealing


func open() -> bool:
	_tab = Tab.TABLE
	if not super.open():
		return false
	_fit_stake()
	return true


## WALKING AWAY MID HAND STANDS FOR HER. The stake is already on the felt and in ranch.gd's
## hands; a hand left open would be chips that vanished. Standing is the one decision that
## needs nothing more from her, so the dealer plays it out and she is paid what she earned.
func close() -> void:
	if is_open() and hand_live():
		action_requested.emit(RoundScript.Action.STAND)
	super.close()


func _purse() -> int:
	return int(chips_provider.call()) if chips_provider.is_valid() else 0


# --- the state --------------------------------------------------------------------------------

## A hand is on the felt and waiting for her decision.
func hand_live() -> bool:
	return not _view.is_empty() and not bool(_view.get("settled", true))


## The chips she can still add to the bet.
func stakes() -> Array[int]:
	var out: Array[int] = []
	for chip: int in CHIPS:
		if can_add(chip):
			out.append(chip)
	return out


## The last chip she put on.
func stake_index() -> int:
	return _stake


## The bet on the spot, never more than she holds.
func selected_stake() -> int:
	return mini(_bet, _purse())


func bet_cap() -> int:
	return mini(TABLE_MAX, _purse())


func can_add(chip: int) -> bool:
	return not _dealing and _bet + chip <= bet_cap()


## Put chip `index` on the bet (for shots and tests, as a press would).
func set_stake_index(index: int) -> void:
	if index >= 0 and index < CHIPS.size() and can_add(CHIPS[index]):
		_stake = index
		_bet += CHIPS[index]
		if _stage != null:
			_stage.queue_redraw()


func _fit_stake() -> void:
	_bet = mini(_bet, bet_cap())


func can_deal() -> bool:
	return _tab == Tab.TABLE and not _dealing and not hand_live() and selected_stake() > 0


func can_double() -> bool:
	return hand_live() and not _dealing and bool(_view.get("can_double", false)) \
		and _purse() >= int(_view.get("stake", 0))


func can_split() -> bool:
	return hand_live() and not _dealing and bool(_view.get("can_split", false)) \
		and _purse() >= int(_view.get("stake", 0))


## The hand she is playing in a split round (0 otherwise).
func active_hand() -> int:
	return int(_view.get("active", 0))


func _split_round() -> bool:
	return bool(_view.get("split", false))


## The player's cards as the felt shows them, one array per hand: a split shows both.
func shown_hands() -> Array:
	if not _split_round():
		return [shown_player_cards()]
	var out: Array = []
	for h: Dictionary in _view.get("hands", []) as Array:
		var cards: Array[int] = []
		for c in h.get("cards", []) as Array:
			cards.append(int(c))
		out.append(cards)
	return out


func shown_chips() -> int:
	return _held_chips if _held_chips >= 0 else _purse()


## The cards the felt is SHOWING right now, which during the deal is fewer than the hand holds.
func shown_player_cards() -> Array[int]:
	var out: Array[int] = []
	var cards: Array = _view.get("player", []) as Array
	for i: int in mini(_shown_player, cards.size()):
		out.append(int(cards[i]))
	return out


## The dealer's cards as shown, the hole card as -1 while it is face down.
func shown_dealer_cards() -> Array[int]:
	var out: Array[int] = []
	var cards: Array = _view.get("dealer", []) as Array
	for i: int in _shown_dealer:
		if i == 1 and not _hole_up:
			out.append(-1)
		elif i < cards.size():
			out.append(int(cards[i]))
	return out


## WHAT THE DEALER'S PILL SAYS: "?" while the hole card is down, his total once it is up.
func dealer_total_text() -> String:
	if _shown_dealer <= 0:
		return ""
	if not _hole_up:
		return "?"
	var total: int = BlackjackScript.hand_total(shown_dealer_cards())
	return "Bust" if total > 21 else str(total)


func player_total_text() -> String:
	var cards: Array[int] = shown_player_cards()
	if cards.is_empty():
		return ""
	var total: int = BlackjackScript.hand_total(cards)
	return "Bust" if total > 21 else str(total)


func banner_up() -> bool:
	return _banner > 0.0


func headline() -> String:
	if _split_round():
		return RoundScript.split_headline(_view)
	return RoundScript.headline(int(_view.get("ending", RoundScript.Ending.NONE)))


func detail() -> String:
	if _split_round():
		return RoundScript.split_detail(_view)
	return RoundScript.detail(_view)


## Chips riding on the round: every hand's stake, doubled where she doubled.
func _riding() -> int:
	if _split_round():
		var total := 0
		for h: Dictionary in _view.get("hands", []) as Array:
			total += int(_view.get("stake", 0)) * (2 if bool(h.get("doubled", false)) else 1)
		return total
	return int(_view.get("stake", 0)) * (2 if bool(_view.get("doubled", false)) else 1)


# --- the controls -----------------------------------------------------------------------------

func stake_chip_rect(index: int) -> Rect2:
	var centre := Vector2(CHIPS_LEFT + CHIP_RADIUS + CHIP_PITCH * float(index), CHIP_ROW_Y)
	return Rect2(centre - Vector2(CHIP_RADIUS, CHIP_RADIUS) * 1.15,
		Vector2(CHIP_RADIUS, CHIP_RADIUS) * 2.3)


func banner_rect() -> Rect2:
	return BANNER


func card_rect(side: int, index: int, count: int) -> Rect2:
	var pitch: float = CARD_PITCH
	if count > 1:
		pitch = minf(CARD_PITCH, (CARDS_RIGHT - CARDS_LEFT - CARD_SIZE.x) / float(count - 1))
	var y: float = DEALER_ROW_Y if side == 1 else PLAYER_ROW_Y
	return Rect2(Vector2(CARDS_LEFT + pitch * float(index), y), CARD_SIZE)


func stage_buttons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _tab != Tab.TABLE:
		return out
	if hand_live():
		out.append({"id": &"hit", "rect": HIT, "enabled": not _dealing})
		out.append({"id": &"stand", "rect": STAND, "enabled": not _dealing})
		out.append({"id": &"double", "rect": DOUBLE, "enabled": can_double()})
		out.append({"id": &"split", "rect": SPLIT, "enabled": can_split()})
		return out
	for i: int in CHIPS.size():
		out.append({"id": StringName("stake:%d" % i), "rect": stake_chip_rect(i),
			"enabled": can_add(CHIPS[i])})
	out.append({"id": &"clear", "rect": CLEAR, "enabled": not _dealing and _bet > 0})
	out.append({"id": &"max", "rect": MAX, "enabled": not _dealing and _bet < bet_cap()})
	out.append({"id": &"deal", "rect": DEAL, "enabled": can_deal()})
	return out


func activate(id: StringName) -> bool:
	var name: String = String(id)
	if name.begins_with("stake:"):
		var index: int = int(name.substr(6))
		if index < 0 or index >= CHIPS.size() or not can_add(CHIPS[index]):
			return false
		set_stake_index(index)
		_sound_call(&"play", [&"chip_clink"])
		return true
	match id:
		&"clear":
			if _dealing or _bet <= 0:
				return false
			_bet = 0
			MenuStyleScript.tick_back()
			refresh()
			return true
		&"max":
			if _dealing or _bet >= bet_cap():
				return false
			_bet = bet_cap()
			_sound_call(&"play", [&"chip_clink"])
			refresh()
			return true
		&"deal":
			if not can_deal():
				return false
			MenuStyleScript.tick_confirm()
			_sound_call(&"play", [&"chip_clink"])
			deal_requested.emit(selected_stake())
			return true
		&"hit":
			return _act(RoundScript.Action.HIT)
		&"stand":
			return _act(RoundScript.Action.STAND)
		&"double":
			if not can_double():
				return false
			_sound_call(&"play", [&"chip_clink"])
			return _act(RoundScript.Action.DOUBLE)
		&"split":
			if not can_split():
				return false
			_sound_call(&"play", [&"chip_clink"])
			return _act(RoundScript.Action.SPLIT)
	return false


func _act(action: int) -> bool:
	if not hand_live() or _dealing:
		return false
	MenuStyleScript.tick_confirm()
	action_requested.emit(action)
	return true


# --- the push ----------------------------------------------------------------------------------

## TOLD, NEVER ASKED, after every step of a hand: the deal, each Hit, the Stand or Double that
## ends it. `view` is BlackjackRound.view(); `won` is what the settle paid (0 until it is over);
## `staked` is the chips riding on it. A hand with no cards in it is a still frame.
##
## WHAT IS NEW SINCE THE LAST PUSH IS WHAT ANIMATES: a fresh hand deals four cards in the
## dealer's order (hers, his, hers, his face down); a Hit slides one card to her; the end of
## the hand turns his hole card over and deals his draws one at a time, then the banner rises.
func show_hand(view: Dictionary, won: int, _staked: int) -> void:
	var player: Array = view.get("player", []) as Array
	var dealer: Array = view.get("dealer", []) as Array
	if player.size() < 2 or dealer.is_empty():
		return
	if _tween != null and _tween.is_valid():
		_tween.custom_step(60.0)
	var fresh: bool = _view.is_empty() or bool(_view.get("settled", true))
	_view = view.duplicate(true)
	_won = maxi(0, won)
	_dealing = true
	_held_chips = maxi(0, _purse() - _won)
	_tween = create_tween()
	if fresh:
		_shown_player = 0
		_shown_dealer = 0
		_hole_up = false
		_banner = 0.0
		for step: int in 4:
			var to_player: bool = step % 2 == 0
			_tween.tween_callback(func() -> void:
				if to_player:
					_shown_player += 1
				else:
					_shown_dealer += 1
				_sound_call(&"play", [&"card_slide"]))
			_tween.tween_interval(CARD_SECONDS)
	for i: int in range(maxi(_shown_player, 2), player.size()):
		_tween.tween_callback(func() -> void:
			_shown_player += 1
			_sound_call(&"play", [&"card_slide"]))
		_tween.tween_interval(CARD_SECONDS)
	if bool(view.get("settled", false)):
		_tween.tween_callback(func() -> void:
			_shown_dealer = maxi(_shown_dealer, 2)
			_hole_up = true
			_sound_call(&"play", [&"card_flip"]))
		_tween.tween_interval(FLIP_SECONDS)
		for i: int in range(2, dealer.size()):
			_tween.tween_callback(func() -> void:
				_shown_dealer += 1
				_sound_call(&"play", [&"card_slide"]))
			_tween.tween_interval(DEALER_DRAW_SECONDS)
		_tween.tween_callback(func() -> void:
			_held_chips = -1
			if _won > 0:
				_sound_call(&"play", [&"slots_win"]))
		_tween.tween_property(self, "_banner", 1.0, BANNER_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		_dealing = false
		_held_chips = -1
		_fit_stake()
		_selected = maxi(0, button_index(_default_focus()))
		refresh())
	# A PUSH INTO A CLOSED TABLE LANDS AT ONCE: nobody is watching, and a felt left mid
	# animation would refuse the next bet when it is opened.
	if not is_open():
		finish_animation()


## A ranch push of result lines lands here and is not printed: the felt tells it.
func show_result(lines: Array[String]) -> void:
	_result = lines.duplicate()


func drawn_lines() -> Array[String]:
	var lines: Array[String] = ["Dealer", "You", "Deal", "Hit", "Stand", "Double", "Split"]
	for line in BlackjackScript.placard_lines():
		lines.append(line)
	if banner_up():
		lines.append(headline())
		lines.append(detail())
	return lines


# --- the paint ----------------------------------------------------------------------------------

## A TABLE, NOT A GREEN RECTANGLE (P8, playtest 2026-11-08 items 58 and 65: "the table is
## mostly empty felt with text labels"; references Red Dead's tables and Clubhouse Games): a
## faint diamond nap in the cloth, a darker rim where the light falls off, and the Spectra
## Palace's crest pressed into the middle of the felt.
func _paint_felt_dressing(ci: Control) -> void:
	var nap := Color(0.0, 0.0, 0.0, 0.05)
	var step := 34.0
	var x := -STAGE_HEIGHT
	while x < STAGE_WIDTH:
		ci.draw_line(Vector2(x, 0.0), Vector2(x + STAGE_HEIGHT, STAGE_HEIGHT), nap, 1.0, true)
		ci.draw_line(Vector2(x + STAGE_HEIGHT, 0.0), Vector2(x, STAGE_HEIGHT), nap, 1.0, true)
		x += step
	for k in 6:
		var inset := 6.0 + float(k) * 7.0
		PaintScript.rounded(ci, Rect2(inset, inset, STAGE_WIDTH - inset * 2.0,
			STAGE_HEIGHT - inset * 2.0), 24.0, Color(0, 0, 0, 0), Color(0.0, 0.05, 0.02, 0.07), 7.0)
	var crest_side := 190.0
	var crest := IconSet.texture("palace", 256, false)
	ci.draw_texture_rect(crest, Rect2(Vector2(STAGE_WIDTH * 0.5 - crest_side * 0.5, 150.0),
		Vector2(crest_side, crest_side)), false, Color(1.0, 1.0, 1.0, 0.12))


func paint(ci: Control) -> void:
	var title_font: Font = MenuStyleScript.title_font()
	var numeral_font: Font = MenuStyleScript.numeral_font()
	if _tab == Tab.RULES:
		_paint_rules(ci, title_font)
		return
	var t: float = anim_time()

	# --- the felt ---------------------------------------------------------------------------
	PaintScript.rounded(ci, Rect2(0.0, 0.0, STAGE_WIDTH, STAGE_HEIGHT), 24.0,
		PaintScript.FELT, PaintScript.FELT_DARK, 6.0)
	_paint_felt_dressing(ci)
	ci.draw_arc(Vector2(STAGE_WIDTH * 0.5, -620.0), 900.0, PI * 0.30, PI * 0.70, 64,
		PaintScript.FELT_LINE, 2.0, true)
	if not banner_up():
		PaintScript.label(ci, title_font, Rect2(380.0, 212.0, 360.0, 34.0),
			"Blackjack pays 3 to 2", 20, Color(1.0, 0.94, 0.72, 0.30))

	# --- the shoe ----------------------------------------------------------------------------
	PaintScript.rounded(ci, SHOE, 10.0, PaintScript.PLUM_DARK, PaintScript.GOLD_DIM, 2.0)
	PaintScript.draw_card(ci, Rect2(SHOE.position + Vector2(10.0, 10.0),
		CARD_SIZE * Vector2(0.88, 0.88)), title_font, -1, false)

	# --- the two badges and their totals ------------------------------------------------------
	_paint_badge(ci, title_font, numeral_font, DEALER_BADGE, "Dealer", dealer_total_text())
	# THE DEALER HAS A FACE (P8 item 65; review 2.9: "the dealer is a word"): the table's own
	# dealer, baked by the PortraitBaker, on a plate at the badge's left.
	var face: Texture2D = dealer_portrait.call() if dealer_portrait.is_valid() else null
	if face != null:
		var plate := Rect2(DEALER_BADGE.position + Vector2(DEALER_BADGE.size.x + 10.0, -14.0),
			Vector2(74.0, 74.0))
		PaintScript.rounded(ci, plate, 37.0, Color(0.95, 0.9, 0.82), PaintScript.GOLD_DIM, 2.0)
		ci.draw_texture_rect(face, plate.grow(-3.0), false)
	_paint_badge(ci, title_font, numeral_font, PLAYER_BADGE, "You", player_total_text())

	# --- the hands ---------------------------------------------------------------------------
	var dealer: Array[int] = shown_dealer_cards()
	for i: int in dealer.size():
		var card: int = dealer[i]
		PaintScript.draw_card(ci, card_rect(1, i, dealer.size()), title_font, card, card >= 0)
	if _split_round():
		_paint_split_hands(ci, title_font, numeral_font)
	else:
		var player: Array[int] = shown_player_cards()
		for i: int in player.size():
			PaintScript.draw_card(ci, card_rect(0, i, player.size()), title_font, player[i], true)

	# --- her bet on its spot -------------------------------------------------------------------
	ci.draw_arc(BET_SPOT, 54.0, 0.0, TAU, 64, PaintScript.FELT_LINE, 3.0, true)
	var riding: int = 0
	if not _view.is_empty() and (hand_live() or banner_up()):
		riding = _riding()
	elif selected_stake() > 0:
		riding = selected_stake()
	if riding > 0:
		PaintScript.chip_stack(ci, BET_SPOT + Vector2(0.0, 14.0),
			clampi(riding / 25, 1, 6), PaintScript.CHIP_COLORS[_chip_colour(riding)], 6.0)
		PaintScript.label(ci, numeral_font, Rect2(BET_SPOT + Vector2(-60.0, 34.0),
			Vector2(120.0, 34.0)), str(riding), 26, PaintScript.GOLD)

	# --- the controls -------------------------------------------------------------------------
	if hand_live():
		PaintScript.button(ci, HIT, "Hit", Color(0.30, 0.66, 0.40), button_enabled(&"hit"),
			is_lit(&"hit"))
		PaintScript.button(ci, STAND, "Stand", Color(0.86, 0.30, 0.32),
			button_enabled(&"stand"), is_lit(&"stand"))
		PaintScript.button(ci, DOUBLE, "Double", Color(0.95, 0.62, 0.18),
			button_enabled(&"double"), is_lit(&"double"))
		PaintScript.button(ci, SPLIT, "Split", Color(0.42, 0.52, 0.92),
			button_enabled(&"split"), is_lit(&"split"))
	else:
		for i: int in CHIPS.size():
			var box: Rect2 = stake_chip_rect(i)
			var usable: bool = can_add(CHIPS[i])
			var centre: Vector2 = box.get_center() - Vector2(0.0, 6.0 if is_lit(StringName("stake:%d" % i)) else 0.0)
			PaintScript.chip(ci, centre, CHIP_RADIUS, _chip_tint(i) if usable
				else Color(0.30, 0.28, 0.32), true)
			PaintScript.label(ci, numeral_font, Rect2(centre - Vector2(CHIP_RADIUS * 0.7,
				14.0), Vector2(CHIP_RADIUS * 1.4, 28.0)), str(CHIPS[i]), 20,
				Color.WHITE if i >= 2 or not usable else PaintScript.CARD_INK)
		PaintScript.button(ci, CLEAR, "Clear", Color(0.62, 0.56, 0.66), button_enabled(&"clear"),
			is_lit(&"clear"))
		PaintScript.button(ci, MAX, "Max", Color(0.95, 0.78, 0.30), button_enabled(&"max"),
			is_lit(&"max"))
		var deal_text := "Deal %d" % selected_stake() if selected_stake() > 0 \
			else ("Place a bet" if _purse() > 0 else "No chips")
		PaintScript.button(ci, DEAL, deal_text, Color(0.95, 0.62, 0.18), can_deal(),
			is_lit(&"deal"))
		PaintScript.rounded(ci, COUNTER, 29.0, Color(0.0, 0.0, 0.0, 0.35),
			Color(PaintScript.GOLD, 0.5), 2.0)
		PaintScript.draw_chip_icon(ci, Rect2(COUNTER.position + Vector2(12.0, 14.0),
			Vector2(30.0, 30.0)))
		PaintScript.label(ci, numeral_font, Rect2(COUNTER.position + Vector2(50.0, 4.0),
			COUNTER.size - Vector2(60.0, 8.0)), "%d" % shown_chips(), 28, PaintScript.GOLD,
			HORIZONTAL_ALIGNMENT_LEFT)

	# --- the banner, last, over everything but the focus ring ----------------------------------
	if banner_up():
		_paint_banner(ci, title_font, numeral_font, t)
	paint_focus(ci)


func _paint_badge(ci: Control, title_font: Font, numeral_font: Font, rect: Rect2,
		caption: String, total: String) -> void:
	PaintScript.rounded(ci, rect, 23.0, Color(0.0, 0.0, 0.0, 0.28),
		Color(PaintScript.GOLD, 0.35), 2.0)
	PaintScript.label(ci, title_font, Rect2(rect.position + Vector2(16.0, 4.0),
		Vector2(rect.size.x - 96.0, rect.size.y - 8.0)), caption, 24,
		MenuStyleScript.COLOR_NAME, HORIZONTAL_ALIGNMENT_LEFT)
	if total.is_empty():
		return
	var pill := Rect2(rect.end.x - 80.0, rect.position.y + 5.0, 74.0, rect.size.y - 10.0)
	var bust: bool = total == "Bust"
	PaintScript.rounded(ci, pill, 18.0, Color(0.86, 0.30, 0.32) if bust else PaintScript.GOLD,
		PaintScript.GOLD_DIM, 2.0)
	PaintScript.label(ci, numeral_font, pill.grow(-6.0), total, 24,
		Color.WHITE if bust else PaintScript.CARD_INK)


## TWO HANDS SIDE BY SIDE on her half of the felt, each with its total over it and a gold bar
## under the one she is playing.
func _paint_split_hands(ci: Control, title_font: Font, numeral_font: Font) -> void:
	var hands: Array = shown_hands()
	var gap := 40.0
	var half: float = (CARDS_RIGHT - CARDS_LEFT - gap) * 0.5
	for h: int in hands.size():
		var cards: Array = hands[h]
		var left: float = CARDS_LEFT + float(h) * (half + gap)
		var pitch: float = minf(CARD_PITCH * 0.6, (half - CARD_SIZE.x) / maxf(1.0, float(cards.size() - 1)))
		for i: int in cards.size():
			PaintScript.draw_card(ci, Rect2(Vector2(left + pitch * float(i), PLAYER_ROW_Y), CARD_SIZE),
				title_font, int(cards[i]), true)
		var total: int = BlackjackScript.hand_total(cards as Array[int]) if cards.size() > 0 else 0
		PaintScript.label(ci, numeral_font, Rect2(left, PLAYER_ROW_Y - 30.0, half, 28.0),
			("Bust" if total > 21 else str(total)), 22, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		if hand_live() and h == active_hand():
			PaintScript.rounded(ci, Rect2(left, PLAYER_ROW_Y + CARD_SIZE.y + 8.0, half, 6.0), 3.0,
				PaintScript.GOLD, Color(0, 0, 0, 0), 0.0)


func _paint_banner(ci: Control, title_font: Font, numeral_font: Font, t: float) -> void:
	var grow: float = lerpf(0.85, 1.0, _banner)
	var rect := Rect2(BANNER.get_center() - BANNER.size * grow * 0.5, BANNER.size * grow)
	var good: bool = _won > _riding()
	var push: bool = int(_view.get("outcome", -1)) == BlackjackScript.Outcome.PUSH
	var edge: Color = PaintScript.GOLD if good else (Color(0.8, 0.8, 0.85) if push
		else Color(0.86, 0.30, 0.32))
	PaintScript.rounded(ci, Rect2(rect.position + Vector2(0.0, 6.0), rect.size), 26.0,
		Color(0.0, 0.0, 0.0, 0.35 * _banner), Color(0, 0, 0, 0), 0.0)
	PaintScript.rounded(ci, rect, 26.0, Color(PaintScript.PLUM_DARK, 0.95 * _banner),
		Color(edge, _banner), 4.0)
	var inner: Rect2 = rect.grow_individual(-24.0, -10.0, -24.0, -10.0)
	var right_w: float = 150.0 if _won > 0 else 0.0
	PaintScript.label(ci, title_font, Rect2(inner.position, Vector2(inner.size.x - right_w,
		inner.size.y * 0.62)), headline(), 50, Color(edge.lightened(0.2), _banner))
	PaintScript.label(ci, numeral_font, Rect2(inner.position + Vector2(0.0,
		inner.size.y * 0.62), Vector2(inner.size.x - right_w, inner.size.y * 0.38)), detail(),
		22, Color(1.0, 1.0, 1.0, 0.8 * _banner))
	if _won > 0:
		var pop: float = 1.0 + (0.05 * sin(t * 10.0) if good else 0.0)
		var prize := Rect2(inner.end.x - right_w + 10.0, inner.position.y + 10.0,
			right_w - 10.0, inner.size.y - 20.0)
		prize = Rect2(prize.get_center() - prize.size * pop * 0.5, prize.size * pop)
		PaintScript.rounded(ci, prize, 20.0, Color(PaintScript.GOLD, _banner),
			PaintScript.GOLD_DIM, 2.0)
		PaintScript.label(ci, numeral_font, prize.grow(-8.0), "+%d" % _won, 34,
			Color(PaintScript.CARD_INK, _banner))


func _paint_rules(ci: Control, title_font: Font) -> void:
	PaintScript.rounded(ci, RULES, 18.0, Color(PaintScript.FELT_DARK, 0.94),
		PaintScript.GOLD_DIM, 2.0)
	PaintScript.label(ci, title_font, Rect2(RULES.position + Vector2(28.0, 16.0),
		Vector2(RULES.size.x - 56.0, 48.0)), "House rules", 34, PaintScript.GOLD,
		HORIZONTAL_ALIGNMENT_LEFT)
	var lines: Array[String] = []
	for line in BlackjackScript.placard_lines():
		lines.append(line)
	lines.append("The house keeps %.1f bits of every 100 against that card."
		% (BlackjackScript.house_edge() * 100.0))
	# ICON ROWS, NOT EIGHT BULLET SENTENCES (Fable AAA review round 1, #8): two columns of
	# rules, each led by a chip that says what it is about at a glance (a suit, the face-down
	# card, 17, 3:2, x2, a split pair, the sign, a coin). The words are the placard's own.
	var top := RULES.position.y + 80.0
	var col_w := (RULES.size.x - 56.0 - 30.0) * 0.5
	var rows := int(ceil(float(lines.size()) / 2.0))
	var row_h := (RULES.size.y - 100.0) / float(maxi(rows, 1))
	for i in lines.size():
		var col := i / rows
		var r := i % rows
		var cell := Rect2(RULES.position.x + 28.0 + float(col) * (col_w + 30.0),
			top + float(r) * row_h, col_w, row_h - 10.0)
		var badge := Rect2(cell.position + Vector2(0.0, (cell.size.y - RULE_BADGE) * 0.5),
			Vector2(RULE_BADGE, RULE_BADGE))
		_rule_badge(ci, badge, lines[i], title_font)
		var words: Array[String] = [lines[i]]
		var text_box := Rect2(cell.position + Vector2(RULE_BADGE + 16.0, 0.0),
			Vector2(cell.size.x - RULE_BADGE - 16.0, cell.size.y))
		var px := PaintScript.paragraph_size(MenuStyleScript.numeral_font(), words, 21,
			text_box.size)
		var h := PaintScript.paragraph_height(MenuStyleScript.numeral_font(), words, px,
			text_box.size.x)
		PaintScript.paragraph(ci, MenuStyleScript.numeral_font(), Rect2(text_box.position
			+ Vector2(0.0, (text_box.size.y - h) * 0.5), Vector2(text_box.size.x, h + 4.0)),
			words, 21, MenuStyleScript.COLOR_NAME)


const RULE_BADGE := 58.0
## What leads each rule: [a word in it, an icon from the set or a short token on a chip].
const RULE_BADGES := [["deck", "suit_spades"], ["face down", "#back"], ["Dealer draws", "17"],
	["pays 3 to 2", "3:2"], ["Double", "x2"], ["Split", "#pair"], ["sign", "board"],
	["house keeps", "coin"]]


## One rule's chip: a gold-rimmed disc on the felt with the rule's picture or token.
func _rule_badge(ci: Control, box: Rect2, line: String, font: Font) -> void:
	var what := "star"
	for pair: Array in RULE_BADGES:
		if line.contains(String(pair[0])):
			what = String(pair[1])
			break
	var c := box.get_center()
	ci.draw_circle(c + Vector2(0, 3), box.size.x * 0.5, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, box.size.x * 0.5, PaintScript.PLUM)
	ci.draw_arc(c, box.size.x * 0.5 - 1.5, 0.0, TAU, 40, PaintScript.GOLD, 3.0, true)
	ci.draw_arc(c, box.size.x * 0.36, 0.0, TAU, 40, Color(PaintScript.GOLD_DIM, 0.6), 1.5, true)
	var inner := box.grow(-box.size.x * 0.2)
	match what:
		"#back":
			var card := Rect2(inner.get_center() - Vector2(13, 17), Vector2(26, 34))
			PaintScript.rounded(ci, card, 4.0, PaintScript.PLUM_DARK, PaintScript.GOLD, 2.0)
			for k in 3:
				ci.draw_line(card.position + Vector2(5, 8 + k * 9), card.position + Vector2(21, 2 + k * 9),
					Color(PaintScript.GOLD, 0.6), 1.5, true)
		"#pair":
			for k in 2:
				var card := Rect2(inner.get_center() + Vector2(-18 + k * 12, -15 + k * 4), Vector2(22, 28))
				PaintScript.rounded(ci, card, 3.0, PaintScript.CARD_FACE, PaintScript.CARD_INK, 1.5)
				PaintScript.label(ci, font, card.grow(-3.0), "A", 16, PaintScript.CARD_RED)
		_:
			if IconSet.has(what):
				# A picture sits on a cream face inside the gold ring, so a black suit reads.
				ci.draw_circle(c, box.size.x * 0.5 - 4.0, PaintScript.CARD_FACE)
				IconSet.draw(ci, what, inner)
			else:
				PaintScript.label(ci, font, inner, what, 22, PaintScript.GOLD)


## A chip's colour by its value: white 10, green 50, black 100, gold 500.
func _chip_tint(index: int) -> Color:
	if index < PaintScript.CHIP_COLORS.size():
		return PaintScript.CHIP_COLORS[index]
	return PaintScript.GOLD


func _chip_colour(amount: int) -> int:
	if amount >= STAKES[2]:
		return 2
	if amount >= STAKES[1]:
		return 1
	return 0
