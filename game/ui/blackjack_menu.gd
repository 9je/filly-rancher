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
## A TABLE, SEEN FROM HER STOOL (Fable AAA round 5: "blackjack reads as a flat web panel";
## slots proved the kit can be a thing). A half-moon of felt in perspective, its straight edge
## (the dealer's) far and a touch narrower than the curve at her end, inside a padded leather
## rail on a wooden lip; the dealer's bust over the far edge with his chip rack and the shoe
## either side of him; his cards in a shallow arc under him and hers fanned in an arc at her
## end; the bet a stack of chips in its printed circle. The buttons stand in front of the
## rail, off the felt, as the slot machine's do under its cabinet.
const STAGE_HEIGHT := 664.0
const CARD_SIZE := Vector2(90.0, 126.0)
const CARD_PITCH := 96.0
const CARDS_LEFT := 300.0
const CARDS_RIGHT := 820.0
## The felt: the dealer's straight edge at TABLE_TOP, the curve of an ellipse round TABLE_CENTRE.
const TABLE_CENTRE := Vector2(560.0, 148.0)
const TABLE_RX := 540.0
const TABLE_RY := 366.0
## How much narrower the far edge is than the near curve: the perspective.
const TABLE_FAR := 0.86
const RAIL := 30.0
const BUST_CENTRE := Vector2(560.0, 68.0)
const BUST_RADIUS := 62.0
## The dealer's arc and hers: card centres on circles round these, CARD_FAN radians apart.
const DEALER_ARC_CENTRE := Vector2(560.0, -516.0)
const DEALER_ARC_RADIUS := 760.0
const PLAYER_ARC_CENTRE := Vector2(560.0, 874.0)
const PLAYER_ARC_RADIUS := 470.0
const DEALER_ROW_Y := 136.0
const PLAYER_ROW_Y := 336.0
const DEALER_BADGE := Rect2(632.0, 50.0, 96.0, 46.0)
const PLAYER_BADGE := Rect2(212.0, 340.0, 96.0, 46.0)
const RACK := Rect2(286.0, 138.0, 210.0, 46.0)
const SHOE := Rect2(838.0, 142.0, 88.0, 118.0)
const BANNER := Rect2(250.0, 234.0, 620.0, 122.0)
const BET_SPOT := Vector2(856.0, 396.0)
const CHIP_ROW_Y := 610.0
const CHIP_RADIUS := 32.0
const CHIP_PITCH := 74.0
const CHIPS_LEFT := 296.0
## CHIPS STACK ONTO THE BET (P8 S8; playtest 2026-11-08 item 58: "i hate i cant bet 100").
## A chip used to SET the stake to one of three values; now each press adds that chip to the
## bet on the spot, as at a real table, with Clear to take it back and Max to push the most
## the table allows. The bet stays out after a round, so "again" is one press of Deal.
const CHIPS: Array[int] = [10, 50, 100, 500]
const TABLE_MAX := 1000
const CLEAR := Rect2(604.0, 566.0, 90.0, 40.0)
const MAX := Rect2(604.0, 612.0, 90.0, 40.0)
const DEAL := Rect2(704.0, 566.0, 210.0, 86.0)
const HIT := Rect2(150.0, 566.0, 190.0, 86.0)
const STAND := Rect2(352.0, 566.0, 190.0, 86.0)
const DOUBLE := Rect2(578.0, 566.0, 190.0, 86.0)
## Split (PS5 item 48): a pair on her first two cards becomes two hands.
const SPLIT := Rect2(780.0, 566.0, 190.0, 86.0)
const COUNTER := Rect2(930.0, 580.0, 160.0, 58.0)
const RULES := Rect2(40.0, 20.0, 1040.0, 624.0)
## Where the felt is printed with its line: the arc's centre and radius.
const PRINT_CENTRE := Vector2(560.0, -516.0)
const PRINT_RADIUS := 846.0

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


## Card `index` of `count` on `side` (1 the dealer's, 0 hers), unturned: the box round where
## card_xform() lays it.
func card_rect(side: int, index: int, count: int) -> Rect2:
	var xf: Transform2D = card_xform(side, index, count)
	return Rect2(xf.origin - CARD_SIZE * 0.5, CARD_SIZE)


