extends GutTest
## OWNER PLAYTEST 2026-10-25, note 1: "basically its super easy to catch ponies so you can
## collect all the spots before you get upgrades". All four plots were open from minute one
## and a Paddock is free, so his save had a free Paddock on three of them by 11.6 minutes.
##
## Two plots start open; slot_3 and slot_4 start OVERGROWN (ranch.gd PLOT_CLEAR_COSTS) and
## cost bits to clear. A save that already built on them keeps its pens.

const RanchScene := preload("res://world/ranch.tscn")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const PlotRegistryScript := preload("res://systems/plot_registry.gd")
const InteractionScript := preload("res://world/interaction.gd")
const BuildMenuScene := preload("res://ui/build_menu.tscn")


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


func _slot(ranch: Node, id: String) -> PlotSlot:
	for s in ranch.plot_slots():
		if String(s.slot_id) == id:
			return s
	return null


func test_a_new_ranch_has_two_open_plots_and_two_overgrown() -> void:
	var ranch = await _ranch()
	var open := 0
	var wild := 0
	for s in ranch.plot_slots():
		if s.is_overgrown():
			wild += 1
		elif s.is_empty():
			open += 1
	assert_eq(open, 2, "two plots to build on from the start")
	assert_eq(wild, 2, "and two to clear")
	assert_true(_slot(ranch, "slot_3").is_overgrown())
	assert_true(_slot(ranch, "slot_4").is_overgrown())
	assert_lt(_slot(ranch, "slot_3").clear_cost(), 150,
		"the third plot is cheaper than the first upgrade: the first real choice")
	assert_gt(_slot(ranch, "slot_4").clear_cost(), 150,
		"the fourth is dearer than either: the mid-game goal")


func test_an_overgrown_plot_refuses_a_build() -> void:
	var r: PlotRegistry = PlotRegistryScript.new()
	r.load_all(PlotRegistryScript.PLOT_DIR)
	var slot: PlotSlot = PlotSlotScript.new()
	add_child_autofree(slot)
	slot.set_overgrown(true, 100)
	assert_false(slot.build(r.by_id(&"pen_small")), "brambles first")
	assert_true(slot.is_empty())
	assert_false(bool(slot.placement_check(Vector3(20, 0, 0), 0.4)["ok"]))
	assert_eq(slot.marker_mesh_count(), 0, "no build markers under the brambles")
	assert_not_null(slot.find_child("Brambles", false, false), "the thicket is drawn")
	slot.set_overgrown(false)
	assert_null(slot.find_child("Brambles", false, false), "and cleared away")
	assert_true(slot.build(r.by_id(&"pen_small")), "then it is a plot like any other")


func test_a_built_slot_cannot_be_overgrown() -> void:
	var r: PlotRegistry = PlotRegistryScript.new()
	r.load_all(PlotRegistryScript.PLOT_DIR)
	var slot: PlotSlot = PlotSlotScript.new()
	add_child_autofree(slot)
	slot.build(r.by_id(&"pen_small"))
	slot.set_overgrown(true, 100)
	assert_false(slot.is_overgrown(), "a pen keeps its ground")


func test_the_prompt_says_clear_and_the_price() -> void:
	var c := InteractionScript.priced(InteractionScript.Kind.PLOT_CLEAR, 1.0, "Slot3", 100, true)
	assert_eq(InteractionScript.prompt_for(c, "E"), "E: clear, 100 bits")
	c["afford"] = false
	assert_eq(InteractionScript.prompt_for(c, "E"),
		"E: clear, 100 bits (need more)")


func test_standing_on_an_overgrown_plot_offers_the_clearing() -> void:
	var ranch = await _ranch()
	var slot := _slot(ranch, "slot_3")
	ranch.player.global_position = slot.global_position + slot.global_basis.x * 4.5 \
		+ Vector3(0, 0.3, 0)
	await wait_physics_frames(3)
	var act: Dictionary = ranch.current_interaction()
	assert_eq(int(act.get("kind", 0)), InteractionScript.Kind.PLOT_CLEAR, "%s" % act)
	assert_eq(int(act.get("price", 0)), slot.clear_cost())


func test_clearing_spends_and_is_remembered() -> void:
	var ranch = await _ranch()
	var slot := _slot(ranch, "slot_3")
	var econ = ranch.get_economy()
	econ.grant(500)
	var before: int = econ.bits
	ranch.call("_on_clear_chosen", slot, slot.clear_cost())
	assert_false(slot.is_overgrown())
	assert_eq(econ.bits, before - 115)
	var gs = ranch.get("_game_state")
	assert_true(gs.story.has_flag("plot_cleared_slot_3"), "a save remembers it")
	ranch.call("_apply_overgrowth")
	assert_false(slot.is_overgrown(), "and a reload does not grow it back")


func test_an_unaffordable_clearing_costs_nothing() -> void:
	var ranch = await _ranch()
	var slot := _slot(ranch, "slot_4")
	var econ = ranch.get_economy()
	var before: int = econ.bits
	ranch.call("_on_clear_chosen", slot, slot.clear_cost())
	assert_true(slot.is_overgrown())
	assert_eq(econ.bits, before)
	assert_string_contains(String(ranch.last_denial()["text"]), "Not enough bits")


func test_an_old_save_with_pens_on_plots_three_and_four_keeps_them() -> void:
	var ranch = await _ranch()
	var gs = ranch.get("_game_state")
	var s3 := _slot(ranch, "slot_3")
	var s4 := _slot(ranch, "slot_4")
	# What an old save's restore does: the slots come back built from GameState.plots.
	gs.plots = {"slot_3": "pen_large", "slot_4": "pen_small"}
	ranch.call("_restore_plots")
	ranch.call("_apply_overgrowth")
	assert_eq(s3.saved_plot_id(), "pen_large", "the Big Pen on plot 3 is still there")
	assert_eq(s4.saved_plot_id(), "pen_small", "and the Paddock on plot 4")
	assert_false(s3.is_overgrown())
	assert_true(gs.story.has_flag("plot_cleared_slot_3"), "and the ground is hers")
	assert_true(gs.story.has_flag("plot_cleared_slot_4"))


func test_the_clear_card_opens_on_an_overgrown_plot() -> void:
	var menu = BuildMenuScene.instantiate()
	add_child_autofree(menu)
	_bits = 0
	menu.bits_provider = func() -> int: return _bits
	var slot: PlotSlot = PlotSlotScript.new()
	add_child_autofree(slot)
	slot.set_overgrown(true, 100)
	assert_false(menu.open(slot), "nothing to build on brambles")
	assert_true(menu.open_clear(slot, 100))
	watch_signals(menu)
	assert_false(menu.confirm(), "no bits, no clearing")
	assert_signal_not_emitted(menu, "clear_chosen")
	_bits = 100
	assert_true(menu.confirm())
	assert_signal_emitted_with_parameters(menu, "clear_chosen", [slot, 100])
