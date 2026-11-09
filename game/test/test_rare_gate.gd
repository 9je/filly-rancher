extends GutTest
## WHO SHOWS UP, AND WHEN (game/systems/rare_gate.gd; playtest 2026-11-08 items 6, 12, 13;
## idea C1): rares keep hours and weather, some wait for a decoration, a new legendary comes
## at most once a day, and Tumble's sightings are one or two a day.

const RareGateScript := preload("res://systems/rare_gate.gd")
const WorldStateScript := preload("res://systems/world_state.gd")


func _legend() -> PonyData:
	var d := PonyData.new()
	d.id = &"testlegend"
	d.rarity = PonyData.Rarity.LEGENDARY
	return d


func test_one_new_legendary_a_day() -> void:
	var d := _legend()
	assert_true(RareGateScript.allowed(d, [], -1, 4), "none caught yet: she may come")
	assert_false(RareGateScript.allowed(d, [], 4, 4), "a new legendary already came today")
	assert_true(RareGateScript.allowed(d, [], 3, 4), "tomorrow is another day")
	assert_true(RareGateScript.allowed(d, [], 4, 4, true), "a known face is not a new one")


func test_a_decoration_brings_her() -> void:
	var fluttershy: PonyData = load("res://data/ponies/fluttershy.tres")
	assert_eq(fluttershy.needs_decor, &"flower_bushes", "Fluttershy waits for the flowers (C1)")
	assert_false(RareGateScript.allowed(fluttershy, [], -1, 0))
	assert_true(RareGateScript.allowed(fluttershy, ["flower_bushes"], -1, 0))


func test_the_mane_cast_keep_hours_or_wait_for_something() -> void:
	# Item 6: every legendary and the debt in one in-game day. Each of these now has a gate.
	for id in ["rainbowdash", "twilight", "rarity", "starlightglimmer", "fluttershy",
			"pinkiepie", "applejack"]:
		var d: PonyData = load("res://data/ponies/%s.tres" % id)
		var gated := not d.phases.is_empty() or not d.weathers.is_empty() or d.needs_decor != &""
		assert_true(gated, "%s keeps hours, weather or a decoration" % id)
	var dash: PonyData = load("res://data/ponies/rainbowdash.tres")
	assert_false(dash.available(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR),
		"Rainbow Dash is out after the rain, not on a clear day")
	assert_true(dash.available(WorldStateScript.Phase.DAY, WorldStateScript.Weather.RAIN))


func test_sightings_are_one_or_two_a_day_and_spaced() -> void:
	assert_false(RareGateScript.sighting_due(0, -INF, 60.0), "not in the first minutes")
	assert_true(RareGateScript.sighting_due(0, -INF, RareGateScript.SIGHTING_FIRST))
	var t := RareGateScript.SIGHTING_FIRST + 10.0
	assert_false(RareGateScript.sighting_due(1, t, t + 60.0), "not straight after the last")
	assert_true(RareGateScript.sighting_due(1, t, t + RareGateScript.SIGHTING_GAP))
	assert_false(RareGateScript.sighting_due(2, t, t + 3600.0), "two is the day's lot")
	assert_lte(RareGateScript.SIGHTINGS_PER_DAY, 2)
