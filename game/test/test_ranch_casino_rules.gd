extends GutTest
## THE FOUR HOUSE RULES THE WHOLE BRANCH REVIEW ASKED FOR, all of them about the same thing:
## a bet is a promise, and the Palace may not quietly get out of one.
##
##   NO SILENT FORFEIT. The stake leaves the purse the instant a race starts and only
##   _on_race_finished() ever puts it back, so a session that ended in between (the window's
##   close button, the tree tearing down, a save written mid race) left the chips simply
##   gone. refund_open_race() is the way back, and save_game() refuses outright rather than
##   writing a file that cannot describe a running bet.
##
##   SHE IS NOT DELIVERABLE WHILE SHE IS RUNNING. The Depot would have credited the account
##   for a pony the wire was about to pay out on and freed her out from under the unhide at
##   the end of the race.
##
##   THE BAN CLOSES WHAT IS OPEN. casino_can_enter() guarded only the door, so a ban landing
##   while the player sat at a table left her at the table.
##
##   THE BET SETTLES AGAINST THE FIELD SHE WAS SHOWN. The card was priced once for the panel
##   and then built a second time at confirm, and a pony fed between the two came back with
##   different odds than the ones on screen.
##
## WHY A DETACHED RANCH, RATHER THAN world/ranch.tscn: see test_ranch_race.gd's class
## comment, whose harness this file borrows outright, down to the stand in pen body.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd.

