extends GutTest
## SPIKE HAS A JOB (PT8; playtest 2026-11-05: "why does spike just sit there"). E at Spike asks
## him for the most useful thing to know right now (systems/spike_tips.gd), most urgent first.

const SpikeTipsScript := preload("res://systems/spike_tips.gd")


func test_hungry_ponies_and_an_empty_pantry_come_first() -> void:
	var tip: String = SpikeTipsScript.pick({"hungry": 2, "pantry": 0, "escapee": "Scootaloo"}, 0)
	assert_string_contains(tip, "Market")
	assert_string_contains(tip, "on their own", "and says feeding is automatic (item 64)")


func test_an_escape_artist_in_a_paddock_is_named() -> void:
	var tip: String = SpikeTipsScript.pick({"escapee": "Scootaloo"}, 0)
	assert_string_contains(tip, "Scootaloo")
	assert_string_contains(tip, "Big Pen")


func test_only_drifters_bloom_when_that_is_what_she_is_stuck_on() -> void:
	var tip: String = SpikeTipsScript.pick({"bloom_goal": true, "drifters": 0}, 0)
	assert_string_contains(tip, "Drifter")


func test_a_rare_she_has_not_seen_says_when_to_look() -> void:
	var tip: String = SpikeTipsScript.pick({"rare_hint": {"region": "The Lake", "when": "at night"}}, 0)
	assert_string_contains(tip, "The Lake")
	assert_string_contains(tip, "at night")


func test_with_nothing_urgent_he_still_has_something_to_say() -> void:
	var a: String = SpikeTipsScript.pick({}, 0)
	var b: String = SpikeTipsScript.pick({}, 1)
	assert_false(a.is_empty())
	assert_ne(a, b, "asking again gets a different tip")


func test_no_tip_carries_an_em_dash() -> void:
	for i in 12:
		assert_false(SpikeTipsScript.pick({}, i).contains("—"))
