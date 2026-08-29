extends GutTest
## Tests for game/systems/request_board.gd: the three-at-a-time board of favours the ranch
## asks of the player. Pure logic, no scene, same discipline as test_compendium.gd and
## test_economy.gd -- built against the REAL shipped roster (game/data/ponies/) so the
## counting and drawing tests are measured against the actual game, not a fixture that
## could drift from it.

const RequestBoardScript := preload("res://systems/request_board.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const RegionRegistryScript := preload("res://systems/region_registry.gd")
const EconomyScript := preload("res://systems/economy.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

const PONY_DIR := "res://data/ponies"

## Fictional display names, deliberately different from game/data/regions/*.tres, to prove
## the board can be built and tested without touching region resource files at all (the
## brief's own controller ruling: "tests do not depend on region .tres files").
const REGIONS: Array[StringName] = [&"everfree", &"lake", &"nightmeadow", &"orchard"]
const REGION_NAMES := {
	&"everfree": "Test Everfree",
	&"lake": "Test Lake",
	&"nightmeadow": "Test Nightmeadow",
	&"orchard": "Test Orchard",
}

var registry: PonyRegistry


func before_each() -> void:
	registry = PonyRegistryScript.new()
	registry.load_all(PONY_DIR)


func _board(seed_value: int) -> RequestBoard:
	return RequestBoardScript.new(seed_value, registry, REGIONS, REGION_NAMES)


func _all_ponies() -> Array:
	var out: Array = []
	for rarity in [PonyDataScript.Rarity.COMMON, PonyDataScript.Rarity.UNCOMMON,
			PonyDataScript.Rarity.RARE, PonyDataScript.Rarity.LEGENDARY]:
		out.append_array(registry.by_rarity(rarity))
	return out


func _pony_with_personality(p: int) -> PonyData:
	for data in _all_ponies():
		if data.personality == p:
			return data
	return null


## Searches seeds 0..max_seed for a fresh board whose fill() draws at least one request of
## `target_kind` among its ACTIVE slots. Returns {} if none found in range (the test that
## calls this fails loudly on that, rather than silently skipping coverage).
func _find_board_with_kind(target_kind: int, max_seed: int = 500) -> Dictionary:
	for s in range(max_seed):
		var board: RequestBoard = _board(s)
		board.fill()
		for req in board.active():
			if int(req.kind) == target_kind:
				return {"board": board, "request": req}
	return {}


# --- the tutorial three ----------------------------------------------------------------------

func test_seed_tutorial_creates_three_requests_in_exact_order_with_exact_text_and_reward() -> void:
	var board := _board(1)
	board.seed_tutorial()
	var reqs := board.requests()

	assert_eq(reqs.size(), 3)

	assert_eq(int(reqs[0].kind), RequestBoardScript.Kind.CATCH_ANY)
	assert_eq(String(reqs[0].id), "tutorial_catch")
	assert_eq(String(reqs[0].text), "Catch a pony with your magic beam.")
	assert_eq(int(reqs[0].reward_bits), 20)

	assert_eq(int(reqs[1].kind), RequestBoardScript.Kind.PEN_ANY)
	assert_eq(String(reqs[1].id), "tutorial_pen")
	assert_eq(String(reqs[1].text), "Move a pony into a pen.")
	assert_eq(int(reqs[1].reward_bits), 30)

	assert_eq(int(reqs[2].kind), RequestBoardScript.Kind.SELL_ANY)
	assert_eq(String(reqs[2].id), "tutorial_sell")
	assert_eq(String(reqs[2].text), "Sell a gem at the market.")
	assert_eq(int(reqs[2].reward_bits), 50)

	for r in reqs:
		assert_eq(int(r.count), 1)
		assert_eq(int(r.progress), 0)
		assert_false(bool(r.done))
		assert_false(bool(r.paid))


# --- fill() ---------------------------------------------------------------------------------

func test_fill_reaches_three_active_requests_from_an_empty_board() -> void:
	var board := _board(7)
	board.fill()
	assert_eq(board.active().size(), RequestBoardScript.ACTIVE)
	assert_eq(board.requests().size(), RequestBoardScript.ACTIVE)


func test_fill_is_deterministic_for_the_same_seed() -> void:
	var a := _board(42)
	a.fill()
	var b := _board(42)
	b.fill()
	assert_eq_deep(a.requests(), b.requests())


func test_fill_does_nothing_once_three_tutorial_requests_are_already_active() -> void:
	var board := _board(3)
	board.seed_tutorial()
	board.fill()
	assert_eq(board.requests().size(), 3,
		"tutorial requests already satisfy ACTIVE; fill() must not add template requests on top")


func test_fill_tops_up_after_a_claim_without_ever_repeating_a_tutorial_request() -> void:
	var board := _board(9)
	board.seed_tutorial()

	var twilight: PonyData = registry.by_id(&"twilight")
	var flipped := board.on_caught(twilight, &"everfree")
	assert_eq(flipped.size(), 1)
	assert_eq(String(flipped[0].id), "tutorial_catch")

	var claimed := board.claim("tutorial_catch")
	assert_false(claimed.is_empty())
	assert_eq(board.active().size(), 2)

	board.fill()
	assert_eq(board.active().size(), 3)

	var catch_count := 0
	for r in board.requests():
		if String(r.id) == "tutorial_catch":
			catch_count += 1
	assert_eq(catch_count, 1, "the tutorial catch request must never be redrawn")
	for r in board.active():
		assert_ne(int(r.kind), RequestBoardScript.Kind.CATCH_ANY)


func test_fill_excludes_seen_characters_from_see_character_draws() -> void:
	var all_ids: Array = []
	for data in _all_ponies():
		all_ids.append(data.id)

	var board := _board(55)
	board.fill(all_ids)
	for r in board.active():
		assert_ne(int(r.kind), RequestBoardScript.Kind.SEE_CHARACTER,
			"no unseen characters remain; SEE_CHARACTER must not be drawable")


func test_sell_gems_of_rarity_count_is_always_between_three_and_six() -> void:
	for s in range(30):
		var board := _board(s)
		board.fill()
		for r in board.active():
			if int(r.kind) == RequestBoardScript.Kind.SELL_GEMS_OF_RARITY:
				assert_between(int(r.count), 3, 6, "seed %d" % s)


func test_generated_text_has_no_dashes_and_uses_lower_case_words() -> void:
	var board := _board(77)
	board.seed_tutorial()
	board.fill()
	for r in board.requests():
		var text: String = r.text
		assert_false(text.contains("--"), text)
		assert_false(text.contains(" - "), text)
		assert_false(text.contains("—"), text)  # em dash
		match int(r.kind):
			RequestBoardScript.Kind.BRING_PERSONALITY_FROM_ZONE:
				var found := false
				for name in ["shy", "bold", "curious"]:
					if text.contains(name):
						found = true
				assert_true(found, text)
			RequestBoardScript.Kind.SELL_GEMS_OF_RARITY:
				var found_r := false
				for name in ["common", "uncommon", "rare", "legendary"]:
					if text.contains(name):
						found_r = true
				assert_true(found_r, text)


func test_bring_personality_text_falls_back_to_the_real_region_registry_when_no_names_given() -> void:
	var real_regions := RegionRegistryScript.new()
	real_regions.load_all()

	var found := false
	for s in range(80):
		var board: RequestBoard = RequestBoardScript.new(s, registry, REGIONS)
		board.fill()
		for r in board.active():
			if int(r.kind) == RequestBoardScript.Kind.BRING_PERSONALITY_FROM_ZONE:
				var region: RegionData = real_regions.by_id(StringName(String(r.zone)))
				assert_not_null(region)
				assert_true(String(r.text).contains(region.display_name))
				found = true
		if found:
			break
	assert_true(found, "expected at least one BRING_PERSONALITY_FROM_ZONE draw within the search range")


# --- events: each on_* completes the matching kind and not others ----------------------------

func test_on_caught_completes_catch_any_and_not_pen_or_sell() -> void:
	var board := _board(5)
	board.seed_tutorial()
	var flipped := board.on_caught(registry.by_id(&"fluttershy"), &"everfree")

	assert_eq(flipped.size(), 1)
	assert_eq(String(flipped[0].id), "tutorial_catch")
	assert_true(bool(flipped[0].done))

	var active_ids: Array = []
	for r in board.active():
		active_ids.append(String(r.id))
	assert_true("tutorial_pen" in active_ids)
	assert_true("tutorial_sell" in active_ids)
	assert_false("tutorial_catch" in active_ids)


func test_on_penned_completes_pen_any_and_not_catch_or_sell() -> void:
	var board := _board(6)
	board.seed_tutorial()
	var flipped := board.on_penned(registry.by_id(&"applejack"))

	assert_eq(flipped.size(), 1)
	assert_eq(String(flipped[0].id), "tutorial_pen")

	var active_ids: Array = []
	for r in board.active():
		active_ids.append(String(r.id))
	assert_true("tutorial_catch" in active_ids)
	assert_true("tutorial_sell" in active_ids)
	assert_false("tutorial_pen" in active_ids)


func test_on_sold_completes_sell_any_and_not_catch_or_pen() -> void:
	var board := _board(8)
	board.seed_tutorial()
	var flipped := board.on_sold(PonyDataScript.Rarity.COMMON, 1)

	assert_eq(flipped.size(), 1)
	assert_eq(String(flipped[0].id), "tutorial_sell")

	var active_ids: Array = []
	for r in board.active():
		active_ids.append(String(r.id))
	assert_true("tutorial_catch" in active_ids)
	assert_true("tutorial_pen" in active_ids)
	assert_false("tutorial_sell" in active_ids)


func test_on_sold_with_zero_count_is_a_no_op() -> void:
	var board := _board(50)
	board.seed_tutorial()
	var flipped := board.on_sold(PonyDataScript.Rarity.COMMON, 0)
	assert_eq(flipped.size(), 0)
	assert_eq(board.active().size(), 3)


func test_on_caught_completes_bring_personality_from_zone_only_on_matching_personality_and_zone() -> void:
	var found := _find_board_with_kind(RequestBoardScript.Kind.BRING_PERSONALITY_FROM_ZONE)
	assert_false(found.is_empty(),
		"expected at least one seed to draw a BRING_PERSONALITY_FROM_ZONE request")

	var board: RequestBoard = found.board
	var req: Dictionary = found.request
	var zone := StringName(String(req.zone))
	var matching: PonyData = _pony_with_personality(int(req.personality))
	assert_not_null(matching, "roster should contain at least one pony of every personality")

	# Wrong zone (same personality) must not complete it.
	var wrong_zone: StringName = &"lake" if zone != &"lake" else &"orchard"
	var wrong := board.on_caught(matching, wrong_zone)
	var wrong_matched: Array = wrong.filter(func(r): return String(r.id) == String(req.id))
	assert_eq(wrong_matched.size(), 0)

	var right := board.on_caught(matching, zone)
	var matched: Array = right.filter(func(r): return String(r.id) == String(req.id))
	assert_eq(matched.size(), 1)
	assert_true(bool(matched[0].done))
	assert_eq(int(matched[0].reward_bits), 80)


func test_on_seen_completes_see_character_only_for_the_named_character() -> void:
	var found := _find_board_with_kind(RequestBoardScript.Kind.SEE_CHARACTER)
	assert_false(found.is_empty(), "expected at least one seed to draw a SEE_CHARACTER request")

	var board: RequestBoard = found.board
	var req: Dictionary = found.request
	var char_id := StringName(String(req.character))
	var target: PonyData = registry.by_id(char_id)
	assert_not_null(target)

	var other_id: StringName = &"twilight" if char_id != &"twilight" else &"rainbowdash"
	var other_flipped := board.on_seen(registry.by_id(other_id))
	var other_matched: Array = other_flipped.filter(func(r): return String(r.id) == String(req.id))
	assert_eq(other_matched.size(), 0)

	var flipped := board.on_seen(target)
	var matched: Array = flipped.filter(func(r): return String(r.id) == String(req.id))
	assert_eq(matched.size(), 1)
	assert_true(bool(matched[0].done))
	assert_eq(int(matched[0].reward_bits), 40)
	assert_eq(String(matched[0].reward_food), "hay")


func test_sell_gems_of_rarity_accumulates_progress_across_several_sales() -> void:
	var found := _find_board_with_kind(RequestBoardScript.Kind.SELL_GEMS_OF_RARITY)
	assert_false(found.is_empty(), "expected at least one seed to draw a SELL_GEMS_OF_RARITY request")

	var board: RequestBoard = found.board
	var req: Dictionary = found.request
	var rarity := int(req.rarity)
	var target := int(req.count)
	assert_between(target, 3, 6)

	var unit_value: int = EconomyScript.GEM_VALUE_BY_RARITY.get(rarity, 0)
	assert_eq(int(req.reward_bits), target * (unit_value + 15))

	# A sale of the wrong rarity must not move it, even in a large quantity.
	var wrong_rarity := (rarity + 1) % 4
	var no_match := board.on_sold(wrong_rarity, 100)
	var no_match_hits: Array = no_match.filter(func(r): return String(r.id) == String(req.id))
	assert_eq(no_match_hits.size(), 0)

	var flipped: Array = []
	var sold_so_far := 0
	while sold_so_far < target:
		var step: int = mini(2, target - sold_so_far)
		sold_so_far += step
		flipped.append_array(board.on_sold(rarity, step))

	var matched: Array = flipped.filter(func(r): return String(r.id) == String(req.id))
	assert_eq(matched.size(), 1, "must flip exactly once, on the call that reaches the target")
	assert_true(bool(matched[0].done))
	assert_eq(int(matched[0].progress), target)


# --- claim() --------------------------------------------------------------------------------

func test_claim_pays_once_and_a_second_claim_returns_empty() -> void:
	var board := _board(11)
	board.seed_tutorial()
	board.on_caught(registry.by_id(&"twilight"), &"everfree")

	var claimed := board.claim("tutorial_catch")
	assert_false(claimed.is_empty())
	assert_true(bool(claimed.paid))
	assert_eq(int(claimed.reward_bits), 20)

	var second := board.claim("tutorial_catch")
	assert_true(second.is_empty())


func test_claim_on_an_unfinished_request_returns_empty() -> void:
	var board := _board(12)
	board.seed_tutorial()
	assert_true(board.claim("tutorial_pen").is_empty())


func test_claim_on_an_unknown_id_returns_empty() -> void:
	var board := _board(13)
	board.seed_tutorial()
	assert_true(board.claim("does_not_exist").is_empty())


# --- requests() / active() are copies ---------------------------------------------------------

func test_active_excludes_done_requests_but_requests_includes_them() -> void:
	var board := _board(30)
	board.seed_tutorial()
	board.on_caught(registry.by_id(&"twilight"), &"everfree")

	assert_eq(board.requests().size(), 3)
	assert_eq(board.active().size(), 2)

	var done_found := false
	for r in board.requests():
		if String(r.id) == "tutorial_catch":
			done_found = bool(r.done)
	assert_true(done_found)


func test_requests_and_active_return_copies_not_live_references() -> void:
	var board := _board(40)
	board.seed_tutorial()

	var reqs := board.requests()
	reqs[0]["done"] = true
	assert_false(bool(board.requests()[0].done))

	var act := board.active()
	act[0]["reward_bits"] = 99999
	assert_ne(int(board.active()[0].reward_bits), 99999)


# --- to_array() / from_array() -----------------------------------------------------------------

func test_round_trip_through_to_array_and_from_array_preserves_state_and_the_draw_sequence() -> void:
	var board := _board(21)
	board.seed_tutorial()
	board.fill()
	board.on_caught(registry.by_id(&"twilight"), &"everfree")
	board.claim("tutorial_catch")

	var saved := board.to_array()
	var restored := RequestBoardScript.from_array(saved, registry, REGIONS, REGION_NAMES)

	assert_eq_deep(restored.requests(), board.requests())
	assert_eq(restored.active().size(), board.active().size())

	# Continuing the sequence after a reload must match continuing it without one.
	board.fill()
	restored.fill()
	assert_eq_deep(board.requests(), restored.requests())
	assert_eq(board.active().size(), RequestBoardScript.ACTIVE)
	assert_eq(restored.active().size(), RequestBoardScript.ACTIVE)


func test_from_array_drops_a_request_naming_an_unknown_character_but_keeps_the_rest() -> void:
	var valid := {
		"id": "req_x", "kind": RequestBoardScript.Kind.SEE_CHARACTER, "personality": -1,
		"zone": "", "rarity": -1, "count": 1, "progress": 0, "character": "twilight",
		"reward_bits": 40, "reward_food": "hay", "done": false, "paid": false,
		"text": "Find Twilight Sparkle and get a good look at her.",
	}
	var unknown_character := valid.duplicate(true)
	unknown_character["id"] = "req_y"
	unknown_character["character"] = "nonexistent_pony_xyz"

	var raw: Array = [{"seed": 0, "draw_counter": 2}, valid, unknown_character]
	var board := RequestBoardScript.from_array(raw, registry, REGIONS, REGION_NAMES)
	assert_engine_error(1, "from_array must report the drop with push_warning, not crash")

	var ids: Array = []
	for r in board.requests():
		ids.append(String(r.id))
	assert_eq(board.requests().size(), 1)
	assert_true("req_x" in ids)
	assert_false("req_y" in ids)


func test_from_array_drops_a_request_naming_a_region_not_in_regions_but_keeps_the_rest() -> void:
	var valid := {
		"id": "req_a", "kind": RequestBoardScript.Kind.BRING_PERSONALITY_FROM_ZONE,
		"personality": PonyDataScript.Personality.SHY, "zone": "lake", "rarity": -1,
		"count": 1, "progress": 0, "character": "", "reward_bits": 80, "reward_food": "",
		"done": false, "paid": false, "text": "Bring a shy pony from Test Lake.",
	}
	var unknown_zone := valid.duplicate(true)
	unknown_zone["id"] = "req_b"
	unknown_zone["zone"] = "nowhere_land"

	var raw: Array = [{"seed": 0, "draw_counter": 1}, valid, unknown_zone]
	var board := RequestBoardScript.from_array(raw, registry, REGIONS, REGION_NAMES)
	assert_engine_error(1, "from_array must report the drop with push_warning, not crash")

	var ids: Array = []
	for r in board.requests():
		ids.append(String(r.id))
	assert_eq(board.requests().size(), 1)
	assert_true("req_a" in ids)
	assert_false("req_b" in ids)


func test_from_array_on_an_empty_array_produces_an_empty_board() -> void:
	var board := RequestBoardScript.from_array([], registry, REGIONS, REGION_NAMES)
	assert_eq(board.requests().size(), 0)
	assert_eq(board.active().size(), 0)
