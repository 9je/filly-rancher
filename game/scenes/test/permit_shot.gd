extends SceneTree
## ITEM 55 RENDER: the Market's Buy tab with each permit selected, at 1280 x 720.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String, frames: int = 20) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and bool(ranch.get("boot_done")):
			break
	for i in 30:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	ranch.call("get_economy").grant(2000)
	root.warp_mouse(Vector2(1270, 710))
	var mm: Node = ranch.get("market_menu")
	mm.call("open")
	mm.call("set_tab", 1)
	var rows: Array = mm.call("buy_rows")
	var ids := []
	for r in rows:
		ids.append(String(r.id))
	print("CATALOGUE ", ids)
	var names := []
	for n in mm.call("row_nodes"):
		names.append(String(n.name))
	print("ROWNODES ", names)
	for i in rows.size():
		if String(rows[i].id).begins_with("permit_"):
			var away := InputEventMouseMotion.new()
			away.position = Vector2(1270, 710)
			away.global_position = away.position
			root.push_input(away)
			await process_frame
			mm.call("point_at_row", i)
			print("PICK ", i, " ", mm.call("detail_state").get("name", ""))
			await _shot("market_" + String(rows[i].id))
			print("AFTER ", mm.call("detail_state").get("name", ""))
	for i in rows.size():
		if String(rows[i].id) == "decor_hay_bales":
			mm.call("point_at_row", i)
			await _shot("market_decor_hay_bales")
			print("DECOR before ", mm.call("detail_state"))
			var ok: bool = mm.call("confirm")
			for k in 10:
				await process_frame
			print("DECOR bought=", ok, " bits=", ranch.call("get_economy").bits, " owned=", Decor.owns(ranch.get("_game_state").story, &"hay_bales"))
			await _shot("market_decor_after_buy")
	quit(0)