## DEALT IN AN ARC (Fable AAA round 5): each card's centre on a circle and the card turned to
## it, his row a shallow smile under him, hers a fan opening toward her. The pitch tightens as
## a hand grows so the fan never leaves its half of the felt.
func card_xform(side: int, index: int, count: int) -> Transform2D:
	var centre: Vector2 = DEALER_ARC_CENTRE if side == 1 else PLAYER_ARC_CENTRE
	var radius: float = DEALER_ARC_RADIUS if side == 1 else PLAYER_ARC_RADIUS
	var pitch: float = CARD_PITCH
	if count > 1:
		pitch = minf(CARD_PITCH, (CARDS_RIGHT - CARDS_LEFT - CARD_SIZE.x) / float(count - 1))
	var step: float = pitch / radius
	var a: float = (float(index) - float(count - 1) * 0.5) * step
	# Down from the dealer's centre, up from hers.
	var dir := Vector2(sin(a), cos(a)) if side == 1 else Vector2(sin(a), -cos(a))
	var at: Vector2 = centre + dir * radius
	var turn: float = -a if side == 1 else a
	return Transform2D(turn, at)


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

## THE TABLE'S OUTLINE: the felt's edge from the dealer's right corner round the near curve to
## his left corner, `grow` pixels out, the far edge narrower than the near curve (TABLE_FAR)
## so the half-moon lies in perspective.
func table_points(grow: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := 64
	for i in n + 1:
		var a: float = PI * float(i) / float(n)
		var s: float = sin(a)
		var w: float = lerpf(TABLE_FAR, 1.0, s)
		out.append(TABLE_CENTRE + Vector2(cos(a) * (TABLE_RX + grow) * w, s * (TABLE_RY + grow)))
	return out


const LEATHER := Color(0.40, 0.12, 0.17)
const WOOD := Color(0.42, 0.24, 0.13)
const WOOD_DARK := Color(0.26, 0.14, 0.08)


## THE TABLE AS A THING (Fable AAA round 5): a shadow on the floor, a wooden lip, the padded
## leather rail with its sheen, its shade and a row of stitches, gold piping where it meets
## the felt, the felt under a warm pool of light, the dealer's wooden rail along the far edge.
func _paint_table(ci: Control, title_font: Font) -> void:
	var shadow := table_points(RAIL + 10.0)
	var lifted := PackedVector2Array()
	for p: Vector2 in shadow:
		lifted.append(p + Vector2(0.0, 14.0))
	ci.draw_colored_polygon(lifted, Color(0.0, 0.0, 0.0, 0.35))
	ci.draw_colored_polygon(table_points(RAIL + 8.0), WOOD_DARK)
	ci.draw_colored_polygon(table_points(RAIL + 5.0), WOOD)
	ci.draw_colored_polygon(table_points(RAIL), LEATHER)
	# The pad's roll: shade at its inner and outer edges, a sheen along its crown.
	ci.draw_polyline(table_points(RAIL - 3.0), LEATHER.darkened(0.35), 5.0, true)
	ci.draw_polyline(table_points(RAIL * 0.58), Color(LEATHER.lightened(0.35), 0.75), 7.0, true)
	ci.draw_polyline(table_points(RAIL * 0.58 - 4.0), Color(1.0, 0.9, 0.9, 0.18), 2.0, true)
	ci.draw_polyline(table_points(4.0), LEATHER.darkened(0.45), 6.0, true)
	var stitches := table_points(RAIL * 0.86)
	for i: int in range(1, stitches.size() - 1):
		ci.draw_circle(stitches[i], 1.6, Color(1.0, 0.85, 0.7, 0.45))
	# The felt, under a warm pool of light toward her end.
	var felt := table_points(0.0)
	ci.draw_colored_polygon(felt, PaintScript.FELT)
	var pool := TABLE_CENTRE + Vector2(0.0, TABLE_RY * 0.52)
	for k in 6:
		var f: float = 0.92 - 0.12 * float(k)
		var ring := PackedVector2Array()
		for p: Vector2 in felt:
			ring.append(pool + (p - pool) * f)
		ci.draw_colored_polygon(ring, Color(0.55, 0.85, 0.55, 0.035))
	var crest_side := 170.0
	var crest := IconSet.texture("palace", 256, false)
	ci.draw_texture_rect(crest, Rect2(Vector2(TABLE_CENTRE.x - crest_side * 0.5, 274.0),
		Vector2(crest_side, crest_side)), false, Color(1.0, 1.0, 1.0, 0.08))
	ci.draw_polyline(table_points(1.0), PaintScript.GOLD_DIM, 3.0, true)
	# The printing: two gold rules round the house's line, as a real felt is printed. A split's
	# two hands sit over it, so it gives way to them.
	if not banner_up() and not _split_round():
		for r: float in [PRINT_RADIUS - 24.0, PRINT_RADIUS + 20.0]:
			ci.draw_arc(PRINT_CENTRE, r, PI * 0.5 - 0.3, PI * 0.5 + 0.3, 64,
				Color(PaintScript.GOLD, 0.35), 2.0, true)
		PaintScript.arc_text(ci, title_font, PRINT_CENTRE, PRINT_RADIUS, PI * 0.5,
			"BLACKJACK PAYS 3 TO 2", 22, Color(PaintScript.GOLD, 0.92))


## THE DEALER BEHIND IT: his face over the far edge in a gold ring (the hall's own dealer,
## baked once by scenes/test/casino_portraits.gd), the wooden rail in front of him, his bow
## tie over it, the chip rack at his right hand and the shoe at his left.
func _paint_dealer(ci: Control, title_font: Font, numeral_font: Font) -> void:
	var left: float = TABLE_CENTRE.x - (TABLE_RX + RAIL + 8.0) * TABLE_FAR
	var right: float = TABLE_CENTRE.x + (TABLE_RX + RAIL + 8.0) * TABLE_FAR
	var rail := Rect2(left, TABLE_CENTRE.y - 18.0, right - left, 22.0)
	PaintScript.rounded(ci, Rect2(rail.position + Vector2(0.0, 5.0), rail.size), 10.0,
		Color(0.0, 0.0, 0.0, 0.3), Color(0, 0, 0, 0), 0.0)
	PaintScript.rounded(ci, rail, 10.0, WOOD, WOOD_DARK, 2.0)
	ci.draw_line(rail.position + Vector2(12.0, 5.0), Vector2(rail.end.x - 12.0, rail.position.y + 5.0),
		Color(1.0, 0.85, 0.6, 0.3), 2.0, true)
	PaintScript.bow_tie(ci, Vector2(BUST_CENTRE.x, rail.position.y + 2.0), 46.0, Color(0.62, 0.12, 0.2))
	_paint_rack(ci)
	# The shoe: a plum box with the next card showing at its mouth.
	PaintScript.rounded(ci, Rect2(SHOE.position + Vector2(0.0, 6.0), SHOE.size), 10.0,
		Color(0.0, 0.0, 0.0, 0.3), Color(0, 0, 0, 0), 0.0)
	PaintScript.rounded(ci, SHOE, 10.0, PaintScript.PLUM_DARK, PaintScript.GOLD_DIM, 2.0)
	PaintScript.draw_card(ci, Rect2(Vector2(-CARD_SIZE.x * 0.42, -CARD_SIZE.y * 0.42),
		CARD_SIZE * 0.84), title_font, -1, false,
		Transform2D(-0.12, SHOE.get_center() + Vector2(-6.0, 4.0)))
	_paint_total(ci, numeral_font, DEALER_BADGE, dealer_total_text())


## The dealer's rack: six channels of chips lying on their edges, a colour to a channel.
func _paint_rack(ci: Control) -> void:
	PaintScript.rounded(ci, RACK, 8.0, Color(0.12, 0.06, 0.08), PaintScript.GOLD_DIM, 2.0)
	var colours: Array[Color] = [PaintScript.CHIP_COLORS[0], PaintScript.CHIP_COLORS[1],
		PaintScript.CHIP_COLORS[2], PaintScript.GOLD, PaintScript.CHIP_COLORS[1],
		PaintScript.CHIP_COLORS[0]]
	var w: float = (RACK.size.x - 14.0) / float(colours.size())
	for i: int in colours.size():
		var ch := Rect2(RACK.position + Vector2(7.0 + w * float(i) + 2.0, 6.0),
			Vector2(w - 4.0, RACK.size.y - 12.0))
		PaintScript.rounded(ci, ch, 5.0, colours[i].darkened(0.15), Color(0, 0, 0, 0), 0.0)
		var y: float = ch.position.y + 3.0
		while y < ch.end.y - 2.0:
			ci.draw_line(Vector2(ch.position.x + 2.0, y), Vector2(ch.end.x - 2.0, y),
				Color(colours[i].lightened(0.4), 0.7), 1.0, true)
			y += 4.0


static var _dealer_tex: Texture2D = null


## The hall's dealer as baked (assets/ui/portraits/palace_dealer.png), or null on a checkout
## without it.
static func _dealer_face() -> Texture2D:
	if _dealer_tex == null and ResourceLoader.exists(DEALER_PORTRAIT):
		_dealer_tex = load(DEALER_PORTRAIT) as Texture2D
	return _dealer_tex


const DEALER_PORTRAIT := "res://assets/ui/portraits/palace_dealer.png"


## A STACK OF CHIPS, standing: `count` chips bottom up, each showing its edge under the next.
static func _stack(ci: Control, base: Vector2, count: int, colour: Color, radius: float,
		step: float) -> void:
	for k: int in mini(count, 8):
		PaintScript.chip(ci, base - Vector2(0.0, step * float(k)), radius, colour,
			k == mini(count, 8) - 1)


func paint(ci: Control) -> void:
	var title_font: Font = MenuStyleScript.title_font()
	var numeral_font: Font = MenuStyleScript.numeral_font()
	if _tab == Tab.RULES:
		_paint_rules(ci, title_font)
		return
	var t: float = anim_time()

	_paint_dealer_backdrop(ci)
	_paint_table(ci, title_font)
	_paint_dealer(ci, title_font, numeral_font)

	# --- the hands ---------------------------------------------------------------------------
	var dealer: Array[int] = shown_dealer_cards()
	var local := Rect2(-CARD_SIZE * 0.5, CARD_SIZE)
	for i: int in dealer.size():
		var card: int = dealer[i]
		PaintScript.draw_card(ci, local, title_font, card, card >= 0,
			card_xform(1, i, dealer.size()))
	if _split_round():
		_paint_split_hands(ci, title_font, numeral_font)
	else:
		var player: Array[int] = shown_player_cards()
		for i: int in player.size():
			PaintScript.draw_card(ci, local, title_font, player[i], true,
				card_xform(0, i, player.size()))
		if not player.is_empty():
			# Her total rides beside her fan, at its left end.
			var first: Vector2 = card_xform(0, 0, player.size()).origin
			_paint_total(ci, numeral_font, Rect2(first + Vector2(-CARD_SIZE.x * 0.5 - 24.0
				- PLAYER_BADGE.size.x, -PLAYER_BADGE.size.y * 0.5), PLAYER_BADGE.size),
				player_total_text())

	# --- her bet, a stack in its printed circle ----------------------------------------------
	ci.draw_arc(BET_SPOT, 52.0, 0.0, TAU, 64, Color(PaintScript.GOLD, 0.55), 3.0, true)
	ci.draw_arc(BET_SPOT, 44.0, 0.0, TAU, 64, Color(PaintScript.GOLD, 0.25), 1.5, true)
	var riding: int = 0
	if not _view.is_empty() and (hand_live() or banner_up()):
		riding = _riding()
	elif selected_stake() > 0:
		riding = selected_stake()
	if riding > 0:
		_stack(ci, BET_SPOT + Vector2(0.0, 12.0), clampi(riding / 25, 1, 6),
			PaintScript.CHIP_COLORS[_chip_colour(riding)], 30.0, 6.0)
		var tag := Rect2(BET_SPOT + Vector2(-46.0, 48.0), Vector2(92.0, 30.0))
		PaintScript.rounded(ci, tag, 15.0, Color(0.0, 0.0, 0.0, 0.45), Color(PaintScript.GOLD, 0.6), 1.5)
		PaintScript.label(ci, numeral_font, tag.grow(-3.0), str(riding), 22, PaintScript.GOLD)

	# --- the controls, in front of the rail -----------------------------------------------------
	if hand_live():
		# One gold primary (Hit, the move a hand is made of), the rest the kit's plum.
		PaintScript.kit_button(ci, HIT, "Hit", true, button_enabled(&"hit"), is_lit(&"hit"))
		PaintScript.kit_button(ci, STAND, "Stand", false, button_enabled(&"stand"),
			is_lit(&"stand"))
		PaintScript.kit_button(ci, DOUBLE, "Double", false, button_enabled(&"double"),
			is_lit(&"double"))
		PaintScript.kit_button(ci, SPLIT, "Split", false, button_enabled(&"split"),
			is_lit(&"split"))
	else:
		for i: int in CHIPS.size():
			var box: Rect2 = stake_chip_rect(i)
			var usable: bool = can_add(CHIPS[i])
			var centre: Vector2 = box.get_center() - Vector2(0.0, 6.0 if is_lit(StringName("stake:%d" % i)) else 0.0)
			# Each denomination a little stack of three, the way they sit in a tray.
			_stack(ci, centre + Vector2(0.0, 8.0), 3, _chip_tint(i) if usable
				else Color(0.30, 0.28, 0.32), CHIP_RADIUS, 5.0)
			PaintScript.label(ci, numeral_font, Rect2(centre - Vector2(CHIP_RADIUS * 0.7,
				16.0), Vector2(CHIP_RADIUS * 1.4, 28.0)), str(CHIPS[i]), 20,
				Color.WHITE if i >= 2 or not usable else PaintScript.CARD_INK)
		PaintScript.kit_button(ci, CLEAR, "Clear", false, button_enabled(&"clear"),
			is_lit(&"clear"))
		PaintScript.kit_button(ci, MAX, "Max", false, button_enabled(&"max"), is_lit(&"max"))
		var deal_text := "Deal %d" % selected_stake() if selected_stake() > 0 \
			else ("Place a bet" if _purse() > 0 else "No chips")
		PaintScript.kit_button(ci, DEAL, deal_text, true, can_deal(), is_lit(&"deal"))
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


## The wall behind the dealer: a velvet drape in the hall's plum with gold-lit folds, so he
## stands somewhere rather than on the panel.
func _paint_dealer_backdrop(ci: Control) -> void:
	var left: float = TABLE_CENTRE.x - (TABLE_RX + RAIL) * TABLE_FAR
	var right: float = TABLE_CENTRE.x + (TABLE_RX + RAIL) * TABLE_FAR
	var drape := Rect2(left, 0.0, right - left, TABLE_CENTRE.y)
	ci.draw_rect(drape, Color(0.27, 0.08, 0.26))
	var folds := 22
	for i in folds:
		var x: float = drape.position.x + drape.size.x * (float(i) + 0.5) / float(folds)
		ci.draw_line(Vector2(x, 0.0), Vector2(x, drape.end.y), Color(0.0, 0.0, 0.0, 0.22), 12.0, true)
		ci.draw_line(Vector2(x + 13.0, 0.0), Vector2(x + 13.0, drape.end.y),
			Color(1.0, 0.7, 0.9, 0.09), 7.0, true)
	# A warm spot on the dealer.
	for k in 4:
		ci.draw_circle(BUST_CENTRE, BUST_RADIUS * (2.2 - 0.3 * float(k)), Color(1.0, 0.85, 0.55, 0.05))
	# The valance: scallops in the drape's colour along the top, gold-trimmed, tassels between.
	var swags := 9
	var w: float = drape.size.x / float(swags)
	for i in swags:
		var x0: float = drape.position.x + w * float(i)
		var pts := PackedVector2Array([Vector2(x0, 0.0)])
		for k in 13:
			var u: float = float(k) / 12.0
			pts.append(Vector2(x0 + w * u, 10.0 + sin(u * PI) * 16.0))
		pts.append(Vector2(x0 + w, 0.0))
		ci.draw_colored_polygon(pts, Color(0.36, 0.12, 0.34))
		var trim := pts.slice(1, pts.size() - 1)
		ci.draw_polyline(trim, PaintScript.GOLD_DIM, 3.0, true)
		if i > 0:
			ci.draw_line(Vector2(x0, 8.0), Vector2(x0, 26.0), PaintScript.GOLD_DIM, 2.0, true)
			ci.draw_circle(Vector2(x0, 28.0), 4.0, PaintScript.GOLD)
	# The bake in the assets first (framed for this bust); the ranch's live bake of the same
	# seeded dealer only on a checkout without it.
	var face: Texture2D = _dealer_face()
	if face == null and dealer_portrait.is_valid():
		face = dealer_portrait.call()
	PaintScript.portrait_disc(ci, BUST_CENTRE, BUST_RADIUS, face, Color(0.86, 0.80, 0.92))


## A HAND'S TOTAL, a gold pill with no word on it (a red Bust when over), beside its owner.
func _paint_total(ci: Control, numeral_font: Font, rect: Rect2, total: String) -> void:
	if total.is_empty():
		return
	var bust: bool = total == "Bust"
	PaintScript.rounded(ci, Rect2(rect.position + Vector2(0.0, 4.0), rect.size), 23.0,
		Color(0.0, 0.0, 0.0, 0.35), Color(0, 0, 0, 0), 0.0)
	PaintScript.rounded(ci, rect, 23.0, Color(0.86, 0.30, 0.32) if bust else PaintScript.GOLD,
		PaintScript.GOLD_DIM, 3.0)
	PaintScript.label(ci, numeral_font, rect.grow(-6.0), total, 28,
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
		_paint_total(ci, numeral_font, Rect2(left, PLAYER_ROW_Y - 46.0, 76.0, 38.0),
			("Bust" if total > 21 else str(total)))
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
