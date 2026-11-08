extends SceneTree
## The Depot at the owner's screenshot spots (playtest 2026-11-05 items 62 and 63):
##   --mode=statement  the Statement tab after an hour of play, half of it spent in menus,
##                     with 31 delivered in the first period [50]
##   --mode=statement_first  the same 31 delivered at cycle 1, before the first collection
##   --mode=colour     P8: blank and Bloomed Drifters, two stallions, one toast, the quota card
##   --mode=deliver    the Deliver tab over four Grand Pens holding the owner's roster as his
##                     save had it, two Sweetie Belles and two Scootaloos included [51]
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/depot_shot.gd -- --out=/abs/dir --mode=statement
const BootIntentScript := preload("res://world/boot_intent.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
var out := ""
var mode := "statement"

## The named ponies penned in the owner's save of 2026-11-05 (slot_0.json), in pen order.
const OWNER_PENS: Array = [
	["twilight", "scootaloo", "rarity", "fluttershy", "berrypunch", "rarity", "sweetiebelle"],
	["sweetiebelle", "scootaloo", "vinylscratch", "octavia"],
	["lotusblossom", "bonbon", "soarin", "milkyway", "cocopommel"],
	["carrottop", "rainbowdash"],
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--mode="):
			mode = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and bool(ranch.get("boot_done")) and i > 30:
			break
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	# xvfb's pointer sits at the screen centre and would hover a tile.
	var away := InputEventMouseMotion.new()
	away.position = Vector2(2, 2)
	away.global_position = Vector2(2, 2)
	root.push_input(away)
	var depot: CanvasLayer = ranch.get("depot_menu")
	if mode == "statement":
		await _statement(ranch, depot)
	elif mode == "statement_first":
		await _statement_first(ranch, depot)
	elif mode == "colour":
		await _colour(ranch, depot)
	else:
		await _deliver(ranch, depot)
	quit()


func _statement(ranch: Node, depot: CanvasLayer) -> void:
	var gs: Node = ranch.get("_game_state")
	for i in 31:
		gs.ledger.credit_delivery(0, true)
	# An hour of play: each minute, one on the clock and one at the Depot's counter.
	ranch.set("_interactive", true)
	for minute in 30:
		ranch.call("advance_world", 60.0)
		depot.call("open")
		ranch.set("_menu_opened_msec", int(ranch.get("_menu_opened_msec")) - 60000)
		depot.call("close")
	ranch.set("_interactive", false)
	var world: WorldState = ranch.call("get_world_state")
	print("DEPOTSHOT clock=%.0f s cycle=%d periods_run=%d delivered=%d" % [world.elapsed(),
		world.cycle_index(), gs.ledger.periods_run, gs.ledger.delivered_this_period])
	for i in 30:
		await process_frame
	depot.call("open")
	depot.call("set_tab", 2)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("statement_after_an_hour.png"))
	print("DEPOTSHOT lines:\n" + "\n".join(ranch.call("_statement")))


## P8 (playtest 2026-11-08 items 4, 9, 20, 21, 70): blank and Bloomed Drifters and two named
## stallions at the counter; three delivered in one visit and the ONE toast when it closes;
## then the Pay tab's quota card.
func _colour(ranch: Node, depot: CanvasLayer) -> void:
	var gen: Script = load("res://systems/pony_generator.gd")
	var grand: PlotData = ranch.call("_plots_catalogue").by_id(&"pen_grand")
	var slot0: PlotSlot = ranch.call("plot_slots")[0]
	if slot0.is_overgrown():
		slot0.set_overgrown(false)
	if slot0.is_empty():
		slot0.build(grand)
	var pen: Pen = slot0.get_built() as Pen
	for inst in pen.ponies():
		pen.remove_pony(inst.uid)
	var blank := PonyInstanceScript.create(&"stock_shy", 7001)
	blank.stock = gen.generate(7001).to_dict()
	var bloomed := PonyInstanceScript.create(&"stock_curious", 7002)
	bloomed.stock = gen.generate(7002).to_dict()
	pen.add_pony(blank)
	pen.add_pony(bloomed)
	pen.bloom_now(bloomed)
	pen.add_pony(PonyInstanceScript.create(&"braeburn", 7003))
	pen.add_pony(PonyInstanceScript.create(&"drwhooves", 7004))
	for i in 20:
		await process_frame
	depot.call("open")
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("colour_deliver_tab.png"))
	# The blank, then the Bloomed one (both on one press), then Braeburn (asks first).
	depot.call("confirm")
	await process_frame
	depot.call("confirm")
	await process_frame
	depot.call("confirm")
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("colour_confirm_he.png"))
	print("DEPOTSHOT confirm lines: ", depot.call("drawn_lines"))
	depot.call("move_selection", -1)
	depot.call("confirm")
	for i in 90:
		await process_frame
	depot.call("close")
	var hud: Node = ranch.get_node("HUD")
	print("DEPOTSHOT toast: ", hud.call("toast_text"), " pending: ", hud.call("pending_toasts"))
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("colour_one_toast.png"))
	depot.call("open")
	depot.call("set_tab", 1)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("colour_pay_quota.png"))
	print("DEPOTSHOT quota: ", depot.call("quota_card_text"))


func _statement_first(ranch: Node, depot: CanvasLayer) -> void:
	var gs: Node = ranch.get("_game_state")
	for i in 31:
		gs.ledger.credit_delivery(0, true)
	ranch.call("advance_world", 1300.0)
	depot.call("open")
	depot.call("set_tab", 2)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("statement_first_period.png"))
	print("DEPOTSHOT lines:\n" + "\n".join(ranch.call("_statement")))


func _deliver(ranch: Node, depot: CanvasLayer) -> void:
	var grand: PlotData = ranch.call("_plots_catalogue").by_id(&"pen_grand")
	var slots: Array = ranch.call("plot_slots")
	for p in OWNER_PENS.size():
		var slot: PlotSlot = slots[p]
		if slot.is_overgrown():
			slot.set_overgrown(false)
		if slot.is_empty():
			slot.build(grand)
		var pen: Pen = slot.get_built() as Pen
		for id: String in OWNER_PENS[p]:
			# Straight into the pen, as a load of the owner's old save does: the duplicates
			# were made before this fix and a load keeps them (nobody owned is ever deleted).
			pen.add_pony(PonyInstanceScript.create(StringName(id)))
	for i in 30:
		await process_frame
	depot.call("open")
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("deliver_owner_roster.png"))
	for r: Dictionary in depot.call("deliver_rows"):
		print("DEPOTSHOT row %s kind=%s" % [r.get("name"), r.get("kind", "?")])
