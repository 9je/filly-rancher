extends GutTest
## Tests for buildable plots: the authored plot definitions (game/systems/plot_data.gd),
## the registry that loads them (game/systems/plot_registry.gd), and the slot on the map
## you build one into (game/world/plot_slot.gd). Phase 1B Task 3.
##
## WHAT THIS FILE IS ACTUALLY GUARDING. A slot is the one piece of the build loop that has
## to say NO. "Build" is triggered by walking up to something and pressing a button, which
## is a thing a player does twice by accident all the time -- a double tap, a held button,
## a menu that did not close. A slot that builds twice leaves two pens interpenetrating in
## the same square metre with two separate rosters and one of them unreachable, and it
## charges twice for it. So `build() returns false and changes NOTHING on a slot that is
## already occupied` is asserted on the return value, on `contents`, AND on the child count
## -- because a version that returned false while still instantiating the scene would look
## correct from the outside and be exactly the bug described.
##
## Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd (the class cache lives in the
## gitignored game/.godot/ and a fresh clone has not built it yet).

const PlotDataScript := preload("res://systems/plot_data.gd")
const PlotRegistryScript := preload("res://systems/plot_registry.gd")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const PenScript := preload("res://world/pen.gd")
const LayersScript := preload("res://world/collision_layers.gd")

const PLOT_DIR := "res://data/plots"


## A plot definition built in code rather than loaded, so the slot's rules are tested
## against a value this file controls end to end. `scene_path` still points at the real
## pen scene: "the slot instantiates what the data told it to" is the whole contract, and
## a stub scene here would test a stub.
func _plot(id: String, cost: int, capacity: int) -> PlotData:
	var plot: PlotData = PlotDataScript.new()
	plot.id = StringName(id)
	plot.display_name = id.capitalize()
	plot.cost = cost
	plot.capacity = capacity
	plot.scene_path = "res://world/pen.tscn"
	plot.description = "a test plot"
	return plot


func _slot(id: String = "slot_test") -> PlotSlot:
	var slot: PlotSlot = PlotSlotScript.new()
	slot.slot_id = StringName(id)
	return autofree(slot)


# --- the authored data ---------------------------------------------------------------

func test_the_shipped_plot_catalogue_loads() -> void:
	# game/data/plots/*.tres is committed (unlike game/assets/converted/), so this holds
	# on every machine including CI -- see docs/ci.md section 4.
	var registry: PlotRegistry = PlotRegistryScript.new()
	registry.load_all(PLOT_DIR)
	assert_gt(registry.all().size(), 0, "game/data/plots/ must contain at least one plot")
	for plot in registry.all():
		assert_false(String(plot.id).is_empty(), "every plot needs an id")
		assert_false(plot.display_name.is_empty(),
			"plot '%s' needs a display name -- the build menu shows it" % String(plot.id))
		assert_true(ResourceLoader.exists(plot.scene_path),
			"plot '%s' points at scene '%s', which does not exist"
				% [String(plot.id), plot.scene_path])
		assert_true(plot.cost >= 0, "plot '%s' cannot cost negative bits" % String(plot.id))


func test_at_least_one_plot_is_free_so_a_cold_start_is_not_deadlocked() -> void:
	# THE LOOP HAS TO BE ENTERABLE. GameState.STARTING_BITS is 0 and bits only come from
	# selling gems, which only come from penned ponies, which need a pen. If every plot in
	# the catalogue cost something, a brand new save could never build anything and the
	# whole economy would be unreachable. This is the check that keeps that circular
	# dependency broken -- a retune that puts a price on every pen fails here.
	var registry: PlotRegistry = PlotRegistryScript.new()
	registry.load_all(PLOT_DIR)
	var free_plots := 0
	for plot in registry.all():
		if plot.cost == 0:
			free_plots += 1
	assert_gt(free_plots, 0, "at least one plot must be buildable with zero bits")


func test_the_registry_resolves_by_id_and_returns_null_for_an_unknown_one() -> void:
	var registry: PlotRegistry = PlotRegistryScript.new()
	registry.load_all(PLOT_DIR)
	var first: PlotData = registry.all()[0]
	assert_eq(registry.by_id(first.id), first, "by_id must return the same object")
	assert_null(registry.by_id(&"not_a_real_plot_at_all"),
		"an unknown id resolves to null rather than crashing")


func test_the_registry_orders_plots_cheapest_first_and_deterministically() -> void:
	# The build menu draws this order. A Dictionary's iteration order follows insertion,
	# and insertion follows a directory listing -- so without an explicit sort the menu
	# would silently reorder itself on a machine whose filesystem enumerates differently,
	# and a gamepad player's muscle memory would break between machines.
	var registry: PlotRegistry = PlotRegistryScript.new()
	registry.load_all(PLOT_DIR)
	var costs: Array[int] = []
	for plot in registry.all():
		costs.append(plot.cost)
	var sorted := costs.duplicate()
	sorted.sort()
	assert_eq(costs, sorted, "all() must come back cheapest first")


