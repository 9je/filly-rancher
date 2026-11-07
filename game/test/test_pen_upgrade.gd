extends GutTest
## OWNER PLAYTEST 2026-10-25, notes 2 and 4: "how do i upgrade my free paddock to the 150
## bits one not clear", and a save that hit "That pen is full." with all four plots taken.
##
## A built pen can be upgraded IN PLACE, Paddock -> Big Pen -> Grand Pen, for the difference
## in list price, keeping every resident. The verb is offered at the pen itself whenever
## moving a pony in is not what E can do (an empty saddlebag, or a full pen), it is named on
## the prompt with its price, and "not enough bits" is said before the key is pressed.

const RanchScene := preload("res://world/ranch.tscn")
const BuildMenuScene := preload("res://ui/build_menu.tscn")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const PlotRegistryScript := preload("res://systems/plot_registry.gd")
const InteractionScript := preload("res://world/interaction.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")


func _catalogue() -> PlotRegistry:
	var r: PlotRegistry = PlotRegistryScript.new()
	r.load_all(PlotRegistryScript.PLOT_DIR)
	return r


var _shared: Node = null
var _bits := 0


func before_all() -> void:
	_shared = RanchScene.instantiate()
	add_child(_shared)
	await wait_for_signal(_shared.gate_report_finished, 180.0)


func after_all() -> void:
	if _shared != null:
		_shared.free()
		_shared = null


## ONE RANCH PER FILE, put back to a new ranch's ground before each test: a full boot per
## test would cost minutes. Every pen down (residents out first: NO PONY EVER DIES applies
## to test bookkeeping too), the bag emptied, the wallet zeroed, the brambles regrown.
func _ranch() -> Node:
	var ranch := _shared
	for s in ranch.plot_slots():
		var pen = s.get_built()
		if pen != null:
			for p in pen.ponies():
				pen.remove_pony(p.uid)
			s.demolish()
	var bag = ranch.player.get_magic_beam().get_storage()
	while bag.peek() != null:
		bag.release()
	var gs = ranch.get("_game_state")
	for k in gs.story.flags.keys():
		if String(k).begins_with("plot_cleared_"):
			gs.story.set_flag(String(k), false)
	gs.plots = {}
	ranch.call("_apply_overgrowth")
	ranch.get_economy().bits = 0
	await wait_physics_frames(2)
	return ranch


# --- the data ------------------------------------------------------------------------------

func test_the_pens_form_an_upgrade_ladder() -> void:
	var r := _catalogue()
	var small := r.by_id(&"pen_small")
	var large := r.by_id(&"pen_large")
	var grand := r.by_id(&"pen_grand")
	assert_eq(small.upgrades_to, &"pen_large", "a Paddock grows into a Big Pen")
	assert_eq(large.upgrades_to, &"pen_grand", "a Big Pen grows into a Grand Pen")
	assert_eq(grand.upgrades_to, &"", "a Grand Pen is the top")
	assert_eq(small.upgrade_price(large), 175, "Paddock to Big Pen is the Big Pen's own 175")
	assert_eq(large.upgrade_price(grand), 375, "Big Pen to Grand Pen is the difference, 375")


# --- the slot ------------------------------------------------------------------------------

func test_upgrading_keeps_the_residents_and_raises_the_capacity() -> void:
	var r := _catalogue()
	var slot: PlotSlot = PlotSlotScript.new()
	slot.slot_id = &"slot_up"
	add_child_autofree(slot)
	assert_true(slot.build(r.by_id(&"pen_small")))
	var pen = slot.get_built()
	var kept: Array = []
	while not pen.is_full():
		var p = PonyInstanceScript.create(&"twilight")
		kept.append(p.uid)
		pen.add_pony(p)
	assert_eq(pen.count(), 3)
	assert_true(slot.upgrade(r.by_id(&"pen_large")), "a Paddock upgrades to a Big Pen")
	assert_eq(slot.get_built(), pen, "the same pen, not a rebuilt one")
	assert_eq(pen.capacity, 6)
	assert_false(pen.is_full(), "and there is room again")
	for uid in kept:
		assert_true(pen.has_pony(uid), "every resident stayed")
	assert_eq(slot.saved_plot_id(), "pen_large", "and a save records the Big Pen")


