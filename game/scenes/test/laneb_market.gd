extends SceneTree
## P9 W3 items 41, 42, 43: the Market the way the owner reaches it. Walk to the door, press E,
## Buy tab; buy hay three times with the pointer (the list must not move); scroll down and
## click the Apple Tree once (it must only ask "Sure?"), click again (bought, Owned).
##   -s res://scenes/test/laneb_market.gd -- --out=<dir> [--w=2560 --h=1440]
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var size := Vector2i(1600, 900)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--w="):
			size.x = int(a.substr(4))
		elif a.begins_with("--h="):
			size.y = int(a.substr(4))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _tiles_y(m: Node) -> String:
	var ys := []
	for t in m.call("row_nodes"):
		ys.append(int((t as Control).global_position.y))
	return str(ys)


func _run() -> void:
	var ranch: Node = await Boot.boot(self, Boot.FIXTURE, size)
	(ranch.get("_economy") as Economy).bits = 9000
	Boot.at_door(ranch, ^"Buildings/Market")
	await Boot.shot(self, out.path_join("market_prompt.png"), 30)
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	await Boot.press(self, &"interact")
	var m: Node = ranch.get("market_menu")
	for i in 30:
		await process_frame
	var buy_tab: Button = m.call("tab_button", 1)
	await Boot.click(self, Boot.centre_of(self, buy_tab))
	for i in 40:
		await process_frame
	await Boot.shot(self, out.path_join("market_buy.png"), 10)
	var scroll: ScrollContainer = m.get("_scroll")
	var hay: Control = m.call("row_nodes")[0]
	var at := Boot.centre_of(self, hay)
	print("BEFORE scroll=", scroll.scroll_vertical, " tiles=", _tiles_y(m), " bits=", ranch.get("_economy").bits)
	for k in 3:
		await Boot.click(self, at)
		for i in 20:
			await process_frame
		print("HAY%d scroll=%d tiles=%s bits=%d" % [k, scroll.scroll_vertical, _tiles_y(m), ranch.get("_economy").bits])
	await Boot.shot(self, out.path_join("market_after_hay.png"), 5)
	# Scroll down with the wheel like a player, then buy hay's neighbours never move either.
	var rows0: Array = m.call("buy_rows")
	var want := -1
	for i in rows0.size():
		if (rows0[i] as ShopItem).display_name.contains("Apple Tree"):
			want = i
	for k in 40:
		var tile0: Control = m.call("row_nodes")[want]
		if scroll.get_global_rect().encloses(tile0.get_global_rect()):
			break
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = at
		wheel.global_position = at
		root.push_input(wheel)
		var up := wheel.duplicate() as InputEventMouseButton
		up.pressed = false
		root.push_input(up)
		for f in 4:
			await process_frame
	for i in 30:
		await process_frame
	var rows: Array = m.call("buy_rows")
	var tree_i := -1
	for i in rows.size():
		if (rows[i] as ShopItem).display_name.contains("Apple Tree"):
			tree_i = i
	var tree_tile: Control = m.call("row_nodes")[tree_i]
	var tat := Boot.centre_of(self, tree_tile)
	print("TREE before scroll=", scroll.scroll_vertical, " at=", tat)
	await Boot.click(self, tat)
	for i in 20:
		await process_frame
	print("TREE one click: bits=%d armed=%s scroll=%d" % [ranch.get("_economy").bits, m.call("armed_item") != null, scroll.scroll_vertical])
	await Boot.shot(self, out.path_join("market_tree_armed.png"), 5)
	await Boot.click(self, tat)
	for i in 30:
		await process_frame
	print("TREE two clicks: bits=%d scroll=%d price=%s" % [ranch.get("_economy").bits, scroll.scroll_vertical, m.call("row_price_text", tree_i)])
	await Boot.shot(self, out.path_join("market_tree_owned.png"), 5)
	print("LANEB_MARKET_OK")
	quit(0)
