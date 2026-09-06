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
const PlotSlotScript := preload("res://world/plot_slot.gd")


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


## THE TWO PLOT VERBS ARE ONE TIER, AND THE OWNER PAID FOR THIS LINE.
##
## The four slots are 9 m apart and a slot holds the player until her centre is 4.77 m out
## (TRIGGER_HALF 4.35 plus her 0.42 capsule). Pressed against a built pen's gate her centre
## is 4.40 m from that pen and 4.60 m from the empty slot behind her, so she is standing in
## both triggers at once. While PLOT_BUILD outranked PEN_MOVE_IN outright, E opened the
## build menu for the plot 20 cm further away instead of pennning the pony in her bag:
## "when i place ponies in the paddock i press e several times and that sound is terrible"
## -- the sound being the build menu's own open and back ticks, once per press.
func test_the_pen_at_your_feet_beats_the_empty_plot_behind_you() -> void:
	var chosen: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.PLOT_BUILD, 4.60, "Slot2"),
		InteractionScript.candidate(InteractionScript.Kind.PEN_MOVE_IN, 4.40, "Buttercup"),
	])
	assert_eq(int(chosen["kind"]), InteractionScript.Kind.PEN_MOVE_IN,
		"the nearer of the two squares of ground she is standing in wins")
	assert_eq(String(chosen["subject"]), "Buttercup")


func test_the_empty_plot_you_are_standing_in_still_beats_the_pen_next_door() -> void:
	# The mirror, and it is the case the tier must not break: walk into an empty plot to
	# build and the pen 4.5 m away does not steal the press.
	var chosen: Dictionary = InteractionScript.resolve([
		InteractionScript.candidate(InteractionScript.Kind.PLOT_BUILD, 0.30, "Slot2"),
		InteractionScript.candidate(InteractionScript.Kind.PEN_MOVE_IN, 4.50, "Buttercup"),
	])
	assert_eq(int(chosen["kind"]), InteractionScript.Kind.PLOT_BUILD)
	assert_eq(String(chosen["subject"]), "Slot2")


func test_both_plot_verbs_share_one_rank() -> void:
	assert_eq(InteractionScript.rank_of(InteractionScript.Kind.PLOT_BUILD),
		InteractionScript.rank_of(InteractionScript.Kind.PEN_MOVE_IN),
		"same tier, so resolve() settles them on distance and nothing else")


## The tier must not have flattened anything ELSE. Ground you stand on still beats ground
## you stand near, at any distance, which is the doctrine PRIORITY's own comment states.
func test_the_ground_tier_still_beats_every_building() -> void:
	for building: int in [InteractionScript.Kind.MARKET, InteractionScript.Kind.BOARD,
			InteractionScript.Kind.MAILBOX, InteractionScript.Kind.DEPOT,
			InteractionScript.Kind.PALACE]:
		for ground: int in InteractionScript.GROUND_TIER:
			var chosen: Dictionary = InteractionScript.resolve([
				InteractionScript.candidate(building, 0.10),
				InteractionScript.candidate(ground, 4.70),
			])
			assert_eq(int(chosen["kind"]), ground,
				"kind %d beat the ground she is standing on" % building)


func test_the_ground_tier_is_not_empty_and_is_ranked() -> void:
	assert_gt(InteractionScript.GROUND_TIER.size(), 1,
		"a tier of one is not a tier and this whole change would be a no-op")
	for kind: int in InteractionScript.GROUND_TIER:
		assert_gte(InteractionScript.rank_of(kind), 0,
			"a tier member outside PRIORITY can never win anything")


## THE WORLD HALF. A pure resolver that is right about dictionaries nobody hands it is a
## pure resolver that is right about nothing -- this file's own class comment says so. This
## stands the player where the playtest stood her: at the gate of a built pen, with the
## empty slot next door inside her reach.
func test_at_a_built_pen_s_gate_the_ranch_offers_the_pen() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_frames(2)
	var slots: Array = ranch.plot_slots()
	assert_gt(slots.size(), 1, "the map has to have at least two slots for this to mean anything")
	var built = slots[0]
	var registry = ranch.get_node("/root/GameState").get_registry() \
		if ranch.has_node("/root/GameState") else null
	var catalogue = ranch.call("_plots_catalogue")
	var plot = catalogue.all()[0]
	assert_true(built.build(plot), "the first slot has to take a pen for this test to mean anything")
	await wait_physics_frames(2)
	# Her centre 4.40 m out from the built slot, on the axis pointing at its neighbour.
	var toward: Vector3 = (slots[1].global_position - built.global_position).normalized()
	ranch.player.global_position = built.global_position + toward * 4.40 + Vector3.UP * 0.3
	await wait_physics_frames(4)
	var kinds: Array[int] = []
	for entry: Dictionary in ranch.interaction_candidates():
		kinds.append(int(entry["kind"]))
	assert_true(kinds.has(InteractionScript.Kind.PEN_MOVE_IN),
		"she is standing at the pen, so the pen must be on offer")
	var chosen: Dictionary = ranch.current_interaction()
	assert_eq(int(chosen.get("kind", -1)), InteractionScript.Kind.PEN_MOVE_IN,
		"the nearer square of ground she is standing in is the one E means")


## THE GHOST, THE PROMPT AND THE REFUSAL ARE ONE ANSWER. Three places used to be able to
## disagree about whether a pen could go up: the prompt said "build here" unconditionally,
## the ground said nothing at all, and the refusal arrived after the catalogue had been read
## and a pen chosen. This drives the real ranch and asks all three at once.
func test_standing_in_the_middle_of_an_empty_plot_says_no_three_ways() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	# _update_interaction() (and the ghost paint inside it) only runs while _interactive is
	# true, which _ready() sets from DisplayServer.get_name() -- false under every headless
	# test run. Overridden the same way test_ranch_creation.gd's _ranch_with_screen() does,
	# so the physics frames below actually drive the seam this test is asking about.
	ranch._interactive = true
	await wait_frames(2)
	var slots: Array = ranch.plot_slots()
	assert_gt(slots.size(), 0)
	var slot = slots[0]
	assert_true(slot.is_empty(), "the probe takes its own pen back down before this runs")
	ranch.player.global_position = slot.global_position + Vector3.UP * 0.3
	await wait_physics_frames(4)
	var chosen: Dictionary = ranch.current_interaction()
	assert_eq(int(chosen.get("kind", -1)), InteractionScript.Kind.PLOT_BUILD)
	assert_false(String(chosen.get("reason", "")).is_empty(),
		"she is standing where the fence goes, and the candidate knows it")
	assert_true(InteractionScript.prompt_for(chosen, "E").contains("cannot build"),
		"and the line on the HUD says so before she presses anything")
	assert_eq(slot.ghost_state(), slot.Ghost.REFUSED,
		"and the ground under her hooves is red")
	# Step out past the markers and all three flip together.
	var out_dir: Vector3 = (ranch.player.global_position - slot.global_position)
	ranch.player.global_position = slot.global_position \
		+ Vector3(0.0, 0.3, PlotSlotScript.STAKE_INSET + 0.6)
	await wait_physics_frames(4)
	var now: Dictionary = ranch.current_interaction()
	assert_eq(int(now.get("kind", -1)), InteractionScript.Kind.PLOT_BUILD)
	assert_true(String(now.get("reason", "")).is_empty())
	assert_eq(slot.ghost_state(), slot.Ghost.VALID)
