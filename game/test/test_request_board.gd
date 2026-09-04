extends GutTest
## Tests for game/systems/request_board.gd: the three-at-a-time board of favours the ranch
## asks of the player. Pure logic, no scene, same discipline as test_compendium.gd and
## test_economy.gd; built against the REAL shipped roster (game/data/ponies/) so the
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


func _board(seed_value: int = 1) -> RequestBoard:
	return RequestBoardScript.new(seed_value, registry, REGIONS, REGION_NAMES)


## The first record out of the real roster, for a test that needs SOME caught pony and does
## not care which one.
func _any_data() -> PonyData:
	return _all_ponies()[0]


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


# --- reading -----------------------------------------------------------------------------

## The board's own account of what BRING_PERSONALITY_FROM_ZONE can draw next is exactly
## what it was constructed with: a copy, so a caller (ranch.gd) can check what it fed the
## board without being able to reach in and change it. This is what let the ranch-level
## regression (game/scenes/test/region_test.gd: the board must never draw a zone with no
## spawn marker in it) assert against something the board itself reports, rather than
## against a hard-coded expectation of ranch.gd's own filtering.
func test_drawable_zones_is_a_copy_of_the_regions_it_was_built_with() -> void:
	var board := _board(3)
	assert_eq(board.drawable_zones(), REGIONS)
	board.drawable_zones().clear()
	assert_eq(board.drawable_zones(), REGIONS, "the getter must not hand out the live array")


func test_drawable_zones_survives_a_round_trip_through_from_array() -> void:
	var written := _board(9)
	written.fill()
	var reloaded := RequestBoardScript.from_array(written.to_array(), registry, REGIONS,
		REGION_NAMES)
	assert_eq(reloaded.drawable_zones(), REGIONS)


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


func test_every_request_carries_the_count_of_the_food_it_pays() -> void:
	# The reward has to be readable off the request alone: game/world/ranch.gd pays it and
	# says what it paid, and game/ui/pause_menu.gd prints the same line on the REQUESTS page.
	# A count that lived only as a constant on this class made the request an incomplete
	# description of its own reward.
	var found := _find_board_with_kind(RequestBoardScript.Kind.SEE_CHARACTER)
	assert_false(found.is_empty(), "expected at least one seed to draw a SEE_CHARACTER request")
	var see_request: Dictionary = found.request
	assert_eq(String(see_request.reward_food), "hay")
	assert_eq(int(see_request.reward_food_count), RequestBoardScript.SEE_CHARACTER_FOOD_COUNT,
		"a SEE_CHARACTER request says how much hay it is offering")

	var board := _board(3)
	board.seed_tutorial()
	board.fill()
	for r in board.requests():
		if int(r.kind) == RequestBoardScript.Kind.SEE_CHARACTER:
			continue
		assert_eq(String(r.reward_food), "", "no other kind pays food")
		assert_eq(int(r.reward_food_count), 0, "...and every one of them says so")


func test_from_array_fills_in_a_food_count_a_save_written_before_it_existed_lacks() -> void:
	# A slice 5 save on somebody's disk has requests with no reward_food_count in them. The
	# board rebuilds the count its kind would have been built with, so an old save pays out
	# exactly what it promised rather than silently paying nothing.
	var found := _find_board_with_kind(RequestBoardScript.Kind.SEE_CHARACTER)
	assert_false(found.is_empty(), "expected at least one seed to draw a SEE_CHARACTER request")
	var written: Array = (found.board as RequestBoard).to_array()
	for entry in written:
		(entry as Dictionary).erase("reward_food_count")

	var reloaded := RequestBoardScript.from_array(written, registry, REGIONS, REGION_NAMES)

	var counted := 0
	for r in reloaded.requests():
		if int(r.kind) == RequestBoardScript.Kind.SEE_CHARACTER:
			counted += 1
			assert_eq(int(r.reward_food_count),
				RequestBoardScript.SEE_CHARACTER_FOOD_COUNT,
				"the SEE_CHARACTER request gets its two hay back")
		else:
			assert_eq(int(r.reward_food_count), 0, "and nobody else is given food")
	assert_gt(counted, 0, "there was a SEE_CHARACTER request in the file to restore")


func test_a_finished_but_unpaid_see_character_request_is_not_drawn_again() -> void:
	# THE GAP BETWEEN DONE AND PAID. on_seen() flips a request to done and the caller claims
	# it a moment later (game/world/ranch.gd, _pay_out), refilling the board in between. The
	# character is not on the `seen` list this test hands in, which is the state a caller
	# that has not rebuilt its list yet is in; testing `done` here let the refill draw a
	# second request for the very face the player is being paid for.
	var found := _find_board_with_kind(RequestBoardScript.Kind.SEE_CHARACTER)
	assert_false(found.is_empty(), "expected at least one seed to draw a SEE_CHARACTER request")
	var board: RequestBoard = found.board
	var char_id := StringName(String(found.request.character))

	board.on_seen(registry.by_id(char_id))
	board.fill()

	for r in board.active():
		if int(r.kind) != RequestBoardScript.Kind.SEE_CHARACTER:
			continue
		assert_ne(String(r.character), String(char_id),
			"the board does not ask twice for a face it has not paid for yet")


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