# --- the slot -------------------------------------------------------------------------

func test_a_fresh_slot_is_empty() -> void:
	var slot := _slot()
	assert_true(slot.is_empty(), "a slot with nothing built on it is empty")
	assert_null(slot.contents, "...and has no contents")
	assert_null(slot.get_built(), "...and no built node")


func test_a_slot_builds_once() -> void:
	var slot := _slot()
	var plot := _plot("pen_test", 0, 3)
	assert_true(slot.build(plot), "the first build succeeds")
	assert_false(slot.is_empty(), "the slot is no longer empty")
	assert_eq(slot.contents, plot, "contents is the plot that was built")
	assert_not_null(slot.get_built(), "...and the scene was actually instantiated")


func test_a_slot_refuses_a_second_build_and_changes_nothing() -> void:
	# See the class comment: the return value alone is not enough to prove this.
	var slot := _slot()
	var first := _plot("pen_first", 0, 3)
	var second := _plot("pen_second", 0, 6)
	assert_true(slot.build(first), "precondition: the first build lands")
	var children_before: int = slot.get_child_count()

	assert_false(slot.build(second), "a second build is refused")
	assert_eq(slot.contents, first, "...and the original plot is still what is there")
	assert_eq(slot.get_child_count(), children_before,
		"...and nothing was instantiated for the refused build")


func test_building_null_is_refused() -> void:
	var slot := _slot()
	assert_false(slot.build(null), "null is not a plot")
	assert_true(slot.is_empty(), "...and the slot stays empty")


func test_building_a_plot_whose_scene_is_missing_is_refused_and_leaves_the_slot_empty() -> void:
	# A hand-edited .tres, or a scene renamed without its data following it. The slot must
	# stay BUILDABLE afterwards rather than being consumed by a build that produced
	# nothing -- otherwise one bad data file permanently bricks a square of the ranch.
	var slot := _slot()
	var broken := _plot("broken", 0, 3)
	broken.scene_path = "res://world/no_such_scene_at_all.tscn"
	assert_false(slot.build(broken), "a plot with no scene cannot be built")
	# LOUDLY. A slot that silently declined would look identical to a slot the player just
	# has not built on yet, and the broken .tres behind it would never be found.
	assert_push_error(1, "a plot pointing at a missing scene must say so")
	assert_true(slot.is_empty(), "...and the slot is still empty")
	assert_true(slot.build(_plot("pen_ok", 0, 3)), "...and still buildable afterwards")


func test_the_slot_configures_what_it_built_from_the_plot_data() -> void:
	# The data-driven half: a small pen and a large pen are the SAME scene with a different
	# number in a .tres. If the slot did not push `capacity` across, adding a pen tier
	# would mean editing pen.gd, which is exactly what the project's "adding content is
	# authoring data, never writing code" rule forbids.
	var slot := _slot("slot_cfg")
	var plot := _plot("pen_big", 0, 7)
	assert_true(slot.build(plot), "precondition")
	var pen: Pen = slot.get_built() as Pen
	assert_not_null(pen, "the pen scene instantiated as a Pen")
	assert_eq(pen.capacity, 7, "capacity came from the plot data, not from pen.gd")
	assert_eq(pen.slot_id, &"slot_cfg", "the pen knows which slot it stands in")


func test_the_slot_watches_for_the_player_and_nothing_else() -> void:
	# An Area3D that monitors ponies would pop the build prompt every time a resident
	# wandered past her own gate.
	var slot := _slot()
	assert_eq(slot.collision_layer, LayersScript.INTERACTION,
		"a slot is an interaction volume")
	assert_eq(slot.collision_mask, LayersScript.PLAYER,
		"...that only notices the player")


func test_a_slot_gets_a_shape_when_it_enters_the_tree() -> void:
	# Built in code rather than authored in ranch.tscn, so four slots cannot drift into
	# four different sizes. An Area3D with no shape never fires body_entered, and that
	# failure is completely invisible -- the prompt just never appears.
	var slot: PlotSlot = PlotSlotScript.new()
	slot.slot_id = &"slot_shape"
	add_child_autofree(slot)
	var shapes: Array = slot.find_children("*", "CollisionShape3D", true, false)
	assert_eq(shapes.size(), 1, "a slot builds itself exactly one trigger shape")
	assert_not_null((shapes[0] as CollisionShape3D).shape, "...with a real shape on it")