const RanchScript := preload("res://world/ranch.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const PenScript := preload("res://world/pen.gd")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const RaceCardScript := preload("res://systems/race_card.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")

const STARTING_CHIPS := 500
const STAKE := 50

## The finish order a settled race hands back, winner first. Lane 0 is the player's, so this
## is a card her own pony won; the arithmetic under test is the bookkeeping either way.
const WINNING_ORDER: Array = [0, 1, 2, 3, 4, 5]


## A track that agrees to start every race and never runs a clock, so a test can stand a bet
## on it and then do something else. `running` is what is_running() answers, and it is a
## field rather than a constant so one object can play both "a race is on" and "the track is
## idle" inside one test.
class FakeTrack:
	extends Node3D

	var running := false

	func is_running() -> bool:
		return running

	func dress(_field: Array) -> int:
		return 6

	func start(_field: Array, _result: Dictionary) -> bool:
		running = true
		return true


## Somewhere for _toast() to land. ranch.gd looks its HUD up by node name, so this only has
## to be called "HUD" and answer toast().
class ToastSpy:
	extends Node

	var said: Array[String] = []

	func toast(text: String) -> void:
		said.append(text)


## A menu with nothing in it but a door. Enough for enforce_casino_ban(), which asks only
## is_open() and close().
class StubMenu:
	extends CanvasLayer

	var open_now := true

	func is_open() -> bool:
		return open_now

	func close() -> void:
		open_now = false


## A GameState that records a save instead of writing one. save_game() must be observable
## without any test in this suite ever putting a file in the player's own slot 0.
class SpyState:
	extends GameStateScript

	var saves := 0

	func save_to_slot(slot: int = DEFAULT_SLOT) -> bool:
		saves += 1
		return slot >= 0


## A ranch that the Palace has thrown out. THE WHOLE OF THE RESISTANCE SLICE'S BAN, as the
## spec promises it: one overridden function and nothing else touched.
class BannedRanch:
	extends RanchScript

	func casino_can_enter() -> bool:
		return false


var _ranch: RanchScript = null
var _track: FakeTrack = null
var _pen: Pen = null
var _inst: PonyInstance = null
var _body: Node3D = null
var _hud: ToastSpy = null


## A detached ranch with one pony in one pen and `track` standing in for race_track.
## Everything the calls under test touch before they reach the track is real: a real
## GameState, a real Casino purse, a real Pen found through the same _plot_slots() walk a
## hosted ranch uses.
func _build(ranch: RanchScript, state: Node) -> void:
	_ranch = autofree(ranch)
	_ranch._game_state = autofree(state)
	_ranch._game_state.casino.add_chips(STARTING_CHIPS)
	_track = FakeTrack.new()
	_ranch.race_track = autofree(_track)

	_hud = ToastSpy.new()
	_hud.name = "HUD"
	_ranch.add_child(_hud)

	_pen = autofree(PenScript.new())
	_pen.slot_id = &"slot_1"
	_inst = PonyInstanceScript.create(&"stock_bold")
	assert_true(_pen.add_pony(_inst), "precondition: she must actually be in the pen")
	_body = autofree(Node3D.new())
	_pen._bodies[_inst.uid] = _body

	var slot: PlotSlot = autofree(PlotSlotScript.new())
	slot._built_node = _pen
	var plots_root: Node3D = autofree(Node3D.new())
	plots_root.add_child(slot)
	_ranch.plots_root = plots_root


func before_each() -> void:
	_build(RanchScript.new(), GameStateScript.new())


func _start_a_race() -> Dictionary:
	var result: Dictionary = _ranch.start_race(_inst.uid, STAKE)
	assert_true(bool(result["ok"]), "precondition: the race actually got under way")
	return result


# --- ruling 16: no silent stake forfeit ---------------------------------------------------

func test_a_race_that_never_settles_hands_the_stake_back() -> void:
	_start_a_race()
	assert_eq(_ranch._game_state.casino.chips, STARTING_CHIPS - STAKE,
		"precondition: the stake is out of the purse and on the track")
	assert_false(_body.visible, "precondition: her pen body is hidden for the race")

	assert_eq(_ranch.refund_open_race(), STAKE, "the refund is the whole stake")
	assert_eq(_ranch._game_state.casino.chips, STARTING_CHIPS,
		"a bet nobody settled must leave the purse exactly as it found it")
	assert_true(_body.visible, "and she is standing in her pen again, in plain sight")
	assert_eq(_ranch._race_entrant, &"", "no bet bookkeeping may be left behind")
	assert_eq(_ranch._race_stake, 0)
	assert_true(_ranch._race_field.is_empty())


func test_the_refund_is_idempotent_and_pays_nothing_when_no_bet_is_standing() -> void:
	assert_eq(_ranch.refund_open_race(), 0, "no race, no refund")
	_start_a_race()
	assert_eq(_ranch.refund_open_race(), STAKE)
	assert_eq(_ranch.refund_open_race(), 0,
		"a second shutdown notification must not pay the stake twice")
	assert_eq(_ranch._game_state.casino.chips, STARTING_CHIPS)


func test_a_settled_race_is_not_refunded_on_top_of_what_it_paid() -> void:
	_start_a_race()
	_track.running = false
	_ranch._on_race_finished(WINNING_ORDER, RaceCardScript.PLAYER_LANE)
	var settled: int = _ranch._game_state.casino.chips
	assert_gt(settled, STARTING_CHIPS - STAKE, "sanity: her own lane won and was paid")
	assert_eq(_ranch.refund_open_race(), 0,
		"the wire already put this bet to bed; there is nothing left to refund")
	assert_eq(_ranch._game_state.casino.chips, settled)


func test_the_wire_clears_every_variable_the_bet_lived_in() -> void:
	_ranch.race_entrants()
	_start_a_race()
	_track.running = false
	_ranch._on_race_finished(WINNING_ORDER, RaceCardScript.PLAYER_LANE)
	assert_eq(_ranch._race_entrant, &"")
	assert_eq(_ranch._race_lane, -1)
	assert_eq(_ranch._race_stake, 0)
	assert_true(_ranch._race_field.is_empty(),
		"the field was the one variable the wire used to leave standing")
	assert_true(_ranch._quoted_fields.is_empty(),
		"and the cards every penned pony was priced from go with it")


func test_the_ranch_cannot_be_saved_while_a_race_is_running() -> void:
	var state: SpyState = SpyState.new()
	_build(RanchScript.new(), state)
	_start_a_race()
	assert_false(_ranch.save_game(),
		"a save taken mid race is a save of a bet the file has no way to describe")
	assert_eq(state.saves, 0, "and nothing was written")

	# THE CONTROL. The same call, the same ranch, the only difference being that the track
	# has gone quiet: the refusal must be conditioned on the race and not on anything else.
	_track.running = false
	assert_true(_ranch.save_game(), "an idle track saves exactly as it always did")
	assert_eq(state.saves, 1)


func test_the_pause_menus_save_row_says_why_it_will_not_save() -> void:
	var state: SpyState = SpyState.new()
	_build(RanchScript.new(), state)
	_start_a_race()
	_hud.said.clear()  # start_race() has its own toast; this test is about the next one.
	_ranch._on_pause_save()
	assert_eq(state.saves, 0, "the Save row must not write while they are running")
	assert_eq(_hud.said.size(), 1, "and it must say so rather than failing silently")
	assert_true(_hud.said[0].to_lower().contains("running"),
		"the refusal names the reason: '%s'" % _hud.said[0])


## THE TWO NOTIFICATIONS A SESSION CAN END ON. The window's close button delivers the first
## and every teardown delivers the second, so both refund. (The refund that actually lands in
## the file on the way out is the one in _sync_game_state(), which runs before GameState
## writes; that path needs a live player and a live beam and so belongs to the casino gate
## rather than here. This is the belt to that pair of braces, and it is the path the ruling
## names.)
func test_closing_the_window_mid_race_hands_the_stake_back() -> void:
	_start_a_race()
	_ranch._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_ranch._game_state.casino.chips, STARTING_CHIPS,
		"quitting on a running race must not quietly keep the stake")
	assert_eq(_ranch._race_stake, 0)


