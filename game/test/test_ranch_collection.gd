extends GutTest
## Regression tests for the collector ladder's persistence guards: game/world/ranch.gd's
## _maybe_run_collection_day() / _maybe_serve_collector() / _seed_collector_state(), and
## Ledger.is_collection_day_due() (game/systems/ledger.gd), which they are built on.
##
## THE BUG THESE PIN. Two runtime only vars on Ranch used to be the guards: a phase change
## drove _maybe_run_collection_day() at most once per cycle through a plain counter that
## reset to -1 on every fresh process, and _collector_due started false on every fresh
## process regardless of what the loaded save's ledger actually had armed. Both agreed
## with a live session and disagreed with a reloaded one: a save written mid cycle came
## back and billed the same period again on the next phase change (upkeep and the service
## charge added twice, the tier escalated twice, delivered_this_period reset a second
## time), and a save written with a punishment already armed came back having lost the
## arming, because nothing ever told the reloaded var about the ledger it just inherited.
##
## WHY THIS DRIVES ranch.gd DIRECTLY AND DETACHED, RATHER THAN THROUGH world/ranch.tscn. A
## full ranch scene boots terrain, a spawner, a player rig and a physics warmup that this
## bug has nothing to do with, and the project's own gates already cover that wiring
## (game/scenes/test/world_test.gd, which already proves a save/reload resumes the same
## hour). What is under test here is arithmetic: given a ledger with a certain
## periods_run or a certain pending_punishment, does a Ranch that has never seen this
## session before make the same call the one that saved would have? Ranch.new() never
## enters a tree, so _ready() never runs and every @onready var the functions under test
## touch stays null -- checked against ranch.gd itself, every one of them is guarded
## before use, except `player`, which is stubbed below. A real GameState
## (game/systems/game_state.gd) is built and saved to disk exactly the way a real load
## would, per the pattern game/test/test_pen.gd's own save/load tests use.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd.