## CAN A PEN GO UP HERE, AND IF NOT, WHY NOT -- ASKED BEFORE ANYTHING IS SPENT.
##
## The owner: "finding the right spot to build the paddock can be harder than it should".
## The rule that refused him already existed (a fence may not go up through the body of the
## person who ordered it) but it was only ever spoken AFTER he had walked in, pressed E,
## read a catalogue and chosen a pen. The reason now travels with the candidate, so it is on
## the HUD before the menu opens and the ground under his hooves is coloured for it.
func test_a_clear_plot_will_take_a_pen() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	var outside := Vector3(PlotSlotScript.STAKE_INSET + 1.0, 0.0, 0.0)
	var verdict: Dictionary = slot.placement_check(outside, 0.42)
	assert_true(bool(verdict["ok"]), "she is a metre clear of the markers")
	assert_eq(String(verdict["reason"]), "", "a yes carries no reason")


func test_standing_on_the_footprint_is_refused_with_a_reason_she_can_act_on() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	var verdict: Dictionary = slot.placement_check(Vector3.ZERO, 0.42)
	assert_false(bool(verdict["ok"]))
	assert_false(String(verdict["reason"]).is_empty(),
		"a refusal with no reason is the refusal he already had")
	assert_false(String(verdict["reason"]).contains("--"),
		"no em dash and no double dash in player-facing copy")


## THE BOUNDARY IS THE LINE ON THE GROUND. is_on_footprint() measures against STAKE_INSET,
## which is the same 3.9 m the markers are drawn on and the same 3.9 m Pen.HALF_EXTENT
## stands its fence on, so the line she is asked to step over is a line she can see.
func test_the_refusal_boundary_is_the_marked_square_plus_her_own_width() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	var radius := 0.42
	var just_inside := Vector3(PlotSlotScript.STAKE_INSET + radius - 0.02, 0.0, 0.0)
	var just_outside := Vector3(PlotSlotScript.STAKE_INSET + radius + 0.02, 0.0, 0.0)
	assert_false(bool(slot.placement_check(just_inside, radius)["ok"]))
	assert_true(bool(slot.placement_check(just_outside, radius)["ok"]))


func test_an_occupied_plot_refuses_and_says_which_refusal_it_is() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	var plot := _a_plot()
	assert_not_null(plot, "the catalogue has to have a plot for this test to mean anything")
	assert_true(slot.build(plot))
	var verdict: Dictionary = slot.placement_check(
		Vector3(PlotSlotScript.STAKE_INSET + 2.0, 0.0, 0.0), 0.42)
	assert_false(bool(verdict["ok"]))
	# In the tree, not just newed: is_on_footprint() reads global_transform, which the
	# engine refuses to give a node outside the tree, and that refusal is itself an error
	# GUT would fail this test over.
	var clear_slot: PlotSlot = add_child_autofree(PlotSlotScript.new())
	assert_ne(String(verdict["reason"]),
		String(clear_slot.placement_check(Vector3.ZERO, 0.42)["reason"]),
		"'something is already here' and 'you are standing in it' are different problems")


func test_the_ghost_starts_off_and_a_built_slot_can_never_show_one() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	assert_eq(slot.ghost_state(), PlotSlotScript.Ghost.OFF)
	slot.set_ghost(PlotSlotScript.Ghost.VALID)
	assert_eq(slot.ghost_state(), PlotSlotScript.Ghost.VALID)
	var plot := _a_plot()
	assert_not_null(plot)
	assert_true(slot.build(plot))
	assert_eq(slot.ghost_state(), PlotSlotScript.Ghost.OFF,
		"a pen stands where the ghost stood; two of them would be the thicket again")
	slot.set_ghost(PlotSlotScript.Ghost.VALID)
	assert_eq(slot.ghost_state(), PlotSlotScript.Ghost.OFF,
		"a built slot refuses a ghost outright rather than drawing one inside its own fence")


func test_the_ghost_is_geometry_and_not_a_line_of_text() -> void:
	# The owner's standing note on this project: visual first, no floating text. The reason
	# is a HUD line; what stands on the ground is a coloured footprint.
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	slot.set_ghost(PlotSlotScript.Ghost.REFUSED)
	var ghost := slot.get_node_or_null("PlotGhost")
	assert_not_null(ghost, "the refused state draws something")
	var meshes := ghost.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "and what it draws is meshes")
	for node in ghost.find_children("*", "Label3D", true, false):
		fail_test("a Label3D in the world is exactly the floating text this project bans")


## THE MARKED PLOT IS A SIGN, NOT SCENERY.
##
## Four slots on a 9 m grid, each drawing a closed pale boundary on a 7.8 m square plus four
## 1.05 m corner stakes, all the time, whether anybody is near them or not. A built pen's
## fence stands on the same 3.9 m half extent, so a fence rail and its neighbour's boundary
## board are 1.2 m apart, and the screenshot pass's own 08_pen_built frames a real fence with
## two marked squares receding behind it: four sets of parallel pale lines at 1.2 m spacing.
## The owner, on that picture: "wtf is happening here".
##
## The markers now answer to how near she is. Standing in the clearing she sees the plot she
## is at; from across the map the clearing is grass and one fence.
func test_the_markers_are_solid_when_she_is_standing_in_the_plot() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	slot.set_marker_focus(0.0)
	assert_almost_eq(slot.marker_alpha(), 1.0, 0.001)


