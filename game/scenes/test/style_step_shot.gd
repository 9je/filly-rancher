extends SceneTree
## ITEM 6 RENDER: the creator's Finishing touches step in the real game, two looks picked
## through the cards (a blaze, sleepy eyes, the straw hat; white dapples, saddlebags), and
## the pony turned to show them.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String, frames: int = 30) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _pick(cs: Node, grid: String, i: int) -> void:
	(cs.find_child(grid, true, false).call("cell", i) as Button).pressed.emit()


func _turn(cs: Node, deg: float) -> void:
	var tt := cs.get_node_or_null(^"Layout/Stage/Viewport/SubViewport/Turntable") as Node3D
	tt.rotation.y = deg_to_rad(deg)
	cs.set("_drag_rest", 999.0)


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 90:
		await process_frame
	# The xvfb pointer sits mid screen and would hover a card: park it in a corner.
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(2, 2)
	Input.parse_input_event(mm)
	var cs: Node = ranch.get("creation_screen")
	cs.call("set_step", 3)
	_pick(cs, "MarkingGrid", 2)
	_pick(cs, "EyeShapeGrid", 2)
	_pick(cs, "WearGrid", 1)
	_turn(cs, 20.0)
	await _shot("style_step_hat")
	_pick(cs, "MarkingGrid", 4)
	_pick(cs, "EyeShapeGrid", 1)
	_pick(cs, "MarkingColourGrid", 0)
	_pick(cs, "WearGrid", 6)
	_turn(cs, -70.0)
	await _shot("style_step_bags")
	# The hat on every mane style of every kind of pony.
	_pick(cs, "WearGrid", 1)
	for race in 3:
		cs.call("set_race", race)
		for style in preload("res://systems/player_look.gd").style_count(race):
			cs.call("set_mane_style", style)
			_turn(cs, 30.0)
			await _shot("hat_%d_%d" % [race, style], 12)
	quit(0)
