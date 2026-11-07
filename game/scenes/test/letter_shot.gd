extends SceneTree
## THE PAPER LETTERS AND THE MARKET, AT THE OWNER'S SPOT (PS6 items 8, 51, G13, G14): the
## welcome letter as a new game opens it, the Employee Appreciation Survey as the mailbox opens
## it (with a pony to name), and the Market's Buy tab scrolled to the decorations.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/letter_shot.gd -- --out=/abs/dir [--size=1280x720]
const BootIntentScript := preload("res://world/boot_intent.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
var out := ""
var size := Vector2i(1280, 720)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(file: String) -> void:
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(file))


func _run() -> void:
	root.get_window().size = size
	# xvfb's pointer sits mid screen and would hover whatever is there: park it in a corner.
	var park := InputEventMouseMotion.new()
	park.position = Vector2(2, 2)
	park.global_position = park.position
	Input.parse_input_event(park)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	for i in 30:
		await process_frame
	var lp: Node = ranch.get("letter_panel")
	print("LETTER welcome open=", lp.call("is_open"))
	await _shot("welcome_letter.png")
	lp.call("close")
	# The survey, with two ponies she could name.
	var state: Node = ranch.get("_game_state")
	state.call("add_pony", PonyInstanceScript.create(&"trixie"))
	state.call("add_pony", PonyInstanceScript.create(&"fluttershy"))
	(ranch.call("get_story") as Object).call("post", &"weather_survey")
	print("LETTER survey open=", ranch.call("open_mailbox_letter"))
	await _shot("mailbox_survey.png")
	var replies: Array = lp.call("reply_buttons")
	if not replies.is_empty():
		var hover := InputEventMouseMotion.new()
		hover.position = root.get_final_transform() * (replies[0] as Control).get_global_rect().get_center()
		hover.global_position = hover.position
		root.push_input(hover)
		await _shot("mailbox_survey_hover.png")
		root.push_input(park)
	lp.call("close")
	paused = false
	for i in 10:
		await process_frame
	var market: Node = ranch.get("market_menu")
	market.call("open")
	market.call("set_tab", 1)
	await _shot("market_buy_top.png")
	var rows: Array = market.call("buy_rows")
	var last := 0
	for i in rows.size():
		if String((rows[i] as Resource).get("id")).begins_with("decor_"):
			last = i
	var first_decor := -1
	for i in rows.size():
		if String((rows[i] as Resource).get("id")).begins_with("decor_"):
			first_decor = i
			break
	market.call("point_at_row", first_decor)
	await _shot("market_buy_decor_a.png")
	market.call("point_at_row", (first_decor + last) / 2)
	await _shot("market_buy_decor_b.png")
	market.call("point_at_row", last)
	await _shot("market_buy_decor_c.png")
	print("LETTERSHOT_OK")
	quit()
