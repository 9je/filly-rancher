extends RefCounted
## ONE HAND OF BLACKJACK THAT THE PLAYER ACTUALLY PLAYS. The deal, then her decisions (Hit,
## Stand, Double) one at a time, then the dealer's fixed rule, then the verdict.
##
## WHY A HAND IS AN OBJECT NOW. Blackjack.play_hand() used to deal and play a whole hand in
## one call, by the strategy card, because the table had no decisions. The owner's playtest
## (2026-11-05: "why blackjack i cant make decisions?") is the reason that is gone: a hand now
## waits for her between cards, so it has to be a thing that lives between two button presses.
## ranch.gd holds the one live round and is still the only file that moves a chip; this file
## never sees the purse. It answers what the cards did and what the hand is worth.
##
## THE DEAL ORDER IS THE OLD ONE, CARD FOR CARD. Player, dealer, player, dealer from a fresh
## partial Fisher Yates deck, then her draws, then the dealer's, each card one swap of the
## undealt tail. Blackjack.play_hand() now plays the strategy card THROUGH this class, and
## because the generator is asked for exactly the same numbers in exactly the same order, the
## edge measured on 2026-08-31 (Blackjack.PUBLISHED_EDGE) re measures to the same figure.
##
## THE RULES, which the placard prints:
##   - a natural on either side settles before anyone draws (the dealer peeks);
##   - she may Hit until she busts or reaches 21 (twenty one stands for her: there is nothing
##     left to decide), Stand, or Double on her first two cards (twice the stake, exactly one
##     more card, then she stands);
##   - the dealer turns the hole card over only when she is done, then draws below 17 and
##     stands on any 17, hard or soft (Blackjack.DEALER_STANDS_ON);
##   - a player bust loses at once and the dealer draws nothing.
##   - a PAIR on her first two cards may be SPLIT, once, into two hands, each carrying the
##     stake again and each dealt one more card; she plays the first to its end, then the
##     second (she may Double either); split aces take one card each and stand; twenty one on
##     a split hand is a win, not a blackjack; the dealer plays once, after both hands, and
##     each hand settles on its own (PS5, playtest 2026-11-05 item 48: "no Hit/Stand/Double/
##     Split").
## No insurance and no resplitting.
##
## Preloaded by path, never by a class_name (the class cache lives in the gitignored .godot/).

const BlackjackScript := preload("res://systems/blackjack.gd")

enum Phase { PLAYER, SETTLED }

## What she can ask for. The menu's request signal carries one of these.
enum Action { HIT, STAND, DOUBLE, SPLIT }

## HOW THE HAND ENDED, finer than Blackjack.Outcome, which only says who is paid. The table's
## banner reads this: "Dealer busts" and "Dealer wins" are both a settle, but they are not the
## same sentence, and the playtest caught the table saying the dealer stood after he bust.
enum Ending { NONE, PLAYER_BLACKJACK, DEALER_BLACKJACK, BOTH_BLACKJACK, PLAYER_BUST,
	DEALER_BUST, PLAYER_HIGHER, DEALER_HIGHER, TIE }

var player: Array[int] = []
var dealer: Array[int] = []
var stake := 0
var doubled := false
var phase: int = Phase.PLAYER
var outcome: int = BlackjackScript.Outcome.PUSH
var ending: int = Ending.NONE

## Every hand she plays: `player` is the first, and a split adds a second. `_hand_doubled`,
## `_hand_outcome` and `_hand_ending` run alongside; `_active` is the hand she is playing.
var _hands: Array = []
var _hand_doubled: Array[bool] = []
var _hand_outcome: Array[int] = []
var _hand_ending: Array[int] = []
var _active := 0
var _split := false

var _deck: Array[int] = []
var _dealt := 0
var _rng: RandomNumberGenerator = null


