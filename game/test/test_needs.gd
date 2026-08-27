extends GutTest
## Tests for the hunger/happiness rules (game/systems/needs.gd) -- the pure-logic half of
## Phase 1B Task 4. The world-facing half (gardens, feeding-in-the-world, HUD display) is
## a separate task; this file is only about Needs.tick()/Needs.feed() as PURE functions of
## an injected delta and a PonyInstance -- no scene, no clock, no randomness, so a headless
## GUT run is the whole story.
##
## THE NUMBERS, AND WHAT THEY MEAN IN REAL TIME (see needs.gd's own header for the same
## table with the reasoning). Restated here because these tests PIN them to literals, the
## same discipline test_pony_instance.gd uses for uid_for() -- a retune must fail a test
## here, not just quietly change behaviour a later task discovers by feel:
##
##   hunger 0 -> 1 (full to starving), never fed:              10 minutes  (600 s)
##   happiness decay only once hunger passes the halfway mark (the "hungry" threshold)
##   a hungry pony (hunger just over threshold), never fed:    ~4 minutes to zero happiness
##   feeding always fully satiates (hunger -> 0) on success
##   feeding a FAVOURITE food:      +0.25 happiness
##   feeding a NEUTRAL (non-favourite) food: +0.10 happiness

const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const FoodRegistryScript := preload("res://systems/food_registry.gd")
const NeedsScript := preload("res://systems/needs.gd")

## Twilight's favourites are daffodil + hay (game/data/ponies/twilight.tres). Apple and
## carrot are foods nobody's favorite_foods list mentions -- see game/data/foods/ -- so
## they are true neutrals, not just "not this pony's favourite by omission".
const KNOWN_ID := &"twilight"
const FAVORITE_FOOD := &"daffodil"
const NEUTRAL_FOOD := &"apple"
const UNKNOWN_FOOD := &"not_a_real_food_at_all"


func before_each() -> void:
	# Each test gets a freshly-caught pony: HAPPINESS_DEFAULT/HUNGER_DEFAULT from
	# pony_instance.gd, not whatever the previous test left behind.
	pass


func after_each() -> void:
	# Needs' food registry is a process-wide static (mirroring PonyInstance's pony
	# registry) -- a test that injects its own must not leak it into the next one.
	NeedsScript.set_food_registry(null)


func _fresh_pony() -> PonyInstance:
	return PonyInstanceScript.create(KNOWN_ID)


# --- hunger rises over time ---------------------------------------------------------

func test_hunger_rises_over_time() -> void:
	var inst := _fresh_pony()
	var before := inst.hunger
	NeedsScript.tick(inst, 10.0)
	assert_gt(inst.hunger, before, "hunger must rise after time passes with no feeding")


func test_hunger_rise_is_a_pure_linear_function_of_delta() -> void:
	# Pinned to a literal so a retune is a deliberate, visible change to this test, the
	# same discipline test_pony_instance.gd uses for uid_for().
	var inst := _fresh_pony()
	inst.hunger = 0.0
	NeedsScript.tick(inst, 60.0)
	assert_almost_eq(inst.hunger, 60.0 / 600.0, 0.0001,
		"60s of un-fed time should be exactly 60/600 of the way to starving")


func test_two_half_ticks_equal_one_whole_tick() -> void:
	# Determinism: the same total elapsed time must produce the same result whether it
	# arrives in one tick or several -- Task 5's production timers will call tick() once
	# per frame, not once per test-convenient chunk.
	var whole := _fresh_pony()
	NeedsScript.tick(whole, 10.0)

	var halved := _fresh_pony()
	NeedsScript.tick(halved, 5.0)
	NeedsScript.tick(halved, 5.0)

	assert_almost_eq(whole.hunger, halved.hunger, 0.0001,
		"tick() must be linear in delta, not path-dependent")