const RanchScript := preload("res://world/ranch.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const LedgerScript := preload("res://systems/ledger.gd")
const SaveIOScript := preload("res://systems/save_io.gd")

## Scratch save slots. NOT slot 0 (the one the game plays in) and NOT slot 9
## (game/world/ranch.gd's own gate probe) -- see game/test/test_pen.gd's SCRATCH_SLOT.
const SLOT_COLLECTION_DAY := 30
const SLOT_PUNISHMENT := 31


## Just enough of a Player to satisfy ranch.gd's `player.get_magic_beam()` call sites
## without dragging in the real player scene (a camera rig, physics, an actual beam) that
## this file has nothing to do with. Every one of those call sites already guards a null
## RETURN from get_magic_beam() (its declared return type is the nullable Node3D); none of
## them guards a null `player` itself, so the stub has to be a real CharacterBody3D rather
## than left null.
class FakePlayer:
	extends CharacterBody3D

	func get_magic_beam() -> Node3D:
		return null


## A detached Ranch: never added to a tree, so _ready() never runs and none of the scene
## it would have built (terrain, spawner, HUD, the real player) exists.
func _ranch() -> RanchScript:
	var ranch: RanchScript = autofree(RanchScript.new())
	var fake_player: FakePlayer = autofree(FakePlayer.new())
	ranch.player = fake_player
	return ranch


func test_reloading_mid_cycle_does_not_bill_the_same_period_twice() -> void:
	# A live session runs collection day for cycle 3 (PERIOD_CYCLES=3, the first
	# collection cycle) and saves immediately after -- the exact "saved mid cycle" moment
	# the bug report describes.
	var writer: Node = autofree(GameStateScript.new())
	var ranch1 := _ranch()
	ranch1._game_state = writer
	ranch1._world = WorldStateScript.new(1, 3.0 * WorldStateScript.CYCLE_SECONDS)
	ranch1._on_world_changed()

	assert_eq(writer.ledger.periods_run, 1, "the live session must have billed period 1")
	var balance_after_billing: int = writer.ledger.balance
	assert_true(writer.save_to_slot(SLOT_COLLECTION_DAY), "the save must land")

	# A FRESH PROCESS loads that save mid cycle...
	var reader: Node = autofree(GameStateScript.new())
	assert_true(reader.load_from_slot(SLOT_COLLECTION_DAY), "...and load back")
	assert_eq(reader.ledger.periods_run, 1, "periods_run itself was always saved correctly")

	# ...and a BRAND NEW Ranch -- its runtime guards starting from nothing, exactly as a
	# fresh process's would -- lives out the rest of cycle 3: an immediate re-check at the
	# same instant (two phase changes in one frame), then DAY, DUSK and NIGHT, all still
	# inside the same collection cycle (PHASE_SECONDS sums to exactly one CYCLE_SECONDS).
	var ranch2 := _ranch()
	ranch2._game_state = reader
	var world2 := WorldStateScript.new(1, 3.0 * WorldStateScript.CYCLE_SECONDS)
	ranch2._world = world2
	ranch2._on_world_changed()
	for offset in [10.0, 200.0, 900.0]:
		world2.set_elapsed(3.0 * WorldStateScript.CYCLE_SECONDS + offset)
		ranch2._on_world_changed()

	assert_eq(reader.ledger.periods_run, 1,
		"a reloaded process must not re-bill a period the save already paid for")
	assert_eq(reader.ledger.balance, balance_after_billing,
		"...and the balance must not move a second time for it either")

	SaveIOScript.delete_slot(SLOT_COLLECTION_DAY)


func test_a_reloaded_pending_punishment_is_served_at_the_next_dawn_exactly_once() -> void:
	# A punishment armed and never yet served -- the "an associate will call at dawn"
	# state -- saved before the dawn that would have served it arrives.
	var writer: Node = autofree(GameStateScript.new())
	writer.ledger.pending_punishment = LedgerScript.Punishment.FEE
	assert_true(writer.save_to_slot(SLOT_PUNISHMENT), "the save must land")

	var reader: Node = autofree(GameStateScript.new())
	assert_true(reader.load_from_slot(SLOT_PUNISHMENT), "...and load back")
	assert_eq(reader.ledger.pending_punishment, LedgerScript.Punishment.FEE,
		"the punishment itself was always saved correctly; that is not the bug")

	# A BRAND NEW Ranch has never had a live session's _maybe_run_collection_day() arm
	# _collector_due -- it starts at that var's own runtime default, false.
	var ranch := _ranch()
	ranch._game_state = reader
	assert_false(ranch._collector_due, "sanity: a fresh Ranch starts with no collector due")
	ranch._seed_collector_state()
	assert_true(ranch._collector_due,
		"a loaded pending punishment must arm the collector, or it is never served")

	# It is not yet dawn: the punishment must wait.
	var world := WorldStateScript.new(1, 0.0)
	world.pin(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	ranch._world = world
	ranch._maybe_serve_collector()
	assert_eq(reader.ledger.pending_punishment, LedgerScript.Punishment.FEE,
		"not dawn yet; nobody has called")

	# Dawn arrives: served, exactly once.
	world.pin(WorldStateScript.Phase.DAWN, WorldStateScript.Weather.CLEAR)
	ranch._maybe_serve_collector()
	assert_eq(reader.ledger.pending_punishment, LedgerScript.Punishment.NONE,
		"the one rung that was due must be served at the dawn that follows the load")
	assert_false(ranch._collector_due, "and the collector is not due again immediately")

	# A second phase change landing on the same dawn (two phase changes in one frame, a
	# pinned clock) must not serve a second rung out of nowhere.
	ranch._maybe_serve_collector()
	assert_eq(reader.ledger.pending_punishment, LedgerScript.Punishment.NONE,
		"nothing pending, so a second dawn call must stay a no-op")

	SaveIOScript.delete_slot(SLOT_PUNISHMENT)


# --- Ruling 8: the letter arrives a whole cycle before the knock ---------------------------

## A COLLECTION DAY ALWAYS LANDS ON A DAWN, which is what made "serve at the next dawn"
## serve at THIS one: Ledger.is_collection_cycle() only answers true at a cycle boundary,
## and a cycle's first phase is DAWN by construction, so ranch._maybe_serve_collector()
## (called out of the same _on_world_changed() as the bill) found the collector armed and
## the phase already right, and the notice and the visit landed in one frame. The player
## never got a period to ship or to pay in, which is the whole point of the notice.
func test_a_collector_armed_today_does_not_call_at_the_dawn_that_armed_him() -> void:
	var state: Node = autofree(GameStateScript.new())
	var ranch := _ranch()
	ranch._game_state = state
	var world: WorldState = WorldStateScript.new(1, 3.0 * WorldStateScript.CYCLE_SECONDS)
	ranch._world = world
	assert_eq(world.cycle_index(), 3, "sanity: three cycles in")
	assert_eq(world.phase(), WorldStateScript.Phase.DAWN,
		"sanity: a collection cycle opens on a dawn, which is the whole difficulty")

	ranch._on_world_changed()
	assert_eq(state.ledger.periods_run, 1, "the period was billed")
	assert_eq(state.ledger.pending_punishment, LedgerScript.Punishment.FEE,
		"an unmet quota arms the first rung")
	assert_eq(state.ledger.pending_punishment_cycle, 3,
		"and the ledger remembers which cycle armed it")
	var billed: int = state.ledger.balance

	ranch._maybe_serve_collector()
	assert_eq(state.ledger.pending_punishment, LedgerScript.Punishment.FEE,
		"nobody calls at the dawn the notice was written on")
	assert_eq(state.ledger.balance, billed,
		"...and nothing is charged for a visit that has not happened")

	# The first dawn of a LATER cycle. Not a collection cycle (4 is not a multiple of 3), so
	# nothing is billed here; the only thing that happens is the knock.
	world.set_elapsed(4.0 * WorldStateScript.CYCLE_SECONDS)
	assert_eq(world.phase(), WorldStateScript.Phase.DAWN, "sanity: a cycle opens on dawn")
	ranch._on_world_changed()
	assert_eq(state.ledger.periods_run, 1, "cycle 4 is not a collection day")
	assert_eq(state.ledger.pending_punishment, LedgerScript.Punishment.NONE,
		"the first dawn of a later cycle is when the associate calls")
	assert_eq(state.ledger.balance, billed + LedgerScript.COLLECTOR_FEE,
		"...and the fee lands then, not a cycle earlier")


## The arming cycle has to survive the save, or a session that quits between the notice and
## the visit comes back and is knocked on immediately.
func test_the_arming_cycle_travels_with_the_save() -> void:
	var writer: Node = autofree(GameStateScript.new())
	writer.ledger.pending_punishment = LedgerScript.Punishment.PEN_PADLOCKED
	writer.ledger.pending_punishment_cycle = 9
	assert_true(writer.save_to_slot(SLOT_PUNISHMENT), "the save must land")

	var reader: Node = autofree(GameStateScript.new())
	assert_true(reader.load_from_slot(SLOT_PUNISHMENT), "...and load back")
	assert_eq(reader.ledger.pending_punishment_cycle, 9,
		"the dawn he may call on is part of the save, like the rung itself")

	var ranch := _ranch()
	ranch._game_state = reader
	ranch._seed_collector_state()
	var world: WorldState = WorldStateScript.new(1, 9.0 * WorldStateScript.CYCLE_SECONDS)
	ranch._world = world
	ranch._maybe_serve_collector()
	assert_eq(reader.ledger.pending_punishment, LedgerScript.Punishment.PEN_PADLOCKED,
		"a reload on the arming cycle's own dawn is still too early")

	world.set_elapsed(10.0 * WorldStateScript.CYCLE_SECONDS)
	ranch._maybe_serve_collector()
	assert_eq(reader.ledger.pending_punishment, LedgerScript.Punishment.NONE,
		"the dawn after it is not")

	SaveIOScript.delete_slot(SLOT_PUNISHMENT)


# --- a rung with nothing to bite on ---------------------------------------------------------

## A player with no permits bought and no pen built is exactly the player early enough in
## the game to be missing quota, and the two middle rungs have nothing to take from her.
## They used to pass silently: the tier had already climbed, the rung was consumed, and the
## period cost her nothing at all. The fee is the rung below and it always lands.
func test_a_permit_rung_with_no_permit_open_falls_back_to_the_fee() -> void:
	var state: Node = autofree(GameStateScript.new())
	var ranch := _ranch()
	ranch._game_state = state
	ranch._world = WorldStateScript.new(1, 0.0)
	state.ledger.pending_punishment = LedgerScript.Punishment.PERMIT_REVOKED
	var before: int = state.ledger.balance

	assert_eq(ranch.serve_collector(), LedgerScript.Punishment.FEE,
		"with no permit to review, the rung below is what is actually served")
	assert_eq(state.ledger.balance, before + LedgerScript.COLLECTOR_FEE,
		"...and it lands on the balance, there being no wallet on a detached ranch")
	assert_true(state.ledger.revoked_permits.is_empty(),
		"nothing was revoked, because there was nothing to revoke")


func test_a_padlock_rung_with_no_pen_built_falls_back_to_the_fee() -> void:
	var state: Node = autofree(GameStateScript.new())
	var ranch := _ranch()
	ranch._game_state = state
	ranch._world = WorldStateScript.new(1, 0.0)
	state.ledger.pending_punishment = LedgerScript.Punishment.PEN_PADLOCKED
	var before: int = state.ledger.balance

	assert_eq(ranch.serve_collector(), LedgerScript.Punishment.FEE,
		"with no pen to seal, the rung below is what is actually served")
	assert_eq(state.ledger.balance, before + LedgerScript.COLLECTOR_FEE)
	assert_true(state.ledger.padlocked_slots.is_empty(),
		"and no slot id was recorded for a padlock that never happened")