func test_a_teardown_mid_race_hands_the_stake_back() -> void:
	_start_a_race()
	_ranch._notification(Node.NOTIFICATION_EXIT_TREE)
	assert_eq(_ranch._game_state.casino.chips, STARTING_CHIPS)
	assert_eq(_ranch._race_stake, 0)


# --- ruling 17: the racing entrant is not deliverable -------------------------------------

func test_the_depot_will_not_take_the_pony_who_is_out_running() -> void:
	_start_a_race()
	assert_true(_ranch.is_racing(_inst.uid), "precondition: she is the one on the track")
	_hud.said.clear()

	var refused: Dictionary = _ranch.deliver_pony(_inst.uid)
	assert_false(bool(refused["ok"]), "the counter must refuse her")
	assert_eq(_hud.said.size(), 1, "and say why")
	assert_true(_hud.said[0].to_lower().contains("palace"),
		"the refusal names the race: '%s'" % _hud.said[0])
	assert_true(_pen.find_pony(_inst.uid) != null, "she is still living in her own pen")
	assert_eq(_ranch._game_state.ledger.shipments, 0, "and nothing was credited for her")

	# THE CONTROL. Once the bet is off the track the racing refusal no longer fires: this
	# same call falls through to the ordinary body check further down (the stand in body is
	# not a Pony), which refuses without saying anything at all.
	_ranch.refund_open_race()
	_hud.said.clear()
	assert_false(bool(_ranch.deliver_pony(_inst.uid)["ok"]))
	assert_eq(_hud.said.size(), 0,
		"a refusal for some other reason must not be wearing the race's toast")


func test_the_depot_rows_skip_her_while_she_runs_and_list_her_again_afterwards() -> void:
	assert_eq(_ranch._penned_rows().size(), 1, "precondition: she is on the Deliver tab")
	_start_a_race()
	assert_eq(_ranch._penned_rows().size(), 0,
		"a row that always refuses is a row that lies; she is off the tab while she runs")
	_track.running = false
	_ranch._on_race_finished(WINNING_ORDER, RaceCardScript.PLAYER_LANE)
	assert_eq(_ranch._penned_rows().size(), 1, "and back on it the moment the wire settles")


