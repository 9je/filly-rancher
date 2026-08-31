extends GutTest
## THE ONE INTERACT RESOLVER. Exactly one candidate wins per frame, the order is stated
## rather than emergent, and the prompt always names what E is about to do.
##
## This file drives no scene and touches no node: the resolver takes dictionaries and
## answers with one, which is the whole reason it was pulled out of ranch.gd.

const InteractionScript := preload("res://world/interaction.gd")


func test_nothing_in_range_resolves_to_nothing() -> void:
	var chosen: Dictionary = InteractionScript.resolve([])
	assert_true(chosen.is_empty(), "no candidate is not the same as a candidate of kind NONE")


func test_one_candidate_wins_on_its_own() -> void:
	var chosen: Dictionary = InteractionScript.resolve(
		[InteractionScript.candidate(InteractionScript.Kind.MARKET, 3.0)])
	assert_eq(int(chosen["kind"]), InteractionScript.Kind.MARKET)


## THE PRIORITY IS A LIST, NOT A DISTANCE. A plot slot the player is standing IN beats a
## Market she is standing nearer to, because she walked onto the plot on purpose.
func test_the_plot_she_stands_on_beats_the_market_she_stands_nearer_to() -> void:
	var chosen: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 0.5),
		InteractionScript.candidate(InteractionScript.Kind.PLOT_BUILD, 4.0),
	])
	assert_eq(int(chosen["kind"]), InteractionScript.Kind.PLOT_BUILD)


## THE OVERLAP THAT SHIPPED AS A HARD CODED CLAUSE INSIDE is_near_board(). The board stands
## five metres from the Market's origin and the two radii meet in the middle.
func test_the_market_beats_the_board_where_their_radii_meet() -> void:
	var chosen: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.BOARD, 1.0),
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 4.4),
	])
	assert_eq(int(chosen["kind"]), InteractionScript.Kind.MARKET,
		"the Market is the older and the busier of the two and keeps the ground")


func test_the_depot_and_the_palace_lose_to_everything_and_the_depot_beats_the_palace() -> void:
	for other: int in [InteractionScript.Kind.PLOT_BUILD, InteractionScript.Kind.PEN_MOVE_IN,
			InteractionScript.Kind.MARKET, InteractionScript.Kind.BOARD]:
		var chosen: Dictionary = InteractionScript.resolve([
			InteractionScript.candidate(InteractionScript.Kind.DEPOT, 0.1),
			InteractionScript.candidate(other, 9.0),
		])
		assert_eq(int(chosen["kind"]), other, "kind %d must outrank the Depot" % other)
	var pair: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.PALACE, 0.1),
		InteractionScript.candidate(InteractionScript.Kind.DEPOT, 4.9),
	])
	assert_eq(int(pair["kind"]), InteractionScript.Kind.DEPOT)


## TWO OF THE SAME KIND IS THE ONE PLACE DISTANCE DECIDES. Two plot slots whose trigger
## boxes overlap is a map edit away, and "whichever one came first in get_children()" is
## not an answer a player can predict.
func test_two_candidates_of_the_same_kind_are_settled_by_distance() -> void:
	var chosen: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.PLOT_BUILD, 3.0, "far"),
		InteractionScript.candidate(InteractionScript.Kind.PLOT_BUILD, 1.0, "near"),
	])
	assert_eq(String(chosen["subject"]), "near")


func test_the_same_candidates_in_any_order_resolve_the_same_way() -> void:
	var a: Array[Dictionary] = [
		InteractionScript.candidate(InteractionScript.Kind.PALACE, 1.0),
		InteractionScript.candidate(InteractionScript.Kind.PEN_MOVE_IN, 2.0, "Buttercup"),
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 0.2),
	]
	var b: Array[Dictionary] = [a[2], a[0], a[1]]
	assert_eq(InteractionScript.resolve(a), InteractionScript.resolve(b),
		"a resolver that depends on the order it was handed is not deterministic")


func test_every_kind_has_a_place_in_the_priority_list() -> void:
	for kind: int in [InteractionScript.Kind.PLOT_BUILD, InteractionScript.Kind.PEN_MOVE_IN,
			InteractionScript.Kind.MARKET, InteractionScript.Kind.BOARD,
			InteractionScript.Kind.DEPOT, InteractionScript.Kind.PALACE]:
		assert_gte(InteractionScript.rank_of(kind), 0,
			"kind %d is not in PRIORITY, so it can never win a tie" % kind)
	assert_lt(InteractionScript.rank_of(InteractionScript.Kind.NONE), 0)


# --- what the prompt says -------------------------------------------------------------------

func test_the_prompt_names_the_verb_for_every_kind() -> void:
	var expected := {
		InteractionScript.Kind.PLOT_BUILD: "E: build here",
		InteractionScript.Kind.MARKET: "E: Market, sell gems",
		InteractionScript.Kind.BOARD: "E: read the board",
		InteractionScript.Kind.DEPOT: "E: Depot, deliver and pay",
		InteractionScript.Kind.PALACE: "E: Spectra Palace",
	}
	for kind: int in expected:
		assert_eq(InteractionScript.prompt_for(
			InteractionScript.candidate(kind, 1.0), "E"), String(expected[kind]))


func test_the_pen_prompt_names_the_pony_who_is_about_to_go_in() -> void:
	assert_eq(InteractionScript.prompt_for(InteractionScript.candidate(
		InteractionScript.Kind.PEN_MOVE_IN, 1.0, "Buttercup"), "E"),
		"E: move Buttercup in")


func test_an_empty_saddlebag_still_holds_the_ground_and_says_why() -> void:
	var line: String = InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.PEN_MOVE_IN, 1.0), "E")
	assert_true(line.contains("saddlebag"),
		"the pen keeps the ground so nothing else steals E there, and it explains itself: %s"
			% line)


func test_the_prompt_uses_the_key_it_is_handed() -> void:
	assert_eq(InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 1.0), "X"),
		"X: Market, sell gems")


func test_nothing_resolves_to_an_empty_prompt() -> void:
	assert_eq(InteractionScript.prompt_for({}, "E"), "")


func test_nothing_the_resolver_says_carries_a_dash() -> void:
	for kind: int in [InteractionScript.Kind.PLOT_BUILD, InteractionScript.Kind.PEN_MOVE_IN,
			InteractionScript.Kind.MARKET, InteractionScript.Kind.BOARD,
			InteractionScript.Kind.DEPOT, InteractionScript.Kind.PALACE]:
		for subject: String in ["", "Buttercup"]:
			var line: String = InteractionScript.prompt_for(
				InteractionScript.candidate(kind, 1.0, subject), "E")
			assert_false(line.contains("--") or line.contains("—"), line)