func test_an_upgrade_must_be_the_next_size() -> void:
	var r := _catalogue()
	var slot: PlotSlot = PlotSlotScript.new()
	add_child_autofree(slot)
	assert_false(slot.upgrade(r.by_id(&"pen_large")), "nothing to upgrade on an empty slot")
	slot.build(r.by_id(&"pen_small"))
	assert_false(slot.upgrade(r.by_id(&"pen_grand")), "no skipping a size")
	assert_eq(slot.saved_plot_id(), "pen_small", "and a refused upgrade changes nothing")


# --- the prompt ----------------------------------------------------------------------------

func test_the_prompt_names_the_upgrade_and_its_price() -> void:
	var c := InteractionScript.priced(InteractionScript.Kind.PEN_UPGRADE, 1.0, "Slot1", 150,
		true, "Big Pen")
	assert_eq(InteractionScript.prompt_for(c, "E"), "E: upgrade to Big Pen (150 bits)")
	var poor := InteractionScript.priced(InteractionScript.Kind.PEN_UPGRADE, 1.0, "Slot1", 150,
		false, "Big Pen", true)
	assert_eq(InteractionScript.prompt_for(poor, "E"),
		"E: pen full, upgrade to Big Pen (150 bits), not enough bits")


func test_a_full_top_size_pen_says_what_to_do() -> void:
	var c := InteractionScript.candidate(InteractionScript.Kind.PEN_MOVE_IN, 1.0, "Fluttershy")
	c["full"] = true
	assert_eq(InteractionScript.prompt_for(c, "E"), "E: this pen is full, build another pen")


func test_the_upgrade_is_ground_like_the_pen() -> void:
	assert_eq(InteractionScript.rank_of(InteractionScript.Kind.PEN_UPGRADE),
		InteractionScript.rank_of(InteractionScript.Kind.PEN_MOVE_IN))
	assert_eq(InteractionScript.rank_of(InteractionScript.Kind.PLOT_CLEAR),
		InteractionScript.rank_of(InteractionScript.Kind.PLOT_BUILD))


# --- the ranch -----------------------------------------------------------------------------

func _stand_in(ranch: Node, slot: PlotSlot) -> void:
	# Just outside the gate, inside the trigger: where a player stands to use the pen.
	ranch.player.global_position = slot.global_position + slot.global_basis.x * 4.4 \
		+ Vector3(0, 0.3, 0)
	await wait_physics_frames(3)


func test_an_empty_bag_at_a_paddock_offers_the_upgrade() -> void:
	var ranch = await _ranch()
	var slot: PlotSlot = ranch.plot_slots()[0]
	assert_true(slot.build(ranch.plots_catalogue().by_id(&"pen_small")))
	await _stand_in(ranch, slot)
	var act: Dictionary = ranch.current_interaction()
	assert_eq(int(act.get("kind", 0)), InteractionScript.Kind.PEN_UPGRADE,
		"with nothing in the bag, E at the Paddock is the upgrade: %s" % act)
	assert_eq(int(act.get("price", 0)), 175)
	assert_eq(String(act.get("what", "")), "Big Pen")


func test_a_pony_in_the_bag_and_room_still_moves_her_in() -> void:
	var ranch = await _ranch()
	var slot: PlotSlot = ranch.plot_slots()[0]
	slot.build(ranch.plots_catalogue().by_id(&"pen_small"))
	ranch.player.get_magic_beam().get_storage().store(PonyInstanceScript.create(&"twilight"))
	await _stand_in(ranch, slot)
	assert_eq(int(ranch.current_interaction().get("kind", 0)),
		InteractionScript.Kind.PEN_MOVE_IN, "penning her is still the first thing E does")