func test_hunger_clamps_at_max_and_never_exceeds_it() -> void:
	var inst := _fresh_pony()
	NeedsScript.tick(inst, 1.0e9)  # absurdly long, uninterrupted neglect
	assert_almost_eq(inst.hunger, PonyInstanceScript.STATE_MAX, 0.0001,
		"hunger must clamp at STATE_MAX, not sail past it")


func test_hunger_never_goes_negative() -> void:
	var inst := _fresh_pony()
	inst.hunger = 0.0
	NeedsScript.tick(inst, 0.001)
	assert_true(inst.hunger >= PonyInstanceScript.STATE_MIN, "hunger must never go negative")


func test_tick_with_zero_or_negative_delta_changes_nothing() -> void:
	var inst := _fresh_pony()
	inst.hunger = 0.3
	inst.happiness = 0.6
	NeedsScript.tick(inst, 0.0)
	NeedsScript.tick(inst, -5.0)
	assert_almost_eq(inst.hunger, 0.3, 0.0001, "a zero/negative delta must not move hunger")
	assert_almost_eq(inst.happiness, 0.6, 0.0001, "...nor happiness")


func test_tick_with_a_null_instance_does_not_crash() -> void:
	NeedsScript.tick(null, 10.0)  # must simply not crash
	assert_true(true)


# --- happiness decays while hungry ---------------------------------------------------

func test_happiness_does_not_decay_while_well_fed() -> void:
	var inst := _fresh_pony()
	inst.hunger = 0.1  # well under the "hungry" threshold
	var before := inst.happiness
	NeedsScript.tick(inst, 60.0)
	assert_almost_eq(inst.happiness, before, 0.0001,
		"a pony who is not hungry must not lose happiness just from time passing")


func test_happiness_decays_while_hungry() -> void:
	var inst := _fresh_pony()
	inst.hunger = 0.9  # well past the hungry threshold
	var before := inst.happiness
	NeedsScript.tick(inst, 60.0)
	assert_lt(inst.happiness, before, "happiness must fall while the pony is hungry")


func test_happiness_decay_rate_is_pinned() -> void:
	var inst := _fresh_pony()
	inst.hunger = 0.9
	inst.happiness = 1.0
	NeedsScript.tick(inst, 60.0)
	assert_almost_eq(inst.happiness, 1.0 - (60.0 / 240.0), 0.0001,
		"a hungry pony loses happiness at 1/240 per second (zero to full unhappy in 4 min)")


func test_happiness_clamps_at_min_and_never_goes_negative() -> void:
	var inst := _fresh_pony()
	inst.hunger = 1.0
	inst.happiness = 0.05
	NeedsScript.tick(inst, 1.0e6)
	assert_almost_eq(inst.happiness, PonyInstanceScript.STATE_MIN, 0.0001,
		"happiness must clamp at STATE_MIN, never go negative")


func test_happiness_clamps_at_max_and_never_exceeds_it() -> void:
	var inst := _fresh_pony()
	inst.hunger = 0.0
	inst.happiness = PonyInstanceScript.STATE_MAX
	# A small delta, deliberately -- large enough to prove nothing nudges happiness, but
	# small enough that hunger itself stays under HUNGRY_THRESHOLD (a huge delta would
	# ALSO push hunger past the threshold in this same tick and correctly trigger decay,
	# which would defeat the "no hunger pressure" premise of this test).
	NeedsScript.tick(inst, 1.0)
	assert_almost_eq(inst.happiness, PonyInstanceScript.STATE_MAX, 0.0001,
		"happiness must clamp at STATE_MAX, never exceed it, even with no hunger pressure")


# --- feeding ---------------------------------------------------------------------------

func test_feeding_lowers_hunger() -> void:
	var inst := _fresh_pony()
	inst.hunger = 0.8
	var ok := NeedsScript.feed(inst, FAVORITE_FOOD)
	assert_true(ok, "feeding a real food must succeed")
	assert_lt(inst.hunger, 0.8, "hunger must fall after feeding")


