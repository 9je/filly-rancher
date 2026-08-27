extends GutTest
## Tests for gem production (game/systems/production.gd) -- Phase 1B Task 5's pure-logic
## half. World-facing spawning of an actual gem pickup happens in game/world/pen.gd (a
## different task); this file only pins the numbers: how fast a pony's happiness turns
## into gems, and that a starving pony makes none at all.
##
## WHY THERE IS AN ACCUMULATOR AND WHY IT LIVES HERE, NOT ON PonyInstance. A frame's delta
## is a fraction of a second; at any sane production rate most single ticks would produce
## zero whole gems if progress were not remembered between calls, and "gems accumulate
## correctly over compressed time" (the plan's own requirement) would be false. The
## natural home for that running total is PonyInstance, but this task does not own that
## file -- Task 1 does, and Task 4 (needs.gd, built concurrently on another branch) is
## also actively shaping it. So Production keeps its own {uid: leftover_progress}
## ledger, keyed by the pony's uid (never by data_id -- see pony_instance.gd's own
## footgun comment on why uids and not character ids are the right key for anything
## per-individual). Production.tick() stays a pure function of
## (inst.uid, inst.happiness, inst.hunger, delta) plus that ledger, so identical input
## sequences produce identical output sequences -- see
## test_production_is_deterministic_given_the_same_inputs below.
##
## Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const ProductionScript := preload("res://systems/production.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")

const HAPPY := 1.0
const UNHAPPY := 0.1
const NOT_HUNGRY := 0.0


func after_each() -> void:
	# The progress ledger is process-wide (see the class comment above); a test that fed
	# it must not leak leftover progress into the next one that reuses a uid.
	ProductionScript.clear_all_progress()


func _pony(happiness: float, hunger: float) -> PonyInstance:
	var inst := PonyInstanceScript.create(&"twilight")
	inst.happiness = happiness
	inst.hunger = hunger
	return inst


# --- happiness scales the rate -------------------------------------------------------

func test_a_happy_pony_produces_more_over_the_same_stretch_of_time() -> void:
	var happy := _pony(HAPPY, NOT_HUNGRY)
	var sad := _pony(UNHAPPY, NOT_HUNGRY)

	var happy_total := 0
	var sad_total := 0
	# Compressed time: simulate five real minutes in one-second steps.
	for i in range(300):
		happy_total += ProductionScript.tick(happy, 1.0)
		sad_total += ProductionScript.tick(sad, 1.0)

	assert_gt(happy_total, sad_total,
		"a happy pony must produce strictly more gems than an unhappy one over the same time")
	assert_gt(happy_total, 0, "and the happy pony must actually have produced something")


func test_a_fully_happy_pony_produces_about_one_gem_per_tuned_period() -> void:
	# Pins the tuning itself (see production.gd's PRODUCTION_PERIOD_SECONDS doc and the
	# report): at happiness 1.0, one gem roughly every PRODUCTION_PERIOD_SECONDS of
	# real, unhungry time.
	var happy := _pony(HAPPY, NOT_HUNGRY)
	var total := 0
	var period: float = ProductionScript.PRODUCTION_PERIOD_SECONDS
	var steps := int(round(period)) * 3
	for i in range(steps):
		total += ProductionScript.tick(happy, 1.0)
	assert_almost_eq(total, 3, 1,
		"three tuned periods of full happiness should yield about three gems")


# --- starvation gates production entirely --------------------------------------------

func test_a_starving_pony_produces_nothing_no_matter_how_happy() -> void:
	var starving := _pony(HAPPY, PonyInstanceScript.STATE_MAX)
	var total := 0
	for i in range(300):
		total += ProductionScript.tick(starving, 1.0)
	assert_eq(total, 0, "starving zeroes production even at maximum happiness")


func test_a_pony_just_below_the_starving_threshold_still_produces() -> void:
	var barely_fed := _pony(HAPPY, ProductionScript.STARVING_HUNGER_THRESHOLD - 0.01)
	var total := 0
	for i in range(300):
		total += ProductionScript.tick(barely_fed, 1.0)
	assert_gt(total, 0, "hunger just under the threshold must not zero production")