func test_a_full_paddock_with_a_pony_in_the_bag_offers_the_upgrade() -> void:
	var ranch = await _ranch()
	var slot: PlotSlot = ranch.plot_slots()[0]
	slot.build(ranch.plots_catalogue().by_id(&"pen_small"))
	await wait_physics_frames(2)
	var pen = slot.get_built()
	while not pen.is_full():
		pen.add_pony(PonyInstanceScript.create(&"twilight"))
	ranch.player.get_magic_beam().get_storage().store(PonyInstanceScript.create(&"twilight"))
	await _stand_in(ranch, slot)
	var act: Dictionary = ranch.current_interaction()
	assert_eq(int(act.get("kind", 0)), InteractionScript.Kind.PEN_UPGRADE)
	assert_true(bool(act.get("full", false)), "and the prompt says the pen is full")


func test_buying_the_upgrade_spends_the_difference_and_keeps_her() -> void:
	var ranch = await _ranch()
	var slot: PlotSlot = ranch.plot_slots()[0]
	var cat = ranch.plots_catalogue()
	slot.build(cat.by_id(&"pen_small"))
	await wait_physics_frames(2)
	var pen = slot.get_built()
	var her = PonyInstanceScript.create(&"twilight")
	pen.add_pony(her)
	var econ = ranch.get_economy()
	econ.grant(200)
	var before: int = econ.bits
	ranch.call("_on_upgrade_chosen", cat.by_id(&"pen_large"), slot, 150)
	assert_eq(econ.bits, before - 150, "150 bits spent")
	assert_eq(slot.saved_plot_id(), "pen_large")
	assert_true(pen.has_pony(her.uid), "she still lives there")


func test_an_unaffordable_upgrade_costs_nothing_and_says_so() -> void:
	var ranch = await _ranch()
	var slot: PlotSlot = ranch.plot_slots()[0]
	var cat = ranch.plots_catalogue()
	slot.build(cat.by_id(&"pen_small"))
	var econ = ranch.get_economy()
	var before: int = econ.bits
	assert_lt(before, 150, "a new ranch cannot afford it")
	ranch.call("_on_upgrade_chosen", cat.by_id(&"pen_large"), slot, 150)
	assert_eq(econ.bits, before)
	assert_eq(slot.saved_plot_id(), "pen_small")
	assert_string_contains(String(ranch.last_denial()["text"]), "Not enough bits")


func test_a_full_pen_refusal_says_what_to_do() -> void:
	var ranch = await _ranch()
	var slot: PlotSlot = ranch.plot_slots()[0]
	slot.build(ranch.plots_catalogue().by_id(&"pen_small"))
	await wait_physics_frames(2)
	var pen = slot.get_built()
	while not pen.is_full():
		pen.add_pony(PonyInstanceScript.create(&"twilight"))
	ranch.player.get_magic_beam().get_storage().store(PonyInstanceScript.create(&"twilight"))
	assert_false(ranch.call("_move_pony_into_pen", slot))
	assert_eq(String(ranch.last_denial()["text"]),
		"That pen is full. Upgrade it, or build another pen.")


# --- the card ------------------------------------------------------------------------------

func test_the_build_menu_opens_an_upgrade_card_on_a_built_pen() -> void:
	var menu = BuildMenuScene.instantiate()
	add_child_autofree(menu)
	_bits = 40
	menu.bits_provider = func() -> int: return _bits
	var r := _catalogue()
	var slot: PlotSlot = PlotSlotScript.new()
	add_child_autofree(slot)
	slot.build(r.by_id(&"pen_small"))
	assert_true(menu.open_upgrade(slot, r.by_id(&"pen_small"), r.by_id(&"pen_large"), 150))
	assert_eq(menu.entries().size(), 1, "one card: the next size")
	assert_eq(menu.selected_plot().id, &"pen_large")
	assert_eq(menu.price_at(0), 150)
	watch_signals(menu)
	assert_false(menu.confirm(), "40 bits does not buy a 150 bit upgrade")
	assert_signal_not_emitted(menu, "upgrade_chosen")
	var short: Label = menu.row_nodes()[0].find_child("Short", true, false)
	assert_true(short.visible, "the card itself says not enough bits")
	assert_string_contains(short.text, "110 more")
	_bits = 200
	assert_true(menu.confirm())
	assert_signal_emitted_with_parameters(menu, "upgrade_chosen", [r.by_id(&"pen_large"), slot, 150])
