extends GutTest
## Tests for the build menu (game/ui/build_menu.gd) -- Phase 1B Task 3.
##
## WHAT THESE ARE REALLY ABOUT: THE MENU IS USABLE WITHOUT A MOUSE. The HUD's hints card
## (game/ui/hud.gd's HINTS) lists a keyboard column and a gamepad column side by side
## because "the build is handed to two people and only one of them is going to be at the
## keyboard", and a build menu that could only be driven by clicking would be the first
## thing in this game one of those two could not use. So every test below drives the menu
## through move_selection()/confirm() -- the exact methods `ui_up`/`ui_down`/`ui_accept`
## route into -- and never through a mouse position, a Button node or a focus grab.
##
## THE SECOND THING THEY GUARD is that the menu never spends anything. It emits
## `plot_chosen`; game/world/ranch.gd checks the wallet, calls PlotSlot.build(), and only
## then spends. A menu that confirmed an unaffordable plot, or that closed without saying
## which plot was picked, would push that transaction into two places -- and two places is
## where "charged but not built" lives.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd.

const BuildMenuScene := preload("res://ui/build_menu.tscn")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const PlotDataScript := preload("res://systems/plot_data.gd")
const PlotRegistryScript := preload("res://systems/plot_registry.gd")

var _menu: BuildMenu = null
var _bits := 0


func before_each() -> void:
	_bits = 0
	_menu = BuildMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.bits_provider = func() -> int: return _bits


func _slot(id: String = "slot_menu") -> PlotSlot:
	var slot: PlotSlot = PlotSlotScript.new()
	slot.slot_id = StringName(id)
	return autofree(slot)


func _built_slot() -> PlotSlot:
	var slot := _slot("slot_taken")
	var plot: PlotData = PlotDataScript.new()
	plot.id = &"pen_test"
	plot.display_name = "Test Pen"
	plot.scene_path = "res://world/pen.tscn"
	plot.capacity = 3
	slot.build(plot)
	return slot


# --- what it offers -----------------------------------------------------------------------

func test_it_lists_the_shipped_catalogue_cheapest_first() -> void:
	var registry: PlotRegistry = PlotRegistryScript.new()
	registry.load_all(PlotRegistryScript.PLOT_DIR)
	var listed := _menu.entries()
	assert_eq(listed.size(), registry.all().size(),
		"the menu shows every plot in game/data/plots/")
	assert_gt(listed.size(), 0, "...and there is at least one")
	for i in range(1, listed.size()):
		assert_lte(listed[i - 1].cost, listed[i].cost, "row %d is not dearer than row %d"
			% [i - 1, i])


func test_the_first_row_is_affordable_from_a_cold_start() -> void:
	# The default selection has to be buildable with the STARTING_BITS a new save has, or
	# the first thing a new player does is press build and be told no.
	_bits = 0
	assert_true(_menu.can_afford(_menu.entries()[0]),
		"the cheapest plot must be affordable with zero bits")


# --- opening ------------------------------------------------------------------------------

func test_it_opens_on_an_empty_slot() -> void:
	var slot := _slot()
	assert_true(_menu.open(slot), "an empty slot has a decision to offer")
	assert_true(_menu.is_open(), "...and the menu is up")
	assert_eq(_menu.get_slot(), slot, "...for that slot")
	assert_eq(_menu.selected_index(), 0, "...with the cheapest row selected")


func test_it_refuses_to_open_on_an_occupied_slot() -> void:
	# Otherwise the player builds a second pen on top of her first one and the slot's
	# build-once rule is bypassed by the only thing that ever calls it.
	var slot := _built_slot()
	assert_false(_menu.open(slot), "there is nothing to choose on a slot that is taken")
	assert_false(_menu.is_open(), "...so nothing came up")


func test_it_refuses_to_open_on_nothing() -> void:
	assert_false(_menu.open(null), "null is not a slot")
	assert_false(_menu.is_open(), "...so nothing came up")


func test_opening_announces_itself_so_the_world_can_stop() -> void:
	# game/world/ranch.gd pauses the tree on this signal. A menu that came up silently would
	# leave the player walking around behind it -- and `ui_down`, which moves the cursor,
	# shares the down arrow with `move_back`.
	watch_signals(_menu)
	var slot := _slot()
	_menu.open(slot)
	assert_signal_emitted(_menu, "opened", "opening must announce itself")
	_menu.close()
	assert_signal_emitted(_menu, "closed", "and so must closing")


func test_closing_a_menu_that_is_not_open_says_nothing() -> void:
	watch_signals(_menu)
	_menu.close()
	assert_signal_not_emitted(_menu, "closed",
		"a close that closed nothing must not tell the ranch to unpause")


# --- navigating without a mouse -------------------------------------------------------------

