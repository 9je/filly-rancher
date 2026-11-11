extends GutTest
## Act Three's rules (game/systems/path_rules.gd): contracts and ranks on the Factory path,
## the Jubilee order; Heat, pylons, the Lantern Line, allies and Placement on the Rescue
## path; and each path's rules doing nothing on the other.

const StoryScript := preload("res://systems/story.gd")
const StoryV1Script := preload("res://systems/story_v1.gd")
const Rules := preload("res://systems/path_rules.gd")

const PASTEL := Color(0.95, 0.85, 0.9)
const VIVID := Color(0.9, 0.1, 0.3)


func _story(p: String) -> Story:
	var s := StoryScript.new()
	StoryV1Script.choose_path(s, p)
	if p == "factory":
		s.set_var("rank", 1)
		s.set_var("stipend_mult", 2)
	return s


func test_contracts_rank_you_up_to_regional_director() -> void:
	var s := _story("factory")
	Rules.post_contract(s)
	var guard := 0
	var bonuses := 0
	while Rules.rank(s) < Rules.DIRECTOR and guard < 200:
		var c := Rules.contract(s)
		var coat := VIVID if c.kind == "vivid" else PASTEL
		bonuses += int(Rules.factory_delivery(s, coat).bonus)
		guard += 1
	assert_eq(Rules.rank_name(s), "Regional Director")
	assert_gt(bonuses, 0)
	assert_eq(Rules.contract(s).kind, "jubilee", "a Director's board shows the Jubilee order")


func test_a_pastel_contract_ignores_a_vivid_pony() -> void:
	var s := _story("factory")
	s.set_var("contract", {"want": 2, "kind": "pastel", "bonus": 100, "got": 0})
	Rules.factory_delivery(s, VIVID)
	assert_eq(int(Rules.contract(s).got), 0)
	Rules.factory_delivery(s, PASTEL)
	assert_eq(int(Rules.contract(s).got), 1)


func test_the_jubilee_order_needs_its_vivid_ponies() -> void:
	var s := _story("factory")
	s.set_var("rank", Rules.DIRECTOR)
	Rules.post_contract(s)
	for i in Rules.JUBILEE_ORDER:
		Rules.factory_delivery(s, PASTEL)
	assert_false(s.has_flag("jubilee_ready"), "all pastel is not enough")
	var r := {}
	for i in Rules.JUBILEE_VIVID:
		r = Rules.factory_delivery(s, VIVID)
	assert_true(s.has_flag("jubilee_ready"))
	assert_true(r.jubilee_ready)


func test_factory_pay_doubles_and_the_lens_triples_vivid() -> void:
	var s := _story("factory")
	assert_eq(Rules.factory_pay(s, 100, PASTEL, true), 200)
	assert_eq(Rules.factory_pay(s, 100, VIVID, false), 200)
	assert_eq(Rules.factory_pay(s, 100, VIVID, true), 600)


func test_heat_rises_with_raids_and_falls_with_cuts() -> void:
	var s := _story("rescue")
	Rules.add_heat(s, "raid", 5)
	assert_eq(Rules.heat(s), 35, "a full corral (5) stays under the fine")
	assert_lt(Rules.heat(s), Rules.FINE_AT)
	assert_true(Rules.cut_pylon(s, "pylon_lake"))
	assert_eq(Rules.heat(s), 20)
	assert_false(Rules.cut_pylon(s, "pylon_lake"), "a pylon is cut once")
	Rules.add_heat(s, "raid", 20)
	assert_eq(Rules.heat(s), Rules.HEAT_MAX, "Heat stops at the top")


func test_what_heat_costs_on_a_collection_day() -> void:
	var s := _story("rescue")
	s.set_var("heat", 10)
	assert_eq(Rules.rescue_collection_day(s, 1), {"fine": 0, "padlock": false, "take": false, "placed": false})
	s.set_var("heat", 70)
	var r := Rules.rescue_collection_day(s, 1)
	assert_eq(r.fine, Rules.FINE)
	assert_true(r.padlock)
	assert_false(r.take)
	s.set_var("heat", 95)
	assert_false(Rules.rescue_collection_day(s, 0).take, "a missed quota tips 95 to 100: placed, not taken")
	assert_true(s.has_flag("placed"))


func test_the_lantern_line_only_takes_marked_ponies() -> void:
	var s := _story("rescue")
	assert_false(Rules.send_down_line(s, false))
	assert_true(Rules.send_down_line(s, true))
	assert_eq(int(s.get_var("rescued")), 1)


func test_four_pylons_open_lights_out() -> void:
	var s := _story("rescue")
	for p in Rules.PYLONS:
		assert_false(Rules.lights_out_ready(s))
		Rules.cut_pylon(s, p)
	assert_true(Rules.lights_out_ready(s))
	assert_lt(StoryV1Script.dread(s, null), 0.15, "four bands out: the sky is nearly clear")


func test_allies_join_on_their_conditions() -> void:
	var s := _story("rescue")
	for a in StoryV1Script.ALLIES:
		assert_false(Rules.ally_ready(s, a))
	s.set_var("raids", 1)
	s.set_var("dyed", 1)
	s.set_flag("intake_ledger")
	for a in StoryV1Script.ALLIES:
		assert_true(Rules.ally_ready(s, a), a)


func test_each_paths_rules_do_nothing_on_the_other() -> void:
	var f := _story("factory")
	Rules.add_heat(f, "raid")
	assert_eq(Rules.heat(f), 0)
	assert_false(Rules.cut_pylon(f, "pylon_lake"))
	var r := _story("rescue")
	assert_eq(Rules.factory_delivery(r, VIVID).bonus, 0)
	assert_true(Rules.contract(r).is_empty())


func test_a_bloom_after_the_reveal_is_a_rescue_on_either_path() -> void:
	var before := StoryScript.new()
	Rules.rescue_bloom(before)
	assert_eq(int(before.get_var("rescued", 0)), 0, "before the reveal a Bloom is just a Bloom")
	for p in ["factory", "rescue"]:
		var s := _story(p)
		Rules.rescue_bloom(s)
		assert_eq(int(s.get_var("rescued", 0)), 1, p)


func test_a_pony_bloomed_then_sent_down_the_line_counts_once() -> void:
	var s := _story("rescue")
	Rules.rescue_bloom(s, "pony#1")
	Rules.send_down_line(s, true, "pony#1")
	Rules.send_down_line(s, true, "pony#2")
	assert_eq(int(s.get_var("rescued")), 2)


func test_a_delivery_after_the_jubilee_order_is_filled_is_quiet() -> void:
	var s := _story("factory")
	s.set_flag("jubilee_ready")
	assert_eq(Rules.factory_delivery(s, VIVID), {"bonus": 0, "rank_up": false, "jubilee_ready": false})


## Post-game on the Factory path (STORY.md section 6): after the Jubilee, contracts keep coming.
func test_contracts_keep_coming_after_the_jubilee() -> void:
	var s := _story("factory")
	s.set_var("rank", Rules.DIRECTOR)
	s.set_flag("jubilee_ready")
	Rules.post_contract(s)
	assert_true(Rules.contract(s).is_empty(), "nothing between the order and the stage")
	s.set_flag("climax_done")
	Rules.post_contract(s)
	assert_false(Rules.contract(s).is_empty())
	assert_ne(str(Rules.contract(s).kind), "jubilee")
	Rules.factory_delivery(s, VIVID)
	assert_gt(int(Rules.contract(s).got) + int(s.get_var("contracts_done", 0)), 0)