## Owner playtest 2026-10-25, "i dont like how hard it is to find the build area": from across
## the yard an empty plot is dimmed, never gone; past MARK_SEEN_METRES it is.
func test_the_markers_are_dimmed_not_gone_from_across_the_clearing() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	slot.set_marker_focus(PlotSlotScript.MARK_FAR_METRES + 20.0)
	assert_almost_eq(slot.marker_alpha(), PlotSlotScript.MARK_FLOOR_ALPHA, 0.001,
		"an empty plot can be seen from the plaza")
	slot.set_marker_focus(PlotSlotScript.MARK_SEEN_METRES + 1.0)
	assert_almost_eq(slot.marker_alpha(), 0.0, 0.001, "and is gone from across the valley")


func test_the_markers_fade_rather_than_snap() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	var previous := 2.0
	var seen := 0
	var d := 0.0
	while d <= PlotSlotScript.MARK_FAR_METRES + 2.0:
		slot.set_marker_focus(d)
		var here: float = slot.marker_alpha()
		assert_lte(here, previous + 0.001, "the markers got brighter as she walked away")
		previous = here
		seen += 1
		d += 0.5
	assert_gt(seen, 20, "the sweep has to actually walk the range it claims to")


## THE NEIGHBOUR SPACING, WHICH IS THE WHOLE PICTURE. The far cutoff has to be tight enough
## that standing in one plot does not light the next one 9 m away, or the fade buys nothing.
func test_standing_in_one_plot_does_not_light_the_next_one() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	slot.set_marker_focus(9.0)
	assert_almost_eq(slot.marker_alpha(), PlotSlotScript.MARK_FLOOR_ALPHA, 0.001,
		"the slots are on a 9 m grid and only the one she is in is lit full")


func test_a_built_slot_carries_no_marker_geometry_at_all() -> void:
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	assert_gt(slot.marker_mesh_count(), 0, "an empty slot is marked")
	var plot := _a_plot()
	assert_not_null(plot)
	assert_true(slot.build(plot))
	assert_eq(slot.marker_mesh_count(), 0,
		"a fence stands where the markers stood; both at once is the reported picture")


func test_building_and_demolishing_never_stacks_a_second_set_of_markers() -> void:
	# The boot-time containment probe builds a pen on slot 0 and takes it down again
	# (game/world/ranch.gd _probe_pen_containment). A refresh that created a new marker node
	# without disposing of the old one would leave two coincident sets, z fighting, forever.
	var slot := PlotSlotScript.new()
	add_child_autofree(slot)
	var plot := _a_plot()
	assert_not_null(plot)
	var baseline: int = slot.marker_mesh_count()
	assert_gt(baseline, 0)
	for i in range(3):
		assert_true(slot.build(plot))
		assert_true(slot.demolish())
	assert_eq(slot.marker_mesh_count(), baseline,
		"three build and demolish cycles left exactly one set of markers")


func _a_plot() -> PlotData:
	var registry = load("res://systems/plot_registry.gd").new()
	registry.load_all(load("res://systems/plot_registry.gd").PLOT_DIR)
	var all: Array = registry.all()
	return all[0] if not all.is_empty() else null


## PLAYTEST 2026-11-10 ITEM 29: a townspony standing on the plot was fenced into the new pen.
## Building steps her out past the nearest fence; one standing clear of it is left alone.
func test_building_a_pen_steps_a_townspony_out_of_its_footprint() -> void:
	var slot := _slot()
	add_child(slot)
	var inside := CharacterBody3D.new()
	inside.add_to_group(&"townsfolk")
	add_child_autofree(inside)
	inside.global_position = Vector3(1.0, 0.0, 0.5)
	var outside := CharacterBody3D.new()
	outside.add_to_group(&"townsfolk")
	add_child_autofree(outside)
	outside.global_position = Vector3(12.0, 0.0, 0.0)
	assert_true(slot.build(_plot("paddock", 0, 3)))
	var half := PenScript.HALF_EXTENT
	var p := inside.global_position
	assert_true(absf(p.x) > half or absf(p.z) > half,
		"she is still inside the fence at %s" % str(p))
	assert_almost_eq(p.x, half + PlotSlotScript.BYSTANDER_GAP, 0.01, "out past the nearest (+X) fence")
	assert_eq(outside.global_position, Vector3(12.0, 0.0, 0.0), "a pony clear of the plot is left be")