func test_the_cursor_moves_down_and_wraps() -> void:
	_menu.open(_slot())
	var count: int = _menu.entries().size()
	for i in range(count):
		assert_eq(_menu.selected_index(), i, "step %d" % i)
		_menu.move_selection(1)
	assert_eq(_menu.selected_index(), 0,
		"past the last row it wraps -- on a gamepad, holding down and having nothing " +
		"happen reads as the menu having frozen")


func test_the_cursor_moves_up_from_the_top_to_the_bottom() -> void:
	_menu.open(_slot())
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), _menu.entries().size() - 1,
		"up from the first row lands on the last")


func test_the_selected_plot_follows_the_cursor() -> void:
	_menu.open(_slot())
	var listed := _menu.entries()
	for i in range(listed.size()):
		assert_eq(_menu.selected_plot(), listed[i],
			"selected_plot() is row %d when the cursor is on row %d" % [i, i])
		_menu.move_selection(1)


# --- confirming -----------------------------------------------------------------------------

func test_confirming_an_affordable_plot_names_it_and_closes() -> void:
	watch_signals(_menu)
	var slot := _slot()
	_menu.open(slot)
	_bits = 100000
	var chosen: PlotData = _menu.selected_plot()
	# Both arguments captured off the live signal rather than through GUT's
	# assert_signal_emitted_with_parameters, whose fourth parameter is an emission INDEX and
	# not a message -- passing text there raises inside GUT rather than failing the assert.
	var got := {}
	_menu.plot_chosen.connect(func(plot: PlotData, on_slot: PlotSlot) -> void:
		got["plot"] = plot
		got["slot"] = on_slot)

	assert_true(_menu.confirm(), "an affordable plot is confirmed")
	assert_signal_emitted(_menu, "plot_chosen", "the ranch is told to build")
	assert_eq(got.get("plot"), chosen,
		"the menu says WHICH plot -- the ranch has no other way to know")
	assert_eq(got.get("slot"), slot, "...and WHICH slot")
	assert_false(_menu.is_open(), "...and the menu gets out of the way")


func test_confirming_an_unaffordable_plot_does_nothing_and_stays_open() -> void:
	# STAYS OPEN IS THE POINT. A menu that shut itself when you pressed the button looks
	# exactly like a menu that built something -- the player walks away believing she has a
	# pen. Refusing while still on screen is the only way she finds out.
	watch_signals(_menu)
	_menu.open(_slot())
	_bits = 0
	# Walk to the dearest row, which the cold-start wallet cannot cover.
	var dearest: int = _menu.entries().size() - 1
	_menu.move_selection(dearest)
	assert_gt(_menu.selected_plot().cost, 0, "precondition: the last row costs something")

	assert_false(_menu.confirm(), "you cannot build what you cannot pay for")
	assert_signal_not_emitted(_menu, "plot_chosen", "...and the ranch is not told to build")
	assert_true(_menu.is_open(), "...and the menu is still on screen saying so")


func test_confirming_with_nothing_open_does_nothing() -> void:
	watch_signals(_menu)
	_bits = 100000
	assert_false(_menu.confirm(), "there is no slot to build on")
	assert_signal_not_emitted(_menu, "plot_chosen", "...so nothing is chosen")


func test_an_unwired_menu_can_afford_nothing_but_the_free_plot() -> void:
	# bits() falls back to 0 rather than to "unlimited" when nothing injected a wallet. An
	# unwired menu that let everything through would hand the player a Grand Pen for free
	# and the mistake would look like generosity rather than like a bug.
	var bare: BuildMenu = BuildMenuScene.instantiate()
	add_child_autofree(bare)
	assert_eq(bare.bits(), 0, "no provider means no bits")
	for plot in bare.entries():
		assert_eq(bare.can_afford(plot), plot.cost == 0,
			"'%s' is affordable only if it is free" % String(plot.id))


func test_menu_navigation_actions_have_a_keyboard_and_a_gamepad_binding() -> void:
	# A gamepad playtester reported "I was pressing A and nothing happened, I needed to
	# hit Enter to build the paddock". Root cause: `ui_accept`/`ui_cancel` were NOT
	# overridden in project.godot, and this Godot version's built-in defaults for those
	# two are keyboard-only (Enter/Kp Enter/Space, Escape) with no joypad event -- unlike
	# `ui_up`/`ui_down`, which really do ship both schemes out of the box. The footer this
	# menu draws ("Enter / A  build", "Esc / B  back") was promising a binding that did
	# not exist. Same shape as test_player.gd's
	# test_every_movement_action_has_a_keyboard_and_a_gamepad_binding(), extended to the
	# menu's own navigation actions rather than the movement ones.
	var expectations := {"ui_accept": true, "ui_cancel": true, "ui_up": true, "ui_down": true,
		"ui_left": true, "ui_right": true}
	for action in expectations:
		var has_desktop := false
		var has_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				has_desktop = true
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		assert_true(has_desktop, "'%s' needs a keyboard binding" % action)
		assert_true(has_pad, ("'%s' needs a gamepad binding -- the build is played on a "
			+ "pad too, and a keyboard-only menu action strands that player mid-menu") % action)
