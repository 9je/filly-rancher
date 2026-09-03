extends GutTest
## THE ONE INTERACT RESOLVER. Exactly one candidate wins per frame, the order is stated
## rather than emergent, and the prompt always names what E is about to do.
##
## MOST OF THIS FILE DRIVES NO SCENE AND TOUCHES NO NODE: the resolver takes dictionaries
## and answers with one, which is the whole reason it was pulled out of ranch.gd.
##
## THE LAST TWO TESTS ARE THE OTHER HALF, and they exist because the whole-branch review of
## 2026-08-31 found that half uncalled. resolve() and prompt_for() are exercised everywhere;
## the WORLD side of the seam, ranch.gd's current_interaction(), which gathers the
## candidates and refuses to offer any of them while a menu is up, had exactly one caller
## and no test. A pure function nobody drives through its real caller is a pure function
## that can be right about nothing.

const InteractionScript := preload("res://world/interaction.gd")
const RanchScene := preload("res://world/ranch.tscn")


## A menu that is open or is not, and says so through the one method _no_menu_but() asks
## for. Standing in for any of the ten real panels, none of which can be opened without a
## tree to pause.
class FakeMenu:
	extends CanvasLayer

	var open := false

	func is_open() -> bool:
		return open


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


## THE REPORT: "the Market prompt says what it does". "E: Market" tells a player where she
## is standing, which she can already see; the verb is the part she needs.
func test_the_market_prompt_names_the_verb_and_not_only_the_place() -> void:
	var line: String = InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.MARKET, 1.0), "E")
	assert_true(line.to_lower().contains("sell"), line)
	assert_true(line.to_lower().contains("gem"), line)


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


## THE SHIPPED RANCH, WITH THE PLAYER WALKED TO THE MARKET'S DOOR. A detached Ranch cannot
## answer this one: interaction_candidates() measures global_position, and a node that never
## entered a tree has none, so the only honest way to ask what the interact key means
## somewhere is to stand in that somewhere on the real map.
func _ranch_at_the_market() -> Node3D:
	var ranch: Node3D = RanchScene.instantiate()
	add_child_autofree(ranch)
	await get_tree().process_frame
	var market: Node3D = ranch.get_node(^"Buildings/Market")
	var player: Node3D = ranch.get_node(^"Player")
	player.global_position = Vector3(market.global_position.x,
		player.global_position.y, market.global_position.z)
	await get_tree().physics_frame
	return ranch


func test_the_ranch_offers_the_verb_when_nothing_is_in_the_way() -> void:
	var ranch: Node3D = await _ranch_at_the_market()
	var action: Dictionary = ranch.current_interaction()
	assert_eq(int(action.get("kind", InteractionScript.Kind.NONE)),
		InteractionScript.Kind.MARKET,
		"standing on the Market's own origin, the interact key means the Market")
	assert_ne(InteractionScript.prompt_for(action, "E"), "",
		"...and the HUD has a line to print about it")


## AN OPEN MENU EMPTIES THE VERB. Every panel in this game pauses the tree and unpauses it
## on close, so a second one opened underneath the first would unpause the world while the
## first is still on screen; current_interaction() answers an EMPTY dictionary rather than a
## candidate whenever anything is up, which is what makes that unreachable through E rather
## than merely discouraged. _update_interaction() then prints no prompt and performs nothing,
## because prompt_for({}) is "" and perform_interaction({}) is false.
##
## THE MENU IS A STUB, AND DELIBERATELY. Opening a real panel emits `opened`, which ranch.gd
## answers by pausing the whole tree. Inside a test run that is GUT's tree, and slice 1
## Task 5 already found what a menu that pauses it does to twenty five unrelated tests. What
## is under test is the PREDICATE, and the predicate asks exactly one question of exactly one
## method.
func test_an_open_menu_empties_the_verb_entirely() -> void:
	var ranch: Node3D = await _ranch_at_the_market()
	var menu: FakeMenu = FakeMenu.new()
	ranch.add_child(menu)
	ranch.market_menu = menu

	menu.open = false
	assert_false(ranch.current_interaction().is_empty(),
		"sanity: with the menu shut there is a verb to empty")

	menu.open = true
	assert_true(ranch.current_interaction().is_empty(),
		"with a menu up, E must mean nothing at all rather than something refusable")
	assert_eq(InteractionScript.prompt_for(ranch.current_interaction(), "E"), "",
		"...and the HUD must therefore print no prompt")
	assert_false(ranch.perform_interaction(ranch.current_interaction()),
		"...and performing nothing must do nothing")

	menu.open = false
	assert_false(ranch.current_interaction().is_empty(),
		"closing the menu hands the verb straight back, with no latch in between")


func test_the_mailbox_is_ranked_and_beats_the_depot_when_both_are_in_reach() -> void:
	var mailbox: Dictionary = InteractionScript.candidate(
		InteractionScript.Kind.MAILBOX, 2.0)
	var depot: Dictionary = InteractionScript.candidate(InteractionScript.Kind.DEPOT, 1.0)
	assert_gte(InteractionScript.rank_of(InteractionScript.Kind.MAILBOX), 0,
		"a kind outside PRIORITY can never win")
	var winner: Dictionary = InteractionScript.resolve([depot, mailbox] as Array[Dictionary])
	assert_eq(int(winner["kind"]), InteractionScript.Kind.MAILBOX,
		"a small thing in front of a big building wins the ground")


func test_the_mailbox_prompt_names_the_verb_and_carries_no_dash() -> void:
	var prompt: String = InteractionScript.prompt_for(
		InteractionScript.candidate(InteractionScript.Kind.MAILBOX, 1.0), "E")
	assert_true(prompt.contains("mail"))
	assert_false(prompt.contains("--"))
	assert_false(prompt.contains(char(0x2014)))
