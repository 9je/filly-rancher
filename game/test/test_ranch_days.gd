extends GutTest
## DAYS, SLEEP, THE AUTOSAVE AND THE DEBT CLEARED (P8; playtest 2026-11-08 items 3, 5, 6, 11).
## A detached Ranch (never in a tree), the way game/test/test_ranch_collection.gd drives one:
## what is under test is the clock and the ledger, not the scene.

const RanchScript := preload("res://world/ranch.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const LedgerScript := preload("res://systems/ledger.gd")


class FakePlayer:
	extends CharacterBody3D

	func get_magic_beam() -> Node3D:
		return null


func _ranch(at_seconds: float) -> RanchScript:
	var ranch: RanchScript = autofree(RanchScript.new())
	ranch.player = autofree(FakePlayer.new())
	ranch._game_state = autofree(GameStateScript.new())
	ranch._world = WorldStateScript.new(1, at_seconds)
	return ranch


func test_sleeping_skips_to_the_next_dawn_and_saves() -> void:
	# Night of day 1: DAWN 120 + DAY 540 + DUSK 120 = 780 s in.
	var ranch := _ranch(900.0)
	assert_eq(ranch._world.phase(), WorldStateScript.Phase.NIGHT)
	watch_signals(ranch._game_state)
	var slept: float = ranch.sleep_till_dawn()
	assert_almost_eq(slept, WorldStateScript.CYCLE_SECONDS - 900.0, 0.01)
	assert_eq(ranch._world.phase(), WorldStateScript.Phase.DAWN, "she wakes at dawn")
	assert_eq(ranch._world.cycle_index(), 1, "of the next day")
	assert_signal_emitted(ranch._game_state, "state_saved", "and the ranch is saved")


func test_a_night_through_a_collection_day_still_bills_it() -> void:
	# The night before cycle 3 (the first collection day): sleeping must not skip it.
	var ranch := _ranch(3.0 * WorldStateScript.CYCLE_SECONDS - 200.0)
	ranch._world.phase_changed.connect(func(_p: int) -> void: ranch._on_world_changed())
	ranch.sleep_till_dawn()
	assert_eq(ranch._game_state.ledger.periods_run, 1, "the collection day ran in the night")


func test_the_autosave_waits_five_minutes_of_free_play() -> void:
	var ranch := _ranch(100.0)
	watch_signals(ranch._game_state)
	ranch._tick_autosave(RanchScript.AUTOSAVE_SECONDS - 1.0)
	assert_signal_not_emitted(ranch._game_state, "state_saved")
	ranch._tick_autosave(2.0)
	assert_signal_emitted(ranch._game_state, "state_saved", "five minutes in: saved")
	assert_eq(ranch.autosaves, 1)
	assert_lte(RanchScript.AUTOSAVE_SECONDS, 300.0, "never more than five minutes apart")


func test_the_autosave_does_not_count_indoors() -> void:
	var ranch := _ranch(100.0)
	ranch._in_palace = true
	watch_signals(ranch._game_state)
	ranch._tick_autosave(RanchScript.AUTOSAVE_SECONDS * 2.0)
	assert_signal_not_emitted(ranch._game_state, "state_saved", "in the Palace, the clock waits")


func test_clearing_the_debt_fires_the_hook_after_the_collection_letter() -> void:
	var ranch := _ranch(3.0 * WorldStateScript.CYCLE_SECONDS)
	var gs: Node = ranch._game_state
	gs.ledger.pay(LedgerScript.STARTING_BALANCE)
	for i in LedgerScript.STARTING_QUOTA:
		gs.ledger.credit_delivery(0, true)
	watch_signals(ranch)
	ranch._on_world_changed()
	assert_true(gs.ledger.closed, "paid and the quota met on collection day: closed")
	assert_true(gs.story.has_flag("debt_cleared"), "the story hears about it")
	assert_signal_emitted(ranch, "debt_cleared")
	assert_true(gs.story.has_mail(&"sunny_quota_note"),
		"the first collection-day letter is in the mailbox (item 6)")


func test_paying_off_early_does_not_clear_before_collection_day() -> void:
	var ranch := _ranch(100.0)
	var gs: Node = ranch._game_state
	gs.ledger.pay(LedgerScript.STARTING_BALANCE)
	ranch._on_world_changed()
	assert_false(gs.story.has_flag("debt_cleared"), "not before a collection day")


## P8, playtest 2026-11-08 item 7: rare ponies went up on the dawn cart with nothing on screen.
## The cart takes Bloomed Drifters and nobody else: never a named pony, never a blank.
func test_the_dawn_cart_takes_only_bloomed_drifters() -> void:
	var registry := PonyRegistry.new()
	registry.load_all("res://data/ponies")
	var named := PonyInstance.new()
	named.data_id = &"fluttershy"
	assert_false(RanchScript.cart_takes(named), "a named pony asks before she goes")
	var blank := PonyInstance.new()
	blank.data_id = &"stock_bold"
	blank.stock = {"coat": 0, "mane": 0, "eyes": 0}
	assert_true(blank.is_stock())
	assert_eq(RanchScript.cart_takes(blank), blank.is_marked(),
		"a blank Drifter stays; a Bloomed one goes")
