extends GutTest
## PLAYTEST 2026-11-05 ITEM 62, in the owner's words: 'Depot statement: "Quota 31 of 2",
## still "cycle 1" and "collections passed 0" after a long session [50].'
##
## THE CAUSE, read off the owner's own save: 3392 s of play, 1647 s on the world clock. The
## clock stopped under every menu (the Palace's tables, the Depot, the Market, the build
## menu, the letters), because those pause the tree and the clock ticks in the ranch's
## _physics_process. Half the session was spent at the tables and the counters, so the day
## never got past cycle 1, the first collection (cycle 3) never came, and the quota never
## reset. Now the time spent in a menu is put back on the clock when it closes (not for the
## pause menu: a pause is a pause).

const RanchScene := preload("res://world/ranch.tscn")
const LedgerScript := preload("res://systems/ledger.gd")
const WorldStateScript := preload("res://systems/world_state.gd")


func _ranch() -> Node:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	for i in 600:
		if bool(ranch.get("boot_done")):
			break
		await wait_physics_frames(1)
	assert_true(bool(ranch.get("boot_done")), "the ranch finished booting")
	# A new game opens the creator and then the welcome letter; neither is under test.
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	get_tree().paused = false
	return ranch


## Played time spent with a menu up: opened, held for `seconds` of real time, closed.
## Real time is not waited out; the opening instant is moved back instead.
func _sit_in(ranch: Node, menu: CanvasLayer, seconds: float) -> void:
	assert_true(bool(menu.call("open")), "the menu opens")
	ranch.set("_menu_opened_msec", int(ranch.get("_menu_opened_msec")) - int(seconds * 1000.0))
	menu.call("close")


func test_time_at_the_tables_and_the_counter_is_time_on_the_clock() -> void:
	var ranch = await _ranch()
	ranch.set("_interactive", true)
	var world: WorldState = ranch.call("get_world_state")
	var before := world.elapsed()
	await _sit_in(ranch, ranch.get("depot_menu"), 29.0 * 60.0)
	ranch.set("_interactive", false)
	assert_almost_eq(world.elapsed() - before, 29.0 * 60.0, 2.0,
		"29 minutes at the Depot are 29 minutes of the day, not none")


func test_the_pause_menu_still_stops_the_clock() -> void:
	var ranch = await _ranch()
	ranch.set("_interactive", true)
	var world: WorldState = ranch.call("get_world_state")
	var before := world.elapsed()
	var pause: CanvasLayer = ranch.get("pause_menu")
	assert_true(bool(pause.call("open")), "the pause menu opens")
	ranch.set("_menu_opened_msec", int(ranch.get("_menu_opened_msec")) - 600000)
	pause.call("close")
	ranch.set("_interactive", false)
	assert_almost_eq(world.elapsed(), before, 0.5, "paused is paused")


func test_after_a_long_session_the_statement_has_moved_on() -> void:
	# An hour of play, half of it at the Palace and the Depot, as the owner's was, with 31
	# ponies delivered in the first period.
	var ranch = await _ranch()
	ranch.set("_interactive", true)
	var gs: Node = ranch.get("_game_state")
	for i in 31:
		gs.ledger.credit_delivery(0, true)
	for minute in 30:
		ranch.call("advance_world", 60.0)
		await _sit_in(ranch, ranch.get("depot_menu"), 60.0)
	ranch.set("_interactive", false)
	var world: WorldState = ranch.call("get_world_state")
	assert_gte(world.cycle_index(), 3, "an hour of play is three cycles, wherever she spent it")
	var lines: String = "\n".join(ranch.call("_statement"))
	assert_true(lines.contains("Collections passed: 1"),
		"the first collection has come and gone:\n" + lines)
	assert_false(lines.contains("31 of 2"), "no 'Quota 31 of 2':\n" + lines)
	assert_false(lines.contains("cycle 1"), "not still cycle 1:\n" + lines)


func test_a_new_account_does_not_read_collections_passed_zero() -> void:
	var l := LedgerScript.new()
	var lines: String = "\n".join(l.statement_lines("Jordan", 4, 2, 1))
	assert_false(lines.contains("Collections passed: 0"),
		"before the first collection the statement says when it comes, not 'passed: 0':\n" + lines)
	assert_true(lines.contains("First collection"), "it names the first one:\n" + lines)
	l.delivered_this_period = 31
	lines = "\n".join(l.statement_lines("Jordan", 4, 2, 1))
	assert_false(lines.contains("31 of 2"), "no 'Quota 31 of 2':\n" + lines)