func test_feeding_fully_satiates() -> void:
	# The chosen pacing: one feeding always fully resets hunger, so "how often do I need
	# to feed her" reduces to hunger's own 600s fill time -- see needs.gd's header.
	var inst := _fresh_pony()
	inst.hunger = 0.8
	NeedsScript.feed(inst, FAVORITE_FOOD)
	assert_almost_eq(inst.hunger, PonyInstanceScript.STATE_MIN, 0.0001,
		"a successful feeding fully satiates -- hunger goes to STATE_MIN")


func test_feeding_an_unknown_food_fails_and_changes_nothing() -> void:
	var inst := _fresh_pony()
	inst.hunger = 0.8
	inst.happiness = 0.4
	var ok := NeedsScript.feed(inst, UNKNOWN_FOOD)
	assert_false(ok, "an id with no matching FoodData must be refused")
	assert_almost_eq(inst.hunger, 0.8, 0.0001, "a refused feed must not touch hunger")
	assert_almost_eq(inst.happiness, 0.4, 0.0001, "...nor happiness")


func test_feeding_a_null_instance_fails_without_crashing() -> void:
	assert_false(NeedsScript.feed(null, FAVORITE_FOOD))


func test_favorite_food_raises_happiness_more_than_neutral_food() -> void:
	# THE case Task 4's spec calls out by name: PonyData.favorite_foods already exists
	# and is populated (game/data/ponies/twilight.tres: daffodil + hay).
	var favored := _fresh_pony()
	favored.happiness = 0.5
	NeedsScript.feed(favored, FAVORITE_FOOD)

	var neutral := _fresh_pony()
	neutral.happiness = 0.5
	NeedsScript.feed(neutral, NEUTRAL_FOOD)

	assert_gt(favored.happiness, neutral.happiness,
		"a favourite food must give a bigger happiness bump than a neutral one")


func test_favorite_and_neutral_happiness_bonuses_are_pinned() -> void:
	var favored := _fresh_pony()
	favored.happiness = 0.5
	NeedsScript.feed(favored, FAVORITE_FOOD)
	assert_almost_eq(favored.happiness, 0.5 + 0.25, 0.0001,
		"a favourite food is worth +0.25 happiness")

	var neutral := _fresh_pony()
	neutral.happiness = 0.5
	NeedsScript.feed(neutral, NEUTRAL_FOOD)
	assert_almost_eq(neutral.happiness, 0.5 + 0.10, 0.0001,
		"a neutral food is worth +0.10 happiness")


func test_feeding_happiness_bonus_clamps_at_max() -> void:
	var inst := _fresh_pony()
	inst.happiness = 0.95
	NeedsScript.feed(inst, FAVORITE_FOOD)
	assert_almost_eq(inst.happiness, PonyInstanceScript.STATE_MAX, 0.0001,
		"a happiness bump must clamp at STATE_MAX, not sail past it")


func test_is_favorite_reads_the_ponys_own_character_record() -> void:
	var inst := _fresh_pony()
	assert_true(NeedsScript.is_favorite(inst, &"daffodil"), "daffodil is Twilight's favourite")
	assert_true(NeedsScript.is_favorite(inst, &"hay"), "hay is Twilight's favourite too")
	assert_false(NeedsScript.is_favorite(inst, NEUTRAL_FOOD), "apple is nobody's favourite")
	assert_false(NeedsScript.is_favorite(null, &"hay"), "a null instance has no favourites")


# --- food registry injection (mirrors PonyInstance's registry injection pattern) -------

func test_the_food_registry_can_be_injected_so_a_caller_is_not_forced_to_hit_the_disk() -> void:
	var registry := FoodRegistryScript.new()
	registry.load_all("res://data/foods")
	NeedsScript.set_food_registry(registry)
	assert_eq(NeedsScript.get_food_registry(), registry,
		"an injected registry is the one that gets used")
	assert_not_null(NeedsScript.resolve_food(&"hay"))