## Shuffle, deal four cards, and settle at once if either side holds a natural. `rng` is the
## caller's and is drawn from lazily, one card at a time, for the rest of the hand.
static func deal(rng: RandomNumberGenerator, stake_chips: int) -> RefCounted:
	var hand: RefCounted = (load("res://systems/blackjack_round.gd") as GDScript).new()
	hand.call("_begin", rng, stake_chips)
	return hand


func _begin(rng: RandomNumberGenerator, stake_chips: int) -> void:
	_rng = rng
	stake = maxi(0, stake_chips)
	_deck.clear()
	for card in BlackjackScript.DECK_SIZE:
		_deck.append(card)
	_dealt = 0
	for i in 2:
		player.append(_draw())
		dealer.append(_draw())
	_hands = [player]
	_hand_doubled = [false]
	_hand_outcome = [BlackjackScript.Outcome.PUSH]
	_hand_ending = [Ending.NONE]
	var player_natural: bool = BlackjackScript.is_blackjack(player)
	var dealer_natural: bool = BlackjackScript.is_blackjack(dealer)
	if player_natural and dealer_natural:
		_settle(BlackjackScript.Outcome.PUSH, Ending.BOTH_BLACKJACK)
	elif player_natural:
		_settle(BlackjackScript.Outcome.PLAYER_BLACKJACK, Ending.PLAYER_BLACKJACK)
	elif dealer_natural:
		_settle(BlackjackScript.Outcome.DEALER_WIN, Ending.DEALER_BLACKJACK)


## One swap of the undealt tail. A deck run dry (it cannot be inside one hand of one deck, but
## a caller can always ask) deals nothing rather than erroring.
func _draw() -> int:
	if _dealt >= BlackjackScript.DECK_SIZE:
		return -1
	var picked: int = _rng.randi_range(_dealt, BlackjackScript.DECK_SIZE - 1)
	var swap: int = _deck[_dealt]
	_deck[_dealt] = _deck[picked]
	_deck[picked] = swap
	_dealt += 1
	return _deck[_dealt - 1]


func is_settled() -> bool:
	return phase == Phase.SETTLED


func can_hit() -> bool:
	return phase == Phase.PLAYER


func can_stand() -> bool:
	return phase == Phase.PLAYER


## The hand she is playing's first two cards only, and once.
func can_double() -> bool:
	return phase == Phase.PLAYER and _cur().size() == 2 and not bool(_hand_doubled[_active])


## A pair on her first two cards, before anything else, once.
func can_split() -> bool:
	return phase == Phase.PLAYER and not _split and player.size() == 2 and not doubled \
		and player[0] % BlackjackScript.RANKS == player[1] % BlackjackScript.RANKS


func hand_count() -> int:
	return _hands.size()


func hand_cards(i: int) -> Array[int]:
	var out: Array[int] = []
	if i >= 0 and i < _hands.size():
		for c in _hands[i] as Array:
			out.append(int(c))
	return out


func hand_outcome(i: int) -> int:
	return int(_hand_outcome[i]) if i >= 0 and i < _hand_outcome.size() else BlackjackScript.Outcome.PUSH


func hand_ending(i: int) -> int:
	return int(_hand_ending[i]) if i >= 0 and i < _hand_ending.size() else Ending.NONE


func active_hand() -> int:
	return _active


func _cur() -> Array:
	return _hands[_active]


## The total of the hand she is playing.
func player_total() -> int:
	return BlackjackScript.hand_total(hand_cards(_active))


func dealer_total() -> int:
	return BlackjackScript.hand_total(dealer)


## Chips riding on the round: the stake on each hand, twice over on a hand she doubled.
func total_staked() -> int:
	var total := 0
	for i in _hands.size():
		total += stake * (2 if bool(_hand_doubled[i]) else 1)
	return total


## What the settle hands back, the stakes included, under the contract every game in this
## Palace shares (Slots.payout()): each hand paid on its own. Zero while it is being played.
func payout() -> int:
	if not is_settled():
		return 0
	var total := 0
	for i in _hands.size():
		total += BlackjackScript.payout(int(_hand_outcome[i]), stake * (2 if bool(_hand_doubled[i]) else 1))
	return total


