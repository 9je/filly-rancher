extends GutTest
## THE ONE THING THE STORY WANTS FROM HER NOW (game/systems/objective.gd). Owner playtest
## 2026-10-25: "idk what to do anymore". The guide spoke only for the first lessons and for
## chores waiting on her; mid-game nothing said what the main path wanted. Objective names
## it for every stage of STORY.md, and nothing for a state it does not know.

const ObjectiveScript := preload("res://systems/objective.gd")


func _s(over: Dictionary = {}) -> Dictionary:
	var s := {"chapter": 0, "path": "", "ending": "", "flags": [] as Array,
		"deliveries": 0, "blooms": 0, "pens": 0, "bag": 0, "pylons": 0, "contract": {}}
	s.merge(over, true)
	return s


func _goal(over: Dictionary) -> StringName:
	return StringName(ObjectiveScript.current(_s(over)).get("goal", &"none"))


func _words(over: Dictionary) -> String:
	return String(ObjectiveScript.current(_s(over)).get("words", ""))


func test_act_one_walks_her_through_the_first_steps() -> void:
	assert_eq(_goal({}), &"marigold", "before the Scoop: Marigold")
	assert_eq(_goal({"flags": ["has_scoop"]}), &"catch", "the Scoop: catch first, as the guide's ring does")
	assert_eq(_goal({"flags": ["has_scoop", "met_fennel"]}), &"pens", "Fennel showed her the pens: build one")
	assert_eq(_goal({"flags": ["has_scoop", "met_fennel"], "pens": 1}), &"catch", "a pen: catch for it")
	assert_eq(_goal({"flags": ["has_scoop", "met_fennel"], "pens": 1, "bag": 2}), &"pens", "ponies in the bag: pen them")


func test_after_the_depot_the_way_is_deliveries_then_blooms() -> void:
	var f := ["has_scoop", "depot_explained"]
	assert_eq(_goal({"flags": f, "pens": 1, "deliveries": 2}), &"depot")
	assert_string_contains(_words({"flags": f, "pens": 1, "deliveries": 2}), "2/6")
	assert_eq(_goal({"chapter": 1, "flags": f, "pens": 2, "deliveries": 6, "blooms": 1}), &"bloom", "the pen with a Drifter (item 53)")
	assert_string_contains(_words({"chapter": 1, "flags": f, "pens": 2, "deliveries": 6, "blooms": 1}), "1/2")


func test_a_bloom_needs_a_penned_drifter_and_the_card_says_so() -> void:
	# PT3 (playtest 2026-11-05 item 53): every Drifter delivered, only named ponies kept, and
	# the card sent her to the pens for a Bloom that could never come. Only a Drifter Blooms.
	var f := ["has_scoop", "depot_explained"]
	var st := {"chapter": 1, "flags": f, "pens": 2, "deliveries": 6, "blooms": 0}
	st["drifters"] = 0
	assert_eq(_goal(st), &"drifter", "no Drifter penned: go and catch one (a Drifter, item 53)")
	assert_string_contains(_words(st), "Drifter")
	st["drifters"] = 1
	assert_eq(_goal(st), &"bloom", "a Drifter penned: her pen, not a pen with room (item 53)")
	assert_string_contains(_words(st), "Drifter")


func test_the_invitation_then_color_day_then_the_lift() -> void:
	var f := ["has_scoop", "depot_explained", "invited"]
	assert_eq(_goal({"chapter": 1, "flags": f}), &"", "Color Day comes at dawn: no place to go")
	assert_false(_words({"chapter": 1, "flags": f}).is_empty(), "but it still says so")
	assert_eq(_goal({"chapter": 2, "flags": f + ["color_day"]}), &"marigold",
		"the trail leads to Marigold herself, not the Depot she stands at (2026-11-08 item 17)")


func test_the_factory_path_is_the_contract_then_the_jubilee() -> void:
	var f := ["has_scoop", "depot_explained", "invited", "color_day", "reveal_done"]
	var c := {"want": 4, "kind": "pastel", "got": 1}
	assert_eq(_goal({"chapter": 3, "path": "factory", "flags": f, "contract": c}), &"depot")
	assert_string_contains(_words({"chapter": 3, "path": "factory", "flags": f, "contract": c}), "1/4")
	assert_eq(_goal({"chapter": 3, "path": "factory", "flags": f + ["jubilee_ready"]}), &"marigold")


func test_the_rescue_path_is_static_then_the_pylons() -> void:
	var f := ["has_scoop", "depot_explained", "invited", "color_day", "reveal_done"]
	assert_eq(_goal({"chapter": 4, "path": "rescue", "flags": f}), &"static")
	assert_string_contains(_words({"chapter": 4, "path": "rescue", "flags": f + ["static_met"], "pylons": 1}), "1/4")
	assert_eq(_goal({"chapter": 4, "path": "rescue", "flags": f + ["static_met"], "pylons": 4}), &"static")


func test_an_ending_or_a_state_it_does_not_know_shows_nothing() -> void:
	assert_true(ObjectiveScript.current(_s({"ending": "placement"})).is_empty())
	assert_true(ObjectiveScript.current(_s({"chapter": 3, "path": "nonsense",
		"flags": ["has_scoop", "reveal_done"]})).is_empty())
	assert_true(ObjectiveScript.current({}).is_empty(), "an empty state from an old save")


func test_every_objective_is_a_few_words_with_an_icon() -> void:
	var states := [{}, {"flags": ["has_scoop"]}, {"flags": ["has_scoop", "depot_explained"], "pens": 1},
		{"chapter": 1, "flags": ["has_scoop", "depot_explained", "invited"]}]
	for st: Dictionary in states:
		var o: Dictionary = ObjectiveScript.current(_s(st))
		var n := String(o.words).split(" ", false).size()
		assert_between(n, 2, 6, "'%s'" % o.words)
		assert_true(o.has("icon"))


func test_the_card_names_what_the_ring_points_at() -> void:
	# One goal on screen at a time: a chore the guide points at (a letter, news, a full bag,
	# gems to sell) is named on the card too, and with no chore the card is the story's step.
	var story := ObjectiveScript.current(_s({"flags": ["has_scoop", "depot_explained"], "pens": 1}))
	assert_eq(ObjectiveScript.for_guide(&"mail", story).goal, &"mail")
	assert_eq(ObjectiveScript.for_guide(&"talk", story).goal, &"talk")
	assert_eq(ObjectiveScript.for_guide(&"market", story).goal, &"market")
	assert_eq(ObjectiveScript.for_guide(&"pens", story).goal, &"pens")
	assert_eq(ObjectiveScript.for_guide(&"depot", story), story, "the ring on the story's place: the story's words")
	assert_eq(ObjectiveScript.for_guide(&"", story), story)
	for g: StringName in [&"mail", &"talk", &"market", &"pens", &"catch"]:
		var o := ObjectiveScript.for_guide(g, story)
		assert_between(String(o.words).split(" ", false).size(), 2, 6, String(o.words))
