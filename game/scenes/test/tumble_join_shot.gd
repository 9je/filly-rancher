extends SceneTree
## ITEM 13 RENDER: Tumble joining (the Scoop handed over), from the player's own camera: a
## frame every half second and her distance, as she comes in from behind the camera.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(960, 540)
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
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	ranch.get("_game_state").story.set_flag("has_scoop")
	ranch.get("people").call("populate")
	var tb: Node3D = ranch.get("people").call("npc", &"tumble")
	var pl: Node3D = ranch.get("player")
	var t0 := Time.get_ticks_msec()
	var k := 0
	while k < 10:
		await process_frame
		if Time.get_ticks_msec() - t0 >= 500 * k:
			root.get_texture().get_image().save_png(out.path_join("join_%02d.png" % k))
			print("JOIN %d d %.1f" % [k, tb.global_position.distance_to(pl.global_position)])
			k += 1
	quit()