# --- determinism -----------------------------------------------------------------------

func test_production_is_deterministic_given_the_same_inputs() -> void:
	var a := _pony(0.7, 0.2)
	var b := _pony(0.7, 0.2)

	var a_total := 0
	var b_total := 0
	for i in range(150):
		a_total += ProductionScript.tick(a, 0.5)
		b_total += ProductionScript.tick(b, 0.5)

	assert_eq(a_total, b_total,
		"two ponies with identical happiness/hunger fed the identical tick sequence " +
		"must produce the identical number of gems")


func test_replaying_the_same_tick_sequence_on_a_reset_ledger_reproduces_the_same_total() -> void:
	var inst := _pony(0.9, 0.0)
	var first_run := 0
	for i in range(100):
		first_run += ProductionScript.tick(inst, 0.3)

	ProductionScript.reset_progress(inst.uid)
	var second_run := 0
	for i in range(100):
		second_run += ProductionScript.tick(inst, 0.3)

	assert_eq(first_run, second_run, "resetting the ledger and replaying must reproduce the total")


# --- accumulation over compressed time --------------------------------------------------

func test_gems_accumulate_correctly_over_compressed_time() -> void:
	# One long tick and many short ticks covering the same total elapsed time must land
	# on the same whole-gem count (up to the one-gem rounding a ledger can differ by
	# depending on exactly where the boundary falls) -- this is what "accumulate
	# correctly" means: no lost fractions, no double-counting.
	var period: float = ProductionScript.PRODUCTION_PERIOD_SECONDS
	var long_tick_inst := _pony(HAPPY, NOT_HUNGRY)
	var long_total := ProductionScript.tick(long_tick_inst, period * 10.0)

	var short_tick_inst := _pony(HAPPY, NOT_HUNGRY)
	var short_total := 0
	for i in range(int(period * 10.0 * 10)):
		short_total += ProductionScript.tick(short_tick_inst, 0.1)

	assert_almost_eq(long_total, short_total, 1,
		"ten tuned periods must yield about ten gems whether ticked coarsely or finely")
	assert_eq(long_total, 10, "one long tick spanning exactly ten periods yields exactly ten")


func test_many_zero_gem_ticks_still_bank_progress_toward_the_next_gem() -> void:
	var inst := _pony(HAPPY, NOT_HUNGRY)
	var period: float = ProductionScript.PRODUCTION_PERIOD_SECONDS
	var saw_a_gem := false
	# Small steps well under one gem's worth each; most return 0, but progress must be
	# banked so a gem eventually lands.
	var step := period / 37.0
	for i in range(200):
		if ProductionScript.tick(inst, step) > 0:
			saw_a_gem = true
			break
	assert_true(saw_a_gem, "fractional progress must be remembered between ticks, not discarded")


# --- independence between ponies ---------------------------------------------------------

func test_two_different_ponies_do_not_share_progress() -> void:
	var a := _pony(HAPPY, NOT_HUNGRY)
	var b := _pony(HAPPY, NOT_HUNGRY)
	var period: float = ProductionScript.PRODUCTION_PERIOD_SECONDS

	# Push A most of the way to a gem; B must be unaffected.
	ProductionScript.tick(a, period * 0.9)
	var b_result := ProductionScript.tick(b, 0.001)
	assert_eq(b_result, 0, "a fresh pony must not inherit another pony's banked progress")


# --- input hygiene ------------------------------------------------------------------------

func test_zero_or_negative_delta_produces_nothing_and_does_not_corrupt_the_ledger() -> void:
	var inst := _pony(HAPPY, NOT_HUNGRY)
	assert_eq(ProductionScript.tick(inst, 0.0), 0)
	assert_eq(ProductionScript.tick(inst, -5.0), 0, "negative delta must be refused, not banked as debt")

	# Ledger must still behave normally afterwards.
	var period: float = ProductionScript.PRODUCTION_PERIOD_SECONDS
	assert_eq(ProductionScript.tick(inst, period), 1, "a clean tick afterwards still works")
