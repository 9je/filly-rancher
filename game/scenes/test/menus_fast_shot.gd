extends SceneTree
## THE TOWN'S COUNTERS AND THE LETTERS, FAST (Fable AAA review round 1, #8). Each menu scene on
## its own over a still of the world (--bg), fed the providers its tests feed it, so a look
## change is judged in seconds rather than after the whole valley boots on the software
## renderer. --only picks from depot, market, letter, blackjack.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/menus_fast_shot.gd -- --out=/abs/dir --bg=/abs/still.png [--only=depot,market]
const LettersScript := preload("res://systems/letters.gd")
var out := ""
var bg := ""
var only: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--bg="):
			bg = a.substr(5)
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _shot(name: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	if bg != "":
		var still := TextureRect.new()
		still.texture = ImageTexture.create_from_image(Image.load_from_file(bg))
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var layer := CanvasLayer.new()
		layer.layer = -1
		root.add_child(layer)
		still.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(still)
	if _want("depot"):
		var depot: Node = load("res://ui/depot_menu.tscn").instantiate()
		root.add_child(depot)
		depot.set("can_open", func() -> bool: return true)
		depot.set("bits_provider", func() -> int: return 0)
		depot.set("balance_provider", func() -> int: return 25000)
		depot.set("rows_provider", func() -> Array[Dictionary]:
			var rows: Array[Dictionary] = []
			return rows)
		depot.set("quota_provider", func() -> Dictionary:
			return {"delivered": 1, "quota": 3, "day": 4, "days_left": 3, "balance": 25000,
				"closed": false, "first": true})
		depot.set("statement_provider", func() -> Array[String]:
			return load("res://systems/ledger.gd").new().statement_lines("Twilight", 1, 0, 2))
		depot.call("open")
		await _shot("depot_empty")
		depot.call("set_tab", 1)
		await _shot("depot_pay")
		depot.call("close")
		depot.queue_free()
	if _want("market"):
		var econ: Economy = load("res://systems/economy.gd").new(140)
		var pouch = load("res://systems/gem_pouch.gd").new()
		var shop = load("res://systems/shop.gd").new(econ, pouch,
			load("res://systems/inventory.gd").new(), [])
		var market: Node = load("res://ui/market_menu.tscn").instantiate()
		root.add_child(market)
		market.set("shop", shop)
		market.call("open")
		market.call("set_tab", 1)
		await _shot("market_buy")
		market.call("close")
		market.queue_free()
	if _want("letter"):
		var panel: Node = load("res://ui/letter_panel.tscn").instantiate()
		root.add_child(panel)
		panel.call("open", LettersScript.render(LettersScript.Id.WELCOME,
			{"name": "Twilight", "balance": 25000, "quota": 3}))
		await _shot("letter_welcome")
		panel.call("close")
		panel.queue_free()
	print("MENUS_FAST_SHOT_OK")
	quit()
