extends GutTest
## THE RANCH'S SIDE OF THE REBUILT TABLES (2026-11-05): the wheel takes a set of stakes, and a
## blackjack hand is dealt, then played a decision at a time. ranch.gd is still the only file
## that moves a chip, so the claims here are about the purse: every stake out before the roll
## or the card, a Double's second stake out before its card (and refused, changing nothing,
## when the purse cannot cover it), one live hand at a time, and the settle paying exactly
## what the round says.

const RanchScript := preload("res://world/ranch.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const WheelScript := preload("res://systems/wheel.gd")
const RoundScript := preload("res://systems/blackjack_round.gd")

const STARTING_CHIPS := 500
const STAKE := 50

var _ranch: RanchScript = null


func before_each() -> void:
	_ranch = autofree(RanchScript.new())
	_ranch._game_state = autofree(GameStateScript.new())
	_ranch._game_state.casino.add_chips(STARTING_CHIPS)


func _chips() -> int:
	return _ranch._game_state.casino.chips


## Deal hands from successive seeds until one is still waiting for her; returns that deal.
func _live_deal() -> Dictionary:
	for seed_value in range(1, 400):
		_ranch.set_casino_seed(seed_value)
		var before: int = _chips()
		var dealt: Dictionary = _ranch.play_blackjack(STAKE)
		if bool(dealt["ok"]) and not bool(dealt["settled"]):
			dealt["purse_before"] = before
			return dealt
	return {}


func test_a_wheel_spin_takes_every_stake_and_pays_only_the_tier_it_lands_on() -> void:
	var bets: Array[int] = [20, 10, 0, 0, 10]
	for i in 30:
		var before: int = _chips()
		var spun: Dictionary = _ranch.play_wheel(bets)
		assert_true(bool(spun["ok"]))
		assert_eq(int(spun["stake"]), 40)
		assert_eq(int(spun["won"]), WheelScript.payout(bets, int(spun["segment"])))
		assert_eq(_chips(), before - 40 + int(spun["won"]))


func test_a_wheel_bet_bigger_than_the_purse_is_refused_and_moves_nothing() -> void:
	var spun: Dictionary = _ranch.play_wheel([400, 200, 0, 0, 0] as Array[int])
	assert_false(bool(spun["ok"]))
	assert_eq(_chips(), STARTING_CHIPS)
	assert_false(bool(_ranch.play_wheel(WheelScript.empty_bets())["ok"]),
		"an empty felt is not a bet")


func test_a_deal_takes_the_stake_and_waits_with_the_hole_card_hidden() -> void:
	var dealt: Dictionary = _live_deal()
	assert_false(dealt.is_empty())
	assert_eq(_chips(), int(dealt["purse_before"]) - STAKE, "the stake is out, nothing paid yet")
	var hand: Dictionary = dealt["hand"]
	assert_true(bool(hand["hole_hidden"]))
	assert_eq((hand["dealer"] as Array).size(), 1)
	assert_false(bool(_ranch.play_blackjack(STAKE)["ok"]), "one live hand at a time")


func test_standing_settles_and_the_purse_adds_up() -> void:
	var dealt: Dictionary = _live_deal()
	var before: int = _chips()
	var done: Dictionary = _ranch.blackjack_action(RoundScript.Action.STAND)
	assert_true(bool(done["ok"]))
	assert_true(bool(done["settled"]))
	assert_eq(_chips(), before + int(done["won"]), "the stake was already out; the win comes in")
	assert_false(bool(done["hand"]["hole_hidden"]))
	assert_false(bool(_ranch.blackjack_action(RoundScript.Action.HIT)["ok"]),
		"no hand, no action")
	assert_true(bool(_ranch.play_blackjack(STAKE)["ok"]), "and the next hand can be dealt")
	assert_false(dealt.is_empty())


func test_a_double_takes_a_second_stake_before_its_card() -> void:
	_live_deal()
	var before: int = _chips()
	var doubled: Dictionary = _ranch.blackjack_action(RoundScript.Action.DOUBLE)
	assert_true(bool(doubled["ok"]))
	assert_true(bool(doubled["settled"]), "a double ends the hand")
	assert_eq(int(doubled["stake"]), STAKE * 2)
	assert_eq(_chips(), before - STAKE + int(doubled["won"]))


func test_a_double_the_purse_cannot_cover_is_refused_and_changes_nothing() -> void:
	_live_deal()
	_ranch._game_state.casino.remove_chips(_chips() - (STAKE - 1))
	var before: int = _chips()
	var refused: Dictionary = _ranch.blackjack_action(RoundScript.Action.DOUBLE)
	assert_false(bool(refused["ok"]))
	assert_eq(_chips(), before)
	assert_true(bool(_ranch.blackjack_action(RoundScript.Action.HIT)["ok"]),
		"the hand is still live and still hers to play")


func test_every_hand_played_to_the_end_settles_the_purse_exactly() -> void:
	for seed_value in range(1, 120):
		_ranch.set_casino_seed(seed_value)
		_ranch._game_state.casino.add_chips(STAKE * 2)
		var before: int = _chips()
		var step: Dictionary = _ranch.play_blackjack(STAKE)
		assert_true(bool(step["ok"]))
		var guard := 0
		while not bool(step["settled"]) and guard < 12:
			step = _ranch.blackjack_action(RoundScript.Action.HIT if guard < 1
				else RoundScript.Action.STAND)
			guard += 1
		assert_true(bool(step["settled"]))
		assert_eq(_chips(), before - int(step["stake"]) + int(step["won"]),
			"seed %d" % seed_value)