# --- ruling 18: the ban closes what is open -----------------------------------------------

func test_a_ban_shuts_every_casino_menu_that_was_already_open() -> void:
	_build(BannedRanch.new(), GameStateScript.new())
	var tables: Array[StubMenu] = []
	for i in 5:
		tables.append(StubMenu.new())
	_ranch.casino_menu = autofree(tables[0])
	_ranch.slots_menu = autofree(tables[1])
	_ranch.wheel_menu = autofree(tables[2])
	_ranch.blackjack_menu = autofree(tables[3])
	_ranch.race_menu = autofree(tables[4])

	assert_true(_ranch.enforce_casino_ban(), "a ban with menus open shuts something")
	for table in tables:
		assert_false(table.open_now, "every casino menu closes when the Palace throws her out")
	assert_false(_ranch.enforce_casino_ban(),
		"and having shut them there is nothing left to shut")


func test_no_ban_leaves_an_open_table_exactly_where_it_was() -> void:
	var table: StubMenu = autofree(StubMenu.new())
	_ranch.slots_menu = table
	assert_false(_ranch.enforce_casino_ban(), "casino_can_enter() says yes in this slice")
	assert_true(table.open_now, "so nothing is shut")


func test_a_banned_palace_will_not_start_a_race_at_all() -> void:
	_build(BannedRanch.new(), GameStateScript.new())
	var result: Dictionary = _ranch.start_race(_inst.uid, STAKE)
	assert_false(bool(result["ok"]), "a barred player does not get to put a horse on the card")
	assert_eq(_ranch._game_state.casino.chips, STARTING_CHIPS, "and is charged nothing for it")
	assert_true(_body.visible, "and her pony never left the pen")


# --- ruling 19: the bet settles against the field she was shown ----------------------------

func test_feeding_her_between_the_price_and_the_confirm_does_not_move_the_odds() -> void:
	_inst.happiness = 0.2
	_ranch.race_entrants()
	var quoted: float = RaceCardScript.decimal_odds(_ranch._quoted_fields[_inst.uid],
		RaceCardScript.PLAYER_LANE)

	# SHE IS FED ON THE WAY TO THE WINDOW. A pen is a short walk from the Palace door, and
	# happiness is a fifth of her form either way, so this genuinely reprices the card.
	_inst.happiness = 1.0
	var rebuilt: Array[Dictionary] = RaceCardScript.build_field(
		RaceCardScript.entrant_from(_inst), CompanyRunnersScript.load_shipped())
	var if_repriced: float = RaceCardScript.decimal_odds(rebuilt, RaceCardScript.PLAYER_LANE)
	assert_true(absf(if_repriced - quoted) > 0.05,
		"sanity: feeding her really does move the price, %.3f against %.3f"
			% [if_repriced, quoted])

	var result: Dictionary = _start_a_race()
	assert_almost_eq(float(result["odds"]), quoted, 1e-6,
		"the bet settles at the price on the panel she was looking at")


func test_a_pony_who_was_never_priced_is_priced_now() -> void:
	# The form guide was never opened, so _quoted_fields has no entry for her at all. There
	# is no shown field to honour, so the card is built from the pony as she stands.
	assert_true(_ranch._quoted_fields.is_empty(), "precondition: nobody has been priced yet")
	_inst.happiness = 1.0
	var fresh: Array[Dictionary] = RaceCardScript.build_field(
		RaceCardScript.entrant_from(_inst), CompanyRunnersScript.load_shipped())
	var result: Dictionary = _start_a_race()
	assert_almost_eq(float(result["odds"]),
		RaceCardScript.decimal_odds(fresh, RaceCardScript.PLAYER_LANE), 1e-6,
		"an unquoted uid builds its own card rather than settling against nothing")
