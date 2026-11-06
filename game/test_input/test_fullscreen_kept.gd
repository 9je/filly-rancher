extends "res://test_input/input_test.gd"
## INPUT_TEST_REALTIME
## OWNER PLAYTEST 2026-11-05 (item 1): "the bug came back where i full screened in loading and
## it went small when it loaded in". New game from the title with the mouse, put the window
## into fullscreen the way the desktop does while the ranch is loading, and it must still be
## fullscreen once the ranch is up: the ranch never sets the window on load (PT11).


func _play() -> void:
	_deadline_s = 300.0
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(30)
	if not await click_text("New game"):
		return
	if RI.find_text(root, "Really start over") != null:
		await click_text("New game")
	await wait(0.5)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	note("fullscreen asked for during the load: mode %d" % DisplayServer.window_get_mode())
	await wait(8.0)
	if not await click_text("This is me", 30.0):
		return
	await wait(8.0)
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		fail("the ranch put the window back to mode %d" % mode)
		return
	ok("fullscreen chosen during the load is still fullscreen in the ranch")