## Returns whether the action was taken. Anything asked of a settled hand is refused.
func act(action: int) -> bool:
	match action:
		Action.HIT:
			return hit()
		Action.STAND:
			return stand()
		Action.DOUBLE:
			return double_down()
		Action.SPLIT:
			return split()
	return false


func hit() -> bool:
	if not can_hit():
		return false
	_cur().append(_draw())
	var total: int = player_total()
	if total >= 21:
		_finish_hand()
	return true


func stand() -> bool:
	if not can_stand():
		return false
	_finish_hand()
	return true


## THE CALLER HAS ALREADY TAKEN THE SECOND STAKE. ranch.gd removes it from the purse first and
## only then calls this, the same take-then-play order every bet in the building keeps.
func double_down() -> bool:
	if not can_double():
		return false
	_hand_doubled[_active] = true
	if _active == 0:
		doubled = true
	_cur().append(_draw())
	_finish_hand()
	return true


## THE CALLER HAS ALREADY TAKEN THE SECOND HAND'S STAKE, as for a Double.
func split() -> bool:
	if not can_split():
		return false
	_split = true
	var second: Array[int] = [player[1]]
	player.remove_at(1)
	_hands.append(second)
	_hand_doubled.append(false)
	_hand_outcome.append(BlackjackScript.Outcome.PUSH)
	_hand_ending.append(Ending.NONE)
	player.append(_draw())
	second.append(_draw())
	_active = 0
	if BlackjackScript.is_ace(player[0]):
		# Split aces take one card each and stand.
		_active = _hands.size() - 1
		_finish_hand()
	elif BlackjackScript.hand_total(hand_cards(0)) == 21:
		_finish_hand()
	return true


## The hand she is playing is done (stood, bust, doubled or at 21): on to the next, or the
## dealer's turn after the last.
func _finish_hand() -> void:
	if _active < _hands.size() - 1:
		_active += 1
		if BlackjackScript.hand_total(hand_cards(_active)) == 21:
			_finish_hand()
		return
	_dealer_plays()


## The dealer plays once, after every hand, unless every hand bust; then each hand settles.
func _dealer_plays() -> void:
	var any_live := false
	for i in _hands.size():
		if BlackjackScript.hand_total(hand_cards(i)) <= 21:
			any_live = true
	if any_live:
		while dealer_total() < BlackjackScript.DEALER_STANDS_ON \
				and _dealt < BlackjackScript.DECK_SIZE:
			dealer.append(_draw())
	var theirs: int = dealer_total()
	for i in _hands.size():
		var mine: int = BlackjackScript.hand_total(hand_cards(i))
		if mine > 21:
			_hand_outcome[i] = BlackjackScript.Outcome.DEALER_WIN
			_hand_ending[i] = Ending.PLAYER_BUST
		elif theirs > 21:
			_hand_outcome[i] = BlackjackScript.Outcome.PLAYER_WIN
			_hand_ending[i] = Ending.DEALER_BUST
		elif mine > theirs:
			_hand_outcome[i] = BlackjackScript.Outcome.PLAYER_WIN
			_hand_ending[i] = Ending.PLAYER_HIGHER
		elif mine < theirs:
			_hand_outcome[i] = BlackjackScript.Outcome.DEALER_WIN
			_hand_ending[i] = Ending.DEALER_HIGHER
		else:
			_hand_outcome[i] = BlackjackScript.Outcome.PUSH
			_hand_ending[i] = Ending.TIE
	outcome = int(_hand_outcome[0])
	ending = int(_hand_ending[0])
	phase = Phase.SETTLED


func _settle(settled_outcome: int, settled_ending: int) -> void:
	outcome = settled_outcome
	ending = settled_ending
	if _hand_outcome.size() > 0:
		_hand_outcome[0] = settled_outcome
		_hand_ending[0] = settled_ending
	phase = Phase.SETTLED