# --- the tutorial checklist the HUD pins --------------------------------------------------

## THE THREE PINNED ON THE HUD. They already existed and were only visible on a pause menu
## page a new player has no reason to open (owner, 2026-08-31: the how do I earn money path
## is not legible in the first minutes).
func test_the_tutorial_rows_are_the_three_seeded_ones_in_order() -> void:
	var board: RequestBoard = _board()
	board.seed_tutorial()
	var rows: Array[Dictionary] = board.tutorial_rows()
	assert_eq(rows.size(), 3)
	for i in rows.size():
		assert_eq(String(rows[i]["id"]), RequestBoardScript.TUTORIAL_IDS[i])
		assert_false(String(rows[i]["text"]).is_empty())
		assert_gt(int(rows[i]["reward_bits"]), 0)


func test_a_board_with_no_tutorial_seeded_pins_nothing() -> void:
	assert_eq(_board().tutorial_rows().size(), 0)


func test_a_finished_tutorial_row_says_so_but_stays_pinned_until_it_is_claimed() -> void:
	var board: RequestBoard = _board()
	board.seed_tutorial()
	board.on_caught(_any_data(), &"ranch")
	var rows: Array[Dictionary] = board.tutorial_rows()
	assert_eq(rows.size(), 3, "finishing one does not take it off the list")
	assert_true(bool(rows[0]["done"]), "catching a pony finishes the first one")
	assert_false(bool(rows[0]["paid"]))


func test_a_claimed_tutorial_row_comes_off_the_list() -> void:
	var board: RequestBoard = _board()
	board.seed_tutorial()
	board.on_caught(_any_data(), &"ranch")
	board.claim(RequestBoardScript.TUTORIAL_IDS[0])
	var rows: Array[Dictionary] = board.tutorial_rows()
	assert_eq(rows.size(), 2)
	assert_eq(String(rows[0]["id"]), RequestBoardScript.TUTORIAL_IDS[1])


func test_the_tutorial_ids_are_the_ids_seed_tutorial_actually_writes() -> void:
	var board: RequestBoard = _board()
	board.seed_tutorial()
	var seeded: Array[String] = []
	for r in board.requests():
		seeded.append(String((r as Dictionary)["id"]))
	assert_eq(seeded, RequestBoardScript.TUTORIAL_IDS,
		"a constant that has drifted from the seeder pins the wrong three")


# --- the board reads differently by chapter ----------------------------------------------

func test_the_board_words_itself_in_the_chapter_it_is_read_in() -> void:
	var wording = preload("res://systems/story_wording.gd")
	var story = preload("res://systems/story.gd")
	var board: RequestBoard = _board()
	board.seed_tutorial()
	assert_eq(String(board.requests()[0]["text"]),
		wording.board_text(RequestBoardScript.Kind.CATCH_ANY, story.Chapter.SUNNY, "", 1))
	board.set_chapter(story.Chapter.WEATHER)
	assert_eq(String(board.requests()[0]["text"]),
		wording.board_text(RequestBoardScript.Kind.CATCH_ANY, story.Chapter.WEATHER, "", 1),
		"an EXISTING request rereads in the new chapter; it is not reworded only at draw")


func test_the_chapter_changes_the_words_and_never_the_rewards_or_the_draw() -> void:
	var story = preload("res://systems/story.gd")
	var sunny: RequestBoard = _board()
	sunny.seed_tutorial()
	sunny.fill([])
	var weather: RequestBoard = _board()
	weather.set_chapter(story.Chapter.WEATHER)
	weather.seed_tutorial()
	weather.fill([])
	var a: Array = sunny.requests()
	var b: Array = weather.requests()
	assert_eq(a.size(), b.size(), "the same board, drawn the same way")
	for i in a.size():
		var one: Dictionary = a[i]
		var two: Dictionary = b[i]
		assert_eq(String(one["id"]), String(two["id"]), "the seeded draw is untouched")
		assert_eq(int(one["kind"]), int(two["kind"]))
		assert_eq(int(one["count"]), int(two["count"]))
		assert_eq(int(one["reward_bits"]), int(two["reward_bits"]), "THE MATH DOES NOT CHANGE")
		assert_eq(int(one["reward_food_count"]), int(two["reward_food_count"]))


func test_a_saved_board_from_before_the_subject_field_keeps_its_own_words() -> void:
	var board: RequestBoard = _board()
	board.seed_tutorial()
	var saved: Array = board.to_array()
	for i in range(1, saved.size()):
		(saved[i] as Dictionary).erase("subject")
		(saved[i] as Dictionary)["text"] = "An older sentence."
	var back := RequestBoardScript.from_array(saved, registry, REGIONS, REGION_NAMES)
	assert_eq(String(back.requests()[0]["text"]), "An older sentence.",
		"a request with no subject to reword from keeps the text it was saved with")


func test_the_board_carries_a_note_for_the_chapter_it_is_in() -> void:
	var wording = preload("res://systems/story_wording.gd")
	var story = preload("res://systems/story.gd")
	var board: RequestBoard = _board()
	assert_eq(board.note(), wording.board_note(story.Chapter.SUNNY))
	board.set_chapter(story.Chapter.WEATHER)
	assert_eq(board.note(), wording.board_note(story.Chapter.WEATHER))
