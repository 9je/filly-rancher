extends SceneTree
## G9 CAPTURE (FS5.1: hoof loudness measured in the 3D mix against the beds). Run under Godot's
## movie writer (--write-movie <dir>/f.png), which mixes the audio into <dir>/f.wav even on the
## Dummy driver, at the player's own camera (the listener):
##   --take=music  the day score alone, standing still (every other bus muted)
##   --take=hoofs  the player walking on grass, only the Effects bus (her hoofsteps) live
## tools/measure_hooves.py compares the two takes.
const BootIntentScript := preload("res://world/boot_intent.gd")
var take := "music"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--take="):
			take = a.substr(7)
	_run.call_deferred()


func _run() -> void:
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
	ranch.get("creation_screen").call("confirm")
	for i in 60:
		await process_frame
		var lp: Node = ranch.get("letter_panel")
		if lp != null and lp.get("visible"):
			(lp.call("close_button_node") as Button).pressed.emit()
			break
	paused = false
	var keep := &"Music" if take == "music" else &"Effects"
	for i in AudioServer.bus_count:
		var n := AudioServer.get_bus_name(i)
		if n != &"Master":
			AudioServer.set_bus_mute(i, n != keep)
	var music := root.get_node_or_null(^"Music")
	if music != null:
		music.call("play_context", &"day")
	# Let the fade in finish, then mark the take's start in the log.
	for i in 200:
		await process_frame
	print("TAKE_START frame ", Engine.get_frames_drawn())
	if take == "hoofs":
		Input.action_press(&"move_forward")
	for i in 360:
		await process_frame
	Input.action_release(&"move_forward")
	print("TAKE_END frame ", Engine.get_frames_drawn())
	quit()