## WHAT THE TABLE MAY SEE. The hole card is not in this dictionary until the hand is over, so
## no drawing bug can show it early: the menu is never handed the card at all.
func view() -> Dictionary:
	var shown_dealer: Array[int] = []
	if is_settled():
		shown_dealer = dealer.duplicate()
	else:
		shown_dealer.append(dealer[0])
	return {
		"player": player.duplicate(),
		"dealer": shown_dealer,
		"hole_hidden": not is_settled(),
		"settled": is_settled(),
		"outcome": outcome,
		"ending": ending,
		"doubled": doubled,
		"stake": stake,
		"can_double": can_double(),
		"can_split": can_split(),
		"split": _split,
		"active": _active,
		"hands": _hands_view(),
	}


func _hands_view() -> Array:
	var out: Array = []
	for i in _hands.size():
		out.append({"cards": hand_cards(i), "total": BlackjackScript.hand_total(hand_cards(i)),
			"doubled": bool(_hand_doubled[i]), "ending": int(_hand_ending[i]),
			"outcome": int(_hand_outcome[i])})
	return out


## The banner's big line. Never "stands" for a dealer who went over: the one wording bug the
## playtest caught on this table.
static func headline(settled_ending: int) -> String:
	match settled_ending:
		Ending.PLAYER_BLACKJACK:
			return "Blackjack!"
		Ending.DEALER_BLACKJACK:
			return "Dealer blackjack"
		Ending.BOTH_BLACKJACK:
			return "Push"
		Ending.PLAYER_BUST:
			return "Bust"
		Ending.DEALER_BUST:
			return "Dealer busts"
		Ending.PLAYER_HIGHER:
			return "You win"
		Ending.DEALER_HIGHER:
			return "Dealer wins"
		Ending.TIE:
			return "Push"
	return ""


## A SPLIT ROUND'S BANNER: how many of the two hands won, then each hand's own verdict.
static func split_headline(view_dict: Dictionary) -> String:
	var won := 0
	var lost := 0
	for h: Dictionary in view_dict.get("hands", []) as Array:
		match int(h.get("outcome", -1)):
			BlackjackScript.Outcome.PLAYER_WIN, BlackjackScript.Outcome.PLAYER_BLACKJACK:
				won += 1
			BlackjackScript.Outcome.DEALER_WIN:
				lost += 1
	var n := (view_dict.get("hands", []) as Array).size()
	if won == n:
		return "Both hands win"
	if lost == n:
		return "Both hands lose"
	if won == 0 and lost == 0:
		return "Push"
	return "Won %d of %d" % [won, n]


static func split_detail(view_dict: Dictionary) -> String:
	var parts: Array[String] = []
	var i := 1
	for h: Dictionary in view_dict.get("hands", []) as Array:
		parts.append("Hand %d: %s" % [i, headline(int(h.get("ending", Ending.NONE)))])
		i += 1
	return " \u00b7 ".join(parts)


## The banner's small line: the numbers behind the headline, or nothing when the headline is
## already the whole story.
static func detail(view_dict: Dictionary) -> String:
	var player_cards: Array[int] = []
	for card in view_dict.get("player", []) as Array:
		player_cards.append(int(card))
	var dealer_cards: Array[int] = []
	for card in view_dict.get("dealer", []) as Array:
		dealer_cards.append(int(card))
	var mine: int = BlackjackScript.hand_total(player_cards)
	var theirs: int = BlackjackScript.hand_total(dealer_cards)
	match int(view_dict.get("ending", Ending.NONE)):
		Ending.PLAYER_BLACKJACK:
			return "Pays 3 to 2"
		Ending.BOTH_BLACKJACK:
			return "Blackjack each"
		Ending.PLAYER_BUST:
			return "%d is over 21" % mine
		Ending.DEALER_BUST:
			return "Dealer drew to %d" % theirs
		Ending.PLAYER_HIGHER:
			return "%d beats %d" % [mine, theirs]
		Ending.DEALER_HIGHER:
			return "%d beats %d" % [theirs, mine]
		Ending.TIE:
			return "%d each" % mine
	return ""
