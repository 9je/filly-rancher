extends SceneTree
## The PS10 menu gaps on screen, in the real ranch at the owner's 1600 x 900:
##   --mode=chip    a lesson chip under the pointer (G1, FS1.4: its sentence as a tooltip)
##   --mode=market  the Market opening (G6, FS6.1: tiles stagger in) and a purchase (the coin)
##   --mode=depot   three deliveries at the Depot (G7, FS6.2: the payout; G8, FS8.3: shapes)
## The animations are filmed at a quarter speed (Engine.time_scale) so a frame lands every few
## game milliseconds; each frame's file name carries its game time in ms.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/fs_menus_shot.gd -- --out=/abs/dir --mode=market
const BootIntentScript := preload("res://world/boot_intent.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const SLOW := 0.25
const KEEP := 9
var out := ""
var mode := "market"


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
	_point_at(Vector2(2, 2))
	if mode == "chip":
		await _chip(ranch)
	elif mode == "depot":
		await _depot(ranch)
	else:
		await _market(ranch)
	quit()


## xvfb's pointer sits at the screen centre and would hover whatever is there.
func _point_at(at: Vector2) -> void:
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


## Film `seconds` of game time at SLOW speed, holding the frames in memory (saving a PNG takes
## longer than a frame) and writing them as <prefix>_<game ms>.png at the end.
func _film(prefix: String, seconds: float, keep := KEEP, on_frame := Callable()) -> void:
	Engine.time_scale = SLOW
	# The first frame at or after each step of `seconds / keep`, so a film is a few frames.
	var frames: Array = []
	var seen := 0
	var next := 0.0
	var start := Time.get_ticks_usec()
	while true:
		if on_frame.is_valid():
			on_frame.call(seen)
		await process_frame
		seen += 1
		var ms := (Time.get_ticks_usec() - start) / 1000.0 * SLOW
		if ms + 0.001 >= next:
			frames.append([ms, root.get_texture().get_image()])
			next = ms + seconds * 1000.0 / keep
		if ms > seconds * 1000.0:
			break
	Engine.time_scale = 1.0
	for f: Array in frames:
		(f[1] as Image).save_png(out.path_join("%s_%04d.png" % [prefix, int(f[0])]))
	print("FSSHOT %s frames=%d kept=%d" % [prefix, seen, frames.size()])


func _chip(ranch: Node) -> void:
	var hud: Node = ranch.get_node("HUD")
	hud.call("set_tasks", [
		{"id": "tutorial_catch", "text": "Catch a pony with your magic beam.", "done": true, "paid": false, "reward_bits": 20},
		{"id": "tutorial_pen", "text": "Move a pony into a pen.", "done": false, "paid": false, "reward_bits": 30},
		{"id": "tutorial_sell", "text": "Sell a gem at the market.", "done": false, "paid": false, "reward_bits": 50},
	])
	for i in 30:
		await process_frame
	_shot("chips_plain")
	# The pointer free, as it is whenever the cursor is not the camera's.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var card := hud.get_node("Tasks") as Control
	var chips: Array = []
	for n in card.find_children("*", "VBoxContainer", true, false):
		if (n as Node).get_child_count() == 3 and (n as Node).get_child(0).get_class() == "Control":
			chips.append(n)
	print("FSSHOT chips=%d" % chips.size())
	if chips.size() < 2:
		return
	var pen := chips[1] as Control
	# Canvas (1920 x 1080 base) to window pixels.
	var at := root.get_final_transform() * pen.get_global_rect().get_center()
	# A few small moves onto the chip, the way a hand arrives, then a rest.
	for k in 4:
		_point_at(at + Vector2(12 - k * 4, 6 - k * 2))
		await process_frame
	for i in 90:
		await process_frame
	_shot("chip_hover_pen")
	print("FSSHOT pointer at %s over %s" % [at, pen.get_global_rect()])


func _market(ranch: Node) -> void:
	var economy: Object = ranch.get("_economy")
	economy.call("grant", 2000)
	var market: CanvasLayer = ranch.get("market_menu")
	for i in 10:
		await process_frame
	market.call("open")
	_point_at(Vector2(2, 2))
	await _film("market_open", 0.45)
	for i in 30:
		await process_frame
	_shot("market_settled")
	var rows: Array = market.call("buy_rows")
	var shop: Object = market.get("shop")
	var pick := -1
	for i in rows.size():
		if bool(shop.call("can_buy", rows[i])) and i >= 3:
			pick = i
			break
	print("FSSHOT buying row %d of %d" % [pick, rows.size()])
	if pick < 0:
		return
	market.call("take_row", pick)
	_point_at(Vector2(2, 2))
	await _film("market_buy", 0.8)
	for i in 30:
		await process_frame
	_shot("market_after_buy")


func _depot(ranch: Node) -> void:
	var grand: PlotData = ranch.call("_plots_catalogue").by_id(&"pen_grand")
	var slot: PlotSlot = ranch.call("plot_slots")[0]
	if slot.is_overgrown():
		slot.set_overgrown(false)
	if slot.is_empty():
		slot.build(grand)
	var pen: Pen = slot.get_built() as Pen
	for id in ["twilight", "rarity", "fluttershy", "berrypunch", "trixie", "derpyhooves", "carrottop", "sweetiebelle"]:
		pen.add_pony(PonyInstanceScript.create(StringName(id)))
	for i in 30:
		await process_frame
	var depot: CanvasLayer = ranch.get("depot_menu")
	depot.call("open")
	_point_at(Vector2(2, 2))
	for i in 30:
		await process_frame
	_shot("depot_tiles")
	# Three deliveries in a row, each a click on her tile and a click on "yes", a few frames
	# apart as a quick hand clicks, filmed from the first click.
	var clicks := func(frame: int) -> void:
		if frame % 16 == 0 and frame < 48:
			depot.call("take_row", 1)
			_point_at(Vector2(2, 2))
		elif frame % 16 == 8 and frame < 48 and bool(depot.call("is_confirming")):
			depot.call("take_row", 0)
			_point_at(Vector2(2, 2))
	await _film("depot_payout", 3.6, 16, clicks)
	for i in 30:
		await process_frame
	_shot("depot_after")
